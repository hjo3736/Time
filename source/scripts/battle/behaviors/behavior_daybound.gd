class_name BehaviorDaybound
extends EnemyBehavior


var _day := -1


func on_battle_start(battle: BattleState, _handle: int) -> void:
	_day = battle.run().clock.day_index()


## 날 넘김. The deadline inside this fight is not a turn count, it is midnight —
## so how long the player has is decided on the map, by when they walk in. Reset
## at the end of its turn rather than the start, for the reason 성장 is granted
## there: what was read is what lands. The pattern is deliberately left where it
## is. Midnight falls on a different step of it depending on when the fight began
## and how long a turn is, and a pattern that jumped would be one more thing to
## work out on top of the reset itself.
func on_turn_end(battle: BattleState, handle: int) -> void:
	if battle == null:
		return
	var today := battle.run().clock.day_index()
	if today == _day:
		return
	_day = today
	var who: Stats = battle.combatants[handle]
	who.hp = who.max_hp
	who.block = 0
	who.statuses.clear()


func tell_key() -> StringName:
	return &"askew.daybound.tell"


func to_dict() -> Dictionary:
	return {"_day": _day}


func from_dict(data: Dictionary) -> void:
	_day = int(data.get("_day", -1))
