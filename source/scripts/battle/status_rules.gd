class_name StatusRules
extends RefCounted


const VULNERABLE := &"vulnerable"

const WEAK := &"weak"

const DURATIONS := [VULNERABLE, WEAK]


static func modified_damage(attacker: Combatant, target: Combatant, amount: int) -> int:
	var out := float(amount)
	if attacker != null and attacker.status(WEAK) > 0:
		out *= 0.75
	if target != null and target.status(VULNERABLE) > 0:
		out *= 1.5
	return floori(out)


static func tick_down(who: Combatant) -> void:
	for id in DURATIONS:
		if who.status(id) > 0:
			who.add_status(id, -1)
