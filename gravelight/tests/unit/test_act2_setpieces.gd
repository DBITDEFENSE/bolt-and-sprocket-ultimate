extends GutTest
## UPDATE 10 §3 (T-156): the pure rules of der Kranich's new set-pieces: the tilt maths (KranichTilt), the
## decompression's suction volume (DecompressionBreach), the wing walk's clip state machine and deck test (WingWalk),
## the discount token's price, and the act's data for them (map04b.json flight).

const DATA: String = "res://data/gravelight/map04b.json"


func _flight() -> Dictionary:
	return (GLData.load_json(DATA) as Dictionary).get("flight", {})


# ---------------------------------------------------------------- the tilt

func test_tilt_angle_eases_in_holds_and_eases_out() -> void:
	assert_eq(KranichTilt.angle_at(0.0, 6.0, 8.0), 0.0, "level at the start")
	assert_almost_eq(KranichTilt.angle_at(3.0, 6.0, 8.0), 8.0, 0.001, "the full tilt in the middle")
	assert_true(KranichTilt.angle_at(0.4, 6.0, 8.0) > 0.0 and KranichTilt.angle_at(0.4, 6.0, 8.0) < 8.0, "easing in")
	assert_true(KranichTilt.angle_at(5.6, 6.0, 8.0) < 8.0, "easing out")
	assert_eq(KranichTilt.angle_at(6.0, 6.0, 8.0), 0.0, "level at the end")
	assert_eq(KranichTilt.angle_at(9.0, 6.0, 8.0), 0.0, "and after")


func test_roll_and_downhill_share_the_banks_convention() -> void:
	assert_eq(KranichTilt.downhill(1.0), Vector3(1, 0, 0))
	assert_eq(KranichTilt.downhill(-1.0), Vector3(-1, 0, 0))
	assert_eq(KranichTilt.roll_for(1.0, 8.0), -8.0, "starboard down rolls the camera like the bank did")
	assert_eq(KranichTilt.roll_for(-1.0, 8.0), 8.0)


func test_a_loose_body_needs_the_slope_to_beat_its_static_friction() -> void:
	# 8 degrees: g sin = 1.365 m/s²
	assert_eq(KranichTilt.slide_step(0.0, 1.0, 2.0, 0.7, 0.4, 0.1), 0.0, "2 degrees cannot move a crate")
	assert_gt(KranichTilt.slide_step(0.0, 1.0, 8.0, 0.7, 0.4, 0.1), 0.0, "8 degrees can, downhill")
	assert_lt(KranichTilt.slide_step(0.0, -1.0, 8.0, 0.7, 0.4, 0.1), 0.0, "the other way on the other side")


func test_friction_brakes_a_slide_to_a_stop_once_level() -> void:
	var v: float = 2.0
	for i: int in 400:   # 2 m/s at 0.45 m/s² stops in under 4.5 s
		v = KranichTilt.slide_step(v, 1.0, 0.0, 0.7, 0.45, 1.0 / 60.0)
	assert_eq(v, 0.0, "level deck: the crate stops")
	assert_eq(KranichTilt.slide_step(5.0, 1.0, 8.0, 0.0, 0.0, 10.0, 7.0), 7.0, "capped at max speed")


func test_slide_accel_and_zombie_slide_scale_with_the_angle() -> void:
	assert_eq(KranichTilt.slide_accel(1.0, 0.7, 0.4, false), 0.0)
	assert_almost_eq(KranichTilt.slide_accel(8.0, 0.0, 0.0, true), 9.81 * sin(deg_to_rad(8.0)), 0.001)
	assert_eq(KranichTilt.zombie_slide_mps(8.0, 8.0, 5.0), 5.0)
	assert_eq(KranichTilt.zombie_slide_mps(4.0, 8.0, 5.0), 2.5)
	assert_eq(KranichTilt.zombie_slide_mps(4.0, 0.0, 5.0), 0.0, "no division by a zero tilt")


func test_wall_impact_needs_speed_a_stop_and_a_wall() -> void:
	assert_true(KranichTilt.is_wall_impact(5.0, 0.1, 1.25, 0.4, 2.5), "fast, stopped, a wall ahead: impact")
	assert_false(KranichTilt.is_wall_impact(5.0, 1.2, 1.25, 0.4, 2.5), "still moving: no impact")
	assert_false(KranichTilt.is_wall_impact(5.0, 0.1, 1.25, -1.0, 2.5), "no wall: no impact")
	assert_false(KranichTilt.is_wall_impact(1.0, 0.0, 0.25, 0.3, 2.5), "leaning on the wall at the start: no impact")
	assert_eq(KranichTilt.impact_damage(1000.0, 0.6), 600.0)
	assert_eq(KranichTilt.impact_damage(10.0, 0.0), 1.0, "at least a point")


func test_a_rolling_casing_hits_only_what_is_in_its_path() -> void:
	assert_true(KranichTilt.bomb_hits(Vector3(2, 0, 9), 2.0, Vector3(2.8, 0, 9.2), 1.0))
	assert_false(KranichTilt.bomb_hits(Vector3(2, 0, 9), 0.5, Vector3(2.8, 0, 9.2), 1.0), "a casing at rest kills nothing")
	assert_false(KranichTilt.bomb_hits(Vector3(2, 0, 9), 2.0, Vector3(4.0, 0, 9.0), 1.0), "two metres off")
	assert_false(KranichTilt.bomb_hits(Vector3(2, 0, 9), 2.0, Vector3(2.5, 3.4, 9.0), 1.0), "not the wing walk above it")


func test_the_flight_clock_gives_two_or_three_ordered_tilts() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var tilt: Dictionary = _flight().get("turbulence_tilt", {})
	for s: int in [1, 2, 3, 99]:
		rng.seed = s
		var pr: Array = tilt["per_round"]
		var n: int = rng.randi_range(int(pr[0]), int(pr[1]))
		var t: Array[float] = KranichTilt.schedule(n, tilt["first_s"], tilt["gap_s"], rng)
		assert_true(t.size() >= 2 and t.size() <= 3, "2-3 per round")
		assert_true(t[0] >= float(tilt["first_s"][0]) - 0.001, "not before first_s")
		for i: int in range(1, t.size()):
			assert_gt(t[i], t[i - 1] + float(tilt["gap_s"][0]) - 0.001, "spaced by gap_s")
		assert_true(t[0] > float(tilt["warn_seconds"]), "there is room for the 3 s warning")


func test_tilt_data_is_the_contract() -> void:
	var tilt: Dictionary = _flight().get("turbulence_tilt", {})
	assert_eq(float(tilt["tilt_deg"]), 8.0, "±8°")
	assert_eq(float(tilt["seconds"]), 6.0, "for 6 s")
	assert_eq(float(tilt["warn_seconds"]), 3.0, "telegraphed 3 s ahead")
	assert_lt(float(tilt["player_push_mps"]), float(tilt["zombie_slide_mps"]), "players slide less than the dead")
	var kinds: Dictionary = {}
	for s: Dictionary in tilt["sliders"]:
		kinds[str(s["kind"])] = true
	assert_true(kinds.has("bomb") and kinds.has("crate"), "loose bombs and crates")


# ---------------------------------------------------------------- decompression

func test_suction_pulls_toward_the_breach_inside_the_radius() -> void:
	var hole: Vector3 = Vector3(0, 1, 0)
	var v: Vector3 = DecompressionBreach.pull_for(hole, Vector3(0, 0, 4), 9.0, 6.0)
	assert_lt(v.z, 0.0, "toward the hole")
	assert_eq(v.y, 0.0, "flat")
	assert_eq(DecompressionBreach.pull_for(hole, Vector3(0, 0, 12), 9.0, 6.0), Vector3.ZERO, "outside the radius: nothing")
	assert_gt(DecompressionBreach.pull_for(hole, Vector3(0, 0, 2), 9.0, 6.0).length(), DecompressionBreach.pull_for(hole, Vector3(0, 0, 8), 9.0, 6.0).length(), "stronger near the hole")
	assert_true(DecompressionBreach.at_edge(hole, Vector3(0.5, 0, 1.0), 1.4))
	assert_false(DecompressionBreach.at_edge(hole, Vector3(0, 0, 3.0), 1.4))


func test_decompression_data_two_per_act_at_the_bay_and_the_starboard_crawlway() -> void:
	var dc: Dictionary = _flight().get("decompression", {})
	var evs: Array = dc.get("events", [])
	assert_eq(evs.size(), 2, "two per act")
	var where: Array = evs.map(func(e: Dictionary) -> String: return str(e["breach"]))
	assert_true(where.has("DecompBay") and where.has("DecompStarboard"))
	assert_eq(float(dc["seconds"]), 4.0, "a 4 s suction")
	assert_eq(float(dc["warn_s"]), 3.0, "telegraphed 3 s ahead")
	assert_eq(int(dc["ammo_out"]), 2, "two ammo boxes' worth")
	for e: Dictionary in evs:
		var ar: int = int(e["act_round"])
		assert_true(ar != 3, "never in the London window's round")


# ---------------------------------------------------------------- the wing walk

func test_clip_state_machine() -> void:
	var OFF: int = WingWalk.ClipState.OFF_WING
	var UN: int = WingWalk.ClipState.UNCLIPPED
	var CL: int = WingWalk.ClipState.CLIPPED
	assert_eq(WingWalk.next_state(OFF, "deck"), [UN, false], "on the deck: unclipped")
	assert_eq(WingWalk.next_state(OFF, "deck", true), [CL, false], "a bot is never unclipped")
	assert_eq(WingWalk.next_state(UN, "clip"), [CL, false], "a clip point's hold clips you in")
	assert_eq(WingWalk.next_state(UN, "turbulence"), [OFF, true], "turbulence throws the unclipped off")
	assert_eq(WingWalk.next_state(CL, "turbulence"), [CL, false], "the clipped stay")
	assert_eq(WingWalk.next_state(UN, "turbulence", true), [UN, false], "a bot is never thrown")
	assert_eq(WingWalk.next_state(CL, "leave"), [OFF, false], "climbing in unclips")
	assert_eq(WingWalk.next_state(OFF, "clip"), [OFF, false], "no clipping in from inside")
	assert_eq(WingWalk.next_state(OFF, "turbulence"), [OFF, false], "nobody inside is thrown")


func test_on_deck_follows_the_segments_and_the_height() -> void:
	var ww: Dictionary = _flight().get("wing_walk", {})
	var segs: Array = ww["segments"]
	var dy: float = float(ww["deck_y"])
	assert_true(WingWalk.on_deck(segs, dy, WingWalk.v3(ww["landing"])), "the landing is on the deck")
	assert_true(WingWalk.on_deck(segs, dy, WingWalk.v3(ww["chest"])), "the wingtip locker is on the deck")
	for cp: Array in ww["clip_points"]:
		assert_true(WingWalk.on_deck(segs, dy, WingWalk.v3(cp)), "tether post %s is on the deck" % str(cp))
	assert_false(WingWalk.on_deck(segs, dy, Vector3(-40, 0, 40)), "the crawlway below is not")
	assert_false(WingWalk.on_deck(segs, dy, Vector3(-90, 3.4, 30)), "off the catwalk is not")
	assert_true(WingWalk.in_rect([[-2, -2], [2, 2]], 2.2, 0, 0.3))
	assert_false(WingWalk.in_rect([[-2, -2], [2, 2]], 2.5, 0, 0.3))


func test_wing_walk_data_is_the_contract() -> void:
	var ww: Dictionary = _flight().get("wing_walk", {})
	assert_eq(float(ww["clip_hold"]), 1.0, "a 1 s hold clips in")
	assert_true(ww["clip_points"].size() >= 5, "tether posts all along")
	assert_true(int(ww["opens_act_round"]) >= 1)
	assert_gt(float(ww["deck_y"]), 3.3, "above the closets' roofs (3.3 m)")
	# no two tether posts more than 14 m apart along the walk, so a warning gives time to reach one
	var pts: Array = ww["clip_points"]
	for i: int in range(1, pts.size()):
		assert_lt(WingWalk.v3(pts[i]).distance_to(WingWalk.v3(pts[i - 1])), 14.0, "post %d to %d" % [i - 1, i])


func test_discount_token_halves_the_next_tier() -> void:
	assert_eq(PerkManager.discounted(4000, 0.5), 2000)
	assert_eq(PerkManager.discounted(3500, 0.5), 1750)
	assert_eq(PerkManager.discounted(1001, 0.5), 500, "rounded down")
	PerkManager.discount_tokens.clear()
	var full: int = PerkManager.tier_price(&"ironhide_stout", 2)
	assert_eq(PerkManager.tier_price_for(7, &"ironhide_stout", 2), full)
	PerkManager.grant_discount_token(7)
	assert_eq(PerkManager.tier_price_for(7, &"ironhide_stout", 2), full / 2)
	PerkManager.use_discount_token(7)
	assert_eq(PerkManager.tier_price_for(7, &"ironhide_stout", 2), full, "one tier only")
	PerkManager.discount_tokens.clear()
