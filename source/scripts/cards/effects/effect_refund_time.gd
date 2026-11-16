class_name EffectRefundTime
extends CardEffect


@export var minutes := 60


func apply(ctx: EffectContext) -> void:
	ctx.refund_turn_time(minutes)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.refund_hours").format({"hours": minutes / Balance.MINUTES_PER_HOUR})
