class_name BehaviorBulwark
extends EnemyBehavior

@export var cap := 15

var _taken := 0

## 버팀목. Gives way a fixed amount a turn and no more: past `cap`, what is dealt
## to it is simply lost. Counted on the gauge, so what its own block takes does
## not use any of the allowance up. The length of the fight is therefore known
## at the door — its gauge over the cap, in turns, at three hours each — and the
## only question is what the hours left over in each of those turns are for.
func absorbs(battle: BattleState, handle: int, amount: int) -> int:
	var block := battle.enemy(handle).block if battle != null else 0
	return mini(amount, maxi(0, cap - _taken) + block)

func on_damaged(_battle: BattleState, _handle: int, dealt: int) -> void:
	_taken += dealt

func on_turn_start(_battle: BattleState, _handle: int) -> void:
	_taken = 0

func taken() -> int:
	return _taken

func tell_key() -> StringName:
	return &"askew.bulwark.tell"

func to_dict() -> Dictionary:
	return {"_taken": _taken}

func from_dict(data: Dictionary) -> void:
	_taken = int(data.get("_taken", 0))
