class_name EffectRestoreTime
extends CardEffect


@export var hours := 2


func apply(ctx: EffectContext) -> void:
	ctx.restore_time(hours * Balance.MINUTES_PER_HOUR)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	return tr("effect.restore").format({"hours": hours})
