class_name SettingsMenu
extends Control
## The shared Settings screen (hub and the Bolt & Sprocket pause menu). Built entirely from
## data/settings_page.json; reads and writes the core Settings autoload, which applies each change at once and
## mirrors Gravelight's copies. Tabs: Q/E or LB/RB (or click). Back: Esc / B / the BACK button (saves).
## Works while the tree is paused (process_mode ALWAYS).

signal closed

const ROW_H: float = 58.0
const CTRL_W: float = 430.0

var page: Dictionary = {}
var _tab: int = 0
var _tab_buttons: Array[Button] = []
var _rows_box: VBoxContainer
var _scroll: ScrollContainer
var _note: Label
var _back: Button
var _first_focus: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	page = Data.table("settings_page")
	Settings.pull_from_gravelight()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.INK2, UIKit.FAINT, 1, 8, 34))
	panel.custom_minimum_size = Vector2(1180, 820)
	center.add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	# header: title + seal line
	var head: HBoxContainer = HBoxContainer.new()
	v.add_child(head)
	head.add_child(UIKit.label(str(page.get("title", "SETTINGS")), 64, UIKit.PAPER, true))
	var sp: Control = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_note = UIKit.label(str(page.get("hint", "")), 17, UIKit.DIM)
	_note.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_note)
	var rule: ColorRect = ColorRect.new()
	rule.color = UIKit.SEAL
	rule.custom_minimum_size = Vector2(0, 3)
	v.add_child(rule)
	# tabs
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var tab_defs: Array = page.get("tabs", [])
	for i: int in tab_defs.size():
		var tb: Button = Button.new()
		tb.text = str((tab_defs[i] as Dictionary)["head"])
		tb.toggle_mode = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_font_override("font", UIKit.head_font())
		tb.add_theme_font_size_override("font_size", 26)
		tb.add_theme_color_override("font_color", UIKit.DIM)
		tb.add_theme_color_override("font_hover_color", UIKit.PAPER)
		tb.add_theme_color_override("font_pressed_color", UIKit.INK)
		tb.add_theme_color_override("font_hover_pressed_color", UIKit.INK)
		tb.add_theme_stylebox_override("normal", UIKit.box(Color(1, 1, 1, 0.03), Color.TRANSPARENT, 0, 4, 22))
		tb.add_theme_stylebox_override("hover", UIKit.box(Color(1, 1, 1, 0.08), Color.TRANSPARENT, 0, 4, 22))
		tb.add_theme_stylebox_override("pressed", UIKit.box(UIKit.PAPER, Color.TRANSPARENT, 0, 4, 22))
		tb.add_theme_stylebox_override("hover_pressed", UIKit.box(UIKit.PAPER, Color.TRANSPARENT, 0, 4, 22))
		tb.pressed.connect(show_tab.bind(i))
		tabs.add_child(tb)
		_tab_buttons.append(tb)
	var keys_hint: Label = UIKit.label("Q / E  ·  LB / RB", 16, UIKit.FAINT)
	keys_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	keys_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(keys_hint)
	# rows
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	v.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows_box)
	# footer
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	var reset: Button = UIKit.button(str(page.get("reset", "RESTORE DEFAULTS")), UIKit.DIM, 22)
	reset.pressed.connect(_on_reset)
	foot.add_child(reset)
	var sp2: Control = Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	_back = UIKit.button(str(page.get("back", "BACK")), UIKit.SEAL, 26)
	_back.custom_minimum_size.x = 220
	_back.pressed.connect(close)
	foot.add_child(_back)
	show_tab(0)


func show_tab(i: int) -> void:
	var tab_defs: Array = page.get("tabs", [])
	if tab_defs.is_empty():
		return
	_tab = wrapi(i, 0, tab_defs.size())
	for j: int in _tab_buttons.size():
		_tab_buttons[j].set_pressed_no_signal(j == _tab)
	for c: Node in _rows_box.get_children():
		_rows_box.remove_child(c)
		c.queue_free()
	_first_focus = null
	for r: Variant in (tab_defs[_tab] as Dictionary).get("rows", []):
		_rows_box.add_child(_make_row(r as Dictionary))
	_scroll.scroll_vertical = 0
	if _first_focus != null:
		_first_focus.grab_focus.call_deferred()


func close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()
		return
	var prev: bool = false
	var next: bool = false
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		prev = (event as InputEventKey).physical_keycode == KEY_Q
		next = (event as InputEventKey).physical_keycode == KEY_E
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		prev = (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER
		next = (event as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER
	if prev or next:
		get_viewport().set_input_as_handled()
		show_tab(_tab + (1 if next else -1))


# --- rows ---------------------------------------------------------------------------------------------------

func _make_row(r: Dictionary) -> Control:
	var key: String = str(r.get("key", ""))
	var row: PanelContainer = PanelContainer.new()
	var idle: StyleBoxFlat = UIKit.box(Color(1, 1, 1, 0.025), Color.TRANSPARENT, 0, 4, 16)
	var lit: StyleBoxFlat = UIKit.box(Color(1, 1, 1, 0.07), UIKit.SEAL, 0, 4, 16)
	lit.border_width_left = 4
	row.add_theme_stylebox_override("panel", idle)
	row.custom_minimum_size.y = ROW_H
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	var name_l: Label = UIKit.label(str(r.get("label", key)), 22, UIKit.PAPER)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(name_l)
	var ctrl: Control
	match str(r.get("type", "")):
		"range":
			ctrl = _range(r, key)
		"toggle":
			ctrl = _toggle(key)
		"cycle":
			ctrl = _cycle(r, key)
		_:
			ctrl = Control.new()
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ctrl is Button and (ctrl as Button).toggle_mode:
		var slot: HBoxContainer = HBoxContainer.new()   # compact ON/OFF pill, right-aligned in the control column
		slot.custom_minimum_size.x = CTRL_W
		slot.alignment = BoxContainer.ALIGNMENT_END
		slot.add_child(ctrl)
		slot.set_meta(&"focus", ctrl)
		ctrl.custom_minimum_size.x = 140
		ctrl = slot
	else:
		ctrl.custom_minimum_size.x = CTRL_W
	h.add_child(ctrl)
	var focus_target: Control = ctrl.get_meta(&"focus", ctrl) as Control
	focus_target.focus_entered.connect(func() -> void: row.add_theme_stylebox_override("panel", lit))
	focus_target.focus_exited.connect(func() -> void: row.add_theme_stylebox_override("panel", idle))
	row.mouse_entered.connect(func() -> void: focus_target.grab_focus())
	if _first_focus == null:
		_first_focus = focus_target
	return row


func _range(r: Dictionary, key: String) -> Control:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var s: HSlider = HSlider.new()
	s.min_value = float(r.get("min", 0.0))
	s.max_value = float(r.get("max", 1.0))
	s.step = float(r.get("step", 0.05))
	s.value = float(Settings.get_value(key, s.min_value))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_ALL
	var grab: StyleBoxFlat = UIKit.box(UIKit.SEAL, Color.TRANSPARENT, 0, 3, 0)
	var track: StyleBoxFlat = UIKit.box(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	s.add_theme_icon_override("grabber", _knob(UIKit.PAPER))
	s.add_theme_icon_override("grabber_highlight", _knob(Color.WHITE))
	h.add_child(s)
	var val: Label = UIKit.label(_fmt(s.value, str(r.get("fmt", ""))), 22, UIKit.PAPER, true)
	val.custom_minimum_size.x = 84
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	var fmt: String = str(r.get("fmt", ""))
	var is_int: bool = fmt == "deg" or fmt == "int"
	s.value_changed.connect(func(x: float) -> void:
		val.text = _fmt(x, fmt)
		Settings.set_value(key, int(roundf(x)) if is_int else snappedf(x, 0.001), false))
	h.set_meta(&"focus", s)
	return h


func _toggle(key: String) -> Control:
	var b: Button = Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.button_pressed = bool(Settings.get_value(key, false))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UIKit.head_font())
	b.add_theme_font_size_override("font_size", 22)
	_style_toggle(b)
	b.toggled.connect(func(on: bool) -> void:
		_style_toggle(b)
		Settings.set_value(key, on, false))
	return b


func _style_toggle(b: Button) -> void:
	b.text = "ON" if b.button_pressed else "OFF"
	var c: Color = UIKit.SEAL if b.button_pressed else UIKit.FAINT
	var fill: Color = Color(c, 0.9) if b.button_pressed else Color(1, 1, 1, 0.04)
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var box: StyleBoxFlat = UIKit.box(fill, c.lightened(0.25) if st in ["hover", "focus", "hover_pressed"] else c, 2, 4, 16)
		b.add_theme_stylebox_override(st, box)
	for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(fc, UIKit.PAPER if b.button_pressed else UIKit.DIM)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _cycle(r: Dictionary, key: String) -> Control:
	var opts: Array = r.get("options", [])
	var labels: Array = r.get("labels", opts)
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", UIKit.head_font())
	b.add_theme_font_size_override("font_size", 22)
	for st: String in ["normal", "pressed"]:
		b.add_theme_stylebox_override(st, UIKit.box(Color(1, 1, 1, 0.04), UIKit.FAINT, 2, 4, 16))
	for st: String in ["hover", "focus"]:
		b.add_theme_stylebox_override(st, UIKit.box(Color(1, 1, 1, 0.08), UIKit.PAPER, 2, 4, 16))
	b.add_theme_color_override("font_color", UIKit.PAPER)
	b.add_theme_color_override("font_hover_color", UIKit.PAPER)
	b.add_theme_color_override("font_focus_color", UIKit.PAPER)
	var idx: Array[int] = [maxi(0, _index_of(opts, Settings.get_value(key, opts[0] if not opts.is_empty() else null)))]
	var show: Callable = func() -> void:
		b.text = "◀   %s   ▶" % str(labels[idx[0]] if idx[0] < labels.size() else opts[idx[0]])
	show.call()
	var step: Callable = func(d: int) -> void:
		if opts.is_empty():
			return
		idx[0] = wrapi(idx[0] + d, 0, opts.size())
		show.call()
		Settings.set_value(key, opts[idx[0]], false)
	b.pressed.connect(func() -> void: step.call(1))
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			step.call(-1)   # right-click steps back
			b.accept_event()
		elif e.is_action_pressed(&"ui_left"):
			step.call(-1)
			b.accept_event()
		elif e.is_action_pressed(&"ui_right"):
			step.call(1)
			b.accept_event())
	return b


func _on_reset() -> void:
	Settings.reset_to_defaults()
	show_tab(_tab)
	_note.text = str(page.get("reset_done", ""))


static func _index_of(opts: Array, v: Variant) -> int:
	for i: int in opts.size():
		if str(opts[i]) == str(v) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and typeof(opts[i]) in [TYPE_INT, TYPE_FLOAT] and is_equal_approx(float(opts[i]), float(v))):
			return i
	return -1


static func _fmt(v: float, fmt: String) -> String:
	match fmt:
		"pct":
			return "%d%%" % roundi(v * 100.0)
		"x2":
			return "%.2f" % v
		"deg":
			return "%d°" % roundi(v)
		"int":
			return str(roundi(v))
	return str(snappedf(v, 0.01))


static func _knob(c: Color) -> ImageTexture:
	var img: Image = Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y: int in 22:
		for x: int in 22:
			var d: float = Vector2(x - 10.5, y - 10.5).length()
			img.set_pixel(x, y, Color(c, clampf(10.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
