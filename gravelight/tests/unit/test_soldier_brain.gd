extends GutTest
## T-142: the relief-squad soldier's brain, its pure decision functions (SoldierBrain).


func _s(over: Dictionary = {}) -> Dictionary:
	var s: Dictionary = {"leaving": false, "hp_frac": 1.0, "retreat_frac": 0.3, "mate_down_d": INF, "revives_left": 1,
		"threat_near": 0, "has_target": false}
	s.merge(over, true)
	return s


func test_decide_priorities() -> void:
	assert_eq(SoldierBrain.decide(_s()), &"follow")
	assert_eq(SoldierBrain.decide(_s({"has_target": true})), &"fight")
	assert_eq(SoldierBrain.decide(_s({"has_target": true, "mate_down_d": 8.0})), &"revive", "a mate down beats a target")
	assert_eq(SoldierBrain.decide(_s({"has_target": true, "mate_down_d": 8.0, "hp_frac": 0.2})), &"retreat", "under 30%: retreat first")
	assert_eq(SoldierBrain.decide(_s({"leaving": true, "hp_frac": 0.1})), &"leave", "pulling out beats everything")


func test_retreat_threshold() -> void:
	assert_eq(SoldierBrain.decide(_s({"hp_frac": 0.31, "has_target": true})), &"fight")
	assert_eq(SoldierBrain.decide(_s({"hp_frac": 0.29, "has_target": true})), &"retreat")


func test_revive_once_and_only_when_safe() -> void:
	assert_true(SoldierBrain.can_revive(10.0, 1, 0))
	assert_false(SoldierBrain.can_revive(10.0, 0, 0), "one revive each")
	assert_false(SoldierBrain.can_revive(25.0, 1, 0), "too far")
	assert_false(SoldierBrain.can_revive(10.0, 1, 3), "too many zombies close")


func test_hold_point_band_and_side() -> void:
	var anchor: Vector3 = Vector3(10, 0, 10)
	var from: Vector3 = Vector3(10, 0, 40)
	for n: int in [1, 3, 6]:
		for i: int in n:
			var p: Vector3 = SoldierBrain.hold_point(anchor, from, i, n, 6.0, 12.0)
			var d: float = Vector2(p.x - anchor.x, p.z - anchor.z).length()
			assert_between(d, 6.0, 12.0, "soldier %d/%d holds 6-12 m from the player" % [i, n])
			assert_gt((p - anchor).dot(from - anchor), 0.0, "on the squad's side of the player")
	assert_eq(SoldierBrain.hold_point(anchor, from, 2, 5, 6.0, 12.0), SoldierBrain.hold_point(anchor, from, 2, 5, 6.0, 12.0), "deterministic")
	assert_true(SoldierBrain.in_hold_band(9.0, 6.0, 12.0))
	assert_false(SoldierBrain.in_hold_band(3.0, 6.0, 12.0))
	assert_false(SoldierBrain.in_hold_band(20.0, 6.0, 12.0))


func test_retreat_point_moves_away() -> void:
	var me: Vector3 = Vector3(0, 0, 0)
	var threat: Vector3 = Vector3(0, 0, -5)
	var anchor: Vector3 = Vector3(10, 0, 0)
	var r: Vector3 = SoldierBrain.retreat_point(me, threat, anchor)
	assert_gt(r.distance_to(threat), me.distance_to(threat), "further from the threats")
	assert_almost_eq(r.distance_to(me), 6.0, 0.01)


func test_target_score() -> void:
	var t: Dictionary = GLData.load_json("res://data/gravelight/ai/combat.json").get("threat", {})
	assert_eq(SoldierBrain.target_score(50.0, &"walk", false, 1.0, false, 40.0, t), 0.0, "beyond the weapon's range")
	var near: float = SoldierBrain.target_score(4.0, &"walk", false, 1.0, false, 40.0, t)
	var far: float = SoldierBrain.target_score(25.0, &"walk", false, 1.0, false, 40.0, t)
	assert_gt(near, far, "closer is more dangerous")
	assert_gt(far, 0.0, "a far zombie still scores (the far term)")
	assert_gt(SoldierBrain.target_score(4.0, &"walk", false, 1.0, true, 40.0, t), near, "one going for me scores higher")
	assert_gt(SoldierBrain.target_score(4.0, &"sprint", false, 1.0, false, 40.0, t), near, "a sprinter scores higher")


func test_pick_target_only_visible() -> void:
	assert_eq(SoldierBrain.pick_target([]), -1)
	assert_eq(SoldierBrain.pick_target([{"score": 5.0, "visible": false}, {"score": 1.0, "visible": true}]), 1)
	assert_eq(SoldierBrain.pick_target([{"score": 0.5, "visible": true}, {"score": 1.0, "visible": true}]), 1)
	assert_eq(SoldierBrain.pick_target([{"score": 0.0, "visible": true}]), -1, "a zero score is no target")


func test_aim_error_settles() -> void:
	var e0: float = SoldierBrain.aim_error_deg(0.0, 6.0, 1.3, 0.5, 1.0)
	var e1: float = SoldierBrain.aim_error_deg(0.5, 6.0, 1.3, 0.5, 1.0)
	var e9: float = SoldierBrain.aim_error_deg(9.0, 6.0, 1.3, 0.5, 1.0)
	assert_almost_eq(e0, 6.0, 0.001)
	assert_lt(e1, e0)
	assert_almost_eq(e9, 1.3, 0.01, "settles to settle_error_deg")
	assert_lt(SoldierBrain.aim_error_deg(0.0, 6.0, 1.3, 0.5, 1.2), e0, "a better shot (aim_mult) misses less")


func test_shot_interval_cap() -> void:
	assert_almost_eq(SoldierBrain.shot_interval(60.0), 1.0, 0.001)
	assert_almost_eq(SoldierBrain.shot_interval(1000.0), 60.0 / 720.0, 0.001, "a PPSh is capped")
