class_name Hud
extends PanelContainer


var _remaining: Label
var _clock: Label
var _hp: Label
var _restored: Label
var _threat: Label
var _act: Label


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	add_child(row)

	_remaining = UiTheme.label("", 30, UiTheme.BONE)
	row.add_child(_column(tr("ui.hud.remaining"), _remaining))

	_clock = UiTheme.label("", 16, UiTheme.INK_DIM)
	row.add_child(_column(tr("ui.hud.now"), _clock))

	_hp = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.hp"), _hp))

	_restored = UiTheme.label("", 20, UiTheme.GOLD)
	row.add_child(_column(tr("ui.hud.restored"), _restored))

	_threat = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.threat"), _threat))

	_act = UiTheme.label("", 20)
	row.add_child(_column(tr("ui.hud.act"), _act))


func _column(caption: String, value: Label) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(UiTheme.label(caption, 13, UiTheme.INK_DIM))
	box.add_child(value)
	return box


func refresh(rc: RunController) -> void:
	var run := rc.run
	_remaining.text = RunClock.format_span(run.clock.remaining)
	_clock.text = run.clock.format_clock()
	_hp.text = "%d / %d" % [run.hp, run.max_hp]
	_hp.add_theme_color_override("font_color",
		UiTheme.BLOOD if run.hp < run.max_hp * 0.35 else UiTheme.INK)
	_restored.text = RunClock.format_span(run.clock.restored)
	_threat.text = "%d / ~%d" % [run.clock.threat_level(), run.clock.balance.expected_threat_steps]
	_act.text = str(run.act)
