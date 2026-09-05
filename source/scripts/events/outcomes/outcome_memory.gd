class_name OutcomeMemory
extends EventOutcome


@export var memory_id := &""


func apply(run: RunState) -> void:
	if memory_id != &"":
		run.recover_memory(memory_id)


func describe() -> String:
	return tr("outcome.memory")
