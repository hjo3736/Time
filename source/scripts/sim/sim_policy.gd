class_name SimPolicy
extends RefCounted


var greed := 0.6

var _rng: RandomNumberGenerator
var _cards: CardDatabase


func _init(p_greed: float, rng: RandomNumberGenerator, cards: CardDatabase = null) -> void:
	greed = p_greed
	_rng = rng
	_cards = cards


func incoming(battle: BattleState) -> int:
	var total := 0
	for handle in battle.enemy_handles():
		total += incoming_from(battle, handle)
	return total


func incoming_from(battle: BattleState, handle: int) -> int:
	var enemy: Combatant = battle.combatants[handle]
	if not enemy.is_alive():
		return 0
	var intent := enemy.current_intent()
	if intent == null or intent.kind != EnemyIntent.Kind.ATTACK:
		return 0
	var amount := intent.amount
	if enemy.behavior != null:
		amount = enemy.behavior.outgoing_amount(battle, handle, intent)
	amount = roundi(amount * enemy.outgoing_multiplier)
	amount = StatusRules.modified_damage(enemy, battle.warden(), amount)
	return amount * maxi(1, intent.times)


func worth(card: CardData, battle: BattleState = null, target: Combatant = null) -> float:
	if card == null:
		return 0.0
	if card.keywords & 16 != 0:
		return -100.0
	var out := 0.0
	var warden: Combatant = battle.warden() if battle != null else null
	for effect in card.effects:
		if effect is EffectDamage:
			var d: EffectDamage = effect
			var hit := d.amount
			if warden != null:
				hit = StatusRules.modified_damage(warden, target, hit)
			out += float(hit * maxi(1, d.times))
		elif effect is EffectVariableDamage:
			out += float((effect as EffectVariableDamage).per_hour) * 2.0
		elif effect is EffectScalingDamage:
			var s: EffectScalingDamage = effect
			out += float(s.base) + float(s.per_card) + float(s.per_turn)
		elif effect is EffectBlock:
			out += float((effect as EffectBlock).amount)
		elif effect is EffectScalingBlock:
			out += 6.0
		elif effect is EffectApplyStatus:
			var a: EffectApplyStatus = effect
			if not a.on_self:
				out += float(a.stacks) * 3.0
		elif effect is EffectDraw:
			out += float((effect as EffectDraw).count) * 4.0
		elif effect is EffectRefundTime:
			out += float((effect as EffectRefundTime).minutes) / 60.0 * 3.0
		elif effect is EffectRestoreTime:
			out += 1.0
	return out


func _is_defensive(card: CardData) -> bool:
	for effect in card.effects:
		if effect is EffectBlock or effect is EffectScalingBlock:
			return true
	return false


func _damage_of(card: CardData, battle: BattleState, target: Combatant) -> int:
	var out := 0
	for effect in card.effects:
		if effect is EffectDamage:
			var d: EffectDamage = effect
			out += StatusRules.modified_damage(battle.warden(), target, d.amount) * maxi(1, d.times)
		elif effect is EffectVariableDamage:
			out += (effect as EffectVariableDamage).per_hour
		elif effect is EffectScalingDamage:
			out += (effect as EffectScalingDamage).base
	return out


func take_turn(rc: RunController) -> void:
	var battle := rc.battle
	var guard := 0
	while rc.phase == RunController.Phase.BATTLE and guard < 40:
		guard += 1
		if not _play_one(rc, battle):
			rc.end_turn()
			return


func _pick_target(battle: BattleState) -> int:
	var handles := battle.enemy_handles()
	if handles.is_empty():
		return -1
	var best := -1
	var best_score := -INF
	for handle in handles:
		var enemy: Combatant = battle.combatants[handle]
		if not enemy.is_alive():
			continue
		var score := float(incoming_from(battle, handle)) * 2.0
		score -= float(enemy.hp + enemy.block) * 0.5
		if _can_finish(battle, enemy):
			score += 100.0
		if score > best_score:
			best_score = score
			best = handle
	return best if best >= 0 else handles[0]


func _can_finish(battle: BattleState, target: Combatant) -> bool:
	var entries := []
	for i in battle.piles().hand.size():
		var card := battle.card_at(i)
		if card == null or _is_defensive(card):
			continue
		var dmg := _damage_of(card, battle, target)
		if dmg <= 0:
			continue
		entries.append({"cost": maxi(0, card.cost_hours), "dmg": dmg})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dmg"]) / maxf(1.0, float(a["cost"])) \
			> float(b["dmg"]) / maxf(1.0, float(b["cost"])))
	var budget := battle.turn_budget
	var total := 0
	for entry in entries:
		if int(entry["cost"]) > budget:
			continue
		budget -= int(entry["cost"])
		total += int(entry["dmg"])
	return total >= target.hp + target.block


func _play_one(rc: RunController, battle: BattleState) -> bool:
	var target_handle := _pick_target(battle)
	if target_handle < 0:
		return false
	var target: Combatant = battle.combatants[target_handle]

	var clearing := true
	for handle in battle.enemy_handles():
		var enemy: Combatant = battle.combatants[handle]
		if enemy.is_alive() and not _can_finish(battle, enemy):
			clearing = false
			break
	var defend := incoming(battle) > battle.warden().block and not clearing

	for i in _hand_order(battle, target, defend):
		if rc.play_card(i, target_handle):
			return true
	return false


func _hand_order(battle: BattleState, target: Combatant, defend: bool) -> Array:
	var scored := []
	for i in battle.piles().hand.size():
		var card := battle.card_at(i)
		if card == null:
			continue
		var score := worth(card, battle, target) / maxf(1.0, float(card.cost_hours))
		if _is_defensive(card) == defend:
			score *= 2.0
		scored.append({"i": i, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	return scored.map(func(e: Dictionary) -> int: return int(e["i"]))


func projected_need(rc: RunController, balance: Balance) -> int:
	var acts_left := balance.acts_per_run - rc.run.act + 1
	return acts_left * 90 * Balance.MINUTES_PER_HOUR


func at_fire(rc: RunController, balance: Balance) -> void:
	var run := rc.run
	var short_on_time := run.clock.remaining < projected_need(rc, balance)
	var hurt := run.hp < roundi(run.max_hp * 0.6)

	if short_on_time and run.clock.convertible_restored() >= balance.conversion_rate * 2:
		if rc.use_fire(RunState.FireAction.CONVERT):
			return
	if hurt and rc.use_fire(RunState.FireAction.REST):
		return
	if rc.use_fire(RunState.FireAction.UPGRADE, _best_deck_index(run)):
		return
	rc.leave_fire()


func _best_deck_index(run: RunState) -> int:
	if run.deck.is_empty() or _cards == null:
		return 0
	var best := 0
	var best_score := -INF
	for i in run.deck.size():
		var entry: Dictionary = run.deck[i]
		var card := _cards.get_card(entry["id"])
		if card == null:
			continue
		var score := worth(card) - float(int(entry.get("upgrades", 0))) * 100.0
		if score > best_score:
			best_score = score
			best = i
	return best


func at_reward(rc: RunController) -> void:
	var deck := rc.run.deck.size()
	if deck >= 20:
		rc.skip_reward()
		return
	var pick := _best_offer(rc.run.pending_reward())
	if deck >= 14 and pick.y < 8.0:
		rc.skip_reward()
		return
	if not rc.take_reward(int(pick.x)):
		rc.skip_reward()


func _best_offer(ids: Array) -> Vector2:
	var best := 0
	var best_score := -INF
	if _cards != null:
		for i in ids.size():
			var card := _cards.get_card(ids[i])
			if card == null:
				continue
			var score := worth(card)
			if score > best_score:
				best_score = score
				best = i
	return Vector2(best, best_score)


func at_shop(rc: RunController) -> void:
	var guard := 0
	while rc.shop != null and guard < 8:
		guard += 1
		if rc.run.deck.size() > 12 and rc.buy_removal(_worst_deck_index(rc.run)):
			continue
		var bought := false
		for i in _shop_order(rc.shop):
			if rc.run.deck.size() < 20 and rc.buy_card(i):
				bought = true
				break
		if not bought:
			break
	rc.leave_shop()


func _shop_order(shop: Shop) -> Array:
	var scored := []
	for i in shop.cards.size():
		scored.append({"i": i, "score": worth(shop.cards[i])})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"]))
	return scored.map(func(e: Dictionary) -> int: return int(e["i"]))


func _worst_deck_index(run: RunState) -> int:
	if run.deck.is_empty() or _cards == null:
		return 0
	var worst := 0
	var worst_score := INF
	for i in run.deck.size():
		var card := _cards.get_card(run.deck[i]["id"])
		if card == null:
			continue
		var score := worth(card)
		if score < worst_score:
			worst_score = score
			worst = i
	return worst


func at_event(rc: RunController) -> void:
	var e := rc.event
	if e == null:
		return
	var best := -1
	var best_score := -INF
	for i in e.choices.size():
		var choice: EventChoice = e.choices[i]
		if not choice.available(rc.run):
			continue
		var score := _event_score(choice)
		if score > best_score:
			best_score = score
			best = i
	if best < 0 or not rc.choose_event(best):
		for i in e.choices.size():
			if rc.choose_event(i):
				return


func _event_score(choice: EventChoice) -> float:
	var score := 0.0
	for outcome in choice.outcomes:
		if outcome is OutcomeHealth:
			score += float((outcome as OutcomeHealth).amount)
		elif outcome is OutcomeRestored:
			score += float((outcome as OutcomeRestored).hours) * 1.5
		elif outcome is OutcomeCard:
			score += 4.0
		elif outcome is OutcomeSpendTime:
			score -= float((outcome as OutcomeSpendTime).hours) * (6.0 - 4.0 * greed)
	return score
