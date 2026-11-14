class_name PlayerStats
extends Stats

@export var id := &""
@export var class_id := &""
@export var starting_deck: Array[CardData] = []

func to_dict() -> Dictionary:
	var written := super.to_dict()
	written["kind"] = "player"
	written["id"] = id
	written["class_id"] = class_id
	
	return written

func _read(data: Dictionary) -> void:
	super._read(data)
	id = StringName(data.get("id", ""))
	class_id = StringName(data.get("class_id", ""))

func spawn(run: RunState) -> PlayerStats:
	var c := create_instance() as PlayerStats
	
	c.max_hp = run.max_hp
	c.hp = run.hp
	
	return c
