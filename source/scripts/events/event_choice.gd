class_name EventChoice
extends Resource


@export var label_key := &""
@export var outcomes: Array[EventOutcome] = []

@export var needs_restored_hours := 0
@export var needs_health := 0


func available(run: RunState) -> bool:
	if needs_restored_hours > 0 \
			and run.clock.restored < needs_restored_hours * Balance.MINUTES_PER_HOUR:
		return false
	if needs_health > 0 and run.hp <= needs_health:
		return false
	return true


func label() -> String:
	return tr(label_key)


func detail() -> String:
	var parts := PackedStringArray()
	for outcome in outcomes:
		var line := outcome.describe()
		if line != "":
			parts.append(line)
	return "  ·  ".join(parts)


func take(run: RunState) -> void:
	for outcome in outcomes:
		outcome.apply(run)
