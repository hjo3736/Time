class_name BehaviorSunDragger
extends EnemyBehavior


## How much harder it holds on after each pull that was broken.
@export var tighten := 4

## Strength for every this many minutes a pull took out of the day, on top of
## what it grows by in the evening anyway.
@export var minutes_per_growth := 180

var _taken := 0
var _tightened := 0
var _base_growth := 1
var _elapsed_shown := 0
var _performed: EnemyIntent = null


## 해를 끄는 것. All morning and all day it pulls at the sun. A pull is shown for
## a whole turn before it happens, and what the gauge loses in that turn is
## counted against its grip: take the grip's worth and the pull fails. So
## outgoing_amount() for a DRAG is what is left of the grip, which is also what
## the view prints — the number on the intent is the damage still owed.
##
## Breaking a pull is not free twice. Every one that fails, it holds on harder
## for the rest of the fight, so the day can be kept for a while and not forever.
func on_battle_start(battle: BattleState, handle: int) -> void:
	var who: Combatant = battle.combatants[handle]
	if not who.evening_intents.is_empty():
		_base_growth = who.evening_intents[0].stacks
	_elapsed_shown = battle.run().clock.elapsed


func on_damaged(_battle: BattleState, _handle: int, dealt: int) -> void:
	_taken += dealt


func outgoing_amount(_battle: BattleState, _handle: int, intent: EnemyIntent) -> int:
	if intent.kind == EnemyIntent.Kind.DRAG:
		return maxi(0, intent.amount + _tightened - _taken)
	return intent.amount



## What the turn it just took came to. A pull that held has moved the clock, and
## by how much — counted from when the pull was first shown, so the turn it took
## is part of it — is how much it grows by when the evening arrives: that is
## written into the evening's intent here, so it is on show for the whole of the
## evening before it lands. An evening that came by itself is only the base.
func on_turn_end(battle: BattleState, handle: int) -> void:
	if battle == null:
		_taken = 0
		return
	var who: Combatant = battle.combatants[handle]
	var performed := _performed
	if performed == null:
		_taken = 0
		return
	match performed.kind:
		EnemyIntent.Kind.DRAG:
			if outgoing_amount(battle, handle, performed) <= 0:
				_tightened += tighten
			else:
				var pulled: int = battle.run().clock.elapsed - _elapsed_shown
				_set_evening(who, _base_growth + pulled / minutes_per_growth)
		EnemyIntent.Kind.GROW:
			_set_evening(who, _base_growth)
	_taken = 0
	_elapsed_shown = battle.run().clock.elapsed


func _set_evening(who: Combatant, stacks: int) -> void:
	var next: Array[EnemyIntent] = [EnemyIntent.grow(stacks)]
	who.evening_intents = next


## Everything else carries its place in the cycle across a change of sky; this
## one begins each sky from the top, because it is the thing changing the sky and
## its fight has to be countable.
##
## Read off the clock rather than off `sky`, which is not brought up to date
## until the next turn begins — by which time the intent is already on show.
func advance_intent(battle: BattleState, who: Combatant) -> void:
	_performed = who.current_intent()
	who.advance_intent()
	if battle != null and battle.run().clock.daytime() != who.sky:
		who.intent_index = 0


func tightened() -> int:
	return _tightened


func tell_key() -> StringName:
	return &"askew.sun_dragger.tell"


func to_dict() -> Dictionary:
	return {"_taken": _taken, "_tightened": _tightened, "_base_growth": _base_growth,
		"_elapsed_shown": _elapsed_shown}


func from_dict(data: Dictionary) -> void:
	_taken = int(data.get("_taken", 0))
	_tightened = int(data.get("_tightened", 0))
	_base_growth = int(data.get("_base_growth", 1))
	_elapsed_shown = int(data.get("_elapsed_shown", 0))
