class_name Balance
extends Resource


const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 1440


@export var starting_remaining := 30 * MINUTES_PER_DAY

@export var starting_max_hp := 80


@export var turn_cost := 3 * MINUTES_PER_HOUR

@export var room_transition_cost := 1 * MINUTES_PER_HOUR

@export var room_cost_min := 1 * MINUTES_PER_HOUR

@export var room_cost_max := 3 * MINUTES_PER_HOUR

@export var fire_rest_cost := 4 * MINUTES_PER_HOUR

@export var fire_upgrade_cost := 2 * MINUTES_PER_HOUR

@export var shop_cost := 1 * MINUTES_PER_HOUR


@export var threat_step := 1 * MINUTES_PER_DAY

@export var expected_threat_steps := 30

@export_range(0.3, 2.0) var enemy_hp_scale := 1.0

@export_range(0.3, 2.0) var enemy_damage_scale := 1.0

@export var threat_hp_bonus_total := 1.0
@export var threat_damage_bonus_total := 1.0
@export_range(1.0, 4.0) var threat_curve := 2.0

@export var encounter_history_length := 2


@export var restored_per_normal_fight := 6 * MINUTES_PER_HOUR

@export var restored_minutes_per_hp := 12

@export var conversion_rate := 2

@export var conversion_cap := 36 * MINUTES_PER_HOUR

@export_range(0.0, 1.0) var fire_heal_fraction := 0.2


@export var reward_weight_common := 60
@export var reward_weight_uncommon := 34
@export var reward_weight_rare := 6
@export var reward_card_choices := 3

@export var price_common := 4 * MINUTES_PER_HOUR
@export var price_uncommon := 6 * MINUTES_PER_HOUR
@export var price_rare := 9 * MINUTES_PER_HOUR
@export var shop_card_count := 4

@export var price_removal := 6 * MINUTES_PER_HOUR
@export var price_removal_increment := 3 * MINUTES_PER_HOUR

## A relic costs this many times what a card of the same rarity costs. One dial
## rather than three prices, so the rarity ladder stays the ladder the cards use.
@export var relic_price_multiple := 2

@export var acts_per_run := 3

@export var starting_deck: Array[StringName] = []


@export var fights_and_events_per_act: Array[int] = [14, 19, 24]

@export var fights_min_per_act: Array[int] = [10, 12, 15]

@export var events_min_per_act: Array[int] = [2, 3, 3]

@export var empty_rooms_per_act: Array[int] = [0, 0, 0]
@export var rooms_per_act_affordable := 8

@export var fires_per_act: Array[int] = [2, 3, 4]
@export var shops_per_act: Array[int] = [1, 2, 2]

## How many rooms the start may touch. 1 makes the floor open on a corridor
## rather than a junction: there is no routing decision until the second room.
## 4 is the most a square can touch, so 4 means unconstrained.
@export var start_exits_per_act: Array[int] = [1, 4, 4]

@export var elite_min_travel_from_start := 10 * MINUTES_PER_HOUR

@export var elite_min_travel_apart := 5 * MINUTES_PER_HOUR

@export var elites_per_act: Array[int] = [2, 2, 3]


@export var boss_marked_on_map := false


@export var days_per_month := 100
@export var months_per_year := 100

@export var morning_starts_minute := 5 * MINUTES_PER_HOUR
@export var day_starts_minute := 8 * MINUTES_PER_HOUR
@export var evening_starts_minute := 17 * MINUTES_PER_HOUR
@export var night_starts_minute := 20 * MINUTES_PER_HOUR


static func default() -> Balance:
	var res := load("res://source/data/balance.tres")
	if res is Balance:
		return res
	push_warning("balance.tres missing or invalid; falling back to script defaults.")
	return Balance.new()


func content_in(act: int) -> int:
	return _per_act(fights_and_events_per_act, act)


func fights_min_in(act: int) -> int:
	return clampi(_per_act(fights_min_per_act, act), 0,
		content_in(act) - events_min_in(act))


func events_min_in(act: int) -> int:
	return clampi(_per_act(events_min_per_act, act), 0, content_in(act))


func fights_max_in(act: int) -> int:
	return maxi(fights_min_in(act), content_in(act) - events_min_in(act))


func empty_in(act: int) -> int:
	return _per_act(empty_rooms_per_act, act)


func fires_in(act: int) -> int:
	return _per_act(fires_per_act, act)


func shops_in(act: int) -> int:
	return _per_act(shops_per_act, act)


func elites_in(act: int) -> int:
	return _per_act(elites_per_act, act)


func start_exits_in(act: int) -> int:
	return clampi(_per_act(start_exits_per_act, act), 1, 4)


func rooms_in(act: int) -> int:
	return (2 + content_in(act) + empty_in(act)
		+ fires_in(act) + shops_in(act) + elites_in(act))


func _per_act(values: Array[int], act: int) -> int:
	if values.is_empty():
		return 0
	return values[clampi(act - 1, 0, values.size() - 1)]


func threat_hp_multiplier(level: int) -> float:
	return 1.0 + threat_hp_bonus_total * _threat_shape(level)


func threat_damage_multiplier(level: int) -> float:
	return 1.0 + threat_damage_bonus_total * _threat_shape(level)


func _threat_shape(level: int) -> float:
	var span := maxi(1, expected_threat_steps)
	return pow(clampf(float(level) / float(span), 0.0, 1.0), threat_curve)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()

	if threat_curve < 1.0:
		problems.append("threat_curve below 1.0 front-loads the ramp instead of back-loading it.")
	if expected_threat_steps != starting_remaining / threat_step:
		problems.append(
			"expected_threat_steps is %d but the budget holds %d; the curve reads it, not just the HUD."
			% [expected_threat_steps, starting_remaining / threat_step])

	if not is_equal_approx(enemy_hp_scale, 1.0):
		problems.append("enemy_hp_scale is %.2f; author the hp on the enemies instead."
			% enemy_hp_scale)

	if conversion_rate < 1:
		problems.append("conversion_rate must be at least 1.")

	if fire_upgrade_cost < 0:
		problems.append("fire_upgrade_cost must not be negative.")

	if conversion_cap < conversion_rate:
		problems.append(
			"Conversion is dead: a %dm cap at %d:1 rounds down to nothing. Raise conversion_cap above conversion_rate."
			% [conversion_cap, conversion_rate]
		)

	for act in range(1, acts_per_run + 1):
		if _per_act(start_exits_per_act, act) < 1:
			problems.append(
				"start_exits_per_act[%d] is below 1; a start room with no way out is a floor nobody leaves."
				% act)

	for named in [
		["fights_and_events_per_act", fights_and_events_per_act],
		["fights_min_per_act", fights_min_per_act],
		["events_min_per_act", events_min_per_act],
		["empty_rooms_per_act", empty_rooms_per_act],
		["fires_per_act", fires_per_act],
		["shops_per_act", shops_per_act],
		["elites_per_act", elites_per_act],
	]:
		var counts: Array = named[1]
		if counts.size() < acts_per_run:
			problems.append("%s lists %d acts but the run has %d; the last entry would be reused."
				% [named[0], counts.size(), acts_per_run])
		for value in counts:
			if int(value) < 0:
				problems.append("%s holds a negative count." % named[0])

	for act in range(1, acts_per_run + 1):
		var promised := _per_act(fights_min_per_act, act) + _per_act(events_min_per_act, act)
		if promised > content_in(act):
			problems.append(
				"Act %d promises %d fights and events out of %d rooms; they do not both fit."
				% [act, promised, content_in(act)])
		if fights_min_in(act) <= rooms_per_act_affordable:
			problems.append(
				"No room choice in act %d: %d fights guaranteed vs %d affordable. The guarantee must exceed affordable or the budget just buys the whole act."
				% [act, fights_min_in(act), rooms_per_act_affordable])

	for pair in [
		["starting_remaining", starting_remaining],
		["starting_max_hp", starting_max_hp],
		["turn_cost", turn_cost],
		["fire_rest_cost", fire_rest_cost],
		["threat_step", threat_step],
		["expected_threat_steps", expected_threat_steps],
	]:
		if int(pair[1]) <= 0:
			problems.append("%s must be positive." % pair[0])

	var turns := [morning_starts_minute, day_starts_minute, evening_starts_minute,
		night_starts_minute]
	for i in range(1, turns.size()):
		if int(turns[i]) <= int(turns[i - 1]):
			problems.append(
				"The sky must turn in order inside one day: %s." % str(turns))
			break
	if night_starts_minute >= MINUTES_PER_DAY:
		problems.append("night_starts_minute must fall inside the day it belongs to.")
	for pair in [["days_per_month", days_per_month], ["months_per_year", months_per_year]]:
		if int(pair[1]) < 1:
			problems.append("%s must be at least 1." % pair[0])

	if room_transition_cost < 0:
		problems.append("room_transition_cost must not be negative.")

	if elite_min_travel_from_start <= 0:
		problems.append("elite_min_travel_from_start must be positive; otherwise the rule does nothing.")
	if elite_min_travel_apart <= 0:
		problems.append("elite_min_travel_apart must be positive; otherwise the rule does nothing.")

	if room_cost_min <= 0:
		problems.append("room_cost_min must be positive.")
	if room_cost_max < room_cost_min:
		problems.append("room_cost_max is below room_cost_min.")
	if room_transition_cost < room_cost_min or room_transition_cost > room_cost_max:
		problems.append("room_transition_cost is the guess shown for an unseen room; keep it inside the real range.")
	for pair in [["room_cost_min", room_cost_min], ["room_cost_max", room_cost_max]]:
		if int(pair[1]) % MINUTES_PER_HOUR != 0:
			problems.append("%s is not a whole number of hours; the clock only shows hours." % pair[0])

	return problems
