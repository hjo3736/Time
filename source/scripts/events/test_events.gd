extends SceneTree

var _failures := 0
var _b: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase
var _events: EventTable


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


func controller(seed_value := 3) -> RunController:
	return RunController.new(_b, _cards, _enemies, _encounters, _relics, seed_value, _events)


func _init() -> void:
	TranslationServer.set_locale("ko")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_encounters = EncounterTable.new()
	_encounters.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()
	_events = EventTable.new()
	_events.load_from()

	print("\n-- the table loads and passes its own linter --")
	check("problems", _events.validate(), PackedStringArray())
	check("a real table", _events.size() >= 5, true)
	var order := _events.all().map(func(e: EventData) -> String: return String(e.id))
	var sorted_order := order.duplicate()
	sorted_order.sort()
	check("sorted by id", order, sorted_order)

	print("\n-- acts with nothing of their own borrow act one's, and say so --")
	check("acts two and three are still unwritten",
		_events.borrowed_acts(_b.acts_per_run), [2, 3])
	check("so a later act still has something to offer",
		_events.candidates(3).is_empty(), false)
	check("and what it offers is act one's", _events.candidates(3)[0].act, 1)
	check("a borrowed act still respects what the run has already seen",
		_events.candidates(3, [_events.candidates(3)[0].id]).size(),
		_events.candidates(3).size() - 1)

	print("\n-- every event offers a way to walk away --")
	for e in _events.all():
		var free := e.choices.any(func(c: EventChoice) -> bool: return c.outcomes.is_empty())
		if not free:
			_failures += 1
			print("  FAIL  %s has no way out" % e.id)
	check("all of them", true, true)

	print("\n-- and every event costs something to reach, even declined --")
	check("a room transition is not free", _b.room_transition_cost > 0, true)

	print("\n-- picking is seeded and does not repeat inside a run --")
	var a := _events.pick(rng(11), 1, [])
	var b := _events.pick(rng(11), 1, [])
	check("same seed, same event", a.id, b.id)
	var without := _events.pick(rng(11), 1, [a.id])
	check("and the seen one is not offered again", without.id != a.id, true)
	var all_seen := _events.all().map(func(e: EventData) -> StringName: return e.id)
	check("nothing left to offer says so", _events.pick(rng(1), 1, all_seen), null)
	check("act 2 draws act one's until it has its own", _events.pick(rng(1), 2, []).act, 1)
	check("and a borrowed act runs dry the same way",
		_events.pick(rng(1), 2, all_seen), null)

	print("\n-- an event resolves and the room is spent --")
	var rc := controller()
	_walk_to_kind(rc, Room.Kind.EVENT)
	check("an event room was reached", rc.phase, RunController.Phase.EVENT)

	if rc.phase == RunController.Phase.EVENT:
		var here := rc.event
		check("with an event in it", here != null, true)
		check("that has choices", here.choices.size() >= 2, true)
		var before := rc.run.clock.remaining
		var pick := 0
		for i in here.choices.size():
			if here.choices[i].available(rc.run):
				pick = i
				break
		check("choosing works", rc.choose_event(pick), true)
		check("and the run moves on", rc.phase, RunController.Phase.EXPLORING)
		check("the room is spent", rc.map.at(rc.map.current).cleared, true)
		check("the event was noted", rc.run.seen_events().has(here.id), true)
		check("out of range is refused", rc.choose_event(99), false)
		check("and choosing again outside the phase is too", rc.choose_event(pick), false)
		if here.choices[pick].outcomes.any(func(o: EventOutcome) -> bool: return o is OutcomeSpendTime):
			check("time was spent", rc.run.clock.remaining < before, true)

	print("\n-- a choice the run cannot pay for is offered but refused --")
	var poor := controller(5)
	var gated: EventData = null
	for e in _events.all():
		for c in e.choices:
			if c.needs_restored_hours > 0:
				gated = e
	check("something is gated on restored time", gated != null, true)
	if gated != null:
		poor.event = gated
		poor.phase = RunController.Phase.EVENT
		var index := 0
		for i in gated.choices.size():
			if gated.choices[i].needs_restored_hours > 0:
				index = i
		check("with nothing saved it cannot be taken",
			gated.choices[index].available(poor.run), false)
		check("so the controller refuses it", poor.choose_event(index), false)
		poor.run.clock.restore(gated.choices[index].needs_restored_hours * 60)
		check("and with the time it can", gated.choices[index].available(poor.run), true)

	print("\n-- outcomes reach the run --")
	var r := controller()
	var start_hp := r.run.hp
	var hurt := OutcomeHealth.new()
	hurt.amount = -7
	hurt.apply(r.run)
	check("damage lands", r.run.hp, start_hp - 7)
	var mend := OutcomeHealth.new()
	mend.amount = 3
	mend.apply(r.run)
	check("healing lands", r.run.hp, start_hp - 4)
	mend.amount = 999
	mend.apply(r.run)
	check("and stops at full", r.run.hp, r.run.max_hp)

	var gain := OutcomeRestored.new()
	gain.hours = 3
	gain.apply(r.run)
	check("restored added", r.run.clock.restored, 180)
	var lose := OutcomeRestored.new()
	lose.hours = -2
	lose.apply(r.run)
	check("and taken away", r.run.clock.restored, 60)

	var deck_before := r.run.deck.size()
	var give := OutcomeCard.new()
	give.card_id = &"quick_cut"
	give.apply(r.run)
	check("a card was added", r.run.deck.size(), deck_before + 1)

	var keep := OutcomeMemory.new()
	keep.memory_id = &"the-kettle"
	keep.apply(r.run)
	keep.apply(r.run)
	check("a memory was recovered", r.run.memories.size(), 1)
	check("and it does not double up", r.run.memories.has(&"the-kettle"), true)

	print("\n-- floors actually contain event rooms --")
	var table := EncounterTable.new()
	table.load_from()
	var rooms := MapGenerator.generate(_b, table, rng(4), 1)
	var count := 0
	for coord in rooms:
		if rooms[coord].kind == Room.Kind.EVENT:
			count += 1
	check("inside the share Balance leaves for events",
		count <= _b.content_in(1) - _b.fights_min_in(1), true)

	print("\n-- every string an event needs exists in both languages --")
	var missing := []
	for lang in ["ko", "en"]:
		TranslationServer.set_locale(lang)
		for e in _events.all():
			if e.title() == String(e.title_key):
				missing.append("%s title (%s)" % [e.id, lang])
			if e.body() == String(e.body_key):
				missing.append("%s body (%s)" % [e.id, lang])
			for c in e.choices:
				if c.label() == String(c.label_key):
					missing.append("%s %s (%s)" % [e.id, c.label_key, lang])
	TranslationServer.set_locale("ko")
	check("nothing missing", missing, [])

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _walk_to_kind(rc: RunController, kind: int) -> void:
	for attempt in 30:
		if rc.phase == RunController.Phase.EVENT:
			return
		if not _settle(rc):
			return
		var path := _path_to(rc, kind)
		if path.is_empty():
			return
		if not rc.move_to(path[0]):
			return


func _settle(rc: RunController) -> bool:
	for guard in 40:
		match rc.phase:
			RunController.Phase.EXPLORING:
				return true
			RunController.Phase.REWARD:
				rc.skip_reward()
			RunController.Phase.FIRE:
				rc.leave_fire()
			RunController.Phase.SHOP:
				rc.leave_shop()
			RunController.Phase.BATTLE:
				for handle in rc.battle.enemy_handles():
					rc.battle.combatants[handle].hp = 0
				rc.end_turn()
			_:
				return false
	return false


func _path_to(rc: RunController, kind: int) -> Array:
	var seen := {rc.map.current: true}
	var queue := [[rc.map.current, []]]
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var at: Vector2i = entry[0]
		var route: Array = entry[1]
		if not route.is_empty() and rc.map.rooms.has(at) \
				and rc.map.rooms[at].kind == kind and not rc.map.rooms[at].cleared:
			return route
		for next in MapGenerator.neighbours_of(rc.map.rooms, at):
			if seen.has(next):
				continue
			seen[next] = true
			queue.append([next, route + [next]])
	return []
