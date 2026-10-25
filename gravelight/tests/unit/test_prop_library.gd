extends GutTest
## UPDATE_05 / 05A section 1.3 (T-088): the CC0 prop library. Every prop in data/gravelight/props_library.json has its
## file and paperwork, loads through PropLibrary.instance(), sits on its footprint (pivot "base") or hangs from
## its origin (pivot "top"), measures within 12% of its declared size_m, and carries no collision.

const TOL: float = 0.12


func after_all() -> void:
	PropLibrary.reset()


func test_data_file_and_paperwork() -> void:
	var props: Dictionary = PropLibrary.data().get("props", {})
	assert_gte(props.size(), 15, "at least the ~15 props the order asked for")
	for key: String in props:
		var e: Dictionary = props[key]
		var path: String = str(e.get("path", ""))
		assert_true(path.begins_with("res://assets/third_party/"), "%s lives under assets/third_party" % key)
		assert_true(FileAccess.file_exists(path), "%s file exists: %s" % [key, path])
		var dir: String = path.get_base_dir()
		assert_true(FileAccess.file_exists(dir.path_join("LICENSE.txt")), "%s has LICENSE.txt" % key)
		assert_true(FileAccess.file_exists(dir.path_join("SOURCE.txt")), "%s has SOURCE.txt" % key)
		assert_eq((e.get("size_m", []) as Array).size(), 3, "%s declares size_m" % key)
		assert_eq(key, key.to_lower(), "%s is lower case" % key)


func test_every_prop_loads_sits_on_its_pivot_and_fits_its_size() -> void:
	var holder: Node3D = Node3D.new()
	add_child_autofree(holder)
	for key: String in PropLibrary.keys():
		var e: Dictionary = PropLibrary.entry(key)
		if not ResourceLoader.exists(str(e["path"])):
			fail_test("%s is not imported (run tools/apply_import_presets.sh)" % key)
			continue
		var n: Node3D = PropLibrary.instance(key)
		assert_not_null(n, "%s instances" % key)
		if n == null:
			continue
		holder.add_child(n)
		assert_eq(n.name, "Prop_" + key)
		assert_gt(PropLibrary.triangles(n), 0, "%s has geometry" % key)
		var box: AABB = PropLibrary.local_aabb(n.get_node("Model"))
		var want: Array = e["size_m"]
		for i: int in 3:
			var w: float = float(want[i])
			assert_almost_eq(box.size[i], w, maxf(0.02, w * TOL), "%s size axis %d: %.3f vs declared %.3f" % [key, i, box.size[i], w])
		var pivot: String = str(e.get("pivot", "base"))
		if pivot == "base":
			assert_almost_eq(box.position.y, 0.0, 0.01, "%s stands on y 0" % key)
			assert_almost_eq(box.get_center().x, 0.0, 0.01, "%s centred in x" % key)
			assert_almost_eq(box.get_center().z, 0.0, 0.01, "%s centred in z" % key)
		elif pivot == "top":
			assert_almost_eq(box.end.y, 0.0, 0.01, "%s hangs from y 0" % key)
		assert_eq(_physics_nodes(n), 0, "%s carries no collision (the generator's job)" % key)
		n.queue_free()


func test_unknown_key_is_null() -> void:
	assert_null(PropLibrary.instance("no_such_prop"))
	assert_false(PropLibrary.has_key("no_such_prop"))


func _physics_nodes(n: Node) -> int:
	var c: int = 1 if (n is CollisionObject3D or n is CollisionShape3D or n is CollisionPolygon3D) else 0
	for ch: Node in n.get_children():
		c += _physics_nodes(ch)
	return c
