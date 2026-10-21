class_name RustvaneDressing
extends RefCounted
## Procedural greybox dressing for Rustvane Canyon, built from the level data's "props" rows (one row per
## prop or scatter; "kind" picks the builder). Solid props are world-layer StaticBody3D colliders built
## before the navmesh bake; the rest is decoration. Every placement and count is data; the shapes here are the
## web build's resort kit (cabana, parasol, adBoard, poolScene floaties, rock spires, bunk containers, laundry,
## stringLights, tents and the Co-op cart), re-made from boxes, cylinders and tori.

const KINDS: PackedStringArray = ["strata", "spires", "cabana", "parasol", "deck_chairs", "tent", "bunk", "laundry",
	"string_lights", "ad_board", "floaties", "stilts", "waterfall", "shrubs", "lava", "ore_cart", "rails_deco",
	"winch", "vending", "time_clock", "kennel", "rating_sign", "mast_deco", "gravel", "valet_loop", "crate_stack"]


static func build_props(parent: Node3D, rows: Array) -> int:
	var n: int = 0
	for r: Variant in rows:
		if not (r is Dictionary) or not (r as Dictionary).has("kind"):
			continue
		var d: Dictionary = r
		var k: String = str(d["kind"])
		if not (k in KINDS):
			push_warning("RustvaneDressing: unknown prop kind %s" % k)
			continue
		var root: Node3D = Node3D.new()
		root.name = "%s_%d" % [k.to_pascal_case(), n]
		parent.add_child(root)
		call_kind(root, k, d)
		n += 1
	return n


static func call_kind(root: Node3D, k: String, d: Dictionary) -> void:
	match k:
		"strata": strata(root, d)
		"spires": spires(root, d)
		"cabana": cabana(root, LevelKit.v3(d.get("p")), float(d.get("ry", 0.0)), bool(d.get("solid", true)))
		"parasol": parasol(root, LevelKit.v3(d.get("p")), d.get("color", "#ff6ac2"))
		"deck_chairs": deck_chairs(root, d)
		"tent": tent(root, LevelKit.v3(d.get("p")), float(d.get("r", 2.0)), float(d.get("h", 2.2)), d.get("color", "#c9b8a0"))
		"bunk": bunk(root, LevelKit.v3(d.get("p")), d.get("color", "#f2ebe0"), float(d.get("ry", 0.0)))
		"laundry": laundry(root, LevelKit.v3(d.get("p")), float(d.get("len", 12.0)))
		"string_lights": string_lights(root, LevelKit.v3(d.get("from")), LevelKit.v3(d.get("to")), int(d.get("n", 10)))
		"ad_board": ad_board(root, d)
		"floaties": floaties(root, d)
		"stilts": stilts(root, d)
		"waterfall": waterfall(root, d)
		"shrubs": shrubs(root, d)
		"lava": lava(root, d)
		"ore_cart": ore_cart(root, LevelKit.v3(d.get("p")), float(d.get("ry", 0.0)))
		"rails_deco": rails_deco(root, d)
		"winch": winch(root, LevelKit.v3(d.get("p")))
		"vending": vending(root, LevelKit.v3(d.get("p")), float(d.get("ry", 0.0)))
		"time_clock": time_clock(root, LevelKit.v3(d.get("p")))
		"kennel": kennel(root, LevelKit.v3(d.get("p")))
		"rating_sign": rating_sign(root, d)
		"mast_deco": mast_deco(root, LevelKit.v3(d.get("p")), float(d.get("h", 12.0)))
		"gravel": gravel(root, d)
		"valet_loop": valet_loop(root, d)
		"crate_stack": crate_stack(root, LevelKit.v3(d.get("p")), int(d.get("n", 3)))


static func _rng(d: Dictionary) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = int(d.get("seed", 7))
	return r


# ------------------------------------------------------------------ canyon

## A banded canyon wall along x (or z): a solid core plus stepped strata bands that read as layered rock.
## Row: from [x,z], to [x,z] (axis-aligned), base, h, t (thickness), face (+1/-1: which side faces the canyon).
static func strata(root: Node3D, d: Dictionary) -> void:
	var a: Vector2 = LevelKit.v2(d.get("from"))
	var b: Vector2 = LevelKit.v2(d.get("to"))
	var base: float = float(d.get("base", 0.0))
	var h: float = float(d.get("h", 30.0))
	var t: float = float(d.get("t", 6.0))
	var face: float = float(d.get("face", 1.0))
	var along_x: bool = absf(b.x - a.x) > absf(b.y - a.y)
	var length: float = absf(b.x - a.x) if along_x else absf(b.y - a.y)
	var mid: Vector2 = (a + b) * 0.5
	var bands: Array = d.get("bands", ["#8a4530", "#74301f", "#9e4a32", "#6e3524", "#b0603a"])
	var core: Vector3 = Vector3(length, h, t) if along_x else Vector3(t, h, length)
	LevelKit.box(root, Vector3(mid.x, base + h * 0.5, mid.y), core, bands[0], true)
	var rng: RandomNumberGenerator = _rng(d)
	var y: float = base
	var i: int = 0
	while y < base + h - 0.5:
		var bh: float = rng.randf_range(1.6, 3.6)
		bh = minf(bh, base + h - y)
		var out: float = rng.randf_range(0.15, 0.9) * face
		var sz: Vector3 = Vector3(length, bh, absf(out) + 0.1) if along_x else Vector3(absf(out) + 0.1, bh, length)
		LevelKit.box(root, Vector3(mid.x, y + bh * 0.5, mid.y) + _face_offset(along_x, t, face, out), sz, bands[i % bands.size()], false)
		y += bh
		i += 1
	# a few fallen boulders at the foot
	for k: int in int(d.get("boulders", 4)):
		var u: float = rng.randf_range(-length * 0.45, length * 0.45)
		var r: float = rng.randf_range(0.7, 1.6)
		var foot: Vector3 = Vector3(mid.x + u, base + r * 0.5, mid.y) if along_x else Vector3(mid.x, base + r * 0.5, mid.y + u)
		foot += _face_offset(along_x, t, face, r + 0.6)
		LevelKit.cylinder(root, foot, r, r, bands[(k + 2) % bands.size()], false, "y", r * 0.6)


static func _face_offset(along_x: bool, t: float, face: float, out: float) -> Vector3:
	var o: float = (t * 0.5 + out * 0.5) * face
	return Vector3(0, 0, o) if along_x else Vector3(o, 0, 0)


## Rock spires and stacked hoodoos (the source's scattered cones).
static func spires(root: Node3D, d: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng(d)
	var c: Vector3 = LevelKit.v3(d.get("center"))
	var r: Vector2 = LevelKit.v2(d.get("r"), Vector2(20, 20))
	var cols: Array = d.get("colors", ["#8a3a2a", "#9e4a32", "#74301f"])
	for i: int in int(d.get("n", 10)):
		var p: Vector3 = c + Vector3(rng.randf_range(-r.x, r.x), 0, rng.randf_range(-r.y, r.y))
		var w: float = rng.randf_range(0.8, 2.2)
		var h: float = rng.randf_range(2.5, float(d.get("h_max", 7.0)))
		LevelKit.cylinder(root, p + Vector3(0, h * 0.5, 0), w, h, cols[i % cols.size()], bool(d.get("solid", false)), "y", w * 0.25)
		if rng.randf() < 0.4:
			LevelKit.cylinder(root, p + Vector3(0, h + 0.3, 0), w * 0.55, 0.6, "#c8955a", false, "y", w * 0.45)


static func shrubs(root: Node3D, d: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng(d)
	var c: Vector3 = LevelKit.v3(d.get("center"))
	var r: Vector2 = LevelKit.v2(d.get("r"), Vector2(8, 8))
	for i: int in int(d.get("n", 10)):
		var p: Vector3 = c + Vector3(rng.randf_range(-r.x, r.x), 0, rng.randf_range(-r.y, r.y))
		var s: float = rng.randf_range(0.4, 0.9)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = s
		sm.height = s * rng.randf_range(1.0, 1.6)
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = LevelKit.mat(["#3f9a4a", "#2f7a3a", "#5aa84a"][i % 3])
		mi.position = p + Vector3(0, s * 0.6, 0)
		root.add_child(mi)


static func gravel(root: Node3D, d: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng(d)
	var c: Vector3 = LevelKit.v3(d.get("center"))
	var r: Vector2 = LevelKit.v2(d.get("r"), Vector2(8, 8))
	for i: int in int(d.get("n", 12)):
		var p: Vector3 = c + Vector3(rng.randf_range(-r.x, r.x), 0, rng.randf_range(-r.y, r.y))
		var w: float = rng.randf_range(0.5, 1.6)
		LevelKit.cylinder(root, p + Vector3(0, w * 0.3, 0), w, w * 0.6, ["#9e4a32", "#c8955a", "#7a5a2a"][i % 3], false, "y", w * 0.3)


static func lava(root: Node3D, d: Dictionary) -> void:
	var p: Vector3 = LevelKit.v3(d.get("p"))
	var s: Vector3 = LevelKit.v3(d.get("s"), Vector3(40, 0.2, 20))
	LevelKit.box(root, p, s, "#ff6a1e", false, Vector3.ZERO, 1, 1.6)
	var rng: RandomNumberGenerator = _rng(d)
	for i: int in int(d.get("crust", 10)):
		var q: Vector3 = p + Vector3(rng.randf_range(-s.x * 0.45, s.x * 0.45), s.y * 0.5 + 0.03, rng.randf_range(-s.z * 0.45, s.z * 0.45))
		LevelKit.box(root, q, Vector3(rng.randf_range(1.0, 3.5), 0.06, rng.randf_range(1.0, 3.0)), "#5a1e10", false, Vector3(0, rng.randf_range(0, 90), 0))
	if d.has("falls"):
		# glowing falls pouring off the stage's infinity edge into the lava
		for f: Variant in d["falls"]:
			var fp: Vector3 = LevelKit.v3(f)
			LevelKit.box(root, fp, Vector3(float(d.get("fall_w", 6.0)), float(d.get("fall_h", 12.0)), 0.4), "#ffb02e", false, Vector3.ZERO, 1, 1.8)


static func waterfall(root: Node3D, d: Dictionary) -> void:
	var p: Vector3 = LevelKit.v3(d.get("p"))
	var w: float = float(d.get("w", 7.4))
	var h: float = float(d.get("h", 8.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.25, h, w)
	mi.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.44, 0.89, 0.94, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color("#6fe4ef")
	m.emission_energy_multiplier = 0.4
	m.roughness = 0.1
	mi.material_override = m
	mi.position = p
	mi.rotation_degrees.y = float(d.get("ry", 0.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# foam at the foot
	LevelKit.box(root, p + Vector3(0, -h * 0.5 + 0.1, 0), Vector3(1.8, 0.2, w + 0.6), "#e8fbff", false, Vector3(0, float(d.get("ry", 0.0)), 0), 1, 0.6)


# ------------------------------------------------------------------ resort kit

## cabana(): four posts, a striped canvas roof (walkable, 2.5 m) and curtains on three sides.
static func cabana(root: Node3D, p: Vector3, ry: float, solid: bool = true) -> void:
	var c: Node3D = Node3D.new()
	c.position = p
	c.rotation_degrees.y = ry
	root.add_child(c)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			LevelKit.box(c, Vector3(sx * 1.4, 1.2, sz * 1.4), Vector3(0.16, 2.4, 0.16), "#f2ebe0", false)
	LevelKit.box(c, Vector3(0, 2.4, 0), Vector3(3.4, 0.3, 3.4), "#ff8ac2", solid)
	for i: int in 5:
		LevelKit.box(c, Vector3(-1.36 + i * 0.68, 2.57, 0), Vector3(0.34, 0.05, 3.42), "#f2ebe0", false)
	LevelKit.box(c, Vector3(0, 1.3, -1.42), Vector3(2.8, 2.1, 0.06), "#f2ebe0", false)
	LevelKit.box(c, Vector3(-1.42, 1.3, -0.4), Vector3(0.06, 2.1, 1.8), "#ffb3d6", false)
	LevelKit.box(c, Vector3(1.42, 1.3, -0.4), Vector3(0.06, 2.1, 1.8), "#ffb3d6", false)
	LevelKit.box(c, Vector3(0, 0.3, -0.2), Vector3(1.0, 0.25, 2.0), "#6fd4ff", solid)
	LevelKit.box(c, Vector3(0, 0.55, -1.0), Vector3(1.0, 0.5, 0.2), "#6fd4ff", false, Vector3(-25, 0, 0))


static func parasol(root: Node3D, p: Vector3, color: Variant) -> void:
	LevelKit.cylinder(root, p + Vector3(0, 1.2, 0), 0.06, 2.4, "#d8dee9")
	LevelKit.cylinder(root, p + Vector3(0, 2.5, 0), 1.6, 0.55, color, false, "y", 0.1)
	LevelKit.cylinder(root, p + Vector3(0, 0.05, 0), 0.35, 0.1, "#39404f")


static func deck_chairs(root: Node3D, d: Dictionary) -> void:
	var p: Vector3 = LevelKit.v3(d.get("p"))
	var n: int = int(d.get("n", 4))
	var step: Vector3 = LevelKit.v3(d.get("step"), Vector3(1.3, 0, 0))
	var ry: float = float(d.get("ry", 0.0))
	var cols: Array = d.get("colors", ["#f2ebe0", "#6fd4ff", "#ff8ac2"])
	for i: int in n:
		var c: Node3D = Node3D.new()
		c.position = p + step * float(i)
		c.rotation_degrees.y = ry
		root.add_child(c)
		LevelKit.box(c, Vector3(0, 0.22, 0), Vector3(0.62, 0.18, 1.5), cols[i % cols.size()], bool(d.get("solid", true)))
		LevelKit.box(c, Vector3(0, 0.55, -0.62), Vector3(0.62, 0.6, 0.12), cols[i % cols.size()], false, Vector3(-30, 0, 0))
		for sx: float in [-0.25, 0.25]:
			LevelKit.box(c, Vector3(sx, 0.07, 0.5), Vector3(0.05, 0.14, 0.05), "#8a95a8", false)


static func floaties(root: Node3D, d: Dictionary) -> void:
	var rng: RandomNumberGenerator = _rng(d)
	var c: Vector3 = LevelKit.v3(d.get("center"))
	var r: float = float(d.get("r", 2.5))
	for i: int in int(d.get("n", 3)):
		var mi: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.22
		tm.outer_radius = 0.5
		tm.rings = 16
		tm.ring_segments = 8
		mi.mesh = tm
		mi.material_override = LevelKit.mat(["#ff6ac2", "#6fd4ff", "#ffd23e"][i % 3])
		var a: float = rng.randf_range(0, TAU)
		mi.position = c + Vector3(cos(a) * rng.randf_range(0.5, r), 0.05, sin(a) * rng.randf_range(0.5, r))
		root.add_child(mi)


## Deck stilts: support columns under a deck rectangle (centre [x,z], size [w,d], top y).
static func stilts(root: Node3D, d: Dictionary) -> void:
	var c: Vector2 = LevelKit.v2(d.get("center"))
	var s: Vector2 = LevelKit.v2(d.get("size"))
	var top: float = float(d.get("top", 6.0))
	var base: float = float(d.get("base", 0.0))
	var sp: float = float(d.get("spacing", 6.0))
	var nx: int = maxi(1, int(s.x / sp))
	var nz: int = maxi(1, int(s.y / sp))
	for i: int in nx + 1:
		for k: int in nz + 1:
			var x: float = c.x - s.x * 0.5 + 0.6 + (s.x - 1.2) * float(i) / float(nx)
			var z: float = c.y - s.y * 0.5 + 0.6 + (s.y - 1.2) * float(k) / float(nz)
			LevelKit.box(root, Vector3(x, (base + top) * 0.5, z), Vector3(0.7, top - base, 0.7), "#d8cfc0", bool(d.get("solid", true)))
	# cross bracing on the long sides
	LevelKit.box(root, Vector3(c.x, base + (top - base) * 0.45, c.y - s.y * 0.5 + 0.6), Vector3(s.x - 1.2, 0.2, 0.2), "#b8ad9c", false)
	LevelKit.box(root, Vector3(c.x, base + (top - base) * 0.45, c.y + s.y * 0.5 - 0.6), Vector3(s.x - 1.2, 0.2, 0.2), "#b8ad9c", false)


## adBoard(): a bright billboard panel with a slogan (data/bs/story/ads.json "billboards"[n], or a line id).
static func ad_board(root: Node3D, d: Dictionary) -> void:
	var p: Vector3 = LevelKit.v3(d.get("p"))
	var size: Vector2 = LevelKit.v2(d.get("size"), Vector2(5, 2.5))
	var ry: float = float(d.get("ry", 0.0))
	var text: String = ""
	if d.has("text"):
		text = LevelKit.text(str(d["text"]))
	else:
		var ads: Variant = Data.table("bs/story/ads")
		var list: Array = (ads as Dictionary).get("billboards", []) if ads is Dictionary else []
		text = str(list[int(d.get("n", 0)) % list.size()]) if not list.is_empty() else ""
	var bg: Array = ["#ff6ac2", "#6fd4ff", "#ffd23e", "#c06aff", "#f2ebe0"]
	var col: String = str(d.get("bg", bg[int(d.get("n", 0)) % bg.size()]))
	var board: Node3D = Node3D.new()
	board.position = p
	board.rotation_degrees.y = ry
	root.add_child(board)
	LevelKit.box(board, Vector3(0, 0, -0.08), Vector3(size.x + 0.3, size.y + 0.3, 0.12), "#2c3242", false)
	LevelKit.box(board, Vector3.ZERO, Vector3(size.x, size.y, 0.06), col, false, Vector3.ZERO, 1, 0.55)
	var lbl: Label3D = Label3D.new()
	lbl.text = text
	lbl.modulate = Color("#1a1020") if col in ["#ffd23e", "#f2ebe0", "#6fd4ff"] else Color("#fff8f0")
	lbl.pixel_size = 0.006
	lbl.font_size = int(clampf(size.y * 52.0, 28.0, 220.0))
	lbl.width = size.x / lbl.pixel_size * 0.92
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.double_sided = true
	lbl.outline_size = 0
	lbl.position = Vector3(0, 0, 0.05)
	board.add_child(lbl)
	if bool(d.get("posts", true)):
		var ph: float = float(d.get("post_h", 0.0))
		if ph > 0.0:
			for sx: float in [-0.35, 0.35]:
				LevelKit.box(board, Vector3(sx * size.x, -size.y * 0.5 - ph * 0.5, -0.1), Vector3(0.2, ph, 0.2), "#8a95a8", false)
	board.set_meta(&"text", text)


static func rating_sign(root: Node3D, d: Dictionary) -> void:
	ad_board(root, d)
	var p: Vector3 = LevelKit.v3(d.get("p"))
	var size: Vector2 = LevelKit.v2(d.get("size"), Vector2(8, 3))
	# five star lamps under the board: two lit
	for i: int in 5:
		var lit: bool = i < 2
		LevelKit.cylinder(root, p + Vector3(-size.x * 0.32 + i * size.x * 0.16, -size.y * 0.5 - 0.5, 0.1), 0.3, 0.1,
			"#ffd23e" if lit else "#4a4038", false, "z", -1.0, 1.4 if lit else 0.0)


# ------------------------------------------------------------------ the staff and the Co-op

static func tent(root: Node3D, p: Vector3, r: float, h: float, color: Variant) -> void:
	LevelKit.cylinder(root, p + Vector3(0, h * 0.5, 0), r, h, color, true, "y", 0.05)
	LevelKit.box(root, p + Vector3(0, h * 0.3, r * 0.75), Vector3(r * 0.6, h * 0.55, 0.06), "#5a2a1e", false)


static func bunk(root: Node3D, p: Vector3, color: Variant, ry: float) -> void:
	var c: Node3D = Node3D.new()
	c.position = p
	c.rotation_degrees.y = ry
	root.add_child(c)
	LevelKit.box(c, Vector3(0, 1.3, 0), Vector3(6, 2.6, 2.6), color, true)
	LevelKit.box(c, Vector3(-1.6, 1.05, 1.33), Vector3(0.9, 1.9, 0.06), "#232838", false)
	LevelKit.box(c, Vector3(1.4, 1.6, 1.34), Vector3(1.1, 0.6, 0.05), "#ffd27a", false, Vector3.ZERO, 1, 1.3)
	for i: int in 5:
		LevelKit.box(c, Vector3(-2.4 + i * 1.2, 1.3, 1.32), Vector3(0.08, 2.5, 0.04), "#c8bfb0", false)


static func laundry(root: Node3D, p: Vector3, length: float) -> void:
	for px: float in [0.0, length]:
		LevelKit.box(root, p + Vector3(px, 1.5, 0), Vector3(0.16, 3.0, 0.16), "#8a95a8", false)
	LevelKit.box(root, p + Vector3(length * 0.5, 2.9, 0), Vector3(length, 0.05, 0.05), "#d8dee9", false)
	var cols: Array = ["#ff8ac2", "#f2ebe0", "#9fd4e0"]
	var n: int = int(length / 1.85)
	for k: int in n:
		LevelKit.box(root, p + Vector3(1.4 + k * 1.85, 2.2, 0), Vector3(1.1, 1.3, 0.06), cols[k % 3], false)


static func string_lights(root: Node3D, a: Vector3, b: Vector3, n: int) -> void:
	for i: int in n:
		var t: float = float(i) / float(maxi(1, n - 1))
		var q: Vector3 = a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.6, 0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.24
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		mi.material_override = LevelKit.mat(["#ffe08a", "#ff8ac2", "#6fd4ff"][i % 3], 2.0)
		mi.position = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


static func ore_cart(root: Node3D, p: Vector3, ry: float) -> void:
	var c: Node3D = Node3D.new()
	c.position = p
	c.rotation_degrees.y = ry
	root.add_child(c)
	LevelKit.box(c, Vector3(0, 0.65, 0), Vector3(1.6, 0.9, 1.1), "#5e3f32", true)
	for sx: float in [-0.55, 0.55]:
		for sz: float in [-0.56, 0.56]:
			LevelKit.cylinder(c, Vector3(sx, 0.2, sz), 0.2, 0.1, "#232838", false, "z")
	for o: Vector3 in [Vector3(-0.3, 1.2, -0.2), Vector3(0.3, 1.2, 0.2), Vector3(0, 1.25, 0)]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.52
		mi.mesh = sm
		mi.material_override = LevelKit.mat("#3fdfe4", 0.9)
		mi.position = o
		c.add_child(mi)


## Cart rails (deco): two thin rails from [x,y,z] to [x,y,z] with sleepers.
static func rails_deco(root: Node3D, d: Dictionary) -> void:
	var a: Vector3 = LevelKit.v3(d.get("from"))
	var b: Vector3 = LevelKit.v3(d.get("to"))
	var dir: Vector3 = (b - a).normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized() * 0.5
	var length: float = a.distance_to(b)
	for s: float in [-1.0, 1.0]:
		var mid: Vector3 = (a + b) * 0.5 + side * s
		var r: Node3D = LevelKit.box(root, mid, Vector3(0.1, 0.1, length), "#5e3f32", false)
		r.look_at_from_position(mid, mid + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)
	var n: int = int(length / 1.2)
	for i: int in n:
		var q: Vector3 = a.lerp(b, (float(i) + 0.5) / float(n))
		var sl: Node3D = LevelKit.box(root, q - Vector3(0, 0.04, 0), Vector3(1.4, 0.08, 0.25), "#4a3428", false)
		sl.look_at_from_position(q - Vector3(0, 0.04, 0), q - Vector3(0, 0.04, 0) + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)


## The Co-op winch: a big cable drum on a frame, where Sprocket builds the Tether-Hook.
static func winch(root: Node3D, p: Vector3) -> void:
	LevelKit.box(root, p + Vector3(0, 0.4, 0), Vector3(3.2, 0.8, 2.2), "#5a2a1e", true)
	for sx: float in [-1.4, 1.4]:
		LevelKit.box(root, p + Vector3(sx, 1.6, 0), Vector3(0.3, 2.0, 1.6), "#74301f", false)
	LevelKit.cylinder(root, p + Vector3(0, 2.0, 0), 0.95, 2.6, "#8a5a30", false, "x")
	for i: int in 6:
		LevelKit.cylinder(root, p + Vector3(-1.1 + i * 0.44, 2.0, 0), 1.0, 0.08, "#c9b8a0", false, "x")
	LevelKit.box(root, p + Vector3(1.9, 1.4, 0), Vector3(0.18, 1.2, 0.18), "#8a95a8", false, Vector3(0, 0, 30))


static func vending(root: Node3D, p: Vector3, ry: float) -> void:
	var c: Node3D = Node3D.new()
	c.position = p
	c.rotation_degrees.y = ry
	root.add_child(c)
	LevelKit.box(c, Vector3(0, 1.1, 0), Vector3(1.2, 2.2, 0.9), "#39404f", true)
	LevelKit.box(c, Vector3(0, 1.4, 0.47), Vector3(0.9, 1.2, 0.05), "#6fd4ff", false, Vector3.ZERO, 1, 1.4)
	LevelKit.box(c, Vector3(0.0, 2.05, 0.47), Vector3(0.9, 0.2, 0.05), "#ff6ac2", false, Vector3.ZERO, 1, 1.0)


static func time_clock(root: Node3D, p: Vector3) -> void:
	LevelKit.box(root, p + Vector3(0, 1.2, 0), Vector3(0.9, 2.4, 0.6), "#39404f", true)
	LevelKit.cylinder(root, p + Vector3(0, 1.9, 0.32), 0.3, 0.04, "#ffe27a", false, "z", -1.0, 1.4)
	LevelKit.box(root, p + Vector3(0, 1.2, 0.31), Vector3(0.5, 0.12, 0.04), "#232838", false)


static func kennel(root: Node3D, p: Vector3) -> void:
	LevelKit.box(root, p + Vector3(0, 0.7, 0), Vector3(2.4, 1.4, 1.8), "#f2ebe0", true)
	LevelKit.box(root, p + Vector3(0, 1.55, 0), Vector3(2.7, 0.3, 2.1), "#ff8ac2", false)
	LevelKit.box(root, p + Vector3(0, 0.55, 0.91), Vector3(0.9, 0.9, 0.04), "#232838", false)
	# the vest rack (XS-Corporate)
	LevelKit.box(root, p + Vector3(1.9, 1.0, 0), Vector3(0.08, 2.0, 0.08), "#8a95a8", false)
	LevelKit.box(root, p + Vector3(1.9, 1.9, 0), Vector3(0.08, 0.08, 1.4), "#8a95a8", false)
	for i: int in 3:
		LevelKit.box(root, p + Vector3(1.9, 1.55, -0.45 + i * 0.45), Vector3(0.1, 0.55, 0.35), "#3a4a8a", false)


static func mast_deco(root: Node3D, p: Vector3, h: float) -> void:
	LevelKit.box(root, p + Vector3(0, h * 0.5, 0), Vector3(0.35, h, 0.35), "#8a95a8", true)
	LevelKit.box(root, p + Vector3(0, h, 0), Vector3(1.4, 0.3, 1.4), "#39404f", false)


static func valet_loop(root: Node3D, d: Dictionary) -> void:
	var c: Vector3 = LevelKit.v3(d.get("center"))
	var r: float = float(d.get("r", 6.0))
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		LevelKit.box(root, c + Vector3(cos(a) * r, 0.02, sin(a) * r), Vector3(1.8, 0.04, 2.6), "#3a3438", false, Vector3(0, -rad_to_deg(a), 0))
	LevelKit.cylinder(root, c + Vector3(0, 0.3, 0), r * 0.55, 0.6, "#c8955a", true)
	LevelKit.cylinder(root, c + Vector3(0, 0.8, 0), 0.4, 1.0, "#3fdfe4", false, "y", 0.2, 0.8)


static func crate_stack(root: Node3D, p: Vector3, n: int) -> void:
	for i: int in n:
		LevelKit.box(root, p + Vector3((i % 2) * 1.1, 0.5 + (i / 2) * 1.0, (i % 3) * 0.3), Vector3(1.0, 1.0, 1.0), ["#74593a", "#8a5a30"][i % 2], true)
