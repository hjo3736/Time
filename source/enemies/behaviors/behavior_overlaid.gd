class_name BehaviorOverlaid
extends EnemyBehavior


var _pending := 0


func absorbs(battle: BattleState, handle: int, amount: int) -> int:
	return 0 if _twin_of(battle, handle) != null else amount


func on_absorbed(battle: BattleState, handle: int, amount: int) -> void:
	var twin := _twin_of(battle, handle)
	if twin != null:
		twin._pending += amount


func _twin_of(battle: BattleState, handle: int) -> BehaviorOverlaid:
	var who := battle.combatants[handle]
	if who.link < 0 or who.link >= battle.combatants.size():
		return null
	var twin: Stats = battle.combatants[who.link]
	if not twin.is_alive():
		return null
	return twin.behavior as BehaviorOverlaid


func on_turn_start(battle: BattleState, handle: int) -> void:
	if _pending <= 0:
		return
	var who := battle.combatants[handle]
	var landing := _pending
	_pending = 0
	who.hp = maxi(0, who.hp - landing)


func pending() -> int:
	return _pending


func tell_key() -> StringName:
	return &"askew.overlaid.tell"


func to_dict() -> Dictionary:
	return {"_pending": _pending}


func from_dict(data: Dictionary) -> void:
	_pending = int(data.get("_pending", 0))
