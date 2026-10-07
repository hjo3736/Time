class_name RelicNightBell
extends Relic


@export var percent := 50


func modify_restored(run: RunState, base: int) -> int:
	if run.clock.daytime() != RunClock.Daytime.NIGHT:
		return base
	return base + roundi(base * percent / 100.0)
