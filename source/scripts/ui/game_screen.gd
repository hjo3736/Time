class_name GameScreen
extends Control


signal title_requested
signal settings_requested

var rc: RunController

## The layout is the scene, which places every other view as an instance; this
## script wires them to the run and decides which one is showing.
const SCENE := preload("res://source/scenes/ui/game_screen.tscn")

@onready var _hud := %Hud as Hud
@onready var _menu := %TopMenu as TopMenu
@onready var _room := %RoomView as RoomView
@onready var _map := %MapView as MapView
@onready var _picker := %CardPicker as CardPicker
@onready var _pause := %PauseView as PauseView
@onready var _relic_view := %RelicView as RelicView

enum PickerJob { NONE, DECK, UPGRADE, REMOVE, DRAW, DISCARD, EXHAUST }
var _picker_job := PickerJob.NONE
@onready var _battle := %BattleView as BattleView
@onready var _choice := %ChoiceView as ChoiceView

var _balance: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase


## Always make one through here, never GameScreen.new(): new() is the script
## without the scene.
static func create() -> GameScreen:
	return SCENE.instantiate() as GameScreen


func _ready() -> void:
	_menu.map_requested.connect(_toggle_map)
	_menu.deck_requested.connect(_toggle_deck)
	_menu.relics_requested.connect(_toggle_relics)

	_room.move_requested.connect(_on_move)

	_battle.card_chosen.connect(_on_card)
	_battle.turn_ended.connect(_on_end_turn)
	_battle.pile_requested.connect(_on_pile)

	_choice.chosen.connect(_on_choice)

	_map.move_requested.connect(_on_map_move)
	_map.closed.connect(_close_map)

	_picker.picked.connect(_on_picked)
	_picker.cancelled.connect(_close_picker)

	_relic_view.closed.connect(_close_relics)

	_pause.closed.connect(_close_pause)
	_pause.resume_requested.connect(_close_pause)
	_pause.title_requested.connect(func() -> void:
		_close_pause()
		title_requested.emit())
	_pause.settings_requested.connect(func() -> void:
		_close_pause()
		settings_requested.emit())
	_pause.abandon_requested.connect(_abandon_run)

	_load_content()


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

	for problems in [_balance.validate(), _cards.validate(), _enemies.validate(),
			_encounters.validate(_enemies), _relics.validate()]:
		for line in problems:
			push_warning(line)


func start_run(seed_value: int) -> void:
	adopt(RunController.new(_balance, _cards, _enemies, _encounters, _relics, seed_value))


func adopt(controller: RunController) -> void:
	rc = controller
	refresh()


func refresh() -> void:
	_hud.refresh(rc)
	_persist()
	_menu.set_deck_count(rc.run.deck.size())
	_menu.set_relic_count(rc.run.relics.size())
	if _relic_view.visible:
		_relic_view.show_relics(rc.run, _relics)
	_room.visible = false
	_battle.visible = false
	_choice.visible = false
	if _map.visible:
		_map.show_map(rc)

	match rc.phase:
		RunController.Phase.EXPLORING:
			_room.visible = true
			_room.show_room(rc)
		RunController.Phase.BATTLE:
			_battle.visible = true
			_battle.show_battle(rc)
		RunController.Phase.REWARD:
			_choice.visible = true
			_show_reward()
		RunController.Phase.FIRE:
			_choice.visible = true
			_show_fire()
		RunController.Phase.SHOP:
			_choice.visible = true
			_show_shop()
		RunController.Phase.EVENT:
			_choice.visible = true
			_show_event()
		RunController.Phase.ACT_CLEARED:
			_choice.visible = true
			var cleared_body := tr("ui.act.cleared_body")
			var boss_gave := _relic_line("ui.act.relic_gained")
			if boss_gave != "":
				cleared_body = "%s\n%s" % [boss_gave, cleared_body]
			_choice.present(tr("ui.act.cleared").format({"n": rc.run.act}), cleared_body,
				[{"label": tr("ui.act.continue"), "id": "next_act"}])
		RunController.Phase.ENDED:
			_choice.visible = true
			_show_ending()


func _on_move(coord: Vector2i) -> void:
	rc.move_to(coord)
	refresh()


func _on_card(index: int, target: int) -> void:
	rc.play_card(index, target)
	refresh()


func _on_end_turn() -> void:
	rc.end_turn()
	refresh()


func _show_reward() -> void:
	var cards := []
	for i in rc.run.pending_reward().size():
		var card: CardData = _cards.get_card(rc.run.pending_reward()[i])
		cards.append({"card": card, "id": ["take", i]})
	var options := []
	options.append({"label": tr("ui.reward.skip"), "id": "skip"})
	var body := tr("ui.reward.body")
	var gained := _relic_line("ui.reward.relic_gained")
	if gained != "":
		body = "%s\n%s" % [gained, body]
	_choice.present(tr("ui.reward.title"), body, options, cards)


## The relic an elite or a boss just handed over, worded for the screen that is
## about to appear. Empty when the room gave none.
func _relic_line(key: String) -> String:
	if rc.last_relic == StringName():
		return ""
	var relic := _relics.get_relic(rc.last_relic)
	if relic == null:
		return ""
	return tr(key).format({"name": relic.display_name(), "text": relic.description()})


func _show_fire() -> void:
	var run := rc.run
	var convertible := run.clock.convertible_restored()
	var gain := run.clock.conversion_yield(convertible)
	var rest_span := RunClock.format_span(run.fire_cost_of(RunState.FireAction.REST))
	var upgrade_span := RunClock.format_span(run.fire_cost_of(RunState.FireAction.UPGRADE))
	# Anything taken here and the fire goes out on leaving, so the way out says so.
	var room := rc.current_room()
	var lit_out := room != null and not room.fire_used.is_empty()
	var options := [
		{
			"label": tr("ui.fire.rest"),
			"detail": tr("ui.fire.rest_detail").format(
				{"span": rest_span, "n": run.fire_heal_amount()}),
			"id": ["fire", RunState.FireAction.REST],
			"disabled": run.hp >= run.max_hp or not run.can_use_fire(RunState.FireAction.REST) \
				or rc.fire_action_used(RunState.FireAction.REST),
		},
		{
			"label": tr("ui.fire.upgrade"),
			"detail": tr("ui.fire.upgrade_detail").format({"span": upgrade_span}),
			"id": ["fire", RunState.FireAction.UPGRADE],
			"disabled": run.deck.is_empty() or not run.can_use_fire(RunState.FireAction.UPGRADE) \
				or rc.fire_action_used(RunState.FireAction.UPGRADE),
		},
		{
			"label": tr("ui.fire.convert"),
			"detail": tr("ui.fire.convert_detail").format({
				"a": RunClock.format_span(convertible),
				"b": RunClock.format_span(gain)}),
			"id": ["fire", RunState.FireAction.CONVERT],
			"disabled": convertible <= 0 or rc.fire_action_used(RunState.FireAction.CONVERT),
		},
		{
			"label": tr("ui.fire.done" if lit_out else "ui.fire.leave"),
			"detail": tr("ui.fire.done_detail" if lit_out else "ui.fire.leave_detail"),
			"id": "leave_fire",
		},
	]
	_choice.present(tr("ui.fire.title"), tr("ui.fire.body"), options)


func _show_shop() -> void:
	var cards := []
	var options := []
	for i in rc.shop.cards.size():
		var card: CardData = rc.shop.cards[i]
		cards.append({
			"card": card,
			"id": ["buy", i],
			"disabled": not rc.shop.can_afford_card(rc.run, i),
		})
		options.append({
			"label": tr("ui.shop.entry").format({
				"name": card.display_name(),
				"price": RunClock.format_span(rc.shop.prices[i])}),
			"id": ["buy", i],
			"disabled": not rc.shop.can_afford_card(rc.run, i),
		})
	if rc.shop.relic != null:
		options.append({
			"label": tr("ui.shop.relic").format({
				"name": rc.shop.relic.display_name(),
				"price": RunClock.format_span(rc.shop.relic_price)}),
			"detail": rc.shop.relic.description(),
			"id": "buy_relic",
			"disabled": not rc.shop.can_afford_relic(rc.run),
		})
	options.append({
		"label": tr("ui.shop.remove").format({
			"price": RunClock.format_span(rc.shop.removal_price(rc.run))}),
		"detail": tr("ui.shop.remove_detail"),
		"id": "remove",
		"disabled": not rc.shop.can_afford_removal(rc.run),
	})
	options.append({"label": tr("ui.shop.leave"), "id": "leave_shop"})
	_choice.present(tr("ui.shop.title"), tr("ui.shop.body"), options, cards)


func _show_ending() -> void:
	var ending := rc.ending()
	var outcome_key: String = {
		RunController.Outcome.FINISHED: "ui.end.finished",
		RunController.Outcome.FELL: "ui.end.fell",
		RunController.Outcome.RAN_OUT: "ui.end.ran_out",
	}.get(rc.outcome, "ui.end.other")
	var headline := tr(outcome_key)

	var body := tr("ui.end.body").format({
		"delivered": RunClock.format_span(int(ending["delivered"])),
		"kept": RunClock.format_span(int(ending["kept"])),
		"memories": int(ending["memories"]),
		"elapsed": RunClock.format_span(int(ending["elapsed"])),
	})
	_choice.present(headline, body, [
		{
			"label": tr("ui.end.restart"),
			"detail": tr("ui.end.restart_detail"),
			"id": "restart",
		},
		{
			"label": tr("ui.end.to_title"),
			"detail": tr("ui.end.to_title_detail"),
			"id": "to_title",
		},
	])


func _on_choice(id: Variant) -> void:
	if id is String:
		match id:
			"skip":
				rc.skip_reward()
			"leave_fire":
				rc.leave_fire()
			"leave_shop":
				rc.leave_shop()
			"buy_relic":
				rc.buy_relic()
			"remove":
				_open_picker(PickerJob.REMOVE)
				return
			"next_act":
				rc.advance_act()
			"restart":
				start_run(randi())
				return
			"to_title":
				title_requested.emit()
				return
	elif id is Array:
		match id[0]:
			"event":
				rc.choose_event(int(id[1]))
			"take":
				rc.take_reward(int(id[1]))
			"buy":
				rc.buy_card(int(id[1]))
			"fire":
				var action: int = id[1]
				if action == RunState.FireAction.UPGRADE:
					_open_picker(PickerJob.UPGRADE)
					return
				rc.use_fire(action)
	refresh()


func _toggle_map() -> void:
	if _map.visible:
		_close_map()
		return
	_close_relics()
	_map.visible = true
	_menu.set_map_open(true)
	_map.open(rc)


func _close_map() -> void:
	_map.visible = false
	_menu.set_map_open(false)


func _toggle_relics() -> void:
	if _relic_view.visible:
		_close_relics()
		return
	_close_map()
	_close_picker()
	_relic_view.visible = true
	_menu.set_relics_open(true)
	_relic_view.show_relics(rc.run, _relics)


func _close_relics() -> void:
	_relic_view.visible = false
	_menu.set_relics_open(false)


func _on_map_move(coord: Vector2i) -> void:
	_close_map()
	_on_move(coord)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match Keybinds.action_for_event(event):
		Keybinds.Action.PAUSE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		Keybinds.Action.MAP:
			_toggle_map()
			get_viewport().set_input_as_handled()
		Keybinds.Action.DECK:
			_toggle_deck()
			get_viewport().set_input_as_handled()
		Keybinds.Action.RELICS:
			_toggle_relics()
			get_viewport().set_input_as_handled()
		Keybinds.Action.END_TURN:
			if rc != null and rc.phase == RunController.Phase.BATTLE and not _pause.visible:
				_on_end_turn()
				get_viewport().set_input_as_handled()


func _on_pile(pile: int) -> void:
	if rc.battle == null:
		return
	match pile:
		BattleView.Pile.DRAW:
			_open_picker(PickerJob.DRAW)
		BattleView.Pile.DISCARD:
			_open_picker(PickerJob.DISCARD)
		BattleView.Pile.EXHAUST:
			_open_picker(PickerJob.EXHAUST)


func _picker_indices(job: PickerJob) -> Array:
	if rc.battle == null:
		return range(rc.run.deck.size())
	var piles := rc.battle.piles()
	match job:
		PickerJob.DRAW:
			var shown := Array(piles.draw)
			shown.sort()
			return shown
		PickerJob.DISCARD:
			return Array(piles.discard)
		PickerJob.EXHAUST:
			return Array(piles.exhausted)
	return range(rc.run.deck.size())


func _open_picker(job: PickerJob) -> void:
	_close_map()
	_close_relics()
	_picker_job = job
	var entries := []
	for i in _picker_indices(job):
		if i < 0 or i >= rc.run.deck.size():
			continue
		var entry: Dictionary = rc.run.deck[i]
		var card := _cards.get_card(entry["id"], int(entry.get("upgrades", 0)))
		if card == null:
			continue
		entries.append({
			"card": card,
			"index": i,
			"choosable": job == PickerJob.UPGRADE and card.can_upgrade() or job == PickerJob.REMOVE,
		})

	var slug: String = {
		PickerJob.DECK: "deck",
		PickerJob.UPGRADE: "upgrade",
		PickerJob.REMOVE: "remove",
		PickerJob.DRAW: "draw",
		PickerJob.DISCARD: "discard",
		PickerJob.EXHAUST: "exhaust",
	}.get(job, "deck")
	_picker.present(
		tr("ui.%s.title" % slug).format({"n": entries.size()}),
		tr("ui.%s.body" % slug),
		entries,
		tr("ui.%s.empty" % slug))

	_picker.visible = true
	_menu.set_deck_open(job == PickerJob.DECK)


func _close_picker() -> void:
	_picker.visible = false
	_picker_job = PickerJob.NONE
	_menu.set_deck_open(false)
	refresh()


func _on_picked(deck_index: int) -> void:
	match _picker_job:
		PickerJob.UPGRADE:
			rc.use_fire(RunState.FireAction.UPGRADE, deck_index)
		PickerJob.REMOVE:
			rc.buy_removal(deck_index)
	_close_picker()


func _toggle_deck() -> void:
	if _picker.visible and _picker_job == PickerJob.DECK:
		_close_picker()
		return
	_open_picker(PickerJob.DECK)


func _persist() -> void:
	if rc == null:
		return
	if rc.phase == RunController.Phase.ENDED:
		SaveGame.clear()
	else:
		SaveGame.save(rc)


func _toggle_pause() -> void:
	if _pause.visible:
		_close_pause()
		return
	_close_map()
	_pause.show_pause()
	_pause.visible = true


func _close_pause() -> void:
	_pause.visible = false


func _abandon_run() -> void:
	SaveGame.clear()
	rc = null
	_close_pause()
	title_requested.emit()


func _show_event() -> void:
	var e := rc.event
	if e == null:
		return
	var options := []
	for i in e.choices.size():
		var choice: EventChoice = e.choices[i]
		options.append({
			"label": choice.label(),
			"detail": choice.detail(),
			"id": ["event", i],
			"disabled": not choice.available(rc.run),
		})
	_choice.present(e.title(), e.body(), options)
