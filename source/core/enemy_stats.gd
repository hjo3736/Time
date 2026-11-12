class_name EnemyStats
extends Stats

signal intent_changed

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
	var written := super.to_dict()
	written["kind"] = "enemy"
	written["restored_value"] = restored_value
	written["intents"] = intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict())
	written["morning_intents"] = morning_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict())
	written["day_intents"] = day_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict())
	written["evening_intents"] = evening_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict())
	written["night_intents"] = night_intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict())
	written["intent_index"] = intent_index
	written["link"] = link
	written["outgoing_multiplier"] = outgoing_multiplier

	if behavior != null:
		var scr := behavior.get_script() as Script

		if scr != null:
			written["behavior_script"] = scr.resource_path
			written["behavior_state"] = behavior.to_dict()

	return written

func _read(data: Dictionary) -> void:
	super._read(data)
	restored_value = int(data.get("restored_value", 0))
	intent_index = int(data.get("intent_index", 0))
	link = int(data.get("link", -1))
	outgoing_multiplier = float(data.get("outgoing_multiplier", 1.0))
	
	var written: Array = data.get("intents", [])
	
	for entry in written:
		intents.append(EnemyIntent.from_dict(entry))
	for entry in data.get("morning_intents", []):
		morning_intents.append(EnemyIntent.from_dict(entry))
	for entry in data.get("day_intents", []):
		day_intents.append(EnemyIntent.from_dict(entry))
	for entry in data.get("evening_intents", []):
		evening_intents.append(EnemyIntent.from_dict(entry))
	for entry in data.get("night_intents", []):
		night_intents.append(EnemyIntent.from_dict(entry))
	
	var path: String = data.get("behavior_script", "")

	if path != "" and ResourceLoader.exists(path):
		var scr := load(path) as Script
		
		if scr != null:
			behavior = scr.new()
			behavior.from_dict(data.get("behavior_state", {}))
