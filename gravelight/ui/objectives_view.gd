class_name ObjectivesView
extends PanelContainer
## The OBJECTIVES tab (Update 04 section 4, DECISIONS T-066): draws an ObjectiveLog result. Skin "ledger" is the
## Gravelight ledger page (paper, ink, stamp headers); "holo" is the Bolt & Sprocket holo panel (cyan on navy).
## Left: CURRENT OBJECTIVE on top, then the sections (EASTER EGG, SIDE QUESTS, CHALLENGES, INTEL; B&S: SIDE
## QUESTS, GOLD BOLTS, MEMOS, CHALLENGES). Right: the selected entry, with Show on map / Assign to bot / Open in
## Archive where they apply. The host (PauseMenu, BSPauseMenu) builds the log and reacts to the signals.

signal entry_selected(entry: Dictionary)
signal locate_requested(entry: Dictionary)
signal assign_requested(entry: Dictionary)
signal archive_requested(entry: Dictionary)
signal spoiler_changed(level: String)

const LEDGER_PAPER: Color = Color(0.87, 0.82, 0.7)
const LEDGER_INK: Color = Color(0.15, 0.11, 0.08)
const LEDGER_RED: Color = Color(0.58, 0.1, 0.08)
const LEDGER_DONE: Color = Color(0.24, 0.34, 0.18)
const LEDGER_FAINT: Color = Color(0.45, 0.41, 0.36)
const LEDGER_RULE: Color = Color(0.55, 0.62, 0.72, 0.55)
const HOLO_BG: Color = Color(0.05, 0.08, 0.14, 0.95)
const HOLO_TEXT: Color = Color(0.86, 0.97, 1.0)
const HOLO_CYAN: Color = Color("#3ee6ff")
const HOLO_YELLOW: Color = Color("#ffd23e")
const HOLO_DONE: Color = Color("#7dff9a")
const HOLO_FAINT: Color = Color("#6f8aa3")

## Host hook: (entry) -> bool, whether "Assign to bot" applies (BotSquad.ee_can_assign). Unset = never.
var can_assign: Callable = Callable()
var skin: String = "ledger"

var _log: Dictionary = {}
var _selected_id: String = ""
var _list: VBoxContainer
var _scroll: ScrollContainer
var _spoiler: OptionButton
var _d_title: Label
var _d_status: Label
var _d_text: Label
var _d_where: Label
var _d_story: Label
var _d_quote: Label
var _d_bar: ProgressBar
var _d_buttons: HBoxContainer
var _d_feedback: Label
var _buttons: Dictionary = {}     # entry id -> Button
var _entries: Dictionary = {}     # entry id -> entry


func _init(skin_name: String = "ledger") -> void:
	skin = skin_name
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	add_theme_stylebox_override("panel", _panel_style())
	var root: HBoxContainer = HBoxContainer.new()
	root.add_theme_constant_override("separation", 22)
	add_child(root)
	# left: the page
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.45
	left.add_theme_constant_override("separation", 6)
	root.add_child(left)
	var top: HBoxContainer = HBoxContainer.new()
	left.add_child(top)
	var cap: Label = _label("CURRENT OBJECTIVE" if skin == "ledger" else "MISSION", 15, _accent(), true)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cap)
	top.add_child(_label("Spoilers", 15, _faint()))
	_spoiler = OptionButton.new()
	for n: String in ObjectiveLog.LEVEL_NAMES:
		_spoiler.add_item(n)
	_spoiler.focus_mode = Control.FOCUS_ALL
	_spoiler.add_theme_font_size_override("font_size", 15)
	_spoiler.item_selected.connect(func(i: int) -> void: spoiler_changed.emit(ObjectiveLog.LEVELS[i]))
	top.add_child(_spoiler)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	left.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)
	# right: the selected entry
	var right: PanelContainer = PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _detail_style())
	root.add_child(right)
	var dv: VBoxContainer = VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	right.add_child(dv)
	_d_status = _label("", 14, _accent(), true)
	dv.add_child(_d_status)
	_d_title = _label("", 21, _ink())
	_d_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_d_title)
	_d_bar = _bar()
	_d_bar.visible = false
	dv.add_child(_d_bar)
	_d_story = _label("", 16, _ink())
	_d_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_story.modulate = Color(1, 1, 1, 0.82)
	dv.add_child(_d_story)
	_d_text = _label("", 17, _ink())
	_d_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_d_text)
	_d_quote = _label("", 15, _faint())
	_d_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_d_quote)
	_d_where = _label("", 16, _accent())
	_d_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_d_where)
	_d_buttons = HBoxContainer.new()
	_d_buttons.add_theme_constant_override("separation", 10)
	dv.add_child(_d_buttons)
	_d_feedback = _label("", 15, _faint())
	_d_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_d_feedback)
	if not _log.is_empty():
		show_log(_log)


## Draws a built ObjectiveLog result, keeping the selection when that entry is still there.
func show_log(log: Dictionary) -> void:
	_log = log
	if _list == null:
		return
	_spoiler.select(maxi(0, ObjectiveLog.LEVELS.find(str(log.get("spoiler", ObjectiveLog.HINTS)))))
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_buttons.clear()
	_entries.clear()
	var cur: Dictionary = log.get("current", {})
	if not cur.is_empty():
		var cb: Control = _entry_button(cur, 22)
		_list.add_child(cb)
		_list.add_child(_rule())
	for s: Variant in log.get("sections", []):
		var sec: Dictionary = s
		var h: Label = _label(str(sec.get("title", "")), 20, _accent(), true)
		_list.add_child(h)
		for e: Variant in sec.get("entries", []):
			_list.add_child(_entry_button(e, 17))
		_list.add_child(_rule())
	var pick: String = _selected_id if _entries.has(_selected_id) else str(cur.get("id", ""))
	if _entries.has(pick):
		_select(_entries[pick], false)


## Focus for controllers: the selected line (or the first one).
func focus_list() -> void:
	if _buttons.has(_selected_id):
		(_buttons[_selected_id] as Button).grab_focus()
	elif not _buttons.is_empty():
		(_buttons.values()[0] as Button).grab_focus()


## Selects (and focuses) an entry by id; false when it isn't on the page.
func select_id(id: String) -> bool:
	if not _entries.has(id):
		return false
	_select(_entries[id], true)
	if _buttons.has(id):
		(_buttons[id] as Button).grab_focus()
	return true


func selected_entry() -> Dictionary:
	return _entries.get(_selected_id, {})


## A line under the buttons ("Dutch is on it.", "No map yet...").
func set_feedback(text: String) -> void:
	if _d_feedback != null:
		_d_feedback.text = text


func _entry_button(e: Dictionary, size: int) -> Control:
	var id: String = str(e.get("id", ""))
	_entries[id] = e
	var kind: String = str(e.get("kind", ""))
	var status: String = str(e.get("status", ""))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var b: Button = Button.new()
	b.text = str(e.get("title", ""))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	if skin == "ledger":
		b.add_theme_font_override("font", MenuKit.type_font())
	b.add_theme_font_size_override("font_size", size + (1 if kind == "header" else 0))
	var col: Color = _ink()
	if status == "done":
		col = _done()
	elif status == "future" or kind == "note":
		col = _faint()
	elif kind == "header":
		col = _accent()
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, col)
	var indent: float = 18.0 if kind == "step" or kind == "collectible" else (0.0 if kind == "objective" else 6.0)
	b.add_theme_stylebox_override("normal", _btn_style(false, indent))
	b.add_theme_stylebox_override("hover", _btn_style(true, indent))
	b.add_theme_stylebox_override("focus", _btn_style(true, indent))
	b.add_theme_stylebox_override("pressed", _btn_style(true, indent))
	b.focus_entered.connect(func() -> void: _select(e, true))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		_select(e, true)
		if bool(e.get("locatable", false)):
			locate_requested.emit(e)
		elif str(e.get("intel_id", "")) != "":
			archive_requested.emit(e))
	row.add_child(b)
	_buttons[id] = b
	if float(e.get("progress", -1.0)) >= 0.0 and kind != "objective":
		var bar: ProgressBar = _bar()
		bar.value = float(e["progress"])
		bar.custom_minimum_size = Vector2(110, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var pt: Label = _label(str(e.get("progress_text", "")), 14, _faint())
		pt.custom_minimum_size = Vector2(76, 0)
		row.add_child(pt)
	return row


func _select(e: Dictionary, emit: bool) -> void:
	_selected_id = str(e.get("id", ""))
	if _d_title == null:
		return
	var kind: String = str(e.get("kind", ""))
	var status: String = str(e.get("status", ""))
	var status_words: Dictionary = {"done": "DONE", "current": "NOW", "future": "NOT YET", "info": ""}
	_d_status.text = ("CURRENT OBJECTIVE" if kind == "objective" else str(status_words.get(status, ""))) if kind != "header" else "QUEST"
	_d_title.text = str(e.get("title", "")).trim_prefix("▸ ").trim_prefix("✔ ")
	_d_text.text = str(e.get("text", "")) if str(e.get("text", "")) != str(e.get("title", "")).trim_prefix("▸ ").trim_prefix("✔ ") else ""
	_d_where.text = ("Where: " + str(e["where"])) if str(e.get("where", "")) != "" else ""
	# T-086: the step's story above the instruction, the line that set it up quoted under it
	_d_story.text = str(e.get("story", ""))
	_d_story.visible = _d_story.text != ""
	var q: String = str(e.get("quote", ""))
	_d_quote.text = ("“%s”  — %s" % [q, str(e.get("quote_by", ""))]) if q != "" else ""
	_d_quote.visible = q != ""
	_d_bar.visible = float(e.get("progress", -1.0)) >= 0.0
	if _d_bar.visible:
		_d_bar.value = float(e["progress"])
	for c: Node in _d_buttons.get_children():
		_d_buttons.remove_child(c)
		c.queue_free()
	_d_feedback.text = ""
	if bool(e.get("locatable", false)):
		_d_buttons.add_child(_action_button("Show on map", func() -> void: locate_requested.emit(e)))
	if bool(e.get("bot_candidate", false)) and can_assign.is_valid() and bool(can_assign.call(e)):
		_d_buttons.add_child(_action_button("Assign to bot", func() -> void: assign_requested.emit(e)))
	if str(e.get("intel_id", "")) != "":
		_d_buttons.add_child(_action_button("Open in Archive", func() -> void: archive_requested.emit(e)))
	if emit:
		entry_selected.emit(e)


func _action_button(text: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if skin == "ledger":
		b.add_theme_font_override("font", MenuKit.type_font())
	b.add_theme_font_size_override("font_size", 17)
	b.custom_minimum_size = Vector2(0, 36)
	for k: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, _ink() if skin == "ledger" else HOLO_TEXT)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.58, 0.1, 0.08, 0.12) if skin == "ledger" else Color(0.24, 0.9, 1.0, 0.12)
	sb.border_color = _accent()
	sb.set_border_width_all(2)
	sb.set_content_margin_all(8)
	var sbf: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	sbf.bg_color = Color(0.58, 0.1, 0.08, 0.3) if skin == "ledger" else Color(0.24, 0.9, 1.0, 0.32)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbf)
	b.add_theme_stylebox_override("focus", sbf)
	b.add_theme_stylebox_override("pressed", sbf)
	b.pressed.connect(cb)
	return b


# ---------------------------------------------------------------- skin

func _ink() -> Color:
	return LEDGER_INK if skin == "ledger" else HOLO_TEXT


func _accent() -> Color:
	return LEDGER_RED if skin == "ledger" else HOLO_YELLOW


func _done() -> Color:
	return LEDGER_DONE if skin == "ledger" else HOLO_DONE


func _faint() -> Color:
	return LEDGER_FAINT if skin == "ledger" else HOLO_FAINT


func _label(text: String, size: int, color: Color, stamp: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	if skin == "ledger":
		l.add_theme_font_override("font", MenuKit.stamp_font() if stamp else MenuKit.type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if skin != "ledger":
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	return l


func _bar() -> ProgressBar:
	var pb: ProgressBar = ProgressBar.new()
	pb.max_value = 1.0
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(200, 8)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = LEDGER_RED if skin == "ledger" else HOLO_CYAN
	pb.add_theme_stylebox_override("fill", fill)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.3, 0.22, 0.15, 0.25) if skin == "ledger" else Color(0, 0, 0, 0.5)
	pb.add_theme_stylebox_override("background", bg)
	return pb


func _rule() -> Control:
	var r: ColorRect = ColorRect.new()
	r.color = LEDGER_RULE if skin == "ledger" else Color(0.24, 0.9, 1.0, 0.25)
	r.custom_minimum_size = Vector2(0, 2)
	return r


func _panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if skin == "ledger":
		sb.bg_color = LEDGER_PAPER
		sb.border_color = Color(0.36, 0.25, 0.16)
		sb.set_border_width_all(3)
		sb.border_width_left = 10   # the ledger's binding
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 8
	else:
		sb.bg_color = HOLO_BG
		sb.border_color = HOLO_CYAN
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	return sb


func _detail_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if skin == "ledger":
		sb.bg_color = Color(0.93, 0.89, 0.79)
		sb.border_color = Color(0.58, 0.1, 0.08, 0.5)
		sb.set_border_width_all(1)
		sb.border_width_left = 3
	else:
		sb.bg_color = Color(0.08, 0.13, 0.22, 0.9)
		sb.border_color = Color(0.24, 0.9, 1.0, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	return sb


func _btn_style(hot: bool, indent: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	if hot:
		sb.bg_color = Color(0.58, 0.1, 0.08, 0.14) if skin == "ledger" else Color(0.24, 0.9, 1.0, 0.16)
		sb.border_color = _accent()
		sb.border_width_left = 4
	sb.content_margin_left = 6 + indent
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
