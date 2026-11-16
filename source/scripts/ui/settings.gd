class_name Settings
extends RefCounted


static var path := "user://settings.cfg"

const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

const CHROME := 40

const LOCALES := ["ko", "en"]

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

static var locale := "ko"
static var screen_mode := Mode.WINDOWED
static var window_size := Vector2i(1600, 900)

static var chosen := false


static func load_from() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	chosen = true
	if file.has_section_key("window", "mode"):
		var stored_mode := int(file.get_value("window", "mode", screen_mode))
		if stored_mode >= Mode.WINDOWED and stored_mode <= Mode.FULLSCREEN:
			screen_mode = stored_mode as Mode
	elif bool(file.get_value("window", "fullscreen", false)):
		screen_mode = Mode.BORDERLESS
	var stored_locale: String = file.get_value("language", "locale", locale)
	if LOCALES.has(stored_locale):
		locale = stored_locale
	var stored: Vector2i = file.get_value("window", "size", window_size)
	if SIZES.has(stored):
		window_size = stored


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("window", "mode", screen_mode)
	file.set_value("window", "size", window_size)
	file.set_value("language", "locale", locale)
	file.save(path)


static func apply() -> void:
	TranslationServer.set_locale(locale)
	if not chosen or DisplayServer.get_name() == "headless":
		return
	if screen_mode == Mode.BORDERLESS:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if screen_mode == Mode.FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	var was := DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	if was != DisplayServer.WINDOW_MODE_WINDOWED:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.process_frame
			await tree.process_frame

	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var fitted := Vector2i(
		mini(window_size.x, usable.size.x),
		mini(window_size.y, usable.size.y - CHROME))
	DisplayServer.window_set_size(fitted)

	var centred := usable.position + (usable.size - fitted) / 2
	centred.y = maxi(centred.y, usable.position.y + CHROME)
	centred.x = maxi(centred.x, usable.position.x)
	DisplayServer.window_set_position(centred)


static func set_screen_mode(value: int) -> void:
	if value < Mode.WINDOWED or value > Mode.FULLSCREEN:
		return
	screen_mode = value as Mode
	chosen = true
	save()
	apply()


static func set_window_size(value: Vector2i) -> void:
	if not SIZES.has(value):
		return
	window_size = value
	screen_mode = Mode.WINDOWED
	chosen = true
	save()
	apply()


static func set_locale(value: String) -> void:
	if not LOCALES.has(value):
		return
	locale = value
	chosen = true
	save()
	TranslationServer.set_locale(locale)
