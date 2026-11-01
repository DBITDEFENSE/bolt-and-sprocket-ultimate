extends Control
## Front-end hub for TERMS & CONDITIONS (placeholder look until the M9 hub: Blartz's shop at night).
## Built from data/hub.json: door list on the left (mouse, keyboard or pad), a preview card on the right for the
## highlighted door, and drifting contract fine print behind it all. Accepting a door stamps it, then launches.
## Doors show their lock state from the profile (Unlocks). The Settings door opens the shared SettingsMenu.
## Input is ignored for a moment after the hub appears so a double-click from the previous screen can't fire a door.

const BS_FIRST_LEVEL: String = "res://bs/planets/scrapheap/scrapheap.tscn"
const GRAVELIGHT_MENU: String = "res://gravelight/ui/main_menu.tscn"   # Gravelight's own menu (map select, etc.)
const INPUT_GRACE: float = 0.35

var hub: Dictionary = {}
var doors: Array = []
var _buttons: Array[Button] = []
var _open: PackedStringArray = []
var _sel: int = 0
var _busy: bool = false
var _born: float = 0.0
var _status: Label
var _card: Control
var _kicker: Label
var _title: Label
var _wordmark: Control   # the CLAUDE ZOMBIES wordmark, shown in the title slot of the "gl" door (T-140)
var _desc: Label
var _state: Label
var _accept: Label
var _accent_bar: ColorRect
var _stamp: Label
var _backdrop: FinePrint
var _settings: SettingsMenu = null


func _ready() -> void:
	Game.set_mode(Game.Mode.MENU)
	var gl: Node = get_node_or_null(^"/root/GLSettings")
	if gl != null:
		gl.call("deactivate")
	Settings.apply_all()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_born = Time.get_ticks_msec() / 1000.0
	hub = Data.table("hub")
	doors = hub.get("doors", [])
	_open = Unlocks.resolve(Data.table("unlocks"), SaveProfile.doc.get("unlocks", []))
	_build()
	_select(_first_open())
	_buttons[_sel].grab_focus.call_deferred()


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = UIKit.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_backdrop = FinePrint.new()
	_backdrop.lines = PackedStringArray(hub.get("fine_print", []))
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	# left: title + doors
	var left: VBoxContainer = VBoxContainer.new()
	left.position = Vector2(130, 110)
	left.custom_minimum_size = Vector2(760, 0)
	left.add_theme_constant_override("separation", 6)
	add_child(left)
	var title: Label = UIKit.label(str(hub.get("title", Game.GAME_TITLE)), 112, UIKit.PAPER, true)
	left.add_child(title)
	var under: ColorRect = ColorRect.new()
	under.color = UIKit.SEAL
	under.custom_minimum_size = Vector2(150, 5)
	under.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(under)
	var tag: Label = UIKit.label(str(hub.get("tagline", "")), 22, UIKit.DIM)
	left.add_child(tag)
	var gap: Control = Control.new()
	gap.custom_minimum_size.y = 46
	left.add_child(gap)
	for i: int in doors.size():
		var b: Button = _door_button(doors[i] as Dictionary, i)
		left.add_child(b)
		_buttons.append(b)
	_status = UIKit.label("", 20, UIKit.GOLD)
	_status.custom_minimum_size.y = 34
	left.add_child(_status)
	# right: preview card
	_card = PanelContainer.new()
	(_card as PanelContainer).add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.09, 0.13, 0.86), UIKit.FAINT, 1, 6, 40))
	_card.position = Vector2(1040, 300)
	_card.custom_minimum_size = Vector2(760, 470)
	add_child(_card)
	var cv: VBoxContainer = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	_card.add_child(cv)
	_accent_bar = ColorRect.new()
	_accent_bar.custom_minimum_size = Vector2(90, 6)
	_accent_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(_accent_bar)
	_kicker = UIKit.label("", 22, UIKit.GOLD, true)
	cv.add_child(_kicker)
	_title = UIKit.label("", 72, UIKit.PAPER, true)
	cv.add_child(_title)
	_wordmark = MenuKit.wordmark(150.0)
	_wordmark.visible = false
	_wordmark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(_wordmark)
	_desc = UIKit.para("", 25, UIKit.PAPER.darkened(0.12), 680)
	cv.add_child(_desc)
	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(fill)
	_state = UIKit.label("", 21, UIKit.DIM)
	cv.add_child(_state)
	_accept = UIKit.label("", 30, UIKit.PAPER, true)
	cv.add_child(_accept)
	# stamp (shown when a door is accepted)
	_stamp = UIKit.label("", 120, UIKit.SEAL, true)
	_stamp.add_theme_color_override("font_outline_color", Color(UIKit.SEAL, 0.35))
	_stamp.add_theme_constant_override("outline_size", 10)
	_stamp.visible = false
	add_child(_stamp)
	# footer
	var foot: Label = UIKit.label("[Enter / A]  %s        [Esc / B]  %s        [↑ ↓]  %s" % [
		str(hub.get("footer_accept", "ACCEPT")), str(hub.get("footer_back", "BACK")), str(hub.get("footer_move", "BROWSE"))], 18, UIKit.FAINT)
	foot.position = Vector2(130, 1010)
	add_child(foot)
	var ver: Label = UIKit.label(str(hub.get("version", "build %s")) % Game.VERSION, 18, UIKit.FAINT)
	ver.position = Vector2(1640, 1010)
	add_child(ver)


func _door_button(d: Dictionary, i: int) -> Button:
	var accent: Color = Color(str(d.get("accent", "#ece6d6")))
	var locked: bool = _is_locked(d)
	var b: Button = Button.new()
	b.text = str(d.get("title", "")) + ("     " + str(hub.get("locked", "SEALED")) if locked else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(620, 66)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", UIKit.head_font())
	b.add_theme_font_size_override("font_size", 40)
	var col: Color = UIKit.FAINT if locked else UIKit.PAPER.darkened(0.25)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", UIKit.FAINT if locked else UIKit.INK)
	b.add_theme_color_override("font_focus_color", UIKit.DIM if locked else UIKit.INK)
	b.add_theme_color_override("font_pressed_color", UIKit.INK)
	var idle: StyleBoxFlat = UIKit.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 2, 22)
	idle.border_width_left = 4
	idle.border_color = Color(accent, 0.35 if not locked else 0.12)
	var lit: StyleBoxFlat = UIKit.box(Color(1, 1, 1, 0.06) if locked else accent, Color.TRANSPARENT, 0, 2, 34)
	lit.border_width_left = 10
	lit.border_color = accent.darkened(0.25) if not locked else Color(accent, 0.3)
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("focus", lit)
	b.add_theme_stylebox_override("pressed", lit)
	b.mouse_entered.connect(func() -> void:
		if _settings == null and not _busy:
			b.grab_focus())
	b.focus_entered.connect(_select.bind(i))
	b.pressed.connect(_activate.bind(i))
	return b


func _process(_dt: float) -> void:
	if _accent_bar != null:
		var t: float = Time.get_ticks_msec() / 1000.0
		_accent_bar.custom_minimum_size.x = 90.0 + 18.0 * sin(t * 2.2)


func _unhandled_input(event: InputEvent) -> void:
	if _settings != null or _busy:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_buttons[_buttons.size() - 1].grab_focus()   # Esc / B highlights QUIT (press again to confirm)


func _select(i: int) -> void:
	_sel = i
	var d: Dictionary = doors[i]
	var accent: Color = Color(str(d.get("accent", "#ece6d6")))
	var locked: bool = _is_locked(d)
	_accent_bar.color = accent
	_kicker.text = str(d.get("kicker", ""))
	_kicker.add_theme_color_override("font_color", accent)
	_title.text = str(d.get("title", ""))
	var is_gl: bool = str(d.get("id", "")) == "gl"
	_title.visible = not is_gl
	_wordmark.visible = is_gl
	_desc.text = str(d.get("desc", ""))
	_state.text = _state_text(d)
	if locked:
		_accept.text = str(hub.get("locked", "SEALED"))
		_accept.add_theme_color_override("font_color", UIKit.FAINT)
	elif str(d.get("action", "")) == "soon":
		_accept.text = str(hub.get("soon", "%s")) % str(d.get("milestone", ""))
		_accept.add_theme_color_override("font_color", UIKit.DIM)
	else:
		_accept.text = "%s  ▸" % str(hub.get("footer_accept", "ACCEPT"))
		_accept.add_theme_color_override("font_color", accent)
	_status.text = ""
	_backdrop.tint = accent


func _state_text(d: Dictionary) -> String:
	match str(d.get("id", "")):
		"bs":
			return str(d.get("status_cont" if BS.flag("cs.intro") else "status_new", ""))
		"gl":
			var s: String = str(d.get("status_new", ""))
			var ps: Node = get_node_or_null(^"/root/ProfileSave")
			if ps != null and ps.has_method("rank"):
				s += "   ·   Rank %d" % int(ps.call("rank"))
			return s
	return str(d.get("status_new", ""))


func _activate(i: int) -> void:
	if _busy or _settings != null:
		return
	if Time.get_ticks_msec() / 1000.0 - _born < INPUT_GRACE:
		return   # swallow a click carried over from the previous screen
	var d: Dictionary = doors[i]
	if _is_locked(d):
		_status.text = str(hub.get("locked", "SEALED")) + " - " + str(d.get("desc", ""))
		return
	match str(d.get("action", "")):
		"launch_bs":
			_stamp_then(launch_bolt_and_sprocket, Color(str(d["accent"])))
		"launch_gl":
			_stamp_then(launch_gravelight, Color(str(d["accent"])))
		"settings":
			open_settings()
		"quit":
			get_tree().quit()
		_:
			_status.text = str(hub.get("soon", "%s")) % str(d.get("milestone", ""))


## Stamps "ACCEPTED" over the preview card, then runs the launch.
func _stamp_then(launch: Callable, accent: Color) -> void:
	_busy = true
	for b: Button in _buttons:
		b.disabled = true
	_stamp.text = "ACCEPTED"
	_stamp.add_theme_color_override("font_color", accent.lerp(UIKit.SEAL, 0.6))
	_stamp.visible = true
	_stamp.pivot_offset = Vector2(260, 70)
	_stamp.position = _card.position + Vector2(170, 170)
	_stamp.rotation = -0.18
	_stamp.scale = Vector2(2.2, 2.2)
	_stamp.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.1)
	tw.chain().tween_interval(0.35)
	tw.chain().tween_callback(func() -> void:
		if not launch.call():
			_busy = false
			_stamp.visible = false
			for b: Button in _buttons:
				b.disabled = false)


func open_settings() -> void:
	if _settings != null:
		return
	_settings = SettingsMenu.new()
	add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings = null
		_buttons[_sel].grab_focus.call_deferred())


## The Bolt & Sprocket door. Returns false (and says so) while the planet scene isn't built yet.
func launch_bolt_and_sprocket() -> bool:
	if not ResourceLoader.exists(BS_FIRST_LEVEL):
		if _status != null:
			_status.text = BSText.text("bs.ui.menu.bs_missing")
		return false
	if BS.flag("cleared.scrapheap"):
		StarMap.open(get_tree())   # past planet 1: choose where to go
		return true
	BSLevel.pending_cutscene = "intro" if not BS.flag("cs.intro") else ""
	get_tree().change_scene_to_file.call_deferred(BS_FIRST_LEVEL)
	return true


## The GRAVELIGHT door: Gravelight's own menu (map select, characters, archive...). It activates its own
## bindings and screen overlays (GLSettings.activate()).
func launch_gravelight() -> bool:
	if not ResourceLoader.exists(GRAVELIGHT_MENU):
		return false
	get_tree().change_scene_to_file.call_deferred(GRAVELIGHT_MENU)
	return true


func _is_locked(d: Dictionary) -> bool:
	var u: String = str(d.get("unlock", ""))
	return u != "" and not (u in _open)


func _first_open() -> int:
	for i: int in doors.size():
		if not _is_locked(doors[i] as Dictionary):
			return i
	return 0


## Slowly drifting lines of contract fine print behind the hub, tinted toward the highlighted door.
class FinePrint extends Control:
	var lines: PackedStringArray = []
	var tint: Color = UIKit.PAPER
	var _t: float = 0.0
	var _cur: Color = UIKit.PAPER

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_t += dt
		_cur = _cur.lerp(tint, minf(1.0, dt * 3.0))
		queue_redraw()

	func _draw() -> void:
		if lines.is_empty():
			return
		var f: Font = UIKit.body_font()
		var row_h: float = 34.0
		var rows: int = int(size.y / row_h) + 2
		var scroll: float = fmod(_t * 9.0, row_h)
		var base_row: int = int(_t * 9.0 / row_h)
		for r: int in rows:
			var y: float = r * row_h - scroll
			var li: int = (r + base_row) % lines.size()
			var x: float = -120.0 + fmod(float(li * 173 + (r + base_row) * 37), 300.0)
			var a: float = 0.05 + 0.03 * sin(_t * 0.6 + r + base_row)
			var c: Color = Color(_cur.lerp(UIKit.PAPER, 0.6), a)
			var text: String = lines[li] + "      " + lines[(li + 5) % lines.size()]
			draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, c)
