class_name OutcomeCard
extends EventOutcome


@export var card_id := &""


func apply(run: RunState) -> void:
	if card_id != &"":
		run.add_card(card_id)


func describe() -> String:
	return tr("outcome.card").format({"card": TranslationServer.translate(
		"card.%s.name" % card_id)})
