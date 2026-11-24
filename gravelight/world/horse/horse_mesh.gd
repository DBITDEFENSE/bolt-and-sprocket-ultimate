class_name HorseMesh
extends RefCounted
## The horse's body as one skinned mesh built in code (T-240; our own work): a heavy Alpine draught horse (Noriker
## type), 1.6 m at the withers, and the same horse long dead. The body, neck and head are lofted from elliptical
## sections (egg-shaped: narrow over the spine, full in the belly), the legs from sections through their joints,
## the mane and tail from hair cards and a tapered loft; every vertex is weighted to the bones HorseRig poses.
## Model space: nose toward -Z, +X the horse's right, the ground at y 0.
##   look "noriker": dark bay with black points, a blaze, feathered fetlocks, a saddle on a loden blanket, a girth,
##     stirrups, a bridle with reins to the pommel.
##   look "dead": the hide drawn tight (a tucked belly, ribs standing, gaps between them that the Nachtglas shines
##     through), a bare jaw with teeth, empty sockets, a torn ear, a thin mane and tail, a draught collar with hames
##     and a back strap, trace chains back along the flanks.
## Surfaces (each its own material, HorseMesh.material): coat, hair, hoof, leather, cloth, metal, eye, bone, glow, dark.

const SEGS: int = 16

## Joints of the right legs at rest (the left mirror x): fore [shoulder, elbow, knee, fetlock, coronet, ground],
## hind [hip, stifle, hock, fetlock, coronet, ground].
const FORE: Array = [Vector3(0.23, 1.20, -0.62), Vector3(0.23, 0.88, -0.48), Vector3(0.23, 0.50, -0.52), Vector3(0.23, 0.17, -0.52), Vector3(0.23, 0.085, -0.58), Vector3(0.23, 0.0, -0.61)]
const HIND: Array = [Vector3(0.24, 1.22, 0.58), Vector3(0.26, 0.90, 0.40), Vector3(0.25, 0.56, 0.84), Vector3(0.25, 0.17, 0.80), Vector3(0.25, 0.085, 0.735), Vector3(0.25, 0.0, 0.705)]
const NECK: Array = [Vector3(0, 1.34, -0.66), Vector3(0, 1.58, -0.92), Vector3(0, 1.84, -1.13), Vector3(0, 2.0, -1.30)]   # three neck joints and the poll
const HEAD_AXIS: Vector3 = Vector3(0, -0.81, -0.586)     # poll -> muzzle
const HEAD_FRONT: Vector3 = Vector3(0, 0.586, -0.81)     # the face's front (the nasal line's normal)
const HEAD_LEN: float = 0.62
const TAIL: Array = [Vector3(0, 1.46, 0.93), Vector3(0, 1.39, 1.05), Vector3(0, 1.17, 1.115), Vector3(0, 0.9, 1.125), Vector3(0, 0.64, 1.105), Vector3(0, 0.4, 1.08)]
const BODY_PIVOT: Vector3 = Vector3(0, 1.2, 0.0)
const HIPS_PIVOT: Vector3 = Vector3(0, 1.35, 0.35)
const SEAT: Vector3 = Vector3(0, 1.63, -0.14)            # where a rider sits (the saddle's dip)
const POMMEL: Vector3 = Vector3(0, 1.69, -0.40)          # where the reins are held

## The barrel's sections: [z, top, bottom, half width, top narrowness]
const BARREL: Array = [
	[-0.85, 1.36, 1.08, 0.13, 0.2], [-0.77, 1.50, 0.93, 0.27, 0.3], [-0.62, 1.58, 0.83, 0.335, 0.45],
	[-0.48, 1.60, 0.79, 0.355, 0.55], [-0.25, 1.555, 0.77, 0.385, 0.42], [0.0, 1.53, 0.76, 0.40, 0.34],
	[0.25, 1.54, 0.79, 0.40, 0.3], [0.45, 1.585, 0.86, 0.39, 0.22], [0.62, 1.60, 0.90, 0.385, 0.18],
	[0.78, 1.56, 0.93, 0.35, 0.18], [0.90, 1.47, 0.99, 0.265, 0.2], [0.97, 1.36, 1.07, 0.14, 0.2]]

const COAT: Color = Color(0.21, 0.115, 0.062)
const COAT_DARK: Color = Color(0.055, 0.04, 0.035)
const COAT_PALE: Color = Color(0.36, 0.25, 0.17)
## T-274: other living coats by look (the same horse, the same black points and tack): [coat, the paler belly].
## A look not listed here (and not "dead") wears the dark bay above.
const COATS: Dictionary = {
	"buckskin": [Color(0.5, 0.36, 0.2), Color(0.66, 0.52, 0.34)],   # Groom Lake's: a tan desert horse with black points
}
const WHITE: Color = Color(0.86, 0.83, 0.77)
const HAIR: Color = Color(0.07, 0.054, 0.045)
const DEAD_HIDE: Color = Color(0.2, 0.17, 0.15)
const DEAD_DARK: Color = Color(0.07, 0.06, 0.06)
const BONE: Color = Color(0.74, 0.7, 0.6)
const GLOW: Color = Color(0.72, 0.42, 1.0)          # the kit's Nachtglas light
const GLOW_CORE: Color = Color(0.5, 0.16, 0.95)     # what burns in the ribcage and the sockets

static var _cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


## Every bone: [name, rest origin]. The skeleton is flat (HorseRig computes each bone's place itself); a bone's rest
## is its origin with no rotation, so an attachment on it sits in model axes.
static func bones() -> Array:
	var out: Array = [["Body", BODY_PIVOT], ["Hips", HIPS_PIVOT], ["Neck1", NECK[0]], ["Neck2", NECK[1]], ["Neck3", NECK[2]],
		["Head", NECK[3]], ["Jaw", head_point(0.1, 0.0, -0.1)], ["EarL", ear_base(-1.0)], ["EarR", ear_base(1.0)],
		["Forelock", head_point(-0.02, 0.0, 0.1)], ["Mane1", NECK[0]], ["Mane2", NECK[1]], ["Mane3", NECK[2]]]
	for i: int in 5:
		out.append(["Tail%d" % (i + 1), TAIL[i]])
	for leg: int in 4:
		var j: Array = leg_joints(leg)
		for s: int in 4:
			out.append(["%s_%s" % [HorseGait.LEG_NAMES[leg], "ABCD"[s]], j[s]])
	return out


## The six joints of a leg at rest (HorseGait's leg order: LH, LF, RH, RF).
static func leg_joints(leg: int) -> Array:
	var src: Array = HIND if leg == HorseGait.LH or leg == HorseGait.RH else FORE
	var sx: float = -1.0 if leg == HorseGait.LH or leg == HorseGait.LF else 1.0
	var out: Array = []
	for p: Vector3 in src:
		out.append(Vector3(p.x * sx, p.y, p.z))
	return out


## A point on the head: `s` metres from the poll toward the muzzle, `side` metres to the horse's right, `front`
## metres out of the face's front.
static func head_point(s: float, side: float, front: float) -> Vector3:
	return (NECK[3] as Vector3) + HEAD_AXIS * s + Vector3.RIGHT * side + HEAD_FRONT * front


static func ear_base(sx: float) -> Vector3:
	return head_point(0.0, 0.062 * sx, 0.085)


static func muzzle() -> Vector3:
	return head_point(HEAD_LEN, 0.0, 0.0)


static func eye_pos(sx: float) -> Vector3:
	return head_point(0.135, 0.121 * sx, 0.046)


static func nostril_pos(sx: float) -> Vector3:
	return head_point(0.59, 0.042 * sx, 0.04)


## The mesh for a look, built once.
static func mesh(look: String) -> ArrayMesh:
	if not _cache.has(look):
		_cache[look] = _Builder.new().build(look)
	return _cache[look]


## The material of a surface (by its name, set as the surface's name on the mesh).
static func material(surface: String, look: String) -> Material:
	var key: String = surface + "|" + look
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	var dead: bool = look == "dead"
	match surface:
		"coat":
			m.roughness = 0.95 if dead else 0.66
			m.metallic_specular = 0.2 if dead else 0.3
			if dead:
				m.cull_mode = BaseMaterial3D.CULL_DISABLED   # the hide has gaps: its inside shows, lit by what burns in there
			else:
				m.rim_enabled = true
				m.rim = 0.18
				m.rim_tint = 0.7
		"hair":
			m.roughness = 0.62
			m.metallic_specular = 0.3
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"hoof":
			m.roughness = 0.45
		"leather":
			m.roughness = 0.55 if not dead else 0.9
		"cloth":
			m.roughness = 0.95
		"metal":
			m.roughness = 0.4 if not dead else 0.75
			m.metallic = 0.85
		"eye":
			m.roughness = 0.08
			m.metallic_specular = 0.9
		"bone":
			m.roughness = 0.7
		"glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = GLOW_CORE
			m.emission_energy_multiplier = 3.2
		"dark":
			m.roughness = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


class _Surf:
	var v: PackedVector3Array = []
	var n: PackedVector3Array = []
	var c: PackedColorArray = []
	var b: PackedInt32Array = []
	var w: PackedFloat32Array = []
	var idx: PackedInt32Array = []


class _Builder:
	var surfs: Dictionary = {}
	var order: Array = []
	var bone_ix: Dictionary = {}
	var dead: bool = false
	var coat: Color = HorseMesh.COAT
	var coat_pale: Color = HorseMesh.COAT_PALE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	func surf(name: String) -> _Surf:
		if not surfs.has(name):
			surfs[name] = _Surf.new()
			order.append(name)
		return surfs[name]

	## One vertex: position, colour, weights as [bone name, weight, ...] (up to four bones).
	func vert(s: _Surf, p: Vector3, col: Color, wts: Array) -> int:
		s.v.append(p)
		s.n.append(Vector3.ZERO)
		s.c.append(col)
		var total: float = 0.0
		for i: int in range(1, wts.size(), 2):
			total += float(wts[i])
		for i: int in 4:
			if i * 2 < wts.size():
				s.b.append(int(bone_ix[wts[i * 2]]))
				s.w.append(float(wts[i * 2 + 1]) / maxf(total, 0.0001))
			else:
				s.b.append(0)
				s.w.append(0.0)
		return s.v.size() - 1

	## A triangle, wound so its face looks away from `inside`.
	func tri(s: _Surf, a: int, b: int, c: int, inside: Vector3) -> void:
		var fn: Vector3 = (s.v[b] - s.v[a]).cross(s.v[c] - s.v[a])
		if fn.length_squared() < 1e-12:
			return
		var mid: Vector3 = (s.v[a] + s.v[b] + s.v[c]) / 3.0
		# Godot's front faces are clockwise: the geometric normal (b-a)x(c-a) of a front face points away from the viewer
		if fn.dot(mid - inside) > 0.0:
			var t: int = b
			b = c
			c = t
			fn = -fn
		s.idx.append(a)
		s.idx.append(b)
		s.idx.append(c)
		var out_n: Vector3 = -fn   # area-weighted, pointing out
		s.n[a] += out_n
		s.n[b] += out_n
		s.n[c] += out_n

	## A ring: {c centre, u, v the section's axes, ru, rv the radii along them, k the narrowness at +v, w weights,
	## col colour or a Callable(theta) -> Color}. theta 0 is +v (the top), a quarter turn is +u.
	func ring(c: Vector3, u: Vector3, v: Vector3, ru: float, rv: float, k: float, w: Array, col: Variant) -> Dictionary:
		return {"c": c, "u": u, "v": v, "ru": ru, "rv": rv, "k": k, "w": w, "col": col}

	func ring_point(r: Dictionary, th: float) -> Vector3:
		var top: float = (cos(th) + 1.0) * 0.5
		var wide: float = 1.0 - float(r["k"]) * top * top
		return (r["c"] as Vector3) + (r["u"] as Vector3) * (float(r["ru"]) * sin(th) * wide) + (r["v"] as Vector3) * (float(r["rv"]) * cos(th))

	## Lofts a skin through `rings`. `arc`: [from, to] in turns of theta for an open strip (a blanket, a strap); the
	## default is the full section. `caps`: close the first / last ring with a fan (`bulge`: how far its middle stands
	## out, in radii). `skip`: Callable(ring i, seg j) -> true leaves that quad out (the gaps between the ribs). `push`:
	## metres every vertex is moved out along the section.
	func loft(sname: String, rings: Array, segs: int = SEGS, arc: Array = [], caps: Array = [true, true], skip: Callable = Callable(), push: float = 0.0, bulge: float = 0.45) -> void:
		var s: _Surf = surf(sname)
		var open: bool = arc.size() == 2
		var cols: int = segs + 1 if open else segs
		var base: Array = []
		for r: Dictionary in rings:
			var first: int = s.v.size()
			base.append(first)
			for j: int in cols:
				var th: float = TAU * (lerpf(float(arc[0]), float(arc[1]), float(j) / float(segs)) if open else float(j) / float(segs))
				var p: Vector3 = ring_point(r, th)
				if push != 0.0:
					var o: Vector3 = p - (r["c"] as Vector3)
					if o.length() > 0.0001:
						p += o.normalized() * push
				var col: Color = (r["col"] as Callable).call(th) if r["col"] is Callable else r["col"]
				vert(s, p, col, r["w"])
		for i: int in rings.size() - 1:
			var inside: Vector3 = ((rings[i]["c"] as Vector3) + (rings[i + 1]["c"] as Vector3)) * 0.5
			for j: int in (segs if open else cols):
				if skip.is_valid() and bool(skip.call(i, j)):
					continue
				var j2: int = j + 1 if open else (j + 1) % cols
				var a: int = int(base[i]) + j
				var b: int = int(base[i]) + j2
				var c2: int = int(base[i + 1]) + j2
				var d: int = int(base[i + 1]) + j
				tri(s, a, b, c2, inside)
				tri(s, a, c2, d, inside)
		if not open:
			for e: int in 2:
				if not bool(caps[e]):
					continue
				var r2: Dictionary = rings[0 if e == 0 else rings.size() - 1]
				var other: Dictionary = rings[1 if e == 0 else rings.size() - 2]
				var out_dir: Vector3 = ((r2["c"] as Vector3) - (other["c"] as Vector3)).normalized()
				var col2: Color = (r2["col"] as Callable).call(0.0) if r2["col"] is Callable else r2["col"]
				var cv: int = vert(s, (r2["c"] as Vector3) + out_dir * minf(float(r2["ru"]), float(r2["rv"])) * bulge, col2, r2["w"])
				var b0: int = int(base[0 if e == 0 else rings.size() - 1])
				for j: int in cols:
					tri(s, cv, b0 + j, b0 + (j + 1) % cols, (r2["c"] as Vector3) - out_dir * 0.05)

	## A hair card through `pts` ([position, half-width vector, weights]): two-sided by its material.
	func card(sname: String, pts: Array, col: Color, tip: Color) -> void:
		var s: _Surf = surf(sname)
		var first: int = s.v.size()
		var n: int = pts.size()
		for i: int in n:
			var t: float = float(i) / float(maxi(1, n - 1))
			var p: Array = pts[i]
			var cc: Color = col.lerp(tip, t)
			vert(s, (p[0] as Vector3) - (p[1] as Vector3), cc, p[2])
			vert(s, (p[0] as Vector3) + (p[1] as Vector3), cc, p[2])
		for i: int in n - 1:
			var a: int = first + i * 2
			var away: Vector3 = (pts[i][0] as Vector3) - ((pts[i][1] as Vector3).cross((pts[i + 1][0] as Vector3) - (pts[i][0] as Vector3))).normalized()
			tri(s, a, a + 1, a + 3, away)
			tri(s, a, a + 3, a + 2, away)

	## A small ellipsoid (an eye, a nostril, a rivet, a tooth) on one bone.
	func blob(sname: String, c: Vector3, radii: Vector3, col: Color, w: Array, segs: int = 8, basis: Basis = Basis.IDENTITY) -> void:
		var rings: Array = []
		var steps: int = maxi(3, segs / 2)
		for i: int in range(1, steps):
			var a: float = PI * float(i) / float(steps)
			rings.append(ring(c + basis.z * (radii.z * cos(a)), basis.x, basis.y, radii.x * sin(a), radii.y * sin(a), 0.0, w, col))
		loft(sname, rings, segs)

	## A tube through points (a strap, a rein, a rib, a hame): `r` its radius (or [ru, rv]), weights per point.
	func tube(sname: String, pts: Array, r: Variant, col: Color, wts: Array, segs: int = 6, side: Vector3 = Vector3.RIGHT) -> void:
		var rings: Array = []
		for i: int in pts.size():
			var a: Vector3 = pts[maxi(0, i - 1)]
			var b: Vector3 = pts[mini(pts.size() - 1, i + 1)]
			var d: Vector3 = (b - a).normalized()
			var u: Vector3 = side - d * side.dot(d)
			if u.length() < 0.05:
				u = Vector3.UP - d * Vector3.UP.dot(d)
			u = u.normalized()
			var v: Vector3 = d.cross(u).normalized()
			var ru: float = float(r[0]) if r is Array else float(r)
			var rv: float = float(r[1]) if r is Array else float(r)
			rings.append(ring(pts[i], u, v, ru, rv, 0.0, wts[mini(i, wts.size() - 1)], col))
		loft(sname, rings, segs)

	func shade(col: Color, p: Vector3, amount: float = 0.07) -> Color:
		# a little unevenness so a flat coat does not read as plastic (a hash of the place, stable between builds)
		var h: float = sin(p.x * 37.1 + p.y * 17.3 + p.z * 29.7) * 0.5 + sin(p.x * 11.3 - p.z * 7.9 + p.y * 23.1) * 0.5
		return Color(col.r * (1.0 + h * amount), col.g * (1.0 + h * amount), col.b * (1.0 + h * amount))

	# ------------------------------------------------------------------ the parts

	func build(look: String) -> ArrayMesh:
		dead = look == "dead"
		if HorseMesh.COATS.has(look):
			coat = (HorseMesh.COATS[look] as Array)[0]
			coat_pale = (HorseMesh.COATS[look] as Array)[1]
		rng.seed = 2407
		var bl: Array = HorseMesh.bones()
		for i: int in bl.size():
			bone_ix[bl[i][0]] = i
		_barrel()
		_neck()
		_head()
		_ears()
		for leg: int in 4:
			_leg(leg)
		_mane()
		_tail()
		if dead:
			_dead_dress()
		else:
			_tack()
		var mesh: ArrayMesh = ArrayMesh.new()
		for name: String in order:
			var s: _Surf = surfs[name]
			if s.idx.is_empty():
				continue
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			var norms: PackedVector3Array = s.n
			for i: int in norms.size():
				norms[i] = norms[i].normalized() if norms[i].length_squared() > 1e-12 else Vector3.UP
			arr[Mesh.ARRAY_VERTEX] = s.v
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = s.c
			arr[Mesh.ARRAY_BONES] = s.b
			arr[Mesh.ARRAY_WEIGHTS] = s.w
			arr[Mesh.ARRAY_INDEX] = s.idx
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var si: int = mesh.get_surface_count() - 1
			mesh.surface_set_name(si, name)
			mesh.surface_set_material(si, HorseMesh.material(name, look))
		return mesh

	func _coat(p: Vector3) -> Color:
		if dead:
			return shade(HorseMesh.DEAD_HIDE.lerp(HorseMesh.DEAD_DARK, clampf((1.0 - p.y) * 0.5, 0.0, 0.6)), p, 0.16)
		# dark bay: the belly and the flanks a shade paler, the top line dark
		var k: float = clampf((1.25 - p.y) * 1.2, 0.0, 0.5)
		return shade(coat.lerp(coat_pale, k * 0.55), p)

	func _barrel() -> void:
		var rings: Array = []
		var n: int = HorseMesh.BARREL.size()
		for i: int in n:
			var st: Array = HorseMesh.BARREL[i]
			var z: float = st[0]
			var top: float = st[1]
			var bot: float = st[2]
			var half: float = st[3]
			if dead:
				# long in the ground: the belly tucked up, the flanks fallen in, the spine and the hips standing
				var mid: float = clampf(1.0 - absf(z - 0.2) / 0.75, 0.0, 1.0)
				bot += 0.1 * mid
				half *= 1.0 - 0.14 * mid
				top -= 0.012 * mid
			var hips: float = clampf((z - 0.1) / 0.5, 0.0, 1.0)
			var w: Array = ["Body", 1.0 - hips, "Hips", hips]
			var c: Vector3 = Vector3(0, (top + bot) * 0.5, z)
			var col: Callable = func(th: float) -> Color:
				return _coat(c + Vector3(sin(th) * half, cos(th) * (top - bot) * 0.5, 0))
			rings.append(ring(c, Vector3.RIGHT, Vector3.UP, half, (top - bot) * 0.5, float(st[4]) + (0.18 if dead else 0.0), w, col))
		var skip: Callable = Callable()
		if dead:
			# gaps in the left flank's hide and one in the right: the ribs bridge them, the Nachtglas shines through
			skip = func(i: int, j: int) -> bool:
				return (i >= 3 and i <= 5 and j >= 10 and j <= 12) or (i == 4 and j >= 3 and j <= 4)
		loft("coat", rings, SEGS, [], [true, true], skip)
		if dead:
			_ribs()

	## The ribs: bars over the flanks (they bridge the gaps in the hide), the spine's knuckles, the points of the hips.
	func _ribs() -> void:
		for i: int in 9:
			var z: float = -0.42 + 0.092 * float(i)
			var st: Array = _barrel_at(z)
			for sx: float in [-1.0, 1.0]:
				var pts: Array = []
				for q: int in 8:
					var th: float = TAU * lerpf(0.07, 0.36, float(q) / 7.0)
					var p: Vector3 = _barrel_point(st, th, 0.006)
					pts.append(Vector3(p.x * sx, p.y, p.z + 0.05 * float(q) / 7.0))   # ribs rake back toward the belly
				tube("bone", pts, [0.014, 0.011], shade(HorseMesh.BONE.lerp(HorseMesh.DEAD_HIDE, 0.45), pts[0], 0.1), [["Body", 1.0]], 5, Vector3.BACK)
		for i: int in 11:
			var z: float = -0.4 + 0.11 * float(i)
			var st: Array = _barrel_at(z)
			blob("bone", Vector3(0, float(st[1]) + 0.004, z), Vector3(0.022, 0.02, 0.034), HorseMesh.BONE.lerp(HorseMesh.DEAD_HIDE, 0.55), ["Body", 1.0 - clampf((z - 0.1) / 0.5, 0.0, 1.0), "Hips", clampf((z - 0.1) / 0.5, 0.0, 1.0)], 6)
		for sx: float in [-1.0, 1.0]:
			blob("coat", Vector3(0.24 * sx, 1.5, 0.5), Vector3(0.06, 0.045, 0.08), _coat(Vector3(0.3, 1.5, 0.5)), ["Hips", 1.0], 8)
		# what burns inside the ribcage: a ragged core of Nachtglas, and the dark lining behind the hide's gaps
		var core: Array = []
		for i: int in 6:
			var z: float = -0.45 + 0.17 * float(i)
			var r: float = 0.16 + 0.05 * sin(float(i) * 2.1)
			core.append(ring(Vector3(0.02 * sin(float(i) * 1.7), 1.2 + 0.03 * cos(float(i) * 2.3), z), Vector3.RIGHT, Vector3.UP, r, r * 1.15, 0.0, ["Body", 1.0], HorseMesh.GLOW_CORE.darkened(0.25 + 0.25 * absf(sin(float(i) * 1.3)))))
		loft("glow", core, 8)

	## The barrel's section at z, interpolated: [z, top, bottom, half width, narrowness] as the mesh has it.
	func _barrel_at(z: float) -> Array:
		var b: Array = HorseMesh.BARREL
		for i: int in b.size() - 1:
			if z <= float(b[i + 1][0]):
				var t: float = clampf((z - float(b[i][0])) / (float(b[i + 1][0]) - float(b[i][0])), 0.0, 1.0)
				var out: Array = [z]
				for q: int in range(1, 5):
					out.append(lerpf(float(b[i][q]), float(b[i + 1][q]), t))
				if dead:
					var mid: float = clampf(1.0 - absf(z - 0.2) / 0.75, 0.0, 1.0)
					out[2] = float(out[2]) + 0.1 * mid
					out[3] = float(out[3]) * (1.0 - 0.14 * mid)
					out[1] = float(out[1]) - 0.012 * mid
					out[4] = float(out[4]) + 0.18
				return out
		return (b[b.size() - 1] as Array).duplicate()

	func _barrel_point(st: Array, th: float, push: float = 0.0) -> Vector3:
		var r: Dictionary = ring(Vector3(0, (float(st[1]) + float(st[2])) * 0.5, float(st[0])), Vector3.RIGHT, Vector3.UP, float(st[3]), (float(st[1]) - float(st[2])) * 0.5, float(st[4]), [], Color.WHITE)
		var p: Vector3 = ring_point(r, th)
		var o: Vector3 = p - (r["c"] as Vector3)
		return p + o.normalized() * push

	## The neck's sections from the chest to the throat: [centre, half width, half depth, narrowness, weights, the
	## neck bone and the mane bone a lock rooted here rides].
	func _neck_path() -> Array:
		return [
			[Vector3(0, 1.30, -0.60), 0.235, 0.33, 0.35, ["Body", 1.0], "Neck1", "Mane1"],
			[Vector3(0, 1.44, -0.76), 0.205, 0.305, 0.42, ["Body", 0.5, "Neck1", 0.5], "Neck1", "Mane1"],
			[Vector3(0, 1.60, -0.90), 0.172, 0.268, 0.5, ["Neck1", 0.6, "Neck2", 0.4], "Neck1", "Mane1"],
			[Vector3(0, 1.75, -1.03), 0.148, 0.232, 0.52, ["Neck2", 0.8, "Neck3", 0.2], "Neck2", "Mane2"],
			[Vector3(0, 1.88, -1.15), 0.128, 0.196, 0.48, ["Neck2", 0.2, "Neck3", 0.8], "Neck3", "Mane3"],
			[Vector3(0, 1.98, -1.255), 0.112, 0.16, 0.4, ["Neck3", 0.4, "Head", 0.6], "Neck3", "Mane3"],
			[Vector3(0, 2.025, -1.31), 0.1, 0.128, 0.3, ["Head", 1.0], "Head", "Mane3"]]

	## A neck section's frame and size: [centre, dorsal axis, half width, half depth].
	func _neck_at(path: Array, i: int) -> Array:
		var a: Vector3 = path[maxi(0, i - 1)][0]
		var b: Vector3 = path[mini(path.size() - 1, i + 1)][0]
		var d: Vector3 = (b - a).normalized()
		var v: Vector3 = Vector3.RIGHT.cross(d).normalized()   # the dorsal side (up and back)
		if v.y < 0.0:
			v = -v
		return [path[i][0], v, float(path[i][1]) * (0.8 if dead else 1.0), float(path[i][2]) * (0.84 if dead else 1.0)]

	func _neck() -> void:
		# deep and thick at the base, a crest standing over the middle
		var path: Array = _neck_path()
		var rings: Array = []
		for i: int in path.size():
			var fr: Array = _neck_at(path, i)
			var c: Vector3 = fr[0]
			var v: Vector3 = fr[1]
			var ru: float = fr[2]
			var rv: float = fr[3]
			var col: Callable = func(th: float) -> Color:
				return _coat(c + Vector3.RIGHT * sin(th) * ru + v * cos(th) * rv)
			rings.append(ring(c, Vector3.RIGHT, v, ru, rv, float(path[i][3]), path[i][4], col))
		loft("coat", rings, SEGS, [], [false, false])

	func _head() -> void:
		# [s from the poll, half width, half depth, the centre's shift toward the jaw]
		var secs: Array = [[-0.045, 0.062, 0.068, 0.0], [0.02, 0.11, 0.122, 0.01], [0.12, 0.134, 0.15, 0.022], [0.24, 0.12, 0.165, 0.038],
			[0.36, 0.094, 0.13, 0.022], [0.47, 0.079, 0.1, 0.006], [0.56, 0.084, 0.096, 0.0], [0.615, 0.068, 0.076, 0.004]]
		var rings: Array = []
		for sc: Array in secs:
			var s: float = sc[0]
			var c: Vector3 = HorseMesh.head_point(s, 0.0, -float(sc[3]))
			var hw: float = float(sc[1])
			var hd: float = float(sc[2])
			var col: Callable = func(th: float) -> Color:
				var p: Vector3 = c + Vector3.RIGHT * sin(th) * hw + HorseMesh.HEAD_FRONT * cos(th) * hd
				if dead:
					# the muzzle's skin is gone: bone from the nose down
					var bare: float = 0.3 + 0.08 * sin(th * 3.0)        # the hide's ragged edge round the muzzle
					return shade(HorseMesh.BONE.darkened(0.12), p, 0.14) if s > bare else _coat(p)
				var front: float = cos(th)
				if front > 0.8 and s > 0.03 and s < 0.5:
					return HorseMesh.WHITE   # the blaze
				if s > 0.5:
					return shade(HorseMesh.COAT_DARK.lerp(coat_pale, 0.25), p)   # the muzzle
				return _coat(p)
			rings.append(ring(c, Vector3.RIGHT, HorseMesh.HEAD_FRONT, hw, hd, 0.25, ["Head", 1.0], col))
		var skip: Callable = Callable()
		if dead:
			# the lower jaw is bare bone, hung on its own (the Jaw bone): the skull's underside stays open
			skip = func(i: int, j: int) -> bool:
				return i >= 2 and j >= 6 and j <= 9
		loft("coat", rings, SEGS, [], [true, true], skip)
		for sx: float in [-1.0, 1.0]:
			var ep: Vector3 = HorseMesh.eye_pos(sx)
			if dead:
				blob("dark", ep - Vector3.RIGHT * 0.004 * sx, Vector3(0.012, 0.042, 0.048), Color(0.012, 0.008, 0.012), ["Head", 1.0])
				blob("glow", ep + Vector3.RIGHT * 0.008 * sx, Vector3(0.012, 0.02, 0.02), HorseMesh.GLOW_CORE.lightened(0.3), ["Head", 1.0], 6)
				blob("dark", HorseMesh.nostril_pos(sx), Vector3(0.02, 0.018, 0.03), Color(0.03, 0.02, 0.02), ["Head", 1.0], 6, Basis(Vector3.RIGHT, 0.6))
			else:
				blob("eye", ep - Vector3.RIGHT * 0.012 * sx, Vector3(0.016, 0.023, 0.026), Color(0.03, 0.02, 0.015), ["Head", 1.0])
				# the brow's ridge over it, and the nostril
				blob("coat", ep - Vector3.RIGHT * 0.02 * sx + HorseMesh.HEAD_FRONT * 0.03, Vector3(0.022, 0.012, 0.04), _coat(ep).darkened(0.2), ["Head", 1.0], 6, Basis(Vector3.RIGHT, 0.6))
				blob("eye", HorseMesh.nostril_pos(sx), Vector3(0.014, 0.012, 0.024), Color(0.02, 0.012, 0.012), ["Head", 1.0], 6, Basis(Vector3.RIGHT, 0.6))
		if dead:
			_jaw()

	## The dead horse's lower jaw: two bars from the joint under the eye to the chin, a row of teeth, and the skull's own.
	func _jaw() -> void:
		var w: Array = [["Jaw", 1.0]]
		for sx: float in [-1.0, 1.0]:
			var pts: Array = [HorseMesh.head_point(0.1, 0.085 * sx, -0.1), HorseMesh.head_point(0.2, 0.08 * sx, -0.19), HorseMesh.head_point(0.38, 0.05 * sx, -0.15), HorseMesh.head_point(0.58, 0.024 * sx, -0.105)]
			tube("bone", pts, [0.016, 0.03], shade(HorseMesh.BONE, pts[1], 0.12), w, 6)
			for t: int in 5:
				var tp: Vector3 = HorseMesh.head_point(0.3 + 0.035 * float(t), 0.05 * sx, -0.118)
				blob("bone", tp, Vector3(0.013, 0.024, 0.016), Color(0.8, 0.76, 0.6), ["Jaw", 1.0], 5)
				blob("bone", HorseMesh.head_point(0.3 + 0.035 * float(t), 0.056 * sx, -0.082), Vector3(0.013, 0.024, 0.016), Color(0.8, 0.76, 0.6), ["Head", 1.0], 5)
		for k: int in 6:
			var np: Array = _neck_path()
			var fr: Array = _neck_at(np, 1 + (k % 4))
			var root: Vector3 = (fr[0] as Vector3) - (fr[1] as Vector3) * (float(fr[3]) * 0.96) + Vector3.RIGHT * (0.05 * (float(k % 3) - 1.0))
			var ln: float = 0.16 + 0.07 * float((k * 5) % 3)
			var nb: String = np[1 + (k % 4)][5]
			var mb: String = np[1 + (k % 4)][6]
			card("coat", [[root, Vector3.RIGHT * 0.035, [nb, 1.0]], [root + Vector3(0.01, -ln * 0.5, 0.01), Vector3.RIGHT * 0.03, [nb, 0.5, mb, 0.5]],
				[root + Vector3(-0.01, -ln, 0.02), Vector3.RIGHT * 0.012, [mb, 1.0]]], HorseMesh.DEAD_HIDE.darkened(0.2), HorseMesh.DEAD_DARK)
		for t: int in 4:
			var x: float = -0.027 + 0.018 * float(t)
			blob("bone", HorseMesh.head_point(0.6, x, -0.085), Vector3(0.009, 0.026, 0.011), Color(0.82, 0.78, 0.62), ["Jaw", 1.0], 5)
			blob("bone", HorseMesh.head_point(0.622, x, -0.05), Vector3(0.009, 0.028, 0.011), Color(0.82, 0.78, 0.62), ["Head", 1.0], 5)

	func _ears() -> void:
		for sx: float in [-1.0, 1.0]:
			var bname: String = "EarL" if sx < 0.0 else "EarR"
			var b: Vector3 = HorseMesh.ear_base(sx)
			var up: Vector3 = (Vector3(0.22 * sx, 1.0, -0.16)).normalized()
			var u: Vector3 = Vector3(1, 0, 0) - up * up.x
			u = u.normalized()
			var v: Vector3 = up.cross(u).normalized()
			var h: float = 0.19
			if dead and sx > 0.0:
				h = 0.09   # the right ear torn off short
			var rings: Array = []
			for q: Array in [[-0.02, 0.034, 0.03], [0.04, 0.042, 0.026], [0.6, 0.03, 0.016], [1.0, 0.006, 0.004]]:
				var c: Vector3 = b + up * (h * float(q[0])) if float(q[0]) < 0.0 else b + up * (h * float(q[0]))
				rings.append(ring(c, u, v, float(q[1]), float(q[2]), 0.0, [bname, 1.0], _coat(c).darkened(0.2)))
			loft("coat", rings, 8, [], [false, true])

	func _leg(leg: int) -> void:
		var hind: bool = leg == HorseGait.LH or leg == HorseGait.RH
		var j: Array = HorseMesh.leg_joints(leg)
		var sx: float = signf((j[0] as Vector3).x)
		var nm: String = HorseGait.LEG_NAMES[leg]
		var a: String = nm + "_A"
		var b: String = nm + "_B"
		var c: String = nm + "_C"
		var d: String = nm + "_D"
		var thin: float = 0.8 if dead else 1.0
		var rings: Array = []
		# [point, lateral radius, fore-aft radius, weights, darkness 0..1]
		var secs: Array = []
		if hind:
			secs = [
				[Vector3(0.14 * sx, 1.42, 0.56), 0.12, 0.27, ["Hips", 1.0], 0.0],
				[Vector3(0.2 * sx, 1.2, 0.56), 0.165, 0.28, ["Hips", 0.6, a, 0.4], 0.0],
				[((j[0] as Vector3) + (j[1] as Vector3)) * 0.5 + Vector3(-0.03 * sx, 0, 0.04), 0.13, 0.235, [a, 1.0], 0.0],
				[(j[1] as Vector3) + Vector3(0, 0, 0.07), 0.105, 0.16, [a, 0.5, b, 0.5], 0.05],
				[((j[1] as Vector3) * 0.55 + (j[2] as Vector3) * 0.45), 0.08, 0.115, [b, 1.0], 0.2],
				[(j[2] as Vector3) + Vector3(0, 0.06, -0.02), 0.06, 0.085, [b, 0.8, c, 0.2], 0.5],
				[(j[2] as Vector3) + Vector3(0, -0.02, -0.02), 0.058, 0.088, [b, 0.3, c, 0.7], 0.7],
				[((j[2] as Vector3) * 0.65 + (j[3] as Vector3) * 0.35), 0.043, 0.056, [c, 1.0], 0.9],
				[((j[2] as Vector3) * 0.2 + (j[3] as Vector3) * 0.8), 0.041, 0.052, [c, 1.0], 1.0],
				[(j[3] as Vector3), 0.055, 0.064, [c, 0.5, d, 0.5], 1.0],
				[((j[3] as Vector3) + (j[4] as Vector3)) * 0.5, 0.045, 0.05, [d, 1.0], 1.0],
				[(j[4] as Vector3), 0.058, 0.062, [d, 1.0], 1.0]]
		else:
			secs = [
				[Vector3(0.14 * sx, 1.46, -0.5), 0.1, 0.2, ["Body", 1.0], 0.0],
				[Vector3(0.2 * sx, 1.2, -0.62), 0.125, 0.225, ["Body", 0.7, a, 0.3], 0.0],
				[Vector3(0.2 * sx, 1.02, -0.56), 0.1, 0.18, ["Body", 0.2, a, 0.8], 0.0],
				[(j[1] as Vector3) + Vector3(0, 0.0, -0.03), 0.09, 0.125, [a, 0.5, b, 0.5], 0.05],
				[((j[1] as Vector3) * 0.6 + (j[2] as Vector3) * 0.4) + Vector3(0, 0, -0.01), 0.074, 0.092, [b, 1.0], 0.25],
				[(j[2] as Vector3) + Vector3(0, 0.05, 0), 0.058, 0.066, [b, 0.8, c, 0.2], 0.6],
				[(j[2] as Vector3) + Vector3(0, -0.01, -0.006), 0.06, 0.07, [b, 0.4, c, 0.6], 0.75],
				[((j[2] as Vector3) * 0.7 + (j[3] as Vector3) * 0.3), 0.043, 0.05, [c, 1.0], 0.95],
				[((j[2] as Vector3) * 0.2 + (j[3] as Vector3) * 0.8), 0.04, 0.047, [c, 1.0], 1.0],
				[(j[3] as Vector3), 0.054, 0.06, [c, 0.5, d, 0.5], 1.0],
				[((j[3] as Vector3) + (j[4] as Vector3)) * 0.5, 0.044, 0.048, [d, 1.0], 1.0],
				[(j[4] as Vector3), 0.058, 0.062, [d, 1.0], 1.0]]
		for i: int in secs.size():
			var p0: Vector3 = secs[maxi(0, i - 1)][0]
			var p1: Vector3 = secs[mini(secs.size() - 1, i + 1)][0]
			var dir: Vector3 = (p1 - p0).normalized()
			var u: Vector3 = (Vector3.RIGHT - dir * dir.x).normalized()
			var v: Vector3 = u.cross(dir).normalized()   # fore-aft
			var cc: Vector3 = secs[i][0]
			var dark: float = float(secs[i][4])
			var col: Color = _coat(cc) if dead else _coat(cc).lerp(HorseMesh.COAT_DARK, dark)
			var k: float = (thin if dead else (1.18 if i >= 4 else 1.06)) if i >= 2 else 1.0
			rings.append(ring(cc, u, v, float(secs[i][1]) * k, float(secs[i][2]) * k, 0.0, secs[i][3], col))
		loft("coat", rings, 14, [], [false, false])
		# the hoof: a cone widening to the ground, its toe ahead
		var hc: Vector3 = j[4]
		var hg: Vector3 = j[5]
		var horn: Color = Color(0.09, 0.075, 0.065) if not dead else Color(0.2, 0.19, 0.17)
		var hr: Array = [
			ring(hc + Vector3(0, 0.005, 0), Vector3.RIGHT, Vector3.FORWARD, 0.06, 0.064, 0.0, [d, 1.0], horn),
			ring(hc.lerp(hg, 0.5) + Vector3(0, 0, -0.004), Vector3.RIGHT, Vector3.FORWARD, 0.07, 0.078, 0.0, [d, 1.0], horn),
			ring(hg + Vector3(0, 0.004, -0.008), Vector3.RIGHT, Vector3.FORWARD, 0.08, 0.094, 0.0, [d, 1.0], horn.lightened(0.12))]
		loft("hoof", hr, 10, [], [false, true], Callable(), 0.0, 0.0)   # (a flat sole)
		if not dead:
			# the feather: long hair from the back of the cannon over the fetlock to the hoof (the Noriker's)
			var f: Vector3 = j[3]
			var fr: Array = [
				ring(f + Vector3(0, 0.15, 0.014), Vector3.RIGHT, Vector3.FORWARD, 0.05, 0.062, 0.0, [c, 1.0], HorseMesh.COAT_DARK),
				ring(f + Vector3(0, 0.06, 0.024), Vector3.RIGHT, Vector3.FORWARD, 0.07, 0.092, 0.0, [c, 0.7, d, 0.3], HorseMesh.HAIR.lightened(0.03)),
				ring(f + Vector3(0, -0.03, 0.022), Vector3.RIGHT, Vector3.FORWARD, 0.082, 0.104, 0.0, [d, 1.0], HorseMesh.HAIR.lightened(0.05)),
				ring(Vector3(f.x, 0.07, (j[4] as Vector3).z + 0.035), Vector3.RIGHT, Vector3.FORWARD, 0.086, 0.11, 0.0, [d, 1.0], HorseMesh.HAIR.lightened(0.09))]
			loft("hair", fr, 10, [], [false, false])

	## The mane: locks falling down both sides of the crest (more on the off side), a roached ridge along the top, the
	## forelock between the ears. Roots ride the neck bones, tips the Mane bones (HorseRig sways those).
	func _mane() -> void:
		var path: Array = _neck_path()
		var cols: int = 22 if not dead else 9
		for sx: float in [1.0, -1.0]:
			# one sheet a side, draped from the crest down the neck: long on the off side, shorter on the near side
			var grid: Array = []
			for ci: int in cols + 1:
				var t: float = 0.06 + 0.9 * float(ci) / float(cols)
				var f: float = t * float(path.size() - 1)
				var i0: int = mini(int(f), path.size() - 2)
				var k: float = f - float(i0)
				var f0: Array = _neck_at(path, i0)
				var f1: Array = _neck_at(path, i0 + 1)
				var c: Vector3 = (f0[0] as Vector3).lerp(f1[0] as Vector3, k)
				var v: Vector3 = ((f0[1] as Vector3).lerp(f1[1] as Vector3, k)).normalized()
				var ru: float = lerpf(float(f0[2]), float(f1[2]), k)
				var rv: float = lerpf(float(f0[3]), float(f1[3]), k)
				var narrow: float = lerpf(float(path[i0][3]), float(path[i0 + 1][3]), k)
				var nb: String = path[i0][5] if k < 0.5 else path[i0 + 1][5]
				var mb: String = path[i0][6] if k < 0.5 else path[i0 + 1][6]
				var ragged: float = 0.78 + 0.3 * absf(sin(float(ci) * 2.7 + sx)) + 0.12 * sin(float(ci) * 0.9)
				var length: float = (0.42 - 0.16 * t) * ragged * (1.0 if sx > 0.0 else 0.55)
				if dead:
					length *= 0.25 + 0.75 * absf(sin(float(ci) * 3.3 + sx * 1.3))   # hanks of it gone
				var col: Array = []
				var rows: int = 5
				for r: int in rows + 1:
					var q: float = float(r) / float(rows)
					var th: float = minf(q * 2.0, 1.0) * 1.35            # over the crest's shoulder in the first half...
					var top: float = (cos(th) + 1.0) * 0.5
					var wide: float = 1.0 - narrow * top * top
					var lap: float = minf(q * 5.0, 1.0)
					var p: Vector3 = c + Vector3.RIGHT * (sx * (ru * sin(th) * wide + 0.014 * lap - 0.01 * (1.0 - lap) + 0.012 * q)) + v * (rv * cos(th) + 0.012)
					if q > 0.5:
						p += Vector3.DOWN * ((q - 0.5) * 2.0 * length)   # ...then hanging
					else:
						p += v * (0.035 * (1.0 - q * 2.0))               # the roots stand up along the crest
					var w: Array = [nb, 1.0 - q, mb, q] if q > 0.0 else [nb, 1.0]
					var shadec: float = 0.04 * absf(sin(float(ci) * 5.1 + float(r)))
					col.append([p, w, HorseMesh.HAIR.lightened(shadec + 0.05 * q)])
				grid.append(col)
				if dead and (ci * 7 + int(sx)) % 3 != 0:
					# what is left of it: thin wisps, each on its own
					var along: Vector3 = ((f1[0] as Vector3) - (f0[0] as Vector3)).normalized()
					var wisp: Array = []
					for e: Array in col:
						wisp.append([e[0], along * (0.012 + 0.008 * absf(sin(float(ci) * 1.9))), e[1]])
					card("hair", wisp, HorseMesh.HAIR, HorseMesh.HAIR.lightened(0.1))
			if not dead:
				sheet("hair", grid)
		if not dead:
			var fl: Array = []
			for q2: int in 4:
				var s2: float = -0.03 + 0.075 * float(q2)
				fl.append([HorseMesh.head_point(s2, 0.0, 0.134 + 0.012 * sin(float(q2) * 1.2)), Vector3.RIGHT * (0.055 - 0.012 * float(q2)), ["Head", 1.0 - float(q2) / 3.0, "Forelock", float(q2) / 3.0]])
			card("hair", fl, HorseMesh.HAIR, HorseMesh.HAIR.lightened(0.07))

	## A sheet through a grid of [position, weights, colour] columns (hair: two-sided by its material).
	func sheet(sname: String, grid: Array) -> void:
		var s: _Surf = surf(sname)
		var base: Array = []
		for col: Array in grid:
			base.append(s.v.size())
			for e: Array in col:
				vert(s, e[0], e[2], e[1])
		for ci: int in grid.size() - 1:
			var rows: int = (grid[ci] as Array).size()
			for r: int in rows - 1:
				var a: int = int(base[ci]) + r
				var b: int = int(base[ci + 1]) + r
				var inside: Vector3 = Vector3(0, s.v[a].y, s.v[a].z)
				tri(s, a, b, b + 1, inside)
				tri(s, a, b + 1, a + 1, inside)

	func _tail() -> void:
		var radii: Array = [0.046, 0.066, 0.084, 0.086, 0.056, 0.012]
		if dead:
			radii = [0.035, 0.03, 0.026, 0.04, 0.034, 0.008]   # the dock and a few strands
		var rings: Array = []
		var n: int = HorseMesh.TAIL.size()
		for i: int in n:
			var a: Vector3 = HorseMesh.TAIL[maxi(0, i - 1)]
			var b: Vector3 = HorseMesh.TAIL[mini(n - 1, i + 1)]
			var d: Vector3 = (b - a).normalized()
			var v: Vector3 = Vector3.RIGHT.cross(d).normalized()
			var bone: String = "Tail%d" % mini(i + 1, 5)
			var w: Array = [bone, 1.0] if i == 0 or i >= 5 else ["Tail%d" % i, 0.5, bone, 0.5]
			rings.append(ring(HorseMesh.TAIL[i], Vector3.RIGHT, v, float(radii[i]), float(radii[i]) * 0.8, 0.0, w, HorseMesh.HAIR.lightened(0.02 + 0.03 * float(i % 2))))
		loft("hair", rings, 10, [], [true, true])
		# strands over it, each ending at its own length (the skirt's ragged end)
		var strands: int = 9 if not dead else 4
		for k: int in strands:
			var ang: float = TAU * float(k) / float(strands) + 0.3
			var reach: float = rng.randf_range(0.7, 1.25)
			var pts: Array = []
			for i: int in n:
				var a2: Vector3 = HorseMesh.TAIL[maxi(0, i - 1)]
				var b2: Vector3 = HorseMesh.TAIL[mini(n - 1, i + 1)]
				var d2: Vector3 = (b2 - a2).normalized()
				var v2: Vector3 = Vector3.RIGHT.cross(d2).normalized()
				var r: float = float(radii[i]) * 1.06 + 0.004
				var c: Vector3 = (HorseMesh.TAIL[i] as Vector3)
				if i == n - 1:
					c += d2 * (0.22 * (reach - 1.0))
				var p: Vector3 = c + Vector3.RIGHT * (cos(ang) * r) + v2 * (sin(ang) * r * 0.8)
				var half: Vector3 = (Vector3.RIGHT * -sin(ang) + v2 * cos(ang)) * (r * 0.42)
				var bone2: String = "Tail%d" % mini(i + 1, 5)
				pts.append([p, half, [bone2, 1.0] if i == 0 or i >= 5 else ["Tail%d" % i, 0.5, bone2, 0.5]])
			card("hair", pts, HorseMesh.HAIR.lightened(rng.randf_range(0.02, 0.09)), HorseMesh.HAIR.lightened(0.1))

	# ------------------------------------------------------------------ the living horse's tack

	func _tack() -> void:
		var leather: Color = Color(0.2, 0.105, 0.055)
		var loden: Color = Color(0.17, 0.215, 0.16)
		var stripe: Color = Color(0.3, 0.075, 0.06)
		# the blanket over the back, a stripe along its edges
		var br: Array = []
		for z: float in [-0.5, -0.4, -0.2, 0.0, 0.2, 0.3]:
			var st: Array = _barrel_at(z)
			var edge: bool = z < -0.45 or z > 0.25
			var c: Vector3 = Vector3(0, (float(st[1]) + float(st[2])) * 0.5, z)
			var col: Callable = func(th: float) -> Color:
				var side: float = absf(wrapf(th, -PI, PI))
				return stripe if edge or side > 1.8 else loden
			br.append(ring(c, Vector3.RIGHT, Vector3.UP, float(st[3]), (float(st[1]) - float(st[2])) * 0.5, float(st[4]), ["Body", 1.0], col))
		loft("cloth", br, 18, [-0.31, 0.31], [false, false], Callable(), 0.014)
		# the saddle: a seat rising to a pommel and a cantle, flaps down the sides
		var sr: Array = []
		for q: Array in [[-0.44, 0.02, 0.1], [-0.4, 0.09, 0.17], [-0.3, 0.05, 0.2], [-0.14, 0.03, 0.22], [0.02, 0.045, 0.23], [0.12, 0.1, 0.22], [0.17, 0.03, 0.14]]:
			var st: Array = _barrel_at(float(q[0]))
			var c: Vector3 = Vector3(0, float(st[1]) - 0.24, float(q[0]))
			sr.append(ring(c, Vector3.RIGHT, Vector3.UP, float(q[2]) * 1.5, 0.24 + float(q[1]) + 0.02, 0.35, ["Body", 1.0], leather.lightened(0.04)))
		loft("leather", sr, 12, [-0.2, 0.2], [false, false])
		for sx: float in [-1.0, 1.0]:
			var fr: Array = []
			for z: float in [-0.36, -0.2, 0.02, 0.1]:
				var st: Array = _barrel_at(z)
				fr.append(ring(Vector3(0, (float(st[1]) + float(st[2])) * 0.5, z), Vector3.RIGHT, Vector3.UP, float(st[3]), (float(st[1]) - float(st[2])) * 0.5, float(st[4]), ["Body", 1.0], leather))
			loft("leather", fr, 6, [0.1 * sx, 0.27 * sx], [false, false], Callable(), 0.03)
			# the stirrup leather and the iron
			var top: Vector3 = _barrel_point(_barrel_at(-0.2), TAU * 0.2 * sx, 0.04)
			var iron: Vector3 = Vector3(top.x + 0.03 * sx, 0.92, -0.2)
			tube("leather", [top, top.lerp(iron, 0.5) + Vector3(0.02 * sx, 0, 0), iron + Vector3(0, 0.12, 0)], [0.016, 0.005], leather.darkened(0.2), [["Body", 1.0]], 4)
			var ip: Array = []
			for q: int in 9:
				var a: float = PI * float(q) / 8.0
				ip.append(iron + Vector3(0, 0.12 * sin(a), 0.06 * cos(a)))   # an arch from the tread up to the leather
			tube("metal", ip, 0.008, Color(0.42, 0.4, 0.38), [["Body", 1.0]], 5)
			tube("metal", [iron + Vector3(0, 0.01, -0.06), iron + Vector3(0, 0.01, 0.06)], [0.012, 0.006], Color(0.42, 0.4, 0.38), [["Body", 1.0]], 4)
		# the girth round the barrel behind the elbow
		var gr: Array = []
		for z: float in [-0.335, -0.265]:
			var st: Array = _barrel_at(z)
			gr.append(ring(Vector3(0, (float(st[1]) + float(st[2])) * 0.5, z), Vector3.RIGHT, Vector3.UP, float(st[3]), (float(st[1]) - float(st[2])) * 0.5, float(st[4]), ["Body", 1.0], leather.darkened(0.25)))
		loft("leather", gr, 20, [0.2, 0.8], [false, false], Callable(), 0.012)
		_bridle(leather)

	func _bridle(leather: Color) -> void:
		var w: Array = [["Head", 1.0]]
		var strap: Array = [0.012, 0.004]
		# noseband, browband, the strap behind the ears, the throat latch
		for q: Array in [[0.4, 0.092, 0.124, 0.016, 1.0], [0.035, 0.118, 0.13, 0.012, 0.5], [-0.035, 0.074, 0.078, 0.0, 0.5]]:
			var pts: Array = []
			var n: int = 14
			var span: float = float(q[4])
			for i: int in n + 1:
				var th: float = TAU * (span * (float(i) / float(n) - 0.5))
				pts.append(HorseMesh.head_point(float(q[0]), sin(th) * (float(q[1]) + 0.008), cos(th) * (float(q[2]) + 0.008) - float(q[3])))
			tube("leather", pts, strap, leather.darkened(0.15), w, 4, HorseMesh.HEAD_AXIS)
		for sx: float in [-1.0, 1.0]:
			# the cheekpiece from the browband to the bit ring, the ring, the rein back to the pommel
			var ringp: Vector3 = HorseMesh.head_point(0.5, 0.086 * sx, -0.05)
			tube("leather", [HorseMesh.head_point(0.03, 0.125 * sx, 0.0), HorseMesh.head_point(0.2, 0.131 * sx, -0.02), HorseMesh.head_point(0.4, 0.102 * sx, -0.03), ringp], strap, leather.darkened(0.15), w, 4, Vector3(sx, 0, 0).cross(HorseMesh.HEAD_AXIS))
			var rp: Array = []
			for i: int in 11:
				var a: float = TAU * float(i) / 10.0
				rp.append(ringp + Vector3(0.004 * sx, 0, 0) + HorseMesh.HEAD_AXIS * (0.024 * cos(a)) + HorseMesh.HEAD_FRONT * (0.024 * sin(a)))
			tube("metal", rp, 0.004, Color(0.5, 0.48, 0.44), w, 4)
			var rein: Array = [ringp, Vector3(0.135 * sx, 1.6, -1.2), Vector3(0.185 * sx, 1.5, -0.94), Vector3(0.2 * sx, 1.55, -0.68), Vector3(0.035 * sx, 1.71, -0.42)]
			var rw: Array = [["Head", 1.0], ["Neck3", 0.6, "Neck2", 0.4], ["Neck2", 0.4, "Neck1", 0.6], ["Neck1", 0.3, "Body", 0.7], ["Body", 1.0]]
			tube("leather", rein, [0.009, 0.003], leather.darkened(0.1), rw, 4, Vector3.UP)

	# ------------------------------------------------------------------ the dead horse's harness

	func _dead_dress() -> void:
		var leather: Color = Color(0.085, 0.07, 0.06)
		var iron: Color = Color(0.2, 0.15, 0.12)
		# the draught collar round the base of the neck, leaning back with the shoulder
		var cc: Vector3 = Vector3(0, 1.3, -0.69)
		var axis: Vector3 = Vector3(0, 0.45, -0.89).normalized()
		var up: Vector3 = Vector3.RIGHT.cross(axis).normalized()
		if up.y < 0.0:
			up = -up
		var col_pts: Array = []
		var hame_l: Array = []
		var hame_r: Array = []
		for i: int in 21:
			var a: float = TAU * float(i) / 20.0
			var p: Vector3 = cc + Vector3.RIGHT * (0.235 * sin(a)) + up * (0.35 * cos(a))
			col_pts.append(p)
			if i <= 9:
				hame_r.append(p + axis * 0.05 + Vector3.RIGHT * 0.012 * sin(a))
			if i >= 11:
				hame_l.append(p + axis * 0.05 + Vector3.RIGHT * 0.012 * sin(a))
		tube("leather", col_pts, [0.06, 0.05], leather, [["Body", 0.8, "Neck1", 0.2]], 8, axis)
		# the hames: iron bars down the collar's face, their knobs standing over the withers
		hame_r.insert(0, (hame_r[0] as Vector3) + up * 0.14 + Vector3.RIGHT * 0.05)
		hame_l.append((hame_l[hame_l.size() - 1] as Vector3) + up * 0.14 - Vector3.RIGHT * 0.05)
		for hp: Array in [hame_r, hame_l]:
			tube("metal", hp, 0.016, iron, [["Body", 0.8, "Neck1", 0.2]], 5, axis)
		blob("metal", hame_r[0], Vector3(0.028, 0.028, 0.028), iron.lightened(0.1), ["Body", 1.0], 6)
		blob("metal", hame_l[hame_l.size() - 1], Vector3(0.028, 0.028, 0.028), iron.lightened(0.1), ["Body", 1.0], 6)
		# the back strap over the spine to the crupper, a belly band, the traces back along the flanks
		var back: Array = []
		var back_w: Array = []
		for z: float in [-0.45, -0.2, 0.05, 0.3, 0.55, 0.8]:
			var st: Array = _barrel_at(z)
			back.append(Vector3(0, float(st[1]) + 0.012, z))
			var hk: float = clampf((z - 0.1) / 0.5, 0.0, 1.0)
			back_w.append(["Body", 1.0 - hk, "Hips", hk])
		tube("leather", back, [0.022, 0.006], leather, back_w, 4)
		var gr: Array = []
		var st2: Array = _barrel_at(-0.3)
		for z: float in [-0.33, -0.27]:
			gr.append(ring(Vector3(0, (float(st2[1]) + float(st2[2])) * 0.5, z), Vector3.RIGHT, Vector3.UP, float(st2[3]), (float(st2[1]) - float(st2[2])) * 0.5, float(st2[4]), ["Body", 1.0], leather))
		loft("leather", gr, 20, [0.0, 1.0], [false, false], Callable(), 0.012)
		for sx: float in [-1.0, 1.0]:
			var tr: Array = [Vector3(0.25 * sx, 1.2, -0.66)]
			for tz: Array in [[-0.35, 1.06], [0.0, 0.98], [0.35, 1.0], [0.62, 1.06]]:
				var tst: Array = _barrel_at(float(tz[0]))
				var half_h: float = (float(tst[1]) - float(tst[2])) * 0.5
				var cth: float = clampf((float(tz[1]) - (float(tst[1]) + float(tst[2])) * 0.5) / half_h, -1.0, 1.0)
				var tp: Vector3 = _barrel_point(tst, acos(cth), 0.018)
				tr.append(Vector3(absf(tp.x) * sx, tp.y, tp.z))
			tr.append(Vector3(0.35 * sx, 0.86, 0.8))
			tube("metal", tr, [0.008, 0.008], iron.darkened(0.2), [["Body", 1.0], ["Body", 1.0], ["Body", 1.0], ["Body", 0.5, "Hips", 0.5], ["Hips", 1.0], ["Hips", 1.0]], 5)
