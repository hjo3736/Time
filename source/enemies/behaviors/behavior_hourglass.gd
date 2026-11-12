class_name BehaviorHourglass
extends EnemyBehavior

@export var flow := 4
@export var growth := 1

## 모래시계. Two bulbs of one glass; the one written first is the upper. Each
## turn `flow` of the upper's gauge runs down into the lower, and the lower grows
## for having received it. The time goes with the sand: what the upper is worth
## shrinks by what the lower gains, so nothing is made or lost by waiting — only
## moved to where it is harder to take back.
##
## Done by the lower bulb, at the end of its own turn. It resolves after the
## upper, so by then both have struck with exactly what they were showing.
func on_turn_end(battle: BattleState, handle: int) -> void:
	if battle == null:
		return
	var lower: EnemyStats = battle.enemy(handle)
	if lower.link < 0 or lower.link >= handle:
		return
	var upper: EnemyStats = battle.enemy(lower.link)
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
