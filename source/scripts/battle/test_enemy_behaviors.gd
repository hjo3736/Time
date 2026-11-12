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


func enemy(hp: int, intents: Array[EnemyIntent], behavior: EnemyBehavior = null) -> EnemyStats:
	var c := EnemyStats.new()
	c.max_hp = hp
	c.hp = hp
	c.restored_value = 360
	c.intents = intents
	c.behavior = behavior
	return c


func strikes(n: int = 10) -> RunState:
	var run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
	for i in n:
		run.add_card(&"take")
	return run


func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func battle(run: RunState, enemies: Array[EnemyStats]) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return BattleState.new(run, _cards, enemies, rng)


func hit(bt: BattleState, target: int) -> bool:
	for i in bt.piles().hand.size():
		if bt.card_at(i).id == &"take":
			return bt.play_card(i, target)
	return false


func _init() -> void:
	# The pool is being rebuilt and holds almost nothing; the machinery under test
	# is exercised with the shelved cards as well. See CardDatabase.SHELF_ROOT.
	CardDatabase.fixture_roots = PackedStringArray(CardDatabase.TEST_ROOTS)
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
	check("no damage on the first wait", sb.warden().hp, _b.starting_max_hp)
	check("charge 1", stilled_behavior.charge(), 1)
	sb.end_turn()
	check("charge 2", stilled_behavior.charge(), 2)
	sb.end_turn()
	check("10 became 18", sb.warden().hp, _b.starting_max_hp - 18)
	check("charge reset after acting", stilled_behavior.charge(), 0)

	print("\n-- 노화: it opens hard and falls apart --")
	var withered_behavior := BehaviorWithered.new()
	withered_behavior.decay = 5
	var withered := enemy(99, [EnemyIntent.attack(20)] as Array[EnemyIntent], withered_behavior)
	var wb := battle(strikes(), [withered])
	wb.end_turn()
	check("first exchange hurts", wb.warden().hp, _b.starting_max_hp - 20)
	wb.end_turn()
	check("weaker", wb.warden().hp, _b.starting_max_hp - 35)
	wb.end_turn()
	check("weaker still", wb.warden().hp, _b.starting_max_hp - 45)

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
	check("hits back", nb.warden().hp, _b.starting_max_hp - 5)

	print("\n-- 힘 is flat, permanent, and blunted along with the blow --")
	var strong := enemy(20, [EnemyIntent.attack(5)] as Array[EnemyIntent])
	var strong_bt := battle(strikes(), [strong])
	check("no strength, no change",
		StatusRules.modified_damage(strong, strong_bt.warden(), 5), 5)
	strong.add_status(StatusRules.STRENGTH, 2)
	check("two strength adds two", StatusRules.modified_damage(strong, strong_bt.warden(), 5), 7)
	strong.add_status(StatusRules.BLUNTED, 1)
	check("무뎌짐 blunts the strength too, not only the blow",
		StatusRules.modified_damage(strong, strong_bt.warden(), 5), 5)
	strong.add_status(StatusRules.BLUNTED, -1)
	StatusRules.tick_down(strong)
	check("and 힘 does not wear off with the durations",
		strong.status(StatusRules.STRENGTH), 2)

	print("\n-- 성장: it grows at twilight and keeps what it gained --")
	var lit := enemy(999, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorTwilit.new())
	# Departing at 05:00 opens the fight in the morning and walks it into day.
	var dawn := RunState.new(_b, RunClock.seed_from_date(1487, 3, 1, 5))
	for i in 10:
		dawn.add_card(&"brace")
	var twilit_bt := battle(dawn, [lit])
	var seen := []
	for turn in 6:
		var shown := StatusRules.modified_damage(lit, twilit_bt.warden(), lit.current_intent().amount)
		var before := twilit_bt.warden().hp
		twilit_bt.end_turn()
		seen.append([lit.sky, shown, before - twilit_bt.warden().hp])
	var strengths := seen.map(func(row: Array) -> int: return int(row[1]))
	check("the blow grows across the fight", strengths, [5, 6, 6, 6, 6, 7])
	var mismatched := 0
	for row in seen:
		if int(row[1]) != int(row[2]):
			mismatched += 1
	# The buff lands at turn end, so what the player read while planning is what
	# actually hit them. A turn where those two disagree is a broken promise.
	check("and every turn landed exactly what it showed", mismatched, 0)
	check("only two skies ever paid", lit.status(StatusRules.STRENGTH), 2)

	print("\n-- 가속: it bills the run, and no amount of blocking answers that --")
	var plain_run := strikes()
	var plain_bt := battle(plain_run, [enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent])])
	check("an ordinary turn costs the authored tick", plain_bt.turn_cost_now(), _b.turn_cost)
	plain_bt.end_turn()
	check("and that is what left the clock",
		_b.starting_remaining - plain_run.clock.remaining, _b.turn_cost)

	var lag_run := strikes()
	var dragger := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorQuickening.new())
	var lag_bt := battle(lag_run, [dragger])
	check("with it standing, the turn costs an hour more",
		lag_bt.turn_cost_now(), _b.turn_cost + 60)
	lag_bt.end_turn()
	check("and the run paid it", _b.starting_remaining - lag_run.clock.remaining, _b.turn_cost + 60)
	check("nothing was taken off the vessel", lag_bt.warden().hp, _b.starting_max_hp)

	var two_run := strikes()
	var two_bt := battle(two_run, [
		enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorQuickening.new()),
		enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorQuickening.new()),
	])
	check("two of them drag twice as hard", two_bt.turn_cost_now(), _b.turn_cost + 120)

	var freed_run := strikes()
	var doomed_dragger := enemy(6, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorQuickening.new())
	var freed_bt := battle(freed_run, [doomed_dragger])
	check("it drags while alive", freed_bt.turn_cost_now(), _b.turn_cost + 60)
	hit(freed_bt, 1)
	check("killed", doomed_dragger.is_alive(), false)
	# Billed on the living at the moment of billing, so the turn you end it is
	# already cheaper. Otherwise the last turn of the fight punishes the kill.
	check("and the turn that killed it costs the ordinary tick",
		freed_bt.turn_cost_now(), _b.turn_cost)

	print("\n-- 흘림: a blow that gets through spills an hour, and block holds it --")
	var bare_run := strikes()
	bare_run.clock.restore(10 * 60)
	var spiller := enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorSpilling.new())
	var bare_bt := battle(bare_run, [spiller])
	bare_bt.end_turn()
	check("an unblocked blow cost an hour of what was carried",
		bare_run.clock.restored, 9 * 60)

	var guarded_run := strikes()
	guarded_run.clock.restore(10 * 60)
	var guarded_bt := battle(guarded_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorSpilling.new())])
	guarded_bt.warden().block = 5
	guarded_bt.end_turn()
	check("a blow fully blocked spills nothing", guarded_run.clock.restored, 10 * 60)

	var flurry_run := strikes()
	flurry_run.clock.restore(10 * 60)
	var flurry_bt := battle(flurry_run, [enemy(99, [EnemyIntent.attack(4, 3)] as Array[EnemyIntent],
		BehaviorSpilling.new())])
	flurry_bt.warden().block = 8
	flurry_bt.end_turn()
	# Block soaks the first two of three 4s; only the third gets through.
	check("a flurry spills once per blow that got past the guard",
		flurry_run.clock.restored, 9 * 60)

	var empty_run := strikes()
	var empty_bt := battle(empty_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorSpilling.new())])
	empty_bt.end_turn()
	check("an empty pool has nothing to spill, and does not go negative",
		empty_run.clock.restored, 0)

	var swing_run := strikes()
	swing_run.clock.restore(10 * 60)
	var target := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorSpilling.new())
	var swing_bt := battle(swing_run, [target])
	hit(swing_bt, 1)
	check("the Warden hitting it spills nothing — only its blows do",
		swing_run.clock.restored, 10 * 60)

	print("\n-- 좀먹음: a blow that gets through is paid in what is carried, not in hp --")
	var carried_run := strikes()
	carried_run.clock.restore(10 * 60)
	var carried_bt := battle(carried_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorGnawing.new())])
	var hp_before := carried_bt.warden().hp
	carried_bt.end_turn()
	check("an unblocked 5 ate five hours of what was carried",
		carried_run.clock.restored, 5 * 60)
	check("and left the Warden alone", carried_bt.warden().hp, hp_before)

	var held_run := strikes()
	held_run.clock.restore(10 * 60)
	var held_bt := battle(held_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorGnawing.new())])
	held_bt.warden().block = 5
	held_bt.end_turn()
	check("a blow fully blocked eats nothing", held_run.clock.restored, 10 * 60)

	var short_run := strikes()
	short_run.clock.restore(10 * 60)
	var short_bt := battle(short_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorGnawing.new())])
	short_bt.warden().block = 3
	short_bt.end_turn()
	check("block two short costs two hours, not five", short_run.clock.restored, 8 * 60)

	var thin_run := strikes()
	thin_run.clock.restore(2 * 60)
	var thin_bt := battle(thin_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorGnawing.new())])
	var thin_hp := thin_bt.warden().hp
	thin_bt.end_turn()
	check("a thin pool is emptied", thin_run.clock.restored, 0)
	check("and what it could not cover lands on hp", thin_bt.warden().hp, thin_hp - 3)

	var broke_run := strikes()
	var broke_bt := battle(broke_run, [enemy(99, [EnemyIntent.attack(5)] as Array[EnemyIntent],
		BehaviorGnawing.new())])
	var broke_hp := broke_bt.warden().hp
	broke_bt.end_turn()
	check("with nothing carried the blow lands on hp as written",
		broke_bt.warden().hp, broke_hp - 5)

	var kept_run := strikes()
	kept_run.clock.restore(10 * 60)
	var gnawer := enemy(6, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorGnawing.new())
	var kept_bt := battle(kept_run, [gnawer])
	kept_bt.end_turn()
	var after_bite := kept_run.clock.restored
	hit(kept_bt, 1)
	check("it fell", gnawer.is_alive(), false)
	check("and felling it paid its own gauge and nothing of what it took",
		kept_run.clock.restored, after_bite + gnawer.restored_value)

	print("\n-- 날 넘김: midnight puts it back as it began, and nothing else does --")
	var noon_run := strikes()
	var noon_foe := enemy(99, [EnemyIntent.attack(1), EnemyIntent.wait()] as Array[EnemyIntent],
		BehaviorDaybound.new())
	var noon_bt := battle(noon_run, [noon_foe])
	hit(noon_bt, 1)
	noon_bt.end_turn()
	check("a turn that stays inside the day leaves the wound", noon_foe.hp, 93)
	check("and the pattern moves on", noon_foe.intent_index, 1)

	var late_run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 21))
	for i in 10:
		late_run.add_card(&"take")
	var late_foe := enemy(99, [EnemyIntent.attack(1), EnemyIntent.wait()] as Array[EnemyIntent],
		BehaviorDaybound.new())
	var late_bt := battle(late_run, [late_foe])
	hit(late_bt, 1)
	late_foe.add_status(StatusRules.SOFTENED, 3)
	check("it was wounded before midnight", late_foe.hp, 93)
	late_bt.end_turn()
	check("the turn crossed midnight", late_run.clock.day_index(), 1)
	check("and it is whole again", late_foe.hp, 99)
	check("with nothing left on it", late_foe.status(StatusRules.SOFTENED), 0)
	check("but its pattern carries on from where it was", late_foe.intent_index, 1)
	hit(late_bt, 1)
	late_bt.end_turn()
	check("the day after, a wound stays a wound", late_foe.hp, 93)
	var woken := Stats.from_dict(late_foe.to_dict())
	check("and a resumed one remembers which day it is on",
		(woken.behavior as BehaviorDaybound).to_dict(), {"_day": 1})

	print("\n-- 성장 as an intent: the turn is spent on it and the Strength stays --")
	var grower := enemy(99, [EnemyIntent.grow(1), EnemyIntent.attack(4)] as Array[EnemyIntent])
	var grow_bt := battle(strikes(), [grower])
	var grow_hp := grow_bt.warden().hp
	grow_bt.end_turn()
	check("it gained the Strength", grower.status(StatusRules.STRENGTH), 1)
	check("and struck nobody that turn", grow_bt.warden().hp, grow_hp)
	grow_bt.end_turn()
	check("the next blow carries it", grow_bt.warden().hp, grow_hp - 5)
	check("and the intent survives a save",
		EnemyIntent.from_dict(EnemyIntent.grow(2).to_dict()).kind, EnemyIntent.Kind.GROW)

	print("\n-- 시소: the heavier end strikes, and the turn's damage picks the next one --")
	var near_end := enemy(40, [EnemyIntent.attack(13), EnemyIntent.block(10)] as Array[EnemyIntent],
		BehaviorSeesaw.new())
	var far_end := enemy(46, [EnemyIntent.attack(5), EnemyIntent.block(10)] as Array[EnemyIntent],
		BehaviorSeesaw.new())
	near_end.link = 2
	far_end.link = 1
	var saw_run := strikes()
	var saw_bt := battle(saw_run, [near_end, far_end])
	check("the heavier end opens striking", far_end.current_intent().kind, EnemyIntent.Kind.ATTACK)
	check("and the lighter one guarding", near_end.current_intent().kind, EnemyIntent.Kind.BLOCK)
	hit(saw_bt, 2)
	hit(saw_bt, 2)
	check("hit below the other, it still strikes this turn — what was read lands",
		[far_end.hp, far_end.current_intent().kind], [34, EnemyIntent.Kind.ATTACK])
	var saw_hp := saw_bt.warden().hp
	saw_bt.end_turn()
	check("it struck", saw_bt.warden().hp, saw_hp - 5)
	check("and the other guarded", near_end.block, 10)
	check("then the ends swap: the one that was hit now guards",
		[near_end.current_intent().kind, far_end.current_intent().kind],
		[EnemyIntent.Kind.ATTACK, EnemyIntent.Kind.BLOCK])
	near_end.hp = far_end.hp
	saw_bt.end_turn()
	check("level, both strike",
		[near_end.current_intent().kind, far_end.current_intent().kind],
		[EnemyIntent.Kind.ATTACK, EnemyIntent.Kind.ATTACK])
	far_end.hp = 0
	saw_bt.end_turn()
	check("and an end left alone only strikes", near_end.current_intent().kind,
		EnemyIntent.Kind.ATTACK)
	saw_bt.end_turn()
	check("turn after turn", near_end.current_intent().kind, EnemyIntent.Kind.ATTACK)

	print("\n-- 모래시계: the upper runs down into the lower, and its worth goes with it --")
	var upper := enemy(20, [EnemyIntent.attack(6)] as Array[EnemyIntent], BehaviorHourglass.new())
	var lower := enemy(14, [EnemyIntent.attack(4)] as Array[EnemyIntent], BehaviorHourglass.new())
	upper.link = 2
	lower.link = 1
	var glass_bt := battle(strikes(), [upper, lower])
	var glass_hp := glass_bt.warden().hp
	glass_bt.end_turn()
	check("both struck with what they were showing", glass_bt.warden().hp, glass_hp - 10)
	check("four ran out of the upper", upper.hp, 16)
	check("and into the lower, which is that much larger", [lower.hp, lower.max_hp], [18, 18])
	check("the lower grew for it", lower.status(StatusRules.STRENGTH), 1)
	check("and the time moved with the sand", [upper.restored_value, lower.restored_value],
		[288, 432])
	glass_hp = glass_bt.warden().hp
	glass_bt.end_turn()
	check("the growth is on the next blow, not the one already shown",
		glass_bt.warden().hp, glass_hp - 11)
	upper.hp = 3
	glass_bt.end_turn()
	check("the last of it runs out and the upper is gone", upper.is_alive(), false)
	check("having kept nothing", upper.restored_value, 0)
	check("all of it is below", [lower.hp, lower.restored_value], [25, 720])
	var grown := lower.status(StatusRules.STRENGTH)
	glass_bt.end_turn()
	check("with nothing above it, the lower stops growing",
		[lower.hp, lower.status(StatusRules.STRENGTH)], [25, grown])

	var top_only := enemy(20, [EnemyIntent.attack(6)] as Array[EnemyIntent], BehaviorHourglass.new())
	var gone := enemy(14, [EnemyIntent.attack(4)] as Array[EnemyIntent], BehaviorHourglass.new())
	top_only.link = 2
	gone.link = 1
	var top_bt := battle(strikes(), [top_only, gone])
	gone.hp = 0
	top_bt.end_turn()
	check("and with nothing below it, the upper keeps its sand", top_only.hp, 20)

	print("\n-- 메아리: what was done this turn comes back the next --")
	var echo := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorEcho.new())
	var echo_bt := battle(strikes(), [echo])
	check("it opens having heard nothing", echo.current_intent().kind, EnemyIntent.Kind.WAIT)
	hit(echo_bt, 1)
	hit(echo_bt, 1)
	hit(echo_bt, 1)
	check("while it is being struck, what it shows does not change",
		echo.current_intent().kind, EnemyIntent.Kind.WAIT)
	var echo_hp := echo_bt.warden().hp
	echo_bt.end_turn()
	check("and nothing comes back the same turn", echo_bt.warden().hp, echo_hp)
	check("18 taken is 12 shown, for the whole turn before it lands",
		[echo.current_intent().kind, echo.current_intent().amount],
		[EnemyIntent.Kind.ATTACK, 12])
	check("and it is the only thing it means to do", echo.behavior.extra_intents(echo_bt, 1), [])
	check("a resumed one is still showing it",
		Stats.from_dict(echo.to_dict()).current_intent().amount, 12)
	hit(echo_bt, 1)
	echo_bt.end_turn()
	check("the 12 landed", echo_bt.warden().hp, echo_hp - 12)
	check("and the 6 taken meanwhile is the next 4", echo.current_intent().amount, 4)
	echo_bt.end_turn()
	echo_bt.end_turn()
	check("left alone, it goes quiet", echo.current_intent().kind, EnemyIntent.Kind.WAIT)

	var odd_echo := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorEcho.new())
	var odd_echo_bt := battle(strikes(), [odd_echo])
	odd_echo.block = 4
	hit(odd_echo_bt, 1)
	odd_echo_bt.end_turn()
	check("what its block took was never heard, and a third of a point rounds up",
		odd_echo.current_intent().amount, 2)

	print("\n-- 메아리: guard and statuses come back too, all shown before any lands --")
	var whole_run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
	for id in [&"sever", &"brace", &"brace", &"brace", &"brace"]:
		whole_run.add_card(id)
	var whole := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorEcho.new())
	var whole_bt := battle(whole_run, [whole])
	var brace_block := 0
	for id in [&"sever", &"brace"]:
		for i in whole_bt.piles().hand.size():
			if whole_bt.card_at(i).id == id:
				whole_bt.play_card(i, 1)
				break
	brace_block = whole_bt.warden().block
	check("a 끊어내기 and a 버티기 were played", [whole.hp, brace_block > 0], [90, true])
	whole_bt.end_turn()
	var plan: Array[EnemyIntent] = [whole.current_intent()]
	plan.append_array(whole.behavior.extra_intents(whole_bt, 1))
	check("it means to do three things", plan.size(), 3)
	check("strike for two thirds of the 9",
		[plan[0].kind, plan[0].amount], [EnemyIntent.Kind.ATTACK, 6])
	check("guard for two thirds of the guard",
		[plan[1].kind, plan[1].amount], [EnemyIntent.Kind.BLOCK, ceili(brace_block * 2.0 / 3.0)])
	check("and soften the Warden exactly as it was softened",
		[plan[2].kind, plan[2].status, plan[2].stacks],
		[EnemyIntent.Kind.STATUS, StatusRules.SOFTENED, 2])
	var kept_plan := Stats.from_dict(whole.to_dict())
	check("a resumed one still means all three", kept_plan.intents.size(), 3)
	var whole_hp := whole_bt.warden().hp
	whole_bt.end_turn()
	check("the blow landed before the softening it carried", whole_bt.warden().hp, whole_hp - 6)
	check("it is behind its guard", whole.block, plan[1].amount)
	check("and the Warden is softened", whole_bt.warden().status(StatusRules.SOFTENED) > 0, true)

	var self_echo := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorEcho.new())
	var self_bt := battle(strikes(), [self_echo])
	self_bt.cost_in_play = 60
	self_bt.heard_status(BattleState.WARDEN, StatusRules.STRENGTH, 2)
	self_bt.cost_in_play = -1
	self_bt.heard_status(1, StatusRules.SOFTENED, 2)
	self_bt.heard_block(BattleState.WARDEN, 9)
	self_bt.end_turn()
	check("what the Warden put on itself, it puts on itself",
		[self_echo.current_intent().kind, self_echo.current_intent().status],
		[EnemyIntent.Kind.BEAR, StatusRules.STRENGTH])
	check("and what no card did was not heard", self_echo.behavior.extra_intents(self_bt, 1), [])
	self_bt.end_turn()
	check("it bore it", self_echo.status(StatusRules.STRENGTH), 2)

	print("\n-- 이어달리기: one blow a turn, handed on and heavier each time --")
	var team: Array[EnemyStats] = []
	for i in 3:
		team.append(enemy(40, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorRelay.new()))
	var relay_bt := battle(strikes(), team)
	var showing := func() -> Array:
		return team.map(func(c: EnemyStats) -> int:
			var i := c.current_intent()
			return i.amount if i.kind == EnemyIntent.Kind.ATTACK else 0)
	check("the first runner opens with it and the others wait", showing.call(), [5, 0, 0])
	var relay_hits := []
	var relay_shown := []
	for i in 4:
		var before := relay_bt.warden().hp
		relay_bt.end_turn()
		relay_hits.append(before - relay_bt.warden().hp)
		relay_shown.append(showing.call())
	check("one blow a turn: 5, 8, 11, 14", relay_hits, [5, 8, 11, 14])
	check("and who strikes next is on show the whole turn before",
		relay_shown, [[0, 8, 0], [0, 0, 11], [14, 0, 0], [0, 17, 0]])

	var dropped: Array[EnemyStats] = []
	for i in 3:
		dropped.append(enemy(40, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorRelay.new()))
	var drop_bt := battle(strikes(), dropped)
	drop_bt.end_turn()
	drop_bt.end_turn()
	check("the third runner is holding an 11", dropped[2].current_intent().amount, 11)
	dropped[2].hp = 0
	var drop_hp := drop_bt.warden().hp
	drop_bt.end_turn()
	check("brought down holding it, the blow never comes", drop_bt.warden().hp, drop_hp)
	check("and it is picked up at the weight it started",
		dropped.slice(0, 2).map(func(c: EnemyStats) -> int:
			var i := c.current_intent()
			return i.amount if i.kind == EnemyIntent.Kind.ATTACK else 0), [5, 0])
	dropped[1].hp = 0
	drop_bt.end_turn()
	drop_bt.end_turn()
	check("the last one left hands it to itself, and it still grows",
		dropped[0].current_intent().amount, 11)
	var resumed := Stats.from_dict(dropped[0].to_dict())
	check("a resumed runner still has it",
		[(resumed.behavior as BehaviorRelay).holds(), resumed.current_intent().amount], [true, 11])

	print("\n-- 합창: each strikes for every one still singing --")
	var choir: Array[EnemyStats] = []
	for i in 3:
		choir.append(enemy(40, [EnemyIntent.attack(2)] as Array[EnemyIntent], BehaviorChorus.new()))
	var choir_bt := battle(strikes(), choir)
	var choir_hp := choir_bt.warden().hp
	choir_bt.end_turn()
	check("three of them are 6 each", choir_bt.warden().hp, choir_hp - 18)
	choir[0].hp = 0
	check("one down, and what the others show drops in the same turn",
		choir[1].behavior.outgoing_amount(choir_bt, 2, choir[1].current_intent()), 4)
	choir_hp = choir_bt.warden().hp
	choir_bt.end_turn()
	check("two are 4 each", choir_bt.warden().hp, choir_hp - 8)
	choir[1].hp = 0
	choir_hp = choir_bt.warden().hp
	choir_bt.end_turn()
	check("and the last is the 2 it was written with", choir_bt.warden().hp, choir_hp - 2)

	print("\n-- 도미노: one falls onto the next, for as long as that is enough --")
	var line_run := strikes()
	var line: Array[EnemyStats] = []
	for i in 4:
		line.append(enemy(10, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorDomino.new()))
	var line_bt := battle(line_run, line)
	for d in line:
		d.hp = 6
	hit(line_bt, 1)
	check("worn to six, all four go from one blow",
		line.map(func(c: Stats) -> bool: return c.is_alive()), [false, false, false, false])
	check("and every one of them was recovered", line_run.clock.restored, 4 * 360)
	check("which ends the fight", line_bt.is_over(), true)

	var stopped: Array[EnemyStats] = []
	for i in 3:
		stopped.append(enemy(10, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorDomino.new()))
	var stop_bt := battle(strikes(), stopped)
	stopped[0].hp = 6
	stopped[1].hp = 7
	hit(stop_bt, 1)
	check("one point too many and it stops there",
		stopped.map(func(c: Stats) -> int: return c.hp), [0, 1, 10])

	var gapped: Array[EnemyStats] = []
	for i in 3:
		gapped.append(enemy(10, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorDomino.new()))
	var gap_bt := battle(strikes(), gapped)
	gapped[0].hp = 6
	gapped[1].hp = 0
	gapped[2].hp = 3
	hit(gap_bt, 1)
	check("and it does not fall across a gap", gapped[2].hp, 3)

	print("\n-- 방패막이: what is aimed at the one behind lands on the one in front --")
	var front := enemy(30, [EnemyIntent.wait()] as Array[EnemyIntent])
	var behind := enemy(12, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorSheltered.new())
	front.link = 2
	behind.link = 1
	var cover_bt := battle(strikes(), [front, behind])
	hit(cover_bt, 2)
	check("a blow aimed behind is taken in front", [front.hp, behind.hp], [24, 12])
	check("and the one behind reads as out of reach", cover_bt.reaches(2), false)
	hit(cover_bt, 1)
	check("the front is struck as usual", front.hp, 18)
	front.hp = 0
	check("with the front down it can be reached", cover_bt.reaches(2), true)
	hit(cover_bt, 2)
	check("and is", behind.hp, 6)

	var wide_run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
	for i in 10:
		wide_run.add_card(&"wear_down")
	var wide_front := enemy(30, [EnemyIntent.wait()] as Array[EnemyIntent])
	var wide_behind := enemy(12, [EnemyIntent.attack(5)] as Array[EnemyIntent], BehaviorSheltered.new())
	wide_front.link = 2
	wide_behind.link = 1
	var wide_bt := battle(wide_run, [wide_front, wide_behind])
	wide_bt.play_card(0, 1)
	check("a card that strikes everything is aimed at nobody, and reaches both",
		[wide_front.hp, wide_behind.hp], [26, 8])
	check("and nothing is being aimed once it has resolved", wide_bt.targets_in_play, 0)

	print("\n-- 버팀목: fifteen a turn and not a point more --")
	var prop := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorBulwark.new())
	var prop_bt := battle(strikes(), [prop])
	hit(prop_bt, 1)
	hit(prop_bt, 1)
	check("two blows land whole", prop.hp, 87)
	check("the card says the third will only do 3 before it is played",
		prop_bt.preview_damage(1, 6, BattleState.WARDEN), 3)
	hit(prop_bt, 1)
	check("and it does", prop.hp, 84)
	check("after that nothing gets through", prop_bt.preview_damage(1, 6, BattleState.WARDEN), 0)
	prop_bt.end_turn()
	check("a new turn is a new fifteen", prop_bt.preview_damage(1, 20, BattleState.WARDEN), 15)
	check("and a resumed one knows how much of it is spent",
		(Stats.from_dict(prop.to_dict()).behavior as BehaviorBulwark).taken(), 0)

	var guarded_prop := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorBulwark.new())
	var guarded_prop_bt := battle(strikes(), [guarded_prop])
	guarded_prop.block = 4
	hit(guarded_prop_bt, 1)
	check("what its block takes uses none of the allowance up",
		[guarded_prop.hp, (guarded_prop.behavior as BehaviorBulwark).taken()], [97, 2])
	guarded_prop.block = 4
	check("so past its block the full remainder is still there",
		guarded_prop_bt.preview_damage(1, 30, BattleState.WARDEN), 17)

	print("\n-- 해를 끄는 것: a pull that holds lands on the evening, and it grows for the hours --")
	var sun_dragger := func() -> EnemyStats:
		var c := enemy(400, [EnemyIntent.drag(18)] as Array[EnemyIntent], BehaviorSunDragger.new())
		var at_dawn: Array[EnemyIntent] = [EnemyIntent.drag(18)]
		var at_dusk: Array[EnemyIntent] = [EnemyIntent.grow(1)]
		var at_night: Array[EnemyIntent] = [EnemyIntent.attack(12)]
		c.morning_intents = at_dawn
		c.evening_intents = at_dusk
		c.night_intents = at_night
		return c
	var sun_dawn := func() -> RunState:
		var run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 5))
		for i in 10:
			run.add_card(&"take")
		return run
	var owed := func(bt: BattleState, who: Stats) -> int:
		return who.behavior.outgoing_amount(bt, 1, who.current_intent())

	var pulled_run: RunState = sun_dawn.call()
	var puller: Stats = sun_dragger.call()
	var pulled_bt := battle(pulled_run, [puller])
	check("at five in the morning it means to pull",
		puller.current_intent().kind, EnemyIntent.Kind.DRAG)
	hit(pulled_bt, 1)
	hit(pulled_bt, 1)
	check("12 of the 18 paid, and the intent says 6 are owed", owed.call(pulled_bt, puller), 6)
	pulled_bt.end_turn()
	check("short of the grip, the day is gone: it is five in the evening",
		pulled_run.clock.minute_of_day(), 17 * 60)
	check("which cost the turn and nine hours more", pulled_run.clock.elapsed, 12 * 60)
	check("the evening it made shows its growth before it lands: 1 and 4 for the twelve hours",
		[puller.current_intent().kind, puller.current_intent().stacks],
		[EnemyIntent.Kind.GROW, 5])
	check("holding did not tighten anything",
		(puller.behavior as BehaviorSunDragger).tightened(), 0)
	pulled_bt.end_turn()
	check("it grew by that", puller.status(StatusRules.STRENGTH), 5)
	check("and the next evening is back to its own 1", puller.evening_intents[0].stacks, 1)
	var night_hp := pulled_bt.warden().hp
	pulled_bt.end_turn()
	check("the night's 12 lands as 17", pulled_bt.warden().hp, night_hp - 17)

	print("\n-- 해를 끄는 것: a pull that is broken costs nothing now and more next time --")
	var held_sun_run: RunState = sun_dawn.call()
	var loser: Stats = sun_dragger.call()
	var held_sun_bt := battle(held_sun_run, [loser])
	held_sun_bt.damage(1, 18)
	check("the grip's worth taken, nothing is owed", owed.call(held_sun_bt, loser), 0)
	held_sun_bt.end_turn()
	check("the turn costs only itself: it is eight", held_sun_run.clock.minute_of_day(), 8 * 60)
	check("it pulls again, the day's first, and holds on harder: 22",
		[loser.current_intent().kind, owed.call(held_sun_bt, loser)],
		[EnemyIntent.Kind.DRAG, 22])
	check("a resumed one remembers how hard",
		(Stats.from_dict(loser.to_dict()).behavior as BehaviorSunDragger).tightened(), 4)
	held_sun_bt.damage(1, 22)
	held_sun_bt.end_turn()
	check("broken again, it is eleven and the grip is 26",
		[held_sun_run.clock.minute_of_day(), owed.call(held_sun_bt, loser)], [11 * 60, 26])
	held_sun_bt.end_turn()
	check("let go this time, it is evening with three hours pulled",
		[held_sun_run.clock.minute_of_day(), held_sun_run.clock.elapsed], [17 * 60, 12 * 60])
	check("the turn counts too, so it grows 1 and 2 more", loser.current_intent().stacks, 3)

	var late_sun_run: RunState = sun_dawn.call()
	var dud: Stats = sun_dragger.call()
	var late_sun_bt := battle(late_sun_run, [dud])
	for grip in [18, 22, 26]:
		late_sun_bt.damage(1, grip)
		late_sun_bt.end_turn()
	check("on the day's last turn it still pulls", dud.current_intent().kind, EnemyIntent.Kind.DRAG)
	late_sun_bt.end_turn()
	check("the turn itself reaches the evening, so the clock is not moved any further",
		[late_sun_run.clock.minute_of_day(), late_sun_run.clock.elapsed], [17 * 60, 12 * 60])
	check("but the turn was pulled all the same: 1 and 1 more", dud.current_intent().stacks, 2)

	var last_run: RunState = sun_dawn.call()
	last_run.clock.advance(_b.starting_remaining - 200, RunClock.Source.TRAVEL)
	var ender := enemy(200, [EnemyIntent.drag(18)] as Array[EnemyIntent], BehaviorSunDragger.new())
	var last_bt := battle(last_run, [ender])
	last_bt.end_turn()
	check("a pull that takes the last of the run's time ends the run",
		[last_run.clock.is_expired(), last_bt.phase], [true, BattleState.Phase.DEFEAT])

	print("\n-- 무거움: a card that cost an hour lands half, a dearer one lands whole --")
	var light_run := strikes()
	var light_foe := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorHeavy.new())
	var light_bt := battle(light_run, [light_foe])
	check("the card says so before it is played",
		light_bt.card_at(0).rules_text_live(light_bt, BattleState.WARDEN, 1).contains("3"), true)
	check("and the weighing does not outlast the preview", light_bt.cost_in_play, -1)
	hit(light_bt, 1)
	check("a one-hour 6 landed as 3", light_foe.hp, 96)
	check("and nothing is being weighed once it has resolved", light_bt.cost_in_play, -1)

	var dear_run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
	for i in 10:
		dear_run.add_card(&"sever")
	var dear_foe := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorHeavy.new())
	var dear_bt := battle(dear_run, [dear_foe])
	dear_bt.play_card(0, 1)
	check("a two-hour 9 landed whole", dear_foe.hp, 90)

	var odd_foe := enemy(99, [EnemyIntent.wait()] as Array[EnemyIntent], BehaviorHeavy.new())
	var odd_bt := battle(strikes(), [odd_foe])
	check("halving rounds up, so a light blow always does something",
		odd_foe.behavior.absorbs(odd_bt, 1, 1), 1)
	odd_bt.damage(1, 8)
	check("and damage from no card at all is not light", odd_foe.hp, 91)

	_the_sky_changes_the_pattern()
	_the_pattern_is_fixed_at_the_turn_it_started()

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)

func _the_sky_changes_the_pattern() -> void:
	print("\n-- an enemy that fights differently after dark --")
	# Built here rather than taken from the roster: this checks the machinery, and
	# it should not start failing because the bestiary was re-authored.
	var data := EnemyData.new()
	data.id = &"test_sky"
	data.name_key = &"enemy.test_sky.name"
	data.hp_min = 20
	data.hp_max = 20
	data.intents = [EnemyIntent.attack(5)] as Array[EnemyIntent]
	data.night_intents = [EnemyIntent.attack(12)] as Array[EnemyIntent]
	check("it was authored with a night pattern", data.night_intents.is_empty(), false)

	var c := data.spawn(_b, rng(1))
	c.sky = RunClock.Daytime.DAY
	check("by day it opens as written", c.current_intent().amount, data.intents[0].amount)
	c.sky = RunClock.Daytime.NIGHT
	check("by night it opens differently",
		c.current_intent().amount, data.night_intents[0].amount)
	check("and the two are not the same",
		data.intents[0].amount != data.night_intents[0].amount, true)
	var plainest := EnemyData.new()
	plainest.id = &"test_steady"
	plainest.name_key = &"enemy.test_steady.name"
	plainest.hp_min = 30
	plainest.hp_max = 30
	plainest.intents = [EnemyIntent.attack(9)] as Array[EnemyIntent]
	var steady := plainest.spawn(_b, rng(1))
	for unwritten in [RunClock.Daytime.MORNING, RunClock.Daytime.DAY,
			RunClock.Daytime.EVENING, RunClock.Daytime.NIGHT]:
		steady.sky = unwritten
		check("an enemy written for no phase reads the same in phase %d" % unwritten,
			steady.current_intent().amount, plainest.intents[0].amount)

	var four := data.spawn(_b, rng(1))
	four.morning_intents = [EnemyIntent.attack(1)] as Array[EnemyIntent]
	four.day_intents = [EnemyIntent.attack(2)] as Array[EnemyIntent]
	four.evening_intents = [EnemyIntent.attack(3)] as Array[EnemyIntent]
	four.night_intents = [EnemyIntent.attack(4)] as Array[EnemyIntent]
	var read := []
	for sky in [RunClock.Daytime.MORNING, RunClock.Daytime.DAY,
			RunClock.Daytime.EVENING, RunClock.Daytime.NIGHT]:
		four.sky = sky
		read.append(four.current_intent().amount)
	check("all four phases can be written apart", read, [1, 2, 3, 4])

	var bare := EnemyData.new()
	bare.id = &"test_bare"
	bare.name_key = &"enemy.test_bare.name"
	bare.hp_min = 20
	bare.hp_max = 20
	bare.intents = [EnemyIntent.attack(7)] as Array[EnemyIntent]
	var plain := bare.spawn(_b, rng(1))
	plain.sky = RunClock.Daytime.NIGHT
	check("an enemy with no night pattern keeps its day one",
		plain.current_intent().amount, bare.intents[0].amount)


func _the_pattern_is_fixed_at_the_turn_it_started() -> void:
	print("\n-- the sky turning mid-turn does not change the pattern until the next one --")
	var b := Balance.default()
	var cards := CardDatabase.new()
	cards.load_from()

	var run := RunState.new(b, 1)
	run.clock.advance(run.clock.minutes_until_sky_turns() - b.turn_cost, RunClock.Source.TRAVEL)
	var opened_under := run.clock.daytime()

	var fixture := EnemyData.new()
	fixture.id = &"test_clockwatcher"
	fixture.name_key = &"enemy.test_clockwatcher.name"
	fixture.hp_min = 30
	fixture.hp_max = 30
	fixture.intents = [EnemyIntent.attack(5)] as Array[EnemyIntent]
	var group: Array[EnemyStats] = [fixture.spawn(b, rng(2))]
	var bt := BattleState.new(run, cards, group, rng(2))
	var enemy: EnemyStats = bt.enemy(1)
	check("the fight opens under the sky the run is under", enemy.sky, opened_under)

	bt.end_turn()
	check("a turn passed and the sky turned", run.clock.daytime() != opened_under, true)
	check("and only now does the enemy read the new sky", enemy.sky, run.clock.daytime())
