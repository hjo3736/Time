class_name BattleView
extends Control


signal card_chosen(hand_index: int, target: int)
signal turn_ended

signal pile_requested(pile: int)

enum Pile { DRAW, DISCARD, EXHAUST }

const HAND_Y := 96.0
const FAN_SPREAD := 0.055

var _rc: RunController
var _stage: Control
var _hand_layer: Control
var _orb_value: Label
var _orb_panel: Panel
var _draw_label: Button
var _discard_label: Button
var _exhaust_label: Button
var _turn_label: Label
var _end_turn: Button
var _selected := -1

var _enemy_panels: Array[Dictionary] = []
var _drag_index := -1
var _drag_at := Vector2.ZERO
var _drag_target := -1
var _cards: Array[CardNode] = []

var _preview_target := -1

var _punch: Punch
var _watching: BattleState = null
var _landed := 0
var _warden_node: Control
var _warden_slot: Control
var _enemy_slot: Control


func _ready() -> void:
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.offset_bottom = -250
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_hand_layer = Control.new()
	_hand_layer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hand_layer.offset_top = -250
	_hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_layer)

	_warden_slot = Control.new()
	_warden_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warden_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_warden_slot)

	_enemy_slot = Control.new()
	_enemy_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enemy_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_enemy_slot)

	_punch = Punch.new()
	add_child(_punch)

	_build_orb()
	_build_end_turn()

	resized.connect(_on_resized)


func _on_resized() -> void:
	if _rc != null and _rc.battle != null and visible:
		_rebuild_hand(_rc)


func _corner(preset: int, at: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(preset)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.position = at
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	return column


func _build_orb() -> void:
	var column := _corner(Control.PRESET_BOTTOM_LEFT, Vector2(6, -6))
	column.add_theme_constant_override("separation", 14)

	_orb_panel = Panel.new()
	_orb_panel.custom_minimum_size = Vector2(104, 104)
	_orb_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var s := StyleBoxFlat.new()
	s.bg_color = UiTheme.PANEL_HI
	s.set_corner_radius_all(52)
	s.set_border_width_all(3)
	s.border_color = UiTheme.GOLD
	_orb_panel.add_theme_stylebox_override("panel", s)
	column.add_child(_orb_panel)

	_draw_label = _pile_button(Pile.DRAW)
	column.add_child(_draw_label)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_panel.add_child(box)

	_orb_value = UiTheme.label("", 30, UiTheme.BONE)
	_orb_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_orb_value)

	var caption := UiTheme.label(tr("ui.battle.this_turn"), 11, UiTheme.INK_DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)


func _pile_button(pile: int) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(176, 34)
	button.add_theme_font_size_override("font_size", UiTheme.size_for(14))
	button.pressed.connect(func() -> void: pile_requested.emit(pile))
	return button


func _build_end_turn() -> void:
	var box := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-186, -6))
	box.add_theme_constant_override("separation", 4)

	_turn_label = UiTheme.label("", 14, UiTheme.INK_DIM)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_turn_label)

	_end_turn = Button.new()
	_end_turn.text = tr("ui.battle.end_turn")
	_end_turn.custom_minimum_size = Vector2(176, 52)
	_end_turn.pressed.connect(func() -> void:
		_selected = -1
		turn_ended.emit())
	box.add_child(_end_turn)

	var warning := UiTheme.label(tr("ui.battle.unspent_warning"), 12, UiTheme.BLOOD)
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(warning)

	var spent := HBoxContainer.new()
	spent.add_theme_constant_override("separation", 6)
	box.add_child(spent)

	_discard_label = _pile_button(Pile.DISCARD)
	_discard_label.custom_minimum_size = Vector2(85, 34)
	_discard_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spent.add_child(_discard_label)

	_exhaust_label = _pile_button(Pile.EXHAUST)
	_exhaust_label.custom_minimum_size = Vector2(85, 34)
	_exhaust_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spent.add_child(_exhaust_label)


func show_battle(rc: RunController) -> void:
	_rc = rc
	if rc.battle == null:
		return
	_watch(rc.battle)

	_orb_value.text = "%d/%d" % [
		rc.battle.turn_budget / Balance.MINUTES_PER_HOUR,
		rc.battle.turn_budget_max / Balance.MINUTES_PER_HOUR]
	_turn_label.text = tr("ui.battle.turn_n").format({"n": rc.battle.turn})
	var piles := rc.battle.piles()
	_draw_label.text = tr("ui.battle.pile_draw").format({"n": piles.draw.size()})
	_discard_label.text = tr("ui.battle.pile_discard").format({"n": piles.discard.size()})
	_exhaust_label.text = tr("ui.battle.pile_exhaust").format({"n": piles.exhausted.size()})

	_preview_target = _drag_target
	_rebuild_stage(rc)
	_rebuild_hand(rc)


func _rebuild_stage(rc: RunController) -> void:
	ChoiceView._clear(_warden_slot)
	ChoiceView._clear(_enemy_slot)

	var warden := _warden_panel(rc)
	warden.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	warden.position = Vector2(40, -60)
	_warden_slot.add_child(warden)
	_warden_node = warden

	_enemy_panels.clear()
	var handles := rc.battle.enemy_handles()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	row.position = Vector2(-40, -70)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_enemy_slot.add_child(row)
	for handle in handles:
		var panel := _enemy_panel(rc, handle)
		row.add_child(panel)
		_enemy_panels.append({"handle": handle, "node": panel})


func _warden_panel(rc: RunController) -> Control:
	var w := rc.battle.warden()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.custom_minimum_size = Vector2(180, 0)

	box.add_child(UiTheme.label(tr("warden.name"), 20, UiTheme.BONE))
	box.add_child(_bar(w.hp, w.max_hp, UiTheme.BLOOD, 180))
	box.add_child(UiTheme.label("%d / %d" % [w.hp, w.max_hp], 14, UiTheme.INK_DIM))
	if w.block > 0:
		box.add_child(UiTheme.label(tr("ui.battle.block").format({"n": w.block}), 15, UiTheme.BONE))
	for status in w.statuses:
		box.add_child(UiTheme.label("%s %d" % [tr("status.%s" % status), w.status(status)], 13, UiTheme.GOLD))
	return box


func _enemy_panel(rc: RunController, handle: int) -> Control:
	var enemy: Combatant = rc.battle.combatants[handle]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.custom_minimum_size = Vector2(200, 0)

	var intent := UiTheme.label(_intent_text(rc, handle, enemy), 17, _intent_colour(rc, handle, enemy))
	intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intent)

	# Whatever else it does this turn, one line each, under the intent it leads
	# with. Everything it is about to do is on screen before it does any of it.
	if enemy.behavior != null:
		for extra in enemy.behavior.extra_intents(rc.battle, handle):
			var also := UiTheme.label(_intent_text(rc, handle, enemy, extra), 17, UiTheme.BLOOD)
			also.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(also)

	if enemy.behavior != null and enemy.behavior.tell_key() != &"":
		var tell := UiTheme.label(tr(enemy.behavior.tell_key()), 12, UiTheme.INK_DIM)
		tell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(tell)

	var name_label := UiTheme.label(tr(enemy.name_key), 20, UiTheme.BONE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	box.add_child(_bar(enemy.hp, enemy.max_hp, UiTheme.BONE, 200))
	var hp := UiTheme.label("%d / %d" % [enemy.hp, enemy.max_hp], 14, UiTheme.INK_DIM)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hp)

	if not rc.battle.reaches(handle):
		var shut := UiTheme.label(tr("ui.battle.out_of_reach"), 14, UiTheme.BLOOD)
		shut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(shut)

	if enemy.block > 0:
		var b := UiTheme.label(tr("ui.battle.block").format({"n": enemy.block}), 14)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(b)
	for status in enemy.statuses:
		var s := UiTheme.label("%s %d" % [tr("status.%s" % status), enemy.status(status)], 13, UiTheme.GOLD)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)

	if _selected >= 0:
		var pick := Button.new()
		pick.text = tr("ui.battle.use_here")
		pick.pressed.connect(func() -> void: _target_chosen(handle))
		box.add_child(pick)
	return box


func _bar(value: int, maximum: int, colour: Color, width: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 16)
	bar.max_value = maxi(1, maximum)
	bar.value = value
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = colour
	fill.set_corner_radius_all(2)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(UiTheme.INK_DIM, 0.22)
	back.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _intent_amount(rc: RunController, handle: int, enemy: Combatant, intent: EnemyIntent) -> int:
	var amount := intent.amount
	if enemy.behavior != null:
		amount = enemy.behavior.outgoing_amount(rc.battle, handle, intent)
	amount = roundi(amount * enemy.outgoing_multiplier)
	if intent.kind == EnemyIntent.Kind.ATTACK:
		amount = StatusRules.modified_damage(enemy, rc.battle.warden(), amount)
	return amount


func _intent_text(rc: RunController, handle: int, enemy: Combatant,
		shown: EnemyIntent = null) -> String:
	var intent := shown if shown != null else enemy.current_intent()
	if intent == null:
		return tr("ui.battle.intent_none")
	var amount := _intent_amount(rc, handle, enemy, intent)
	match intent.kind:
		EnemyIntent.Kind.ATTACK:
			var times := "" if intent.times <= 1 else tr("ui.battle.intent_times").format(
				{"n": intent.times})
			return tr("ui.battle.intent_attack").format({"n": amount, "times": times})
		EnemyIntent.Kind.BLOCK:
			return tr("ui.battle.intent_block").format({"n": amount})
		EnemyIntent.Kind.STATUS:
			return tr("ui.battle.intent_status").format({
				"name": tr("status.%s" % intent.status), "n": intent.stacks})
		EnemyIntent.Kind.GROW:
			return tr("ui.battle.intent_grow").format({"n": intent.stacks})
		EnemyIntent.Kind.DRAG:
			# Not `amount`: that has Threat on it, and the grip is not a blow.
			var left := intent.amount
			if enemy.behavior != null:
				left = enemy.behavior.outgoing_amount(rc.battle, handle, intent)
			if left <= 0:
				return tr("ui.battle.intent_drag_lost")
			return tr("ui.battle.intent_drag").format({"n": left})
		EnemyIntent.Kind.BEAR:
			return tr("ui.battle.intent_bear").format({
				"name": tr("status.%s" % intent.status), "n": intent.stacks})
		EnemyIntent.Kind.WAIT:
			return tr("ui.battle.intent_wait")
	return tr("ui.battle.intent_none")


func _rebuild_hand(rc: RunController) -> void:
	ChoiceView._clear(_hand_layer)
	_cards.clear()

	var hand := rc.battle.piles().hand
	var count := hand.size()
	if count == 0:
		return

	if size.x <= 0.0:
		return

	var centre := size.x * 0.5
	var step: float = minf(CardNode.SIZE.x + 12.0, (size.x - 460.0) / maxf(1.0, float(count)))

	for i in count:
		var card := rc.battle.card_at(i)
		if card == null:
			continue
		var node := CardNode.new()
		node.setup(card, i, card.cost_minutes() <= rc.battle.turn_budget, i == _selected)
		node.clicked.connect(_card_pressed)
		node.drag_started.connect(_on_drag_started)
		node.drag_moved.connect(_on_drag_moved)
		node.dropped.connect(_on_dropped)
		_hand_layer.add_child(node)
		_cards.append(node)

		var offset := float(i) - float(count - 1) * 0.5
		var angle := offset * FAN_SPREAD
		var lift := absf(offset) * absf(offset) * 3.0
		node.settle(
			Vector2(centre + offset * step - CardNode.SIZE.x * 0.5, HAND_Y + lift),
			angle)

	_refresh_card_numbers()


func _card_pressed(index: int) -> void:
	if _rc == null or _rc.battle == null:
		return
	var card := _rc.battle.card_at(index)
	if card == null:
		return
	if CardTargeting.requires_player_choice(card.targeting):
		_selected = index if _selected != index else -1
		show_battle(_rc)
		return
	_selected = -1
	card_chosen.emit(index, -1)


func _target_chosen(handle: int) -> void:
	if _selected < 0:
		return
	var index := _selected
	_selected = -1
	card_chosen.emit(index, handle)


func _on_drag_started(index: int) -> void:
	_drag_index = index
	_drag_target = -1
	queue_redraw()


func _on_drag_moved(index: int, at: Vector2) -> void:
	_drag_index = index
	_drag_at = at
	var was := _drag_target
	_drag_target = _enemy_under(at)
	if _drag_target != was:
		_preview_target = _drag_target
		_refresh_card_numbers()
	queue_redraw()


func _on_dropped(index: int, at: Vector2) -> void:
	var node := _card_node(index)
	_drag_index = -1
	_drag_target = -1
	_preview_target = -1
	_refresh_card_numbers()
	queue_redraw()

	if _rc == null or _rc.battle == null:
		return
	var card := _rc.battle.card_at(index)
	if card == null:
		return

	if CardTargeting.requires_player_choice(card.targeting):
		var handle := _enemy_under(at)
		if handle < 0:
			if node != null:
				node.return_home()
			return
		card_chosen.emit(index, handle)
		return

	if at.y < _hand_layer.global_position.y:
		card_chosen.emit(index, -1)
		return
	if node != null:
		node.return_home()


func _card_node(index: int) -> CardNode:
	for node in _cards:
		if is_instance_valid(node) and node.index == index:
			return node
	return null


func _enemy_under(at: Vector2) -> int:
	for entry in _enemy_panels:
		var node: Control = entry["node"]
		if is_instance_valid(node) and Rect2(node.global_position, node.size).has_point(at):
			return int(entry["handle"])
	return -1


func _draw() -> void:
	if _drag_index < 0:
		return
	var node := _card_node(_drag_index)
	if node == null:
		return
	var from := node.global_position + node.size * 0.5 - global_position
	var to := _drag_at - global_position
	var colour := UiTheme.GOLD if _drag_target >= 0 else Color(UiTheme.INK_DIM, 0.55)
	draw_line(from, to, colour, 3.0, true)
	draw_circle(to, 7.0, colour)

	var landing := aimed_damage()
	if _drag_target >= 0:
		for entry in _enemy_panels:
			var node2: Control = entry["node"]
			if int(entry["handle"]) == _drag_target and is_instance_valid(node2):
				var box := Rect2(node2.global_position - global_position, node2.size)
				draw_rect(box, UiTheme.GOLD, false, 2.0)
				if landing > 0:
					var font := UiTheme.font()
					var text := "-%d" % landing
					var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
					draw_string(font, box.position + Vector2(box.size.x * 0.5 - width * 0.5, -10),
						text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiTheme.GOLD)


func _refresh_card_numbers() -> void:
	if _rc == null or _rc.battle == null:
		return
	for node in _cards:
		if not is_instance_valid(node):
			continue
		var card := _rc.battle.card_at(node.index)
		if card == null:
			continue
		node.show_live_text(card.rules_text_live(_rc.battle, BattleState.WARDEN, _preview_target))


func aimed_damage() -> int:
	if _drag_index < 0 or _drag_target < 0 or _rc == null or _rc.battle == null:
		return 0
	var card := _rc.battle.card_at(_drag_index)
	if card == null:
		return 0

	var attacker := _rc.battle.warden()
	var victim: Combatant = _rc.battle.combatants[_drag_target]
	var total := 0
	for effect in card.effects:
		if effect is EffectDamage:
			var d := effect as EffectDamage
			total += StatusRules.modified_damage(attacker, victim, d.amount) * maxi(1, d.times)
	return total


func _intent_colour(rc: RunController, handle: int, enemy: Combatant) -> Color:
	var intent := enemy.current_intent()
	if intent == null or intent.kind != EnemyIntent.Kind.ATTACK:
		return UiTheme.BLOOD
	var raw := intent.amount
	if enemy.behavior != null:
		raw = enemy.behavior.outgoing_amount(rc.battle, handle, intent)
	raw = roundi(raw * enemy.outgoing_multiplier)
	var shown := _intent_amount(rc, handle, enemy, intent)
	if shown < raw:
		return UiTheme.GREEN
	return UiTheme.BLOOD


func _watch(battle: BattleState) -> void:
	if _watching == battle:
		return
	if _watching != null and _watching.combatant_damaged.is_connected(_on_damaged):
		_watching.combatant_damaged.disconnect(_on_damaged)
		_watching.combatant_blocked.disconnect(_on_blocked)
	_watching = battle
	battle.combatant_damaged.connect(_on_damaged)
	battle.combatant_blocked.connect(_on_blocked)


func _on_damaged(handle: int, amount: int) -> void:
	if amount <= 0 or _punch == null:
		return
	var panel := _panel_for(handle)
	if panel == null:
		return

	var waited := float(_landed) * Punch.STAGGER
	_landed += 1
	get_tree().create_timer(Punch.STAGGER * 2.0).timeout.connect(
		func() -> void: _landed = maxi(0, _landed - 1))

	var hurt := handle == BattleState.WARDEN
	var tint := UiTheme.BLOOD if hurt else UiTheme.BONE
	var where := Rect2(panel.global_position - global_position, panel.size)
	_punch.land(where, amount, tint, waited)
	_punch.shake(_slot_for(handle), minf(4.0 + float(amount) * 0.7, 18.0), waited)


func _panel_for(handle: int) -> Control:
	if handle == BattleState.WARDEN:
		return _warden_node
	for entry in _enemy_panels:
		if int(entry["handle"]) == handle:
			return entry["node"]
	return null



func _on_blocked(handle: int, absorbed: int) -> void:
	if absorbed <= 0 or _punch == null:
		return
	var panel := _panel_for(handle)
	if panel == null:
		return

	var waited := float(_landed) * Punch.STAGGER
	_landed += 1
	get_tree().create_timer(Punch.STAGGER * 2.0).timeout.connect(
		func() -> void: _landed = maxi(0, _landed - 1))

	var where := Rect2(panel.global_position - global_position, panel.size)
	_punch.turn_aside(where, absorbed, waited)
	_punch.shake(_slot_for(handle), Punch.GUARD_SHAKE, waited)


func _slot_for(handle: int) -> Control:
	return _warden_slot if handle == BattleState.WARDEN else _enemy_slot
