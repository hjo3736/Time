class_name Combatant
extends RefCounted


var name_key := &""
var hp := 1
var max_hp := 1
var block := 0

var statuses: Dictionary = {}

var restored_value := 0

var intents: Array[EnemyIntent] = []
var intent_index := 0

var behavior: EnemyBehavior = null

var link := -1

var outgoing_multiplier := 1.0


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


func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var absorbed := mini(amount, block)
	block -= absorbed
	var through := amount - absorbed
	hp = maxi(0, hp - through)
	return through


func current_intent() -> EnemyIntent:
	if intents.is_empty():
		return null
	return intents[posmod(intent_index, intents.size())]


func advance_intent() -> void:
	if not intents.is_empty():
		intent_index += 1


func to_dict() -> Dictionary:
	var written := {
		"name_key": String(name_key),
		"hp": hp,
		"max_hp": max_hp,
		"block": block,
		"statuses": _statuses_out(),
		"restored_value": restored_value,
		"intents": intents.map(func(i: EnemyIntent) -> Dictionary: return i.to_dict()),
		"intent_index": intent_index,
		"link": link,
		"outgoing_multiplier": outgoing_multiplier,
	}
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


static func from_dict(data: Dictionary) -> Combatant:
	var out := Combatant.new()
	out.name_key = StringName(data.get("name_key", ""))
	out.hp = int(data.get("hp", 1))
	out.max_hp = int(data.get("max_hp", 1))
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

	var path: String = data.get("behavior_script", "")
	if path != "" and ResourceLoader.exists(path):
		var scr := load(path) as Script
		if scr != null:
			out.behavior = scr.new()
			out.behavior.from_dict(data.get("behavior_state", {}))
	return out
