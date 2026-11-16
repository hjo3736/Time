class_name EffectVariableBlock
extends CardEffect


@export var per_hour := 5


## The guarding half of 다 쓰기: an X card, so the hours are whatever the turn has
## left, and the block is by the hour. What it is for is the hour that was going
## to be lost anyway.
func apply(ctx: EffectContext) -> void:
	var hours := 0
	if ctx is BattleEffectContext:
		hours = (ctx as BattleEffectContext).variable_amount
	if hours <= 0:
		return
	ctx.gain_block(ctx.source, per_hour * hours)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.per_hour_block").format({"amount": per_hour})
