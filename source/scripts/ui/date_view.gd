class_name DateView
extends OverlayView


signal chosen(seed_value: int)

const PLATE := Vector2(560, 310)

## The form is the scene, on the overlay frame it inherits. Opening it only puts
## a date in the fields.
const SCENE := preload("res://source/scenes/ui/date_view.tscn")

# The unit sits after its number, the way the date is read: 9550년 28월.
@onready var _year := %Year as LineEdit
@onready var _month := %Month as LineEdit
@onready var _day := %Day as LineEdit
@onready var _hour := %Hour as LineEdit
@onready var _reads := %Reads as Label


## Always make one through here, never DateView.new(): new() is the script
## without the scene it shares with the other overlays.
static func create() -> DateView:
	return SCENE.instantiate() as DateView


func _ready() -> void:
	super._ready()
	for field in [_year, _month, _day, _hour]:
		(field as LineEdit).text_changed.connect(func(_t: String) -> void: _retell())
	(%Depart as Button).pressed.connect(func() -> void: chosen.emit(entered_seed()))


func open_on(seed_value: int) -> void:
	var marks := RunClock.date_from_seed(seed_value)
	set_compact(true, PLATE)
	heading(tr("ui.date.title"))
	relabel_chrome()

	_year.text = "%04d" % int(marks["year"])
	_month.text = "%02d" % int(marks["month"])
	_day.text = "%02d" % int(marks["day"])
	_hour.text = "%02d" % int(marks["hour"])
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


func _retell() -> void:
	if _reads == null:
		return
	var clock := RunClock.new(null, -1, entered_seed())
	_reads.text = clock.format_clock()
