class_name Props
extends RefCounted

## Procedural prop builders for set dressing (original, code-built). Everything here is decorative:
## no collision, so props never change the navmesh. Boxes reuse one shared unit mesh scaled per instance;
## materials are world-triplanar (Mats), so scaling never stretches textures.

const BAKED_MM: Script = preload("res://gravelight/world/baked_multimesh.gd")   # T-125

static var _unit: BoxMesh
static var _cyl: CylinderMesh
static var _sph: SphereMesh


static func unit_box() -> BoxMesh:
	if _unit == null:
		_unit = BoxMesh.new()
	return _unit


static func unit_cyl() -> CylinderMesh:
	if _cyl == null:
		_cyl = CylinderMesh.new()
		_cyl.top_radius = 0.5
		_cyl.bottom_radius = 0.5
		_cyl.height = 1.0
		_cyl.radial_segments = 12
		_cyl.rings = 1
	return _cyl


static func unit_sphere() -> SphereMesh:
	if _sph == null:
		_sph = SphereMesh.new()
		_sph.radius = 0.5
		_sph.height = 1.0
		_sph.radial_segments = 12
		_sph.rings = 6
	return _sph


## Box from min/max corners (in parent space).
static func block(parent: Node3D, a: Vector3, b: Vector3, key: String, shadows: bool = true) -> MeshInstance3D:
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = unit_box()
	mi.material_override = Mats.get_mat(key)
	mi.position = (lo + hi) * 0.5
	mi.scale = (hi - lo).max(Vector3(0.002, 0.002, 0.002))
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_probe(mi, "block", key)
	return mi


## T-230: "what is that piece?" With the environment variable GL_PROBE_BOX="x0,y0,z0,x1,y1,z1" set when a generator
## runs, every block / obox / cyl whose world box touches that box is printed (kind, material key, the group path, the
## box), so a stray piece seen in a render can be traced to its line without guessing from coordinates.
static var _probe_box: Variant = null   # AABB once read; false when unset


static func _probe(mi: MeshInstance3D, kind: String, key: String) -> void:
	if _probe_box == null:
		var env: String = OS.get_environment("GL_PROBE_BOX")
		var v: PackedFloat64Array = []
		for part: String in env.split(","):
			if part.strip_edges().is_valid_float():
				v.append(float(part))
		_probe_box = AABB(Vector3(v[0], v[1], v[2]), Vector3(v[3] - v[0], v[4] - v[1], v[5] - v[2])) if v.size() == 6 else false
	if _probe_box is bool:
		return
	# the world transform without a tree: walk the parents' local transforms
	var xf: Transform3D = mi.transform
	var path: String = ""
	var n: Node = mi.get_parent()
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		path = n.name + "/" + path
		n = n.get_parent()
	var box: AABB = xf * AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)   # unit box / cylinder bounds
	if box.intersects(_probe_box as AABB):
		print("[probe] %s %-14s %-40s at %s size %s" % [kind, key, path, str(box.position + box.size * 0.5), str(box.size)])


## The same probe for a generator's geometry box (gen_mapNN box(): a collider with drawn faces), by its corners.
static func probe_geo(n: String, a: Vector3, b: Vector3, key: String) -> void:
	if _probe_box == null:
		var mi: MeshInstance3D = MeshInstance3D.new()
		_probe(mi, "", "")   # reads the environment once
		mi.free()
	if _probe_box is bool:
		return
	var lo: Vector3 = Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	if AABB(lo, hi - lo).intersects(_probe_box as AABB):
		print("[probe] geo  %-14s %-40s at %s size %s" % [key, n, str((lo + hi) * 0.5), str(hi - lo)])


## Oriented box: centre, size, yaw/pitch/roll in degrees.
static func obox(parent: Node3D, center: Vector3, size: Vector3, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = unit_box()
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.rotation = rot_deg * (PI / 180.0)
	mi.scale = size
	parent.add_child(mi)
	_probe(mi, "obox", key)
	return mi


static func cyl(parent: Node3D, center: Vector3, radius: float, height: float, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = unit_cyl()
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.rotation = rot_deg * (PI / 180.0)
	mi.scale = Vector3(radius * 2.0, height, radius * 2.0)
	parent.add_child(mi)
	_probe(mi, "cyl", key)
	return mi


static func ball(parent: Node3D, center: Vector3, size: Vector3, key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = unit_sphere()
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.scale = size
	parent.add_child(mi)
	return mi


static func group(parent: Node3D, n: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	g.position = pos
	g.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(g)
	return g


# ================================================================== furniture

static func table_visual(parent: Node3D, center: Vector3, w: float, d: float, h: float = 0.75) -> void:
	var g: Node3D = group(parent, "Table", center)
	block(g, Vector3(-w * 0.5 - 0.05, h - 0.06, -d * 0.5 - 0.05), Vector3(w * 0.5 + 0.05, h, d * 0.5 + 0.05), "furniture")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			block(g, Vector3(sx * (w * 0.5 - 0.12) - 0.05, 0, sz * (d * 0.5 - 0.12) - 0.05),
				Vector3(sx * (w * 0.5 - 0.12) + 0.05, h - 0.06, sz * (d * 0.5 - 0.12) + 0.05), "furniture")
	block(g, Vector3(-w * 0.5 + 0.1, 0.15, -0.03), Vector3(w * 0.5 - 0.1, 0.2, 0.03), "furniture")


static func chair(parent: Node3D, pos: Vector3, yaw: float, tipped: bool = false) -> void:
	var g: Node3D = group(parent, "Chair", pos, yaw)
	if tipped:
		g.rotation.x = deg_to_rad(-80)
		g.position.y += 0.22
	block(g, Vector3(-0.22, 0.43, -0.22), Vector3(0.22, 0.47, 0.22), "furniture")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			block(g, Vector3(sx * 0.18 - 0.025, 0, sz * 0.18 - 0.025), Vector3(sx * 0.18 + 0.025, 0.43, sz * 0.18 + 0.025), "furniture")
	block(g, Vector3(-0.22, 0.47, 0.18), Vector3(0.22, 0.95, 0.22), "furniture")
	block(g, Vector3(-0.16, 0.6, 0.17), Vector3(0.16, 0.85, 0.19), "beam")


static func bench(parent: Node3D, pos: Vector3, yaw: float, length: float = 1.6) -> void:
	var g: Node3D = group(parent, "Bench", pos, yaw)
	block(g, Vector3(-length * 0.5, 0.42, -0.16), Vector3(length * 0.5, 0.47, 0.16), "furniture")
	for sx: float in [-1.0, 1.0]:
		block(g, Vector3(sx * (length * 0.5 - 0.15) - 0.04, 0, -0.13), Vector3(sx * (length * 0.5 - 0.15) + 0.04, 0.42, 0.13), "furniture")


static func stool(parent: Node3D, pos: Vector3) -> void:
	var g: Node3D = group(parent, "Stool", pos)
	cyl(g, Vector3(0, 0.72, 0), 0.18, 0.05, "furniture")
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0
		obox(g, Vector3(cos(a) * 0.11, 0.36, sin(a) * 0.11), Vector3(0.04, 0.74, 0.04), "furniture", Vector3(sin(a) * 8.0, 0, -cos(a) * 8.0))


static func bed(parent: Node3D, a: Vector3, b: Vector3, blanket: String = "cloth_red") -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z))
	var h: float = hi.y - lo.y
	block(parent, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y + h * 0.45, hi.z), "furniture")
	block(parent, Vector3(lo.x + 0.05, lo.y + h * 0.45, lo.z + 0.05), Vector3(hi.x - 0.05, lo.y + h * 0.85, hi.z - 0.05), "linen")
	block(parent, Vector3(lo.x + 0.04, lo.y + h * 0.85, lo.z + (hi.z - lo.z) * 0.3), Vector3(hi.x - 0.04, lo.y + h * 0.95, hi.z - 0.04), blanket)
	if hi.z - lo.z > hi.x - lo.x:
		block(parent, Vector3(lo.x + 0.1, lo.y + h * 0.85, lo.z + 0.08), Vector3(hi.x - 0.1, lo.y + h * 1.05, lo.z + 0.4), "linen")
		block(parent, Vector3(lo.x, lo.y, lo.z - 0.06), Vector3(hi.x, lo.y + 1.0, lo.z), "furniture")
	else:
		block(parent, Vector3(lo.x + 0.08, lo.y + h * 0.85, lo.z + 0.1), Vector3(lo.x + 0.4, lo.y + h * 1.05, hi.z - 0.1), "linen")
		block(parent, Vector3(lo.x - 0.06, lo.y, lo.z), Vector3(lo.x, lo.y + 1.0, hi.z), "furniture")


## The bed's soft parts only (mattress, blanket, pillow) at the same heights as bed(), for a frame drawn by
## something else (Map 0's iron bed frames from the prop library, T-093).
static func bed_soft(parent: Node3D, a: Vector3, b: Vector3, blanket: String = "cloth_red") -> void:
	var lo: Vector3 = Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi: Vector3 = Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z))
	var h: float = hi.y - lo.y
	block(parent, Vector3(lo.x + 0.05, lo.y + h * 0.45, lo.z + 0.05), Vector3(hi.x - 0.05, lo.y + h * 0.85, hi.z - 0.05), "linen")
	block(parent, Vector3(lo.x + 0.04, lo.y + h * 0.85, lo.z + (hi.z - lo.z) * 0.3), Vector3(hi.x - 0.04, lo.y + h * 0.95, hi.z - 0.04), blanket)
	if hi.z - lo.z > hi.x - lo.x:
		block(parent, Vector3(lo.x + 0.1, lo.y + h * 0.85, lo.z + 0.08), Vector3(hi.x - 0.1, lo.y + h * 1.05, lo.z + 0.4), "linen")
	else:
		block(parent, Vector3(lo.x + 0.08, lo.y + h * 0.85, lo.z + 0.1), Vector3(lo.x + 0.4, lo.y + h * 1.05, hi.z - 0.1), "linen")


static func trunk(parent: Node3D, a: Vector3, b: Vector3) -> void:
	block(parent, a, b, "furniture")
	block(parent, Vector3(a.x - 0.01, b.y - 0.06, a.z - 0.01), Vector3(b.x + 0.01, b.y, b.z + 0.01), "iron")
	block(parent, Vector3((a.x + b.x) * 0.5 - 0.05, a.y, a.z - 0.015), Vector3((a.x + b.x) * 0.5 + 0.05, b.y, b.z + 0.015), "iron")


static func washstand(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "Washstand", pos, yaw)
	block(g, Vector3(-0.35, 0, -0.22), Vector3(0.35, 0.8, 0.22), "furniture")
	cyl(g, Vector3(0, 0.84, 0), 0.2, 0.08, "stein")
	cyl(g, Vector3(0.18, 0.95, 0.05), 0.07, 0.22, "stein")
	block(g, Vector3(-0.3, 1.1, 0.2), Vector3(0.3, 1.6, 0.23), "frame_gold")
	block(g, Vector3(-0.26, 1.14, 0.19), Vector3(0.26, 1.56, 0.2), "window_dark")


static func wardrobe(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "Wardrobe", pos, yaw)
	block(g, Vector3(-0.55, 0, -0.3), Vector3(0.55, 2.0, 0.3), "furniture")
	block(g, Vector3(-0.01, 0.1, -0.31), Vector3(0.01, 1.9, -0.3), "beam")
	block(g, Vector3(-0.6, 2.0, -0.34), Vector3(0.6, 2.08, 0.34), "beam")


static func coat_rack(parent: Node3D, pos: Vector3) -> void:
	var g: Node3D = group(parent, "CoatRack", pos)
	cyl(g, Vector3(0, 0.9, 0), 0.03, 1.8, "beam")
	cyl(g, Vector3(0, 0.02, 0), 0.2, 0.04, "beam")
	block(g, Vector3(-0.18, 1.0, -0.12), Vector3(0.18, 1.72, 0.06), "cloth_green")   # a greatcoat
	block(g, Vector3(-0.15, 1.72, -0.12), Vector3(0.15, 1.8, 0.12), "iron")          # a helmet on the hook


# ================================================================== bar dressing

## Bottles/steins on a shelf line from a to b (both at the shelf's top surface).
static func bottles(parent: Node3D, a: Vector3, b: Vector3, count: int, seed_v: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var keys: Array = ["bottle_green", "bottle_amber", "stein"]
	for k: String in keys:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit_cyl()
		var xf: Array[Transform3D] = []
		for i: int in count:
			if keys[rng.randi() % keys.size()] != k:
				continue
			var t: float = (float(i) + rng.randf_range(0.1, 0.9)) / float(count)
			var p: Vector3 = a.lerp(b, t)
			var tall: float = rng.randf_range(0.24, 0.34) if k != "stein" else 0.17
			var rad: float = 0.04 if k != "stein" else 0.06
			xf.append(Transform3D(Basis.from_scale(Vector3(rad * 2.0, tall, rad * 2.0)), p + Vector3(0, tall * 0.5, rng.randf_range(-0.06, 0.06))))
		var mmi: MultiMeshInstance3D = BAKED_MM.new()   # T-125: transforms kept on the node
		mmi.set("transforms", xf)
		mmi.multimesh = mm
		mmi.call("fill")
		mmi.material_override = Mats.get_mat(k)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


static var _lantern_body: ArrayMesh


## A hanging lantern on its chain. Update 02 section 7 (T-052): it hangs from a pivot at the ceiling (group
## "swing_lamps", meta "keep" so the static batching leaves it whole) so LampSway can swing it, and the lamp's
## light with it, when shells land close or something hits it. Two draw calls: the chain and the body.
static func lantern(parent: Node3D, pos: Vector3, ceiling_y: float) -> void:
	var g: Node3D = group(parent, "Lantern", pos)
	var chain: float = maxf(0.05, ceiling_y - pos.y - 0.25)
	var pivot: Node3D = group(g, "LanternSwing", Vector3(0, 0.25 + chain, 0))
	pivot.add_to_group(&"swing_lamps", true)
	var c: MeshInstance3D = block(pivot, Vector3(-0.01, -chain, -0.01), Vector3(0.01, 0.0, 0.01), "iron", false)
	c.set_meta("keep", true)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "LanternBody"
	body.mesh = lantern_body()
	body.position = Vector3(0, -0.25 - chain, 0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.set_meta("keep", true)
	pivot.add_child(body)
	# Update 02 section 8 (T-053): a shot swings it (a "decor" hit volume; DecorTarget)
	DecorHit.make_target(pivot, body.position, 0.16, &"lamp")


## The lantern's cage, cap and glass as one shared mesh (surface 0 iron, surface 1 the lit glass).
static func lantern_body() -> ArrayMesh:
	if _lantern_body != null:
		return _lantern_body
	var iron: SurfaceTool = SurfaceTool.new()
	iron.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass: SurfaceTool = SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var boxes: Array = [[Vector3(-0.1, 0.16, -0.1), Vector3(0.1, 0.22, 0.1)], [Vector3(-0.11, -0.2, -0.11), Vector3(0.11, -0.16, 0.11)]]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			boxes.append([Vector3(sx * 0.09 - 0.01, -0.18, sz * 0.09 - 0.01), Vector3(sx * 0.09 + 0.01, 0.18, sz * 0.09 + 0.01)])
	for b: Array in boxes:
		var lo: Vector3 = b[0]
		var hi: Vector3 = b[1]
		iron.append_from(unit_box(), 0, Transform3D(Basis.from_scale(hi - lo), (lo + hi) * 0.5))
	glass.append_from(unit_box(), 0, Transform3D(Basis.from_scale(Vector3(0.16, 0.32, 0.16)), Vector3.ZERO))
	_lantern_body = iron.commit()
	glass.commit(_lantern_body)
	_lantern_body.surface_set_material(0, Mats.get_mat("iron"))
	_lantern_body.surface_set_material(1, Mats.get_mat("lantern_glass"))
	return _lantern_body


static func wall_lamp(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "WallLamp", pos, yaw)
	block(g, Vector3(-0.06, -0.2, 0.0), Vector3(0.06, 0.2, 0.04), "iron")
	block(g, Vector3(-0.015, 0.0, -0.18), Vector3(0.015, 0.03, 0.0), "iron")
	block(g, Vector3(-0.07, -0.12, -0.3), Vector3(0.07, 0.1, -0.16), "lantern_glass", false)


static func picture(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float) -> void:
	var g: Node3D = group(parent, "Picture", pos, yaw)
	block(g, Vector3(-w * 0.5, -h * 0.5, -0.03), Vector3(w * 0.5, h * 0.5, 0.0), "frame_gold")
	block(g, Vector3(-w * 0.5 + 0.05, -h * 0.5 + 0.05, -0.035), Vector3(w * 0.5 - 0.05, h * 0.5 - 0.05, -0.03), "picture")


static func antlers(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "Antlers", pos, yaw)
	block(g, Vector3(-0.15, -0.2, -0.03), Vector3(0.15, 0.15, 0.0), "furniture")
	ball(g, Vector3(0, 0, -0.08), Vector3(0.12, 0.14, 0.12), "antler")
	for s: float in [-1.0, 1.0]:
		obox(g, Vector3(s * 0.16, 0.18, -0.1), Vector3(0.03, 0.4, 0.03), "antler", Vector3(0, 0, -s * 35.0))
		obox(g, Vector3(s * 0.3, 0.38, -0.12), Vector3(0.025, 0.3, 0.025), "antler", Vector3(0, 0, -s * 15.0))
		obox(g, Vector3(s * 0.2, 0.42, -0.1), Vector3(0.02, 0.22, 0.02), "antler", Vector3(0, 0, s * 20.0))


static func curtain(parent: Node3D, pos: Vector3, yaw: float, height: float, key: String = "cloth_red") -> void:
	var g: Node3D = group(parent, "Curtain", pos, yaw)
	for i: int in 4:
		obox(g, Vector3(-0.15 + i * 0.1, -height * 0.5, -0.02 - (i % 2) * 0.03), Vector3(0.11, height, 0.03), key)


static func crate(parent: Node3D, pos: Vector3, size: float, yaw: float, stencil: String = "") -> void:
	var g: Node3D = group(parent, "Crate", pos, yaw)
	block(g, Vector3(-size * 0.5, 0, -size * 0.5), Vector3(size * 0.5, size, size * 0.5), "planks")
	block(g, Vector3(-size * 0.52, size * 0.45, -size * 0.52), Vector3(size * 0.52, size * 0.55, size * 0.52), "beam")
	if stencil != "":
		var l: Label3D = Label3D.new()
		l.text = stencil
		l.font_size = 40
		l.pixel_size = 0.004
		l.modulate = Color(0.85, 0.82, 0.7, 0.75)
		l.position = Vector3(0, size * 0.72, -size * 0.51)
		l.rotation.y = PI
		SurfaceText.apply(l)   # T-247: stencilled paint, lit by the room
		g.add_child(l)


# ================================================================== stable / outside

static func hay_bale(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "Bale", pos, yaw)
	block(g, Vector3(-0.45, 0, -0.25), Vector3(0.45, 0.45, 0.25), "hay")
	for s: float in [-0.25, 0.25]:
		block(g, Vector3(s - 0.01, -0.005, -0.255), Vector3(s + 0.01, 0.455, 0.255), "beam", false)


static func cart(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "Cart", pos, yaw)
	block(g, Vector3(-0.8, 0.55, -1.3), Vector3(0.8, 0.65, 1.3), "planks")
	for s: float in [-1.0, 1.0]:
		block(g, Vector3(s * 0.8 - 0.04 * s, 0.65, -1.3), Vector3(s * 0.8, 1.05, 1.3), "planks")
		cyl(g, Vector3(s * 0.95, 0.5, 0.4), 0.5, 0.08, "furniture", Vector3(0, 0, 90))
		cyl(g, Vector3(s * 0.95, 0.5, 0.4), 0.12, 0.12, "iron", Vector3(0, 0, 90))
	obox(g, Vector3(0, 0.45, -2.2), Vector3(0.08, 0.08, 1.9), "beam", Vector3(8, 0, 0))
	for i: int in 3:
		hay_bale(g, Vector3(-0.3 + i * 0.3, 0.65, 0.3 - i * 0.5), 15.0 * i)


## A rail fence from a to b: square posts and two split rails per bay (T-093: the rails are hewn round poles in the
## weathered planks, the posts dark oak; two MultiMeshes). A bay is left open now and then.
## `tall` (T-125): a 2.3 m corral fence with four rails and no open bays, drawn over a collider that tall.
static func fence(parent: Node3D, a: Vector3, b: Vector3, seed_v: int, tall: bool = false) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var length: float = a.distance_to(b)
	var count: int = int(length / 2.2) + 1
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var dir: Vector3 = (b - a).normalized()
	var yaw: float = atan2(dir.x, dir.z)
	for i: int in count:
		var p: Vector3 = a.lerp(b, float(i) / maxf(1.0, float(count - 1)))
		var tilt: Basis = Basis(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)) * Basis(Vector3.FORWARD, rng.randf_range(-0.08, 0.08))
		if tall:
			posts.append(Transform3D(tilt * Basis.from_scale(Vector3(0.14, 2.45, 0.14)), p + Vector3(0, 1.17, 0)))
		else:
			posts.append(Transform3D(tilt * Basis.from_scale(Vector3(0.12, 1.3, 0.12)), p + Vector3(0, 0.6, 0)))
		var open_bay: bool = rng.randf() <= 0.15 if i < count - 1 else true
		if i < count - 1 and (not open_bay or tall):
			var q: Vector3 = a.lerp(b, (float(i) + 0.5) / maxf(1.0, float(count - 1)))
			for h: float in ([0.5, 1.0, 1.6, 2.15] if tall else [0.5, 1.0]):
				var rb: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05))
				var span: float = length / maxf(1.0, float(count - 1)) + 0.1
				rails.append(Transform3D(rb * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.1, span, 0.08)), q + Vector3(0, h, 0)))
	for part: Array in [[posts, unit_box(), "beam"], [rails, unit_hex(), "planks"]]:
		var xf: Array[Transform3D] = part[0]
		if xf.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[1]
		# T-125: the transforms live on the node (a headless generator's MultiMesh saves none)
		var mmi: MultiMeshInstance3D = BAKED_MM.new()
		mmi.set("transforms", xf)
		mmi.multimesh = mm
		mmi.call("fill")
		mmi.material_override = Mats.get_mat(str(part[2]))
		parent.add_child(mmi)


static func dead_tree(parent: Node3D, pos: Vector3, seed_v: int, height: float = 7.0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var g: Node3D = group(parent, "DeadTree", pos, rng.randf() * 360.0)
	var wood: String = "bark" if MaterialLibrary.for_generator("bark") != null else "beam"   # T-093: the library's bark when it's on
	cyl(g, Vector3(0, height * 0.5, 0), 0.22, height, wood, Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))
	for i: int in 7:
		var y: float = height * rng.randf_range(0.35, 0.95)
		var a: float = rng.randf() * 360.0
		var blen: float = rng.randf_range(1.2, 2.8) * (1.0 - y / height * 0.5)
		var br: Node3D = group(g, "Branch", Vector3(0, y, 0), a)
		obox(br, Vector3(0, blen * 0.35, -blen * 0.3), Vector3(0.09, blen, 0.09), wood, Vector3(-rng.randf_range(35, 65), 0, 0))
	# snow on the ground around the roots
	ball(g, Vector3(0, 0.0, 0), Vector3(1.6, 0.35, 1.6), "snow")


static func signpost(parent: Node3D, pos: Vector3, signs: Array) -> void:
	var g: Node3D = group(parent, "Signpost", pos)
	cyl(g, Vector3(0, 1.4, 0), 0.07, 2.8, "beam")
	var y: float = 2.5
	for s: Array in signs:   # [text, yaw]
		var arm: Node3D = group(g, "Sign", Vector3(0, y, 0), float(s[1]))
		block(arm, Vector3(-0.05, -0.12, 0.05), Vector3(0.05, 0.12, 1.25), "planks")
		obox(arm, Vector3(0, 0, 1.33), Vector3(0.08, 0.18, 0.18), "planks", Vector3(45, 0, 0))
		for side: float in [-1.0, 1.0]:
			var l: Label3D = Label3D.new()
			l.text = str(s[0])
			l.font_size = 46
			l.pixel_size = 0.003
			l.modulate = Color(0.08, 0.06, 0.05)
			l.position = Vector3(0.06 * side, 0, 0.65)
			l.rotation.y = PI * 0.5 * side
			SurfaceText.apply(l)   # T-247: painted on the arm, lit by the scene
			arm.add_child(l)
		block(arm, Vector3(-0.07, 0.11, 0.05), Vector3(0.07, 0.16, 1.25), "snow", false)
		y -= 0.36


static func snow_drift(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var mi: MeshInstance3D = ball(parent, pos, size, "snow")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ================================================================== fire & smoke

static func _particle_mat(color_a: Color, color_b: Color, energy: float, additive: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1, 1, 1, 1)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	tex.gradient = g
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = color_a.lerp(color_b, 0.5)
		m.emission_energy_multiplier = energy
	return m


static func _ramp_tex(stops: Array) -> GradientTexture1D:
	var offs: PackedFloat32Array = []
	var cols: PackedColorArray = []
	for s: Array in stops:
		offs.append(float(s[0]))
		cols.append(s[1] as Color)
	var g: Gradient = Gradient.new()
	g.offsets = offs
	g.colors = cols
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	return t


static func flames(parent: Node3D, pos: Vector3, width: float, height: float, amount: int = 40) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Flames"
	p.position = pos
	p.amount = amount
	p.lifetime = 0.7
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 6, 6))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.5, 0.05, width * 0.25)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = height * 0.8
	pm.initial_velocity_max = height * 1.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = _curve_tex([[0.0, 0.6], [0.3, 1.0], [1.0, 0.1]])
	pm.color_ramp = _ramp_tex([[0.0, Color(1.0, 0.85, 0.5, 0.9)], [0.35, Color(1.0, 0.45, 0.1, 0.8)], [1.0, Color(0.5, 0.1, 0.02, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(width * 0.45, width * 0.55)
	q.material = _particle_mat(Color(1, 0.6, 0.2), Color(1, 0.3, 0.05), 3.0, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


static func embers(parent: Node3D, pos: Vector3, extent: float, amount: int = 16) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Embers"
	p.position = pos
	p.amount = amount
	p.lifetime = 2.2
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 10, 8))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extent, 0.1, extent * 0.5)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 0.3, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.color_ramp = _ramp_tex([[0.0, Color(1.0, 0.6, 0.2, 1.0)], [1.0, Color(1.0, 0.2, 0.0, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	q.material = _particle_mat(Color(1, 0.5, 0.1), Color(1, 0.3, 0.05), 6.0, true)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


static func smoke(parent: Node3D, pos: Vector3, extent: float, rise: float, amount: int = 30) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Smoke"
	p.position = pos
	p.amount = amount
	p.lifetime = 7.0
	p.visibility_aabb = AABB(Vector3(-15, -2, -15), Vector3(30, 40, 30))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(extent, 0.2, extent)
	pm.direction = Vector3(0.25, 1, 0.1)
	pm.spread = 10.0
	pm.initial_velocity_min = rise * 0.6
	pm.initial_velocity_max = rise
	pm.gravity = Vector3(0.4, 0.2, 0.1)
	pm.scale_min = 1.5
	pm.scale_max = 3.0
	pm.scale_curve = _curve_tex([[0.0, 0.3], [1.0, 1.0]])
	pm.color_ramp = _ramp_tex([[0.0, Color(0.15, 0.13, 0.12, 0.0)], [0.15, Color(0.12, 0.11, 0.10, 0.55)], [1.0, Color(0.20, 0.21, 0.24, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	q.material = _particle_mat(Color(0, 0, 0), Color(0, 0, 0), 0.0, false)
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


static func _curve_tex(points: Array) -> CurveTexture:
	var c: Curve = Curve.new()
	for pt: Array in points:
		c.add_point(Vector2(float(pt[0]), float(pt[1])))
	var t: CurveTexture = CurveTexture.new()
	t.curve = c
	return t


## Logs + flames + embers: a hearth fire.
static func hearth_fire(parent: Node3D, pos: Vector3) -> void:
	var g: Node3D = group(parent, "HearthFire", pos)
	obox(g, Vector3(-0.15, 0.07, 0), Vector3(0.8, 0.14, 0.14), "char", Vector3(0, 20, 0))
	obox(g, Vector3(0.15, 0.07, 0.05), Vector3(0.8, 0.14, 0.14), "char", Vector3(0, -25, 0))
	obox(g, Vector3(0, 0.18, 0.0), Vector3(0.7, 0.12, 0.12), "ember", Vector3(0, 80, 10))
	block(g, Vector3(-0.45, 0.0, -0.2), Vector3(0.45, 0.04, 0.2), "ember", false)
	flames(g, Vector3(0, 0.12, 0), 0.8, 0.9, 36)
	embers(g, Vector3(0, 0.3, 0), 0.3, 10)


# ================================================================== Map 1 (Kaltenbrunn) additions

static var _prism: PrismMesh
static var _hex: CylinderMesh
static var _cone: CylinderMesh
static var _tip: CylinderMesh


## Unit triangular prism (apex up, centred), for roofs and gables.
static func unit_prism() -> PrismMesh:
	if _prism == null:
		_prism = PrismMesh.new()
		_prism.size = Vector3.ONE
	return _prism


## Six-sided unit column, for crystals.
static func unit_hex() -> CylinderMesh:
	if _hex == null:
		_hex = CylinderMesh.new()
		_hex.top_radius = 0.5
		_hex.bottom_radius = 0.5
		_hex.height = 1.0
		_hex.radial_segments = 6
		_hex.rings = 1
	return _hex


## Unit cone-ish frustum (top radius 0.15), for crystal tips, lamp shades and bells.
static func unit_cone() -> CylinderMesh:
	if _cone == null:
		_cone = CylinderMesh.new()
		_cone.top_radius = 0.15
		_cone.bottom_radius = 0.5
		_cone.height = 1.0
		_cone.radial_segments = 12
		_cone.rings = 1
	return _cone


## Unit hexagonal point (top radius 0), for crystal tips.
static func unit_tip() -> CylinderMesh:
	if _tip == null:
		_tip = CylinderMesh.new()
		_tip.top_radius = 0.0
		_tip.bottom_radius = 0.5
		_tip.height = 1.0
		_tip.radial_segments = 6
		_tip.rings = 1
	return _tip


static func _mesh(parent: Node3D, mesh: Mesh, center: Vector3, size: Vector3, key: String, rot_deg: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.get_mat(key)
	mi.position = center
	mi.rotation = rot_deg * (PI / 180.0)
	mi.scale = size
	parent.add_child(mi)
	return mi


static func prism(parent: Node3D, center: Vector3, size: Vector3, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mesh(parent, unit_prism(), center, size, key, rot_deg)


static func hexcol(parent: Node3D, center: Vector3, radius: float, height: float, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mesh(parent, unit_hex(), center, Vector3(radius * 2.0, height, radius * 2.0), key, rot_deg)


static func cone(parent: Node3D, center: Vector3, radius: float, height: float, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mesh(parent, unit_cone(), center, Vector3(radius * 2.0, height, radius * 2.0), key, rot_deg)


## A box stretched between two points (beams, braces, struts, cables).
static func strut(parent: Node3D, a: Vector3, b: Vector3, thick: float, key: String, round_: bool = false) -> MeshInstance3D:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.001:
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = unit_cyl() if round_ else unit_box()
	mi.material_override = Mats.get_mat(key)
	var y: Vector3 = d / length
	var x: Vector3 = y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x * thick, y * length, z * thick), (a + b) * 0.5)
	parent.add_child(mi)
	return mi


## A sagging cable between two points, built from short round segments.
static func cable(parent: Node3D, a: Vector3, b: Vector3, sag: float, radius: float = 0.03, segments: int = 8, key: String = "rubber") -> void:
	var prev: Vector3 = a
	for i: int in segments:
		var t: float = float(i + 1) / float(segments)
		var p: Vector3 = a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		var mi: MeshInstance3D = strut(parent, prev, p, radius * 2.0, key, true)
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prev = p


## Gable roof over a rectangle, ridge along X (along_x) or Z, with snow on both slopes.
static func gable_roof(parent: Node3D, lo: Vector3, hi: Vector3, rise: float, along_x: bool, key: String = "roof", snow: bool = true) -> void:
	var c: Vector3 = Vector3((lo.x + hi.x) * 0.5, lo.y + rise * 0.5, (lo.z + hi.z) * 0.5)
	var w: float = (hi.z - lo.z) if along_x else (hi.x - lo.x)
	var length: float = (hi.x - lo.x) if along_x else (hi.z - lo.z)
	var yaw: float = 90.0 if along_x else 0.0
	prism(parent, c, Vector3(w, rise, length), key, Vector3(0, yaw, 0))
	if not snow:
		return
	var slope: float = rad_to_deg(atan2(rise, w * 0.5))
	var slant: float = sqrt(rise * rise + w * w * 0.25)
	for s: float in [-1.0, 1.0]:
		var n: Vector3 = Vector3(0, w * 0.5, rise * s).normalized() if along_x else Vector3(rise * s, w * 0.5, 0).normalized()
		var mid: Vector3 = c + (Vector3(0, 0, s * w * 0.25) if along_x else Vector3(s * w * 0.25, 0, 0)) + n * 0.07
		var rot: Vector3 = Vector3(s * slope, 0, 0) if along_x else Vector3(0, 0, -s * slope)
		var sz: Vector3 = Vector3(length * 0.98, 0.1, slant * 0.92) if along_x else Vector3(slant * 0.92, 0.1, length * 0.98)
		var mi: MeshInstance3D = obox(parent, mid, sz, "snow", rot)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mine ore cart (Hunt wagon) with a heap of salt rock, on its own wheelsets.
static func ore_cart(parent: Node3D, pos: Vector3, yaw: float, load_key: String = "ore_salt", tipped: float = 0.0) -> Node3D:
	var g: Node3D = group(parent, "OreCart", pos, yaw)
	g.rotation.z = deg_to_rad(tipped)
	block(g, Vector3(-0.55, 0.32, -0.8), Vector3(0.55, 1.05, 0.8), "rust")
	block(g, Vector3(-0.6, 1.0, -0.85), Vector3(0.6, 1.08, 0.85), "iron")
	for sz: float in [-0.55, 0.55]:
		block(g, Vector3(-0.58, 0.45, sz - 0.04), Vector3(0.58, 0.95, sz + 0.04), "iron")
		for sx: float in [-0.45, 0.45]:
			cyl(g, Vector3(sx, 0.2, sz), 0.2, 0.08, "iron", Vector3(0, 0, 90))
	block(g, Vector3(-0.3, 0.26, -0.95), Vector3(0.3, 0.42, 0.95), "iron")
	if load_key != "":
		ball(g, Vector3(0, 1.05, 0), Vector3(1.0, 0.45, 1.5), load_key)
	return g


## Barbed-wire run: Y-posts leaning outward (-out) and four strands.
static func barbed_wire(parent: Node3D, a: Vector3, b: Vector3, out: Vector3, height: float = 0.7) -> void:
	var length: float = a.distance_to(b)
	var n: int = maxi(1, int(length / 3.0))
	var lean: Vector3 = out.normalized() * 0.25
	for i: int in n + 1:
		var p: Vector3 = a.lerp(b, float(i) / float(n))
		strut(parent, p, p + Vector3(0, height, 0) + lean, 0.05, "iron")
	for k: int in 4:
		var h: float = height * (0.25 + 0.25 * float(k))
		var l2: Vector3 = lean * (h / height)
		var mi: MeshInstance3D = strut(parent, a + Vector3(0, h, 0) + l2, b + Vector3(0, h, 0) + l2, 0.012, "rust")
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a loose coil of concertina at the foot
	for i2: int in int(length / 0.6):
		var q: Vector3 = a.lerp(b, (float(i2) + 0.5) / (length / 0.6)) + Vector3(0, height + 0.15, 0) + lean
		var ring: MeshInstance3D = cyl(parent, q, 0.18, 0.012, "rust", Vector3(0, rad_to_deg(atan2((b - a).x, (b - a).z)), 90))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A low wall of sandbags from a to b (rows high), staggered.
static func sandbags(parent: Node3D, a: Vector3, b: Vector3, rows: int = 2) -> void:
	var length: float = a.distance_to(b)
	var yaw: float = rad_to_deg(atan2((b - a).x, (b - a).z))
	var n: int = maxi(1, int(length / 0.6))
	for r: int in rows:
		for i: int in n:
			var t: float = (float(i) + 0.5 + (0.5 if r % 2 == 1 else 0.0)) / float(n)
			if t > 1.0:
				continue
			var p: Vector3 = a.lerp(b, t) + Vector3(0, 0.12 + r * 0.22, 0)
			ball(parent, p, Vector3(0.42, 0.26, 0.62), "sandbag").rotation.y = deg_to_rad(yaw + 90.0)


## Timber pit-prop set (two legs and a cap) framing a passage of the given width.
static func pit_prop(parent: Node3D, pos: Vector3, yaw: float, width: float, height: float, key: String = "pine") -> void:
	var g: Node3D = group(parent, "PitProp", pos, yaw)
	for s: float in [-1.0, 1.0]:
		cyl(g, Vector3(s * (width * 0.5 - 0.14), height * 0.5, 0), 0.13, height, key, Vector3(0, 0, -s * 3.0))
		block(g, Vector3(s * (width * 0.5 - 0.14) - 0.08, height - 0.32, -0.14), Vector3(s * (width * 0.5 - 0.14) + 0.08, height - 0.2, 0.14), key)
	block(g, Vector3(-width * 0.5 - 0.1, height - 0.2, -0.15), Vector3(width * 0.5 + 0.1, height + 0.08, 0.15), key)
	for i: int in 3:
		block(g, Vector3(-width * 0.4 + i * width * 0.4 - 0.15, height + 0.08, -0.1), Vector3(-width * 0.4 + i * width * 0.4 + 0.15, height + 0.18, 0.1), key)


## Hospital gurney with a sheet (and something under it).
static func gurney(parent: Node3D, pos: Vector3, yaw: float, occupied: bool = true) -> void:
	var g: Node3D = group(parent, "Gurney", pos, yaw)
	block(g, Vector3(-0.35, 0.78, -1.0), Vector3(0.35, 0.82, 1.0), "steel")
	for sx: float in [-0.3, 0.3]:
		for sz: float in [-0.9, 0.9]:
			block(g, Vector3(sx - 0.02, 0.1, sz - 0.02), Vector3(sx + 0.02, 0.78, sz + 0.02), "steel")
			cyl(g, Vector3(sx, 0.06, sz), 0.06, 0.04, "rubber", Vector3(0, 0, 90))
	block(g, Vector3(-0.3, 0.3, -0.9), Vector3(0.3, 0.32, 0.9), "steel")
	if occupied:
		ball(g, Vector3(0, 0.92, 0.1), Vector3(0.5, 0.22, 1.6), "linen")
		ball(g, Vector3(0, 0.95, -0.75), Vector3(0.24, 0.2, 0.26), "linen")
	else:
		block(g, Vector3(-0.32, 0.82, -0.95), Vector3(0.32, 0.86, 0.95), "linen")


## Steel instrument/specimen cabinet with glass doors and jars.
static func cabinet(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, d: float, jars: bool = true) -> void:
	var g: Node3D = group(parent, "Cabinet", pos, yaw)
	block(g, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, h, d * 0.5), "enamel_white")
	block(g, Vector3(-w * 0.5 + 0.05, 0.9, -d * 0.5 - 0.01), Vector3(w * 0.5 - 0.05, h - 0.05, -d * 0.5), "window_dark")
	if jars:
		for row: int in 3:
			for i: int in int(w / 0.18):
				var key: String = "nachtglas_dim" if (row + i) % 5 == 0 else ("bottle_amber" if (row * 3 + i) % 2 == 0 else "bottle_green")
				cyl(g, Vector3(-w * 0.5 + 0.12 + i * 0.18, 1.0 + row * 0.33 + 0.1, -d * 0.5 + 0.12), 0.06, 0.2, key)
	block(g, Vector3(-0.01, 0.9, -d * 0.5 - 0.02), Vector3(0.01, h - 0.05, -d * 0.5 - 0.01), "steel")


## A round dial gauge on a wall (face toward local -Z).
static func gauge(parent: Node3D, pos: Vector3, yaw: float, r: float = 0.14) -> void:
	var g: Node3D = group(parent, "Gauge", pos, yaw)
	cyl(g, Vector3(0, 0, -0.03), r + 0.02, 0.06, "brass", Vector3(90, 0, 0))
	cyl(g, Vector3(0, 0, -0.062), r, 0.01, "gauge_face", Vector3(90, 0, 0))
	obox(g, Vector3(r * 0.25, r * 0.2, -0.07), Vector3(0.012, r * 0.8, 0.006), "black_paint", Vector3(0, 0, -50))


static func oil_drum(parent: Node3D, pos: Vector3, key: String = "rust", tipped: bool = false) -> void:
	var rot: Vector3 = Vector3(0, 0, 90) if tipped else Vector3.ZERO
	var c: Vector3 = pos + (Vector3(0, 0.29, 0) if tipped else Vector3(0, 0.45, 0))
	cyl(parent, c, 0.29, 0.9, key, rot)
	if not tipped:
		for h: float in [0.3, 0.6]:
			cyl(parent, pos + Vector3(0, h, 0), 0.3, 0.03, "iron")


## A cluster of hexagonal crystals bursting from a point (local up = +Y).
static func crystal_cluster(parent: Node3D, pos: Vector3, seed_v: int, size: float, key: String, up: Vector3 = Vector3.UP) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	var g: Node3D = Node3D.new()
	g.name = "Crystals"
	g.position = pos
	parent.add_child(g)
	if not up.is_equal_approx(Vector3.UP):
		var ax: Vector3 = Vector3.UP.cross(up.normalized())
		if ax.length() > 0.001:
			g.basis = Basis(ax.normalized(), Vector3.UP.angle_to(up.normalized()))
	for i: int in rng.randi_range(5, 9):
		var h: float = size * rng.randf_range(0.4, 1.0) * (1.6 if i == 0 else 1.0)
		var r: float = size * rng.randf_range(0.07, 0.14) * (1.5 if i == 0 else 1.0)
		var tilt: Vector3 = Vector3(rng.randf_range(-35, 35), rng.randf_range(0, 360), rng.randf_range(-35, 35)) if i > 0 else Vector3(0, rng.randf_range(0, 60), 0)
		var holder: Node3D = Node3D.new()
		holder.rotation = tilt * (PI / 180.0)
		g.add_child(holder)
		hexcol(holder, Vector3(0, h * 0.4, 0), r, h * 0.8, key)
		_mesh(holder, unit_tip(), Vector3(0, h * 0.9, 0), Vector3(r * 2.0, h * 0.2, r * 2.0), key, Vector3.ZERO)


## A cast bell (mouth down) at pos = the crown, total height h.
static func bell(parent: Node3D, pos: Vector3, h: float, key: String = "brass") -> void:
	cone(parent, pos + Vector3(0, -h * 0.35, 0), h * 0.36, h * 0.7, key)
	cyl(parent, pos + Vector3(0, -h * 0.82, 0), h * 0.42, h * 0.16, key)
	cyl(parent, pos + Vector3(0, -h * 0.02, 0), h * 0.14, h * 0.08, key)
	ball(parent, pos + Vector3(0, -h * 0.95, 0), Vector3(h * 0.12, h * 0.12, h * 0.12), "iron")


## Merges the primitive meshes under `root` into one mesh per material, in root's local space (for props that
## move as a whole, e.g. a falling chandelier). Glowing materials don't cast shadows.
static func bake(root: Node3D) -> void:
	var groups: Dictionary = {}
	var victims: Array[MeshInstance3D] = []
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
			continue
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var key: int = mi.material_override.get_instance_id()
		if not groups.has(key):
			var st: SurfaceTool = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"mat": mi.material_override, "st": st}
		(groups[key]["st"] as SurfaceTool).append_from(mi.mesh, 0, xf)
		victims.append(mi)
	for mi: MeshInstance3D in victims:
		mi.get_parent().remove_child(mi)
		mi.free()
	for k: int in groups.keys():
		var out: MeshInstance3D = MeshInstance3D.new()
		out.mesh = (groups[k]["st"] as SurfaceTool).commit()
		out.material_override = groups[k]["mat"]
		var m: Material = groups[k]["mat"]
		if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
			out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(out)


## A salt-crystal chandelier hanging at the parent's origin on a chain `chain` metres long: a brass ring of
## candle bulbs, a fringe of crystal drops and a crystal pendant. Baked into a few meshes.
static func crystal_chandelier(parent: Node3D, chain: float, lit_key: String = "candle") -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "ChandelierArt"
	parent.add_child(g)
	block(g, Vector3(-0.03, 0.55, -0.03), Vector3(0.03, 0.55 + chain, 0.03), "iron", false)
	for tier: int in 2:
		var r: float = 1.15 - tier * 0.45
		var y: float = tier * 0.38
		var prev: Vector3 = Vector3(r, y, 0)
		for k: int in 16:
			var a: float = TAU * float(k + 1) / 16.0
			var p: Vector3 = Vector3(cos(a) * r, y, sin(a) * r)
			strut(g, prev, p, 0.07, "brass")
			prev = p
		for k2: int in 4:
			var a2: float = TAU * (float(k2) + 0.5) / 4.0
			strut(g, Vector3(0, 0.55, 0), Vector3(cos(a2) * r, y, sin(a2) * r), 0.03, "iron")
		for k3: int in 16:
			var a3: float = TAU * (float(k3) + 0.5) / 16.0
			var dp: Vector3 = Vector3(cos(a3) * r, y - 0.3 - (k3 % 2) * 0.12, sin(a3) * r)
			hexcol(g, dp, 0.05, 0.42, "salt_crystal")
			if k3 % 2 == 0 and tier == 0:
				cyl(g, Vector3(cos(a3) * r, y + 0.08, sin(a3) * r), 0.03, 0.12, "brass")
				ball(g, Vector3(cos(a3) * r, y + 0.2, sin(a3) * r), Vector3(0.06, 0.1, 0.06), lit_key)
	_mesh(g, unit_tip(), Vector3(0, -0.75, 0), Vector3(0.6, 1.1, 0.6), "salt_crystal", Vector3(180, 0, 0))
	ball(g, Vector3(0, -0.05, 0), Vector3(0.42, 0.42, 0.42), "salt_crystal")
	bake(g)
	return g


# ================================================================== Map 0 (Crossroads Inn) art pass

static var _quad: QuadMesh


## Unit quad (UV 0..1), facing local +Z.
static func unit_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad


static func _noshadow(mi: MeshInstance3D) -> MeshInstance3D:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A framed procedural painting on a wall; local -Z faces the room (pos = the wall face). `style` is one of the
## Mats "painting:<style>:<n>" styles (landscape, portrait, hunting, photo, licence, stilllife); `n` picks the
## palette/seed; `tilt` hangs it askew; `mount` adds a paper mount inside the frame.
static func painting(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, style: String, n: int = 0,
		frame: String = "frame_gold", tilt: float = 0.0, mount: bool = false) -> Node3D:
	var g: Node3D = group(parent, "Painting", pos, yaw)
	g.rotation.z = deg_to_rad(tilt)
	var fw: float = 0.04 if w < 0.5 else 0.06
	var d: float = 0.04 if w < 0.5 else 0.055
	block(g, Vector3(-w * 0.5 - fw, h * 0.5, -d), Vector3(w * 0.5 + fw, h * 0.5 + fw, 0.0), frame)
	block(g, Vector3(-w * 0.5 - fw, -h * 0.5 - fw, -d), Vector3(w * 0.5 + fw, -h * 0.5, 0.0), frame)
	block(g, Vector3(-w * 0.5 - fw, -h * 0.5, -d), Vector3(-w * 0.5, h * 0.5, 0.0), frame)
	block(g, Vector3(w * 0.5, -h * 0.5, -d), Vector3(w * 0.5 + fw, h * 0.5, 0.0), frame)
	# inner lip (the rebate) and a backboard
	block(g, Vector3(-w * 0.5 - 0.012, -h * 0.5 - 0.012, -d * 0.55), Vector3(w * 0.5 + 0.012, h * 0.5 + 0.012, -d * 0.4), "frame_black")
	block(g, Vector3(-w * 0.5, -h * 0.5, -d * 0.4), Vector3(w * 0.5, h * 0.5, 0.0), "wainscot")
	var cw: float = w
	var ch: float = h
	if mount:
		_noshadow(block(g, Vector3(-w * 0.5, -h * 0.5, -d * 0.6), Vector3(w * 0.5, h * 0.5, -d * 0.55), "paper"))
		cw = w * 0.72
		ch = h * 0.72
	var cv: MeshInstance3D = MeshInstance3D.new()
	cv.mesh = unit_quad()
	cv.material_override = Mats.get_mat("painting:%s:%d" % [style, n])
	cv.position = Vector3(0, 0, -d * 0.62)   # in front of the lip, recessed inside the frame rails
	cv.rotation.y = PI
	cv.scale = Vector3(cw, ch, 1.0)
	cv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(cv)
	return g


## A framed wall mirror (local -Z faces the room).
static func mirror(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, frame: String = "gilt") -> void:
	var g: Node3D = group(parent, "Mirror", pos, yaw)
	block(g, Vector3(-w * 0.5 - 0.06, -h * 0.5 - 0.06, -0.05), Vector3(w * 0.5 + 0.06, h * 0.5 + 0.06, 0.0), frame)
	block(g, Vector3(-w * 0.5 - 0.02, -h * 0.5 - 0.02, -0.055), Vector3(w * 0.5 + 0.02, h * 0.5 + 0.02, -0.05), "frame_black")
	_noshadow(block(g, Vector3(-w * 0.5, -h * 0.5, -0.058), Vector3(w * 0.5, h * 0.5, -0.05), "mirror"))


## Oak barrel: bulged staves, iron hoops, a bung. Upright on the floor at pos, or lying along local Z (tipped).
static func barrel(parent: Node3D, pos: Vector3, yaw: float, r: float = 0.32, h: float = 0.9, tipped: bool = false) -> Node3D:
	var g: Node3D = group(parent, "Barrel", pos + Vector3(0, r if tipped else h * 0.5, 0), yaw)
	if tipped:
		g.rotation.x = PI * 0.5
	cyl(g, Vector3.ZERO, r * 0.92, h, "oak_stave")
	cyl(g, Vector3.ZERO, r, h * 0.55, "oak_stave")
	for y: float in [-h * 0.32, h * 0.32]:
		cyl(g, Vector3(0, y, 0), r * 0.92 + 0.012, 0.04, "iron")
	for y2: float in [-h * 0.11, h * 0.11]:
		cyl(g, Vector3(0, y2, 0), r + 0.01, 0.035, "iron")
	cyl(g, Vector3(0, h * 0.05, -r + 0.005), 0.03, 0.04, "beam", Vector3(90, 0, 0))
	return g


## Wall shelves (the back at local z = 0 against the wall, boards reaching to -depth), with jars, bottles and tins.
static func shelves(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, depth: float = 0.3, boards: int = 3, seed_v: int = 1) -> void:
	var g: Node3D = group(parent, "Shelves", pos, yaw)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	for sx: float in [-1.0, 1.0]:
		block(g, Vector3(sx * w * 0.5 - 0.02, 0, -depth), Vector3(sx * w * 0.5 + 0.02, h, 0), "planks")
	var keys: Array = ["jar_red", "bottle_green", "bottle_amber", "stein", "tin", "jar_red", "paper_old"]
	for i: int in boards:
		var y: float = h * float(i + 1) / float(boards) - 0.03
		block(g, Vector3(-w * 0.5, y, -depth), Vector3(w * 0.5, y + 0.03, 0), "furniture")
		var n: int = int(w / 0.15)
		for k: int in n:
			if rng.randf() < 0.25:
				continue
			var key: String = keys[rng.randi() % keys.size()]
			var x: float = -w * 0.5 + 0.1 + float(k) * 0.15 + rng.randf_range(-0.03, 0.03)
			var z: float = -depth * 0.5 + rng.randf_range(-0.05, 0.05)
			if key == "paper_old":   # a small box / a stack of tied papers
				_noshadow(block(g, Vector3(x - 0.07, y + 0.03, z - 0.06), Vector3(x + 0.07, y + 0.03 + rng.randf_range(0.05, 0.12), z + 0.06), key))
			elif key == "tin":
				_noshadow(cyl(g, Vector3(x, y + 0.03 + 0.08, z), 0.045, 0.16, key))
			else:
				var tall: float = rng.randf_range(0.12, 0.24) if key != "stein" else 0.15
				var rad: float = 0.05 if key == "jar_red" else (0.055 if key == "stein" else 0.035)
				_noshadow(cyl(g, Vector3(x, y + 0.03 + tall * 0.5, z), rad, tall, key))
				if key == "jar_red":
					_noshadow(cyl(g, Vector3(x, y + 0.03 + tall + 0.006, z), rad + 0.004, 0.012, "paper"))


## Bare bulb on a cord under a tin shade, hanging from `ceiling_y`. The lit twin (bulb_warm, slightly larger) goes
## under `lit_parent`, which the map shows only once the power is on. The lit mesh carries meta "keep" so a static
## merge leaves it alone.
static func pendant(parent: Node3D, pos: Vector3, ceiling_y: float, lit_parent: Node3D = null, shade: String = "tin") -> void:
	var g: Node3D = group(parent, "Pendant", pos)
	_noshadow(block(g, Vector3(-0.008, 0.12, -0.008), Vector3(0.008, ceiling_y - pos.y, 0.008), "rubber"))
	cyl(g, Vector3(0, ceiling_y - pos.y - 0.02, 0), 0.05, 0.04, "iron")
	cone(g, Vector3(0, 0.1, 0), 0.2, 0.15, shade)
	cyl(g, Vector3(0, 0.17, 0), 0.03, 0.06, "bakelite")
	_noshadow(ball(g, Vector3.ZERO, Vector3(0.085, 0.115, 0.085), "bulb_off"))
	if lit_parent != null:
		var lit: MeshInstance3D = _noshadow(ball(lit_parent, pos, Vector3(0.095, 0.125, 0.095), "bulb_warm"))
		lit.set_meta("keep", true)


## A cobweb in a ceiling corner: two thin translucent triangles, one hanging across the corner's diagonal and one
## flat under the ceiling. `corner` is the ceiling corner point; the web spans into local +X / +Z.
static func cobweb(parent: Node3D, corner: Vector3, yaw: float, size: float = 0.8) -> void:
	var g: Node3D = group(parent, "Cobweb", corner, yaw)
	_noshadow(prism(g, Vector3(size * 0.3, -size * 0.42, size * 0.3), Vector3(size * 0.85, size * 0.85, 0.003), "cobweb", Vector3(0, 45, 180)))
	_noshadow(prism(g, Vector3(size * 0.26, -0.01, size * 0.26), Vector3(size * 0.75, size * 0.75, 0.003), "cobweb", Vector3(90, 45, 0)))


## A puddle on a floor at `pos.y` (the floor's top): a glossy dark, flattened disc.
static func puddle(parent: Node3D, pos: Vector3, w: float, d: float, yaw: float = 0.0) -> void:
	var mi: MeshInstance3D = _noshadow(ball(parent, pos + Vector3(0, 0.003, 0), Vector3(w, 0.006, d), "puddle"))
	mi.rotation.y = deg_to_rad(yaw)


## A heavy workbench (top at 0.9) with a vice, a shelf of tins below and tools on the top. Local -Z faces the room.
static func workbench(parent: Node3D, pos: Vector3, yaw: float, w: float = 2.0, d: float = 0.7) -> void:
	var g: Node3D = group(parent, "Workbench", pos, yaw)
	block(g, Vector3(-w * 0.5, 0.82, -d * 0.5), Vector3(w * 0.5, 0.9, d * 0.5), "planks")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			block(g, Vector3(sx * (w * 0.5 - 0.1) - 0.05, 0, sz * (d * 0.5 - 0.1) - 0.05), Vector3(sx * (w * 0.5 - 0.1) + 0.05, 0.82, sz * (d * 0.5 - 0.1) + 0.05), "beam")
	block(g, Vector3(-w * 0.5 + 0.05, 0.25, -d * 0.5 + 0.08), Vector3(w * 0.5 - 0.05, 0.29, d * 0.5 - 0.08), "planks")
	# vice at the left end, a tool roll, tins, a hammer and an oil can
	block(g, Vector3(-w * 0.5 + 0.1, 0.9, -d * 0.5 - 0.1), Vector3(-w * 0.5 + 0.28, 1.08, -d * 0.5 + 0.1), "iron")
	cyl(g, Vector3(-w * 0.5 + 0.19, 1.0, -d * 0.5 - 0.22), 0.015, 0.3, "steel", Vector3(0, 0, 90))
	block(g, Vector3(w * 0.5 - 0.6, 0.9, -0.1), Vector3(w * 0.5 - 0.2, 0.95, 0.22), "leather")
	for i: int in 3:
		_noshadow(cyl(g, Vector3(-0.3 + i * 0.16, 0.37, d * 0.2), 0.05, 0.16, "tin"))
	_noshadow(cyl(g, Vector3(0.1, 0.96, 0.12), 0.045, 0.12, "tin"))
	obox(g, Vector3(-0.2, 0.915, -0.05), Vector3(0.03, 0.03, 0.3), "beam", Vector3(0, 30, 0))
	block(g, Vector3(-0.17, 0.9, -0.2), Vector3(-0.09, 0.95, -0.14), "iron")
	# a drawer front
	block(g, Vector3(0.1, 0.68, -d * 0.5 - 0.01), Vector3(0.7, 0.8, -d * 0.5), "furniture")
	block(g, Vector3(0.36, 0.72, -d * 0.5 - 0.03), Vector3(0.44, 0.76, -d * 0.5 - 0.01), "brass")


## A slumped sack (flour, salt, potatoes) with a tied neck.
static func sack(parent: Node3D, pos: Vector3, yaw: float, s: float = 1.0) -> void:
	var g: Node3D = group(parent, "Sack", pos, yaw)
	ball(g, Vector3(0, 0.27 * s, 0), Vector3(0.56, 0.56, 0.42) * s, "sandbag")
	ball(g, Vector3(0, 0.52 * s, 0.02 * s), Vector3(0.3, 0.22, 0.24) * s, "sandbag")
	cyl(g, Vector3(0, 0.58 * s, 0.02 * s), 0.07 * s, 0.03 * s, "rubber")


## Stair newel post with a turned cap and a ball finial.
static func newel(parent: Node3D, pos: Vector3, h: float = 1.05, key: String = "furniture") -> void:
	var g: Node3D = group(parent, "Newel", pos)
	block(g, Vector3(-0.07, 0, -0.07), Vector3(0.07, h - 0.12, 0.07), key)
	block(g, Vector3(-0.09, h - 0.12, -0.09), Vector3(0.09, h - 0.06, 0.09), key)
	cyl(g, Vector3(0, h - 0.03, 0), 0.05, 0.06, key)
	ball(g, Vector3(0, h + 0.05, 0), Vector3(0.14, 0.14, 0.14), key)


## Painted stencil text on a wall (local -Z faces the room; pos is on the wall face). T-247: in the surface look
## (SurfaceText: a period face, lit by the scene, no outline, toned down); `look` picks paint, chalk or print.
static func stencil(parent: Node3D, pos: Vector3, yaw: float, text: String, size_px: int = 40, color: Color = Color(0.85, 0.82, 0.7, 0.75),
		pixel: float = 0.004, look: int = SurfaceText.PAINT) -> Label3D:
	var g: Node3D = group(parent, "Stencil", pos, yaw)
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = size_px
	l.pixel_size = pixel
	l.modulate = color
	l.position = Vector3(0, 0, -0.012)
	l.rotation.y = PI
	SurfaceText.apply(l, look)
	g.add_child(l)
	return l


## Iron pipe between two points with a collar at each end.
static func pipe(parent: Node3D, a: Vector3, b: Vector3, r: float = 0.035, key: String = "iron") -> void:
	strut(parent, a, b, r * 2.0, key, true)
	var d: Vector3 = (b - a).normalized()
	for p: Vector3 in [a, b]:
		var mi: MeshInstance3D = strut(parent, p - d * 0.03, p + d * 0.03, (r + 0.015) * 2.0, key, true)
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Wall-mounted iron fuse / junction box with a cable gland on top and a row of porcelain fuses (local -Z out).
static func fuse_box(parent: Node3D, pos: Vector3, yaw: float, w: float = 0.5, h: float = 0.7) -> void:
	var g: Node3D = group(parent, "FuseBox", pos, yaw)
	block(g, Vector3(-w * 0.5, -h * 0.5, -0.16), Vector3(w * 0.5, h * 0.5, 0.0), "machine_grey")
	block(g, Vector3(-w * 0.5 + 0.03, -h * 0.5 + 0.03, -0.175), Vector3(w * 0.5 - 0.03, h * 0.5 - 0.03, -0.16), "black_paint")
	for i: int in 4:
		var x: float = -w * 0.5 + 0.09 + float(i) * (w - 0.18) / 3.0
		_noshadow(cyl(g, Vector3(x, 0.05, -0.19), 0.03, 0.03, "enamel_white", Vector3(90, 0, 0)))
		_noshadow(block(g, Vector3(x - 0.012, -0.14, -0.185), Vector3(x + 0.012, -0.08, -0.175), "bakelite"))
	block(g, Vector3(-0.12, -h * 0.5 + 0.06, -0.19), Vector3(0.12, -h * 0.5 + 0.1, -0.175), "gauge_face")
	cyl(g, Vector3(0.1, h * 0.5 + 0.03, -0.08), 0.03, 0.06, "iron")



# ================================================================== Map 2 (Totenhafen) props (T-036)

## Cast-iron mooring bollard: a squat drum with a flared cap, on a base plate.
static func bollard(parent: Node3D, pos: Vector3, key: String = "iron") -> void:
	var g: Node3D = group(parent, "Bollard", pos)
	block(g, Vector3(-0.32, 0, -0.32), Vector3(0.32, 0.06, 0.32), key)
	cyl(g, Vector3(0, 0.36, 0), 0.17, 0.6, key)
	cyl(g, Vector3(0, 0.7, 0), 0.24, 0.1, key)
	ball(g, Vector3(0, 0.78, 0), Vector3(0.44, 0.14, 0.44), key)


## Lead-sealed Nachtglas coffin on its pallet: a 2.0 × 0.7 × 0.6 lead case with soldered seams, three steel
## straps, a Helvetia maker's plate, a stencilled unit number, and a hair-line violet seam under the lid where
## the seal weeps. Local -Z is the front (the plate end). Non-colliding dressing; the navmesh block is separate.
static func coffin(parent: Node3D, pos: Vector3, yaw: float, unit: String, pallet: bool = true) -> void:
	var g: Node3D = group(parent, "Coffin", pos, yaw)
	var y0: float = 0.0
	if pallet:
		for sx: float in [-0.95, 0.0, 0.95]:
			block(g, Vector3(sx - 0.05, 0, -0.42), Vector3(sx + 0.05, 0.1, 0.42), "planks")
		for sz: float in [-0.36, 0.0, 0.36]:
			block(g, Vector3(-1.05, 0.1, sz - 0.05), Vector3(1.05, 0.14, sz + 0.05), "planks")
		y0 = 0.14
	block(g, Vector3(-1.0, y0, -0.35), Vector3(1.0, y0 + 0.56, 0.35), "lead")
	block(g, Vector3(-1.03, y0 + 0.5, -0.38), Vector3(1.03, y0 + 0.6, 0.38), "lead")
	for sx2: float in [-0.6, 0.0, 0.6]:
		block(g, Vector3(sx2 - 0.03, y0 - 0.005, -0.37), Vector3(sx2 + 0.03, y0 + 0.61, 0.37), "steel")
	_noshadow(block(g, Vector3(-0.99, y0 + 0.495, -0.352), Vector3(0.99, y0 + 0.505, 0.352), "nachtglas_dim"))
	block(g, Vector3(-0.16, y0 + 0.14, -0.356), Vector3(0.16, y0 + 0.3, -0.35), "brass_plate")
	stencil(g, Vector3(0.55, y0 + 0.3, -0.352), 0.0, unit, 22, Color(0.85, 0.82, 0.7, 0.8), 0.003)
	stencil(g, Vector3(0.0, y0 + 0.21, -0.354), 0.0, "HELVETIA AUTOMATEN AG", 9, Color(0.12, 0.09, 0.03, 0.9), 0.003)


## A coiled hawser lying flat (torus of rope segments) with a tail.
static func rope_coil(parent: Node3D, pos: Vector3, r: float = 0.45) -> void:
	var g: Node3D = group(parent, "RopeCoil", pos)
	var prev: Vector3 = Vector3(r, 0.04, 0)
	for k: int in 14:
		var a: float = TAU * float(k + 1) / 14.0
		var p: Vector3 = Vector3(cos(a) * r, 0.04, sin(a) * r)
		strut(g, prev, p, 0.08, "rope", true)
		prev = p
	prev = Vector3(r * 0.7, 0.11, 0)
	for k2: int in 12:
		var a2: float = TAU * float(k2 + 1) / 12.0
		var p2: Vector3 = Vector3(cos(a2) * r * 0.7, 0.11, sin(a2) * r * 0.7)
		strut(g, prev, p2, 0.08, "rope", true)
		prev = p2
	strut(g, Vector3(r, 0.04, 0), Vector3(r + 0.9, 0.03, 0.4), 0.07, "rope", true)


## Cork life ring on a wall hook (local -Z faces out).
static func life_ring(parent: Node3D, pos: Vector3, yaw: float) -> void:
	var g: Node3D = group(parent, "LifeRing", pos, yaw)
	var prev: Vector3 = Vector3(0.36, 0, -0.08)
	for k: int in 12:
		var a: float = TAU * float(k + 1) / 12.0
		var p: Vector3 = Vector3(cos(a) * 0.36, sin(a) * 0.36, -0.08)
		strut(g, prev, p, 0.12, "enamel_white" if k % 3 != 2 else "red_paint", true)
		prev = p
	block(g, Vector3(-0.03, 0.34, -0.06), Vector3(0.03, 0.5, 0.0), "iron")


## A torpedo on two trestles (or lying on the deck): grey body, red-lead warhead band, brass propellers, fins.
## Axis along local Z, nose at -Z.
static func torpedo(parent: Node3D, pos: Vector3, yaw: float, length: float = 7.0, trestles: bool = true) -> void:
	var g: Node3D = group(parent, "Torpedo", pos, yaw)
	var r: float = 0.27
	var y: float = 0.95 if trestles else r
	if trestles:
		for tz: float in [-length * 0.3, length * 0.3]:
			for sx: float in [-0.45, 0.45]:
				block(g, Vector3(sx - 0.05, 0, tz - 0.05), Vector3(sx + 0.05, 0.72, tz + 0.05), "furniture")
			block(g, Vector3(-0.55, 0.68, tz - 0.08), Vector3(0.55, 0.76, tz + 0.08), "furniture")
	cyl(g, Vector3(0, y, 0), r, length * 0.82, "grey_paint", Vector3(90, 0, 0))
	cone(g, Vector3(0, y, -length * 0.41 - length * 0.09), r, length * 0.18, "grey_paint", Vector3(-90, 0, 0))
	cyl(g, Vector3(0, y, -length * 0.3), r + 0.004, 0.5, "hull_red", Vector3(90, 0, 0))
	cone(g, Vector3(0, y, length * 0.41 + length * 0.06), r, length * 0.12, "grey_paint", Vector3(90, 0, 0))
	for a: float in [0.0, 90.0, 180.0, 270.0]:
		obox(g, Vector3(0, y, length * 0.44), Vector3(0.05, 0.34, 0.5), "grey_paint", Vector3(0, 0, a))
	for a2: float in [0.0, 60.0, 120.0]:
		obox(g, Vector3(0, y, length * 0.5 + 0.02), Vector3(0.46, 0.03, 0.08), "brass", Vector3(0, 0, a2))
	cyl(g, Vector3(0, y, length * 0.5), 0.05, 0.1, "brass", Vector3(90, 0, 0))


## A heap of fishing nets with cork floats.
static func net_pile(parent: Node3D, pos: Vector3, size: Vector3, seed_v: int) -> void:
	var g: Node3D = group(parent, "NetPile", pos)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v
	ball(g, Vector3(0, size.y * 0.4, 0), Vector3(size.x, size.y * 0.8, size.z), "net")
	ball(g, Vector3(size.x * 0.2, size.y * 0.7, -size.z * 0.15), Vector3(size.x * 0.6, size.y * 0.6, size.z * 0.6), "net")
	for i: int in 7:
		var p: Vector3 = Vector3(rng.randf_range(-0.45, 0.45) * size.x, size.y * rng.randf_range(0.5, 0.95), rng.randf_range(-0.45, 0.45) * size.z)
		ball(g, p, Vector3(0.14, 0.1, 0.14), "cream")


## Steel rung ladder against a wall (local -Z faces away from the wall), from y 0 to height.
static func ladder(parent: Node3D, pos: Vector3, yaw: float, height: float, key: String = "iron") -> void:
	var g: Node3D = group(parent, "Ladder", pos, yaw)
	for sx: float in [-0.2, 0.2]:
		block(g, Vector3(sx - 0.025, 0, -0.14), Vector3(sx + 0.025, height, -0.09), key)
	var n: int = int(height / 0.3)
	for k: int in n:
		cyl(g, Vector3(0, 0.15 + k * 0.3, -0.115), 0.016, 0.4, key, Vector3(0, 0, 90))


## A ladder stowed on hooks along a wall (T-229: a ladder nobody is meant to climb lies down). pos is on the wall
## face at the ladder's centre, local -Z out of the wall; the ladder runs along local X at that height.
static func ladder_stowed(parent: Node3D, pos: Vector3, yaw: float, length: float, key: String = "iron") -> void:
	var g: Node3D = group(parent, "LadderStowed", pos, yaw)
	for sy: float in [-0.2, 0.2]:
		block(g, Vector3(-length * 0.5, sy - 0.025, -0.16), Vector3(length * 0.5, sy + 0.025, -0.11), key)
	var n: int = int(length / 0.3)
	for k: int in n:
		cyl(g, Vector3(-length * 0.5 + 0.15 + k * 0.3, 0.0, -0.135), 0.016, 0.4, key)
	for hx: float in [-length * 0.3, length * 0.3]:
		block(g, Vector3(hx - 0.02, -0.26, -0.2), Vector3(hx + 0.02, -0.22, 0.0), "iron")   # the hooks
		block(g, Vector3(hx - 0.02, -0.26, -0.2), Vector3(hx + 0.02, -0.14, -0.17), "iron")


## A locked ladder guard (T-229: a ladder that leads nowhere a player may go is barred the way real ones are): a
## steel plate over the rungs from knee height to `h`, hasp and padlock. Same frame as Props.ladder (pos at the foot).
static func ladder_guard(parent: Node3D, pos: Vector3, yaw: float, h: float = 2.2, key: String = "machine_grey") -> void:
	var g: Node3D = group(parent, "LadderGuard", pos, yaw)
	block(g, Vector3(-0.3, 0.35, -0.21), Vector3(0.3, h, -0.18), key)
	for sy: float in [0.4, h - 0.05]:
		block(g, Vector3(-0.27, sy - 0.02, -0.17), Vector3(0.27, sy + 0.02, -0.14), "iron")   # the hinge straps
	block(g, Vector3(0.24, h * 0.5 - 0.04, -0.235), Vector3(0.3, h * 0.5 + 0.04, -0.21), "iron")   # the hasp
	cyl(g, Vector3(0.3, h * 0.5 - 0.08, -0.225), 0.035, 0.02, "brass", Vector3(90, 0, 0))          # the padlock


## A chain across a ladder with a tag (T-229): the ladder is closed, not broken. pos as Props.ladder's, y_chain up it.
static func ladder_chain(parent: Node3D, pos: Vector3, yaw: float, y_chain: float = 1.1, tag: String = "GESPERRT") -> void:
	var g: Node3D = group(parent, "LadderChain", pos, yaw)
	cable(g, Vector3(-0.2, y_chain, -0.2), Vector3(0.2, y_chain, -0.2), 0.06, 0.012, 6, "iron")
	block(g, Vector3(-0.09, y_chain - 0.19, -0.215), Vector3(0.09, y_chain - 0.07, -0.205), "enamel_white")
	block(g, Vector3(-0.004, y_chain - 0.08, -0.212), Vector3(0.004, y_chain - 0.03, -0.208), "iron")
	stencil(g, Vector3(0, y_chain - 0.13, -0.216), 0.0, tag, 10, Color(0.6, 0.08, 0.06, 0.95))


## A stack of tinned cans (cannery): rows of small cylinders on a board.
static func can_stack(parent: Node3D, pos: Vector3, cols: int, rows: int, layers: int) -> void:
	var g: Node3D = group(parent, "Cans", pos)
	block(g, Vector3(-cols * 0.06 - 0.02, 0, -rows * 0.06 - 0.02), Vector3(cols * 0.06 + 0.02, 0.03, rows * 0.06 + 0.02), "planks")
	for l: int in layers:
		for c: int in cols:
			for r: int in rows:
				_noshadow(cyl(g, Vector3(-cols * 0.06 + 0.06 + c * 0.12, 0.03 + l * 0.11 + 0.055, -rows * 0.06 + 0.06 + r * 0.12), 0.055, 0.11, "can_tin"))


## Hand wheel valve on a pipe (local -Z faces the user).
static func valve_wheel(parent: Node3D, pos: Vector3, yaw: float, r: float = 0.14, key: String = "red_paint") -> void:
	var g: Node3D = group(parent, "Valve", pos, yaw)
	var prev: Vector3 = Vector3(r, 0, 0)
	for k: int in 10:
		var a: float = TAU * float(k + 1) / 10.0
		var p: Vector3 = Vector3(cos(a) * r, sin(a) * r, 0)
		strut(g, prev, p, 0.025, key, true)
		prev = p
	for k2: int in 3:
		var a2: float = TAU * float(k2) / 3.0
		strut(g, Vector3.ZERO, Vector3(cos(a2) * r, sin(a2) * r, 0), 0.02, key, true)
	cyl(g, Vector3(0, 0, 0.04), 0.03, 0.1, "iron", Vector3(90, 0, 0))


## Steel sea grille: vertical bars with two horizontal bands, from (a) to (b) along X or Z, height h.
static func grille(parent: Node3D, a: Vector3, b: Vector3, h: float, step: float = 0.3, key: String = "rust") -> void:
	var g: Node3D = group(parent, "Grille", a)
	var d: Vector3 = b - a
	var n: int = maxi(1, int(d.length() / step))
	for k: int in n + 1:
		var p: Vector3 = d * (float(k) / float(n))
		block(g, p + Vector3(-0.03, 0, -0.03), p + Vector3(0.03, h, 0.03), key)
	for hy: float in [h * 0.3, h * 0.75]:
		strut(g, Vector3(0, hy, 0), d + Vector3(0, hy, 0), 0.08, key)


## Wintergarten / pier railing: posts every 1.5 m with a top rail and a mid rail (round iron).
static func railing(parent: Node3D, a: Vector3, b: Vector3, h: float = 1.05, key: String = "iron", step: float = 1.5) -> void:
	var g: Node3D = group(parent, "Railing", a)
	var d: Vector3 = b - a
	var n: int = maxi(1, int(round(d.length() / step)))
	for k: int in n + 1:
		var p: Vector3 = d * (float(k) / float(n))
		block(g, p + Vector3(-0.03, 0, -0.03), p + Vector3(0.03, h, 0.03), key)
	strut(g, Vector3(0, h, 0), d + Vector3(0, h, 0), 0.06, key, true)
	strut(g, Vector3(0, h * 0.5, 0), d + Vector3(0, h * 0.5, 0), 0.035, key, true)


## Caged bulkhead lamp body only (no light): used for the boat's battle lanterns and the pen bulkheads.
static func bulkhead_lamp(parent: Node3D, pos: Vector3, yaw: float, glass: String = "bulb_off") -> void:
	var g: Node3D = group(parent, "BulkheadLamp", pos, yaw)
	block(g, Vector3(-0.12, -0.12, -0.04), Vector3(0.12, 0.12, 0.0), "iron")
	_noshadow(cyl(g, Vector3(0, 0, -0.1), 0.09, 0.14, glass, Vector3(90, 0, 0)))
	for a: float in [0.0, 60.0, 120.0]:
		obox(g, Vector3(0, 0, -0.12), Vector3(0.22, 0.015, 0.2), "iron", Vector3(0, 0, a))
