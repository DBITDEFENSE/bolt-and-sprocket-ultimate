class_name MenuScreen
extends Control
## Base for full-screen menu pages: a titled panel with a Back button. Back / Esc / pad B closes it.
## T-144: the page comes in with a 0.25 s cross-fade and a 20 px slide over the live menu scene (a darker shade
## behind it), and fades out the same way when it closes.

signal closed

var content: VBoxContainer
var header: VBoxContainer   # T-218: rows that stay put above the scrolling content (Settings' tabs); fill in build_header()
var _title: String = ""
var _scroll: ScrollContainer
var _page_root: Control = null
var _closing: bool = false


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
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	build()
	MenuKit.focus_first.call_deferred(content)
	_scroll = scroll
	_page_root = margin
	_settle_scroll()
	MenuKit.transition_in.call_deferred(margin)


## A long page (the Muster) opened part-way down: follow_focus scrolled before the layout settled. Once it has,
## start at the top and keep the focused control in view.
func _settle_scroll() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	_scroll.scroll_vertical = 0
	var f: Control = get_viewport().gui_get_focus_owner()
	if f != null and _scroll.is_ancestor_of(f):
		_scroll.ensure_control_visible(f)


## Override: fill `content`.
func build() -> void:
	pass


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


## Removes and rebuilds the page content (after a change).
func rebuild() -> void:
	for c: Node in content.get_children():
		content.remove_child(c)
		c.queue_free()
	build()
	MenuKit.focus_first.call_deferred(content)
