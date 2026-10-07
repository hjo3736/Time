class_name RelicThinIce
extends Relic


@export var bonus_minutes := 120
@export var penalty_percent := 50


func modify_turn_budget(_run: RunState, base: int) -> int:
	return base + bonus_minutes


func modify_restored(_run: RunState, base: int) -> int:
	return base - roundi(base * penalty_percent / 100.0)
