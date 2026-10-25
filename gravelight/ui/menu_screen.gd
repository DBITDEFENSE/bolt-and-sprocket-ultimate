class_name MenuScreen
extends Control
## Base for full-screen menu pages: a titled panel with a Back button. Back / Esc / pad B closes it.

signal closed

var content: VBoxContainer
var _title: String = ""
var _scroll: ScrollContainer


func _init(title: String = "") -> void:
	_title = title
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)
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
	_settle_scroll()


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


func close() -> void:
	AudioDirector.play_2d("ui_back", 0.0, 0.0)
	closed.emit()
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
