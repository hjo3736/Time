class_name TitleView
extends Control


signal date_requested
signal continue_requested
signal compendium_requested
signal settings_requested

## The layout is the scene; the menu's look is the theme on its Menu node.
const SCENE := preload("res://source/scenes/ui/title_view.tscn")

@onready var _continue_item := %Continue as Button


## Always make one through here, never TitleView.new(): new() is the script
## without the scene.
static func create() -> TitleView:
	return SCENE.instantiate() as TitleView


func _ready() -> void:
	UiTheme.localize(self)
	_continue_item.pressed.connect(func() -> void: continue_requested.emit())
	(%NewRun as Button).pressed.connect(func() -> void: date_requested.emit())
	(%Compendium as Button).pressed.connect(func() -> void: compendium_requested.emit())
	(%Settings as Button).pressed.connect(func() -> void: settings_requested.emit())
	(%Quit as Button).pressed.connect(func() -> void: get_tree().quit())


func set_continue_available(available: bool) -> void:
	_continue_item.visible = available

