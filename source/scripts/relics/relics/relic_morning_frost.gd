class_name RelicMorningFrost
extends Relic


@export var stacks := 2


func on_battle_start(run: RunState, battle) -> void:
	if run.clock.daytime() != RunClock.Daytime.MORNING:
		return
	for handle in battle.enemy_handles():
		battle.combatants[handle].add_status(StatusRules.SOFTENED, stacks)
