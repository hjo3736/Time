class_name RelicDatabase
extends RefCounted


const DEFAULT_ROOT := "res://source/relics"

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

	for file in _resource_files(root):
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


## Every resource file under root, subfolders included (each relic has its own
## folder), as paths relative to root.
static func _resource_files(root: String) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in ResourceLoader.list_directory(root):
		if entry.ends_with("/"):
			for inner in _resource_files(root.path_join(entry)):
				out.append(entry.path_join(inner))
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			out.append(entry)
	return out


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


func of_rarity(rarity: Relic.Rarity, owned: Array = []) -> Array[Relic]:
	var out: Array[Relic] = []
	for r in all():
		if r.rarity == rarity and not owned.has(r.id):
			out.append(r)
	return out


static func rarity_for(balance: Balance, rng: RandomNumberGenerator) -> Relic.Rarity:
	var total := (balance.reward_weight_common + balance.reward_weight_uncommon
		+ balance.reward_weight_rare)
	var drawn := rng.randi_range(1, maxi(1, total))
	if drawn <= balance.reward_weight_common:
		return Relic.Rarity.COMMON
	if drawn <= balance.reward_weight_common + balance.reward_weight_uncommon:
		return Relic.Rarity.UNCOMMON
	return Relic.Rarity.RARE


## The general table. BOSS is deliberately absent: those are handed out by act
## bosses and by nothing else, so no roll can put one in a shop.
func roll(rng: RandomNumberGenerator, balance: Balance, owned: Array = []) -> Relic:
	var wanted := rarity_for(balance, rng)
	for candidate in [wanted, Relic.Rarity.COMMON, Relic.Rarity.UNCOMMON, Relic.Rarity.RARE]:
		var pool := of_rarity(candidate, owned)
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
	return null


func roll_boss(rng: RandomNumberGenerator, owned: Array = []) -> Relic:
	var pool := of_rarity(Relic.Rarity.BOSS, owned)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


func validate() -> PackedStringArray:
	var problems := _load_problems.duplicate()
	if _by_id.is_empty():
		problems.append("Relic database is empty.")
	for r in all():
		problems.append_array(r.validate())
	return problems
