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


func enemy(hp: int, intents: Array[EnemyIntent], behavior: EnemyBehavior = null) -> Combatant:
	var c := Combatant.new()
	c.max_hp = hp
	c.hp = hp
	c.restored_value = 360
	c.intents = intents
	c.behavior = behavior
	return c


func strikes(n: int = 10) -> RunState:
	var run := RunState.new(_b, 1)
	for i in n:
		run.add_card(&"interrupt")
	return run


func battle(run: RunState, enemies: Array[Combatant]) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return BattleState.new(run, _cards, enemies, rng)


func hit(bt: BattleState, target: int) -> bool:
	for i in bt.piles().hand.size():
		if bt.card_at(i).id == &"interrupt":
			return bt.play_card(i, target)
	return false


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()

	print("\n-- 되풀이: damage does nothing outside the break window --")
	var open := EnemyIntent.attack(4)
	open.is_break_window = true
	var loop_intents: Array[EnemyIntent] = [EnemyIntent.attack(4), EnemyIntent.block(3), open]
	var looper := enemy(40, loop_intents, BehaviorLooper.new())
	var lb := battle(strikes(), [looper])
	hit(lb, 1)
	check("shrugged it off", looper.hp, 40)
	lb.end_turn()
	hit(lb, 1)
	check("still nothing", looper.hp, 40)
	lb.end_turn()
	check("window is telegraphed", looper.current_intent().is_break_window, true)
	check("block it raised is still standing", looper.block, 3)
	hit(lb, 1)
	check("6 lands, 3 absorbed", looper.hp, 37)

	print("\n-- 역행: wounds un-happen unless it dies inside the turn --")
	var rev := enemy(30, [EnemyIntent.attack(3), EnemyIntent.block(2)] as Array[EnemyIntent], BehaviorReversed.new())
	var rb := battle(strikes(), [rev])
	hit(rb, 1)
	hit(rb, 1)
	check("hurt for now", rev.hp, 18)
	rb.end_turn()
	check("it all came back", rev.hp, 30)
	check("cycle ran backwards", rev.intent_index, -1)
	check("and still reads a real intent", rb.combatants[1].current_intent() != null, true)

	print("\n-- 역행: killing it inside one turn sticks --")
	var doomed := enemy(12, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorReversed.new())
	var db := battle(strikes(), [doomed])
	hit(db, 1)
	hit(db, 1)
	check("dead before the rewind", doomed.hp, 0)
	check("victory", db.phase, BattleState.Phase.VICTORY)

	print("\n-- 정지: every turn it waits makes the blow worse --")
	var stilled_behavior := BehaviorStilled.new()
	stilled_behavior.growth = 4
	var stilled := enemy(99, [EnemyIntent.wait(), EnemyIntent.wait(), EnemyIntent.attack(10)] as Array[EnemyIntent], stilled_behavior)
	var sb := battle(strikes(), [stilled])
	sb.end_turn()
	check("no damage on the first wait", sb.warden().hp, 70)
	check("charge 1", stilled_behavior.charge(), 1)
	sb.end_turn()
	check("charge 2", stilled_behavior.charge(), 2)
	sb.end_turn()
	check("10 became 18", sb.warden().hp, 70 - 18)
	check("charge reset after acting", stilled_behavior.charge(), 0)

	print("\n-- 노화: it opens hard and falls apart --")
	var withered_behavior := BehaviorWithered.new()
	withered_behavior.decay = 5
	var withered := enemy(99, [EnemyIntent.attack(20)] as Array[EnemyIntent], withered_behavior)
	var wb := battle(strikes(), [withered])
	wb.end_turn()
	check("first exchange hurts", wb.warden().hp, 50)
	wb.end_turn()
	check("weaker", wb.warden().hp, 50 - 15)
	wb.end_turn()
	check("weaker still", wb.warden().hp, 35 - 10)

	print("\n-- 겹침: damage lands on the twin, one turn late --")
	var a := enemy(30, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorOverlaid.new())
	var b := enemy(30, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorOverlaid.new())
	a.link = 2
	b.link = 1
	var ob := battle(strikes(), [a, b])
	hit(ob, 1)
	check("the one hit is untouched", a.hp, 30)
	check("so is the twin, for now", b.hp, 30)
	check("queued on the twin", (b.behavior as BehaviorOverlaid).pending(), 6)
	ob.end_turn()
	check("it lands on the twin", b.hp, 24)
	check("and the one hit stays whole", a.hp, 30)

	print("\n-- 겹침: a broken link makes it dull, never unkillable --")
	var lone := enemy(20, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorOverlaid.new())
	lone.link = -1
	var lb2 := battle(strikes(), [lone])
	hit(lb2, 1)
	check("takes damage normally", lone.hp, 14)

	print("\n-- behaviours are per-combatant, not shared --")
	var w1 := BehaviorWithered.new()
	var w2 := BehaviorWithered.new()
	var e1 := enemy(99, [EnemyIntent.attack(20)] as Array[EnemyIntent], w1)
	var e2 := enemy(99, [EnemyIntent.attack(20)] as Array[EnemyIntent], w2)
	var pb := battle(strikes(), [e1, e2])
	pb.end_turn()
	pb.end_turn()
	check("each ages on its own clock", [w1.turns_elapsed(), w2.turns_elapsed()], [2, 2])

	print("\n-- a plain enemy still works with no behaviour at all --")
	var plain := enemy(20, [EnemyIntent.attack(5)] as Array[EnemyIntent])
	var nb := battle(strikes(), [plain])
	hit(nb, 1)
	check("takes damage", plain.hp, 14)
	nb.end_turn()
	check("hits back", nb.warden().hp, 65)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
