extends GutTest
## T-266: what the Shadows and Level of detail settings take off the render load below High (the sun's cascades and
## reach, small things' shadows, the lamps' draw distance) and that High and Ultra stay the map as authored.

var _was: bool = true


func before_each() -> void:
	_was = RenderTune.enabled
	RenderTune.enabled = true


func after_each() -> void:
	RenderTune.enabled = _was


func test_sun_rows_low_gets_the_most_ultra_nothing() -> void:
	assert_eq(ShadowBudget.sun_for(DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, 70.0, ShadowBudget.sun_row("low")), [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 40.0])
	assert_eq(ShadowBudget.sun_for(DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, 70.0, ShadowBudget.sun_row("medium")), [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 55.0])
	for lv: String in ["high", "ultra", "nonsense"]:
		assert_eq(ShadowBudget.sun_for(DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, 70.0, ShadowBudget.sun_row(lv)), [DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, 70.0], lv + " is the map as authored")
	assert_gt(float(ShadowBudget.sun_row("low")[2]), float(ShadowBudget.sun_row("medium")[2]), "Low drops bigger things' shadows than Medium")
	assert_eq(float(ShadowBudget.sun_row("high")[2]), 0.0)
	assert_eq(float(ShadowBudget.sun_row("ultra")[2]), 0.0)


func test_sun_never_gets_more_than_the_map_built() -> void:
	assert_eq(ShadowBudget.sun_for(DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 30.0, ShadowBudget.sun_row("low")), [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, 30.0])
	assert_eq(ShadowBudget.sun_for(DirectionalLight3D.SHADOW_ORTHOGONAL, 90.0, ShadowBudget.sun_row("medium")), [DirectionalLight3D.SHADOW_ORTHOGONAL, 55.0])


func _box(root: Node3D, side: float, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(side, side * 0.5, side * 0.5)
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)
	return mi


func test_node_applies_the_sun_and_the_small_casters_per_setting() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var cam: Camera3D = Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)
	var bottle: MeshInstance3D = _box(root, 0.2, Vector3(1, 0, 0))
	var stool: MeshInstance3D = _box(root, 0.4, Vector3(2, 0, 0))
	var table: MeshInstance3D = _box(root, 1.6, Vector3(3, 0, 0))
	var never: MeshInstance3D = _box(root, 0.2, Vector3(4, 0, 0))
	never.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var proxy: MeshInstance3D = _box(root, 0.2, Vector3(5, 0, 0))
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var sb: ShadowBudget = ShadowBudget.new()
	sb.map_root = root
	sb.level = "high"
	root.add_child(sb)
	await wait_process_frames(3)
	var on: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var off: int = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "High: the sun as authored")
	assert_almost_eq(sun.directional_shadow_max_distance, 70.0, 0.001)
	assert_eq([bottle.cast_shadow, stool.cast_shadow, table.cast_shadow], [on, on, on], "High: everything casts")
	sb.set_level("medium")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	assert_almost_eq(sun.directional_shadow_max_distance, 55.0, 0.001)
	assert_eq([bottle.cast_shadow, stool.cast_shadow, table.cast_shadow], [off, on, on], "Medium: under 25 cm casts nothing")
	sb.set_level("low")
	assert_almost_eq(sun.directional_shadow_max_distance, 40.0, 0.001)
	assert_eq([bottle.cast_shadow, stool.cast_shadow, table.cast_shadow], [off, off, on], "Low: under 50 cm casts nothing")
	assert_eq(int(sb.stats["small_off"]), 2)
	assert_eq(never.cast_shadow, off)
	assert_eq(proxy.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY, "a shadow-only proxy is not a small thing")
	var late: MeshInstance3D = _box(root, 0.3, Vector3(6, 0, 0))   # spawned in play (a dropped clip)
	await wait_process_frames(2)
	assert_eq(late.cast_shadow, off, "what joins the map on Low follows the rule")
	sb.set_level("ultra")
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "back to the authored sun")
	assert_almost_eq(sun.directional_shadow_max_distance, 70.0, 0.001)
	assert_eq([bottle.cast_shadow, stool.cast_shadow, table.cast_shadow, late.cast_shadow], [on, on, on, on], "and every shadow is back")
	never.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	assert_eq(never.cast_shadow, off, "a thing built without a shadow never gets one")


func test_switched_off_the_node_leaves_sun_and_casters_alone() -> void:
	RenderTune.enabled = false
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	root.add_child(sun)
	var bottle: MeshInstance3D = _box(root, 0.2, Vector3(1, 0, 0))
	var sb: ShadowBudget = ShadowBudget.new()
	sb.map_root = root
	sb.level = "low"
	root.add_child(sb)
	await wait_process_frames(3)
	assert_almost_eq(sun.directional_shadow_max_distance, 70.0, 0.001)
	assert_eq(bottle.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)


func test_light_range_per_setting() -> void:
	assert_gt(LightRange.end_for("low"), 0.0)
	assert_gt(LightRange.end_for("medium"), LightRange.end_for("low"), "Medium draws lamps further than Low")
	assert_eq(LightRange.end_for("high"), 0.0, "High: no draw distance")
	assert_eq(LightRange.end_for("ultra"), 0.0)
	assert_eq(LightRange.end_for("nonsense"), 0.0)
	var f: Vector2 = LightRange.fade_for(36.0, 4.0)
	assert_almost_eq(f.x + f.y, 40.0, 0.001, "gone at the distance plus the lamp's own reach")
	assert_almost_eq(f.y, 10.0, 0.001, "fading over the last quarter")


func test_light_range_applies_and_goes_back() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = 4.0
	root.add_child(lamp)
	var spot: SpotLight3D = SpotLight3D.new()
	spot.spot_range = 10.0
	root.add_child(spot)
	var own: OmniLight3D = OmniLight3D.new()   # a lamp the map already fades its own way
	own.distance_fade_enabled = true
	own.distance_fade_begin = 12.0
	root.add_child(own)
	var actor: CharacterBody3D = CharacterBody3D.new()
	root.add_child(actor)
	var torch: OmniLight3D = OmniLight3D.new()
	actor.add_child(torch)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	root.add_child(sun)
	assert_eq(LightRange.apply(root, LightRange.end_for("low")), 2)
	assert_true(lamp.distance_fade_enabled)
	assert_almost_eq(lamp.distance_fade_begin + lamp.distance_fade_length, 40.0, 0.001)
	assert_almost_eq(spot.distance_fade_begin + spot.distance_fade_length, 46.0, 0.001)
	assert_almost_eq(own.distance_fade_begin, 12.0, 0.001, "left alone")
	assert_false(torch.distance_fade_enabled, "a light a character carries is left alone")
	assert_eq(LightRange.apply(root, LightRange.end_for("medium")), 2)
	assert_almost_eq(lamp.distance_fade_begin + lamp.distance_fade_length, 60.0, 0.001, "re-applied from the setting")
	assert_eq(LightRange.apply(root, LightRange.end_for("high")), 0)
	assert_false(lamp.distance_fade_enabled, "High: as authored")
	assert_false(spot.distance_fade_enabled)
	assert_true(own.distance_fade_enabled)
