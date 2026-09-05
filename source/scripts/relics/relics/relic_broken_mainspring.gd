class_name RelicBrokenMainspring
extends Relic


@export var bonus_minutes := 60


func modify_turn_budget(_run: RunState, base: int) -> int:
	return base + bonus_minutes
