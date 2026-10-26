class_name MapCanvas
extends Control
## Draws a level's map (Update 04 section 2, DECISIONS T-065): the baked floor image, the other floors ghosted
## under it, the fog of war, stairs / ladder / lift arrows, the POIs the squad knows about, objectives, marks, the
## live icons and the player's arrow. Used by the minimap (Minimap) and meant for the full pause map (section 3):
## the caller sets what to look at and the canvas draws it.
##
## View parameters (set them any time; the canvas follows on its next frame): floor_index, center (world XZ at the
## middle of the control), zoom (px per metre), heading (radians the map is turned by: the player's yaw makes
## "forward" point up, 0 = north up). Helpers: world_to_canvas / canvas_to_world, icon_at (hit test against what
## is on screen, for hover / clicks), fit_floor (the whole floor in view), refresh_now (re-read POIs / marks at once).
##
## Retained drawing, to stay well under the minimap's 0.3 ms budget: the floor images sit on one layer that is only
## moved and turned each frame (redrawn when the floor, zoom or fog changes), and every icon is its own small node
## that redraws only when what it shows changes; a frame just places them. POI, objective and mark lists refresh
## 5 times a second (and at once when marks change); live icons (teammates, zombies...) every frame.

const REFRESH_S: float = 0.25
const NO_OPTS: Dictionary = {}

var state: MapState = null
var floor_index: int = 0
var center: Vector2 = Vector2.ZERO
var zoom: float = 4.0
var heading: float = 0.0
var show_fog: bool = true
var show_ghosts: bool = true
var show_pois: bool = true
var show_live: bool = true
var show_markers: bool = true
var show_objectives: bool = true
var show_connectors: bool = true
var show_player: bool = true
var show_zone_labels: bool = false
## Teammates, marks and the boss outside the view are pinned to the rim (minimap).
var clamp_to_rim: bool = false
var rim_radius: float = 0.0   # 0 = half the smaller side
var icon_scale: float = 1.0
var cb_shapes: bool = false
## Fades the map (paper, floors, fog), not the icons on it.
var opacity: float = 1.0
## Colours (filled from the map's style in set_state; override freely).
var paper: Color = Color("#e9dfc6")
var ink: Color = Color("#2a2118")
var ghost_alpha: float = 0.22
var icon_colors: Dictionary = {}
## Microseconds the last frame cost: cost_usec = this canvas's update, draw_usec = the redraws of its layer and
## icons in the frame before (the minimap budget is < 300 us per frame for both).
var cost_usec: int = 0
var draw_usec: int = 0
## Rolling averages of the parts (us): the 5 Hz list rebuild (spread over frames), placing icons, live icons.
var prof: Dictionary = {"rebuild": 0.0, "place": 0.0, "live": 0.0}
static var _draw_acc: int = 0
## What is on screen: [{pos (canvas), r, kind, poi | live | marker | objective | connector, state?}] (kept only
## with record_hits: the pause map's hover / clicks; the minimap skips it).
var hits: Array[Dictionary] = []
var record_hits: bool = true

var _layer: MapLayer
var _static_root: Node2D              # POI / stairs / objective icons: moves and turns with the map layer
var _icon_root: Control               # marks and live icons: placed every frame
var _spool: Array[IconNode] = []
var _pool: Array[IconNode] = []
var _static: Array[Dictionary] = []   # POIs / connectors / objectives / marks: {kind, wpos, size, color, opts, ref_key, ref, rim?}
var _rim_static: Array[Dictionary] = []   # the "rim" ones of _static (marks: placed every frame)
var _static_zoom: float = -1.0
var _static_heading: float = INF
var _static_used: int = 0
var _refresh_t: float = 0.0
var _floor_seen: int = -1
var _hex_colors: Dictionary = {}      # "#rrggbb" -> Color (icon_color)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_layer = MapLayer.new()
	_layer.canvas = self
	add_child(_layer)
	_static_root = Node2D.new()
	add_child(_static_root)
	_icon_root = Control.new()
	_icon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_root)


## Points the canvas at a match's map state and takes the style's colours.
func set_state(ms: MapState) -> void:
	if state != null and is_instance_valid(state):
		if state.fog_changed.is_connected(_on_fog):
			state.fog_changed.disconnect(_on_fog)
		if state.markers_changed.is_connected(refresh_now):
			state.markers_changed.disconnect(refresh_now)
	state = ms
	if ms == null:
		return
	var styles: Dictionary = MapBake.config().get("styles", {})
	var sc: Dictionary = styles.get(ms.data.style, {})
	paper = Color(str(sc.get("paper", "#e9dfc6")))
	ink = Color(str(sc.get("ink", "#2a2118")))
	ghost_alpha = float(sc.get("ghost_alpha", 0.22))
	icon_colors = (ms.cfg.get("icons", {}) as Dictionary).get(ms.data.style, {})
	ms.fog_changed.connect(_on_fog)
	ms.markers_changed.connect(refresh_now)
	refresh_now()
	_layer.queue_redraw()
	queue_redraw()


func icon_color(kind: String) -> Color:
	var hex: Variant = icon_colors.get(kind, "#ffffff")
	if hex is Color:
		return hex
	var c: Variant = _hex_colors.get(hex)
	if c == null:   # parsed once per colour string (it ran per icon per frame: T-070)
		c = Color(str(hex))
		_hex_colors[hex] = c
	return c


func _on_fog(fi: int) -> void:
	if fi == floor_index or show_ghosts:
		_layer.queue_redraw()
	_refresh_t = minf(_refresh_t, 0.0)


## Re-reads POIs, connectors, objectives and marks on the next frame.
func refresh_now() -> void:
	_refresh_t = 0.0


# ================================================================== transforms

func world_to_canvas(p: Vector3) -> Vector2:
	return size * 0.5 + (Vector2(p.x, p.z) - center).rotated(heading) * zoom


func canvas_to_world(c: Vector2) -> Vector3:
	var d: Vector2 = ((c - size * 0.5) / zoom).rotated(-heading) + center
	var y: float = 0.0
	if state != null and floor_index < state.data.floors.size():
		y = float(state.data.floors[floor_index].get("base_y", 0.0))
	return Vector3(d.x, y, d.y)


## Centre and zoom so the whole floor image fits the control (north up).
func fit_floor(margin_px: float = 20.0) -> void:
	if state == null:
		return
	fit_rect(state.data.world_rect, margin_px)


## Centre and zoom so a world rect (XZ, metres) fits the control, north up (T-096: the pause map opens on the
## built zones, not the whole 104 x 118 m rect).
func fit_rect(r: Rect2, margin_px: float = 20.0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	center = r.get_center()
	heading = 0.0
	zoom = minf((size.x - margin_px * 2.0) / r.size.x, (size.y - margin_px * 2.0) / r.size.y)


## The icon nearest `c` within `radius` px ({} when none).
func icon_at(c: Vector2, radius: float = 14.0) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = radius
	for h: Dictionary in hits:
		var d: float = (h["pos"] as Vector2).distance_to(c) - float(h.get("r", 0.0)) * 0.5
		if d <= bd:
			bd = d
			best = h
	return best


# ================================================================== per frame

func _draw() -> void:
	var a: float = opacity
	draw_rect(Rect2(Vector2.ZERO, size), Color(paper.r * 0.93, paper.g * 0.93, paper.b * 0.93, a))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(delta: float) -> void:
	if state == null or not is_instance_valid(state) or not is_visible_in_tree():
		return
	var t0: int = Time.get_ticks_usec()
	draw_usec = _draw_acc
	_draw_acc = 0
	_layer.position = size * 0.5 + (-center * zoom).rotated(heading)
	_layer.rotation = heading
	if _layer.sync(floor_index, zoom, show_fog, show_ghosts, opacity, center * zoom, size.length() * 0.5 + 24.0):
		queue_redraw()
	_static_root.position = _layer.position
	_static_root.rotation = heading
	_refresh_t -= delta
	if _refresh_t <= 0.0 or _floor_seen != floor_index or not is_equal_approx(_static_zoom, zoom):
		_refresh_t = REFRESH_S
		_floor_seen = floor_index
		var tr: int = Time.get_ticks_usec()
		_rebuild_static()
		prof["rebuild"] = lerpf(float(prof["rebuild"]), float(Time.get_ticks_usec() - tr), 0.2)
	var tp: int = Time.get_ticks_usec()
	_place_icons()
	prof["place"] = lerpf(float(prof["place"]), float(Time.get_ticks_usec() - tp), 0.05)
	cost_usec = Time.get_ticks_usec() - t0


## POIs, stairs arrows, objectives and marks (world positions; placed every frame).
func _rebuild_static() -> void:
	_static.clear()
	var md: MapData = state.data
	var s: float = 16.0 * icon_scale
	if show_connectors:
		var cc: Color = icon_color("connector")
		cc.a = 0.85
		for c: Dictionary in md.connectors:
			if int(c["floor_a"]) == floor_index and (not show_fog or state.is_revealed(c["a"] as Vector3, floor_index)):
				_static.append({"kind": "chevron_up", "wpos": c["a"], "size": s * 0.8, "color": cc, "opts": {}, "ref_key": "connector", "ref": c})
			if int(c["floor_b"]) == floor_index and (not show_fog or state.is_revealed(c["b"] as Vector3, floor_index)):
				_static.append({"kind": "chevron_down", "wpos": c["b"], "size": s * 0.8, "color": cc, "opts": {}, "ref_key": "connector", "ref": c})
	if show_pois:
		for p: Dictionary in state.visible_pois(floor_index, show_fog):
			var st: Dictionary = state.poi_state(p)
			var kind: String = str(p["type"])
			var col: Color = icon_color("door_open" if kind == "door" and bool(st["open"]) else kind)
			var dim: bool = not bool(st["powered"]) or (kind == "trap" and not bool(st["ready"]))
			col.a = 0.5 if dim else 1.0
			_static.append({"kind": kind, "wpos": state.poi_world_pos(p), "size": s * (0.8 if kind == "door" else 1.0), "color": col,
				"opts": {"open": bool(st["open"]), "locked": bool(st["locked"]), "cb": cb_shapes}, "ref_key": "poi", "ref": p, "state": st})
	if show_objectives:
		var oc: Color = icon_color("objective")
		for o: Dictionary in state.objectives():
			var op: Vector3 = o["pos"]
			var of: int = md.floor_at(op + Vector3.UP * 0.2)
			var c2: Color = oc if of == floor_index else Color(oc.r, oc.g, oc.b, 0.45)
			_static.append({"kind": "objective", "wpos": op, "size": s * 0.95, "color": c2, "opts": {"up": of > floor_index, "down": of < floor_index},
				"ref_key": "objective", "ref": o})
	if show_markers:
		for m: Dictionary in state.markers():
			var mf: int = int(m.get("floor", floor_index))
			var mc: Color = m.get("color", icon_color("marker"))
			mc.a = 1.0 if mf == floor_index else 0.55
			_static.append({"kind": "marker", "wpos": m["pos"], "size": s * 1.1, "color": mc, "rim": true,
				"opts": {"mark": str(m.get("kind", "")), "up": mf > floor_index, "down": mf < floor_index}, "ref_key": "marker", "ref": m})
	# the fixed ones go on the static layer now (positions in world px); marks stay dynamic (pinned to the rim)
	_static_zoom = zoom
	_static_heading = INF
	_rim_static.clear()
	var used: int = 0
	for e: Dictionary in _static:
		if bool(e.get("rim", false)):
			_rim_static.append(e)
			continue
		while used >= _spool.size():
			var n: IconNode = IconNode.new()
			_static_root.add_child(n)
			_spool.append(n)
		var node: IconNode = _spool[used]
		used += 1
		node.visible = true
		node.show_icon(str(e["kind"]), float(e["size"]), e["color"] as Color, e["opts"] as Dictionary)
		var w: Vector3 = e["wpos"]
		node.position = Vector2(w.x, w.z) * zoom
	for i: int in range(used, _spool.size()):
		_spool[i].visible = false
	_static_used = used


func _place_icons() -> void:
	hits.clear()
	var used: int = 0
	var view: Rect2 = Rect2(Vector2.ZERO, size).grow(24.0 * icon_scale)
	if not is_equal_approx(_static_heading, heading):
		_static_heading = heading
		for i: int in _static_used:
			_spool[i].rotation = -heading   # icons stay upright while the map turns
	# without hit records (the minimap) only the rim-pinned marks need placing; the rest ride the static layer
	for e: Dictionary in (_static if record_hits else _rim_static):
		var rim: bool = bool(e.get("rim", false))
		var cp: Vector2 = world_to_canvas(e["wpos"] as Vector3)
		if rim:
			cp = _rim(cp, float(e["size"]))
			var node: IconNode = _icon(used)
			used += 1
			node.show_icon(str(e["kind"]), float(e["size"]), e["color"] as Color, e["opts"] as Dictionary)
			node.position = cp
			node.rotation = 0.0
		elif not view.has_point(cp):
			continue
		if not record_hits:
			continue
		var hk: String = str(e["kind"])
		var h: Dictionary = {"pos": cp, "r": float(e["size"]), "kind": "connector" if hk.begins_with("chevron_") else hk}
		h[str(e["ref_key"])] = e["ref"]
		if e.has("state"):
			h["state"] = e["state"]
		hits.append(h)
	if show_live:
		var s: float = 16.0 * icon_scale
		var md: MapData = state.data
		var blink_on: bool = fmod(Time.get_ticks_msec() / 1000.0 * float(state.cfg.get("blink_hz", 2.2)), 1.0) < 0.6
		var tl: int = Time.get_ticks_usec()
		var lives: Array[Dictionary] = state.live_icons()
		prof["live"] = lerpf(float(prof["live"]), float(Time.get_ticks_usec() - tl), 0.05)
		var zcol: Color = icon_color("zombie")
		zcol.a = 1.0
		var zsz: float = s * 0.55
		var half: Vector2 = size * 0.5
		for l: Dictionary in lives:
			var k: String = l["kind"]
			if k == "zombie":   # the common case, kept lean (T-070): same icon, size and colour every time, full alpha
				var zp: Vector3 = l["pos"]
				var zc: Vector2 = half + (Vector2(zp.x, zp.z) - center).rotated(heading) * zoom   # world_to_canvas
				if not view.has_point(zc):
					continue
				var zn: IconNode = _icon(used)
				used += 1
				if zn.kind != k or zn.icon_size != zsz or zn.color != zcol:
					zn.show_icon(k, zsz, zcol, NO_OPTS)
				zn.position = zc
				if zn.rotation != 0.0:
					zn.rotation = 0.0
				if record_hits:
					hits.append({"pos": zc, "r": zsz, "kind": k, "live": l})
				continue
			if bool(l.get("blink", false)) and not blink_on:
				continue
			var lp: Vector3 = l["pos"]
			var lf: int = md.floor_at(lp + Vector3.UP * 0.2)
			var cp2: Vector2 = world_to_canvas(lp)
			if k in ["ally", "bot", "jakub", "downed", "boss"]:
				cp2 = _rim(cp2, s)
			elif not view.has_point(cp2):
				continue
			var col2: Color = (l["color"] as Color) if l.has("color") and k in ["ally", "bot", "jakub"] else icon_color(k)
			col2.a = 1.0 if lf == floor_index else 0.5
			var sz: float = s * (1.25 if k == "boss" else 1.0)
			var node2: IconNode = _icon(used)
			used += 1
			node2.show_icon(k, sz, col2, {"initial": str(l.get("initial", "")), "bleed": snappedf(float(l.get("bleed", 1.0)), 0.02),
				"up": lf > floor_index, "down": lf < floor_index})
			node2.position = cp2
			node2.rotation = 0.0
			if record_hits:
				hits.append({"pos": cp2, "r": sz, "kind": k, "live": l})
	if show_player:
		var me: Node3D = state.local_body()
		if me != null and is_instance_valid(me):
			var pc: Color = icon_color("player")
			var node3: IconNode = _icon(used)
			used += 1
			node3.show_icon("player", 16.0 * icon_scale * 1.15, pc, {})
			node3.position = world_to_canvas(me.global_position)
			node3.rotation = heading - state.facing_yaw()   # the arrow points where the body faces
	for i: int in range(used, _pool.size()):
		_pool[i].visible = false


func _icon(i: int) -> IconNode:
	while i >= _pool.size():
		var n: IconNode = IconNode.new()
		_icon_root.add_child(n)
		_pool.append(n)
	var node: IconNode = _pool[i]
	node.visible = true
	return node


## Pins a point outside the rim back onto it (minimap edge indicators).
func _rim(p: Vector2, s: float) -> Vector2:
	if not clamp_to_rim:
		return p
	var c: Vector2 = size * 0.5
	var rr: float = (rim_radius if rim_radius > 0.0 else minf(size.x, size.y) * 0.5) - s * 0.7
	return c + (p - c).limit_length(rr)


## The floor images and the fog in world-pixel space (world XZ x zoom), moved / turned as one. A Node2D, not a
## Control: a Control is culled by its own (here empty) rect, so the layer vanished whenever its origin (world 0,0)
## left the screen. It draws only a window around the view, redrawn when the view has moved out of its middle.
class MapLayer extends Node2D:
	const SLACK: float = 96.0
	var canvas: MapCanvas
	var _floor: int = -1
	var _zoom: float = -1.0
	var _fog: bool = true
	var _ghosts: bool = true
	var _alpha: float = -1.0
	var _win: Rect2 = Rect2()

	## Takes the view settings (centre in layer px, view radius px); redraws when one changed. True when it did.
	func sync(fi: int, z: float, fog: bool, ghosts: bool, a: float, c: Vector2, view_r: float) -> bool:
		var inside: bool = _win.size.x >= (view_r + SLACK) * 2.0 - 1.0 and _win.grow(-SLACK * 0.75).has_point(c)
		if inside and fi == _floor and is_equal_approx(z, _zoom) and fog == _fog and ghosts == _ghosts and is_equal_approx(a, _alpha):
			return false
		_win = Rect2(c - Vector2.ONE * (view_r + SLACK), Vector2.ONE * (view_r + SLACK) * 2.0)
		_floor = fi
		_zoom = z
		_fog = fog
		_ghosts = ghosts
		_alpha = a
		queue_redraw()
		return true

	func _draw() -> void:
		if canvas == null or canvas.state == null or _zoom <= 0.0:
			return   # not synced yet (a draw queued by set_state before the first frame)
		var t0: int = Time.get_ticks_usec()
		_paint()
		MapCanvas._draw_acc += Time.get_ticks_usec() - t0

	func _paint() -> void:
		var md: MapData = canvas.state.data
		var r: Rect2 = Rect2(md.world_rect.position * _zoom, md.world_rect.size * _zoom)
		var a: float = _alpha
		var bg: Color = Color(canvas.paper.r * 0.93, canvas.paper.g * 0.93, canvas.paper.b * 0.93, a)
		if _ghosts:
			for i: int in md.floors.size():
				if i == _floor:
					continue
				_window(md.floor_texture(i), r, Color(1, 1, 1, canvas.ghost_alpha * a))
		_window(md.floor_texture(_floor), r, Color(1, 1, 1, a))
		if _fog and _floor < canvas.state.fog_textures.size():
			_window(canvas.state.fog_textures[_floor], r, bg)
		if canvas.show_zone_labels:
			_zone_labels(md, a)

	## The part of `tex` (spanning `r`) inside the current window.
	func _window(tex: Texture2D, r: Rect2, mod: Color) -> void:
		if tex == null:
			return
		var dst: Rect2 = r.intersection(_win)
		if dst.size.x <= 0.0 or dst.size.y <= 0.0:
			return
		var ts: Vector2 = tex.get_size()
		var src: Rect2 = Rect2((dst.position - r.position) / r.size * ts, dst.size / r.size * ts)
		draw_texture_rect_region(tex, dst, src, mod)

	## A zone label belongs to the floor its polygon's middle height is on (poly_on_floor counts any overlap, which
	## put the Old Cellar's name over the Taproom's on the ground floor).
	static func _label_on_floor(z: Dictionary, i: int, f: Dictionary) -> bool:
		var ys: Array = z.get("ys", [])
		var lo: float = float(ys[i][0]) if i < ys.size() else float(z["y_min"])
		var hi: float = float(ys[i][1]) if i < ys.size() else float(z["y_max"])
		var mid: float = (lo + hi) * 0.5
		return mid >= float(f["y_min"]) and mid < float(f["y_max"])

	func _zone_labels(md: MapData, a: float) -> void:
		var f: Font = MapIcons.font()
		var fl: Dictionary = md.floors[_floor] if _floor < md.floors.size() else {}
		for z: Dictionary in md.zones:
			var best: PackedVector2Array = PackedVector2Array()
			var ba: float = 0.0
			var polys: Array = z["polys"]
			for pi: int in polys.size():
				var poly: PackedVector2Array = polys[pi]
				if not fl.is_empty() and not _label_on_floor(z, pi, fl):
					continue
				var rr: Rect2 = Rect2(poly[0], Vector2.ZERO)
				for q: Vector2 in poly:
					rr = rr.expand(q)
				if rr.get_area() > ba:
					ba = rr.get_area()
					best = poly
			if best.is_empty():
				continue
			var cen: Vector2 = Vector2.ZERO
			for q2: Vector2 in best:
				cen += q2
			cen = cen / best.size() * _zoom
			var txt: String = str(z.get("name", z["id"])).to_upper()
			var fs: int = int(13 * canvas.icon_scale)
			var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_set_transform(cen, -rotation, Vector2.ONE)
			draw_string_outline(f, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(canvas.paper.r, canvas.paper.g, canvas.paper.b, 0.8 * a))
			draw_string(f, Vector2(-w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(canvas.ink.r, canvas.ink.g, canvas.ink.b, 0.85 * a))
		draw_set_transform_matrix(Transform2D.IDENTITY)


## One icon (a Node2D: no Control rect culling); redraws only when what it shows changes (the downed pulse redraws
## every frame).
class IconNode extends Node2D:
	var kind: String = ""
	var icon_size: float = 16.0
	var color: Color = Color.WHITE
	var opts: Dictionary = {}

	func show_icon(k: String, s: float, c: Color, o: Dictionary) -> void:
		var animated: bool = k == "downed"
		if animated or k != kind or not is_equal_approx(s, icon_size) or c != color or o != opts:
			kind = k
			icon_size = s
			color = c
			opts = o
			queue_redraw()

	func _draw() -> void:
		var t0: int = Time.get_ticks_usec()
		_paint()
		MapCanvas._draw_acc += Time.get_ticks_usec() - t0

	func _paint() -> void:
		var o: Dictionary = opts
		if kind == "downed":
			o = opts.duplicate()
			o["t"] = Time.get_ticks_msec() / 1000.0
		match kind:
			"player":
				MapIcons.draw_player(self, Vector2.ZERO, Vector2.UP, icon_size, color)
			"chevron_up":
				MapIcons.chevron(self, Vector2.ZERO, icon_size, true, color)
			"chevron_down":
				MapIcons.chevron(self, Vector2.ZERO, icon_size, false, color)
			_:
				MapIcons.draw(self, kind, Vector2.ZERO, icon_size, color, o)
