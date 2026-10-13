class_name BehaviorDomino
extends EnemyBehavior


@export var push := 6


## 도미노. Falls onto the one standing directly behind it — the next in the line
## as written — and if that is enough to bring that one down, it falls onto the
## next. A gap stops it: there is nothing for a domino to fall onto where one has
## already gone. Dealt as ordinary damage from nobody, so block takes it,
## 물러짐 swells it, and whatever it fells is recovered like anything else.
func on_defeated(battle: BattleState, handle: int) -> void:
	var behind := handle + 1
	if behind >= battle.combatants.size():
		return
	var next: Combatant = battle.combatants[behind]
	if next.is_alive() and next.behavior is BehaviorDomino:
		battle.damage(behind, push)


func tell_key() -> StringName:
	return &"askew.domino.tell"
