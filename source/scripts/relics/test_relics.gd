extends SceneTree


var _failures := 0
var _b: Balance
var _cards: CardDatabase
var _relics: RelicDatabase


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func run_at(hour: int, relic_ids: Array, cards_in_deck: int = 8) -> RunState:
	# The seed carries the departure hour, so it is also how a test picks the sky.
	var run := RunState.new(_b, RunClock.seed_from_date(1487, 3, 1, hour))
	for i in cards_in_deck:
		run.add_card(&"take")
	for id in relic_ids:
		run.add_relic(id, _relics)
	return run


func run_with(relic_ids: Array, cards_in_deck: int = 8) -> RunState:
	var run := RunState.new(_b, 1)
	for i in cards_in_deck:
		run.add_card(&"take")
	for id in relic_ids:
		run.add_relic(id, _relics)
	return run


func dummy(hp: int) -> EnemyStats:
	var c := EnemyStats.new()
	c.max_hp = hp
	c.hp = hp
	c.restored_value = 100
	c.intents = [EnemyIntent.wait()] as Array[EnemyIntent]
	return c


func battle_for(run: RunState, hp: int = 99) -> BattleState:
	return BattleState.new(run, _cards, [dummy(hp)] as Array[EnemyStats], rng(3))


func hit(bt: BattleState) -> bool:
	for i in bt.piles().hand.size():
		if bt.card_at(i).id == &"take":
			return bt.play_card(i, 1)
	return false


func _init() -> void:
	# The pool is being rebuilt and holds almost nothing; the machinery under test
	# is exercised with the shelved cards as well. See CardDatabase.SHELF_ROOT.
	CardDatabase.fixture_roots = PackedStringArray(CardDatabase.TEST_ROOTS)
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()

	print("\n-- the roster loads and passes its own linter --")
	check("problems", _relics.validate(), PackedStringArray())
	check("twenty-one relics", _relics.size(), 21)
	var ids := _relics.all().map(func(r: Relic) -> String: return String(r.id))
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	check("sorted", ids, sorted_ids)

	print("\n-- every relic reads, in both languages --")
	var unwritten := []
	for locale in ["ko", "en"]:
		TranslationServer.set_locale(locale)
		for r in _relics.all():
			# tr() hands back the key when the row is missing, and a passive the
			# player cannot read is the bug validate() cannot see.
			if r.display_name() == String(r.name_key):
				unwritten.append("%s/%s.name" % [locale, r.id])
			if r.description() == String(r.text_key):
				unwritten.append("%s/%s.text" % [locale, r.id])
	TranslationServer.set_locale("en")
	check("nothing missing from strings.csv", unwritten, [])

	print("\n-- 깨진 태엽 adds an hour to every turn --")
	var plain := battle_for(run_with([]))
	check("baseline budget", plain.turn_budget, 180)
	var spring := battle_for(run_with([&"broken_mainspring"]))
	check("with the relic", spring.turn_budget, 240)
	spring.end_turn()
	check("and every turn after", spring.turn_budget, 240)

	print("\n-- 닳은 신발 halves the walk, outside battle entirely --")
	var walker := run_with([&"worn_shoes"], 0)
	var before := walker.clock.remaining
	walker.enter_room(&"a")
	check("nothing at all", before - walker.clock.remaining, 0)
	var barefoot := run_with([], 0)
	var b2 := barefoot.clock.remaining
	barefoot.enter_room(&"a")
	check("without it, the base rate", b2 - barefoot.clock.remaining, _b.room_transition_cost)

	print("\n-- 거둔 것 pays more time out of every defeat --")
	var greedy := run_with([&"gleaning"])
	var gb := battle_for(greedy, 6)
	hit(gb)
	check("victory", gb.phase, BattleState.Phase.VICTORY)
	check("100 became 125, then rounded to the hour", greedy.clock.restored, 120)
	var normal := run_with([])
	var nb := battle_for(normal, 6)
	hit(nb)
	check("without it, 100 rounds to the same hour", normal.clock.restored, 120)

	print("\n-- 멈춘 회중시계 makes the first card of each turn free --")
	var watch := run_with([&"stopped_watch"])
	var wb := battle_for(watch)
	hit(wb)
	check("first card cost nothing", wb.turn_budget, 180)
	hit(wb)
	check("the second cost its hour", wb.turn_budget, 120)
	wb.end_turn()
	hit(wb)
	check("free again next turn", wb.turn_budget, 180)

	print("\n-- the general table never rolls a boss relic --")
	var boss_ids := _relics.of_rarity(Relic.Rarity.BOSS).map(
		func(r: Relic) -> StringName: return r.id)
	check("there are boss relics to avoid", boss_ids.is_empty(), false)
	var rolled := {}
	var empties := 0
	var bosses := 0
	for seed_value in 300:
		var r := _relics.roll(rng(seed_value), _b, [])
		if r == null:
			empties += 1
			continue
		rolled[r.id] = true
		if boss_ids.has(r.id):
			bosses += 1
	check("roll never came up empty", empties, 0)
	check("and never turned up a boss relic in 300 rolls", bosses, 0)
	check("the table is wide enough to be worth rolling", rolled.size() >= 10, true)
	check("a boss relic comes only from the boss table",
		boss_ids.has(_relics.roll_boss(rng(1)).id), true)

	print("\n-- owning a relic takes it off both tables --")
	var everything := _relics.all().map(func(r: Relic) -> StringName: return r.id)
	check("nothing left to give", _relics.roll(rng(1), _b, everything), null)
	check("and no boss relic either", _relics.roll_boss(rng(1), everything), null)

	print("\n-- 평등 makes the four skies the same length --")
	var even := run_at(0, [&"equality"])
	check("the bounds are quarters of a day", Array(even.clock.sky_bounds), [360, 720, 1080, 1440])
	var plain_sky := run_at(0, [])
	check("without it, seven in the morning is night",
		plain_sky.clock.daytime(), RunClock.Daytime.NIGHT)
	for hour in [[3, RunClock.Daytime.NIGHT], [9, RunClock.Daytime.MORNING],
			[15, RunClock.Daytime.DAY], [21, RunClock.Daytime.EVENING]]:
		check("with it, %02d:00 reads %d" % [hour[0], hour[1]],
			run_at(int(hour[0]), [&"equality"]).clock.daytime(), int(hour[1]))
	check("and the sky turns on the quarter",
		run_at(3, [&"equality"]).clock.minutes_until_sky_turns(), 180)

	print("\n-- the sky is recomputed from Balance, never folded onto itself --")
	var settled := run_at(0, [])
	check("a run without it keeps Balance's bounds",
		Array(settled.clock.sky_bounds), Array(settled.clock.default_sky_bounds()))
	var twice := run_at(0, [&"equality"])
	twice.attach_relics(_relics)
	twice.attach_relics(_relics)
	check("and reattaching twice lands in the same place",
		Array(twice.clock.sky_bounds), [360, 720, 1080, 1440])

	print("\n-- the sky decides whether a daytime relic is worth anything --")
	check("noon is the day", run_at(12, []).clock.daytime(), RunClock.Daytime.DAY)
	check("해시계 pays at noon", battle_for(run_at(12, [&"sundial"])).turn_budget, 240)
	check("and nothing at midnight", battle_for(run_at(0, [&"sundial"])).turn_budget, 180)
	var by_night := run_at(0, [&"night_bell"])
	var nb2 := battle_for(by_night, 6)
	hit(nb2)
	check("밤종 turns a 100 kill into 150, which rounds up to three hours",
		by_night.clock.restored, 180)
	var by_noon := run_at(12, [&"night_bell"])
	var nb3 := battle_for(by_noon, 6)
	hit(nb3)
	check("and by day it is dead weight", by_noon.clock.restored, 120)
	var evening := run_at(18, [&"long_shadow"], 0)
	var ev := evening.clock.remaining
	evening.enter_room(&"a")
	check("긴 그림자 halves the evening walk",
		ev - evening.clock.remaining, _b.room_transition_cost / 2)
	var frosted := battle_for(run_at(6, [&"morning_frost"]))
	check("아침 서리 softens what the morning finds",
		frosted.combatants[1].status(StatusRules.SOFTENED), 2)
	check("but only in the morning",
		battle_for(run_at(12, [&"morning_frost"])).combatants[1].status(StatusRules.SOFTENED), 0)

	print("\n-- front-loaded relics fire on turn one and then stop --")
	var opener := battle_for(run_with([&"first_light", &"held_stone", &"quick_hand"]))
	check("첫 빛 on the opening turn", opener.turn_budget, 240)
	check("쥐고 있던 돌 with it", opener.player().block, 8)
	check("빠른 손 dealt a wider hand", opener.piles().hand.size(), 7)
	opener.end_turn()
	check("and turn two is ordinary again", opener.turn_budget, 180)
	check("with no stone left", opener.player().block, 0)
	check("and a hand of five", opener.piles().hand.size(), 5)

	print("\n-- back-loaded relics are worth nothing until the fight drags --")
	var kettle := battle_for(run_with([&"slow_kettle"]))
	check("turn one pays nothing", kettle.turn_budget, 180)
	for i in 3:
		kettle.end_turn()
	check("turn four pays an hour", kettle.turn_budget, 240)

	print("\n-- 가라앉은 먼지 is the same every turn, which is the point --")
	var dust := battle_for(run_with([&"settled_dust"]))
	check("turn one", dust.player().block, 2)
	dust.end_turn()
	check("turn two, on a cleared guard", dust.player().block, 2)

	print("\n-- 마지막 불씨 reads the body, not the run --")
	var hurt := run_with([&"last_ember"])
	var hb := battle_for(hurt)
	check("hale, so nothing", hb.turn_budget, 180)
	hb.player().hp = 10
	hb.end_turn()
	check("wounded, so an hour", hb.turn_budget, 240)

	print("\n-- 빌린 외투 and 짧은 끈 pay out on a kill --")
	var coat := run_with([&"borrowed_coat"])
	var cb := battle_for(coat, 6)
	cb.player().hp = 40
	hit(cb)
	check("the coat healed the vessel", coat.hp, 43)
	var rope := run_with([&"short_rope"])
	var rb := battle_for(rope, 6)
	hit(rb)
	check("a quick kill pays 100 and 25 on top, each rounded up", rope.clock.restored, 180)

	print("\n-- 살얼음 gives with one hand and takes with the other --")
	var ice := run_with([&"thin_ice"])
	var ib := battle_for(ice, 6)
	check("two hours more a turn", ib.turn_budget, 300)
	hit(ib)
	check("and half the time back out of the kill", ice.clock.restored, 60)

	print("\n-- relics hold no state, so the same object serves every run --")
	var first := run_with([&"stopped_watch"])
	var fb := battle_for(first)
	hit(fb)
	hit(fb)
	var second := run_with([&"stopped_watch"])
	var sb := battle_for(second)
	hit(sb)
	check("a later run starts clean", sb.turn_budget, 180)

	print("\n-- modifiers chain in acquisition order --")
	var both := run_with([&"broken_mainspring", &"worn_shoes"])
	check("both attached", both.relics.size(), 2)
	check("budget relic applied", battle_for(both).turn_budget, 240)
	var walked := both.clock.remaining
	both.enter_room(&"b")
	check("walk relic applied too", walked - both.clock.remaining, 0)

	print("\n-- duplicates are refused --")
	var dupe := run_with([&"gleaning"])
	dupe.add_relic(&"gleaning", _relics)
	check("still one", dupe.relics.size(), 1)
	check("and one definition", dupe.relic_defs().size(), 1)

	print("\n-- an unknown id is ignored rather than crashing a run --")
	var bogus := run_with([])
	bogus.add_relic(&"no_such_relic", _relics)
	check("id recorded", bogus.relics.size(), 1)
	check("no definition attached", bogus.relic_defs().size(), 0)
	check("and the run still works", battle_for(bogus).turn_budget, 180)

	print("\n-- relics survive a save and reattach --")
	var saved := run_with([&"broken_mainspring", &"gleaning"])
	var back := RunState.from_dict(saved.to_dict(), _b)
	check("ids carried", Array(back.relics), [&"broken_mainspring", &"gleaning"])
	check("definitions need reattaching", back.relic_defs().size(), 0)
	back.attach_relics(_relics)
	check("now they are back", back.relic_defs().size(), 2)
	check("and working", battle_for(back).turn_budget, 240)
	check("in the same order", back.relic_defs().map(func(r: Relic) -> String: return String(r.id)),
		["broken_mainspring", "gleaning"])

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
