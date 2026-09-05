class_name TopMenu
extends HBoxContainer


signal map_requested
signal deck_requested

var _map_button: Button
var _deck_button: Button


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 8)

	_map_button = Button.new()
	_map_button.text = tr("ui.menu.map")
	_map_button.custom_minimum_size = Vector2(120, 40)
	_map_button.pressed.connect(func() -> void: map_requested.emit())
	add_child(_map_button)

	_deck_button = Button.new()
	_deck_button.text = tr("ui.menu.deck")
	_deck_button.custom_minimum_size = Vector2(120, 40)
	_deck_button.pressed.connect(func() -> void: deck_requested.emit())
	add_child(_deck_button)


func set_map_open(open: bool) -> void:
	_map_button.text = tr("ui.menu.close_map") if open else tr("ui.menu.map")


func set_deck_open(open: bool) -> void:
	_deck_button.text = tr("ui.menu.close_deck") if open else tr("ui.menu.deck")


func set_deck_count(count: int) -> void:
	_deck_button.tooltip_text = tr("ui.menu.deck_count").format({"n": count})
