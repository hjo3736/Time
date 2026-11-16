class_name EffectVariableDamage
extends CardEffect


@export var per_hour := 5


func apply(ctx: EffectContext) -> void:
	var hours := 0
	if ctx is BattleEffectContext:
		hours = (ctx as BattleEffectContext).variable_amount
	if hours <= 0:
		return
	for target in ctx.targets:
		if ctx.is_alive(target):
			ctx.deal_damage(target, per_hour * hours)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.per_hour_damage").format({"amount": per_hour})


func faces_enemies() -> bool:
	return true
