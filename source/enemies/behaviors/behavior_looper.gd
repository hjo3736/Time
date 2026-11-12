class_name BehaviorLooper
extends EnemyBehavior


func absorbs(battle: BattleState, handle: int, amount: int) -> int:
	var who := battle.enemy(handle)
	var intent := who.current_intent()
	if intent != null and intent.is_break_window:
		return amount
	return 0


func tell_key() -> StringName:
	return &"askew.looper.tell"
