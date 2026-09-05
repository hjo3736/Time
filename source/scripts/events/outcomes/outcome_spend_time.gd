class_name OutcomeSpendTime
extends EventOutcome


@export var hours := 1


func apply(run: RunState) -> void:
	run.clock.advance(hours * Balance.MINUTES_PER_HOUR, RunClock.Source.EVENT)


func describe() -> String:
	return tr("outcome.spend_time").format({"span": RunClock.format_span(
		hours * Balance.MINUTES_PER_HOUR)})
