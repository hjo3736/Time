class_name BehaviorWithered
extends EnemyBehavior


@export var decay := 5

var _turns := 0


func outgoing_amount(_battle: BattleState, _handle: int, intent: EnemyIntent) -> int:
	if intent.kind == EnemyIntent.Kind.ATTACK:
		return maxi(0, intent.amount - _turns * decay)
	return intent.amount


func on_turn_end(_battle: BattleState, _handle: int) -> void:
	_turns += 1


func turns_elapsed() -> int:
	return _turns


func tell_key() -> StringName:
	return &"askew.withered.tell"


func to_dict() -> Dictionary:
	return {"_turns": _turns}


func from_dict(data: Dictionary) -> void:
	_turns = int(data.get("_turns", 0))
