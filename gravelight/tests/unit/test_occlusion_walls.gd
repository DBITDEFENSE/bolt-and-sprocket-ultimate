extends GutTest
## T-266: OcclusionWalls (the batches' big faces as occluders, on the Low and Medium Level of detail settings).

var _off: PackedStringArray = []


func before_each() -> void:
	_off = RenderTune.off.duplicate()
	RenderTune.off = PackedStringArray()


func after_each() -> void:
	RenderTune.off = _off


func test_big_triangles_only() -> void:
	var faces: PackedVector3Array = PackedVector3Array([
		Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 3, 0),          # 6 m2: a wall
		Vector3(0, 0, 0), Vector3(0.5, 0, 0), Vector3(0, 0.5, 0),      # 0.125 m2: a bottle crate's side
		Vector3(0, 0, 5), Vector3(2, 0, 5), Vector3(0, 1, 5),          # 1 m2: just in
	])
	var out: PackedVector3Array = OcclusionWalls.big_triangles(faces, 1.0)
	assert_eq(out.size(), 6)
	assert_eq(out[1], Vector3(4, 0, 0))
	assert_eq(out[3], Vector3(0, 0, 5))


func test_occlusion_is_for_low_and_medium() -> void:
	assert_true(OcclusionWalls.wanted("low"))
	assert_true(OcclusionWalls.wanted("medium"))
	assert_false(OcclusionWalls.wanted("high"), "High draws the map exactly as before")
	assert_false(OcclusionWalls.wanted("ultra"))
	RenderTune.off = PackedStringArray(["occlusion"])
	assert_false(OcclusionWalls.wanted("low"))


func test_occluders_hang_on_the_shadow_proxies_and_see_through_labels_are_exempt() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var holder: Node3D = Node3D.new()
	holder.name = "StaticBatches"
	root.add_child(holder)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(6, 3, 0.3)
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays())
	wall.mesh = am
	wall.material_override = StandardMaterial3D.new()
	holder.add_child(wall)
	var ranged: MeshInstance3D = MeshInstance3D.new()
	ranged.mesh = am
	ranged.material_override = StandardMaterial3D.new()
	ranged.position = Vector3(40, 0, 0)
	ranged.visibility_range_end = 80.0
	holder.add_child(ranged)
	var tag: Label3D = Label3D.new()
	tag.no_depth_test = true
	root.add_child(tag)
	var sign_: Label3D = Label3D.new()
	root.add_child(sign_)
	ShadowProxies.build_all(root)
	var ow: OcclusionWalls = OcclusionWalls.new()
	ow.name = OcclusionWalls.NAME
	ow.map_root = root
	root.add_child(ow)
	ow.set_level("low")
	assert_true(ow.want)
	assert_eq(int(ow.stats["occluders"]), 1, "the wall's proxy; the batch with a draw distance is no occluder")
	assert_eq(int(ow.stats["triangles"]), 4, "the wall's two big faces (9 m2 triangles); its 0.9 m2 and 0.45 m2 edges are left out")
	var found: int = 0
	for p: Node in holder.get_children():
		if str(p.name).begins_with("ShadowProxy_") and p.get_node_or_null("WallOccluder") is OccluderInstance3D:
			found += 1
	assert_eq(found, 1)
	assert_true(tag.ignore_occlusion_culling, "a label drawn through walls is never culled by them")
	assert_false(sign_.ignore_occlusion_culling)
	ow.set_level("high")
	assert_false(ow.want)
	assert_false(get_viewport().use_occlusion_culling, "High: off")
