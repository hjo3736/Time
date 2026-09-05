class_name Balance
extends Resource


const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 1440


@export var starting_remaining := 336 * MINUTES_PER_HOUR

@export var starting_max_hp := 70


@export var turn_cost := 3 * MINUTES_PER_HOUR

@export var room_transition_cost := 1 * MINUTES_PER_HOUR

@export var room_cost_min := 1 * MINUTES_PER_HOUR

@export var room_cost_max := 3 * MINUTES_PER_HOUR

@export var fire_cost := 8 * MINUTES_PER_HOUR

@export var shop_cost := 1 * MINUTES_PER_HOUR


@export var threat_step := 48 * MINUTES_PER_HOUR

@export var expected_threat_steps := 14

@export_range(0.3, 2.0) var enemy_hp_scale := 1.0

@export_range(0.3, 2.0) var enemy_damage_scale := 1.0

@export var threat_hp_bonus_per_step := 0.08
@export var threat_damage_bonus_per_step := 0.06

@export var encounter_history_length := 2


@export var restored_per_normal_fight := 6 * MINUTES_PER_HOUR

@export var restored_minutes_per_hp := 12

@export var conversion_rate := 2

@export var conversion_cap := 36 * MINUTES_PER_HOUR

@export_range(0.0, 1.0) var fire_heal_fraction := 0.3


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

@export var acts_per_run := 3

@export var starting_deck: Array[StringName] = []


@export var rooms_per_act_available := 19
@export var rooms_per_act_affordable := 8

@export var fires_per_act := 2
@export var shops_per_act := 1

@export var elites_per_act := 2
@export var events_per_act := 3


@export var clock_start_minute := 8 * MINUTES_PER_HOUR


static func default() -> Balance:
	var res := load("res://source/data/balance.tres")
	if res is Balance:
		return res
	push_warning("balance.tres missing or invalid; falling back to script defaults.")
	return Balance.new()


func validate() -> PackedStringArray:
	var problems := PackedStringArray()

	if not is_equal_approx(enemy_hp_scale, 1.0):
		problems.append("enemy_hp_scale is %.2f; author the hp on the enemies instead."
			% enemy_hp_scale)

	if conversion_rate < 1:
		problems.append("conversion_rate must be at least 1.")

	var best_yield := conversion_cap / maxi(1, conversion_rate)
	if best_yield <= fire_cost:
		problems.append(
			"Conversion is a net loss: a full %dm conversion yields %dm against a %dm fire. Raise conversion_cap above fire_cost * conversion_rate."
			% [conversion_cap, best_yield, fire_cost]
		)

	if rooms_per_act_available <= rooms_per_act_affordable:
		problems.append(
			"No room choice: %d available vs %d affordable. Available must exceed affordable or the budget just buys the whole act."
			% [rooms_per_act_available, rooms_per_act_affordable]
		)

	for pair in [
		["starting_remaining", starting_remaining],
		["starting_max_hp", starting_max_hp],
		["turn_cost", turn_cost],
		["fire_cost", fire_cost],
		["threat_step", threat_step],
		["expected_threat_steps", expected_threat_steps],
	]:
		if int(pair[1]) <= 0:
			problems.append("%s must be positive." % pair[0])

	if room_transition_cost < 0:
		problems.append("room_transition_cost must not be negative.")

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
