class_name RootScreen
extends Control


## The title and the panels over it are the scene. The title is rebuilt on a
## language change and a run's screen is made fresh for each run, so those two
## are replaced from here rather than kept.
const SCENE := preload("res://source/scenes/main_scene.tscn")

var _title: TitleView
var _game: GameScreen
@onready var _compendium := %CompendiumView as CompendiumView
@onready var _settings := %SettingsView as SettingsView
@onready var _dates := %DateView as DateView

var _balance: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase


## Always make one through here, never RootScreen.new(): new() is the script
## without the scene.
static func create() -> RootScreen:
	return SCENE.instantiate() as RootScreen


## Before any child is ready: the views in the scene translate themselves in their
## own _ready, so the saved language has to be in force by then, or the title comes
## up in whatever language the machine started in.
func _enter_tree() -> void:
	Settings.load_from()
	Settings.apply()
	Keybinds.load_from()


func _ready() -> void:
	_load_content()

	_build_title()

	_compendium.closed.connect(func() -> void: _compendium.visible = false)

	_settings.closed.connect(func() -> void: _settings.visible = false)
	_settings.language_changed.connect(_on_language_changed)

	_dates.closed.connect(func() -> void: _dates.visible = false)
	_dates.chosen.connect(func(seed_value: int) -> void:
		_dates.visible = false
		begin(seed_value))

	get_viewport().size_changed.connect(_on_viewport_resized)


func _build_title() -> void:
	if _title == null:
		_title = $TitleView as TitleView
	else:
		var was_visible := _title.visible
		remove_child(_title)
		_title.queue_free()
		_title = TitleView.create()
		add_child(_title)
		move_child(_title, 0)
		_title.visible = was_visible
	_title.date_requested.connect(_open_dates)
	_title.continue_requested.connect(resume)
	_title.compendium_requested.connect(_open_compendium)
	_title.settings_requested.connect(_open_settings)
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
	_game = GameScreen.create()
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
