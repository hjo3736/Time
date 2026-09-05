class_name EventTable
extends RefCounted


const DEFAULT_ROOT := "res://source/data/events"

var _by_id: Dictionary = {}
var _sorted_ids: Array[StringName] = []
var _load_problems := PackedStringArray()


func load_from(root: String = DEFAULT_ROOT) -> void:
	_by_id.clear()
	_sorted_ids.clear()
	_load_problems = PackedStringArray()

	var dir := DirAccess.open(root)
	if dir == null:
		_load_problems.append("%s: directory not found." % root)
		return

	for file in ResourceLoader.list_directory(root):
		if file.ends_with("/"):
			continue
		var res := ResourceLoader.load(root.path_join(file))
		if not (res is EventData):
			continue
		var e: EventData = res
		if e.id == &"" or _by_id.has(e.id):
			_load_problems.append("%s: missing or duplicate id." % file)
			continue
		_by_id[e.id] = e
		_sorted_ids.append(e.id)

	_sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))


func size() -> int:
	return _sorted_ids.size()


func get_event(id: StringName) -> EventData:
	return _by_id.get(id, null)


func all() -> Array[EventData]:
	var out: Array[EventData] = []
	for id in _sorted_ids:
		out.append(_by_id[id])
	return out


func candidates(act: int, seen: Array = []) -> Array[EventData]:
	var out: Array[EventData] = []
	for id in _sorted_ids:
		var e: EventData = _by_id[id]
		if e.act == act and not seen.has(e.id):
			out.append(e)
	return out


func pick(rng: RandomNumberGenerator, act: int, seen: Array = []) -> EventData:
	var pool := candidates(act, seen)
	if pool.is_empty():
		return null
	var total := 0
	for e in pool:
		total += e.weight
	var roll := rng.randi_range(1, total)
	for e in pool:
		roll -= e.weight
		if roll <= 0:
			return e
	return pool[pool.size() - 1]


func validate() -> PackedStringArray:
	var problems := _load_problems.duplicate()
	for e in all():
		problems.append_array(e.validate())
	return problems
