class_name MapGenerator
extends RefCounted


const NEIGHBOURS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

const LOOP_CHANCE := 0.18


static func generate(
	balance: Balance,
	encounters: EncounterTable,
	rng: RandomNumberGenerator,
	act: int = 1,
) -> Dictionary:
	var content := balance.content_in(act)
	var combat_rooms := rng.randi_range(balance.fights_min_in(act), balance.fights_max_in(act))
	var empty_rooms := balance.empty_in(act)
	var fires := balance.fires_in(act)
	var shops := balance.shops_in(act)
	var elites := balance.elites_in(act) if not encounters.candidates(act, EnemyStats.Tier.ELITE).is_empty() else 0
	var events := content - combat_rooms
	var total := 2 + combat_rooms + empty_rooms + fires + shops + elites + events

	var rooms := _carve(total, rng, balance.start_exits_in(act))
	_price(rooms, balance, rng)
	var distances := _distances(rooms, Vector2i.ZERO)
	var travel := _travel(rooms, Vector2i.ZERO, balance)
	_assign(rooms, distances, travel, combat_rooms, empty_rooms, fires, shops, elites, events,
		balance, encounters, rng, act)

	return rooms


static func _price(rooms: Dictionary, balance: Balance, rng: RandomNumberGenerator) -> void:
	var lo := maxi(1, balance.room_cost_min / Balance.MINUTES_PER_HOUR)
	var hi := maxi(lo, balance.room_cost_max / Balance.MINUTES_PER_HOUR)
	var order := rooms.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for coord in order:
		for step in NEIGHBOURS:
			var next: Vector2i = coord + step
			if not rooms.has(next) or rooms[coord].exits.has(step):
				continue
			var drawn := mini(rng.randi_range(lo, hi), rng.randi_range(lo, hi))
			var minutes := drawn * Balance.MINUTES_PER_HOUR
			rooms[coord].exits[step] = minutes
			rooms[next].exits[-step] = minutes


static func _carve(target: int, rng: RandomNumberGenerator,
		start_exits: int = 4) -> Dictionary:
	var rooms := {Vector2i.ZERO: _room(Vector2i.ZERO, Room.Kind.START)}

	while rooms.size() < target:
		var allow_loops := rng.randf() < LOOP_CHANCE
		var options := _candidates(rooms, allow_loops, start_exits)
		if options.is_empty():
			options = _candidates(rooms, true, start_exits)
		if options.is_empty():
			break
		var coord: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		rooms[coord] = _room(coord, Room.Kind.EMPTY)

	return rooms


static func _candidates(rooms: Dictionary, allow_loops: bool,
		start_exits: int = 4) -> Array:
	# Adjacency is the map: a room next to the start is a way out of it, whether
	# or not anything meant it to be. So capping the start's exits is a carving
	# rule, not something that can be tidied up afterwards.
	var start_is_full := neighbours_of(rooms, Vector2i.ZERO).size() >= start_exits

	var seen := {}
	for coord in rooms:
		for step in NEIGHBOURS:
			var next: Vector2i = coord + step
			if rooms.has(next):
				continue
			if start_is_full and next.distance_squared_to(Vector2i.ZERO) == 1:
				continue
			var touching := 0
			for back in NEIGHBOURS:
				if rooms.has(next + back):
					touching += 1
			if touching == 1 or (allow_loops and touching >= 1):
				seen[next] = true

	var out := seen.keys()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


static func _room(coord: Vector2i, kind: Room.Kind) -> Room:
	var r := Room.new()
	r.coord = coord
	r.kind = kind
	return r


static func neighbours_of(rooms: Dictionary, coord: Vector2i) -> Array:
	var out := []
	for step in NEIGHBOURS:
		if rooms.has(coord + step):
			out.append(coord + step)
	return out


static func _travel(rooms: Dictionary, from: Vector2i, balance: Balance) -> Dictionary:
	var best := {from: 0}
	var queue := [from]
	while not queue.is_empty():
		queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(best[a]) < int(best[b]))
		var coord: Vector2i = queue.pop_front()
		for next in neighbours_of(rooms, coord):
			var walked: int = rooms[coord].exits.get(next - coord, balance.room_transition_cost)
			var through := int(best[coord]) + walked
			if not best.has(next) or through < int(best[next]):
				best[next] = through
				queue.append(next)
	return best


static func _distances(rooms: Dictionary, from: Vector2i) -> Dictionary:
	var out := {from: 0}
	var queue := [from]
	while not queue.is_empty():
		var coord: Vector2i = queue.pop_front()
		for next in neighbours_of(rooms, coord):
			if not out.has(next):
				out[next] = int(out[coord]) + 1
				queue.append(next)
	return out


static func _assign(
	rooms: Dictionary,
	distances: Dictionary,
	travel: Dictionary,
	combat_rooms: int,
	empty_rooms: int,
	fires: int,
	shops: int,
	elites: int,
	events: int,
	balance: Balance,
	encounters: EncounterTable,
	rng: RandomNumberGenerator,
	act: int,
) -> void:
	var open := rooms.keys().filter(func(c: Vector2i) -> bool: return c != Vector2i.ZERO)
	open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := int(distances.get(a, 0))
		var db := int(distances.get(b, 0))
		if da != db:
			return da > db
		return a.y < b.y if a.y != b.y else a.x < b.x)

	var dead_ends := open.filter(func(c: Vector2i) -> bool:
		return neighbours_of(rooms, c).size() == 1)

	var boss_coord: Vector2i = dead_ends[0] if not dead_ends.is_empty() else open[0]
	rooms[boss_coord].kind = Room.Kind.BOSS
	_stock(rooms[boss_coord], encounters, rng, act, EnemyStats.Tier.BOSS)
	open.erase(boss_coord)
	dead_ends.erase(boss_coord)

	for i in fires:
		var coord: Variant = _take(dead_ends, open, rng)
		if coord != null:
			rooms[coord].kind = Room.Kind.FIRE
	for i in shops:
		var coord: Variant = _take(dead_ends, open, rng)
		if coord != null:
			rooms[coord].kind = Room.Kind.SHOP
	for i in events:
		var coord: Variant = _take(dead_ends, open, rng)
		if coord != null:
			rooms[coord].kind = Room.Kind.EVENT

	var through := open.filter(func(c: Vector2i) -> bool:
		return neighbours_of(rooms, c).size() >= 2)
	through.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(travel.get(a, 0)) > int(travel.get(b, 0)))

	var spacing := {}
	for coord in through:
		spacing[coord] = _travel(rooms, coord, balance)

	var settled: Array[Vector2i] = []
	for i in elites:
		var spread_out := through.filter(func(c: Vector2i) -> bool:
			return _clear_of(spacing, settled, c, balance.elite_min_travel_apart))
		var deep := spread_out.filter(func(c: Vector2i) -> bool:
			return int(travel.get(c, 0)) >= balance.elite_min_travel_from_start)
		var viable := deep.filter(func(c: Vector2i) -> bool:
			return _leaves_room(deep, spacing, c, elites - i - 1,
				balance.elite_min_travel_apart))

		var coord: Variant = null
		if not viable.is_empty():
			coord = viable[rng.randi_range(0, viable.size() - 1)]
		elif not deep.is_empty():
			coord = deep[rng.randi_range(0, deep.size() - 1)]
		elif not spread_out.is_empty():
			coord = spread_out[0]
		elif not through.is_empty():
			coord = through[0]
		else:
			coord = _take(open, open, rng)
		if coord == null:
			continue

		through.erase(coord)
		open.erase(coord)
		settled.append(coord)
		rooms[coord].kind = Room.Kind.ELITE
		_stock(rooms[coord], encounters, rng, act, EnemyStats.Tier.ELITE)

	var order := open.duplicate()
	_shuffle(order, rng)
	for i in mini(combat_rooms, order.size()):
		var room: Room = rooms[order[i]]
		room.kind = Room.Kind.COMBAT
		# Rolled only when there is something to roll, so a floor that opens on a
		# corridor spends no randomness deciding what was never in doubt.
		var chance := balance.solo_chance_at(act, int(distances.get(order[i], 0)))
		var alone := chance >= 1.0 or (chance > 0.0 and rng.randf() < chance)
		_stock(room, encounters, rng, act, EnemyStats.Tier.NORMAL, alone)
		if not alone:
			room.companions = encounters.draw_companions(rng, act, balance.mixed_fight_size)


static func _leaves_room(pool: Array, spacing: Dictionary, chosen: Vector2i,
		still_needed: int, apart: int) -> bool:
	if still_needed <= 0:
		return true
	var taken: Array[Vector2i] = [chosen]
	for other in pool:
		if other == chosen:
			continue
		if not _clear_of(spacing, taken, other, apart):
			continue
		taken.append(other)
		if taken.size() > still_needed:
			return true
	return false


static func _clear_of(spacing: Dictionary, settled: Array, coord: Vector2i,
		apart: int) -> bool:
	for other in settled:
		var reach: Dictionary = spacing[other]
		if int(reach.get(coord, 0)) < apart:
			return false
	return true


static func _stock(room: Room, encounters: EncounterTable, rng: RandomNumberGenerator,
		act: int, tier: EnemyStats.Tier, alone: bool = false) -> void:
	var by_day := encounters.pick(rng, act, tier, false, RunClock.Daytime.DAY, alone)
	if by_day != null:
		room.encounter_id = by_day.id
	var by_morning := encounters.pick(rng, act, tier, false, RunClock.Daytime.MORNING, alone)
	if by_morning != null:
		room.morning_encounter_id = by_morning.id
	var by_evening := encounters.pick(rng, act, tier, false, RunClock.Daytime.EVENING, alone)
	if by_evening != null:
		room.evening_encounter_id = by_evening.id
	var by_night := encounters.pick(rng, act, tier, false, RunClock.Daytime.NIGHT, alone)
	if by_night != null:
		room.night_encounter_id = by_night.id


static func _take(preferred: Array, fallback: Array, rng: RandomNumberGenerator) -> Variant:
	var pool: Array = preferred if not preferred.is_empty() else fallback
	if pool.is_empty():
		return null
	var coord = pool[rng.randi_range(0, pool.size() - 1)]
	preferred.erase(coord)
	fallback.erase(coord)
	return coord


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
