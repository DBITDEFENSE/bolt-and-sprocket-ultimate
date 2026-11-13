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


# ---- the review fixes (2026-11-11): lights, kinds, ids, feedback kinds

func _kit_with_lamps(n: int) -> Array:
	var room: Node3D = Node3D.new()
	add_child_autofree(room)
	var boss: Node3D = Node3D.new()
	room.add_child(boss)
	var lamps: Array = []
	for i: int in n:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_energy = 2.0
		room.add_child(l)
		l.position = Vector3(float(i), 0, 0)
		lamps.append(l)
	return [BossFx.make(boss, {}), lamps, boss]


func test_restore_eases_and_a_dim_during_it_keeps_the_true_base() -> void:
	var k: Array = _kit_with_lamps(2)
	var fx: BossFx = k[0]
	var lamp: OmniLight3D = k[1][0]
	fx.lights_dim(Vector3.ZERO, 10.0, 0.25, 0.05)
	await wait_seconds(0.2)
	assert_almost_eq(lamp.light_energy, 0.5, 0.02, "dimmed to a quarter")
	fx.lights_restore(0.6)
	await wait_seconds(0.3)
	assert_gt(lamp.light_energy, 0.55, "the restore eases (it used to sit dark and snap at the end)")
	assert_lt(lamp.light_energy, 1.95, "and is not there yet")
	fx.lights_dim(Vector3.ZERO, 10.0, 0.5, 0.05)   # a phase change inside the restore
	await wait_seconds(0.2)
	assert_almost_eq(lamp.light_energy, 1.0, 0.03, "half of the TRUE base, not of the dimmed value")
	fx.lights_restore(0.05)
	await wait_seconds(0.25)
	assert_almost_eq(lamp.light_energy, 2.0, 0.001, "back at base")
	assert_eq(fx.dimmed_count(), 0, "and forgotten")


func test_a_boss_freed_while_dimmed_gives_the_lamps_back() -> void:
	var k: Array = _kit_with_lamps(1)
	var fx: BossFx = k[0]
	var lamp: OmniLight3D = k[1][0]
	fx.lights_dim(Vector3.ZERO, 10.0, 0.3, 0.05)
	await wait_seconds(0.2)
	fx.lights_restore(1.5)          # HomageBoss._vanish: the restore, then the boss is freed in the same call
	(k[2] as Node3D).queue_free()
	await wait_seconds(1.9)
	assert_almost_eq(lamp.light_energy, 2.0, 0.001, "the tree eased it back after the kit was freed")


func test_flicker_ends_on_the_plain_level() -> void:
	var k: Array = _kit_with_lamps(3)
	var fx: BossFx = k[0]
	fx.lights_dim(Vector3.ZERO, 10.0, 0.8, 0.05)
	await wait_seconds(0.2)
	fx.lights_flicker(0.3, 1.0)
	await wait_seconds(0.6)
	for l: OmniLight3D in k[1]:
		assert_almost_eq(l.light_energy, 1.6, 0.001, "base x level once the gutter stops")
	fx.lights_restore(0.05)
	await wait_seconds(0.2)


func test_two_bosses_on_one_lamp_share_its_true_base() -> void:
	var k: Array = _kit_with_lamps(1)
	var a: BossFx = k[0]
	var lamp: OmniLight3D = k[1][0]
	var boss_b: Node3D = Node3D.new()
	(k[2] as Node3D).get_parent().add_child(boss_b)
	var b: BossFx = BossFx.make(boss_b, {})
	a.lights_dim(Vector3.ZERO, 10.0, 0.25, 0.05)
	await wait_seconds(0.2)
	b.lights_dim(Vector3.ZERO, 10.0, 0.5, 0.05)   # captures a lamp another boss holds at a quarter
	await wait_seconds(0.2)
	assert_almost_eq(lamp.light_energy, 1.0, 0.03, "half of 2.0, not half of 0.5")
	a.lights_restore(0.05)
	await wait_seconds(0.2)
	assert_almost_eq(lamp.light_energy, 1.0, 0.03, "the first lets go: the second still holds it down")
	b.lights_restore(0.05)
	await wait_seconds(0.2)
	assert_almost_eq(lamp.light_energy, 2.0, 0.001, "the last holder gives it back whole")


func test_a_freed_lamp_does_not_trip_the_fade_or_the_gutter() -> void:
	var k: Array = _kit_with_lamps(2)
	var fx: BossFx = k[0]
	fx.lights_dim(Vector3.ZERO, 10.0, 0.5, 0.3)
	(k[1][0] as Node).free()
	fx.lights_flicker(0.2, 0.8)
	await wait_seconds(0.5)
	fx.lights_restore(0.05)
	await wait_seconds(0.2)
	assert_almost_eq((k[1][1] as OmniLight3D).light_energy, 2.0, 0.001, "the lamp that is left is whole")


func test_unknown_kind_is_dust_not_an_error() -> void:
	var holder: Node3D = Node3D.new()
	add_child_autofree(holder)
	var e: GPUParticles3D = BossFx.emitter("ember", holder)   # a typo for embers
	assert_not_null(e, "builds")
	assert_eq(str(e.name), "Fx_dust", "as dust")
	assert_same(BossFx.emitter("dust", holder).process_material, e.process_material, "the process material is shared per kind and scale")


func test_hit_kind_respects_the_gore_setting() -> void:
	assert_eq(BossFx.hit_kind("flesh", true), "mist", "gore full: blood")
	assert_eq(BossFx.hit_kind("flesh", false), "dust", "gore reduced or off: no blood")
	assert_eq(BossFx.hit_kind("iron", false), "sparks", "other surfaces as they were")
	assert_eq(BossFx.hit_kind("nonsense", false), "dust")


func test_two_bosses_of_one_kind_report_apart() -> void:
	var a: Array = _kit_with_lamps(0)
	var b: Array = _kit_with_lamps(0)
	(a[0] as BossFx).dread_id = &"hammer"
	(b[0] as BossFx).dread_id = &"hammer"
	assert_ne((a[0] as BossFx).report_id(), (b[0] as BossFx).report_id(), "same boss key, two reporters")
	var d: DreadFx = DreadFx.new()
	d.report((a[0] as BossFx).report_id(), 0.9, false)
	d.report((b[0] as BossFx).report_id(), 0.2, false)
	assert_almost_eq(float(d.target_level()[0]), 0.9, 0.001, "the near one is not overwritten by the far one")
	d.release((b[0] as BossFx).report_id())
	assert_almost_eq(float(d.target_level()[0]), 0.9, 0.001, "nor released by it")
	d.free()


func test_burns_and_world_damage_are_not_hits() -> void:
	assert_false(HomageBoss.hit_feedback_kind(&"fire"))
	assert_false(HomageBoss.hit_feedback_kind(&"world"))
	assert_true(HomageBoss.hit_feedback_kind(&"bullet"))
	assert_true(HomageBoss.hit_feedback_kind(&"melee"))
	assert_true(HomageBoss.hit_feedback_kind(&"explosive"))
