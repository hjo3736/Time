class_name RecordingEffectContext
extends EffectContext


var calls: Array[Dictionary] = []

var dead: PackedInt32Array = []
var block: Dictionary = {}
var statuses: Dictionary = {}
var draw_pile_size := 99
var turn := 1
var played_this_turn := 0
var hand := 5

var _rng := RandomNumberGenerator.new()


func _init(p_source: int = 0, p_targets: PackedInt32Array = PackedInt32Array([1])) -> void:
	source = p_source
	targets = p_targets
	_rng.seed = 1


func verbs() -> Array:
	return calls.map(func(c: Dictionary) -> StringName: return c["verb"])


func count(verb: StringName) -> int:
	return calls.filter(func(c: Dictionary) -> bool: return c["verb"] == verb).size()


func deal_damage(target: int, amount: int) -> int:
	var absorbed: int = mini(amount, int(block.get(target, 0)))
	block[target] = int(block.get(target, 0)) - absorbed
	var dealt := amount - absorbed
	calls.append({"verb": &"deal_damage", "target": target, "amount": amount, "dealt": dealt})
	return dealt


func gain_block(target: int, amount: int) -> void:
	block[target] = int(block.get(target, 0)) + amount
	calls.append({"verb": &"gain_block", "target": target, "amount": amount})


func apply_status(target: int, status: StringName, stacks: int) -> void:
	var key := "%d/%s" % [target, status]
	statuses[key] = int(statuses.get(key, 0)) + stacks
	calls.append({"verb": &"apply_status", "target": target, "status": status, "stacks": stacks})


func draw_cards(count_requested: int) -> int:
	var drawn: int = mini(count_requested, draw_pile_size)
	draw_pile_size -= drawn
	hand += drawn
	calls.append({"verb": &"draw_cards", "requested": count_requested, "drawn": drawn})
	return drawn


func refund_turn_time(minutes: int) -> void:
	calls.append({"verb": &"refund_turn_time", "minutes": minutes})


func restore_time(minutes: int) -> void:
	calls.append({"verb": &"restore_time", "minutes": minutes})


func is_alive(target: int) -> bool:
	return not dead.has(target)


func get_block(target: int) -> int:
	return int(block.get(target, 0))


func get_status(target: int, status: StringName) -> int:
	return int(statuses.get("%d/%s" % [target, status], 0))


func turn_index() -> int:
	return turn


func cards_played_this_turn() -> int:
	return played_this_turn


func hand_size() -> int:
	return hand


func rng() -> RandomNumberGenerator:
	return _rng


func random_living_enemy() -> int:
	var alive := PackedInt32Array()
	for t in targets:
		if is_alive(t):
			alive.append(t)
	if alive.is_empty():
		return -1
	return alive[_rng.randi_range(0, alive.size() - 1)]
