class_name StatusRules
extends RefCounted


const SOFTENED := &"softened"

const BLUNTED := &"blunted"

## Flat damage added to every attack the holder makes. Unlike the two above it
## does not tick down: it is a buff that stays for the fight, and it stacks.
const STRENGTH := &"strength"

const DURATIONS := [SOFTENED, BLUNTED]


## Strength lands before the multipliers, so 무뎌짐 blunts the strength too. The
## other order would let a strong attacker shrug the debuff off by out-scaling it.
static func modified_damage(attacker: Combatant, target: Combatant, amount: int) -> int:
	var out := float(amount)
	if attacker != null:
		out += float(attacker.status(STRENGTH))
	if attacker != null and attacker.status(BLUNTED) > 0:
		out *= 0.75
	if target != null and target.status(SOFTENED) > 0:
		out *= 1.5
	return maxi(0, floori(out))


static func tick_down(who: Combatant) -> void:
	for id in DURATIONS:
		if who.status(id) > 0:
			who.add_status(id, -1)
