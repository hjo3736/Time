class_name ChoiceView
extends Control


signal chosen(id: Variant)

## The frame is the scene. Cards and options come with each choice, so they are
## built here.
const SCENE := preload("res://source/scenes/ui/choice_view.tscn")

@onready var _title := %Title as Label
@onready var _subtitle := %Subtitle as Label
@onready var _options := %Options as VBoxContainer
@onready var _cards_row := %Cards as HBoxContainer


## Always make one through here, never ChoiceView.new(): new() is the script
## without the scene.
static func create() -> ChoiceView:
	return SCENE.instantiate() as ChoiceView


func present(title: String, subtitle: String, options: Array, cards: Array = []) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_clear(_options)
	_clear(_cards_row)

	_cards_row.visible = not cards.is_empty()
	for i in cards.size():
		var entry: Dictionary = cards[i]
		var node := CardNode.create(entry["card"], i, not bool(entry.get("disabled", false)))
		var id: Variant = entry["id"]
		node.clicked.connect(func(_i: int) -> void: chosen.emit(id))
		_cards_row.add_child(node)

	for option in options:
		var button := Button.new()
		var detail: String = option.get("detail", "")
		button.text = option["label"] if detail == "" else "%s\n%s" % [option["label"], detail]
		button.disabled = bool(option.get("disabled", false))
		button.custom_minimum_size = Vector2(0, 56)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var id: Variant = option["id"]
		button.pressed.connect(func() -> void: chosen.emit(id))
		_options.add_child(button)


static func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
