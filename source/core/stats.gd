class_name Stats

extends Resource

signal stats_changed
signal intent_changed

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

# --- 적 전용: 3단계에서 EnemyStats로 옮긴다 ---
var restored_value := 0

var intents: Array[EnemyIntent] = []
var morning_intents: Array[EnemyIntent] = []
var day_intents: Array[EnemyIntent] = []
var evening_intents: Array[EnemyIntent] = []
var night_intents: Array[EnemyIntent] = []
var behavior: EnemyBehavior = null

var intent_index := 0 : set = set_intent_index
var sky := RunClock.Daytime.DAY : set = set_sky
var link := -1
var outgoing_multiplier := 1.0

func set_intent_index(value: int) -> void:
	intent_index = value
	intent_changed.emit()

func set_sky(value: RunClock.Daytime) -> void:
	sky = value
	intent_changed.emit()

func current_intent() -> EnemyIntent:
	var list := active_intents()
	
	if list.is_empty():
		return null
		
	return list[posmod(intent_index, list.size())]


func advance_intent() -> void:
	if not active_intents().is_empty():
		intent_index += 1


func active_intents() -> Array[EnemyIntent]:
	match sky:
		RunClock.Daytime.MORNING:
			if not morning_intents.is_empty():
				return morning_intents
		RunClock.Daytime.DAY:
			if not day_intents.is_empty():
				return day_intents
		RunClock.Daytime.EVENING:
			if not evening_intents.is_empty():
				return evening_intents
		RunClock.Daytime.NIGHT:
			if not night_intents.is_empty():
				return night_intents
	return intents

func to_dict() -> Dictionary:
	var written := {
		"name_key": String(name_key),
		"max_hp": max_hp,
		"start_block": start_block,
		"hp": hp,
		"block": block,
		"statuses": _statuses_out(),
		"restored_value": restored_value,
		"intents": intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict()),
		"morning_intents": morning_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict()),
		"day_intents": day_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict()),
		"evening_intents": evening_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict()),
		"night_intents": night_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict()),
		"intent_index": intent_index,
		"link": link,
		"outgoing_multiplier": outgoing_multiplier,
	}
	
	if art != null:
		written["art"] = art.resource_path
	
	if behavior != null:
		var scr := behavior.get_script() as Script
		
		if scr != null:
			written["behavior_script"] = scr.resource_path
			written["behavior_state"] = behavior.to_dict()
			
	return written

func _statuses_out() -> Dictionary:
	var out := {}
	
	for id in statuses:
		out[String(id)] = int(statuses[id])
		
	return out

static func from_dict(data: Dictionary) -> Stats:
	var out := Stats.new()
	out.name_key = StringName(data.get("name_key", ""))
	out.max_hp = int(data.get("max_hp", 1))
	out.start_block = int(data.get("start_block", 0))
	out.hp = int(data.get("hp", 1))
	out.block = int(data.get("block", 0))
	out.restored_value = int(data.get("restored_value", 0))
	out.intent_index = int(data.get("intent_index", 0))
	out.link = int(data.get("link", -1))
	out.outgoing_multiplier = float(data.get("outgoing_multiplier", 1.0))

	for id in data.get("statuses", {}):
		out.statuses[StringName(id)] = int(data["statuses"][id])

	var written: Array = data.get("intents", [])
	
	for entry in written:
		out.intents.append(EnemyIntent.from_dict(entry))
		
	for entry in data.get("morning_intents", []):
		out.morning_intents.append(EnemyIntent.from_dict(entry))
		
	for entry in data.get("day_intents", []):
		out.day_intents.append(EnemyIntent.from_dict(entry))
		
	for entry in data.get("evening_intents", []):
		out.evening_intents.append(EnemyIntent.from_dict(entry))
		
	for entry in data.get("night_intents", []):
		out.night_intents.append(EnemyIntent.from_dict(entry))
		
	var path: String = data.get("art", "")
	
	if path != "" and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		
		if texture != null:
			out.art = texture
	
	path = data.get("behavior_script", "")

	if path != "" and ResourceLoader.exists(path):
		var scr := load(path) as Script
		
		if scr != null:
			out.behavior = scr.new()
			out.behavior.from_dict(data.get("behavior_state", {}))
			
	return out

func create_instance() -> Stats:
	var instance: Stats = self.duplicate() as Stats
	
	instance.hp = max_hp
	instance.block = start_block
	
	return instance
