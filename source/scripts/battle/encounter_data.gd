class_name EncounterData
extends Resource

enum When { ANY, MORNING, DAY, EVENING, NIGHT }

@export var id := &""
@export var act := 1
@export var tier := EnemyData.Tier.NORMAL
@export var weight := 10
@export var members: Array[StringName] = []
@export var opening_only := false
@export var appears := When.ANY
@export var link_pairs := false

## Applied to every member's gauge on top of Threat. 1.0 for anything authored;
## a fight mixed from the solo pool is given the balance profile's figure, because
## two enemies each written to stand alone are more than twice one of them.
@export var hp_scale := 1.0

func validate(enemies: EnemyDatabase) -> PackedStringArray:
	var problems := PackedStringArray()
	var label := String(id) if id != &"" else "<unnamed encounter>"

	if id == &"":
		problems.append("%s: id is required." % label)
		
	if members.is_empty():
		problems.append("%s: has no members." % label)
		
	if weight <= 0:
		problems.append("%s: weight %d would make it unpickable." % [label, weight])
		
	for member in members:
		if not enemies.has(member):
			problems.append("%s: unknown enemy '%s'." % [label, member])
			continue
		# The acts are three separate rosters, not one roster reskinned. An act I
		# encounter fielding an act III Askew would put the least legible thing in
		# the game in front of a player who has met nothing yet.
		var data := enemies.get_enemy(member)
		
		if data.act != act:
			problems.append("%s: is act %d but fields '%s', which is act %d."
				% [label, act, member, data.act])
				
	if link_pairs and members.size() % 2 != 0:
		problems.append("%s: link_pairs needs an even number of members." % label)

	return problems
