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
	var run := RunState.new(_b, RunClock.seed_from_date(0, 0, 0, 12))
	for i in n:
		run.add_card(&"take")
	return run


func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func battle(run: RunState, enemies: Array[Combatant]) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return BattleState.new(run, _cards, enemies, rng)


func hit(bt: BattleState, target: int) -> bool:
	for i in bt.piles().hand.size():
		if bt.card_at(i).id == &"take":
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
	var woken := Combatant.from_dict(late_foe.to_dict())
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
	var group: Array[Combatant] = [fixture.spawn(b, rng(2))]
	var bt := BattleState.new(run, cards, group, rng(2))
	var enemy: Combatant = bt.combatants[1]
	check("the fight opens under the sky the run is under", enemy.sky, opened_under)

	bt.end_turn()
	check("a turn passed and the sky turned", run.clock.daytime() != opened_under, true)
	check("and only now does the enemy read the new sky", enemy.sky, run.clock.daytime())
