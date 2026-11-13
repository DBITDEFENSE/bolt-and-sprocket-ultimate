extends GutTest
## T-232 (docs/BOSS_REWORK.md 4.1, worker W2: Kaltenbrunn): the pure parts of PAUL's, the Foreman's and the Screamer's
## rework. The rage spike when a player runs out of his sight; the data blocks the kit and the new battle beats read
## (the dread blocks, the guard, the squad rules, the floods beat, the Foreman's Core Vent and ENRAGED lights, the
## Screamer's punch); every telegraph in the readable band; every new sound id in the manifest; the capture sets.

var paul: Dictionary
var foreman: Dictionary
var screamer: Dictionary


func before_all() -> void:
	paul = HomageEncounter.block(GLData.table("bosses/map01"), "paul")
	var e: Dictionary = GLData.table("enemies")["enemies"]
	foreman = e["foreman"]
	screamer = e["screamer"]


# ---------------------------------------------------------------- PAUL

func test_flee_break_spikes_the_meter_once() -> void:
	var r: PaulRage = PaulRage.new(paul["rage"])
	r.set_value(10.0)
	r.on_flee_break()
	assert_almost_eq(r.value, 16.0, 0.001, "running out of his sight: +6 at once")
	assert_almost_eq(float(PaulRage.defaults()["flee_break"]), 6.0, 0.001, "the default matches the data")
	assert_almost_eq(float(paul["rage"]["flee_break_every"]), 3.0, 0.001, "at most every 3 s per player")
	r.set_value(64.0)
	r.on_flee_break()
	assert_eq(r.stage, PaulRage.BERSERK, "a spike can tip him into BERSERK")


func test_paul_dread_block_and_stage_shake() -> void:
	var d: Dictionary = paul["dread"]
	assert_eq(str(d["surface"]), "flesh")
	assert_eq(str(d["step_sound"]), "boss_stomp")
	assert_almost_eq(float(d["step_shake"]), 0.45, 0.001, "Calm footfalls shake 0.45")
	assert_almost_eq(float(d["step_shake"]) + 2.0 * float(d["stage_step_shake"]), 0.85, 0.001, "BERSERK footfalls shake 0.85")
	assert_gt(float(d["radius"]), float(d["near"]))


func test_paul_guard_is_a_telegraphed_front_slam_not_a_grab() -> void:
	var g: Dictionary = paul["guard"]
	assert_gte(float(g["telegraph"]), 0.5, "the guard slam winds up at least 0.5 s")
	assert_lte(float(g["telegraph"]), 1.0, "and at most 1 s")
	assert_almost_eq(float(g["arc_deg"]), 180.0, 0.001, "a half-circle in front: the far side is for the revive")
	assert_gt(float(g["approach"]), float(g["radius"]), "he winds up before the comer is in reach")
	assert_gt(float(g["max"]), 0.0)
	assert_gt(float(g["again_after"]), float(g["cooldown"]), "after a guard ends he does not guard again at once")
	assert_false(g.has("mash"), "not a grab: nothing to break")
	assert_false(paul["moves"].has("guard"), "not in the move table (the stage gates and the move-table test are unchanged)")


func test_paul_squad_rules_keep_the_solo_grab_fair() -> void:
	var sq: Dictionary = paul["squad"]
	var grab: Dictionary = paul["moves"]["grab"]
	assert_lt(float(sq["alone_grab_max"]), float(grab["max"]), "a lone player is held shorter")
	assert_lt(int(sq["alone_grab_mash"]), int(grab["mash"]), "and breaks free sooner")
	assert_lt(float(sq["alone_cd_mult"]), 1.0, "the pressure is in the cooldowns instead")
	assert_gt(float(sq["hurt_fraction"]), 0.0)
	assert_lt(float(sq["hurt_fraction"]), 0.5)


func test_paul_floods_beat_dims_and_restores() -> void:
	var fl: Dictionary = paul["floods"]
	assert_lt(float(fl["level"]), 0.3, "the yard's floods die (not just dim)")
	assert_gt(float(fl["level"]), 0.0, "never to pure black")
	assert_gt(float(fl["restore_s"]), 0.0)
	assert_gt(float(fl["again_s"]), float(fl["flicker_s"]))


# ---------------------------------------------------------------- THE FOREMAN

func test_foreman_dread_block_is_iron() -> void:
	var d: Dictionary = foreman["dread"]
	assert_eq(str(d["surface"]), "iron")
	assert_eq(str(d["step_sound"]), "boss_stomp")
	assert_gt(float(d["step_shake"]), 0.0)


func test_foreman_vent_is_readable_and_a_window() -> void:
	var v: Dictionary = foreman["vent"]
	assert_gte(float(v["windup"]), 0.5, "the vent winds up at least 0.5 s")
	assert_lte(float(v["windup"]), 1.0)
	assert_gt(float(v["core_mult"]), float(foreman["weakpoint_mult"]), "the core takes more while it flares: the window")
	assert_gt(float(v["cooldown"]), float(foreman["slam"]["cooldown"]), "rarer than the slam")
	assert_lte(float(v["damage"]), float(foreman["jab"]["damage"]), "the hurt is the slow and the dread, not the number")


func test_foreman_enraged_lights_follow_him() -> void:
	var el: Dictionary = foreman["enrage_lights"]
	assert_lt(float(el["level"]), 0.2, "the gallery lamps go out")
	assert_gt(float(el["follow_m"]), 0.0)
	assert_lt(float(el["follow_m"]), float(el["radius"]), "re-captured before he walks out of the dark")
	var ar: Dictionary = foreman["arrival"]
	assert_gt(float(ar["light_back_s"]), 0.0, "the arrival's light drop comes back")


func test_foreman_squad_rules() -> void:
	var sq: Dictionary = foreman["squad"]
	assert_true(bool(sq["alone_whip_any_side"]))
	assert_lt(float(sq["hurt_fraction"]), 0.5)
	assert_gt(float(sq["hurt_shout_every"]), 5.0, "the cadence is not a loop")


# ---------------------------------------------------------------- the Screamer

func test_screamer_effects_data() -> void:
	assert_gt(float(screamer["scream_punch"]), 0.0)
	assert_lte(float(screamer["scream_punch"]), 1.0)
	assert_gt(float(screamer["throat_pulse_hz"]), 0.0)
	assert_almost_eq(float(screamer["windup"]), 1.5, 0.001, "the wind-up is unchanged (effects only)")


# ---------------------------------------------------------------- sounds and cameras

func test_every_sound_the_rework_plays_is_in_the_manifest() -> void:
	var sounds: Dictionary = (GLData.load_json("res://data/gravelight/audio.json") as Dictionary).get("sounds", {})
	for k: String in ["paul_roar", "paul_plate_grind", "paul_bottle_break", "boss_breath", "boss_roar_low", "boss_stomp", "boss_bone_crack",
			"boss_hit_glass", "boss_hit_iron", "boss_weakpoint_hit", "boss_telegraph_rise", "foreman_drill_spin", "foreman_chain_whip",
			"foreman_drill", "foreman_chain", "foreman_step", "foreman_roar", "screamer_scream", "screamer_hum"]:
		assert_true(sounds.has(k), k + " is in audio.json")


func test_capture_sets_pose_the_two_bosses() -> void:
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/capture_cams.json") as Dictionary
	var sets: Dictionary = cfg["sets"]
	for s: String in ["u14_paul", "u14_foreman"]:
		assert_true(sets.has(s), s + " exists")
		assert_eq(str(sets[s]["map"]), "res://gravelight/maps/map01_kaltenbrunn/map01.tscn")
		assert_gte((sets[s]["cams"] as Array).size(), 4)
	var first_f: Dictionary = (sets["u14_foreman"]["cams"] as Array)[0]
	var has_boss_op: bool = false
	for op: Variant in first_f["do"]:
		if str(op).begins_with("boss:foreman"):
			has_boss_op = true
	assert_true(has_boss_op, "the Foreman is posed by the CaptureDo boss op")
	var first_p: Dictionary = (sets["u14_paul"]["cams"] as Array)[0]
	var has_pose: bool = false
	for op2: Variant in first_p["do"]:
		if str(op2).begins_with("callv:PaulEncounter:pose"):
			has_pose = true
	assert_true(has_pose, "PAUL is posed through his encounter (the boss op returns the director)")
