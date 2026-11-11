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


func dummy(hp: int, intents: Array[EnemyIntent], restored: int = 360) -> Stats:
	var c := Stats.new()
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


func battle(run: RunState, enemies: Array[Stats], seed_value: int = 7) -> BattleState:
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
	check("block gained", guard.warden().block, 5)
	guard.end_turn()
	check("only 3 got through", guard.warden().hp, _b.starting_max_hp - 3)
	check("block cleared for the new turn", guard.warden().block, 0)

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
	check("two hours were left, so twelve block", spare.warden().block, 12)
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
	doomed_run.damage(_b.starting_max_hp - 5)
	var doomed := battle(doomed_run, [dummy(50, [EnemyIntent.attack(20)])])
	check("carried hp in", doomed.warden().hp, 5)
	doomed.end_turn()
	check("defeat", doomed.phase, BattleState.Phase.DEFEAT)
	check("hp written back to the run", doomed_run.hp, 0)
	check("run agrees", doomed_run.is_defeated(), true)

	print("\n-- damage taken in a fight is written back on victory --")
	var hurt_run := run_with_deck([&"take", &"take", &"take", &"take", &"take"])
	var hurt := battle(hurt_run, [dummy(60, [EnemyIntent.attack(9)])])
	hurt.end_turn()
	check("still fighting", hurt.phase, BattleState.Phase.PLAYER_TURN)
	check("run hp untouched mid-fight", hurt_run.hp, _b.starting_max_hp)
	while hurt.combatants[1].is_alive() and hurt.turn < 30:
		var idx := hand_index_of(hurt, &"take")
		if idx < 0 or not hurt.play_card(idx, 1):
			hurt.end_turn()
	check("won", hurt.phase, BattleState.Phase.VICTORY)
	check("run hp now reflects the fight", hurt_run.hp < _b.starting_max_hp, true)

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

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
