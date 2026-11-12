class_name BehaviorTwilit
extends EnemyBehavior


@export var gain := 1

const SKIES := [RunClock.Daytime.MORNING, RunClock.Daytime.EVENING]


## Granted at the end of its turn rather than the start, so the intent the player
## reads while planning is the intent that lands. A buff that arrives between the
## reading and the blow is a surprise, and losses here are meant to be planning
## failures instead.
func on_turn_end(battle: BattleState, handle: int) -> void:
	if battle == null:
		return
	var who: Stats = battle.combatants[handle]
	if SKIES.has(who.sky):
		who.add_status(StatusRules.STRENGTH, gain)


## 성장 is the mechanic — gaining Strength — and is defined once, under
## `keyword.growth`, the way a card keyword is. This line only says when it
## happens, and says 성장 to name what happens, so anything else that strengthens
## reads as the same thing however it is set off.
func tell_key() -> StringName:
	return &"askew.twilight.tell"
