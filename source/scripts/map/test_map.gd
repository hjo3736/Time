extends SceneTree


var _failures := 0
var _b: Balance
var _enemies: EnemyDatabase
var _encounters: EncounterTable


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


func floor_for(seed_value: int) -> Dictionary:
	var table := EncounterTable.new()
	table.load_from()
	return MapGenerator.generate(_b, table, rng(seed_value))


func state_for(seed_value: int) -> MapState:
	var run := RunState.new(_b, seed_value)
	return MapState.new(run, floor_for(seed_value))


func kinds(rooms: Dictionary) -> Dictionary:
	var out := {}
	for coord in rooms:
		var k: int = rooms[coord].kind
		out[k] = int(out.get(k, 0)) + 1
	return out


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_encounters = EncounterTable.new()
	_encounters.load_from()

	print("\n-- a floor is one connected piece --")
	var rooms := floor_for(1)
	var want := (2 + _b.rooms_per_act_available
		+ roundi(_b.rooms_per_act_available * 0.32)
		+ _b.fires_per_act + _b.shops_per_act + _b.elites_per_act + _b.events_per_act)
	check("room count", rooms.size(), want)
	var reached := 0
	var seen := {Vector2i.ZERO: true}
	var queue := [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		reached += 1
		for n in MapGenerator.neighbours_of(rooms, c):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	check("every room is walkable from the start", reached, rooms.size())

	print("\n-- the floor holds what it was asked for --")
	var tally := kinds(rooms)
	check("one start", int(tally.get(Room.Kind.START, 0)), 1)
	check("one boss", int(tally.get(Room.Kind.BOSS, 0)), 1)
	check("fires", int(tally.get(Room.Kind.FIRE, 0)), _b.fires_per_act)
	check("shops", int(tally.get(Room.Kind.SHOP, 0)), _b.shops_per_act)
	check("elites", int(tally.get(Room.Kind.ELITE, 0)), _b.elites_per_act)
	check("combat rooms", int(tally.get(Room.Kind.COMBAT, 0)), _b.rooms_per_act_available)
	check("events", int(tally.get(Room.Kind.EVENT, 0)), _b.events_per_act)
	check("and dead space between them", int(tally.get(Room.Kind.EMPTY, 0)) > 0, true)

	print("\n-- every combat room was given an encounter --")
	var missing := 0
	for coord in rooms:
		var r: Room = rooms[coord]
		if r.kind == Room.Kind.COMBAT and (r.encounter_id == &"" or _encounters.get_encounter(r.encounter_id) == null):
			missing += 1
	check("none unpopulated", missing, 0)

	print("\n-- more rooms exist than the budget can buy --")
	check("available beats affordable",
		int(tally.get(Room.Kind.COMBAT, 0)) > _b.rooms_per_act_affordable, true)

	print("\n-- the boss is far away, which is what makes the decision cost --")
	var ms := state_for(1)
	check("boss is not next door", ms.steps_to_boss() > 3, true)
	check("and the walk is priced", ms.minutes_to_boss() >= ms.steps_to_boss() * _b.room_cost_min, true)
	check("but no dearer than the worst case",
		ms.minutes_to_boss() <= ms.steps_to_boss() * _b.room_cost_max, true)

	print("\n-- an unwalked room costs what the map guesses, not what it is --")
	check("the far walk is an estimate", ms.boss_walk_is_guess(), true)
	var unseen := 0
	var surveyed := 0
	for coord in ms.rooms:
		if ms.is_surveyed(coord):
			surveyed += 1
		else:
			unseen += 1
			check("an unseen room is guessed at the base rate",
				ms.guessed_cost_at(coord), _b.room_transition_cost)
	check("most of the floor is still unseen", unseen > surveyed, true)

	print("\n-- rooms are not all priced the same --")
	var prices := {}
	for coord in ms.rooms:
		prices[ms.cost_at(coord)] = true
		check("%s is a whole number of hours" % str(coord),
			ms.cost_at(coord) % Balance.MINUTES_PER_HOUR, 0)
		check("%s is inside the range" % str(coord),
			ms.cost_at(coord) >= _b.room_cost_min and ms.cost_at(coord) <= _b.room_cost_max, true)
	check("more than one price exists", prices.size() > 1, true)

	print("\n-- the same seed builds the same floor --")
	var a := floor_for(4242)
	var b := floor_for(4242)
	check("same size", a.size(), b.size())
	var same := true
	for coord in a:
		if not b.has(coord) or a[coord].kind != b[coord].kind or a[coord].encounter_id != b[coord].encounter_id:
			same = false
			break
	check("identical layout and contents", same, true)
	check("a different seed differs", floor_for(4243).keys() == a.keys(), false)

	print("\n-- fog: the frontier shows its type, nothing beyond it does --")
	var fog := state_for(7)
	check("standing on the start", fog.current, Vector2i.ZERO)
	check("the start is known", fog.is_known(Vector2i.ZERO), true)
	for n in fog.neighbours(Vector2i.ZERO):
		check("neighbour %s is known" % n, fog.is_known(n), true)
	var far := 0
	for coord in fog.rooms:
		if not fog.is_known(coord):
			far += 1
	check("most of the floor is still dark", far > 0, true)

	print("\n-- the boss is marked from the first moment --")
	check("boss is known before anyone walks", fog.is_known(fog.boss_coord), true)
	check("without having been visited", fog.at(fog.boss_coord).visited, false)

	print("\n-- walking is charged at the room's own price, backtracking included --")
	var walk := state_for(11)
	var start_remaining := walk._run.clock.remaining
	var first: Vector2i = walk.neighbours(Vector2i.ZERO)[0]
	check("moved", walk.move_to(first), true)
	check("charged that room", start_remaining - walk._run.clock.remaining, walk.cost_at(first))
	check("standing there now", walk.current, first)
	check("stepping back is legal", walk.move_to(Vector2i.ZERO), true)
	check("and the start has its own price too", start_remaining - walk._run.clock.remaining,
		walk.cost_at(first) + walk.cost_at(Vector2i.ZERO))
	check("logged as travel", walk._run.clock.spent_by_source()[RunClock.Source.TRAVEL],
		walk.cost_at(first) + walk.cost_at(Vector2i.ZERO))

	print("\n-- illegal moves change nothing --")
	var before := walk._run.clock.remaining
	check("cannot teleport", walk.move_to(Vector2i(99, 99)), false)
	check("cannot skip a room", walk.move_to(Vector2i(0, 4)), false)
	check("nothing charged", walk._run.clock.remaining, before)

	print("\n-- entering reveals, and the reveal is one ring wide --")
	var reveal := state_for(3)
	var step: Vector2i = reveal.neighbours(Vector2i.ZERO)[0]
	var known_before := reveal.known_rooms().size()
	reveal.move_to(step)
	check("the frontier grew", reveal.known_rooms().size() >= known_before, true)
	for n in reveal.neighbours(step):
		check("neighbour of the new room is known %s" % n, reveal.is_known(n), true)

	print("\n-- cleared rooms stay cleared --")
	var clear := state_for(5)
	var target := Vector2i.ZERO
	for coord in clear.rooms:
		if clear.rooms[coord].kind == Room.Kind.COMBAT:
			target = coord
			break
	clear.current = target
	check("a fight is waiting", clear.current_is_spent(), false)
	clear.clear_current()
	check("now it is not", clear.current_is_spent(), true)
	check("and walking back in offers nothing", clear.at(target).cleared, true)

	print("\n-- a move can be priced before it is taken --")
	var preview := state_for(2)
	var door: Vector2i = preview.neighbours(Vector2i.ZERO)[0]
	var projected := preview.preview_move(door)
	var was := preview._run.clock.remaining
	preview.move_to(door)
	check("the preview told the truth", preview._run.clock.remaining, projected["remaining"])
	check("and it charged that door's own price",
		was - int(projected["remaining"]), preview.cost_at(door))

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
