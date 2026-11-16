class_name RunController
extends RefCounted

signal phase_changed(phase: Phase)
signal act_started(act: int)
signal battle_started
signal battle_finished(victory: bool)
signal reward_offered(card_ids: Array)
signal run_ended(outcome: Outcome)

enum Phase { EXPLORING, BATTLE, REWARD, FIRE, SHOP, EVENT, ACT_CLEARED, ENDED }

enum Outcome { NONE, FELL, RAN_OUT, FINISHED }

var phase := Phase.EXPLORING:
	set(value):
		if phase != value:
			phase = value
			phase_changed.emit(value)

var outcome := Outcome.NONE
var run: RunState
var map: MapState
var battle: BattleState
var shop: Shop
var event: EventData

var _balance: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase
var _events: EventTable
var _rng: RandomNumberGenerator
var _opened_with_teaching_fight := false

var fight_snapshot := {}

## What the room just resolved handed over, so the screen can name it. Transient:
## it describes the last room, not the run, and is not saved.
var last_relic := StringName()

func _init(
	balance: Balance,
	cards: CardDatabase,
	enemies: EnemyDatabase,
	encounters: EncounterTable,
	relics: RelicDatabase,
	seed_value: int = 0,
	events: EventTable = null,
	player: PlayerStats = null
) -> void:
	_balance = balance
	_cards = cards
	_enemies = enemies
	_encounters = encounters
	_relics = relics
	_events = events if events != null else EventTable.new()
	
	if events == null:
		_events.load_from()

	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

	run = RunState.new(balance, seed_value, player)
	
	for card in run.player.starting_deck:
		run.add_card(card.id)

	_begin_act(1)

func _floor_rng(act: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([run.seed, act])
	return r

func _begin_act(act: int) -> void:
	run.act = act
	map = MapState.new(run, MapGenerator.generate(_balance, _encounters, _floor_rng(act), act))
	phase = Phase.EXPLORING
	act_started.emit(act)

func current_room() -> Room:
	return map.at(map.current)

func reachable() -> Array:
	return map.reachable()

func status() -> Dictionary:
	return {
		"act": run.act,
		"phase": phase,
		"remaining": run.clock.remaining,
		"elapsed": run.clock.elapsed,
		"restored": run.clock.restored,
		"threat": run.clock.threat_level(),
		"hp": run.hp,
		"max_hp": run.max_hp,
		"deck": run.deck.size(),
		"relics": run.relics.size(),
		"at": map.current,
		"room": current_room().kind if current_room() != null else -1,
	}

func move_to(coord: Vector2i) -> bool:
	if phase != Phase.EXPLORING:
		return false
	if not map.move_to(coord):
		return false
	if _check_clock():
		return true
	_resolve_room()
	return true

func _resolve_room() -> void:
	var room := current_room()
	if room == null or room.is_spent():
		phase = Phase.EXPLORING
		return

	match room.kind:
		Room.Kind.COMBAT, Room.Kind.ELITE, Room.Kind.BOSS:
			_start_battle(room)
		Room.Kind.FIRE:
			phase = Phase.FIRE
		Room.Kind.EVENT:
			_start_event()
		Room.Kind.SHOP:
			shop = Shop.new(_cards, _balance, _rng, run.player.class_id, [], false, _relics, run.relics)
			run.clock.advance(_balance.shop_cost, RunClock.Source.SHOP)
			if _check_clock():
				return
			phase = Phase.SHOP
		_:
			phase = Phase.EXPLORING

func _start_battle(room: Room) -> void:
	var data: EncounterData = null
	if not _opened_with_teaching_fight:
		data = _encounters.pick(_rng, run.act, EnemyStats.Tier.NORMAL, true)
		_opened_with_teaching_fight = true
	if data == null:
		data = _encounters.mixed(
			_encounters.get_encounter(room.encounter_for(run.clock.daytime())),
			room.companions, _balance.mixed_fight_size, _balance.mixed_fight_hp_scale)
	if data == null:
		map.clear_current()
		_room_resolved(room)
		return

	var group := _encounters.spawn(data, _enemies, _balance, _rng, run.clock.threat_level())
	battle = BattleState.new(run, _cards, group, _rng)
	battle.battle_ended.connect(_on_battle_ended, CONNECT_ONE_SHOT)
	phase = Phase.BATTLE
	_snapshot_fight()
	battle_started.emit()

func _snapshot_fight() -> void:
	if battle == null:
		return
	fight_snapshot = to_dict()

func play_card(hand_index: int, target: int = -1) -> bool:
	if phase != Phase.BATTLE or battle == null:
		return false
	return battle.play_card(hand_index, target)

func end_turn() -> bool:
	if phase != Phase.BATTLE or battle == null:
		return false
	battle.end_turn()
	return true

func _on_battle_ended(victory: bool) -> void:
	battle_finished.emit(victory)
	battle = null

	if not victory:
		_finish(Outcome.RAN_OUT if run.clock.is_expired() else Outcome.FELL)
		return

	map.clear_current()
	_room_resolved(current_room())

func _room_resolved(room: Room) -> void:
	last_relic = StringName()

	# An elite is worth a relic on top of its card, and an act boss is the only
	# thing that hands out a boss relic. Nothing else grants one.
	if room != null and room.kind == Room.Kind.ELITE:
		_grant_relic(_relics.roll(_rng, _balance, run.relics))
	if room != null and room.kind == Room.Kind.BOSS:
		_grant_relic(_relics.roll_boss(_rng, run.relics))
		run.heal(maxi(1, roundi(run.max_hp * _balance.act_clear_heal_fraction)))
		phase = Phase.ACT_CLEARED
		return

	var offer := CardReward.offer(_cards, _balance, _rng, run.player.class_id)
	if offer.is_empty():
		phase = Phase.EXPLORING
		return
	run.offer_reward(offer.map(func(c: CardData) -> StringName: return c.id))
	reward_offered.emit(Array(run.pending_reward()))
	phase = Phase.REWARD

func _grant_relic(relic: Relic) -> void:
	if relic == null:
		return
	run.add_relic(relic.id, _relics)
	last_relic = relic.id

func take_reward(index: int) -> bool:
	if phase != Phase.REWARD:
		return false
	if not run.take_reward(index):
		return false
	phase = Phase.EXPLORING
	return true

func skip_reward() -> void:
	if phase != Phase.REWARD:
		return
	run.skip_reward()
	phase = Phase.EXPLORING

## Rest, sharpen and keep can all be taken at one fire, each once. The Warden
## stays at the fire until it leaves; leaving having taken anything puts the
## fire out, leaving having taken nothing keeps it lit for later.
func use_fire(action: RunState.FireAction, argument: int = 0) -> bool:
	if phase != Phase.FIRE or fire_action_used(action):
		return false
	if not run.use_fire(action, argument):
		return false
	current_room().fire_used.append(action)
	_check_clock()
	return true

func fire_action_used(action: RunState.FireAction) -> bool:
	var room := current_room()
	return room != null and room.fire_used.has(action)

func leave_fire() -> void:
	if phase != Phase.FIRE:
		return
	var room := current_room()
	if room != null and not room.fire_used.is_empty():
		map.clear_current()
	phase = Phase.EXPLORING

func buy_card(index: int) -> bool:
	return phase == Phase.SHOP and shop != null and shop.buy_card(run, index)

func buy_removal(deck_index: int) -> bool:
	return phase == Phase.SHOP and shop != null and shop.buy_removal(run, deck_index)

func buy_relic() -> bool:
	return phase == Phase.SHOP and shop != null and shop.buy_relic(run, _relics)

func leave_shop() -> void:
	if phase != Phase.SHOP:
		return
	map.clear_current()
	shop = null
	phase = Phase.EXPLORING

func advance_act() -> bool:
	if phase != Phase.ACT_CLEARED:
		return false
	if run.act >= _balance.acts_per_run:
		_finish(Outcome.FINISHED)
		return true
	_begin_act(run.act + 1)
	return true

func is_over() -> bool:
	return phase == Phase.ENDED

func _check_clock() -> bool:
	if run.clock.is_expired():
		_finish(Outcome.RAN_OUT)
		return true
	if run.is_defeated():
		_finish(Outcome.FELL)
		return true
	return false

func _finish(result: Outcome) -> void:
	outcome = result
	phase = Phase.ENDED
	run_ended.emit(result)

func ending() -> Dictionary:
	return {
		"outcome": outcome,
		"delivered": run.delivered(),
		"kept": run.total_kept,
		"memories": run.memories.size(),
		"elapsed": run.clock.elapsed,
		"act": run.act,
	}

func to_dict() -> Dictionary:
	var written := {
		"version": SAVE_VERSION,
		"phase": phase,
		"outcome": outcome,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"opened_with_teaching_fight": _opened_with_teaching_fight,
		"run": run.to_dict(),
		"map": map.to_dict() if map != null else {},
	}
	if battle != null:
		written["battle"] = battle.to_dict()
	if shop != null:
		written["shop"] = shop.to_dict()
	if event != null:
		written["event"] = String(event.id)
	return written

const SAVE_VERSION := 3

static func from_dict(
	data: Dictionary,
	balance: Balance,
	cards: CardDatabase,
	enemies: EnemyDatabase,
	encounters: EncounterTable,
	relics: RelicDatabase,
) -> RunController:
	var saved_run := RunState.from_dict(data.get("run", {}), balance)
	# The save carries relic ids, not definitions. Without this a resumed run
	# keeps the list and loses every effect on it, silently.
	saved_run.attach_relics(relics)
	var out := RunController.new(balance, cards, enemies, encounters, relics, saved_run.seed, null, saved_run.player)
	out.run = saved_run
	out._rng.seed = int(data.get("rng_seed", saved_run.seed))
	out._rng.state = int(data.get("rng_state", 0))
	out._opened_with_teaching_fight = bool(data.get("opened_with_teaching_fight", false))
	out.outcome = int(data.get("outcome", Outcome.NONE)) as Outcome

	out.map = MapState.from_dict(data.get("map", {}), saved_run)
	out.battle = BattleState.from_dict(data["battle"], saved_run, cards) if data.has("battle") else null
	if out.battle != null:
		out.battle.battle_ended.connect(out._on_battle_ended, CONNECT_ONE_SHOT)
	out.shop = Shop.from_dict(data["shop"], cards, balance, relics) if data.has("shop") else null
	if data.has("event"):
		out.event = out._events.get_event(StringName(data["event"]))
	out.phase = int(data.get("phase", Phase.EXPLORING)) as Phase
	out._snapshot_fight()
	return out

func save_state() -> Dictionary:
	if phase == Phase.BATTLE and not fight_snapshot.is_empty():
		return fight_snapshot
	return to_dict()

func _start_event() -> void:
	event = _events.pick(_rng, run.act, run.seen_events())
	if event == null:
		map.clear_current()
		phase = Phase.EXPLORING
		return
	phase = Phase.EVENT

func choose_event(index: int) -> bool:
	if phase != Phase.EVENT or event == null:
		return false
	if index < 0 or index >= event.choices.size():
		return false
	var choice := event.choices[index]
	if not choice.available(run):
		return false

	run.note_event_seen(event.id)
	choice.take(run)
	event = null
	map.clear_current()
	if _check_clock():
		return true
	phase = Phase.EXPLORING
	return true
