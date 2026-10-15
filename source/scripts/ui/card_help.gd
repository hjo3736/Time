class_name CardHelp
extends RefCounted


static func tooltip_for(card: CardData) -> String:
	var lines := PackedStringArray()

	lines.append(_targeting_line(card))

	for effect in card.effects:
		var note := _effect_note(effect)
		if note != "" and not lines.has(note):
			lines.append(note)

	for pair in [
		[CardData.Keyword.EXHAUST, "exhaust"],
		[CardData.Keyword.RETAIN, "retain"],
		[CardData.Keyword.INNATE, "innate"],
		[CardData.Keyword.ETHEREAL, "ethereal"],
		[CardData.Keyword.UNPLAYABLE, "unplayable"],
	]:
		if card.has_keyword(pair[0]):
			lines.append("%s — %s" % [TranslationServer.translate("keyword.%s" % pair[1]), TranslationServer.translate("keyword.%s.help" % pair[1])])

	if card.has_keyword(CardData.Keyword.EXHAUST) and _refunds_time(card):
		lines.append(TranslationServer.translate("help.exhaust_reason"))

	return "\n".join(lines)


static func _targeting_line(card: CardData) -> String:
	match card.targeting:
		CardTargeting.Mode.SINGLE_ENEMY:
			return TranslationServer.translate("help.target.single")
		CardTargeting.Mode.ALL_ENEMIES:
			return TranslationServer.translate("help.target.all")
		CardTargeting.Mode.SELF:
			return TranslationServer.translate("help.target.self")
		CardTargeting.Mode.RANDOM_ENEMY:
			return TranslationServer.translate("help.target.random")
	return ""


static func _effect_note(effect: CardEffect) -> String:
	if effect is EffectApplyStatus:
		var id: StringName = (effect as EffectApplyStatus).status
		return "%s — %s" % [TranslationServer.translate("status.%s" % id), TranslationServer.translate("status.%s.help" % id)]
	if effect is EffectRefundTime:
		return TranslationServer.translate("help.refund")
	if effect is EffectDamage and (effect as EffectDamage).reroll_target_each_hit:
		return TranslationServer.translate("help.reroll")
	if effect is EffectScalingDamage or effect is EffectScalingBlock:
		return TranslationServer.translate("help.scaling")
	if effect is EffectVariableDamage or effect is EffectVariableBlock:
		return TranslationServer.translate("help.variable")
	if effect is EffectRestoreTime:
		return TranslationServer.translate("help.restore")
	return ""


static func _refunds_time(card: CardData) -> bool:
	for effect in card.effects:
		if effect is EffectRefundTime:
			return true
	return false
