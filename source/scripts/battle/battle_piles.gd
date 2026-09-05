class_name BattlePiles
extends RefCounted


var draw: Array[int] = []
var hand: Array[int] = []
var discard: Array[int] = []
var exhausted: Array[int] = []

var _rng: RandomNumberGenerator


func _init(deck_size: int, rng: RandomNumberGenerator) -> void:
	_rng = rng
	for i in deck_size:
		draw.append(i)
	_shuffle(draw)


func _shuffle(pile: Array[int]) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pile[i]
		pile[i] = pile[j]
		pile[j] = tmp


func draw_cards(count: int) -> int:
	var drawn := 0
	for i in count:
		if draw.is_empty():
			if discard.is_empty():
				break
			draw.append_array(discard)
			discard.clear()
			_shuffle(draw)
		hand.append(draw.pop_back())
		drawn += 1
	return drawn


func discard_hand() -> void:
	discard.append_array(hand)
	hand.clear()


func discard_one(hand_index: int) -> void:
	discard.append(hand.pop_at(hand_index))


func exhaust_one(hand_index: int) -> void:
	exhausted.append(hand.pop_at(hand_index))


func to_dict() -> Dictionary:
	return {
		"draw": draw.duplicate(),
		"hand": hand.duplicate(),
		"discard": discard.duplicate(),
		"exhausted": exhausted.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	draw.assign(data.get("draw", []))
	hand.assign(data.get("hand", []))
	discard.assign(data.get("discard", []))
	exhausted.assign(data.get("exhausted", []))
