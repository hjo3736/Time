class_name Punch
extends Control


const RISE := 52.0
const LIFE := 0.55
const FLASH_LIFE := 0.22
const SHAKE_LIFE := 0.26
const SHAKE_STEPS := 6
const STAGGER := 0.09
const GUARD_SHAKE := 3.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func land(where: Rect2, amount: int, tint: Color, waited: float) -> void:
	_flash(where, tint, waited)
	_number(where.get_center(), amount, tint, waited)


func turn_aside(where: Rect2, absorbed: int, waited: float) -> void:
	_flash(where, UiTheme.INK, waited)
	_number(where.get_center(), absorbed, UiTheme.INK_DIM, waited)


func shake(target: Control, force: float, waited: float) -> void:
	if target == null or force <= 0.0:
		return
	var home := target.position
	var beat := create_tween()
	beat.tween_interval(waited)
	for i in SHAKE_STEPS:
		var falling := force * (1.0 - float(i) / float(SHAKE_STEPS))
		var aside := Vector2(
			falling * (1.0 if i % 2 == 0 else -1.0),
			falling * 0.4 * (1.0 if i % 3 == 0 else -1.0))
		beat.tween_property(target, "position", home + aside,
			SHAKE_LIFE / float(SHAKE_STEPS)).set_trans(Tween.TRANS_SINE)
	beat.tween_property(target, "position", home, SHAKE_LIFE / float(SHAKE_STEPS))


func _flash(where: Rect2, tint: Color, waited: float) -> void:
	var sheet := ColorRect.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.color = Color(tint, 0.0)
	sheet.position = where.position - Vector2(6, 6)
	sheet.size = where.size + Vector2(12, 12)
	add_child(sheet)

	var fade := create_tween()
	fade.tween_interval(waited)
	fade.tween_property(sheet, "color", Color(tint, 0.42), 0.04)
	fade.tween_property(sheet, "color", Color(tint, 0.0), FLASH_LIFE)
	fade.tween_callback(sheet.queue_free)


func _number(at: Vector2, amount: int, tint: Color, waited: float) -> void:
	var font_size := 26 + mini(amount, 30)
	var mark := UiTheme.label(str(amount), font_size, tint)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.size = Vector2(140, 60)
	mark.position = at - Vector2(70, 30)
	mark.modulate = Color(1, 1, 1, 0)
	mark.scale = Vector2(0.5, 0.5)
	mark.pivot_offset = mark.size * 0.5
	add_child(mark)

	var flight := create_tween()
	flight.tween_interval(waited)
	flight.tween_property(mark, "modulate", Color(1, 1, 1, 1), 0.05)
	flight.parallel().tween_property(mark, "scale", Vector2(1.25, 1.25), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flight.tween_property(mark, "scale", Vector2.ONE, 0.07)
	flight.tween_property(mark, "position", mark.position - Vector2(0, RISE), LIFE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.parallel().tween_property(mark, "modulate", Color(1, 1, 1, 0), LIFE)
	flight.tween_callback(mark.queue_free)
