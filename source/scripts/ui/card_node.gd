class_name CardNode
extends Control


signal clicked(index: int)
signal drag_started(index: int)
signal drag_moved(index: int, at: Vector2)
signal dropped(index: int, at: Vector2)

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
var _panel: Panel
var _tween: Tween
var _text: RichTextLabel


func setup(p_card: CardData, p_index: int, p_playable: bool, p_selected: bool = false) -> void:
	card = p_card
	index = p_index
	playable = p_playable
	selected = p_selected
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = CardHelp.tooltip_for(p_card)
	_build()


func settle(at: Vector2, angle: float) -> void:
	_settled = true
	_base_position = at
	_base_rotation = angle
	position = at
	rotation = angle


func _build() -> void:
	for child in get_children():
		child.queue_free()

	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style())
	add_child(_panel)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		box.add_theme_constant_override("margin_%s" % side, 10)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 10)
	margin.add_child(box)
	add_child(margin)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	var cost := UiTheme.label(card.cost_text(), 18, UiTheme.GOLD if playable else UiTheme.INK_DIM)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(cost)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var kind := UiTheme.label(_kind_text(), 11, UiTheme.INK_DIM)
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(kind)

	var name_label := UiTheme.label(card.display_name(), 17, UiTheme.BONE if playable else UiTheme.INK_DIM)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var rule := HSeparator.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", UiTheme.size_for(13))
	_text.add_theme_color_override("default_color", UiTheme.INK if playable else UiTheme.INK_DIM)
	_text.text = card.rules_text()
	box.add_child(_text)

	if card.has_keyword(CardData.Keyword.EXHAUST):
		var mark := UiTheme.label(tr("ui.card.exhaust"), 12, UiTheme.BLOOD)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(mark)


static func kind_name(kind: int) -> String:
	match kind:
		CardData.Kind.ATTACK: return TranslationServer.translate("ui.card.kind.attack")
		CardData.Kind.SKILL: return TranslationServer.translate("ui.card.kind.skill")
		CardData.Kind.POWER: return TranslationServer.translate("ui.card.kind.power")
		CardData.Kind.CURSE: return TranslationServer.translate("ui.card.kind.curse")
	return ""


func _kind_text() -> String:
	return kind_name(card.kind)


func _style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UiTheme.PANEL_HI if selected else UiTheme.PANEL
	if not playable:
		s.bg_color = Color(UiTheme.PANEL, 0.55)
	s.set_corner_radius_all(6)
	s.set_border_width_all(2)
	if selected:
		s.border_color = UiTheme.GOLD
	elif playable:
		s.border_color = Color(UiTheme.INK_DIM, 0.65)
	else:
		s.border_color = Color(UiTheme.INK_DIM, 0.2)
	return s


func _ready() -> void:
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
	if _text != null:
		_text.text = bbcode


func get_rules_text() -> String:
	return _text.text if _text != null else ""
