class_name Room
extends RefCounted


enum Kind { START, EMPTY, COMBAT, ELITE, EVENT, SHOP, FIRE, BOSS }

var coord := Vector2i.ZERO
var kind := Kind.EMPTY

var encounter_id := &""

var exits := {}

var visited := false

var cleared := false


func _written_exits() -> Array:
	var out := []
	var steps := exits.keys()
	steps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for step in steps:
		out.append([step.x, step.y, int(exits[step])])
	return out


func is_hostile() -> bool:
	return kind == Kind.COMBAT or kind == Kind.ELITE or kind == Kind.BOSS


func is_spent() -> bool:
	match kind:
		Kind.START, Kind.EMPTY:
			return true
		_:
			return cleared


func to_dict() -> Dictionary:
	return {
		"x": coord.x,
		"y": coord.y,
		"kind": kind,
		"encounter_id": String(encounter_id),
		"exits": _written_exits(),
		"visited": visited,
		"cleared": cleared,
	}


static func from_dict(data: Dictionary) -> Room:
	var out := Room.new()
	out.coord = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	out.kind = int(data.get("kind", Kind.EMPTY))
	out.encounter_id = StringName(data.get("encounter_id", ""))
	for entry in data.get("exits", []):
		if entry.size() >= 3:
			out.exits[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	out.visited = bool(data.get("visited", false))
	out.cleared = bool(data.get("cleared", false))
	return out
