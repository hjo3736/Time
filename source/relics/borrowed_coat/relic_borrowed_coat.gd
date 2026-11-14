class_name RelicBorrowedCoat
extends Relic


@export var amount := 3


func on_enemy_defeated(_run: RunState, battle, _enemy: EnemyStats) -> void:
	var player: Stats = battle.player()
	player.hp = mini(player.max_hp, player.hp + amount)
