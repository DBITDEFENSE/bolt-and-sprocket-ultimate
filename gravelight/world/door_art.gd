class_name DoorArt
extends RefCounted
## The bought doors' look (UPDATE_05 section 5, DECISIONS T-094): a real ledged-and-braced plank door sized to its
## opening, built here because every map's openings differ, with the ironmongery from our own door kit
## (tools_src/blender/world/door_kit.py -> assets/ours/world/door_kit: strap hinges, the brass price plaque, a hasp
## and padlock, a chain, a ring pull) and two of the barricade planks nailed across it. BuyDoor, GateDoor and the
## inn's front door's plaque use it. Visual only: BuyDoor's collider, area, prompt and lift-away tween are unchanged.
##
## Frame (BuyDoor's): origin = the opening's centre on the floor, the leaf in the plane z = 0, -Z the front (the side
## the zone you buy from sees first), +Z the back; the price labels sit on the plaques on both faces.

const KIT: String = "door_kit"
const PLANK_LEN: float = 1.85          # barricade_planks' model length
const PLAQUE_W: float = 0.62           # the kit's plaque (scaled 1.15 across for two-word labels)
const LEAF_T: float = 0.07

static var _leaves: Dictionary = {}    # "w_h" -> ArrayMesh


static func available() -> bool:
	return WorldArt.has(KIT)


## Builds a bought door's leaf and fittings under `g` for an opening of `size`; returns the label planes
## [front z, back z] (the plaques' faces) or [] when the kit is absent (the caller keeps the procedural door).
static func buy_door(g: Node3D, size: Vector3) -> Array:
	if not available():
		return []
	var w: float = size.x
	var h: float = size.y
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Leaf"
	mi.mesh = leaf_mesh(w - 0.04, h - 0.02)
	mi.position = Vector3(0, 0.01, 0)
	g.add_child(mi)
	var zf: float = -LEAF_T * 0.5
	var zb: float = LEAF_T * 0.5
	# strap hinges on the front, at the hinge jamb (-X), and the ring pull by the latch
	for hy: float in [0.42, h - 0.48]:
		_part(g, "Hinge", Vector3(-w * 0.5 + 0.03, hy, zf), 0.0, Vector3.ONE * clampf(w / 1.8, 0.75, 1.15))
	_part(g, "Pull", Vector3(w * 0.32, 1.02, zf), 0.0)
	# two planks nailed across the front (bought, they come off with the door), the chain and padlock over them
	var zx: float = zf - 0.0235
	for d: float in [-1.0, 1.0]:
		var a: Vector2 = Vector2(-w * 0.5 + 0.02, h * 0.14 if d > 0.0 else h * 0.86)
		var b: Vector2 = Vector2(w * 0.5 - 0.02, h * 0.86 if d > 0.0 else h * 0.14)
		var m: Mesh = WorldArt.part_mesh("barricade_planks", "Plank%d" % (2 if d > 0.0 else 4))
		if m == null:
			continue
		var bm: MeshInstance3D = MeshInstance3D.new()
		bm.mesh = m
		var span_len: float = a.distance_to(b) + 0.12
		var ang: float = atan2(b.y - a.y, b.x - a.x)
		# the plank's nails face +Z: turned about Y so they face the front, laid along the diagonal
		bm.transform = Transform3D(Basis(Vector3.BACK, ang) * Basis(Vector3.UP, PI) * Basis.from_scale(Vector3(span_len / PLANK_LEN, 1.0, 1.0)),
			Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, zx - (0.0 if d > 0.0 else 0.046)))
		g.add_child(bm)
	var zc: float = zx - 0.07
	_part(g, "Chain", Vector3(0, 1.12, zc + 0.02), 0.0, Vector3(w * 0.86, 1.0, 1.0))
	_part(g, "Padlock", Vector3(0.04, 0.98, zc), 0.0)
	# the plaques, proud of the planks on the front and of the ledges on the back
	var pf: float = zx - 0.05
	var pb: float = zb + 0.035
	_part(g, "Plaque", Vector3(0, h * 0.6, pf), 0.0, Vector3(1.75, 1.2, 1.0))
	_part(g, "Plaque", Vector3(0, h * 0.6, pb), PI, Vector3(1.75, 1.2, 1.0))
	return [pf - 0.022, pb + 0.022]


## A plaque (front plane at `at`, facing -Z turned by `yaw`) for a label that is painted beside an opening (GateDoor's
## label_offset, the inn's front door); returns the label's distance from `at` along the plaque's facing.
static func plaque(g: Node3D, at: Vector3, yaw: float) -> float:
	if not available():
		return 0.0
	_part(g, "Plaque", at, yaw, Vector3(1.75, 1.2, 1.0))
	return 0.022


## One kit part as a MeshInstance3D (shared mesh, mapped materials).
static func _part(g: Node3D, part_name: String, at: Vector3, yaw: float, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m: Mesh = WorldArt.part_mesh(KIT, part_name)
	if m == null:
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = m
	mi.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	return mi


## A ledged-and-braced leaf w x h (cached per size): vertical boards with hairline gaps over a dark core, three ledges
## and two braces on the back. Boards in the library's weathered planks (UV mode, metre UVs: they lift with the door).
static func leaf_mesh(w: float, h: float) -> ArrayMesh:
	var key: String = "%d_%d" % [int(w * 100.0), int(h * 100.0)]
	if _leaves.has(key):
		return _leaves[key]
	var wood: SurfaceTool = SurfaceTool.new()
	wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var core: SurfaceTool = SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var t: float = LEAF_T * 0.6
	box(core, Vector3(-w * 0.5 + 0.01, 0.01, -t * 0.3), Vector3(w * 0.5 - 0.01, h - 0.03, t * 0.3), false)
	var n: int = maxi(5, int(round(w / 0.17)))
	var pw: float = w / float(n)
	for i: int in n:
		var x0: float = -w * 0.5 + i * pw
		var top: float = h - float((i * 7) % 3) * 0.012
		var dz: float = (fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) - 0.5) * 0.006
		box(wood, Vector3(x0 + 0.004, 0.0, -t * 0.5 + dz), Vector3(x0 + pw - 0.004, top, t * 0.5 + dz), true, Vector2(i * 0.37, 0.0))
	# the back: ledges and braces (the classic Z)
	var zb0: float = t * 0.5
	var zb1: float = LEAF_T * 0.5
	var ledges: Array = [0.28, h * 0.5, h - 0.34]
	for ly: float in ledges:
		box(wood, Vector3(-w * 0.5 + 0.05, ly - 0.07, zb0), Vector3(w * 0.5 - 0.05, ly + 0.07, zb1), false, Vector2(0.0, ly))
	for k: int in 2:
		var y0: float = float(ledges[k]) + 0.07
		var y1: float = float(ledges[k + 1]) - 0.07
		var ax: float = -w * 0.5 + 0.12
		var bx: float = w * 0.5 - 0.12
		var span_len: float = Vector2(bx - ax, y1 - y0).length()
		var ang: float = atan2(y1 - y0, bx - ax)
		var xf: Transform3D = Transform3D(Basis(Vector3.BACK, ang), Vector3((ax + bx) * 0.5, (y0 + y1) * 0.5, (zb0 + zb1) * 0.5))
		box(wood, Vector3(-span_len * 0.5, -0.06, -(zb1 - zb0) * 0.5), Vector3(span_len * 0.5, 0.06, (zb1 - zb0) * 0.5), false, Vector2(k * 0.5, 0.3), xf)
	var am: ArrayMesh = ArrayMesh.new()
	wood.generate_tangents()
	wood.commit(am)
	am.surface_set_material(0, WorldArt.mat("lib_planks__ffd8a0"))   # lighter than the walls: a door reads
	core.generate_tangents()
	core.commit(am)
	am.surface_set_material(1, Mats.get_mat("char"))
	_leaves[key] = am
	return am


## A box into a SurfaceTool with metre UVs (grain_y: the texture's boards run up the box, for vertical planks).
static func box(st: SurfaceTool, a: Vector3, b: Vector3, grain_y: bool, uv_off: Vector2 = Vector2.ZERO, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var lo: Vector3 = a.min(b)
	var hi: Vector3 = a.max(b)
	# the six faces: normal, then the four corners counter-clockwise seen from outside
	var faces: Array = [
		[Vector3(0, 0, -1), [Vector3(hi.x, lo.y, lo.z), Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z)]],
		[Vector3(0, 0, 1), [Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]],
		[Vector3(-1, 0, 0), [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(lo.x, hi.y, hi.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3(1, 0, 0), [Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z)]],
		[Vector3(0, 1, 0), [Vector3(lo.x, hi.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z)]],
		[Vector3(0, -1, 0), [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]],
	]
	for f: Array in faces:
		var nrm: Vector3 = f[0]
		var c: Array = f[1]
		var uvs: Array = []
		for p: Vector3 in c:
			var uv: Vector2
			if absf(nrm.z) > 0.5:
				uv = Vector2(p.x, -p.y)
			elif absf(nrm.x) > 0.5:
				uv = Vector2(p.z, -p.y)
			else:
				uv = Vector2(p.x, p.z)
			if grain_y:
				uv = Vector2(uv.y, uv.x)
			uvs.append(uv + uv_off)
		var wn: Vector3 = (xf.basis * nrm).normalized()
		for idx: int in [0, 2, 1, 0, 3, 2]:   # Godot's front faces wind clockwise
			st.set_normal(wn)
			st.set_uv(uvs[idx])
			st.add_vertex(xf * (c[idx] as Vector3))


## Drops the cached leaves (tests).
static func reset() -> void:
	_leaves = {}
