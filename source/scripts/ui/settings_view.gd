class_name SettingsView
extends OverlayView

signal language_changed

enum Tab { SCREEN, KEYS }

const TAB_KEYS := ["ui.settings.tab_screen", "ui.settings.tab_keys"]

var _tab := Tab.SCREEN
var _listening := -1


func show_settings() -> void:
	set_compact(true, OverlayView.SETTINGS_PLATE)
	_listening = -1
	_rebuild()


func _select(tab: int) -> void:
	_tab = tab
	_listening = -1
	_rebuild()


func _rebuild() -> void:
	heading(tr("ui.settings.title"))
	set_tabs(TAB_KEYS.map(func(k: String) -> String: return tr(k)), _tab, _select)
	clear_body()
	match _tab:
		Tab.SCREEN:
			_build_screen()
		Tab.KEYS:
			_build_keys()


func _build_screen() -> void:
	body().add_child(_row(tr("ui.settings.language"), [
		{"label": "한국어", "on": Settings.locale == "ko", "action": func() -> void:
			Settings.set_locale("ko")},
		{"label": "English", "on": Settings.locale == "en", "action": func() -> void:
			Settings.set_locale("en")},
	], true))

	var windowed := Settings.screen_mode == Settings.Mode.WINDOWED
	body().add_child(_row(tr("ui.settings.screen"), [
		{"label": tr("ui.settings.windowed"), "on": windowed,
			"action": func() -> void: Settings.set_screen_mode(Settings.Mode.WINDOWED)},
		{"label": tr("ui.settings.borderless"),
			"on": Settings.screen_mode == Settings.Mode.BORDERLESS,
			"action": func() -> void: Settings.set_screen_mode(Settings.Mode.BORDERLESS)},
		{"label": tr("ui.settings.fullscreen"),
			"on": Settings.screen_mode == Settings.Mode.FULLSCREEN,
			"action": func() -> void: Settings.set_screen_mode(Settings.Mode.FULLSCREEN)},
	]))

	var sizes := []
	for size in Settings.SIZES:
		sizes.append({
			"label": "%d × %d" % [size.x, size.y],
			"on": windowed and Settings.window_size == size,
			"disabled": not windowed,
			"action": func() -> void: Settings.set_window_size(size),
		})
	body().add_child(_row(tr("ui.settings.window_size"), sizes))

	body().add_child(UiTheme.label(tr("ui.settings.no_audio"), 16, UiTheme.INK_DIM))


func _build_keys() -> void:
	for action in Keybinds.ORDER:
		var frame := PanelContainer.new()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		frame.add_child(line)

		var label := UiTheme.label(tr(Keybinds.LABELS[action]), 20, UiTheme.INK)
		label.custom_minimum_size = Vector2(200, 0)
		line.add_child(label)

		var button := Button.new()
		button.text = tr("ui.keys.press") if _listening == action else Keybinds.name_of(action)
		button.custom_minimum_size = Vector2(240, 46)
		var chosen: int = action
		button.pressed.connect(func() -> void:
			_listening = chosen
			_rebuild())
		line.add_child(button)
		body().add_child(frame)

	var reset := Button.new()
	reset.text = tr("ui.keys.reset")
	reset.custom_minimum_size = Vector2(0, 46)
	reset.pressed.connect(func() -> void:
		Keybinds.reset_to_defaults()
		_listening = -1
		_rebuild())
	body().add_child(reset)


func _unhandled_input(event: InputEvent) -> void:
	if visible and _listening >= 0 and event is InputEventKey and event.pressed \
			and not event.echo:
		if Keybinds.is_modifier(event.keycode):
			return
		var captured := _listening
		_listening = -1
		if event.keycode != KEY_ESCAPE:
			Keybinds.bind(captured, event.get_keycode_with_modifiers())
		_rebuild()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _row(label: String, choices: Array, is_language := false) -> Control:
	var frame := PanelContainer.new()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	frame.add_child(line)

	var name_label := UiTheme.label(label, 20, UiTheme.INK)
	name_label.custom_minimum_size = Vector2(200, 0)
	line.add_child(name_label)

	for choice in choices:
		var button := Button.new()
		button.text = String(choice["label"])
		button.custom_minimum_size = Vector2(200, 46)
		button.disabled = bool(choice.get("disabled", false)) or bool(choice["on"])
		var action: Callable = choice["action"]
		button.pressed.connect(func() -> void:
			action.call()
			if is_language:
				language_changed.emit()
			_rebuild())
		line.add_child(button)
	return frame
