class_name BattleEffectContext
extends EffectContext


var variable_amount := 0

var _battle: BattleState


func _init(battle: BattleState) -> void:
	_battle = battle


func _at(handle: int) -> Combatant:
	if handle < 0 or handle >= _battle.combatants.size():
		return null
	return _battle.combatants[handle]


func deal_damage(target: int, amount: int) -> int:
	return _battle.damage(target, amount, source)


func gain_block(target: int, amount: int) -> void:
	var c := _at(target)
	if c != null:
		c.block += amount
		_battle.heard_block(target, amount)


func apply_status(target: int, status: StringName, stacks: int) -> void:
	var c := _at(target)
	if c != null:
		c.add_status(status, stacks)
		_battle.heard_status(target, status, stacks)


func draw_cards(count: int) -> int:
	return _battle.piles().draw_cards(count)


func refund_turn_time(minutes: int) -> void:
	_battle.borrow_turn_time(minutes)


func restore_time(minutes: int) -> void:
	_battle.rng()
	_battle._run.clock.restore(minutes)


func is_alive(target: int) -> bool:
	var c := _at(target)
	return c != null and c.is_alive()


func get_block(target: int) -> int:
	var c := _at(target)
	return c.block if c != null else 0


func get_status(target: int, status: StringName) -> int:
	var c := _at(target)
	return c.status(status) if c != null else 0


func turn_index() -> int:
	return _battle.turn


func cards_played_this_turn() -> int:
	return _battle.cards_played_this_turn


func days_elapsed() -> int:
	return _battle.run().clock.day_index()


func hand_size() -> int:
	return _battle.piles().hand.size()


func rng() -> RandomNumberGenerator:
	return _battle.rng()


func random_living_enemy() -> int:
	var alive := _battle.enemy_handles()
	if alive.is_empty():
		return -1
	return alive[_battle.rng().randi_range(0, alive.size() - 1)]
