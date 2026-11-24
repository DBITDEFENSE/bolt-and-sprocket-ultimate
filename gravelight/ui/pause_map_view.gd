class_name PauseMapView
extends Control
## The pause page's MAP tab (Update 04 section 3, DECISIONS T-069): the whole level on a MapCanvas, with the floor
## tabs, pan and zoom, zone labels, a legend, hover tooltips (what it is, its price, open / bought / locked), the
## round and the power in a corner, and the squad down the side, each bot with the line of what it is doing
## ("Going to buy Ironhide Stout (1,200 short)", "Defending Rail Yard", "Doing: Collecting the radio notes (2/3)",
## "Idle"). PauseMenu makes one on the first MAP visit (class name PauseMapView) and calls bind_pause_menu; in solo
## the tree is paused under it, so it runs with PROCESS_MODE_ALWAYS (PauseMenu.set_map_view sets that).
##
## Marking (MapMarks, data/maps/marks.json): click an empty spot for the radial Go Here · Defend Here · Danger ·
## Regroup · Custom note; a buyable for BUY THIS (a door asks "Open this door for 1,250?"); an easter-egg object,
## part or power-up for Collect / Activate this; then who it is for: Me, Any bot, a bot by its portrait, Jakub
## (default Any bot for buy / collect / defend, Me for Go here). Right-click (pad B) on a mark removes it.
##
## Mouse: move = cursor, click = mark, drag = pan, wheel = zoom, shift + wheel or PgUp / PgDn = floor, C = centre on
## you. Controller: left stick = cursor, right stick = pan, LT / RT = zoom, D-pad up / down = floor, A = mark,
## B = remove / back, Y = centre on you. (LB / RB stay the pause page's tab keys.)
## B&S uses the same view in the holo skin (skin = "holo"): personal marks only, it has no bots.

signal mark_placed(result: Dictionary)

const TYPE_NAMES: Dictionary = {
	"perk": "Perk machine", "wall_buy": "Wall weapon", "ammo_box": "Ammo box", "door": "Door", "crate_spot": "Requisition Crate (random weapon box)",
	"crucible": "The Crucible", "workbench": "Workbench", "trap": "Trap", "power_switch": "Power switch", "lift": "Lift",
	"bank": "Savings bank", "vendor": "Vendor", "save": "Save point", "checkpoint": "Checkpoint", "exit": "Exit", "npc": "Someone to talk to", "ship": "Ship",
}
const LEGEND: Array = [["perk", "Perk"], ["wall_buy", "Wall weapon"], ["ammo_box", "Ammo"], ["door", "Door"], ["crate_spot", "Crate"],
	["crucible", "Crucible"], ["workbench", "Bench"], ["trap", "Trap"], ["bank", "Bank"], ["power_switch", "Power"], ["objective", "Objective"],
	["powerup", "Power-up"], ["marker", "Mark"], ["bot", "Bot"], ["player", "You"]]
const LEGEND_BS: Array = [["door", "Door"], ["vendor", "Vendor"], ["checkpoint", "Checkpoint"], ["save", "Save"], ["exit", "Exit"],
	["npc", "NPC"], ["objective", "Objective"], ["marker", "Mark"], ["player", "You"]]
const ZOOM_MAX: float = 14.0
const PAD_CURSOR_PX_S: float = 620.0
const PAD_PAN_M_S: float = 32.0

var skin: String = "ledger"
var pause_menu: Node = null
var state: MapState = null
var marks: MapMarks = null
var canvas: MapCanvas
## Where the cursor is (canvas px) and whether the controller moved it last (then it is drawn as a crosshair).
var cursor: Vector2 = Vector2.ZERO
var pad_cursor: bool = false

var _area: Control
var _overlay: Overlay
var _floor_bar: HBoxContainer
var _floor_buttons: Array[Button] = []
var _corner: Label
var _legend: Legend
var _tip: PanelContainer
var _tip_label: Label
var _toast: Label
var _toast_t: float = 0.0
var _side: VBoxContainer
var _squad_box: VBoxContainer
var _marks_box: VBoxContainer
var _marks_title: Label
var _help: Label
var radial: Radial
var _picker: PanelContainer = null
var _picker_items: Array = []        # [{target, label, button}]
var _picker_sel: int = 0
var _dialog: PanelContainer = null
var _note_edit: LineEdit = null
## The mark being made: {kind, pos, node, poi, c (MarkTargets class), slot, option, label, floor}.
var pending: Dictionary = {}
var _highlights: Array[Dictionary] = []
var _fitted: bool = false
var _side_t: float = 0.0
var _drag: bool = false
var _drag_moved: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _fit_zoom: float = 1.0
var _fit_size: Vector2 = Vector2.ZERO   # the canvas size the first fit used (re-fitted while the layout settles)
var _fit_stable: int = 0
var _hover: Dictionary = {}
var _nav_hold_t: float = 0.0
var _last_floor_auto: int = -1


func _init() -> void:
	name = "PauseMapView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build()
	refresh()


## PauseMenu calls this once after making the view.
func bind_pause_menu(pm: Node) -> void:
	pause_menu = pm


func _ink() -> Color:
	return ObjectivesView.LEDGER_INK if skin == "ledger" else ObjectivesView.HOLO_TEXT


func _red() -> Color:
	return ObjectivesView.LEDGER_RED if skin == "ledger" else ObjectivesView.HOLO_YELLOW


func _faint() -> Color:
	return ObjectivesView.LEDGER_FAINT if skin == "ledger" else ObjectivesView.HOLO_FAINT


func _paper_box(alpha: float = 0.96) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	if skin == "ledger":
		sb.bg_color = Color(0.86, 0.81, 0.69, alpha)
		sb.border_color = Color(0.36, 0.25, 0.16)
	else:
		sb.bg_color = Color(0.03, 0.07, 0.12, alpha)
		sb.border_color = ObjectivesView.HOLO_CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3 if skin == "ledger" else 6)
	sb.set_content_margin_all(8)
	return sb


func _label(text: String, size: int, col: Color, stamp: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", MenuKit.stamp_font() if stamp else MenuKit.type_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _small_button(text: String, cb: Callable, size: int = 15) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", MenuKit.stamp_font())
	b.add_theme_font_size_override("font_size", size)
	var n: StyleBoxFlat = _paper_box(0.9)
	n.set_content_margin_all(4)
	var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	h.bg_color = h.bg_color.lerp(_red(), 0.25)
	var pr: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	pr.bg_color = _red()
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_color_override("font_color", _ink())
	b.add_theme_color_override("font_hover_color", _ink())
	b.add_theme_color_override("font_pressed_color", Color(0.98, 0.95, 0.88))
	var fo: StyleBoxFlat = h.duplicate() as StyleBoxFlat
	fo.border_color = _red()
	fo.set_border_width_all(3)
	fo.draw_center = false
	b.add_theme_stylebox_override("focus", fo)
	b.add_theme_color_override("font_focus_color", _ink())
	b.add_theme_color_override("font_hover_pressed_color", Color(0.98, 0.95, 0.88))
	b.pressed.connect(cb)
	return b


# ================================================================== build

func _build() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var frame: PanelContainer = PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fsb: StyleBoxFlat = _paper_box(1.0)
	fsb.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", fsb)
	row.add_child(frame)
	_area = Control.new()
	_area.clip_contents = true
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.focus_mode = Control.FOCUS_NONE
	_area.gui_input.connect(_area_input)
	_area.mouse_exited.connect(func() -> void: _tip.visible = false)
	frame.add_child(_area)
	canvas = MapCanvas.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.record_hits = true
	canvas.show_zone_labels = true
	canvas.icon_scale = 1.25
	_area.add_child(canvas)
	_overlay = Overlay.new()
	_overlay.view = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.add_child(_overlay)
	# floor tabs (top left), round and power (top right), legend (bottom left), toast (bottom)
	_floor_bar = HBoxContainer.new()
	_floor_bar.position = Vector2(10, 8)
	_floor_bar.add_theme_constant_override("separation", 4)
	_area.add_child(_floor_bar)
	_corner = _label("", 18, _red(), true)
	_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_corner.position = Vector2(-360, 8)
	_corner.size = Vector2(350, 50)
	_area.add_child(_corner)
	_legend = Legend.new()
	_legend.view = self
	_legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_area.add_child(_legend)
	_toast = _label("", 17, _red(), true)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(700, 30)
	_toast.position = Vector2(-350, -40)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color(0.93, 0.89, 0.8, 0.9) if skin == "ledger" else Color(0, 0, 0, 0.9))
	_area.add_child(_toast)
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", _paper_box(0.97))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip_label = _label("", 15, _ink())
	_tip.add_child(_tip_label)
	_area.add_child(_tip)
	radial = Radial.new()
	radial.view = self
	radial.set_anchors_preset(Control.PRESET_FULL_RECT)
	radial.visible = false
	radial.chosen.connect(_on_radial)
	_area.add_child(radial)
	# the side: the squad and their orders, your marks, the keys
	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(330, 0)
	side_panel.add_theme_stylebox_override("panel", _paper_box(0.96))
	row.add_child(side_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(scroll)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 6)
	scroll.add_child(_side)
	_side.add_child(_label("SQUAD ORDERS" if skin == "ledger" else "CREW", 20, _red(), true))
	_squad_box = VBoxContainer.new()
	_squad_box.add_theme_constant_override("separation", 6)
	_side.add_child(_squad_box)
	_side.add_child(HSeparator.new())
	_marks_title = _label("YOUR MARKS", 18, _red(), true)
	_side.add_child(_marks_title)
	_marks_box = VBoxContainer.new()
	_side.add_child(_marks_box)
	_side.add_child(HSeparator.new())
	_help = _label("", 13, _faint())
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(300, 0)
	_side.add_child(_help)
	_help.text = "Click: mark  ·  Right-click: remove a mark\nDrag: pan  ·  Wheel: zoom  ·  Shift+wheel / PgUp PgDn: floor  ·  C: you\n" \
		+ "Pad: L-stick cursor · R-stick pan · LT/RT zoom · D-pad floors · A mark · B remove · Y you"


# ================================================================== the PauseMenu hooks

## Each time the MAP tab opens: the match's map state, the floor you are on, the squad.
func refresh() -> void:
	var ms: MapState = MapState.current()
	if ms != state:
		state = ms
		canvas.set_state(ms)
		_fitted = false
		_build_floor_tabs()
	marks = MapMarks.of(state)
	if state == null:
		_corner.text = "NO MAP DATA"
		return
	canvas.show_fog = str(Minimap.setting("minimap_fog")) != "always"
	canvas.cb_shapes = bool(Minimap.setting("minimap_cb_shapes"))
	_fit_now()
	_close_popups()
	_refresh_side()
	_refresh_corner()


func _fit_now() -> void:
	if state == null:
		return
	if canvas.size.x < 60.0 or canvas.size.y < 60.0:
		if is_inside_tree() and not get_tree().process_frame.is_connected(_fit_now):
			get_tree().process_frame.connect(_fit_now, CONNECT_ONE_SHOT)   # laid out next frame
		return
	var keep_zoom: float = canvas.zoom
	var pm: Dictionary = MenuKit.cfg().get("pause_map", {})
	var margin: float = float(pm.get("fit_margin_px", 24.0))
	canvas.fit_floor(margin)
	_fit_zoom = canvas.zoom   # the whole rect (the Grounds too): the floor of the zoom range
	var f: int = state.local_floor()
	set_floor(f)
	var me: Node3D = state.local_body()
	if _fitted:
		canvas.zoom = clampf(keep_zoom, _fit_zoom * 0.8, ZOOM_MAX)   # the last zoom of the match is kept
	else:
		# T-096: the first view fits the built zones (Map 0: the inn, stable and yard), not the whole 104 x 118 m
		# rect that left the inn a thumbnail in the middle; the Grounds stay reachable by zoom and pan.
		canvas.fit_rect(built_rect(state.data, float(pm.get("fit_zone_max_frac", 0.4))), margin)
		canvas.zoom = clampf(canvas.zoom, _fit_zoom * 0.8, ZOOM_MAX)
	_fitted = true
	_fit_size = canvas.size
	_fit_stable = 0
	if me != null and canvas.zoom > _fit_zoom * 1.05:
		canvas.center = Vector2(me.global_position.x, me.global_position.z)
	cursor = _area.size * 0.5


## The rect (world XZ) round the built zones of a map: the union of the bounding boxes of every zone whose own
## bounding box covers at most `max_frac` of the map's world rect (open ground like Map 0's Grounds is left out);
## the whole world rect when no zone qualifies.
static func built_rect(md: MapData, max_frac: float = 0.4) -> Rect2:
	if md == null:
		return Rect2()
	var total: float = maxf(1.0, md.world_rect.get_area())
	var out: Rect2 = Rect2()
	var any: bool = false
	for z: Dictionary in md.zones:
		var r: Rect2 = Rect2()
		var first: bool = true
		for poly: Variant in z.get("polys", []):
			for q: Vector2 in poly:
				if first:
					r = Rect2(q, Vector2.ZERO)
					first = false
				else:
					r = r.expand(q)
		if first or r.get_area() / total > max_frac:
			continue
		out = r if not any else out.merge(r)
		any = true
	return out.grow(4.0) if any else md.world_rect


## Highlights a place (the OBJECTIVES tab's "Show on map"): its floor, centred, a pulsing ring for 8 s.
func highlight_location(world_pos: Vector3, floor_id: StringName = &"", label: String = "") -> void:
	highlight_locations([world_pos], floor_id, label)


func highlight_locations(points: Array, floor_id: StringName = &"", label: String = "") -> void:
	if state == null:
		refresh()
	if state == null or points.is_empty():
		return
	_highlights.clear()
	var until: int = Time.get_ticks_msec() + 8000
	for p: Variant in points:
		_highlights.append({"pos": p as Vector3, "label": label, "until": until})
	var fi: int = -1
	if String(floor_id) != "":
		for i: int in state.data.floors.size():
			if str(state.data.floors[i].get("id", "")) == String(floor_id):
				fi = i
	if fi < 0:
		fi = state.data.floor_at((points[0] as Vector3) + Vector3.UP * 0.2)
	set_floor(fi)
	var c: Vector2 = Vector2.ZERO
	for p2: Variant in points:
		c += Vector2((p2 as Vector3).x, (p2 as Vector3).z)
	canvas.center = c / float(points.size())
	canvas.zoom = maxf(canvas.zoom, minf(ZOOM_MAX, _fit_zoom * 2.0))
	_show_toast("Marked on the map: %s" % label if label != "" else "Marked on the map")


# ================================================================== floors / view

func _build_floor_tabs() -> void:
	for b: Button in _floor_buttons:
		b.queue_free()
	_floor_buttons.clear()
	if state == null:
		return
	for i: int in state.data.floors.size():
		var b: Button = _small_button(state.data.floor_name(i).to_upper(), set_floor.bind(i), 15)
		b.toggle_mode = true
		_floor_bar.add_child(b)
		_floor_buttons.append(b)


func set_floor(i: int) -> void:
	if state == null:
		return
	canvas.floor_index = clampi(i, 0, state.data.floors.size() - 1)
	var here: int = state.local_floor()
	for k: int in _floor_buttons.size():
		_floor_buttons[k].set_pressed_no_signal(k == canvas.floor_index)
		_floor_buttons[k].text = ("● " if k == here else "") + state.data.floor_name(k).to_upper()
	canvas.refresh_now()


func step_floor(d: int) -> void:
	set_floor(canvas.floor_index + d)


func zoom_at(pt: Vector2, factor: float) -> void:
	var before: Vector3 = canvas.canvas_to_world(pt)
	canvas.zoom = clampf(canvas.zoom * factor, _fit_zoom * 0.8, ZOOM_MAX)
	var after: Vector3 = canvas.canvas_to_world(pt)
	canvas.center += Vector2(before.x - after.x, before.z - after.z)


func center_on_me() -> void:
	if state == null:
		return
	var me: Node3D = state.local_body()
	if me != null:
		set_floor(state.local_floor())
		canvas.center = Vector2(me.global_position.x, me.global_position.z)
		canvas.zoom = maxf(canvas.zoom, minf(ZOOM_MAX, _fit_zoom * 2.0))


# ================================================================== input

func _popup_open() -> bool:
	return radial.visible or _picker != null or _dialog != null


func _typing() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f is LineEdit or f is TextEdit


func _area_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		pad_cursor = false
		cursor = mm.position
		if radial.visible:
			radial.pointer(mm.position)
		elif _drag:
			if mm.position.distance_to(_press_at) > 6.0:
				_drag_moved = true
			if _drag_moved:
				canvas.center -= mm.relative / canvas.zoom
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		cursor = mb.position
		pad_cursor = false
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _popup_open():
				return
			var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if mb.shift_pressed:
				step_floor(1 if up else -1)
			else:
				zoom_at(mb.position, 1.18 if up else 1.0 / 1.18)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if radial.visible:
				if not mb.pressed:
					radial.confirm()
				accept_event()
				return
			if _picker != null or _dialog != null:
				return
			if mb.pressed:
				_drag = true
				_drag_moved = false
				_press_at = mb.position
			else:
				var was_drag: bool = _drag_moved
				_drag = false
				_drag_moved = false
				if not was_drag:
					click(mb.position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _popup_open():
				_close_popups()
			else:
				remove_at(mb.position)
			accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or state == null:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and not _typing():
		var kc: Key = (event as InputEventKey).physical_keycode
		if _popup_open() and (event.is_action(&"pause") or event.is_action(&"ui_cancel")):
			_close_popups()
			get_viewport().set_input_as_handled()
			return
		if _picker != null and (kc == KEY_LEFT or kc == KEY_RIGHT or kc == KEY_ENTER or kc == KEY_KP_ENTER):
			if kc == KEY_ENTER or kc == KEY_KP_ENTER:
				_pick(_picker_sel)
			else:
				_picker_move(-1 if kc == KEY_LEFT else 1)
			get_viewport().set_input_as_handled()
			return
		if _popup_open():
			return
		match kc:
			KEY_PAGEUP:
				step_floor(1)
			KEY_PAGEDOWN:
				step_floor(-1)
			KEY_C:
				center_on_me()
			KEY_EQUAL, KEY_KP_ADD:
				zoom_at(_area.size * 0.5, 1.25)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_at(_area.size * 0.5, 0.8)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.is_pressed():
		var jb: JoyButton = (event as InputEventJoypadButton).button_index
		if jb == JOY_BUTTON_LEFT_SHOULDER or jb == JOY_BUTTON_RIGHT_SHOULDER or jb == JOY_BUTTON_START:
			return   # the pause page's tabs / resume
		if _dialog != null:
			return   # its buttons take the pad (focus)
		pad_cursor = true
		match jb:
			JOY_BUTTON_A:
				if radial.visible:
					radial.confirm()
				elif _picker != null:
					_pick(_picker_sel)
				else:
					click(cursor)
			JOY_BUTTON_B:
				if _popup_open():
					_close_popups()
				elif not remove_at(cursor):
					return   # nothing to remove: B goes on to the page (B&S: back)
			JOY_BUTTON_Y:
				center_on_me()
			JOY_BUTTON_DPAD_UP:
				step_floor(1)
			JOY_BUTTON_DPAD_DOWN:
				step_floor(-1)
			JOY_BUTTON_DPAD_LEFT:
				if _picker != null:
					_picker_move(-1)
			JOY_BUTTON_DPAD_RIGHT:
				if _picker != null:
					_picker_move(1)
			_:
				return
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _fitted and _fit_stable < 3 and state != null:
		if canvas.size != _fit_size:   # the containers were still settling when the first fit ran: fit again
			_fitted = false
			_fit_now()
		else:
			_fit_stable += 1
	if not is_visible_in_tree() or state == null:
		return
	# the controller: the cursor, panning, zoom (sticks and triggers)
	var lv: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var rv: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var lt: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	var rt: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	if lv.length() > 0.2:
		pad_cursor = true
		if radial.visible:
			radial.stick(lv)
		elif _picker != null:
			_nav_hold_t -= delta
			if absf(lv.x) > 0.6 and _nav_hold_t <= 0.0:
				_nav_hold_t = 0.25
				_picker_move(1 if lv.x > 0.0 else -1)
		elif _dialog == null:
			cursor = (cursor + lv * lv.length() * PAD_CURSOR_PX_S * delta).clamp(Vector2.ZERO, _area.size)
	if rv.length() > 0.2 and not _popup_open():
		canvas.center += rv * rv.length() * PAD_PAN_M_S * delta * (6.0 / maxf(1.0, canvas.zoom))
	if (lt > 0.2 or rt > 0.2) and not _popup_open():
		zoom_at(cursor, pow(1.8, (rt - lt) * delta))
	_hover_update()
	_side_t -= delta
	if _side_t <= 0.0:
		_side_t = 0.3
		_refresh_side()
		_refresh_corner()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	_legend.position = Vector2(8, _area.size.y - _legend.size.y - 8)
	_overlay.queue_redraw()


# ================================================================== hover

func _hover_update() -> void:
	if _popup_open() or _drag_moved:
		_tip.visible = false
		_hover = {}
		return
	_hover = canvas.icon_at(cursor, 16.0)
	if _hover.is_empty():
		_tip.visible = false
		return
	var lines: PackedStringArray = tooltip_lines(_hover, state, marks, Net.local_player_id())
	if lines.is_empty():
		_tip.visible = false
		return
	_tip_label.text = "\n".join(lines)
	_tip.visible = true
	_tip.reset_size()
	var p: Vector2 = cursor + Vector2(18, 14)
	if p.x + _tip.size.x > _area.size.x - 6.0:
		p.x = cursor.x - _tip.size.x - 14.0
	if p.y + _tip.size.y > _area.size.y - 6.0:
		p.y = cursor.y - _tip.size.y - 10.0
	_tip.position = p


## The hover text for something on the map (pure enough to test with a fake hit): what it is, the price, its state.
static func tooltip_lines(h: Dictionary, ms: MapState, mm: MapMarks, local_pid: int) -> PackedStringArray:
	var out: PackedStringArray = []
	match str(h.get("kind", "")):
		"marker":
			var m: Dictionary = h.get("marker", {})
			var who: String = "yours"
			var pid: int = int(m.get("pid", -1))
			if bool(m.get("order", false)) and pid > 0:
				who = "Jakub" if pid == 9 else Net.display_name(pid)
			elif str(m.get("target", "")) == "squad":
				who = "the squad"
			out.append("%s: %s" % [MapMarks.kind_name(str(m.get("kind", ""))), str(m.get("label", ""))])
			out.append("For %s" % who)
			if bool(m.get("order", false)) and pid > 0 and mm != null:
				var st: String = mm.status_of(pid)
				if st != "":
					out.append(st)
			out.append("Right-click / B: remove")
		"objective":
			var o: Dictionary = h.get("objective", {})
			out.append(str(o.get("label", "Objective")))
			out.append("Easter egg  ·  click: a bot does it")
		"connector":
			out.append("Stairs / ladder / lift")
		"zombie":
			out.append("Zombie")
		"powerup":
			var l: Dictionary = h.get("live", {})
			out.append("%s (power-up)" % str(l.get("label", "Power-up")))
			out.append("Click: a bot collects it")
		"ally", "bot", "jakub", "downed", "boss":
			var l2: Dictionary = h.get("live", {})
			out.append(str(l2.get("label", "")))
			if str(h.get("kind", "")) == "downed":
				out.append("DOWN: %d%% of the bleed-out left" % int(float(l2.get("bleed", 1.0)) * 100.0))
			var pid2: int = int(l2.get("pid", -1))
			if pid2 > 0 and mm != null:
				var st2: String = mm.status_of(pid2)
				if st2 != "":
					out.append(st2)
		_:
			var poi: Dictionary = h.get("poi", {})
			if poi.is_empty():
				return out
			var st3: Dictionary = h.get("state", ms.poi_state(poi) if ms != null else {})
			out.append(str(st3.get("label", poi.get("label", ""))))
			var ty: String = str(poi.get("type", ""))
			var tname: String = str(TYPE_NAMES.get(ty, ty.capitalize()))
			if ty == "workbench" and str((poi.get("data", {}) as Dictionary).get("bench", "")) == "armorer":
				tname = "Armorer's Bench (M1911 attachments)"
			var price: int = int(st3.get("price", poi.get("price", 0)))
			out.append("%s%s" % [tname, ("  ·  %s Scrip" % MarkTargets.money(price)) if price > 0 else ""])
			out.append(state_text(ty, st3, poi, local_pid, ms))
	return out


## Open / bought / locked, in words.
static func state_text(ty: String, st: Dictionary, poi: Dictionary, local_pid: int, ms: MapState) -> String:
	match ty:
		"door":
			if bool(st.get("open", false)):
				return "Open"
			return "Locked: needs the power" if bool(st.get("locked", false)) else "Closed: click to have a bot open it"
		"perk":
			var n: Node = ms.poi_node(poi) if ms != null else null
			if n is PerkMachine and PerkManager.has_perk(local_pid, (n as PerkMachine).perk_id):
				return "Bought (you have it)"
			return "No power" if not bool(st.get("powered", true)) else "Powered"
		"crucible":
			return "No power" if not bool(st.get("powered", true)) else "Ready to forge"
		"trap":
			return "Ready" if bool(st.get("ready", true)) else "Recharging"
		"workbench":
			if str((poi.get("data", {}) as Dictionary).get("bench", "")) == "armorer":
				return "Five slots: magazine, barrel, sights, grip, ammo"
			return "Built" if bool(st.get("open", false)) else "Not built yet"
		"power_switch":
			return "ON" if bool(st.get("open", false)) else "Off"
		"bank":
			var why: String = BankAccount.closed_reason()
			return "Shut (%s)" % why if why != "" else "Deposit Scrip: it earns interest every round, kept in your profile"
		"crate_spot":
			return "The crate is here" if bool(st.get("here", true)) else "The crate was here"
		"wall_buy":
			var n2: Node = ms.poi_node(poi) if ms != null else null
			for p: Node in (ms.get_tree().get_nodes_in_group(&"players") if ms != null and ms.is_inside_tree() else []):
				var pl: Player = p as Player
				if pl != null and pl.player_id == local_pid and n2 is WallBuy and pl.weapons != null and pl.weapons.find_weapon_base((n2 as WallBuy).weapon_id) != null:
					return "Bought (ammo here)"
			return "Chalk outline"
		"lift":
			return "Ready" if bool(st.get("ready", true)) else "Not running"
	return ""


# ================================================================== marking

## A click (or pad A) at `at` on the map: the radial for whatever is there.
func click(at: Vector2) -> void:
	if state == null or marks == null:
		return
	var h: Dictionary = canvas.icon_at(at, 16.0)
	var pos: Vector3 = _world_at(at)
	pending = {"pos": pos, "at": at, "c": {"kind": "go", "sub": "", "label": "", "price": 0, "node": null}}
	var entries: Array = []
	if str(h.get("kind", "")) == "marker":
		# a mark: Remove it, and whatever it sits on (a machine with a buy mark) keeps its own options
		var m: Dictionary = h["marker"]
		pending["mark_id"] = int(m["id"])
		pending["pos"] = m["pos"]
		entries.append({"id": "remove", "label": "Remove mark"})
		h = _under_mark(at)
	match str(h.get("kind", "")):
		"marker":
			pass
		"objective":
			var o: Dictionary = h["objective"]
			var on: Variant = o.get("node")
			pending["pos"] = o["pos"]
			if on is Node and is_instance_valid(on):
				pending["c"] = MarkTargets.classify(on as Node)
				pending["c"]["label"] = str(o.get("label", pending["c"].get("label", "")))
		"powerup":
			var l: Dictionary = h["live"]
			pending["pos"] = l["pos"]
			var pn: Node = _powerup_near(l["pos"] as Vector3)
			if pn != null:
				pending["c"] = MarkTargets.classify(pn)
		"connector", "zombie", "ally", "bot", "jakub", "downed", "boss", "":
			pass
		_:
			var poi: Dictionary = h.get("poi", {})
			if not poi.is_empty():
				pending["pos"] = state.poi_world_pos(poi)
				pending["poi"] = poi
				pending["c"] = MarkTargets.classify_poi(poi, state)
	entries.append_array(radial_for(pending["c"], marks.has_bots(), skin == "holo"))
	radial.open(at, entries, _radial_title(pending["c"]))


## The nearest icon at `at` that isn't a mark ({} none).
func _under_mark(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = 16.0
	for hh: Dictionary in canvas.hits:
		if str(hh.get("kind", "")) == "marker":
			continue
		var d: float = (hh["pos"] as Vector2).distance_to(at) - float(hh.get("r", 0.0)) * 0.5
		if d <= bd:
			bd = d
			best = hh
	return best


func _radial_title(c: Dictionary) -> String:
	var l: String = str(c.get("label", ""))
	if int(c.get("price", 0)) > 0:
		l += "  ·  %s" % MarkTargets.money(int(c["price"]))
	return l


## The radial's entries for a target (MarkTargets.classify): BUY THIS / COLLECT / the empty-spot set. Pure.
static func radial_for(c: Dictionary, has_bots: bool, bs: bool = false) -> Array:
	var out: Array = []
	var k: String = str(c.get("kind", "go"))
	var sub: String = str(c.get("sub", ""))
	if k == "buy" and not bs:
		if sub == "bench":
			out.append({"id": "bench_pick", "label": "BUY THIS: bot's pick", "kind": "buy"})
			for slot: Variant in WeaponKit.slot_ids():
				out.append({"id": "bench_slot:" + str(slot), "label": WeaponKit.slot_name(null, str(slot)), "kind": "buy"})
		elif sub == "door":
			out.append({"id": "buy", "label": "OPEN THIS DOOR", "kind": "buy"})
		else:
			out.append({"id": "buy", "label": "BUY THIS", "kind": "buy"})
		out.append({"id": "go", "label": "Go here", "kind": "go"})
		return out
	if (k == "collect" or k == "activate") and not bs:
		out.append({"id": "collect", "label": "ACTIVATE THIS" if k == "activate" else "COLLECT / ACTIVATE", "kind": "collect"})
		out.append({"id": "go", "label": "Go here", "kind": "go"})
		return out
	out.append({"id": "go", "label": "Go here", "kind": "go"})
	if has_bots:
		out.append({"id": "defend", "label": "Defend here", "kind": "defend"})
	out.append({"id": "danger", "label": "Danger", "kind": "danger"})
	if has_bots:
		out.append({"id": "regroup", "label": "Regroup", "kind": "regroup"})
	out.append({"id": "note", "label": "Custom note", "kind": "note"})
	return out


## The guns the squad's bots would take to the bench (WeaponKit.gun_of each), for the bench's option radial.
func _bot_guns() -> Array:
	var out: Array = []
	if marks == null or not is_inside_tree():
		return out
	var pids: Array = marks.bots().map(func(d: Dictionary) -> int: return int(d.get("pid", -1)))
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and pids.has(p.player_id):
			var w: WeaponInstance = WeaponKit.gun_of(p)
			if w != null:
				out.append(w)
	return out


func _on_radial(e: Dictionary) -> void:
	var id: String = str(e.get("id", ""))
	if id == "remove":
		marks.remove(int(pending.get("mark_id", -1)))
		_show_toast("Mark removed.")
		pending = {}
		return
	if id.begins_with("bench_slot:"):
		var slot: String = id.get_slice(":", 1)
		# T-074: the slot's options on the guns the squad's bots are holding (the bot picks its own when its
		# gun doesn't take the one chosen), and "bot's pick" in that slot
		var opts: Array = [{"id": "bench_any:" + slot, "label": "Bot's pick", "kind": "buy"}]
		var seen: Dictionary = {}
		for bw: WeaponInstance in _bot_guns():
			for o: Variant in WeaponKit.options(bw, slot):
				if seen.has(o):
					continue
				seen[o] = true
				opts.append({"id": "bench_opt:%s:%s" % [slot, str(o)], "label": "%s\n%s" % [WeaponKit.option_name(bw, slot, str(o), false), MarkTargets.money(WeaponKit.price(bw, slot, str(o)))], "kind": "buy"})
		radial.open(pending.get("at", cursor), opts, WeaponKit.slot_name(null, slot))
		return
	if id.begins_with("bench_any:"):
		pending["slot"] = id.get_slice(":", 1)
		pending["option"] = ""
		id = "buy"
	if id.begins_with("bench_opt:"):
		pending["slot"] = id.get_slice(":", 1)
		pending["option"] = id.get_slice(":", 2)
		id = "buy"
	if id == "bench_pick":
		id = "buy"
	pending["kind"] = str(e.get("kind", id))
	match id:
		"note":
			_open_note()
		"danger", "regroup":
			place_pending(MapMarks.default_target(id, marks.has_bots()))
		_:
			if not marks.has_bots():
				place_pending("me")
			else:
				_open_picker()


## Who a mark can be for: [{target, label}] with the default first-picked index. Pure.
static func who_options(kind: String, sub: String, bots: Array) -> Dictionary:
	var out: Array = []
	var buying: bool = kind == "buy" and sub != "power"
	if kind == "buy" and sub == "gun":
		out.append({"target": "me_for", "label": "FOR ME\n(a bot buys it)"})
	elif kind == "buy" and sub == "door":
		out.append({"target": "me", "label": "ME\n(a waypoint)"})
	else:
		out.append({"target": "me", "label": "ME" if kind == "go" else "ME\n(a waypoint)"})
	out.append({"target": "any", "label": "ANY BOT"})
	for b: Variant in bots:
		var d: Dictionary = b
		if bool(d.get("jakub", false)):
			if buying:
				continue   # he has no Scrip, and never a perk machine or the Crucible
			out.append({"target": "jakub", "label": "JAKUB", "pid": int(d["pid"]), "color": d.get("color", Color.WHITE), "jakub": true})
		else:
			out.append({"target": int(d["pid"]), "label": str(d.get("name", "")).to_upper(), "pid": int(d["pid"]), "color": d.get("color", Color.WHITE)})
	var def: String = MapMarks.default_target(kind, true)
	var sel: int = 0
	for i: int in out.size():
		if str(out[i]["target"]) == def:
			sel = i
	return {"options": out, "default": sel}


func _open_picker() -> void:
	_close_popups()
	var c: Dictionary = pending.get("c", {})
	var w: Dictionary = who_options(str(pending.get("kind", "go")), str(c.get("sub", "")), marks.bots())
	_picker = PanelContainer.new()
	_picker.add_theme_stylebox_override("panel", _paper_box(0.98))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_picker.add_child(v)
	var what: String = MapMarks.kind_name(str(pending.get("kind", "go")))
	if str(c.get("label", "")) != "":
		what += ": " + str(c["label"])
	if str(pending.get("slot", "")) != "":
		var ps: String = str(pending["slot"])
		what += " (%s)" % (WeaponKit.any_option_name(ps, str(pending["option"])) if str(pending.get("option", "")) != "" else "bot's pick: " + WeaponKit.slot_name(null, ps))
	v.add_child(_label(what.to_upper(), 16, _red(), true))
	v.add_child(_label("Who is it for?", 14, _faint()))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	_picker_items = []
	var opts: Array = w["options"]
	for i: int in opts.size():
		var o: Dictionary = opts[i]
		var chip: WhoChip = WhoChip.new()
		chip.view = self
		chip.label_text = str(o["label"])
		chip.color = o.get("color", Color(0, 0, 0, 0))
		chip.jakub = bool(o.get("jakub", false))
		chip.portrait = o.has("pid")
		chip.status = marks.status_of(int(o["pid"])) if o.has("pid") else ""
		chip.pressed.connect(_pick.bind(i))
		chip.mouse_entered.connect(func() -> void:
			_picker_sel = i
			_picker_refresh())
		row.add_child(chip)
		_picker_items.append({"target": o["target"], "chip": chip})
	_picker_sel = int(w["default"])
	_area.add_child(_picker)
	_picker.reset_size()
	var at: Vector2 = pending.get("at", cursor)
	_picker.position = (at + Vector2(-_picker.size.x * 0.5, 26)).clamp(Vector2(6, 6), _area.size - _picker.size - Vector2(6, 6))
	_picker_refresh()


func _picker_refresh() -> void:
	for i: int in _picker_items.size():
		var ch: WhoChip = _picker_items[i]["chip"]
		ch.selected = i == _picker_sel
		ch.queue_redraw()


func _picker_move(d: int) -> void:
	if _picker_items.is_empty():
		return
	_picker_sel = posmod(_picker_sel + d, _picker_items.size())
	_picker_refresh()


func _pick(i: int) -> void:
	if i < 0 or i >= _picker_items.size():
		return
	var t: Variant = _picker_items[i]["target"]
	_close_popups()
	var c: Dictionary = pending.get("c", {})
	if str(pending.get("kind", "")) == "buy" and str(c.get("sub", "")) == "door" and str(t) != "me":
		_open_confirm(MarkTargets.door_question(int(c.get("price", 0))), func() -> void: place_pending(t, true))
		return
	place_pending(t)


## Places the pending mark for `target` ("me" / "me_for" / "any" / "jakub" / a pid / "squad").
func place_pending(target: Variant, confirmed: bool = false) -> Dictionary:
	if pending.is_empty() or marks == null:
		return {}
	var c: Dictionary = pending.get("c", {})
	var kind: String = str(pending.get("kind", "go"))
	var spec: Dictionary = {"kind": kind, "pos": pending["pos"], "node": c.get("node"), "target": target, "confirmed": confirmed,
		"owner": Net.local_player_id()}
	if pending.has("poi"):
		spec["poi_id"] = str((pending["poi"] as Dictionary).get("id", ""))
	if str(target) == "me_for":
		spec["target"] = "any"
		spec["for_pid"] = Net.local_player_id()
	var lbl: String = str(c.get("label", ""))
	match kind:
		"go", "defend", "danger", "regroup":
			var z: String = state.data.zone_label_at(pending["pos"] as Vector3) if state != null else ""
			spec["label"] = (z if z != "" else MapMarks.kind_name(kind)) if lbl == "" or kind != "go" else lbl
		"note":
			spec["label"] = str(pending.get("note", "Note"))
		_:
			spec["label"] = lbl if lbl != "" else MapMarks.kind_name(kind)
	if pending.has("slot"):
		spec["slot"] = pending["slot"]
		spec["option"] = pending["option"]
	var res: Dictionary = marks.place(spec)
	if bool(res.get("ok", false)):
		var pid: int = int(res.get("pid", -1))
		var msg: String = "%s: %s" % [MapMarks.kind_name(kind), str(res.get("label", spec["label"]))]
		if pid > 0:
			msg = "%s · %s" % [msg, "Jakub" if pid == 9 else Net.display_name(pid)]
			var st: String = marks.status_of(pid)
			if st != "":
				msg += " · " + st
		elif str(res.get("reason", "")) != "":
			msg += " · " + str(res["reason"])
		if not (res.get("replaced", []) as Array).is_empty():
			msg += "  (your oldest mark went)"
		_show_toast(msg)
	else:
		_show_toast("Can't: %s" % str(res.get("reason", "")))
	mark_placed.emit(res)
	pending = {}
	_refresh_side()
	return res


## Right-click / B on a mark: it goes.
func remove_at(at: Vector2) -> bool:
	if marks == null:
		return false
	var h: Dictionary = canvas.icon_at(at, 16.0)
	if str(h.get("kind", "")) != "marker":
		return false
	marks.remove(int((h["marker"] as Dictionary)["id"]))
	_show_toast("Mark removed.")
	return true


func _open_note() -> void:
	_close_popups()
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", _paper_box(0.98))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_dialog.add_child(v)
	v.add_child(_label("CUSTOM NOTE", 16, _red(), true))
	_note_edit = LineEdit.new()
	_note_edit.max_length = int(MapMarks.cfg().get("note_max_chars", 28))
	_note_edit.placeholder_text = "Type a short note, or pick one"
	_note_edit.custom_minimum_size = Vector2(300, 0)
	_note_edit.text_submitted.connect(func(t: String) -> void: _submit_note(t))
	v.add_child(_note_edit)
	var flow: HFlowContainer = HFlowContainer.new()
	flow.custom_minimum_size = Vector2(320, 0)
	for p: Variant in MapMarks.cfg().get("note_presets", []):
		var pb: Button = _small_button(str(p), _submit_note.bind(str(p)), 13)
		pb.focus_mode = Control.FOCUS_ALL
		flow.add_child(pb)
	v.add_child(flow)
	var row: HBoxContainer = HBoxContainer.new()
	var ok: Button = _small_button("PLACE", func() -> void: _submit_note(_note_edit.text), 15)
	ok.focus_mode = Control.FOCUS_ALL
	row.add_child(ok)
	var cancel: Button = _small_button("CANCEL", _close_popups, 15)
	cancel.focus_mode = Control.FOCUS_ALL
	row.add_child(cancel)
	v.add_child(row)
	_area.add_child(_dialog)
	_dialog.reset_size()
	var at: Vector2 = pending.get("at", cursor)
	_dialog.position = (at + Vector2(-_dialog.size.x * 0.5, 20)).clamp(Vector2(6, 6), _area.size - _dialog.size - Vector2(6, 6))
	_note_edit.grab_focus()


func _submit_note(t: String) -> void:
	var s: String = t.strip_edges()
	if s == "":
		s = "Note"
	pending["note"] = s
	pending["kind"] = "note"
	_close_popups()
	place_pending("me")


func _open_confirm(question: String, yes: Callable) -> void:
	_close_popups()
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", _paper_box(0.98))
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_dialog.add_child(v)
	v.add_child(_label(question, 20, _ink(), true))
	v.add_child(_label("Doors cost the squad's progress: the bot pays from its own Scrip.", 13, _faint()))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var yb: Button = _small_button("YES, OPEN IT", func() -> void:
		_close_popups()
		yes.call(), 17)
	yb.focus_mode = Control.FOCUS_ALL
	row.add_child(yb)
	var nb: Button = _small_button("NO", func() -> void:
		_close_popups()
		pending = {}, 17)
	nb.focus_mode = Control.FOCUS_ALL
	row.add_child(nb)
	_area.add_child(_dialog)
	_dialog.reset_size()
	var at: Vector2 = pending.get("at", cursor)
	_dialog.position = (at + Vector2(-_dialog.size.x * 0.5, 20)).clamp(Vector2(6, 6), _area.size - _dialog.size - Vector2(6, 6))
	yb.grab_focus.call_deferred()


## The question on screen now ("" none): the door confirmation's text (tests, captures).
func dialog_text() -> String:
	if _dialog == null:
		return ""
	for n: Node in _dialog.find_children("*", "Label", true, false):
		return (n as Label).text
	return ""


## Presses the confirmation's first button (tests, captures).
func confirm_dialog(yes: bool = true) -> void:
	if _dialog == null:
		return
	var bs: Array[Node] = _dialog.find_children("*", "Button", true, false)
	if bs.size() >= 2:
		(bs[0 if yes else 1] as Button).pressed.emit()


func picker_open() -> bool:
	return _picker != null


## The who-picker's choice by target ("any", a pid, "me"...), for tests and captures.
func pick_target(t: Variant) -> void:
	for i: int in _picker_items.size():
		if str(_picker_items[i]["target"]) == str(t):
			_pick(i)
			return


func _close_popups() -> void:
	radial.visible = false
	if _picker != null:
		_picker.queue_free()
		_picker = null
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
	_note_edit = null


func _world_at(at: Vector2) -> Vector3:
	var p: Vector3 = canvas.canvas_to_world(at)
	if state == null or not (state.level_root is Node3D) or not (state.level_root as Node3D).is_inside_tree():
		return p
	var nav: RID = (state.level_root as Node3D).get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav) == 0:
		return p
	var q: Vector3 = NavigationServer3D.map_get_closest_point(nav, p + Vector3.UP * 0.6)
	if Vector2(q.x - p.x, q.z - p.z).length() < 2.5 and state.data.floor_at(q + Vector3.UP * 0.2) == canvas.floor_index:
		return q
	return p


func _powerup_near(p: Vector3) -> Node:
	for n: Node in get_tree().get_nodes_in_group(&"powerups"):
		if n is Node3D and (n as Node3D).global_position.distance_to(p) < 1.5:
			return n
	var root: Node = state.level_root if state != null else null
	if root != null:
		for n2: Node in root.find_children("*", "PowerupPickup", true, false):
			if (n2 as Node3D).global_position.distance_to(p) < 1.5:
				return n2
	return null


func _show_toast(t: String) -> void:
	_toast.text = t
	_toast_t = 4.0
	_toast.modulate.a = 1.0


func toast_text() -> String:
	return _toast.text


# ================================================================== the side and the corner

func _refresh_corner() -> void:
	if state == null:
		return
	var r: int = RoundManager.current_round if state.game == "gravelight" else 0
	var pw: String = "POWER ON" if GameState.power_on else "POWER OFF"
	_corner.text = "ROUND %d   ·   %s" % [r, pw] if state.game == "gravelight" else state.data.display_name.to_upper()


func _refresh_side() -> void:
	if marks == null:
		return
	for c: Node in _squad_box.get_children():
		_squad_box.remove_child(c)
		c.queue_free()
	var bots: Array = marks.bots()
	if bots.is_empty():
		_squad_box.add_child(_label("No bots this match: marks are your own waypoints.", 14, _faint()))
	for b: Variant in bots:
		var d: Dictionary = b
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var por: Portrait = Portrait.new()
		por.color = d.get("color", Color.WHITE)
		por.initial = str(d.get("name", "?")).substr(0, 1)
		por.jakub = bool(d.get("jakub", false))
		por.down = bool(d.get("down", false))
		row.add_child(por)
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head: String = str(d.get("name", ""))
		if not bool(d.get("jakub", false)):
			head += "   %s Scrip" % MarkTargets.money(int(d.get("scrip", 0)))
		col.add_child(_label(head, 16, _ink(), true))
		var st: Label = _label(marks.status_of(int(d["pid"])), 14, _red())
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.custom_minimum_size = Vector2(250, 0)
		col.add_child(st)
		row.add_child(col)
		_squad_box.add_child(row)
	for c2: Node in _marks_box.get_children():
		_marks_box.remove_child(c2)
		c2.queue_free()
	var me: int = Net.local_player_id()
	var mine: Array[Dictionary] = marks.personal(me)
	_marks_title.text = "YOUR MARKS  %d / %d" % [mine.size(), MapMarks.limit("personal", 3)]
	for m: Dictionary in marks.marks():
		var line: HBoxContainer = HBoxContainer.new()
		var who: String = ""
		if bool(m.get("order", false)):
			var pid: int = int(m.get("pid", -1))
			who = " → %s" % ("Jakub" if pid == 9 else Net.display_name(pid))
		elif str(m.get("target", "")) == "squad":
			who = " → squad"
		var l: Label = _label("%s %s%s" % [str(MapIcons.MARK_LETTERS.get(str(m.get("kind", "")), "•")), str(m.get("label", "")), who], 14, _ink())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		line.add_child(l)
		var id: int = int(m["id"])
		line.add_child(_small_button("✕", func() -> void:
			marks.remove(id)
			_refresh_side(), 12))
		_marks_box.add_child(line)


# ================================================================== drawing helpers

## Highlights, the hover ring, the pending spot, the controller's crosshair.
class Overlay extends Control:
	var view: PauseMapView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if view == null or view.canvas == null or view.state == null:
			return
		var t: float = Time.get_ticks_msec() / 1000.0
		var red: Color = view._red()
		var now: int = Time.get_ticks_msec()
		var keep: Array[Dictionary] = []
		for h: Dictionary in view._highlights:
			if int(h["until"]) < now:
				continue
			keep.append(h)
			var p: Vector2 = view.canvas.world_to_canvas(h["pos"] as Vector3)
			var r: float = 16.0 + 6.0 * sin(t * 5.0)
			draw_arc(p, r, 0.0, TAU, 40, red, 3.0)
			draw_arc(p, r + 9.0, 0.0, TAU, 40, Color(red.r, red.g, red.b, 0.4), 2.0)
		view._highlights = keep
		if not view._hover.is_empty():
			var hp: Vector2 = view._hover["pos"]
			draw_arc(hp, float(view._hover.get("r", 16.0)) * 0.7 + 4.0, 0.0, TAU, 28, Color(red.r, red.g, red.b, 0.8), 2.0)
		if not view.pending.is_empty() and view.pending.has("pos"):
			var pp: Vector2 = view.canvas.world_to_canvas(view.pending["pos"] as Vector3)
			draw_circle(pp, 5.0, red)
			draw_arc(pp, 11.0, 0.0, TAU, 24, red, 2.0)
		if view.pad_cursor:
			var c: Vector2 = view.cursor
			var ink: Color = view._ink()
			draw_arc(c, 10.0, 0.0, TAU, 24, ink, 2.0)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				draw_line(c + d * 6.0, c + d * 16.0, ink, 2.0)


## The legend: every icon with its word, in two columns.
class Legend extends Control:
	var view: PauseMapView

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(250, 150)

	func _draw() -> void:
		if view == null:
			return
		var rows: Array = PauseMapView.LEGEND_BS if view.skin == "holo" else PauseMapView.LEGEND
		var n: int = int(ceil(rows.size() / 2.0))
		size = Vector2(250, 20.0 * n + 12.0)
		var bg: Color = Color(0.9, 0.86, 0.75, 0.88) if view.skin == "ledger" else Color(0.02, 0.06, 0.1, 0.85)
		draw_rect(Rect2(Vector2.ZERO, size), bg)
		draw_rect(Rect2(Vector2.ZERO, size), view._faint(), false, 1.0)
		var f: Font = MenuKit.type_font()
		for i: int in rows.size():
			var col: int = i / n
			var r: int = i % n
			var p: Vector2 = Vector2(16.0 + col * 124.0, 16.0 + r * 20.0)
			var kind: String = str(rows[i][0])
			var c: Color = view.canvas.icon_color(kind) if kind != "bot" else Color("#3f7fbf")
			if kind == "player":
				MapIcons.draw_player(self, p, Vector2.UP, 14.0, view.canvas.icon_color("player"))
			elif kind == "marker":
				MapIcons.draw(self, "marker", p, 14.0, MapMarks.kind_color("buy"), {"mark": "buy"})
			else:
				MapIcons.draw(self, kind, p, 13.0, c, {"initial": "D" if kind == "bot" else ""})
			draw_string(f, p + Vector2(14, 5), str(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, view._ink())


## A bot's portrait: its body icon in its colour with the initial (Jakub his shield), greyed when down.
class Portrait extends Control:
	var color: Color = Color.WHITE
	var initial: String = "?"
	var jakub: bool = false
	var down: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Color = color if not down else color.lerp(Color(0.4, 0.4, 0.4), 0.6)
		MapIcons.draw(self, "jakub" if jakub else "bot", size * 0.5, 32.0, c, {"initial": "J" if jakub else initial.to_upper()})
		if down:
			draw_line(Vector2(6, 6), size - Vector2(6, 6), Color(0.7, 0.1, 0.08), 3.0)


## A who-picker chip: Me / Any bot / a bot's portrait and name (with its current order underneath).
class WhoChip extends Button:
	var view: PauseMapView
	var color: Color = Color(0, 0, 0, 0)
	var jakub: bool = false
	var portrait: bool = false
	var selected: bool = false
	var status: String = ""
	var label_text: String = ""

	func _init() -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(112, 96)
		flat = true

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var ink: Color = view._ink() if view != null else Color.BLACK
		var red: Color = view._red() if view != null else Color.RED
		draw_rect(r, Color(1, 1, 1, 0.25) if not selected else Color(red.r, red.g, red.b, 0.22))
		draw_rect(r, red if selected else Color(ink.r, ink.g, ink.b, 0.4), false, 3.0 if selected else 1.0)
		var f: Font = MenuKit.stamp_font()
		var y: float = 16.0
		if portrait:
			MapIcons.draw(self, "jakub" if jakub else "bot", Vector2(size.x * 0.5, 24.0), 30.0, color, {"initial": label_text.substr(0, 1)})
			y = 52.0
		var lines: PackedStringArray = label_text.split("\n")
		for i: int in lines.size():
			var fs: int = 14 if i == 0 else 11
			var w: float = f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2((size.x - w) * 0.5, y + i * 15.0 + 8.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		if status != "" and portrait:
			var tf: Font = MenuKit.type_font()
			var s: String = status
			while s.length() > 4 and tf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > size.x - 10.0:
				s = s.substr(0, s.length() - 3) + ".."
				s = s.replace("....", "..")
			var w2: float = tf.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(tf, Vector2((size.x - w2) * 0.5, size.y - 6.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ink.r, ink.g, ink.b, 0.75))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT:
			queue_redraw()


## The marking radial: up to eight segments round the clicked spot; the mouse (or the left stick) points, a click
## (or A) picks, right-click / B / Esc backs out.
class Radial extends Control:
	signal chosen(entry: Dictionary)
	var view: PauseMapView
	var entries: Array = []
	var center: Vector2 = Vector2.ZERO
	var sel: int = -1
	var title: String = ""
	const R_OUT: float = 118.0
	const R_IN: float = 30.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func open(at: Vector2, list: Array, t: String) -> void:
		entries = list
		title = t
		center = at.clamp(Vector2(R_OUT + 10.0, R_OUT + 30.0), size - Vector2(R_OUT + 10.0, R_OUT + 10.0)) if size.x > R_OUT * 2.5 else at
		sel = 0 if entries.size() == 1 else -1
		visible = true
		queue_redraw()

	func _seg_angle(i: int) -> float:
		return -PI * 0.5 + TAU * float(i) / float(maxi(1, entries.size()))

	func pointer(p: Vector2) -> void:
		var d: Vector2 = p - center
		if d.length() < R_IN * 0.7:
			sel = -1
		else:
			sel = _index_for(d.angle())
		queue_redraw()

	func stick(v: Vector2) -> void:
		if v.length() > 0.5:
			sel = _index_for(v.angle())
			queue_redraw()

	func _index_for(a: float) -> int:
		var n: int = entries.size()
		var step: float = TAU / float(maxi(1, n))
		return posmod(roundi((a + PI * 0.5) / step), n)

	func confirm() -> void:
		if sel < 0 or sel >= entries.size():
			visible = false
			return
		var e: Dictionary = entries[sel]
		visible = false
		chosen.emit(e)

	## Picks an entry by id (tests, captures).
	func choose_id(id: String) -> bool:
		for i: int in entries.size():
			if str((entries[i] as Dictionary).get("id", "")) == id:
				sel = i
				confirm()
				return true
		return false

	func ids() -> PackedStringArray:
		var out: PackedStringArray = []
		for e: Variant in entries:
			out.append(str((e as Dictionary).get("id", "")))
		return out

	func _draw() -> void:
		if view == null or entries.is_empty():
			return
		var n: int = entries.size()
		var ledger: bool = view.skin == "ledger"
		var bg: Color = Color(0.16, 0.12, 0.08, 0.82) if ledger else Color(0.02, 0.07, 0.12, 0.88)
		var hi: Color = view._red()
		var txt: Color = Color(0.96, 0.92, 0.84) if ledger else ObjectivesView.HOLO_TEXT
		draw_circle(center, R_OUT + 6.0, bg)
		var step: float = TAU / float(n)
		for i: int in n:
			var a0: float = _seg_angle(i) - step * 0.5
			var a1: float = a0 + step
			if i == sel:
				var pts: PackedVector2Array = []
				for k: int in 13:
					pts.append(center + Vector2.from_angle(lerpf(a0, a1, k / 12.0)) * R_OUT)
				for k2: int in range(12, -1, -1):
					pts.append(center + Vector2.from_angle(lerpf(a0, a1, k2 / 12.0)) * R_IN)
				draw_colored_polygon(pts, Color(hi.r, hi.g, hi.b, 0.85))
			if n > 1:
				draw_line(center + Vector2.from_angle(a0) * R_IN, center + Vector2.from_angle(a0) * R_OUT, Color(txt.r, txt.g, txt.b, 0.3), 1.5)
			var e: Dictionary = entries[i]
			var f: Font = MenuKit.stamp_font()
			var lines: PackedStringArray = str(e.get("label", "")).split("\n")
			var mid: Vector2 = center + Vector2.from_angle(_seg_angle(i)) * (R_OUT * 0.64 if n > 1 else 0.0)
			for li: int in lines.size():
				var fs: int = 13 if lines[li].length() > 12 else 15
				if li > 0:
					fs = 12
				var w: float = f.get_string_size(lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var at: Vector2 = mid + Vector2(-w * 0.5, 5.0 + (li - (lines.size() - 1) * 0.5) * 15.0)
				draw_string_outline(f, at, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
				draw_string(f, at, lines[li], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, txt)
		draw_arc(center, R_OUT, 0.0, TAU, 64, Color(txt.r, txt.g, txt.b, 0.6), 2.0)
		draw_arc(center, R_IN, 0.0, TAU, 32, Color(txt.r, txt.g, txt.b, 0.6), 2.0)
		if title != "":
			var tf: Font = MenuKit.stamp_font()
			var tw: float = tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var tp: Vector2 = center + Vector2(-tw * 0.5, -R_OUT - 14.0)
			draw_rect(Rect2(tp + Vector2(-6, -16), Vector2(tw + 12, 22)), bg)
			draw_string(tf, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, txt)
