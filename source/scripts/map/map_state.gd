class_name MapState
extends RefCounted


signal moved(coord: Vector2i)
signal room_revealed(coord: Vector2i)
signal room_cleared(coord: Vector2i)

var rooms: Dictionary = {}
var current := Vector2i.ZERO
var boss_coord := Vector2i.ZERO

var _run: RunState


func _init(run: RunState, generated: Dictionary) -> void:
	_run = run
	rooms = generated
	for coord in rooms:
		if rooms[coord].kind == Room.Kind.BOSS:
			boss_coord = coord
	current = Vector2i.ZERO
	at(current).visited = true


func at(coord: Vector2i) -> Room:
	return rooms.get(coord)


func neighbours(coord: Vector2i) -> Array:
	return MapGenerator.neighbours_of(rooms, coord)


func is_surveyed(coord: Vector2i) -> bool:
	if not rooms.has(coord):
		return false
	if rooms[coord].visited:
		return true
	for next in neighbours(coord):
		if rooms[next].visited:
			return true
	return false


func is_known(coord: Vector2i) -> bool:
	if not rooms.has(coord):
		return false
	if coord == boss_coord and _run.clock.balance.boss_marked_on_map:
		return true
	return is_surveyed(coord)


func known_rooms() -> Array:
	var out := rooms.keys().filter(func(c: Vector2i) -> bool: return is_known(c))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


func reachable() -> Array:
	return neighbours(current)


func cost_between(from: Vector2i, to: Vector2i) -> int:
	var room: Room = rooms.get(from)
	if room == null:
		return _run.clock.balance.room_transition_cost
	return int(room.exits.get(to - from, _run.clock.balance.room_transition_cost))


func priced_cost_between(from: Vector2i, to: Vector2i) -> int:
	return _run.relic_room_cost(cost_between(from, to))


func priced_cost_to(coord: Vector2i) -> int:
	return priced_cost_between(current, coord)


func walked_between(from: Vector2i, to: Vector2i) -> bool:
	return rooms.has(from) and rooms.has(to) \
		and (rooms[from].visited or rooms[to].visited)


func guessed_cost_between(from: Vector2i, to: Vector2i) -> int:
	if walked_between(from, to):
		return cost_between(from, to)
	return _run.clock.balance.room_transition_cost


func guessed_priced_between(from: Vector2i, to: Vector2i) -> int:
	return _run.relic_room_cost(guessed_cost_between(from, to))


func preview_move(coord: Vector2i = Vector2i.ZERO) -> Dictionary:
	if not rooms.has(coord):
		return _run.clock.project(_run.relic_room_cost(_run.clock.balance.room_transition_cost))
	return _run.clock.project(priced_cost_to(coord))


func move_to(coord: Vector2i) -> bool:
	if not rooms.has(coord) or not neighbours(current).has(coord):
		return false

	_run.skip_reward()

	var walked := cost_between(current, coord)
	current = coord
	_run.enter_room(StringName(str(coord)), walked)

	var room: Room = rooms[coord]
	var first_time := not room.visited
	room.visited = true

	moved.emit(coord)
	if first_time:
		room_revealed.emit(coord)
		for next in neighbours(coord):
			room_revealed.emit(next)
	return true


func clear_current() -> void:
	var room: Room = at(current)
	if room == null or room.cleared:
		return
	room.cleared = true
	room_cleared.emit(current)


func current_is_spent() -> bool:
	var room := at(current)
	return room == null or room.is_spent()


func count_of(kind: Room.Kind) -> int:
	var n := 0
	for coord in rooms:
		if rooms[coord].kind == kind:
			n += 1
	return n


# The three boss-walk queries below answer questions about a generated floor and
# are read by tests and tools. None of them may reach the player: how far the boss
# door is, is not information the run gives out. See the fog section of
# docs/time-system.md.
func steps_to_boss() -> int:
	var seen := {current: 0}
	var queue := [current]
	while not queue.is_empty():
		var coord: Vector2i = queue.pop_front()
		if coord == boss_coord:
			return int(seen[coord])
		for next in neighbours(coord):
			if not seen.has(next):
				seen[next] = int(seen[coord]) + 1
				queue.append(next)
	return -1


func minutes_to_boss() -> int:
	return int(_walk_to_boss()["minutes"])


func boss_walk_is_guess() -> bool:
	return bool(_walk_to_boss()["guessed"])


func _walk_to_boss() -> Dictionary:
	var unreachable := {"minutes": -1, "guessed": false}
	if not rooms.has(boss_coord):
		return unreachable
	var best := {current: 0}
	var guessed := {current: false}
	var queue := [current]
	while not queue.is_empty():
		queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return int(best[a]) < int(best[b]))
		var coord: Vector2i = queue.pop_front()
		for next in neighbours(coord):
			var through := int(best[coord]) + _run.relic_room_cost(guessed_cost_between(coord, next))
			if not best.has(next) or through < int(best[next]):
				best[next] = through
				guessed[next] = bool(guessed[coord]) or not walked_between(coord, next)
				queue.append(next)
	if not best.has(boss_coord):
		return unreachable
	return {"minutes": int(best[boss_coord]), "guessed": bool(guessed[boss_coord])}


func to_dict() -> Dictionary:
	var written := []
	for coord in rooms:
		written.append(rooms[coord].to_dict())
	return {"rooms": written, "cx": current.x, "cy": current.y}


static func from_dict(data: Dictionary, run: RunState) -> MapState:
	var built := {}
	for entry in data.get("rooms", []):
		var room := Room.from_dict(entry)
		built[room.coord] = room
	var out := MapState.new(run, built)
	out.current = Vector2i(int(data.get("cx", 0)), int(data.get("cy", 0)))
	for entry in data.get("rooms", []):
		var coord := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if out.rooms.has(coord):
			out.rooms[coord].visited = bool(entry.get("visited", false))
	return out
