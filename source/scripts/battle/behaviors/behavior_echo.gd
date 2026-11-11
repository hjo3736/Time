class_name BehaviorEcho
extends EnemyBehavior


## How much of a number comes back. Statuses are not numbers of that kind — two
## turns of 물러짐 is two turns of it — so they come back as they were.
@export var share := 2.0 / 3.0

var _damage := 0
var _block := 0
var _inflicted := {}
var _taken_on := {}


## 메아리. Has no pattern of its own: what it does next turn is what was done
## this turn. The blows it took come back as a blow, the guard the Warden raised
## comes back as its guard, what was put on it is put on the Warden and what the
## Warden put on itself it puts on itself.
##
## Damage is counted on what reached the gauge — a blow its block took was never
## heard. Guard and statuses are counted from cards only, which is what "done"
## means: a relic that softens every enemy as the fight opens did not do anything.
func on_damaged(_battle: BattleState, _handle: int, dealt: int) -> void:
	_damage += dealt


func on_block_gained(battle: BattleState, _handle: int, target: int, amount: int) -> void:
	if target == BattleState.WARDEN and battle.cost_in_play >= 0:
		_block += amount


func on_status_applied(battle: BattleState, handle: int, target: int,
		status: StringName, stacks: int) -> void:
	if battle.cost_in_play < 0 or stacks <= 0:
		return
	if target == handle:
		_inflicted[status] = int(_inflicted.get(status, 0)) + stacks
	elif target == BattleState.WARDEN:
		_taken_on[status] = int(_taken_on.get(status, 0)) + stacks


## Settled as its turn ends, from the turn the player just finished, and shown
## for the whole of the next one before any of it lands. The blow is written
## first so it is the intent everything else reads as this turn's; the rest
## follow it as extra_intents().
func advance_intent(_battle: BattleState, who: Stats) -> void:
	var next: Array[EnemyIntent] = []
	if _damage > 0:
		next.append(EnemyIntent.attack(ceili(_damage * share)))
	if _block > 0:
		next.append(EnemyIntent.block(ceili(_block * share)))
	for status in _sorted(_inflicted):
		next.append(EnemyIntent.inflict(status, int(_inflicted[status])))
	for status in _sorted(_taken_on):
		next.append(EnemyIntent.bear(status, int(_taken_on[status])))
	if next.is_empty():
		next.append(EnemyIntent.wait())

	_damage = 0
	_block = 0
	_inflicted = {}
	_taken_on = {}
	who.intents = next
	who.intent_index = 0


func extra_intents(battle: BattleState, handle: int) -> Array[EnemyIntent]:
	var who: Stats = battle.combatants[handle]
	return who.intents.slice(1)


func _sorted(heard: Dictionary) -> Array:
	var keys := heard.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return keys


func tell_key() -> StringName:
	return &"askew.echo.tell"


func to_dict() -> Dictionary:
	return {
		"_damage": _damage,
		"_block": _block,
		"_inflicted": _written(_inflicted),
		"_taken_on": _written(_taken_on),
	}


func from_dict(data: Dictionary) -> void:
	_damage = int(data.get("_damage", 0))
	_block = int(data.get("_block", 0))
	_inflicted = _read(data.get("_inflicted", {}))
	_taken_on = _read(data.get("_taken_on", {}))


func _written(heard: Dictionary) -> Dictionary:
	var out := {}
	for status in heard:
		out[String(status)] = int(heard[status])
	return out


func _read(written: Dictionary) -> Dictionary:
	var out := {}
	for status in written:
		out[StringName(status)] = int(written[status])
	return out
