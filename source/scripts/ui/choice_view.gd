class_name ChoiceView
extends Control


signal chosen(id: Variant)

var _title: Label
var _subtitle: Label
var _options: VBoxContainer
var _cards_row: HBoxContainer


func _ready() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(760, 0)
	centre.add_child(box)

	_title = UiTheme.label("", 30, UiTheme.BONE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_subtitle = UiTheme.label("", 16, UiTheme.INK_DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_subtitle)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 18)
	_cards_row.custom_minimum_size = Vector2(0, 220)
	box.add_child(_cards_row)

	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 8)
	box.add_child(_options)


func present(title: String, subtitle: String, options: Array, cards: Array = []) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_clear(_options)
	_clear(_cards_row)

	_cards_row.visible = not cards.is_empty()
	for i in cards.size():
		var entry: Dictionary = cards[i]
		var node := CardNode.new()
		node.setup(entry["card"], i, not bool(entry.get("disabled", false)))
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
