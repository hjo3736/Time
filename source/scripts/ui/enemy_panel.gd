class_name EnemyPanel
extends VBoxContainer


signal target_chosen(handle: int)

## The layout is the scene; this script only fills it. One per Askew in the
## fight, rebuilt with the stage.
const SCENE := preload("res://source/scenes/ui/enemy_panel.tscn")

var handle := -1


## Always make one through here, never EnemyPanel.new(): new() is the script
## without the scene.
static func create(rc: RunController, p_handle: int, picking: bool) -> EnemyPanel:
	var panel := SCENE.instantiate() as EnemyPanel
	panel.fill(rc, p_handle, picking)
	return panel


func fill(rc: RunController, p_handle: int, picking: bool) -> void:
	handle = p_handle
	var enemy: Combatant = rc.battle.combatants[handle]

	var intent := %Intent as Label
	intent.text = intent_text(rc, handle, enemy)
	intent.add_theme_color_override("font_color", intent_colour(rc, handle, enemy))

	# Whatever else it does this turn, one line each, under the intent it leads
	# with. Everything it is about to do is on screen before it does any of it.
	var extras := %Extras as VBoxContainer
	ChoiceView._clear(extras)
	if enemy.behavior != null:
		for extra in enemy.behavior.extra_intents(rc.battle, handle):
			var also := UiTheme.label(intent_text(rc, handle, enemy, extra), 17, UiTheme.BLOOD)
			also.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			extras.add_child(also)
	extras.visible = extras.get_child_count() > 0

	# What an enemy's behaviour does is not written out here. The fight shows the
	# intent and the numbers; the rule behind them is the compendium's to state,
	# and the player's to work out.
	(%Title as Label).text = tr(enemy.name_key)

	var bar := %Health as ProgressBar
	bar.max_value = maxi(1, enemy.max_hp)
	bar.value = enemy.hp
	(%HealthText as Label).text = "%d / %d" % [enemy.hp, enemy.max_hp]

	var shut := %OutOfReach as Label
	shut.text = tr("ui.battle.out_of_reach")
	shut.visible = not rc.battle.reaches(handle)

	var block := %Block as Label
	block.text = tr("ui.battle.block").format({"n": enemy.block})
	block.visible = enemy.block > 0

	var statuses := %Statuses as VBoxContainer
	ChoiceView._clear(statuses)
	for status in enemy.statuses:
		var s := UiTheme.label("%s %d" % [tr("status.%s" % status), enemy.status(status)], 13, UiTheme.GOLD)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		statuses.add_child(s)
	statuses.visible = statuses.get_child_count() > 0

	var pick := %UseHere as Button
	pick.text = tr("ui.battle.use_here")
	pick.visible = picking


func _ready() -> void:
	UiTheme.localize(self)
	(%UseHere as Button).pressed.connect(func() -> void: target_chosen.emit(handle))


static func intent_amount(rc: RunController, p_handle: int, enemy: Combatant,
		intent: EnemyIntent) -> int:
	var amount := intent.amount
	if enemy.behavior != null:
		amount = enemy.behavior.outgoing_amount(rc.battle, p_handle, intent)
	amount = roundi(amount * enemy.outgoing_multiplier)
	if intent.kind == EnemyIntent.Kind.ATTACK:
		amount = StatusRules.modified_damage(enemy, rc.battle.warden(), amount)
	return amount


static func intent_text(rc: RunController, p_handle: int, enemy: Combatant,
		shown: EnemyIntent = null) -> String:
	var intent := shown if shown != null else enemy.current_intent()
	if intent == null:
		return TranslationServer.translate("ui.battle.intent_none")
	var amount := intent_amount(rc, p_handle, enemy, intent)
	match intent.kind:
		EnemyIntent.Kind.ATTACK:
			var times := "" if intent.times <= 1 else TranslationServer.translate(
				"ui.battle.intent_times").format({"n": intent.times})
			return TranslationServer.translate("ui.battle.intent_attack").format(
				{"n": amount, "times": times})
		EnemyIntent.Kind.BLOCK:
			return TranslationServer.translate("ui.battle.intent_block").format({"n": amount})
		EnemyIntent.Kind.STATUS:
			return TranslationServer.translate("ui.battle.intent_status").format({
				"name": TranslationServer.translate("status.%s" % intent.status),
				"n": intent.stacks})
		EnemyIntent.Kind.GROW:
			return TranslationServer.translate("ui.battle.intent_grow").format({"n": intent.stacks})
		EnemyIntent.Kind.DRAG:
			# Not `amount`: that has Threat on it, and the grip is not a blow.
			var left := intent.amount
			if enemy.behavior != null:
				left = enemy.behavior.outgoing_amount(rc.battle, p_handle, intent)
			if left <= 0:
				return TranslationServer.translate("ui.battle.intent_drag_lost")
			return TranslationServer.translate("ui.battle.intent_drag").format({"n": left})
		EnemyIntent.Kind.BEAR:
			return TranslationServer.translate("ui.battle.intent_bear").format({
				"name": TranslationServer.translate("status.%s" % intent.status),
				"n": intent.stacks})
		EnemyIntent.Kind.WAIT:
			return TranslationServer.translate("ui.battle.intent_wait")
	return TranslationServer.translate("ui.battle.intent_none")


## Green when what is shown is less than what it would strike for unmodified, so
## a blow the player has already softened reads as softened.
static func intent_colour(rc: RunController, p_handle: int, enemy: Combatant) -> Color:
	var intent := enemy.current_intent()
	if intent == null or intent.kind != EnemyIntent.Kind.ATTACK:
		return UiTheme.BLOOD
	var raw := intent.amount
	if enemy.behavior != null:
		raw = enemy.behavior.outgoing_amount(rc.battle, p_handle, intent)
	raw = roundi(raw * enemy.outgoing_multiplier)
	var shown := intent_amount(rc, p_handle, enemy, intent)
	if shown < raw:
		return UiTheme.GREEN
	return UiTheme.BLOOD
