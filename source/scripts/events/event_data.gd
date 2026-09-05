class_name EventData
extends Resource


@export var id := &""
@export var act := 1
@export var weight := 10

@export var title_key := &""
@export var body_key := &""
@export var choices: Array[EventChoice] = []


func title() -> String:
	return tr(title_key)


func body() -> String:
	return tr(body_key)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("an event has no id.")
	if title_key == &"" or body_key == &"":
		problems.append("%s: missing title or body key." % id)
	if choices.size() < 2:
		problems.append("%s: an event with fewer than two choices is a message." % id)
	if weight <= 0:
		problems.append("%s: weight must be positive." % id)
	var acts := false
	for choice in choices:
		if choice.label_key == &"":
			problems.append("%s: a choice has no label." % id)
		if not choice.outcomes.is_empty():
			acts = true
	if not acts:
		problems.append("%s: no choice does anything." % id)
	return problems
