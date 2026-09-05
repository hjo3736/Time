class_name EnemyIntent
extends Resource


enum Kind { ATTACK, BLOCK, STATUS, WAIT }

@export var kind := Kind.ATTACK
@export var amount := 5
@export var times := 1
@export var status := &""
@export var stacks := 0

@export var is_break_window := false


static func attack(amount: int, times: int = 1) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.ATTACK
	i.amount = amount
	i.times = times
	return i


static func block(amount: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.BLOCK
	i.amount = amount
	return i


static func inflict(status_id: StringName, stacks: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.kind = Kind.STATUS
	i.status = status_id
	i.stacks = stacks
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
	out.kind = int(data.get("kind", Kind.ATTACK))
	out.amount = int(data.get("amount", 5))
	out.times = int(data.get("times", 1))
	out.status = StringName(data.get("status", ""))
	out.stacks = int(data.get("stacks", 0))
	out.is_break_window = bool(data.get("is_break_window", false))
	return out
