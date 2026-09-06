class_name MapView
extends Control


signal move_requested(coord: Vector2i)
signal closed

const CELL := 58

const UNIT := 46
const APART := CELL + 26
const RELAX_PASSES := 90
const PULL := 0.28
const SHOVE := 0.55
const LINK_WIDTH := 5.0
const BOW_MIN := 0.06
const BOW_MAX := 0.16
const BOW_STEPS := 7
const BENDS_MIN := 2
const BENDS_MAX := 4
const BOW_LEAST := 11.0

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
var _places := {}
var _extent := Vector2.ZERO
var _lines: MapLinks

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
	_legend.position = Vector2(10, -90)
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
		tr("ui.map.legend_length"),
		tr("ui.map.legend_close").format({"key": Keybinds.name_of(Keybinds.Action.MAP)}),
	])


func show_map(rc: RunController) -> void:
	ChoiceView._clear(_canvas)
	_refresh_legend()
	_layout(rc)

	var known := rc.map.known_rooms()
	var walkable := rc.phase == RunController.Phase.EXPLORING
	var reachable := rc.map.reachable()

	_lines = MapLinks.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.size = _extent
	_lines.segments = _corridors(rc, known)
	_canvas.add_child(_lines)
	for coord in known:
		_canvas.add_child(_cell(rc, coord, reachable.has(coord), walkable))

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
	var current: Vector2i = _canvas.get_meta("current")
	_canvas.scale = Vector2(_zoom, _zoom)
	_canvas.position = _viewport.size * 0.5 - _middle_of(current) * _zoom


func _layout(rc: RunController) -> void:
	var coords := rc.map.rooms.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x)

	var places := {}
	for coord in coords:
		var sway := hash(coord) % 1000
		places[coord] = Vector2(coord) * (CELL + UNIT * 1.6) + Vector2(
			float(sway % 13) - 6.0, float((sway / 13) % 13) - 6.0)

	var edges := []
	var met := {}
	for a in coords:
		for b in rc.map.neighbours(a):
			var key := [a, b] if (a.y < b.y or (a.y == b.y and a.x < b.x)) else [b, a]
			if met.has(key):
				continue
			met[key] = true
			edges.append([key[0], key[1],
				float(CELL) + UNIT * _hours(rc, key[0], key[1])])

	for pass_number in RELAX_PASSES:
		_pull(edges, places)
		_shove(coords, places)

	var least := Vector2(INF, INF)
	for coord in coords:
		least = least.min(places[coord])
	_places.clear()
	_extent = Vector2.ZERO
	for coord in coords:
		_places[coord] = (places[coord] - least).round()
		_extent = _extent.max(_places[coord] + Vector2(CELL, CELL))


func _hours(rc: RunController, a: Vector2i, b: Vector2i) -> float:
	return maxf(1.0, float(rc.map.guessed_priced_between(a, b)) / Balance.MINUTES_PER_HOUR)


func _pull(edges: Array, places: Dictionary) -> void:
	for edge in edges:
		var a: Vector2i = edge[0]
		var b: Vector2i = edge[1]
		var want: float = edge[2]
		var apart: Vector2 = places[b] - places[a]
		var span := maxf(apart.length(), 0.01)
		var shift := apart / span * (span - want) * 0.5 * PULL
		places[a] += shift
		places[b] -= shift


func _shove(coords: Array, places: Dictionary) -> void:
	for i in coords.size():
		for j in range(i + 1, coords.size()):
			var a: Vector2i = coords[i]
			var b: Vector2i = coords[j]
			var apart: Vector2 = places[b] - places[a]
			var span := maxf(apart.length(), 0.01)
			if span >= APART:
				continue
			var push := apart / span * (APART - span) * 0.5 * SHOVE
			places[a] -= push
			places[b] += push


func _local_of(coord: Vector2i) -> Vector2:
	return _places.get(coord, Vector2.ZERO)


func _middle_of(coord: Vector2i) -> Vector2:
	return _local_of(coord) + Vector2(CELL, CELL) * 0.5


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


func _cell(rc: RunController, coord: Vector2i, adjacent: bool, walkable: bool) -> Control:
	var room: Room = rc.map.at(coord)
	var here := coord == rc.map.current

	var button := Button.new()
	button.position = _local_of(coord)
	button.custom_minimum_size = Vector2(CELL, CELL)
	button.size = Vector2(CELL, CELL)
	button.text = RoomLabels.short_of(room, here)
	button.tooltip_text = tr("ui.map.here") if here else (
		"%s · %s" % [RoomLabels.name_of(room),
			RoomLabels.price_of(room, rc.map.priced_cost_to(coord))] if adjacent else "")
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
		return UiTheme.PANEL.lerp(UiTheme.BG, 0.55)
	match room.kind:
		Room.Kind.BOSS: return UiTheme.PANEL.lerp(UiTheme.BLOOD, 0.55)
		Room.Kind.FIRE: return UiTheme.PANEL.lerp(UiTheme.GOLD, 0.28)
		Room.Kind.SHOP: return UiTheme.PANEL.lerp(UiTheme.GREEN, 0.32)
	return UiTheme.PANEL


func _corridors(rc: RunController, known: Array) -> Array:
	var out := []
	var lit := {}
	for coord in known:
		lit[coord] = true

	var met := {}
	for coord in known:
		for next in rc.map.neighbours(coord):
			if not lit.has(next):
				continue
			var key := [coord, next] if (coord.y < next.y
				or (coord.y == next.y and coord.x < next.x)) else [next, coord]
			if met.has(key):
				continue
			met[key] = true

			var live: bool = coord == rc.map.current or next == rc.map.current
			var walked: bool = rc.map.walked_between(coord, next)
			var from := _middle_of(key[0])
			var to := _middle_of(key[1])
			out.append({
				"from": from,
				"to": to,
				"points": _wander(from, to, hash(key[0]) ^ hash(key[1])),
				"shade": Color(UiTheme.GOLD, 0.8) if live else Color(UiTheme.INK_DIM,
					0.5 if walked else 0.22),
				"width": LINK_WIDTH if walked else LINK_WIDTH * 0.5,
				"corridor": key,
				"walked": walked,
			})

	return out


func _wander(from: Vector2, to: Vector2, salt: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var span := to - from
	var sideways := Vector2(-span.y, span.x).normalized()
	var reach := span.length()

	var knots: Array[Vector2] = [from]
	var bends := rng.randi_range(BENDS_MIN, BENDS_MAX)
	for i in bends:
		var along := float(i + 1) / float(bends + 1) + rng.randf_range(-0.09, 0.09)
		var swing := rng.randf_range(0.45, 1.0) * (1.0 if rng.randi() % 2 == 0 else -1.0)
		var lean := maxf(BOW_LEAST, reach * rng.randf_range(BOW_MIN, BOW_MAX)) * swing
		knots.append(from + span * along + sideways * lean)
	knots.append(to)

	var line := PackedVector2Array()
	for i in range(knots.size() - 1):
		var before: Vector2 = knots[maxi(i - 1, 0)]
		var start: Vector2 = knots[i]
		var end: Vector2 = knots[i + 1]
		var after: Vector2 = knots[mini(i + 2, knots.size() - 1)]
		for step in BOW_STEPS:
			line.append(_through(before, start, end, after, float(step) / float(BOW_STEPS)))
	line.append(to)
	return line


func _through(before: Vector2, start: Vector2, end: Vector2, after: Vector2,
		t: float) -> Vector2:
	var square := t * t
	var cube := square * t
	return 0.5 * (2.0 * start
		+ (end - before) * t
		+ (2.0 * before - 5.0 * start + 4.0 * end - after) * square
		+ (after - 3.0 * end + 3.0 * start - before) * cube)
