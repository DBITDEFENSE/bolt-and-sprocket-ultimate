class_name UIKit
extends RefCounted
## Front-end look for TERMS & CONDITIONS itself (hub, settings): dark contract-paper ink, a signature red,
## condensed headings. The modes keep their own looks (BSStyle, Gravelight's MenuKit).
## Fonts are the OS's (SystemFont with fallbacks): nothing bundled, nothing to license.

const INK: Color = Color("#0b0d14")
const INK2: Color = Color("#141826")
const PAPER: Color = Color("#ece6d6")
const DIM: Color = Color("#8d93a6")
const FAINT: Color = Color("#4a5064")
const SEAL: Color = Color("#e0483e")      # signature / stamp red
const GOLD: Color = Color("#ffd23e")

static var _head: SystemFont
static var _body: SystemFont


static func head_font() -> Font:
	if _head == null:
		_head = SystemFont.new()
		_head.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Arial Narrow", "Segoe UI", "Arial"])
		_head.font_weight = 700
		_head.font_stretch = 75
	return _head


static func body_font() -> Font:
	if _body == null:
		_body = SystemFont.new()
		_body.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial"])
	return _body


static func label(text: String, size: int, color: Color = PAPER, heading: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", head_font() if heading else body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func para(text: String, size: int, color: Color = PAPER, width: float = 0.0) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l


static func box(bg: Color, rim: Color = Color.TRANSPARENT, border: int = 0, radius: int = 6, pad: int = 12) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = rim
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


## A plain action button (settings footer, dialogs).
static func button(text: String, accent: Color = PAPER, size: int = 22) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", head_font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", PAPER.darkened(0.15))
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_stylebox_override("normal", box(Color(1, 1, 1, 0.04), accent.darkened(0.4), 2, 4, 18))
	b.add_theme_stylebox_override("hover", box(accent, accent, 2, 4, 18))
	b.add_theme_stylebox_override("focus", box(accent, accent, 2, 4, 18))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.2), accent, 2, 4, 18))
	return b


static func headless() -> bool:
	return DisplayServer.get_name() == "headless"
