class_name Stats

extends Resource

signal stats_changed

@export var name_key := &""
@export var max_hp := 1
@export var art: Texture2D
@export var start_block := 0

var hp := 1 : set = set_hp
var block: int : set = set_block
var statuses: Dictionary = {}

func is_alive() -> bool:
	return hp > 0

func status(id: StringName) -> int:
	return int(statuses.get(id, 0))

func add_status(id: StringName, stacks: int) -> void:
	if stacks == 0:
		return
		
	var total := status(id) + stacks
	
	if total <= 0:
		statuses.erase(id)
	else:
		statuses[id] = total
	
	stats_changed.emit()

func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	stats_changed.emit()
	
func set_block(value: int) -> void:
	block = clampi(value, 0, 999)
	stats_changed.emit()
	
func take_damage(value: int) -> int:
	if value <= 0:
		return 0
		
	var absorbed := mini(value, block)
	block -= absorbed
	
	var through := value - absorbed
	hp = maxi(0, hp - through)
	
	return through

func heal(value: int) -> void:
	hp += value

func to_dict() -> Dictionary:
	var written := {
		"name_key": String(name_key),
		"max_hp": max_hp,
		"start_block": start_block,
		"hp": hp,
		"block": block,
		"statuses": _statuses_out()
	}
	
	if art != null:
		written["art"] = art.resource_path
	
	return written

func _statuses_out() -> Dictionary:
	var out := {}
	
	for id in statuses:
		out[String(id)] = int(statuses[id])
		
	return out

static func from_dict(data: Dictionary) -> Stats:
	var out: Stats = EnemyStats.new() if data.get("kind", "") == "enemy" else Stats.new()
	out._read(data)
	
	return out

func _read(data: Dictionary) -> void:
	name_key = StringName(data.get("name_key", ""))
	max_hp = int(data.get("max_hp", 1))
	start_block = int(data.get("start_block", 0))
	hp = int(data.get("hp", 1))
	block = int(data.get("block", 0))

	for id in data.get("statuses", {}):
		statuses[StringName(id)] = int(data["statuses"][id])

	var path: String = data.get("art", "")

	if path != "" and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D

		if texture != null:
			art = texture

func create_instance() -> Stats:
	var instance: Stats = self.duplicate() as Stats
	
	instance.hp = max_hp
	instance.block = start_block
	
	return instance
