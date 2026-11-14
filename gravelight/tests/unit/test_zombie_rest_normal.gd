extends GutTest
## T-242 b: the zombie kit's triplanar weights come from a rest-pose normal packed into CUSTOM1.w (octahedral, 12 bits
## a component, +1 so 0 means none): smooth across faces and fixed to the body under skinning. Before, they came
## from the rest position's per-triangle derivatives, which faceted on curved low-poly cloth.


func test_pack_round_trips_within_a_degree() -> void:
	var worst: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var dirs: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
		Vector3(1, 1, 1).normalized(), Vector3(-1, 0.2, -1).normalized(), Vector3(0.0001, 0.0, -1.0).normalized()]
	for i: int in 2000:
		dirs.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
	for n: Vector3 in dirs:
		var p: float = ZombieBody.pack_rest_normal(n)
		assert_gt(p, 0.5, "a packed normal is never the 'none' value")
		# exact in the float32 vertex attribute it is stored in
		var stored: PackedFloat32Array = PackedFloat32Array([p])
		assert_eq(stored[0], p)
		worst = maxf(worst, rad_to_deg(ZombieBody.unpack_rest_normal(stored[0]).angle_to(n)))
	assert_lt(worst, 1.0, "worst round-trip error %.3f deg" % worst)
	assert_eq(ZombieBody.pack_rest_normal(Vector3.ZERO), 0.0, "no normal packs to 0")
	assert_eq(ZombieBody.unpack_rest_normal(0.0), Vector3.ZERO)


func _check_kit_normals(mesh: ArrayMesh, tag: String) -> void:
	var si: int = -1
	for s: int in mesh.get_surface_count():
		if mesh.surface_get_name(s) == "kit":
			si = s
	assert_gt(si, -1, tag + ": has a kit surface")
	if si < 0:
		return
	var a: Array = mesh.surface_get_arrays(si)
	var c1: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM1]
	var norms: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var missing: int = 0
	var worst: float = 0.0
	for i: int in norms.size():
		var rn: Vector3 = ZombieBody.unpack_rest_normal(c1[i * 4 + 3])
		if rn == Vector3.ZERO:
			missing += 1
		elif norms[i].length_squared() > 0.5:
			worst = maxf(worst, rad_to_deg(rn.angle_to(norms[i].normalized())))
	assert_eq(missing, 0, tag + ": every kit vertex carries its rest normal")
	assert_lt(worst, 1.0, tag + ": the packed normal is the vertex's own rest normal (worst %.3f deg)" % worst)
	assert_same(mesh.surface_get_material(si), ZombieBody.kit_material(true), tag + ": the zombie kit material")


func test_glb_zombie_kits_carry_rest_normals() -> void:
	for kit: String in ["soldier", "sailor"]:
		_check_kit_normals(ZombieBody.build_skinned(kit, "medium", false), kit)


func test_procedural_fallback_kits_carry_rest_normals_and_the_zombie_material() -> void:
	var mesh: ArrayMesh = ZombieBody._skin_parts(ZombieBody.body_parts("soldier", "medium", false), "soldier")
	_check_kit_normals(mesh, "procedural soldier")


func test_kit_shader_reads_the_rest_normal() -> void:
	var code: String = ZombieBody.kit_shader().code
	assert_string_contains(code, "v_rest_nrm")
	assert_string_contains(code, "CUSTOM1.w")
