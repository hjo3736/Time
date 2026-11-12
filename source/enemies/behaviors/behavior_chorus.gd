class_name BehaviorChorus
extends EnemyBehavior


## 합창. The blow it is written with is one voice's worth; what lands is that
## times however many are still singing. Read live, like 노화: bring one down
## and what the others are showing drops there and then, in the same turn.
func outgoing_amount(battle: BattleState, _handle: int, intent: EnemyIntent) -> int:
	if battle == null or intent.kind != EnemyIntent.Kind.ATTACK:
		return intent.amount
	return intent.amount * voices(battle)


func voices(battle: BattleState) -> int:
	var count := 0
	for handle in battle.enemy_handles():
		if battle.enemy(handle).behavior is BehaviorChorus:
			count += 1
	return maxi(1, count)


func tell_key() -> StringName:
	return &"askew.chorus.tell"
