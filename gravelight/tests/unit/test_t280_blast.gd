extends GutTest
## T-280 (better, more detailed explosions that never cost a frame): BlastFx's pool, that a blast allocates nothing,
## the look scaling with kind and radius, the quality tiers, the light cap, the old two-argument call, the co-op
## mirror carrying the look, the screen pass honouring the accessibility settings, the warm-up and the sound layers.

var _quality: Variant
var _shake: Variant
var _reduce: Variant
var _preset: Variant


func before_each() -> void:
	_quality = GLSettings.values.get("vfx_quality", "high")
	_shake = GLSettings.values.get("screen_shake", 1.0)
	_reduce = GLSettings.values.get("reduce_motion", false)
	_preset = GLSettings.values.get("graphics_preset", "high")
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["graphics_preset"] = "high"
	Effects.blast.clear()


func after_each() -> void:
	GLSettings.values["vfx_quality"] = _quality
	GLSettings.values["screen_shake"] = _shake
	GLSettings.values["reduce_motion"] = _reduce
	GLSettings.values["graphics_preset"] = _preset
	Effects.blast.clear()
	Effects.clear_marks()


func _emitter(slot: int, nm: String) -> GPUParticles3D:
	return Effects.blast.get_child(slot).get_node(nm) as GPUParticles3D


func test_the_pool_is_built_once_with_shared_materials() -> void:
	var b: BlastFx = Effects.blast
	assert_eq(Effects.BLASTS, BlastFx.SLOTS)
	var slots: int = 0
	var lights: int = 0
	for c: Node in b.get_children():
		if c.name.begins_with("Blast") and c is Node3D and not (c is OmniLight3D):
			slots += 1
		if c is OmniLight3D:
			lights += 1
			assert_false((c as OmniLight3D).shadow_enabled, "a blast light casts no shadow")
	assert_eq(slots, BlastFx.SLOTS)
	assert_eq(lights, BlastFx.LIGHTS)
	for nm: String in BlastFx.EMITTERS:
		var first: GPUParticles3D = _emitter(0, nm)
		assert_not_null(first, nm)
		assert_true(first.one_shot, nm + " is one-shot")
		for i: int in range(1, BlastFx.SLOTS):
			assert_same(_emitter(i, nm).process_material, first.process_material, nm + ": one process material for every slot")
			if nm != "Debris":
				assert_same(_emitter(i, nm).draw_pass_1, first.draw_pass_1, nm + ": one draw mesh for every slot")
	var fl0: MeshInstance3D = b.get_child(0).get_node("Flash")
	var fl1: MeshInstance3D = b.get_child(1).get_node("Flash")
	assert_same(fl0.material_override, fl1.material_override, "one flash material")
	assert_same((_emitter(0, "Fire").draw_pass_1 as QuadMesh).material, (_emitter(0, "Smoke").draw_pass_1 as QuadMesh).material, "one puff material")


func test_a_blast_allocates_no_object() -> void:
	Effects.explosion(Vector3(0, 0.3, 0), 6.0, "grenade")   # anything lazy happens here, not below
	var objects: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var res: float = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	for i: int in 6:
		Effects.explosion(Vector3(i * 2.0, 0.3, 0), [6.0, 4.5, 7.0, 0.6, 3.0, 9.0][i], ["grenade", "", "bomb", "", "shell", ""][i])
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "no node made by six blasts")
	assert_eq(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), res, "no resource (material, mesh, texture) made")
	assert_eq(Performance.get_monitor(Performance.OBJECT_COUNT), objects, "no object at all")


func test_more_blasts_than_slots_reuse_the_oldest() -> void:
	for i: int in BlastFx.SLOTS + 3:
		Effects.explosion(Vector3(i, 0.3, 0), 4.5)
	assert_eq(Effects.blast.live_count(), BlastFx.SLOTS, "capped at the pool")


func test_the_kind_comes_from_the_radius_when_not_named() -> void:
	assert_eq(BlastFx.kind_for(0.6), "small")
	assert_eq(BlastFx.kind_for(1.49), "small")
	assert_eq(BlastFx.kind_for(1.5), "shell")
	assert_eq(BlastFx.kind_for(4.5), "shell")
	assert_eq(BlastFx.kind_for(7.0), "bomb")
	assert_eq(Effects.blast.kind_row("nonsense", 7.0)["kind"], "bomb", "an unknown kind falls back to the radius")
	assert_eq(Explosion.fx_kind({}, &"frag"), "grenade", "a frag looks like a hand grenade")
	assert_eq(Explosion.fx_kind({}, &"panzerschreck"), "", "other blasts by radius")
	assert_eq(Explosion.fx_kind({"fx": "bomb"}, &"frag"), "bomb", "a cfg can name its look")


func test_the_look_scales_with_kind_and_radius() -> void:
	var sizes: Array = []
	for pair: Array in [[0.6, "small"], [6.0, "grenade"], [4.5, "shell"], [7.0, "bomb"]]:
		Effects.explosion(Vector3(0, 0.3, 0), float(pair[0]), str(pair[1]))
		assert_eq(Effects.blast.last["kind"], pair[1])
		sizes.append(float(Effects.blast.last["scale"]))
	for i: int in range(1, sizes.size()):
		assert_gt(float(sizes[i]), float(sizes[i - 1]), "each kind is bigger than the last: %s" % str(sizes))
	var row: Dictionary = Effects.blast.kind_row("shell", 4.5)
	assert_gt(BlastFx.visual_scale(row, 5.5), BlastFx.visual_scale(row, 4.5), "a wider shell blast is drawn bigger")
	assert_eq(BlastFx.visual_scale(row, 100.0), float(row["size"]) * float(row["max_k"]), "but clamped")


func test_a_small_blast_stays_small() -> void:
	Effects.explosion(Vector3(0, 1.4, 0), 0.6)
	var slot: int = int(Effects.blast.last["slot"])
	assert_eq(Effects.blast.last["kind"], "small")
	assert_lt(float(Effects.blast.last["scale"]), 0.6)
	for nm: String in ["Smoke", "Spray", "Skirt", "Debris"]:
		assert_false(_emitter(slot, nm).visible, "a pop has no " + nm)
	assert_true(_emitter(slot, "Sparks").visible, "but sparks")
	assert_eq(Effects.scorch_count(), 0, "and leaves no scorch mark")


func test_an_air_burst_throws_no_dirt() -> void:
	Effects.explosion(Vector3(0, 40.0, 0), 4.5, "shell")   # nothing under it in the test world
	var slot: int = int(Effects.blast.last["slot"])
	assert_false(Effects.blast.last["ground"])
	assert_false(_emitter(slot, "Spray").visible)
	assert_false(_emitter(slot, "Debris").visible)
	assert_true(_emitter(slot, "Fire").visible)
	assert_true(_emitter(slot, "Smoke").visible)


func test_quality_tiers() -> void:
	GLSettings.values["vfx_quality"] = "high"
	Effects.explosion(Vector3.ZERO, 4.5, "shell")
	var hi: float = float(Effects.blast.last["ratio"])
	GLSettings.values["vfx_quality"] = "low"
	Effects.explosion(Vector3.ZERO, 4.5, "shell")
	var lo: float = float(Effects.blast.last["ratio"])
	assert_almost_eq(lo, hi * float(Effects.quality()["particles"]) / 1.0, 0.001 + hi * 0.5 * (1.0 if GLSettings.is_compat() else 0.0))
	assert_lt(lo, hi, "Low throws fewer particles")
	assert_gt(float(Effects.blast.last["speed"]), 1.0, "and runs them faster (shorter smoke)")


func test_the_light_cap_follows_quality() -> void:
	for q: String in ["low", "medium", "high"]:
		Effects.blast.clear()
		GLSettings.values["vfx_quality"] = q
		for i: int in 6:
			Effects.explosion(Vector3(i * 3.0, 0.3, 0), 4.5)
		var cap: int = int(Effects.quality().get("blast_lights", 3))
		assert_eq(Effects.blast.lights_alive(), cap, "%s: %d lights at once" % [q, cap])
	assert_eq(int(Effects.vfx["quality"]["low"]["blast_lights"]), 1)


func test_the_lights_fade_and_slots_free_themselves() -> void:
	Effects.explosion(Vector3.ZERO, 4.5)
	assert_eq(Effects.blast.lights_alive(), 1)
	for f: int in 60:
		Effects.blast._process(0.05)
	assert_eq(Effects.blast.lights_alive(), 0, "the light is gone within a second")
	for f: int in 200:
		Effects.blast._process(0.05)
	assert_eq(Effects.blast.live_count(), 0, "the smoke has cleared and the slot is free")
	assert_false(Effects.blast.get_child(0).visible)


func test_the_old_two_argument_call_and_the_co_op_mirror() -> void:
	Effects.explosion(Vector3(1, 0.3, 1), 3.0)
	assert_eq(Effects.blast.last["kind"], "shell", "two arguments: the kind from the radius")
	var nm: Node = (load("res://gravelight/net/net_match.gd") as GDScript).new()
	nm.call("_show_fx", &"explosion", [Vector3(2, 0.3, 2), 6.0, "grenade_explode", 0.0])
	assert_eq(Effects.blast.last["kind"], "shell", "an old peer's four arguments still show a blast")
	nm.call("_show_fx", &"explosion", [Vector3(2, 0.3, 2), 6.0, "grenade_explode", 0.0, "grenade"])
	assert_eq(Effects.blast.last["kind"], "grenade", "the look rides along to the other peers")
	nm.free()


func test_the_screen_pass_honours_the_accessibility_settings() -> void:
	GLSettings.values["reduce_motion"] = false
	GLSettings.values["screen_shake"] = 1.0
	assert_eq(BlastScreen.accessibility_k(), Vector2(1.0, 1.0))
	GLSettings.values["screen_shake"] = 0.0
	assert_eq(BlastScreen.accessibility_k().y, 0.0, "no shake, no blur")
	GLSettings.values["reduce_motion"] = true
	GLSettings.values["screen_shake"] = 1.0
	var k: Vector2 = BlastScreen.accessibility_k()
	assert_eq(k.y, 0.0, "Reduce Motion: no blur")
	assert_eq(k.x, 0.5, "and half the flash")
	var s: BlastScreen = Effects.blast.screen
	s.pulse(1.0, Vector2(0.5, 0.5))
	assert_almost_eq(s.last_flash, BlastScreen.FLASH_MAX * 0.5, 0.001)
	assert_eq(s.last_blur, 0.0)
	s.clear()
	assert_false(s.active())


func test_the_warm_up_compiles_in_front_of_the_camera_and_hides_again() -> void:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	cam.make_current()
	var before: int = int(Effects.blast.stats["warmed"])
	Effects.blast.warm()
	Effects.blast._process(0.016)
	var slot: Node3D = Effects.blast.get_child(BlastFx.SLOTS - 1)
	assert_true(slot.visible, "the warm-up blast is out")
	assert_lt(slot.scale.x, 0.01, "too small to see")
	for f: int in 4:
		Effects.blast._process(0.016)
	assert_eq(int(Effects.blast.stats["warmed"]), before + 1)
	assert_false(slot.visible, "and gone again")
	assert_eq(Effects.blast.lights_alive(), 0)


func test_the_sound_layers_by_distance() -> void:
	var b: BlastFx = Effects.blast
	var row: Dictionary = b.kind_row("shell", 4.5)
	var snd: Dictionary = row["sound"]
	for k: String in ["crack", "rumble", "debris"]:
		assert_true(AudioDirector.has_sound(str(snd[k])), "%s is in the bank" % snd[k])
	assert_true(AudioDirector.has_sound("blast_pop"))
	var played: int = int(b.stats["sounds"])
	b._sounds(Vector3.ZERO, 3.0, row)   # close: the crack now, the debris after a moment, no rumble
	assert_eq(int(b.stats["sounds"]), played + 1, "the crack plays at once")
	assert_eq(b._npend, 1, "the debris patter waits")
	b.clear()
	b._sounds(Vector3.ZERO, 120.0, row)   # far: only the rumble, late
	assert_eq(b._npend, 1)
	var due: float = -1.0
	for t: float in b._pend_t:
		due = maxf(due, t)
	assert_almost_eq(due, 120.0 / BlastFx.SPEED_OF_SOUND, 0.01, "it arrives at the speed of sound")
	b.clear()


func test_the_graphics_preset_thins_them_too() -> void:
	Effects.explosion(Vector3.ZERO, 4.5, "shell")
	var hi: float = float(Effects.blast.last["ratio"])
	GLSettings.values["graphics_preset"] = "low"
	assert_lt(Effects.blast.preset_k(), 1.0)
	Effects.blast.clear()
	for i: int in 4:
		Effects.explosion(Vector3(i * 3.0, 0.3, 0), 4.5, "shell")
	assert_lt(float(Effects.blast.last["ratio"]), hi, "the Low preset throws fewer particles at the same VFX quality")
	assert_eq(Effects.blast.lights_alive(), 1, "and keeps one blast light")
	GLSettings.values["graphics_preset"] = "ultra"
	assert_eq(Effects.blast.preset_k(), 1.0)
