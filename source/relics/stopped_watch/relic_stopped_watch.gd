class_name RelicStoppedWatch
extends Relic


func modify_card_cost(_run: RunState, battle, _card: CardData, base: int) -> int:
	if battle != null and battle.cards_played_this_turn == 0:
		return 0
	return base
