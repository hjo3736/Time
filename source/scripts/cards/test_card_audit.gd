extends SceneTree

var _failures := 0
var _db: CardDatabase


func fail(card: CardData, what: String) -> void:
	_failures += 1
	print("  FAIL  %-16s %-14s  %s" % [card.id, _mode(card.targeting), what])


func _mode(mode: int) -> String:
	match mode:
		CardTargeting.Mode.SINGLE_ENEMY: return "SINGLE"
		CardTargeting.Mode.ALL_ENEMIES: return "ALL"
		CardTargeting.Mode.SELF: return "SELF"
		CardTargeting.Mode.RANDOM_ENEMY: return "RANDOM"
	return "?"


func _hits_enemies(card: CardData) -> bool:
	for e in card.effects:
		if e is EffectDamage or e is EffectVariableDamage or e is EffectScalingDamage:
			return true
		if e is EffectApplyStatus and not (e as EffectApplyStatus).on_self:
			return true
	return false


func _init() -> void:
	TranslationServer.set_locale("ko")
	_db = CardDatabase.new()
	_db.load_from()

	var single := TranslationServer.translate("target.enemy")
	var many := TranslationServer.translate("target.enemies")

	print("\n-- what a card says is what a card does --")
	for card in _db.all():
		var text := card.rules_text()

		if card.targeting == CardTargeting.Mode.SELF and _hits_enemies(card):
			fail(card, "targets itself but its effects act on enemies")

		if card.targeting != CardTargeting.Mode.SELF and not _hits_enemies(card):
			fail(card, "asks for a target it never uses")

		if card.targeting == CardTargeting.Mode.ALL_ENEMIES \
				and single != many and text.contains(single) and not text.contains(many):
			fail(card, "hits every enemy but reads as one: %s" % text)

		if card.targeting == CardTargeting.Mode.SINGLE_ENEMY and text.contains(many):
			fail(card, "hits one enemy but reads as all: %s" % text)

		if not _names_once(text, many):
			fail(card, "says who it hits more than once: %s" % text)
		if not _names_once(text, TranslationServer.translate("target.random_enemy")):
			fail(card, "says who it hits more than once: %s" % text)

		if card.targeting == CardTargeting.Mode.SINGLE_ENEMY and text.contains(single):
			fail(card, "names a target it did not have to: %s" % text)

	print("\n-- and the upgrade says the same kind of thing --")
	for card in _db.all():
		if not card.can_upgrade():
			continue
		var up := card.upgraded()
		if up.targeting != card.targeting:
			fail(card, "changes targeting when sharpened: %s -> %s" % [
				_mode(card.targeting), _mode(up.targeting)])
		if _hits_enemies(up) != _hits_enemies(card):
			fail(card, "changes who it touches when sharpened")

	print("\n-- every card is printable in both languages --")
	for lang in ["ko", "en"]:
		TranslationServer.set_locale(lang)
		for card in _db.all():
			if card.rules_text().strip_edges().is_empty() \
					and not card.has_keyword(CardData.Keyword.UNPLAYABLE):
				fail(card, "has no rules text in %s" % lang)
			if card.display_name().begins_with("card."):
				fail(card, "has no name in %s" % lang)
	TranslationServer.set_locale("ko")

	print("\n-- the whole set, for reading --")
	for card in _db.all():
		print("  %-16s %-7s %-6s %s" % [
			card.id, _mode(card.targeting), card.cost_text(), card.rules_text()])

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _names_once(text: String, who: String) -> bool:
	return who == "" or text.count(who) <= 1
