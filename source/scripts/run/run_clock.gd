class_name RunClock
extends RefCounted


signal time_changed
signal threat_level_changed(new_level: int)
signal warden_expired

enum Source { TURN, TRAVEL, FIRE, SHOP, EVENT }

var balance: Balance:
	get:
		return _balance

var remaining: int:
	get:
		return _remaining

var elapsed: int:
	get:
		return _elapsed

var restored: int:
	get:
		return _restored

var _balance: Balance
var _remaining: int
var _elapsed: int
var _restored: int
var _expired_announced := false
var _spent: Dictionary = {}


func _init(p_balance: Balance = null, starting_remaining_override: int = -1) -> void:
	_balance = p_balance if p_balance != null else Balance.default()
	var start := starting_remaining_override if starting_remaining_override >= 0 else _balance.starting_remaining
	_remaining = maxi(0, start)
	_elapsed = 0
	_restored = 0
	for source in Source.values():
		_spent[source] = 0


func advance(minutes: int, source: Source) -> void:
	if minutes < 0:
		push_error("RunClock.advance() refuses negative minutes; elapsed is one-way.")
		return
	if minutes == 0:
		return

	var previous_level := threat_level()

	_remaining = maxi(0, _remaining - minutes)
	_elapsed += minutes
	_spent[source] = int(_spent[source]) + minutes

	time_changed.emit()

	var level := threat_level()
	if level != previous_level:
		threat_level_changed.emit(level)

	if _remaining == 0 and not _expired_announced:
		_expired_announced = true
		warden_expired.emit()


func advance_turn() -> void:
	advance(_balance.turn_cost, Source.TURN)


func advance_room() -> void:
	advance(_balance.room_transition_cost, Source.TRAVEL)


func is_expired() -> bool:
	return _remaining == 0


func restore(minutes: int) -> void:
	if minutes <= 0:
		return
	_restored += maxi(Balance.MINUTES_PER_HOUR,
		roundi(float(minutes) / Balance.MINUTES_PER_HOUR) * Balance.MINUTES_PER_HOUR)
	time_changed.emit()


func spend_restored(minutes: int) -> bool:
	if minutes <= 0 or minutes > _restored:
		return false
	_restored -= minutes
	time_changed.emit()
	return true


func conversion_unit() -> int:
	return _balance.conversion_rate * Balance.MINUTES_PER_HOUR


func convertible_restored() -> int:
	# What can actually be converted, not what is on hand. A conversion yields
	# whole hours, so a remainder below the unit converts to nothing at all.
	var available := mini(_restored, _balance.conversion_cap)
	return available - available % conversion_unit()


func conversion_yield(restored_minutes: int) -> int:
	return restored_minutes / _balance.conversion_rate


func net_from_conversion(restored_minutes: int) -> int:
	return conversion_yield(restored_minutes) - _balance.fire_cost


func convert(restored_minutes: int) -> int:
	var taken := clampi(restored_minutes, 0, convertible_restored())
	taken -= taken % conversion_unit()
	if taken == 0:
		return 0

	var gained := conversion_yield(taken)
	_restored -= taken
	_remaining += gained
	_expired_announced = false
	time_changed.emit()
	return gained


func threat_level() -> int:
	return _elapsed / _balance.threat_step


func minutes_to_next_threat() -> int:
	return _balance.threat_step - (_elapsed % _balance.threat_step)


func threat_progress() -> String:
	return "Threat %d / ~%d" % [threat_level(), _balance.expected_threat_steps]


func project(minutes: int) -> Dictionary:
	var projected_elapsed := _elapsed + minutes
	var level := projected_elapsed / _balance.threat_step
	return {
		"remaining": maxi(0, _remaining - minutes),
		"elapsed": projected_elapsed,
		"threat_level": level,
		"crosses_threat": level > threat_level(),
		"fatal": minutes >= _remaining,
	}


func can_afford(minutes: int) -> bool:
	return minutes < _remaining


func spent_by_source() -> Dictionary:
	return _spent.duplicate()


func format_clock() -> String:
	var total := _balance.clock_start_minute + _elapsed
	var day := total / Balance.MINUTES_PER_DAY + 1
	var minute_of_day := total % Balance.MINUTES_PER_DAY
	return "Day %d - %02d:%02d" % [
		day,
		minute_of_day / Balance.MINUTES_PER_HOUR,
		minute_of_day % Balance.MINUTES_PER_HOUR,
	]


static func format_span(minutes: int) -> String:
	var hours := roundi(float(minutes) / Balance.MINUTES_PER_HOUR)
	return TranslationServer.translate("time.hours").format({"n": hours})


func to_dict() -> Dictionary:
	return {
		"remaining": _remaining,
		"elapsed": _elapsed,
		"restored": _restored,
		"spent": _spent.duplicate(),
	}


static func from_dict(data: Dictionary, p_balance: Balance = null) -> RunClock:
	var clock := RunClock.new(p_balance, int(data.get("remaining", 0)))
	clock._elapsed = int(data.get("elapsed", 0))
	clock._restored = int(data.get("restored", 0))
	clock._expired_announced = clock._remaining == 0
	var spent: Dictionary = data.get("spent", {})
	for source in Source.values():
		clock._spent[source] = int(spent.get(source, 0))
	return clock
