class_name StatusRules
extends RefCounted


const SOFTENED := &"softened"

const BLUNTED := &"blunted"

const DURATIONS := [SOFTENED, BLUNTED]


static func modified_damage(attacker: Combatant, target: Combatant, amount: int) -> int:
	var out := float(amount)
	if attacker != null and attacker.status(BLUNTED) > 0:
		out *= 0.75
	if target != null and target.status(SOFTENED) > 0:
		out *= 1.5
	return floori(out)


static func tick_down(who: Combatant) -> void:
	for id in DURATIONS:
		if who.status(id) > 0:
			who.add_status(id, -1)
