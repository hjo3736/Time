class_name RelicSettledDust
extends Relic


@export var amount := 2


func on_turn_start(_run: RunState, battle) -> void:
	battle.player().block += amount
