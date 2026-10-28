extends SceneTree
## Lists colliders on a map that have little visible geometry around them (invisible walls).
## Usage: godot --headless --path . --script res://gravelight/tools_src/probe_invisible_walls.gd -- [--map=res://...tscn] [--min-cover=0.5]
## Walks each collider's length in 0.5 m steps: flags spots with no drawing over them, or a drawing lower than the
## collider's top by over 0.2 m (an invisible band above a drawn fence). Mesh AABBs only: a rough first pass.
## The scene is instantiated but not added to the tree (no _ready), so only the generated geometry is checked.

var _meshes: Array = []    # [AABB world, path]
var _shapes: Array = []    # [AABB world, layer, path]


func _initialize() -> void:
	var map: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
	var min_cover: float = 0.9
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map = a.substr(6)
		elif a.begins_with("--min-cover="):
			min_cover = float(a.substr(12))
	var root: Node = (load(map) as PackedScene).instantiate()
	_walk(root, Transform3D.IDENTITY, true, 0)
	print("meshes %d, shapes %d" % [_meshes.size(), _shapes.size()])
	for s: Array in _shapes:
		var box: AABB = s[0]
		# along the collider's long axis, in 0.5 m steps: the top of the drawing over that spot (-1 none)
		var long_x: bool = box.size.x >= box.size.z
		var steps: int = maxi(1, int((box.size.x if long_x else box.size.z) / 0.5))
		var worst_gap: float = 0.0
		var bare: int = 0
		for i: int in steps:
			var f: float = (i + 0.5) / float(steps)
			var c: Vector3 = box.get_center()
			var p: Vector3 = Vector3(box.position.x + box.size.x * f, 0, c.z) if long_x else Vector3(c.x, 0, box.position.z + box.size.z * f)
			var top: float = -INF
			for m: Array in _meshes:
				var ab: AABB = (m[0] as AABB).grow(0.3)
				if p.x >= ab.position.x and p.x <= ab.end.x and p.z >= ab.position.z and p.z <= ab.end.z and ab.position.y < box.end.y and ab.end.y > box.position.y:
					top = maxf(top, ab.end.y - 0.3)
			if top == -INF:
				bare += 1
			else:
				worst_gap = maxf(worst_gap, box.end.y - top)
		var cover: float = 1.0 - float(bare) / float(steps)
		if cover < min_cover or worst_gap > 0.2:
			print("UNCOVERED %.2f gap %.2f layer %d pos %s size %s %s" % [cover, worst_gap, s[1], str(box.get_center().snapped(Vector3.ONE * 0.01)),
				str(box.size.snapped(Vector3.ONE * 0.01)), s[2]])
	root.free()
	quit()


func _walk(n: Node, xf: Transform3D, vis: bool, layer: int) -> void:
	var t: Transform3D = xf
	var v: bool = vis
	var l: int = layer
	if n is Node3D:
		t = xf * (n as Node3D).transform
		v = vis and (n as Node3D).visible
	if n is CollisionObject3D:
		l = (n as CollisionObject3D).collision_layer
	if n is MeshInstance3D and v and (n as MeshInstance3D).mesh != null:
		_meshes.append([t * (n as MeshInstance3D).get_aabb(), _path(n)])
	if n is MultiMeshInstance3D and v and (n as MultiMeshInstance3D).multimesh != null:
		var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
		if mm.mesh != null:
			# a headless run keeps no MultiMesh buffer: only a BakedMultiMesh's own transforms are readable
			var xfs: Variant = n.get("transforms")
			if xfs is Array:
				for x: Variant in xfs:
					_meshes.append([t * (x as Transform3D) * mm.mesh.get_aabb(), _path(n)])
	if n is CSGShape3D and v:
		_meshes.append([t * (n as VisualInstance3D).get_aabb(), _path(n)])
	if n is CollisionShape3D and not (n as CollisionShape3D).disabled and (n as CollisionShape3D).shape != null:
		var sh: Shape3D = (n as CollisionShape3D).shape
		var local: AABB
		if sh is BoxShape3D:
			local = AABB(-(sh as BoxShape3D).size * 0.5, (sh as BoxShape3D).size)
		elif sh is ConvexPolygonShape3D:
			var pts: PackedVector3Array = (sh as ConvexPolygonShape3D).points
			local = AABB(pts[0], Vector3.ZERO)
			for p: Vector3 in pts:
				local = local.expand(p)
		elif sh is CylinderShape3D:
			var c: CylinderShape3D = sh
			local = AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2, c.height, c.radius * 2))
		else:
			local = AABB()
		if local.size != Vector3.ZERO:
			_shapes.append([t * local, l, _path(n)])
	for c: Node in n.get_children():
		_walk(c, t, v, l)


func _path(n: Node) -> String:
	var parts: PackedStringArray = []
	var c: Node = n
	while c != null:
		parts.insert(0, String(c.name))
		c = c.get_parent()
	return "/".join(parts)
