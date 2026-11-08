class_name KranichExterior
extends Node3D
## Der Kranich from outside (T-220, the owner's plane pass on Fernflug Act II): the flying wing the squad stands on,
## built at load from data/gravelight/map04b_plane.json "hull" (the .tscn holds only this node). Visual only: no
## collider, no navmesh source, nothing on a gameplay layer; every face points outward and back-face culls, so from
## inside the plane (the blisters, the flight-deck glass, a breach) none of it draws.
##   the skin       one upper and one lower surface over the planform (a swept flying wing, 268 m tip to tip), the
##                  leading edge rounded, the trailing edge thin, fairings over every room roof, the window closets and
##                  the four engines, the skin dropped behind the starboard gun blisters (their field of fire), the
##                  wingtip caps; kranich_hull.gdshader paints it (panels, rivets, hatches, oil, wear, soot, stencils)
##   the engines    four impellers: an intake in the leading edge, a fairing on top, a nozzle in the trailing edge with
##                  a heat shimmer behind it and a dim exhaust glow at night (one small shadowless light each)
##   the structure  the dorsal aerial mast, the wingtip masts and the aerial wires, the dorsal gun turret, the
##                  navigator's astrodome over the flight deck, crew-sized hatches, the wingtip lamp pods
##   the motion     tarps, ropes and streamers that flutter (flutter.gdshader), a crate that buzzes on the skin, the
##                  formation's bombers re-skinned as the same wing (smaller); KranichAir's turbulence gusts them
## Pure rules (the planform, the skin heights, the mesh grid) are static so the tests can check the layout's
## clearances without building anything.

const DATA: String = "res://data/gravelight/map04b_plane.json"
const HULL_SHADER: String = "res://gravelight/world/map04/kranich_hull.gdshader"
const FLUTTER_SHADER: String = "res://gravelight/world/map04/flutter.gdshader"
const SHIMMER_SHADER: String = "res://gravelight/world/map04/heat_shimmer.gdshader"
const MARKS_TEX: String = "res://assets/ours/textures/kranich_markings/kranich_markings.png"
const SPAN: float = 134.0
const CHUNK_COLS: int = 18

@export var build_on_ready: bool = true
## the perf A/B (perf_marks --no-plane): never builds, never ticks
static var disabled: bool = false

var hull: Dictionary = {}
var built: bool = false
var tris: int = 0
var gust: float = 0.0            # 0..1, KranichAir raises it in a turbulence event (tarps flap harder, the crate buzzes)
var _hull_mat: ShaderMaterial = null
var _flutter_mats: Array[ShaderMaterial] = []
var _shimmer_mats: Array[ShaderMaterial] = []
var _glow_mats: Array[StandardMaterial3D] = []
var _glows: Array[OmniLight3D] = []
var _vibrate: Array = []         # [node, base position]
var _sky: Node = null
var _frost_src: ShaderMaterial = null
var _frost_t: float = 0.0
var _formation_done: bool = false
var _formation_t: float = 0.0
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ---------------------------------------------------------------- pure rules: the planform and the skin

## A knot list [[|x|, z], ...] (ascending |x|) read at |x| (straight segments, clamped at the ends).
static func knot_z(knots: Array, ax: float) -> float:
	if knots.is_empty():
		return 0.0
	var a: float = absf(ax)
	var prev: Array = knots[0]
	if a <= float(prev[0]):
		return float(prev[1])
	for i: int in range(1, knots.size()):
		var k: Array = knots[i]
		if a <= float(k[0]):
			var t: float = (a - float(prev[0])) / maxf(0.0001, float(k[0]) - float(prev[0]))
			return lerpf(float(prev[1]), float(k[1]), t)
		prev = k
	return float(prev[1])


static func le_z(h: Dictionary, x: float) -> float:
	return knot_z(h.get("le", []), x)


static func te_z(h: Dictionary, x: float) -> float:
	return knot_z(h.get("te", []), x)


## Is (x, z) over the wing's planform?
static func in_planform(h: Dictionary, x: float, z: float) -> bool:
	return absf(x) <= SPAN and z >= te_z(h, x) and z <= le_z(h, x)


## A rounded rectangle's weight along one axis: 1 inside [a, b], a cosine shoulder over `m` outside, 0 beyond.
static func shoulder(v: float, a: float, b: float, m: float) -> float:
	var d: float = maxf(a - v, v - b)
	if d <= 0.0:
		return 1.0
	if m <= 0.0 or d >= m:
		return 0.0
	return 0.5 + 0.5 * cos(PI * d / m)


## Every fairing [x0, z0, x1, z1, height, margin]: the data's bumps plus one per engine (from_z to the leading edge).
static func all_bumps(h: Dictionary) -> Array:
	var out: Array = (h.get("bumps", []) as Array).duplicate()
	var ef: Dictionary = h.get("engine_fairing", {})
	if not ef.is_empty():
		for ex: Variant in h.get("engines", []):
			var x: float = float(ex)
			var hw: float = float(ef.get("half_w", 2.0))
			out.append([x - hw, float(ef.get("from_z", 24.6)), x + hw, le_z(h, x) - float(ef.get("to_le", 1.2)),
				float(ef.get("height", 3.55)), float(ef.get("margin", 1.6))])
	return out


## The thickness at the span: the skin's top / bottom before the rounding (the tip thins past tip_from).
static func _span_tb(h: Dictionary, ax: float) -> Vector2:
	var top: float = float(h.get("top", 2.95))
	var bot: float = float(h.get("bottom", -0.62))
	var tf: float = float(h.get("tip_from", 120.0))
	if ax > tf:
		var k: float = smoothstep(tf, SPAN, ax)
		top = lerpf(top, float(h.get("tip_top", 2.25)), k)
		bot = lerpf(bot, float(h.get("tip_bottom", 0.45)), k)
	return Vector2(top, bot)


## The nose and tail rounding at (x, z): Vector2(top, bottom) of the bare airfoil (no fairings).
static func _airfoil(h: Dictionary, x: float, z: float) -> Vector2:
	var ax: float = absf(x)
	var le: float = le_z(h, x)
	var te: float = te_z(h, x)
	var c: float = maxf(0.5, le - te)
	var tb: Vector2 = _span_tb(h, ax)
	var mid: float = float(h.get("mid_y", 1.25))
	var gx: float = float(h.get("glass_x", 22.0))
	var round_on: float = smoothstep(gx, gx + 3.0, ax)
	var rle: float = minf(float(h.get("le_round", 6.0)), c * 0.3)
	var dl: float = clampf((le - z) / maxf(0.01, rle), 0.0, 1.0)
	var f: float = lerpf(1.0, pow(sin(dl * PI * 0.5), 0.55), round_on)
	var top: float = mid + (tb.x - mid) * f
	var bot: float = mid - (mid - tb.y) * f
	if round_on < 1.0:
		# in front of the flight-deck glass the nose is blunt: the bottom stays flat, the top too
		bot = lerpf(tb.y, bot, round_on)
		top = lerpf(tb.x, top, round_on)
	var rte: float = minf(float(h.get("te_round", 4.2)), c * 0.25)
	var g: float = smoothstep(0.0, rte, z - te)
	top = lerpf(float(h.get("te_top", 1.62)), top, g)
	bot = lerpf(float(h.get("te_bottom", 1.36)), bot, g)
	return Vector2(top, bot)


## The upper skin's height at (x, z): the airfoil, raised over every fairing, dropped behind the starboard blisters.
static func top_y(h: Dictionary, x: float, z: float, bumps: Array = []) -> float:
	var af: Vector2 = _airfoil(h, x, z)
	var top: float = af.x
	var bl: Array = bumps if not bumps.is_empty() else all_bumps(h)
	for b: Array in bl:
		var hb: float = float(b[4])
		if hb <= top:
			continue
		var m: float = float(b[5])
		var w: float = shoulder(x, float(b[0]), float(b[2]), m) * shoulder(z, float(b[1]), float(b[3]), m)
		if w > 0.0:
			top = maxf(top, lerpf(af.x, hb, w))
	var nt: Array = h.get("notch", [])
	if nt.size() >= 4 and x > 0.0:
		var wx: float = shoulder(x, float(nt[0]), float(nt[1]), 1.5)
		var wz: float = 1.0 - smoothstep(float(nt[2]) - 0.6, float(nt[2]), z)
		var wn: float = wx * wz
		if wn > 0.0:
			top = lerpf(top, maxf(float(nt[3]), af.y + 0.3), wn)
	return maxf(top, af.y + 0.05)


## The lower skin's height at (x, z).
static func bottom_y(h: Dictionary, x: float, z: float) -> float:
	return _airfoil(h, x, z).y


## The spanwise grid lines: a uniform step plus every feature edge (fairing edges and shoulders, the glass, the knots,
## the tip), so steep fairing sides fall on grid lines. Sorted, de-duplicated, -SPAN..SPAN.
static func grid_columns(h: Dictionary, step: float, features: bool = true) -> PackedFloat32Array:
	var xs: Array[float] = []
	var x: float = -SPAN
	while x < SPAN:
		xs.append(x)
		x += step
	xs.append(SPAN)
	for k: Variant in h.get("le", []) + h.get("te", []):
		var kx: float = float((k as Array)[0])
		xs.append(kx)
		xs.append(-kx)
	if features:
		var gx: float = float(h.get("glass_x", 22.0))
		for v: float in [gx, gx + 1.5, gx + 3.0, float(h.get("tip_from", 120.0))]:
			xs.append(v)
			xs.append(-v)
		for b: Array in all_bumps(h):
			var m: float = float(b[5])
			for v2: float in [float(b[0]), float(b[2]), float(b[0]) - m, float(b[2]) + m, float(b[0]) - m * 0.5, float(b[2]) + m * 0.5]:
				xs.append(v2)
		var nt: Array = h.get("notch", [])
		if nt.size() >= 4:
			for v3: float in [float(nt[0]), float(nt[1]), float(nt[0]) - 1.5, float(nt[1]) + 1.5]:
				xs.append(v3)
	xs.sort()
	var out: PackedFloat32Array = []
	for v4: float in xs:
		if v4 < -SPAN or v4 > SPAN:
			continue
		if out.is_empty() or v4 - out[out.size() - 1] > 0.18:
			out.append(v4)
	if out[out.size() - 1] < SPAN - 0.01:
		out[out.size() - 1] = SPAN
	return out


## The chordwise rows (0 = the trailing edge, 1 = the leading edge): denser at both edges for the rounding.
static func grid_rows(n: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = []
	for j: int in n + 1:
		var u: float = float(j) / float(n)
		out.append(lerpf(0.5 - 0.5 * cos(PI * u), u, 0.4))
	return out


# ---------------------------------------------------------------- build

func _ready() -> void:
	add_to_group(&"kranich_exterior")
	if disabled:
		set_process(false)
		return
	_rng.randomize()
	if build_on_ready:
		build()


func build() -> void:
	if built:
		return
	built = true
	var d: Dictionary = GLData.load_json(DATA)
	hull = d.get("hull", {})
	if hull.is_empty():
		push_warning("KranichExterior: no hull in %s" % DATA)
		return
	var t0: int = Time.get_ticks_usec()
	_hull_mat = _make_hull_material()
	_build_skin()
	_build_engines()
	_build_structure()
	_build_flutter()
	_build_walk_lamps()
	print("[exterior] der Kranich's hull: %d triangles, built in %.0f ms" % [tris, float(Time.get_ticks_usec() - t0) / 1000.0])


func _make_hull_material() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(HULL_SHADER) as Shader
	var tex: Callable = func(k: String) -> Texture2D:
		return MaterialLibrary.texture("kranich_skin", k) if MaterialLibrary != null else null
	m.set_shader_parameter("albedo_tex", tex.call("albedo"))
	m.set_shader_parameter("normal_tex", tex.call("normal"))
	m.set_shader_parameter("orm_tex", tex.call("orm"))
	if ResourceLoader.exists(MARKS_TEX):
		m.set_shader_parameter("marks_tex", load(MARKS_TEX))
	var paint: Dictionary = hull.get("paint", {})
	for k: String in ["top_a", "top_b", "under", "bare"]:
		if paint.has(k):
			m.set_shader_parameter(k, Color(str(paint[k])))
	if paint.has("soot"):
		m.set_shader_parameter("soot_color", Color(str(paint["soot"])))
	if paint.has("oil"):
		m.set_shader_parameter("oil_color", Color(str(paint["oil"])))
	# the nozzles for the soot
	var nz: Dictionary = hull.get("nozzle", {})
	var eng: Array = []
	for ex: Variant in hull.get("engines", []):
		var x: float = float(ex)
		var exit_z: float = te_z(hull, x) - float(nz.get("past_te", 1.3))
		eng.append(Vector4(x, exit_z, exit_z + float(nz.get("len_fwd", 5.0)), float(nz.get("radius", 0.86))))
	while eng.size() < 4:
		eng.append(Vector4(0, -999, -999, 0))
	m.set_shader_parameter("engines", eng.slice(0, 4))
	m.set_shader_parameter("engine_count", mini(4, (hull.get("engines", []) as Array).size()))
	# the stencils
	var rects: Array = []
	var cells: Array = []
	var cols: Array = []
	for mk: Variant in hull.get("markings", []):
		var a: Array = mk
		if rects.size() >= 12:
			break
		var rot: float = deg_to_rad(float(a[5]))
		rects.append(Vector4(float(a[0]), float(a[1]), float(a[2]) * 0.5, float(a[3]) * 0.5))
		cells.append(Vector4(float(a[4]), cos(rot), sin(rot), 0.0))
		cols.append(Color(str(a[6])))
	m.set_shader_parameter("mk_count", rects.size())
	while rects.size() < 12:
		rects.append(Vector4.ZERO)
		cells.append(Vector4.ZERO)
		cols.append(Color(0, 0, 0, 0))
	m.set_shader_parameter("mk_rect", rects)
	m.set_shader_parameter("mk_cell", cells)
	m.set_shader_parameter("mk_col", cols)
	return m


## Adds a surface (vertices, normals, indices) as one MeshInstance3D child.
func _add_mesh(nm: String, v: PackedVector3Array, n: PackedVector3Array, idx: PackedInt32Array, mat: Material, shadow: bool, parent: Node3D = null) -> MeshInstance3D:
	if idx.is_empty():
		return null
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	var tan: PackedFloat32Array = []
	tan.resize(v.size() * 4)
	for i: int in v.size():
		var nn: Vector3 = n[i]
		var t: Vector3 = (Vector3.RIGHT - nn * nn.dot(Vector3.RIGHT))
		if t.length_squared() < 0.0001:
			t = Vector3.FORWARD
		t = t.normalized()
		tan[i * 4] = t.x
		tan[i * 4 + 1] = t.y
		tan[i * 4 + 2] = t.z
		tan[i * 4 + 3] = -1.0 if nn.y >= 0.0 else 1.0
	arr[Mesh.ARRAY_TANGENT] = tan
	arr[Mesh.ARRAY_INDEX] = idx
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = am
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	(parent if parent != null else self).add_child(mi)
	tris += idx.size() / 3
	return mi


## One skin surface as chunks of CHUNK_COLS columns: rows over the chord at every column, normals from the grid.
func _build_surface(prefix: String, xs: PackedFloat32Array, rows: PackedFloat32Array, upper: bool, parent: Node3D, scale_k: float = 1.0, shadow: bool = true) -> void:
	var bumps: Array = all_bumps(hull)
	var nr: int = rows.size()
	var nc: int = xs.size()
	# positions for the whole grid first (normals need the neighbours across chunk seams)
	var pos: Array[PackedVector3Array] = []
	for i: int in nc:
		var x: float = xs[i]
		var te: float = te_z(hull, x)
		var le: float = le_z(hull, x)
		var col: PackedVector3Array = []
		col.resize(nr)
		for j: int in nr:
			var z: float = lerpf(te, le, rows[j])
			var y: float = top_y(hull, x, z, bumps) if upper else bottom_y(hull, x, z)
			col[j] = Vector3(x, y, z) * scale_k
		pos.append(col)
	var c0: int = 0
	var chunk: int = 0
	while c0 < nc - 1:
		var c1: int = mini(nc - 1, c0 + CHUNK_COLS)
		var v: PackedVector3Array = []
		var n: PackedVector3Array = []
		var idx: PackedInt32Array = []
		for i: int in range(c0, c1 + 1):
			for j: int in nr:
				var p: Vector3 = pos[i][j]
				var px: Vector3 = pos[mini(nc - 1, i + 1)][j] - pos[maxi(0, i - 1)][j]
				var pz: Vector3 = pos[i][mini(nr - 1, j + 1)] - pos[i][maxi(0, j - 1)]
				var nn: Vector3 = pz.cross(px).normalized()
				if (nn.y < 0.0) == upper:
					nn = -nn
				v.append(p)
				n.append(nn)
		var w: int = nr
		for i2: int in range(0, c1 - c0):
			for j2: int in nr - 1:
				var a: int = i2 * w + j2
				var b: int = (i2 + 1) * w + j2
				# winding so the face's front is outward (up on the top, down underneath)
				if upper:
					idx.append_array([a, b, a + 1, b, b + 1, a + 1])
				else:
					idx.append_array([a, a + 1, b, b, a + 1, b + 1])
		_add_mesh("%s%d" % [prefix, chunk], v, n, idx, _hull_mat, shadow, parent)
		chunk += 1
		c0 = c1


## The closing faces: the trailing edge's lip, the blunt nose in front of the glass (its brow over the glass, its chin
## under it), the wingtip caps.
func _build_edges(parent: Node3D, scale_k: float = 1.0) -> void:
	var xs: PackedFloat32Array = grid_columns(hull, float(hull.get("cols_step", 2.0)))
	var bumps: Array = all_bumps(hull)
	var gx: float = float(hull.get("glass_x", 22.0))
	var gtop: float = float(hull.get("glass_top", 4.85))
	var v: PackedVector3Array = []
	var n: PackedVector3Array = []
	var idx: PackedInt32Array = []
	var quad: Callable = func(a: Vector3, b: Vector3, c: Vector3, dd: Vector3, out_hint: Vector3) -> void:
		# a-b along the edge at the top, c-d below them; the face turned to face out_hint
		var nn: Vector3 = (b - a).cross(c - a).normalized()
		var flip: bool = nn.dot(out_hint) < 0.0
		if flip:
			nn = -nn
		var base: int = v.size()
		v.append_array([a * scale_k, b * scale_k, c * scale_k, dd * scale_k])
		n.append_array([nn, nn, nn, nn])
		if flip:
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
		else:
			idx.append_array([base, base + 2, base + 1, base + 1, base + 2, base + 3])
	for i: int in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		# the trailing edge
		var t0: float = te_z(hull, x0)
		var t1: float = te_z(hull, x1)
		var a: Vector3 = Vector3(x0, top_y(hull, x0, t0, bumps), t0)
		var b: Vector3 = Vector3(x1, top_y(hull, x1, t1, bumps), t1)
		var c: Vector3 = Vector3(x0, bottom_y(hull, x0, t0), t0)
		var dd: Vector3 = Vector3(x1, bottom_y(hull, x1, t1), t1)
		var inward: Vector3 = Vector3((x0 + x1) * 0.5, 1.0, (t0 + t1) * 0.5 + 1.0)
		quad.call(a, b, c, dd, ((a + b) * 0.5 - inward) * Vector3(1, 0, 1))
		# the leading edge: only where the top and the bottom do not meet (in front of the glass)
		var l0: float = le_z(hull, x0)
		var l1: float = le_z(hull, x1)
		var ta: Vector3 = Vector3(x0, top_y(hull, x0, l0, bumps), l0)
		var tb: Vector3 = Vector3(x1, top_y(hull, x1, l1, bumps), l1)
		var ba: Vector3 = Vector3(x0, bottom_y(hull, x0, l0), l0)
		var bb: Vector3 = Vector3(x1, bottom_y(hull, x1, l1), l1)
		if ta.y - ba.y > 0.03 or tb.y - bb.y > 0.03:
			var fwd: Vector3 = Vector3(0, 0, 1)
			if absf(x0) < gx - 0.01 and absf(x1) < gx + 0.01:
				# the brow over the glass, the chin under it
				quad.call(ta, tb, Vector3(x0, gtop, l0), Vector3(x1, gtop, l1), fwd)
				quad.call(Vector3(x0, 0.0, l0), Vector3(x1, 0.0, l1), ba, bb, fwd)
			else:
				quad.call(ta, tb, ba, bb, Vector3(signf(x0 + x1) * 0.3, 0, 1))
	# the wingtip caps: the tip chord's profile closed with a fan of quads
	for sx: float in [-1.0, 1.0]:
		var x: float = SPAN * sx
		var te2: float = te_z(hull, x)
		var le2: float = le_z(hull, x)
		var k: int = 14
		for j: int in k:
			var z0: float = lerpf(te2, le2, float(j) / float(k))
			var z1: float = lerpf(te2, le2, float(j + 1) / float(k))
			quad.call(Vector3(x, top_y(hull, x, z0, bumps), z0), Vector3(x, top_y(hull, x, z1, bumps), z1),
				Vector3(x, bottom_y(hull, x, z0), z0), Vector3(x, bottom_y(hull, x, z1), z1), Vector3(sx, 0, 0))
	_add_mesh("HullEdges", v, n, idx, _hull_mat, true, parent)


func _build_skin() -> void:
	var skin: Node3D = Node3D.new()
	skin.name = "Skin"
	add_child(skin)
	_build_surface("Top", grid_columns(hull, float(hull.get("cols_step", 2.0))), grid_rows(int(hull.get("rows", 150))), true, skin)
	_build_surface("Under", grid_columns(hull, float(hull.get("bottom_cols_step", 4.0)), false), grid_rows(int(hull.get("bottom_rows", 46))), false, skin, 1.0, false)
	_build_edges(skin)


# ---------------------------------------------------------------- engines

func _steel(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _mesh(nm: String, mesh: Mesh, mat: Material, xf: Transform3D, parent: Node3D, shadow: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mi)
	var am: Mesh = mesh
	for s: int in am.get_surface_count():
		var a: Array = am.surface_get_arrays(s)
		var ix: Variant = a[Mesh.ARRAY_INDEX]
		tris += ((ix as PackedInt32Array).size() if ix != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return mi


func _cyl(r0: float, r1: float, h: float, seg: int = 20, caps: bool = true) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.cap_top = caps
	c.cap_bottom = caps
	return c


## An axis-z transform (a cylinder's local Y turned to point along +Z) at p, scaled (sx, sy) across.
static func _along_z(p: Vector3, sx: float = 1.0, sy: float = 1.0) -> Transform3D:
	var b: Basis = Basis(Vector3(1, 0, 0), deg_to_rad(90.0))
	return Transform3D(Basis.from_scale(Vector3(sx, sy, 1.0)) * b, p)


func _build_engines() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Engines"
	add_child(root)
	var nz: Dictionary = hull.get("nozzle", {})
	var it: Dictionary = hull.get("intake", {})
	var heat: StandardMaterial3D = _steel(Color(0.17, 0.16, 0.16), 0.75, 0.48)
	heat.cull_mode = BaseMaterial3D.CULL_DISABLED   # open tubes: their inner walls are what you look into
	var lip_paint: StandardMaterial3D = _steel(Color(str((hull.get("paint", {}) as Dictionary).get("top_a", "#3b3e37"))), 0.3, 0.55)
	lip_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark: StandardMaterial3D = _steel(Color(0.02, 0.02, 0.022), 0.2, 0.9)
	var glow_c: Color = Color(str(nz.get("glow", "#ff9a52")))
	var sh: Shader = load(SHIMMER_SHADER) as Shader
	for ex: Variant in hull.get("engines", []):
		var x: float = float(ex)
		var e: Node3D = Node3D.new()
		e.name = "Engine%d" % int(x)
		root.add_child(e)
		# the nozzle, half in the trailing-edge apron
		var r: float = float(nz.get("radius", 0.86))
		var exit_z: float = te_z(hull, x) - float(nz.get("past_te", 1.3))
		var ln: float = float(nz.get("len_fwd", 5.0))
		var y: float = float(nz.get("y", 2.62))
		_mesh("Nozzle", _cyl(r * 1.06, r, ln, 24, false), heat, _along_z(Vector3(x, y, exit_z + ln * 0.5)), e, true)
		_mesh("NozzleLip", _cyl(r * 1.12, r * 1.12, 0.12, 24, false), _steel(Color(0.09, 0.085, 0.08), 0.8, 0.4), _along_z(Vector3(x, y, exit_z + 0.06)), e)
		# deep inside: the dark throat and the glowing cone at night
		_mesh("Throat", _cyl(r * 0.98, r * 0.98, 0.02, 24), dark, _along_z(Vector3(x, y, exit_z + 1.6)), e)
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color = glow_c
		gm.emission_enabled = true
		gm.emission = glow_c
		gm.emission_energy_multiplier = 1.6
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glow_mats.append(gm)
		_mesh("Glow", _cyl(r * 0.2, r * 0.9, 1.0, 24, false), gm, _along_z(Vector3(x, y, exit_z + 1.1)), e)
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "ExhaustGlow"
		l.light_color = glow_c
		l.light_energy = float(nz.get("light_energy", 0.55))
		l.omni_range = float(nz.get("light_range", 7.0))
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 90.0
		l.distance_fade_length = 20.0
		l.position = Vector3(x, y + 0.2, exit_z - 1.4)
		l.set_meta("zone", &"SKY")
		l.set_meta("base_energy", l.light_energy)
		e.add_child(l)
		_glows.append(l)
		# the heat shimmer: an open cone streaming aft
		if sh != null:
			var sm: ShaderMaterial = ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("glow", glow_c)
			_shimmer_mats.append(sm)
			_mesh("Shimmer", _cyl(r * 0.95, r * 2.6, 9.0, 16, false), sm, _along_z(Vector3(x, y, exit_z - 4.5)), e)
		# the intake in the leading edge, under the fairing's nose
		var le: float = le_z(hull, x)
		var rx: float = float(it.get("rx", 1.25))
		var ry: float = float(it.get("ry", 0.62))
		var iy: float = float(it.get("y", 1.5))
		var depth: float = float(it.get("depth", 1.4))
		_mesh("IntakeLip", _cyl(1.0, 1.08, depth, 28, false), lip_paint, _along_z(Vector3(x, iy, le + depth * 0.15), rx, ry), e, true)
		_mesh("IntakeMouth", _cyl(0.96, 0.96, 0.02, 28), dark, _along_z(Vector3(x, iy, le - depth * 0.2), rx, ry), e)
		_mesh("Spinner", _cyl(0.02, 0.32, 0.6, 16), heat, _along_z(Vector3(x, iy, le), 1.0, 1.0), e)


# ---------------------------------------------------------------- structure

func _y(x: float, z: float) -> float:
	return top_y(hull, x, z)


func _build_structure() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Structure"
	add_child(root)
	var paint: StandardMaterial3D = _steel(Color(0.12, 0.125, 0.12), 0.45, 0.6)
	var wire: StandardMaterial3D = _steel(Color(0.05, 0.05, 0.05), 0.6, 0.5)
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.5, 0.58, 0.66, 0.22)
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_BACK
	var ms: Dictionary = hull.get("masts", {})
	# the aerial masts and the wires between them (a little sag)
	var tops: Array[Vector3] = []
	var dm: Array = ms.get("dorsal", [0.0, 40.0, 4.6])
	var db: float = _y(float(dm[0]), float(dm[1]))
	var dtop: Vector3 = Vector3(float(dm[0]), db + float(dm[2]), float(dm[1]))
	_mesh("DorsalMast", _cyl(0.035, 0.09, float(dm[2]), 10), paint, Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(-12.0)), Vector3(dtop.x, db + float(dm[2]) * 0.5, dtop.z - 0.4)), root, true)
	_mesh("DorsalMastFoot", _cyl(0.32, 0.42, 0.18, 14), paint, Transform3D(Basis.IDENTITY, Vector3(dtop.x, db + 0.05, dtop.z)), root)
	for tm: Variant in ms.get("tips", []):
		var a: Array = tm
		var tb: float = _y(float(a[0]), float(a[1]))
		_mesh("TipMast", _cyl(0.03, 0.06, float(a[2]), 8), paint, Transform3D(Basis.IDENTITY, Vector3(float(a[0]), tb + float(a[2]) * 0.5, float(a[1]))), root, true)
		tops.append(Vector3(float(a[0]), tb + float(a[2]), float(a[1])))
	var wr: float = float(ms.get("wire_r", 0.016))
	for tp: Vector3 in tops:
		var mid: Vector3 = (dtop + tp) * 0.5 + Vector3(0, -0.7, 0)
		for seg: Array in [[dtop, mid], [mid, tp]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			var ln: float = p0.distance_to(p1)
			var up: Vector3 = (p1 - p0).normalized()
			var bx: Basis = Basis(up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized(), up, Vector3.ZERO)
			bx.z = bx.x.cross(bx.y).normalized()
			_mesh("AerialWire", _cyl(wr, wr, ln, 4, false), wire, Transform3D(bx, (p0 + p1) * 0.5), root)
		# insulators
		_mesh("Insulator", SphereMesh.new(), _steel(Color(0.32, 0.26, 0.2), 0.0, 0.5), Transform3D(Basis.from_scale(Vector3.ONE * 0.09), tp.lerp(dtop, 0.02)), root)
	# the dorsal turret: a perspex dome on a ring, twin guns aft
	var tu: Array = hull.get("turret", [0.0, 30.5])
	var ty: float = _y(float(tu[0]), float(tu[1]))
	var tc: Vector3 = Vector3(float(tu[0]), ty, float(tu[1]))
	_mesh("TurretRing", _cyl(1.25, 1.35, 0.32, 28), paint, Transform3D(Basis.IDENTITY, tc + Vector3(0, 0.12, 0)), root, true)
	var dome: SphereMesh = SphereMesh.new()
	dome.radius = 1.1
	dome.height = 2.2
	dome.is_hemisphere = true
	dome.radial_segments = 28
	dome.rings = 10
	_mesh("TurretDome", dome, glass, Transform3D(Basis.from_scale(Vector3(1, 0.85, 1)), tc + Vector3(0, 0.28, 0)), root)
	_mesh("TurretSeat", _cyl(0.5, 0.6, 0.6, 12), _steel(Color(0.04, 0.04, 0.04), 0.3, 0.8), Transform3D(Basis.IDENTITY, tc + Vector3(0, 0.55, 0)), root)
	for gx: float in [-0.22, 0.22]:
		_mesh("TurretGun", _cyl(0.045, 0.06, 2.0, 8), _steel(Color(0.06, 0.06, 0.065), 0.8, 0.4),
			Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(-80.0)), tc + Vector3(gx, 0.85, -1.4)), root, true)
	# the navigator's astrodome over the flight deck, framed
	var cn: Array = hull.get("canopy", [0.0, 67.0, 7.0, 4.2, 1.1])
	var cc: Vector3 = Vector3(float(cn[0]), _y(float(cn[0]), float(cn[1])), float(cn[1]))
	var cdome: SphereMesh = SphereMesh.new()
	cdome.radius = 1.0
	cdome.height = 2.0
	cdome.is_hemisphere = true
	cdome.radial_segments = 32
	cdome.rings = 12
	var csx: float = float(cn[2]) * 0.5
	var csz: float = float(cn[3]) * 0.5
	var csy: float = float(cn[4])
	_mesh("CanopyGlass", cdome, glass, Transform3D(Basis.from_scale(Vector3(csx, csy, csz)), cc), root)
	_mesh("CanopyCoaming", _cyl(1.0, 1.04, 0.16, 32), paint, Transform3D(Basis.from_scale(Vector3(csx, 1.0, csz)), cc + Vector3(0, 0.05, 0)), root, true)
	_mesh("CanopyFloor", _cyl(0.97, 0.97, 0.02, 32), _steel(Color(0.015, 0.016, 0.018), 0.1, 0.9), Transform3D(Basis.from_scale(Vector3(csx, 1.0, csz)), cc + Vector3(0, 0.12, 0)), root)
	for k: int in 5:
		var fz: float = lerpf(-0.8, 0.8, float(k) / 4.0)
		var rr: float = sqrt(maxf(0.0, 1.0 - fz * fz))
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.985
		tor.outer_radius = 1.015
		tor.rings = 24
		tor.ring_segments = 4
		_mesh("CanopyFrame", tor, paint, Transform3D(Basis.from_scale(Vector3(csx * rr, csy * rr, 1.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(90.0)), cc + Vector3(0, 0, fz * csz)), root)
	# crew-sized hatches: a frame, a lid standing a little proud, hinges and a handle
	for hp: Variant in hull.get("hatches", []):
		var a2: Array = hp
		var hx: float = float(a2[0])
		var hz: float = float(a2[1])
		var hy: float = _y(hx, hz)
		var h: Node3D = Node3D.new()
		h.name = "Hatch"
		h.position = Vector3(hx, hy, hz)
		var nrm: Vector3 = Vector3(_y(hx - 0.5, hz) - _y(hx + 0.5, hz), 1.0, _y(hx, hz - 0.5) - _y(hx, hz + 0.5)).normalized()
		h.basis = Basis(Quaternion(Vector3.UP, nrm))
		root.add_child(h)
		var frame: BoxMesh = BoxMesh.new()
		frame.size = Vector3(1.0, 0.05, 1.0)
		_mesh("Frame", frame, paint, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), h)
		var lid: BoxMesh = BoxMesh.new()
		lid.size = Vector3(0.86, 0.06, 0.86)
		_mesh("Lid", lid, _hull_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.035, 0)), h, true)
		for side: float in [-0.3, 0.3]:
			_mesh("Hinge", _cyl(0.035, 0.035, 0.16, 8), paint, Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(90.0)), Vector3(side, 0.05, 0.45)), h)
		var hb: BoxMesh = BoxMesh.new()
		hb.size = Vector3(0.22, 0.04, 0.04)
		_mesh("Handle", hb, _steel(Color(0.2, 0.19, 0.17), 0.8, 0.45), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, -0.3)), h)
	# the wingtip lamp pods (the lamps themselves are the generator's red / green nav lights)
	for sx: float in [-1.0, 1.0]:
		var lp: Vector3 = Vector3(129.5 * sx, 3.3, 25.0)
		var py: float = _y(lp.x, lp.z)
		_mesh("NavStalk", _cyl(0.05, 0.08, lp.y - py, 8), paint, Transform3D(Basis.IDENTITY, Vector3(lp.x, (lp.y + py) * 0.5, lp.z)), root)
		var lens: StandardMaterial3D = StandardMaterial3D.new()
		lens.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lens.albedo_color = Color(0.9, 0.2, 0.15) if sx < 0.0 else Color(0.25, 0.9, 0.4)
		_mesh("NavLens", SphereMesh.new(), lens, Transform3D(Basis.from_scale(Vector3.ONE * 0.22), lp), root)


# ---------------------------------------------------------------- the things the wind moves

## A strip of quads from `a` along `dir` for `length` m, `width` wide, `segs` segments; COLOR.r = 0 at the root .. 1 at
## the free end (the flutter shader's freedom), COLOR.g = a phase.
func _ribbon(a: Vector3, dir: Vector3, side: Vector3, length: float, width: float, segs: int, phase: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d: Vector3 = dir.normalized()
	var s: Vector3 = side.normalized() * width * 0.5
	var nrm: Vector3 = d.cross(s).normalized()
	for i: int in segs:
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var p0: Vector3 = a + d * length * t0
		var p1: Vector3 = a + d * length * t1
		var q: Array = [[p0 - s, t0], [p0 + s, t0], [p1 - s, t1], [p1 + s, t1]]
		for k: int in [0, 2, 1, 1, 2, 3]:
			st.set_color(Color(float(q[k][1]), phase, 0, 1))
			st.set_normal(nrm)
			st.set_uv(Vector2(float(k % 2), float(q[k][1])))
			st.add_vertex(q[k][0])
	return st.commit()


func _flutter_mat(albedo: Color, amp: float, freq: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(FLUTTER_SHADER) as Shader
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("freq", freq)
	_flutter_mats.append(m)
	return m


## A canvas tarp lashed over a crate: a grid draped over the box and down to the skin, its loose aft hem flapping.
func _tarp(at: Vector3, yaw_deg: float, parent: Node3D) -> void:
	var g: Node3D = Node3D.new()
	g.name = "Tarp"
	g.position = at
	g.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(g)
	var crate: BoxMesh = BoxMesh.new()
	crate.size = Vector3(1.7, 0.9, 1.1)
	var cm: MeshInstance3D = _mesh("Crate", crate, _steel(Color(0.2, 0.19, 0.15), 0.0, 0.85), Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), g, true)
	_vibrate.append([cm, cm.position])
	var can: BoxMesh = BoxMesh.new()
	can.size = Vector3(0.18, 0.47, 0.34)
	var jc: MeshInstance3D = _mesh("Jerrycan", can, _steel(Color(0.17, 0.18, 0.15), 0.4, 0.6), Transform3D(Basis.IDENTITY, Vector3(1.05, 0.24, 0.1)), g, true)
	_vibrate.append([jc, jc.position])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx: int = 12
	var nzc: int = 10
	var hx: float = 1.25
	var hz: float = 0.95
	var pts: Array = []
	for i: int in nx + 1:
		var row: Array = []
		for j: int in nzc + 1:
			var u: float = lerpf(-hx, hx, float(i) / float(nx))
			var w: float = lerpf(-hz, hz, float(j) / float(nzc))
			# over the box top (0.92), then falling down its sides to the skin
			var ox: float = maxf(0.0, absf(u) - 0.85)
			var oz: float = maxf(0.0, absf(w) - 0.55)
			var o: float = maxf(ox, oz)
			var y: float = 0.93 - minf(0.9, o * 2.6)
			var free: float = clampf(o / 0.4, 0.0, 1.0) * (1.0 if w < 0.0 else 0.35)   # the aft hem is loose
			row.append([Vector3(u, y, w), free])
		pts.append(row)
	for i2: int in nx:
		for j2: int in nzc:
			var q: Array = [pts[i2][j2], pts[i2 + 1][j2], pts[i2][j2 + 1], pts[i2 + 1][j2 + 1]]
			for k: int in [0, 2, 1, 1, 2, 3]:
				st.set_color(Color(float(q[k][1]), 0.3, 0, 1))
				st.set_uv(Vector2(float(i2 + (k % 2)) / float(nx), float(j2 + (k / 2)) / float(nzc)))
				st.add_vertex(q[k][0])
	st.generate_normals()
	var tm: ArrayMesh = st.commit()
	_mesh("Canvas", tm, _flutter_mat(Color(0.3, 0.29, 0.24), 0.08, 9.0), Transform3D.IDENTITY, g, true)
	# the lashings to the skin
	for c: Vector3 in [Vector3(-1.2, 0, -0.9), Vector3(1.2, 0, -0.9), Vector3(-1.2, 0, 0.9), Vector3(1.2, 0, 0.9)]:
		_mesh("Lashing", _cyl(0.012, 0.012, 1.1, 4, false), _steel(Color(0.18, 0.16, 0.12), 0.0, 0.9),
			Transform3D(Basis(Vector3(c.z, 0, -c.x).normalized(), deg_to_rad(38.0)), c * 0.85 + Vector3(0, 0.45, 0)), g)


func _build_flutter() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Flutter"
	add_child(root)
	var fl: Dictionary = hull.get("flutter", {})
	for t: Variant in fl.get("tarps", []):
		var a: Array = t
		_tarp(Vector3(float(a[0]), _y(float(a[0]), float(a[1])), float(a[1])), float(a[2]), root)
	# loose tether lines streaming aft off the catwalk's aft rail
	var rope_m: ShaderMaterial = _flutter_mat(Color(0.32, 0.29, 0.22), 0.16, 7.0)
	for r: Variant in fl.get("ropes", []):
		var b: Array = r
		var at: Vector3 = Vector3(float(b[0]), 3.4 + 1.0, float(b[1]))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Rope"
		mi.mesh = _ribbon(at, Vector3(0, -0.45, -1.0), Vector3(1, 0, 0), float(b[2]), 0.035, 14, _rng.randf())
		mi.material_override = rope_m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	# canvas streamers on the masts and the pitot
	var str_m: ShaderMaterial = _flutter_mat(Color(0.52, 0.5, 0.44), 0.22, 11.0)
	for s: Variant in fl.get("streamers", []):
		var c: Array = s
		var base_y: float = _y(float(c[0]), float(c[1]))
		var at2: Vector3 = Vector3(float(c[0]), base_y + float(c[2]) * 0.82, float(c[1]))
		var mi2: MeshInstance3D = MeshInstance3D.new()
		mi2.name = "Streamer"
		mi2.mesh = _ribbon(at2, Vector3(0, -0.12, -1.0), Vector3(0, 1, 0), 1.5, 0.11, 10, _rng.randf())
		mi2.material_override = str_m
		mi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi2)


## The wing walk's lamps: the tether posts' own lamps (ClipPoint) given a little real light, dim and warm, low on the
## post, so the skin under the grating reads at night (no shadows).
func _build_walk_lamps() -> void:
	var wl: Dictionary = hull.get("walk_lamps", {})
	if wl.is_empty():
		return
	var ww: Dictionary = ((GLData.load_json("res://data/gravelight/map04b.json") as Dictionary).get("flight", {}) as Dictionary).get("wing_walk", {})
	var root: Node3D = Node3D.new()
	root.name = "WalkLamps"
	add_child(root)
	for cp: Variant in ww.get("clip_points", []):
		var a: Array = cp
		var p: Vector3 = Vector3(float(a[0]), float(a[1]) + float(wl.get("up", 1.15)), float(a[2]))
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "WalkLamp"
		l.light_color = Color(str(wl.get("color", "#ffc98a")))
		l.light_energy = float(wl.get("energy", 0.45))
		l.omni_range = float(wl.get("range", 6.5))
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.3
		l.distance_fade_enabled = true
		l.distance_fade_begin = 70.0
		l.distance_fade_length = 15.0
		l.position = p + Vector3(0, 0.25, 0)
		l.set_meta("zone", &"C_FLUEGEL_L")
		root.add_child(l)


## The formation's bombers (MapAmbience kind `formation`, boxes) re-skinned as this same wing, smaller: their box
## meshes hidden, a low-detail copy of the hull under each (it rides their bob and the one that goes down).
func _reskin_formation() -> void:
	var nodes: Array[Node] = []
	var root: Node = get_parent() if get_parent() != null else get_tree().current_scene
	if root == null:
		return
	for n: Node in root.find_children("Formation*", "Node3D", true, false):
		nodes.append(n)
	if nodes.is_empty():
		return
	_formation_done = true
	var k: float = float(hull.get("formation_scale", 0.5))
	var proto: Node3D = Node3D.new()
	proto.name = "WingProto"
	_build_surface("FTop", grid_columns(hull, 9.0, false), grid_rows(24), true, proto, k, false)
	_build_surface("FUnder", grid_columns(hull, 18.0, false), grid_rows(8), false, proto, k, false)
	for n2: Node in nodes:
		var f: Node3D = n2 as Node3D
		for c: Node in f.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
				(c as MeshInstance3D).visible = false
		var copy: Node3D = proto.duplicate() as Node3D
		copy.position = Vector3(0, -1.6, -37.0) * k
		f.add_child(copy)
	proto.free()
	print("[exterior] re-skinned %d formation bombers" % nodes.size())


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	if not built or hull.is_empty():
		return
	_t += delta
	gust = move_toward(gust, 0.0, delta / 2.5)
	if not _formation_done:
		_formation_t += delta
		if _formation_t > 1.0:
			_formation_t = 0.0
			_reskin_formation()
	if _sky == null or not is_instance_valid(_sky):
		_sky = get_tree().get_first_node_in_group(&"flight_sky")
	var dawn: float = clampf(float(_sky.get("sunrise")) if _sky != null else 0.0, 0.0, 1.0)
	var nz: Dictionary = hull.get("nozzle", {})
	var glow_k: float = lerpf(float(nz.get("glow_night", 0.9)), float(nz.get("glow_dawn", 0.25)), dawn)
	for l: OmniLight3D in _glows:
		l.light_energy = float(l.get_meta("base_energy", 0.55)) * glow_k * (0.9 + 0.1 * sin(_t * 23.0 + l.position.x))
	for gm: StandardMaterial3D in _glow_mats:
		gm.emission_energy_multiplier = 1.6 * glow_k
	for fm: ShaderMaterial in _flutter_mats:
		fm.set_shader_parameter("gust", gust)
	for sm: ShaderMaterial in _shimmer_mats:
		sm.set_shader_parameter("night", glow_k)
	# the crate and the jerrycan buzz on the skin (the impellers' beat; harder in a gust)
	var amp: float = 0.0025 + 0.01 * gust
	for v: Array in _vibrate:
		var n: Node3D = v[0] as Node3D
		if is_instance_valid(n):
			n.position = (v[1] as Vector3) + Vector3(sin(_t * 61.0 + n.position.x) * amp, absf(sin(_t * 47.0)) * amp, cos(_t * 53.0) * amp * 0.6)
	# the act's frost on the inner skin (MapAmbience kranich_frost) rimes the outer skin too
	_frost_t -= delta
	if _frost_t <= 0.0:
		_frost_t = 1.0
		if _frost_src == null:
			var m: Material = KranichShell.skin_material()
			_frost_src = m as ShaderMaterial
		if _frost_src != null and _hull_mat != null:
			var fr: Variant = _frost_src.get_shader_parameter("frost")
			_hull_mat.set_shader_parameter("frost", float(fr) if fr != null else 0.0)


## KranichAir's turbulence: the canvas snaps, the crate rattles.
func gust_now(k: float = 1.0) -> void:
	gust = maxf(gust, clampf(k, 0.0, 1.0))
