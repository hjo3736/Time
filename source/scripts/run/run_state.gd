class_name RunState
extends RefCounted


signal hp_changed(current: int, maximum: int)
signal defeated
signal memory_recovered(memory_id: StringName)
signal fire_used(action: FireAction)

enum FireAction { REST, UPGRADE, CONVERT }

var clock: RunClock:
	get:
		return _clock

var hp: int:
	get:
		return _hp

var max_hp: int:
	get:
		return _max_hp

var deck: Array[Dictionary]:
	get:
		return _deck

var relics: Array[StringName]:
	get:
		return _relics

var memories: Array[StringName]:
	get:
		return _memories

var total_kept: int:
	get:
		return _total_kept

var removals_purchased: int:
	get:
		return _removals_purchased

var act := 1
var room_id := StringName()
var seed := 0

var _balance: Balance
var _clock: RunClock
var _hp: int
var _max_hp: int
var _deck: Array[Dictionary] = []
var _relics: Array[StringName] = []
var _memories: Array[StringName] = []
var _total_kept := 0
var _removals_purchased := 0
var _seen_events: Array[StringName] = []
var _pending_reward: Array[StringName] = []
var _relic_defs: Array[Relic] = []


func _init(p_balance: Balance = null, p_seed: int = 0) -> void:
	_balance = p_balance if p_balance != null else Balance.default()
	_clock = RunClock.new(_balance)
	_max_hp = _balance.starting_max_hp
	_hp = _max_hp
	seed = p_seed


func damage(amount: int) -> bool:
	if amount <= 0:
		return false
	_hp = maxi(0, _hp - amount)
	hp_changed.emit(_hp, _max_hp)
	if _hp == 0:
		defeated.emit()
		return true
	return false


func set_hp(value: int) -> void:
	var clamped := clampi(value, 0, _max_hp)
	if clamped == _hp:
		return
	_hp = clamped
	hp_changed.emit(_hp, _max_hp)
	if _hp == 0:
		defeated.emit()


func is_defeated() -> bool:
	return _hp == 0


func fire_heal_amount() -> int:
	return maxi(1, roundi(_max_hp * _balance.fire_heal_fraction))


func fire_cost_of(action: FireAction) -> int:
	match action:
		FireAction.REST:
			return _balance.fire_rest_cost
		FireAction.UPGRADE:
			return _balance.fire_upgrade_cost
	return 0


func can_use_fire(action: FireAction = FireAction.REST) -> bool:
	return _clock.can_afford(fire_cost_of(action))


func use_fire(action: FireAction, argument: int = 0) -> bool:
	if not can_use_fire(action):
		return false

	match action:
		FireAction.REST:
			if _hp >= _max_hp:
				return false
		FireAction.UPGRADE:
			if argument < 0 or argument >= _deck.size():
				return false
		FireAction.CONVERT:
			if _clock.convertible_restored() <= 0:
				return false

	_clock.advance(fire_cost_of(action), RunClock.Source.FIRE)

	match action:
		FireAction.REST:
			_hp = mini(_max_hp, _hp + fire_heal_amount())
			hp_changed.emit(_hp, _max_hp)
		FireAction.UPGRADE:
			var card := _deck[argument]
			card["upgrades"] = int(card.get("upgrades", 0)) + 1
		FireAction.CONVERT:
			var requested := argument if argument > 0 else _clock.convertible_restored()
			_total_kept += _clock.convert(requested) * _balance.conversion_rate

	fire_used.emit(action)
	return true


func defeat_askew(restored_minutes: int, memory_id: StringName = StringName()) -> void:
	_clock.restore(restored_minutes)
	recover_memory(memory_id)


func recover_memory(memory_id: StringName) -> void:
	if memory_id == StringName() or _memories.has(memory_id):
		return
	_memories.append(memory_id)
	memory_recovered.emit(memory_id)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	_hp = mini(_max_hp, _hp + amount)
	hp_changed.emit(_hp, _max_hp)


func enter_room(next_room_id: StringName, minutes: int = -1) -> void:
	room_id = next_room_id
	var base := minutes if minutes > 0 else _balance.room_transition_cost
	_clock.advance(relic_room_cost(base), RunClock.Source.TRAVEL)


func offer_reward(card_ids: Array) -> void:
	_pending_reward.assign(card_ids)


func pending_reward() -> Array[StringName]:
	return _pending_reward


func has_pending_reward() -> bool:
	return not _pending_reward.is_empty()


func take_reward(index: int) -> bool:
	if index < 0 or index >= _pending_reward.size():
		return false
	add_card(_pending_reward[index])
	_pending_reward.clear()
	return true


func skip_reward() -> void:
	_pending_reward.clear()


func add_card(card_id: StringName, upgrades: int = 0) -> void:
	_deck.append({"id": card_id, "upgrades": upgrades})


func remove_card(index: int) -> bool:
	if index < 0 or index >= _deck.size():
		return false
	_deck.remove_at(index)
	return true


func note_removal_purchased() -> void:
	_removals_purchased += 1


func attach_relics(db: RelicDatabase) -> void:
	_relic_defs.clear()
	for id in _relics:
		var def := db.get_relic(id)
		if def != null:
			_relic_defs.append(def)


func relic_defs() -> Array[Relic]:
	return _relic_defs


func add_relic(relic_id: StringName, db: RelicDatabase = null) -> void:
	if _relics.has(relic_id):
		return
	_relics.append(relic_id)
	if db != null:
		var def := db.get_relic(relic_id)
		if def != null:
			_relic_defs.append(def)


func relic_room_cost(base: int) -> int:
	var out := base
	for r in _relic_defs:
		out = r.modify_room_cost(self, out)
	return out


func relic_restored(base: int) -> int:
	var out := base
	for r in _relic_defs:
		out = r.modify_restored(self, out)
	return out


func relic_turn_budget(base: int) -> int:
	var out := base
	for r in _relic_defs:
		out = r.modify_turn_budget(self, out)
	return out


func delivered() -> int:
	return _clock.restored


func to_dict() -> Dictionary:
	return {
		"clock": _clock.to_dict(),
		"hp": _hp,
		"max_hp": _max_hp,
		"deck": _deck.duplicate(true),
		"relics": _relics.duplicate(),
		"memories": _memories.duplicate(),
		"total_kept": _total_kept,
		"removals_purchased": _removals_purchased,
		"seen_events": _seen_events.duplicate(),
		"pending_reward": _pending_reward.duplicate(),
		"act": act,
		"room_id": String(room_id),
		"seed": seed,
	}


static func from_dict(data: Dictionary, p_balance: Balance = null) -> RunState:
	var state := RunState.new(p_balance, int(data.get("seed", 0)))
	state._clock = RunClock.from_dict(data.get("clock", {}), state._balance)
	state._max_hp = int(data.get("max_hp", state._balance.starting_max_hp))
	state._hp = int(data.get("hp", state._max_hp))
	state._total_kept = int(data.get("total_kept", 0))
	state._removals_purchased = int(data.get("removals_purchased", 0))
	for id in data.get("pending_reward", []):
		state._pending_reward.append(StringName(id))
	state.act = int(data.get("act", 1))
	state.room_id = StringName(data.get("room_id", ""))

	for entry in data.get("deck", []):
		state._deck.append({
			"id": StringName(entry.get("id", "")),
			"upgrades": int(entry.get("upgrades", 0)),
		})
	for relic in data.get("relics", []):
		state._relics.append(StringName(relic))
	for memory in data.get("memories", []):
		state._memories.append(StringName(memory))
	for seen in data.get("seen_events", []):
		state._seen_events.append(StringName(seen))

	return state


func seen_events() -> Array[StringName]:
	return _seen_events


func note_event_seen(event_id: StringName) -> void:
	if event_id != StringName() and not _seen_events.has(event_id):
		_seen_events.append(event_id)
