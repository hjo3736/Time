class_name DateView
extends OverlayView


signal chosen(seed_value: int)

const PLATE := Vector2(560, 310)

var _year: LineEdit
var _month: LineEdit
var _day: LineEdit
var _hour: LineEdit
var _reads: Label


func open_on(seed_value: int) -> void:
	var marks := RunClock.date_from_seed(seed_value)
	set_compact(true, PLATE)
	heading(tr("ui.date.title"))
	clear_body()
	relabel_chrome()

	var box := body()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var told := UiTheme.label(tr("ui.date.body"), 15, UiTheme.INK_DIM)
	told.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	told.custom_minimum_size = Vector2(420, 0)
	told.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(told)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(row)
	_year = _field(row, tr("ui.date.year"), "%04d" % int(marks["year"]), 4, 110)
	_month = _field(row, tr("ui.date.month"), "%02d" % int(marks["month"]), 2, 80)
	_day = _field(row, tr("ui.date.day"), "%02d" % int(marks["day"]), 2, 80)
	_hour = _field(row, tr("ui.date.hour"), "%02d" % int(marks["hour"]), 2, 80)

	_reads = UiTheme.label("", 22, UiTheme.BONE)
	_reads.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reads.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_reads)

	var go := Button.new()
	go.text = tr("ui.date.depart")
	go.custom_minimum_size = Vector2(240, 46)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func() -> void: chosen.emit(entered_seed()))
	box.add_child(go)

	_retell()


func entered_seed() -> int:
	return RunClock.seed_from_date(
		_read(_year), _read(_month), _read(_day), _read(_hour))


func _read(field: LineEdit) -> int:
	var digits := ""
	for c in field.text:
		if c >= "0" and c <= "9":
			digits += c
	return 0 if digits.is_empty() else digits.to_int()


func _field(row: HBoxContainer, caption: String, value: String,
		digits: int, width: float) -> LineEdit:
	# The unit sits after its number, the way the date is read: 9550년 28월.
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 4)

	var edit := LineEdit.new()
	edit.text = value
	edit.max_length = digits
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(width, 40)
	edit.text_changed.connect(func(_t: String) -> void: _retell())
	pair.add_child(edit)

	var tag := UiTheme.label(caption, 16, UiTheme.INK_DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pair.add_child(tag)

	row.add_child(pair)
	return edit


func _retell() -> void:
	if _reads == null:
		return
	var clock := RunClock.new(null, -1, entered_seed())
	_reads.text = clock.format_clock()
