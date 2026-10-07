class_name RelicSundial
extends Relic


@export var bonus_minutes := 60


func modify_turn_budget(run: RunState, base: int) -> int:
	if run.clock.daytime() == RunClock.Daytime.DAY:
		return base + bonus_minutes
	return base
