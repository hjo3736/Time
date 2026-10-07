class_name TopMenu
extends HBoxContainer


signal map_requested
signal deck_requested
signal relics_requested

var _map_button: Button
var _deck_button: Button
var _relic_button: Button


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

	_relic_button = Button.new()
	_relic_button.text = tr("ui.menu.relics")
	_relic_button.custom_minimum_size = Vector2(120, 40)
	_relic_button.pressed.connect(func() -> void: relics_requested.emit())
	add_child(_relic_button)


func set_map_open(open: bool) -> void:
	_map_button.text = tr("ui.menu.close_map") if open else tr("ui.menu.map")


func set_deck_open(open: bool) -> void:
	_deck_button.text = tr("ui.menu.close_deck") if open else tr("ui.menu.deck")


func set_deck_count(count: int) -> void:
	_deck_button.tooltip_text = tr("ui.menu.deck_count").format({"n": count})


func set_relics_open(open: bool) -> void:
	_relic_button.text = tr("ui.menu.close_relics") if open else tr("ui.menu.relics")


func set_relic_count(count: int) -> void:
	_relic_button.tooltip_text = tr("ui.menu.relic_count").format({"n": count})
