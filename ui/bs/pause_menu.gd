class_name BSPauseMenu
extends CanvasLayer
## Pause screen (setPause, index.html:17584): pauses the tree, saves, frees the mouse. RESUME,
## RESTART PLANET, MAIN MENU. Opens on the pause action only while nothing else owns the input.

signal restart_requested
signal quit_requested

const MENU_SCENE: String = "res://ui/main_menu.tscn"

var is_open: bool = false
var _panel: PanelContainer
var _resume: Button


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", BSStyle.panel(BSStyle.YELLOW, Color(0.06, 0.08, 0.13, 0.95), 22, 4))
	_panel.position = Vector2(720, 300)
	_panel.custom_minimum_size = Vector2(480, 0)
	var holder: Control = Control.new()
	holder.name = "Holder"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)
	holder.add_child(_panel)
	add_child(holder)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	var t: Label = BSStyle.label(BSText.text("html.pause.001"), 56, BSStyle.YELLOW, 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_resume = BSStyle.button(BSText.text("html.btnResume.001"), BSStyle.CYAN, 26)
	_resume.pressed.connect(close)
	v.add_child(_resume)
	var r: Button = BSStyle.button(BSText.text("html.btnRestart.001"), BSStyle.ORANGE, 26)
	r.pressed.connect(func() -> void:
		close()
		restart_requested.emit())
	v.add_child(r)
	var q: Button = BSStyle.button(BSText.text("html.btnQuit.001"), BSStyle.PINK, 26)
	q.pressed.connect(func() -> void:
		close()
		quit_requested.emit())
	v.add_child(q)
	holder.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause"):
		return
	if is_open:
		close()
		get_viewport().set_input_as_handled()
	elif not BS.blocked():
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open:
		return
	is_open = true
	BS.ui_block += 1
	get_tree().paused = true
	BS.save_to_profile()
	BSStyle.free_mouse()
	($Holder as Control).visible = true
	_resume.grab_focus.call_deferred()


func close() -> void:
	if not is_open:
		return
	is_open = false
	BS.ui_block = maxi(0, BS.ui_block - 1)
	get_tree().paused = false
	($Holder as Control).visible = false
	BSStyle.capture_mouse(get_tree())


func _exit_tree() -> void:
	if is_open:
		is_open = false
		BS.ui_block = maxi(0, BS.ui_block - 1)
		get_tree().paused = false
