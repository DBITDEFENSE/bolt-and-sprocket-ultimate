extends CanvasLayer
## Tuning dial for FieldRadio. A/D, mouse wheel or the left stick turn it (0.005 steps, holding speeds up);
## use locks the frequency; Esc / crouch leaves. The player can't move while tuning.

const MIN_F: float = 2.0
const MAX_F: float = 8.0
const STEP: float = 0.005

var radio: FieldRadio
var player: Player
var freq: float = 4.5
var _hold: float = 0.0
var _label: Label
var _status: Label
var _locked: PackedStringArray = []
var _bar: ColorRect
var _needle: ColorRect


func _init() -> void:
	layer = 25


func _ready() -> void:
	GameState.input_blocked = true
	var font: Font = MenuKit.mono_font()   # the dial reads like an instrument
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-330, -330)
	panel.custom_minimum_size = Vector2(660, 200)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.05, 0.92)
	sb.border_color = Color(0.75, 0.6, 0.3)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	MenuKit.apply_theme(panel)
	add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	panel.add_child(v)
	_label = Label.new()
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", MenuKit.px(44))
	_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_label)
	var track: Control = Control.new()
	track.custom_minimum_size = Vector2(600, 18)
	v.add_child(track)
	_bar = ColorRect.new()
	_bar.color = Color(0.3, 0.25, 0.15)
	_bar.size = Vector2(600, 6)
	_bar.position = Vector2(14, 6)
	track.add_child(_bar)
	_needle = ColorRect.new()
	_needle.color = Color(1.0, 0.4, 0.2)
	_needle.size = Vector2(3, 18)
	track.add_child(_needle)
	_status = Label.new()
	_status.add_theme_font_override("font", MenuKit.type_font())
	_status.add_theme_font_size_override("font_size", MenuKit.size("body"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)
	var hint: Label = Label.new()
	hint.add_theme_font_override("font", MenuKit.body_font())
	hint.add_theme_font_size_override("font_size", MenuKit.size("caption"))
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	hint.text = "[A/D, wheel, stick] tune   [%s] lock   [Esc/C] leave" % GLSettings.action_label(&"interact")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	_refresh()


func _exit_tree() -> void:
	GameState.input_blocked = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"crouch"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		var f: String = "%.3f" % freq
		var result: String = radio.lock_frequency(f)
		match result:
			"ok":
				_locked.append(f)
				_status.text = "LOCKED %s" % f
			"done":
				queue_free()
			"wrong":
				_locked.clear()
				_status.text = "STATIC. The sequence is lost."
	elif event is InputEventMouseButton and event.is_pressed():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_nudge(1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_nudge(-1)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.downed or GameState.phase != GameState.Phase.PLAYING:
		queue_free()
		return
	var dir: float = Input.get_axis(&"move_left", &"move_right")
	if absf(dir) > 0.2:
		_hold += delta
		var rate: float = 0.12 if _hold < 0.6 else (0.6 if _hold < 1.6 else 2.0)
		freq = clampf(freq + signf(dir) * rate * delta, MIN_F, MAX_F)
		freq = snappedf(freq, STEP)
		_refresh()
	else:
		_hold = 0.0


func _nudge(steps: int) -> void:
	freq = clampf(snappedf(freq + STEP * float(steps), STEP), MIN_F, MAX_F)
	AudioDirector.play_2d("radio_tune", -10.0, 0.0)
	_refresh()


func _refresh() -> void:
	_label.text = "%.3f Mc/s" % freq
	_needle.position = Vector2(14 + 600.0 * (freq - MIN_F) / (MAX_F - MIN_F), 0)
	if _status.text == "":
		_status.text = "Locked: " + (", ".join(_locked) if not _locked.is_empty() else "none")
