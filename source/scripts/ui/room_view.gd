class_name RoomView
extends Control


signal move_requested(coord: Vector2i)

const DIRECTIONS := [
	{"step": Vector2i.UP, "key": "ui.room.north"},
	{"step": Vector2i.LEFT, "key": "ui.room.west"},
	{"step": Vector2i.RIGHT, "key": "ui.room.east"},
	{"step": Vector2i.DOWN, "key": "ui.room.south"},
]

## The frame is the scene. The doors depend on the room, so they are built here.
const SCENE := preload("res://source/scenes/ui/room_view.tscn")

@onready var _here := %Here as Label
@onready var _here_note := %HereNote as Label
@onready var _doors := %Doors as GridContainer


## Always make one through here, never RoomView.new(): new() is the script
## without the scene.
static func create() -> RoomView:
	return SCENE.instantiate() as RoomView


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
