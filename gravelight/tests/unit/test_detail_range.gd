extends GutTest
## T-223: the draw distance of the generators' small detail follows the Level of detail setting.


func test_factor_per_setting() -> void:
	assert_eq(DetailRange.factor("low"), 1.0, "Low keeps the authored distances")
	assert_gt(DetailRange.factor("ultra"), DetailRange.factor("high"))
	assert_gt(DetailRange.factor("high"), DetailRange.factor("medium"))
	assert_eq(DetailRange.factor("nonsense"), DetailRange.factor("high"))


func _map() -> Node3D:
	var root: Node3D = Node3D.new()
	var sb: Node3D = Node3D.new()
	sb.name = "StaticBatches"
	root.add_child(sb)
	var cut: MeshInstance3D = MeshInstance3D.new()
	cut.name = "Grating"
	cut.visibility_range_end = 80.0
	cut.visibility_range_end_margin = 6.0
	sb.add_child(cut)
	var lod: MeshInstance3D = MeshInstance3D.new()
	lod.name = "Impostor"
	lod.visibility_range_begin = 120.0
	lod.visibility_range_end = 400.0
	sb.add_child(lod)
	var free: MeshInstance3D = MeshInstance3D.new()
	free.name = "Unranged"
	sb.add_child(free)
	var outside: MeshInstance3D = MeshInstance3D.new()
	outside.name = "RuntimeThing"
	outside.visibility_range_end = 50.0
	root.add_child(outside)
	return root


func test_apply_scales_plain_cut_offs_only() -> void:
	var root: Node3D = _map()
	add_child_autofree(root)
	assert_eq(DetailRange.apply(root, 3.0), 1, "one plain cut-off under the generator's batches")
	var g: MeshInstance3D = root.get_node("StaticBatches/Grating")
	assert_almost_eq(g.visibility_range_end, 240.0, 0.01)
	assert_almost_eq(g.visibility_range_end_margin, 18.0, 0.01)
	var lod: MeshInstance3D = root.get_node("StaticBatches/Impostor")
	assert_eq(lod.visibility_range_end, 400.0, "an LOD chain keeps its pair")
	assert_eq(root.get_node("StaticBatches/Unranged").visibility_range_end, 0.0, "no range stays no range")
	assert_eq((root.get_node("RuntimeThing") as MeshInstance3D).visibility_range_end, 50.0, "outside the generator containers: untouched")


func test_reapply_works_from_the_authored_distance() -> void:
	var root: Node3D = _map()
	add_child_autofree(root)
	DetailRange.apply(root, 3.0)
	DetailRange.apply(root, 1.5)
	assert_almost_eq((root.get_node("StaticBatches/Grating") as MeshInstance3D).visibility_range_end, 120.0, 0.01, "not 80 x 3 x 1.5")
	DetailRange.apply(root, 1.0)
	assert_almost_eq((root.get_node("StaticBatches/Grating") as MeshInstance3D).visibility_range_end, 80.0, 0.01)


func test_the_shipped_maps_have_cut_offs_to_scale() -> void:
	for path: String in ["res://gravelight/maps/map04_fernflug/map04a.tscn", "res://gravelight/maps/map04_fernflug/map04b.tscn"]:
		var t: String = FileAccess.get_file_as_string(path)
		assert_true(t.contains("visibility_range_end = "), "%s still authors cut-offs (DetailRange scales them)" % path)
