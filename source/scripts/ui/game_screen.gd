class_name GameScreen
extends Control


signal title_requested
signal settings_requested

var rc: RunController

var _hud: Hud
var _menu: TopMenu
var _room: RoomView
var _map: MapView
var _picker: CardPicker
var _pause: PauseView

enum PickerJob { NONE, DECK, UPGRADE, REMOVE, DRAW, DISCARD, EXHAUST }
var _picker_job := PickerJob.NONE
var _battle: BattleView
var _choice: ChoiceView
var _content: Control

var _balance: Balance
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _encounters: EncounterTable
var _relics: RelicDatabase


func _ready() -> void:
	theme = UiTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	column.add_child(top)

	_hud = Hud.new()
	_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_hud)

	_menu = TopMenu.new()
	_menu.map_requested.connect(_toggle_map)
	_menu.deck_requested.connect(_toggle_deck)
	top.add_child(_menu)

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_content)

	_room = RoomView.new()
	_room.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room.move_requested.connect(_on_move)
	_content.add_child(_room)

	_battle = BattleView.new()
	_battle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle.card_chosen.connect(_on_card)
	_battle.turn_ended.connect(_on_end_turn)
	_battle.pile_requested.connect(_on_pile)
	_content.add_child(_battle)

	_choice = ChoiceView.new()
	_choice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice.chosen.connect(_on_choice)
	_content.add_child(_choice)

	_map = MapView.new()
	_map.move_requested.connect(_on_map_move)
	_map.closed.connect(_close_map)
	_map.visible = false
	add_child(_map)

	_picker = CardPicker.new()
	_picker.picked.connect(_on_picked)
	_picker.cancelled.connect(_close_picker)
	_picker.visible = false
	add_child(_picker)

	_pause = PauseView.new()
	_pause.visible = false
	_pause.closed.connect(_close_pause)
	_pause.resume_requested.connect(_close_pause)
	_pause.title_requested.connect(func() -> void:
		_close_pause()
		title_requested.emit())
	_pause.settings_requested.connect(func() -> void:
		_close_pause()
		settings_requested.emit())
	_pause.abandon_requested.connect(_abandon_run)
	add_child(_pause)

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
			_choice.present(tr("ui.act.cleared").format({"n": rc.run.act}),
				tr("ui.act.cleared_body"),
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
	_choice.present(tr("ui.reward.title"), tr("ui.reward.body"), options, cards)


func _show_fire() -> void:
	var run := rc.run
	var convertible := run.clock.convertible_restored()
	var gain := run.clock.conversion_yield(convertible)
	var options := [
		{
			"label": tr("ui.fire.rest"),
			"detail": tr("ui.fire.rest_detail").format({"n": run.fire_heal_amount()}),
			"id": ["fire", RunState.FireAction.REST],
			"disabled": run.hp >= run.max_hp,
		},
		{
			"label": tr("ui.fire.upgrade"),
			"detail": tr("ui.fire.upgrade_detail"),
			"id": ["fire", RunState.FireAction.UPGRADE],
			"disabled": run.deck.is_empty(),
		},
		{
			"label": tr("ui.fire.convert"),
			"detail": tr("ui.fire.convert_detail").format({
				"a": RunClock.format_span(convertible),
				"b": RunClock.format_span(gain)}),
			"id": ["fire", RunState.FireAction.CONVERT],
			"disabled": convertible <= 0,
		},
		{
			"label": tr("ui.fire.leave"),
			"detail": tr("ui.fire.leave_detail"),
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
	_map.visible = true
	_menu.set_map_open(true)
	_map.open(rc)


func _close_map() -> void:
	_map.visible = false
	_menu.set_map_open(false)


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
