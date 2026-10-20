class_name CardNode
extends Control


signal clicked(index: int)
signal drag_started(index: int)
signal drag_moved(index: int, at: Vector2)
signal dropped(index: int, at: Vector2)

## The layout is the scene; this script only fills it. The frame's look is the
## `CardFrame` type in ui_theme.tres.
const SCENE := preload("res://source/scenes/ui/card_node.tscn")

const SIZE := Vector2(148, 206)
const LIFT := 34.0

var index := -1
var card: CardData
var playable := true
var selected := false

const DRAG_SLOP := 8.0

var _settled := false
var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _pressed := false
var draggable := true

var _dragging := false
var _grab_offset := Vector2.ZERO
var _press_at := Vector2.ZERO
var _tween: Tween


## Always make one through here, never CardNode.new(): new() is the script
## without the scene, a card with no face.
static func create(p_card: CardData, p_index: int, p_playable: bool,
		p_selected: bool = false) -> CardNode:
	var node := SCENE.instantiate() as CardNode
	node.setup(p_card, p_index, p_playable, p_selected)
	return node


func setup(p_card: CardData, p_index: int, p_playable: bool, p_selected: bool = false) -> void:
	card = p_card
	index = p_index
	playable = p_playable
	selected = p_selected
	tooltip_text = CardHelp.tooltip_for(p_card)
	_fill()


func settle(at: Vector2, angle: float) -> void:
	_settled = true
	_base_position = at
	_base_rotation = angle
	position = at
	rotation = angle


func _fill() -> void:
	var frame := (&"unplayable_selected" if selected else &"unplayable") if not playable \
		else (&"selected" if selected else &"normal")
	(%Frame as Panel).add_theme_stylebox_override("panel",
		UiTheme.build().get_stylebox(frame, &"CardFrame"))

	var cost := %Cost as Label
	cost.text = card.cost_text()
	cost.add_theme_color_override("font_color", UiTheme.GOLD if playable else UiTheme.INK_DIM)

	var kind := %Kind as Label
	kind.text = _kind_text()
	kind.add_theme_color_override("font_color", UiTheme.INK_DIM)

	var title := %Title as Label
	title.text = card.display_name()
	title.add_theme_color_override("font_color", UiTheme.BONE if playable else UiTheme.INK_DIM)

	var text := %Text as RichTextLabel
	text.add_theme_color_override("default_color", UiTheme.INK if playable else UiTheme.INK_DIM)
	text.text = card.rules_text()

	var exhaust := %Exhaust as Label
	exhaust.visible = card.has_keyword(CardData.Keyword.EXHAUST)
	exhaust.add_theme_color_override("font_color", UiTheme.BLOOD)


static func kind_name(kind: int) -> String:
	match kind:
		CardData.Kind.ATTACK: return TranslationServer.translate("ui.card.kind.attack")
		CardData.Kind.SKILL: return TranslationServer.translate("ui.card.kind.skill")
		CardData.Kind.POWER: return TranslationServer.translate("ui.card.kind.power")
		CardData.Kind.CURSE: return TranslationServer.translate("ui.card.kind.curse")
	return ""


func _kind_text() -> String:
	return kind_name(card.kind)


func _ready() -> void:
	UiTheme.localize(self)
	set_process_input(false)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))


func _hover(on: bool) -> void:
	if not playable or _dragging or not _alive():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	z_index = 10 if on else 0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(1.08, 1.08) if on else Vector2.ONE, 0.09)
	if not _settled:
		return
	_tween.tween_property(self, "position", _base_position - Vector2(0, LIFT) if on else _base_position, 0.09)
	_tween.tween_property(self, "rotation", 0.0 if on else _base_rotation, 0.09)


func _alive() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _gui_input(event: InputEvent) -> void:
	if not playable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = true
		_press_at = get_global_mouse_position()
		_grab_offset = global_position - _press_at
		set_process_input(true)


func _input(event: InputEvent) -> void:
	if not _pressed:
		return

	if event is InputEventMouseMotion:
		if not draggable:
			return
		var at := get_global_mouse_position()
		if not _dragging and at.distance_to(_press_at) > DRAG_SLOP:
			_begin_drag()
		if _dragging:
			global_position = at + _grab_offset
			drag_moved.emit(index, at)
		return

	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := get_global_mouse_position()
		_pressed = false
		set_process_input(false)
		if _dragging:
			_dragging = false
			dropped.emit(index, at)
		else:
			clicked.emit(index)


func _begin_drag() -> void:
	_dragging = true
	z_index = 20
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rotation = 0.0
	scale = Vector2(1.05, 1.05)
	drag_started.emit(index)


func return_home() -> void:
	_dragging = false
	_pressed = false
	set_process_input(false)
	z_index = 0
	if not _settled or not _alive():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", _base_position, 0.12)
	_tween.tween_property(self, "rotation", _base_rotation, 0.12)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func show_live_text(bbcode: String) -> void:
	(%Text as RichTextLabel).text = bbcode


func get_rules_text() -> String:
	return (%Text as RichTextLabel).text
