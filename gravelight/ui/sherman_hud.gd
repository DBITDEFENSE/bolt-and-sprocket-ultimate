class_name ShermanHud
extends CanvasLayer
## The Sherman event's own HUD lines (T-249), on every peer: a counter under the boss bars while the dead are on the
## tank ("THE DEAD ON THE SHERMAN: 14"), and the air raid's warning in the middle of the screen (the title, the line
## under it, the countdown, then whether you are under a roof). The tank's health is a boss bar (BossHud, the boss
## kit's bar); the banners are the HUD's own (Hud.show_banner).

const RED: Color = Color(0.95, 0.22, 0.16)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const SAFE: Color = Color(0.6, 0.9, 0.62)

var counter: Label
var title: Label
var small: Label
var count: Label
var status: Label
var _box: VBoxContainer
var _pulse: float = 0.0


func _init() -> void:
	layer = 12
	name = "ShermanHud"


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MenuKit.apply_theme(root)
	add_child(root)
	counter = MenuKit.label("", 22, PAPER, true)
	counter.anchor_left = 0.5
	counter.anchor_right = 0.5
	counter.offset_left = -300
	counter.offset_right = 300
	counter.offset_top = float(MenuKit.hud("boss_top", 22.0)) + 74.0
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.hide()
	root.add_child(counter)
	_box = VBoxContainer.new()
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 0.22
	_box.offset_left = -420
	_box.offset_right = 420
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_box)
	title = MenuKit.label("", 64, RED, true)
	small = MenuKit.label("", 30, PAPER, true)
	count = MenuKit.label("", 40, PAPER, true)
	status = MenuKit.label("", 26, PAPER, true)
	for l: Label in [title, small, count, status]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		MenuKit.outline(l, "hud")
		_box.add_child(l)
	MenuKit.outline(counter, "hud")
	_box.hide()


func set_counter(text: String) -> void:
	counter.text = text
	counter.visible = text != ""


## The raid's warning: `t_title` big, `t_small` under it, `t_count` (the countdown) and `t_status` (inside or out).
func set_warning(t_title: String, t_small: String, t_count: String, t_status: String, safe: bool) -> void:
	title.text = t_title
	small.text = t_small
	count.text = t_count
	status.text = t_status
	status.add_theme_color_override("font_color", SAFE if safe else RED)
	_box.visible = t_title != "" or t_status != ""


func clear_warning() -> void:
	_box.hide()


func _process(delta: float) -> void:
	if _box.visible and title.text != "":
		_pulse += delta * 3.2
		title.modulate.a = 0.75 + 0.25 * sin(_pulse)
