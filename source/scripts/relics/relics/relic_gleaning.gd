class_name RelicGleaning
extends Relic


@export var percent := 25


func modify_restored(_run: RunState, base: int) -> int:
	return base + roundi(base * percent / 100.0)
