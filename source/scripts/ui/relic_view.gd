class_name RelicView
extends OverlayView


const SCENE := preload("res://source/scenes/ui/relic_view.tscn")


## Always make one through here, never RelicView.new(): new() is the script
## without the scene it shares with the other overlays.
static func create() -> RelicView:
	return SCENE.instantiate() as RelicView


## What the Warden is carrying, as opposed to the compendium's list of everything
## that exists. A relic the player cannot read is a passive they cannot plan
## around, and every one of these changes a number they are being asked to budget.
func show_relics(run: RunState, db: RelicDatabase) -> void:
	set_compact(false)
	clear_body()
	relabel_chrome()

	var carried := _carried(run, db)
	heading(tr("ui.relics.title").format({"n": carried.size()}))

	if carried.is_empty():
		var none := UiTheme.label(tr("ui.relics.empty"), 18, UiTheme.INK_DIM)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body().add_child(none)
		return

	for relic in carried:
		body().add_child(_row(relic))


## In the order they were picked up, which is also the order their modifiers
## chain in — see RunState.relic_room_cost and its neighbours.
func _carried(run: RunState, db: RelicDatabase) -> Array[Relic]:
	var out: Array[Relic] = []
	for id in run.relics:
		var relic := db.get_relic(id)
		if relic != null:
			out.append(relic)
	return out


func _row(relic: Relic) -> PanelContainer:
	var frame := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	frame.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UiTheme.label(relic.display_name(), 20, UiTheme.GOLD))
	var tag := UiTheme.label(tr(RARITY_KEYS[relic.rarity]), 13, UiTheme.INK_DIM)
	tag.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(tag)
	column.add_child(top)

	var text := UiTheme.label(relic.description(), 16, UiTheme.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(text)

	return frame


const RARITY_KEYS := {
	Relic.Rarity.COMMON: "ui.relics.common",
	Relic.Rarity.UNCOMMON: "ui.relics.uncommon",
	Relic.Rarity.RARE: "ui.relics.rare",
	Relic.Rarity.BOSS: "ui.relics.boss",
}
