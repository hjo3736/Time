class_name BehaviorSpilling
extends EnemyBehavior


@export var minutes_per_hit := 60


## 흘림. Per blow that gets through, not per point of it: block either holds a hit
## or it does not, and whole hours are the only thing the player is ever shown. A
## multi-hit attack is therefore several chances to spill, which is where the dial
## for a nastier version lives.
func on_hit_player(battle: BattleState, _handle: int, _dealt: int) -> void:
	battle.run().clock.spill(minutes_per_hit)


func tell_key() -> StringName:
	return &"askew.spill.tell"
