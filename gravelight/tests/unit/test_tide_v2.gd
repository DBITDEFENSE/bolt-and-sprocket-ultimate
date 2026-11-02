extends GutTest
## Tide v2 (UPDATE 10 contract C2, DECISIONS T-153): the stage schedule (spring every 9th round, high every 3rd, half
## the round before a high one), the stage heights, the holds and the Pumpenschalter crank's maths, the storm values
## per stage, the floating power-ups' drift and the data block's sanity.

var t: Dictionary


func before_all() -> void:
	t = GLData.load_json("res://data/gravelight/map02.json")["tide"]


func test_stage_schedule() -> void:
	assert_eq(TideController.stage_for_round(1, t), &"low", "round 1 is low water")
	assert_eq(TideController.stage_for_round(2, t), &"half", "round 2: half tide before the first high one")
	assert_eq(TideController.stage_for_round(3, t), &"high", "round 3: high tide")
	assert_eq(TideController.stage_for_round(4, t), &"low", "round 4: low")
	assert_eq(TideController.stage_for_round(8, t), &"half", "round 8: half (a spring follows)")
	assert_eq(TideController.stage_for_round(9, t), &"spring", "round 9: the first spring tide")
	assert_eq(TideController.stage_for_round(18, t), &"spring", "round 18: spring")
	assert_eq(TideController.stage_for_round(21, t), &"high", "round 21: high, not spring")
	assert_eq(TideController.stage_for_round(27, t), &"spring", "round 27: spring")
	var springs: int = 0
	for r: int in range(1, 46):
		if TideController.is_spring_round(r, t):
			springs += 1
			assert_true(TideController.is_high_round(r, t), "a spring round %d is also a flood round (the v1 rule)" % r)
	assert_eq(springs, 5, "five spring tides in 45 rounds (9, 18, 27, 36, 45)")
	assert_eq(TideController.next_spring(10, t), 18, "after round 9 the next spring is 18")
	assert_eq(TideController.next_spring(1, t), 9, "the first spring is 9")


func test_v1_rules_kept() -> void:
	assert_true(TideController.is_high_round(33, t) and TideController.is_high_round(36, t), "33 and 36 flood")
	assert_false(TideController.is_high_round(34, t), "34 does not")
	assert_true(TideController.warns_next(32, t) and not TideController.warns_next(33, t), "the forecast at 32")


func test_stage_heights_rise() -> void:
	var low: float = float(t["low_y"])
	var half: float = TideController.stage_y(&"half", t)
	var high: float = TideController.stage_y(&"high", t)
	var spring: float = TideController.stage_y(&"spring", t)
	assert_eq(TideController.stage_y(&"low", t), low, "low is low_y")
	assert_true(low < half and half < high and high < spring, "low < half < high < spring (%.1f %.1f %.1f %.1f)" % [low, half, high, spring])
	assert_almost_eq(high, float(t["high_y"]), 0.001, "the high stage matches the v1 high_y")
	assert_lt(half, float(t["wade_min_y"]), "the half tide stays under the wading line (it only fills the basins)")
	assert_gt(float(t["spring_sheet_y"]), 0.0, "the spring sheet stands over the apron floor (y 0)")


func test_holds_and_crank_maths() -> void:
	var pc: Dictionary = t["pump_crank"]
	assert_eq(float(pc["seconds"]), 30.0, "the crank is a 30 s holdout")
	assert_eq(float(pc["spawn_mult"]), 2.0, "under x2 spawns")
	assert_eq(float(pc["shortens_by_s"]), 40.0, "and takes 40 s off the flood")
	assert_gt(TideController.hold_for(&"spring", t), TideController.hold_for(&"high", t), "a spring tide holds longer")
	assert_eq(TideController.hold_for(&"low", t), 0.0, "low water has no hold")
	assert_eq(TideController.after_crank(150.0, t), 110.0, "150 s left -> 110 s after one crank")
	assert_eq(TideController.after_crank(25.0, t), 0.0, "never below zero: the water falls")
	var left: float = TideController.hold_for(&"spring", t)
	var cranks: int = 0
	while left > 0.0:
		left = TideController.after_crank(left, t)
		cranks += 1
	assert_eq(cranks, int(ceil(TideController.hold_for(&"spring", t) / 40.0)), "cranks to drain a spring tide's hold")


func test_storm_scales_with_stage() -> void:
	var prev: Dictionary = TideController.storm_for(&"low", t)
	for s: StringName in [&"half", &"high", &"spring"]:
		var cur: Dictionary = TideController.storm_for(s, t)
		assert_gt(float(cur["spray"]), float(prev["spray"]), "spray rises at %s" % s)
		assert_gt(float(cur["wave_height"]), float(prev["wave_height"]), "waves rise at %s" % s)
		if float(prev["lightning_interval"]) > 0.0:
			assert_lt(float(cur["lightning_interval"]), float(prev["lightning_interval"]), "lightning comes faster at %s" % s)
		prev = cur


func test_drift_and_boxes() -> void:
	var boxes: Array[AABB] = TideController.boxes_from(t["flood_boxes"])
	var spring: Array[AABB] = TideController.boxes_from(t["spring_flood_boxes"])
	assert_eq((t["float_drift"] as Array).size(), boxes.size() + spring.size(), "one drift direction per flood box")
	var b: AABB = spring[0]   # the north apron, drifting south into the docks
	var start: Vector3 = Vector3(10.0, 0.0, 34.0)
	var r1: Dictionary = TideController.drift_result(start, b, Vector3(0, 0, 1), float(t["drift_mps"]), 2.0)
	assert_false(bool(r1["lost"]), "after 2 s a drop is still on the apron")
	var r2: Dictionary = TideController.drift_result(start, b, Vector3(0, 0, 1), float(t["drift_mps"]), 20.0)
	assert_true(bool(r2["lost"]), "after 20 s it has drifted off the dock edge")
	# the piers stay dry islands: no spring box covers a pier's middle
	for pier: Vector3 in [Vector3(-17, 0.1, 60), Vector3(-3, 0.1, 60), Vector3(17, 0.1, 60)]:
		for sb: AABB in spring:
			assert_false(sb.has_point(pier), "pier at %s is not flooded by the spring tide" % pier)


func test_cables_data() -> void:
	var ids: Dictionary = {}
	for c: Variant in t["cables"]:
		var cd: Dictionary = c
		assert_false(ids.has(cd["id"]), "cable ids are unique")
		ids[cd["id"]] = true
		assert_gt(float(cd["radius_m"]), 0.0, "a cable has a reach")
		assert_gt(float(cd["stun_s"]), 0.0, "a cable stuns")
	assert_gte(ids.size(), 3, "at least three sparking cables")
	assert_gt(float(t["player_dps"]), 0.0, "players are hurt by a live cable")
