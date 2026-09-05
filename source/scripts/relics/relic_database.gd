class_name RelicDatabase
extends RefCounted


const DEFAULT_ROOT := "res://source/data/relics"

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
		if not (res is Relic):
			continue
		var r: Relic = res
		if r.id == &"" or _by_id.has(r.id):
			_load_problems.append("%s: missing or duplicate id." % file)
			continue
		_by_id[r.id] = r

	_sorted_ids.assign(_by_id.keys())
	_sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))


func size() -> int:
	return _by_id.size()


func has(id: StringName) -> bool:
	return _by_id.has(id)


func get_relic(id: StringName) -> Relic:
	return _by_id.get(id)


func all() -> Array[Relic]:
	var out: Array[Relic] = []
	for id in _sorted_ids:
		out.append(_by_id[id])
	return out


func validate() -> PackedStringArray:
	var problems := _load_problems.duplicate()
	if _by_id.is_empty():
		problems.append("Relic database is empty.")
	for r in all():
		problems.append_array(r.validate())
	return problems
