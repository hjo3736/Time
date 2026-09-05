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
	check("loaded from disk, not fallback", _b.starting_remaining, 336 * 60)

	print("\n-- validate() catches the dead-conversion bug --")
	var bad := Balance.new()
	bad.conversion_cap = 12 * 60
	var bad_problems := bad.validate()
	check("flagged", bad_problems.size(), 1)
	check("names the right field", bad_problems[0].contains("conversion_cap"), true)

	print("\n-- validate() catches a floor with no choice in it --")
	var flat := Balance.new()
	flat.rooms_per_act_available = 10
	flat.rooms_per_act_affordable = 10
	check("flagged", flat.validate()[0].contains("No room choice"), true)

	print("\n-- one-way elapsed --")
	var c := RunClock.new(_b)
	c.advance_turn()
	c.advance_turn()
	check("remaining", c.remaining, 336 * 60 - 360)
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
	t.advance(47 * 60, RunClock.Source.TRAVEL)
	check("level at 47h", t.threat_level(), 0)
	check("minutes to next", t.minutes_to_next_threat(), 60)
	var seen := []
	t.threat_level_changed.connect(func(l: int) -> void: seen.append(l))
	t.advance(60, RunClock.Source.TRAVEL)
	check("level at 48h", t.threat_level(), 1)
	check("signal fired once", seen, [1])
	check("progress label", t.threat_progress(), "Threat 1 / ~14")

	print("\n-- conversion must beat the fire it costs --")
	var f := RunClock.new(_b)
	f.restore(_b.conversion_cap)
	check("convertible", f.convertible_restored(), 36 * 60)
	check("yield", f.conversion_yield(f.convertible_restored()), 18 * 60)
	check("net after 8h fire", f.net_from_conversion(f.convertible_restored()), 10 * 60)
	check("gained", f.convert(f.convertible_restored()), 18 * 60)
	check("restored drained", f.restored, 0)
	check("remaining raised", f.remaining, 336 * 60 + 18 * 60)

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
	p.advance(47 * 60, RunClock.Source.TRAVEL)
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
	check("remaining untouched", s.remaining, 336 * 60)

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
	l.advance(_b.fire_cost, RunClock.Source.FIRE)
	l.restore(360)
	check("turn total", l.spent_by_source()[RunClock.Source.TURN], 180)
	check("fire total", l.spent_by_source()[RunClock.Source.FIRE], 480)
	var back := RunClock.from_dict(l.to_dict(), _b)
	check("remaining survives", back.remaining, l.remaining)
	check("elapsed survives", back.elapsed, l.elapsed)
	check("restored survives", back.restored, l.restored)
	check("ledger survives", back.spent_by_source()[RunClock.Source.FIRE], 480)

	print("\n-- formatting --")
	var d := RunClock.new(_b)
	d.advance(30 * 60 + 45, RunClock.Source.TRAVEL)
	check("clock", d.format_clock(), "Day 2 - 14:45")
	check("span is hours, never days or minutes", RunClock.format_span(336 * 60), TranslationServer.translate("time.hours").format({"n": 336}))

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
