class_name RelicFirstLight
extends Relic


@export var bonus_minutes := 60


func on_turn_start(_run: RunState, battle) -> void:
	if battle.turn == 1:
		battle.turn_budget += bonus_minutes
		battle.turn_budget_max += bonus_minutes
