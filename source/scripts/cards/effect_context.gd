class_name EffectContext
extends RefCounted

var source := 0
var targets := PackedInt32Array()

func _unimplemented(verb: String) -> void:
	push_error("EffectContext.%s() not implemented by %s" % [verb, get_script().resource_path])

func deal_damage(_target: int, _amount: int) -> int:
	_unimplemented("deal_damage")
	return 0

func gain_block(_target: int, _amount: int) -> void:
	_unimplemented("gain_block")

func apply_status(_target: int, _status: StringName, _stacks: int) -> void:
	_unimplemented("apply_status")

func draw_cards(_count: int) -> int:
	_unimplemented("draw_cards")
	return 0

func refund_turn_time(_minutes: int) -> void:
	_unimplemented("refund_turn_time")

func restore_time(_minutes: int) -> void:
	_unimplemented("restore_time")

func is_alive(_target: int) -> bool:
	_unimplemented("is_alive")
	return false

func get_block(_target: int) -> int:
	_unimplemented("get_block")
	return 0

func get_status(_target: int, _status: StringName) -> int:
	_unimplemented("get_status")
	return 0

func turn_index() -> int:
	_unimplemented("turn_index")
	return 0

func cards_played_this_turn() -> int:
	_unimplemented("cards_played_this_turn")
	return 0

## Midnights the run has passed, not turns of the fight.
func days_elapsed() -> int:
	_unimplemented("days_elapsed")
	return 0

func hand_size() -> int:
	_unimplemented("hand_size")
	return 0

func rng() -> RandomNumberGenerator:
	_unimplemented("rng")
	return RandomNumberGenerator.new()

func random_living_enemy() -> int:
	_unimplemented("random_living_enemy")
	return -1
