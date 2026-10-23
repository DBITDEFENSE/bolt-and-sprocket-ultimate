class_name Minimap
extends Control
## The HUD minimap (Update 04 section 2, DECISIONS T-065), top-left by default, drawn from the pre-baked floor
## images (no live 3D render) by a MapCanvas inside a circular (or rounded-square) mask:
##   GRAVELIGHT: a brass compass bezel with N/E/S/W on the ring, the zone you are in stamped under it in the
##     round counter's red ledger-stamp ink, the floor name typed below;
##   B&S: a cyan holo ring with orange ticks; the HP panel moves under it (BSHud).
## Shows the player arrow at the centre, teammates / bots / Jakub / the downed, marks, doors, discovered buyables,
## power-ups (blinking), the boss, objectives (spoiler setting), zombies per the setting, stairs / ladder / lift
## arrows, the other floors ghosted, the fog of war. Everything it shows comes from MapState.
##
## Settings (GLSettings.values; the GRAVELIGHT settings menu "Minimap" rows; B&S reads the same values):
##   classic_hud (minimap off), minimap_rotate, minimap_zoom (0..2, also the "minimap_zoom" key), minimap_size,
##   minimap_opacity, minimap_position ("tl" / "tr"), minimap_icon_scale, minimap_shape ("circle" / "square"),
##   minimap_cb_shapes, minimap_zombies ("off" / "firing" / "always"), minimap_fog ("visit" / "always").
## Other HUD elements read Minimap.layout_bottom / layout_rect to stay clear of it.

const BRASS_DARK: Color = Color(0.36, 0.25, 0.1)
const BRASS: Color = Color(0.72, 0.55, 0.25)
const BRASS_HI: Color = Color(0.95, 0.83, 0.5)
const INK: Color = Color(0.62, 0.09, 0.08)
const PAPER: Color = Color(0.93, 0.89, 0.8)
const HOLO: Color = Color("#4fe6ff")
const HOLO_ORANGE: Color = Color("#ff9a3c")
const DEFAULTS: Dictionary = {
	"classic_hud": false, "minimap_rotate": true, "minimap_zoom": 1, "minimap_size": 1.0, "minimap_opacity": 0.92,
	"minimap_position": "tl", "minimap_icon_scale": 1.0, "minimap_shape": "circle", "minimap_cb_shapes": false,
	"minimap_zombies": "firing", "minimap_fog": "visit",
}

## Bottom edge (canvas px) of the minimap and its labels when it is shown top-left, else 0; and its rect.
static var layout_bottom: float = 0.0
static var layout_rect: Rect2 = Rect2()

var game: String = "gravelight"
var canvas: MapCanvas
var zoom_level: int = 1
var _mask: ShapeMask
var _frame: Frame
var _zone: Label
var _floor: Label
var _stamp_box: PanelContainer
var _state: MapState = null
var _diam: float = 250.0
var _settings_t: float = 0.0
var _cfg: Dictionary = {}
var _process_usec: int = 0
var _avg_usec: float = 0.0
var _rotate: bool = true
var _pos_tr: bool = false
var _label_t: float = 0.0
var _layout_key: String = ""
var _frame_heading: float = INF


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	name = "Minimap"


## A setting with the minimap's default.
static func setting(key: String) -> Variant:
	return GLSettings.values.get(key, DEFAULTS.get(key))


## Forwards a map mark to the match's MapState (see MapState.add_marker); -1 without one.
static func add_marker(m: Dictionary) -> int:
	var ms: MapState = MapState.current()
	return ms.add_marker(m) if ms != null else -1


static func markers() -> Array[Dictionary]:
	var ms: MapState = MapState.current()
	return ms.markers() if ms != null else ([] as Array[Dictionary])


func _ready() -> void:
	_cfg = MapScan._json(MapState.CONFIG)
	_mask = ShapeMask.new()
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_mask)
	canvas = MapCanvas.new()
	canvas.clamp_to_rim = true
	canvas.record_hits = false
	_mask.add_child(canvas)
	_frame = Frame.new()
	_frame.owner_map = self
	add_child(_frame)
	_stamp_box = PanelContainer.new()
	_stamp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0)
	sb.border_color = INK if game == "gravelight" else HOLO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	_stamp_box.add_theme_stylebox_override("panel", sb)
	add_child(_stamp_box)
	_zone = Label.new()
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stamp_font: SystemFont = SystemFont.new()
	stamp_font.font_names = PackedStringArray(["Stencil", "Impact", "Arial Black"])
	_zone.add_theme_font_override("font", stamp_font)
	_zone.add_theme_font_size_override("font_size", 22)
	_zone.add_theme_color_override("font_color", INK if game == "gravelight" else HOLO)
	_zone.add_theme_constant_override("outline_size", 3)
	_zone.add_theme_color_override("font_outline_color", Color(PAPER.r, PAPER.g, PAPER.b, 0.35) if game == "gravelight" else Color(0, 0, 0, 0.8))
	_stamp_box.add_child(_zone)
	_floor = Label.new()
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var type_font: SystemFont = SystemFont.new()
	type_font.font_names = PackedStringArray(["Courier New", "Consolas", "Monospace"])
	type_font.font_weight = 700
	_floor.add_theme_font_override("font", type_font)
	_floor.add_theme_font_size_override("font_size", 15)
	_floor.add_theme_color_override("font_color", PAPER if game == "gravelight" else HOLO)
	_floor.add_theme_constant_override("outline_size", 4)
	_floor.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	add_child(_floor)
	_apply_settings()


func _exit_tree() -> void:
	layout_bottom = 0.0
	layout_rect = Rect2()


func _apply_settings() -> void:
	var on: bool = not bool(setting("classic_hud"))
	_rotate = bool(setting("minimap_rotate"))
	_pos_tr = str(setting("minimap_position")) == "tr"
	zoom_level = clampi(int(setting("minimap_zoom")), 0, 2)
	_diam = float(_cfg.get("size_px", 250.0)) * clampf(float(setting("minimap_size")), 0.6, 1.6)
	canvas.icon_scale = clampf(float(setting("minimap_icon_scale")), 0.6, 2.0)
	canvas.cb_shapes = bool(setting("minimap_cb_shapes"))
	canvas.opacity = clampf(float(setting("minimap_opacity")), 0.2, 1.0)
	canvas.show_fog = str(setting("minimap_fog")) != "always"
	if _mask.square != (str(setting("minimap_shape")) == "square"):
		_mask.square = not _mask.square
		_mask.queue_redraw()
		_frame_heading = INF
	_frame.square = _mask.square
	visible = on and _state != null


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_settings_t -= delta
	if _settings_t <= 0.0:
		_settings_t = 0.5
		if _state == null or not is_instance_valid(_state):
			_state = MapState.current()
			canvas.set_state(_state)
		_apply_settings()
	if InputMap.has_action(&"minimap_zoom") and Input.is_action_just_pressed(&"minimap_zoom") and visible:
		zoom_level = (zoom_level + 1) % 3
		GLSettings.values["minimap_zoom"] = zoom_level
	if not visible or _state == null:
		layout_bottom = 0.0
		layout_rect = Rect2()
		return
	var body: Node3D = _state.local_body()
	if body != null and is_instance_valid(body):
		var pos: Vector3 = body.global_position
		var fi: int = _state.data.floor_at(pos + Vector3.UP * 0.2)
		canvas.floor_index = fi
		canvas.center = Vector2(pos.x, pos.z)
		canvas.heading = _state.view_yaw() if _rotate else 0.0   # ahead on screen = up on the map
		var radii: Array = _cfg.get("view_radius_m", [16.0, 26.0, 42.0])
		canvas.zoom = (_diam * 0.5) / float(radii[clampi(zoom_level, 0, radii.size() - 1)])
		_label_t -= delta
		if _label_t <= 0.0:   # the zone / floor labels, 4 times a second
			_label_t = 0.25
			_zone.text = short_label(_state.data.zone_label_at(pos), _state.data.display_name).to_upper()
			_floor.text = _state.data.floor_name(fi) if _state.data.floors.size() > 1 else ""
	var key: String = "%s|%s|%s|%s|%s" % [get_viewport().get_visible_rect().size, _diam, _pos_tr, _zone.text, _floor.text]
	if key != _layout_key:   # the layout only when something it depends on changed
		_layout_key = key
		_layout()
	if not is_equal_approx(_frame_heading, canvas.heading):
		_frame_heading = canvas.heading
		_frame.queue_redraw()
	_process_usec = Time.get_ticks_usec() - t0
	_avg_usec = lerpf(_avg_usec, float(_process_usec + canvas.cost_usec + canvas.draw_usec), 0.05)


## Where cardinal point k (0 N, 1 E, 2 S, 3 W) sits on the bezel, as a unit canvas direction, when the map is turned
## by `heading` (MapCanvas.heading): exactly where MapCanvas draws that world direction, so letters and map agree.
static func cardinal_dir(k: int, heading: float) -> Vector2:
	var world: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][k]   # XZ: north = -Z, east = +X
	return world.rotated(heading)


## The zone label for the stamp: "" -> the map's name; long names keep the part after a colon ("The Junction:
## landing yard" -> "landing yard") and are cut at 24 characters.
static func short_label(zone: String, fallback: String) -> String:
	var t: String = zone if zone != "" else fallback
	if t.length() > 20 and t.contains(":"):
		t = t.get_slice(":", t.get_slice_count(":") - 1).strip_edges()
	if t.length() > 24:
		t = t.substr(0, 23).strip_edges() + "."
	return t


## Rolling average of the minimap's CPU cost per frame (its update + the canvas update + the redraws), microseconds.
func perf_usec() -> float:
	return _avg_usec


func _layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var m: Array = _cfg.get("margin_px", [26.0, 24.0])
	var ring: float = 14.0
	var x: float = vp.x - float(m[0]) - _diam - ring if _pos_tr else float(m[0]) + ring
	var y: float = float(m[1]) + ring
	position = Vector2.ZERO
	size = vp
	_mask.position = Vector2(x, y)
	_mask.size = Vector2(_diam, _diam)
	canvas.position = Vector2.ZERO
	canvas.size = _mask.size
	canvas.rim_radius = _diam * 0.5 if not _mask.square else 0.0
	_frame.position = _mask.position - Vector2(ring, ring)
	_frame.size = _mask.size + Vector2(ring, ring) * 2.0
	_stamp_box.reset_size()
	var sbw: float = _stamp_box.get_combined_minimum_size().x
	_stamp_box.position = Vector2(clampf(x + _diam * 0.5 - sbw * 0.5, 6.0, vp.x - sbw - 6.0), y + _diam + ring + 4.0)
	_stamp_box.pivot_offset = _stamp_box.size * 0.5
	_stamp_box.rotation = deg_to_rad(-3.0) if game == "gravelight" else 0.0
	_floor.reset_size()
	_floor.position = Vector2(x + _diam * 0.5 - _floor.size.x * 0.5, _stamp_box.position.y + _stamp_box.size.y + 2.0)
	var bottom: float = _floor.position.y + (_floor.size.y if _floor.text != "" else 0.0)
	layout_rect = Rect2(Vector2(x - ring, y - ring), Vector2(_diam + ring * 2.0, bottom - (y - ring)))
	layout_bottom = bottom if not _pos_tr else 0.0


## The clip shape: a disc or a rounded square (CLIP_CHILDREN_ONLY: only its alpha is used).
class ShapeMask extends Control:
	var square: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if square:
			var sb: StyleBoxFlat = StyleBoxFlat.new()
			sb.bg_color = Color.WHITE
			sb.set_corner_radius_all(int(size.x * 0.12))
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		else:
			draw_circle(size * 0.5, size.x * 0.5, Color.WHITE)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## The bezel: brass compass ring (GRAVELIGHT) or holo ring (B&S), with the cardinal points turning with the map.
class Frame extends Control:
	var owner_map: Minimap
	var square: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r_out: float = size.x * 0.5
		var r_in: float = r_out - 14.0
		var heading: float = owner_map.canvas.heading if owner_map != null and owner_map.canvas != null else 0.0
		var gl: bool = owner_map == null or owner_map.game == "gravelight"
		if square:
			_square_frame(c, r_out, r_in, gl)
		elif gl:
			draw_arc(c, r_out - 1.0, 0.0, TAU, 96, BRASS_DARK, 3.0, true)
			draw_arc(c, r_out - 7.0, 0.0, TAU, 96, BRASS, 10.0, true)
			draw_arc(c, r_out - 5.0, PI * 1.05, PI * 1.6, 32, BRASS_HI, 3.0, true)   # the light on the brass
			draw_arc(c, r_in, 0.0, TAU, 96, BRASS_DARK, 2.0, true)
			for i: int in 72:
				var a: float = TAU * i / 72.0 + heading
				var dir: Vector2 = Vector2(sin(a), -cos(a))
				var long: bool = i % 9 == 0
				draw_line(c + dir * (r_in + 1.0), c + dir * (r_in + (8.0 if long else 4.0)), BRASS_DARK, 2.0 if long else 1.0)
		else:
			draw_arc(c, r_in + 3.0, 0.0, TAU, 96, Color(HOLO.r, HOLO.g, HOLO.b, 0.25), 9.0, true)
			draw_arc(c, r_in + 3.0, 0.0, TAU, 96, HOLO, 2.5, true)
			for i2: int in 4:
				var a2: float = TAU * i2 / 4.0 + heading
				var d2: Vector2 = Vector2(sin(a2), -cos(a2))
				draw_line(c + d2 * (r_in - 2.0), c + d2 * (r_in + 9.0), HOLO_ORANGE, 3.0)
		# cardinal letters
		var f: Font = MapIcons.font()
		var letters: Array = ["N", "E", "S", "W"]
		for k: int in 4:
			var d3: Vector2 = Minimap.cardinal_dir(k, heading)
			var p: Vector2 = c + d3 * (r_out - 7.0)
			var fs: int = 15 if k == 0 else 12
			var w: float = f.get_string_size(letters[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var col: Color = (INK if k == 0 else Color(0.15, 0.1, 0.05)) if gl else (HOLO_ORANGE if k == 0 else HOLO)
			if gl:
				draw_circle(p, 8.0, BRASS_HI if k == 0 else BRASS)
			else:
				draw_circle(p, 8.0, Color(0.03, 0.08, 0.14, 0.9))
			draw_string(f, p + Vector2(-w * 0.5, fs * 0.36), letters[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		# lubber mark: "ahead" at the top
		var top: Vector2 = c + Vector2(0, -r_in + 2.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, 7), top + Vector2(-5, -2), top + Vector2(5, -2)]), INK if gl else HOLO_ORANGE)

	func _square_frame(c: Vector2, r_out: float, r_in: float, gl: bool) -> void:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(int((r_in * 2.0) * 0.12) + 12)
		sb.border_color = BRASS if gl else HOLO
		sb.set_border_width_all(10 if gl else 3)
		draw_style_box(sb, Rect2(c - Vector2(r_out, r_out) + Vector2(2, 2), Vector2(r_out, r_out) * 2.0 - Vector2(4, 4)))
		var sb2: StyleBoxFlat = StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_corner_radius_all(int((r_in * 2.0) * 0.12) + 2)
		sb2.border_color = BRASS_DARK if gl else Color(HOLO.r, HOLO.g, HOLO.b, 0.3)
		sb2.set_border_width_all(2)
		draw_style_box(sb2, Rect2(c - Vector2(r_in, r_in) - Vector2(1, 1), Vector2(r_in, r_in) * 2.0 + Vector2(2, 2)))
