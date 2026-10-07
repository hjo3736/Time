class_name RelicCountedDays
extends Relic


@export var minutes_per_step := 10


func modify_turn_budget(run: RunState, base: int) -> int:
	return base + run.clock.threat_level() * minutes_per_step
