class_name RelicQuickHand
extends Relic


@export var cards := 2


func on_turn_start(_run: RunState, battle) -> void:
	if battle.turn == 1:
		battle.piles().draw_cards(cards)
