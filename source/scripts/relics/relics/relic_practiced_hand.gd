class_name RelicPracticedHand
extends Relic


@export var from_turn := 5
@export var discount_minutes := 60


func modify_card_cost(_run: RunState, battle, _card: CardData, base: int) -> int:
	if battle != null and battle.turn >= from_turn:
		return base - discount_minutes
	return base
