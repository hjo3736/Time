class_name EnemyData
extends Resource


enum Tier { NORMAL, ELITE, BOSS }

@export var id := &""
@export var name_key := &""
@export var tier := Tier.NORMAL

## Which act's pool this belongs to. An act is how far gone its Askew are — see
## docs/setting.md — so the roster is split three ways rather than reskinned, and
## an encounter may not mix acts.
@export var act := 1

@export var hp_min := 20
@export var hp_max := 26

@export var intents: Array[EnemyIntent] = []
@export var morning_intents: Array[EnemyIntent] = []
@export var day_intents: Array[EnemyIntent] = []
@export var evening_intents: Array[EnemyIntent] = []
@export var night_intents: Array[EnemyIntent] = []

@export var behavior_script: Script = null

@export var restored_multiplier := 1.0


func spawn(balance: Balance, rng: RandomNumberGenerator) -> Stats:
	var c := Stats.new()
	c.name_key = name_key
	c.max_hp = rng.randi_range(hp_min, maxi(hp_min, hp_max))
	c.hp = c.max_hp
	c.restored_value = roundi(c.max_hp * balance.restored_minutes_per_hp * restored_multiplier)
	c.intents = intents.duplicate()
	c.morning_intents = morning_intents.duplicate()
	c.day_intents = day_intents.duplicate()
	c.evening_intents = evening_intents.duplicate()
	c.night_intents = night_intents.duplicate()
	if behavior_script != null:
		c.behavior = behavior_script.new()
	return c


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var label := String(id) if id != &"" else "<unnamed enemy>"

	if id == &"":
		problems.append("%s: id is required." % label)
	if name_key == &"":
		problems.append("%s: name_key is required." % label)
	if hp_min <= 0 or hp_max < hp_min:
		problems.append("%s: hp range %d-%d is not usable." % [label, hp_min, hp_max])
	if intents.is_empty():
		problems.append("%s: has no intents, so it would stand there forever." % label)
	for intent in intents:
		if intent == null:
			problems.append("%s: intent list contains a null entry." % label)
	if behavior_script != null and not (behavior_script.new() is EnemyBehavior):
		problems.append("%s: behavior_script is not an EnemyBehavior." % label)

	return problems
