class_name BSPauseMenu
extends CanvasLayer
## Pause screen (setPause, index.html:17584): pauses the tree, saves, frees the mouse. RESUME,
## RESTART PLANET, MAIN MENU. Opens on the pause action only while nothing else owns the input.
## OBJECTIVES (Update 04 section 4, T-066): the planet's quest log in the holo skin (ObjectivesView over
## ObjectiveLog.build_bs): the mission, side quests, gold bolts, memos and planet challenges.

signal restart_requested
signal quit_requested

const MENU_SCENE: String = "res://ui/main_menu.tscn"

var is_open: bool = false
var _panel: PanelContainer
var _resume: Button
var _settings: SettingsMenu = null
var _objectives: Control = null
var _obj_view: ObjectivesView = null


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
	var ob: Button = BSStyle.button("OBJECTIVES", BSStyle.CYAN, 26)
	ob.pressed.connect(open_objectives)
	v.add_child(ob)
	var r: Button = BSStyle.button(BSText.text("html.btnRestart.001"), BSStyle.ORANGE, 26)
	r.pressed.connect(func() -> void:
		close()
		restart_requested.emit())
	v.add_child(r)
	var s: Button = BSStyle.button(BSText.text("html.btnPauseSettings.001"), BSStyle.GREEN, 26)
	s.pressed.connect(open_settings)
	v.add_child(s)
	var q: Button = BSStyle.button(BSText.text("html.btnQuit.001"), BSStyle.PINK, 26)
	q.pressed.connect(func() -> void:
		close()
		quit_requested.emit())
	v.add_child(q)
	holder.visible = false


## The shared Settings screen over the pause panel (the web build's pause SETTINGS button).
func open_settings() -> void:
	if _settings != null:
		return
	($Holder as Control).visible = false
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings = null
		if is_open:
			($Holder as Control).visible = true
			_resume.grab_focus.call_deferred())


## The planet's quest log over the pause panel (Back, Esc or pad B returns to the panel).
func open_objectives() -> void:
	if _objectives != null:
		return
	($Holder as Control).visible = false
	var layer_root: Control = Control.new()
	layer_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_root.add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	layer_root.add_child(margin)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var head: HBoxContainer = HBoxContainer.new()
	v.add_child(head)
	var t: Label = BSStyle.label("OBJECTIVES", 40, BSStyle.YELLOW, 10)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back: Button = BSStyle.button("BACK", BSStyle.PINK, 22)
	back.pressed.connect(close_objectives)
	head.add_child(back)
	_obj_view = ObjectivesView.new("holo")
	_obj_view.spoiler_changed.connect(func(lv: String) -> void:
		var gs: Node = get_node_or_null(^"/root/GLSettings")
		if gs != null:
			(gs.get("values") as Dictionary)["objective_spoilers"] = lv   # no set_value: that re-applies Gravelight's visuals
			gs.call("save_settings")
		refresh_objectives())
	v.add_child(_obj_view)
	_objectives = layer_root
	add_child(layer_root)
	refresh_objectives()
	_obj_view.focus_list.call_deferred()


func refresh_objectives() -> void:
	if _obj_view == null:
		return
	var gs: Node = get_node_or_null(^"/root/GLSettings")
	var lv: String = str((gs.get("values") as Dictionary).get("objective_spoilers", "hints")) if gs != null else "hints"
	_obj_view.show_log(ObjectiveLog.build_bs(ObjectiveSnapshot.bs(get_parent()), {}, lv))


func close_objectives() -> void:
	if _objectives == null:
		return
	_objectives.queue_free()
	_objectives = null
	_obj_view = null
	if is_open:
		($Holder as Control).visible = true
		_resume.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _settings != null:
		return   # the settings screen handles its own back / pause
	if _objectives != null:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			close_objectives()
			get_viewport().set_input_as_handled()
		return
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
	close_objectives()
	BS.ui_block = maxi(0, BS.ui_block - 1)
	get_tree().paused = false
	($Holder as Control).visible = false
	BSStyle.capture_mouse(get_tree())


func _exit_tree() -> void:
	if is_open:
		is_open = false
		BS.ui_block = maxi(0, BS.ui_block - 1)
		get_tree().paused = false
