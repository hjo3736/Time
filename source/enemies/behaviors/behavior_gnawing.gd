class_name BehaviorGnawing
extends EnemyBehavior


@export var minutes_per_point := 60


## 좀먹음. Damage that gets past the guard is paid out of what is being carried
## back rather than out of the Warden, and killing the thing returns none of it —
## what it took has gone back into the leak. An hour a point, so the number on
## the intent is the number of hours at stake and nothing has to be converted.
## What the pool cannot cover lands on hp as written: an empty pool is not an
## immunity, and a thin one is only a thin shield.
func diverts_hit(battle: BattleState, _handle: int, through: int) -> int:
	if minutes_per_point <= 0:
		return 0
	var lost := battle.run().clock.spill(through * minutes_per_point)
	return lost / minutes_per_point


func tell_key() -> StringName:
	return &"askew.gnaw.tell"
