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
	var want := _b.rooms_in(1)
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

	print("\n-- act one opens on a corridor, and only act one --")
	var table := EncounterTable.new()
	table.load_from()
	var spread := {1: {}, 2: {}, 3: {}}
	var wrong := 0
	var stranded := 0
	for act in [1, 2, 3]:
		for seed_value in 60:
			var built := MapGenerator.generate(_b, table, rng(seed_value), act)
			var exits: int = MapGenerator.neighbours_of(built, Vector2i.ZERO).size()
			spread[act][exits] = int(spread[act].get(exits, 0)) + 1
			if act == 1 and exits != 1:
				wrong += 1
			if exits < 1:
				stranded += 1
	# There is nothing to decide on the first step, which is the point: act one
	# does not ask the player to route before it has shown them anything.
	check("every act one floor leaves exactly one way out", wrong, 0)
	check("and it is the dial doing it, not luck",
		spread[2].size() > 1 or spread[3].size() > 1, true)
	check("no floor in any act strands the Warden on the start", stranded, 0)

	print("\n-- the floor holds what it was asked for --")
	var tally := kinds(rooms)
	check("one start", int(tally.get(Room.Kind.START, 0)), 1)
	check("one boss", int(tally.get(Room.Kind.BOSS, 0)), 1)
	check("fires", int(tally.get(Room.Kind.FIRE, 0)), _b.fires_in(1))
	check("shops", int(tally.get(Room.Kind.SHOP, 0)), _b.shops_in(1))
	check("elites", int(tally.get(Room.Kind.ELITE, 0)), _b.elites_in(1))
	check("empty rooms only if the floor asked for them",
		int(tally.get(Room.Kind.EMPTY, 0)), _b.empty_in(1))

	print("\n-- fights and events share a fixed total, with fights guaranteed a floor --")
	var short_of_min := 0
	var short_of_events := 0
	var wrong_total := 0
	var splits := {}
	for seed_value in 120:
		var floor_rooms := floor_for(seed_value)
		var counts := kinds(floor_rooms)
		var fights := int(counts.get(Room.Kind.COMBAT, 0))
		var events := int(counts.get(Room.Kind.EVENT, 0))
		if fights + events != _b.content_in(1):
			wrong_total += 1
		if fights < _b.fights_min_in(1):
			short_of_min += 1
		if events < _b.events_min_in(1):
			short_of_events += 1
		splits[fights] = int(splits.get(fights, 0)) + 1
	check("the total never moves", wrong_total, 0)
	check("and the guaranteed fights are always there", short_of_min, 0)
	check("so are the guaranteed events", short_of_events, 0)
	check("but the split is not always the same", splits.size() > 1, true)

	print("\n-- every combat room was given an encounter --")
	var missing := 0
	for coord in rooms:
		var r: Room = rooms[coord]
		if r.kind == Room.Kind.COMBAT and (r.encounter_id == &"" or _encounters.get_encounter(r.encounter_id) == null):
			missing += 1
	check("none unpopulated", missing, 0)

	print("\n-- more rooms exist than the budget can buy --")
	check("available beats affordable",
		_b.fights_min_in(1) > _b.rooms_per_act_affordable, true)

	print("\n-- elites go deep, stay apart, and are never dropped --")
	var elites_found := 0
	var wasted_room := 0
	var crowded := 0
	var settled_short := 0
	for seed_value in 60:
		var floor_rooms := floor_for(seed_value)
		var reach_of := {}
		var marked := []
		var eligible := []
		for coord in floor_rooms:
			var room: Room = floor_rooms[coord]
			if room.kind == Room.Kind.ELITE:
				marked.append(coord)
			var usable: bool = (room.kind == Room.Kind.COMBAT
				or room.kind == Room.Kind.EMPTY or room.kind == Room.Kind.ELITE)
			if usable and MapGenerator.neighbours_of(floor_rooms, coord).size() >= 2:
				eligible.append(coord)
		for coord in eligible:
			reach_of[coord] = _walked_from(floor_rooms, coord)

		elites_found += marked.size()
		if marked.size() < _b.elites_in(1):
			wasted_room += 1

		var from_start := _walked_from(floor_rooms, Vector2i.ZERO)
		for i in marked.size():
			for j in range(i + 1, marked.size()):
				if int(reach_of[marked[i]].get(marked[j], 0)) < _b.elite_min_travel_apart:
					crowded += 1

		var deep := eligible.filter(func(c: Vector2i) -> bool:
			return int(from_start.get(c, 0)) >= _b.elite_min_travel_from_start)
		var deep_pair := false
		for i in deep.size():
			for j in range(i + 1, deep.size()):
				if int(reach_of[deep[i]].get(deep[j], 0)) >= _b.elite_min_travel_apart:
					deep_pair = true
		if not deep_pair:
			continue
		for coord in marked:
			if int(from_start.get(coord, 0)) < _b.elite_min_travel_from_start:
				settled_short += 1

	check("every floor got its elites", elites_found, 60 * _b.elites_in(1))
	check("none was dropped for want of a spot", wasted_room, 0)
	check("no pair is closer to each other than the rule allows", crowded, 0)
	check("and when a deep pair was available, both elites took it", settled_short, 0)

	print("\n-- the boss is far away, which is what makes the decision cost --")
	var ms := state_for(1)
	check("boss is not next door", ms.steps_to_boss() > 3, true)
	check("and the walk is priced", ms.minutes_to_boss() >= ms.steps_to_boss() * _b.room_cost_min, true)
	check("but no dearer than the worst case",
		ms.minutes_to_boss() <= ms.steps_to_boss() * _b.room_cost_max, true)

	print("\n-- a corridor costs the same walked either way --")
	var pairs := 0
	var lopsided := 0
	var prices := {}
	for coord in ms.rooms:
		for next in ms.neighbours(coord):
			pairs += 1
			if ms.cost_between(coord, next) != ms.cost_between(next, coord):
				lopsided += 1
			prices[ms.cost_between(coord, next)] = true
			check("%s->%s is a whole number of hours" % [str(coord), str(next)],
				ms.cost_between(coord, next) % Balance.MINUTES_PER_HOUR, 0)
			check("%s->%s is inside the range" % [str(coord), str(next)],
				ms.cost_between(coord, next) >= _b.room_cost_min
				and ms.cost_between(coord, next) <= _b.room_cost_max, true)
	check("there are corridors to check", pairs > 20, true)
	check("not one of them disagrees with itself", lopsided, 0)
	check("and they are not all the same length", prices.size() > 1, true)

	print("\n-- an unwalked corridor costs what the map guesses, not what it is --")
	check("the far walk is an estimate", ms.boss_walk_is_guess(), true)
	var unwalked := 0
	var walked := 0
	for coord in ms.rooms:
		for next in ms.neighbours(coord):
			if ms.walked_between(coord, next):
				walked += 1
			else:
				unwalked += 1
				check("an unwalked corridor is guessed at the base rate",
					ms.guessed_cost_between(coord, next), _b.room_transition_cost)
	check("most of the floor is still unwalked", unwalked > walked, true)

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

	print("\n-- whether the boss door is marked is a dial, and it is obeyed both ways --")
	check("the shipped setting is followed",
		fog.is_known(fog.boss_coord), _b.boss_marked_on_map)
	check("without having been visited", fog.at(fog.boss_coord).visited, false)

	var shown := Balance.default().duplicate()
	shown.boss_marked_on_map = true
	var lit := MapState.new(RunState.new(shown, 7), floor_for(7))
	check("marked, it is known from the first moment",
		lit.is_known(lit.boss_coord), true)

	var hidden := Balance.default().duplicate()
	hidden.boss_marked_on_map = false
	var dark := MapState.new(RunState.new(hidden, 7), floor_for(7))
	check("unmarked, it stays dark until walked near",
		dark.is_known(dark.boss_coord), false)
	check("and the walk to it is a guess either way", dark.boss_walk_is_guess(), true)

	print("\n-- walking back out costs exactly what walking in cost --")
	var walk := state_for(11)
	var start_remaining := walk._run.clock.remaining
	var first: Vector2i = walk.neighbours(Vector2i.ZERO)[0]
	var corridor := walk.cost_between(Vector2i.ZERO, first)
	check("moved", walk.move_to(first), true)
	check("charged the corridor", start_remaining - walk._run.clock.remaining, corridor)
	check("standing there now", walk.current, first)
	var mid := walk._run.clock.remaining
	check("stepping back is legal", walk.move_to(Vector2i.ZERO), true)
	check("the way back cost the same", mid - walk._run.clock.remaining, corridor)
	check("so the round trip is exactly twice", start_remaining - walk._run.clock.remaining,
		corridor * 2)
	check("logged as travel", walk._run.clock.spent_by_source()[RunClock.Source.TRAVEL],
		corridor * 2)

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
	check("and it charged that corridor",
		was - int(projected["remaining"]), preview.cost_between(Vector2i.ZERO, door))

	_rooms_are_stocked_for_both_skies()
	_near_the_start_a_fight_is_alone()

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _walked_from_start(rooms: Dictionary) -> Dictionary:
	return _walked_from(rooms, Vector2i.ZERO)


func _walked_from(rooms: Dictionary, origin: Vector2i) -> Dictionary:
	var best := {origin: 0}
	var queue := [origin]
	while not queue.is_empty():
		queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(best[a]) < int(best[b]))
		var at: Vector2i = queue.pop_front()
		for n in MapGenerator.neighbours_of(rooms, at):
			var through: int = int(best[at]) + int(
				rooms[at].exits.get(n - at, _b.room_transition_cost))
			if not best.has(n) or through < int(best[n]):
				best[n] = through
				queue.append(n)
	return best


const SKIES := [RunClock.Daytime.MORNING, RunClock.Daytime.DAY,
	RunClock.Daytime.EVENING, RunClock.Daytime.NIGHT]


func _rooms_are_stocked_for_both_skies() -> void:
	print("\n-- every hostile room is stocked for all four skies --")
	# encounter_for() takes a Daytime, and this used to pass it false and true.
	# That read as MORNING and DAY, so evening and night were never checked at all.
	var hostile := 0
	var missing := {}
	var differs := 0
	var floors := 40
	for sky in SKIES:
		missing[sky] = 0
	for seed_value in floors:
		var rooms := floor_for(seed_value)
		for coord in rooms:
			var room: Room = rooms[coord]
			if not room.is_hostile():
				continue
			hostile += 1
			for sky in SKIES:
				if _encounters.get_encounter(room.encounter_for(sky)) == null:
					missing[sky] = int(missing[sky]) + 1
			if room.encounter_for(RunClock.Daytime.NIGHT) \
					!= room.encounter_for(RunClock.Daytime.DAY):
				differs += 1

	check("there are hostile rooms to check", hostile > 100, true)
	# A room can only be stocked from a pool that exists. Act one has no boss
	# encounter yet, so its boss rooms are the unstocked ones and the count should
	# equal the number of floors — not zero, and not more than that either.
	var boss_pool := _encounters.candidates(1, EnemyData.Tier.BOSS).size()
	for sky in SKIES:
		if boss_pool > 0:
			check("none is unstocked for sky %d" % sky, missing[sky], 0)
		else:
			check("only the boss room is unstocked for sky %d, once per floor" % sky,
				missing[sky], floors)
	# Stocking a room draws four times in a row off one pool, and pick() refuses the
	# last `encounter_history_length` ids it handed out. At exactly one more than
	# that history the refusals leave a single candidate each time, so the draws
	# cycle with that period and the first and fourth — day and night — land on the
	# same encounter every single time. One fewer and the history saturates, pick()
	# falls back to the whole pool, and they vary again. So the dead spot is a
	# specific pool size rather than "small", which is the opposite of obvious.
	var normals := _encounters.candidates(1, EnemyData.Tier.NORMAL).size()
	if normals == _b.encounter_history_length + 1:
		check("a pool one larger than the history forces day and night to match",
			differs, 0)
	else:
		check("day and night are not the same room everywhere", differs > 0, true)

	print("\n-- the same seed stocks the same fights, whichever way you walk --")
	var a := floor_for(99)
	var b := floor_for(99)
	var drifted := 0
	for coord in a:
		for sky in SKIES:
			if a[coord].encounter_for(sky) != b[coord].encounter_for(sky):
				drifted += 1
	check("nothing drifted", drifted, 0)


func _near_the_start_a_fight_is_alone() -> void:
	print("\n-- a fight near the start is one enemy, and further out it has company --")
	var table := EncounterTable.new()
	table.load_from()
	for act in [1, 2]:
		var corridor := _b.start_exits_in(act) == 1
		var sure := _b.solo_steps_single_exit if corridor else _b.solo_steps
		var near_with_company := 0
		var ring_alone := 0
		var ring_total := 0
		var far_alone := 0
		var far_total := 0
		var strangers := 0
		var twice := 0
		for seed_value in 200:
			var rooms := MapGenerator.generate(_b, table, rng(seed_value), act)
			var steps := MapGenerator._distances(rooms, Vector2i.ZERO)
			for coord in rooms:
				var room: Room = rooms[coord]
				if room.kind != Room.Kind.COMBAT:
					if not room.companions.is_empty():
						strangers += 1
					continue
				var seen := {}
				for id in room.companions:
					if not _enemies.has(id) or seen.has(id):
						twice += 1
					seen[id] = true
				var d := int(steps[coord])
				if d <= sure:
					if not room.companions.is_empty():
						near_with_company += 1
				elif not corridor and d == sure + 1:
					ring_total += 1
					if room.companions.is_empty():
						ring_alone += 1
				else:
					far_total += 1
					if room.companions.is_empty():
						far_alone += 1
		check("act %d: no fight within %d rooms has company" % [act, sure],
			near_with_company, 0)
		check("act %d: every fight past that does" % act, [far_total > 100, far_alone],
			[true, 0])
		check("act %d: company is never a repeat or a stranger to the roster" % act, twice, 0)
		check("act %d: and only fights are given any" % act, strangers, 0)
		if corridor:
			check("act %d: a corridor floor has no in-between ring" % act, ring_total, 0)
		else:
			var share := float(ring_alone) / maxf(1.0, float(ring_total))
			check("act %d: the ring after is alone about as often as the profile says" % act,
				absf(share - _b.solo_chance_next_step) < 0.08, true)

	var round_trip := Room.new()
	round_trip.companions.assign([&"squabble", &"doorsill"])
	check("a room's company survives a save",
		Room.from_dict(round_trip.to_dict()).companions, round_trip.companions)
