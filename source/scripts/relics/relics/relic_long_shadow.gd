class_name RelicLongShadow
extends Relic


func modify_room_cost(run: RunState, base: int) -> int:
	if run.clock.daytime() == RunClock.Daytime.EVENING:
		return base / 2
	return base
