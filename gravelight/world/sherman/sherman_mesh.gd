class_name ShermanMesh
extends RefCounted
## The Sherman (T-249; our own work, built in code): an American M4 medium tank of the winter of 1944, a welded hull
## with the sloped one-piece glacis, a cast turret with the 75 mm gun, vertical-volute bogies, a plain white star
## on the sponsons and the turret. Model space: the bow toward -Z, +X the tank's right, the ground at y 0. 5.9 m
## long over the hull (6.9 m to the muzzle), 2.62 m wide over the tracks, 2.74 m to the turret roof.
## Parts (each an ArrayMesh with a surface per material key, `material(key)`):
##   hull      the lower hull, the final drive housing, the sponsons, the glacis with its hatches, periscopes, bow
##             machine gun, headlights and their guards, spare track links, the engine deck with its grilles, the rear
##             plate with the air cleaners and the exhaust deflector, the stowage (a tarp roll, ammunition boxes, a jerrycan,
##             the pioneer tools), the stars; the bogie brackets, volute spring housings and skids
##   turret    the cast turret (lofted), the rotor shield, the commander's cupola with its doors open, the loader's hatch,
##             periscopes, the vent, lifting rings, the antenna base and whip, the .50 calibre on its post, the stars
##   gun       the mantlet, the 75 mm barrel and the coaxial machine gun, about the trunnion (the gun pivot's origin)
##   wheel     a dual road wheel (rubber tyres on dished steel discs), about its axle (X)
##   sprocket  the drive sprocket (two toothed rings and the hub), about its axle
##   idler     the idler wheel, about its axle
##   roller    a return roller, about its axle
##   link      one track link (+Z along the run, +Y outward from the wheels): the shoe, the end connectors, the guide
##             horn and the steel chevron
## The running gear's places are constants (WHEELS, SPROCKET, IDLER, ROLLERS) and the track's path is `track_path()`.

const TRACK_X: float = 1.10
const TRACK_W: float = 0.42
const WHEEL_R: float = 0.254
const WHEEL_Y: float = 0.29
const BOGIES: Array[float] = [-1.62, -0.06, 1.50]
const WHEEL_DZ: float = 0.355
const SPROCKET: Vector3 = Vector3(0, 0.66, -2.62)   # (x per side)
const SPROCKET_R: float = 0.34
const IDLER: Vector3 = Vector3(0, 0.44, 2.66)
const IDLER_R: float = 0.29
const ROLLER_Y: float = 0.87
const ROLLER_R: float = 0.11
const ROLLER_DZ: float = 0.10
const LINK_PITCH: float = 0.152
const LINK_T: float = 0.045
const TURRET_AT: Vector3 = Vector3(0, 1.90, -0.30)   # the turret ring's centre on the hull roof
const GUN_AT: Vector3 = Vector3(0, 0.38, -0.92)      # the trunnion in the turret's frame
const GUN_LEN: float = 3.05
const MG50_AT: Vector3 = Vector3(0.40, 0.98, 0.70)   # the .50's muzzle base (turret frame)
const COAX_AT: Vector3 = Vector3(0.24, 0.02, -0.30)  # the coax's muzzle, gun frame
const BOW_MG_AT: Vector3 = Vector3(0.52, 1.62, -2.27)

const OD: Color = Color(1, 1, 1)
const MUD: Color = Color(0.55, 0.46, 0.36)
const SNOW: Color = Color(0.92, 0.94, 0.98)

static var _cache: Dictionary = {}
static var _mats: Dictionary = {}


## Road wheel centres on one side (x = 0; the caller puts them at ±TRACK_X).
static func wheel_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b: float in BOGIES:
		out.append(Vector3(0, WHEEL_Y, b - WHEEL_DZ))
		out.append(Vector3(0, WHEEL_Y, b + WHEEL_DZ))
	return out


static func roller_centres() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b: float in BOGIES:
		out.append(Vector3(0, ROLLER_Y, b + ROLLER_DZ))
	return out


## The track's centre line in the side plane, as (z, y) points round the loop in order (going forward along the
## bottom run, up round the sprocket, back along the top, down round the idler), sampled every ~2 cm: the convex hull
## of the wheels' rims (a track hangs straight between them).
static func track_path() -> PackedVector2Array:
	if _cache.has("path"):
		return _cache["path"]
	var pts: PackedVector2Array = PackedVector2Array()
	var off: float = LINK_T * 0.5
	var circles: Array = [[Vector2(SPROCKET.z, SPROCKET.y), SPROCKET_R + 0.02 + off], [Vector2(IDLER.z, IDLER.y), IDLER_R + off]]
	for c: Vector3 in wheel_centres():
		circles.append([Vector2(c.z, c.y), WHEEL_R + off])
	for c2: Vector3 in roller_centres():
		circles.append([Vector2(c2.z, c2.y), ROLLER_R + off])
	for cc: Array in circles:
		for i: int in 72:
			var a: float = TAU * float(i) / 72.0
			pts.append(cc[0] + Vector2(cos(a), sin(a)) * float(cc[1]))
	var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
	# resample evenly
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in hull.size() - 1:
		var a2: Vector2 = hull[i]
		var b2: Vector2 = hull[i + 1]
		var n: int = maxi(1, int(ceil(a2.distance_to(b2) / 0.02)))
		for k: int in n:
			out.append(a2.lerp(b2, float(k) / float(n)))
	_cache["path"] = out
	return out


static func path_length(path: PackedVector2Array) -> float:
	var l: float = 0.0
	for i: int in path.size():
		l += path[i].distance_to(path[(i + 1) % path.size()])
	return l


# ================================================================== materials

## The tank's materials: olive drab (local triplanar, so the paint does not slide over a moving hull), a darker olive,
## the track steel, the rubber, the white of the stars, wood, canvas, the glass of the periscopes, and the burnt
## versions for the wreck (`burnt` true).
static func material(key: String, burnt: bool = false) -> Material:
	var ck: String = key + ("#b" if burnt else "")
	if _mats.has(ck):
		return _mats[ck]
	var m: StandardMaterial3D = null
	match key:
		"od", "od_dark":
			var base: Material = Mats.get_mat("olive_steel")
			m = (base as StandardMaterial3D).duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
			m.uv1_world_triplanar = false
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(1.6, 1.6, 1.6)
			m.roughness = 0.74
			m.metallic = 0.25
			if key == "od_dark":
				m.albedo_color = Color(0.72, 0.72, 0.68)
		"steel":
			var b2: Material = Mats.get_mat("iron")
			m = (b2 as StandardMaterial3D).duplicate() if b2 is StandardMaterial3D else StandardMaterial3D.new()
			m.uv1_world_triplanar = false
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(3, 3, 3)
			m.albedo_color = Color(0.42, 0.4, 0.38)
			m.roughness = 0.78
			m.metallic = 0.3
		"rubber":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.05, 0.05, 0.05)
			m.roughness = 0.85
		"white":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.82, 0.82, 0.78)
			m.roughness = 0.8
		"wood":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.36, 0.25, 0.14)
			m.roughness = 0.9
		"canvas":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.33, 0.31, 0.22)
			m.roughness = 0.95
		"glass":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.05, 0.07, 0.07)
			m.roughness = 0.08
			m.metallic = 0.4
		"brass":
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.55, 0.42, 0.2)
			m.roughness = 0.4
			m.metallic = 0.8
		_:
			m = StandardMaterial3D.new()
			m.albedo_color = Color(0.3, 0.3, 0.3)
	m.vertex_color_use_as_albedo = true
	if burnt and key != "glass":
		m = m.duplicate()
		m.albedo_texture = null
		m.albedo_color = Color(0.11, 0.095, 0.085) if key != "rubber" else Color(0.02, 0.02, 0.02)
		if key == "steel":
			m.albedo_color = Color(0.2, 0.11, 0.06)   # the tracks gone to rust in the fire
		m.roughness = 0.95
		m.metallic = 0.1
	_mats[ck] = m
	return m


## A MeshInstance3D of part `name` with its materials.
static func instance(name: String, burnt: bool = false) -> MeshInstance3D:
	var mk: Array = part(name)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = name.capitalize().replace(" ", "")
	mi.mesh = mk[0]
	var ks: Array = mk[1]
	for i: int in ks.size():
		mi.set_surface_override_material(i, material(str(ks[i]), burnt))
	return mi


static func part(name: String) -> Array:
	if not _cache.has(name):
		var k: ProcKit = ProcKit.new()
		match name:
			"hull":
				_hull(k)
			"turret":
				_turret(k)
			"gun":
				_gun(k)
			"wheel":
				_wheel(k)
			"sprocket":
				_sprocket(k)
			"idler":
				_idler(k)
			"roller":
				_roller(k)
			"link":
				_link(k)
		_cache[name] = k.commit()
	return _cache[name]


# ================================================================== the hull

static func _wedge(k: ProcKit, key: String, t0: Vector3, t1: Vector3, b0: Vector3, b1: Vector3, c0: Vector3, c1: Vector3) -> void:
	## A sloped plate from the top edge t0-t1 down to b0-b1, closed by its sides down to c0-c1 (under the top edge).
	var mid: Vector3 = (t0 + t1 + b0 + b1 + c0 + c1) / 6.0
	var faces: Array = [[t0, t1, b1, b0], [b0, b1, c1, c0], [t0, b0, c0], [t1, c1, b1], [t0, c0, c1, t1]]
	for f: Array in faces:
		var c: Vector3 = Vector3.ZERO
		for p: Vector3 in f:
			c += p
		c /= float(f.size())
		var out: Vector3 = c - mid
		k.tri_facing(key, f[0], f[1], f[2], out)
		if f.size() == 4:
			k.tri_facing(key, f[0], f[2], f[3], out)


static func _hull(k: ProcKit) -> void:
	k.shade_y = Vector2(0.35, 1.25)
	k.shade_k = Color(0.6, 0.55, 0.47)
	# the lower hull between the tracks, its belly
	k.block("od", Vector3(-0.86, 0.40, -2.45), Vector3(0.86, 1.03, 2.62))
	# the final drive housing: the rounded cast nose, extruded across
	var prof: Array = [Vector2(-2.80, 1.20), Vector2(-2.91, 1.08), Vector2(-2.97, 0.90), Vector2(-2.94, 0.72), Vector2(-2.82, 0.56),
		Vector2(-2.62, 0.45), Vector2(-2.45, 0.41), Vector2(-2.40, 1.20)]
	var rings: Array = []
	for x: float in [-0.97, 0.97]:
		var r: PackedVector3Array = PackedVector3Array()
		for p: Vector2 in prof:
			r.append(Vector3(x, p.y, p.x))
		rings.append(r)
	k.loft("od", rings, true, true, true)
	# its bolted seams (three-piece housing): two raised flanges
	for x2: float in [-0.36, 0.36]:
		var fl: Array = []
		for dx: float in [-0.03, 0.03]:
			var r2: PackedVector3Array = PackedVector3Array()
			for p2: Vector2 in prof.slice(0, 7):
				r2.append(Vector3(x2 + dx, p2.y, p2.x - 0.025))
			fl.append(r2)
		k.loft("od_dark", fl, false, false, false)
	# the sponsons and the hull's upper box, the glacis
	k.block("od", Vector3(-1.31, 1.03, -1.80), Vector3(1.31, 1.90, 2.62))
	_wedge(k, "od", Vector3(-1.31, 1.90, -1.80), Vector3(1.31, 1.90, -1.80), Vector3(-1.31, 1.20, -2.80), Vector3(1.31, 1.20, -2.80),
		Vector3(-1.31, 1.03, -1.80), Vector3(1.31, 1.03, -1.80))
	# the sponsons' underside lip over the tracks, a weld bead along the glacis' top edge
	k.beam("od_dark", Vector3(-1.31, 1.905, -1.80), Vector3(1.31, 1.905, -1.80), 0.03)
	# the rear plate: sloped in at the bottom, over the tracks' ends
	_wedge(k, "od", Vector3(-1.31, 1.90, 2.62), Vector3(1.31, 1.90, 2.62), Vector3(-1.31, 1.03, 2.78), Vector3(1.31, 1.03, 2.78),
		Vector3(-1.31, 1.03, 2.62), Vector3(1.31, 1.03, 2.62))
	k.block("od", Vector3(-0.86, 0.55, 2.55), Vector3(0.86, 1.03, 2.78))
	# fenders over the sprockets and the idlers (thin sheet, bent)
	for s: float in [-1.0, 1.0]:
		var x0: float = s * (TRACK_X - TRACK_W * 0.5 - 0.02)
		var x1: float = s * (TRACK_X + TRACK_W * 0.5 + 0.03)
		k.block("od", Vector3(minf(x0, x1), 1.18, -3.02), Vector3(maxf(x0, x1), 1.205, -2.80))
		k.block("od", Vector3(minf(x0, x1), 1.205, -2.84), Vector3(maxf(x0, x1), 1.22, -2.40))
		k.block("od", Vector3(minf(x0, x1), 1.00, 2.62), Vector3(maxf(x0, x1), 1.03, 2.98))
	# the hull roof: the driver's and the co-driver's hatches (raised rings, doors, a periscope ahead of each)
	for s2: float in [-1.0, 1.0]:
		var hc: Vector3 = Vector3(s2 * 0.55, 1.90, -1.30)
		k.cyl("od_dark", hc, hc + Vector3(0, 0.06, 0), 0.33, 0.33, 20)
		k.cyl("od", hc + Vector3(0, 0.06, 0), hc + Vector3(0, 0.10, 0), 0.30, 0.29, 20)
		k.cyl("od_dark", hc + Vector3(s2 * 0.12, 0.10, 0.05), hc + Vector3(s2 * 0.12, 0.15, 0.05), 0.07, 0.07, 10)   # the door's own periscope
		k.box("od_dark", hc + Vector3(-s2 * 0.18, 0.115, 0.0), Vector3(0.05, 0.03, 0.14))   # the hinge
		var pc: Vector3 = Vector3(s2 * 0.55, 1.90, -1.72)
		k.box("od_dark", pc + Vector3(0, 0.05, 0), Vector3(0.20, 0.10, 0.12))
		k.box("glass", pc + Vector3(0, 0.07, -0.062), Vector3(0.16, 0.05, 0.005))
		k.box("od_dark", pc + Vector3(0, 0.115, 0.01), Vector3(0.22, 0.02, 0.16))   # the rain guard
	# the ventilator dome between them, lifting eyes at the corners
	k.cyl("od_dark", Vector3(0, 1.90, -1.45), Vector3(0, 1.97, -1.45), 0.12, 0.09, 14)
	for c: Vector3 in [Vector3(-1.18, 1.90, -1.70), Vector3(1.18, 1.90, -1.70), Vector3(-1.18, 1.90, 2.50), Vector3(1.18, 1.90, 2.50)]:
		k.ring("od_dark", c + Vector3(0, 0.0, -0.05), c + Vector3(0, 0.0, 0.05), 0.07, 0.035, 10)
	# the glacis' fittings: the bow machine gun's ball, the headlights and their brush guards, the spare track links,
	# the towing shackles on the nose, the siren's bracket
	var gn: Vector3 = Vector3(0, 1.0, -0.7).normalized()   # the glacis' outward normal
	var ball: Vector3 = BOW_MG_AT
	k.cyl("od_dark", ball - gn * 0.02, ball + gn * 0.06, 0.16, 0.15, 16)
	k.cyl("od", ball + gn * 0.06, ball + gn * 0.12, 0.13, 0.10, 16)
	k.cyl("steel", ball + gn * 0.10, ball + Vector3(0, -0.02, -0.38), 0.022, 0.018, 8)
	k.cyl("steel", ball + Vector3(0, -0.02, -0.38), ball + Vector3(0, -0.025, -0.42), 0.028, 0.028, 8)
	for s3: float in [-1.0, 1.0]:
		var hl: Vector3 = Vector3(s3 * 0.98, 1.36, -2.62)
		k.cyl("od_dark", hl + gn * 0.0, hl + gn * 0.12, 0.03, 0.03, 8)
		k.cyl("od_dark", hl + gn * 0.12 + Vector3(0, 0.02, 0.06), hl + gn * 0.12 + Vector3(0, 0.02, -0.12), 0.085, 0.09, 14)
		k.cyl("glass", hl + gn * 0.12 + Vector3(0, 0.02, -0.12), hl + gn * 0.12 + Vector3(0, 0.02, -0.125), 0.075, 0.075, 14)
		# the guard: a U of flat bar round the lamp
		var g0: Vector3 = hl + Vector3(-0.14, -0.04, 0.08)
		var g1: Vector3 = hl + Vector3(0.14, -0.04, 0.08)
		var top: float = 0.30
		k.beam("od", g0, g0 + Vector3(0, top, -0.22), 0.025)
		k.beam("od", g1, g1 + Vector3(0, top, -0.22), 0.025)
		k.beam("od", g0 + Vector3(0, top, -0.22), g1 + Vector3(0, top, -0.22), 0.025)
		k.beam("od", g0 + Vector3(0, top * 0.5, -0.11), g1 + Vector3(0, top * 0.5, -0.11), 0.02)
		# the towing shackles on the nose
		var sh: Vector3 = Vector3(s3 * 0.62, 0.66, -2.95)
		k.ring("steel", sh + Vector3(-0.03, 0, 0), sh + Vector3(0.03, 0, 0), 0.085, 0.045, 12)
		k.block("od_dark", sh + Vector3(-0.06, 0.06, 0.02), sh + Vector3(0.06, 0.16, 0.12))
	# spare track links hung across the lower glacis (three, on their bar)
	var lb: Vector3 = Vector3(0, 1.36, -2.56)
	k.beam("steel", lb + Vector3(-0.72, 0.12, -0.08), lb + Vector3(0.72, 0.12, -0.08), 0.03)
	for i: int in 3:
		var lc: Vector3 = lb + Vector3(-0.52 + 0.52 * float(i), 0.0, 0.0)
		var lbas: Basis = Basis(Vector3.RIGHT, -deg_to_rad(55.0))
		k.box("steel", lc, Vector3(0.40, 0.035, 0.14), lbas)
		k.box("steel", lc + lbas * Vector3(0, 0.025, 0), Vector3(0.36, 0.02, 0.045), lbas * Basis(Vector3.UP, 0.35))
	# the engine deck: two grilles, the access doors, the fuel caps
	for s4: float in [-1.0, 1.0]:
		k.block("od_dark", Vector3(s4 * 0.10, 1.90, 0.95), Vector3(s4 * 1.05, 1.925, 2.35))
		for j: int in 9:
			var gz: float = 1.02 + 0.15 * float(j)
			var ga: float = s4 * 0.16
			var gb: float = s4 * 0.99
			k.block("steel", Vector3(minf(ga, gb), 1.925, gz), Vector3(maxf(ga, gb), 1.945, gz + 0.06))
		k.cyl("od_dark", Vector3(s4 * 1.0, 1.90, 0.55), Vector3(s4 * 1.0, 1.94, 0.55), 0.07, 0.07, 10)
	# the rear plate: the two air cleaners, the tail lights, the towing pintle, the exhaust deflector, the idler mounts
	for s5: float in [-1.0, 1.0]:
		k.cyl("od_dark", Vector3(s5 * 0.62, 1.30, 2.74), Vector3(s5 * 0.62, 1.78, 2.71), 0.13, 0.13, 14)
		k.cyl("od", Vector3(s5 * 0.62, 1.78, 2.71), Vector3(s5 * 0.62, 1.84, 2.70), 0.14, 0.10, 14)
		k.box("od_dark", Vector3(s5 * 1.10, 1.70, 2.66), Vector3(0.12, 0.10, 0.06))
		k.box("glass", Vector3(s5 * 1.10, 1.70, 2.695), Vector3(0.08, 0.06, 0.005))
	k.block("od_dark", Vector3(-0.9, 0.62, 2.78), Vector3(0.9, 0.66, 3.05))
	_wedge(k, "od_dark", Vector3(-0.9, 1.00, 2.78), Vector3(0.9, 1.00, 2.78), Vector3(-0.9, 0.66, 3.05), Vector3(0.9, 0.66, 3.05),
		Vector3(-0.9, 0.66, 2.78), Vector3(0.9, 0.66, 2.78))
	k.cyl("steel", Vector3(0, 0.56, 2.98), Vector3(0, 0.56, 3.14), 0.05, 0.05, 10)
	k.ring("steel", Vector3(0, 0.50, 3.10), Vector3(0, 0.62, 3.10), 0.08, 0.045, 12)
	# the stowage: a tarp roll on the deck's back edge, an ammunition box, a jerrycan, the pioneer tools on the sponson's top
	k.tint = Color(1, 1, 1)
	k.cyl("canvas", Vector3(-1.05, 2.06, 2.50), Vector3(1.05, 2.06, 2.50), 0.15, 0.15, 14)
	for sx: float in [-0.75, 0.0, 0.75]:
		k.box("canvas", Vector3(sx, 2.06, 2.50), Vector3(0.05, 0.31, 0.32))   # its straps
	k.block("od_dark", Vector3(0.28, 1.945, 1.72), Vector3(0.62, 2.12, 1.96))
	k.block("od", Vector3(-0.74, 1.945, 1.70), Vector3(-0.42, 2.25, 1.86))   # a jerrycan, upright
	k.block("od_dark", Vector3(-0.66, 2.25, 1.74), Vector3(-0.50, 2.28, 1.82))
	for s6: float in [-1.0, 1.0]:
		var bx: float = s6 * 1.22
		k.beam("wood", Vector3(bx, 1.93, -0.9), Vector3(bx, 1.93, 0.45), 0.04)               # the axe's helve
		k.box("steel", Vector3(bx, 1.94, -0.95), Vector3(0.05, 0.03, 0.16))
		k.beam("wood", Vector3(bx - s6 * 0.08, 1.93, 0.55), Vector3(bx - s6 * 0.08, 1.93, 1.55), 0.035)   # the shovel
		k.box("steel", Vector3(bx - s6 * 0.08, 1.935, 1.70), Vector3(0.18, 0.02, 0.26))
	# the stars: on each sponson's side and the glacis
	for s7: float in [-1.0, 1.0]:
		k.star("white", Vector3(s7 * 1.312, 1.46, 0.35), Vector3(s7, 0, 0), Vector3.UP, 0.34)
	k.star("white", Vector3(-0.62, 1.58, -2.23) + gn * 0.004, gn, Vector3(0, 0.7, 1.0).normalized(), 0.22)
	# the running gear's fixed parts: the bogie brackets bolted to the hull side, the volute spring housings, the arms'
	# pivots, the skids, the return rollers' brackets; the sprockets' final drive hubs and the idlers' brackets
	for s8: float in [-1.0, 1.0]:
		var tx: float = s8 * TRACK_X
		for b: float in BOGIES:
			k.block("od", Vector3(minf(s8 * 0.86, tx), 0.52, b - 0.22), Vector3(maxf(s8 * 0.86, tx), 0.86, b + 0.22))
			k.block("od_dark", Vector3(tx - 0.08, 0.40, b - 0.10), Vector3(tx + 0.08, 0.80, b + 0.10))
			k.cyl("od_dark", Vector3(tx, 0.38, b), Vector3(tx, 0.66, b), 0.095, 0.08, 12)   # the volute spring housing
			for dz: float in [-WHEEL_DZ, WHEEL_DZ]:
				k.beam("od", Vector3(tx, 0.58, b + dz * 0.25), Vector3(tx, WHEEL_Y, b + dz), 0.07, 0.11)
			k.block("od_dark", Vector3(tx - 0.13, 0.86, b - 0.18), Vector3(tx + 0.13, 0.90, b + 0.06))   # the skid
			k.beam("od", Vector3(tx, 0.84, b + ROLLER_DZ), Vector3(tx, ROLLER_Y, b + ROLLER_DZ), 0.06)
		k.cyl("od_dark", Vector3(s8 * 0.97, SPROCKET.y, SPROCKET.z), Vector3(tx - s8 * 0.04, SPROCKET.y, SPROCKET.z), 0.22, 0.20, 16)
		k.block("od", Vector3(minf(s8 * 0.86, tx), IDLER.y - 0.07, IDLER.z - 0.30), Vector3(maxf(s8 * 0.86, tx), IDLER.y + 0.07, IDLER.z - 0.02))
	k.shade_y = Vector2(-1000.0, -999.0)


# ================================================================== the turret

## The turret's sections along its length (turret frame: the ring's centre at the origin): [z, half width, roof height,
## floor of the section].
const TURRET: Array = [[-0.92, 0.60, 0.62, 0.10], [-0.78, 0.78, 0.74, 0.02], [-0.45, 0.92, 0.80, 0.0], [0.05, 0.96, 0.82, 0.0],
	[0.50, 0.90, 0.78, 0.0], [0.86, 0.74, 0.68, 0.04], [1.08, 0.50, 0.54, 0.10], [1.16, 0.26, 0.40, 0.16]]


static func _turret(k: ProcKit) -> void:
	k.shade_y = Vector2(-0.1, 0.25)
	k.shade_k = Color(0.75, 0.72, 0.66)
	# the ring's collar
	k.cyl("od_dark", Vector3(0, -0.02, 0), Vector3(0, 0.06, 0), 0.98, 0.97, 32)
	# the cast body: rounded sections, sides falling in toward the roof
	var rings: Array = []
	for s: Array in TURRET:
		var z: float = float(s[0])
		var hw: float = float(s[1])
		var h: float = float(s[2])
		var f: float = float(s[3])
		var c: Vector3 = Vector3(0, f + (h - f) * 0.5, z)
		rings.append(ProcKit.superellipse(c, Vector3.RIGHT, Vector3.UP, hw, (h - f) * 0.5, 3.0, 28, 0.2))
	k.loft("od", rings, true, true, true)
	# the rotor shield's flat face round the mantlet
	k.box("od", Vector3(0, 0.38, -0.96), Vector3(1.10, 0.58, 0.08))
	k.box("od_dark", Vector3(0, 0.38, -1.005), Vector3(1.04, 0.52, 0.02))
	# the commander's cupola, the doors standing open; the loader's hatch closed; periscopes; the vent; lifting rings
	var cu: Vector3 = Vector3(0.40, 0.81, 0.32)
	k.cyl("od", cu, cu + Vector3(0, 0.14, 0), 0.37, 0.35, 24)
	k.ring("od_dark", cu + Vector3(0, 0.14, 0), cu + Vector3(0, 0.17, 0), 0.36, 0.28, 24)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0 + 0.3
		var d: Vector3 = Vector3(cos(a), 0, sin(a))
		k.box("glass", cu + d * 0.36 + Vector3(0, 0.08, 0), Vector3(0.10, 0.05, 0.01), Basis(Vector3.UP, -a + PI * 0.5))
	for sgn: float in [-1.0, 1.0]:
		var hinge: Vector3 = cu + Vector3(sgn * 0.33, 0.17, 0)
		k.box("od", hinge + Vector3(sgn * 0.08, 0.15, 0), Vector3(0.035, 0.32, 0.50), Basis(Vector3.BACK, sgn * deg_to_rad(28.0)))
	var lh: Vector3 = Vector3(-0.40, 0.81, 0.10)
	k.cyl("od_dark", lh, lh + Vector3(0, 0.05, 0), 0.30, 0.29, 20)
	k.cyl("od", lh + Vector3(0, 0.05, 0), lh + Vector3(0, 0.08, 0), 0.27, 0.25, 20)
	k.box("od_dark", lh + Vector3(0.22, 0.07, 0), Vector3(0.05, 0.03, 0.18))
	for pp: Vector3 in [Vector3(-0.40, 0.80, -0.38), Vector3(0.12, 0.80, -0.52)]:
		k.box("od_dark", pp + Vector3(0, 0.05, 0), Vector3(0.18, 0.10, 0.12))
		k.box("glass", pp + Vector3(0, 0.07, -0.062), Vector3(0.14, 0.05, 0.005))
		k.box("od_dark", pp + Vector3(0, 0.115, 0.01), Vector3(0.20, 0.02, 0.15))
	k.cyl("od_dark", Vector3(-0.05, 0.80, 0.72), Vector3(-0.05, 0.87, 0.72), 0.13, 0.10, 14)
	for sg: float in [-1.0, 1.0]:
		k.ring("od_dark", Vector3(sg * 0.86, 0.66, -0.25), Vector3(sg * 0.86, 0.66, -0.15), 0.07, 0.035, 10)
		k.ring("od_dark", Vector3(sg * 0.62, 0.62, 0.85), Vector3(sg * 0.62, 0.62, 0.95), 0.07, 0.035, 10)
	# the pistol port on the left, the antenna base and its whip at the bustle's back
	k.box("od_dark", Vector3(-0.90, 0.44, 0.25), Vector3(0.05, 0.20, 0.18), Basis(Vector3.BACK, deg_to_rad(-12.0)))
	k.cyl("od_dark", Vector3(-0.55, 0.66, 0.95), Vector3(-0.55, 0.78, 0.95), 0.06, 0.05, 10)
	k.cyl("steel", Vector3(-0.55, 0.78, 0.95), Vector3(-0.62, 2.70, 1.20), 0.009, 0.004, 5, false)
	# the .50 on its post behind the cupola: the post, the cradle, the receiver, the heavy barrel, the grips, the ammo can
	var post: Vector3 = Vector3(0.40, 0.81, 0.78)
	k.cyl("od_dark", post, post + Vector3(0, 0.40, 0), 0.04, 0.035, 10)
	var g0: Vector3 = post + Vector3(0, 0.46, 0.10)
	k.box("steel", g0, Vector3(0.13, 0.12, 0.62))
	k.box("steel", g0 + Vector3(0, 0.0, 0.36), Vector3(0.10, 0.14, 0.10))   # the back plate
	k.beam("steel", g0 + Vector3(-0.06, 0, 0.42), g0 + Vector3(-0.06, -0.08, 0.50), 0.025)   # the spade grips
	k.beam("steel", g0 + Vector3(0.06, 0, 0.42), g0 + Vector3(0.06, -0.08, 0.50), 0.025)
	k.cyl("steel", g0 + Vector3(0, 0.02, -0.31), g0 + Vector3(0, 0.02, -0.62), 0.032, 0.032, 10)   # the barrel's jacket
	k.cyl("steel", g0 + Vector3(0, 0.02, -0.62), g0 + Vector3(0, 0.02, -1.32), 0.02, 0.02, 8)
	k.cyl("steel", g0 + Vector3(0, 0.02, -1.32), g0 + Vector3(0, 0.02, -1.38), 0.028, 0.028, 8)   # the flash hider
	k.box("od_dark", g0 + Vector3(-0.15, -0.04, 0.02), Vector3(0.10, 0.17, 0.27))
	# a star on each side
	for s2: float in [-1.0, 1.0]:
		k.star("white", Vector3(s2 * 0.955, 0.43, 0.25), Vector3(s2, 0.0, 0.0), Vector3.UP, 0.22)
	k.shade_y = Vector2(-1000.0, -999.0)


# ================================================================== the gun (about the trunnion)

static func _gun(k: ProcKit) -> void:
	# the mantlet: a thick curved shield (lofted), the coax's port, the sight's slot
	var rings: Array = []
	for z: float in [0.04, -0.06, -0.16, -0.22]:
		var w: float = 0.46 - 0.07 * absf(z + 0.06) * 3.0
		var h: float = 0.27 - 0.05 * absf(z + 0.06) * 3.0
		rings.append(ProcKit.superellipse(Vector3(0, 0, z), Vector3.RIGHT, Vector3.UP, w, h, 3.4, 24))
	k.loft("od", rings, true, true, true)
	k.box("od_dark", Vector3(0.25, 0.10, -0.23), Vector3(0.06, 0.05, 0.02))   # the sight
	# the barrel: the recoil sleeve, the tube, the muzzle's lip
	k.cyl("od", Vector3(0, 0, -0.20), Vector3(0, 0, -0.62), 0.095, 0.085, 18)
	k.cyl("od", Vector3(0, 0, -0.62), Vector3(0, 0, -GUN_LEN + 0.10), 0.062, 0.055, 18)
	k.cyl("od_dark", Vector3(0, 0, -GUN_LEN + 0.10), Vector3(0, 0, -GUN_LEN), 0.066, 0.066, 18)
	k.ring("steel", Vector3(0, 0, -GUN_LEN - 0.001), Vector3(0, 0, -GUN_LEN + 0.03), 0.06, 0.038, 16)
	# the coax
	k.cyl("steel", Vector3(COAX_AT.x, COAX_AT.y, -0.18), COAX_AT, 0.02, 0.018, 8)


# ================================================================== the running gear (about the axle, X)

static func _wheel(k: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.45)
	for side: float in [-1.0, 1.0]:
		var x0: float = side * 0.035
		var x1: float = side * 0.135
		k.cyl("rubber", Vector3(x0, 0, 0), Vector3(x1, 0, 0), WHEEL_R, WHEEL_R, 24)
		k.cyl("od", Vector3(x1, 0, 0), Vector3(x1 + side * 0.012, 0, 0), WHEEL_R * 0.80, WHEEL_R * 0.62, 20)
		# the dish's spokes (five), raised
		for i: int in 5:
			var a: float = TAU * float(i) / 5.0
			var d: Vector3 = Vector3(0, cos(a), sin(a))
			k.box("od_dark", Vector3(x1 + side * 0.016, 0, 0) + d * 0.11, Vector3(0.012, 0.10, 0.04), Basis(Vector3.RIGHT, a))
		k.cyl("od_dark", Vector3(x1 + side * 0.012, 0, 0), Vector3(x1 + side * 0.04, 0, 0), 0.065, 0.05, 12)
	k.cyl("od", Vector3(-0.035, 0, 0), Vector3(0.035, 0, 0), 0.12, 0.12, 14)
	k.tint = Color.WHITE


static func _sprocket(k: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.55)
	for side: float in [-1.0, 1.0]:
		var x0: float = side * 0.07
		var x1: float = side * 0.12
		k.cyl("od", Vector3(x0, 0, 0), Vector3(x1, 0, 0), SPROCKET_R - 0.02, SPROCKET_R - 0.02, 26)
		for i: int in 13:
			var a: float = TAU * float(i) / 13.0
			var d: Vector3 = Vector3(0, cos(a), sin(a))
			k.box("steel", Vector3((x0 + x1) * 0.5, 0, 0) + d * (SPROCKET_R - 0.005), Vector3(0.045, 0.06, 0.05), Basis(Vector3.RIGHT, a))
		for j: int in 6:   # lightening holes, the dark of them
			var a2: float = TAU * float(j) / 6.0
			var d2: Vector3 = Vector3(0, cos(a2), sin(a2))
			k.cyl("od_dark", Vector3(x1, 0, 0) + d2 * 0.19, Vector3(x1 + side * 0.004, 0, 0) + d2 * 0.19, 0.045, 0.045, 10)
	k.cyl("od_dark", Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0), 0.20, 0.20, 18)
	k.cyl("od", Vector3(0.12, 0, 0), Vector3(0.20, 0, 0), 0.15, 0.10, 16)   # the hub, outboard
	for b: int in 8:
		var a3: float = TAU * float(b) / 8.0
		k.cyl("steel", Vector3(0.20, 0, 0) + Vector3(0, cos(a3), sin(a3)) * 0.075, Vector3(0.215, 0, 0) + Vector3(0, cos(a3), sin(a3)) * 0.075, 0.012, 0.012, 6)
	k.tint = Color.WHITE


static func _idler(k: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.5)
	for side: float in [-1.0, 1.0]:
		k.cyl("od", Vector3(side * 0.04, 0, 0), Vector3(side * 0.13, 0, 0), IDLER_R, IDLER_R, 24)
		for i: int in 6:
			var a: float = TAU * float(i) / 6.0
			var d: Vector3 = Vector3(0, cos(a), sin(a))
			k.cyl("od_dark", Vector3(side * 0.13, 0, 0) + d * 0.16, Vector3(side * 0.134, 0, 0) + d * 0.16, 0.05, 0.05, 10)
	k.cyl("od_dark", Vector3(-0.17, 0, 0), Vector3(0.17, 0, 0), 0.07, 0.07, 12)
	k.tint = Color.WHITE


static func _roller(k: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.5)
	k.cyl("rubber", Vector3(-0.10, 0, 0), Vector3(-0.02, 0, 0), ROLLER_R, ROLLER_R, 16)
	k.cyl("rubber", Vector3(0.02, 0, 0), Vector3(0.10, 0, 0), ROLLER_R, ROLLER_R, 16)
	k.cyl("od_dark", Vector3(-0.12, 0, 0), Vector3(0.12, 0, 0), 0.05, 0.05, 10)
	k.tint = Color.WHITE


static func _link(k: ProcKit) -> void:
	k.tint = MUD.lerp(Color.WHITE, 0.35)
	var hw: float = TRACK_W * 0.5
	var l: float = LINK_PITCH * 0.86
	k.box("steel", Vector3(0, 0, 0), Vector3(TRACK_W - 0.08, LINK_T * 0.7, l))   # the shoe
	for s: float in [-1.0, 1.0]:
		k.box("steel", Vector3(s * (hw - 0.025), 0, 0), Vector3(0.05, LINK_T, LINK_PITCH * 0.98))   # the end connectors
		# the chevron's two bars, outward
		k.box("steel", Vector3(s * 0.09, LINK_T * 0.45, 0), Vector3(0.15, LINK_T * 0.45, 0.035), Basis(Vector3.UP, s * 0.42))
	k.box("steel", Vector3(0, -LINK_T * 0.5 - 0.03, 0), Vector3(0.035, 0.06, 0.05))   # the guide horn, inward
	k.tint = Color.WHITE
