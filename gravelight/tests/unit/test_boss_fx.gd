extends GutTest
## T-231: the boss effects kit's pure parts (docs/BOSS_REWORK.md section 2): the dread level by distance, facing and
## sight; DreadFx's max over reporters and its forgetting; the sound pack's ids all in the manifest with files on
## disk; every emitter kind builds.


func test_dread_level_falls_with_distance_and_rises_when_seen() -> void:
	assert_almost_eq(BossFx.dread_level(30.0, 5.0, 18.0, false, false, 0.0), 0.0, 0.001, "out of range: nothing")
	var near: float = BossFx.dread_level(4.0, 5.0, 18.0, false, true, 0.0)
	var mid: float = BossFx.dread_level(11.0, 5.0, 18.0, false, true, 0.0)
	assert_gt(near, mid, "closer is more")
	assert_almost_eq(near, 1.0, 0.001, "inside `near` with sight: full")
	assert_lt(BossFx.dread_level(11.0, 5.0, 18.0, false, false, 0.0), mid, "no line of sight: less")
	assert_gt(BossFx.dread_level(11.0, 5.0, 18.0, true, true, 0.0), mid, "the boss looking your way: more")
	assert_almost_eq(BossFx.dread_level(30.0, 5.0, 18.0, false, false, 0.4), 0.4, 0.001, "a subclass's extra adds")
	assert_lte(BossFx.dread_level(1.0, 5.0, 18.0, true, true, 1.0), 1.0, "never over 1")


func test_dread_fx_takes_the_max_and_forgets() -> void:
	var d: DreadFx = DreadFx.new()
	d.report(&"a", 0.3, false)
	d.report(&"b", 0.8, true)
	var t: Array = d.target_level()
	assert_almost_eq(float(t[0]), 0.8, 0.001, "the max over reporters")
	assert_almost_eq(float(t[1]), 0.8, 0.001, "looking = the looker's level")
	d.release(&"b")
	t = d.target_level()
	assert_almost_eq(float(t[0]), 0.3, 0.001, "released: the other remains")
	assert_almost_eq(float(t[1]), 0.0, 0.001, "nobody looking")
	d.free()


func test_sound_pack_ids_are_in_the_manifest_with_files() -> void:
	var sounds: Dictionary = (GLData.load_json("res://data/gravelight/audio.json") as Dictionary).get("sounds", {})
	var want: Array = ["boss_dread_bed", "boss_pulse", "boss_stomp", "boss_hit_porcelain", "boss_hit_iron", "boss_hit_flesh",
		"boss_hit_glass", "boss_hit_cloth", "boss_weakpoint_hit", "boss_telegraph_rise", "boss_death_toll", "boss_roar_low",
		"boss_breath", "boss_bone_crack", "boss_doll_giggle", "boss_doll_crack", "boss_hum_wrong", "paul_roar",
		"paul_bottle_break", "paul_plate_grind", "slender_lantern_hum", "slender_keys_still", "slender_whisper",
		"kielholer_chain_drag", "kielholer_water_rise", "kielholer_helmet_knock", "foreman_drill_spin", "foreman_chain_whip",
		"kran_rail_screech", "kran_casing_drop", "bordwart_cable_sing", "bordwart_impeller_loop", "pilot_rig_whine",
		"pilot_rig_misfire", "manager_servo", "manager_stamp", "manager_field_hum"]
	for k: String in want:
		assert_true(sounds.has(k), k + " is in audio.json")
		if sounds.has(k):
			for f: String in (sounds[k] as Dictionary).get("files", []):
				assert_true(ResourceLoader.exists(f) or FileAccess.file_exists(f), "%s: %s exists" % [k, f])
	for k: String in ["boss_dread_bed", "boss_pulse", "boss_hum_wrong", "slender_lantern_hum", "kielholer_chain_drag",
			"foreman_drill_spin", "bordwart_impeller_loop", "pilot_rig_whine", "manager_field_hum"]:
		assert_true(bool((sounds.get(k, {}) as Dictionary).get("loop", false)), k + " loops")


func test_every_emitter_kind_builds() -> void:
	var holder: Node3D = Node3D.new()
	add_child_autofree(holder)
	for k: Variant in BossFx.KINDS.keys():
		var e: GPUParticles3D = BossFx.emitter(str(k), holder, Vector3.ZERO, 1.0)
		assert_not_null(e, str(k) + " builds")
		assert_gt(e.amount, 1, str(k) + " has particles")
		assert_false(e.emitting, str(k) + " starts off")
