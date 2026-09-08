extends SceneTree


var _failures := 0
var _b: Balance


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func _init() -> void:
	_b = Balance.default()

	print("\n-- shipped balance obeys its own invariants --")
	var problems := _b.validate()
	check("balance.tres problems", problems, PackedStringArray())
	check("loaded from disk, not fallback", _b.starting_remaining, 30 * Balance.MINUTES_PER_DAY)

	print("\n-- validate() catches the dead-conversion bug --")
	var bad := Balance.new()
	bad.conversion_cap = 1
	var bad_problems := bad.validate()
	check("flagged", bad_problems.size(), 1)
	check("names the right field", bad_problems[0].contains("conversion_cap"), true)

	print("\n-- validate() catches a floor with no choice in it --")
	var flat := Balance.new()
	flat.fights_and_events_per_act = [10, 10, 10]
	flat.fights_min_per_act = [10, 10, 10]
	flat.events_min_per_act = [0, 0, 0]
	flat.rooms_per_act_affordable = 10
	check("flagged", flat.validate()[0].contains("No room choice"), true)

	print("\n-- one-way elapsed --")
	var c := RunClock.new(_b)
	c.advance_turn()
	c.advance_turn()
	check("remaining", c.remaining, _b.starting_remaining - 360)
	check("elapsed", c.elapsed, 360)
	c.advance(-60, RunClock.Source.TRAVEL)
	check("elapsed unchanged by negative", c.elapsed, 360)

	print("\n-- an unpriced room transition falls back to the base rate, one-way too --")
	var r := RunClock.new(_b)
	for i in 4:
		r.advance_room()
	check("four rooms", r.elapsed, 4 * _b.room_transition_cost)
	check("logged as travel", r.spent_by_source()[RunClock.Source.TRAVEL],
		4 * _b.room_transition_cost)

	print("\n-- threat steps --")
	var t := RunClock.new(_b)
	check("level at 0h", t.threat_level(), 0)
	t.advance(_b.threat_step - 60, RunClock.Source.TRAVEL)
	check("level one minute short of a step", t.threat_level(), 0)
	check("minutes to next", t.minutes_to_next_threat(), 60)
	var seen := []
	t.threat_level_changed.connect(func(l: int) -> void: seen.append(l))
	t.advance(60, RunClock.Source.TRAVEL)
	check("level on the step", t.threat_level(), 1)
	check("signal fired once", seen, [1])
	check("progress label", t.threat_progress(),
		"Threat 1 / ~%d" % _b.expected_threat_steps)

	print("\n-- conversion must beat the fire it costs --")
	var f := RunClock.new(_b)
	f.restore(_b.conversion_cap)
	check("convertible", f.convertible_restored(), 36 * 60)
	check("yield", f.conversion_yield(f.convertible_restored()), 18 * 60)
	check("gained", f.convert(f.convertible_restored()), 18 * 60)
	check("restored drained", f.restored, 0)
	check("remaining raised", f.remaining, _b.starting_remaining + 18 * 60)

	print("\n-- conversion is capped --")
	var cap := RunClock.new(_b)
	cap.restore(100 * 60)
	check("cap holds", cap.convert(100 * 60), 18 * 60)
	check("surplus untouched", cap.restored, 64 * 60)

	print("\n-- a remainder too small to convert is not convertible --")
	var odd := RunClock.new(_b)
	odd.restore(60)
	check("an hour on hand", odd.restored, 60)
	check("but none of it converts", odd.convertible_restored(), 0)
	check("converting it yields nothing", odd.convert(odd.restored), 0)
	check("and takes nothing", odd.restored, 60)
	odd.restore(120)
	check("a third hour makes two convertible", odd.convertible_restored(), 120)
	check("which yield one", odd.convert(odd.convertible_restored()), 60)
	check("leaving the odd hour behind", odd.restored, 60)

	print("\n-- expiry fires once --")
	var e := RunClock.new(_b, 120)
	var expired := []
	e.warden_expired.connect(func() -> void: expired.append(true))
	check("can_afford 120 of 120", e.can_afford(120), false)
	e.advance(90, RunClock.Source.TRAVEL)
	check("not yet", expired.size(), 0)
	e.advance(90, RunClock.Source.TRAVEL)
	check("remaining floors at 0", e.remaining, 0)
	check("expired once", expired.size(), 1)
	e.advance(60, RunClock.Source.TRAVEL)
	check("no second emit", expired.size(), 1)
	check("elapsed still counted", e.elapsed, 240)

	print("\n-- projection matches the real thing --")
	var p := RunClock.new(_b)
	p.advance(_b.threat_step - 60, RunClock.Source.TRAVEL)
	var proj := p.project(2 * 60)
	check("crosses threat", proj["crosses_threat"], true)
	check("projected level", proj["threat_level"], 1)
	check("not fatal", proj["fatal"], false)
	p.advance(2 * 60, RunClock.Source.TRAVEL)
	check("projection was right", p.threat_level(), proj["threat_level"])

	print("\n-- shops spend restored, not remaining --")
	var s := RunClock.new(_b)
	s.restore(600)
	check("overspend refused", s.spend_restored(700), false)
	check("spend ok", s.spend_restored(600), true)
	check("restored gone", s.restored, 0)
	check("remaining untouched", s.remaining, _b.starting_remaining)

	print("\n-- retuning Balance actually retunes the clock --")
	var tuned := Balance.new()
	tuned.turn_cost = 60
	tuned.threat_step = 600
	var tc := RunClock.new(tuned)
	tc.advance_turn()
	check("turn cost follows balance", tc.elapsed, 60)
	tc.advance(9 * 60, RunClock.Source.TRAVEL)
	check("threat step follows balance", tc.threat_level(), 1)

	print("\n-- ledger and round-trip --")
	var l := RunClock.new(_b)
	l.advance_turn()
	l.advance(_b.fire_rest_cost, RunClock.Source.FIRE)
	l.restore(360)
	check("turn total", l.spent_by_source()[RunClock.Source.TURN], 180)
	check("fire total", l.spent_by_source()[RunClock.Source.FIRE], _b.fire_rest_cost)
	var back := RunClock.from_dict(l.to_dict(), _b)
	check("remaining survives", back.remaining, l.remaining)
	check("elapsed survives", back.elapsed, l.elapsed)
	check("restored survives", back.restored, l.restored)
	check("ledger survives", back.spent_by_source()[RunClock.Source.FIRE], _b.fire_rest_cost)

	print("\n-- formatting --")
	var d := RunClock.new(_b)
	d.advance(30 * 60 + 45, RunClock.Source.TRAVEL)
	check("the calendar reads the elapsed time", d.format_clock(),
		d.format_date_of(d.date_at(30 * 60 + 45)))
	var marks := d.date_at(30 * 60 + 45)
	check("a day and a half in, one day has turned",
		marks["day"], int(RunClock.date_from_seed(0)["day"]) + 1)
	check("at the right hour", marks["hour"],
		(int(RunClock.date_from_seed(0)["hour"]) + 30) % 24)
	check("and the deadline is the budget away",
		d.format_deadline(), d.format_date_of(d.date_at(d.elapsed + d.remaining)))
	check("span is hours, never days or minutes", RunClock.format_span(336 * 60), TranslationServer.translate("time.hours").format({"n": 336}))

	_daytime_checks(_b)

	_the_seed_is_the_date(_b)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)

func _daytime_checks(b: Balance) -> void:
	print("\n-- the day is cut into four, and the cuts are where the balance says --")
	var turns := [b.morning_starts_minute, b.day_starts_minute,
		b.evening_starts_minute, b.night_starts_minute]
	var want := [RunClock.Daytime.MORNING, RunClock.Daytime.DAY,
		RunClock.Daytime.EVENING, RunClock.Daytime.NIGHT]
	for i in turns.size():
		var at_turn := RunClock.new(b, -1, RunClock.seed_from_date(0, 0, 0, 0))
		at_turn.advance(int(turns[i]), RunClock.Source.TRAVEL)
		check("on the stroke it is phase %d" % want[i], at_turn.daytime(), want[i])
		var moment_before := RunClock.new(b, -1, RunClock.seed_from_date(0, 0, 0, 0))
		moment_before.advance(int(turns[i]) - 1, RunClock.Source.TRAVEL)
		check("and a minute earlier it is not", moment_before.daytime() != want[i], true)

	print("\n-- the four add up to one whole day --")
	var counted := {}
	var walk := RunClock.new(b, -1, RunClock.seed_from_date(0, 0, 0, 0))
	for hour in 24:
		counted[walk.daytime()] = int(counted.get(walk.daytime(), 0)) + 1
		walk.advance(60, RunClock.Source.TRAVEL)
	var total := 0
	for sky in counted:
		total += int(counted[sky])
	check("every hour belongs to some phase", total, 24)
	check("all four phases appear", counted.size(), 4)

	print("\n-- the opening hour comes from the seed, not from a dial --")
	for hour in [0, 6, 13, 23]:
		var opened := RunClock.new(b, -1, RunClock.seed_from_date(1, 2, 3, hour))
		check("a seed set to %02d opens at %02d" % [hour, hour],
			opened.date_at(0)["hour"], hour)
	var wrapped := RunClock.new(b, -1, RunClock.seed_from_date(1, 2, 3, 99))
	check("an hour past the end of a day is refused, not wrapped",
		wrapped.date_at(0)["hour"], 23)


func _the_seed_is_the_date(b: Balance) -> void:
	print("\n-- the seed and the opening moment are the same number --")
	check("a date packs into a seed", RunClock.seed_from_date(1487, 3, 1, 8),
		1487 * 1000000 + 3 * 10000 + 1 * 100 + 8)
	var back := RunClock.date_from_seed(RunClock.seed_from_date(1487, 3, 1, 8))
	check("and unpacks unchanged",
		[back["year"], back["month"], back["day"], back["hour"]], [1487, 3, 1, 8])

	print("\n-- the lower world's calendar takes any two digits --")
	var wild := RunClock.seed_from_date(9999, 47, 88, 21)
	var read := RunClock.date_from_seed(wild)
	check("month 47 survives", read["month"], 47)
	check("day 88 survives", read["day"], 88)
	var clock := RunClock.new(b, -1, wild)
	var opened := clock.date_at(0)
	check("nothing was quietly normalised",
		[opened["year"], opened["month"], opened["day"], opened["hour"]], [9999, 47, 88, 21])

	print("\n-- and it rolls over at a hundred, not at thirty --")
	var late := RunClock.new(b, -1, RunClock.seed_from_date(5, 9, 99, 0))
	var tomorrow := late.date_at(Balance.MINUTES_PER_DAY)
	check("day 99 becomes day 0 of the next month",
		[tomorrow["month"], tomorrow["day"]], [10, 0])
	var year_end := RunClock.new(b, -1, RunClock.seed_from_date(5, 99, 99, 0))
	var over := year_end.date_at(Balance.MINUTES_PER_DAY)
	check("and month 99 rolls the year", [over["year"], over["month"], over["day"]], [6, 0, 0])

	print("\n-- the year stops at four digits --")
	check("a wider year is clamped, not wrapped",
		RunClock.date_from_seed(RunClock.seed_from_date(RunClock.YEAR_LIMIT + 500, 0, 0, 0))["year"],
		RunClock.YEAR_LIMIT)
	check("and the widest date there is still fits an integer",
		RunClock.seed_from_date(RunClock.YEAR_LIMIT, 99, 99, 23) < 9223372036854775807, true)
