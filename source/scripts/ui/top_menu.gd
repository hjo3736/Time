class_name TopMenu
extends HBoxContainer


signal map_requested
signal deck_requested
signal relics_requested

## The layout is the scene; this script only fills it.
const SCENE := preload("res://source/scenes/ui/top_menu.tscn")

@onready var _map_button := %Map as Button
@onready var _deck_button := %Deck as Button
@onready var _relic_button := %Relics as Button


## Always make one through here, never TopMenu.new(): new() is the script
## without the scene.
static func create() -> TopMenu:
	return SCENE.instantiate() as TopMenu


func _ready() -> void:
	UiTheme.localize(self)
	_map_button.pressed.connect(func() -> void: map_requested.emit())
	_deck_button.pressed.connect(func() -> void: deck_requested.emit())
	_relic_button.pressed.connect(func() -> void: relics_requested.emit())


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
