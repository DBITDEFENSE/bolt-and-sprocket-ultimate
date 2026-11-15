class_name ProcKit
extends RefCounted
## A small mesh kit for props built in code (T-249: the Sherman, the dive bomber, the bombs; our own work). Every call
## appends triangles to the surface of one material key; `commit()` gives one ArrayMesh with a surface per key (the
## caller maps keys to materials). Flat-shaded boxes and wedges, smooth cylinders, cones and lofts through rings of
## points. Every vertex carries a colour the materials multiply (vertex_color_use_as_albedo): `tint` for the next
## parts, and an optional height shading (`shade_y`: darker toward the ground, the grime of a vehicle's running gear).

var _st: Dictionary = {}          # key -> SurfaceTool
var _order: Array[String] = []
var tint: Color = Color.WHITE
## Height shading: below shade_y[0] the colour is multiplied by shade_k, ramping to none at shade_y[1] (local y).
var shade_y: Vector2 = Vector2(-1000.0, -999.0)
var shade_k: Color = Color(0.62, 0.58, 0.5)
var xf: Transform3D = Transform3D.IDENTITY   # applied to everything appended (a sub-assembly's frame)
## Undersides painted another colour (an aircraft's belly): faces whose normal points down take `belly` (alpha 0 = off).
var belly: Color = Color(0, 0, 0, 0)
## Edge wear for the next vertices (T-253): written as 1 - alpha of the vertex colour; the vehicle paint shader chips
## the paint there first. The bevelled shapes set it on their chamfers themselves.
var edge: float = 0.0


func _surface(key: String) -> SurfaceTool:
	if not _st.has(key):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
		_order.append(key)
	return _st[key]


func keys() -> Array[String]:
	return _order.duplicate()


func _col(p: Vector3) -> Color:
	var c: Color = tint
	if p.y < shade_y.y:
		var k: float = clampf((p.y - shade_y.x) / maxf(0.001, shade_y.y - shade_y.x), 0.0, 1.0)
		c = c * shade_k.lerp(Color.WHITE, k)
		c.a = tint.a
	return c


func _v(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	var wp: Vector3 = xf * p
	var wn: Vector3 = (xf.basis * n).normalized()
	var c: Color = _col(wp)
	if belly.a > 0.0:
		c = c.lerp(Color(belly.r, belly.g, belly.b, c.a), smoothstep(0.05, -0.35, wn.y))
	c.a = clampf(c.a * (1.0 - edge), 0.0, 1.0)
	st.set_color(c)
	st.set_normal(wn)
	st.set_uv(Vector2(wp.x + wp.y, wp.z + wp.y))
	st.add_vertex(wp)


## One triangle (counter-clockwise seen from outside), flat.
func tri(key: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	n = n.normalized()
	var st: SurfaceTool = _surface(key)
	_v(st, a, n)
	_v(st, c, n)
	_v(st, b, n)


## A triangle turned to face `out` whatever order its points come in.
func tri_facing(key: String, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b - a).cross(c - a).dot(out) >= 0.0:
		tri(key, a, b, c)
	else:
		tri(key, a, c, b)


## A smooth triangle: emitted clockwise as seen from the side its normals point to (Godot's front faces).
func _emit(st: SurfaceTool, pa: Vector3, na: Vector3, pb: Vector3, nb: Vector3, pc: Vector3, nc: Vector3) -> void:
	var fn: Vector3 = (pb - pa).cross(pc - pa)
	if fn.length_squared() < 1e-16:
		return
	if fn.dot(na + nb + nc) > 0.0:
		_v(st, pa, na)
		_v(st, pc, nc)
		_v(st, pb, nb)
	else:
		_v(st, pa, na)
		_v(st, pb, nb)
		_v(st, pc, nc)


## A flat quad a-b-c-d (counter-clockwise seen from outside).
func quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(key, a, b, c)
	tri(key, a, c, d)


## A box of `size` centred at `c` in the frame `basis` (rotation only).
func box(key: String, c: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	var h: Vector3 = size * 0.5
	var p: Array[Vector3] = []
	for i: int in 8:
		p.append(c + basis * Vector3(h.x if (i & 1) != 0 else -h.x, h.y if (i & 2) != 0 else -h.y, h.z if (i & 4) != 0 else -h.z))
	quad(key, p[0], p[2], p[3], p[1])   # -z
	quad(key, p[4], p[5], p[7], p[6])   # +z
	quad(key, p[0], p[4], p[6], p[2])   # -x
	quad(key, p[1], p[3], p[7], p[5])   # +x
	quad(key, p[2], p[6], p[7], p[3])   # +y
	quad(key, p[0], p[1], p[5], p[4])   # -y


## A box between two corners (axis aligned).
func block(key: String, a: Vector3, b: Vector3) -> void:
	box(key, (a + b) * 0.5, (b - a).abs())


## A beam of square section `t` from `a` to `b`.
func beam(key: String, a: Vector3, b: Vector3, t: float, t2: float = -1.0) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 1e-5:
		return
	box(key, (a + b) * 0.5, Vector3(t, t if t2 < 0.0 else t2, l), _look(d))


## A basis whose +Z runs along `d`.
static func _look(d: Vector3) -> Basis:
	var z: Vector3 = d.normalized()
	var up: Vector3 = Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x: Vector3 = up.cross(z).normalized()
	var y: Vector3 = z.cross(x).normalized()
	return Basis(x, y, z)


## A cylinder (or a cone frustum) from `a` to `b`, radii r0 at a and r1 at b, `seg` sides, smooth sides, flat caps.
func cyl(key: String, a: Vector3, b: Vector3, r0: float, r1: float, seg: int = 16, caps: bool = true) -> void:
	var d: Vector3 = b - a
	if d.length() < 1e-5:
		return
	var bs: Basis = _look(d)
	var slope: float = (r0 - r1) / d.length()
	var st: SurfaceTool = _surface(key)
	for i: int in seg:
		var a0: float = TAU * float(i) / float(seg)
		var a1: float = TAU * float(i + 1) / float(seg)
		var u0: Vector3 = bs * Vector3(cos(a0), sin(a0), 0)
		var u1: Vector3 = bs * Vector3(cos(a1), sin(a1), 0)
		var n0: Vector3 = (u0 + bs.z * slope).normalized()
		var n1: Vector3 = (u1 + bs.z * slope).normalized()
		var p00: Vector3 = a + u0 * r0
		var p01: Vector3 = a + u1 * r0
		var p10: Vector3 = b + u0 * r1
		var p11: Vector3 = b + u1 * r1
		_emit(st, p00, n0, p01, n1, p11, n1)
		_emit(st, p00, n0, p11, n1, p10, n0)
		if caps:
			if r0 > 0.0:
				tri(key, a, p01, p00)
			if r1 > 0.0:
				tri(key, b, p10, p11)


## A ring (a tube's wall with a hole): outer radius ro, inner ri, from a to b, both faces and the edges.
func ring(key: String, a: Vector3, b: Vector3, ro: float, ri: float, seg: int = 20) -> void:
	var d: Vector3 = b - a
	var bs: Basis = _look(d)
	for i: int in seg:
		var a0: float = TAU * float(i) / float(seg)
		var a1: float = TAU * float(i + 1) / float(seg)
		var u0: Vector3 = bs * Vector3(cos(a0), sin(a0), 0)
		var u1: Vector3 = bs * Vector3(cos(a1), sin(a1), 0)
		quad(key, a + u0 * ro, a + u1 * ro, b + u1 * ro, b + u0 * ro)
		quad(key, b + u0 * ri, b + u1 * ri, a + u1 * ri, a + u0 * ri)
		quad(key, a + u0 * ri, a + u1 * ri, a + u1 * ro, a + u0 * ro)
		quad(key, b + u0 * ro, b + u1 * ro, b + u1 * ri, b + u0 * ri)


## A loft through rings of points (each ring the same count, in order round it), smooth across the rings' points;
## caps the first and last ring with a fan when asked.
func loft(key: String, rings: Array, closed: bool = true, cap0: bool = true, cap1: bool = true) -> void:
	if rings.size() < 2:
		return
	var n: int = (rings[0] as PackedVector3Array).size()
	var st: SurfaceTool = _surface(key)
	var cnt: int = n if closed else n - 1
	for r: int in rings.size() - 1:
		var A: PackedVector3Array = rings[r]
		var B: PackedVector3Array = rings[r + 1]
		var ca: Vector3 = _centre(A)
		var cb: Vector3 = _centre(B)
		for i: int in cnt:
			var j: int = (i + 1) % n
			var na: Vector3 = _ring_normal(rings, r, i, ca)
			var naj: Vector3 = _ring_normal(rings, r, j, ca)
			var nb: Vector3 = _ring_normal(rings, r + 1, i, cb)
			var nbj: Vector3 = _ring_normal(rings, r + 1, j, cb)
			_emit(st, A[i], na, A[j], naj, B[j], nbj)
			_emit(st, A[i], na, B[j], nbj, B[i], nb)
	if cap0:
		var c0: Vector3 = _centre(rings[0])
		var R0: PackedVector3Array = rings[0]
		var o0: Vector3 = c0 - _centre(rings[1])
		for i: int in cnt:
			tri_facing(key, c0, R0[(i + 1) % n], R0[i], o0)
	if cap1:
		var last: PackedVector3Array = rings[rings.size() - 1]
		var c1: Vector3 = _centre(last)
		var o1: Vector3 = c1 - _centre(rings[rings.size() - 2])
		for i: int in cnt:
			tri_facing(key, c1, last[i], last[(i + 1) % n], o1)


static func _centre(r: PackedVector3Array) -> Vector3:
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in r:
		c += p
	return c / float(maxi(1, r.size()))


## The outward normal at ring r, point i: across the ring (from the neighbours) crossed with along the loft.
func _ring_normal(rings: Array, r: int, i: int, c: Vector3) -> Vector3:
	var R: PackedVector3Array = rings[r]
	var n: int = R.size()
	var t: Vector3 = R[(i + 1) % n] - R[(i - 1 + n) % n]
	var a: Vector3 = (rings[mini(r + 1, rings.size() - 1)] as PackedVector3Array)[i] - (rings[maxi(r - 1, 0)] as PackedVector3Array)[i]
	var nn: Vector3 = a.cross(t)
	var out: Vector3 = R[i] - c
	if nn.length_squared() < 1e-12:
		return out.normalized()
	nn = nn.normalized()
	return nn if nn.dot(out) >= 0.0 else -nn


## A ring of `n` points round `c` in the plane of axes (u, v): a superellipse of half sizes (a, b) and exponent `e`
## (2 an ellipse, higher a rounded rectangle); `squeeze` narrows the +v half (a turret's tumblehome).
static func superellipse(c: Vector3, u: Vector3, v: Vector3, a: float, b: float, e: float, n: int, squeeze: float = 0.0) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for i: int in n:
		var t: float = TAU * float(i) / float(n)
		var ct: float = cos(t)
		var s: float = sin(t)
		var x: float = signf(ct) * pow(absf(ct), 2.0 / e) * a
		var y: float = signf(s) * pow(absf(s), 2.0 / e) * b
		if y > 0.0:
			x *= 1.0 - squeeze * (y / b)
		out.append(c + u * x + v * y)
	return out


## A flat star (five points) facing `n` at `c`, outer radius r (the inner 0.382 r), drawn on the side of the normal.
func star(key: String, c: Vector3, n: Vector3, up: Vector3, r: float) -> void:
	var nz: Vector3 = n.normalized()
	var ux: Vector3 = up.cross(nz).normalized()
	var uy: Vector3 = nz.cross(ux).normalized()
	var pts: Array[Vector3] = []
	for i: int in 10:
		var a: float = PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = r if i % 2 == 0 else r * 0.382
		pts.append(c + (ux * cos(a) + uy * sin(a)) * rr)
	for i: int in 10:
		tri(key, c, pts[i], pts[(i + 1) % 10])


# ================================================================== T-253: bevels, lathes, tubes, lumps

## A smooth quad a-b-c-d with a normal per corner (a bevel's strip, a bent sheet).
func squad(key: String, a: Vector3, na: Vector3, b: Vector3, nb: Vector3, c: Vector3, nc: Vector3, d: Vector3, nd: Vector3) -> void:
	var st: SurfaceTool = _surface(key)
	_emit(st, a, na, b, nb, c, nc)
	_emit(st, a, na, c, nc, d, nd)


## A box with its twelve edges chamfered by `bevel` (the chamfers shaded round and marked as edges for the paint's
## wear). `c` its centre, `size` its full size, in the frame `basis`.
func bbox(key: String, c: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY, bevel: float = 0.012) -> void:
	var h: Vector3 = size * 0.5
	var bv: float = minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.45)
	if bv <= 0.0005:
		box(key, c, size, basis)
		return
	var e0: float = edge
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	# the six faces, inset
	for ai: int in 3:
		var u: Vector3 = axes[(ai + 1) % 3]
		var v: Vector3 = axes[(ai + 2) % 3]
		var hu: float = h[(ai + 1) % 3] - bv
		var hv: float = h[(ai + 2) % 3] - bv
		for sg: float in [-1.0, 1.0]:
			var nrm: Vector3 = axes[ai] * sg
			var o: Vector3 = nrm * h[ai]
			var p0: Vector3 = c + basis * (o - u * hu - v * hv)
			var p1: Vector3 = c + basis * (o + u * hu - v * hv)
			var p2: Vector3 = c + basis * (o + u * hu + v * hv)
			var p3: Vector3 = c + basis * (o - u * hu + v * hv)
			var wn: Vector3 = basis * nrm
			tri_facing(key, p0, p1, p2, wn)
			tri_facing(key, p0, p2, p3, wn)
	# the twelve chamfers: between the faces of axes a and b, running along the third
	edge = maxf(e0, 0.85)
	for ai2: int in 3:
		var bi: int = (ai2 + 1) % 3
		var ci: int = (ai2 + 2) % 3
		for sa: float in [-1.0, 1.0]:
			for sb: float in [-1.0, 1.0]:
				var na: Vector3 = axes[ai2] * sa
				var nb: Vector3 = axes[bi] * sb
				var l: Vector3 = axes[ci] * (h[ci] - bv)
				var pa: Vector3 = na * h[ai2] + nb * (h[bi] - bv)
				var pb: Vector3 = na * (h[ai2] - bv) + nb * h[bi]
				squad(key, c + basis * (pa - l), basis * na, c + basis * (pa + l), basis * na,
					c + basis * (pb + l), basis * nb, c + basis * (pb - l), basis * nb)
	# the eight corners
	var st: SurfaceTool = _surface(key)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var px: Vector3 = Vector3(sx * h.x, sy * (h.y - bv), sz * (h.z - bv))
				var py: Vector3 = Vector3(sx * (h.x - bv), sy * h.y, sz * (h.z - bv))
				var pz: Vector3 = Vector3(sx * (h.x - bv), sy * (h.y - bv), sz * h.z)
				_emit(st, c + basis * px, basis * Vector3(sx, 0, 0), c + basis * py, basis * Vector3(0, sy, 0), c + basis * pz, basis * Vector3(0, 0, sz))
	edge = e0


## A chamfered box between two corners (axis aligned).
func bblock(key: String, a: Vector3, b: Vector3, bevel: float = 0.012) -> void:
	bbox(key, (a + b) * 0.5, (b - a).abs(), Basis.IDENTITY, bevel)


## A prism: the polygon `poly` (in the plane of `frame`'s x and y, any winding, convex or mildly concave) pushed
## `half` to each side along the frame's z, the rims of the two end faces chamfered by `bevel`.
func prism(key: String, poly: PackedVector2Array, frame: Transform3D, half: float, bevel: float = 0.0) -> void:
	var n: int = poly.size()
	if n < 3:
		return
	var pts: PackedVector2Array = poly.duplicate()
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	var bv: float = minf(bevel, half * 0.45)
	var inner: PackedVector2Array = pts
	if bv > 0.0005:
		inner = PackedVector2Array()
		for i: int in n:
			var a: Vector2 = pts[(i - 1 + n) % n]
			var b: Vector2 = pts[i]
			var c2: Vector2 = pts[(i + 1) % n]
			var e1: Vector2 = (b - a).normalized()
			var e2: Vector2 = (c2 - b).normalized()
			var n1: Vector2 = Vector2(-e1.y, e1.x)
			var n2: Vector2 = Vector2(-e2.y, e2.x)
			var m: Vector2 = n1 + n2
			var ml: float = m.length()
			if ml < 0.05:
				inner.append(b + n1 * bv)
			else:
				m /= ml
				inner.append(b + m * minf(bv / maxf(0.25, m.dot(n1)), bv * 3.0))
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(inner)
	var e0: float = edge
	for sg: float in [-1.0, 1.0]:
		var zc: float = sg * half
		var wn: Vector3 = frame.basis * Vector3(0, 0, sg)
		for t: int in range(0, idx.size(), 3):
			tri_facing(key, frame * Vector3(inner[idx[t]].x, inner[idx[t]].y, zc), frame * Vector3(inner[idx[t + 1]].x, inner[idx[t + 1]].y, zc),
				frame * Vector3(inner[idx[t + 2]].x, inner[idx[t + 2]].y, zc), wn)
	for i2: int in n:
		var j: int = (i2 + 1) % n
		var en: Vector2 = (pts[j] - pts[i2]).normalized()
		var out: Vector3 = (frame.basis * Vector3(en.y, -en.x, 0)).normalized()
		var z1: float = half - bv
		var a0: Vector3 = frame * Vector3(pts[i2].x, pts[i2].y, -z1)
		var a1: Vector3 = frame * Vector3(pts[j].x, pts[j].y, -z1)
		var b0: Vector3 = frame * Vector3(pts[i2].x, pts[i2].y, z1)
		var b1: Vector3 = frame * Vector3(pts[j].x, pts[j].y, z1)
		tri_facing(key, a0, a1, b1, out)
		tri_facing(key, a0, b1, b0, out)
		if bv > 0.0005:
			edge = maxf(e0, 0.85)
			for sg2: float in [-1.0, 1.0]:
				var wz: Vector3 = (frame.basis * Vector3(0, 0, sg2)).normalized()
				var q0: Vector3 = frame * Vector3(pts[i2].x, pts[i2].y, sg2 * z1)
				var q1: Vector3 = frame * Vector3(pts[j].x, pts[j].y, sg2 * z1)
				var r0: Vector3 = frame * Vector3(inner[i2].x, inner[i2].y, sg2 * half)
				var r1: Vector3 = frame * Vector3(inner[j].x, inner[j].y, sg2 * half)
				squad(key, q0, out, q1, out, r1, wz, r0, wz)
			edge = e0


## A lathe: the profile `prof` (x = radius, y = distance along the axis) turned round the axis from `o` along
## `axis`. Each stretch of the profile shaded on its own slope (a machined part's crisp rings), smooth round the axis.
## A stretch whose radius reaches 0 closes the end. The profile runs so that its outside is on the right of its
## direction (radius out, then along the axis: a cylinder's wall is (r, 0) -> (r, l)).
func lathe(key: String, o: Vector3, axis: Vector3, prof: PackedVector2Array, seg: int = 16) -> void:
	var bs: Basis = _look(axis)
	var st: SurfaceTool = _surface(key)
	for s: int in prof.size() - 1:
		var p0: Vector2 = prof[s]
		var p1: Vector2 = prof[s + 1]
		var dl: Vector2 = p1 - p0
		if dl.length() < 1e-5:
			continue
		var nr: Vector2 = Vector2(dl.y, -dl.x).normalized()   # (radial, axial) of the outward normal
		for i: int in seg:
			var a0: float = TAU * float(i) / float(seg)
			var a1: float = TAU * float(i + 1) / float(seg)
			var u0: Vector3 = bs * Vector3(cos(a0), sin(a0), 0)
			var u1: Vector3 = bs * Vector3(cos(a1), sin(a1), 0)
			var n0: Vector3 = (u0 * nr.x + bs.z * nr.y).normalized()
			var n1: Vector3 = (u1 * nr.x + bs.z * nr.y).normalized()
			var q00: Vector3 = o + bs.z * p0.y + u0 * p0.x
			var q01: Vector3 = o + bs.z * p0.y + u1 * p0.x
			var q10: Vector3 = o + bs.z * p1.y + u0 * p1.x
			var q11: Vector3 = o + bs.z * p1.y + u1 * p1.x
			if p0.x > 1e-5:
				_emit(st, q00, n0, q01, n1, q11, n1)
			if p1.x > 1e-5:
				_emit(st, q00, n0, q11, n1, q10, n0)


## A round tube along the points `pts` (a cable, a rail, a grab handle), smooth; `closed` joins the ends.
func tube(key: String, pts: PackedVector3Array, r: float, seg: int = 6, closed: bool = false, caps: bool = true) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var rings: Array = []
	var prev_u: Vector3 = Vector3.ZERO
	for i: int in n:
		var a: Vector3 = pts[(i - 1 + n) % n] if (closed or i > 0) else pts[i]
		var b: Vector3 = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
		var t: Vector3 = (b - a).normalized()
		var u: Vector3 = prev_u - t * prev_u.dot(t)
		if u.length_squared() < 1e-6:
			u = _look(t).x
		u = u.normalized()
		prev_u = u
		var v: Vector3 = t.cross(u).normalized()
		var ring_pts: PackedVector3Array = PackedVector3Array()
		for k: int in seg:
			var ang: float = TAU * float(k) / float(seg)
			ring_pts.append(pts[i] + (u * cos(ang) + v * sin(ang)) * r)
		rings.append(ring_pts)
	if closed:
		rings.append(rings[0])
	loft(key, rings, true, caps and not closed, caps and not closed)


## A soft lump (a sandbag, a bedroll, a drift of snow, a pack): a superellipsoid of half sizes `half` in `basis`, its
## surface pushed about by `lump` (a fraction of the size), repeatable from `seed`. `flat` in 0..1 presses its
## underside flat; `end_r` is how wide its two ends stay (0.12 a rounded lump, 0.8 a roll's blunt end).
func blob(key: String, c: Vector3, half: Vector3, basis: Basis = Basis.IDENTITY, lump: float = 0.08, seed: int = 1, n: int = 10, rows: int = 5, flat: float = 0.0, e: float = 2.6, end_r: float = 0.12) -> void:
	var rings: Array = []
	for r: int in rows + 1:
		var v: float = -1.0 + 2.0 * float(r) / float(rows)
		var vy: float = signf(v) * pow(absf(v), 0.8)
		var rr: float = pow(maxf(0.0, 1.0 - pow(absf(vy), e)), 1.0 / e)
		rr = maxf(rr, end_r)
		var ring_pts: PackedVector3Array = PackedVector3Array()
		for i: int in n:
			var t: float = TAU * float(i) / float(n)
			var ct: float = cos(t)
			var s: float = sin(t)
			var x: float = signf(ct) * pow(absf(ct), 2.0 / minf(e, 3.0)) * rr
			var z: float = signf(s) * pow(absf(s), 2.0 / minf(e, 3.0)) * rr
			var hsh: float = sin(float(seed) * 12.9898 + float(i) * 78.233 + float(r) * 37.719) * 43758.5453
			var jit: float = 1.0 + lump * ((hsh - floor(hsh)) * 2.0 - 1.0)
			var y: float = vy
			if y < 0.0:
				y *= 1.0 - flat
			ring_pts.append(c + basis * (Vector3(x * half.x, y * half.y, z * half.z) * jit))
		rings.append(ring_pts)
	loft(key, rings, true, true, true)


## A bolt head (a low four-sided stud) standing on a surface at `at` along `n`.
func bolt(key: String, at: Vector3, n: Vector3, r: float = 0.014, h: float = 0.01) -> void:
	var e0: float = edge
	edge = maxf(e0, 0.6)
	var d: Vector3 = n.normalized()
	cyl(key, at - d * 0.001, at + d * h, r, r * 0.8, 4, false)
	var bs: Basis = _look(d)
	var top: Vector3 = at + d * h
	var q: Array[Vector3] = []
	for i: int in 4:
		var a0: float = TAU * float(i) / 4.0
		q.append(top + bs * Vector3(cos(a0), sin(a0), 0) * r * 0.8)
	tri_facing(key, q[0], q[1], q[2], d)
	tri_facing(key, q[0], q[2], q[3], d)
	edge = e0


## A row of `count` bolts from `a` to `b` (ends included).
func bolts(key: String, a: Vector3, b: Vector3, count: int, n: Vector3, r: float = 0.014, h: float = 0.01) -> void:
	for i: int in count:
		bolt(key, a.lerp(b, float(i) / float(maxi(1, count - 1))), n, r, h)


## A weld bead from `a` to `b`: a low four-sided ridge, marked as an edge.
func weld(key: String, a: Vector3, b: Vector3, r: float = 0.012) -> void:
	var e0: float = edge
	edge = maxf(e0, 0.5)
	cyl(key, a, b, r, r, 4, false)
	edge = e0


## A U of round bar standing on two feet (a lifting ring, a grab handle, a lamp's guard): feet at `a` and `b`,
## rising `h` along `up`.
func uring(key: String, a: Vector3, b: Vector3, up: Vector3, h: float, r: float = 0.012, seg: int = 5) -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	var u: Vector3 = up.normalized() * h
	pts.append(a)
	pts.append(a + u * 0.75)
	pts.append(a.lerp(b, 0.15) + u)
	pts.append(a.lerp(b, 0.85) + u)
	pts.append(b + u * 0.75)
	pts.append(b)
	tube(key, pts, r, seg, false, false)


const PAINT_SHADER: String = "res://gravelight/world/sherman/vehicle_paint.gdshader"
const PAINT_SHADER_SKY: String = "res://gravelight/world/sherman/vehicle_paint_sky.gdshader"
const PAINT_TEX: String = "res://assets/ours/world/vehicle_paint/"

## A material of the vehicle paint shader (vehicle_paint.gdshader) with `params` set over its defaults: tint, rough,
## metal, bump, grime, chips, chip_color, chip_cut, streaks, snow, mud, mud_y, burnt, glow, night_lift, scheme...
## `sky`: the variant the fog does not touch (an aircraft far up).
static func paint_material(params: Dictionary, sky: bool = false) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(PAINT_SHADER_SKY if sky else PAINT_SHADER) as Shader
	m.set_shader_parameter("mask_tex", load(PAINT_TEX + "paint_mask.png"))
	m.set_shader_parameter("normal_tex", load(PAINT_TEX + "paint_normal.png"))
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## The triangles of a mesh (all surfaces).
static func mesh_tris(m: Mesh) -> int:
	var t: int = 0
	if m == null:
		return 0
	for s: int in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var ix: Variant = arr[Mesh.ARRAY_INDEX]
		if ix != null and (ix as PackedInt32Array).size() > 0:
			t += (ix as PackedInt32Array).size() / 3
		else:
			t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t


## The mesh: one surface per key, in the order first used. Returns [ArrayMesh, keys].
func commit() -> Array:
	var m: ArrayMesh = ArrayMesh.new()
	var ks: Array[String] = []
	for k: String in _order:
		var st: SurfaceTool = _st[k]
		st.index()
		st.commit(m)
		ks.append(k)
	return [m, ks]
