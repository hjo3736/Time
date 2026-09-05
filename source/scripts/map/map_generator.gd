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
	var combat_rooms: int = balance.rooms_per_act_available
	var empty_rooms: int = maxi(1, roundi(combat_rooms * 0.32))
	var fires: int = balance.fires_per_act
	var shops: int = balance.shops_per_act
	var elites: int = balance.elites_per_act if not encounters.candidates(act, EnemyData.Tier.ELITE).is_empty() else 0
	var events: int = balance.events_per_act
	var total := 2 + combat_rooms + empty_rooms + fires + shops + elites + events

	var rooms := _carve(total, rng)
	_price(rooms, balance, rng)
	var distances := _distances(rooms, Vector2i.ZERO)
	_assign(rooms, distances, combat_rooms, empty_rooms, fires, shops, elites, events, encounters, rng, act)

	return rooms


static func _price(rooms: Dictionary, balance: Balance, rng: RandomNumberGenerator) -> void:
	var lo := maxi(1, balance.room_cost_min / Balance.MINUTES_PER_HOUR)
	var hi := maxi(lo, balance.room_cost_max / Balance.MINUTES_PER_HOUR)
	var order := rooms.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for coord in order:
		var drawn := mini(rng.randi_range(lo, hi), rng.randi_range(lo, hi))
		rooms[coord].cost = drawn * Balance.MINUTES_PER_HOUR


static func _carve(target: int, rng: RandomNumberGenerator) -> Dictionary:
	var rooms := {Vector2i.ZERO: _room(Vector2i.ZERO, Room.Kind.START)}

	while rooms.size() < target:
		var allow_loops := rng.randf() < LOOP_CHANCE
		var options := _candidates(rooms, allow_loops)
		if options.is_empty():
			options = _candidates(rooms, true)
		if options.is_empty():
			break
		var coord: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		rooms[coord] = _room(coord, Room.Kind.EMPTY)

	return rooms


static func _candidates(rooms: Dictionary, allow_loops: bool) -> Array:
	var seen := {}
	for coord in rooms:
		for step in NEIGHBOURS:
			var next: Vector2i = coord + step
			if rooms.has(next):
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
	combat_rooms: int,
	empty_rooms: int,
	fires: int,
	shops: int,
	elites: int,
	events: int,
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
	var boss_encounter := encounters.pick(rng, act, EnemyData.Tier.BOSS)
	if boss_encounter != null:
		rooms[boss_coord].encounter_id = boss_encounter.id
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
	for i in elites:
		var coord: Variant = _take(through, open, rng)
		if coord == null:
			continue
		rooms[coord].kind = Room.Kind.ELITE
		var elite := encounters.pick(rng, act, EnemyData.Tier.ELITE)
		if elite != null:
			rooms[coord].encounter_id = elite.id

	var order := open.duplicate()
	_shuffle(order, rng)
	for i in mini(combat_rooms, order.size()):
		var room: Room = rooms[order[i]]
		room.kind = Room.Kind.COMBAT
		var encounter := encounters.pick(rng, act, EnemyData.Tier.NORMAL)
		if encounter != null:
			room.encounter_id = encounter.id


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
