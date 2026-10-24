class_name DoorClearance
extends RefCounted
## Finds geometry that crosses a doorway (T-072): after the stable door's "pole" playtest note, every map's door
## openings must stay clear. An opening is a box in a door's own frame (local X across the doorway, Y up from the
## sill, Z through the wall); anything drawn or solid inside it, other than the door itself, is an intrusion.
## Drawn meshes are tested triangle by triangle (the generator merges dressing into big batches, so a batch's
## bounding box says nothing), collision shapes as their solid shapes.
## Used by the GUT test (test_map00_alive.gd) and smoke_map00_alive.

## Each opening is tested as two boxes: the doorway itself through the wall (margins left for the frame, the
## lintel and the sill: a threshold plank or a rug may sit under SILL), and the space a body passes through just
## either side of it, REACH deep, kept REACH_SIDE_MARGIN in from the jambs (a doorway beside a room's corner has the
## other wall's trim there). A mesh carrying the meta "clearance_ignore" (a light shaft, a snow fall sheet) is skipped.
const REACH: float = 0.45
const SIDE_MARGIN: float = 0.07
const REACH_SIDE_MARGIN: float = 0.2
const TOP_MARGIN: float = 0.07
const SILL: float = 0.12


## Every BuyDoor under `root` as an opening: {name, xf (global), size}. The door's own collider fills it, so its
## subtree is excluded from the check.
static func buy_door_openings(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n: Node in root.find_children("*", "Node3D", true, false):
		var d: BuyDoor = n as BuyDoor
		if d == null:
			continue
		out.append({"name": String(d.name), "xf": d.global_transform, "size": d.size, "skip": d})
	return out


## An extra opening (a doorway without a bought door): its sill centre, its yaw (local X across the doorway) and
## its width and height. `skip`: a node (or an Array of nodes) that belongs in the doorway (its door leaf, the
## invisible collider that keeps a drawn doorway shut).
static func opening(name_: String, sill_centre: Vector3, yaw_deg: float, width: float, height: float, skip: Variant = null) -> Dictionary:
	return {"name": name_, "xf": Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), sill_centre),
		"size": Vector3(width, height, 0.3), "skip": skip}


## The test volumes of an opening, in its own frame: [the doorway, the passage either side].
static func volumes(o: Dictionary) -> Array[AABB]:
	var s: Vector3 = o["size"]
	var h: float = s.y - TOP_MARGIN - SILL
	var wall: float = maxf(s.z, 0.3) * 0.5 - 0.01   # inside the wall: the trim of a wall meeting the jamb sits just outside
	var half_w: float = s.x * 0.5 - SIDE_MARGIN
	var half_r: float = s.x * 0.5 - REACH_SIDE_MARGIN
	var depth: float = wall + REACH
	return [AABB(Vector3(-half_w, SILL, -wall), Vector3(half_w * 2.0, h, wall * 2.0)),
		AABB(Vector3(-half_r, SILL, -depth), Vector3(half_r * 2.0, h, depth * 2.0))] as Array[AABB]


## Everything under `root` that crosses one of `openings`: ["<opening>: <node path> (<kind>)", ...]. Checks visible
## MeshInstance3Ds and MultiMesh instances and the solid CollisionShape3Ds of physics bodies (not areas).
static func intrusions(root: Node, openings: Array[Dictionary]) -> PackedStringArray:
	var out: PackedStringArray = []
	var vols: Array[AABB] = []
	var owner_of: Array[int] = []
	var invs: Array[Transform3D] = []
	var world_boxes: Array[AABB] = []
	for oi: int in openings.size():
		var xf: Transform3D = openings[oi]["xf"]
		for v: AABB in volumes(openings[oi]):
			vols.append(v)
			owner_of.append(oi)
			invs.append(xf.affine_inverse())
			world_boxes.append(xf * v)
	var movers: Array[Node] = root.find_children("*", "CharacterBody3D", true, false)
	movers.append_array(root.find_children("*", "RigidBody3D", true, false))
	for n: Node in root.find_children("*", "", true, false):
		if _under_any(n, movers):
			continue
		var faces: PackedVector3Array = PackedVector3Array()
		var xf_n: Transform3D
		var kind: String = ""
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree() or mi.has_meta(&"clearance_ignore"):
				continue
			faces = mi.mesh.get_faces()
			xf_n = mi.global_transform
			kind = "mesh"
		elif n is MultiMeshInstance3D:
			var mm: MultiMeshInstance3D = n as MultiMeshInstance3D
			if mm.multimesh == null or mm.multimesh.mesh == null or not mm.is_visible_in_tree():
				continue
			var base: PackedVector3Array = mm.multimesh.mesh.get_faces()
			var count: int = mm.multimesh.visible_instance_count
			if count < 0:
				count = mm.multimesh.instance_count
			for i: int in count:
				var ixf: Transform3D = mm.multimesh.get_instance_transform(i)
				for p: Vector3 in base:
					faces.append(ixf * p)
			xf_n = mm.global_transform
			kind = "multimesh"
		elif n is CollisionShape3D:
			var cs: CollisionShape3D = n as CollisionShape3D
			if cs.disabled or cs.shape == null or not (cs.get_parent() is PhysicsBody3D):
				continue
			if (cs.get_parent() as CollisionObject3D).collision_layer == 0:
				continue
			faces = shape_faces(cs.shape)
			xf_n = cs.global_transform
			kind = "collider"
		else:
			continue
		if faces.is_empty():
			continue
		var bb: AABB = xf_n * _faces_aabb(faces)
		var hit_by: Dictionary = {}
		for i: int in vols.size():
			var oi: int = owner_of[i]
			if hit_by.has(oi):
				continue
			if _skipped(n, openings[oi].get("skip")):
				continue
			if not bb.intersects(world_boxes[i]):
				continue
			var to_local: Transform3D = invs[i] * xf_n
			if _faces_hit(faces, to_local, vols[i]):
				hit_by[oi] = true
				out.append("%s: %s (%s)" % [openings[oi]["name"], str(root.get_path_to(n)), kind])
	return out


static func _skipped(n: Node, skip: Variant) -> bool:
	if skip is Node:
		return n == skip or (skip as Node).is_ancestor_of(n)
	if skip is Array:
		for k: Variant in skip:
			if k is Node and (n == k or (k as Node).is_ancestor_of(n)):
				return true
	return false


## Players, zombies and loose physics props move: they are not part of the doorway's dressing.
static func _under_any(n: Node, roots: Array[Node]) -> bool:
	for r: Node in roots:
		if n == r or r.is_ancestor_of(n):
			return true
	return false


## Triangles for a collision shape (boxes, cylinders, capsules and spheres as their primitive meshes).
static func shape_faces(s: Shape3D) -> PackedVector3Array:
	if s is BoxShape3D:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = (s as BoxShape3D).size
		return bm.get_faces()
	if s is CylinderShape3D:
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = (s as CylinderShape3D).radius
		cm.bottom_radius = cm.top_radius
		cm.height = (s as CylinderShape3D).height
		cm.radial_segments = 12
		return cm.get_faces()
	if s is CapsuleShape3D:
		var pm: CapsuleMesh = CapsuleMesh.new()
		pm.radius = (s as CapsuleShape3D).radius
		pm.height = (s as CapsuleShape3D).height
		return pm.get_faces()
	if s is SphereShape3D:
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = (s as SphereShape3D).radius
		sm.height = sm.radius * 2.0
		return sm.get_faces()
	if s is ConcavePolygonShape3D:
		return (s as ConcavePolygonShape3D).get_faces()
	if s is ConvexPolygonShape3D:
		var pts: PackedVector3Array = (s as ConvexPolygonShape3D).points
		if pts.is_empty():
			return PackedVector3Array()
		var bb: AABB = AABB(pts[0], Vector3.ZERO)
		for p: Vector3 in pts:
			bb = bb.expand(p)
		var bm2: BoxMesh = BoxMesh.new()
		bm2.size = bb.size
		var f: PackedVector3Array = bm2.get_faces()
		for i: int in f.size():
			f[i] += bb.get_center()
		return f
	return s.get_debug_mesh().get_faces()


static func _faces_aabb(faces: PackedVector3Array) -> AABB:
	var bb: AABB = AABB(faces[0], Vector3.ZERO)
	for p: Vector3 in faces:
		bb = bb.expand(p)
	return bb


static func _faces_hit(faces: PackedVector3Array, xf: Transform3D, box: AABB) -> bool:
	var c: Vector3 = box.get_center()
	var h: Vector3 = box.size * 0.5
	for i: int in range(0, faces.size() - 2, 3):
		if tri_box(xf * faces[i] - c, xf * faces[i + 1] - c, xf * faces[i + 2] - c, h):
			return true
	return false


## Triangle (relative to a box's centre) against a box of half extents h: the separating axis test.
static func tri_box(v0: Vector3, v1: Vector3, v2: Vector3, h: Vector3) -> bool:
	# the box's own axes
	for a: int in 3:
		var mn: float = minf(v0[a], minf(v1[a], v2[a]))
		var mx: float = maxf(v0[a], maxf(v1[a], v2[a]))
		if mn > h[a] or mx < -h[a]:
			return false
	var e0: Vector3 = v1 - v0
	var e1: Vector3 = v2 - v1
	var e2: Vector3 = v0 - v2
	# the triangle's plane
	var nrm: Vector3 = e0.cross(e1)
	var r: float = h.x * absf(nrm.x) + h.y * absf(nrm.y) + h.z * absf(nrm.z)
	if absf(nrm.dot(v0)) > r:
		return false
	# the nine edge cross axes
	for e: Vector3 in [e0, e1, e2]:
		for b: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			var ax: Vector3 = b.cross(e)
			if ax.length_squared() < 1e-12:
				continue
			var p0: float = ax.dot(v0)
			var p1: float = ax.dot(v1)
			var p2: float = ax.dot(v2)
			var rr: float = h.x * absf(ax.x) + h.y * absf(ax.y) + h.z * absf(ax.z)
			if minf(p0, minf(p1, p2)) > rr or maxf(p0, maxf(p1, p2)) < -rr:
				return false
	return true
