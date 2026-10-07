class_name Hud
extends PanelContainer


var _remaining: Label
var _date: Label
var _deadline: Label
var _sky: Label
var _hp: Label
var _restored: Label
var _threat: Label
var _act: Label
var _relics: Label

const SKY_KEYS := {
	RunClock.Daytime.MORNING: "time.sky_morning",
	RunClock.Daytime.DAY: "time.sky_day",
	RunClock.Daytime.EVENING: "time.sky_evening",
	RunClock.Daytime.NIGHT: "time.sky_night",
}

const SKY_TINTS := {
	RunClock.Daytime.MORNING: UiTheme.BONE,
	RunClock.Daytime.DAY: UiTheme.GOLD,
	RunClock.Daytime.EVENING: UiTheme.BLOOD,
	RunClock.Daytime.NIGHT: UiTheme.INK_DIM,
}

var _shown := 0.0
var _running := false
var _flow: Tween


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)

	_date = UiTheme.label("", 28, UiTheme.BONE)
	_deadline = UiTheme.label("", 13, UiTheme.INK_DIM)
	var when := VBoxContainer.new()
	when.add_theme_constant_override("separation", 2)
	when.add_child(UiTheme.label(tr("ui.hud.now"), 13, UiTheme.INK_DIM))
	when.add_child(_date)
	when.add_child(_deadline)
	row.add_child(when)

	_sky = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.sky"), _sky))

	_remaining = UiTheme.label("", 20, UiTheme.INK_DIM)
	row.add_child(_column(tr("ui.hud.remaining"), _remaining))

	_hp = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.hp"), _hp))

	_restored = UiTheme.label("", 20, UiTheme.GOLD)
	row.add_child(_column(tr("ui.hud.restored"), _restored))

	_threat = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.threat"), _threat))

	_act = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.act"), _act))

	_relics = UiTheme.label("", 20, UiTheme.GOLD)
	row.add_child(_column(tr("ui.hud.relics"), _relics))


func _column(caption: String, value: Label) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(UiTheme.label(caption, 13, UiTheme.INK_DIM))
	box.add_child(value)
	return box


func spent_so_far(rc: RunController) -> int:
	var battle := rc.battle
	if battle == null or battle.phase != BattleState.Phase.PLAYER_TURN:
		return 0
	var tick := battle.turn_cost_now()
	var committed := clampi(battle.turn_budget_max - battle.turn_budget, 0, tick)
	# Anything the turn bills beyond the budget cannot be played out of, so it is
	# shown as already gone rather than arriving as a jump when the turn ends.
	var unavoidable := maxi(0, tick - battle.turn_budget_max)
	return mini(tick, committed + unavoidable)


func shown_target(rc: RunController) -> int:
	return maxi(0, rc.run.clock.remaining - spent_so_far(rc))


func refresh(rc: RunController) -> void:
	var run := rc.run
	_flow_to(shown_target(rc))
	_date.text = run.clock.format_clock()
	_deadline.text = tr("time.deadline").format({"date": run.clock.format_deadline()})
	var now := run.clock.daytime()
	_sky.text = tr(SKY_KEYS[now])
	_sky.add_theme_color_override("font_color", SKY_TINTS[now])
	_hp.text = "%d / %d" % [run.hp, run.max_hp]
	_hp.add_theme_color_override("font_color",
		UiTheme.BLOOD if run.hp < run.max_hp * 0.35 else UiTheme.INK)
	_restored.text = RunClock.format_span(run.clock.restored)
	_threat.text = "%d / ~%d" % [run.clock.threat_level(), run.clock.balance.expected_threat_steps]
	_act.text = str(run.act)
	_relics.text = str(run.relics.size())


func _flow_to(target: int) -> void:
	if not _running:
		_running = true
		_shown = float(target)
		_write(target)
		return
	if is_equal_approx(_shown, float(target)):
		return
	if _flow != null and _flow.is_valid():
		_flow.kill()
	var far := absf(_shown - float(target)) / float(Balance.MINUTES_PER_HOUR)
	_flow = create_tween()
	_flow.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flow.tween_method(_write_float, _shown, float(target),
		clampf(0.16 + far * 0.14, 0.16, 0.7))


func _write_float(minutes: float) -> void:
	_shown = minutes
	_write(roundi(minutes))


func _write(minutes: int) -> void:
	_remaining.text = RunClock.format_span(minutes)
