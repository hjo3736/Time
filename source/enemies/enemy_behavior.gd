class_name EnemyBehavior
extends Resource


## Once, when the fight opens and before the first hand is drawn. Not called on a
## resumed fight — whatever this set is in to_dict() and comes back from there.
func on_battle_start(_battle: BattleState, _handle: int) -> void:
	pass


func on_turn_start(_battle: BattleState, _handle: int) -> void:
	pass


func on_turn_end(_battle: BattleState, _handle: int) -> void:
	pass


func absorbs(_battle: BattleState, _handle: int, amount: int) -> int:
	return amount


func on_absorbed(_battle: BattleState, _handle: int, _amount: int) -> void:
	pass


func on_damaged(_battle: BattleState, _handle: int, _dealt: int) -> void:
	pass


func outgoing_amount(_battle: BattleState, _handle: int, intent: EnemyIntent) -> int:
	return intent.amount


## What a turn of this fight bills to the run's clock. The only hook that reaches
## out of the battle and into the run, so the only one a block cannot answer.
func modify_turn_cost(_battle: BattleState, _handle: int, base: int) -> int:
	return base


## Called when one of this enemy's blows takes hp off the Warden — after block, so
## only what actually got through. `dealt` is that hp.
func on_hit_warden(_battle: BattleState, _handle: int, _dealt: int) -> void:
	pass


## Asked before one of this enemy's blows takes hp off the Warden, with what got
## past the block. Returns how much of it was paid for somewhere else; only the
## rest reaches hp, and on_hit_warden follows only if some of it did.
func diverts_hit(_battle: BattleState, _handle: int, _through: int) -> int:
	return 0


## Called once, as this enemy's gauge reaches nothing through a blow — after the
## time it held has been recovered.
func on_defeated(_battle: BattleState, _handle: int) -> void:
	pass


## Asked as the Warden's cards resolve: someone was given block, or a status.
## `target` is who received it. Every living enemy is told, not only the one it
## landed on — the thing listening is not always the thing struck.
func on_block_gained(_battle: BattleState, _handle: int, _target: int, _amount: int) -> void:
	pass


func on_status_applied(_battle: BattleState, _handle: int, _target: int,
		_status: StringName, _stacks: int) -> void:
	pass


## Anything this enemy does in a turn besides the intent it is showing. Performed
## after that intent, in order, and drawn under it — a turn that does three
## things has to say all three before it does any of them.
func extra_intents(_battle: BattleState, _handle: int) -> Array[EnemyIntent]:
	return []


func advance_intent(_battle: BattleState, who: EnemyStats) -> void:
	who.advance_intent()


func tell_key() -> StringName:
	return &""


func to_dict() -> Dictionary:
	return {}


func from_dict(_data: Dictionary) -> void:
	pass
