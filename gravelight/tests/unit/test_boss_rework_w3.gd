extends GutTest
## T-233, the boss rework's Totenhafen half (docs/BOSS_REWORK.md 4.1 W3; docs/boss_rework/w3_totenhafen.md): the pure
## rules THE SLENDER and DER KIELHOLER gained: the Slender's data blocks (dread, the Mirroring step, the phase
## overrides, the whisper), the Watch's lone-in-the-dark multiplier, the trail point the Mirroring step stands on, the
## phase value lookup; the Kielholer's data blocks (dread, the dunk, the squad rule), the spring tide's quicker
## surfacing, the lone-wader rule.

var file: Dictionary
var s: Dictionary
var k: Dictionary


func before_all() -> void:
	file = GLData.table("bosses/map02")
	s = HomageEncounter.block(file, "the_slender")
	k = (file["bosses"] as Dictionary)["der_kielholer"]


# ---------------------------------------------------------------- THE SLENDER

func test_slender_data_blocks() -> void:
	var d: Dictionary = s["dread"]
	assert_almost_eq(float(d["radius"]), 24.0, 0.001, "felt from 24 m")
	assert_eq(str(d["surface"]), "cloth")
	assert_eq(str(d["step_sound"]), "", "a quiet step")
	assert_almost_eq(float(d["step_shake"]), 0.0, 0.001, "no shake")
	var mv: Dictionary = s["moves"]["mirror"]
	assert_almost_eq(float(mv["step_silence"]), 0.8, 0.001, "the step's silence is a telegraph of at least 0.5 s")
	assert_true(float(mv["step_silence"]) >= 0.5)
	assert_almost_eq(float(mv["step_delay_s"]), 1.0, 0.001, "where you stood a second ago")
	assert_true(float(mv["step_min_range"]) >= 1.5, "never on top of you")
	assert_almost_eq(float(s["watch"]["alone_dark_mult"]), 1.5, 0.001)
	var w: Dictionary = s["whisper"]
	assert_eq((w["tier_s"] as Array).size(), 5, "one interval per tier")
	assert_almost_eq(float((w["tier_s"] as Array)[0]), 0.0, 0.001, "no whisper at NONE")
	assert_gt(float((w["tier_s"] as Array)[2]), float((w["tier_s"] as Array)[4]), "closer tiers whisper more often")
	assert_true((s["lines"] as Dictionary).has("SLN_MIRROR_STEP_01"), "the step's line")
	assert_eq(str((s["lines"]["SLN_MIRROR_STEP_01"] as Dictionary)["speaker"]), "SLN")


func test_watch_alone_in_the_dark_fills_faster() -> void:
	var m: WatchMeter = WatchMeter.new(s["watch"])
	assert_almost_eq(m.rate({"pool": true, "seen": true, "dark": true, "alone": true}, 0.0, 0.0), 18.0, 0.001, "alone in the dark: the pool's +12 is +18")
	assert_almost_eq(m.rate({"pool": true, "seen": true, "dark": true, "teammate": true}, 0.0, 0.0), 8.0, 0.001, "beside a teammate: 12 - 4, no multiplier")
	assert_almost_eq(m.rate({"pool": true, "seen": true, "lit": true, "alone": true}, 0.0, 0.0), -3.0, 0.001, "alone but lit: no multiplier (12 - 15)")
	assert_almost_eq(m.rate({"seen": false, "dark": true, "alone": true}, 0.0, 0.0), -6.0, 0.001, "the drains are untouched")
	var plain: WatchMeter = WatchMeter.new({})
	assert_almost_eq(plain.rate({"pool": true, "seen": true, "dark": true, "alone": true}, 0.0, 0.0), 18.0, 0.001, "the default multiplier is 1.5")


func test_trail_point() -> void:
	var a: Vector3 = Vector3(1, 0, 0)
	var b: Vector3 = Vector3(2, 0, 0)
	var c: Vector3 = Vector3(3, 0, 0)
	var d: Vector3 = Vector3(4, 0, 0)
	var trail: Array = [[0.0, a], [0.5, b], [1.0, c], [1.5, d]]
	assert_eq(Slender.trail_point(trail, 2.0, 1.0), c, "the newest sample at least a second old")
	assert_eq(Slender.trail_point(trail, 2.0, 1.4), b)
	assert_eq(Slender.trail_point(trail, 2.0, 0.5), d)
	assert_false(Slender.trail_point(trail, 2.0, 3.0).is_finite(), "a trail too short: nowhere to stand")
	assert_false(Slender.trail_point([], 2.0, 1.0).is_finite())


func test_phase_values_escalate() -> void:
	assert_almost_eq(Slender.phase_value(s, 1, "sweep", "cooldown", 12.0), 12.0, 0.001, "phase 1: the sweep's data")
	assert_almost_eq(Slender.phase_value(s, 2, "sweep", "cooldown", 12.0), 9.0, 0.001, "Shift Change: 9 s")
	assert_almost_eq(Slender.phase_value(s, 3, "sweep", "cooldown", 12.0), 7.0, 0.001, "End of Shift: 7 s")
	assert_almost_eq(Slender.phase_value(s, 1, "mirror", "step_cooldown", 14.0), 14.0, 0.001)
	assert_almost_eq(Slender.phase_value(s, 3, "mirror", "step_cooldown", 14.0), 7.0, 0.001)
	assert_almost_eq(Slender.phase_value(s, 2, "lash", "range", 4.0), 4.0, 0.001, "the Lash keeps 4 m until End of Shift")
	assert_almost_eq(Slender.phase_value(s, 3, "lash", "range", 4.0), 5.0, 0.001, "then 5 m")
	assert_almost_eq(Slender.phase_value(s, 3, "lash", "damage", 85.0), 85.0, 0.001, "an unoverridden key: the move's own")
	assert_almost_eq(Slender.phase_value(s, 3, "nothing", "x", 2.5), 2.5, 0.001, "unknown: the default")
	assert_almost_eq(float((s["phases"]["3"] as Dictionary)["speed"]), 1.9, 0.001, "his last-round walk")
	assert_lt(float((s["phases"]["3"] as Dictionary)["speed"]), 2.5, "he never runs")
	for ph: String in ["2", "3"]:
		assert_true(float(Slender.phase_value(s, int(ph), "sweep", "cooldown", 12.0)) >= 5.0, "the sweep never machine-guns")


# ---------------------------------------------------------------- DER KIELHOLER

func test_kielholer_data_blocks() -> void:
	var d: Dictionary = k["dread"]
	assert_eq(str(d["surface"]), "iron")
	assert_eq(str(d["step_sound"]), "boss_stomp")
	assert_almost_eq(float(d["step_shake"]), 0.4, 0.001)
	var g: Dictionary = k["grab"]
	assert_almost_eq(float(g["dunk_after"]), 1.2, 0.001)
	assert_almost_eq(float(g["dunk_seconds"]), 1.0, 0.001, "a breath-holding second")
	assert_true(float(g["dunk_after"]) + float(g["dunk_seconds"]) < float(g["max_hold"]), "the dunk fits inside a hold that still breaks on its own")
	assert_almost_eq(float(g["max_hold"]), 5.0, 0.001, "max_hold unchanged (every grab breaks in solo)")
	assert_eq(int(g["break_melee"]), 4, "the mash unchanged")
	assert_almost_eq(float(k["tide_under_mult"]), 0.6, 0.001)
	assert_almost_eq(float(k["tide_ripple_mult"]), 0.75, 0.001)
	assert_almost_eq(float(k["drip_seconds"]), 10.0, 0.001)
	assert_true((k["squad"] as Dictionary).has("lone_edge_m") and (k["squad"] as Dictionary).has("lone_mate_m"), "the squad rule's data")


func test_kielholer_spring_tide_surfaces_quicker() -> void:
	assert_eq(Kielholer.under_range(k, false), Vector2(6.0, 10.0), "low tide: 6-10 s under")
	assert_eq(Kielholer.under_range(k, true), Vector2(3.6, 6.0), "a fast tide: 3.6-6 s")
	assert_almost_eq(Kielholer.ripple_for(k, false), 1.6, 0.001, "the ripple's 1.6 s")
	assert_almost_eq(Kielholer.ripple_for(k, true), 1.2, 0.001, "1.2 s on a fast tide")
	assert_almost_eq(Kielholer.ripple_for({"ripple_seconds": 1.0, "tide_ripple_mult": 0.5}, true), 1.0, 0.001, "never under the 1.0 s telegraph floor")
	assert_eq(Kielholer.under_range({}, true), Vector2(3.6, 6.0), "defaults")


func test_kielholer_lone_wader() -> void:
	var sq: Dictionary = k["squad"]
	# [distance to him, distance to a water edge, has a teammate near, in sight]
	assert_eq(Kielholer.lone_wader([[10.0, 1.0, false, true], [5.0, 8.0, false, true]], sq), 0, "the lone one at the edge over the nearer one inland")
	assert_eq(Kielholer.lone_wader([[10.0, 1.0, true, true], [5.0, 8.0, false, true]], sq), -1, "with a teammate beside them: nobody is a lone wader")
	assert_eq(Kielholer.lone_wader([[10.0, 1.0, false, false]], sq), -1, "out of sight: no")
	assert_eq(Kielholer.lone_wader([[19.0, 1.0, false, true]], sq), -1, "beyond lone_range: no")
	assert_eq(Kielholer.lone_wader([[10.0, 1.0, false, true], [6.0, 2.0, false, true]], sq), 1, "two lone waders: the nearer")
	assert_eq(Kielholer.lone_wader([], sq), -1)
