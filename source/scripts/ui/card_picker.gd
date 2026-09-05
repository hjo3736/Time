class_name CardPicker
extends Control


signal picked(deck_index: int)
signal cancelled

var _title: Label
var _subtitle: Label
var _grid: GridContainer
var _empty: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cancelled.emit())
	add_child(shade)

	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 60
	frame.offset_right = -60
	frame.offset_top = 40
	frame.offset_bottom = -40
	add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	_title = UiTheme.label("", 24, UiTheme.BONE)
	header.add_child(_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close := Button.new()
	close.text = tr("ui.picker.close")
	close.pressed.connect(func() -> void: cancelled.emit())
	header.add_child(close)

	_subtitle = UiTheme.label("", 14, UiTheme.INK_DIM)
	box.add_child(_subtitle)

	_empty = UiTheme.label("", 16, UiTheme.INK_DIM)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_empty)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 7
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.add_child(_grid)


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
		var node := CardNode.new()
		node.setup(entry["card"], int(entry["index"]), choosable or not picking)
		node.draggable = false
		if choosable:
			var deck_index := int(entry["index"])
			node.clicked.connect(func(_i: int) -> void: picked.emit(deck_index))
		_grid.add_child(node)
