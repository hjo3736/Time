class_name UiTheme
extends RefCounted


## The look lives in this file, edited in the inspector: fonts, the button and
## panel boxes, and the palette under the `Palette` type. Nothing here builds a
## style any more; it only reads one.
const THEME_PATH := "res://source/assets/theme/ui_theme.tres"
const GAME_FONT := "res://source/assets/font/DungGeunMo.ttf"

const FONT_GRID := 16

static var _theme: Theme = load(THEME_PATH)

# The palette, read once from the theme. Kept under the names the views already
# use; they read like constants because nothing should write them.
static var BG := _palette(&"bg")
static var PANEL := _palette(&"panel")
static var PANEL_HI := _palette(&"panel_hi")
static var INK := _palette(&"ink")
static var INK_DIM := _palette(&"ink_dim")
static var BONE := _palette(&"bone")
static var GOLD := _palette(&"gold")
static var BLOOD := _palette(&"blood")
static var GREEN := _palette(&"green")


static func _palette(key: StringName) -> Color:
	return _theme.get_color(key, &"Palette")


static func size_for(requested: int) -> int:
	return maxi(FONT_GRID, roundi(float(requested) / FONT_GRID) * FONT_GRID)


## The pixel settings — no antialiasing, hinting or subpixel positioning — are
## on the font's import, so the editor draws it the way the game does.
static func font() -> Font:
	return _theme.default_font


static func build() -> Theme:
	return _theme


## Labels and buttons in a scene carry their strings.csv key as their text, so the
## editor shows the words. Left to auto-translate, `.text` would still read the
## key at runtime, so this swaps the key for the words and keeps the key in meta:
## calling it again after a language change translates from the key, not from the
## words of the last language. Text that is not a key — anything code already
## wrote — is left alone.
static func localize(root: Node) -> void:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node in nodes:
		if not (node is Label or node is Button):
			continue
		var key := String(node.get_meta(&"text_key", node.text))
		if key == "" or (not node.has_meta(&"text_key") and TranslationServer.translate(key) == key):
			continue
		node.set_meta(&"text_key", key)
		node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		node.text = TranslationServer.translate(key)


static func label(text: String, size: int = 18, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_for(size))
	l.add_theme_color_override("font_color", color)
	return l
