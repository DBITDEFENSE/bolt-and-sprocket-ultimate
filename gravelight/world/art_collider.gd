class_name ArtCollider
extends RefCounted
## T-188: a collider that matches the art. The perk machines and the Crucible stood in plain boxes (2.4 m tall over a
## rounded cabinet top, 2.0 x 2.4 x 1.6 m round the Crucible) that reached 20-30 cm past what you see: you bumped into
## air above and beside them (T-180's audit). fit() gives the body one convex hull per visible art mesh instead, in the
## owner's frame; a mesh smaller than MIN_M is left out (a screw, a label), and when no art is found the body keeps
## the box it was given (the fallback). Collision layers, the use box and the navmesh are untouched.

const MIN_M: float = 0.08


## Replaces `body`'s shapes with hulls of the meshes under `art_root` (`owner` gives the frame). Returns the hull count
## (0: nothing changed). `skip` nodes (and their children) are left out (a plaque, the body itself).
static func fit(owner: Node3D, art_root: Node, body: StaticBody3D, skip: Array = []) -> int:
	if owner == null or art_root == null or body == null:
		return 0
	var hulls: Array = []
	_collect(owner, art_root, body, skip, hulls)
	if hulls.is_empty():
		return 0
	for c: Node in body.get_children():
		if c is CollisionShape3D:
			body.remove_child(c)
			c.queue_free()
	for h: Array in hulls:
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = h[0]
		cs.transform = h[1]
		body.add_child(cs)
	body.set_meta("art_fit", hulls.size())
	return hulls.size()


static func _collect(owner: Node3D, n: Node, body: StaticBody3D, skip: Array, out: Array) -> void:
	if n == body or skip.has(n):
		return
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh != null:
			var ab: AABB = mi.mesh.get_aabb()
			var big: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
			if big >= MIN_M:
				var xf: Transform3D = owner.global_transform.affine_inverse() * mi.global_transform if owner.is_inside_tree() and mi.is_inside_tree() else _rel(owner, mi)
				# one hull per connected piece of the mesh (a merged body holds the cabinet, its sign arch, its feet: one
				# hull round all of them bridged the air between the wide sign and the narrower cabinet)
				for pts: PackedVector3Array in pieces(mi.mesh.get_faces()):
					var pab: AABB = AABB(pts[0], Vector3.ZERO)
					for q: Vector3 in pts:
						pab = pab.expand(q)
					if maxf(pab.size.x, maxf(pab.size.y, pab.size.z)) < MIN_M:
						continue
					var sh: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
					sh.points = pts
					out.append([sh, xf])
	for c: Node in n.get_children():
		_collect(owner, c, body, skip, out)


## The connected pieces of a triangle soup (Mesh.get_faces: 3 points a triangle), as point sets: triangles sharing a
## corner (to 1 mm) are one piece. Pure.
static func pieces(faces: PackedVector3Array) -> Array:
	var key_of: Dictionary = {}
	var parent: PackedInt32Array = PackedInt32Array()
	var pts: PackedVector3Array = PackedVector3Array()
	var ids: PackedInt32Array = PackedInt32Array()
	for v: Vector3 in faces:
		var k: Vector3i = Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
		var id: int = int(key_of.get(k, -1))
		if id < 0:
			id = pts.size()
			key_of[k] = id
			pts.append(v)
			parent.append(id)
		ids.append(id)
	for t: int in ids.size() / 3:
		var a: int = _find(parent, ids[t * 3])
		for j: int in [1, 2]:
			var b: int = _find(parent, ids[t * 3 + j])
			if a != b:
				parent[b] = a
	var groups: Dictionary = {}
	for i: int in pts.size():
		var r: int = _find(parent, i)
		if not groups.has(r):
			groups[r] = PackedVector3Array()
		var g: PackedVector3Array = groups[r]
		g.append(pts[i])
		groups[r] = g
	var out: Array = []
	for g2: Variant in groups.values():
		if (g2 as PackedVector3Array).size() >= 4:
			out.append(g2)
	return out


static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


## `mi`'s transform in `owner`'s frame without the tree (the parent chain's local transforms).
static func _rel(owner: Node3D, mi: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = mi
	while n != null and n != owner:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## T-188: a NavBlock box under a thing that carries its own collider (a perk machine, the Crucible, the Armorer's
## Bench, a crate spot, the bank's counter) stops blocking at runtime: it still shapes the baked navmesh (no zombie or
## bot path moves) but the half metre of box round the machine was an invisible wall (T-180 did this for Totenhafen by
## name; this does it on every map by place). Returns how many it switched off.
const OWN_COLLIDER_GROUPS: Array[StringName] = [&"perk_machines", &"crucible", &"armorers_bench", &"crate_spots", &"bank_branch"]

static func free_blocks_under(tree: SceneTree, root: Node) -> int:
	var spots: Array[Vector3] = []
	for g: StringName in OWN_COLLIDER_GROUPS:
		for n: Node in tree.get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).is_inside_tree():
				spots.append((n as Node3D).global_position)
	if spots.is_empty():
		return 0
	var off: int = 0
	for b: Node in root.find_children("NavBlock_*", "StaticBody3D", true, false):
		var body: StaticBody3D = b as StaticBody3D
		if body.collision_layer == 0:
			continue
		var bb: AABB = body_aabb(body)
		if bb.size == Vector3.ZERO:
			continue
		for p: Vector3 in spots:
			if p.x >= bb.position.x - 0.1 and p.x <= bb.end.x + 0.1 and p.z >= bb.position.z - 0.1 and p.z <= bb.end.z + 0.1 \
					and p.y >= bb.position.y - 0.6 and p.y <= bb.end.y + 0.1:
				body.collision_layer = 0
				body.add_to_group(&"bake_only", true)
				off += 1
				break
	return off


## A static body's world AABB from its box / convex shapes (empty when it has none).
static func body_aabb(body: StaticBody3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in body.get_children():
		var cs: CollisionShape3D = c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var local: AABB
		if cs.shape is BoxShape3D:
			var sz: Vector3 = (cs.shape as BoxShape3D).size
			local = AABB(-sz * 0.5, sz)
		elif cs.shape is ConvexPolygonShape3D and (cs.shape as ConvexPolygonShape3D).points.size() > 0:
			var pts: PackedVector3Array = (cs.shape as ConvexPolygonShape3D).points
			local = AABB(pts[0], Vector3.ZERO)
			for q: Vector3 in pts:
				local = local.expand(q)
		else:
			continue
		var w: AABB = cs.global_transform * local
		out = w if first else out.merge(w)
		first = false
	return out
