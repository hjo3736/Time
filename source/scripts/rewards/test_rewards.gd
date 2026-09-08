extends SceneTree


var _failures := 0
var _b: Balance
var _cards: CardDatabase


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func ids(cards: Array[CardData]) -> Array:
	return cards.map(func(c: CardData) -> String: return String(c.id))


func rich_run(restored: int) -> RunState:
	var run := RunState.new(_b, 1)
	run.clock.restore(restored)
	return run


func _init() -> void:
	TranslationServer.set_locale("en")
	_b = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()

	print("\n-- a reward offers a few cards, never the same one twice --")
	var offer := CardReward.offer(_cards, _b, rng(1))
	check("three choices", offer.size(), _b.reward_card_choices)
	check("all distinct", ids(offer).size(), Array(ids(offer)).size())
	var unique := {}
	for id in ids(offer):
		unique[id] = true
	check("really distinct", unique.size(), offer.size())

	print("\n-- starters and curses are never offered --")
	var bad := 0
	for i in 60:
		for card in CardReward.offer(_cards, _b, rng(i)):
			if not CardReward.is_offerable(card):
				bad += 1
	check("sixty offers, none illegal", bad, 0)

	print("\n-- offers are seeded and replay --")
	check("same seed", ids(CardReward.offer(_cards, _b, rng(99))), ids(CardReward.offer(_cards, _b, rng(99))))

	print("\n-- rarity weights bend the roll --")
	var tally := {}
	var r := rng(31)
	for i in 900:
		var rarity := CardReward.rarity_for(_b, r)
		tally[rarity] = int(tally.get(rarity, 0)) + 1
	check("commons dominate",
		int(tally.get(CardData.Rarity.COMMON, 0)) > int(tally.get(CardData.Rarity.UNCOMMON, 0)), true)
	check("rares are rare",
		int(tally.get(CardData.Rarity.RARE, 0)) < int(tally.get(CardData.Rarity.UNCOMMON, 0)), true)

	print("\n-- a thin pool makes offers repetitive, never short --")
	var only_rare := CardReward.offer(_cards, _b, rng(5), &"warden", [&"regather"])
	check("still returns something", only_rare.size() > 0, true)
	check("and nothing outside the pool", ids(only_rare), ["regather"])

	print("\n-- unlocks gate the pool --")
	var gated := CardReward.offer(_cards, _b, rng(8), &"warden", [&"sweep_missing", &"soften", &"scatter"])
	for id in ids(gated):
		check("offered %s is unlocked" % id, ["soften", "scatter"].has(id), true)

	print("\n-- shops price by rarity, in Restored --")
	var run := rich_run(100 * 60)
	var shop := Shop.new(_cards, _b, rng(2))
	check("stocked", shop.cards.size() > 0, true)
	for i in shop.cards.size():
		check("%s priced by rarity" % shop.cards[i].id, shop.prices[i], shop.price_of(shop.cards[i]))

	print("\n-- buying spends Restored and takes the card off the shelf --")
	var before := run.clock.restored
	var wanted := shop.cards[0]
	var price := shop.prices[0]
	var stock := shop.cards.size()
	check("bought", shop.buy_card(run, 0), true)
	check("paid", before - run.clock.restored, price)
	check("shelf shrank", shop.cards.size(), stock - 1)
	check("deck grew", run.deck.size(), 1)
	check("got what was bought", run.deck[0]["id"], wanted.id)
	check("prices stayed aligned", shop.prices.size(), shop.cards.size())

	print("\n-- shopping never touches the ending ledger --")
	check("nothing kept", run.total_kept, 0)
	check("Remaining untouched", run.clock.remaining, _b.starting_remaining)

	print("\n-- what cannot be afforded cannot be bought --")
	var broke := RunState.new(_b, 1)
	var shop2 := Shop.new(_cards, _b, rng(2))
	var stock2 := shop2.cards.size()
	check("refused", shop2.buy_card(broke, 0), false)
	check("shelf intact", shop2.cards.size(), stock2)
	check("deck intact", broke.deck.size(), 0)

	print("\n-- removal is one per shop and climbs across the run --")
	var trim := rich_run(200 * 60)
	trim.add_card(&"take")
	trim.add_card(&"brace")
	var s1 := Shop.new(_cards, _b, rng(3))
	check("first price", s1.removal_price(trim), _b.price_removal)
	check("removed", s1.buy_removal(trim, 0), true)
	check("deck shrank", trim.deck.size(), 1)
	check("no second removal here", s1.can_afford_removal(trim), false)
	check("and the offer is spent", s1.buy_removal(trim, 0), false)

	var s2 := Shop.new(_cards, _b, rng(4))
	check("next shop costs more", s2.removal_price(trim), _b.price_removal + _b.price_removal_increment)
	s2.buy_removal(trim, 0)
	var s3 := Shop.new(_cards, _b, rng(5))
	check("and more again", s3.removal_price(trim), _b.price_removal + 2 * _b.price_removal_increment)
	check("run counted them", trim.removals_purchased, 2)

	print("\n-- an empty deck has nothing to remove --")
	var bare := rich_run(200 * 60)
	var s4 := Shop.new(_cards, _b, rng(6))
	check("refused", s4.can_afford_removal(bare), false)

	print("\n-- the removal count survives a save --")
	var back := RunState.from_dict(trim.to_dict(), _b)
	check("carried", back.removals_purchased, 2)
	check("so the price does not reset", Shop.new(_cards, _b, rng(7)).removal_price(back),
		_b.price_removal + 2 * _b.price_removal_increment)

	print("\n-- a reward is taken or lost, never banked --")
	var pending := RunState.new(_b, 1)
	pending.offer_reward([&"soften", &"scatter", &"disperse"])
	check("three on the table", pending.pending_reward().size(), 3)
	check("taking one adds it", pending.take_reward(1), true)
	check("got the one chosen", pending.deck[0]["id"], &"scatter")
	check("the rest are gone", pending.has_pending_reward(), false)
	check("and cannot be taken twice", pending.take_reward(0), false)

	var skipped := RunState.new(_b, 1)
	skipped.offer_reward([&"soften", &"scatter"])
	skipped.skip_reward()
	check("skipping clears it", skipped.has_pending_reward(), false)
	check("and adds nothing", skipped.deck.size(), 0)

	print("\n-- walking away is the skip, and the cards are gone --")
	var table := EncounterTable.new()
	table.load_from()
	var walker := RunState.new(_b, 12)
	var map := MapState.new(walker, MapGenerator.generate(_b, table, rng(12)))
	var step: Vector2i = map.neighbours(Vector2i.ZERO)[0]
	walker.offer_reward([&"soften", &"scatter"])
	check("leaving is allowed", map.move_to(step), true)
	check("the offer did not follow", walker.has_pending_reward(), false)
	check("and nothing was taken", walker.deck.size(), 0)
	check("coming back does not bring it back", map.move_to(Vector2i.ZERO), true)
	check("still gone", walker.has_pending_reward(), false)

	print("\n-- a fire skipped is a fire kept --")
	var fire_run := RunState.new(_b, 21)
	var fire_map := MapState.new(fire_run, MapGenerator.generate(_b, table, rng(21)))
	var fire_coord := Vector2i.ZERO
	for coord in fire_map.rooms:
		if fire_map.rooms[coord].kind == Room.Kind.FIRE:
			fire_coord = coord
			break
	fire_map.current = fire_coord
	check("a fire is waiting", fire_map.current_is_spent(), false)
	var away: Vector2i = fire_map.neighbours(fire_coord)[0]
	fire_map.move_to(away)
	fire_map.move_to(fire_coord)
	check("still waiting on the way back", fire_map.current_is_spent(), false)
	fire_map.clear_current()
	check("only using it spends it", fire_map.current_is_spent(), true)

	print("\n-- a pending reward survives a save --")
	var mid := RunState.new(_b, 1)
	mid.offer_reward([&"soften", &"scatter", &"disperse"])
	var resumed := RunState.from_dict(mid.to_dict(), _b)
	check("the same three cards come back", Array(resumed.pending_reward()),
		[&"soften", &"scatter", &"disperse"])

	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)
