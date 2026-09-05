class_name EncounterData
extends Resource


@export var id := &""
@export var act := 1
@export var tier := EnemyData.Tier.NORMAL

@export var weight := 10

@export var members: Array[StringName] = []

@export var opening_only := false

@export var link_pairs := false


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
	if link_pairs and members.size() % 2 != 0:
		problems.append("%s: link_pairs needs an even number of members." % label)

	return problems
