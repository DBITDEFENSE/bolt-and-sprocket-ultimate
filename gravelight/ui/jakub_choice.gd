class_name JakubChoice
extends CanvasLayer
## "Talk to Jakub" (Update 02 section 6.2): the two-way choice once he is out of his cage. GIVE HIM A GUN hands
## him the weapon in your hands (you lose it); NOT YET and he follows you with the coal shovel (you can give him a
## gun any time later, or buy him one at a wall-buy while he stands beside you). Like the radio dial, the player
## can't move while it is open; it closes on its own after choice_timeout_s as NOT YET.
## Keys: [interact] give, [crouch] / [pause] not yet (pad: X / B / Start).

var companion: JakubCompanion
var player: Player
var offer: Dictionary = {}       # JakubCompanion.gun_offer(player)
var timeout_s: float = 12.0
var _t: float = 0.0
var _done: bool = false


func _init() -> void:
	layer = 25


func _ready() -> void:
	GameState.input_blocked = true
	var font: Font = MenuKit.type_font()
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -250)   # above the prompt and the subtitles
	panel.custom_minimum_size = Vector2(760, 210)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.06, 0.93)
	sb.border_color = Color(0.72, 0.8, 0.62)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	MenuKit.apply_theme(panel)
	add_child(panel)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_label("JAKUB OSTROWSKI", font, 26, Color(0.72, 0.8, 0.62)))
	v.add_child(_label("\"So. Do I come with you as a man with a gun, or a man with a shovel?\"", font, 18, Color(0.9, 0.88, 0.8)))
	var give: String = "[%s]  GIVE HIM A GUN" % GLSettings.action_label(&"interact")
	if bool(offer.get("ok", false)):
		give += "  ·  your %s (you lose it)" % str(offer.get("name", "gun"))
	else:
		give += "  ·  " + str(offer.get("reason", "nothing to give"))
	v.add_child(_label(give, font, 20, Color(1.0, 0.82, 0.45) if bool(offer.get("ok", false)) else Color(0.6, 0.58, 0.52)))
	v.add_child(_label("[%s / %s]  NOT YET  ·  he follows you with the coal shovel" % [GLSettings.action_label(&"crouch"), GLSettings.action_label(&"pause")],
		font, 20, Color(0.85, 0.85, 0.8)))
	v.add_child(_label("Or buy him one at a wall: stand at it with Jakub beside you.", font, 15, Color(0.62, 0.62, 0.58)))


func _label(text: String, font: Font, size: int, col: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font if size >= 20 else MenuKit.body_font())
	l.add_theme_font_size_override("font_size", MenuKit.px(size))
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(720, 0)
	return l


func _exit_tree() -> void:
	GameState.input_blocked = false


func _input(event: InputEvent) -> void:
	if _done or _t < 0.25:
		return
	if event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		if bool(offer.get("ok", false)):
			_close(true)
		else:
			AudioDirector.play_2d("deny", -4.0)
	elif event.is_action_pressed(&"crouch") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_close(false)


func _process(delta: float) -> void:
	_t += delta
	if player == null or not is_instance_valid(player) or player.downed or GameState.phase != GameState.Phase.PLAYING \
			or companion == null or not is_instance_valid(companion):
		_done = true
		queue_free()
		return
	if _t >= timeout_s:
		_close(false)


## The choice: true = give the gun in your hands, false = not yet.
func _close(give: bool) -> void:
	if _done:
		return
	_done = true
	companion.choose(player, give)
	queue_free()
