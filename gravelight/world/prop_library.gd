class_name PropLibrary
extends RefCounted
## The CC0 prop library (UPDATE_05 / 05A section 1.3, T-088). `PropLibrary.instance("barrel_wine")` loads the GLB
## data/gravelight/props_library.json names for the key, instances it, applies the entry's scale (metres) and
## pivot shift, strips any collision the file carried (collision stays the generator's job, UPDATE_05 section 0.4)
## and returns a Node3D whose origin is the prop's footprint centre at floor level. Visual only: callers put it
## under a map's Dressing and add their own colliders where gameplay needs them.
##
## Entry fields (props_library.json "props"): path (res://), scale (1.0 = the file is already metres), pivot
## ("base" = the AABB's bottom centre at the origin, "top" = its top centre (hanging lamps), "file" = the file's
## own origin), rot_deg (a fixed yaw/pitch/roll correction), size_m (the expected AABB in metres after scale, what
## the tests check), tris, note.

const DATA: String = "res://data/gravelight/props_library.json"

static var _data: Dictionary = {}
static var _scenes: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f: FileAccess = FileAccess.open(DATA, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_data = d
	return _data


static func keys() -> Array:
	return (data().get("props", {}) as Dictionary).keys()


static func has_key(key: String) -> bool:
	return (data().get("props", {}) as Dictionary).has(key)


static func entry(key: String) -> Dictionary:
	return (data().get("props", {}) as Dictionary).get(key, {})


static func scene(key: String) -> PackedScene:
	if _scenes.has(key):
		return _scenes[key]
	var e: Dictionary = entry(key)
	if e.is_empty():
		return null
	var path: String = str(e.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		push_warning("PropLibrary: '%s' has no imported scene at %s" % [key, path])
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps != null:
		_scenes[key] = ps
	return ps


## A ready-to-place visual: Node3D "Prop_<key>" holding the GLB's content, scaled to metres, pivot at the footprint
## centre on the floor (pivot "base"), collision-free. Null when the key or its file is missing.
static func instance(key: String) -> Node3D:
	var ps: PackedScene = scene(key)
	if ps == null:
		return null
	var e: Dictionary = entry(key)
	var root: Node3D = Node3D.new()
	root.name = "Prop_" + key
	var inner: Node = ps.instantiate()
	var model: Node3D = inner if inner is Node3D else Node3D.new()
	if model != inner:
		model.add_child(inner)
	model.name = "Model"
	var s: float = float(e.get("scale", 1.0))
	model.scale = Vector3(s, s, s)
	if e.has("rot_deg"):
		var r: Array = e["rot_deg"]
		model.rotation_degrees = Vector3(float(r[0]), float(r[1]), float(r[2]))
	root.add_child(model)
	_strip_collision(model)
	for mi: MeshInstance3D in meshes(model):
		mi.set_meta("prop_key", key)
	var pivot: String = str(e.get("pivot", "base"))
	if pivot == "base" or pivot == "top":
		var box: AABB = local_aabb(model)
		if box.size != Vector3.ZERO:
			var c: Vector3 = box.get_center()
			var y: float = box.position.y if pivot == "base" else box.end.y   # "top": hangs from its origin
			model.position -= Vector3(c.x, y, c.z)
	root.set_meta("prop_key", key)
	return root


## The AABB of every mesh under `n`, in `n`'s parent's space (so a model's transform counts).
static func local_aabb(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in meshes(n):
		if mi.mesh == null:
			continue
		var t: Transform3D = _xform(mi, n.get_parent())
		var b: AABB = t * mi.mesh.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


static func meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c: Node in n.get_children():
		out.append_array(meshes(c))
	return out


static func _xform(n: Node3D, stop: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != stop:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Drops StaticBody3D / CollisionShape3D / Area3D nodes a GLB carried (the "-col" suffixes), keeping their meshes.
static func _strip_collision(n: Node) -> void:
	for c: Node in n.get_children():
		_strip_collision(c)
	if n is CollisionShape3D or n is CollisionPolygon3D:
		n.get_parent().remove_child(n)
		n.free()
	elif n is PhysicsBody3D or n is Area3D:
		var parent: Node = n.get_parent()
		for c: Node in n.get_children():
			n.remove_child(c)
			parent.add_child(c)
			if c is Node3D:
				(c as Node3D).transform = (n as Node3D).transform * (c as Node3D).transform
		parent.remove_child(n)
		n.free()


## Tris of the prop's LOD0 (all surfaces), for reports and tests.
static func triangles(n: Node) -> int:
	var total: int = 0
	for mi: MeshInstance3D in meshes(n):
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			if arrays.is_empty():
				continue
			var idx: Variant = arrays[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				total += (idx as PackedInt32Array).size() / 3
			elif arrays[Mesh.ARRAY_VERTEX] != null:
				total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


static func reset() -> void:
	_data = {}
	_scenes = {}
