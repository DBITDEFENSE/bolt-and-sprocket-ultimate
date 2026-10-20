class_name MenuKit
extends RefCounted
## Shared look for the menus: ledger-paper colors, stencil + typewriter fonts, and widget builders.
## Every builder returns a focusable control so menus work with a controller.

const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const DIM: Color = Color(0.62, 0.6, 0.56)
const VIOLET: Color = Color(0.62, 0.45, 0.85)
const GOLD: Color = Color(0.95, 0.86, 0.55)

static var _stamp: SystemFont
static var _type: SystemFont


static func stamp_font() -> SystemFont:
	if _stamp == null:
		_stamp = SystemFont.new()
		_stamp.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	return _stamp


static func type_font() -> SystemFont:
	if _type == null:
		_type = SystemFont.new()
		_type.font_names = PackedStringArray(["Courier New", "Consolas"])
		_type.font_weight = 700
	return _type


static func label(text: String, size: int = 22, color: Color = PAPER, stamp: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", stamp_font() if stamp else type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	return l


static func para(text: String, size: int = 18, color: Color = PAPER) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## `sound`: the bank key played on press ("ui_click", "ui_confirm", "ui_back"; "" for none).
static func button(text: String, cb: Callable, size: int = 24, sound: String = "ui_click") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", type_font())
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, size * 1.9)
	b.focus_mode = Control.FOCUS_ALL
	if sound != "":
		b.pressed.connect(func() -> void: AudioDirector.play_2d(sound, 0.0, 0.0))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.86)
	sb.border_color = Color(0.4, 0.33, 0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	return p


static func bar(value: float, width: float = 320.0, color: Color = INK) -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.max_value = 1.0
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(width, 10)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	pb.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	pb.add_theme_stylebox_override("background", bg)
	return pb


static func row(label_text: String, control: Control, label_width: float = 300.0) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l: Label = label(label_text, 20)
	l.custom_minimum_size = Vector2(label_width, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


static func slider(lo: float, hi: float, step: float, value: float, cb: Callable) -> HSlider:
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(280, 28)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(cb)
	return s


static func check(text: String, value: bool, cb: Callable) -> CheckButton:
	var c: CheckButton = CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_override("font", type_font())
	c.add_theme_font_size_override("font_size", 20)
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(cb)
	return c


static func options(items: PackedStringArray, selected: int, cb: Callable) -> OptionButton:
	var o: OptionButton = OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.selected = clampi(selected, 0, items.size() - 1)
	o.add_theme_font_override("font", type_font())
	o.add_theme_font_size_override("font_size", 20)
	o.focus_mode = Control.FOCUS_ALL
	o.item_selected.connect(cb)
	return o


## Grabs focus on the first focusable control under `root` (for controller users).
static func focus_first(root: Node) -> void:
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree():
			c.grab_focus()
			return
