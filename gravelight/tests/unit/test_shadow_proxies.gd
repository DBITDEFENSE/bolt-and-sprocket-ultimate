extends GutTest
## T-266: ShadowProxies' wider merge (the textured library materials' batches, batches with a far cut-off, the
## ViewCells groups, every batch container) and the rule that says which shaders have a plain depth pass.

const SURFACE: String = "res://assets/materials/shaders/surface_pbr.gdshader"

var _was: bool = true


func before_each() -> void:
	_was = RenderTune.enabled
	RenderTune.enabled = true


func after_each() -> void:
	RenderTune.enabled = _was


func _box(parent: Node, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(2, 2, 2)
	var am: ArrayMesh = ArrayMesh.new()   # the generators' batches are ArrayMeshes
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bm.get_mesh_arrays())
	mi.mesh = am
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _map(holder_name: String = "StaticBatches") -> Array:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var holder: Node3D = Node3D.new()
	holder.name = holder_name
	root.add_child(holder)
	return [root, holder]


func _shader_mat(code: String) -> ShaderMaterial:
	var sh: Shader = Shader.new()
	sh.code = code
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = sh
	return m


func _proxies(holder: Node) -> Array:
	var out: Array = []
	for c: Node in holder.get_children():
		if str(c.name).begins_with("ShadowProxy_"):
			out.append(c)
	return out


func test_the_library_surface_shader_has_a_plain_depth_pass() -> void:
	var sh: Shader = load(SURFACE) as Shader
	assert_not_null(sh)
	assert_eq(ShadowProxies.shader_cull(sh), BaseMaterial3D.CULL_BACK, "surface_pbr moves no vertex and writes no alpha: its batches merge")


func test_code_cull_reads_the_cull_mode() -> void:
	assert_eq(ShadowProxies.code_cull("shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0); }"), BaseMaterial3D.CULL_BACK)
	assert_eq(ShadowProxies.code_cull("shader_type spatial;\nrender_mode cull_disabled, diffuse_burley;\nvoid fragment() { ALBEDO = vec3(1.0); }"), BaseMaterial3D.CULL_DISABLED)
	assert_eq(ShadowProxies.code_cull("shader_type spatial;\nrender_mode cull_front;\nvoid fragment() { ALBEDO = vec3(1.0); }"), BaseMaterial3D.CULL_FRONT)


func test_code_cull_refuses_what_changes_the_depth() -> void:
	var bad: Dictionary = {
		"alpha": "shader_type spatial;\nvoid fragment() { ALPHA = 0.5; }",
		"scissor": "shader_type spatial;\nvoid fragment() { ALPHA_SCISSOR_THRESHOLD = 0.5; }",
		"discard": "shader_type spatial;\nvoid fragment() { if (UV.x > 0.5) { discard; } }",
		"vertex move": "shader_type spatial;\nvoid vertex() { VERTEX += NORMAL * 0.1; }",
		"vertex component": "shader_type spatial;\nvoid vertex() { VERTEX.y = sin(TIME); }",
		"position": "shader_type spatial;\nvoid vertex() { POSITION = vec4(VERTEX, 1.0); }",
		"depth": "shader_type spatial;\nvoid fragment() { DEPTH = 0.0; }",
		"blend": "shader_type spatial;\nrender_mode blend_add;\nvoid fragment() { ALBEDO = vec3(1.0); }",
		"no depth": "shader_type spatial;\nrender_mode depth_draw_never;\nvoid fragment() { ALBEDO = vec3(1.0); }",
		"world coords": "shader_type spatial;\nrender_mode world_vertex_coords;\nvoid fragment() { ALBEDO = vec3(1.0); }",
		"canvas": "shader_type canvas_item;\nvoid fragment() { COLOR = vec4(1.0); }",
	}
	for k: String in bad:
		assert_eq(ShadowProxies.code_cull(bad[k]), -1, k)


func test_code_cull_ignores_comments_and_reads_of_vertex() -> void:
	var code: String = "shader_type spatial;\n// ALPHA is never written; discard neither\n/* VERTEX += 1.0; */\nvarying vec3 wp;\nvoid vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }\nvoid fragment() { ALBEDO = wp; if (VERTEX.z == 0.0) { ALBEDO = vec3(0.0); } }"
	assert_eq(ShadowProxies.code_cull(code), BaseMaterial3D.CULL_BACK)


func test_shader_material_batches_merge_into_a_proxy() -> void:
	var m: Array = _map()
	var mat: ShaderMaterial = _shader_mat("shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }")
	var a: MeshInstance3D = _box(m[1], Vector3(1, 1, 1), mat)
	var b: MeshInstance3D = _box(m[1], Vector3(4, 1, 1), mat)
	var r: Dictionary = ShadowProxies.build(m[0])
	assert_eq(int(r["batches"]), 2)
	assert_eq(int(r["proxies"]), 1)
	assert_eq(a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(b.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var p: MeshInstance3D = _proxies(m[1])[0]
	assert_eq(p.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var tris: int = p.mesh.get_faces().size() / 3
	assert_eq(tris, 24, "both boxes' 12 triangles each")


func test_an_alpha_shader_batch_keeps_its_own_shadow() -> void:
	var m: Array = _map()
	var a: MeshInstance3D = _box(m[1], Vector3(1, 1, 1), _shader_mat("shader_type spatial;\nvoid fragment() { ALPHA = 0.5; }"))
	var r: Dictionary = ShadowProxies.build(m[0])
	assert_eq(int(r["batches"]), 0)
	assert_eq(int(r["kept"]), 1)
	assert_eq(a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func test_switched_off_only_standard_materials_merge() -> void:
	RenderTune.enabled = false
	var m: Array = _map()
	_box(m[1], Vector3(1, 1, 1), _shader_mat("shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }"))
	_box(m[1], Vector3(4, 1, 1), StandardMaterial3D.new())
	var r: Dictionary = ShadowProxies.build(m[0])
	assert_eq(int(r["batches"]), 1)
	assert_eq(int(r["kept"]), 1)


func test_a_far_cut_off_merges_and_the_proxy_outlasts_the_batch() -> void:
	var m: Array = _map()
	var a: MeshInstance3D = _box(m[1], Vector3(1, 1, 1), StandardMaterial3D.new())
	a.visibility_range_end = 80.0
	a.visibility_range_end_margin = 6.0
	var near: MeshInstance3D = _box(m[1], Vector3(2, 1, 1), StandardMaterial3D.new())
	near.visibility_range_end = 20.0
	var plain: MeshInstance3D = _box(m[1], Vector3(3, 1, 1), StandardMaterial3D.new())
	var r: Dictionary = ShadowProxies.build(m[0])
	assert_eq(int(r["batches"]), 2, "the far cut-off and the plain one; the 20 m detail keeps its own")
	assert_eq(int(r["proxies"]), 2, "a ranged proxy and a plain one, never mixed")
	assert_eq(near.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert_eq(plain.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var ranged: int = 0
	for p: MeshInstance3D in _proxies(m[1]):
		if p.visibility_range_end > 0.0:
			ranged += 1
			assert_gt(p.visibility_range_end, 80.0 + 12.0, "a cell's reach past the batch's own cut-off")
			assert_almost_eq(p.visibility_range_end_margin, 6.0, 0.001)
	assert_eq(ranged, 1)


func test_view_cell_groups_get_their_own_tagged_proxies() -> void:
	var m: Array = _map("ZoneBatches")
	var a: MeshInstance3D = _box(m[1], Vector3(1, 1, 1), StandardMaterial3D.new())
	a.set_meta("vis_group", "A")
	var b: MeshInstance3D = _box(m[1], Vector3(2, 1, 1), StandardMaterial3D.new())
	b.set_meta("vis_group", "B")
	var r: Dictionary = ShadowProxies.build_all(m[0])
	assert_eq(int(r["batches"]), 2)
	assert_eq(int(r["proxies"]), 2, "one per group though they share a cell")
	var tags: Array = []
	for p: MeshInstance3D in _proxies(m[1]):
		tags.append(str(p.get_meta("vis_group", "")))
		assert_true(p.is_in_group(&"view_cell_member"), "ViewCells hides it with its group")
	tags.sort()
	assert_eq(tags, ["A", "B"])


func test_build_all_covers_the_generators_containers_and_group_holders() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	for h: String in ["StaticBatches", "DressBatches"]:
		var holder: Node3D = Node3D.new()
		holder.name = h
		root.add_child(holder)
		_box(holder, Vector3(1, 1, 1), StandardMaterial3D.new())
	var vg: Node3D = Node3D.new()
	vg.name = "VisGroup_A"
	vg.set_meta("vis_group", "A")
	root.get_node("StaticBatches").add_child(vg)
	_box(vg, Vector3(1, 1, 1), StandardMaterial3D.new())
	var r: Dictionary = ShadowProxies.build_all(root)
	assert_eq(int(r["batches"]), 3)
	assert_eq(int(r["proxies"]), 3)
	assert_eq(_proxies(vg).size(), 1, "the group holder's proxy sits under it")
	assert_eq(int(ShadowProxies.build_all(root)["batches"]), 0, "built once")


func test_undo_gives_the_batches_their_shadows_back() -> void:
	var m: Array = _map()
	var a: MeshInstance3D = _box(m[1], Vector3(1, 1, 1), _shader_mat("shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }"))
	ShadowProxies.build(m[0])
	ShadowProxies.undo(m[0])
	assert_eq(a.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
