class_name UiTheme
extends RefCounted


const BG := Color("15151b")
const PANEL := Color("1e1e26")
const PANEL_HI := Color("2a2a36")
const INK := Color("ded8ca")
const INK_DIM := Color("8a8276")
const BONE := Color("f2eee6")
const GOLD := Color("d9a441")
const BLOOD := Color("a34b4b")
const GREEN := Color("6f8f5f")

const GAME_FONT := "res://source/assets/font/DungGeunMo.ttf"

const FONT_GRID := 16


static func size_for(requested: int) -> int:
	return maxi(FONT_GRID, roundi(float(requested) / FONT_GRID) * FONT_GRID)


static func font() -> Font:
	if ResourceLoader.exists(GAME_FONT):
		var loaded := ResourceLoader.load(GAME_FONT)
		if loaded is FontFile:
			return _as_pixel_font(loaded as FontFile)
	if FileAccess.file_exists(ProjectSettings.globalize_path(GAME_FONT)):
		var f := FontFile.new()
		f.load_dynamic_font(ProjectSettings.globalize_path(GAME_FONT))
		return _as_pixel_font(f)
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Gulim", "sans-serif"])
	return fallback


static func _as_pixel_font(f: FontFile) -> FontFile:
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	f.multichannel_signed_distance_field = false
	return f


static func build() -> Theme:
	var t := Theme.new()
	var f := font()
	t.default_font = f
	t.default_font_size = size_for(18)

	var button := StyleBoxFlat.new()
	button.bg_color = PANEL
	button.border_color = Color(INK_DIM, 0.5)
	button.set_border_width_all(1)
	button.set_corner_radius_all(3)
	button.set_content_margin_all(10)

	var hover := button.duplicate()
	hover.bg_color = PANEL_HI
	hover.border_color = GOLD

	var pressed := button.duplicate()
	pressed.bg_color = PANEL_HI

	var disabled := button.duplicate()
	disabled.bg_color = Color(PANEL, 0.4)
	disabled.border_color = Color(INK_DIM, 0.2)

	t.set_stylebox("normal", "Button", button)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", BONE)
	t.set_color("font_disabled_color", "Button", Color(INK_DIM, 0.5))
	t.set_color("font_color", "Label", INK)

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", panel)

	return t


static func label(text: String, size: int = 18, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_for(size))
	l.add_theme_color_override("font_color", color)
	return l
