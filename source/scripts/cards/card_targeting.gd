class_name CardTargeting
extends RefCounted


enum Mode {
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SELF,
	RANDOM_ENEMY,
}


static func requires_player_choice(mode: Mode) -> bool:
	return mode == Mode.SINGLE_ENEMY


static func resolve(
	mode: Mode,
	source: int,
	living_enemies: PackedInt32Array,
	rng: RandomNumberGenerator = null,
	chosen: int = -1,
) -> PackedInt32Array:
	match mode:
		Mode.SELF:
			return PackedInt32Array([source])

		Mode.ALL_ENEMIES:
			return living_enemies.duplicate()

		Mode.SINGLE_ENEMY:
			if chosen < 0 or not living_enemies.has(chosen):
				return PackedInt32Array()
			return PackedInt32Array([chosen])

		Mode.RANDOM_ENEMY:
			if living_enemies.is_empty():
				return PackedInt32Array()
			if rng == null:
				push_error("CardTargeting.resolve(): RANDOM_ENEMY needs the run's seeded rng.")
				return PackedInt32Array()
			return PackedInt32Array([living_enemies[rng.randi_range(0, living_enemies.size() - 1)]])

	return PackedInt32Array()


static func describe(mode: Mode) -> String:
	match mode:
		Mode.SINGLE_ENEMY:
			return "an enemy"
		Mode.ALL_ENEMIES:
			return "all enemies"
		Mode.SELF:
			return "yourself"
		Mode.RANDOM_ENEMY:
			return "a random enemy"
	return "?"
