class_name BehaviorSeesaw
extends EnemyBehavior


const STRIKES := 0
const GUARDS := 1


func on_battle_start(battle: BattleState, handle: int) -> void:
	_settle(battle, battle.combatants[handle])


## 시소. Written as two intents — the blow, then the guard — and which one is
## showing is decided by the gauges, not by a cycle. Settled as its own turn
## ends, from where the player left the two of them, and then left alone: the
## intent on show through the player's turn is the one that lands, however the
## gauges move while it is on show. What the player does this turn chooses the
## turn after.
func advance_intent(battle: BattleState, who: Combatant) -> void:
	_settle(battle, who)


func _settle(battle: BattleState, who: Combatant) -> void:
	var other := _other_end(battle, who)
	# Level is both down: neither end is the lighter one. And an end left on its
	# own has nothing to be lighter than.
	if other == null or who.hp >= other.hp:
		who.intent_index = STRIKES
	else:
		who.intent_index = GUARDS


func _other_end(battle: BattleState, who: Combatant) -> Combatant:
	if battle == null or who.link < 0 or who.link >= battle.combatants.size():
		return null
	var other: Combatant = battle.combatants[who.link]
	return other if other.is_alive() else null


func tell_key() -> StringName:
	return &"askew.seesaw.tell"
