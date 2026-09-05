class_name Shop
extends RefCounted


signal card_bought(card: CardData)
signal removal_bought(deck_index: int)

var cards: Array[CardData] = []
var prices: PackedInt32Array = PackedInt32Array()

var removal_available := true

var _balance: Balance


func _init(
	db: CardDatabase,
	balance: Balance,
	rng: RandomNumberGenerator,
	class_id: StringName = &"warden",
	unlocked: Array = [],
	restoring := false,
) -> void:
	_balance = balance
	if restoring:
		return

	var taken: Array = []
	for slot in balance.shop_card_count:
		var rarity := CardReward.rarity_for(balance, rng)
		var query := {"class_id": class_id, "rarity": rarity, "exclude": taken}
		if not unlocked.is_empty():
			query["unlocked"] = unlocked
		var drawn := db.pick(rng, 1, query)
		if drawn.is_empty():
			continue
		var card: CardData = drawn[0]
		if not CardReward.is_offerable(card):
			continue
		cards.append(card)
		prices.append(price_of(card))
		taken.append(card.id)


func price_of(card: CardData) -> int:
	match card.rarity:
		CardData.Rarity.RARE:
			return _balance.price_rare
		CardData.Rarity.UNCOMMON:
			return _balance.price_uncommon
		_:
			return _balance.price_common


func removal_price(run: RunState) -> int:
	return _balance.price_removal + run.removals_purchased * _balance.price_removal_increment


func can_afford_card(run: RunState, index: int) -> bool:
	if index < 0 or index >= cards.size():
		return false
	return run.clock.restored >= prices[index]


func buy_card(run: RunState, index: int) -> bool:
	if not can_afford_card(run, index):
		return false
	var card := cards[index]
	if not run.clock.spend_restored(prices[index]):
		return false

	cards.remove_at(index)
	var kept := PackedInt32Array()
	for i in prices.size():
		if i != index:
			kept.append(prices[i])
	prices = kept

	run.add_card(card.id)
	card_bought.emit(card)
	return true


func can_afford_removal(run: RunState) -> bool:
	return removal_available and not run.deck.is_empty() and run.clock.restored >= removal_price(run)


func buy_removal(run: RunState, deck_index: int) -> bool:
	if not can_afford_removal(run):
		return false
	if deck_index < 0 or deck_index >= run.deck.size():
		return false
	if not run.clock.spend_restored(removal_price(run)):
		return false

	run.remove_card(deck_index)
	run.note_removal_purchased()
	removal_available = false
	removal_bought.emit(deck_index)
	return true


func is_empty() -> bool:
	return cards.is_empty() and not removal_available


func to_dict() -> Dictionary:
	return {
		"cards": cards.map(func(c: CardData) -> String: return String(c.id)),
		"prices": prices.duplicate(),
		"removal_available": removal_available,
	}


static func from_dict(data: Dictionary, db: CardDatabase, balance: Balance) -> Shop:
	var rng := RandomNumberGenerator.new()
	var out := Shop.new(db, balance, rng, &"warden", [], true)
	for id in data.get("cards", []):
		var card := db.get_card(StringName(id))
		if card != null:
			out.cards.append(card)
	out.prices = PackedInt32Array(data.get("prices", []))
	out.removal_available = bool(data.get("removal_available", true))
	return out
