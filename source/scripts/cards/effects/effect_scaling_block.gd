class_name EffectScalingBlock
extends CardEffect


@export var base := 5
@export var per_card := 0
@export var per_turn := 3


func amount_now(battle) -> int:
	if battle == null:
		return base
	return base + per_card * battle.cards_played_this_turn + per_turn * maxi(0, battle.turn - 1)


func apply(ctx: EffectContext) -> void:
	ctx.gain_block(ctx.source,
		base + per_card * ctx.cards_played_this_turn() + per_turn * maxi(0, ctx.turn_index() - 1))


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.block").format({"amount": base}) + " " + _growth_text()


func describe_live(battle, _source: int, _target: int, targeting := CardTargeting.Mode.SINGLE_ENEMY, name_target := true) -> String:
	if battle == null:
		return describe(targeting, name_target)
	var shown := amount_now(battle)
	if shown == base:
		return describe(targeting, name_target)
	var marked := "[color=#%s]%d[/color]" % [UiTheme.GOLD.to_html(false), shown]
	return tr("effect.block").format({"amount": marked}) + " " + _growth_text()


func _growth_text() -> String:
	if per_card > 0:
		return tr("effect.grows_per_card").format({"n": per_card})
	if per_turn > 0:
		return tr("effect.grows_per_turn").format({"n": per_turn})
	return ""
