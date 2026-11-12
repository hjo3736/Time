class_name RelicFullPockets
extends Relic


@export var threshold_minutes := 24 * 60


func modify_room_cost(run: RunState, base: int) -> int:
	if run.clock.restored >= threshold_minutes:
		return base / 2
	return base
