class_name BehaviorStilled
extends EnemyBehavior


@export var growth := 4

var _charge := 0


func outgoing_amount(_battle: BattleState, _handle: int, intent: EnemyIntent) -> int:
	if intent.kind == EnemyIntent.Kind.ATTACK:
		return intent.amount + _charge * growth
	return intent.amount


func on_turn_end(battle: BattleState, handle: int) -> void:
	var who := battle.combatants[handle]
	var performed := who.intents[(who.intent_index - 1) % who.intents.size()]
	if performed.kind == EnemyIntent.Kind.WAIT:
		_charge += 1
	else:
		_charge = 0


func charge() -> int:
	return _charge


func tell_key() -> StringName:
	return &"askew.stilled.tell"


func to_dict() -> Dictionary:
	return {"_charge": _charge}


func from_dict(data: Dictionary) -> void:
	_charge = int(data.get("_charge", 0))
