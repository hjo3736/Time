class_name CompendiumView
extends OverlayView


const SCENE := preload("res://source/scenes/ui/compendium_view.tscn")


## Always make one through here, never CompendiumView.new(): new() is the script
## without the scene it shares with the other overlays.
static func create() -> CompendiumView:
	return SCENE.instantiate() as CompendiumView


enum Tab { CARDS, ENEMIES, RELICS }

const TAB_KEYS := ["ui.compendium.tab_cards", "ui.compendium.tab_enemies", "ui.compendium.tab_relics"]

const DETAIL_SCALE := 2.0

var _on := {}

var _query := ""
var _search: LineEdit
var _count: Label

var _tab := Tab.CARDS
var _focus: CardData
var _cards: CardDatabase
var _enemies: EnemyDatabase
var _relics: RelicDatabase


func show_all(cards: CardDatabase, enemies: EnemyDatabase, relics: RelicDatabase) -> void:
	_cards = cards
	_enemies = enemies
	_relics = relics
	_focus = null
	_rebuild()


func _select(tab: int) -> void:
	_tab = tab as Tab
	_focus = null
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _focus != null and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE:
		_focus = null
		_rebuild()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _rebuild() -> void:
	relabel_chrome()
	if _focus != null:
		set_back(func() -> void:
			_focus = null
			_rebuild())
		clear_body()
		heading(_focus.display_name())
		_build_card_detail(_focus)
		return

	set_tabs(TAB_KEYS.map(func(k: String) -> String: return tr(k)), _tab, _select)
	clear_body()
	clear_side()
	show_side(false)
	match _tab:
		Tab.CARDS:
			heading(tr("ui.compendium.heading_cards").format({"n": _cards.size()}))
			_build_card_filters()
			_build_cards()
		Tab.ENEMIES:
			heading(tr("ui.compendium.heading_enemies").format({"n": _enemies.size()}))
			_build_enemy_filters()
			_build_enemies()
		Tab.RELICS:
			heading(tr("ui.compendium.heading_relics").format({"n": _relics.size()}))
			_build_relics()


func _passes(group: String, value: Variant) -> bool:
	var chosen: Dictionary = _on.get(group, {})
	return chosen.is_empty() or chosen.has(value)


func _toggle(group: String, value: Variant) -> void:
	var chosen: Dictionary = _on.get(group, {})
	if chosen.has(value):
		chosen.erase(value)
	else:
		chosen[value] = true
	_on[group] = chosen
	_rebuild()


func _clear_filters() -> void:
	_on.clear()
	_query = ""
	_rebuild()


func _group(label: String, group: String, options: Array) -> void:
	if options.size() < 2:
		return
	side().add_child(UiTheme.label(label, 18, UiTheme.GOLD))
	for option in options:
		var value: Variant = option["value"]
		var button := Button.new()
		button.text = String(option["label"])
		button.custom_minimum_size = Vector2(0, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", UiTheme.size_for(16))
		button.toggle_mode = true
		button.button_pressed = _on.get(group, {}).has(value)
		button.pressed.connect(func() -> void: _toggle(group, value))
		side().add_child(button)


func _side_header(shown: int) -> void:
	show_side(true)
	side().add_child(UiTheme.label(tr("ui.compendium.filter"), 22, UiTheme.BONE))

	_search = LineEdit.new()
	_search.text = _query
	_search.placeholder_text = tr("ui.compendium.search")
	_search.custom_minimum_size = Vector2(0, 42)
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(text: String) -> void:
		_query = text
		_refresh_list())
	side().add_child(_search)

	_count = UiTheme.label(
		tr("ui.compendium.filter_count").format({"n": shown}), 16, UiTheme.INK_DIM)
	side().add_child(_count)

	var reset := Button.new()
	reset.text = tr("ui.compendium.filter_all")
	reset.custom_minimum_size = Vector2(0, 40)
	reset.disabled = _on.is_empty() and _query.is_empty()
	reset.pressed.connect(_clear_filters)
	side().add_child(reset)


func _refresh_list() -> void:
	clear_body()
	match _tab:
		Tab.CARDS:
			_build_cards()
			_set_count(_visible_cards().size())
		Tab.ENEMIES:
			_build_enemies()
			_set_count(_visible_enemies().size())


func _set_count(shown: int) -> void:
	if _count != null and is_instance_valid(_count):
		_count.text = tr("ui.compendium.filter_count").format({"n": shown})


func _matches_query(text: String) -> bool:
	return _query.strip_edges().is_empty() \
		or text.to_lower().contains(_query.strip_edges().to_lower())


func _visible_cards() -> Array:
	return _cards.all().filter(func(card: CardData) -> bool:
		if not _matches_query(card.display_name()):
			return false
		if not _passes("kind", card.kind):
			return false
		if not _passes("rarity", card.rarity):
			return false
		var lanes: Array = card.lanes if not card.lanes.is_empty() else [-1]
		var chosen: Dictionary = _on.get("lane", {})
		if not chosen.is_empty() and not lanes.any(func(l: int) -> bool: return chosen.has(l)):
			return false
		return true)


func _build_card_filters() -> void:
	_side_header(_visible_cards().size())

	var kinds := []
	for kind in [CardData.Kind.ATTACK, CardData.Kind.SKILL,
			CardData.Kind.POWER, CardData.Kind.CURSE]:
		if _cards.all().any(func(c: CardData) -> bool: return c.kind == kind):
			kinds.append({"value": kind, "label": CardNode.kind_name(kind)})
	_group(tr("ui.compendium.filter_kind"), "kind", kinds)

	var rarities := []
	for entry in [[CardData.Rarity.STARTER, "starter"], [CardData.Rarity.COMMON, "common"],
			[CardData.Rarity.UNCOMMON, "uncommon"], [CardData.Rarity.RARE, "rare"],
			[CardData.Rarity.SPECIAL, "special"]]:
		if _cards.all().any(func(c: CardData) -> bool: return c.rarity == entry[0]):
			rarities.append({"value": entry[0], "label": tr("card.rarity.%s" % entry[1])})
	_group(tr("ui.compendium.filter_rarity"), "rarity", rarities)

	var lanes := []
	for entry in [[CardData.Lane.RUSH, "rush"], [CardData.Lane.ENGINE, "engine"],
			[CardData.Lane.CHRONOMANCY, "chronomancy"]]:
		if _cards.all().any(func(c: CardData) -> bool: return c.lanes.has(entry[0])):
			lanes.append({"value": entry[0], "label": tr("card.lane.%s" % entry[1])})
	if _cards.all().any(func(c: CardData) -> bool: return c.lanes.is_empty()):
		lanes.append({"value": -1, "label": tr("card.lane.none")})
	_group(tr("ui.compendium.filter_lane"), "lane", lanes)


func _build_enemy_filters() -> void:
	_side_header(_visible_enemies().size())

	var tiers := []
	for tier in [EnemyStats.Tier.NORMAL, EnemyStats.Tier.ELITE, EnemyStats.Tier.BOSS]:
		if not _enemies.of_tier(tier).is_empty():
			tiers.append({"value": tier, "label": _tier_name(tier)})
	_group(tr("ui.compendium.filter_tier"), "tier", tiers)


func _build_cards() -> void:
	var grid := GridContainer.new()
	grid.columns = _columns_for(
		get_viewport_rect().size.x - 200.0 - OverlayView.SIDE_WIDTH - 20.0)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body().add_child(grid)
	var shown := _visible_cards()
	if shown.is_empty():
		body().add_child(UiTheme.label(
			tr("ui.compendium.nothing_matches"), 20, UiTheme.INK_DIM))
		return
	for card in shown:
		var node := CardNode.create(card, -1, true)
		node.draggable = false
		node.clicked.connect(func(_index: int) -> void:
			_focus = card
			_rebuild())
		grid.add_child(node)


func _build_card_detail(card: CardData) -> void:
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_%s" % edge, 48)
	body().add_child(pad)

	var split := HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 16)
	split.add_child(left)

	var pair := HBoxContainer.new()
	pair.alignment = BoxContainer.ALIGNMENT_CENTER
	pair.add_theme_constant_override("separation", 40)
	left.add_child(pair)

	pair.add_child(_blown_up(card, tr("ui.compendium.before")))
	if card.can_upgrade():
		pair.add_child(_blown_up(card.upgraded(), tr("ui.compendium.after")))
	else:
		var none := VBoxContainer.new()
		none.alignment = BoxContainer.ALIGNMENT_CENTER
		none.custom_minimum_size = Vector2(CardNode.SIZE.x * DETAIL_SCALE, 0)
		var note := UiTheme.label(tr("ui.compendium.no_upgrade"), 20, UiTheme.INK_DIM)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_child(note)
		pair.add_child(none)

	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	split.add_child(right)


func _blown_up(card: CardData, caption: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)

	var label := UiTheme.label(caption, 20, UiTheme.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(CardNode.SIZE.x * DETAIL_SCALE, 0)
	column.add_child(label)

	var slot := Control.new()
	slot.custom_minimum_size = CardNode.SIZE * DETAIL_SCALE
	column.add_child(slot)

	var node := CardNode.create(card, -1, true)
	node.pivot_offset = Vector2.ZERO
	node.scale = Vector2(DETAIL_SCALE, DETAIL_SCALE)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(node)
	return column


func _build_enemies() -> void:
	var shown := _visible_enemies()
	if shown.is_empty():
		body().add_child(UiTheme.label(
			tr("ui.compendium.nothing_matches"), 20, UiTheme.INK_DIM))
		return
	for tier in [EnemyStats.Tier.NORMAL, EnemyStats.Tier.ELITE, EnemyStats.Tier.BOSS]:
		var group := shown.filter(func(e: EnemyStats) -> bool: return e.tier == tier)
		if group.is_empty():
			continue
		body().add_child(UiTheme.label(_tier_name(tier), 20, UiTheme.GOLD))
		for enemy in group:
			body().add_child(_enemy_row(enemy))


func _tier_name(tier: int) -> String:
	match tier:
		EnemyStats.Tier.ELITE:
			return tr("ui.compendium.tier_elite")
		EnemyStats.Tier.BOSS:
			return tr("ui.compendium.tier_boss")
	return tr("ui.compendium.tier_normal")


func _enemy_row(enemy: EnemyStats) -> Control:
	var frame := PanelContainer.new()
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	frame.add_child(row)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	row.add_child(top)
	top.add_child(UiTheme.label(TranslationServer.translate(enemy.name_key), 20, UiTheme.BONE))
	top.add_child(UiTheme.label(tr("ui.compendium.hp_range").format({"a": enemy.hp_min, "b": enemy.hp_max}), 16, UiTheme.INK_DIM))

	if enemy.behavior_script != null:
		var behavior: EnemyBehavior = enemy.behavior_script.new()
		var tell := TranslationServer.translate(behavior.tell_key())
		if tell != String(behavior.tell_key()):
			row.add_child(UiTheme.label(tell, 16, UiTheme.INK))

	row.add_child(UiTheme.label(_intent_line(enemy), 16, UiTheme.INK_DIM))
	return frame


func _intent_line(enemy: EnemyStats) -> String:
	var parts := []
	for intent in enemy.intents:
		match intent.kind:
			EnemyIntent.Kind.ATTACK:
				var hit := tr("ui.compendium.intent_attack").format({"n": intent.amount})
				if intent.times > 1:
					hit += tr("ui.battle.intent_times").format({"n": intent.times})
				parts.append(hit)
			EnemyIntent.Kind.BLOCK:
				parts.append(tr("ui.compendium.intent_block").format({"n": intent.amount}))
			EnemyIntent.Kind.STATUS:
				parts.append(tr("ui.compendium.intent_status").format({
					"name": tr("status.%s" % intent.status), "n": intent.stacks}))
			EnemyIntent.Kind.GROW:
				parts.append(tr("ui.compendium.intent_grow").format({"n": intent.stacks}))
			EnemyIntent.Kind.DRAG:
				parts.append(tr("ui.compendium.intent_drag").format({"n": intent.amount}))
			EnemyIntent.Kind.BEAR:
				parts.append(tr("ui.compendium.intent_bear").format({
					"name": tr("status.%s" % intent.status), "n": intent.stacks}))
			EnemyIntent.Kind.WAIT:
				parts.append(tr("ui.compendium.intent_wait"))
	return "  →  ".join(parts) if not parts.is_empty() else "―"


func _build_relics() -> void:
	for relic in _relics.all():
		var frame := PanelContainer.new()
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		frame.add_child(row)
		row.add_child(UiTheme.label(relic.display_name(), 20, UiTheme.GOLD))
		row.add_child(UiTheme.label(relic.description(), 16, UiTheme.INK))
		body().add_child(frame)


static func _columns_for(available: float) -> int:
	var step := CardNode.SIZE.x + 10.0
	return clampi(floori(available / step), 3, 10)


func _visible_enemies() -> Array:
	var out := []
	for tier in [EnemyStats.Tier.NORMAL, EnemyStats.Tier.ELITE, EnemyStats.Tier.BOSS]:
		if not _passes("tier", tier):
			continue
		for enemy in _enemies.of_tier(tier):
			if _matches_query(TranslationServer.translate(enemy.name_key)):
				out.append(enemy)
	return out
