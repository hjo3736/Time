class_name EnemyIntent
extends Resource


## New kinds go on the end: a saved fight stores the kind as its number.
enum Kind { ATTACK, BLOCK, STATUS, WAIT, GROW, BEAR, DRAG }

@export var kind := Kind.ATTACK
@export var amount := 5
@export var times := 1
@export var status := &""
@export var stacks := 0

@export var is_break_window := false


static func attack(p_amount: int, p_times: int = 1) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.ATTACK
	i.amount = p_amount
	i.times = p_times
	return i


static func block(p_amount: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.BLOCK
	i.amount = p_amount
	return i


static func inflict(status_id: StringName, p_stacks: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.STATUS
	i.status = status_id
	i.stacks = p_stacks
	return i


## 성장 as a turn of its own: the enemy spends the turn and keeps the Strength.
## Carried in `stacks`, like a status, so Threat does not scale it.
static func grow(p_stacks: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.GROW
	i.stacks = p_stacks
	return i


## A status the enemy puts on itself. STATUS is always aimed at the Warden, and
## GROW is only ever Strength; this is the rest.
static func bear(status_id: StringName, p_stacks: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.BEAR
	i.status = status_id
	i.stacks = p_stacks
	return i


## Pulls the run's clock on to the next sky. `amount` is the grip: how much it
## has to take in the turn it is showing this for the pull to fail. Whether it
## failed is the behaviour's to say — with none, nothing can stop it.
static func drag(grip: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.DRAG
	i.amount = grip
	return i


static func wait() -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.WAIT
	return i


func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"amount": amount,
		"times": times,
		"status": String(status),
		"stacks": stacks,
		"is_break_window": is_break_window,
	}


static func from_dict(data: Dictionary) -> EnemyIntent:
	var out := EnemyIntent.new()
	out.kind = int(data.get("kind", Kind.ATTACK)) as Kind
	out.amount = int(data.get("amount", 5))
	out.times = int(data.get("times", 1))
	out.status = StringName(data.get("status", ""))
	out.stacks = int(data.get("stacks", 0))
	out.is_break_window = bool(data.get("is_break_window", false))
	return out
