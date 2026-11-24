class_name MenuScreen
extends Control
## Base for full-screen menu pages: a titled panel with a Back button. Back / Esc / pad B closes it.
## T-144: the page comes in with a 0.25 s cross-fade and a 20 px slide over the live menu scene (a darker shade
## behind it), and fades out the same way when it closes.

signal closed

var content: VBoxContainer
var header: VBoxContainer   # T-218: rows that stay put above the scrolling content (Settings' tabs); fill in build_header()
var _title: String = ""
## T-267: one plain line under the title saying what the page is for ("" = none). Set it before _ready.
var subtitle: String = ""
## T-267: a page may keep a panel beside the scrolling list (the Loadout's 3D view of the sidearm): return it from
## build_side(); it stays put while `content` scrolls and rebuilds.
var side: Control = null
## T-267: build() may name the control that takes the focus when the page (re)opens; null = the first focusable.
var focus_target: Control = null
var _scroll: ScrollContainer
var _page_root: Control = null
var _closing: bool = false
var _built_key: String = ""   # T-264: page_key() at the last build
const STICK_SCROLL_PX_S: float = 1100.0   # T-264: the right stick scrolls the page (a long text has nothing to focus)


func _init(title: String = "") -> void:
	_title = title
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	MenuKit.apply_theme(self)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.015, 0.66)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
	MenuKit.keep_centred(margin, 60.0)   # T-100: centred on ultrawide
	var p: PanelContainer = MenuKit.panel()
	margin.add_child(p)
	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	p.add_child(outer)
	var head: HBoxContainer = HBoxContainer.new()
	outer.add_child(head)
	var t: Label = MenuKit.label(_title, 46, MenuKit.PAPER, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if subtitle != "":   # T-267: the title with its plain line under it
		var tcol: VBoxContainer = VBoxContainer.new()
		tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tcol.add_theme_constant_override("separation", 0)
		head.add_child(tcol)
		tcol.add_child(t)
		var st: Label = MenuKit.para(subtitle, 18, MenuKit.DIM.lightened(0.12))
		st.name = "Subtitle"
		# one line, cut with an ellipsis if it ever does not fit: a wrapping label outside the scroll reports a huge
		# height before it knows its width, and the page (anchored to the screen) then stays taller than the screen
		st.autowrap_mode = TextServer.AUTOWRAP_OFF
		st.clip_text = true
		st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tcol.add_child(st)
	else:
		head.add_child(t)
	var back: Button = MenuKit.button("Back", close, 22, "")   # close() plays ui_back
	back.custom_minimum_size = Vector2(140, 44)
	head.add_child(back)
	var rule: ColorRect = MenuKit.rule(2.0)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(rule)
	header = VBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 6)
	outer.add_child(header)
	build_header()
	header.visible = header.get_child_count() > 0
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	side = build_side()
	if side != null:   # T-267: the list on the left, the page's fixed panel on the right
		var body: HBoxContainer = HBoxContainer.new()
		body.name = "Body"
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_theme_constant_override("separation", 22)
		outer.add_child(body)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(scroll)
		body.add_child(side)
	else:
		outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	build()
	_built_key = page_key()
	_focus_start.call_deferred()
	_scroll = scroll
	_page_root = margin
	_settle_scroll()
	MenuKit.transition_in.call_deferred(margin)
	MenuMotion.stagger.call_deferred(content)   # T-267: the rows arrive one after another


## A long page (the Muster) opened part-way down: follow_focus scrolled before the layout settled. Once it has,
## start at the top and keep the focused control in view.
func _settle_scroll() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	_scroll.scroll_vertical = 0
	var f: Control = get_viewport().gui_get_focus_owner()
	# T-264: a bare spacer at the foot of a text page (Credits, the Service Record) holds the focus only so a
	# controller has something to stand on: the page opens at its top, and the right stick scrolls it
	if f != null and _scroll.is_ancestor_of(f) and f.get_class() != "Control":
		_scroll.ensure_control_visible(f)


## T-264: the right stick scrolls the page (any connected pad): pages of text have no control to walk down.
func _process(delta: float) -> void:
	if _closing or not is_instance_valid(_scroll) or not is_visible_in_tree():
		return
	var v: float = 0.0
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		pads = [0]
	for dev: int in pads:
		var a: float = Input.get_joy_axis(dev, JOY_AXIS_RIGHT_Y)
		if absf(a) > absf(v):
			v = a
	if absf(v) < 0.25:
		return
	for ch: Node in get_children():
		if ch is MenuScreen:
			return   # a page open over this one scrolls instead
	_scroll.scroll_vertical += int(v * STICK_SCROLL_PX_S * delta)


## Override (T-264): the sub-page shown now ("" = the screen has one page). rebuild() keeps the focused control's
## place only while this stays the same; a new sub-page starts at its first control.
func page_key() -> String:
	return ""


func _focus_start() -> void:
	MenuKit.quiet()
	if is_instance_valid(focus_target) and focus_target.is_inside_tree() and focus_target.focus_mode == Control.FOCUS_ALL:
		focus_target.grab_focus()
	else:
		MenuKit.focus_first(content)
	focus_target = null


## Override: fill `content`.
func build() -> void:
	pass


## Override (T-267): the panel that stays beside the scrolling list, or null for a page without one. Called once,
## before build().
func build_side() -> Control:
	return null


## Override (T-218): fill `header`, the rows above the scroll that never scroll away. Called once, before build().
func build_header() -> void:
	pass


func close() -> void:
	if _closing:
		return
	_closing = true
	AudioDirector.play_2d("ui_back", 0.0, 0.0)
	closed.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(false)
	if _page_root != null and is_inside_tree() and is_visible_in_tree():
		MenuKit.transition_out(_page_root, queue_free, 1.0, 0.16)
		var sh: Node = get_child(0)
		if sh is ColorRect:
			create_tween().tween_property(sh, "modulate:a", 0.0, 0.16)
	else:
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Removes and rebuilds the page content (after a change). `keep_focus` (T-267): the control with the same name as
## the focused one takes the focus again, so a toggle in the middle of a long list does not jump to the top;
## `animate`: the new rows stagger in (a change of step, not a toggle).
## T-264, for every other rebuild (the lobby list refreshes every 5 s, a graphics choice rebuilds the Video tab): when
## build() names no focus_target and the sub-page is the same (page_key), the focus keeps its place in order and the
## scroll stays, so a controller player is not thrown back to the top; focus that sits outside the content (the
## Back button, a tab, a page open over this one) is left where it is.
func rebuild(keep_focus: bool = false, animate: bool = false) -> void:
	var was: String = ""
	var scroll_y: int = _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var idx: int = -1
	var kind: String = ""
	if f != null and content.is_ancestor_of(f):
		idx = MenuKit.focusables(content).find(f)
		kind = f.get_class()
		if keep_focus:
			was = str(content.get_path_to(f))
	var outside: bool = f != null and not content.is_ancestor_of(f)
	for c: Node in content.get_children():
		content.remove_child(c)
		c.queue_free()
	focus_target = null
	build()
	var same_page: bool = page_key() == _built_key
	_built_key = page_key()
	var again: Control = content.get_node_or_null(was) as Control if was != "" else null
	if again != null and again.focus_mode == Control.FOCUS_ALL:
		MenuKit.quiet()
		again.grab_focus.call_deferred()
		if is_instance_valid(_scroll):
			_scroll.set_deferred("scroll_vertical", scroll_y)
	elif is_instance_valid(focus_target) or animate:
		_focus_start.call_deferred()
	elif outside:
		pass
	elif idx >= 0 and same_page:
		_refocus.call_deferred(idx, kind, scroll_y)
	else:
		_focus_start.call_deferred()
	if animate:
		MenuMotion.stagger.call_deferred(content)


func _refocus(idx: int, kind: String, scroll_at: int) -> void:
	var list: Array[Control] = MenuKit.focusables(content)
	if list.is_empty():
		return
	var c: Control = list[mini(idx, list.size() - 1)]
	if c.get_class() != kind:
		_focus_start()
		return
	if is_instance_valid(_scroll):
		_scroll.follow_focus = false   # grab_focus would scroll before the new layout has its sizes
	MenuKit.quiet()
	c.grab_focus()
	if is_instance_valid(_scroll):
		await get_tree().process_frame
		if not is_instance_valid(_scroll):
			return
		_scroll.follow_focus = true
		_scroll.scroll_vertical = scroll_at
		if is_instance_valid(c) and c.is_inside_tree():
			_scroll.ensure_control_visible(c)
