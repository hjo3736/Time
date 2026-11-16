class_name EffectScalingDamage
extends CardEffect


@export var base := 4

@export var per_card := 3

@export var per_turn := 0

## Grows with the run rather than the fight: once for every midnight the run has
## passed. The only number on a card that taking too long makes bigger.
@export var per_day := 0


func amount_now(battle) -> int:
	if battle == null:
		return base
	return (base + per_card * battle.cards_played_this_turn
		+ per_turn * maxi(0, battle.turn - 1)
		+ per_day * battle.run().clock.day_index())


func apply(ctx: EffectContext) -> void:
	var hit := (base + per_card * ctx.cards_played_this_turn()
		+ per_turn * maxi(0, ctx.turn_index() - 1)
		+ per_day * ctx.days_elapsed())
	for target in ctx.targets:
		if ctx.is_alive(target):
			ctx.deal_damage(target, hit)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.damage").format({"amount": base}) + " " + _growth_text()


func describe_live(battle, source: int, target: int, targeting := CardTargeting.Mode.SINGLE_ENEMY, name_target := true) -> String:
	if battle == null:
		return describe(targeting, name_target)
	var raw := amount_now(battle)
	var victim: Stats = battle.combatants[target] if target >= 0 and target < battle.combatants.size() else null
	var shown: int = battle.preview_damage(target, raw, source) if victim != null else raw

	if shown == base:
		return describe(targeting, name_target)
	var colour := UiTheme.GOLD if shown > base else UiTheme.BLOOD
	var marked := "[color=#%s]%d[/color]" % [colour.to_html(false), shown]
	return tr("effect.damage").format({"amount": marked}) + " " + _growth_text()


func _growth_text() -> String:
	if per_card > 0:
		return tr("effect.grows_per_card").format({"n": per_card})
	if per_turn > 0:
		return tr("effect.grows_per_turn").format({"n": per_turn})
	if per_day > 0:
		return tr("effect.grows_per_day").format({"n": per_day})
	return ""


func faces_enemies() -> bool:
	return true
