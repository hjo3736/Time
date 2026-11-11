class_name BehaviorSheltered
extends EnemyBehavior


## 방패막이. Worn by the one behind. While the one in front of it stands, a blow
## aimed at this one lands on that one instead — in full, as ordinary damage, so
## the front's own block and statuses are what it meets.
##
## Aimed is the word. A card that strikes everything is not aimed at anyone, and
## reaches it; that is the one way past, short of bringing the front down.
func absorbs(battle: BattleState, handle: int, amount: int) -> int:
	return 0 if _covered(battle, handle) else amount


func on_absorbed(battle: BattleState, handle: int, amount: int) -> void:
	if amount > 0 and _covered(battle, handle):
		battle.damage(battle.combatants[handle].link, amount)


func _covered(battle: BattleState, handle: int) -> bool:
	if battle == null or battle.targets_in_play > 1:
		return false
	var who: Stats = battle.combatants[handle]
	if who.link < 0 or who.link >= battle.combatants.size():
		return false
	return battle.combatants[who.link].is_alive()


func tell_key() -> StringName:
	return &"askew.sheltered.tell"
