extends SceneTree


var _failures := 0
var _b: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func controller(seed_value: int) -> RunController:
	return RunController.new(_b, _cards, _enemies, _encounters, _relics, seed_value)


func walk_to_kind(rc: RunController, kind: Room.Kind, budget: int = 60) -> bool:
	for step in budget:
		if rc.is_over():
			return false

		var here := rc.current_room()
		if here != null and here.kind == kind and not here.is_spent():
			return true

		match rc.phase:
			RunController.Phase.BATTLE:
				_auto_fight(rc)
			RunController.Phase.REWARD:
				rc.skip_reward()
			RunController.Phase.FIRE:
				rc.leave_fire()
			RunController.Phase.SHOP:
				rc.leave_shop()
			RunController.Phase.EXPLORING:
				var target: Variant = _nearest(rc, kind)
				if target == null:
					return false
				if not rc.move_to(target):
					return false
			_:
				return false
	return false


func _nearest(rc: RunController, kind: Room.Kind) -> Variant:
	var came := {rc.map.current: rc.map.current}
	var queue := [rc.map.current]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if rc.map.at(at).kind == kind and at != rc.map.current:
			var node: Vector2i = at
			while came[node] != rc.map.current:
				node = came[node]
			return node
		for n in rc.map.neighbours(at):
			if not came.has(n):
				came[n] = at
				queue.append(n)
	return null


func _auto_fight(rc: RunController) -> void:
	var guard := 0
	while rc.phase == RunController.Phase.BATTLE and guard < 200:
		guard += 1
		var played := false
		for i in rc.battle.piles().hand.size():
			var enemies := rc.battle.enemy_handles()
			var target := enemies[0] if not enemies.is_empty() else -1
			if rc.play_card(i, target):
				played = true
				break
		if not played:
			rc.end_turn()


func _init() -> void:
	# The pool is being rebuilt and holds almost nothing; the machinery under test
	# is exercised with the shelved cards as well. See CardDatabase.SHELF_ROOT.
	CardDatabase.fixture_roots = PackedStringArray(CardDatabase.TEST_ROOTS)
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_encounters = EncounterTable.new()
	_encounters.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()

	print("\n-- a run starts on act one with a deck and a full clock --")
	var rc := controller(1)
	check("act", rc.run.act, 1)
	check("exploring", rc.phase, RunController.Phase.EXPLORING)
	check("starting deck", rc.run.deck.size(), rc.run.player.starting_deck.size())
	check("full clock", rc.run.clock.remaining, _b.starting_remaining)
	check("standing on the start", rc.map.current, Vector2i.ZERO)
	check("the boss door follows the dial",
		rc.map.is_known(rc.map.boss_coord), _b.boss_marked_on_map)
	check("and the run quotes no distance to it", rc.status().has("to_boss"), false)

	print("\n-- walking into a fight starts one --")
	var f := controller(2)
	check("found a fight", walk_to_kind(f, Room.Kind.COMBAT), true)
	check("in battle", f.phase, RunController.Phase.BATTLE)
	check("with enemies", f.battle.enemy_handles().size() > 0, true)
	check("cannot walk out mid-fight", f.move_to(f.map.reachable()[0]), false)

	print("\n-- winning clears the room and offers a reward --")
	_auto_fight(f)
	check("reward on the table", f.phase, RunController.Phase.REWARD)
	check("three cards", f.run.pending_reward().size(), _b.reward_card_choices)
	check("room cleared", f.map.at(f.map.current).cleared, true)
	check("some time came back", f.run.clock.restored > 0, true)

	print("\n-- taking one adds it and returns to the floor --")
	var deck_before := f.run.deck.size()
	check("taken", f.take_reward(0), true)
	check("deck grew", f.run.deck.size(), deck_before + 1)
	check("exploring again", f.phase, RunController.Phase.EXPLORING)
	check("walking back offers nothing", f.map.at(f.map.current).is_spent(), true)

	print("\n-- a fire offers each of its actions once --")
	var fr := _walk_until(Room.Kind.FIRE, 30)
	check("reached a fire", fr != null, true)
	if fr == null:
		print("FAILURES (%d failures)" % maxi(1, _failures))
		quit(1)
		return
	check("at the fire", fr.phase, RunController.Phase.FIRE)
	var hp_before := fr.run.hp
	var clock_before := fr.run.clock.remaining
	check("rested", fr.use_fire(RunState.FireAction.REST), true)
	check("healed", fr.run.hp > hp_before, true)
	check("cost what resting costs", clock_before - fr.run.clock.remaining,
		fr.run.fire_cost_of(RunState.FireAction.REST))
	check("still at the fire", fr.phase, RunController.Phase.FIRE)
	check("resting twice is refused", fr.use_fire(RunState.FireAction.REST), false)
	check("refused for free", clock_before - fr.run.clock.remaining,
		fr.run.fire_cost_of(RunState.FireAction.REST))

	var resumed := RunController.from_dict(JSON.parse_string(JSON.stringify(fr.save_state())),
		_b, _cards, _enemies, _encounters, _relics)
	check("a resumed fire remembers the rest", resumed.use_fire(RunState.FireAction.REST), false)

	check("sharpening still offered", fr.use_fire(RunState.FireAction.UPGRADE, 0), true)
	check("sharpened once", int(fr.run.deck[0].get("upgrades", 0)), 1)
	check("sharpening twice is refused", fr.use_fire(RunState.FireAction.UPGRADE, 1), false)
	check("the fire is lit until it is left", fr.map.at(fr.map.current).cleared, false)
	fr.leave_fire()
	check("back on the floor", fr.phase, RunController.Phase.EXPLORING)
	check("and the fire is spent", fr.map.at(fr.map.current).cleared, true)

	print("\n-- a fire walked past keeps --")
	var skip := _walk_until(Room.Kind.FIRE, 0)
	check("reached a fire to walk past", skip != null, true)
	if skip == null:
		print("FAILURES (%d failures)" % maxi(1, _failures))
		quit(1)
		return
	skip.leave_fire()
	var fire_coord := skip.map.current
	check("not cleared by leaving", skip.map.at(fire_coord).cleared, false)
	check("still waiting later", skip.map.at(fire_coord).is_spent(), false)

	print("\n-- the same seed plays the same run --")
	var a := controller(777)
	var b := controller(777)
	check("same floor size", a.map.rooms.size(), b.map.rooms.size())
	check("same boss", a.map.boss_coord, b.map.boss_coord)
	var path_a := []
	var path_b := []
	for i in 6:
		if a.phase == RunController.Phase.EXPLORING and not a.reachable().is_empty():
			a.move_to(a.reachable()[0])
			b.move_to(b.reachable()[0])
			path_a.append(a.map.current)
			path_b.append(b.map.current)
	check("same walk", path_a, path_b)
	check("same clock", a.run.clock.remaining, b.run.clock.remaining)

	print("\n-- running out of time ends the run, whatever else was happening --")
	var doomed := controller(5)
	doomed.run.clock.advance(_b.starting_remaining - 30, RunClock.Source.TRAVEL)
	check("half an hour left", doomed.run.clock.remaining, 30)
	doomed.move_to(doomed.reachable()[0])
	check("ended", doomed.phase, RunController.Phase.ENDED)
	check("by the clock, not by damage", doomed.outcome, RunController.Outcome.RAN_OUT)
	check("hp was never the problem", doomed.run.hp, _start_hp())

	print("\n-- an elite pays a relic on top of its card --")
	var elite := controller(11)
	if walk_to_kind(elite, Room.Kind.ELITE):
		check("no relics before it", elite.run.relics.size(), 0)
		# This checks what winning pays, not whether a hand played in order can
		# win: which elite the seed lands on changes whenever the roster does, and
		# several of them are not beaten by playing every card at the first enemy.
		for handle in elite.battle.enemy_handles():
			elite.battle.combatants[handle].hp = 1
		_auto_fight(elite)
		check("one after", elite.run.relics.size(), 1)
		check("named for the screen", elite.last_relic, elite.run.relics[0])
		check("never a boss relic",
			_relics.get_relic(elite.last_relic).rarity == Relic.Rarity.BOSS, false)
		check("and the card reward still came", elite.phase, RunController.Phase.REWARD)
		elite.skip_reward()
		check("which clears when the next room resolves", elite.run.relics.size(), 1)
	else:
		check("an elite was reachable", false, true)

	print("\n-- opening the boss door finishes the act --")
	var boss := controller(6)
	boss.map.current = boss.map.neighbours(boss.map.boss_coord)[0]
	var hp_at_the_fall := [-1]
	# Reach the controller through a weakref: a lambda that captured boss itself
	# would sit in boss's own signal, a cycle that keeps it alive past the test.
	var boss_ref: WeakRef = weakref(boss)
	boss.battle_finished.connect(func(_won: bool) -> void:
		hp_at_the_fall[0] = (boss_ref.get_ref() as RunController).run.hp)
	check("at the door", boss.move_to(boss.map.boss_coord), true)
	if boss.phase == RunController.Phase.BATTLE:
		_auto_fight(boss)
	check("act cleared", boss.phase, RunController.Phase.ACT_CLEARED)
	check("no reward screen for a boss", boss.run.has_pending_reward(), false)
	check("the boss handed over a relic", boss.run.relics.size(), 1)
	check("and the screen can name it", boss.last_relic, boss.run.relics[0])
	check("a boss relic, from the shelf nothing else draws from",
		_relics.get_relic(boss.last_relic).rarity, Relic.Rarity.BOSS)
	var tenth := roundi(boss.run.max_hp * _b.act_clear_heal_fraction)
	check("the boss falling heals a tenth, or up to full", boss.run.hp,
		mini(boss.run.max_hp, hp_at_the_fall[0] + tenth))
	var boss_resumed := RunController.from_dict(JSON.parse_string(JSON.stringify(boss.save_state())),
		_b, _cards, _enemies, _encounters, _relics)
	check("a resumed act screen does not heal again", boss_resumed.run.hp, boss.run.hp)
	check("moving on", boss.advance_act(), true)
	check("act two", boss.run.act, 2)
	check("on a new floor", boss.map.current, Vector2i.ZERO)
	check("with the clock carried over", boss.run.clock.remaining < _b.starting_remaining, true)

	print("\n-- the ending reads both axes --")
	var ending := boss.ending()
	check("delivered is the pool", int(ending["delivered"]), boss.run.clock.restored)
	check("kept is what went into the Warden", int(ending["kept"]), boss.run.total_kept)
	check("and memories are counted", ending.has("memories"), true)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _walk_until(kind: Room.Kind, hurt_by: int) -> RunController:
	for seed_value in [3, 5, 7, 11, 13, 17, 19, 23, 29, 31]:
		var rc := controller(seed_value)
		if hurt_by > 0:
			rc.run.damage(hurt_by)
		if walk_to_kind(rc, kind):
			return rc
	return null


## What a run opens on: the max hp of the character it is played as.
func _start_hp() -> int:
	return RunState.new(_b).player.max_hp
