class_name WorldArt
extends RefCounted
## The world objects' art (UPDATE_05 section 5, DECISIONS T-094): GLBs our own Blender scripts build
## (tools_src/blender/world/*.py -> assets/ours/world/<folder>/model.glb, with LICENSE.txt and SOURCE.txt "Ours"),
## instanced here for the gameplay scripts that draw them (PerkMachine, MysteryCrate, AmmoBox, Barricade, BuyDoor,
## WallBuy, ArmorersBench, Crucible, FieldRadio, PowerSwitch, ExfilPoint).
##
## The GLB contract (tools_src/blender/world/wo_lib.py): Godot's frame (metres, +Y up, front -Z, origin = the floor
## centre of the footprint); every part the game moves is its own node with its pivot at the node origin; empties
## mark where a script hangs something (CapAnchor, LampAnchor ...). Material slots are named, never textured, and
## mapped here once per mesh:
##   lib_<key>[__rrggbb][@local]  MaterialLibrary key (the CC0 PBR set) in UV mode (the GLB's UVs are metres), tinted
##   mats_<key>[@local]           a procedural Mats key (@local: object-space for a part that moves)
##   enamel_ / glass_ / paint_ / neon_ / glow_soft_<rrggbb>   Mats' colour keys
##   neon, backlight, lamp_glass, chalk   left as they are: the owning script overrides them at runtime
## Visuals only: no collision is ever taken from a GLB (UPDATE_05 section 0.4); colliders stay the scripts'.
## Missing or unimported GLB: instance() returns null and the caller keeps its procedural fallback.

const ROOT: String = "res://assets/ours/world/"
## Slots the owning script drives (lit/unlit, power, chalk): never remapped.
const RUNTIME_SLOTS: PackedStringArray = ["neon", "backlight", "lamp_glass", "chalk"]
## A part smaller than this (longest side, metres) casts no shadow (ART_BIBLE section 5: only things bigger than a
## chair cast from omni lights).
const SHADOW_MIN_M: float = 0.45
## Procedural stand-ins when a library set's textures are missing (a checkout without the CC0 library).
const LIB_FALLBACK: Dictionary = {"planks": "planks", "floorboards": "floorboards", "iron": "iron", "leather": "leather",
	"canvas": "tarp", "burlap": "sandbag", "wool": "cloth_red", "fieldstone": "stone", "plaster_worn": "plaster"}

static var _scenes: Dictionary = {}     # folder -> PackedScene (null when absent)
static var _mats: Dictionary = {}       # slot name -> Material
static var _off: int = -1               # --no-world-art (unknown until asked)
static var _part_meshes: Dictionary = {}   # "folder/part" -> Mesh


static func glb_path(folder: String) -> String:
	return ROOT + folder + "/model.glb"


## Whether the folder's GLB exists and is imported.
static func has(folder: String) -> bool:
	return scene(folder) != null


## True when the run asked for the old procedural look (`-- --no-world-art`: the "before" half of a capture pair).
static func disabled() -> bool:
	if _off < 0:
		_off = 1 if OS.get_cmdline_user_args().has("--no-world-art") else 0
	return _off == 1


static func scene(folder: String) -> PackedScene:
	if disabled():
		return null
	if _scenes.has(folder):
		return _scenes[folder]
	var p: String = glb_path(folder)
	var ps: PackedScene = null
	if ResourceLoader.exists(p):
		ps = load(p) as PackedScene
	_scenes[folder] = ps
	return ps


## A fresh instance of the folder's model (named `node_name`), its materials mapped, no collision; null if absent.
static func instance(folder: String, node_name: String = "Model") -> Node3D:
	var ps: PackedScene = scene(folder)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	if n == null:
		return null
	n.name = node_name
	_strip_collision(n)
	for mi: MeshInstance3D in meshes(n):
		_map_mesh(mi.mesh)
		var aabb: AABB = mi.get_aabb()
		if maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) < SHADOW_MIN_M:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## The (shared, material-mapped) mesh of one part of a folder's model, for scripts that draw many copies of it
## (Barricade's planks); null when absent.
static func part_mesh(folder: String, part_name: String) -> Mesh:
	if disabled():
		return null
	var key: String = folder + "/" + part_name
	if _part_meshes.has(key):
		return _part_meshes[key]
	var m: Mesh = null
	var inst: Node3D = instance(folder)
	if inst != null:
		var mi: MeshInstance3D = mesh_of(part(inst, part_name))
		if mi != null:
			m = mi.mesh
		inst.free()
	_part_meshes[key] = m
	return m


## A named part (node) of an instance, or null.
static func part(root: Node, part_name: String) -> Node3D:
	if root == null:
		return null
	return root.find_child(part_name, true, false) as Node3D


## The first MeshInstance3D at or under a part (the part node itself for a plain mesh part).
static func mesh_of(n: Node) -> MeshInstance3D:
	if n == null:
		return null
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var m: MeshInstance3D = mesh_of(c)
		if m != null:
			return m
	return null


## Takes a part out of `root` and parents it to `new_parent`, keeping its place (so a script can animate it on
## its own pivot or hide it independently).
static func detach(root: Node3D, part_name: String, new_parent: Node3D) -> Node3D:
	var p: Node3D = part(root, part_name)
	if p == null:
		return null
	var xf: Transform3D = _rel_xform(p, new_parent)
	p.owner = null
	p.get_parent().remove_child(p)
	new_parent.add_child(p)
	p.transform = xf
	return p


## Every MeshInstance3D under n (n included).
static func meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_collect(n, out)
	return out


static func _collect(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		_collect(c, out)


## Total triangles of an instance (tests, the asset report).
static func triangles(n: Node) -> int:
	var t: int = 0
	for mi: MeshInstance3D in meshes(n):
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			t += ((idx as PackedInt32Array).size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t


## The local AABB of everything drawn under n, in n's own space.
static func local_aabb(n: Node3D) -> AABB:
	var first: bool = true
	var out: AABB = AABB()
	for mi: MeshInstance3D in meshes(n):
		if mi.mesh == null:
			continue
		var b: AABB = _rel_xform(mi, n) * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


static func _rel_xform(c: Node3D, stop: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = c
	while n != null and n != stop:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


# ================================================================== materials

static func _map_mesh(m: Mesh) -> void:
	if m == null or m.has_meta("wo_mapped"):
		return
	m.set_meta("wo_mapped", true)
	for s: int in m.get_surface_count():
		var cur: Material = m.surface_get_material(s)
		if cur == null:
			continue
		var slot: String = cur.resource_name
		var mapped: Material = mat(slot)
		if mapped != null:
			m.surface_set_material(s, mapped)


## The game material for a GLB slot name (null = keep the GLB's own: runtime slots and unknown names).
static func mat(slot: String) -> Material:
	if _mats.has(slot):
		return _mats[slot]
	var m: Material = _build(slot)
	_mats[slot] = m
	return m


static func _build(slot: String) -> Material:
	var local: bool = slot.ends_with("@local")
	var base: String = slot.trim_suffix("@local")
	if RUNTIME_SLOTS.has(base):
		return null
	if base.begins_with("lib_"):
		var key: String = base.substr(4)
		var tint: String = ""
		if key.contains("__"):
			tint = key.get_slice("__", 1)
			key = key.get_slice("__", 0)
		var ov: Dictionary = {"triplanar": false}
		if tint != "":
			var lt: Array = MaterialLibrary.entry(key).get("tint", [1.0, 1.0, 1.0])
			var c: Color = Color("#" + tint)
			ov["tint"] = [float(lt[0]) * c.r * 1.6, float(lt[1]) * c.g * 1.6, float(lt[2]) * c.b * 1.6]
		var lm: Material = MaterialLibrary.build(key, ov) if MaterialLibrary.has_key(key) else null
		if lm != null:
			lm.resource_name = "wo_" + base
			return lm
		return Mats.get_mat(str(LIB_FALLBACK.get(key, "planks")) + ("@local" if local else ""))
	if base.begins_with("mats_"):
		return Mats.get_mat(base.substr(5) + ("@local" if local else ""))
	for prefix: String in ["enamel_", "glass_", "paint_", "neon_", "glow_soft_", "stripes_"]:
		if base.begins_with(prefix):
			return Mats.get_mat(prefix.trim_suffix("_") + ":#" + base.substr(prefix.length()))
	return null


static func _strip_collision(n: Node) -> void:
	for c: Node in n.get_children():
		if c is CollisionObject3D or c is CollisionShape3D:
			n.remove_child(c)
			c.free()
		else:
			_strip_collision(c)


## Drops the caches (tests).
static func reset() -> void:
	_scenes = {}
	_mats = {}
	_part_meshes = {}
