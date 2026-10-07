class_name RunClock
extends RefCounted


signal time_changed
signal threat_level_changed(new_level: int)
signal warden_expired

enum Source { TURN, TRAVEL, FIRE, SHOP, EVENT }
enum Daytime { MORNING, DAY, EVENING, NIGHT }

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

## When morning, day, evening and night begin, in minutes of the day. Seeded from
## Balance and rewritten by RunState whenever the relics change, because a relic
## may reshape the sky and the clock is what everything else asks.
var sky_bounds: PackedInt32Array

var _balance: Balance
var _seed := 0
var _remaining: int
var _elapsed: int
var _restored: int
var _expired_announced := false
var _spent: Dictionary = {}


func _init(p_balance: Balance = null, starting_remaining_override: int = -1,
		p_seed: int = 0) -> void:
	_balance = p_balance if p_balance != null else Balance.default()
	_seed = p_seed
	var start := starting_remaining_override if starting_remaining_override >= 0 else _balance.starting_remaining
	_remaining = maxi(0, start)
	_elapsed = 0
	_restored = 0
	sky_bounds = default_sky_bounds()
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


## Restored lost rather than spent: it goes back into the leak, so it never
## reaches a shop or a fire. Clamped at nothing — an empty pool has nothing to
## spill — and returns what actually left, so a caller can say how much.
func spill(minutes: int) -> int:
	var lost := clampi(minutes, 0, _restored)
	if lost == 0:
		return 0
	_restored -= lost
	time_changed.emit()
	return lost


func convertible_restored() -> int:
	# What can actually be converted, not what is on hand. A conversion yields
	# whole hours, so a remainder below the unit converts to nothing at all.
	var available := mini(_restored, _balance.conversion_cap)
	return available - available % conversion_unit()


func conversion_yield(restored_minutes: int) -> int:
	return restored_minutes / _balance.conversion_rate


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


const YEAR_LIMIT := 9999


static func seed_from_date(year: int, month: int, day: int, hour: int = 0) -> int:
	return (clampi(year, 0, YEAR_LIMIT) * 1000000
		+ clampi(month, 0, 99) * 10000
		+ clampi(day, 0, 99) * 100
		+ clampi(hour, 0, 23))


static func date_from_seed(seed_value: int) -> Dictionary:
	var whole: int = clampi(seed_value, 0, YEAR_LIMIT * 1000000 + 999999)
	return {
		"year": whole / 1000000,
		"month": (whole / 10000) % 100,
		"day": (whole / 100) % 100,
		"hour": clampi(whole % 100, 0, 23),
	}


func opening_minute() -> int:
	return int(date_from_seed(_seed)["hour"]) * Balance.MINUTES_PER_HOUR


func minute_of_day() -> int:
	return (opening_minute() + _elapsed) % Balance.MINUTES_PER_DAY


func default_sky_bounds() -> PackedInt32Array:
	return PackedInt32Array([
		_balance.morning_starts_minute,
		_balance.day_starts_minute,
		_balance.evening_starts_minute,
		_balance.night_starts_minute,
	])


func daytime() -> int:
	var now := minute_of_day()
	if now < sky_bounds[0]:
		return Daytime.NIGHT
	if now < sky_bounds[1]:
		return Daytime.MORNING
	if now < sky_bounds[2]:
		return Daytime.DAY
	if now < sky_bounds[3]:
		return Daytime.EVENING
	return Daytime.NIGHT


func is_night() -> bool:
	return daytime() == Daytime.NIGHT


func minutes_until_sky_turns() -> int:
	var now := minute_of_day()
	for turn in sky_bounds:
		if now < int(turn):
			return int(turn) - now
	return Balance.MINUTES_PER_DAY - now + sky_bounds[0]


func date_at(minutes_from_start: int) -> Dictionary:
	var total: int = opening_minute() + maxi(0, minutes_from_start)
	var days_in := total / Balance.MINUTES_PER_DAY
	var minute := total % Balance.MINUTES_PER_DAY

	var opened := date_from_seed(_seed)
	var day: int = int(opened["day"]) + days_in
	var month: int = int(opened["month"]) + day / _balance.days_per_month
	day = day % _balance.days_per_month
	var year: int = int(opened["year"]) + month / _balance.months_per_year
	month = month % _balance.months_per_year

	return {
		"year": year, "month": month, "day": day,
		"hour": minute / Balance.MINUTES_PER_HOUR,
		"minute": minute % Balance.MINUTES_PER_HOUR,
	}


func format_date_of(marks: Dictionary) -> String:
	return TranslationServer.translate("time.date").format({
		"year": marks["year"],
		"month": "%02d" % int(marks["month"]),
		"day": "%02d" % int(marks["day"]),
		"hour": "%02d" % int(marks["hour"]),
	})
func format_clock() -> String:
	return format_date_of(date_at(_elapsed))


func format_deadline() -> String:
	return format_date_of(date_at(_elapsed + _remaining))


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
