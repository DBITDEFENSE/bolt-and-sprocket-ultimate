extends GutTest
## Ballast v2 (UPDATE 10 contract C2, design section 3, DECISIONS T-153): the carry limit (melee + the pistol slot),
## the two destinations' counters and the egg's rule, the squad line pick, the load bonus, the extra Glasshide queue
## and the map's spawn-pressure override.

var b: Dictionary


func before_all() -> void:
	b = GLData.load_json("res://data/gravelight/map02.json")["ballast"]


func test_carry_limit_allows_only_pistols() -> void:
	assert_true(WeaponHolder.carry_allows(WeaponInstance.create(&"m1911")), "a carrier may fire the M1911")
	assert_true(WeaponHolder.carry_allows(WeaponInstance.create(&"luger_p08")), "or any pistol")
	assert_false(WeaponHolder.carry_allows(WeaponInstance.create(&"m1_garand")), "not a rifle")
	assert_false(WeaponHolder.carry_allows(null), "nothing in hand: nothing to fire (melee still works)")


func test_carry_limit_on_a_holder() -> void:
	var h: WeaponHolder = WeaponHolder.new()
	h.slots = [WeaponInstance.create(&"m1_garand"), WeaponInstance.create(&"m1911")]
	h.current_index = 0
	assert_eq(h.pistol_slot(), 1, "the pistol is in slot 2")
	h.carry_limited = true
	assert_true(h.carry_limited, "the limit is on")
	h.free()


func test_choice_counters() -> void:
	assert_false(TotenhafenBallast.choice_done(0, 3), "three dumped but none loaded: the power still wants one")
	assert_false(TotenhafenBallast.choice_done(1, 2), "one loaded, two dumped: the egg wants three")
	assert_true(TotenhafenBallast.choice_done(1, 3), "one loaded and three dumped: done")
	assert_true(TotenhafenBallast.choice_done(2, 4), "more of either is fine")
	assert_eq(int(b["needed"]), 1, "the power needs one loaded")
	assert_eq(int(b["shard_after_dumps"]), 3, "the shard comes with the third dump")


func test_squad_line_pick() -> void:
	var lines: Array = b["squad_load"]
	assert_eq(TotenhafenBallast.pick_line(lines, ["DUT", "PEG"], "DUT"), "DUT_BALLAST_LOAD_01", "Dutch comments on a load when he's here")
	assert_eq(TotenhafenBallast.pick_line(lines, ["WRN", "PEG"], "DUT"), "PEG_BALLAST_LOAD_01", "else the first squad member present")
	assert_eq(TotenhafenBallast.pick_line(b["squad_dump"], ["DEA"], "DEA"), "DEA_BALLAST_DUMP_01", "Deacon on a dump")
	assert_eq(TotenhafenBallast.pick_line([], ["DEA"], "DEA"), "", "no lines, no line")


func test_lines_exist() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: Variant in (b["squad_load"] as Array) + (b["squad_dump"] as Array) + [b["squad_dump_third"]]:
		assert_true(lines.has(str(id)), "VO line %s exists" % id)
	for cat: String in ["OPR_BALLAST_LOAD_01", "OPR_BALLAST_DUMP_01"]:
		assert_true(lines.has(cat), "Operator line %s exists" % cat)


func test_dump_and_respawn_data() -> void:
	assert_eq((b["dump"] as Array).size(), 3, "the dump has a position")
	assert_lt(float((b["dump"] as Array)[2]), 3.0, "the dump is at the quay parapet by the sea stairs (z < 3)")
	assert_gt(float(b["respawn_seconds"]), 0.0, "gone coffins come back")
	assert_gte((b["coffin_spots"] as Array).size() + (b["pallet_spots"] as Array).size(), int(b["max_coffins"]) + 1, "more pallets than coffins (a free one to respawn on)")
	assert_gt(int(GLData.table("economy").get("ballast_load_bonus", 0)), 0, "a load pays Scrip")


func test_extra_spawn_queue() -> void:
	var before: int = RoundManager.pending_extra(&"glasshide")
	RoundManager.extra_spawn(&"glasshide", 1)
	RoundManager.extra_spawn(&"glasshide", 1)
	assert_eq(RoundManager.pending_extra(&"glasshide"), before + 2, "two dumps queue two Glasshides for the next round")
	RoundManager._extra_next.clear()


func test_map_spawn_override() -> void:
	var cfg: Dictionary = GLData.table("rounds")
	var o: Dictionary = RoundManager.map_override(&"map02_totenhafen", cfg)
	assert_almost_eq(float(o.get("spawn_interval_mult", 1.0)), 0.75, 0.001, "Totenhafen spawns 25% faster (C2)")
	assert_eq(int(o.get("max_active_add", 0)), 4, "and four more at once")
	assert_true(RoundManager.map_override(&"map00_crossroads", cfg).is_empty(), "Map 0 is unchanged")
