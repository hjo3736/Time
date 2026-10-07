class_name RelicLastEmber
extends Relic


@export var bonus_minutes := 60


func on_turn_start(_run: RunState, battle) -> void:
	var warden: Combatant = battle.warden()
	if warden.hp * 2 <= warden.max_hp:
		battle.turn_budget += bonus_minutes
		battle.turn_budget_max += bonus_minutes
