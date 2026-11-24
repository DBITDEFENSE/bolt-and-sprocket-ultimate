extends GutTest
## T-266: PropShadows (one shadow draw per static prop mesh) and RenderTune's switches.

var _off: PackedStringArray = []


func before_each() -> void:
	_off = RenderTune.off.duplicate()
	RenderTune.off = PackedStringArray()
	PropShadows._cache.clear()


func after_each() -> void:
	RenderTune.off = _off


func _mesh(mats: Array) -> ArrayMesh:
	var am: ArrayMesh = ArrayMesh.new()
	for i: int in mats.size():
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1, 1, 1)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays())
		am.surface_set_material(i, mats[i])
	return am


func _prop(parent: Node, mats: Array) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _mesh(mats)
	parent.add_child(mi)
	return mi


func _alpha() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _scissor() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return m


func test_surface_cull() -> void:
	assert_eq(PropShadows.surface_cull(StandardMaterial3D.new()), BaseMaterial3D.CULL_BACK)
	var two: StandardMaterial3D = StandardMaterial3D.new()
	two.cull_mode = BaseMaterial3D.CULL_DISABLED
	assert_eq(PropShadows.surface_cull(two), BaseMaterial3D.CULL_DISABLED)
	assert_eq(PropShadows.surface_cull(_alpha()), -2, "alpha-blended glass never casts: left out of the proxy")
	assert_eq(PropShadows.surface_cull(_scissor()), -1, "a cut-out casts its own shape: the mesh keeps its shadows")
	assert_eq(PropShadows.surface_cull(null), -1)
	var sh: Shader = Shader.new()
	sh.code = "shader_type spatial;\nvoid vertex() { VERTEX.y += sin(TIME); }"
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = sh
	assert_eq(PropShadows.surface_cull(sm), -1, "a shader that moves vertices")


func test_a_multi_surface_prop_gets_one_shadow_child() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var a: MeshInstance3D = _prop(root, [StandardMaterial3D.new(), StandardMaterial3D.new(), StandardMaterial3D.new(), _alpha()])
	a.visibility_range_end = 40.0
	a.visibility_range_end_margin = 3.0
	var r: Dictionary = PropShadows.build(root)
	assert_eq(int(r["meshes"]), 1)
	assert_eq(int(r["surfaces"]), 4)
	assert_eq(a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the prop no longer draws its 4 surfaces into shadow maps")
	var p: MeshInstance3D = a.get_node("ShadowProp") as MeshInstance3D
	assert_not_null(p)
	assert_eq(p.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert_eq(p.mesh.get_surface_count(), 1, "one surface: one draw")
	assert_eq(p.mesh.get_faces().size() / 3, 36, "the three opaque boxes' triangles, not the glass")
	assert_almost_eq(p.visibility_range_end, 40.0, 0.001, "it goes when its mesh goes")
	assert_almost_eq(p.visibility_range_end_margin, 3.0, 0.001)
	assert_eq(int(PropShadows.build(root)["meshes"]), 0, "built once")
	PropShadows.undo(root)
	assert_eq(a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_null(a.get_node_or_null("ShadowProp"))


func test_cull_modes_stay_apart() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var two: StandardMaterial3D = StandardMaterial3D.new()
	two.cull_mode = BaseMaterial3D.CULL_DISABLED
	var a: MeshInstance3D = _prop(root, [StandardMaterial3D.new(), StandardMaterial3D.new(), two])
	PropShadows.build(root)
	var p: MeshInstance3D = a.get_node("ShadowProp") as MeshInstance3D
	assert_eq(p.mesh.get_surface_count(), 2, "back-culled and two-sided surfaces draw as they did")


func test_what_is_left_alone() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var plain: Array = [StandardMaterial3D.new(), StandardMaterial3D.new()]
	var single: MeshInstance3D = _prop(root, [StandardMaterial3D.new()])
	var cutout: MeshInstance3D = _prop(root, [StandardMaterial3D.new(), StandardMaterial3D.new(), _scissor()])
	var no_shadow: MeshInstance3D = _prop(root, plain)
	no_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var faded: MeshInstance3D = _prop(root, plain)
	faded.transparency = 0.5
	var body: CharacterBody3D = CharacterBody3D.new()
	root.add_child(body)
	var carried: MeshInstance3D = _prop(body, plain)
	var rigid: RigidBody3D = RigidBody3D.new()
	root.add_child(rigid)
	var thrown: MeshInstance3D = _prop(rigid, plain)
	var skel: Skeleton3D = Skeleton3D.new()
	root.add_child(skel)
	var skinned: MeshInstance3D = _prop(skel, plain)
	var one_caster: MeshInstance3D = _prop(root, [StandardMaterial3D.new(), _alpha()])
	assert_eq(int(PropShadows.build(root)["meshes"]), 0)
	for mi: MeshInstance3D in [single, cutout, faded, carried, thrown, skinned, one_caster]:
		assert_eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, str(mi.get_path()))
		assert_null(mi.get_node_or_null("ShadowProp"))
	assert_eq(no_shadow.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_switched_off_nothing_is_built() -> void:
	RenderTune.off = PackedStringArray(["props"])
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var a: MeshInstance3D = _prop(root, [StandardMaterial3D.new(), StandardMaterial3D.new()])
	assert_eq(int(PropShadows.build(root)["meshes"]), 0)
	assert_eq(a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func test_render_tune_switches() -> void:
	assert_true(RenderTune.enabled)
	assert_true(RenderTune.on("props"))
	RenderTune.off = PackedStringArray(["props", "sun"])
	assert_false(RenderTune.on("props"))
	assert_true(RenderTune.on("proxies"))
	assert_true(RenderTune.enabled, "some passes still on")
	RenderTune.enabled = false
	for f: String in RenderTune.FEATURES:
		assert_false(RenderTune.on(f), f)
	RenderTune.enabled = true
	assert_true(RenderTune.off.is_empty())
