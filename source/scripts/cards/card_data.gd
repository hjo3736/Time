class_name CardData
extends Resource


enum Kind { ATTACK, SKILL, POWER, CURSE, STATUS }

enum Rarity { STARTER, COMMON, UNCOMMON, RARE, SPECIAL }

enum Lane { RUSH, ENGINE, CHRONOMANCY }

const COST_VARIABLE := -1

const MAX_COST_HOURS := 3

@export var id := &""

@export var name_key := &""
@export var kind := Kind.ATTACK
@export var rarity := Rarity.COMMON

@export var class_id := &"warden"

@export var lanes: Array[Lane] = []

@export var cost_hours := 1

@export var targeting := CardTargeting.Mode.SINGLE_ENEMY

@export var effects: Array[CardEffect] = []

@export_flags("Exhaust", "Retain", "Innate", "Ethereal", "Unplayable") var keywords := 0

@export var upgrade: CardUpgrade = null

@export var text_key := &""

var name_suffix := ""

var upgrade_level := 0


enum Keyword { EXHAUST = 1, RETAIN = 2, INNATE = 4, ETHEREAL = 8, UNPLAYABLE = 16 }


func has_keyword(keyword: Keyword) -> bool:
	return (keywords & int(keyword)) != 0


func is_variable_cost() -> bool:
	return cost_hours == COST_VARIABLE


func cost_minutes() -> int:
	if is_variable_cost():
		return 0
	return cost_hours * Balance.MINUTES_PER_HOUR


func in_lane(lane: Lane) -> bool:
	return lanes.has(lane)


func can_upgrade() -> bool:
	return upgrade != null and upgrade_level == 0


func upgraded() -> CardData:
	if not can_upgrade():
		return self

	var out := CardData.new()
	out.id = id
	out.name_key = name_key
	out.name_suffix = name_suffix + upgrade.name_suffix
	out.kind = kind
	out.rarity = rarity
	out.class_id = class_id
	out.lanes = lanes.duplicate()
	out.upgrade_level = upgrade_level + 1
	out.upgrade = null

	out.cost_hours = cost_hours if upgrade.cost_hours == CardUpgrade.INHERIT else upgrade.cost_hours
	out.targeting = upgrade.targeting if upgrade.override_targeting else targeting
	out.effects = upgrade.effects.duplicate() if not upgrade.effects.is_empty() else effects.duplicate()
	out.keywords = (keywords | upgrade.add_keywords) & ~upgrade.remove_keywords
	out.text_key = upgrade.text_key if upgrade.text_key != &"" else text_key

	return out


func display_name() -> String:
	return tr(name_key) + name_suffix


func rules_text() -> String:
	if text_key != &"":
		return tr(text_key)
	var parts := PackedStringArray()
	var named := false
	for effect in effects:
		var line: String = effect.describe(targeting, not named)
		if effect.faces_enemies():
			named = true
		if line != "":
			parts.append(line)
	return " ".join(parts)


func rules_text_live(battle, source: int, target: int) -> String:
	if text_key != &"":
		return tr(text_key)
	var parts := PackedStringArray()
	var named := false
	# The preview has to be weighed the way the play will be, or a number shown on
	# the card is not the number that lands.
	if battle != null:
		battle.cost_in_play = battle.cost_of(self)
	for effect in effects:
		var line: String = effect.describe_live(battle, source, target, targeting, not named)
		if effect.faces_enemies():
			named = true
		if line != "":
			parts.append(line)
	if battle != null:
		battle.cost_in_play = -1
	return " ".join(parts)


func cost_text() -> String:
	if is_variable_cost():
		return "X"
	return str(cost_hours)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var label := String(id) if id != &"" else "<unnamed card>"

	if id == &"":
		problems.append("%s: id is required." % label)
	if name_key == &"":
		problems.append("%s: name_key is required." % label)
	if class_id == &"":
		problems.append("%s: class_id is required, even while there is only one class." % label)

	if not is_variable_cost() and (cost_hours < 0 or cost_hours > MAX_COST_HOURS):
		problems.append("%s: cost_hours %d is outside 0-%d. Costs are whole hours." % [label, cost_hours, MAX_COST_HOURS])

	if effects.is_empty() and kind != Kind.CURSE and kind != Kind.STATUS:
		problems.append("%s: has no effects." % label)

	for effect in effects:
		if effect == null:
			problems.append("%s: effect list contains a null entry." % label)

	if kind == Kind.ATTACK and targeting == CardTargeting.Mode.SELF:
		problems.append("%s: an attack targeting SELF is almost certainly a mistake." % label)

	if has_keyword(Keyword.UNPLAYABLE) and not effects.is_empty():
		problems.append("%s: unplayable cards cannot have effects that would never run." % label)

	if upgrade != null:
		if upgrade.cost_hours != CardUpgrade.INHERIT \
				and upgrade.cost_hours != COST_VARIABLE \
				and (upgrade.cost_hours < 0 or upgrade.cost_hours > MAX_COST_HOURS):
			problems.append("%s: upgrade cost_hours %d is outside 0-%d." % [label, upgrade.cost_hours, MAX_COST_HOURS])
		if upgrade.effects.is_empty() \
				and upgrade.cost_hours == CardUpgrade.INHERIT \
				and not upgrade.override_targeting \
				and upgrade.add_keywords == 0 \
				and upgrade.remove_keywords == 0 \
				and upgrade.text_key == &"":
			problems.append("%s: upgrade block changes nothing." % label)

	return problems
