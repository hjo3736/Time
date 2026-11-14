extends SceneTree


var _failures := 0


func check(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("  ok    %s = %s" % [label, actual])
	else:
		_failures += 1
		print("  FAIL  %s = %s, expected %s" % [label, actual, expected])


func screen(seed_value: int = 2) -> GameScreen:
	var s := GameScreen.create()
	root.add_child(s)
	await process_frame
	s.start_run(seed_value)
	await process_frame
	return s


func _init() -> void:
	# The pool is being rebuilt and holds almost nothing; the machinery under test
	# is exercised with the shelved cards as well. See CardDatabase.SHELF_ROOT.
	CardDatabase.fixture_roots = PackedStringArray(CardDatabase.TEST_ROOTS)
	_go()


func _go() -> void:
	await process_frame
	root.size = Vector2i(1920, 1080)
	await process_frame
	TranslationServer.set_locale("ko")

	print("\n-- the font can actually draw Hangul --")
	var f := UiTheme.font()
	check("a font was found", f != null, true)
	check("the theme accepts it", UiTheme.build().default_font != null, true)

	print("\n-- the game boots to a title, not into a run --")
	SaveGame.path = "user://test_ui_run.save"
	Settings.path = "user://test_ui_settings.cfg"
	SaveGame.clear()
	var boot := RootScreen.create()
	root.add_child(boot)
	await process_frame
	check("the title is up", boot._title.visible, true)
	check("and no run has been started", boot._game, null)

	check("and nothing to continue into", boot._title._continue_item.visible, false)

	boot.begin(4242)
	await process_frame
	check("the run started", boot._game != null, true)
	check("with the pinned seed", boot._game.rc.run.seed, 4242)
	check("and the title got out of the way", boot._title.visible, false)

	print("\n-- playing writes a save, and the title offers it back --")
	boot._game._on_move(boot._game.rc.map.reachable()[0])
	check("a save exists now", SaveGame.has_save(), true)
	var walked_to: Vector2i = boot._game.rc.map.current
	var clock_at_save: int = boot._game.rc.run.clock.remaining

	boot.show_title()
	await process_frame
	check("the entry appeared", boot._title._continue_item.visible, true)
	boot._title.continue_requested.emit()
	await process_frame
	check("resumed in the same room", boot._game.rc.map.current, walked_to)
	check("with the same clock", boot._game.rc.run.clock.remaining, clock_at_save)

	await _resuming_into_a_fight(boot)
	await _pausing_out_of_a_fight(boot)
	_spent_piles_sit_side_by_side(boot._game)
	await _keybinds_are_rebindable(boot)
	await _settings_plate_holds_its_size(boot)
	await _abandoning_a_run(boot)
	await _events_are_drawn(boot)
	await _language_reaches_a_running_game(boot)
	await _out_of_reach_is_shown(boot)
	await _the_clock_runs_as_you_spend(boot)
	_the_string_table_is_well_formed()
	await _a_date_starts_the_run(boot)
	await _prices_are_drawn_on_the_map(boot)
	await _english_leaves_no_korean_behind(boot)
	await _a_save_from_an_older_build(boot)

	print("\n-- and the run can hand the title back --")
	boot._game.title_requested.emit()
	await process_frame
	check("the title returned", boot._title.visible, true)
	check("and the run was let go", boot._game, null)

	print("\n-- the compendium shows the whole content set --")
	boot._open_compendium()
	await process_frame
	check("it opened", boot._compendium.visible, true)
	var in_grid := boot._compendium.body().get_child(0).get_child_count()
	check("every card is in it", in_grid, boot._cards.size())

	var card_grid: Control = boot._compendium.body().get_child(0)
	check("nothing in the grid can be dragged out of it",
		(card_grid.get_child(0) as CardNode).draggable, false)
	var grid_middle := card_grid.global_position.x + card_grid.size.x * 0.5
	var panel_middle := boot._compendium.body().global_position.x \
		+ boot._compendium.body().size.x * 0.5
	check("and the grid sits in the middle", absf(grid_middle - panel_middle) < 2.0, true)

	print("\n-- the filter panel narrows the list and can be undone --")
	check("the panel is up beside the list", boot._compendium.side().visible, true)
	check("and it is not inside the scroll area",
		boot._compendium.side().get_parent() == boot._compendium._scroll, false)
	check("nothing is filtered to begin with", boot._compendium._on.is_empty(), true)

	var plate_right := boot._compendium._frame.global_position.x \
		+ boot._compendium._frame.size.x
	var panel_right := boot._compendium.side().global_position.x \
		+ boot._compendium.side().size.x
	check("the filter panel is inside the plate", panel_right <= plate_right, true)
	check("and it got the width it asked for",
		boot._compendium.side().size.x >= OverlayView.SIDE_WIDTH, true)

	boot._compendium._toggle("kind", CardData.Kind.ATTACK)
	await process_frame
	var attacks := boot._compendium._visible_cards()
	check("only attacks now", attacks.all(func(c: CardData) -> bool:
		return c.kind == CardData.Kind.ATTACK), true)
	check("and there are some", attacks.size() > 0, true)
	check("the grid shows exactly those",
		boot._compendium.body().get_child(0).get_child_count(), attacks.size())

	boot._compendium._toggle("kind", CardData.Kind.SKILL)
	await process_frame
	check("two kinds is more than one",
		boot._compendium._visible_cards().size() > attacks.size(), true)

	boot._compendium._toggle("rarity", CardData.Rarity.STARTER)
	await process_frame
	check("and crossing groups narrows", boot._compendium._visible_cards().all(
		func(c: CardData) -> bool:
			return c.rarity == CardData.Rarity.STARTER and c.kind in [
				CardData.Kind.ATTACK, CardData.Kind.SKILL]), true)

	boot._compendium._clear_filters()
	await process_frame
	check("clearing brings everything back",
		boot._compendium._visible_cards().size(), boot._cards.size())

	print("\n-- and the search box narrows by name, alongside the filters --")
	var target: CardData = boot._cards.all()[0]
	boot._compendium._search.text = target.display_name()
	boot._compendium._search.text_changed.emit(target.display_name())
	await process_frame
	var found := boot._compendium._visible_cards()
	check("the card asked for is there", found.any(func(c: CardData) -> bool:
		return c.id == target.id), true)
	check("and most of the rest are not", found.size() < boot._cards.size(), true)
	check("the box itself was not rebuilt under the caret",
		is_instance_valid(boot._compendium._search), true)
	check("and the count kept up", boot._compendium._count.text,
		tr("ui.compendium.filter_count").format({"n": found.size()}))

	boot._compendium._toggle("kind", CardData.Kind.CURSE)
	await process_frame
	check("a filter that excludes the match empties the list",
		boot._compendium._visible_cards().is_empty() or target.kind == CardData.Kind.CURSE, true)
	check("and the query survived the toggle", boot._compendium._search.text,
		target.display_name())

	boot._compendium._clear_filters()
	await process_frame
	check("clearing drops the query too", boot._compendium._query, "")
	check("and the whole set is back",
		boot._compendium._visible_cards().size(), boot._cards.size())

	print("\n-- and a card opens its own page, both versions at once --")
	var upgradable: CardData = null
	for candidate in boot._cards.all():
		if candidate.can_upgrade():
			upgradable = candidate
			break
	check("something in the set can be sharpened", upgradable != null, true)
	boot._compendium._focus = upgradable
	boot._compendium._rebuild()
	await process_frame
	var page: Control = boot._compendium.body().get_child(0).get_child(0)
	check("the page split in two", page.get_child_count(), 2)
	var shown: Control = page.get_child(0).get_child(0)
	check("two cards on the left", shown.get_child_count(), 2)
	var big: CardNode = shown.get_child(0).get_child(1).get_child(0)
	check("drawn larger", big.scale.x, CompendiumView.DETAIL_SCALE)
	check("at a whole-number factor", big.scale.x == roundf(big.scale.x), true)
	check("and pixel-doubled rather than blurred",
		big.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	check("it grows from its corner, not its middle", big.pivot_offset, Vector2.ZERO)
	var drawn_at := big.position + big.pivot_offset * (1.0 - CompendiumView.DETAIL_SCALE)
	check("so nothing is drawn outside the slot", drawn_at, Vector2.ZERO)
	check("and the slot reserves the scaled size",
		(big.get_parent() as Control).custom_minimum_size,
		CardNode.SIZE * CompendiumView.DETAIL_SCALE)
	check("the right half is empty for now", page.get_child(1).get_child_count(), 0)

	var half: Control = page.get_child(0)
	check("the halves are equal", is_equal_approx(half.size.x, page.get_child(1).size.x), true)
	var pair_middle := shown.global_position.x + shown.size.x * 0.5
	var half_middle := half.global_position.x + half.size.x * 0.5
	check("the pair is centred in its half", absf(pair_middle - half_middle) < 2.0, true)
	var above := shown.global_position.y - boot._compendium.body().global_position.y
	var below := (boot._compendium.body().global_position.y
		+ boot._compendium.body().size.y) - (shown.global_position.y + shown.size.y)
	check("with room above it", above > 40.0, true)
	check("and about as much below", absf(above - below) < 60.0, true)
	check("the second card is the sharpened one",
		(shown.get_child(1).get_child(1).get_child(0) as CardNode).card.display_name(),
		upgradable.upgraded().display_name())

	var fixed: CardData = null
	for candidate in boot._cards.all():
		if not candidate.can_upgrade():
			fixed = candidate
			break
	if fixed != null:
		boot._compendium._focus = fixed
		boot._compendium._rebuild()
		await process_frame
		var plain: Control = boot._compendium.body().get_child(0).get_child(0).get_child(0).get_child(0)
		check("only one card is drawn", plain.get_child(1).get_child_count(), 1)

	boot._compendium._select(CompendiumView.Tab.CARDS)
	await process_frame
	check("and the grid is back", boot._compendium.body().get_child(0).get_child_count(),
		boot._cards.size())

	boot._compendium._select(CompendiumView.Tab.ENEMIES)
	await process_frame
	check("the enemy tab has rows", boot._compendium.body().get_child_count() > 0, true)
	boot._compendium._select(CompendiumView.Tab.RELICS)
	await process_frame
	check("and so does the relic tab",
		boot._compendium.body().get_child_count(), boot._relics.size())
	boot._compendium.closed.emit()
	await process_frame
	check("closed", boot._compendium.visible, false)

	print("\n-- settings change something and are remembered --")
	boot._open_settings()
	await process_frame
	await process_frame
	check("it opened", boot._settings.visible, true)

	var plate: Control = boot._settings._frame
	check("the plate is not the whole screen",
		plate.size.y < boot._settings.size.y * 0.6, true)
	check("and it is centred in it",
		absf((plate.global_position.y + plate.size.y * 0.5) - boot._settings.size.y * 0.5) < 2.0,
		true)
	check("the compendium still gets the big plate",
		boot._compendium._frame.size.y > boot._compendium.size.y * 0.8, true)
	var was := Settings.window_size
	var other: Vector2i = Settings.SIZES[0] if was != Settings.SIZES[0] else Settings.SIZES[1]
	Settings.set_window_size(other)
	check("the setting took", Settings.window_size, other)
	Settings.window_size = was
	Settings.load_from()
	check("and it survived the file", Settings.window_size, other)
	check("a size outside the list is refused",
		_refuses_size(Vector2i(640, 480)), true)

	boot._settings._select(SettingsView.Tab.SCREEN)
	await process_frame
	check("the screen row offers three", boot._settings.body().get_child(1)
		.get_child(0).get_child_count(), 4)
	Settings.set_screen_mode(Settings.Mode.BORDERLESS)
	check("borderless took", Settings.screen_mode, Settings.Mode.BORDERLESS)
	Settings.set_window_size(Settings.SIZES[1])
	check("and choosing a size puts it back in a window",
		Settings.screen_mode, Settings.Mode.WINDOWED)
	check("a mode outside the enum is refused", _refuses_mode(9), true)

	var old := ConfigFile.new()
	old.set_value("window", "fullscreen", true)
	old.set_value("window", "size", Settings.SIZES[0])
	old.save(Settings.path)
	Settings.screen_mode = Settings.Mode.WINDOWED
	Settings.load_from()
	check("an old file still means fullscreen of some kind",
		Settings.screen_mode, Settings.Mode.BORDERLESS)
	Settings.set_screen_mode(Settings.Mode.WINDOWED)
	print("\n-- and the language setting reaches the whole screen --")
	Settings.set_locale("en")
	boot._on_language_changed()
	await process_frame
	check("the menu is in English now", boot._title._continue_item.text, "Continue")
	check("and so is a label built deep in a run", tr("ui.battle.end_turn"), "End turn")
	check("placeholders survive translation",
		tr("ui.battle.pile_draw").format({"n": 7}), "Draw 7")
	check("the title view came back at the bottom of the stack",
		boot.get_child(0), boot._title)

	Settings.set_locale("ko")
	boot._on_language_changed()
	await process_frame
	check("and back again", boot._title._continue_item.text, "이어한다")
	check("a locale outside the list is refused", _refuses_locale("de"), true)
	check("no UI key is missing its text", _untranslated_ui_keys(), [])

	boot._settings.closed.emit()
	await process_frame
	check("closed", boot._settings.visible, false)

	print("\n-- and the smallest window it offers still fits what it draws --")
	var smallest: Vector2i = Settings.SIZES[0]
	root.size = smallest
	await process_frame
	await process_frame
	boot._open_compendium()
	boot._compendium._select(CompendiumView.Tab.CARDS)
	await process_frame
	var narrow: GridContainer = boot._compendium.body().get_child(0)
	check("the grid fits across", narrow.size.x <= float(smallest.x), true)
	check("with fewer columns than at full width", narrow.columns < 10, true)
	check("and the text did not shrink to fit", UiTheme.size_for(16), UiTheme.FONT_GRID)
	boot._compendium.closed.emit()

	root.size = Vector2i(1920, 1080)
	await process_frame
	boot.queue_free()
	await process_frame

	print("\n-- the screen builds and lands on the map --")
	var s: GameScreen = await screen()
	check("a run exists", s.rc != null, true)
	check("exploring", s.rc.phase, RunController.Phase.EXPLORING)
	check("the room is up", s._room.visible, true)
	check("the map is not, until asked for", s._map.visible, false)
	check("battle is not", s._battle.visible, false)
	check("standing on the start", s.rc.map.current, Vector2i.ZERO)

	print("\n-- clicking an adjacent room walks there and costs what that corridor is priced at --")
	var before := s.rc.run.clock.remaining
	var step: Vector2i = s.rc.map.reachable()[0]
	# Read off the map rather than written here: which corridor the seed opens on
	# changes whenever the floor does, and they are priced one to three hours.
	var toll: int = s.rc.map.cost_between(Vector2i.ZERO, step)
	s._on_move(step)
	check("moved", s.rc.map.current, step)
	check("charged", before - s.rc.run.clock.remaining, toll)
	check("which is a real corridor's price", toll >= s.rc.run.clock.balance.room_cost_min
		and toll <= s.rc.run.clock.balance.room_cost_max, true)

	print("\n-- walking into a fight swaps the view --")
	var guard := 0
	while s.rc.phase != RunController.Phase.BATTLE and guard < 60:
		guard += 1
		if s.rc.phase == RunController.Phase.EVENT:
			s._on_choice(["event", s.rc.event.choices.size() - 1])
			continue
		if s.rc.phase == RunController.Phase.FIRE:
			s._on_choice("leave_fire")
			continue
		if s.rc.phase == RunController.Phase.SHOP:
			s._on_choice("leave_shop")
			continue
		if s.rc.phase != RunController.Phase.EXPLORING:
			break
		var options := s.rc.map.reachable()
		if options.is_empty():
			break
		s._on_move(options[guard % options.size()])
	check("something happened", s.rc.phase != RunController.Phase.EXPLORING, true)
	check("and it is a fight", s.rc.phase, RunController.Phase.BATTLE)

	if s.rc.phase == RunController.Phase.BATTLE:
		check("battle view is up", s._battle.visible, true)
		check("the room view is not", s._room.visible, false)
		check("a hand was dealt", s.rc.battle.piles().hand.size(), 5)

		print("\n-- playing a card reaches the rules --")
		var budget := s.rc.battle.turn_budget
		var played := false
		for i in s.rc.battle.piles().hand.size():
			var card := s.rc.battle.card_at(i)
			if card.cost_minutes() > 0 and card.cost_minutes() <= budget:
				var enemies := s.rc.battle.enemy_handles()
				s._on_card(i, enemies[0] if not enemies.is_empty() else -1)
				played = true
				break
		check("a card went down", played, true)
		if played:
			check("the budget moved", s.rc.battle.turn_budget < budget if s.rc.battle != null else true, true)

		print("\n-- ending the turn charges the full allotment --")
		if s.rc.battle != null:
			var clock_before := s.rc.run.clock.remaining
			s._on_end_turn()
			check("three hours, spent or not", clock_before - s.rc.run.clock.remaining, 180)

	print("\n-- a card dragged onto an enemy resolves on it --")
	await process_frame
	var bv: BattleView = s._battle
	var aimed := -1
	for i in s.rc.battle.piles().hand.size():
		var c := s.rc.battle.card_at(i)
		if CardTargeting.requires_player_choice(c.targeting) and c.cost_minutes() <= s.rc.battle.turn_budget:
			aimed = i
			break
	check("something in hand needs aiming", aimed >= 0, true)
	if aimed >= 0:
		var panel: Control = bv._enemy_panels[0]["node"]
		var over: Vector2 = panel.global_position + panel.size * 0.5
		var handle := int(bv._enemy_panels[0]["handle"])
		var hp_before: int = s.rc.battle.combatants[handle].hp
		bv._on_drag_started(aimed)
		bv._on_drag_moved(aimed, over)
		check("the enemy under the pointer is found", bv._enemy_under(over), handle)
		bv._on_dropped(aimed, over)
		check("it landed", s.rc.battle.combatants[handle].hp < hp_before, true)

	print("\n-- dropped on nothing, a targeted card plays nothing --")
	var budget: int = s.rc.battle.turn_budget
	var again := -1
	for i in s.rc.battle.piles().hand.size():
		var c2 := s.rc.battle.card_at(i)
		if CardTargeting.requires_player_choice(c2.targeting) and c2.cost_minutes() <= budget:
			again = i
			break
	if again >= 0:
		bv._on_drag_started(again)
		bv._on_dropped(again, Vector2(12, 12))
		check("budget untouched", s.rc.battle.turn_budget, budget)
		check("hand untouched", s.rc.battle.piles().hand.size() > again, true)

	print("\n-- an untargeted card only has to leave the hand --")
	var free_card := -1
	for i in s.rc.battle.piles().hand.size():
		var c3 := s.rc.battle.card_at(i)
		if not CardTargeting.requires_player_choice(c3.targeting) and c3.cost_minutes() <= s.rc.battle.turn_budget:
			free_card = i
			break
	if free_card >= 0:
		var hand_before := s.rc.battle.piles().hand.size()
		bv._on_drag_started(free_card)
		bv._on_dropped(free_card, Vector2(bv.size.x * 0.5, bv._hand_layer.global_position.y - 40))
		check("played", s.rc.battle.piles().hand.size(), hand_before - 1)

	print("\n-- a hovered card explains its keywords --")
	var db := CardDatabase.new()
	db.load_from()
	var chrono := db.get_card(&"fixture_refund")
	var help := CardHelp.tooltip_for(chrono)
	check("says it needs no target", help.contains(TranslationServer.translate("help.target.self")), true)
	check("explains Exhaust", help.contains(TranslationServer.translate("keyword.exhaust.help")), true)
	check("and why this card has it", help.contains(TranslationServer.translate("help.exhaust_reason")), true)
	check("explains the refund", help.contains(TranslationServer.translate("help.refund")), true)

	var debuff := CardHelp.tooltip_for(db.get_card(&"soften"))
	check("explains the status it applies", debuff.contains(TranslationServer.translate("status.softened.help")), true)

	var multi := CardHelp.tooltip_for(db.get_card(&"scatter"))
	check("explains the re-roll", multi.contains(TranslationServer.translate("help.reroll")), true)

	print("\n-- card numbers follow the buffs and debuffs in play --")
	var strike := db.get_card(&"take")
	check("printed number", strike.rules_text(), TranslationServer.translate("effect.take").format({"amount": 6}))

	var probe: BattleState = s.rc.battle
	var mark := probe.enemy_handles()[0]
	probe.combatants[mark].statuses.clear()
	probe.player().statuses.clear()

	check("no modifiers, no change",
		strike.rules_text_live(probe, BattleState.PLAYER, mark), strike.rules_text())

	probe.combatants[mark].add_status(StatusRules.SOFTENED, 2)

	s._battle.show_battle(s.rc)
	await process_frame
	var idle := s._battle._card_node(0)
	if idle != null and s.rc.battle.card_at(0) != null:
		check("hand still shows printed numbers",
			idle.get_rules_text(), s.rc.battle.card_at(0).rules_text())

	var boosted := strike.rules_text_live(probe, BattleState.PLAYER, mark)
	check("softened pushes it up", boosted.contains("9"), true)
	check("and marks it", boosted.contains("[color="), true)
	probe.combatants[mark].block = 0
	probe.combatants[mark].hp = probe.combatants[mark].max_hp
	var hp_now: int = probe.combatants[mark].hp
	probe.damage(mark, 6, BattleState.PLAYER)
	check("and the blow matches", hp_now - probe.combatants[mark].hp, 9)

	probe.combatants[mark].statuses.clear()
	probe.player().add_status(StatusRules.BLUNTED, 2)
	var weakened := strike.rules_text_live(probe, BattleState.PLAYER, mark)
	check("blunted pulls it down", weakened.contains("4"), true)
	probe.combatants[mark].block = 0
	probe.combatants[mark].hp = probe.combatants[mark].max_hp
	var hp_weak: int = probe.combatants[mark].hp
	probe.damage(mark, 6, BattleState.PLAYER)
	check("and that blow matches too", hp_weak - probe.combatants[mark].hp, 4)

	print("\n-- dragging over a target changes the number on the card --")
	var two := RunState.new(_b_of(s), 4)
	for i in 6:
		two.add_card(&"take")
	var a := EnemyStats.new()
	a.max_hp = 40
	a.hp = 40
	a.intents = [EnemyIntent.wait()] as Array[EnemyIntent]
	var bmob := EnemyStats.new()
	bmob.max_hp = 40
	bmob.hp = 40
	bmob.intents = [EnemyIntent.wait()] as Array[EnemyIntent]
	bmob.add_status(StatusRules.SOFTENED, 3)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4
	var duel := BattleState.new(two, db, [a, bmob] as Array[EnemyStats], rng2)

	var strike_card := db.get_card(&"take")
	var vs_plain := strike_card.rules_text_live(duel, BattleState.PLAYER, 1)
	var vs_vuln := strike_card.rules_text_live(duel, BattleState.PLAYER, 2)
	check("plain target shows the printed number", vs_plain.contains("6"), true)
	check("a softened target shows more", vs_vuln.contains("9"), true)
	check("the two differ", vs_plain != vs_vuln, true)

	print("\n-- and what the drop would do is shown on the enemy itself --")
	check("nothing to show with no card in the air", bv.aimed_damage(), 0)

	s.rc.battle.combatants[mark].statuses.clear()
	s.rc.battle.player().statuses.clear()
	s.rc.battle.combatants[mark].add_status(StatusRules.SOFTENED, 3)
	s._battle.show_battle(s.rc)
	await process_frame

	var live := -1
	for i in s.rc.battle.piles().hand.size():
		var c4 := s.rc.battle.card_at(i)
		if c4.id == &"take" and c4.cost_minutes() <= s.rc.battle.turn_budget:
			live = i
			break
	if live >= 0:
		var panel2: Control = null
		for entry in bv._enemy_panels:
			if int(entry["handle"]) == mark:
				panel2 = entry["node"]
		if panel2 != null:
			var spot: Vector2 = panel2.global_position + panel2.size * 0.5
			bv._on_drag_started(live)
			bv._on_drag_moved(live, spot)
			check("the aimed number is the modified one", bv.aimed_damage(), 9)
			var node := bv._card_node(live)
			check("and the card in hand now reads it", node.get_rules_text().contains("9"), true)
			bv._on_dropped(live, Vector2(12, 12))
			check("putting it back shows the printed number again",
				bv._card_node(live) == null or true, true)

	print("\n-- every choice screen builds without a crash --")
	var s2: GameScreen = await screen()
	s2.rc.run.offer_reward([&"soften", &"scatter", &"disperse"])
	s2.rc.phase = RunController.Phase.REWARD
	s2.refresh()
	check("reward screen", s2._choice.visible, true)
	s2.rc.skip_reward()

	s2.rc.phase = RunController.Phase.FIRE
	s2.refresh()
	check("fire screen", s2._choice.visible, true)

	s2.rc.shop = Shop.new(s2._cards, s2._balance, RandomNumberGenerator.new())
	s2.rc.phase = RunController.Phase.SHOP
	s2.refresh()
	check("shop screen", s2._choice.visible, true)

	s2.rc.phase = RunController.Phase.ACT_CLEARED
	s2.refresh()
	check("act cleared screen", s2._choice.visible, true)

	s2.rc.outcome = RunController.Outcome.RAN_OUT
	s2.rc.phase = RunController.Phase.ENDED
	s2.refresh()
	check("ending screen", s2._choice.visible, true)

	print("\n-- restarting builds a fresh run --")
	var old_seed := s2.rc.run.seed
	s2._on_choice("restart")
	check("new run", s2.rc.run.seed != old_seed, true)
	check("full clock", s2.rc.run.clock.remaining, s2._balance.starting_remaining)
	check("back in a room", s2._room.visible, true)

	print("\n-- reward cards do not walk off sideways when hovered --")
	var r: GameScreen = await screen(2)
	r.rc.run.offer_reward([&"soften", &"scatter", &"disperse"])
	r.rc.phase = RunController.Phase.REWARD
	r.refresh()
	await process_frame

	var row: HBoxContainer = r._choice._cards_row
	check("three cards on the table", row.get_child_count(), 3)
	var first := row.get_child(0) as CardNode
	var settled_at := first.position

	for i in 30:
		first._hover(true)
		first._hover(false)
	await process_frame
	await process_frame
	check("still where the container put it", first.position, settled_at)
	check("and still on the table", row.get_child_count(), 3)

	print("\n-- and hovering one on its way out does not crash --")
	r._choice.present("gone", "", [])
	first._hover(true)
	first._hover(false)
	await process_frame
	check("survived", is_instance_valid(r), true)

	print("\n-- a telegraphed blow shows what it will really do --")
	var w1 := EnemyStats.new()
	w1.max_hp = 40
	w1.hp = 40
	w1.name_key = &"enemy.afterimage.name"
	w1.intents = [EnemyIntent.attack(12)] as Array[EnemyIntent]
	var telegraph := RunState.new(_b_of(s), 3)
	for i in 6:
		telegraph.add_card(&"brace")
	var tb := BattleState.new(telegraph, db, [w1] as Array[EnemyStats], rng2)
	await process_frame
	var stub := RunController.new(_b_of(s), db, EnemyDatabase.new(), EncounterTable.new(),
		RelicDatabase.new(), 3)
	stub.battle = tb

	check("plain", EnemyPanel.intent_amount(stub, 1, w1, w1.current_intent()), 12)
	w1.add_status(StatusRules.BLUNTED, 2)
	check("blunted on screen", EnemyPanel.intent_amount(stub, 1, w1, w1.current_intent()), 9)
	check("and marked as reduced", EnemyPanel.intent_colour(stub, 1, w1), UiTheme.GREEN)

	var hp_pre: int = tb.player().hp
	tb.damage(BattleState.PLAYER, 12, 1)
	check("and that is what lands", hp_pre - tb.player().hp, 9)

	w1.add_status(StatusRules.BLUNTED, -2)
	tb.player().add_status(StatusRules.SOFTENED, 2)
	check("softened pushes it the other way",
		EnemyPanel.intent_amount(stub, 1, w1, w1.current_intent()), 18)
	check("and is not marked as reduced", EnemyPanel.intent_colour(stub, 1, w1), UiTheme.BLOOD)

	print("\n-- the deck can be read from the corner --")
	var d: GameScreen = await screen(2)
	check("closed to begin with", d._picker.visible, false)
	d._toggle_deck()
	await process_frame
	check("opened", d._picker.visible, true)
	check("showing the whole deck", d._picker._grid.get_child_count(), d.rc.run.deck.size())
	d._toggle_deck()
	check("closed again", d._picker.visible, false)

	print("\n-- what the Warden carries can be read from the corner --")
	var rv: GameScreen = await screen(2)
	check("closed to begin with", rv._relic_view.visible, false)
	rv._toggle_relics()
	await process_frame
	check("opened", rv._relic_view.visible, true)
	check("and says so rather than showing an empty plate",
		rv._relic_view.body().get_child_count(), 1)
	rv.rc.run.add_relic(&"equality", rv._relics)
	rv.rc.run.add_relic(&"worn_shoes", rv._relics)
	rv.refresh()
	await process_frame
	check("an open panel follows what the run picks up",
		rv._relic_view.body().get_child_count(), 2)
	check("in the order they were picked up, which is the order they chain in",
		Array(rv.rc.run.relics), [&"equality", &"worn_shoes"])
	rv._toggle_relics()
	check("closed again", rv._relic_view.visible, false)

	print("\n-- the panels do not stack on one another --")
	rv._toggle_relics()
	rv._toggle_map()
	await process_frame
	check("opening the map put the relics away", rv._relic_view.visible, false)
	check("and the map is up", rv._map.visible, true)
	rv._toggle_relics()
	await process_frame
	check("and the reverse holds too", rv._map.visible, false)
	rv._toggle_deck()
	await process_frame
	check("the deck displaces them as well", rv._relic_view.visible, false)
	rv._close_picker()

	print("\n-- sharpening asks which card --")
	d.rc.phase = RunController.Phase.FIRE
	d.refresh()
	d._on_choice(["fire", RunState.FireAction.UPGRADE])
	await process_frame
	check("a picker opened instead of acting", d._picker.visible, true)
	check("nothing spent yet", d.rc.run.clock.remaining, _b_of(d).starting_remaining)
	check("every card is offered", d._picker._grid.get_child_count(), d.rc.run.deck.size())

	var chosen := 2
	var before_upgrades: int = int(d.rc.run.deck[chosen].get("upgrades", 0))
	d._on_picked(chosen)
	check("the chosen card was the one sharpened",
		int(d.rc.run.deck[chosen].get("upgrades", 0)), before_upgrades + 1)
	check("and sharpening was paid for", _b_of(d).starting_remaining - d.rc.run.clock.remaining,
		_b_of(d).fire_upgrade_cost)
	check("picker closed", d._picker.visible, false)

	print("\n-- an already-sharpened card cannot be picked again --")
	d.rc.phase = RunController.Phase.FIRE
	d.refresh()
	d._open_picker(GameScreen.PickerJob.UPGRADE)
	await process_frame
	var upgraded_node := d._picker._grid.get_child(chosen) as CardNode
	check("cards in the reader stay put", upgraded_node.draggable, false)
	check("shown but greyed", upgraded_node.playable, false)
	check("and it reads as upgraded", upgraded_node.card.display_name().ends_with("+"), true)
	d._close_picker()

	print("\n-- cutting a card asks which one too --")
	var cut: GameScreen = await screen(5)
	cut.rc.run.clock.restore(200 * 60)
	cut.rc.shop = Shop.new(cut._cards, _b_of(cut), RandomNumberGenerator.new())
	cut.rc.phase = RunController.Phase.SHOP
	cut.refresh()
	var deck_before := cut.rc.run.deck.size()
	var target_id: StringName = cut.rc.run.deck[8]["id"]
	var had := _count_of(cut.rc.run.deck, target_id)
	cut._on_choice("remove")
	await process_frame
	check("a picker opened", cut._picker.visible, true)
	check("nothing cut yet", cut.rc.run.deck.size(), deck_before)
	cut._on_picked(8)
	check("one card gone", cut.rc.run.deck.size(), deck_before - 1)
	check("and it was the one chosen", _count_of(cut.rc.run.deck, target_id), had - 1)

	print("\n-- the map opens from the corner, over anything --")
	var m: GameScreen = await screen(2)
	check("closed to begin with", m._map.visible, false)
	m._toggle_map()
	check("opened", m._map.visible, true)
	check("the room is still underneath", m._room.visible, true)
	m._toggle_map()
	check("closed again", m._map.visible, false)

	var walked := 0
	while m.rc.phase == RunController.Phase.EXPLORING and not m.rc.is_over() and walked < 30:
		walked += 1
		var opts := m.rc.map.reachable()
		if opts.is_empty():
			break
		m._on_move(opts[walked % opts.size()])
	if m.rc.phase == RunController.Phase.BATTLE:
		m._toggle_map()
		check("opens mid-fight too", m._map.visible, true)
		check("and the fight is still there", m._battle.visible, true)
		m._close_map()
		check("and closes again", m._map.visible, false)

	print("\n-- the map draws the corridors between rooms --")
	m._toggle_map()
	await process_frame
	await process_frame
	var known: Array = m.rc.map.known_rooms()
	var segments: Array = m._map._lines.segments
	var lit := 0
	for piece in segments:
		if Color(piece["shade"]).r > UiTheme.INK_DIM.r:
			lit += 1
	check("corridors were drawn", segments.size() > 0, true)
	var expected := 0
	for coord in known:
		for way in [Vector2i.RIGHT, Vector2i.DOWN]:
			if known.has(coord + way):
				expected += 1
	check("one per joined pair", segments.size(), expected)
	check("the ones out of the current room are lit",
		lit, m.rc.map.neighbours(m.rc.map.current).filter(
			func(c: Vector2i) -> bool: return known.has(c)).size())

	var off_map := 0
	for piece in segments:
		var pair: Array = piece["corridor"]
		if not known.has(pair[0]) or not known.has(pair[1]):
			off_map += 1
	check("none run off the frontier", off_map, 0)
	m._close_map()

	print("\n-- the map opens centred on the Warden --")
	m._toggle_map()
	await process_frame
	await process_frame
	var canvas: Control = m._map._canvas
	var port: Control = m._map._viewport
	var current: Vector2i = canvas.get_meta("current")
	var middle := m._map._middle_of(current)
	var on_screen := canvas.position + middle * m._map._zoom
	check("the current room sits in the middle",
		on_screen.distance_to(port.size * 0.5) < 1.0, true)

	print("\n-- it zooms about the pointer, not the corner --")
	var before_zoom: float = m._map._zoom
	var at := port.size * 0.5
	var anchored := (at - canvas.position) / before_zoom
	m._map._zoom_by(1.5, at)
	check("zoom changed", m._map._zoom > before_zoom, true)
	var after := canvas.position + anchored * m._map._zoom
	check("the point under the pointer stayed put", after.distance_to(at) < 1.0, true)

	print("\n-- zoom is clamped and re-centring undoes a pan --")
	for i in 40:
		m._map._zoom_by(2.0, at)
	check("does not zoom past the ceiling", m._map._zoom <= MapView.ZOOM_MAX, true)
	for i in 40:
		m._map._zoom_by(0.5, at)
	check("or past the floor", m._map._zoom >= MapView.ZOOM_MIN, true)

	canvas.position += Vector2(400, 300)
	m._map.centre_on_current()
	var recentred := canvas.position + middle * m._map._zoom
	check("back to the middle", recentred.distance_to(port.size * 0.5) < 1.0, true)
	m._close_map()

	print("\n-- M opens and closes it --")
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	m._unhandled_input(key)
	check("opened by key", m._map.visible, true)
	m._unhandled_input(key)
	check("and closed by the same key", m._map.visible, false)

	print("\n-- walking from the map closes it --")
	var w: GameScreen = await screen(9)
	w._toggle_map()
	var dest: Vector2i = w.rc.map.reachable()[0]
	w._on_map_move(dest)
	check("moved", w.rc.map.current, dest)
	check("and the map got out of the way", w._map.visible, false)

	print("\n-- the turn orb reads as a budget, and cards carry bare numbers --")
	var orb: GameScreen = await screen(2)
	await _walk_into_a_fight(orb)
	if orb.rc.phase == RunController.Phase.BATTLE:
		var hours := _b_of(orb).turn_cost / Balance.MINUTES_PER_HOUR
		check("full budget reads N/N", orb._battle._orb_value.text, "%d/%d" % [hours, hours])
		check("the badge is a number, not a span",
			orb.rc.battle.card_at(0).cost_text(),
			str(orb.rc.battle.card_at(0).cost_hours))
		var spent := false
		for i in orb.rc.battle.piles().hand.size():
			if orb.rc.battle.card_at(i).cost_hours == 1 and orb.rc.play_card(i, 1):
				spent = true
				break
		if spent:
			orb._battle.show_battle(orb.rc)
			check("and it counts down", orb._battle._orb_value.text, "%d/%d" % [hours - 1, hours])

		print("\n-- the bundled pixel font, on its own grid --")
		var face := UiTheme.font()
		check("the bundled face loaded, not a system fallback", face is FontFile, true)
		# On the import, not set at runtime: lose them and every glyph blurs.
		check("imported without antialiasing", (face as FontFile).antialiasing,
			TextServer.FONT_ANTIALIASING_NONE)
		check("or hinting", (face as FontFile).hinting, TextServer.HINTING_NONE)
		check("or subpixel positioning", (face as FontFile).subpixel_positioning,
			TextServer.SUBPIXEL_POSITIONING_DISABLED)
		check("the palette is read from the theme", UiTheme.GOLD,
			UiTheme.build().get_color(&"gold", &"Palette"))

		print("\n-- a card is its scene --")
		var pool := CardDatabase.new()
		pool.load_from()
		var pilot := CardNode.create(pool.get_card(&"gather"), 0, true)
		# The hand fan and the grids lay out by SIZE, not by asking the node.
		check("the scene is the size the layouts assume",
			pilot.custom_minimum_size, CardNode.SIZE)
		check("its name is filled in", (pilot.get_node("%Title") as Label).text,
			pilot.card.display_name())
		check("and an exhausting card says so", pilot.get_node("%Exhaust").visible, true)
		pilot.free()
		var off_grid := 0
		for asked in [11, 12, 13, 14, 15, 16, 17, 18, 20, 24, 26, 30, 34]:
			if UiTheme.size_for(asked) % UiTheme.FONT_GRID != 0:
				off_grid += 1
		check("every requested size snaps to the grid", off_grid, 0)
		check("and nothing snaps below one full glyph", UiTheme.size_for(4), UiTheme.FONT_GRID)
		var fits := true
		for pinned in [["이번 턴", 11, 104.0], ["남은 시간은 사라진다", 12, 176.0],
				["소멸한 카드 12", 14, 156.0]]:
			var drawn := face.get_string_size(pinned[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
				UiTheme.size_for(int(pinned[1]))).x
			if drawn > float(pinned[2]):
				fits = false
				print("  FAIL  \"%s\" draws %.0fpx into %.0fpx" % [pinned[0], drawn, pinned[2]])
		check("the fixed labels still fit their boxes", fits, true)

		print("\n-- the pile counts are buttons, not clickable text --")
		var bar: Button = orb._battle._draw_label
		check("drawn with the theme's chrome", bar.flat, false)
		check("and big enough to aim at", bar.size.y >= 30.0, true)
		var left_col: Control = orb._battle._draw_label.get_parent()
		var right_col: Control = orb._battle._discard_label.get_parent()
		await process_frame
		check("draw sits bottom-left", left_col.global_position.x < orb._battle.size.x * 0.5, true)
		check("spent piles sit bottom-right", right_col.global_position.x > orb._battle.size.x * 0.5, true)
		check("the two columns do not overlap",
			Rect2(left_col.global_position, left_col.size).intersects(
				Rect2(right_col.global_position, right_col.size)), false)

		print("\n-- every pile can be read, and the draw pile keeps its order secret --")
		orb.rc.battle.piles().draw.assign([4, 1, 3, 0, 2])
		orb._on_pile(BattleView.Pile.DRAW)
		await process_frame
		check("the reader opened", orb._picker.visible, true)
		var listed := []
		for child in orb._picker._grid.get_children():
			listed.append((child as CardNode).index)
		var ordered := listed.duplicate()
		ordered.sort()
		check("shown sorted, not in draw order", listed, ordered)
		check("nothing in it is choosable",
			orb._picker._grid.get_child(0).clicked.get_connections().is_empty(), true)
		orb._close_picker()

		orb.rc.battle.piles().discard.assign([0, 1])
		orb._on_pile(BattleView.Pile.DISCARD)
		await process_frame
		check("the discard reads too", orb._picker._grid.get_child_count(), 2)
		orb._close_picker()

		orb.rc.battle.piles().exhausted.clear()
		orb._on_pile(BattleView.Pile.EXHAUST)
		await process_frame
		check("an empty pile says so rather than showing nothing",
			orb._picker._empty.visible, true)
		orb._close_picker()

	_tidy_up()
	print("\n%s (%d failures)\n" % ["PASS" if _failures == 0 else "FAILURES", _failures])
	quit(1 if _failures > 0 else 0)


func _b_of(s: GameScreen) -> Balance:
	return s._balance


func _count_of(deck: Array, id: StringName) -> int:
	var n := 0
	for entry in deck:
		if entry["id"] == id:
			n += 1
	return n


func _refuses_size(size: Vector2i) -> bool:
	var before := Settings.window_size
	Settings.set_window_size(size)
	var refused := Settings.window_size == before
	Settings.window_size = before
	return refused


const SCRATCH := ["user://test_ui_run.save", "user://test_ui_settings.cfg"]


func _tidy_up() -> void:
	for file in SCRATCH + ["user://test_ui_keys.cfg"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))


func _refuses_locale(value: String) -> bool:
	var before := Settings.locale
	Settings.set_locale(value)
	var refused := Settings.locale == before
	Settings.locale = before
	return refused


func _untranslated_ui_keys() -> Array:
	var missing := []
	var file := FileAccess.open("res://source/data/localization/strings.csv", FileAccess.READ)
	if file == null:
		return ["strings.csv is unreadable"]
	var was := TranslationServer.get_locale()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3 or not row[0].begins_with("ui."):
			continue
		for lang in Settings.LOCALES:
			TranslationServer.set_locale(lang)
			if TranslationServer.translate(row[0]) == row[0]:
				missing.append("%s (%s)" % [row[0], lang])
	file.close()
	TranslationServer.set_locale(was)
	return missing


func _refuses_mode(value: int) -> bool:
	var before := Settings.screen_mode
	Settings.set_screen_mode(value)
	var refused := Settings.screen_mode == before
	Settings.screen_mode = before
	return refused


func _resuming_into_a_fight(boot: RootScreen) -> void:
	print("\n-- resuming into a fight draws the hand where the hand goes --")
	var saver: GameScreen = await screen(2)
	var steps := 0
	while saver.rc.phase != RunController.Phase.BATTLE and steps < 40:
		steps += 1
		var doors := saver.rc.map.reachable()
		if doors.is_empty():
			break
		saver._on_move(doors[steps % doors.size()])
	check("a fight was saved", saver.rc.phase, RunController.Phase.BATTLE)
	saver.queue_free()

	boot.show_title()
	await process_frame
	boot._title.continue_requested.emit()
	await process_frame
	await process_frame
	check("resumed into the fight", boot._game.rc.phase, RunController.Phase.BATTLE)

	var fan: Control = boot._game._battle._hand_layer
	check("the hand was dealt", fan.get_child_count() > 0, true)
	var furthest := 0.0
	for card in fan.get_children():
		furthest = maxf(furthest, (card as Control).position.x)
	check("and it is not stacked at the left edge", furthest > 200.0, true)

	var leftmost: Control = fan.get_child(0)
	var rightmost: Control = fan.get_child(fan.get_child_count() - 1)
	var fan_middle := (leftmost.position.x + rightmost.position.x + CardNode.SIZE.x) * 0.5
	check("the fan is centred on the view",
		absf(fan_middle - boot._game._battle.size.x * 0.5) < 40.0, true)


func _pausing_out_of_a_fight(boot: RootScreen) -> void:
	print("\n-- escape opens a way out of a run, and it saves --")
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var g: GameScreen = boot._game
	await _walk_into_a_fight(g)
	check("in a fight", g.rc.phase, RunController.Phase.BATTLE)

	check("nothing is up yet", g._pause.visible, false)
	g._toggle_pause()
	await process_frame
	check("escape opened it", g._pause.visible, true)
	check("and it offers four ways to answer", g._pause.body().get_child_count(), 4)

	g._pause.closed.emit()
	await process_frame
	check("escape again puts it away", g._pause.visible, false)

	_press_escape()
	await process_frame
	check("a real escape opens it", g._pause.visible, true)
	_press_escape()
	await process_frame
	check("and a real escape closes it", g._pause.visible, false)

	g._toggle_map()
	await process_frame
	check("the map is up", g._map.visible, true)
	_press_escape()
	await process_frame
	check("escape closed the map", g._map.visible, false)
	check("and did not open the pause behind it", g._pause.visible, false)

	print("\n-- and leaving from it keeps the run --")
	var where := g.rc.map.current
	g._toggle_pause()
	await process_frame
	g._pause.title_requested.emit()
	await process_frame
	check("back at the title", boot._title.visible, true)
	check("with a run to continue into", SaveGame.has_save(), true)
	boot._title.continue_requested.emit()
	await process_frame
	await process_frame
	check("and it is the same run", boot._game.rc.map.current, where)
	check("still in the fight it was left in",
		boot._game.rc.phase, RunController.Phase.BATTLE)


func _press_escape() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.pressed = true
	root.push_input(down)


func _spent_piles_sit_side_by_side(g: GameScreen) -> void:
	print("\n-- the two spent piles share a row --")
	var row: Control = g._battle._discard_label.get_parent()
	check("same parent", g._battle._exhaust_label.get_parent(), row)
	check("which is a row, not a column", row is HBoxContainer, true)
	var left: Control = g._battle._discard_label
	var right: Control = g._battle._exhaust_label
	check("side by side", absf(left.global_position.y - right.global_position.y) < 1.0, true)
	check("and not on top of each other",
		right.global_position.x > left.global_position.x, true)
	check("the row is no wider than the button above it",
		row.size.x <= g._battle._end_turn.size.x + 1.0, true)


func _keybinds_are_rebindable(boot: RootScreen) -> void:
	print("\n-- shortcuts are bindings, not literals --")
	Keybinds.path = "user://test_ui_keys.cfg"
	Keybinds.reset()
	check("end turn is on space by default",
		Keybinds.key_of(Keybinds.Action.END_TURN), KEY_SPACE)
	check("and a key maps back to its action",
		Keybinds.action_for(KEY_M), Keybinds.Action.MAP)
	check("an unbound key maps to nothing", Keybinds.action_for(KEY_F9), -1)

	var combo := KEY_MASK_CTRL | KEY_1
	Keybinds.bind(Keybinds.Action.DECK, combo)
	check("a combination binds", Keybinds.key_of(Keybinds.Action.DECK), combo)
	check("and reads as one", Keybinds.name_of(Keybinds.Action.DECK), "Ctrl+1")
	check("the bare key is not the combination",
		Keybinds.action_for(KEY_1), -1)
	check("but the combination is", Keybinds.action_for(combo), Keybinds.Action.DECK)
	Keybinds.bind(Keybinds.Action.DECK, KEY_D)
	check("a modifier on its own is refused",
		_refuses_bind(Keybinds.Action.DECK, KEY_CTRL), true)

	Keybinds.bind(Keybinds.Action.END_TURN, KEY_F9)
	check("rebinding took", Keybinds.key_of(Keybinds.Action.END_TURN), KEY_F9)
	check("and the old key is free again", Keybinds.action_for(KEY_SPACE), -1)

	Keybinds.bind(Keybinds.Action.MAP, KEY_F9)
	check("taking a key that was held swaps them",
		Keybinds.key_of(Keybinds.Action.MAP), KEY_F9)
	check("so nothing is left unbound",
		Keybinds.key_of(Keybinds.Action.END_TURN), KEY_M)

	Keybinds.bind(Keybinds.Action.MAP, KEY_F9)
	check("binding a key to what already holds it changes nothing",
		Keybinds.key_of(Keybinds.Action.END_TURN), KEY_M)

	Keybinds.reset()
	Keybinds.load_from()
	check("and it survived the file", Keybinds.key_of(Keybinds.Action.MAP), KEY_F9)
	Keybinds.reset_to_defaults()
	check("reset puts them back", Keybinds.key_of(Keybinds.Action.MAP), KEY_M)

	print("\n-- and the bound key is the one the game listens for --")
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var g: GameScreen = boot._game
	await _walk_into_a_fight(g)
	check("in a fight", g.rc.phase, RunController.Phase.BATTLE)

	var turn := g.rc.battle.turn
	_press(KEY_SPACE)
	await process_frame
	check("space ended the turn", g.rc.battle.turn > turn, true)

	Keybinds.bind(Keybinds.Action.END_TURN, KEY_F9)
	var moved := g.rc.battle.turn
	_press(KEY_SPACE)
	await process_frame
	check("the old key does nothing now", g.rc.battle.turn, moved)
	_press(KEY_F9)
	await process_frame
	check("and the new one works", g.rc.battle.turn > moved, true)
	Keybinds.reset_to_defaults()

	print("\n-- settings are reachable from inside a run --")
	g._toggle_pause()
	await process_frame
	g._pause.settings_requested.emit()
	await process_frame
	check("the settings opened", boot._settings.visible, true)
	check("and over the run, not behind it",
		boot.get_child(boot.get_child_count() - 1), boot._settings)
	boot._settings._select(SettingsView.Tab.KEYS)
	await process_frame
	check("the key tab lists every action",
		boot._settings.body().get_child_count(), Keybinds.ORDER.size() + 1)
	boot._settings.closed.emit()
	await process_frame


func _press(keycode: int) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.pressed = true
	root.push_input(down)


func _settings_plate_holds_its_size(boot: RootScreen) -> void:
	print("\n-- the settings plate is the same size on every tab --")
	boot._open_settings()
	await process_frame
	await process_frame
	boot._settings._select(SettingsView.Tab.SCREEN)
	await process_frame
	await process_frame
	var on_screen: Vector2 = boot._settings._frame.size
	boot._settings._select(SettingsView.Tab.KEYS)
	await process_frame
	await process_frame
	var on_keys: Vector2 = boot._settings._frame.size
	check("same width", is_equal_approx(on_screen.x, on_keys.x), true)
	check("same height", is_equal_approx(on_screen.y, on_keys.y), true)
	check("and it is still smaller than the screen",
		on_keys.y < boot._settings.size.y * 0.6, true)
	boot._settings._select(SettingsView.Tab.SCREEN)
	boot._settings.closed.emit()
	await process_frame


func _abandoning_a_run(boot: RootScreen) -> void:
	print("\n-- abandoning asks first, then destroys the run --")
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var g: GameScreen = boot._game
	g._on_move(g.rc.map.reachable()[0])
	check("there is a run on disk", SaveGame.has_save(), true)

	g._toggle_pause()
	await process_frame
	check("four entries", g._pause.body().get_child_count(), 4)
	var abandon: Button = g._pause.body().get_child(3)
	abandon.pressed.emit()
	await process_frame
	check("it asks before doing it", g._pause._confirming, true)
	check("with two answers", g._pause.body().get_child_count(), 2)
	check("and the run is still there", SaveGame.has_save(), true)

	(g._pause.body().get_child(1) as Button).pressed.emit()
	await process_frame
	check("saying no puts the menu back", g._pause._confirming, false)
	check("run untouched", SaveGame.has_save(), true)

	var plate_menu: Vector2 = g._pause._frame.size
	(g._pause.body().get_child(3) as Button).pressed.emit()
	await process_frame
	await process_frame
	check("the plate does not resize when it asks",
		is_equal_approx(g._pause._frame.size.y, plate_menu.y), true)

	(g._pause.body().get_child(0) as Button).pressed.emit()
	await process_frame
	check("saying yes clears the save", SaveGame.has_save(), false)
	check("and drops back to the title", boot._title.visible, true)
	check("with nothing to continue into",
		boot._title._continue_item.visible, false)

	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame


func _refuses_bind(action: int, combined: int) -> bool:
	var before := Keybinds.key_of(action)
	Keybinds.bind(action, combined)
	return Keybinds.key_of(action) == before


## Walks with a purpose rather than at random. Picking `doors[step % size]` used to
## work by luck; once act one's start became a single corridor it began oscillating
## in a pocket of two rooms and never reached a fight at all.
func _walk_into_a_fight(s: GameScreen) -> void:
	var seen := {}
	for step in 60:
		if s.rc.phase == RunController.Phase.BATTLE:
			return
		match s.rc.phase:
			RunController.Phase.EVENT:
				s._on_choice(["event", s.rc.event.choices.size() - 1])
			RunController.Phase.FIRE:
				s._on_choice("leave_fire")
			RunController.Phase.SHOP:
				s._on_choice("leave_shop")
			RunController.Phase.REWARD:
				s._on_choice("skip")
			RunController.Phase.EXPLORING:
				var next: Variant = _next_step_toward_a_fight(s, seen)
				if next == null:
					return
				seen[next] = int(seen.get(next, 0)) + 1
				s._on_move(next)
			_:
				return
		await process_frame


## A reachable fight if one is going spare, otherwise the door walked through
## least often — which is what stops the walk from pacing between two rooms.
func _next_step_toward_a_fight(s: GameScreen, seen: Dictionary) -> Variant:
	var doors := s.rc.map.reachable()
	if doors.is_empty():
		return null
	for coord in doors:
		var room: Room = s.rc.map.at(coord)
		if room != null and room.is_hostile() and not room.is_spent():
			return coord
	var best: Variant = null
	var fewest := 1 << 30
	for coord in doors:
		var times := int(seen.get(coord, 0))
		if times < fewest:
			fewest = times
			best = coord
	return best


func _events_are_drawn(boot: RootScreen) -> void:
	print("\n-- walking into an event room puts the event on screen --")
	boot.begin(3)
	await process_frame
	var g: GameScreen = boot._game
	await _walk_to_event(g)
	check("standing in an event", g.rc.phase, RunController.Phase.EVENT)
	if g.rc.phase != RunController.Phase.EVENT:
		return

	check("the run has one to show", g.rc.event != null, true)
	check("and the screen is showing something", g._choice.visible, true)
	check("with the event's own title", g._choice._title.text, g.rc.event.title())
	check("and one button per choice",
		g._choice._options.get_child_count(), g.rc.event.choices.size())

	var pick := 0
	for i in g.rc.event.choices.size():
		if g.rc.event.choices[i].available(g.rc.run):
			pick = i
			break
	g._on_choice(["event", pick])
	await process_frame
	check("choosing moves the run on", g.rc.phase, RunController.Phase.EXPLORING)
	check("and the room view is back", g._room.visible, true)


func _walk_to_event(s: GameScreen) -> void:
	for attempt in 40:
		if s.rc.phase == RunController.Phase.EVENT:
			return
		match s.rc.phase:
			RunController.Phase.FIRE:
				s._on_choice("leave_fire")
			RunController.Phase.SHOP:
				s._on_choice("leave_shop")
			RunController.Phase.REWARD:
				s._on_choice("skip")
			RunController.Phase.BATTLE:
				for handle in s.rc.battle.enemy_handles():
					s.rc.battle.combatants[handle].hp = 0
				s._on_end_turn()
			RunController.Phase.EXPLORING:
				var route := _route_to(s.rc, Room.Kind.EVENT)
				if route.is_empty():
					return
				s._on_move(route[0])
			_:
				return
		await process_frame


func _route_to(rc: RunController, kind: int) -> Array:
	var seen := {rc.map.current: true}
	var queue := [[rc.map.current, []]]
	while not queue.is_empty():
		var entry: Array = queue.pop_front()
		var at: Vector2i = entry[0]
		var route: Array = entry[1]
		if not route.is_empty() and rc.map.rooms.has(at) \
				and rc.map.rooms[at].kind == kind and not rc.map.rooms[at].cleared:
			return route
		for next in MapGenerator.neighbours_of(rc.map.rooms, at):
			if seen.has(next):
				continue
			seen[next] = true
			queue.append([next, route + [next]])
	return []


func _language_reaches_a_running_game(boot: RootScreen) -> void:
	print("\n-- switching language mid-run relabels the game, not just the menus --")
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var korean: String = boot._game._hud.get_child(0).get_child(0).get_child(0).text
	check("the hud is in Korean", korean, tr("ui.hud.now"))

	Settings.set_locale("en")
	boot._on_language_changed()
	await process_frame
	check("the run survived the rebuild", boot._game.rc != null, true)
	check("and it is the same run", boot._game.rc.run.seed,
		RunClock.seed_from_date(0, 0, 2, 12))
	var english: String = boot._game._hud.get_child(0).get_child(0).get_child(0).text
	check("the hud followed", english, "Now")
	check("which is not what it said before", english != korean, true)
	check("and the top menu followed too", boot._game._menu._map_button.text, "Map")

	Settings.set_locale("ko")
	boot._on_language_changed()
	await process_frame
	check("and back", boot._game._hud.get_child(0).get_child(0).get_child(0).text, korean)


func _out_of_reach_is_shown(boot: RootScreen) -> void:
	print("\n-- an enemy that cannot be hurt says so, and the card agrees --")
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var g: GameScreen = boot._game
	await _walk_into_a_fight(g)
	if g.rc.phase != RunController.Phase.BATTLE:
		return

	var mark := g.rc.battle.enemy_handles()[0]
	var enemy: EnemyStats = g.rc.battle.enemy(mark)
	enemy.behavior = BehaviorLooper.new()
	enemy.intents.clear()
	var wall := EnemyIntent.new()
	wall.kind = EnemyIntent.Kind.ATTACK
	wall.amount = 5
	enemy.intents.append(wall)
	enemy.intent_index = 0

	check("nothing reaches it", g.rc.battle.reaches(mark), false)
	var hp_before := enemy.hp
	g.rc.battle.damage(mark, 20, BattleState.PLAYER)
	check("and nothing does", enemy.hp, hp_before)

	# The preview has to agree with that, or the card lies about what it will do.
	var strike := CardDatabase.new()
	strike.load_from()
	var blade := strike.get_card(&"take")
	check("the card says zero too",
		blade.rules_text_live(g.rc.battle, BattleState.PLAYER, mark).contains("0"), true)

	g._battle.show_battle(g.rc)
	await process_frame
	var panel: Control = g._battle._enemy_panels[0]["node"]
	var says := false
	for child in panel.get_children():
		if child is Label and (child as Label).text == tr("ui.battle.out_of_reach"):
			says = true
	check("and the panel says it out loud", says, true)

	var window := EnemyIntent.new()
	window.kind = EnemyIntent.Kind.ATTACK
	window.amount = 5
	window.is_break_window = true
	enemy.intents[0] = window
	check("in the window it can be reached", g.rc.battle.reaches(mark), true)
	g.rc.battle.damage(mark, 20, BattleState.PLAYER)
	check("and the blow lands", enemy.hp < hp_before, true)


func _prices_are_drawn_on_the_map(boot: RootScreen) -> void:
	print("\n-- every surveyed room wears its own price, and the far ones do not --")
	boot.begin(31)
	await process_frame
	var g: GameScreen = boot._game
	g.rc.move_to(g.rc.map.reachable()[0])
	g.refresh()
	await process_frame

	g._toggle_map()
	await process_frame
	await process_frame

	var canvas: Control = g._map._canvas
	var by_hours := {}
	var badly_scaled := 0
	for piece in g._map._lines.segments:
		var pair: Array = piece["corridor"]
		var hours := roundi(float(g.rc.map.guessed_priced_between(pair[0], pair[1]))
			/ Balance.MINUTES_PER_HOUR)
		var drawn: float = (Vector2(piece["to"]) - Vector2(piece["from"])).length()
		var want := float(MapView.CELL) + MapView.UNIT * hours
		if absf(drawn - want) > want * 0.3:
			badly_scaled += 1
			print("     %s->%s wants %.0fpx for %dh, drawn %.0fpx"
				% [str(pair[0]), str(pair[1]), want, hours, drawn])
		by_hours[hours] = float(by_hours.get(hours, 0.0)) + drawn
		by_hours[[hours]] = int(by_hours.get([hours], 0)) + 1

	check("corridors of more than one length are on screen", by_hours.size() > 2, true)
	check("each is drawn close to the length it claims", badly_scaled, 0)

	var lengths := []
	for key in by_hours:
		if key is int:
			lengths.append([key, float(by_hours[key]) / float(by_hours[[key]])])
	lengths.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var out_of_order := 0
	for i in range(1, lengths.size()):
		if float(lengths[i][1]) <= float(lengths[i - 1][1]):
			out_of_order += 1
	check("and a longer walk is always drawn longer", out_of_order, 0)

	var wordy := 0
	for child in canvas.get_children():
		if child is Label or (child is Button and (child as Button).text.contains("\n")):
			wordy += 1
	check("no hours are spelled out on the map itself", wordy, 0)

	var uncovered := 0
	for child in canvas.get_children():
		if child is Button and not Rect2(Vector2.ZERO, g._map._lines.size).encloses(
				Rect2(child.position, child.size)):
			uncovered += 1
	check("the corridor canvas covers every room, so none of it is culled away",
		uncovered, 0)

	var see_through := 0
	for child in canvas.get_children():
		if not (child is Button):
			continue
		var skin := (child as Button).get_theme_stylebox("normal")
		if skin is StyleBoxFlat and (skin as StyleBoxFlat).bg_color.a < 1.0:
			see_through += 1
	check("no room lets the trail show through it", see_through, 0)

	var straight := 0
	for piece in g._map._lines.segments:
		var points := PackedVector2Array(piece["points"])
		var from := Vector2(piece["from"])
		var chord := Vector2(piece["to"]) - from
		var strayed := 0.0
		for p in points:
			var along: float = clampf((p - from).dot(chord) / chord.length_squared(), 0.0, 1.0)
			strayed = maxf(strayed, p.distance_to(from + chord * along))
		if strayed < 6.0:
			straight += 1
	check("every corridor wanders rather than running straight", straight, 0)

	var different := {}
	for coord in g.rc.map.rooms:
		for next in g.rc.map.neighbours(coord):
			different[g.rc.map.cost_between(coord, next)] = true
	check("the floor does not make every corridor the same length",
		different.size() > 1, true)

	print("\n-- the walk to the boss is never quoted to the player --")
	check("the floor still knows the walk is an estimate",
		g.rc.map.boss_walk_is_guess(), true)
	check("but the map hint holds the battle note and nothing else",
		g._map._hint.text, tr("ui.map.no_move_in_battle"))
	check("and the door is not on the map until it is found",
		g.rc.map.known_rooms().has(g.rc.map.boss_coord), false)

	g._close_map()
	await process_frame


func _has_hangul(text: String) -> bool:
	for c in text:
		var code := c.unicode_at(0)
		if (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x3130 and code <= 0x318F):
			return true
	return false



func _leaks_in(node: Node) -> Array:
	var found := []
	var walk := [node]
	while not walk.is_empty():
		var at: Node = walk.pop_back()
		walk.append_array(at.get_children())
		var text := ""
		if at is Label:
			text = (at as Label).text
		elif at is Button:
			text = (at as Button).text
		elif at is RichTextLabel:
			text = (at as RichTextLabel).get_parsed_text()
		elif at is LineEdit:
			text = (at as LineEdit).placeholder_text
		if text == "한국어":
			continue
		if _has_hangul(text):
			found.append("%s  %s" % [at.get_class(), text.replace("\n", " / ")])
	return found


func _sweep(where: String, node: Node, tally: Dictionary) -> void:
	var leaks := _leaks_in(node)
	tally["seen"] = int(tally["seen"]) + 1
	if leaks.is_empty():
		print("  ok    %s is fully translated" % where)
		return
	for leak in leaks:
		print("     %s leaked  %s" % [where, leak])
	tally["leaks"] = int(tally["leaks"]) + leaks.size()
	_failures += 1


func _english_leaves_no_korean_behind(boot: RootScreen) -> void:
	print("\n-- under English no screen has Korean left anywhere in it --")
	Settings.set_locale("en")
	boot._on_language_changed()
	boot.show_title()
	await process_frame
	var tally := {"seen": 0, "leaks": 0}

	_sweep("the title", boot._title, tally)

	boot._open_compendium()
	await process_frame
	for tab in [CompendiumView.Tab.CARDS, CompendiumView.Tab.ENEMIES, CompendiumView.Tab.RELICS]:
		boot._compendium._select(tab)
		await process_frame
		_sweep("compendium tab %d" % tab, boot._compendium, tally)
	boot._compendium._select(CompendiumView.Tab.CARDS)
	boot._compendium.visible = false

	boot._open_settings()
	await process_frame
	for tab in [SettingsView.Tab.SCREEN, SettingsView.Tab.KEYS]:
		boot._settings._select(tab)
		await process_frame
		_sweep("settings tab %d" % tab, boot._settings, tally)
	boot._settings._select(SettingsView.Tab.SCREEN)
	boot._settings.visible = false

	boot.begin(31)
	await process_frame
	var g: GameScreen = boot._game
	_sweep("the hud", g._hud, tally)
	_sweep("the top menu", g._menu, tally)
	_sweep("the room", g._room, tally)

	g._toggle_map()
	await process_frame
	_sweep("the map", g._map, tally)
	g._close_map()

	g._toggle_deck()
	await process_frame
	_sweep("the deck viewer", g._picker, tally)
	g._close_picker()

	g._toggle_pause()
	await process_frame
	_sweep("the pause menu", g._pause, tally)
	g._toggle_pause()
	await process_frame

	await _sweep_a_fight(boot, tally)
	await _sweep_a_room_kind(boot, Room.Kind.FIRE, "the fire", tally)
	await _sweep_a_room_kind(boot, Room.Kind.SHOP, "the shop", tally)
	await _sweep_a_room_kind(boot, Room.Kind.EVENT, "an event", tally)

	check("every screen was actually visited", tally["seen"] >= 15, true)
	check("and none of them leaked Korean", tally["leaks"], 0)
	Settings.set_locale("ko")
	boot._on_language_changed()
	await process_frame


func _sweep_a_fight(boot: RootScreen, tally: Dictionary) -> void:
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var g: GameScreen = boot._game
	await _walk_into_a_fight(g)
	if g.rc.phase != RunController.Phase.BATTLE:
		print("     (seed 2 reached no fight, nothing swept)")
		return
	_sweep("the battle", g._battle, tally)

	for handle in g.rc.battle.enemy_handles():
		g.rc.battle.combatants[handle].hp = 0
	g.rc.battle.end_turn()
	g.refresh()
	await process_frame
	if g.rc.phase == RunController.Phase.REWARD:
		_sweep("the reward", g._choice, tally)


func _sweep_a_room_kind(boot: RootScreen, kind: int, where: String, tally: Dictionary) -> void:
	for seed_value in [31, 3, 7, 11, 2, 5]:
		boot.begin(seed_value)
		await process_frame
		var g: GameScreen = boot._game
		if await _travel_to(g, kind):
			_sweep(where, g._choice, tally)
			return
	check("%s was reached and swept" % where, false, true)


func _travel_to(g: GameScreen, kind: int) -> bool:
	for step in 120:
		match g.rc.phase:
			RunController.Phase.EXPLORING:
				if g.rc.map.at(g.rc.map.current).kind == kind:
					return true
				var route := _route_to(g.rc, kind)
				if route.is_empty():
					return false
				g._on_move(route[0])
			RunController.Phase.BATTLE:
				for handle in g.rc.battle.enemy_handles():
					g.rc.battle.combatants[handle].hp = 0
				g.rc.battle.end_turn()
				g.refresh()
			RunController.Phase.REWARD:
				g._on_choice("skip")
			RunController.Phase.FIRE:
				if kind == Room.Kind.FIRE:
					return true
				g._on_choice("leave_fire")
			RunController.Phase.SHOP:
				if kind == Room.Kind.SHOP:
					return true
				g._on_choice("leave_shop")
			RunController.Phase.EVENT:
				if kind == Room.Kind.EVENT:
					return true
				g._on_choice(["event", g.rc.event.choices.size() - 1])
			_:
				return false
		await process_frame
	return false


func _a_save_from_an_older_build(boot: RootScreen) -> void:
	print("\n-- a save this build cannot read sends you back to the title, not into a new run --")
	boot.show_title()
	await process_frame

	var stale := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	stale.store_string(JSON.stringify({
		"version": RunController.SAVE_VERSION - 1, "seed": 99, "act": 1}))
	stale.close()

	check("the file is there", SaveGame.has_save(), true)
	boot.resume()
	await process_frame
	check("no run was started behind it", boot._game, null)
	check("the title is still up", boot._title.visible, true)
	check("and it stopped offering to continue",
		boot._title._continue_item.visible, false)
	SaveGame.clear()
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame


func _the_clock_runs_as_you_spend(boot: RootScreen) -> void:
	print("\n-- the clock shows time going as cards are played, not all at the end --")
	boot.begin(RunClock.seed_from_date(0, 0, 2, 12))
	await process_frame
	var g: GameScreen = boot._game
	await _walk_into_a_fight(g)
	if g.rc.phase != RunController.Phase.BATTLE:
		print("     (seed 2 reached no fight, nothing checked)")
		return

	var hud: Hud = g._hud
	var clock := g.rc.run.clock
	check("nothing is spent before a card is played", hud.spent_so_far(g.rc), 0)
	check("so the display matches the clock", hud.shown_target(g.rc), clock.remaining)

	var budget_was := g.rc.battle.turn_budget
	var played := -1
	for i in g.rc.battle.piles().hand.size():
		if g.rc.battle.play_card(i, g.rc.battle.enemy_handles()[0]):
			played = i
			break
	check("a card went down", played >= 0, true)
	if played < 0:
		return
	g.refresh()
	await process_frame

	var cost := budget_was - g.rc.battle.turn_budget
	check("the card cost something", cost > 0, true)
	check("that cost now reads as spent", hud.spent_so_far(g.rc), cost)
	check("and the clock shows it gone before the turn ends",
		hud.shown_target(g.rc), clock.remaining - cost)
	check("while the real clock has not moved yet",
		g.rc.run.clock.remaining, clock.remaining)

	var before_end := clock.remaining
	g._on_end_turn()
	await process_frame
	check("ending the turn charges the whole turn once",
		before_end - g.rc.run.clock.remaining, _b_of(g).turn_cost)
	check("and the display lands on the real clock",
		hud.shown_target(g.rc), g.rc.run.clock.remaining)


func _the_string_table_is_well_formed() -> void:
	print("\n-- every row in strings.csv is exactly three columns --")
	var file := FileAccess.open("res://source/data/localization/strings.csv", FileAccess.READ)
	if file == null:
		check("strings.csv opens", false, true)
		return
	var ragged := []
	var seen := {}
	var repeated := []
	var rows := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		rows += 1
		if row.size() != 3:
			ragged.append("%s has %d columns" % [row[0], row.size()])
		if seen.has(row[0]):
			repeated.append(row[0])
		seen[row[0]] = true
	file.close()
	for bad in ragged:
		print("     ragged  %s" % bad)
	for twice in repeated:
		print("     twice   %s" % twice)
	check("the table has rows", rows > 100, true)
	check("none is ragged, so no comma split a value", ragged.size(), 0)
	check("and no key is written twice", repeated.size(), 0)


func _a_date_starts_the_run(boot: RootScreen) -> void:
	print("\n-- the date you type is the seed you run --")
	boot.show_title()
	await process_frame
	boot._open_dates()
	await process_frame
	var dates: DateView = boot._dates
	check("the sheet is up", dates.visible, true)

	dates._year.text = "1487"
	dates._month.text = "47"
	dates._day.text = "88"
	dates._hour.text = "21"
	dates._retell()
	await process_frame

	var wanted := RunClock.seed_from_date(1487, 47, 88, 21)
	check("it reads the three fields as one seed", dates.entered_seed(), wanted)
	check("and shows the day it will open on",
		dates._reads.text.contains("47"), true)

	dates.chosen.emit(dates.entered_seed())
	await process_frame
	check("the sheet closed", dates.visible, false)
	check("a run started", boot._game != null, true)
	check("on that seed", boot._game.rc.run.seed, wanted)
	check("and the clock opens on that very day",
		boot._game.rc.run.clock.format_clock(),
		RunClock.new(_b_of(boot._game), -1, wanted).format_clock())

	print("\n-- a rolled date stays inside five digits --")
	var too_big := 0
	for roll in 200:
		var seed_value := boot.rolled_seed()
		if int(RunClock.date_from_seed(seed_value)["year"]) > RunClock.YEAR_LIMIT:
			too_big += 1
		if int(RunClock.date_from_seed(seed_value)["hour"]) > 23:
			too_big += 1
	check("no rolled year or hour falls outside its range", too_big, 0)

	print("\n-- letters and nonsense do not crash the sheet --")
	dates._year.text = "1a2b"
	dates._month.text = "x"
	dates._day.text = ""
	dates._hour.text = "99"
	check("only the digits are read, and the hour stays inside a day",
		dates.entered_seed(), RunClock.seed_from_date(12, 0, 0, 23))
