class_name EncounterTable
extends RefCounted


const DEFAULT_ROOT := "res://source/data/encounters"

var _all: Array[EncounterData] = []
var _by_id: Dictionary = {}
var _load_problems := PackedStringArray()
var _recent: Array[StringName] = []


func load_from(root: String = DEFAULT_ROOT) -> void:
	_all.clear()
	_by_id.clear()
	_recent.clear()
	_load_problems = PackedStringArray()

	var dir := DirAccess.open(root)
	if dir == null:
		_load_problems.append("%s: directory not found." % root)
		return

	for file in ResourceLoader.list_directory(root):
		if file.ends_with("/"):
			continue
		var res := ResourceLoader.load(root.path_join(file))
		if not (res is EncounterData):
			continue
		var e: EncounterData = res
		if e.id == &"" or _by_id.has(e.id):
			_load_problems.append("%s: missing or duplicate id." % file)
			continue
		_by_id[e.id] = e

	_all.assign(_by_id.values())
	_all.sort_custom(func(a: EncounterData, b: EncounterData) -> bool:
		return String(a.id) < String(b.id))


func size() -> int:
	return _all.size()


func get_encounter(id: StringName) -> EncounterData:
	return _by_id.get(id)


func candidates(act: int, tier: EnemyData.Tier, opening: bool = false) -> Array[EncounterData]:
	return _all.filter(func(e: EncounterData) -> bool:
		return e.act == act and e.tier == tier and e.opening_only == opening)


func pick(rng: RandomNumberGenerator, act: int, tier: EnemyData.Tier, opening: bool = false) -> EncounterData:
	var pool := candidates(act, tier, opening)
	if pool.is_empty():
		return null

	var fresh := pool.filter(func(e: EncounterData) -> bool: return not _recent.has(e.id))
	if not fresh.is_empty():
		pool = fresh

	var total := 0
	for e in pool:
		total += e.weight
	var roll := rng.randi_range(1, total)
	for e in pool:
		roll -= e.weight
		if roll <= 0:
			_remember(e.id)
			return e
	_remember(pool[-1].id)
	return pool[-1]


func _remember(id: StringName) -> void:
	_recent.append(id)
	var limit := 2
	while _recent.size() > limit:
		_recent.pop_front()


func set_history_length(length: int) -> void:
	while _recent.size() > length:
		_recent.pop_front()


func spawn(
	encounter: EncounterData,
	enemies: EnemyDatabase,
	balance: Balance,
	rng: RandomNumberGenerator,
	threat_level: int = 0,
) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var hp_scale := balance.enemy_hp_scale * (1.0 + threat_level * balance.threat_hp_bonus_per_step)
	var damage_scale := balance.enemy_damage_scale * (1.0 + threat_level * balance.threat_damage_bonus_per_step)

	for member in encounter.members:
		var data := enemies.get_enemy(member)
		if data == null:
			continue
		var c := data.spawn(balance, rng)
		c.max_hp = maxi(1, roundi(c.max_hp * hp_scale))
		c.hp = c.max_hp
		c.restored_value = roundi(c.max_hp * balance.restored_minutes_per_hp * data.restored_multiplier)
		c.outgoing_multiplier = damage_scale
		out.append(c)

	if encounter.link_pairs:
		for i in range(0, out.size() - 1, 2):
			out[i].link = i + 2
			out[i + 1].link = i + 1

	return out


func validate(enemies: EnemyDatabase) -> PackedStringArray:
	var problems := _load_problems.duplicate()
	if _all.is_empty():
		problems.append("Encounter table is empty.")
	if candidates(1, EnemyData.Tier.NORMAL, true).is_empty():
		problems.append("Act 1 has no opening encounter: the first fight of a run would be a general roll.")
	for e in _all:
		problems.append_array(e.validate(enemies))
	return problems
