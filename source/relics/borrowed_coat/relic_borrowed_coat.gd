class_name RelicBorrowedCoat
extends Relic


@export var amount := 3


func on_enemy_defeated(_run: RunState, battle, _enemy: EnemyStats) -> void:
	var warden: Stats = battle.warden()
	warden.hp = mini(warden.max_hp, warden.hp + amount)
