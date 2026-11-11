class_name CardDatabase
extends RefCounted


const DEFAULT_ROOT := "res://source/data/cards"

## Cards taken out of the pool while it is rebuilt. Nothing in the game loads
## this. The tests do: they need a card that draws, one that strikes everything,
## one that exhausts, and so on, to exercise the machinery, and the machinery is
## not on the shelf even though the cards that showed it off are.
const SHELF_ROOT := "res://source/data/cards_shelved"

## Cards that exist only for the tests: something that refunds time, draws and
## exhausts, kept apart so redesigning a real card never takes the machinery's
## test case with it. Ids begin with `fixture_`.
const FIXTURE_ROOT := "res://source/data/cards_fixtures"

## What a test suite reads besides the pool.
const TEST_ROOTS: Array[String] = [SHELF_ROOT, FIXTURE_ROOT]

## Extra directories read whenever the default one is. Empty in the game. A var
## for the same reason SaveGame.path is: a suite sets it once and every database
## built anywhere under that suite — a screen builds its own — sees the same
## cards.
static var fixture_roots: PackedStringArray = []

var _by_id: Dictionary = {}
var _sorted_ids: Array[StringName] = []
var _upgrade_cache: Dictionary = {}
var _load_problems := PackedStringArray()


func load_from(root: String = DEFAULT_ROOT) -> void:
	_by_id.clear()
	_sorted_ids.clear()
	_upgrade_cache.clear()
	_load_problems = PackedStringArray()

	var paths := _resource_paths(root)
	if root == DEFAULT_ROOT:
		for extra in fixture_roots:
			paths.append_array(_resource_paths(extra))
	for path in paths:
		var res := ResourceLoader.load(path)
		if res == null:
			_load_problems.append("%s: failed to load." % path)
			continue
		if not (res is CardData):
			continue
		var card: CardData = res
		if card.id == &"":
			_load_problems.append("%s: card has no id." % path)
			continue
		if _by_id.has(card.id):
			_load_problems.append("%s: duplicate id '%s'." % [path, card.id])
			continue
		_by_id[card.id] = card

	_sorted_ids.assign(_by_id.keys())
	_sorted_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))


func _resource_paths(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		_load_problems.append("%s: directory not found." % root)
		return found

	for file in ResourceLoader.list_directory(root):
		if file.ends_with("/"):
			found.append_array(_resource_paths(root.path_join(file.trim_suffix("/"))))
		else:
			found.append(root.path_join(file))
	return found


func size() -> int:
	return _by_id.size()


func has(id: StringName) -> bool:
	return _by_id.has(id)


func get_card(id: StringName, upgrade_level: int = 0) -> CardData:
	if not _by_id.has(id):
		return null
	var base: CardData = _by_id[id]
	if upgrade_level <= 0:
		return base

	var key := "%s@%d" % [id, upgrade_level]
	if not _upgrade_cache.has(key):
		_upgrade_cache[key] = get_card(id, upgrade_level-1).upgraded()
	return _upgrade_cache[key]


func all() -> Array[CardData]:
	var out: Array[CardData] = []
	for id in _sorted_ids:
		out.append(_by_id[id])
	return out


func filter(query: Dictionary = {}) -> Array[CardData]:
	var out: Array[CardData] = []
	for card in all():
		if query.has("class_id") and card.class_id != query["class_id"]:
			continue
		if query.has("lane") and not card.in_lane(query["lane"]):
			continue
		if query.has("rarity") and card.rarity != query["rarity"]:
			continue
		if query.has("kind") and card.kind != query["kind"]:
			continue
		if query.has("unlocked") and not (query["unlocked"] as Array).has(card.id):
			continue
		if query.has("exclude") and (query["exclude"] as Array).has(card.id):
			continue
		out.append(card)
	return out


func pick(rng: RandomNumberGenerator, count: int, query: Dictionary = {}) -> Array[CardData]:
	var pool := filter(query)
	var out: Array[CardData] = []
	for i in mini(count, pool.size()):
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func validate() -> PackedStringArray:
	var problems := _load_problems.duplicate()

	if _by_id.is_empty():
		problems.append("Card database is empty.")

	for card in all():
		problems.append_array(card.validate())

	return problems
