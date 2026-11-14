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
