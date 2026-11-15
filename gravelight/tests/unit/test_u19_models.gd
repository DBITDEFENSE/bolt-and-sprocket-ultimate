extends GutTest
## T-253 (UPDATE 19): the more detailed models keep their contracts. The Sherman (ShermanMesh, ShermanTank): the parts
## and their levels of detail, the triangle budget, the paint shader and its burnt version, the rig's node names, the
## colliders' sizes, the lamps, the wreck. The dive bomber (StukaPlane): its parts, its span, its scheme. The sky's
## aircraft (PlaneModels): silhouettes still, with the surfaces their users expect. The wagon and the crate (Props):
## inside the boxes their colliders have always used.


func _tris(m: Mesh) -> int:
	return ProcKit.mesh_tris(m)


func test_sherman_levels_of_detail_and_budget() -> void:
	for p: String in ["hull_detail", "turret_detail", "gun_detail", "wheel_far", "roller_far", "sprocket_far", "idler_far", "link_far"]:
		assert_true(ShermanMesh.has_part(p), "%s exists" % p)
	assert_false(ShermanMesh.has_part("wheel_detail"), "a wheel has no separate small parts")
	assert_false(ShermanMesh.has_part("nonsense"), "an unknown part is not a part")
	var counts: Dictionary = {"hull": 1, "turret": 1, "gun": 1, "wheel": 12, "roller": 6, "sprocket": 2, "idler": 2}
	var near: int = 0
	var far: int = 0
	for p2: String in counts:
		var n: int = int(counts[p2])
		near += _tris(ShermanMesh.part(p2)[0]) * n
		if ShermanMesh.has_part(p2 + "_detail"):
			near += _tris(ShermanMesh.part(p2 + "_detail")[0]) * n
		far += _tris(ShermanMesh.part(p2 + "_far")[0] if ShermanMesh.has_part(p2 + "_far") else ShermanMesh.part(p2)[0]) * n
	var links: int = int(floor(ShermanMesh.path_length(ShermanMesh.track_path()) / ShermanMesh.LINK_PITCH)) * 2
	near += _tris(ShermanMesh.part("link")[0]) * links
	far += _tris(ShermanMesh.part("link_far")[0]) * links
	assert_lt(near, 48000, "the whole tank near: %d triangles" % near)
	assert_gt(near, 35000, "and it is the detailed one (%d)" % near)
	assert_lt(far, 20000, "beyond the far range: %d triangles" % far)
	var hull: MeshInstance3D = ShermanMesh.instance("hull")
	var det: MeshInstance3D = hull.get_node("Detail")
	assert_almost_eq(det.visibility_range_end, ShermanMesh.DETAIL_RANGE, 0.01, "the small parts are drawn near only")
	assert_eq(hull.visibility_range_end, 0.0, "the hull itself is always drawn")
	hull.free()
	var wheel: MeshInstance3D = ShermanMesh.instance("wheel")
	assert_almost_eq(wheel.visibility_range_end, ShermanMesh.FAR_RANGE, 0.01)
	assert_almost_eq((wheel.get_node("Far") as MeshInstance3D).visibility_range_begin, ShermanMesh.FAR_RANGE, 0.01)
	wheel.free()


func test_sherman_paint_and_its_burnt_version() -> void:
	for key: String in ["od", "od_dark", "gear", "steel", "track", "rubber", "white", "wood", "canvas"]:
		var m: ShaderMaterial = ShermanMesh.material(key) as ShaderMaterial
		assert_not_null(m, "%s is the paint shader" % key)
		assert_eq(m.shader.resource_path, ProcKit.PAINT_SHADER)
		assert_not_null(m.get_shader_parameter("mask_tex"), "%s has its mask" % key)
		var b: ShaderMaterial = ShermanMesh.material(key, true) as ShaderMaterial
		assert_eq(float(b.get_shader_parameter("burnt")), 1.0, "%s burnt" % key)
		assert_eq(float(b.get_shader_parameter("snow")), 0.0, "no snow on a burning hull")
	assert_gt(float((ShermanMesh.material("od") as ShaderMaterial).get_shader_parameter("snow")), 0.3, "snow lies on the tank")
	assert_ne(ShermanMesh.material("snow"), ShermanMesh.material("snow", true), "the lying snow is gone from the wreck")
	# every key a part uses has a material of its own (none falls to the grey default)
	for p: String in ["hull", "hull_detail", "turret", "turret_detail", "gun", "gun_detail", "wheel", "sprocket", "idler", "roller", "link", "link_far"]:
		for k: Variant in ShermanMesh.part(p)[1]:
			assert_true(["od", "od_dark", "gear", "gear_dark", "steel", "track", "rubber", "white", "wood", "canvas", "glass", "brass", "lamp", "snow"].has(str(k)),
				"%s: key %s is known" % [p, str(k)])


func test_sherman_rig_contracts() -> void:
	var tk: ShermanTank = ShermanTank.new()
	tk.setup(ShermanEvent.table()["tank"], ShermanEvent.table()["assist"], 8000.0)
	add_child_autofree(tk)
	for path: String in ["Body", "Body/Hull", "Body/Hull/Detail", "Body/Turret", "Body/Turret/Turret", "Body/Turret/Gun", "Body/Turret/Gun/Gun", "Body/TrackL", "Body/TrackR",
			"Body/TrackLFar", "Body/TrackRFar", "Body/Exhaust", "Body/Turret/CrewLamp", "Body/HeadLamp", "HullBody", "AttackPoint0", "Body/wheel_0", "Body/sprocket_9"]:
		assert_not_null(tk.get_node_or_null(path), "node %s" % path)
	assert_eq((tk.get_node("Body/Turret") as Node3D).position, ShermanMesh.TURRET_AT)
	assert_eq((tk.get_node("Body/Turret/Gun") as Node3D).position, ShermanMesh.GUN_AT)
	var shapes: Array[Vector3] = []
	for c: Node in tk.get_node("HullBody").get_children():
		if c is CollisionShape3D:
			shapes.append(((c as CollisionShape3D).shape as BoxShape3D).size)
	assert_eq(shapes, [Vector3(2.62, 1.75, 5.9), Vector3(1.9, 0.85, 2.1)] as Array[Vector3], "the colliders are the size they were")
	assert_false((tk.get_node("Body/HeadLamp") as SpotLight3D).shadow_enabled, "the lamps cast no shadows")
	var far: MultiMeshInstance3D = tk.get_node("Body/TrackLFar")
	assert_eq(far.multimesh.instance_count, (tk.get_node("Body/TrackL") as MultiMeshInstance3D).multimesh.instance_count, "the far track has every link")
	assert_eq((tk.get("_links") as Array).size(), 4, "and the rig lays all four (near and far, both sides) in one loop")
	assert_almost_eq(tk.muzzle().distance_to(tk.gun.global_position), ShermanMesh.GUN_LEN + 0.05, 0.01, "the muzzle where it was")
	tk.wreck(false)
	await wait_frames(2)
	assert_null(tk.get_node_or_null("Body/HeadLamp"), "the wreck's lamps are out")
	assert_null(tk.get_node_or_null("Body/Turret/CrewLamp"))
	var hull: MeshInstance3D = tk.get_node("Body/Hull")
	assert_eq(float((hull.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("burnt")), 1.0, "the hull is burnt")
	var det: MeshInstance3D = tk.get_node("Body/Hull/Detail")
	assert_eq(float((det.get_surface_override_material(0) as ShaderMaterial).get_shader_parameter("burnt")), 1.0, "and its small parts")
	assert_eq(float(((tk.get_node("Body/TrackR") as MultiMeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("burnt")), 1.0, "and its tracks")
	assert_not_null(tk.get_node_or_null("Body/WreckFire"), "it burns")


func test_stuka_model() -> void:
	var body: ArrayMesh = StukaPlane.part("body")[0]
	var box: AABB = body.get_aabb()
	assert_true(box.size.x > 13.0 and box.size.x < 14.5, "a 13.9 m span (%.1f)" % box.size.x)
	assert_true(box.size.z > 10.5 and box.size.z < 11.6, "about 11 m long (%.1f)" % box.size.z)
	var total: int = _tris(body) + _tris(StukaPlane.part("prop")[0]) + _tris(StukaPlane.part("bomb")[0])
	assert_lt(total, 14000, "the dive bomber: %d triangles" % total)
	assert_gt(total, 6000, "and it is the detailed one")
	var paint: ShaderMaterial = StukaPlane.material("paint") as ShaderMaterial
	assert_eq(float(paint.get_shader_parameter("scheme")), 1.0, "its paint is the splinter scheme")
	assert_eq(paint.shader.resource_path, ProcKit.PAINT_SHADER_SKY, "and the fog does not swallow it (the sky's other aircraft are the same)")
	assert_eq(float(paint.get_shader_parameter("crosses")), 1.0 if StukaPlane.CROSSES else 0.0, "the crosses follow the switch")
	var s: StukaPlane = StukaPlane.new()
	add_child_autofree(s)
	s.build()
	assert_not_null(s.get_node_or_null("Prop"), "the airscrew's node")
	assert_not_null(s.get_node_or_null("Bomb"), "the bomb's node")
	var lights: int = 0
	for c: Node in s.get_children():
		if c is OmniLight3D:
			lights += 1
	assert_eq(lights, 2, "the exhausts' glow is still there for the night sky")


func test_sky_aircraft_are_shaped_silhouettes() -> void:
	for key: String in ["bomber", "fighter", "mosquito", "il2", "pe2", "nightfighter"]:
		var m: ArrayMesh = PlaneModels.by_name(key)
		var t: int = _tris(m)
		assert_lt(t, 1200, "%s: %d triangles" % [key, t])
		assert_gt(t, 250, "%s is more than boxes (%d)" % [key, t])
		var box: AABB = m.get_aabb()
		assert_almost_eq(box.size.x, 1.0, 0.03, "%s: span 1" % key)
		assert_almost_eq(box.get_center().x, 0.0, 0.01, "%s: centred" % key)
		assert_eq(m.get_surface_count(), 3 if key in ["il2", "pe2"] else 2, "%s: airframe, glow%s" % [key, ", stars" if key in ["il2", "pe2"] else ""])
		assert_true((m.surface_get_material(1) as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "%s: surface 1 is the glow" % key)


func _bounds(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func test_wagon_and_crate_stay_in_their_boxes() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	Props.cart(root, Vector3.ZERO, 0.0)
	var b: AABB = _bounds(root)
	assert_lt(maxf(absf(b.position.x), absf(b.end.x)), 0.97, "the wagon is inside its 1.9 m wide collider (%.2f)" % maxf(absf(b.position.x), absf(b.end.x)))
	assert_lt(b.end.z, 1.5, "and its 3 m length behind")
	assert_gt(b.position.z, -3.3, "the drawbar no longer than it was")
	assert_gt(b.position.y, -0.01, "nothing under the ground")
	assert_gt(root.find_children("*", "MeshInstance3D", true, false).size(), 100, "four spoked wheels, the ladders, the bed")
	var root2: Node3D = Node3D.new()
	add_child_autofree(root2)
	Props.crate(root2, Vector3.ZERO, 1.0, 0.0)
	var c: AABB = _bounds(root2)
	assert_lt(maxf(absf(c.position.x), absf(c.end.x)), 0.521, "the crate's width as before")
	assert_lt(maxf(absf(c.position.z), absf(c.end.z)), 0.521)
	assert_lt(c.end.y, 1.001, "and its height")
