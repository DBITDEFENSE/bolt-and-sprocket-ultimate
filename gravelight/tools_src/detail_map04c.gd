extends RefCounted
## Act III (Groom Lake) detail pieces for gen_map04c.gd (UPDATE 09 §5.4, DECISIONS T-148). Static and pure: every
## function builds non-colliding dressing under `parent` (the generator's Dressing) and returns nothing the
## gameplay reads. Two kinds of pieces:
##   · generator-scripted meshes (SurfaceTool lofts, one ArrayMesh per material): the Kranich's wing shell and its
##     torn port wing, the radar dish, the ridge rings, the scorch card, the canvas truck covers;
##   · proportioned primitives through `Props` (boxes, cylinders, struts), which gen_map04_lib's
##     merge_static_meshes() folds into per-material batches, so a 300-strut lattice costs a handful of draw calls.
## Coordinates are world metres (+Z north, +X east, y up) unless a function says "local".
## Faces: `face()` orients each polygon against an outward hint with Godot's rule (front normal = (c-a)x(b-a)).

const SH: String = "res://gravelight/world/map04/shaders/"

static var _mats: Dictionary = {}


# ================================================================== mesh utils

static func st_new(smooth: bool = true) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0 if smooth else -1)
	return st


## A convex polygon (3+ points, in order round its edge), turned so its front faces `out`.
static func face(st: SurfaceTool, pts: Array, out: Vector3) -> void:
	if pts.size() < 3:
		return
	var a: Vector3 = pts[0]
	var n: Vector3 = Vector3.ZERO
	for i: int in range(1, pts.size() - 1):
		n += ((pts[i + 1] as Vector3) - a).cross((pts[i] as Vector3) - a)
	var flip: bool = n.dot(out) < 0.0
	for i: int in range(1, pts.size() - 1):
		var b: Vector3 = pts[i]
		var c: Vector3 = pts[i + 1]
		st.set_uv(Vector2(a.x + a.y, a.z) * 0.25)
		st.add_vertex(a)
		if flip:
			st.set_uv(Vector2(c.x + c.y, c.z) * 0.25)
			st.add_vertex(c)
			st.set_uv(Vector2(b.x + b.y, b.z) * 0.25)
			st.add_vertex(b)
		else:
			st.set_uv(Vector2(b.x + b.y, b.z) * 0.25)
			st.add_vertex(b)
			st.set_uv(Vector2(c.x + c.y, c.z) * 0.25)
			st.add_vertex(c)


static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func mesh_node(parent: Node3D, n: String, mesh: Mesh, mat: Variant, shadow: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat as Material if mat is Material else Mats.get_mat(str(mat))
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func shader_mat(file: String, params: Dictionary = {}) -> ShaderMaterial:
	var key: String = file + str(params)
	if _mats.has(key):
		return _mats[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH + file) as Shader
	for k: String in params.keys():
		m.set_shader_parameter(k, params[k])
	_mats[key] = m
	return m


# ================================================================== profiles

## NACA-style thickness (flat belly): 0 at the leading and trailing edges, 1.0 at ~30 % chord.
static func naca(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 2.0 * 5.0 * (0.2969 * sqrt(t) - 0.126 * t - 0.3516 * t * t + 0.2843 * t * t * t - 0.1036 * t * t * t * t)


## The centre body's fuller profile: it has to clear the spawn room's roof (4.6 m) almost to its aft wall.
static func body(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return pow(sin(PI * t), 0.35) * (1.0 + 0.15 * sin(PI * t)) / 1.15


# ================================================================== the Kranich wreck

## The wing's stations, west to east: [x, le_z, te_z, thickness, belly_y, body?]. The centre body (|x| <= 14.3)
## has a virtual leading edge at z +1 and is cut open at z -3.7 (the bay, the AB wall's face); the wings proper
## sweep back from z -4.4 so nothing ever hangs over the walkable salt north of the berm (z > -4.15).
const BODY_LE: float = 1.0
const BODY_TE: float = -41.0
const BODY_CUT: float = -3.7
const BODY_TH: float = 7.8


static func wing_le(x: float) -> float:
	return -4.4 - 0.62 * maxf(absf(x) - 14.3, 0.0)


static func wing_te(x: float) -> float:
	return -41.0 + 0.2 * maxf(absf(x) - 14.3, 0.0)


static func wing_th(x: float) -> float:
	return lerpf(4.6, 0.6, clampf((absf(x) - 14.3) / 39.7, 0.0, 1.0))


## Height of the shell's top over the salt at (x, z) (the fires sit on it); 0 outside the shell.
static func shell_top(x: float, z: float) -> float:
	if absf(x) <= 14.3:
		var t: float = (BODY_LE - z) / (BODY_LE - BODY_TE)
		return BODY_TH * body(t) if z <= BODY_CUT and t <= 1.0 else 0.0
	if x < -17.2:
		return 0.0
	var le: float = wing_le(x)
	var te: float = wing_te(x)
	if z > le or z < te:
		return 0.0
	return wing_th(x) * naca((le - z) / (le - te)) + maxf(x - 40.0, 0.0) * 0.08


## One airfoil section: top points LE->TE (with a flat belly under them) at span position x.
static func _section(x: float, le: float, te: float, th: float, y0: float, prof: Callable, t0: float, n: int) -> Array:
	var top: Array = []
	var bot: Array = []
	for i: int in n + 1:
		var t: float = lerpf(t0, 1.0, float(i) / float(n))
		var z: float = le - (le - te) * t
		top.append(Vector3(x, y0 + th * float(prof.call(t)), z))
		bot.append(Vector3(x, y0, z))
	return [top, bot]


## Lofts a run of sections into skin faces (top and belly) on `st`; the interior point for the outward hints is
## each strip's mid-chord at a third of its height. `skip` (Rect2 in x/z) leaves a hole (the bay).
static func _loft(st: SurfaceTool, secs: Array, skip: Rect2 = Rect2()) -> void:
	for s: int in secs.size() - 1:
		var ta: Array = secs[s][0]
		var tb: Array = secs[s + 1][0]
		var ba: Array = secs[s][1]
		var bb: Array = secs[s + 1][1]
		for i: int in ta.size() - 1:
			var q: Array = [ta[i], ta[i + 1], tb[i + 1], tb[i]]
			var c: Vector3 = ((q[0] as Vector3) + (q[1] as Vector3) + (q[2] as Vector3) + (q[3] as Vector3)) * 0.25
			if skip.size != Vector2.ZERO and skip.has_point(Vector2(c.x, c.z)):
				continue
			var mid: Vector3 = ((ba[i] as Vector3) + (bb[i + 1] as Vector3)) * 0.5
			face(st, q, c - Vector3(mid.x, mid.y + (c.y - mid.y) * 0.3, mid.z) + Vector3(0, 0.01, 0))
		# belly faces are on the salt and never seen: left out


## Caps a section (a flat face from the top curve down to the belly) facing `out`.
static func _cap(st: SurfaceTool, sec: Array, out: Vector3) -> void:
	var top: Array = sec[0]
	var bot: Array = sec[1]
	for i: int in top.size() - 1:
		face(st, [top[i], top[i + 1], bot[i + 1], bot[i]], out)


## The Kranich on its belly: the centre body over the spawn room (the bay torn open over its forward end), the
## starboard wing still on, sweeping east and bent up at the tip, the port wing's torn stub. Skin in `skin`,
## the torn edges and the bay's liner in `torn`. Returns the shell's node.
static func kranich_shell(parent: Node3D, skin: String = "wreck", torn: String = "char") -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "KranichShell"
	parent.add_child(g)
	var st: SurfaceTool = st_new(true)
	var tst: SurfaceTool = st_new(false)
	var bay: Rect2 = Rect2(Vector2(-4.5, -12.5), Vector2(9.0, 8.8))
	# the centre body: stations every 2 m, cut at the bay
	var body_secs: Array = []
	var t0: float = (BODY_LE - BODY_CUT) / (BODY_LE - BODY_TE)
	var xs: Array = []
	var x: float = -14.3
	while x < 14.31:
		xs.append(x)
		x += 2.2
	if absf(float(xs[-1]) - 14.3) > 0.01:
		xs.append(14.3)
	for xv: float in xs:
		body_secs.append(_section(xv, BODY_LE, BODY_TE, BODY_TH * (1.0 - 0.06 * absf(xv) / 14.3), 0.0, body, t0, 16))
	_loft(st, body_secs, bay)
	# the body's side faces (above the wings they show; the port one is the tear)
	_cap(st, body_secs[-1], Vector3.RIGHT)
	_cap(tst, body_secs[0], Vector3.LEFT)
	# the front: the torn skin band between the AB wall's top (4.2) and the shell, across the bay
	for i: int in body_secs.size() - 1:
		var a: Vector3 = (body_secs[i][0] as Array)[0]
		var b: Vector3 = (body_secs[i + 1][0] as Array)[0]
		if a.y > 4.2 and b.y > 4.2:
			face(tst, [a, b, Vector3(b.x, 4.15, b.z), Vector3(a.x, 4.15, a.z)], Vector3.BACK)
	# the bay's liner: four walls from the room's roof up to the skin round the hole
	var corners: Array = [Vector2(bay.position.x, bay.position.y), Vector2(bay.end.x, bay.position.y), Vector2(bay.end.x, bay.end.y), Vector2(bay.position.x, bay.end.y)]
	for k: int in 4:
		var p: Vector2 = corners[k]
		var q: Vector2 = corners[(k + 1) % 4]
		var mid: Vector2 = (p + q) * 0.5
		var out: Vector3 = Vector3(mid.x - bay.get_center().x, 0, mid.y - bay.get_center().y)
		var segs: int = 4
		for s: int in segs:
			var u0: Vector2 = p.lerp(q, float(s) / segs)
			var u1: Vector2 = p.lerp(q, float(s + 1) / segs)
			var h0: float = maxf(shell_top(u0.x, minf(u0.y, BODY_CUT - 0.01)), 4.7)
			var h1: float = maxf(shell_top(u1.x, minf(u1.y, BODY_CUT - 0.01)), 4.7)
			face(tst, [Vector3(u0.x, 4.6, u0.y), Vector3(u1.x, 4.6, u1.y), Vector3(u1.x, h1, u1.y), Vector3(u0.x, h0, u0.y)], -out)
	# the starboard wing: 14.3 -> 54, bent up past x 40
	var stb: Array = []
	for i: int in 13:
		var wx: float = lerpf(14.3, 54.0, float(i) / 12.0)
		stb.append(_section(wx, wing_le(wx), wing_te(wx), wing_th(wx), maxf(wx - 40.0, 0.0) * 0.08, naca, 0.0, 14))
	_loft(st, stb)
	_cap(st, stb[-1], Vector3.RIGHT)
	# the port stub: 14.3 -> 17.2 west, torn at its end
	var prt: Array = []
	for i: int in 3:
		var px: float = lerpf(-14.3, -17.2, float(i) / 2.0)
		prt.append(_section(px, wing_le(px), wing_te(px), wing_th(px), 0.0, naca, 0.0, 14))
	_loft(st, prt)
	_cap(tst, prt[-1], Vector3.LEFT)
	mesh_node(g, "Skin", finish(st), skin)
	mesh_node(g, "Torn", finish(tst), torn)
	return g


## The port wing, torn off and lying on the salt west of the hull (over the WingTorn / WingTornTip colliders).
static func torn_wing(parent: Node3D, skin: String = "wreck", torn: String = "char") -> void:
	var st: SurfaceTool = st_new(true)
	var tst: SurfaceTool = st_new(false)
	var secs: Array = []
	var rows: Array = [[-18.0, -13.6, -31.0, 2.5], [-30.0, -13.8, -30.6, 2.2], [-42.0, -14.6, -29.6, 1.8], [-52.0, -16.2, -28.0, 1.25], [-62.0, -18.2, -24.4, 0.6]]
	for r: Array in rows:
		secs.append(_section(float(r[0]), float(r[1]), float(r[2]), float(r[3]), 0.0, naca, 0.0, 12))
	_loft(st, secs)
	_cap(tst, secs[0], Vector3.RIGHT)
	_cap(st, secs[-1], Vector3.LEFT)
	mesh_node(parent, "TornWingSkin", finish(st), skin)
	mesh_node(parent, "TornWingEdge", finish(tst), torn)


## Ribs and spar ends sticking out of a torn edge at span x (world), between z0 and z1, up to the local skin.
static func torn_ribs(parent: Node3D, x: float, z0: float, z1: float, dir: float, h_at: Callable, seed_v: int, key: String = "steel") -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var n: int = int(absf(z1 - z0) / 1.6)
	for i: int in n:
		var z: float = lerpf(z0, z1, (float(i) + 0.5) / float(n))
		var h: float = float(h_at.call(x, z))
		if h < 0.4:
			continue
		var reach: float = rng.randf_range(0.3, 1.6)
		# a rib stub: the profile's top and bottom flanges and a web
		Props.obox(parent, Vector3(x + dir * reach * 0.5, h * 0.5, z), Vector3(reach, h * 0.92, 0.06), key, Vector3(0, rng.randf_range(-8, 8), rng.randf_range(-6, 6)))
		Props.obox(parent, Vector3(x + dir * reach * 0.5, h - 0.05, z), Vector3(reach, 0.06, 0.18), key)
	# two spar ends
	for sz: float in [lerpf(z0, z1, 0.3), lerpf(z0, z1, 0.62)]:
		var hh: float = float(h_at.call(x, sz))
		if hh > 0.6:
			Props.obox(parent, Vector3(x + dir * 1.1, hh * 0.5, sz), Vector3(2.2, hh * 0.8, 0.22), key, Vector3(0, rng.randf_range(-5, 5), 0))
	# skin flaps peeled back
	for k: int in 4:
		var fz: float = lerpf(z0, z1, rng.randf())
		var fh: float = float(h_at.call(x, fz))
		if fh > 0.5:
			Props.obox(parent, Vector3(x + dir * 0.6, fh + 0.1, fz), Vector3(1.4, 0.03, rng.randf_range(0.8, 2.0)), "wreck", Vector3(rng.randf_range(-30, 30), 0, dir * rng.randf_range(15, 45)))


## Engine intakes on the wing's leading edge (dark mouths, a violet glow ring where a core sat).
static func intakes(parent: Node3D) -> void:
	for ix: float in [-9.0, -3.0, 3.0, 9.0]:
		var z: float = BODY_CUT - 0.6
		var y: float = maxf(shell_top(ix, z) - 1.0, 4.4)
		Props.cyl(parent, Vector3(ix, y, z - 0.6), 0.75, 1.6, "black_paint", Vector3(90, 0, 0))
		Props.cyl(parent, Vector3(ix, y, z + 0.18), 0.85, 0.16, "steel", Vector3(90, 0, 0))


## Debris on the black salt: skin panels, a bent spar, an engine cowl ring, casings, scattered small bits.
static func debris_field(parent: Node3D, centre: Vector3, rx: float, rz: float, count: int, seed_v: int, keep_out: Array) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 6:
		tries += 1
		var p: Vector3 = centre + Vector3(rng.randf_range(-rx, rx), 0, rng.randf_range(-rz, rz))
		var bad: bool = false
		for r: Rect2 in keep_out:
			if r.has_point(Vector2(p.x, p.z)):
				bad = true
				break
		if bad:
			continue
		placed += 1
		var kind: int = rng.randi_range(0, 5)
		var yaw: float = rng.randf_range(0, 360)
		match kind:
			0, 1:
				Props.obox(parent, p + Vector3(0, 0.06, 0), Vector3(rng.randf_range(0.8, 2.6), 0.04, rng.randf_range(0.5, 1.6)), "wreck", Vector3(rng.randf_range(-12, 12), yaw, rng.randf_range(-14, 14)))
			2:
				Props.obox(parent, p + Vector3(0, 0.15, 0), Vector3(rng.randf_range(2.0, 4.5), 0.18, 0.12), "steel", Vector3(0, yaw, rng.randf_range(-8, 8)))
			3:
				Props.cyl(parent, p + Vector3(0, 0.5, 0), 0.6, 0.5, "char", Vector3(rng.randf_range(60, 90), yaw, 0))
			4:
				Props.obox(parent, p + Vector3(0, 0.08, 0), Vector3(0.35, 0.16, 0.35), "char", Vector3(0, yaw, 0))
			_:
				Props.obox(parent, p + Vector3(0, 0.02, 0), Vector3(rng.randf_range(0.3, 0.9), 0.03, rng.randf_range(0.2, 0.6)), "steel", Vector3(0, yaw, rng.randf_range(-20, 20)))


## A ground card (a thin flat quad grid, no collider) a few cm over the salt.
static func ground_card(parent: Node3D, n: String, lo: Vector2, hi: Vector2, y: float, mat: Material, cells: int = 8) -> MeshInstance3D:
	var st: SurfaceTool = st_new(false)
	for i: int in cells:
		for j: int in cells:
			var x0: float = lerpf(lo.x, hi.x, float(i) / cells)
			var x1: float = lerpf(lo.x, hi.x, float(i + 1) / cells)
			var z0: float = lerpf(lo.y, hi.y, float(j) / cells)
			var z1: float = lerpf(lo.y, hi.y, float(j + 1) / cells)
			face(st, [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)], Vector3.UP)
	return mesh_node(parent, n, finish(st), mat, false)


# ================================================================== the far world

## A ring of ridges round `centre`: a jagged crest (seeded), radius r0..r1, heights h0..h1, built as one mesh
## (the crest strip plus a back skirt down below the salt so the gaps never show sky under the land).
static func ridge_ring(parent: Node3D, n: String, centre: Vector3, r: float, depth: float, h0: float, h1: float, seed_v: int, mat: Material, segs: int = 160) -> void:
	var st: SurfaceTool = st_new(true)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.6
	noise.fractal_octaves = 4
	var crest: Array = []
	for i: int in segs + 1:
		var a: float = TAU * float(i % segs) / float(segs)
		var u: float = float(i % segs) / float(segs)
		var nv: float = noise.get_noise_2d(cos(a) * 1.3, sin(a) * 1.3) * 0.5 + 0.5
		var h: float = lerpf(h0, h1, pow(nv, 1.6))
		crest.append([a, h, u])
	for i: int in segs:
		var c0: Array = crest[i]
		var c1: Array = crest[i + 1]
		var d0: Vector3 = Vector3(sin(float(c0[0])), 0, cos(float(c0[0])))
		var d1: Vector3 = Vector3(sin(float(c1[0])), 0, cos(float(c1[0])))
		var f0: Vector3 = centre + d0 * r
		var f1: Vector3 = centre + d1 * r
		var t0: Vector3 = centre + d0 * (r + depth * 0.45) + Vector3(0, float(c0[1]), 0)
		var t1: Vector3 = centre + d1 * (r + depth * 0.45) + Vector3(0, float(c1[1]), 0)
		var b0: Vector3 = centre + d0 * (r + depth) + Vector3(0, float(c0[1]) * 0.55, 0)
		var b1: Vector3 = centre + d1 * (r + depth) + Vector3(0, float(c1[1]) * 0.55, 0)
		var fy: Vector3 = Vector3(0, -2.0, 0)
		# the front slope (toward the lake), then the back slope
		face(st, [f0 + fy, f1 + fy, t1, t0], -(d0 + d1))
		face(st, [t0, t1, b1, b0], Vector3.UP)
	mesh_node(parent, n, finish(st), mat, false)


# ================================================================== the radar tower

## A four-legged lattice tower from a square base (half `b`) to a square top (half `t`), `levels` bays, X-braced
## on every face, a platform with a railing on top, a ladder up the south face. Local to `base` (world).
static func lattice_tower(parent: Node3D, base: Vector3, b: float, t: float, h: float, levels: int, key: String = "iron") -> void:
	var legs: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for k: int in 4:
		var l: Vector2 = legs[k]
		Props.strut(parent, base + Vector3(l.x * b, 0, l.y * b), base + Vector3(l.x * t, h, l.y * t), 0.16, key)
		Props.block(parent, base + Vector3(l.x * b - 0.3, -0.05, l.y * b - 0.3), base + Vector3(l.x * b + 0.3, 0.25, l.y * b + 0.3), "concrete")
	for lv: int in levels:
		var y0: float = h * float(lv) / levels
		var y1: float = h * float(lv + 1) / levels
		var s0: float = lerpf(b, t, float(lv) / levels)
		var s1: float = lerpf(b, t, float(lv + 1) / levels)
		for k: int in 4:
			var p: Vector2 = legs[k]
			var q: Vector2 = legs[(k + 1) % 4]
			var a0: Vector3 = base + Vector3(p.x * s0, y0, p.y * s0)
			var b0: Vector3 = base + Vector3(q.x * s0, y0, q.y * s0)
			var a1: Vector3 = base + Vector3(p.x * s1, y1, p.y * s1)
			var b1: Vector3 = base + Vector3(q.x * s1, y1, q.y * s1)
			Props.strut(parent, a1, b1, 0.09, key)
			Props.strut(parent, a0, b1, 0.06, key)
			Props.strut(parent, b0, a1, 0.06, key)
	# the platform and its railing
	var top: Vector3 = base + Vector3(0, h, 0)
	Props.block(parent, top + Vector3(-t - 0.6, -0.08, -t - 0.6), top + Vector3(t + 0.6, 0.04, t + 0.6), "steel_grate")
	for k: int in 4:
		var p2: Vector2 = legs[k]
		var q2: Vector2 = legs[(k + 1) % 4]
		Props.railing(parent, top + Vector3(p2.x * (t + 0.6), 0, p2.y * (t + 0.6)), top + Vector3(q2.x * (t + 0.6), 0, q2.y * (t + 0.6)), 1.0, key, 1.2)
	# the ladder up the south face's middle
	var lad0: Vector3 = base + Vector3(0, 0, -b + 0.05)
	var lad1: Vector3 = base + Vector3(0, h, -t + 0.05)
	for sx: float in [-0.22, 0.22]:
		Props.strut(parent, lad0 + Vector3(sx, 0, 0), lad1 + Vector3(sx, 0, 0), 0.04, key, true)
	var rungs: int = int(h / 0.35)
	for i: int in rungs:
		var p3: Vector3 = lad0.lerp(lad1, float(i) / rungs)
		Props.strut(parent, p3 + Vector3(-0.22, 0, 0), p3 + Vector3(0.22, 0, 0), 0.025, key, true)


## A parabolic dish (radius r, focal f) on a yoke, facing `aim` (world direction), centred at `c`: front skin and
## a back skin in `skin`, radial ribs and a rim ring in `frame`, the feed horn on three struts.
static func dish(parent: Node3D, c: Vector3, r: float, f: float, aim: Vector3, skin: String = "grey_paint", frame: String = "iron") -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "Dish"
	parent.add_child(g)
	g.transform = Transform3D(Basis.looking_at(-aim.normalized(), Vector3.UP), c)
	# local: the dish opens toward +Z (looking_at points -Z at -aim, so +Z is aim)
	var st: SurfaceTool = st_new(true)
	var rings: int = 6
	var segs: int = 24
	var pts: Array = []
	for i: int in rings + 1:
		var rr: float = r * float(i) / rings
		var row: Array = []
		for j: int in segs:
			var a: float = TAU * float(j) / segs
			row.append(Vector3(cos(a) * rr, sin(a) * rr, rr * rr / (4.0 * f)))
		pts.append(row)
	for i: int in rings:
		for j: int in segs:
			var a0: Vector3 = pts[i][j]
			var a1: Vector3 = pts[i][(j + 1) % segs]
			var b0: Vector3 = pts[i + 1][j]
			var b1: Vector3 = pts[i + 1][(j + 1) % segs]
			face(st, [a0, a1, b1, b0], Vector3(0, 0, 1))                      # the reflector (front)
			var o: Vector3 = Vector3(0, 0, -0.06)
			face(st, [a0 + o, a1 + o, b1 + o, b0 + o], Vector3(0, 0, -1))   # the back skin
	mesh_node(g, "Reflector", finish(st), skin)
	var rim_z: float = r * r / (4.0 * f)
	for j: int in segs:
		var p: Vector3 = pts[rings][j]
		var q: Vector3 = pts[rings][(j + 1) % segs]
		Props.strut(g, p, q, 0.08, frame)
		if j % 3 == 0:
			Props.strut(g, Vector3(0, 0, -0.1), p - Vector3(0, 0, 0.08), 0.07, frame)
	# the feed horn at the focus on three struts
	Props.cyl(g, Vector3(0, 0, f), 0.16, 0.5, frame, Vector3(90, 0, 0))
	for j: int in 3:
		var a2: float = TAU * float(j) / 3.0 + 0.5
		Props.strut(g, Vector3(cos(a2) * r * 0.92, sin(a2) * r * 0.92, rim_z), Vector3(0, 0, f), 0.05, frame, true)
	# the hub and the yoke
	Props.cyl(g, Vector3(0, 0, -0.35), 0.45, 0.6, frame, Vector3(90, 0, 0))
	return g


# ================================================================== vehicles

## A generic 1940s 2½-ton cargo truck (no maker, no unit marks: the star, "ARMY" and a number), local +Z forward,
## its footprint centred on `pos`. Body olive; the cargo bed under a canvas cover on bows (lofted).
static func truck(parent: Node3D, pos: Vector3, yaw: float, number: String, covered: bool = true) -> Node3D:
	var g: Node3D = Props.group(parent, "Truck", pos, yaw)
	var od: String = "olive_drab"
	# chassis rails and bumper
	for sx: float in [-0.45, 0.45]:
		Props.block(g, Vector3(sx - 0.08, 0.62, -3.3), Vector3(sx + 0.08, 0.82, 3.3), "black_paint")
	Props.block(g, Vector3(-1.1, 0.55, 3.25), Vector3(1.1, 0.8, 3.45), od)
	# wheels: single front axle, tandem dual rear
	for wz: float in [2.25, -1.25, -2.55]:
		for sx2: float in [-0.95, 0.95]:
			var w: float = 0.32 if wz > 0.0 else 0.5
			Props.cyl(g, Vector3(sx2, 0.52, wz), 0.52, w, "rubber", Vector3(0, 0, 90))
			Props.cyl(g, Vector3(sx2 + signf(sx2) * (w * 0.5 + 0.01), 0.52, wz), 0.22, 0.03, od, Vector3(0, 0, 90))
	# hood, grille, fenders, headlamps
	Props.block(g, Vector3(-0.62, 0.85, 1.75), Vector3(0.62, 1.55, 3.2), od)
	Props.obox(g, Vector3(0, 1.62, 2.45), Vector3(1.0, 0.16, 1.45), od, Vector3(0, 0, 0))
	Props.block(g, Vector3(-0.66, 0.75, 3.2), Vector3(0.66, 1.6, 3.28), "black_paint")
	for i: int in 9:
		var gx: float = -0.56 + 0.14 * float(i)
		Props.block(g, Vector3(gx - 0.02, 0.8, 3.27), Vector3(gx + 0.02, 1.55, 3.31), od)
	for sx3: float in [-1.0, 1.0]:
		Props.obox(g, Vector3(sx3 * 0.92, 1.12, 2.35), Vector3(0.42, 0.06, 1.5), od, Vector3(0, 0, -sx3 * 8.0))
		Props.obox(g, Vector3(sx3 * 0.92, 0.95, 3.05), Vector3(0.42, 0.06, 0.55), od, Vector3(35, 0, 0))
		Props.cyl(g, Vector3(sx3 * 0.82, 1.32, 3.2), 0.13, 0.12, "chrome_worn", Vector3(90, 0, 0))
	# the cab: an open cab with a canvas top, the windscreen frame folded up
	Props.block(g, Vector3(-1.05, 0.85, 0.35), Vector3(1.05, 1.75, 1.75), od)
	Props.block(g, Vector3(-1.05, 1.75, 1.66), Vector3(1.05, 2.45, 1.74), "glass")
	for sx4: float in [-1.02, 1.02]:
		Props.block(g, Vector3(sx4 - 0.03, 1.75, 1.66), Vector3(sx4 + 0.03, 2.45, 1.74), od)
	Props.block(g, Vector3(-1.06, 2.42, 0.3), Vector3(1.06, 2.5, 1.74), "canvas")
	Props.block(g, Vector3(-1.0, 1.0, 0.3), Vector3(1.0, 1.9, 0.42), od)
	Props.cyl(g, Vector3(0.45, 1.85, 1.35), 0.2, 0.04, "black_paint", Vector3(55, 0, 0))   # the wheel
	# the cargo bed: floor, slatted sides, the tailgate
	Props.block(g, Vector3(-1.12, 0.85, -3.4), Vector3(1.12, 0.98, 0.2), "planks")
	for sx5: float in [-1.12, 1.12]:
		Props.block(g, Vector3(sx5 - 0.04, 0.98, -3.4), Vector3(sx5 + 0.04, 1.65, 0.2), od)
	Props.block(g, Vector3(-1.12, 0.98, -3.44), Vector3(1.12, 1.65, -3.36), od)
	if covered:
		var st: SurfaceTool = st_new(true)
		var prev: Array = []
		for k: int in 7:
			var bz: float = lerpf(-3.4, 0.2, float(k) / 6.0)
			var row: Array = []
			for a: int in 9:
				var ang: float = PI * float(a) / 8.0
				row.append(Vector3(cos(ang) * 1.14, 1.65 + sin(ang) * 1.05, bz))
			if k > 0:
				for a2: int in 8:
					var q: Array = [prev[a2], prev[a2 + 1], row[a2 + 1], row[a2]]
					var c: Vector3 = ((q[0] as Vector3) + (q[2] as Vector3)) * 0.5
					face(st, q, c - Vector3(0, 1.65, c.z))
			prev = row
		mesh_node(g, "Canvas", finish(st), "canvas")
	# markings: the star on the hood and the doors, ARMY and the number on the hood's side
	star(g, Vector3(0, 1.71, 2.45), 0.38, Vector3(-90, 0, 0))
	for sx6: float in [-1.06, 1.06]:
		star(g, Vector3(sx6 * 1.002, 1.3, 1.05), 0.3, Vector3(0, 90.0 * signf(sx6), 0))
		var l: Label3D = Props.stencil(g, Vector3(sx6 * 1.0 + signf(sx6) * 0.0, 1.22, 2.45), -90.0 * signf(sx6), "ARMY  " + number, 22, Color(0.85, 0.85, 0.8, 0.85))
		l.position.z = -0.03
	return g


## A white five-pointed star (the period's generic vehicle star), a flat mesh facing local +Y before `rot`.
static func star(parent: Node3D, c: Vector3, r: float, rot: Vector3) -> void:
	var st: SurfaceTool = st_new(false)
	var pts: Array = []
	for i: int in 10:
		var a: float = PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = r if i % 2 == 0 else r * 0.4
		pts.append(Vector3(cos(a) * rr, 0, -sin(a) * rr))
	for i2: int in 10:
		face(st, [Vector3.ZERO, pts[i2], pts[(i2 + 1) % 10]], Vector3.UP)
	var mi: MeshInstance3D = mesh_node(parent, "Star", finish(st), "enamel_white", false)
	mi.position = c
	mi.rotation_degrees = rot


## A jeep-sized utility car (generic), local +Z forward.
static func utility_car(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = Props.group(parent, "UtilityCar", pos, yaw)
	for wz: float in [1.05, -1.05]:
		for sx: float in [-0.68, 0.68]:
			Props.cyl(g, Vector3(sx, 0.38, wz), 0.38, 0.24, "rubber", Vector3(0, 0, 90))
	Props.block(g, Vector3(-0.72, 0.45, -1.6), Vector3(0.72, 0.95, 1.6), "olive_drab")
	Props.block(g, Vector3(-0.6, 0.95, 0.75), Vector3(0.6, 1.08, 1.6), "olive_drab")
	Props.block(g, Vector3(-0.7, 0.95, 0.58), Vector3(0.7, 1.45, 0.64), "glass")
	Props.block(g, Vector3(-0.6, 0.95, -0.6), Vector3(0.6, 1.25, -0.2), "canvas")
	Props.cyl(g, Vector3(0, 0.7, -1.72), 0.36, 0.22, "rubber", Vector3(90, 0, 0))
	star(g, Vector3(0, 1.085, 1.18), 0.26, Vector3.ZERO)


# ================================================================== hangar

## A king-post truss of sawn timber spanning x0..x1 at depth z, its tie beam at y (local world), rise `rise`.
static func truss(parent: Node3D, x0: float, x1: float, z: float, y: float, rise: float, key: String = "beam") -> void:
	var mid: float = (x0 + x1) * 0.5
	var apex: Vector3 = Vector3(mid, y + rise, z)
	Props.strut(parent, Vector3(x0, y, z), Vector3(x1, y, z), 0.24, key)
	Props.strut(parent, Vector3(x0, y, z), apex, 0.26, key)
	Props.strut(parent, Vector3(x1, y, z), apex, 0.26, key)
	Props.strut(parent, Vector3(mid, y, z), apex, 0.18, key)
	for f: float in [0.25, 0.75]:
		var bx: float = lerpf(x0, x1, f)
		var top: Vector3 = Vector3(bx, y + rise * (1.0 - absf(bx - mid) / (mid - x0)), z)
		Props.strut(parent, Vector3(bx, y, z), top, 0.12, key)
		Props.strut(parent, Vector3(mid, y, z), top, 0.12, key)
	# the iron straps at the joints
	Props.block(parent, Vector3(mid - 0.2, y - 0.16, z - 0.13), Vector3(mid + 0.2, y + 0.16, z + 0.13), "iron")


## A big sliding door leaf (planks in a frame with Z-bracing) hung from a rail, local: the leaf's centre bottom
## at `pos`, width along X.
static func sliding_leaf(parent: Node3D, pos: Vector3, w: float, h: float, yaw: float = 0.0) -> void:
	var g: Node3D = Props.group(parent, "SlidingDoor", pos, yaw)
	Props.block(g, Vector3(-w * 0.5, 0.05, -0.06), Vector3(w * 0.5, h, 0.06), "planks")
	for y: float in [0.15, h * 0.5, h - 0.15]:
		Props.block(g, Vector3(-w * 0.5, y - 0.1, -0.1), Vector3(w * 0.5, y + 0.1, -0.06), "board_wood")
	Props.strut(g, Vector3(-w * 0.5 + 0.1, 0.2, -0.09), Vector3(w * 0.5 - 0.1, h * 0.5 - 0.1, -0.09), 0.16, "board_wood")
	Props.strut(g, Vector3(-w * 0.5 + 0.1, h * 0.5 + 0.1, -0.09), Vector3(w * 0.5 - 0.1, h - 0.2, -0.09), 0.16, "board_wood")
	for sx: float in [-w * 0.35, w * 0.35]:
		Props.cyl(g, Vector3(sx, h + 0.12, 0), 0.1, 0.06, "iron", Vector3(90, 0, 0))


## A four-engine bomber stripped for parts, on jacks, nose north: the fuselage (a round body tapering to the
## tail), the glazed nose, the wing centre section with two engines gone (bare mounts), the tail fin, the jacks,
## the parts on the floor; sized to fill the hangar's Bomber collider (38..52 × 72..92, 3 m).
static func bomber(parent: Node3D, c: Vector3) -> void:
	var g: Node3D = Props.group(parent, "BomberDress", c)
	var od: String = "olive_steel"
	# fuselage along Z: centre sections, tapering aft
	var rows: Array = [[8.6, 1.25], [6.0, 1.45], [2.0, 1.5], [-2.0, 1.5], [-5.0, 1.35], [-7.5, 1.05], [-9.5, 0.7]]
	for i: int in rows.size() - 1:
		var z0: float = float(rows[i][0])
		var z1: float = float(rows[i + 1][0])
		var r: float = (float(rows[i][1]) + float(rows[i + 1][1])) * 0.5
		Props.cyl(g, Vector3(0, 2.0, (z0 + z1) * 0.5), r, absf(z1 - z0) + 0.05, od, Vector3(90, 0, 0))
	# the glazed nose and the cockpit glazing
	Props.ball(g, Vector3(0, 2.0, 9.2), Vector3(2.4, 2.3, 2.0), "glass")
	Props.obox(g, Vector3(0, 3.35, 6.3), Vector3(1.6, 0.5, 1.6), "glass", Vector3(-12, 0, 0))
	# a panel off the side: the bomb bay open, ribs showing
	Props.block(g, Vector3(-1.3, 0.75, -2.5), Vector3(1.3, 0.85, 3.5), "black_paint")
	for rz: float in [-2.0, -0.5, 1.0, 2.5]:
		Props.obox(g, Vector3(1.48, 2.0, rz), Vector3(0.06, 2.6, 0.12), "steel")
	Props.block(g, Vector3(1.46, 1.2, -2.4), Vector3(1.52, 2.6, 3.4), "black_paint")
	# the tail: fin and stabilisers
	Props.obox(g, Vector3(0, 3.6, -9.0), Vector3(0.2, 3.2, 2.4), od, Vector3(-10, 0, 0))
	Props.obox(g, Vector3(0, 2.1, -9.3), Vector3(6.5, 0.14, 1.6), od)
	# the wing centre section (the long wings are off; stubs to the hangar's wing boxes 26..64 at 2.2-2.8)
	Props.block(g, Vector3(-19.0, 2.25, -2.0), Vector3(19.0, 2.75, 2.0), od)
	# engine nacelles: two bare mounts, two with the engines still on (the other parts are in Dee's cage)
	for nx: float in [-11.0, -5.5, 5.5, 11.0]:
		var bare: bool = absf(nx) > 8.0
		if bare:
			# the outer engines are gone (outside the collider: nothing hangs below the wing's 2.25 m)
			Props.block(g, Vector3(nx - 0.7, 2.75, -1.6), Vector3(nx + 0.7, 3.05, 1.2), od)
			for k: int in 4:
				var a: float = TAU * float(k) / 4.0 + 0.78
				Props.strut(g, Vector3(nx, 3.3, 1.2), Vector3(nx + cos(a) * 0.5, 3.3 + absf(sin(a)) * 0.5, 2.3), 0.06, "steel")
		else:
			Props.cyl(g, Vector3(nx, 2.1, -1.0), 0.8, 2.6, od, Vector3(90, 0, 0))
			Props.cyl(g, Vector3(nx, 2.1, 0.9), 0.82, 1.3, "black_paint", Vector3(90, 0, 0))
			Props.cyl(g, Vector3(nx, 2.1, 1.7), 0.18, 0.4, "steel", Vector3(90, 0, 0))
			for k2: int in 3:
				Props.obox(g, Vector3(nx, 2.1, 1.9), Vector3(0.22, 3.2, 0.06), "black_paint", Vector3(0, 0, 60.0 * k2 + 15.0))
	# the jacks under the wings and the nose, and blocks under the main wheels' empty wells
	for jp: Vector3 in [Vector3(-6, 0, -0.5), Vector3(6, 0, -0.5), Vector3(0, 0, 7.0), Vector3(0, 0, -7.0)]:
		Props.block(g, jp + Vector3(-0.35, 0, -0.35), jp + Vector3(0.35, 0.12, 0.35), "crane_yellow")
		Props.cyl(g, jp + Vector3(0, 0.7, 0), 0.09, 1.3, "crane_yellow")
		Props.block(g, jp + Vector3(-0.2, 1.3, -0.2), jp + Vector3(0.2, 1.42, 0.2), "steel")
	# the star on the fuselage side (painted over half way: olive on olive), a number
	star(g, Vector3(1.53, 2.3, -4.6), 0.55, Vector3(0, 0, -90))
	star(g, Vector3(-1.53, 2.3, -4.6), 0.55, Vector3(0, 0, 90))
	# parts on the floor inside the footprint: an engine on a stand, a propeller blade, crates
	Props.block(g, Vector3(-6.6, 0, -9.6), Vector3(-4.6, 0.5, -7.4), "crane_yellow")
	Props.cyl(g, Vector3(-5.6, 1.1, -8.5), 0.7, 1.2, "black_paint", Vector3(90, 0, 0))
	Props.obox(g, Vector3(5.2, 0.12, -8.2), Vector3(3.6, 0.08, 0.36), "black_paint", Vector3(0, 25, 0))
	Props.crate(g, Vector3(5.6, 0, 6.6), 1.0, 12.0, "PARTS")
	Props.crate(g, Vector3(-5.8, 0, 7.2), 0.9, -20.0, "")


## Hale's glass office (22..36 × 92..100, 3 m): a timber frame with mullions and glass, a roof with a lip, the desk,
## the lamp's shade, a filing cabinet, a map on the back wall, the hatch in its east face (the cradle).
static func glass_office(parent: Node3D, lo: Vector3, hi: Vector3) -> void:
	var h: float = hi.y - lo.y
	Props.block(parent, Vector3(lo.x - 0.1, hi.y, lo.z - 0.1), Vector3(hi.x + 0.1, hi.y + 0.18, hi.z + 0.1), "board_wood")
	Props.block(parent, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y + 0.9, lo.z + 0.12), "planks")       # the knee wall (south)
	Props.block(parent, Vector3(hi.x - 0.12, lo.y, lo.z), Vector3(hi.x, lo.y + 0.9, hi.z), "planks")       # (east)
	Props.block(parent, Vector3(lo.x, lo.y + 0.9, lo.z + 0.02), Vector3(hi.x, hi.y, lo.z + 0.08), "glass", false)
	Props.block(parent, Vector3(hi.x - 0.08, lo.y + 0.9, lo.z), Vector3(hi.x - 0.02, hi.y, hi.z), "glass", false)
	Props.block(parent, Vector3(lo.x, lo.y + 0.9, lo.z), Vector3(lo.x + 0.12, hi.y, hi.z), "planks")
	var n: int = int((hi.x - lo.x) / 1.4)
	for i: int in n + 1:
		var x: float = lerpf(lo.x, hi.x, float(i) / n)
		Props.block(parent, Vector3(x - 0.05, lo.y, lo.z - 0.02), Vector3(x + 0.05, hi.y, lo.z + 0.14), "board_wood")
	var m: int = int((hi.z - lo.z) / 1.4)
	for j: int in m + 1:
		var z: float = lerpf(lo.z, hi.z, float(j) / m)
		Props.block(parent, Vector3(hi.x - 0.14, lo.y, z - 0.05), Vector3(hi.x + 0.02, hi.y, z + 0.05), "board_wood")
	for y: float in [lo.y + 0.9, lo.y + 2.2]:
		Props.block(parent, Vector3(lo.x, y - 0.04, lo.z - 0.03), Vector3(hi.x, y + 0.04, lo.z + 0.15), "board_wood")
		Props.block(parent, Vector3(hi.x - 0.15, y - 0.04, lo.z), Vector3(hi.x + 0.03, y + 0.04, hi.z), "board_wood")
	# inside: the desk with the lamp, papers, a chair, the filing cabinet, the map, the filter unit's box
	var dc: Vector3 = Vector3(lo.x + 7.0, lo.y, lo.z + 4.0)
	Props.table_visual(parent, dc + Vector3(0, 0, 0), 2.0, 0.9, 0.78)
	Props.cone(parent, dc + Vector3(0.5, 1.15, 0.1), 0.18, 0.22, "enamel_green")
	Props.cyl(parent, dc + Vector3(0.5, 0.95, 0.1), 0.02, 0.35, "brass")
	Props.block(parent, dc + Vector3(-0.6, 0.78, -0.2), dc + Vector3(-0.1, 0.8, 0.2), "paper")
	Props.chair(parent, dc + Vector3(0, 0, 0.9), 180.0)
	Props.block(parent, Vector3(lo.x + 0.2, lo.y, hi.z - 0.7), Vector3(lo.x + 0.9, lo.y + 1.35, hi.z - 0.15), "grey_paint")
	for d: float in [0.3, 0.7, 1.1]:
		Props.block(parent, Vector3(lo.x + 0.9, lo.y + d - 0.12, hi.z - 0.6), Vector3(lo.x + 0.92, lo.y + d + 0.12, hi.z - 0.25), "chrome_worn")
	Props.block(parent, Vector3(lo.x + 3.0, lo.y + 1.0, hi.z - 0.12), Vector3(lo.x + 6.0, lo.y + 2.4, hi.z - 0.1), "paper_old")
	Props.block(parent, Vector3(lo.x + 10.0, lo.y, hi.z - 1.0), Vector3(lo.x + 11.6, lo.y + 1.8, hi.z - 0.2), "machine_grey")
	Props.grille(parent, Vector3(lo.x + 10.05, lo.y + 1.0, hi.z - 1.02), Vector3(lo.x + 11.55, lo.y + 1.0, hi.z - 1.02), 0.6, 0.12, "iron")


## Dee's supply cage (the NavBlock_Cage 62..70 × 92..100, 2.4 m): posts, wire mesh panels, the counter with its
## hatch (the radio stands on it), shelves of supplies inside, the cot, the honey jars, sandbags at the door.
## The bank window (the Range Finance Office, bank.json: 62..66 × 90.55..92) stays clear on its south side.
static func supply_cage(parent: Node3D, lo: Vector3, hi: Vector3) -> void:
	var h: float = hi.y - lo.y
	for p: Vector3 in [Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), Vector3(lo.x + 4.0, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, lo.z + 4.0)]:
		Props.block(parent, p + Vector3(-0.06, 0, -0.06), p + Vector3(0.06, h + 0.2, 0.06), "steel")
	Props.grille(parent, Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), h, 0.12, "iron")
	Props.grille(parent, Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), h, 0.12, "iron")
	Props.block(parent, Vector3(lo.x, h, lo.z), Vector3(hi.x, h + 0.06, hi.z), "steel_grate")
	# the counter on the west face (the radio's at x 61.6, z 96)
	Props.block(parent, Vector3(lo.x - 0.5, 0, lo.z + 0.9), Vector3(lo.x + 0.05, 1.05, lo.z + 3.2), "planks")
	Props.block(parent, Vector3(lo.x - 0.55, 1.05, lo.z + 0.85), Vector3(lo.x + 0.1, 1.1, lo.z + 3.25), "board_wood")
	# shelves along the back (north and east) walls, stocked
	Props.shelves(parent, Vector3(hi.x - 0.35, 0, lo.z + 4.5), -90.0, 3.0, 2.0, 0.5, 4, 41)
	Props.shelves(parent, Vector3(lo.x + 3.5, 0, hi.z - 0.35), 180.0, 3.0, 2.0, 0.5, 4, 43)
	for k: int in 4:
		Props.crate(parent, Vector3(lo.x + 1.2 + 0.9 * float(k % 2), 0.82 * float(k / 2), lo.z + 1.2), 0.8, 7.0 * float(k), "RATIONS" if k == 0 else "")
	# the cot, the rifle rack, the honey
	Props.bed(parent, Vector3(lo.x + 4.4, 0, hi.z - 2.4), Vector3(hi.x - 0.6, 0.45, hi.z - 1.6), "cloth_green")
	for j: int in 3:
		Props.cyl(parent, Vector3(lo.x - 0.3, 1.16, lo.z + 1.4 + 0.18 * float(j)), 0.06, 0.12, "bottle_amber")
	Props.sandbags(parent, Vector3(lo.x - 0.9, 0, lo.z + 5.4), Vector3(lo.x - 0.9, 0, hi.z - 0.3), 2)


## The diesel generator set inside its shed: the skid, the engine block with its cylinder head and rocker
## covers, the radiator with its fan guard, the flywheel, the alternator, the exhaust up through the roof, the
## day tank, the switchboard on the wall. Local to the shed's floor centre `c`, long axis X.
static func generator_set(parent: Node3D, c: Vector3) -> void:
	var g: Node3D = Props.group(parent, "Generator", c)
	Props.block(g, Vector3(-3.0, 0, -0.8), Vector3(3.0, 0.25, 0.8), "black_paint")
	Props.block(g, Vector3(-1.6, 0.25, -0.6), Vector3(0.9, 1.45, 0.6), "machine_green")
	Props.block(g, Vector3(-1.5, 1.45, -0.45), Vector3(0.8, 1.75, 0.45), "machine_green")
	for k: int in 4:
		Props.block(g, Vector3(-1.35 + 0.55 * float(k), 1.75, -0.3), Vector3(-0.95 + 0.55 * float(k), 1.9, 0.3), "steel")
	Props.block(g, Vector3(-2.8, 0.25, -0.75), Vector3(-1.9, 1.85, 0.75), "black_paint")       # the radiator
	Props.grille(g, Vector3(-2.82, 0.4, -0.7), Vector3(-2.82, 0.4, 0.7), 1.3, 0.08, "iron")
	Props.cyl(g, Vector3(1.15, 0.85, 0), 0.62, 0.22, "steel", Vector3(0, 0, 90))            # the flywheel
	Props.cyl(g, Vector3(2.1, 0.85, 0), 0.5, 1.5, "copper", Vector3(0, 0, 90))              # the alternator
	Props.cyl(g, Vector3(-0.6, 2.6, 0.35), 0.11, 1.8, "rust")                              # the exhaust stack
	Props.cyl(g, Vector3(-0.6, 3.55, 0.35), 0.16, 0.3, "rust")
	Props.cyl(g, Vector3(0.3, 2.3, -0.5), 0.35, 1.4, "rust", Vector3(0, 0, 90))             # the day tank
	Props.pipe(g, Vector3(0.3, 2.0, -0.5), Vector3(0.0, 1.4, -0.4), 0.03, "copper")
	Props.stencil(g, Vector3(0.0, 1.0, 0.62), 0.0, "DIESEL  ·  30 KW  ·  RANGE POWER", 18)


## A horizontal fuel tank on two saddles (local X long), with a ladder, a filler and a hose reel.
static func fuel_tank(parent: Node3D, c: Vector3, length: float, r: float) -> void:
	var g: Node3D = Props.group(parent, "FuelTank", c)
	Props.cyl(g, Vector3(0, 0.6 + r, 0), r, length, "olive_steel", Vector3(0, 0, 90))
	for sx: float in [-length * 0.32, length * 0.32]:
		Props.block(g, Vector3(sx - 0.25, 0, -r * 0.9), Vector3(sx + 0.25, 0.6 + r * 0.6, r * 0.9), "concrete")
	Props.cyl(g, Vector3(length * 0.2, 0.6 + 2.0 * r + 0.1, 0), 0.2, 0.25, "steel")
	Props.cyl(g, Vector3(-length * 0.5 - 0.3, 0.7, 0.6), 0.35, 0.3, "red_paint", Vector3(0, 0, 90))
	Props.stencil(g, Vector3(0, 0.6 + r, -r - 0.01), 0.0, "GASOLINE  ·  NO SMOKING", 30, Color(0.9, 0.85, 0.7, 0.85))


## A jerrycan (local footprint centre).
static func jerrycan(parent: Node3D, p: Vector3, yaw: float) -> void:
	Props.obox(parent, p + Vector3(0, 0.235, 0), Vector3(0.165, 0.47, 0.345), "olive_drab", Vector3(0, yaw, 0))
	Props.obox(parent, p + Vector3(0, 0.5, 0), Vector3(0.05, 0.05, 0.2), "olive_drab", Vector3(0, yaw, 0))


# ================================================================== the silo

## The LANTERN rocket (a kept group so `fx: launch` lifts it), local to its base: the tail section with the
## engine bell, the fins, the body in two-tone panels, the ogive nose, the two-ring disc, the stencil.
static func lantern_rocket(rk: Node3D) -> void:
	Props.cone(rk, Vector3(0, 0.6, 0), 1.25, 1.2, "black_paint")                        # the engine bell
	Props.cyl(rk, Vector3(0, 2.6, 0), 1.9, 2.8, "steel")                                # the tail section
	Props.cone(rk, Vector3(0, 4.6, 0), 2.4, 1.2, "steel", Vector3(180, 0, 0))           # the boat-tail flare
	Props.cyl(rk, Vector3(0, 11.2, 0), 2.4, 12.0, "steel")                              # the body
	for y: float in [6.0, 9.0, 12.0, 15.0]:
		Props.cyl(rk, Vector3(0, y, 0), 2.43, 0.06, "black_paint")                      # the panel seams
	Props.cyl(rk, Vector3(0, 17.8, 0), 2.38, 1.2, "black_paint")                        # the instrument ring
	Props.cone(rk, Vector3(0, 20.9, 0), 2.38, 5.0, "steel")                             # the ogive (frustum)
	Props.cone(rk, Vector3(0, 24.4, 0), 0.75, 2.2, "steel")
	Props.ball(rk, Vector3(0, 25.5, 0), Vector3(0.3, 0.5, 0.3), "steel")
	for fa: float in [0.0, 90.0, 180.0, 270.0]:
		var d: Vector3 = Vector3(cos(deg_to_rad(fa)), 0, sin(deg_to_rad(fa)))
		Props.prism(rk, d * 2.9 + Vector3(0, 2.7, 0), Vector3(1.6, 4.2, 0.22), "black_paint", Vector3(0, -fa + 90.0, 0))
	# the two-ring disc on the west side (red field, white rings)
	Props.cyl(rk, Vector3(-2.42, 13.0, 0), 0.9, 0.04, "red_paint", Vector3(0, 0, 90))
	Props.cyl(rk, Vector3(-2.44, 13.0, 0), 0.62, 0.04, "enamel_white", Vector3(0, 0, 90))
	Props.cyl(rk, Vector3(-2.46, 13.0, 0), 0.42, 0.04, "red_paint", Vector3(0, 0, 90))
	Props.stencil(rk, Vector3(-2.47, 9.0, 0), 90.0, "LANTERN", 40)


## The service gantry beside the rocket: a 4-post lattice from the shaft floor, swing arms at three levels, the
## lift cage on its guide rails, a platform at each arm. `post` is the Gantry_Post collider's centre at the floor.
static func gantry(parent: Node3D, post: Vector3, h: float, rocket: Vector3) -> void:
	var b: float = 1.4
	for sx: float in [-b, b]:
		for sz: float in [-b, b]:
			Props.block(parent, post + Vector3(sx + 0.8 - 0.1, 0, sz - 0.1), post + Vector3(sx + 0.8 + 0.1, h, sz + 0.1), "crane_yellow")
	var n: int = int(h / 2.5)
	for i: int in n:
		var y0: float = 2.5 * float(i)
		var y1: float = y0 + 2.5
		for f: Array in [[Vector3(-b, 0, -b), Vector3(b, 0, -b)], [Vector3(b, 0, -b), Vector3(b, 0, b)], [Vector3(b, 0, b), Vector3(-b, 0, b)], [Vector3(-b, 0, b), Vector3(-b, 0, -b)]]:
			var a: Vector3 = post + Vector3(0.8, 0, 0) + (f[0] as Vector3)
			var c: Vector3 = post + Vector3(0.8, 0, 0) + (f[1] as Vector3)
			Props.strut(parent, a + Vector3(0, y1, 0), c + Vector3(0, y1, 0), 0.08, "crane_yellow")
			Props.strut(parent, a + Vector3(0, y0, 0), c + Vector3(0, y1, 0), 0.06, "crane_yellow")
	# the lift cage on the west face (toward the rocket), at the foot
	var cage: Vector3 = post + Vector3(-0.9, 0, 0)
	Props.grille(parent, cage + Vector3(-0.7, 0.1, -0.8), cage + Vector3(-0.7, 0.1, 0.8), 2.2, 0.15, "iron")
	Props.block(parent, cage + Vector3(-0.75, 0, -0.85), cage + Vector3(0.6, 0.12, 0.85), "steel_grate")
	Props.block(parent, cage + Vector3(-0.75, 2.3, -0.85), cage + Vector3(0.6, 2.4, 0.85), "steel")
	for gz: float in [-0.9, 0.9]:
		Props.block(parent, cage + Vector3(0.55, 0, gz - 0.05), cage + Vector3(0.65, h, gz + 0.05), "steel")
	# the swing arms and platforms
	for ay: float in [8.0, 16.0, 24.0]:
		var p0: Vector3 = post + Vector3(-0.5, ay, 0)
		var p1: Vector3 = Vector3(rocket.x + 2.5, post.y + ay, rocket.z)
		Props.block(parent, Vector3(p1.x, p0.y - 0.08, p0.z - 0.9), Vector3(p0.x, p0.y + 0.04, p0.z + 0.9), "steel_grate")
		Props.railing(parent, Vector3(p1.x, p0.y, p0.z - 0.9), Vector3(p0.x, p0.y, p0.z - 0.9), 1.0, "crane_yellow", 1.0)
		Props.railing(parent, Vector3(p1.x, p0.y, p0.z + 0.9), Vector3(p0.x, p0.y, p0.z + 0.9), 1.0, "crane_yellow", 1.0)
		Props.cable(parent, Vector3(p1.x, p0.y + 0.1, p0.z + 0.4), Vector3(rocket.x + 2.4, p0.y - 1.5, rocket.z + 0.4), 0.3, 0.04, 4, "rubber")


## A floodlight on a bracket: the housing, the lens (emissive key), aimed by yaw/pitch.
static func floodlight(parent: Node3D, p: Vector3, yaw: float, pitch: float, lens: String = "flood_glass") -> void:
	var g: Node3D = Props.group(parent, "Flood", p, yaw)
	var h: Node3D = Node3D.new()
	h.rotation_degrees = Vector3(pitch, 0, 0)
	g.add_child(h)
	Props.block(h, Vector3(-0.32, -0.25, -0.2), Vector3(0.32, 0.25, 0.22), "black_paint")
	var mi: MeshInstance3D = Props.block(h, Vector3(-0.27, -0.2, 0.22), Vector3(0.27, 0.2, 0.25), lens)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Props.strut(g, Vector3(0, 0, -0.2), Vector3(0, 0, -0.6), 0.06, "iron")


# ================================================================== the lab

## A glass front on a jamb (the NavBlock_GlassJamb collider): a steel frame, three panes with mullions and a
## transom, one pane cracked. x is the jamb's line, z0..z1 its extent, y the floor, h the height.
static func glass_front(parent: Node3D, x: float, z0: float, z1: float, y: float, h: float, cracked: bool) -> void:
	Props.block(parent, Vector3(x - 0.2, y, z0), Vector3(x + 0.2, y + 0.45, z1), "steel")                 # the sill
	Props.block(parent, Vector3(x - 0.2, y + h - 0.35, z0), Vector3(x + 0.2, y + h, z1), "steel")         # the head
	Props.block(parent, Vector3(x - 0.04, y + 0.45, z0 + 0.05), Vector3(x + 0.04, y + h - 0.35, z1 - 0.05), "glass", false)
	var n: int = maxi(1, int((z1 - z0) / 0.9))
	for i: int in n + 1:
		var z: float = lerpf(z0, z1, float(i) / n)
		Props.block(parent, Vector3(x - 0.12, y + 0.45, z - 0.04), Vector3(x + 0.12, y + h - 0.35, z + 0.04), "steel")
	Props.block(parent, Vector3(x - 0.12, y + 2.4, z0), Vector3(x + 0.12, y + 2.48, z1), "steel")
	if cracked:
		for k: int in 5:
			Props.obox(parent, Vector3(x + 0.05, y + 1.4 + 0.12 * k, (z0 + z1) * 0.5), Vector3(0.01, 0.015, 0.9 - 0.12 * k), "enamel_white", Vector3(0, 0, 0)).rotation_degrees = Vector3(32.0 * k, 0, 0)


## An A-frame hoist over the stone's pit: two A-legs, the beam, the chain block and its hook down into the pit.
static func pit_crane(parent: Node3D, c: Vector3, span: float, h: float) -> void:
	for sx: float in [-span * 0.5, span * 0.5]:
		Props.strut(parent, c + Vector3(sx, 0, -1.6), c + Vector3(sx, h, 0), 0.14, "crane_yellow")
		Props.strut(parent, c + Vector3(sx, 0, 1.6), c + Vector3(sx, h, 0), 0.14, "crane_yellow")
		Props.strut(parent, c + Vector3(sx, h * 0.35, -1.04), c + Vector3(sx, h * 0.35, 1.04), 0.08, "crane_yellow")
	Props.block(parent, c + Vector3(-span * 0.5 - 0.2, h - 0.1, -0.12), c + Vector3(span * 0.5 + 0.2, h + 0.2, 0.12), "crane_yellow")
	Props.block(parent, c + Vector3(-0.25, h - 0.55, -0.15), c + Vector3(0.25, h - 0.1, 0.15), "black_paint")
	Props.cable(parent, c + Vector3(-0.08, h - 0.55, 0), c + Vector3(-0.08, 1.5, 0), 0.0, 0.025, 3, "iron")
	Props.cable(parent, c + Vector3(0.08, h - 0.55, 0), c + Vector3(0.08, 1.5, 0), 0.0, 0.025, 3, "iron")
	Props.cyl(parent, c + Vector3(0, 1.4, 0), 0.12, 0.25, "steel")


# ================================================================== the lakebed

## A range marker post: striped (white/red bands), a number board, a stake ring of stones.
static func range_marker(parent: Node3D, p: Vector3, number: String) -> void:
	for k: int in 4:
		Props.block(parent, p + Vector3(-0.3, 0.4 * k, -0.3), p + Vector3(0.3, 0.4 * (k + 1), 0.3), "red_paint" if k % 2 == 1 else "enamel_white")
	Props.block(parent, p + Vector3(-0.55, 1.6, -0.06), p + Vector3(0.55, 2.3, 0.06), "enamel_white")
	Props.stencil(parent, p + Vector3(0, 1.95, -0.07), 0.0, number, 60, Color(0.08, 0.08, 0.08, 0.95))
	Props.stencil(parent, p + Vector3(0, 1.95, 0.07), 180.0, number, 60, Color(0.08, 0.08, 0.08, 0.95))


## A desert scrub bush (creosote / sagebrush): a few crossing twig boxes and leaf balls, low.
static func scrub(parent: Node3D, p: Vector3, s: float, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for k: int in 3:
		Props.ball(parent, p + Vector3(rng.randf_range(-0.3, 0.3) * s, (0.25 + 0.12 * k) * s, rng.randf_range(-0.3, 0.3) * s),
			Vector3(0.9, 0.55, 0.9) * s * rng.randf_range(0.7, 1.1), "paint:#5c6446" if k % 2 == 0 else "paint:#6e5f48")


## Tyre tracks: pairs of dark strips along a polyline (world points on the salt).
static func tyre_tracks(parent: Node3D, pts: Array, gauge: float, mat: Material) -> void:
	var st: SurfaceTool = st_new(false)
	for i: int in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(-d.z, 0, d.x)
		for s: float in [-gauge * 0.5, gauge * 0.5]:
			var o: Vector3 = side * s
			var w: Vector3 = side * 0.22
			face(st, [a + o - w + Vector3(0, 0.012, 0), b + o - w + Vector3(0, 0.012, 0), b + o + w + Vector3(0, 0.012, 0), a + o + w + Vector3(0, 0.012, 0)], Vector3.UP)
	mesh_node(parent, "TyreTracks", finish(st), mat, false)
