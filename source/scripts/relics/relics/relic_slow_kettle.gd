class_name RelicSlowKettle
extends Relic


@export var from_turn := 4
@export var bonus_minutes := 60


func on_turn_start(_run: RunState, battle) -> void:
	if battle.turn >= from_turn:
		battle.turn_budget += bonus_minutes
		battle.turn_budget_max += bonus_minutes
