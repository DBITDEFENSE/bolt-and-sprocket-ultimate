class_name V2Model
extends RefCounted
## T-276: the V2 rocket and the erector trailer's arm, built in code (both move, so neither is baked into the map).
## The rocket wears the plain black-and-white test paint of the trials (quarters that swap from band to band): no
## insignia, no markings, no text, no numbers. 14 m long, 1.65 m across, four fins spanning 3.56 m. Its local origin
## is the middle of its base (the nozzle's plane), +Y up its axis. The arm's local origin is its hinge, +Y along its
## rails, the rocket's axis RocketErector.AXIS_OFF m along local +X.

const LENGTH: float = 14.0
const RADIUS: float = 0.825
const FIN_SPAN: float = 1.78
const SEGMENTS: int = 24
## The lathe profile: [height, radius] from the base to the tip.
const PROFILE: Array = [[0.0, 0.62], [0.25, 0.68], [1.0, 0.75], [2.2, 0.8], [3.4, RADIUS], [9.4, RADIUS], [10.3, 0.8],
	[11.2, 0.72], [12.1, 0.58], [12.9, 0.4], [13.5, 0.22], [13.85, 0.08], [LENGTH, 0.0]]
## Paint bands (heights where the quarters swap colour).
const BANDS: Array = [0.0, 3.4, 6.4, 9.4, LENGTH + 1.0]
## The arm: rail length, the rocket's axis from the hinge (local +X), the clamp heights on the rocket.
const ARM_LENGTH: float = 13.4
const AXIS_OFF: float = 1.9
const CLAMPS: Array = [3.6, 8.2, 11.6]


## The rocket as a node with two meshes (black, white) and the fins; `with_flame_point` adds a "Nozzle" marker.
static func rocket() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "V2"
	var sts: Array[SurfaceTool] = [SurfaceTool.new(), SurfaceTool.new()]
	for st: SurfaceTool in sts:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in PROFILE.size() - 1:
		var y0: float = float(PROFILE[k][0])
		var r0: float = float(PROFILE[k][1])
		var y1: float = float(PROFILE[k + 1][0])
		var r1: float = float(PROFILE[k + 1][1])
		var band: int = _band_of((y0 + y1) * 0.5)
		var slope: float = (r0 - r1) / maxf(0.001, y1 - y0)
		for s: int in SEGMENTS:
			var a0: float = TAU * float(s) / float(SEGMENTS)
			var a1: float = TAU * float(s + 1) / float(SEGMENTS)
			var quarter: int = int(floor(float(s) * 4.0 / float(SEGMENTS)))
			var st2: SurfaceTool = sts[(quarter + band) % 2]
			var p00: Vector3 = Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p01: Vector3 = Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p10: Vector3 = Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11: Vector3 = Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var n0: Vector3 = Vector3(cos(a0), slope, sin(a0)).normalized()
			var n1: Vector3 = Vector3(cos(a1), slope, sin(a1)).normalized()
			for v: Array in [[p00, n0], [p11, n1], [p10, n0], [p00, n0], [p01, n1], [p11, n1]]:   # (clockwise from outside: Godot's front face)
				st2.set_normal(v[1])
				st2.add_vertex(v[0])
	# the base: a dark ring round the nozzle's mouth
	var keys: Array[String] = ["black_paint", "paint_cream"]
	for i: int in 2:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Body%d" % i
		mi.mesh = sts[i].commit()
		mi.material_override = Mats.get_mat(keys[i])
		root.add_child(mi)
	# four fins on the quarter lines, each painted the other colour from the body quarter it starts on, and the
	# graphite jet vanes' outer rudders at the fin tips
	for f: int in 4:
		var a: float = TAU * float(f) / 4.0
		var fin: Node3D = Node3D.new()
		fin.name = "Fin%d" % f
		fin.rotation.y = -a
		root.add_child(fin)
		var key: String = keys[(f + 1) % 2]
		_fin(fin, key)
	var noz: MeshInstance3D = MeshInstance3D.new()
	noz.name = "Nozzle"
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.48
	cm.height = 0.3
	noz.mesh = cm
	noz.material_override = Mats.get_mat("char")
	noz.position = Vector3(0, 0.12, 0)
	root.add_child(noz)
	return root


static func _band_of(y: float) -> int:
	for i: int in BANDS.size() - 1:
		if y >= float(BANDS[i]) and y < float(BANDS[i + 1]):
			return i
	return 0


## One fin in the local XY plane (+X outward), 9 cm thick: root along the body from 0.05 to 3.3 m, a swept leading
## edge to the tip at FIN_SPAN, the trailing edge level with the base; a small rudder at its tip.
static func _fin(parent: Node3D, key: String) -> void:
	var pts: Array[Vector2] = [Vector2(0.62, 0.0), Vector2(FIN_SPAN, 0.05), Vector2(FIN_SPAN, 0.95), Vector2(0.82, 3.3), Vector2(0.62, 1.0)]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t: float = 0.045
	for side: float in [-1.0, 1.0]:
		var n: Vector3 = Vector3(0, 0, side)
		for k: int in range(1, pts.size() - 1):
			var tri: Array = [pts[0], pts[k + 1], pts[k]] if side > 0.0 else [pts[0], pts[k], pts[k + 1]]   # (clockwise seen from that side)
			for q: Vector2 in tri:
				st.set_normal(n)
				st.add_vertex(Vector3(q.x, q.y, side * t))
	for k2: int in pts.size():
		var a: Vector2 = pts[k2]
		var b: Vector2 = pts[(k2 + 1) % pts.size()]
		var e: Vector2 = (b - a).normalized()
		var n2: Vector3 = Vector3(e.y, -e.x, 0)
		for q2: Vector3 in [Vector3(a.x, a.y, -t), Vector3(b.x, b.y, t), Vector3(b.x, b.y, -t), Vector3(a.x, a.y, -t), Vector3(a.x, a.y, t), Vector3(b.x, b.y, t)]:
			st.set_normal(n2)
			st.add_vertex(q2)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Mats.get_mat(key)
	parent.add_child(mi)
	Props.block(parent, Vector3(FIN_SPAN - 0.05, 0.0, -0.08), Vector3(FIN_SPAN + 0.03, 0.55, 0.08), "black_paint")


## The erector arm: two lattice rails, cross members, diagonal braces, three clamp frames that reach round the rocket,
## two working platforms and a ladder up the rails. Baked to a few meshes (Props.bake).
static func erector_arm() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ErectorArm"
	var parts: Node3D = Node3D.new()
	root.add_child(parts)
	var key: String = "olive_steel"
	var zr: float = 0.95
	for sz: float in [-zr, zr]:
		Props.block(parts, Vector3(-0.22, 0.0, sz - 0.1), Vector3(0.0, ARM_LENGTH, sz + 0.1), key)
		Props.block(parts, Vector3(0.35, 0.4, sz - 0.07), Vector3(0.5, ARM_LENGTH - 0.6, sz + 0.07), key)
		var y: float = 0.6
		while y < ARM_LENGTH - 0.8:
			Props.strut(parts, Vector3(0.0, y, sz), Vector3(0.42, y + 0.9, sz), 0.06, key)
			Props.block(parts, Vector3(0.0, y - 0.04, sz - 0.04), Vector3(0.42, y + 0.04, sz + 0.04), key)
			y += 0.9
	var y2: float = 0.5
	while y2 < ARM_LENGTH:
		Props.block(parts, Vector3(-0.2, y2 - 0.05, -zr), Vector3(-0.02, y2 + 0.05, zr), key)
		y2 += 1.6
	for k: int in 7:
		var ya: float = 0.6 + k * 1.8
		Props.strut(parts, Vector3(-0.11, ya, -zr), Vector3(-0.11, ya + 1.8, zr), 0.06, key)
	# the clamps: a frame from the rails out round the rocket's axis (local +X AXIS_OFF), open on the far side
	for ch: float in CLAMPS:
		var c: Vector3 = Vector3(AXIS_OFF, ch, 0)
		for sz2: float in [-1.0, 1.0]:
			Props.strut(parts, Vector3(0.4, ch, sz2 * zr), c + Vector3(-0.35, 0, sz2 * (RADIUS + 0.12)), 0.12, key)
			Props.strut(parts, c + Vector3(-0.35, 0, sz2 * (RADIUS + 0.12)), c + Vector3(0.45, 0, sz2 * (RADIUS + 0.1)), 0.1, key)
		Props.block(parts, Vector3(0.35, ch - 0.08, -zr), Vector3(0.6, ch + 0.08, zr), key)
	# working platforms on the rails' outer side (local -X) at two heights, with a rail
	for ph: float in [5.6, 9.8]:
		Props.block(parts, Vector3(-1.1, ph, -zr - 0.1), Vector3(-0.2, ph + 0.06, zr + 0.1), "steel_grate")
		for sz3: float in [-zr - 0.1, zr + 0.1]:
			Props.block(parts, Vector3(-1.1, ph, sz3 - 0.03), Vector3(-1.05, ph + 1.0, sz3 + 0.03), key)
		Props.block(parts, Vector3(-1.12, ph + 0.95, -zr - 0.1), Vector3(-1.04, ph + 1.02, zr + 0.1), key)
	# a ladder up the rails' back
	Props.ladder(parts, Vector3(-0.3, 0.2, 0.0), -90.0, ARM_LENGTH - 1.0, key)
	# the pivot boss at the hinge
	Props.cyl(parts, Vector3(-0.1, 0.0, 0), 0.22, zr * 2.0 + 0.3, "rust", Vector3(90, 0, 0))
	# T-279: riveted gusset plates where the braces meet the rails, rust at the joints and grime down the rails
	for sz4: float in [-zr, zr]:
		var y3: float = 0.6
		while y3 < ARM_LENGTH - 0.8:
			Props.block(parts, Vector3(0.02, y3 - 0.12, sz4 - 0.105), Vector3(0.3, y3 + 0.12, sz4 - 0.095) if sz4 < 0.0 else Vector3(0.3, y3 + 0.12, sz4 + 0.105), "steel")
			Props.block(parts, Vector3(-0.23, y3 - 0.08, sz4 - 0.11), Vector3(-0.21, y3 + 0.08, sz4 + 0.11), "rust")
			y3 += 1.8
		Props.block(parts, Vector3(-0.225, 0.2, sz4 - 0.104), Vector3(-0.2, ARM_LENGTH - 0.2, sz4 + 0.104), "grime")
	Props.bake(parts)
	return root
