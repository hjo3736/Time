extends SceneTree


var _failures := 0


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func damage(amount: int) -> EffectDamage:
	var e := EffectDamage.new()
	e.amount = amount
	return e


func strike() -> CardData:
	var c := CardData.new()
	c.id = &"take"
	c.name_key = &"card.take.name"
	c.kind = CardData.Kind.ATTACK
	c.rarity = CardData.Rarity.STARTER
	c.cost_hours = 1
	c.targeting = CardTargeting.Mode.SINGLE_ENEMY
	c.effects = [damage(6)]
	return c


func _init() -> void:
	TranslationServer.set_locale("en")

	print("\n-- costs are whole hours, minutes appear only at the seam --")
	var c := strike()
	check("authored in hours", c.cost_hours, 1)
	check("converted for the clock", c.cost_minutes(), 60)
	check("displayed bare", c.cost_text(), "1")
	c.cost_hours = CardData.COST_VARIABLE
	check("X cost", c.cost_text(), "X")
	check("X costs nothing up front", c.cost_minutes(), 0)

	print("\n-- rules text is composed, never authored --")
	var multi := strike()
	multi.effects = [damage(6), EffectDraw.new()]
	check("composed", multi.rules_text(), "Deal 6 damage. Draw 1 card.")
	multi.text_key = &"card.delay.text"
	check("override wins", multi.rules_text(), "Time passes.")

	print("\n-- upgrading returns a new card and leaves the base alone --")
	var base := strike()
	var up := CardUpgrade.new()
	up.effects = [damage(9)]
	base.upgrade = up
	var plus := base.upgraded()
	check("name", plus.display_name(), "Take+")
	check("upgraded text", plus.rules_text(), "Deal 9 damage.")
	check("base untouched", base.rules_text(), "Deal 6 damage.")
	check("level recorded", plus.upgrade_level, 1)
	check("base is still upgradable", base.can_upgrade(), true)
	check("the product is not", plus.can_upgrade(), false)
	check("upgrading again is a no-op", plus.upgraded(), plus)

	print("\n-- upgrade inherits what it does not override --")
	check("cost inherited", plus.cost_hours, 1)
	check("targeting inherited", plus.targeting, CardTargeting.Mode.SINGLE_ENEMY)
	check("id inherited", plus.id, &"take")
	check("class inherited", plus.class_id, &"warden")

	print("\n-- upgrade can change cost, targeting and keywords --")
	var body := strike()
	body.keywords = CardData.Keyword.EXHAUST
	var u2 := CardUpgrade.new()
	u2.cost_hours = 0
	u2.override_targeting = true
	u2.targeting = CardTargeting.Mode.ALL_ENEMIES
	u2.remove_keywords = CardData.Keyword.EXHAUST
	u2.add_keywords = CardData.Keyword.RETAIN
	body.upgrade = u2
	var b2 := body.upgraded()
	check("cost overridden", b2.cost_hours, 0)
	check("free card reads 0", b2.cost_text(), "0")
	check("targeting overridden", b2.targeting, CardTargeting.Mode.ALL_ENEMIES)
	check("exhaust dropped", b2.has_keyword(CardData.Keyword.EXHAUST), false)
	check("retain added", b2.has_keyword(CardData.Keyword.RETAIN), true)
	check("effects inherited when block is empty", b2.rules_text(),
		"Deal 6 damage to all enemies.")
	check("and the inherited text follows the new targeting",
		b2.rules_text().contains(TranslationServer.translate("target.all_enemies")), true)
	check("base keywords untouched", body.has_keyword(CardData.Keyword.EXHAUST), true)

	print("\n-- an upgraded card actually resolves differently --")
	var ctx := RecordingEffectContext.new(0, PackedInt32Array([1]))
	for e in plus.effects:
		e.apply(ctx)
	check("hits for the upgraded number", ctx.calls[0]["amount"], 9)

	print("\n-- lanes are tags, and may be empty or several --")
	var chrono := strike()
	check("neutral core card", chrono.in_lane(CardData.Lane.RUSH), false)
	chrono.lanes = [CardData.Lane.RUSH, CardData.Lane.CHRONOMANCY]
	check("rush", chrono.in_lane(CardData.Lane.RUSH), true)
	check("chronomancy", chrono.in_lane(CardData.Lane.CHRONOMANCY), true)
	check("not engine", chrono.in_lane(CardData.Lane.ENGINE), false)

	print("\n-- validation --")
	check("a good card is quiet", strike().validate(), PackedStringArray())

	var no_id := strike()
	no_id.id = &""
	check("missing id caught", no_id.validate().size() > 0, true)

	var pricey := strike()
	pricey.cost_hours = 4
	check("cost above 3h caught", pricey.validate()[0].contains("whole hours"), true)

	var empty := strike()
	empty.effects = []
	check("empty attack caught", empty.validate()[0].contains("no effects"), true)

	var curse := CardData.new()
	curse.id = &"delay"
	curse.name_key = &"card.delay.name"
	curse.kind = CardData.Kind.CURSE
	curse.cost_hours = 1
	curse.targeting = CardTargeting.Mode.SELF
	check("empty curse is legal", curse.validate(), PackedStringArray())

	var backwards := strike()
	backwards.targeting = CardTargeting.Mode.SELF
	check("attack on self caught", backwards.validate()[0].contains("SELF"), true)

	var pointless := strike()
	pointless.upgrade = CardUpgrade.new()
	check("empty upgrade block caught", pointless.validate()[0].contains("changes nothing"), true)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
