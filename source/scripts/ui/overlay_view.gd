class_name OverlayView
extends Control


signal closed

const SIDE_WIDTH := 260.0

## Fixed so the plate does not resize as the player moves between tabs. The height
## is set by the tallest tab, which is the keybinding list, so **adding a binding to
## `Keybinds.ORDER` means raising this.** test_ui measures every tab against it.
const SETTINGS_PLATE := Vector2(900, 560)

const PAUSE_PLATE := Vector2(470, 340)

## The frame is overlay_view.tscn, and each overlay's own scene inherits it. What
## goes in the body is built by the overlay, from whatever it is showing.
@onready var _frame := %Frame as PanelContainer
@onready var _column := %Column as VBoxContainer
@onready var _scroll := %Scroll as ScrollContainer

@onready var _heading := %Heading as Label
@onready var _close := %Close as Button
@onready var _tabs := %Tabs as HBoxContainer
@onready var _body := %Body as VBoxContainer
@onready var _side := %Side as VBoxContainer


func _ready() -> void:
	(%Shade as ColorRect).gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	_close.pressed.connect(func() -> void: closed.emit())
	relabel_chrome()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()


func heading(text: String) -> void:
	_heading.text = text


func relabel_chrome() -> void:
	UiTheme.localize(self)


func body() -> VBoxContainer:
	return _body


func set_back(on_back: Callable) -> void:
	ChoiceView._clear(_tabs)
	var back := Button.new()
	back.text = tr("ui.overlay.back")
	back.custom_minimum_size = Vector2(160, 40)
	back.pressed.connect(on_back)
	_tabs.add_child(back)


func set_tabs(labels: Array, active: int, on_pick: Callable) -> void:
	ChoiceView._clear(_tabs)
	if labels.size() < 2:
		return
	for i in labels.size():
		var tab := Button.new()
		tab.text = String(labels[i])
		tab.custom_minimum_size = Vector2(120, 40)
		tab.disabled = i == active
		var index := i
		tab.pressed.connect(func() -> void: on_pick.call(index))
		_tabs.add_child(tab)


func clear_body() -> void:
	ChoiceView._clear(_body)


func set_compact(on: bool, fixed := Vector2.ZERO) -> void:
	_frame.custom_minimum_size = fixed if on else Vector2.ZERO
	if on:
		if _body.get_parent() == _scroll:
			_scroll.remove_child(_body)
			_column.add_child(_body)
		_side.visible = false
		_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_scroll.visible = false
		_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_frame.grow_vertical = Control.GROW_DIRECTION_BOTH
		return

	if _body.get_parent() == _column:
		_column.remove_child(_body)
		_scroll.add_child(_body)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.visible = true
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = 80
	_frame.offset_right = -80
	_frame.offset_top = 50
	_frame.offset_bottom = -50


func side() -> VBoxContainer:
	return _side


func show_side(on: bool) -> void:
	_side.visible = on


func clear_side() -> void:
	ChoiceView._clear(_side)
