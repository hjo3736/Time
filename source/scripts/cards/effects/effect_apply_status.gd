class_name EffectApplyStatus
extends CardEffect


@export var status := &"softened"
@export var stacks := 2
@export var on_self := false


func apply(ctx: EffectContext) -> void:
	if on_self:
		ctx.apply_status(ctx.source, status, stacks)
		return
	for target in ctx.targets:
		if ctx.is_alive(target):
			ctx.apply_status(target, status, stacks)


func describe(targeting := CardTargeting.Mode.SINGLE_ENEMY, name_target := true) -> String:
	if not on_self and (not name_target or not names_its_target(targeting)):
		return tr("effect.status_bare").format({
			"stacks": stacks, "status": tr("status.%s" % status)})
	return tr("effect.status").format({
		"stacks": stacks,
		"status": tr("status.%s" % status),
		"who": tr("target.self" if on_self else who_key(targeting)),
	})


func faces_enemies() -> bool:
	return not on_self
