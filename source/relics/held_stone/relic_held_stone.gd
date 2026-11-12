class_name RelicHeldStone
extends Relic


@export var amount := 8


func on_turn_start(_run: RunState, battle) -> void:
	if battle.turn == 1:
		battle.warden().block += amount
