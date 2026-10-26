extends CanvasLayer
## Switchboard jack selector: A/D, wheel or stick picks a jack 0–9, use plugs it, Esc / crouch leaves.

var board: Switchboard
var player: Player
var digit: int = 0
var _label: Label
var _status: Label
var _plugged: String = ""
var _hold: float = 0.0


func _init() -> void:
	layer = 25


func _ready() -> void:
	GameState.input_blocked = true
	var font: Font = MenuKit.mono_font()
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -330
	panel.offset_bottom = -150
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.05, 0.92)
	sb.border_color = Color(0.75, 0.6, 0.3)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	MenuKit.apply_theme(panel)
	add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	panel.add_child(v)
	_label = _mk(v, font, MenuKit.px(40), Color(1.0, 0.78, 0.4))
	_status = _mk(v, MenuKit.type_font(), MenuKit.size("body"), Color(0.9, 0.9, 0.85))
	var hint: Label = _mk(v, MenuKit.body_font(), MenuKit.size("caption"), Color(0.7, 0.7, 0.65))
	hint.text = "[A/D, wheel, stick] pick a jack   [%s] plug it   [Esc/C] leave" % GLSettings.action_label(&"interact")
	_refresh()


func _mk(parent: Control, font: Font, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _exit_tree() -> void:
	GameState.input_blocked = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"crouch"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		var r: String = board.plug(digit)
		match r:
			"ok":
				_plugged += str(digit)
				_status.text = "Plugged: %s" % _plugged
			"done":
				queue_free()
			"wrong":
				_plugged = ""
				_status.text = "SPARKS. The line drops."
			_:
				queue_free()
	elif event is InputEventMouseButton and event.is_pressed():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			digit = (digit + 1) % 10
			_refresh()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			digit = (digit + 9) % 10
			_refresh()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.downed or GameState.phase != GameState.Phase.PLAYING:
		queue_free()
		return
	var dir: float = Input.get_axis(&"move_left", &"move_right")
	if absf(dir) > 0.4:
		_hold -= delta
		if _hold <= 0.0:
			_hold = 0.22
			digit = (digit + (1 if dir > 0.0 else 9)) % 10
			_refresh()
	else:
		_hold = 0.0


func _refresh() -> void:
	var s: String = ""
	for i: int in 10:
		s += ("[%d]" % i) if i == digit else (" %d " % i)
	_label.text = s
	if _status.text == "":
		_status.text = "Plugged: -"
