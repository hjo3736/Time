extends SceneTree


var _failures := 0
var _b: Balance
var _cards: CardDatabase


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func dummy(hp: int, intents: Array[EnemyIntent], restored: int = 360) -> EnemyStats:
	var c := EnemyStats.new()
	c.max_hp = hp
	c.hp = hp
	c.restored_value = restored
	c.intents = intents
	return c


func run_with_deck(ids: Array) -> RunState:
	var run := RunState.new(_b, 1)
	for id in ids:
		run.add_card(id)
	return run


func battle(run: RunState, enemies: Array[EnemyStats], seed_value: int = 7) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return BattleState.new(run, _cards, enemies, rng)


func hand_index_of(bt: BattleState, id: StringName) -> int:
	for i in bt.piles().hand.size():
		if bt.card_at(i).id == id:
			return i
	return -1


func _init() -> void:
	# The pool is being rebuilt and holds almost nothing; the machinery under test
	# is exercised with the shelved cards as well. See CardDatabase.SHELF_ROOT.
	CardDatabase.fixture_roots = PackedStringArray(CardDatabase.TEST_ROOTS)
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()

	print("\n-- a fight opens with a hand and a full budget --")
	var run := run_with_deck([&"take", &"take", &"brace", &"brace", &"take", &"brace"])
	var bt := battle(run, [dummy(30, [EnemyIntent.attack(5)])])
	check("turn", bt.turn, 1)
	check("phase", bt.phase, BattleState.Phase.PLAYER_TURN)
	check("hand", bt.piles().hand.size(), 5)
	check("draw pile", bt.piles().draw.size(), 1)
	check("budget is the turn allotment", bt.turn_budget, 180)

	print("\n-- playing a card spends the budget and moves the card --")
	var i := hand_index_of(bt, &"take")
	check("played", bt.play_card(i, 1), true)
	check("budget", bt.turn_budget, 120)
	check("hand shrank", bt.piles().hand.size(), 4)
	check("discarded", bt.piles().discard.size(), 1)
	check("enemy took 6", bt.combatants[1].hp, 24)

	print("\n-- the budget is a hard stop --")
	# 끊어내기 for the two-hour card: it is in the starting deck, so it is the one
	# whose cost is least likely to be retuned out from under this.
	var poor := battle(run_with_deck([&"sever", &"sever", &"sever"]), [dummy(60, [EnemyIntent.wait()])])
	check("first 2h play", poor.play_card(hand_index_of(poor, &"sever"), 1), true)
	check("budget left", poor.turn_budget, 60)
	check("second 2h play refused", poor.play_card(hand_index_of(poor, &"sever"), 1), false)
	check("nothing spent on the refusal", poor.turn_budget, 60)

	print("\n-- unspent time is lost, and the hour passes either way --")
	var thrifty := battle(run_with_deck([&"brace", &"brace", &"brace"]), [dummy(50, [EnemyIntent.wait()])])
	var before := thrifty._run.clock.remaining
	thrifty.end_turn()
	check("charged the full allotment", before - thrifty._run.clock.remaining, 180)
	check("hand was discarded", thrifty.piles().hand.size(), 3)
	check("new turn", thrifty.turn, 2)
	check("budget refilled", thrifty.turn_budget, 180)

	print("\n-- block absorbs, then expires at the start of the next turn --")
	var guard := battle(run_with_deck([&"brace", &"brace", &"brace", &"brace", &"brace"]),
		[dummy(50, [EnemyIntent.attack(8)])])
	guard.play_card(hand_index_of(guard, &"brace"))
	check("block gained", guard.player().block, 5)
	guard.end_turn()
	check("only 3 got through", guard.player().hp, _start_hp() - 3)
	check("block cleared for the new turn", guard.player().block, 0)

	print("\n-- softened is applied in one place and multiplies once --")
	var vuln := battle(run_with_deck([&"soften", &"take", &"take", &"take", &"take"]),
		[dummy(40, [EnemyIntent.wait()])])
	vuln.play_card(hand_index_of(vuln, &"soften"), 1)
	check("stacks", vuln.combatants[1].status(StatusRules.SOFTENED), 2)
	vuln.play_card(hand_index_of(vuln, &"take"), 1)
	check("6 became 9", vuln.combatants[1].hp, 31)

	print("\n-- exhaust leaves the fight, discard does not --")
	var ex := battle(run_with_deck([&"fixture_refund", &"brace", &"brace", &"brace", &"brace"]),
		[dummy(50, [EnemyIntent.wait()])])
	var hb := hand_index_of(ex, &"fixture_refund")
	var budget_before := ex.turn_budget
	ex.play_card(hb)
	check("exhausted", ex.piles().exhausted.size(), 1)
	check("not discarded", ex.piles().discard.size(), 0)
	check("net +1h after paying 1h", ex.turn_budget - budget_before, 60)

	print("\n-- time a card adds is borrowed from the run, and billed whether it is spent or not --")
	check("two hours were borrowed", ex.borrowed_this_turn, 120)
	check("and the turn is five hours from the moment the card is played", ex.turn_cost_now(), 300)
	ex.play_card(hand_index_of(ex, &"brace"))
	ex.play_card(hand_index_of(ex, &"brace"))
	ex.play_card(hand_index_of(ex, &"brace"))
	ex.play_card(hand_index_of(ex, &"brace"))
	check("spending them changes nothing about what the turn costs",
		[ex.turn_budget, ex.turn_cost_now()], [0, 300])
	var clock_before := ex._run.clock.elapsed
	ex.end_turn()
	check("ending the turn bills all five to the run", ex._run.clock.elapsed - clock_before, 300)
	check("and the next turn has borrowed nothing", [ex.borrowed_this_turn, ex.turn_cost_now()],
		[0, 180])

	var frugal := battle(run_with_deck([&"fixture_refund", &"brace", &"brace", &"brace", &"brace"]),
		[dummy(50, [EnemyIntent.wait()])])
	frugal.play_card(hand_index_of(frugal, &"fixture_refund"))
	var frugal_clock := frugal._run.clock.elapsed
	frugal.end_turn()
	check("borrowed and left unspent, it is five hours all the same",
		frugal._run.clock.elapsed - frugal_clock, 300)

	print("\n-- an X card that guards spends what is left and blocks by the hour --")
	var spare := battle(run_with_deck([&"leave_nothing", &"take", &"take", &"take", &"take"]),
		[dummy(50, [EnemyIntent.wait()])])
	spare.play_card(hand_index_of(spare, &"take"), 1)
	spare.play_card(hand_index_of(spare, &"leave_nothing"))
	check("two hours were left, so twelve block", spare.player().block, 12)
	check("and nothing is left of the turn", spare.turn_budget, 0)

	print("\n-- killing the last enemy ends it and pays Restored --")
	var kill := battle(run_with_deck([&"take", &"take", &"take", &"take", &"take"]),
		[dummy(6, [EnemyIntent.wait()], 420)])
	check("restored starts empty", kill._run.clock.restored, 0)
	kill.play_card(hand_index_of(kill, &"take"), 1)
	check("victory", kill.phase, BattleState.Phase.VICTORY)
	check("paid from the enemy, not the blow", kill._run.clock.restored, 420)

	print("\n-- overkill pays exactly the same --")
	var over := battle(run_with_deck([&"take", &"take", &"take", &"take", &"take"]),
		[dummy(1, [EnemyIntent.wait()], 420)])
	over.play_card(hand_index_of(over, &"take"), 1)
	check("same payout", over._run.clock.restored, 420)

	print("\n-- the Warden falling ends the fight and reaches the run --")
	var doomed_run := run_with_deck([&"brace", &"brace", &"brace", &"brace", &"brace"])
	doomed_run.damage(_start_hp() - 5)
	var doomed := battle(doomed_run, [dummy(50, [EnemyIntent.attack(20)])])
	check("carried hp in", doomed.player().hp, 5)
	doomed.end_turn()
	check("defeat", doomed.phase, BattleState.Phase.DEFEAT)
	check("hp written back to the run", doomed_run.hp, 0)
	check("run agrees", doomed_run.is_defeated(), true)

	print("\n-- damage taken in a fight is written back on victory --")
	var hurt_run := run_with_deck([&"take", &"take", &"take", &"take", &"take"])
	var hurt := battle(hurt_run, [dummy(60, [EnemyIntent.attack(9)])])
	hurt.end_turn()
	check("still fighting", hurt.phase, BattleState.Phase.PLAYER_TURN)
	check("run hp untouched mid-fight", hurt_run.hp, _start_hp())
	while hurt.combatants[1].is_alive() and hurt.turn < 30:
		var idx := hand_index_of(hurt, &"take")
		if idx < 0 or not hurt.play_card(idx, 1):
			hurt.end_turn()
	check("won", hurt.phase, BattleState.Phase.VICTORY)
	check("run hp now reflects the fight", hurt_run.hp < _start_hp(), true)

	print("\n-- running out of time mid-fight ends the run --")
	var last_run := RunState.new(_b, 1)
	last_run.clock.advance(_b.starting_remaining - 60, RunClock.Source.TRAVEL)
	for id in [&"brace", &"brace", &"brace", &"brace", &"brace"]:
		last_run.add_card(id)
	var last := battle(last_run, [dummy(99, [EnemyIntent.wait()])])
	check("an hour left", last._run.clock.remaining, 60)
	last.end_turn()
	check("the turn cost three", last._run.clock.remaining, 0)
	check("defeat, with the enemy untouched", last.phase, BattleState.Phase.DEFEAT)

	print("\n-- the draw pile reshuffles from the discard --")
	var cycle := battle(run_with_deck([&"brace", &"brace", &"brace", &"brace", &"brace", &"brace"]),
		[dummy(99, [EnemyIntent.wait()])])
	check("one left undrawn", cycle.piles().draw.size(), 1)
	cycle.end_turn()
	check("hand refilled past the pile", cycle.piles().hand.size(), 5)
	check("discard was recycled", cycle.piles().draw.size() + cycle.piles().hand.size(), 6)

	print("\n-- the same seed deals the same fight --")
	var seen := []
	for attempt in 2:
		var r := run_with_deck([&"take", &"brace", &"disperse", &"soften", &"scatter", &"fixture_refund"])
		var bs := battle(r, [dummy(99, [EnemyIntent.wait()])], 99)
		seen.append(bs.piles().hand.map(func(x: int) -> String: return String(bs.card_at(bs.piles().hand.find(x)).id)))
	check("identical openings", seen[0], seen[1])

	_stats_hold_their_bounds()
	_stats_say_when_they_change()
	_stats_survive_a_save()
	_stats_instances_do_not_share()
	_spawned_askew_leave_the_template_alone()
	_the_warden_comes_from_its_character()

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _stats_hold_their_bounds() -> void:
	print("\n-- stats: hp stays between 0 and max, block under its cap --")
	var s := Stats.new()
	s.max_hp = 30
	s.hp = 50
	check("hp above max is held at max", s.hp, 30)
	s.hp = -5
	check("hp below zero is held at zero", s.hp, 0)
	s.block = 1200
	check("block is capped", s.block, 999)

	print("\n-- stats: take_damage spends block first and reports what got through --")
	var t := Stats.new()
	t.max_hp = 30
	t.hp = 30
	t.block = 5
	check("three of eight get past five block", t.take_damage(8), 3)
	check("and land on hp", [t.hp, t.block], [27, 0])
	check("nothing offered, nothing through", t.take_damage(0), 0)


func _stats_say_when_they_change() -> void:
	print("\n-- stats: changes are announced --")
	var s := Stats.new()
	s.max_hp = 30
	var heard := [0]
	s.stats_changed.connect(func() -> void: heard[0] += 1)
	s.hp = 10
	check("an hp change is heard", heard[0], 1)
	s.add_status(StatusRules.STRENGTH, 0)
	check("a status change of nothing is not", heard[0], 1)
	s.add_status(StatusRules.STRENGTH, 2)
	check("a real status change is", heard[0], 2)

	var e := EnemyStats.new()
	e.intents = [EnemyIntent.attack(3), EnemyIntent.block(2)] as Array[EnemyIntent]
	var turned := [0]
	e.intent_changed.connect(func() -> void: turned[0] += 1)
	e.advance_intent()
	check("advancing the intent is heard once", turned[0], 1)
	e.intent_index = 0
	check("so is a behaviour setting it directly", turned[0], 2)


func _stats_survive_a_save() -> void:
	print("\n-- stats: a save and a load give the same fighter back --")
	var saved := EnemyStats.new()
	saved.name_key = &"askew.test"
	saved.max_hp = 80
	saved.hp = 34
	saved.block = 5
	saved.link = 2
	saved.restored_value = 120
	saved.intents = [EnemyIntent.attack(6), EnemyIntent.block(4)] as Array[EnemyIntent]
	saved.intent_index = 1
	saved.add_status(StatusRules.STRENGTH, 2)

	var written := saved.to_dict()
	check("no art, no art entry", written.has("art"), false)
	# Through JSON, as the save file is, so numbers come back as floats.
	var loaded := Stats.from_dict(JSON.parse_string(JSON.stringify(written)))
	check("an Askew comes back as an Askew", loaded is EnemyStats, true)
	var back := loaded as EnemyStats
	check("hp is not cut down to the default max on load", [back.hp, back.max_hp], [34, 80])
	check("block, link and worth come back", [back.block, back.link, back.restored_value], [5, 2, 120])
	check("the intents come back", back.intents.size(), 2)
	check("on the one it was showing", back.current_intent().kind, EnemyIntent.Kind.BLOCK)
	check("statuses come back", back.status(StatusRules.STRENGTH), 2)

	var plain := Stats.from_dict(JSON.parse_string(JSON.stringify(Stats.new().to_dict())))
	check("and the Warden as plain Stats", plain is EnemyStats, false)

	var pictured := Stats.new()
	pictured.art = load("res://icon.svg") as Texture2D
	var pictured_back := Stats.from_dict(JSON.parse_string(JSON.stringify(pictured.to_dict())))
	check("art comes back by its path", pictured_back.art != null
		and pictured_back.art.resource_path == "res://icon.svg", true)


func _stats_instances_do_not_share() -> void:
	print("\n-- stats: each instance is its own --")
	var template := Stats.new()
	template.max_hp = 40
	template.hp = 1
	var a := template.create_instance()
	var b := template.create_instance()
	# Starting block is an Askew's alone now; see the spawn test below.
	check("an instance opens at full hp with no block", [a.hp, a.block], [40, 0])
	a.take_damage(20)
	check("striking one leaves the other whole", b.hp, 40)
	check("and the template untouched", [template.hp, template.block], [1, 0])


func _spawned_askew_leave_the_template_alone() -> void:
	print("\n-- an Askew .tres is a template: spawn makes fighters from it --")
	var template := EnemyStats.new()
	template.id = &"fixture_template"
	template.hp_min = 20
	template.hp_max = 26
	template.start_block = 4
	template.intents = [EnemyIntent.attack(5), EnemyIntent.block(3)] as Array[EnemyIntent]
	template.behavior_script = BehaviorEcho
	var dice := RandomNumberGenerator.new()
	dice.seed = 11
	var a := template.spawn(_b, dice)
	var b := template.spawn(_b, dice)
	check("hp is rolled inside the range", a.max_hp >= 20 and a.max_hp <= 26 and a.hp == a.max_hp, true)
	check("it opens with the template's block", a.block, 4)
	check("each fighter gets its own behaviour", [a.behavior is BehaviorEcho, a.behavior != b.behavior], [true, true])
	check("and the template none", template.behavior, null)
	a.intents.clear()
	check("emptying one fighter's intents leaves the template's", template.intents.size(), 2)
	check("and the other fighter's", b.intents.size(), 2)
	a.take_damage(10)
	check("striking a fighter leaves the template whole", [template.hp, template.block], [1, 0])


## What a run opens on: the max hp of the character it is played as.
func _start_hp() -> int:
	return RunState.new(_b).player.max_hp


func _the_warden_comes_from_its_character() -> void:
	print("\n-- the Warden is built from warden.tres and the run it is in --")
	var run := run_with_deck([&"take", &"take", &"brace", &"brace", &"take", &"brace"])
	var warden_def := run.player
	check("the run is played as the Warden", warden_def.id, &"warden")
	check("its card class is set", warden_def.class_id, &"warden")
	check("it opens with a deck", warden_def.starting_deck.is_empty(), false)
	check("and no empty slot in it", warden_def.starting_deck.has(null), false)
	check("the run opens on the character's max hp", [run.hp, run.max_hp],
		[warden_def.max_hp, warden_def.max_hp])

	run.damage(30)
	var bt := battle(run, [dummy(30, [EnemyIntent.wait()])])
	check("in a fight the Warden is a PlayerStats", bt.player() is PlayerStats, true)
	check("carrying the run's hp, not a fresh one", [bt.player().hp, bt.player().max_hp],
		[run.hp, run.max_hp])
	check("and the definition is left alone", warden_def.hp, 1)

	var back := BattleState.from_dict(JSON.parse_string(JSON.stringify(bt.to_dict())), run, _cards)
	check("a saved fight brings the Warden back as a PlayerStats", back.player() is PlayerStats, true)
	check("still knowing which character it is", (back.player() as PlayerStats).id, &"warden")
	check("with its hp", back.player().hp, run.hp)
