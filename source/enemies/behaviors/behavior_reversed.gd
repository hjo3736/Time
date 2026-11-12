class_name BehaviorReversed
extends EnemyBehavior


var _taken_this_turn := 0


func on_turn_start(battle: BattleState, handle: int) -> void:
	if _taken_this_turn <= 0:
		return
	var who := battle.enemy(handle)
	who.hp = mini(who.max_hp, who.hp + _taken_this_turn)
	_taken_this_turn = 0


func on_damaged(_battle: BattleState, _handle: int, dealt: int) -> void:
	_taken_this_turn += dealt


func advance_intent(_battle: BattleState, who: EnemyStats) -> void:
	who.intent_index -= 1


func tell_key() -> StringName:
	return &"askew.reversed.tell"


func to_dict() -> Dictionary:
	return {"_taken_this_turn": _taken_this_turn}


func from_dict(data: Dictionary) -> void:
	_taken_this_turn = int(data.get("_taken_this_turn", 0))
