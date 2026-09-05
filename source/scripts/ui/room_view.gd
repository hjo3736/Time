class_name RoomView
extends Control


signal move_requested(coord: Vector2i)
signal map_requested

const DIRECTIONS := [
	{"step": Vector2i.UP, "key": "ui.room.north"},
	{"step": Vector2i.LEFT, "key": "ui.room.west"},
	{"step": Vector2i.RIGHT, "key": "ui.room.east"},
	{"step": Vector2i.DOWN, "key": "ui.room.south"},
]

var _here: Label
var _here_note: Label
var _doors: GridContainer
var _boss_note: Label


func _ready() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.custom_minimum_size = Vector2(560, 0)
	centre.add_child(box)

	_here = UiTheme.label("", 34, UiTheme.BONE)
	_here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_here)

	_here_note = UiTheme.label("", 15, UiTheme.INK_DIM)
	_here_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_here_note)

	var rule := HSeparator.new()
	box.add_child(rule)

	_doors = GridContainer.new()
	_doors.columns = 3
	_doors.add_theme_constant_override("h_separation", 10)
	_doors.add_theme_constant_override("v_separation", 10)
	box.add_child(_doors)

	_boss_note = UiTheme.label("", 14, UiTheme.INK_DIM)
	_boss_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_boss_note)


func show_room(rc: RunController) -> void:
	var room := rc.current_room()
	_here.text = RoomLabels.name_of(room)
	_here_note.text = tr("ui.room.spent_note") if room != null and room.is_spent() else ""

	ChoiceView._clear(_doors)

	var by_step := {}
	for entry in DIRECTIONS:
		by_step[entry["step"]] = tr(entry["key"])

	var slots := [
		Vector2i.ZERO, Vector2i.UP, Vector2i.ZERO,
		Vector2i.LEFT, Vector2i.ZERO, Vector2i.RIGHT,
		Vector2i.ZERO, Vector2i.DOWN, Vector2i.ZERO,
	]
	for i in slots.size():
		if i == 4:
			_doors.add_child(_centre_marker())
			continue
		var step: Vector2i = slots[i]
		if step == Vector2i.ZERO:
			_doors.add_child(_blank())
			continue
		_doors.add_child(_door(rc, step, String(by_step[step])))

	var steps := rc.map.steps_to_boss()
	_boss_note.text = tr("ui.room.boss_note").format({
		"n": steps,
		"span": RunClock.format_span(rc.map.minutes_to_boss()),
		"about": tr("ui.map.about") if rc.map.boss_walk_is_guess() else "",
	})


func _blank() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(170, 76)
	return c


func _centre_marker() -> Control:
	var l := UiTheme.label("◈", 26, UiTheme.GOLD)
	l.custom_minimum_size = Vector2(170, 76)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _door(rc: RunController, step: Vector2i, compass: String) -> Control:
	var target := rc.map.current + step
	if not rc.map.rooms.has(target):
		return _blank()

	var room: Room = rc.map.at(target)
	var button := Button.new()
	button.custom_minimum_size = Vector2(170, 76)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = "%s  ·  %s\n%s" % [
		compass, RoomLabels.name_of(room),
		RoomLabels.price_of(room, rc.map.priced_cost_to(target))]
	button.add_theme_font_size_override("font_size", UiTheme.size_for(15))
	button.pressed.connect(func() -> void: move_requested.emit(target))
	return button
