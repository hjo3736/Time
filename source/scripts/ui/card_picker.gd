class_name CardPicker
extends Control


signal picked(deck_index: int)
signal cancelled

## The frame is the scene; the cards in it are whatever is being picked from.
const SCENE := preload("res://source/scenes/ui/card_picker.tscn")

@onready var _title := %Title as Label
@onready var _subtitle := %Subtitle as Label
@onready var _grid := %Grid as GridContainer
@onready var _empty := %Empty as Label


## Always make one through here, never CardPicker.new(): new() is the script
## without the scene.
static func create() -> CardPicker:
	return SCENE.instantiate() as CardPicker


func _ready() -> void:
	UiTheme.localize(self)
	(%Shade as ColorRect).gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cancelled.emit())
	(%Close as Button).pressed.connect(func() -> void: cancelled.emit())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancelled.emit()
		get_viewport().set_input_as_handled()


func present(title: String, subtitle: String, entries: Array, empty_text: String = "") -> void:
	_title.text = title
	_subtitle.text = subtitle
	ChoiceView._clear(_grid)

	_empty.text = empty_text if entries.is_empty() else ""
	_empty.visible = entries.is_empty()

	var picking := entries.any(func(e: Dictionary) -> bool: return bool(e.get("choosable", false)))

	_grid.columns = CompendiumView._columns_for(get_viewport_rect().size.x - 160.0)

	for entry in entries:
		var choosable := bool(entry.get("choosable", false))
		var node := CardNode.create(entry["card"], int(entry["index"]), choosable or not picking)
		node.draggable = false
		if choosable:
			var deck_index := int(entry["index"])
			node.clicked.connect(func(_i: int) -> void: picked.emit(deck_index))
		_grid.add_child(node)
