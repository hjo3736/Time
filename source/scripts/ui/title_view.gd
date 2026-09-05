class_name TitleView
extends Control


signal run_requested
signal continue_requested
signal compendium_requested
signal settings_requested

const TITLE := "DECKBOUND"

const VERSION_KEY := "ui.title.version"

var _continue_item: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = UiTheme.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var plate := VBoxContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	plate.position = Vector2(0, -90)
	plate.add_theme_constant_override("separation", 12)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	var name_label := UiTheme.label(TITLE, 64, UiTheme.BONE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(name_label)

	var rule := ColorRect.new()
	rule.color = UiTheme.GOLD
	rule.custom_minimum_size = Vector2(360, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.add_child(rule)

	var menu := VBoxContainer.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu.position = Vector2(110, -70)
	menu.add_theme_constant_override("separation", 2)
	add_child(menu)

	_continue_item = _item(tr("ui.title.continue"), func() -> void: continue_requested.emit())
	menu.add_child(_continue_item)
	menu.add_child(_item(tr("ui.title.new_run"), func() -> void: run_requested.emit()))
	menu.add_child(_item(tr("ui.title.compendium"), func() -> void: compendium_requested.emit()))
	menu.add_child(_item(tr("ui.title.settings"), func() -> void: settings_requested.emit()))
	menu.add_child(_item(tr("ui.title.quit"), func() -> void: get_tree().quit()))

	var version := UiTheme.label(tr(VERSION_KEY), 16, Color(UiTheme.INK_DIM, 0.7))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position = Vector2(24, -14)
	add_child(version)


func set_continue_available(available: bool) -> void:
	_continue_item.visible = available


func _item(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(300, 52)
	button.add_theme_font_size_override("font_size", UiTheme.size_for(28))

	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(UiTheme.BONE, 0.9)
	lit.set_corner_radius_all(4)
	lit.content_margin_left = 16
	lit.content_margin_right = 16

	var bare := StyleBoxEmpty.new()
	bare.content_margin_left = 16
	bare.content_margin_right = 16

	button.add_theme_stylebox_override("normal", bare)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_color_override("font_color", UiTheme.INK)
	button.add_theme_color_override("font_hover_color", UiTheme.BG)
	button.add_theme_color_override("font_pressed_color", UiTheme.BG)
	button.pressed.connect(action)
	return button
