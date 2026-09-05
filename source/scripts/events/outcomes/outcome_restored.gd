class_name OutcomeRestored
extends EventOutcome


@export var hours := 2


func apply(run: RunState) -> void:
	var minutes := hours * Balance.MINUTES_PER_HOUR
	if minutes < 0:
		run.clock.spend_restored(-minutes)
		return
	run.clock.restore(minutes)


func describe() -> String:
	var span := RunClock.format_span(absi(hours) * Balance.MINUTES_PER_HOUR)
	return tr("outcome.restored_lost" if hours < 0 else "outcome.restored").format({"span": span})
