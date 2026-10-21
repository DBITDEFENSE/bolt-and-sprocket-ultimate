class_name StoryReader
extends CanvasLayer
## Full-screen reader for a StoryProp (docs/gravelight/LORE.md section 13.1): a sheet of old paper with the item's
## title, a caption (the first paragraph of the text, which describes the object) and the text itself, which
## scrolls when it is long (arrows / mouse wheel). The first read files the item in the Intel Archive, with the
## usual INTEL FILED banner once the reader closes. Closes on Use / Esc / pause, or by itself if the reader is
## hurt (it's a zombies map: you read at your own risk). Modelled on FinePrintReader.

static var _open: StoryReader = null

var intel_id: StringName
var title: String = ""
var text: String = ""
var player: Player
var _born_ms: int = 0
var _scroll: ScrollContainer
var _first_read: bool = false


static func open_for(p: Player, id: StringName, row: Dictionary) -> void:
	if _open != null and is_instance_valid(_open):
		return
	var r: StoryReader = StoryReader.new()
	r.intel_id = id
	r.title = str(row.get("title", "Story item"))
	r.text = str(row.get("text", ""))
	r.player = p
	p.get_tree().root.add_child(r)
	_open = r


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


## [caption, body]: the first paragraph describes the object; the rest is the text itself.
static func split_caption(t: String) -> PackedStringArray:
	var i: int = t.find("\n\n")
	if i < 0:
		return PackedStringArray(["", t.strip_edges()])
	return PackedStringArray([t.substr(0, i).strip_edges(), t.substr(i + 2).strip_edges()])


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_born_ms = Time.get_ticks_msec()
	GameState.input_blocked = true
	var parts: PackedStringArray = split_caption(text)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var sheet: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.84, 0.78, 0.62)
	sb.border_color = Color(0.46, 0.37, 0.22)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 54
	sb.content_margin_right = 54
	sb.content_margin_top = 38
	sb.content_margin_bottom = 28
	sb.shadow_size = 22
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.custom_minimum_size = Vector2(940, 0)
	center.add_child(sheet)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var head: Label = Label.new()
	head.text = title
	head.add_theme_color_override("font_color", Color(0.16, 0.11, 0.05))
	head.add_theme_font_size_override("font_size", 27)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(head)
	if parts[0] != "":
		var cap: Label = Label.new()
		cap.text = parts[0]
		cap.add_theme_color_override("font_color", Color(0.38, 0.3, 0.17))
		cap.add_theme_font_size_override("font_size", 17)
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.custom_minimum_size = Vector2(830, 0)
		v.add_child(cap)
	var rule: HSeparator = HSeparator.new()
	var rs: StyleBoxFlat = StyleBoxFlat.new()
	rs.bg_color = Color(0.46, 0.37, 0.22, 0.6)
	rs.content_margin_top = 1
	rs.content_margin_bottom = 1
	rule.add_theme_stylebox_override("separator", rs)
	v.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.custom_minimum_size = Vector2(830, 0)
	var max_h: float = maxf(300.0, get_viewport().get_visible_rect().size.y - 330.0)
	v.add_child(_scroll)
	var body: RichTextLabel = RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.custom_minimum_size = Vector2(810, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("default_color", Color(0.15, 0.11, 0.06))
	body.add_theme_font_size_override("normal_font_size", 19)
	body.text = parts[1]
	_scroll.add_child(body)
	# size the scroll window once the text has laid out (a long guest book scrolls, a short docket doesn't)
	_scroll.custom_minimum_size.y = max_h
	body.resized.connect(func() -> void: _scroll.custom_minimum_size.y = minf(max_h, body.size.y + 4.0))
	var hint: Label = Label.new()
	hint.text = "[%s] / [Esc]  put it down      arrows / wheel  scroll" % Interactable.prompt_key(&"interact")
	hint.add_theme_color_override("font_color", Color(0.3, 0.23, 0.12))
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)
	# file it (ProfileSave de-duplicates and awards XP on the first time only)
	_first_read = not ProfileSave.has_intel(String(intel_id))
	GLBus.intel_found.emit(intel_id)
	if _first_read:
		AudioDirector.play_2d("intel_pickup", 0.0, 0.0)
	GLBus.player_damaged.connect(_on_damaged)


func _on_damaged(pid: int, _amount: float) -> void:
	if player != null and is_instance_valid(player) and pid == player.player_id:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(80)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-80)
		return
	if event.is_action_pressed(&"ui_down", true):
		_scroll_by(60)
		return
	if event.is_action_pressed(&"ui_up", true):
		_scroll_by(-60)
		return
	if Time.get_ticks_msec() - _born_ms < 250:
		return   # the Use press that opened it
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _scroll_by(px: int) -> void:
	if _scroll != null:
		_scroll.scroll_vertical += px


func close() -> void:
	if is_queued_for_deletion():
		return
	GameState.input_blocked = false
	_open = null
	if _first_read:
		var hud: Node = get_tree().get_first_node_in_group(&"hud")
		if hud != null:
			hud.call("show_banner", "INTEL FILED\n" + title, 2.5)
		_first_read = false
	queue_free()


func _exit_tree() -> void:
	if _open == self:
		_open = null
		GameState.input_blocked = false
