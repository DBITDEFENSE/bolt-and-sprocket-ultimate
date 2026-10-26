class_name Minimap
extends Control
## The HUD minimap (Update 04 section 2, DECISIONS T-065), top-left by default, drawn from the pre-baked floor
## images (no live 3D render) by a MapCanvas inside a circular (or rounded-square) mask:
##   GRAVELIGHT: a drawn brass compass bezel (T-096: bevelled ring, screws, intercardinal rose points on the tick
##     ring, a faint etched rose and a glass glint over the map, N/E/S/W on the ring), the zone you are in stamped
##     under it in the round counter's red ledger-stamp ink, the floor name typed below;
##   B&S: a cyan holo ring with orange ticks; the HP panel moves under it (BSHud).
## Shows the player arrow at the centre, teammates / bots / Jakub / the downed, marks, doors, discovered buyables,
## power-ups (blinking), the boss, objectives (spoiler setting), zombies per the setting, stairs / ladder / lift
## arrows, the other floors ghosted, the fog of war. Everything it shows comes from MapState.
##
## Settings (GLSettings.values; the GRAVELIGHT settings menu "Minimap" rows; B&S reads the same values):
##   classic_hud (minimap off), minimap_rotate, minimap_zoom (0..2, also the "minimap_zoom" key), minimap_size,
##   minimap_opacity, minimap_position ("tl" / "tr"), minimap_icon_scale, minimap_shape ("circle" / "square"),
##   minimap_cb_shapes, minimap_zombies ("off" / "firing" / "always"), minimap_fog ("visit" / "always").
## Open ground (T-096, ui.json minimap): a zone whose bounding box covers more than outdoor_zone_frac of the map's
## rect (Map 0's Grounds, 104 x 118 m) steps the view out by outdoor_zoom_step levels, so the field reads at the
## same density as a room; indoors the chosen zoom level holds.
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
## The zoom level in use this frame (zoom_level, stepped out on open ground).
var zoom_level_effective: int = 1
var _mask: ShapeMask
var _glass: Glass
var _frame: Frame
var _zone: Label
var _floor: Label
var _stamp_box: PanelContainer
var _state: MapState = null
var _diam: float = 250.0
var _ring: float = 14.0
var _settings_t: float = 0.0
var _cfg: Dictionary = {}
var _ui: Dictionary = {}
var _process_usec: int = 0
var _avg_usec: float = 0.0
var _rotate: bool = true
var _pos_tr: bool = false
var _label_t: float = 0.0
var _layout_vp: Vector2 = Vector2(-1, -1)
var _layout_diam: float = -1.0
var _layout_tr: bool = false
var _layout_zone: String = ""
var _layout_floor: String = ""
var _frame_heading: float = INF
var _big_zones: Dictionary = {}   # zone id -> true when it is open ground (see outdoor_zone_frac)
var _big_zones_for: MapData = null
var _outdoor: bool = false


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


## The zone ids of `md` that count as open ground: a bounding box over `frac` of the map's world rect.
static func big_zones(md: MapData, frac: float) -> Dictionary:
	var out: Dictionary = {}
	if md == null:
		return out
	var total: float = maxf(1.0, md.world_rect.get_area())
	for z: Dictionary in md.zones:
		var r: Rect2 = Rect2()
		var first: bool = true
		for poly: Variant in z.get("polys", []):
			for q: Variant in poly:
				var p: Vector2 = q as Vector2 if q is Vector2 else Vector2(float((q as Array)[0]), float((q as Array)[1]))
				if first:
					r = Rect2(p, Vector2.ZERO)
					first = false
				else:
					r = r.expand(p)
		if not first and r.get_area() / total > frac:
			out[str(z.get("id", ""))] = true
	return out


func _ready() -> void:
	_cfg = MapScan._json(MapState.CONFIG)
	_ui = MenuKit.cfg().get("minimap", {})
	_ring = float(_ui.get("ring_px", 14.0)) if game == "gravelight" else 14.0
	_mask = ShapeMask.new()
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_mask)
	canvas = MapCanvas.new()
	canvas.clamp_to_rim = true
	canvas.record_hits = false
	_mask.add_child(canvas)
	_glass = Glass.new()
	_glass.owner_map = self
	_mask.add_child(_glass)
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
	sb.content_margin_bottom = 1
	if game == "gravelight":
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		sb.shadow_offset = Vector2(1, 2)
	_stamp_box.add_theme_stylebox_override("panel", sb)
	add_child(_stamp_box)
	_zone = Label.new()
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone.add_theme_font_override("font", MenuKit.stamp_font())
	_zone.add_theme_font_size_override("font_size", MenuKit.size("hud_zone_stamp"))
	_zone.add_theme_color_override("font_color", INK if game == "gravelight" else HOLO)
	if game == "gravelight":
		MenuKit.outline(_zone, "stamp")
	else:
		_zone.add_theme_constant_override("outline_size", 3)
		_zone.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_stamp_box.add_child(_zone)
	_floor = Label.new()
	_floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor.add_theme_font_override("font", MenuKit.type_font())
	_floor.add_theme_font_size_override("font_size", MenuKit.size("hud_floor"))
	_floor.add_theme_color_override("font_color", PAPER if game == "gravelight" else HOLO)
	MenuKit.outline(_floor, "hud")
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
		_glass.queue_redraw()
		_frame_heading = INF
	_frame.square = _mask.square
	_glass.square = _mask.square
	visible = on and _state != null


## Whether `pos` is on open ground (a big zone, see big_zones) on this map.
func is_outdoor(pos: Vector3) -> bool:
	if _state == null:
		return false
	if _big_zones_for != _state.data:
		_big_zones_for = _state.data
		_big_zones = big_zones(_state.data, float(_ui.get("outdoor_zone_frac", 0.5)))
	return _big_zones.has(_state.data.zone_at(pos))


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
		_label_t -= delta
		if _label_t <= 0.0:   # the zone / floor labels and the open-ground check, 4 times a second
			_label_t = 0.25
			_zone.text = short_label(_state.data.zone_label_at(pos), _state.data.display_name).to_upper()
			_floor.text = _state.data.floor_name(fi) if _state.data.floors.size() > 1 else ""
			_outdoor = is_outdoor(pos)
		zoom_level_effective = clampi(zoom_level + (int(_ui.get("outdoor_zoom_step", 1)) if _outdoor else 0), 0, radii.size() - 1)
		var want_zoom: float = (_diam * 0.5) / float(radii[zoom_level_effective])
		canvas.zoom = want_zoom if canvas.zoom <= 0.0 else lerpf(canvas.zoom, want_zoom, clampf(delta * 6.0, 0.0, 1.0))
	var vps: Vector2 = get_viewport().get_visible_rect().size
	if vps != _layout_vp or _diam != _layout_diam or _pos_tr != _layout_tr or _zone.text != _layout_zone or _floor.text != _layout_floor:
		_layout_vp = vps   # the layout only when something it depends on changed
		_layout_diam = _diam
		_layout_tr = _pos_tr
		_layout_zone = _zone.text
		_layout_floor = _floor.text
		_layout()
	if not is_equal_approx(_frame_heading, canvas.heading):
		_frame_heading = canvas.heading
		_frame.turn(canvas.heading)   # the ticks and letters move; nothing is redrawn (T-070)
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
	var mx: float = float(m[0])
	var my: float = float(m[1])
	if game == "gravelight":   # the HUD grid (T-096): the bezel's outer edge sits on the margin
		var hm: Vector2 = MenuKit.hud_margin(vp)
		mx = hm.x - _ring
		my = hm.y - _ring
	var ring: float = _ring
	var x: float = vp.x - mx - _diam - ring if _pos_tr else mx + ring
	var y: float = my + ring
	position = Vector2.ZERO
	size = vp
	_mask.position = Vector2(x, y)
	_mask.size = Vector2(_diam, _diam)
	canvas.position = Vector2.ZERO
	canvas.size = _mask.size
	canvas.rim_radius = _diam * 0.5 if not _mask.square else 0.0
	_glass.position = Vector2.ZERO
	_glass.size = _mask.size
	_frame.position = _mask.position - Vector2(ring, ring)
	_frame.size = _mask.size + Vector2(ring, ring) * 2.0
	_stamp_box.reset_size()
	var sbw: float = _stamp_box.get_combined_minimum_size().x
	_stamp_box.position = Vector2(clampf(x + _diam * 0.5 - sbw * 0.5, 6.0, vp.x - sbw - 6.0), y + _diam + ring + 6.0)
	_stamp_box.pivot_offset = _stamp_box.size * 0.5
	_stamp_box.rotation = deg_to_rad(-3.0) if game == "gravelight" else 0.0
	_floor.reset_size()
	_floor.position = Vector2(x + _diam * 0.5 - _floor.size.x * 0.5, _stamp_box.position.y + _stamp_box.size.y + 4.0)
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


## The glass over the map (inside the mask, over the canvas): a soft glint top-left, a darker vignette at the rim
## (GRAVELIGHT only; B&S keeps its clean holo panel). Static: drawn once per size.
class Glass extends Control:
	var owner_map: Minimap
	var square: bool = false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		if owner_map != null and owner_map.game != "gravelight":
			return
		var a: float = float(MenuKit.cfg().get("minimap", {}).get("glint_alpha", 0.13))
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.5
		if square:
			return
		# the rim shade: the glass darkens towards the bezel
		for k: int in 5:
			draw_arc(c, r - 2.0 - k * 3.0, 0.0, TAU, 96, Color(0.1, 0.07, 0.03, 0.16 - k * 0.03), 3.2, true)
		# the glint: a broad light arc in the upper left, a thin bright one just inside the rim
		draw_arc(c + Vector2(-r * 0.08, -r * 0.08), r * 0.78, PI * 1.08, PI * 1.5, 40, Color(1, 1, 1, a * 0.5), r * 0.16, true)
		draw_arc(c, r - 6.0, PI * 1.12, PI * 1.46, 40, Color(1, 1, 1, a), 2.5, true)
		draw_arc(c, r - 9.0, PI * 0.1, PI * 0.42, 40, Color(1, 1, 1, a * 0.45), 1.5, true)


## The bezel: brass compass ring (GRAVELIGHT) or holo ring (B&S), with the cardinal points turning with the map.
## Retained (T-070): the rings are drawn once; the tick ring is a child turned by the heading and each cardinal
## letter a child moved round the ring, so a turning player moves four nodes instead of redrawing ~90 shapes a frame.
class Frame extends Control:
	var owner_map: Minimap
	var square: bool = false:
		set(v):
			if v == square:
				return
			square = v
			queue_redraw()
			if _ticks != null:
				_ticks.visible = not v
	var _ticks: Ticks
	var _letters: Array[Letter] = []
	var _lubber: Lubber
	var _heading: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ticks = Ticks.new()
		_ticks.frame = self
		add_child(_ticks)
		for k: int in 4:
			var l: Letter = Letter.new()
			l.frame = self
			l.k = k
			add_child(l)
			_letters.append(l)
		_lubber = Lubber.new()
		_lubber.frame = self
		add_child(_lubber)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
			for n: CanvasItem in [_ticks, _lubber] + _letters:
				n.queue_redraw()
			turn(_heading)

	func gl() -> bool:
		return owner_map == null or owner_map.game == "gravelight"

	func ring() -> float:
		return owner_map._ring if owner_map != null else 14.0

	func r_out() -> float:
		return size.x * 0.5

	func r_in() -> float:
		return r_out() - ring()

	## Places the turning parts for the map's heading (MapCanvas.heading).
	func turn(heading: float) -> void:
		_heading = heading
		var c: Vector2 = size * 0.5
		_ticks.position = c
		_ticks.rotation = heading
		_lubber.position = c
		for l: Letter in _letters:
			l.position = c + Minimap.cardinal_dir(l.k, heading) * (r_out() - ring() * 0.5)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var ro: float = r_out()
		var ri: float = r_in()
		if square:
			_square_frame(c, ro, ri, gl())
		elif gl():
			_brass_ring(c, ro, ri)
		else:
			draw_arc(c, ri + 3.0, 0.0, TAU, 96, Color(HOLO.r, HOLO.g, HOLO.b, 0.25), 9.0, true)
			draw_arc(c, ri + 3.0, 0.0, TAU, 96, HOLO, 2.5, true)

	## The drawn brass bezel: a bevelled band (dark outer lip, light crest, brass face, dark inner lip), the light
	## on the upper left and shade on the lower right, four slotted screws, and the shadow it throws on the HUD.
	func _brass_ring(c: Vector2, ro: float, ri: float) -> void:
		var w: float = ro - ri
		var mid: float = (ro + ri) * 0.5
		draw_arc(c + Vector2(1.5, 3.0), mid, 0.0, TAU, 96, Color(0, 0, 0, 0.35), w + 2.0, true)   # the drop shadow
		draw_arc(c, ro - 1.0, 0.0, TAU, 96, BRASS_DARK.darkened(0.3), 2.5, true)                 # outer lip
		draw_arc(c, mid, 0.0, TAU, 96, BRASS, w - 3.0, true)                                      # the face
		draw_arc(c, ro - 3.5, 0.0, TAU, 96, BRASS_HI.lerp(BRASS, 0.45), 2.0, true)                # the crest of the bevel
		draw_arc(c, ri + 2.0, 0.0, TAU, 96, BRASS_DARK, 2.5, true)                               # inner lip
		draw_arc(c, ri + 0.5, 0.0, TAU, 96, Color(0, 0, 0, 0.55), 1.5, true)                     # the glass seat
		# light and shade round the ring (upper left lit, lower right in shadow)
		draw_arc(c, mid, PI * 1.02, PI * 1.62, 40, Color(BRASS_HI.r, BRASS_HI.g, BRASS_HI.b, 0.55), w - 5.0, true)
		draw_arc(c, mid, PI * 0.05, PI * 0.6, 40, Color(0.2, 0.13, 0.05, 0.4), w - 5.0, true)
		# a fine engraved line down the middle of the face
		draw_arc(c, mid + 1.0, 0.0, TAU, 96, Color(BRASS_DARK.r, BRASS_DARK.g, BRASS_DARK.b, 0.5), 1.0, true)
		# screws at the intercardinals of the frame (they do not turn)
		for k: int in 4:
			var a: float = PI * 0.25 + k * PI * 0.5
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * mid
			draw_circle(p + Vector2(0.5, 1.0), 3.6, Color(0, 0, 0, 0.45))
			draw_circle(p, 3.4, BRASS_DARK)
			draw_circle(p, 2.6, BRASS_HI.lerp(BRASS, 0.3))
			var slot: Vector2 = Vector2(cos(a + 0.6), sin(a + 0.6)) * 2.2
			draw_line(p - slot, p + slot, BRASS_DARK.darkened(0.3), 1.0, true)

	func _square_frame(c: Vector2, ro: float, ri: float, is_gl: bool) -> void:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(int((ri * 2.0) * 0.12) + 12)
		sb.border_color = BRASS if is_gl else HOLO
		sb.set_border_width_all(10 if is_gl else 3)
		if is_gl:
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_size = 3
			sb.shadow_offset = Vector2(1, 3)
		draw_style_box(sb, Rect2(c - Vector2(ro, ro) + Vector2(2, 2), Vector2(ro, ro) * 2.0 - Vector2(4, 4)))
		var sb2: StyleBoxFlat = StyleBoxFlat.new()
		sb2.bg_color = Color(0, 0, 0, 0)
		sb2.set_corner_radius_all(int((ri * 2.0) * 0.12) + 2)
		sb2.border_color = BRASS_DARK if is_gl else Color(HOLO.r, HOLO.g, HOLO.b, 0.3)
		sb2.set_border_width_all(2)
		draw_style_box(sb2, Rect2(c - Vector2(ri, ri) - Vector2(1, 1), Vector2(ri, ri) * 2.0 + Vector2(2, 2)))


## The bezel's tick ring, drawn north-up around its origin; Frame.turn rotates it by the heading. GRAVELIGHT adds the
## compass rose: brass points at the intercardinals on the ring and a faint eight-point rose etched in the glass.
class Ticks extends Node2D:
	var frame: Frame

	func _draw() -> void:
		var ri: float = frame.r_in()
		if frame.gl():
			var ro: float = frame.r_out()
			var mid: float = (ri + ro) * 0.5
			for i: int in 72:
				var a: float = TAU * i / 72.0
				var dir: Vector2 = Vector2(sin(a), -cos(a))
				var long: bool = i % 9 == 0
				draw_line(dir * (ri + 2.0), dir * (ri + (9.0 if long else 5.0)), BRASS_DARK, 2.0 if long else 1.0)
			# intercardinal rose points on the face of the ring
			for k: int in 4:
				var a2: float = PI * 0.25 + k * PI * 0.5
				var d: Vector2 = Vector2(sin(a2), -cos(a2))
				var side: Vector2 = Vector2(d.y, -d.x)
				var tip: Vector2 = d * (mid + 5.0)
				var base: Vector2 = d * (mid - 5.0)
				draw_colored_polygon(PackedVector2Array([tip, base + side * 2.5, base - side * 2.5]), BRASS_DARK)
				draw_colored_polygon(PackedVector2Array([tip, d * mid + side * 1.2, d * mid - side * 1.2]), BRASS_HI)
			# the etched rose in the glass, under the icons' size so the centre arrow stays clear
			var ra: float = float(MenuKit.cfg().get("minimap", {}).get("compass_rose_alpha", 0.16))
			var rose: Color = Color(0.2, 0.14, 0.06, ra)
			var r1: float = ri * 0.62
			var r2: float = ri * 0.34
			var rin: float = ri * 0.1
			for k2: int in 8:
				var a3: float = k2 * PI * 0.25
				var d3: Vector2 = Vector2(sin(a3), -cos(a3))
				var s3: Vector2 = Vector2(d3.y, -d3.x)
				var len: float = r1 if k2 % 2 == 0 else r2
				var half: float = rin * (1.0 if k2 % 2 == 0 else 0.7)
				draw_colored_polygon(PackedVector2Array([d3 * len, s3 * half, d3 * rin]), rose)
				draw_colored_polygon(PackedVector2Array([d3 * len, -s3 * half, d3 * rin]), Color(rose.r, rose.g, rose.b, ra * 0.55))
			draw_arc(Vector2.ZERO, r1 + 3.0, 0.0, TAU, 64, Color(rose.r, rose.g, rose.b, ra * 0.7), 1.0, true)
		else:
			for i2: int in 4:
				var a4: float = TAU * i2 / 4.0
				var d2: Vector2 = Vector2(sin(a4), -cos(a4))
				draw_line(d2 * (ri - 2.0), d2 * (ri + 9.0), HOLO_ORANGE, 3.0)


## One cardinal letter on its disc, upright; Frame.turn moves it round the ring.
class Letter extends Node2D:
	var frame: Frame
	var k: int = 0

	func _draw() -> void:
		var is_gl: bool = frame.gl()
		var f: Font = MenuKit.stamp_font() if is_gl else MapIcons.font()
		var letter: String = ["N", "E", "S", "W"][k]
		var fs: int = 15 if k == 0 else 12
		var w: float = f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col: Color = (INK if k == 0 else Color(0.15, 0.1, 0.05)) if is_gl else (HOLO_ORANGE if k == 0 else HOLO)
		if is_gl:
			draw_circle(Vector2(0.5, 1.0), 8.5, Color(0, 0, 0, 0.35))
			draw_circle(Vector2.ZERO, 8.0, BRASS_HI if k == 0 else BRASS)
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, BRASS_DARK, 1.0, true)
		else:
			draw_circle(Vector2.ZERO, 8.0, Color(0.03, 0.08, 0.14, 0.9))
		draw_string(f, Vector2(-w * 0.5, fs * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## The lubber mark, "ahead" at the top (drawn last, over the ring).
class Lubber extends Node2D:
	var frame: Frame

	func _draw() -> void:
		var top: Vector2 = Vector2(0, -frame.r_in() + 2.0)
		if frame.gl():
			draw_colored_polygon(PackedVector2Array([top + Vector2(0, 8), top + Vector2(-6, -3), top + Vector2(6, -3)]), Color(0, 0, 0, 0.5))
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, 7), top + Vector2(-5, -2), top + Vector2(5, -2)]), INK if frame.gl() else HOLO_ORANGE)
