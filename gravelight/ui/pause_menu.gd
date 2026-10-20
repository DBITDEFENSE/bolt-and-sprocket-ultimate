class_name PauseMenu
extends CanvasLayer
## Esc / Start pauses the match (solo). Resume, restart, quit to menu, and a few quick settings.
## Co-op: the world keeps running (only your input stops); Restart is the host's, and quitting leaves the game
## (the host leaving ends it for everyone).

signal quit_requested
signal restart_requested

var _box: VBoxContainer
var _sens: HSlider
var _fov: HSlider


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas"])
	font.font_weight = 700
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_CENTER)
	_box.custom_minimum_size = Vector2(460, 0)
	_box.position = Vector2(-230, -220)
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	var title: Label = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_add_button("Resume", font, toggle)
	_sens = _add_slider("Mouse sensitivity", font, 0.2, 3.0, GLSettings.get_f("sensitivity"), "sensitivity")
	_fov = _add_slider("Field of view", font, 65.0, 110.0, GLSettings.get_f("fov"), "fov")
	var classic: CheckButton = CheckButton.new()
	classic.text = "Classic Rules (no character traits)"
	classic.add_theme_font_override("font", font)
	classic.button_pressed = bool(GLSettings.values["classic_rules"])
	classic.toggled.connect(func(on: bool) -> void:
		GLSettings.values["classic_rules"] = on
		GLSettings.save_settings())
	_box.add_child(classic)
	if not Net.is_client():
		_add_button("Restart" if not Net.is_online() else "Restart (everyone)", font, func() -> void: restart_requested.emit())
	if Net.is_host():
		_add_button("Back to lobby (everyone)", font, func() -> void: quit_requested.emit())
		_add_button("End the game", font, func() -> void:
			Net.leave("")
			get_tree().paused = false
			GameState.phase = GameState.Phase.MENU
			get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn"))
	else:
		_add_button("Quit to menu" if not Net.is_online() else "Leave the game", font, func() -> void: quit_requested.emit())


func _add_button(text: String, font: Font, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _add_slider(text: String, font: Font, lo: float, hi: float, value: float, key: String) -> HSlider:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	_box.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = value
	s.value_changed.connect(func(v: float) -> void:
		GLSettings.values[key] = v
		GLSettings.save_settings())
	_box.add_child(s)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and GameState.phase == GameState.Phase.PLAYING:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	if Net.is_online():
		GameState.input_blocked = visible   # co-op never stops the world
	else:
		get_tree().paused = visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
	if visible:
		(_box.get_child(1) as Button).grab_focus()
