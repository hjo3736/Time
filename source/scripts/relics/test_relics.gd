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


func run_with(relic_ids: Array, cards_in_deck: int = 8) -> RunState:
	var run := RunState.new(_b, 1)
	for i in cards_in_deck:
		run.add_card(&"interrupt")
	for id in relic_ids:
		run.add_relic(id, _relics)
	return run


func dummy(hp: int) -> Combatant:
	var c := Combatant.new()
	c.max_hp = hp
	c.hp = hp
	c.restored_value = 100
	c.intents = [EnemyIntent.wait()] as Array[EnemyIntent]
	return c


func battle_for(run: RunState, hp: int = 99) -> BattleState:
	return BattleState.new(run, _cards, [dummy(hp)] as Array[Combatant], rng(3))


func hit(bt: BattleState) -> bool:
	for i in bt.piles().hand.size():
		if bt.card_at(i).id == &"interrupt":
			return bt.play_card(i, 1)
	return false


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()

	print("\n-- the roster loads and passes its own linter --")
	check("problems", _relics.validate(), PackedStringArray())
	check("four relics", _relics.size(), 4)
	check("sorted", _relics.all().map(func(r: Relic) -> String: return String(r.id)),
		["broken_mainspring", "gleaning", "stopped_watch", "worn_shoes"])
	for r in _relics.all():
		check("%s reads" % r.id, r.description() != "", true)

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
