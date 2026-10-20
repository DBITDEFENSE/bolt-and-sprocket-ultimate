class_name BSStyle
extends RefCounted
## Bright Bolt & Sprocket UI look, shared by the HUD, shop, pause menu and console: chunky navy panels with
## coloured rims, the web build's palette (index.html CSS vars: yellow #ffd23e, cyan #3ee6ff, pink #ff4d9d,
## Blartz green #7dff9a).

const YELLOW: Color = Color("#ffd23e")
const CYAN: Color = Color("#3ee6ff")
const PINK: Color = Color("#ff4d9d")
const GREEN: Color = Color("#7dff9a")
const RED: Color = Color("#ff5d5d")
const ORANGE: Color = Color("#ff9d2e")
const INK: Color = Color("#0d1220")
const PANEL: Color = Color(0.07, 0.09, 0.15, 0.88)
const DIM: Color = Color("#9fb3c8")


static func panel(rim: Color = CYAN, bg: Color = PANEL, radius: int = 14, border: int = 3) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = rim
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func label(text: String, size: int = 22, color: Color = Color.WHITE, outline: int = 6) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func bar(fill: Color, w: float, h: float) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	var bg: StyleBoxFlat = panel(Color(1, 1, 1, 0.25), Color(0, 0, 0, 0.55), 6, 2)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fg: StyleBoxFlat = StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(5)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


static func button(text: String, rim: Color = YELLOW, size: int = 22) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", panel(rim.darkened(0.35), Color(0.1, 0.13, 0.2, 0.95), 10, 2))
	b.add_theme_stylebox_override("hover", panel(rim, Color(0.16, 0.2, 0.3, 0.98), 10, 3))
	b.add_theme_stylebox_override("focus", panel(rim, Color(0.16, 0.2, 0.3, 0.98), 10, 3))
	b.add_theme_stylebox_override("pressed", panel(rim, rim.darkened(0.55), 10, 3))
	b.add_theme_stylebox_override("disabled", panel(Color(0.4, 0.4, 0.45), Color(0.08, 0.08, 0.1, 0.9), 10, 2))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.52, 0.58))
	return b


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Gameplay wants the mouse captured; only grab it in a real, focused window (never in tests).
static func capture_mouse(tree: SceneTree) -> void:
	if headless() or tree == null:
		return
	if tree.root.has_focus():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func free_mouse() -> void:
	if not headless():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
