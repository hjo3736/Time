extends SceneTree


var _failures := 0
var _b: Balance
var _db: EnemyDatabase


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func rng(seed_value: int = 5) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_db = EnemyDatabase.new()
	_db.load_from()

	print("\n-- the roster loads and passes its own linter --")
	check("problems", _db.validate(), PackedStringArray())
	check("a real roster", _db.size() >= 10, true)
	var order := _db.all().map(func(e: EnemyData) -> String: return String(e.id))
	var sorted_order := order.duplicate()
	sorted_order.sort()
	check("sorted by id", order, sorted_order)
	check("normals", _db.of_tier(EnemyData.Tier.NORMAL).size() >= 6, true)
	check("elites", _db.of_tier(EnemyData.Tier.ELITE).size() >= 2, true)
	check("a boss", _db.of_tier(EnemyData.Tier.BOSS).size() >= 1, true)

	var behaviours := {}
	for e in _db.all():
		if e.behavior_script != null:
			behaviours[e.behavior_script.get_global_name()] = true
	for wanted in ["BehaviorLooper", "BehaviorReversed", "BehaviorStilled",
			"BehaviorOverlaid", "BehaviorWithered"]:
		check("%s is met somewhere" % wanted, behaviours.has(wanted), true)

	print("\n-- hp rolls inside the authored range, and replays --")
	var data := _db.get_enemy(&"afterimage")
	var rolls := []
	for i in 12:
		var c := data.spawn(_b, rng(i))
		rolls.append(c.max_hp)
		if c.max_hp < data.hp_min or c.max_hp > data.hp_max:
			_failures += 1
			print("  FAIL  hp %d outside %d-%d" % [c.max_hp, data.hp_min, data.hp_max])
	check("twelve rolls all in range", true, true)
	check("same seed, same roll", data.spawn(_b, rng(3)).max_hp, data.spawn(_b, rng(3)).max_hp)

	print("\n-- Restored is derived from hp, never authored --")
	var one := data.spawn(_b, rng(1))
	check("derived", one.restored_value, one.max_hp * _b.restored_minutes_per_hp)

	print("\n-- two of a kind do not share a behaviour --")
	var crumbling := _db.get_enemy(&"crumbling")
	var a := crumbling.spawn(_b, rng(1))
	var b := crumbling.spawn(_b, rng(2))
	check("both got one", [a.behavior != null, b.behavior != null], [true, true])
	check("not the same object", a.behavior == b.behavior, false)
	(a.behavior as BehaviorWithered).on_turn_end(null, 0)
	check("ageing one does not age the other",
		[(a.behavior as BehaviorWithered).turns_elapsed(), (b.behavior as BehaviorWithered).turns_elapsed()],
		[1, 0])

	print("\n-- intents are copied, so a fight cannot rewrite the definition --")
	var p1 := _db.get_enemy(&"pacing").spawn(_b, rng(1))
	p1.intents.clear()
	check("definition intact", _db.get_enemy(&"pacing").intents.size(), 3)

	print("\n-- 잔상 fights as authored --")
	var cards := CardDatabase.new()
	cards.load_from()
	var run := RunState.new(_b, 1)
	for i in 10:
		run.add_card(&"brace")
	var ghost := data.spawn(_b, rng(1))
	var bt := BattleState.new(run, cards, [ghost] as Array[Combatant], rng(1))
	bt.end_turn()
	check("first hit", bt.warden().hp, 70 - 5)
	bt.end_turn()
	check("second hit", bt.warden().hp, 65 - 5)
	bt.end_turn()
	check("then the big one", bt.warden().hp, 60 - 9)
	bt.end_turn()
	check("and the cycle comes round", bt.warden().hp, 51 - 5)

	print("\n-- 바스러지는 것 opens hard and falls apart --")
	var run2 := RunState.new(_b, 1)
	for i in 10:
		run2.add_card(&"brace")
	var crumb := crumbling.spawn(_b, rng(1))
	var bt2 := BattleState.new(run2, cards, [crumb] as Array[Combatant], rng(1))
	bt2.end_turn()
	check("opening blow", bt2.warden().hp, 70 - 14)
	bt2.end_turn()
	check("already weaker", bt2.warden().hp, 56 - 9)
	bt2.end_turn()
	check("weaker again", bt2.warden().hp, 47 - 4)
	bt2.end_turn()
	check("harmless by now", bt2.warden().hp, 43)

	print("\n-- killing one pays its own size --")
	var run3 := RunState.new(_b, 1)
	for i in 10:
		run3.add_card(&"interrupt")
	var victim := data.spawn(_b, rng(1))
	var bt3 := BattleState.new(run3, cards, [victim] as Array[Combatant], rng(1))
	while not bt3.is_over() and bt3.turn < 40:
		var played := false
		for i in bt3.piles().hand.size():
			if bt3.card_at(i).id == &"interrupt" and bt3.play_card(i, 1):
				played = true
				break
		if not played:
			bt3.end_turn()
	check("victory", bt3.phase, BattleState.Phase.VICTORY)
	check("paid its derived value, to the nearest hour", run3.clock.restored,
		_hours(victim.max_hp * _b.restored_minutes_per_hp))

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _hours(minutes: int) -> int:
	return maxi(60, roundi(float(minutes) / 60.0) * 60)
