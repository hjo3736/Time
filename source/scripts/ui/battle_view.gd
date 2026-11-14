class_name BattleView
extends Control


signal card_chosen(hand_index: int, target: int)
signal turn_ended

signal pile_requested(pile: int)

enum Pile { DRAW, DISCARD, EXHAUST }

## The layout is the scene; this script fills it and runs the hand. Each Askew
## is an EnemyPanel, made fresh with the stage.
const SCENE := preload("res://source/scenes/ui/battle_view.tscn")

const HAND_Y := 96.0
const FAN_SPREAD := 0.055

var _rc: RunController
@onready var _hand_layer := %HandLayer as Control
@onready var _orb_value := %OrbValue as Label
@onready var _orb_panel := %Orb as Panel
@onready var _draw_label := %DrawPile as Button
@onready var _discard_label := %DiscardPile as Button
@onready var _exhaust_label := %ExhaustPile as Button
@onready var _turn_label := %TurnLabel as Label
@onready var _end_turn := %EndTurn as Button
var _selected := -1

var _enemy_panels: Array[Dictionary] = []
var _drag_index := -1
var _drag_at := Vector2.ZERO
var _drag_target := -1
var _cards: Array[CardNode] = []

var _preview_target := -1

@onready var _punch := %Punch as Punch
var _watching: BattleState = null
var _landed := 0
@onready var _player_node := %Player as Control
@onready var _player_slot := %PlayerSlot as Control
@onready var _enemy_slot := %EnemySlot as Control


## Always make one through here, never BattleView.new(): new() is the script
## without the scene.
static func create() -> BattleView:
	return SCENE.instantiate() as BattleView


func _ready() -> void:
	UiTheme.localize(self)
	_draw_label.pressed.connect(func() -> void: pile_requested.emit(Pile.DRAW))
	_discard_label.pressed.connect(func() -> void: pile_requested.emit(Pile.DISCARD))
	_exhaust_label.pressed.connect(func() -> void: pile_requested.emit(Pile.EXHAUST))
	_end_turn.pressed.connect(func() -> void:
		_selected = -1
		turn_ended.emit())
	resized.connect(_on_resized)


func _on_resized() -> void:
	if _rc != null and _rc.battle != null and visible:
		_rebuild_hand(_rc)


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
	_fill_player(rc)

	var row := %EnemyRow as HBoxContainer
	ChoiceView._clear(row)
	_enemy_panels.clear()
	for handle in rc.battle.enemy_handles():
		var panel := EnemyPanel.create(rc, handle, _selected >= 0)
		panel.target_chosen.connect(_target_chosen)
		row.add_child(panel)
		_enemy_panels.append({"handle": handle, "node": panel})


func _fill_player(rc: RunController) -> void:
	var w := rc.battle.player()
	# The name is the character's, so a second character is not a second scene.
	(_player_node.get_node("Title") as Label).text = tr(w.name_key)
	var bar := %Health as ProgressBar
	bar.max_value = maxi(1, w.max_hp)
	bar.value = w.hp
	(%HealthText as Label).text = "%d / %d" % [w.hp, w.max_hp]

	var block := %Block as Label
	block.text = tr("ui.battle.block").format({"n": w.block})
	block.visible = w.block > 0

	var statuses := %Statuses as VBoxContainer
	ChoiceView._clear(statuses)
	for status in w.statuses:
		statuses.add_child(UiTheme.label("%s %d" % [tr("status.%s" % status), w.status(status)], 13, UiTheme.GOLD))
	statuses.visible = statuses.get_child_count() > 0


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
		var node := CardNode.create(card, i, card.cost_minutes() <= rc.battle.turn_budget, i == _selected)
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
		node.show_live_text(card.rules_text_live(_rc.battle, BattleState.PLAYER, _preview_target))


func aimed_damage() -> int:
	if _drag_index < 0 or _drag_target < 0 or _rc == null or _rc.battle == null:
		return 0
	var card := _rc.battle.card_at(_drag_index)
	if card == null:
		return 0

	var attacker := _rc.battle.player()
	var victim: Stats = _rc.battle.combatants[_drag_target]
	var total := 0
	for effect in card.effects:
		if effect is EffectDamage:
			var d := effect as EffectDamage
			total += StatusRules.modified_damage(attacker, victim, d.amount) * maxi(1, d.times)
	return total


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

	var hurt := handle == BattleState.PLAYER
	var tint := UiTheme.BLOOD if hurt else UiTheme.BONE
	var where := Rect2(panel.global_position - global_position, panel.size)
	_punch.land(where, amount, tint, waited)
	_punch.shake(_slot_for(handle), minf(4.0 + float(amount) * 0.7, 18.0), waited)


func _panel_for(handle: int) -> Control:
	if handle == BattleState.PLAYER:
		return _player_node
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
	return _player_slot if handle == BattleState.PLAYER else _enemy_slot
