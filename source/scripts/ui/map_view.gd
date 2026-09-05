class_name MapView
extends Control


signal move_requested(coord: Vector2i)
signal closed

const CELL := 58

const GAP := 16
const STRIDE := CELL + GAP
const LINK_WIDTH := 18

const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.4
const ZOOM_STEP := 1.12
const ZOOM_DEFAULT := 1.0

var _viewport: Control
var _canvas: Control
var _hint: Label
var _legend: Label
var _zoom := ZOOM_DEFAULT
var _panning := false

var _centre_pending := false


func _ready() -> void:
	set_process(false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
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

	header.add_child(UiTheme.label(tr("ui.map.title"), 24, UiTheme.BONE))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var close := Button.new()
	close.text = tr("ui.map.close")
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)

	_hint = UiTheme.label("", 14, UiTheme.INK_DIM)
	box.add_child(_hint)

	_viewport = Control.new()
	_viewport.clip_contents = true
	_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport.gui_input.connect(_on_viewport_input)
	_viewport.resized.connect(func() -> void:
		if _centre_pending:
			centre_on_current())
	box.add_child(_viewport)

	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_canvas)

	_legend = UiTheme.label("", 13, UiTheme.INK_DIM)
	_legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_legend.position = Vector2(10, -70)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_legend)


func open(rc: RunController) -> void:
	_zoom = ZOOM_DEFAULT
	show_map(rc)
	_centre_pending = true
	set_process(true)
	centre_on_current()


func _process(_delta: float) -> void:
	if not _centre_pending:
		set_process(false)
		return
	if _viewport.size.x > 0.0 and _viewport.size.y > 0.0:
		centre_on_current()
		_centre_pending = false
		set_process(false)


func _refresh_legend() -> void:
	_legend.text = "\n".join([
		tr("ui.map.legend_zoom"),
		tr("ui.map.legend_pan"),
		tr("ui.map.legend_close").format({"key": Keybinds.name_of(Keybinds.Action.MAP)}),
	])


func show_map(rc: RunController) -> void:
	ChoiceView._clear(_canvas)
	_refresh_legend()

	var known := rc.map.known_rooms()
	var min_x := 0
	var min_y := 0
	for coord in known:
		min_x = mini(min_x, coord.x)
		min_y = mini(min_y, coord.y)

	var walkable := rc.phase == RunController.Phase.EXPLORING
	var reachable := rc.map.reachable()
	var origin := Vector2i(min_x, min_y)

	for node in _links(rc, known, origin):
		_canvas.add_child(node)
	for coord in known:
		_canvas.add_child(_cell(rc, coord, min_x, min_y, reachable.has(coord), walkable))

	_canvas.set_meta("origin", Vector2i(min_x, min_y))
	_canvas.set_meta("current", rc.map.current)
	_canvas.scale = Vector2(_zoom, _zoom)

	_hint.text = tr("ui.map.boss_hint").format({
		"n": rc.map.steps_to_boss(),
		"span": RunClock.format_span(rc.map.minutes_to_boss()),
		"about": tr("ui.map.about") if rc.map.boss_walk_is_guess() else "",
		"note": "" if walkable else tr("ui.map.no_move_in_battle"),
	})


func centre_on_current() -> void:
	if _canvas == null or not _canvas.has_meta("current"):
		return
	if _viewport.size.x <= 0.0 or _viewport.size.y <= 0.0:
		_centre_pending = true
		set_process(true)
		return
	var origin: Vector2i = _canvas.get_meta("origin")
	var current: Vector2i = _canvas.get_meta("current")
	var middle := _local_of(current, origin) + Vector2(CELL, CELL) * 0.5
	_canvas.scale = Vector2(_zoom, _zoom)
	_canvas.position = _viewport.size * 0.5 - middle * _zoom


func _local_of(coord: Vector2i, origin: Vector2i) -> Vector2:
	return Vector2((coord.x - origin.x) * STRIDE, (coord.y - origin.y) * STRIDE)


func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_by(ZOOM_STEP, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_by(1.0 / ZOOM_STEP, event.position)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed
	elif event is InputEventMouseMotion and _panning:
		_canvas.position += event.relative


func _zoom_by(factor: float, about: Vector2) -> void:
	var next := clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(next, _zoom):
		return
	var anchor := (about - _canvas.position) / _zoom
	_zoom = next
	_canvas.scale = Vector2(_zoom, _zoom)
	_canvas.position = about - anchor * _zoom


func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()


func _cell(rc: RunController, coord: Vector2i, min_x: int, min_y: int, adjacent: bool, walkable: bool) -> Control:
	var room: Room = rc.map.at(coord)
	var here := coord == rc.map.current

	var button := Button.new()
	button.position = _local_of(coord, Vector2i(min_x, min_y))
	button.custom_minimum_size = Vector2(CELL, CELL)
	button.size = Vector2(CELL, CELL)
	button.text = RoomLabels.short_of(room, here)
	if not here and rc.map.is_surveyed(coord):
		button.text += "\n" + RunClock.format_span(rc.map.priced_cost_at(coord))
	button.tooltip_text = tr("ui.map.here") if here else (
		"%s · %s" % [RoomLabels.name_of(room),
			RoomLabels.price_of(room, rc.map.priced_cost_at(coord))] if adjacent else "")
	button.disabled = not (adjacent and walkable)
	button.add_theme_font_size_override("font_size", UiTheme.size_for(14))

	var style := StyleBoxFlat.new()
	style.bg_color = _colour(room, here)
	style.set_corner_radius_all(3)
	style.set_border_width_all(2)
	style.border_color = UiTheme.GOLD if here else Color(UiTheme.INK_DIM, 0.9 if adjacent else 0.3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)

	if adjacent and walkable:
		button.pressed.connect(func() -> void: move_requested.emit(coord))
	return button


func _colour(room: Room, here: bool) -> Color:
	if here:
		return UiTheme.PANEL_HI
	if room.is_spent():
		return Color(UiTheme.PANEL, 0.45)
	match room.kind:
		Room.Kind.BOSS: return Color(UiTheme.BLOOD, 0.55)
		Room.Kind.FIRE: return Color(UiTheme.GOLD, 0.28)
		Room.Kind.SHOP: return Color(UiTheme.GREEN, 0.32)
		Room.Kind.COMBAT, Room.Kind.ELITE: return UiTheme.PANEL
	return Color(UiTheme.PANEL, 0.7)


func _links(rc: RunController, known: Array, origin: Vector2i) -> Array:
	var out := []
	var seen := {}
	for coord in known:
		seen[coord] = true

	for coord in known:
		for step in [Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = coord + step
			if not seen.has(next):
				continue

			var bar := ColorRect.new()
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var here := _local_of(coord, origin)
			if step == Vector2i.RIGHT:
				bar.position = Vector2(here.x + CELL, here.y + (CELL - LINK_WIDTH) * 0.5)
				bar.size = Vector2(GAP, LINK_WIDTH)
			else:
				bar.position = Vector2(here.x + (CELL - LINK_WIDTH) * 0.5, here.y + CELL)
				bar.size = Vector2(LINK_WIDTH, GAP)

			var live: bool = coord == rc.map.current or next == rc.map.current
			bar.color = Color(UiTheme.GOLD, 0.75) if live else Color(UiTheme.INK_DIM, 0.35)
			out.append(bar)

	return out
