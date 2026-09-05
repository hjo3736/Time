class_name Keybinds
extends RefCounted

enum Action { END_TURN, MAP, DECK, PAUSE }

const ORDER := [Action.END_TURN, Action.MAP, Action.DECK, Action.PAUSE]

const LABELS := {
	Action.END_TURN: "ui.keys.end_turn",
	Action.MAP: "ui.keys.map",
	Action.DECK: "ui.keys.deck",
	Action.PAUSE: "ui.keys.pause",
}

const DEFAULTS := {
	Action.END_TURN: KEY_SPACE,
	Action.MAP: KEY_M,
	Action.DECK: KEY_D,
	Action.PAUSE: KEY_ESCAPE,
}

static var path := "user://keys.cfg"

static var _bound := {}


static func load_from() -> void:
	reset()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for action in ORDER:
		var stored := int(file.get_value("keys", str(action), _bound[action]))
		if stored != 0:
			_bound[action] = stored


static func save() -> void:
	var file := ConfigFile.new()
	for action in ORDER:
		file.set_value("keys", str(action), _bound[action])
	file.save(path)


static func reset() -> void:
	_bound = DEFAULTS.duplicate()


static func key_of(action: int) -> int:
	return int(_bound.get(action, DEFAULTS.get(action, 0)))


static func name_of(action: int) -> String:
	return OS.get_keycode_string(key_of(action))


static func action_for(combined: int) -> int:
	for action in ORDER:
		if key_of(action) == combined:
			return action
	return -1


static func action_for_event(event: InputEventKey) -> int:
	return action_for(event.get_keycode_with_modifiers())


static func is_modifier(keycode: int) -> bool:
	return keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META, KEY_CAPSLOCK]


static func bind(action: int, combined: int) -> void:
	if combined == 0 or not DEFAULTS.has(action):
		return
	if is_modifier(combined & KEY_CODE_MASK):
		return
	var held := action_for(combined)
	if held == action:
		return
	if held >= 0:
		_bound[held] = key_of(action)
	_bound[action] = combined
	save()


static func reset_to_defaults() -> void:
	reset()
	save()
