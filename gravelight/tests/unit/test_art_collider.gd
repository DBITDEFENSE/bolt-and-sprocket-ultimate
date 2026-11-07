extends GutTest
## T-188: perk machines and the Crucible collide with what you see (ArtCollider), and the NavBlock round them no longer
## blocks.


func _box_faces(c: Vector3, s: Vector3) -> PackedVector3Array:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = s
	var f: PackedVector3Array = bm.get_faces()
	for i: int in f.size():
		f[i] += c
	return f


func test_pieces_split_what_does_not_touch() -> void:
	var f: PackedVector3Array = _box_faces(Vector3.ZERO, Vector3.ONE)
	f.append_array(_box_faces(Vector3(3, 0, 0), Vector3(0.5, 0.5, 0.5)))
	assert_eq(ArtCollider.pieces(f).size(), 2, "two boxes apart: two hulls (no bridge of air between them)")
	assert_eq(ArtCollider.pieces(_box_faces(Vector3.ZERO, Vector3.ONE)).size(), 1, "one box: one hull")


func test_fit_follows_the_art() -> void:
	var owner: Node3D = autofree(Node3D.new())
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.6, 1.8, 0.5)
	mi.mesh = bm
	mi.position = Vector3(0, 0.9, 0)
	owner.add_child(mi)
	var tiny: MeshInstance3D = MeshInstance3D.new()
	var tb: BoxMesh = BoxMesh.new()
	tb.size = Vector3(0.02, 0.02, 0.02)
	tiny.mesh = tb
	owner.add_child(tiny)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.2, 2.4, 1.0)
	cs.shape = box
	body.add_child(cs)
	owner.add_child(body)
	assert_eq(ArtCollider.fit(owner, owner, body), 1, "one hull for the cabinet, none for a 2 cm screw")
	await wait_frames(1)
	var shapes: Array = body.get_children().filter(func(c: Node) -> bool: return c is CollisionShape3D and not c.is_queued_for_deletion())
	assert_eq(shapes.size(), 1)
	var top: float = -INF
	for p: Vector3 in ((shapes[0] as CollisionShape3D).shape as ConvexPolygonShape3D).points:
		top = maxf(top, ((shapes[0] as CollisionShape3D).transform * p).y)
	assert_almost_eq(top, 1.8, 0.02, "the hull's top is the art's top, not the 2.4 m box")


func test_fit_keeps_the_box_without_art() -> void:
	var owner: Node3D = autofree(Node3D.new())
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	body.add_child(cs)
	owner.add_child(body)
	assert_eq(ArtCollider.fit(owner, owner, body), 0, "no art: nothing changes")
	assert_true(cs.get_parent() == body, "the fallback box stays")
