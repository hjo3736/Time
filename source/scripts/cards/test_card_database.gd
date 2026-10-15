extends SceneTree


var _failures := 0


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func ids(cards: Array[CardData]) -> Array:
	return cards.map(func(c: CardData) -> String: return String(c.id))


func _init() -> void:
	TranslationServer.set_locale("en")

	var db := CardDatabase.new()
	db.load_from()

	print("\n-- the shipped content loads and passes its own linter --")
	check("problems", db.validate(), PackedStringArray())

	print("\n-- what the pool holds while it is being rebuilt --")
	# The pool was emptied on purpose, the way the bestiary was. This is what it
	# holds today, not what the finished game wants: adding a card turns this red
	# so that the list here is edited deliberately. The target for the one class
	# is ~75-100 cards across three lanes.
	check("everything but the curses is back, and chronomancy is being written again",
		ids(db.all()), ["all_at_once", "blunt", "brace", "catch_breath", "disperse", "double_cut",
			"flurry",
			"gather", "harden", "leave_nothing", "long_hour", "long_kept", "momentum", "quick_cut",
			"regather",
			"scatter", "sever", "soften", "spend_it", "steady", "stillness", "take", "unmake",
			"unspool", "wear_down"])
	check("and the shelf is not part of it",
		DirAccess.dir_exists_absolute(CardDatabase.SHELF_ROOT) and not db.has(&"delay"), true)

	# Everything below checks how the database answers, not what is in it, and
	# needs more than four cards to ask anything of. It reads the shelf as well.
	CardDatabase.fixture_roots = PackedStringArray(CardDatabase.TEST_ROOTS)
	db = CardDatabase.new()
	db.load_from()
	check("with the shelf and the fixtures read in, there is more to query",
		db.size() > 23 and db.has(&"fixture_refund") and db.has(&"delay"), true)
	check("which also passes the linter", db.validate(), PackedStringArray())

	print("\n-- order is sorted by id, not by whatever the filesystem said --")
	var sorted := ids(db.all())
	var expected_order := sorted.duplicate()
	expected_order.sort()
	check("sorted by id", sorted, expected_order)

	print("\n-- lookup --")
	check("has", db.has(&"take"), true)
	check("missing", db.has(&"nonesuch"), false)
	check("missing returns null", db.get_card(&"nonesuch"), null)
	check("base card", db.get_card(&"take").rules_text(), tr("effect.take").format({"amount": 6}))

	print("\n-- upgraded variants are built once and reused --")
	var up := db.get_card(&"take", 1)
	check("upgraded text", up.rules_text(), tr("effect.take").format({"amount": 9}))
	check("upgraded name", up.display_name(), "Take+")
	check("cached, not rebuilt", db.get_card(&"take", 1), up)
	check("base still base", db.get_card(&"take").rules_text(), tr("effect.take").format({"amount": 6}))

	print("\n-- filters --")
	check("by rarity", ids(db.filter({"rarity": CardData.Rarity.STARTER})), ["brace", "take"])
	var skills := db.filter({"kind": CardData.Kind.SKILL})
	check("kind filter returns only that kind",
		skills.all(func(c: CardData) -> bool: return c.kind == CardData.Kind.SKILL), true)
	check("and not everything", skills.size() < db.size(), true)
	var rush := db.filter({"lane": CardData.Lane.RUSH})
	check("lane filter returns only that lane",
		rush.all(func(c: CardData) -> bool: return c.in_lane(CardData.Lane.RUSH)), true)
	var engine := db.filter({"lane": CardData.Lane.ENGINE})
	check("every lane is stocked", engine.size() > 0 and rush.size() > 0
		and db.filter({"lane": CardData.Lane.CHRONOMANCY}).size() > 0, true)
	var neutral := db.all().filter(func(c: CardData) -> bool: return c.lanes.is_empty())
	check("and the neutral core outnumbers any one lane",
		neutral.size() > maxi(engine.size(), rush.size()), true)
	check("by class", db.filter({"class_id": &"warden"}).size(), db.size())
	check("wrong class", ids(db.filter({"class_id": &"nobody"})), [])
	var common_attacks := db.filter({"kind": CardData.Kind.ATTACK, "rarity": CardData.Rarity.COMMON})
	check("combined filters both apply", common_attacks.all(func(c: CardData) -> bool:
		return c.kind == CardData.Kind.ATTACK and c.rarity == CardData.Rarity.COMMON), true)

	print("\n-- filters carry the meta-progression pool --")
	check("unlocked subset", ids(db.filter({"unlocked": [&"take", &"disperse"]})), ["disperse", "take"])
	check("exclude what was already offered", ids(db.filter({"exclude": [&"take"]})).has("take"), false)

	print("\n-- filters keep the sorted order --")
	check("still sorted", ids(db.filter({"class_id": &"warden"})), ids(db.all()))

	print("\n-- picking is seeded and replayable --")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 777
	b.seed = 777
	var rolls_a := []
	var rolls_b := []
	for i in 6:
		rolls_a.append(ids(db.pick(a, 2)))
		rolls_b.append(ids(db.pick(b, 2)))
	check("same seed, same offers", rolls_a, rolls_b)

	print("\n-- picking does not repeat a card within one offer --")
	var c := RandomNumberGenerator.new()
	c.seed = 3
	for i in 20:
		var offer := ids(db.pick(c, 3))
		if offer.size() != 3 or offer[0] == offer[1] or offer[1] == offer[2] or offer[0] == offer[2]:
			_failures += 1
			print("  FAIL  duplicate in offer: %s" % [offer])
			break
	check("twenty offers, no repeats", true, true)

	print("\n-- asking for more than exists returns what exists --")
	check("clamped", db.pick(c, 99).size(), db.size())
	check("empty pool", db.pick(c, 2, {"kind": CardData.Kind.POWER}), [])

	print("\n-- a missing directory is reported, not silently empty --")
	var missing := CardDatabase.new()
	missing.load_from("res://source/data/does_not_exist")
	check("no cards", missing.size(), 0)
	check("says why", missing.validate()[0].contains("directory not found"), true)

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
