extends GutTest
## T-077: the survivors upstairs at the Crossroads Inn (InnSurvivors, map00_survivors.json): the data, the shot,
## swipe, lure and rise rules, and the survivor node's prompts before and after the stair door.


func _cfg() -> Dictionary:
	return InnSurvivors.load_cfg()


func test_data() -> void:
	var c: Dictionary = _cfg()
	assert_false(c.is_empty(), "map00_survivors.json loads")
	assert_eq(str(c["map"]), "map00_crossroads")
	assert_eq(str(c["reveal_door"]), "door_upstairs", "the stair door reveals them")
	var ss: Array = c["survivors"]
	assert_between(ss.size(), 2, 3, "2-3 survivors")
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	assert_true(weapons.has(str(c["arm"]["weapon"])), "the arming weapon is a real weapon")
	assert_gt(int(c["arm"]["cost"]), 0, "arming costs Scrip")
	var cast: Dictionary = GLData.load_json("res://data/gravelight/vo/voice_cast.json")["cast"]
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for r: Dictionary in ss:
		assert_true(str(r["name"]).contains(" "), "%s has a full name" % r["id"])
		assert_gt(str(r.get("role", "")).length(), 20, "%s has a backstory" % r["id"])
		assert_true(cast.has(str(r["speaker"])), "%s is cast (%s)" % [r["id"], r["speaker"]])
		if cast.has(str(r["speaker"])):
			assert_true(str(cast[str(r["speaker"])]["accent"]).begins_with("german"), "%s speaks with a German accent" % r["id"])
		for kind: String in ["reveal", "scared", "flinch", "armed", "fight", "hurt", "downed", "death"]:
			var pool: Array = (r["lines"] as Dictionary).get(kind, [])
			assert_gt(pool.size(), 0, "%s has a %s line" % [r["id"], kind])
			for id: Variant in pool:
				assert_true(lines.has(str(id)), "line %s exists" % id)
				if lines.has(str(id)):
					assert_eq(str((lines[str(id)] as Dictionary)["speaker"]), str(r["speaker"]), "%s is %s's" % [id, r["id"]])
		assert_almost_eq(float(r["hide"][1]), 3.8, 0.01, "%s hides on the upstairs floor" % r["id"])
	for sp: String in ["DUT", "PEG", "DEA", "WRN"]:
		assert_true(lines.has("%s_INN_SURV_TURN_01" % sp), "%s warns when a survivor turns" % sp)


func test_shot_damage() -> void:
	var a: Dictionary = {"damage_mult": 1.0, "head_mult": 2.0}
	assert_almost_eq(InnSurvivors.shot_damage(100.0, false, a), 100.0, 0.001)
	assert_almost_eq(InnSurvivors.shot_damage(100.0, true, a), 200.0, 0.001, "a head hit")
	assert_almost_eq(InnSurvivors.shot_damage(100.0, false, {"damage_mult": 0.5}), 50.0, 0.001)


func test_swipes_down_the_armed_and_kill_the_hiding() -> void:
	assert_eq(InnSurvivors.swipe_outcome(10.0, true), "", "still standing")
	assert_eq(InnSurvivors.swipe_outcome(0.0, true), "downed", "armed: downed, can be helped up")
	assert_eq(InnSurvivors.swipe_outcome(-5.0, false), "dead", "hiding: killed")


func test_lure_rules() -> void:
	var a: Dictionary = {"lure_radius": 8.0, "lure_radius_hidden": 4.5, "lure_floor_dy": 1.6, "max_lured": 2}
	var s: Vector3 = Vector3(12, 3.8, 2)
	assert_true(InnSurvivors.may_lure(Vector3(12, 3.8, 5), s, false, 0, a), "a zombie in the room")
	assert_false(InnSurvivors.may_lure(Vector3(12, 3.8, 8), s, false, 0, a), "the hall is too far for a hiding one")
	assert_true(InnSurvivors.may_lure(Vector3(12, 3.8, 8), s, true, 0, a), "an armed one draws them further")
	assert_false(InnSurvivors.may_lure(Vector3(12, 0.0, 3), s, true, 0, a), "never from the floor below")
	assert_false(InnSurvivors.may_lure(Vector3(12, 3.8, 3), s, true, 2, a), "at most max_lured each")


func test_rise_waits_for_a_round() -> void:
	var a: Dictionary = {"rise_after": 5.0}
	assert_false(InnSurvivors.rises_now(4.9, true, a))
	assert_true(InnSurvivors.rises_now(5.0, true, a))
	assert_false(InnSurvivors.rises_now(20.0, false, a), "not in the break: it waits for the next round")


func test_survivor_prompts_follow_state() -> void:
	var mgr: InnSurvivors = InnSurvivors.new()
	add_child_autofree(mgr)   # not on Map 0: it builds no survivors of its own
	mgr.cfg = _cfg()
	var s: InnSurvivor = InnSurvivor.new()
	s.setup(mgr.cfg["survivors"][0], mgr)
	mgr.add_child(s)
	assert_false(s.visible, "hidden before the stair door")
	assert_false(s.is_catchable(), "zombies can't find the hidden")
	assert_eq(s.get_prompt(null), "", "no prompt while hidden")
	assert_false(s.can_interact(null))
	s.apply_state(InnSurvivor.State.HIDING, s.global_position, 0.0)
	assert_true(s.visible and s.is_catchable(), "in the room, in danger")
	assert_true(s.get_prompt(null).contains(str(int(mgr.cfg["arm"]["cost"]))), "the arm prompt shows the price: %s" % s.get_prompt(null))
	assert_eq(s.body.pose, &"cower")
	s.apply_state(InnSurvivor.State.ARMED, s.global_position, 0.0)
	assert_eq(s.body.pose, &"aim")
	assert_eq(s.get_prompt(null), "", "an armed survivor has nothing to buy")
	s.apply_state(InnSurvivor.State.DOWNED, s.global_position, 0.0)
	assert_false(s.is_catchable(), "zombies leave the downed")
	assert_true(s.get_prompt(null).contains("help"), "help them up")
	for n: Node in s.find_children("*", "CollisionObject3D", true, false):
		assert_true(n is Area3D, "nothing solid: shots and bots pass through (%s)" % n.name)
