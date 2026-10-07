class_name BattleState
extends RefCounted


signal phase_changed(phase: Phase)
signal turn_started(turn: int)
signal card_played(deck_index: int)
signal combatant_damaged(handle: int, amount: int)
signal combatant_blocked(handle: int, absorbed: int)
signal battle_ended(victory: bool)

enum Phase { PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT }

const WARDEN := 0

var phase := Phase.PLAYER_TURN:
	set(value):
		if phase != value:
			phase = value
			phase_changed.emit(value)

var turn := 0
var combatants: Array[Combatant] = []

var turn_budget := 0

var turn_budget_max := 0

var cards_played_this_turn := 0

var _run: RunState
var _balance: Balance
var _cards: CardDatabase
var _rng: RandomNumberGenerator
var _piles: BattlePiles
var _hand_size := 5


func _init(run: RunState, cards: CardDatabase, enemies: Array[Combatant],
		rng: RandomNumberGenerator, restoring := false) -> void:
	_run = run
	_balance = run.clock.balance
	_cards = cards
	_rng = rng

	if restoring:
		_piles = BattlePiles.new(run.deck.size(), rng)
		return

	var warden := Combatant.new()
	warden.name_key = &"warden.name"
	warden.max_hp = run.max_hp
	warden.hp = run.hp
	combatants.append(warden)
	combatants.append_array(enemies)

	_piles = BattlePiles.new(run.deck.size(), rng)

	follow_the_sky()
	for relic in run.relic_defs():
		relic.on_battle_start(run, self)

	begin_turn()


func follow_the_sky() -> void:
	var now := _run.clock.daytime()
	for c in combatants:
		c.sky = now


func piles() -> BattlePiles:
	return _piles


## For behaviours that reach past the fight into the run — 가속 and 흘림.
func run() -> RunState:
	return _run


func warden() -> Combatant:
	return combatants[WARDEN]


func enemy_handles() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(1, combatants.size()):
		if combatants[i].is_alive():
			out.append(i)
	return out


func card_at(hand_index: int) -> CardData:
	if hand_index < 0 or hand_index >= _piles.hand.size():
		return null
	var entry: Dictionary = _run.deck[_piles.hand[hand_index]]
	return _cards.get_card(entry["id"], int(entry.get("upgrades", 0)))


func rng() -> RandomNumberGenerator:
	return _rng


func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT


## Asked of the living only, and asked at the moment the turn is billed — so
## killing the thing that was dragging the clock stops the bleeding that same turn.
func turn_cost_now() -> int:
	var out := _balance.turn_cost
	for handle in enemy_handles():
		var who: Combatant = combatants[handle]
		if who.behavior != null:
			out = who.behavior.modify_turn_cost(self, handle, out)
	return maxi(0, out)


func begin_turn() -> void:
	if is_over():
		return
	turn += 1
	follow_the_sky()
	phase = Phase.PLAYER_TURN
	turn_budget = _run.relic_turn_budget(_balance.turn_cost)
	turn_budget_max = turn_budget
	cards_played_this_turn = 0
	warden().block = 0
	_piles.draw_cards(_hand_size)
	for relic in _run.relic_defs():
		relic.on_turn_start(_run, self)
	turn_started.emit(turn)


func play_card(hand_index: int, chosen_target: int = -1) -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	var card := card_at(hand_index)
	if card == null:
		return false
	if card.has_keyword(CardData.Keyword.UNPLAYABLE):
		return false

	var cost := card.cost_minutes()
	if card.is_variable_cost():
		cost = turn_budget
	for relic in _run.relic_defs():
		cost = relic.modify_card_cost(_run, self, card, cost)
	cost = maxi(0, cost)
	if cost > turn_budget:
		return false

	var targets := CardTargeting.resolve(card.targeting, WARDEN, enemy_handles(), _rng, chosen_target)
	if targets.is_empty() and CardTargeting.requires_player_choice(card.targeting):
		return false

	turn_budget -= cost
	cards_played_this_turn += 1

	var deck_index := _piles.hand[hand_index]
	if card.has_keyword(CardData.Keyword.EXHAUST):
		_piles.exhaust_one(hand_index)
	else:
		_piles.discard_one(hand_index)

	var ctx := BattleEffectContext.new(self)
	ctx.source = WARDEN
	ctx.targets = targets
	if card.is_variable_cost():
		ctx.variable_amount = cost / Balance.MINUTES_PER_HOUR
	for effect in card.effects:
		effect.apply(ctx)

	card_played.emit(deck_index)
	_check_end()
	return true


func end_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	_piles.discard_hand()
	_run.clock.advance(turn_cost_now(), RunClock.Source.TURN)
	StatusRules.tick_down(warden())

	if _run.clock.is_expired():
		_finish(false)
		return

	phase = Phase.ENEMY_TURN
	_resolve_enemies()
	if is_over():
		return
	begin_turn()


func _resolve_enemies() -> void:
	for handle in range(1, combatants.size()):
		var enemy := combatants[handle]
		if not enemy.is_alive():
			continue
		enemy.block = 0
		if enemy.behavior != null:
			enemy.behavior.on_turn_start(self, handle)
			if not enemy.is_alive():
				_check_end()
				if is_over():
					return
				continue
		var intent := enemy.current_intent()
		if intent != null:
			_perform(handle, intent)
		if enemy.behavior != null:
			enemy.behavior.advance_intent(self, enemy)
			enemy.behavior.on_turn_end(self, handle)
		else:
			enemy.advance_intent()
		StatusRules.tick_down(enemy)
		if not warden().is_alive():
			_finish(false)
			return
	_check_end()


func _perform(handle: int, intent: EnemyIntent) -> void:
	var enemy := combatants[handle]
	var amount := intent.amount
	if enemy.behavior != null:
		amount = enemy.behavior.outgoing_amount(self, handle, intent)
	amount = roundi(amount * enemy.outgoing_multiplier)
	match intent.kind:
		EnemyIntent.Kind.ATTACK:
			for i in maxi(1, intent.times):
				damage(WARDEN, amount, handle)
		EnemyIntent.Kind.BLOCK:
			enemy.block += amount
		EnemyIntent.Kind.STATUS:
			warden().add_status(intent.status, intent.stacks)
		EnemyIntent.Kind.WAIT:
			pass


func damage(handle: int, amount: int, from: int = -1) -> int:
	var target := combatants[handle]
	if not target.is_alive():
		return 0
	var offered := _after_status(handle, amount, from)
	var incoming := offered
	if target.behavior != null:
		incoming = target.behavior.absorbs(self, handle, offered)
		target.behavior.on_absorbed(self, handle, offered - incoming)
	var shielded := mini(incoming, target.block)
	var dealt := target.take_damage(incoming)
	if target.behavior != null and dealt > 0:
		target.behavior.on_damaged(self, handle, dealt)
	if shielded > 0:
		combatant_blocked.emit(handle, shielded)
	if dealt > 0:
		combatant_damaged.emit(handle, dealt)
	if handle == WARDEN and dealt > 0 and from > WARDEN and from < combatants.size():
		var attacker: Combatant = combatants[from]
		if attacker.behavior != null:
			attacker.behavior.on_hit_warden(self, from, dealt)
	if handle != WARDEN and not target.is_alive():
		_run.clock.restore(_run.relic_restored(target.restored_value))
		for relic in _run.relic_defs():
			relic.on_enemy_defeated(_run, self, target)
	return dealt


func _check_end() -> void:
	if not warden().is_alive():
		_finish(false)
	elif enemy_handles().is_empty():
		_finish(true)


func _finish(victory: bool) -> void:
	_run.set_hp(warden().hp)
	phase = Phase.VICTORY if victory else Phase.DEFEAT
	battle_ended.emit(victory)


func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"turn": turn,
		"turn_budget": turn_budget,
		"turn_budget_max": turn_budget_max,
		"cards_played_this_turn": cards_played_this_turn,
		"hand_size": _hand_size,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"piles": _piles.to_dict(),
		"combatants": combatants.map(func(c: Combatant) -> Dictionary: return c.to_dict()),
	}


static func from_dict(data: Dictionary, run: RunState, cards: CardDatabase) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("rng_seed", 0))
	rng.state = int(data.get("rng_state", 0))

	var out := BattleState.new(run, cards, [] as Array[Combatant], rng, true)
	for entry in data.get("combatants", []):
		out.combatants.append(Combatant.from_dict(entry))
	out._piles.from_dict(data.get("piles", {}))
	out.turn = int(data.get("turn", 1))
	out.turn_budget = int(data.get("turn_budget", 0))
	out.turn_budget_max = int(data.get("turn_budget_max", out.turn_budget))
	out.cards_played_this_turn = int(data.get("cards_played_this_turn", 0))
	out._hand_size = int(data.get("hand_size", 5))
	out.phase = int(data.get("phase", Phase.PLAYER_TURN))
	out.follow_the_sky()
	return out


func _after_status(handle: int, amount: int, from: int) -> int:
	var target := combatants[handle]
	var attacker: Combatant = combatants[from] if from >= 0 and from < combatants.size() else null
	return StatusRules.modified_damage(attacker, target, amount)


func preview_damage(handle: int, amount: int, from: int = -1) -> int:
	if handle < 0 or handle >= combatants.size():
		return amount
	var target := combatants[handle]
	if not target.is_alive():
		return 0
	var offered := _after_status(handle, amount, from)
	if target.behavior != null:
		return target.behavior.absorbs(self, handle, offered)
	return offered


func reaches(handle: int) -> bool:
	return preview_damage(handle, 100, WARDEN) > 0
