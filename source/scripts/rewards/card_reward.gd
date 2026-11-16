class_name CardReward
extends RefCounted


static func rarity_for(balance: Balance, rng: RandomNumberGenerator) -> CardData.Rarity:
	var total := balance.reward_weight_common + balance.reward_weight_uncommon + balance.reward_weight_rare
	var roll := rng.randi_range(1, maxi(1, total))
	if roll <= balance.reward_weight_common:
		return CardData.Rarity.COMMON
	if roll <= balance.reward_weight_common + balance.reward_weight_uncommon:
		return CardData.Rarity.UNCOMMON
	return CardData.Rarity.RARE


static func offer(
	cards: CardDatabase,
	balance: Balance,
	rng: RandomNumberGenerator,
	class_id: StringName = &"warden",
	unlocked: Array = [],
) -> Array[CardData]:
	var out: Array[CardData] = []
	var taken: Array = []

	for slot in balance.reward_card_choices:
		var picked := _draw(cards, balance, rng, class_id, unlocked, taken, rarity_for(balance, rng))
		if picked == null:
			break
		out.append(picked)
		taken.append(picked.id)

	return out


static func _draw(
	cards: CardDatabase,
	_balance: Balance,
	rng: RandomNumberGenerator,
	class_id: StringName,
	unlocked: Array,
	exclude: Array,
	rarity: CardData.Rarity,
) -> CardData:
	for candidate in [rarity, CardData.Rarity.COMMON, CardData.Rarity.UNCOMMON, CardData.Rarity.RARE]:
		var query := {"class_id": class_id, "rarity": candidate, "exclude": exclude}
		if not unlocked.is_empty():
			query["unlocked"] = unlocked
		var pool := cards.pick(rng, 1, query)
		if not pool.is_empty():
			return pool[0]
	return null


static func is_offerable(card: CardData) -> bool:
	return card.rarity != CardData.Rarity.STARTER and card.rarity != CardData.Rarity.SPECIAL
