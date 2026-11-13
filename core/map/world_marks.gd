class_name WorldMarks
extends Node3D
## The map marks in the world (Update 04 section 3, DECISIONS T-069), for the local player: GRAVELIGHT draws a chalk
## "X" on the floor (a Decal, so it lies on whatever is there: boards, flagstones, the stairs), B&S a holo pin
## (an emissive stem and ring). Above each, a small label: the mark's letter, its name and the distance, fading
## with distance and hidden beyond world.hide_m, standing on it, or when more than world.labels_max nearer marks
## have one already, so they read at a glance and never clutter (tuning: data/maps/marks.json "world").
## Rebuilt when the marks change (MapState.markers_changed); per frame only the labels' text and alpha.

var marks: MapMarks = null
var _items: Dictionary = {}       # mark id -> {root: Node3D, label: Label3D, mark: Dictionary}
var _wc: Dictionary = {}
var _gl: bool = true
static var _x_tex: Texture2D = null
## PersonRig.CHAR_LAYER (render layer 18, the people's bodies): the chalk X leaves it out.
const CHAR_LAYER: int = 1 << 17


func setup(m: MapMarks) -> void:
	marks = m
	_wc = MapMarks.cfg().get("world", {})
	_gl = m.state == null or m.state.game == "gravelight"


func _ready() -> void:
	if marks != null and marks.state != null:
		marks.state.markers_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if marks == null or marks.state == null:
		return
	var seen: Dictionary = {}
	for m: Dictionary in marks.marks():
		var id: int = int(m["id"])
		seen[id] = true
		var it: Dictionary = _items.get(id, {})
		if it.is_empty():
			it = _make(m)
			_items[id] = it
		it["mark"] = m
		(it["root"] as Node3D).global_position = m["pos"] as Vector3
		_tint(it, m)
	for k: Variant in _items.keys():
		if not seen.has(k):
			((_items[k] as Dictionary)["root"] as Node).queue_free()
			_items.erase(k)


func item_count() -> int:
	return _items.size()


func _make(m: Dictionary) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "Mark%d" % int(m["id"])
	add_child(root)
	var it: Dictionary = {"root": root}
	if _gl:
		var d: Decal = Decal.new()
		var s: float = float(_wc.get("x_size_m", 1.15))
		# 2026-11-12 (the owner's screenshots: white smears down the extra people, who stand on their own note marks): the
		# projector was 2.4 m tall, so it painted the chalk down everyone standing on the mark, stretched on their sides.
		# It reaches 0.8 m above and below the mark now (a stair's few treads), skips faces that are not floor-like
		# (normal_fade), and skips the people's bodies (PersonRig.CHAR_LAYER).
		d.size = Vector3(s, 1.6, s)
		d.position = Vector3(0, 0.0, 0)
		d.normal_fade = 0.6
		d.cull_mask = 0xFFFFF & ~CHAR_LAYER
		d.texture_albedo = chalk_x_texture()
		d.texture_emission = chalk_x_texture()   # chalk catches what little light there is: it reads in a dark cellar
		d.emission_energy = float(_wc.get("chalk_glow", 0.35))
		d.albedo_mix = 1.0
		d.upper_fade = 0.2
		d.lower_fade = 0.4
		d.distance_fade_enabled = true
		d.distance_fade_begin = float(_wc.get("decal_fade_begin_m", 30.0))
		d.distance_fade_length = float(_wc.get("decal_fade_length_m", 25.0))
		root.add_child(d)
		it["decal"] = d
	else:
		var stem: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.035
		cm.height = 1.4
		stem.mesh = cm
		stem.position = Vector3(0, 0.7, 0)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(stem)
		var ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.42
		tm.outer_radius = 0.5
		ring.mesh = tm
		ring.position = Vector3(0, 0.05, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)
		var head: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		head.mesh = sm
		head.position = Vector3(0, 1.45, 0)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(head)
		it["holo"] = [stem, ring, head]
	var l: Label3D = Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 30
	l.outline_size = 9
	l.no_depth_test = true
	l.double_sided = true
	l.position = Vector3(0, float(_wc.get("label_height_m", 1.7)), 0)
	l.render_priority = 4
	root.add_child(l)
	it["label"] = l
	return it


func _tint(it: Dictionary, m: Dictionary) -> void:
	var col: Color = m.get("color", MapMarks.kind_color(str(m.get("kind", ""))))
	if it.has("decal"):
		# chalk: the mark's colour washed toward white, as if rubbed onto the floor
		(it["decal"] as Decal).modulate = col.lerp(Color(0.97, 0.95, 0.9), 0.45)
	if it.has("holo"):
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 2.0
		for mi: Variant in it["holo"]:
			(mi as MeshInstance3D).material_override = mat
	var l: Label3D = it["label"]
	l.modulate = col.lerp(Color.WHITE, 0.55) if _gl else col.lerp(Color.WHITE, 0.3)
	l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9) if _gl else Color(0.0, 0.08, 0.12, 0.9)


func _process(_delta: float) -> void:
	if marks == null or marks.state == null or _items.is_empty():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye: Vector3 = cam.global_position
	var rows: Array = []
	for k: Variant in _items.keys():
		var it: Dictionary = _items[k]
		var p: Vector3 = (it["root"] as Node3D).global_position
		rows.append([eye.distance_to(p), it])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var shown: int = 0
	var placed: Array[Vector2] = []
	var gap: Vector2 = Vector2(float(_wc.get("label_gap_px", 170.0)), float(_wc.get("label_gap_y_px", 26.0)))
	var fb: float = float(_wc.get("fade_begin_m", 12.0))
	var hide_m: float = float(_wc.get("hide_m", 70.0))
	var low: float = float(_wc.get("fade_end_alpha", 0.35))
	for r: Array in rows:
		var d: float = float(r[0])
		var it2: Dictionary = r[1]
		var l: Label3D = it2["label"]
		var m: Dictionary = it2["mark"]
		var vis: bool = d < hide_m and d > float(_wc.get("near_hide_m", 2.2)) and shown < int(_wc.get("labels_max", 4))
		if vis:
			# never cluttered: a label that would sit on a nearer one's is left out
			var lp: Vector3 = l.global_position
			if cam.is_position_behind(lp):
				vis = false
			else:
				var sp: Vector2 = cam.unproject_position(lp)
				for q: Vector2 in placed:
					if absf(q.x - sp.x) < gap.x and absf(q.y - sp.y) < gap.y:
						vis = false
						break
				if vis:
					placed.append(sp)
		l.visible = vis
		(it2["root"] as Node3D).visible = d < hide_m * 1.2
		if not vis:
			continue
		shown += 1
		var a: float = 1.0 if d <= fb else lerpf(1.0, low, clampf((d - fb) / maxf(1.0, hide_m - fb), 0.0, 1.0))
		l.modulate.a = a
		l.outline_modulate.a = a * 0.9
		l.text = label_text(m, d)


## The label over a mark: its letter, name and the distance ("$ Ironhide · Dutch · 14 m").
static func label_text(m: Dictionary, dist: float) -> String:
	var letter: String = str(MapIcons.MARK_LETTERS.get(str(m.get("kind", "")), "•"))
	var nm: String = str(m.get("label", ""))
	if nm.length() > 24:
		nm = nm.substr(0, 22) + ".."
	var who: String = ""
	var pid: int = int(m.get("pid", -1))
	if bool(m.get("order", false)) and pid > 0:
		who = " · Jakub" if pid == 9 else " · " + Net.display_name(pid)
	return "%s  %s%s · %d m" % [letter, nm, who, roundi(dist)]


## A chalk "X": two rough strokes with dusty edges and gaps, white on transparent (made once).
static func chalk_x_texture() -> Texture2D:
	if _x_tex != null:
		return _x_tex
	var n: int = 128
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))   # black where empty: the emission texture reads RGB only
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7341
	var strokes: Array = [[Vector2(0.14, 0.17), Vector2(0.86, 0.83)], [Vector2(0.84, 0.15), Vector2(0.17, 0.86)]]
	for s: Array in strokes:
		var a: Vector2 = (s[0] as Vector2) * n
		var b: Vector2 = (s[1] as Vector2) * n
		var steps: int = 220
		for i: int in steps:
			var t: float = float(i) / float(steps - 1)
			var c: Vector2 = a.lerp(b, t) + Vector2(sin(t * 9.0) * 1.6, cos(t * 7.0) * 1.2)
			var w: float = lerpf(7.5, 5.0, t) + rng.randf_range(-1.0, 1.0)
			for k: int in 18:
				var q: Vector2 = c + Vector2(rng.randf_range(-w, w), rng.randf_range(-w, w))
				var x: int = int(q.x)
				var y: int = int(q.y)
				if x < 0 or y < 0 or x >= n or y >= n:
					continue
				var edge: float = 1.0 - clampf(c.distance_to(q) / w, 0.0, 1.0)
				var al: float = clampf(edge * 2.2, 0.0, 1.0) * rng.randf_range(0.7, 1.0)
				var cur: Color = img.get_pixel(x, y)
				if al > cur.a:
					img.set_pixel(x, y, Color(1, 1, 1, al))
	_x_tex = ImageTexture.create_from_image(img)
	return _x_tex
