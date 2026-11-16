class_name Room
extends RefCounted


enum Kind { START, EMPTY, COMBAT, ELITE, EVENT, SHOP, FIRE, BOSS }

var coord := Vector2i.ZERO
var kind := Kind.EMPTY

var encounter_id := &""
var morning_encounter_id := &""
var evening_encounter_id := &""
var night_encounter_id := &""

## Who joins this room's enemy when the room is far enough out not to be alone.
## Empty for a room that is. One more than the fight needs — see
## EncounterTable.draw_companions().
var companions: Array[StringName] = []

var exits := {}

var visited := false

var cleared := false

## A fire's actions already taken here (RunState.FireAction). Each can be taken
## once; the fire goes out when the Warden leaves having taken any.
var fire_used: Array[int] = []


func _written_exits() -> Array:
	var out := []
	var steps := exits.keys()
	steps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)
	for step in steps:
		out.append([step.x, step.y, int(exits[step])])
	return out


func encounter_for(sky: int) -> StringName:
	var chosen := &""
	match sky:
		RunClock.Daytime.MORNING:
			chosen = morning_encounter_id
		RunClock.Daytime.EVENING:
			chosen = evening_encounter_id
		RunClock.Daytime.NIGHT:
			chosen = night_encounter_id
	return chosen if chosen != &"" else encounter_id


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
		"morning_encounter_id": String(morning_encounter_id),
		"evening_encounter_id": String(evening_encounter_id),
		"night_encounter_id": String(night_encounter_id),
		"companions": companions.map(func(id: StringName) -> String: return String(id)),
		"exits": _written_exits(),
		"visited": visited,
		"cleared": cleared,
		"fire_used": Array(fire_used),
	}


static func from_dict(data: Dictionary) -> Room:
	var out := Room.new()
	out.coord = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	out.kind = int(data.get("kind", Kind.EMPTY)) as Kind
	out.encounter_id = StringName(data.get("encounter_id", ""))
	out.morning_encounter_id = StringName(data.get("morning_encounter_id", ""))
	out.evening_encounter_id = StringName(data.get("evening_encounter_id", ""))
	out.night_encounter_id = StringName(data.get("night_encounter_id", ""))
	for id in data.get("companions", []):
		out.companions.append(StringName(id))
	for entry in data.get("exits", []):
		if entry.size() >= 3:
			out.exits[Vector2i(int(entry[0]), int(entry[1]))] = int(entry[2])
	out.visited = bool(data.get("visited", false))
	out.cleared = bool(data.get("cleared", false))
	for action in data.get("fire_used", []):
		out.fire_used.append(int(action))
	return out
