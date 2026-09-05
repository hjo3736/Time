class_name EnemyDatabase
extends RefCounted


const DEFAULT_ROOT := "res://source/data/enemies"

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
		if not (res is EnemyData):
			continue
		var e: EnemyData = res
		if e.id == &"":
			_load_problems.append("%s: enemy has no id." % file)
			continue
		if _by_id.has(e.id):
			_load_problems.append("%s: duplicate id '%s'." % [file, e.id])
			continue
		_by_id[e.id] = e

	_sorted_ids.assign(_by_id.keys())
	_sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))


func size() -> int:
	return _by_id.size()


func has(id: StringName) -> bool:
	return _by_id.has(id)


func get_enemy(id: StringName) -> EnemyData:
	return _by_id.get(id)


func all() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id in _sorted_ids:
		out.append(_by_id[id])
	return out


func of_tier(tier: EnemyData.Tier) -> Array[EnemyData]:
	return all().filter(func(e: EnemyData) -> bool: return e.tier == tier)


func validate() -> PackedStringArray:
	var problems := _load_problems.duplicate()
	if _by_id.is_empty():
		problems.append("Enemy database is empty.")
	for e in all():
		problems.append_array(e.validate())
	return problems
