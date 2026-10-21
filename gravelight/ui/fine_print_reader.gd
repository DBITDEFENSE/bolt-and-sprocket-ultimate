class_name FinePrintReader
extends CanvasLayer
## Full-screen reader for a machine's fine-print panel: a brass plate of small type. Files the panel in the
## Intel Archive on first read. Closes on Use / Esc / pause, or by itself if the reader is hurt (it's a
## zombies map: you read at your own risk).

static var _open: FinePrintReader = null

var perk_id: StringName
var player: Player
var _born_ms: int = 0


static func open_for(p: Player, pid: StringName) -> void:
	if _open != null and is_instance_valid(_open):
		return
	var r: FinePrintReader = FinePrintReader.new()
	r.perk_id = pid
	r.player = p
	p.get_tree().root.add_child(r)
	_open = r


static func lore(pid: StringName) -> Dictionary:
	return (GLData.load_json("res://data/gravelight/perk_lore.json").get("perks", {}) as Dictionary).get(String(pid), {})


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_born_ms = Time.get_ticks_msec()
	GameState.input_blocked = true
	var lo: Dictionary = lore(perk_id)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var plate: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.56, 0.46, 0.28)
	sb.border_color = Color(0.32, 0.25, 0.13)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 36
	sb.content_margin_bottom = 30
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.6)
	plate.add_theme_stylebox_override("panel", sb)
	plate.custom_minimum_size = Vector2(900, 0)
	center.add_child(plate)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	plate.add_child(v)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(800, 0)
	text.add_theme_color_override("default_color", Color(0.14, 0.1, 0.05))
	text.add_theme_font_size_override("normal_font_size", 19)
	text.add_theme_font_size_override("bold_font_size", 19)
	text.add_theme_font_size_override("italics_font_size", 19)
	var lines: Array = lo.get("panel", ["(The plate is too worn to read.)"])
	text.text = "\n".join(PackedStringArray(lines.map(func(x: Variant) -> String: return str(x))))
	v.add_child(text)
	var hint: Label = Label.new()
	hint.text = "[%s] / [Esc]  step back" % Interactable.prompt_key(&"interact")
	hint.add_theme_color_override("font_color", Color(0.25, 0.19, 0.1))
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	GLBus.intel_found.emit(StringName("panel." + String(perk_id)))
	GLBus.player_damaged.connect(_on_damaged)


func _on_damaged(pid: int, _amount: float) -> void:
	if player != null and is_instance_valid(player) and pid == player.player_id:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _born_ms < 250:
		return   # the Use press that opened it
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	GameState.input_blocked = false
	_open = null
	queue_free()


func _exit_tree() -> void:
	if _open == self:
		_open = null
		GameState.input_blocked = false
