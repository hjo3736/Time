class_name EffectDraw
extends CardEffect

@export var count := 1


func apply(ctx: EffectContext) -> void:
	ctx.draw_cards(count)


func describe(_targeting := CardTargeting.Mode.SINGLE_ENEMY, _name_target := true) -> String:
	var key := "effect.draw_one" if count == 1 else "effect.draw_many"
	return tr(key).format({"count": count})
