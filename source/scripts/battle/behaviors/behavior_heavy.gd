class_name BehaviorHeavy
extends EnemyBehavior


@export var light_minutes := 60


## 무거움. Reads what the card cost, which is the one thing about a card every
## other enemy ignores. Measured on the hours actually paid, so a relic that
## cheapens a card makes it light as well. Damage that comes from no card at all
## is not light — there is nothing to weigh — and lands whole. Halved rounding
## up, so a light blow always does something.
func absorbs(battle: BattleState, _handle: int, amount: int) -> int:
	if battle == null or battle.cost_in_play < 0 or battle.cost_in_play > light_minutes:
		return amount
	return (amount + 1) / 2


func tell_key() -> StringName:
	return &"askew.heavy.tell"
