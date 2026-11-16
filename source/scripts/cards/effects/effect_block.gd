class_name EffectBlock
extends CardEffect


@export var amount := 5


func apply(ctx: EffectContext) -> void:
	ctx.gain_block(ctx.source, amount)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.block").format({"amount": amount})
