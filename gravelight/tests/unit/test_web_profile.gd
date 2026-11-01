extends GutTest
## T-139 (UPDATE 09 section 2c/2d): the browser build's graphics profile. The "web" preset is complete and
## Compatibility-safe, the first-launch detection picks low / medium / high / web from sample adapter strings,
## WebProfile caps a synthetic scene (depth fog for volumetric fog, 40 m sun shadows, 4 shadowed lights per zone
## nearest the spawn, particles and zombie animation LOD halved) and is idempotent, the web texture cap shrinks a
## compressed image, and MapPacks is a no-op on the desktop.

var _saved: Dictionary


func before_each() -> void:
	_saved = GLSettings.values.duplicate(true)


func after_each() -> void:
	GLSettings.values = _saved
	GLSettings.compat_override = -1
	Zombie.anim_lod_scale = 1.0
	Snowfall.density_scale = 1.0


func test_the_web_preset_is_complete_and_has_nothing_compatibility_lacks() -> void:
	var w: Dictionary = GLSettings.PRESETS[GLSettings.WEB_PRESET]
	for k: Variant in (GLSettings.PRESETS["high"] as Dictionary).keys():
		assert_true(w.has(k), "web has %s" % k)
	assert_false(str(w["gfx_aa"]).begins_with("msaa"), "no MSAA")
	assert_false(str(w["gfx_aa"]).contains("taa"), "no TAA")
	assert_eq(str(w["gfx_upscaler"]), "bilinear", "FSR needs Forward+")
	assert_false(bool(w["gfx_gi"]))
	assert_false(bool(w["gfx_ssil"]))
	assert_false(bool(w["gfx_ssr"]))
	assert_eq(str(w["gfx_fog"]), "off")
	assert_eq(str(w["gfx_ao"]), "off")
	assert_false(GLSettings.PRESET_ORDER.has(GLSettings.WEB_PRESET), "the desktop menu keeps its four presets")
	assert_true(GLSettings.preset_order(true).has(GLSettings.WEB_PRESET), "the browser's menu offers it")
	assert_false(GLSettings.preset_order(false).has(GLSettings.WEB_PRESET))
	assert_eq(GLSettings.matching_preset(w), GLSettings.WEB_PRESET, "its own settings read as the web preset")


func test_detect_preset_on_sample_adapters() -> void:
	var D: Dictionary = {"other": RenderingDevice.DEVICE_TYPE_OTHER, "igpu": RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU,
		"dgpu": RenderingDevice.DEVICE_TYPE_DISCRETE_GPU, "cpu": RenderingDevice.DEVICE_TYPE_CPU}
	var cases: Array = [
		["NVIDIA GeForce RTX 5090", "dgpu", "forward_plus", "high"],
		["NVIDIA GeForce GTX 1060 6GB", "dgpu", "forward_plus", "high"],
		["AMD Radeon RX 7800 XT", "dgpu", "forward_plus", "high"],
		["Intel(R) Iris(R) Xe Graphics", "igpu", "forward_plus", "low"],
		["Intel(R) Iris(R) Xe Graphics", "other", "forward_plus", "low"],
		["Intel(R) UHD Graphics 620", "other", "forward_plus", "low"],
		["AMD Radeon(TM) Graphics", "igpu", "forward_plus", "low"],
		["AMD Radeon 680M", "other", "forward_plus", "low"],
		["AMD Radeon 780M Graphics", "igpu", "mobile", "low"],
		["llvmpipe (LLVM 17.0.6, 256 bits)", "cpu", "forward_plus", "low"],
		["NVIDIA GeForce RTX 4070 Laptop GPU", "other", "forward_plus", "high"],
		["Intel(R) Arc(TM) A770 Graphics", "dgpu", "forward_plus", "medium"],
		["Apple M2", "igpu", "forward_plus", "low"],
		["", "other", "forward_plus", "medium"],
		["Some Future GPU", "other", "forward_plus", "medium"],
		["NVIDIA GeForce RTX 5090", "dgpu", "gl_compatibility", "web"],
		["ANGLE (Intel, Intel(R) Iris(R) Xe Graphics Direct3D11)", "other", "gl_compatibility", "web"],
	]
	for c: Array in cases:
		assert_eq(GLSettings.detect_preset(str(c[0]), int(D[str(c[1])]), str(c[2])), str(c[3]), "%s (%s, %s)" % [c[0], c[1], c[2]])
	for c2: Array in cases:
		assert_ne(GLSettings.detect_preset(str(c2[0]), int(D[str(c2[1])]), str(c2[2])), "ultra", "never auto-picks ultra")


func test_compat_override_and_web_flag() -> void:
	GLSettings.compat_override = 1
	assert_true(GLSettings.is_compat())
	GLSettings.compat_override = 0
	assert_false(GLSettings.is_compat())
	assert_false(GLSettings.is_web(), "the test runner is a desktop build")


func _scene() -> Node3D:
	var root: Node3D = Node3D.new()
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.volumetric_fog_enabled = true
	we.environment.volumetric_fog_density = 0.05
	we.environment.volumetric_fog_albedo = Color(0.8, 0.8, 0.9)
	we.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
	we.environment.ambient_light_energy = 0.5
	we.environment.sdfgi_enabled = true
	we.environment.ssil_enabled = true
	we.environment.ssr_enabled = true
	root.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	root.add_child(sun)
	var za: ZoneVolume = ZoneVolume.new()
	za.zone_id = &"za"
	za.size = Vector3(40, 10, 40)
	root.add_child(za)
	var zb: ZoneVolume = ZoneVolume.new()
	zb.zone_id = &"zb"
	zb.size = Vector3(40, 10, 40)
	zb.position = Vector3(100, 0, 0)
	root.add_child(zb)
	for i: int in 7:   # zone A: 7 shadowed lamps at x = 1..7 m from the spawn (the origin)
		var l: OmniLight3D = OmniLight3D.new()
		l.name = "A%d" % i
		l.shadow_enabled = true
		l.position = Vector3(1.0 + i, 2, 0)
		root.add_child(l)
	for j: int in 2:   # zone B: 2 shadowed spots, under the cap
		var s: SpotLight3D = SpotLight3D.new()
		s.name = "B%d" % j
		s.shadow_enabled = true
		s.position = Vector3(100 + j, 2, 0)
		root.add_child(s)
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Snow"
	p.amount = 200
	root.add_child(p)
	var fv: FogVolume = FogVolume.new()
	fv.name = "Mist"
	root.add_child(fv)
	return root


func test_web_profile_caps_a_synthetic_scene() -> void:
	var root: Node3D = _scene()
	add_child_autofree(root)
	var r: Dictionary = WebProfile.apply(root)
	var env: Environment = (root.get_child(0) as WorldEnvironment).environment
	assert_false(env.sdfgi_enabled)
	assert_false(env.ssil_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)
	assert_true(env.fog_enabled, "volumetric fog became depth fog")
	assert_eq(env.fog_mode, Environment.FOG_MODE_DEPTH)
	assert_eq(str(r["fog"]), "depth")
	assert_almost_eq(env.fog_depth_end, 50.0, 0.01, "2.5 / density")
	assert_gt(env.fog_light_color.b, 0.0, "the fog keeps a colour from the volumetric fog")
	assert_almost_eq((root.get_node("Sun") as DirectionalLight3D).directional_shadow_max_distance, 40.0, 0.001)
	for i: int in 7:
		assert_eq((root.get_node("A%d" % i) as Light3D).shadow_enabled, i < 4, "zone A lamp %d (the 4 nearest keep it)" % i)
	assert_true((root.get_node("B0") as Light3D).shadow_enabled, "zone B is under the cap")
	assert_true((root.get_node("B1") as Light3D).shadow_enabled)
	assert_eq(int(r["shadows_off"]), 3)
	assert_eq(int(r["shadowed_kept"]), 6)
	assert_almost_eq((root.get_node("Snow") as GPUParticles3D).amount_ratio, 0.5, 0.001)
	assert_false((root.get_node("Mist") as FogVolume).visible)
	assert_almost_eq(Zombie.anim_lod_scale, 0.5, 0.001)
	assert_almost_eq(Snowfall.density_scale, 0.5, 0.001)
	# idempotent: a second pass halves nothing twice and changes no fog
	var r2: Dictionary = WebProfile.apply(root)
	assert_almost_eq((root.get_node("Snow") as GPUParticles3D).amount_ratio, 0.5, 0.001)
	assert_eq(int(r2["particles"]), 0)
	assert_eq(int(r2["shadows_off"]), 0)
	assert_almost_eq(env.fog_depth_end, 50.0, 0.01)


func test_map_fog_is_kept_when_the_map_had_its_own() -> void:
	var env: Environment = Environment.new()
	env.fog_enabled = true
	env.fog_density = 0.02
	env.volumetric_fog_enabled = true
	assert_eq(WebProfile.environment(env), "kept")
	assert_eq(env.fog_mode, Environment.FOG_MODE_EXPONENTIAL)
	assert_almost_eq(env.fog_density, 0.026, 0.0001)
	assert_false(env.volumetric_fog_enabled)
	var plain: Environment = Environment.new()
	assert_eq(WebProfile.environment(plain), "", "no fog wanted, none made")
	assert_false(plain.fog_enabled)


func test_cap_shadows_prefers_the_spawn() -> void:
	var lights: Array = []
	for x: float in [30.0, 5.0, 12.0, 1.0, 50.0]:
		var l: OmniLight3D = OmniLight3D.new()
		l.shadow_enabled = true
		l.position = Vector3(x, 0, 0)
		lights.append(l)
	var r: Vector2i = WebProfile.cap_shadows(lights, Vector3.ZERO, 2)
	assert_eq(r, Vector2i(2, 3))
	var kept: Array = lights.filter(func(l: OmniLight3D) -> bool: return l.shadow_enabled).map(func(l: OmniLight3D) -> float: return l.position.x)
	kept.sort()
	assert_eq(kept, [1.0, 5.0])
	for l2: OmniLight3D in lights:
		l2.free()


func test_web_texture_cap_shrinks_a_compressed_image() -> void:
	var cap: GDScript = load("res://addons/gl_web_export/web_texture_cap.gd") as GDScript
	var img: Image = Image.create(256, 128, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.4, 0.2, 0.8))
	img.compress(Image.COMPRESS_S3TC)
	var out: PortableCompressedTexture2D = cap.call("cap_image", img, 64) as PortableCompressedTexture2D
	assert_not_null(out)
	assert_eq(out.get_width(), 64)
	assert_eq(out.get_height(), 32, "keeps the aspect")
	assert_null(cap.call("cap_image", img, 512), "under the cap: unchanged")


func test_map_packs_on_the_desktop() -> void:
	assert_eq(MapPacks.map_id_of("res://gravelight/maps/map01_kaltenbrunn/map01.tscn"), "map01_kaltenbrunn")
	assert_eq(MapPacks.scene_of("map04c_groomlake"), "res://gravelight/maps/map04_fernflug/map04c.tscn")
	assert_false(MapPacks.knows(&"map00_crossroads"), "the desktop has no packs")
	var ok: bool = await MapPacks.ensure("map00_crossroads")
	assert_true(ok, "desktop: the scene is there")
	assert_true(Campaign.scene_exists(&"map02_totenhafen"))
	assert_eq(MapPacks.SCENE_MAP.size(), 7, "every map in the menu has a pack entry")
