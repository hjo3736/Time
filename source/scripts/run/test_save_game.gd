extends SceneTree


var _failures := 0
var _balance: Balance
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


func controller(seed_value: int = 7) -> RunController:
	return RunController.new(_balance, _cards, _enemies, _encounters, _relics, seed_value)


func through_disk(rc: RunController) -> RunController:
	SaveGame.save(rc)
	return SaveGame.load_run(_balance, _cards, _enemies, _encounters, _relics)


func _init() -> void:
	TranslationServer.set_locale("en")
	_balance = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_encounters = EncounterTable.new()
	_encounters.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()
	SaveGame.path = "user://test_run.save"
	SaveGame.clear()

	print("\n-- nothing to continue into, before anything is saved --")
	check("no save", SaveGame.has_save(), false)
	check("and loading says so rather than guessing",
		SaveGame.load_run(_balance, _cards, _enemies, _encounters, _relics), null)

	print("\n-- a run mid-floor comes back the same --")
	var walked := controller()
	var guard := 0
	while walked.phase == RunController.Phase.EXPLORING and guard < 6:
		guard += 1
		var options := walked.map.reachable()
		if options.is_empty():
			break
		walked.move_to(options[0])
	var back := through_disk(walked)
	check("loaded", back != null, true)
	check("phase", back.phase, walked.phase)
	check("act", back.run.act, walked.run.act)
	check("hp", back.run.hp, walked.run.hp)
	check("remaining", back.run.clock.remaining, walked.run.clock.remaining)
	check("restored", back.run.clock.restored, walked.run.clock.restored)
	check("elapsed", back.run.clock.elapsed, walked.run.clock.elapsed)
	check("deck", back.run.deck, walked.run.deck)
	check("standing in the same room", back.map.current, walked.map.current)
	check("same floor size", back.map.rooms.size(), walked.map.rooms.size())
	check("boss still marked", back.map.boss_coord, walked.map.boss_coord)

	var repriced := 0
	for coord in walked.map.rooms:
		for next in walked.map.neighbours(coord):
			if back.map.cost_between(coord, next) != walked.map.cost_between(coord, next):
				repriced += 1
	check("every corridor kept the length it was carved with", repriced, 0)
	check("and the walk to the boss still reads the same",
		back.map.minutes_to_boss(), walked.map.minutes_to_boss())

	print("\n-- the fog is saved, not re-derived from the start room --")
	var visited_before := 0
	for coord in walked.map.rooms:
		if walked.map.rooms[coord].visited:
			visited_before += 1
	var visited_after := 0
	for coord in back.map.rooms:
		if back.map.rooms[coord].visited:
			visited_after += 1
	check("same rooms visited", visited_after, visited_before)
	check("and more than just the start", visited_before > 1, true)

	print("\n-- a fight in progress survives, mid-turn --")
	var fighting := controller()
	var walk := 0
	while fighting.phase != RunController.Phase.BATTLE and walk < 60:
		walk += 1
		if fighting.phase == RunController.Phase.EVENT:
			fighting.choose_event(fighting.event.choices.size() - 1)
			continue
		if fighting.phase != RunController.Phase.EXPLORING:
			break
		var options := fighting.map.reachable()
		if options.is_empty():
			break
		fighting.move_to(options[walk % options.size()])
	check("found a fight", fighting.phase, RunController.Phase.BATTLE)

	if fighting.phase == RunController.Phase.BATTLE:
		for i in fighting.battle.piles().hand.size():
			var card := fighting.battle.card_at(i)
			if card != null and card.cost_minutes() <= fighting.battle.turn_budget:
				if fighting.play_card(i, fighting.battle.enemy_handles()[0]):
					break

		var mark := fighting.battle.enemy_handles()[0]
		fighting.battle.combatants[mark].add_status(StatusRules.VULNERABLE, 2)

		var resumed := through_disk(fighting)
		check("still in the fight", resumed.phase, RunController.Phase.BATTLE)
		check("the budget is whole again",
			resumed.battle.turn_budget, resumed.battle.turn_budget_max)
		check("which is more than was left", resumed.battle.turn_budget
			> fighting.battle.turn_budget, true)
		check("and the hand is the one the fight opened with",
			resumed.battle.piles().hand.size(), 5)
		check("back on turn one", resumed.battle.turn, 1)
		check("nothing has been discarded yet", resumed.battle.piles().discard.size(), 0)
		check("same number of enemies", resumed.battle.combatants.size(),
			fighting.battle.combatants.size())
		check("the mid-turn debuff went with it",
			resumed.battle.combatants[mark].status(StatusRules.VULNERABLE), 0)
		check("and the enemy is unhurt again",
			resumed.battle.combatants[mark].hp, resumed.battle.combatants[mark].max_hp)
		check("intents intact", resumed.battle.combatants[mark].intents.size(),
			fighting.battle.combatants[mark].intents.size())

		print("\n-- a fight several turns in still resumes at its start --")
		fighting.end_turn()
		if fighting.phase == RunController.Phase.BATTLE:
			check("the live fight moved on", fighting.battle.turn > 1, true)
			var restarted := through_disk(fighting)
			check("but the save is still turn one", restarted.battle.turn, 1)
			check("with nothing discarded", restarted.battle.piles().discard.size(), 0)
			check("and the enemy whole", restarted.battle.combatants[mark].hp,
				restarted.battle.combatants[mark].max_hp)

		print("\n-- restarting the fight is not a reroll --")
		var again := through_disk(resumed)
		check("the same hand comes back every time",
			Array(again.battle.piles().hand), Array(resumed.battle.piles().hand))
		check("and the same draw order under it",
			Array(again.battle.piles().draw), Array(resumed.battle.piles().draw))
		resumed.end_turn()
		again.end_turn()
		check("and the turn plays out the same",
			Array(again.battle.piles().hand) if again.battle != null else [],
			Array(resumed.battle.piles().hand) if resumed.battle != null else [])

	print("\n-- a behaviour that counts turns keeps its count --")
	var withered := _enemies.get_enemy(&"crumbling")
	if withered != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var spawned := withered.spawn(_balance, rng)
		(spawned.behavior as BehaviorWithered).on_turn_end(null, 0)
		(spawned.behavior as BehaviorWithered).on_turn_end(null, 0)
		var copied := Combatant.from_dict(spawned.to_dict())
		check("the behaviour came back", copied.behavior != null, true)
		check("as the same class", copied.behavior.get_script(), spawned.behavior.get_script())
		check("with its age intact", (copied.behavior as BehaviorWithered).turns_elapsed(), 2)

	print("\n-- a garbage file is ignored, not crashed on --")
	var junk := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	junk.store_string("this is not json {{{")
	junk.close()
	check("refused", SaveGame.load_run(_balance, _cards, _enemies, _encounters, _relics), null)

	var wrong := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	wrong.store_string(JSON.stringify({"version": 999, "run": {}}))
	wrong.close()
	check("a future version is refused too",
		SaveGame.load_run(_balance, _cards, _enemies, _encounters, _relics), null)

	print("\n-- clearing leaves nothing to continue --")
	SaveGame.save(controller())
	check("saved", SaveGame.has_save(), true)
	SaveGame.clear()
	check("cleared", SaveGame.has_save(), false)
	check("and the scratch file is gone with it",
		FileAccess.file_exists("user://test_run.save"), false)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
