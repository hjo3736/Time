class_name BehaviorRelay
extends EnemyBehavior


@export var growth := 3

var _base := 0
var _holds := false
var _power := 0
var _incoming := 0


## 이어달리기. One baton between however many runners: only the one holding it
## strikes, and having struck it hands it on, a little heavier each time. The
## runner written first starts with it, at the blow it was authored with.
func on_battle_start(battle: BattleState, handle: int) -> void:
	var who: Combatant = battle.combatants[handle]
	_base = who.intents[0].amount if not who.intents.is_empty() else 0
	if _first_runner(battle) == handle:
		_take(who, _base)
	else:
		_rest(who)


## Settled as its own turn ends, so what every runner is showing through the
## player's turn is what that runner does.
##
## Handing on has to mind the order they resolve in. A runner further down the
## line has not had its turn yet this round, and a baton put straight into its
## hand would be swung at once, unannounced. So it is only told one is coming,
## and takes it up as its own turn ends. A runner earlier in the line has already
## been, and can simply be given it.
func advance_intent(battle: BattleState, who: Combatant) -> void:
	var handle := battle.combatants.find(who)
	if _incoming > 0:
		_take(who, _incoming)
		_incoming = 0
		return
	if _holds:
		var next := _next_runner(battle, handle)
		var heavier := _power + growth
		if next == handle:
			_take(who, heavier)
			return
		_rest(who)
		var to: Combatant = battle.combatants[next]
		var theirs := to.behavior as BehaviorRelay
		if next > handle:
			theirs._incoming = heavier
		else:
			theirs._take(to, heavier)
		return
	# Nobody has it: whoever was holding went down with it in their hand. It is
	# picked up where it fell, at the weight it started — that is what bringing
	# the holder down buys, besides the blow that never came.
	if not _someone_has_it(battle):
		_take(who, _base)


func _take(who: Combatant, power: int) -> void:
	_holds = true
	_power = power
	var next: Array[EnemyIntent] = [EnemyIntent.attack(power)]
	who.intents = next
	who.intent_index = 0


func _rest(who: Combatant) -> void:
	_holds = false
	_power = 0
	var next: Array[EnemyIntent] = [EnemyIntent.wait()]
	who.intents = next
	who.intent_index = 0


func _runners(battle: BattleState) -> PackedInt32Array:
	var out := PackedInt32Array()
	for handle in battle.enemy_handles():
		if battle.combatants[handle].behavior is BehaviorRelay:
			out.append(handle)
	return out


func _first_runner(battle: BattleState) -> int:
	var all := _runners(battle)
	return all[0] if not all.is_empty() else -1


func _next_runner(battle: BattleState, handle: int) -> int:
	var all := _runners(battle)
	for other in all:
		if other > handle:
			return other
	return all[0] if not all.is_empty() else handle


func _someone_has_it(battle: BattleState) -> bool:
	for handle in _runners(battle):
		var theirs := battle.combatants[handle].behavior as BehaviorRelay
		if theirs._holds or theirs._incoming > 0:
			return true
	return false


func holds() -> bool:
	return _holds


func tell_key() -> StringName:
	return &"askew.relay.tell"


func to_dict() -> Dictionary:
	return {"_base": _base, "_holds": _holds, "_power": _power, "_incoming": _incoming}


func from_dict(data: Dictionary) -> void:
	_base = int(data.get("_base", 0))
	_holds = bool(data.get("_holds", false))
	_power = int(data.get("_power", 0))
	_incoming = int(data.get("_incoming", 0))
