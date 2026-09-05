class_name EnemyBehavior
extends Resource


func on_turn_start(_battle: BattleState, _handle: int) -> void:
	pass


func on_turn_end(_battle: BattleState, _handle: int) -> void:
	pass


func absorbs(_battle: BattleState, _handle: int, amount: int) -> int:
	return amount


func on_absorbed(_battle: BattleState, _handle: int, _amount: int) -> void:
	pass


func on_damaged(_battle: BattleState, _handle: int, _dealt: int) -> void:
	pass


func outgoing_amount(_battle: BattleState, _handle: int, intent: EnemyIntent) -> int:
	return intent.amount


func advance_intent(_battle: BattleState, who: Combatant) -> void:
	who.advance_intent()


func tell_key() -> StringName:
	return &""


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	pass
