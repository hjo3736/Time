class_name OutcomeHealth
extends EventOutcome


@export var amount := -5


func apply(run: RunState) -> void:
	if amount < 0:
		run.damage(-amount)
		return
	run.heal(amount)


func describe() -> String:
	if amount < 0:
		return tr("outcome.hurt").format({"n": -amount})
	return tr("outcome.heal").format({"n": amount})
