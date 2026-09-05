class_name OverlayView
extends Control


signal closed

const SIDE_WIDTH := 260.0

const SETTINGS_PLATE := Vector2(900, 430)

const PAUSE_PLATE := Vector2(470, 340)

var _frame: PanelContainer
var _column: VBoxContainer
var _scroll: ScrollContainer

var _heading: Label
var _tabs: HBoxContainer
var _body: VBoxContainer
var _side: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			closed.emit())
	add_child(shade)

	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.offset_left = 80
	_frame.offset_right = -80
	_frame.offset_top = 50
	_frame.offset_bottom = -50
	add_child(_frame)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 14)
	_frame.add_child(_column)
	var column := _column

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)

	_heading = UiTheme.label("", 32, UiTheme.BONE)
	top.add_child(_heading)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)

	var close := Button.new()
	close.text = tr("ui.overlay.close")
	close.custom_minimum_size = Vector2(140, 44)
	close.pressed.connect(func() -> void: closed.emit())
	top.add_child(close)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 20)
	column.add_child(middle)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(_scroll)

	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	_side.add_theme_constant_override("separation", 12)
	_side.visible = false
	middle.add_child(_side)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()


func heading(text: String) -> void:
	_heading.text = text


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
