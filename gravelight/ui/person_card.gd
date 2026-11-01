class_name PersonCard
extends CanvasLayer
## T-143: the Talk card of an extra person (ExtraPerson, and the quartermaster Ammer's trade in MapCompanion): a name,
## a bio, what they say now, up to three options on [interact] / [reload] / [melee], [crouch] / [pause] to leave.
## Like the bank card the player stands still while it is open; it closes by itself when you are hurt or downed, walk
## away (you can't), the match leaves play or nothing is pressed for card_close_s.
## options: Array of {action: StringName, label: String, call: Callable, enabled: bool}; the call gets the player.

var player: Player
var title: String = ""
var bio: String = ""
var said: String = ""
var options: Array = []
var close_after_s: float = 25.0
var _t: float = 0.0
var _idle: float = 0.0
var _done: bool = false
var _hp0: float = 0.0
var _said_label: Label


func _init() -> void:
	layer = 25


func _ready() -> void:
	GameState.input_blocked = true
	_hp0 = player.hp if player != null else 0.0
	var font: Font = MenuKit.type_font()
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-400, -260)
	panel.custom_minimum_size = Vector2(800, 280)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.06, 0.94)
	sb.border_color = Color(0.72, 0.62, 0.42)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	MenuKit.apply_theme(panel)
	add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	panel.add_child(v)
	v.add_child(_label(title, font, 26, Color(0.85, 0.72, 0.38)))
	v.add_child(_label(bio, font, 15, Color(0.62, 0.62, 0.58)))
	_said_label = _label(said, font, 19, Color(0.95, 0.9, 0.75))
	v.add_child(_said_label)
	for o: Variant in options:
		var d: Dictionary = o
		var col: Color = Color(1.0, 0.82, 0.45) if bool(d.get("enabled", true)) else Color(0.5, 0.5, 0.46)
		v.add_child(_label("[%s]  %s" % [GLSettings.action_label(d["action"]), str(d["label"])], font, 20, col))
	v.add_child(_label("[%s / %s]  LEAVE" % [GLSettings.action_label(&"crouch"), GLSettings.action_label(&"pause")], font, 18, Color(0.85, 0.85, 0.8)))


func _label(text: String, font: Font, size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font if size >= 20 else MenuKit.body_font())
	l.add_theme_font_size_override("font_size", MenuKit.px(size))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	return l


## Picks the option on `action` (also the tests): runs its call when enabled; true when one ran.
func choose(action: StringName) -> bool:
	_idle = 0.0
	for o: Variant in options:
		var d: Dictionary = o
		if d["action"] == action:
			if not bool(d.get("enabled", true)):
				AudioDirector.play_2d("deny", -4.0)
				return false
			(d["call"] as Callable).call(player)
			close()
			return true
	return false


func _exit_tree() -> void:
	GameState.input_blocked = false


func _input(event: InputEvent) -> void:
	if _done or _t < 0.25:
		return
	for a: StringName in [&"interact", &"reload", &"melee"]:
		if event.is_action_pressed(a):
			get_viewport().set_input_as_handled()
			choose(a)
			return
	if event.is_action_pressed(&"crouch") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	_t += delta
	_idle += delta
	if player != null and is_instance_valid(player):
		_hp0 = maxf(_hp0, player.hp)
	if player == null or not is_instance_valid(player) or player.downed or player.hp < _hp0 - 0.5 \
			or GameState.phase != GameState.Phase.PLAYING or _idle >= close_after_s:
		close()


func close() -> void:
	if _done:
		return
	_done = true
	queue_free()
