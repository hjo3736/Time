class_name BehaviorHourglass
extends EnemyBehavior

@export var flow := 4
@export var growth := 1

func on_turn_end(battle: BattleState, handle: int) -> void:
	if battle == null:
		return
	var lower: Stats = battle.combatants[handle]
	if lower.link < 0 or lower.link >= handle:
		return
	var upper: Stats = battle.combatants[lower.link]
	if not upper.is_alive() or not lower.is_alive():
		return

	var moved := mini(flow, upper.hp)
	var worth := roundi(float(upper.restored_value) * moved / upper.hp)
	upper.hp -= moved
	upper.restored_value -= worth
	lower.max_hp += moved
	lower.hp += moved
	lower.restored_value += worth
	lower.add_status(StatusRules.STRENGTH, growth)


func tell_key() -> StringName:
	return &"askew.hourglass.tell"
