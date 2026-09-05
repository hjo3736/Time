class_name Relic
extends Resource


@export var id := &""
@export var name_key := &""
@export var text_key := &""


func display_name() -> String:
	return tr(name_key)


func description() -> String:
	return tr(text_key)


func on_battle_start(_run: RunState, _battle) -> void:
	pass


func on_turn_start(_run: RunState, _battle) -> void:
	pass


func on_enemy_defeated(_run: RunState, _battle, _enemy: Combatant) -> void:
	pass


func modify_turn_budget(_run: RunState, base: int) -> int:
	return base


func modify_card_cost(_run: RunState, _battle, _card: CardData, base: int) -> int:
	return base


func modify_restored(_run: RunState, base: int) -> int:
	return base


func modify_room_cost(_run: RunState, base: int) -> int:
	return base


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var label := String(id) if id != &"" else "<unnamed relic>"
	if id == &"":
		problems.append("%s: id is required." % label)
	if name_key == &"":
		problems.append("%s: name_key is required." % label)
	if text_key == &"":
		problems.append("%s: text_key is required — a passive the player cannot read is a bug." % label)
	return problems
