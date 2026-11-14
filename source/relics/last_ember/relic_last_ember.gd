class_name RelicLastEmber
extends Relic


@export var bonus_minutes := 60


func on_turn_start(_run: RunState, battle) -> void:
	var player: Stats = battle.player()
	if player.hp * 2 <= player.max_hp:
		battle.turn_budget += bonus_minutes
		battle.turn_budget_max += bonus_minutes
