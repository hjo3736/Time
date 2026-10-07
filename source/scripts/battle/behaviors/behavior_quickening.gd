class_name BehaviorQuickening
extends EnemyBehavior


@export var extra_minutes := 60


## 가속. It never touches hp, damage or block — it bills the run. Blocking well
## does not answer it and neither does healing; the only answer is fewer turns,
## which is the deck-building goal this game has never had an enemy enforce.
func modify_turn_cost(_battle: BattleState, _handle: int, base: int) -> int:
	return base + extra_minutes


func tell_key() -> StringName:
	return &"askew.quickening.tell"
