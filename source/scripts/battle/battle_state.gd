class_name BattleState
extends RefCounted

signal phase_changed(phase: Phase)
signal turn_started(turn: int)
signal card_played(deck_index: int)
signal combatant_damaged(handle: int, amount: int)
signal combatant_blocked(handle: int, absorbed: int)
signal battle_ended(victory: bool)

enum Phase { PLAYER_TURN, ENEMY_TURN, VICTORY, DEFEAT }

const PLAYER := 0

var phase := Phase.PLAYER_TURN:
	set(value):
		if phase != value:
			phase = value
			phase_changed.emit(value)

var turn := 0
var combatants: Array[Stats] = []
var turn_budget := 0
var turn_budget_max := 0
var cards_played_this_turn := 0
## Minutes paid for the card whose effects are resolving, or being previewed;
## -1 when no card is. Damage that arrives while this is -1 came from no card.
var cost_in_play := -1
## Minutes a card has added to this turn's budget. Time is not made by being
## rearranged: what a card adds is borrowed from the run, and all of it is billed
## to the clock when the turn ends, spent or not. See overtime_now().
var borrowed_this_turn := 0
## How many the card being resolved, or previewed, is aimed at; 0 when no card
## is. More than one means it was not aimed at anyone in particular.
var targets_in_play := 0

var _run: RunState
var _balance: Balance
var _cards: CardDatabase
var _rng: RandomNumberGenerator
var _piles: BattlePiles
var _hand_size := 5

func _init(run: RunState, cards: CardDatabase, enemies: Array[EnemyStats],
		rng: RandomNumberGenerator, restoring := false) -> void:
	_run = run
	_balance = run.clock.balance
	_cards = cards
	_rng = rng

	if restoring:
		_piles = BattlePiles.new(run.deck.size(), rng)
		return

	var player := run.player.spawn(run)
	
	combatants.append(player)
	combatants.append_array(enemies)

	_piles = BattlePiles.new(run.deck.size(), rng)

	follow_the_sky()
	for handle in enemy_handles():
		var who: EnemyStats = enemy(handle)
		
		if who.behavior != null:
			who.behavior.on_battle_start(self, handle)
			
	for relic in run.relic_defs():
		relic.on_battle_start(run, self)

	begin_turn()

func follow_the_sky() -> void:
	var now := _run.clock.daytime()
	
	for handle in enemy_handles():
		var who: EnemyStats = enemy(handle)
		
		who.sky = now

func piles() -> BattlePiles:
	return _piles

## For behaviours that reach past the fight into the run — 가속 and 흘림.
func run() -> RunState:
	return _run

func player() -> Stats:
	return combatants[PLAYER]
	
func enemy(handle: int) -> EnemyStats:
	return combatants[handle] as EnemyStats

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
		var who: EnemyStats = enemy(handle)
		
		if who.behavior != null:
			out = who.behavior.modify_turn_cost(self, handle, out)
			
	return maxi(0, out) + overtime_now()

## What this turn bills the run beyond its own length: everything a card added
## to it, whether or not it was then spent. The hours were taken out of the run
## when they were asked for — unspent time is lost here like any other, and a
## borrowed hour is not an exception. In turn_cost_now(), so the HUD shows it
## leaving the moment the card is played.
func overtime_now() -> int:
	return borrowed_this_turn

## The one way a card adds to the turn. Not `turn_budget += n` from an effect:
## that would be time from nowhere.
func borrow_turn_time(minutes: int) -> void:
	if minutes <= 0:
		return
	turn_budget += minutes
	borrowed_this_turn += minutes

func begin_turn() -> void:
	if is_over():
		return
	turn += 1
	follow_the_sky()
	phase = Phase.PLAYER_TURN
	turn_budget = _run.relic_turn_budget(_balance.turn_cost)
	turn_budget_max = turn_budget
	borrowed_this_turn = 0
	cards_played_this_turn = 0
	player().block = 0
	_piles.draw_cards(_hand_size)
	for relic in _run.relic_defs():
		relic.on_turn_start(_run, self)
	turn_started.emit(turn)

## What playing this card would bill the turn right now, in minutes — the printed
## cost after everything that changes it. One function so that the play and the
## preview of the play cannot disagree.
func cost_of(card: CardData) -> int:
	var cost := card.cost_minutes()
	if card.is_variable_cost():
		cost = turn_budget
	for relic in _run.relic_defs():
		cost = relic.modify_card_cost(_run, self, card, cost)
	return maxi(0, cost)

func play_card(hand_index: int, chosen_target: int = -1) -> bool:
	if phase != Phase.PLAYER_TURN:
		return false
	var card := card_at(hand_index)
	if card == null:
		return false
	if card.has_keyword(CardData.Keyword.UNPLAYABLE):
		return false

	var cost := cost_of(card)
	if cost > turn_budget:
		return false

	var targets := CardTargeting.resolve(card.targeting, PLAYER, enemy_handles(), _rng, chosen_target)
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
	ctx.source = PLAYER
	ctx.targets = targets
	if card.is_variable_cost():
		ctx.variable_amount = cost / Balance.MINUTES_PER_HOUR
	cost_in_play = cost
	targets_in_play = targets.size()
	for effect in card.effects:
		effect.apply(ctx)
	cost_in_play = -1
	targets_in_play = 0

	card_played.emit(deck_index)
	_check_end()
	return true

func end_turn() -> void:
	if phase != Phase.PLAYER_TURN:
		return

	_piles.discard_hand()
	_run.clock.advance(turn_cost_now(), RunClock.Source.TURN)
	StatusRules.tick_down(player())

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
		var target: EnemyStats = enemy(handle)
		
		if not target.is_alive():
			continue
			
		target.block = 0
		
		if target.behavior != null:
			target.behavior.on_turn_start(self, handle)
			
			if not target.is_alive():
				_check_end()
				
				if is_over():
					return
					
				continue
				
		var intent := target.current_intent()
		
		if intent != null:
			_perform(handle, intent)
			
		if target.behavior != null:
			for extra in target.behavior.extra_intents(self, handle):
				_perform(handle, extra)
		# An enemy can spend the run's time as well as the Warden's gauge, and
		# running out is running out whoever spent the last of it.
		if _run.clock.is_expired():
			_finish(false)
			return
			
		if target.behavior != null:
			target.behavior.advance_intent(self, target)
			target.behavior.on_turn_end(self, handle)
		else:
			target.advance_intent()
			
		StatusRules.tick_down(target)
		
		if not player().is_alive():
			_finish(false)
			return
			
	_check_end()

func _perform(handle: int, intent: EnemyIntent) -> void:
	var enemy := enemy(handle)
	var amount := intent.amount
	
	if enemy.behavior != null:
		amount = enemy.behavior.outgoing_amount(self, handle, intent)
		
	amount = roundi(amount * enemy.outgoing_multiplier)
	
	match intent.kind:
		EnemyIntent.Kind.ATTACK:
			for i in maxi(1, intent.times):
				damage(PLAYER, amount, handle)
		EnemyIntent.Kind.BLOCK:
			enemy.block += amount
		EnemyIntent.Kind.STATUS:
			player().add_status(intent.status, intent.stacks)
		EnemyIntent.Kind.GROW:
			enemy.add_status(StatusRules.STRENGTH, intent.stacks)
		EnemyIntent.Kind.BEAR:
			enemy.add_status(intent.status, intent.stacks)
		EnemyIntent.Kind.DRAG:
			# `amount` is what is left of the grip. Nothing left, nothing pulled.
			# The sun is dragged down, so it is always the evening it lands on —
			# and already being there, late in the day, is a pull that moves nothing.
			if amount > 0:
				_run.clock.advance(_run.clock.minutes_until(RunClock.Daytime.EVENING),
					RunClock.Source.TURN)
		EnemyIntent.Kind.WAIT:
			pass

func damage(handle: int, amount: int, from: int = -1) -> int:
	var target := combatants[handle]
	var foe := target as EnemyStats
	
	if not target.is_alive():
		return 0
		
	var offered := _after_status(handle, amount, from)
	var incoming := offered
	
	if foe != null and foe.behavior != null:
		incoming = foe.behavior.absorbs(self, handle, offered)
		foe.behavior.on_absorbed(self, handle, offered - incoming)
		
	var shielded := mini(incoming, target.block)
	
	if incoming > shielded:
		incoming -= _diverted(handle, from, incoming - shielded)
		
	var dealt := target.take_damage(incoming)
	
	if foe != null and foe.behavior != null and dealt > 0:
		foe.behavior.on_damaged(self, handle, dealt)
		
	if shielded > 0:
		combatant_blocked.emit(handle, shielded)
		
	if dealt > 0:
		combatant_damaged.emit(handle, dealt)
		
	if handle == PLAYER and dealt > 0 and from > PLAYER and from < combatants.size():
		var attacker: EnemyStats = enemy(from)
		
		if attacker.behavior != null:
			attacker.behavior.on_hit_player(self, from, dealt)
			
	if handle != PLAYER and not target.is_alive():
		_run.clock.restore(_run.relic_restored(foe.restored_value))
		
		for relic in _run.relic_defs():
			relic.on_enemy_defeated(_run, self, foe)
			
		if foe != null and foe.behavior != null:
			foe.behavior.on_defeated(self, handle)
			
	return dealt

## Called by the effect context as a card hands out block or a status, so the
## enemies that listen can hear it. Nothing here changes what the card did.
func heard_block(target: int, amount: int) -> void:
	for handle in enemy_handles():
		var who: EnemyStats = enemy(handle)
		
		if who.behavior != null:
			who.behavior.on_block_gained(self, handle, target, amount)

func heard_status(target: int, status: StringName, stacks: int) -> void:
	for handle in enemy_handles():
		var who: EnemyStats = enemy(handle)
		
		if who.behavior != null:
			who.behavior.on_status_applied(self, handle, target, status, stacks)

func _diverted(handle: int, from: int, through: int) -> int:
	if handle != PLAYER or from <= PLAYER or from >= combatants.size():
		return 0
		
	var attacker: EnemyStats = enemy(from)
	
	if attacker.behavior == null:
		return 0
		
	return clampi(attacker.behavior.diverts_hit(self, from, through), 0, through)

func _check_end() -> void:
	if not player().is_alive():
		_finish(false)
	elif enemy_handles().is_empty():
		_finish(true)

func _finish(victory: bool) -> void:
	_run.set_hp(player().hp)
	phase = Phase.VICTORY if victory else Phase.DEFEAT
	battle_ended.emit(victory)

func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"turn": turn,
		"turn_budget": turn_budget,
		"turn_budget_max": turn_budget_max,
		"cards_played_this_turn": cards_played_this_turn,
		"borrowed_this_turn": borrowed_this_turn,
		"hand_size": _hand_size,
		"rng_seed": _rng.seed,
		"rng_state": _rng.state,
		"piles": _piles.to_dict(),
		"combatants": combatants.map(func(c: Stats) -> Dictionary: return c.to_dict()),
	}

static func from_dict(data: Dictionary, run: RunState, cards: CardDatabase) -> BattleState:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("rng_seed", 0))
	rng.state = int(data.get("rng_state", 0))

	var out := BattleState.new(run, cards, [] as Array[EnemyStats], rng, true)
	for entry in data.get("combatants", []):
		out.combatants.append(Stats.from_dict(entry))
	out._piles.from_dict(data.get("piles", {}))
	out.turn = int(data.get("turn", 1))
	out.turn_budget = int(data.get("turn_budget", 0))
	out.turn_budget_max = int(data.get("turn_budget_max", out.turn_budget))
	out.cards_played_this_turn = int(data.get("cards_played_this_turn", 0))
	out.borrowed_this_turn = int(data.get("borrowed_this_turn", 0))
	out._hand_size = int(data.get("hand_size", 5))
	out.phase = int(data.get("phase", Phase.PLAYER_TURN))
	out.follow_the_sky()
	return out

func _after_status(handle: int, amount: int, from: int) -> int:
	var target := combatants[handle]
	var attacker: Stats = combatants[from] if from >= 0 and from < combatants.size() else null
	return StatusRules.modified_damage(attacker, target, amount)

func preview_damage(handle: int, amount: int, from: int = -1) -> int:
	if handle < 0 or handle >= combatants.size():
		return amount
		
	var target := combatants[handle]
	var foe := target as EnemyStats
	
	if not target.is_alive():
		return 0
		
	var offered := _after_status(handle, amount, from)
	
	if foe != null and foe.behavior != null:
		return foe.behavior.absorbs(self, handle, offered)
		
	return offered

func reaches(handle: int) -> bool:
	return preview_damage(handle, 100, PLAYER) > 0
