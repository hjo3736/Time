class_name RelicShortRope
extends Relic


@export var within_turns := 3
@export var percent := 25


func on_enemy_defeated(run: RunState, battle, enemy: EnemyStats) -> void:
	if battle.turn > within_turns:
		return
	run.clock.restore(roundi(enemy.restored_value * percent / 100.0))
