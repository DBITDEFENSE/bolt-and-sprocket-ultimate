extends RefCounted
## PropsHay (preloaded by the generators as `Hay`; no class_name, so a fresh checkout needs no class-cache rebuild).
## T-238 (the owner: "the haystacks feel half baked in the barn"): hay that reads as hay. A bale was one plain
## hay-coloured box with two dark strips; the pile was a 2 x 0.7 x 2.6 m block. Here: bales with bevelled, softly
## shaded edges, two twine bands, darker cut ends and loose stalks on top; a loose heap as a mound of lobes with a
## thin skirt and stalks lying over it; scattered stalks for a floor; a pitchfork. Everything is dressing (no
## colliders: the generator owns those and sizes a bale to its collider); the pieces are primitives or meshes tagged
## "batch", so the generator's static batching merges them like any Props block.

static var _soft: Dictionary = {}   # "x,y,z,b" -> ArrayMesh
static var _blob: SphereMesh


## A box with bevelled edges and corners, its normals blended across the bevels (so the edges read rounded), centred
## on the origin. Cached per size.
static func soft_box_mesh(size: Vector3, bevel: Vector3) -> ArrayMesh:
	var h: Vector3 = size * 0.5
	var b: Vector3 = Vector3(minf(bevel.x, h.x * 0.9), minf(bevel.y, h.y * 0.9), minf(bevel.z, h.z * 0.9))
	var key: String = "%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [size.x, size.y, size.z, b.x, b.y, b.z]
	if _soft.has(key):
		return _soft[key]
	var i: Vector3 = h - b
	var verts: PackedVector3Array = []
	var norms: PackedVector3Array = []
	for c: int in 8:   # corner c (bit 0 = +x, bit 1 = +y, bit 2 = +z), three vertices each: one on each face it touches
		var sg: Vector3 = Vector3(1.0 if c & 1 else -1.0, 1.0 if c & 2 else -1.0, 1.0 if c & 4 else -1.0)
		verts.append(Vector3(sg.x * h.x, sg.y * i.y, sg.z * i.z))
		norms.append(Vector3(sg.x, 0, 0))
		verts.append(Vector3(sg.x * i.x, sg.y * h.y, sg.z * i.z))
		norms.append(Vector3(0, sg.y, 0))
		verts.append(Vector3(sg.x * i.x, sg.y * i.y, sg.z * h.z))
		norms.append(Vector3(0, 0, sg.z))
	var tris: PackedInt32Array = []
	for s: int in 2:
		# the six faces: the four corners with that bit set (or clear), on that face's axis
		for axis: int in 3:
			var bit: int = 1 << axis
			var o1: int = 1 << ((axis + 1) % 3)
			var o2: int = 1 << ((axis + 2) % 3)
			var base: int = bit if s == 1 else 0
			_quad(tris, verts, (base) * 3 + axis, (base | o1) * 3 + axis, (base | o1 | o2) * 3 + axis, (base | o2) * 3 + axis)
		# the twelve edge bevels: an edge runs along `axis` between two corners; it joins the two faces it lies on
		for t: int in 2:
			for axis2: int in 3:
				var a1: int = (axis2 + 1) % 3
				var a2: int = (axis2 + 2) % 3
				var c0: int = (s << a1) | (t << a2)
				var c1: int = c0 | (1 << axis2)
				_quad(tris, verts, c0 * 3 + a1, c1 * 3 + a1, c1 * 3 + a2, c0 * 3 + a2)
	for c2: int in 8:   # the eight corners
		_quad(tris, verts, c2 * 3, c2 * 3 + 1, c2 * 3 + 2, c2 * 3 + 2)
	var uvs: PackedVector2Array = []
	var tans: PackedFloat32Array = []
	for k: int in verts.size():   # (the hay materials are world-triplanar: the UVs and tangents only keep the batch's format whole)
		uvs.append(Vector2(verts[k].x + verts[k].z, verts[k].y))
		var tn: Vector3 = Vector3.UP.cross(norms[k])
		if tn.length_squared() < 0.01:
			tn = Vector3.RIGHT
		tn = tn.normalized()
		tans.append_array([tn.x, tn.y, tn.z, 1.0])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_INDEX] = tris
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_soft[key] = m
	return m


## Two triangles a-b-c, a-c-d wound so they face away from the origin (Godot's front faces wind clockwise: the
## right-hand normal points inward). A degenerate one is dropped.
static func _quad(tris: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, d: int) -> void:
	for t: Array in [[a, b, c], [a, c, d]]:
		var p0: Vector3 = verts[t[0]]
		var p1: Vector3 = verts[t[1]]
		var p2: Vector3 = verts[t[2]]
		var n: Vector3 = (p1 - p0).cross(p2 - p0)
		if n.length_squared() < 1e-14:
			continue
		if n.dot(p0 + p1 + p2) > 0.0:
			tris.append_array([t[0], t[2], t[1]])
		else:
			tris.append_array([t[0], t[1], t[2]])


## A soft-edged box: centre, size, material key, rotation in degrees. Tagged "batch" for the generator's batching.
static func soft(parent: Node3D, center: Vector3, size: Vector3, key: String, bevel: float = 0.05, rot_deg: Vector3 = Vector3.ZERO,
		shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	return soft3(parent, center, size, key, Vector3(bevel, bevel, bevel), rot_deg, shadows)


## The same with a bevel per axis (a thin band keeps its full bevel on its two long axes).
static func soft3(parent: Node3D, center: Vector3, size: Vector3, key: String, bevel: Vector3, rot_deg: Vector3 = Vector3.ZERO,
		shadows: bool = true) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = soft_box_mesh(size, bevel)
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.rotation = rot_deg * (PI / 180.0)
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("batch", true)
	parent.add_child(mi)
	return mi


## A rounder ellipsoid than Props.ball (20 x 10 against 12 x 6), for mounds seen from two metres.
static func blob(parent: Node3D, center: Vector3, size: Vector3, key: String, shadows: bool = true) -> MeshInstance3D:
	if _blob == null:
		_blob = SphereMesh.new()
		_blob.radius = 0.5
		_blob.height = 1.0
		_blob.radial_segments = 20
		_blob.rings = 10
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _blob
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.scale = size
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A trodden patch of straw on a floor: loose stalks strewn over the footprint a flat box of `size` would take (same
## arguments as Props.obox, which these patches were: flat dark rectangles that read as mats; a flat ellipsoid read
## as a pit). `key` is the darker of the two straw tones used.
static func pad(parent: Node3D, center: Vector3, size: Vector3, key: String = "straw_floor", rot_deg: Vector3 = Vector3.ZERO) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(center.x * 733.0) * 31 + int(center.z * 911.0) + int(center.y * 7.0)
	var yaw: float = deg_to_rad(rot_deg.y)
	var n: int = 4 + int(size.x * size.z * 14.0)
	for k: int in n:
		var off: Vector3 = Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0.0, rng.randf_range(-0.5, 0.5) * size.z).rotated(Vector3.UP, yaw)
		stalk(parent, Vector3(center.x, center.y - 0.004 + rng.randf_range(0.0, 0.01), center.z) + off, rng.randf_range(0.18, 0.46), rng.randf_range(0.0, 180.0),
			rng.randf_range(-2.5, 2.5), "hay" if rng.randf() < 0.6 else key, rng.randf_range(0.014, 0.024))


## One loose stalk: a thin strip lying at `pos`, `len` long, turned `yaw` and tipped `tilt` degrees.
static func stalk(parent: Node3D, pos: Vector3, length: float, yaw: float, tilt: float = 0.0, key: String = "hay", thick: float = 0.008) -> void:
	var mi: MeshInstance3D = Props.obox(parent, pos, Vector3(length, thick * 0.7, thick), key, Vector3(0.0, yaw, tilt))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A hay bale standing on `pos` (the middle of its foot), `w` long (local X) by `d` deep by `h` high: the bevelled
## body, two twine bands round it, a few stalks worked loose on top and at the ends. `wisps` 0 for a bale buried in a stack.
static func bale(parent: Node3D, pos: Vector3, yaw: float, seed_v: int = 0, w: float = 0.9, h: float = 0.45, d: float = 0.5,
		wisps: int = 7) -> Node3D:
	var g: Node3D = Props.group(parent, "Bale", pos, yaw)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7919 * (seed_v + 1) + int(pos.x * 131.0) + int(pos.z * 977.0)
	var bev: float = 0.055
	soft(g, Vector3(0, h * 0.5, 0), Vector3(w, h, d), "hay", bev)
	for tx: float in [-0.24, 0.24]:   # twine: a dark band standing 5 mm proud all round the section (tarred sisal)
		soft3(g, Vector3(tx * w / 0.9, h * 0.5, 0), Vector3(0.022, h + 0.01, d + 0.01), "beam", Vector3(0.003, bev + 0.004, bev + 0.004), Vector3.ZERO, false)
	for k: int in wisps:
		var top: bool = rng.randf() < 0.65
		if top:
			var p: Vector3 = Vector3(rng.randf_range(-w * 0.42, w * 0.42), h + 0.004, rng.randf_range(-d * 0.4, d * 0.4))
			stalk(g, p, rng.randf_range(0.12, 0.3), rng.randf_range(-30.0, 30.0), rng.randf_range(-6.0, 6.0), "hay", 0.014)
		else:   # sticking out of a cut end
			var s2: float = -1.0 if rng.randf() < 0.5 else 1.0
			var p2: Vector3 = Vector3(s2 * (w * 0.5 + 0.03), rng.randf_range(h * 0.2, h * 0.85), rng.randf_range(-d * 0.35, d * 0.35))
			stalk(g, p2, rng.randf_range(0.08, 0.16), rng.randf_range(-20.0, 20.0), rng.randf_range(-25.0, 25.0), "hay", 0.014)
	return g


## A course-laid block of bales filling the box from `lo` to `hi` (floor corner to top corner): `courses` layers, the
## bales' long side turned 90 degrees from one course to the next (so no joint runs through two layers), every bale a
## touch out of line (`cross` false: every course the same way, for a stack one bale deep against a wall). The art
## fills the box exactly, so a collider of that box has nothing invisible about it.
static func stack(parent: Node3D, lo: Vector3, hi: Vector3, courses: int, seed_v: int = 0, cross: bool = true) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4409 + seed_v
	var sx: float = hi.x - lo.x
	var sz: float = hi.z - lo.z
	var ch: float = (hi.y - lo.y) / float(courses)
	for c: int in courses:
		var along_x: bool = (c % 2 == 0) if cross else (sx >= sz)   # (a stack one bale deep keeps its bales along the wall)
		var run: float = sx if along_x else sz     # the bales' long side lies along this
		var across: float = sz if along_x else sx
		var n_run: int = maxi(1, roundi(run / 1.0))
		var n_across: int = maxi(1, roundi(across / 0.52))
		var bw: float = run / float(n_run)
		var bd: float = across / float(n_across)
		for a: int in n_run:
			for b: int in n_across:
				var u: float = (float(a) + 0.5) * bw
				var v: float = (float(b) + 0.5) * bd
				var p: Vector3 = Vector3(lo.x + (u if along_x else v), lo.y + ch * float(c), lo.z + (v if along_x else u))
				var top_course: bool = c == courses - 1
				bale(parent, p, (0.0 if along_x else 90.0) + rng.randf_range(-1.5, 1.5), seed_v + c * 97 + a * 13 + b, bw - 0.012, ch - 0.004, bd - 0.012,
					4 if top_course else 0)


## A loose heap of hay on the floor: `size` is its footprint (x, z) and peak height (y), `pos` the middle of its
## foot. A big dome, lower lobes round it, a thin skirt where it thins out onto the floor, stalks lying over all of
## it. `lean` shifts the peak (e.g. toward the wall it is banked against).
static func heap(parent: Node3D, pos: Vector3, size: Vector3, seed_v: int = 0, lean: Vector3 = Vector3.ZERO) -> Node3D:
	var g: Node3D = Props.group(parent, "HayHeap", pos)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1723 + seed_v
	var rx: float = size.x * 0.5
	var rz: float = size.z * 0.5
	var hy: float = size.y
	blob(g, lean, Vector3(size.x * 0.72, hy * 2.0, size.z * 0.72), "hay")
	for k: int in 16:   # lobes round the dome: lower the farther out, small enough that the outline is ragged
		var a: float = TAU * (float(k) + rng.randf_range(-0.4, 0.4)) / 16.0
		var r: float = rng.randf_range(0.35, 0.68)
		var c: Vector3 = Vector3(cos(a) * rx * r, 0.0, sin(a) * rz * r) + lean * (1.0 - r)
		var lh: float = hy * rng.randf_range(0.4, 0.8) * (1.15 - r)
		blob(g, c, Vector3(rx * rng.randf_range(0.42, 0.66), lh * 2.0, rz * rng.randf_range(0.42, 0.66)), "hay").rotation.y = rng.randf_range(0.0, PI)
	for k2: int in 12:   # the skirt: thin pads where the heap runs out
		var a2: float = TAU * (float(k2) + rng.randf_range(-0.4, 0.4)) / 12.0
		var c2: Vector3 = Vector3(cos(a2) * rx * rng.randf_range(0.78, 0.98), 0.0, sin(a2) * rz * rng.randf_range(0.78, 0.98))
		blob(g, c2, Vector3(rng.randf_range(0.45, 0.8), rng.randf_range(0.08, 0.18), rng.randf_range(0.4, 0.7)), "hay", false)
	for k4: int in 34:   # clumps breaking the lobes' smooth backs: forkfuls lying as they fell
		var a4: float = rng.randf_range(0.0, TAU)
		var t4: float = sqrt(rng.randf()) * 0.92
		var p4: Vector3 = Vector3(cos(a4) * rx * 0.78 * t4, 0.0, sin(a4) * rz * 0.78 * t4) + lean * (1.0 - t4)
		p4.y = hy * sqrt(maxf(0.0, 1.0 - t4 * t4)) * 0.86
		var cl: MeshInstance3D = blob(g, p4, Vector3(rng.randf_range(0.28, 0.5), rng.randf_range(0.12, 0.2), rng.randf_range(0.16, 0.28)), "hay", false)
		cl.rotation = Vector3(deg_to_rad(rng.randf_range(-22.0, 22.0)), rng.randf_range(0.0, PI), deg_to_rad(rng.randf_range(-22.0, 22.0)))
	for k3: int in 90:   # wisps lying on the surface, pointing down the slope, some standing off it
		var a3: float = rng.randf_range(0.0, TAU)
		var t: float = sqrt(rng.randf())   # 0 at the peak, 1 at the rim
		var p: Vector3 = Vector3(cos(a3) * rx * 0.8 * t, 0.0, sin(a3) * rz * 0.8 * t) + lean * (1.0 - t)
		p.y = hy * sqrt(maxf(0.0, 1.0 - t * t)) * 0.95 + 0.02
		var slope: float = rad_to_deg(atan2(hy * t, maxf(0.05, (rx + rz) * 0.5 * sqrt(maxf(0.02, 1.0 - t * t)))))
		stalk(g, p, rng.randf_range(0.22, 0.5), -rad_to_deg(a3) + rng.randf_range(-40.0, 40.0), -slope * rng.randf_range(0.3, 1.0) + rng.randf_range(-12.0, 22.0),
			"hay" if rng.randf() < 0.75 else "straw_floor", rng.randf_range(0.014, 0.026))
	return g


## Loose straw on a floor: `n` stalks and a few trodden tufts inside the ellipse (rx, rz) round `pos` (y = the floor).
static func scatter(parent: Node3D, pos: Vector3, rx: float, rz: float, n: int, seed_v: int = 0, tufts: int = 3) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 911 + seed_v
	for k: int in tufts:
		var a: float = rng.randf_range(0.0, TAU)
		var t: float = sqrt(rng.randf()) * 0.8
		pad(parent, pos + Vector3(cos(a) * rx * t, 0.012, sin(a) * rz * t), Vector3(rng.randf_range(0.3, 0.7), 0.018, rng.randf_range(0.2, 0.45)),
			"straw_floor", Vector3(0, rng.randf_range(0.0, 180.0), 0))
	for k2: int in n:
		var a2: float = rng.randf_range(0.0, TAU)
		var t2: float = sqrt(rng.randf())
		stalk(parent, pos + Vector3(cos(a2) * rx * t2, 0.018 + rng.randf_range(0.0, 0.008), sin(a2) * rz * t2), rng.randf_range(0.14, 0.4), rng.randf_range(0.0, 180.0),
			rng.randf_range(-3.0, 3.0), "hay" if rng.randf() < 0.7 else "straw_floor", rng.randf_range(0.012, 0.022))


## A small tuft of loose hay (a low mound with a few stalks), e.g. dropped along a wall.
static func tuft(parent: Node3D, pos: Vector3, size: float = 0.5, seed_v: int = 0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 337 + seed_v
	blob(parent, pos, Vector3(size, size * 0.42, size * 0.7), "hay", false).rotation.y = rng.randf_range(0.0, PI)
	blob(parent, pos + Vector3(size * 0.25, 0, size * 0.12), Vector3(size * 0.6, size * 0.22, size * 0.5), "hay", false)
	for k: int in 6:
		var a: float = rng.randf_range(0.0, TAU)
		stalk(parent, pos + Vector3(cos(a) * size * 0.3, size * 0.12 + 0.01, sin(a) * size * 0.22), rng.randf_range(0.15, 0.32), rng.randf_range(0.0, 180.0), rng.randf_range(-14.0, 14.0))


## A hay fork: an ash handle, a forged socket and three curved tines. `pos` is where the tines' points rest (stuck
## in a heap or standing on the floor), `yaw` the way it leans, `lean` degrees off the vertical. Tines down.
static func pitchfork(parent: Node3D, pos: Vector3, yaw: float, lean: float = 12.0, length: float = 1.55) -> Node3D:
	var g: Node3D = Props.group(parent, "Pitchfork", pos, yaw)
	var tip: Node3D = Props.group(g, "Lean", Vector3.ZERO)
	tip.rotation.x = deg_to_rad(-lean)   # leans toward local -Z... the head stays at the origin
	Props.cyl(tip, Vector3(0, 0.34 + (length - 0.34) * 0.5, 0), 0.017, length - 0.34, "furniture")   # the handle
	Props.cyl(tip, Vector3(0, 0.36, 0), 0.022, 0.12, "iron")                                          # the socket
	Props.block(tip, Vector3(-0.11, 0.285, -0.012), Vector3(0.11, 0.31, 0.012), "iron")               # the head bar
	for tx: float in [-0.1, 0.0, 0.1]:
		Props.obox(tip, Vector3(tx, 0.2, 0.012), Vector3(0.012, 0.19, 0.012), "iron", Vector3(8, 0, 0))
		Props.obox(tip, Vector3(tx, 0.055, 0.02), Vector3(0.011, 0.13, 0.011), "iron", Vector3(-9, 0, 0))
	return g
