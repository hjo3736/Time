class_name EffectDamage
extends CardEffect


@export var amount := 6

@export var times := 1

@export var reroll_target_each_hit := false


func apply(ctx: EffectContext) -> void:
	for i in maxi(1, times):
		if reroll_target_each_hit:
			var target := ctx.random_living_enemy()
			if target >= 0:
				ctx.deal_damage(target, amount)
			continue
		for target in ctx.targets:
			if ctx.is_alive(target):
				ctx.deal_damage(target, amount)


func describe(targeting := CardTargeting.Mode.SINGLE_ENEMY, name_target := true) -> String:
	return _line(amount, targeting, name_target)


func _line(shown: Variant, targeting: int, name_target := true) -> String:
	if name_target and names_its_target(targeting):
		var who := tr(who_key(targeting))
		if times > 1:
			return tr("effect.damage_multi_at").format({
				"who": who, "amount": shown, "times": times})
		return tr("effect.damage_at").format({"who": who, "amount": shown})
	if times > 1:
		return tr("effect.damage_multi").format({"amount": shown, "times": times})
	return tr("effect.damage").format({"amount": shown})


func describe_live(battle, source: int, target: int, targeting := CardTargeting.Mode.SINGLE_ENEMY, name_target := true) -> String:
	if battle == null:
		return describe(targeting, name_target)
	var victim: Combatant = battle.combatants[target] if target >= 0 and target < battle.combatants.size() else null
	if victim == null:
		return describe(targeting, name_target)

	var shown: int = battle.preview_damage(target, amount, source)
	if shown == amount:
		return describe(targeting, name_target)

	var colour := UiTheme.GOLD if shown > amount else UiTheme.BLOOD
	var marked := "[color=#%s]%d[/color]" % [colour.to_html(false), shown]
	return _line(marked, targeting, name_target)


func faces_enemies() -> bool:
	return true
