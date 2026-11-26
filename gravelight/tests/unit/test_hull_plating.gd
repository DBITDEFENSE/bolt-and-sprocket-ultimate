extends GutTest
## T-287: the U-boats' plating read as strong vertical stripes (rusty_painted_metal is a corrugated container wall,
## world-triplanar on the hull). The lofted sides and bottom now carry UVs (u along the hull, v down the girth) and
## wear our own UV-mapped plating (data/gravelight/materials.json m2_hull_plate / m2_hull_wreck_plate /
## m2_hull_red_plate); the boxes, caps and casing keep the triplanar keys, now steel_plating / red_lead_plating.
## Headless: builds the hulls in a bare Node3D and reads their meshes and materials.

const PLATE_KEYS: Array = ["m2_hull_plate", "m2_hull_wreck_plate", "m2_hull_red_plate"]


func before_all() -> void:
	MaterialLibrary.reset()


func after_all() -> void:
	MaterialLibrary.reset()


func _vii(k_hull: String) -> Node3D:
	var g: Node3D = Node3D.new()
	DetailMap02.type_vii(g, 58.6, -2.6, k_hull, "m2_hull_red", "iron", 48.2 if k_hull == "m2_hull" else -1.0)
	return g


func _uvs(mi: MeshInstance3D) -> PackedVector2Array:
	var a: Array = mi.mesh.surface_get_arrays(0)
	return a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()


func test_plating_keys_are_uv_mapped_library_materials() -> void:
	for k: String in PLATE_KEYS:
		var e: Dictionary = MaterialLibrary.entry(k)
		assert_false(e.is_empty(), "%s is in the library" % k)
		assert_false(bool(e.get("triplanar", true)), "%s uses the mesh's UVs" % k)
		var m: ShaderMaterial = Mats.get_mat(k) as ShaderMaterial
		assert_not_null(m, "%s reaches the generator through Mats" % k)
		if m != null:
			assert_eq(m.shader, MaterialLibrary.shader(), "%s is surface_pbr (T-266 batching / proxies)" % k)
			assert_ne(ShadowProxies.shader_cull(m.shader), -1, "%s: the shader's depth pass stays plain" % k)
	for k2: String in ["m2_hull", "m2_hull_red"]:
		assert_true(bool(MaterialLibrary.entry(k2).get("triplanar", true)), "%s stays triplanar (boxes, caps, the patrol boat)" % k2)
		assert_false(MaterialLibrary.texture_path(k2, "albedo").contains("rusty_painted_metal"), "%s is off the corrugated texture" % k2)


func test_u1047_sides_and_bottom_carry_girth_uvs_and_tangents() -> void:
	var g: Node3D = _vii("m2_hull")
	var want: Dictionary = {"HullTop_R": "m2_hull_plate", "HullTop_L": "m2_hull_plate", "HullBottom": "m2_hull_red_plate"}
	for n: String in want:
		var mi: MeshInstance3D = g.get_node_or_null(n) as MeshInstance3D
		assert_not_null(mi, "%s built" % n)
		if mi == null:
			continue
		var fmt: int = mi.mesh.surface_get_format(0)
		assert_true(fmt & Mesh.ARRAY_FORMAT_TEX_UV != 0, "%s has UVs" % n)
		assert_true(fmt & Mesh.ARRAY_FORMAT_TANGENT != 0, "%s has tangents (the normal map)" % n)
		assert_eq(String(mi.material_override.resource_name), "lib_" + str(want[n]), "%s wears %s" % [n, want[n]])
		var uv: PackedVector2Array = _uvs(mi)
		var umin: float = 1e9
		var umax: float = -1e9
		var vmin: float = 1e9
		var vmax: float = -1e9
		for p: Vector2 in uv:
			umin = minf(umin, p.x)
			umax = maxf(umax, p.x)
			vmin = minf(vmin, p.y)
			vmax = maxf(vmax, p.y)
		# u runs along the hull in metres (the stripes came from a texture tiled the other way)
		assert_almost_eq(umin, 0.0, 0.01, "%s: u starts at the bow" % n)
		assert_almost_eq(umax, 58.6, 0.01, "%s: u ends at the stern (metres along the hull)" % n)
		assert_almost_eq(vmin, 0.0, 0.01, "%s: v starts at the deck edge / the boot-top" % n)
		if n.begins_with("HullTop"):
			assert_almost_eq(vmax, DetailMap02.PLATE_BOOT_V, 0.01, "%s: the boot-top sits at the tile's foot in every section" % n)
		else:
			assert_between(vmax, 2.0, 5.0, "%s: v is metres of girth below the boot-top" % n)
	# the casing and the end caps keep their triplanar key (no UVs needed)
	var casing: MeshInstance3D = g.get_node("DeckCasing") as MeshInstance3D
	assert_eq(String(casing.material_override.resource_name), "lib_m2_hull", "the casing keeps the triplanar plates")
	g.free()


func test_the_dead_uboat_wears_the_wreck_plating() -> void:
	var g: Node3D = _vii("rust")
	var top: MeshInstance3D = g.get_node("HullTop_R") as MeshInstance3D
	assert_eq(String(top.material_override.resource_name), "lib_m2_hull_wreck_plate", "the wreck's topsides")
	assert_true(top.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV != 0, "with UVs")
	g.free()


func test_strip_without_uvs_is_unchanged() -> void:
	var lines: Array = []
	for s: int in 3:
		lines.append(PackedVector3Array([Vector3(1, 0, s), Vector3(1, -1, s), Vector3(0.5, -2, s)]))
	var m: ArrayMesh = DetailMap02.strip(lines, func(p: Vector3) -> Vector3: return Vector3(0, -1, p.z))
	assert_eq(m.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV, 0, "no UVs unless asked for (the triplanar hulls)")
	var uvs: Array = []
	for s2: int in 3:
		uvs.append(PackedVector2Array([Vector2(s2, 0), Vector2(s2, 1), Vector2(s2, 2)]))
	var m2: ArrayMesh = DetailMap02.strip(lines, func(p: Vector3) -> Vector3: return Vector3(0, -1, p.z), false, uvs)
	var a: Array = m.surface_get_arrays(0)
	var a2: Array = m2.surface_get_arrays(0)
	assert_eq((a2[Mesh.ARRAY_VERTEX] as PackedVector3Array), (a[Mesh.ARRAY_VERTEX] as PackedVector3Array), "the same triangles with or without UVs")
	# each vertex's UV is the one given for its point
	var v2: PackedVector3Array = a2[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = a2[Mesh.ARRAY_TEX_UV]
	for i: int in v2.size():
		var p: Vector3 = v2[i]
		var row: int = int(round(p.z))
		var col: int = 0 if p.y > -0.5 else (1 if p.y > -1.5 else 2)
		assert_eq(uv2[i], Vector2(row, col), "vertex %d's UV" % i)
