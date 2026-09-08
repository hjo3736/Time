class_name RootScreen
extends Control


var _title: TitleView
var _game: GameScreen
var _compendium: CompendiumView
var _settings: SettingsView
var _dates: DateView

var _balance: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_load_content()
	Settings.load_from()
	Settings.apply()
	Keybinds.load_from()

	_build_title()

	_compendium = CompendiumView.new()
	_compendium.visible = false
	_compendium.closed.connect(func() -> void: _compendium.visible = false)
	add_child(_compendium)

	_settings = SettingsView.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void: _settings.visible = false)
	_settings.language_changed.connect(_on_language_changed)
	add_child(_settings)

	_dates = DateView.new()
	_dates.visible = false
	_dates.closed.connect(func() -> void: _dates.visible = false)
	_dates.chosen.connect(func(seed_value: int) -> void:
		_dates.visible = false
		begin(seed_value))
	add_child(_dates)

	get_viewport().size_changed.connect(_on_viewport_resized)


func _build_title() -> void:
	var was_visible := _title == null or _title.visible
	if _title != null:
		remove_child(_title)
		_title.queue_free()
	_title = TitleView.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.date_requested.connect(_open_dates)
	_title.continue_requested.connect(resume)
	_title.compendium_requested.connect(_open_compendium)
	_title.settings_requested.connect(_open_settings)
	add_child(_title)
	move_child(_title, 0)
	_title.visible = was_visible
	_title.set_continue_available(SaveGame.has_save())


func _on_language_changed() -> void:
	_build_title()
	if _game == null:
		return
	var carried := _game.rc
	_show_game()
	if carried != null:
		_game.adopt(carried)
	if _settings != null and _settings.visible:
		move_child(_settings, get_child_count() - 1)
	if _compendium != null and _compendium.visible:
		move_child(_compendium, get_child_count() - 1)


func _on_viewport_resized() -> void:
	if _compendium != null and _compendium.visible:
		_compendium.show_all(_cards, _enemies, _relics)
	if _settings != null and _settings.visible:
		_settings.show_settings()
	if _game != null:
		_game.refresh()


func rolled_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return RunClock.seed_from_date(
		rng.randi_range(0, RunClock.YEAR_LIMIT), rng.randi_range(0, 99),
		rng.randi_range(0, 99), rng.randi_range(0, 23))


func _open_dates() -> void:
	_dates.open_on(rolled_seed())
	_dates.visible = true
	move_child(_dates, get_child_count() - 1)


func _open_compendium() -> void:
	_compendium.show_all(_cards, _enemies, _relics)
	_compendium.visible = true
	move_child(_compendium, get_child_count() - 1)


func _open_settings() -> void:
	_settings.show_settings()
	_settings.visible = true
	move_child(_settings, get_child_count() - 1)


func _load_content() -> void:
	_balance = Balance.default()
	_cards = CardDatabase.new()
	_cards.load_from()
	_enemies = EnemyDatabase.new()
	_enemies.load_from()
	_encounters = EncounterTable.new()
	_encounters.load_from()
	_relics = RelicDatabase.new()
	_relics.load_from()


func begin(seed_value: int) -> void:
	_show_game().start_run(seed_value)


func resume() -> void:
	var loaded := SaveGame.load_run(_balance, _cards, _enemies, _encounters, _relics)
	if loaded == null:
		_title.set_continue_available(false)
		_title.visible = true
		return
	_show_game().adopt(loaded)


func _show_game() -> GameScreen:
	_title.visible = false
	if _game != null:
		remove_child(_game)
		_game.queue_free()
	_game = GameScreen.new()
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game.title_requested.connect(show_title)
	_game.settings_requested.connect(_open_settings)
	add_child(_game)
	return _game


func show_title() -> void:
	if _game != null:
		remove_child(_game)
		_game.queue_free()
		_game = null
	_title.visible = true
	_title.set_continue_available(SaveGame.has_save())
