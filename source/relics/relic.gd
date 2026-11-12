class_name Relic
extends Resource


enum Rarity { COMMON, UNCOMMON, RARE, BOSS }

@export var id := &""
@export var name_key := &""
@export var text_key := &""

## BOSS is not a step above RARE, it is a separate shelf: boss relics are handed
## out by act bosses and never rolled anywhere else, so they may be strange in
## ways a relic on the general table could not afford to be.
@export var rarity := Rarity.COMMON


func display_name() -> String:
	return tr(name_key)


func description() -> String:
	return tr(text_key)


func on_battle_start(_run: RunState, _battle) -> void:
	pass


func on_turn_start(_run: RunState, _battle) -> void:
	pass


func on_enemy_defeated(_run: RunState, _battle, _enemy: EnemyStats) -> void:
	pass


func modify_turn_budget(_run: RunState, base: int) -> int:
	return base


func modify_card_cost(_run: RunState, _battle, _card: CardData, base: int) -> int:
	return base


func modify_restored(_run: RunState, base: int) -> int:
	return base


func modify_room_cost(_run: RunState, base: int) -> int:
	return base


## The four minutes-of-day at which morning, day, evening and night begin. A
## relic that reshapes the sky rewrites them; RunState folds every relic's answer
## together and hands the result to the clock.
func modify_sky_bounds(_run: RunState, bounds: PackedInt32Array) -> PackedInt32Array:
	return bounds


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var label := String(id) if id != &"" else "<unnamed relic>"
	if id == &"":
		problems.append("%s: id is required." % label)
	if name_key == &"":
		problems.append("%s: name_key is required." % label)
	if text_key == &"":
		problems.append("%s: text_key is required — a passive the player cannot read is a bug." % label)
	return problems
