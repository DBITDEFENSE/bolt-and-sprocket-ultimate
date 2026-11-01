extends GutTest
## T-142 (UPDATE 09 section 4, contract C5): the relief squads' roll, data tables, looks, actor budget and Scrip share.

const MAPS_WITH: PackedStringArray = ["map00", "map01", "map02", "map04a", "map04c"]
const MAPS_WITHOUT: PackedStringArray = ["map04b", "map04d"]
const CATS: PackedStringArray = ["ARRIVE", "CONTACT", "HURT", "DOWN", "LEAVE", "SURVIVE"]


func _g() -> Dictionary:
	return ReliefSquad.cfg()


func test_global_tuning_matches_the_contract() -> void:
	var g: Dictionary = _g()
	assert_eq(int(g["from_round"]), 4)
	assert_almost_eq(float(g["chance_per_round"]), 0.35, 0.0001)
	assert_eq(int(g["max_active"]), 1)
	assert_eq(int(g["cooldown_rounds"]), 3)
	assert_eq((g["size"] as Array).map(func(x: Variant) -> int: return int(x)), [3, 6])
	assert_eq((g["stay_seconds"] as Array).map(func(x: Variant) -> int: return int(x)), [60, 150])
	assert_almost_eq(float(g["survivor_chance"]), 0.25, 0.0001)
	assert_almost_eq(float(g["scrip_share"]), 0.25, 0.0001)
	assert_gt(float(g["overrun_bias"]), 0.5, "most leavers are overrun")


func test_roll_waits_for_from_round() -> void:
	var g: Dictionary = _g()
	assert_false(ReliefSquad.roll_allowed(3, -1000, 0, false, g), "round 3: too early")
	assert_true(ReliefSquad.roll_allowed(4, -1000, 0, false, g), "round 4: allowed")


func test_roll_cooldown() -> void:
	var g: Dictionary = _g()
	assert_false(ReliefSquad.roll_allowed(5, 4, 0, false, g), "1 round after an arrival")
	assert_false(ReliefSquad.roll_allowed(6, 4, 0, false, g), "2 rounds after")
	assert_true(ReliefSquad.roll_allowed(7, 4, 0, false, g), "3 rounds after: free again")


func test_roll_max_active_and_blocked() -> void:
	var g: Dictionary = _g()
	assert_false(ReliefSquad.roll_allowed(9, -1000, 1, false, g), "one squad already in")
	assert_false(ReliefSquad.roll_allowed(9, -1000, 0, true, g), "a boss fight / holdout / cutscene blocks")


func test_roll_chance_with_a_seeded_rng() -> void:
	var g: Dictionary = _g()
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 1942
	b.seed = 1942
	var hits: int = 0
	for i: int in 4000:
		var ra: bool = ReliefSquad.roll(10, -1000, 0, false, g, a)
		assert_eq(ra, ReliefSquad.roll(10, -1000, 0, false, g, b)) if i < 20 else b.randf()
		if ra:
			hits += 1
	assert_almost_eq(float(hits) / 4000.0, 0.35, 0.03, "about chance_per_round of the allowed rounds")
	var c: RandomNumberGenerator = RandomNumberGenerator.new()
	c.seed = 7
	for i2: int in 50:
		assert_false(ReliefSquad.roll(2, -1000, 0, false, g, c), "never before from_round, whatever the dice")


func test_event_flags_block_the_roll() -> void:
	var g: Dictionary = _g()
	for f: StringName in GameState.EVENT_FLAGS:
		GameState.set_flag(f, true)
		assert_true(GameState.in_event(), "%s is an event" % f)
		assert_true(ReliefSquad.blocked_now(false, g), "%s blocks squads" % f)
		GameState.set_flag(f, false)
	assert_false(GameState.in_event())
	assert_false(ReliefSquad.blocked_now(false, g))
	assert_true(ReliefSquad.blocked_now(true, g), "special rounds are skipped")


func test_hold_flag_while_a_node_lives() -> void:
	var n: Node = Node.new()
	add_child(n)
	GameState.hold_flag_while(&"cutscene", n)
	assert_true(GameState.has_flag(&"cutscene"))
	var n2: Node = Node.new()
	add_child(n2)
	GameState.hold_flag_while(&"cutscene", n2)
	remove_child(n)
	assert_true(GameState.has_flag(&"cutscene"), "still one holder")
	remove_child(n2)
	assert_false(GameState.has_flag(&"cutscene"), "the last holder left")
	n.free()
	n2.free()


func test_pick_size_and_stay_in_range() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 3
	for i: int in 200:
		var s: int = ReliefSquad.pick_size(_g(), r)
		assert_between(s, 3, 6)
		var st: float = ReliefSquad.pick_stay(_g(), r)
		assert_between(st, 60.0, 150.0)


func test_faction_tables_per_map() -> void:
	var tbl: Dictionary = ReliefSquad.table()
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var cast: Dictionary = GLData.load_json("res://data/gravelight/vo/voice_cast.json").get("cast", {})
	for m: String in MAPS_WITH:
		var fs: Array[Dictionary] = ReliefSquad.factions_for(m, tbl)
		assert_gt(fs.size(), 0, "%s has factions" % m)
		for f: Dictionary in fs:
			var fid: String = str(f.get("id", ""))
			assert_ne(fid, "", "%s faction id" % m)
			assert_ne(str(f.get("display", "")), "")
			assert_true((tbl["kits"] as Dictionary).has(str(f["kit"])), "%s/%s kit %s exists" % [m, fid, f["kit"]])
			for w: Variant in f["weapons"]:
				assert_true(weapons.has(str(w)), "%s/%s weapon %s exists" % [m, fid, w])
			assert_true(f.has("marked"), "%s/%s says whether it carries the Marke" % [m, fid])
			var pre: String = str(f["barks_prefix"])
			assert_true(pre.begins_with("SQD_"), pre)
			assert_true(cast.has(pre), "voice_cast has a voice for %s" % pre)
			for cat: String in CATS:
				var n: int = 0
				for i: int in range(1, 4):
					if lines.has("%s_%s_%02d" % [pre, cat, i]):
						n += 1
						assert_eq(str(lines["%s_%s_%02d" % [pre, cat, i]]["speaker"]), "SQD")
				assert_between(n, 2, 3, "%s_%s has 2-3 lines" % [pre, cat])
			var edges: Array = f.get("edge_spawns", [])
			assert_gt(edges.size(), 1, "%s/%s has edge spawns" % [m, fid])
			for e: Variant in edges:
				assert_eq((e as Array).size(), 3)
	for m2: String in MAPS_WITHOUT:
		assert_eq(ReliefSquad.factions_for(m2, tbl).size(), 0, "%s has none" % m2)
		assert_ne(str(((tbl["maps"] as Dictionary)[m2] as Dictionary).get("_doc", "")), "", "%s says why" % m2)
	for spk: String in ["DEA", "WRN", "DUT", "PEG"]:
		assert_true(lines.has("%s_SQD_RISE_01" % spk) and lines.has("%s_SQD_RISE_02" % spk), "%s reacts to a rise" % spk)


func test_map_key() -> void:
	assert_eq(ReliefSquad.map_key("map00_crossroads"), "map00")
	assert_eq(ReliefSquad.map_key("map04a_thalbach"), "map04a")


func test_kits_use_existing_bodies_and_no_insignia_kits() -> void:
	var kits: Dictionary = ReliefSquad.table()["kits"]
	for k: String in ["partisan", "soviet_scout", "volkssturm", "commando", "shore_party", "paratrooper", "mp"]:
		assert_true(kits.has(k), "kit %s" % k)
		var row: Dictionary = kits[k]
		for base: Variant in (row["bases"] as Dictionary).keys():
			assert_true(ZombieBody.KITS.has(str(base)), "%s wears an existing kit (%s)" % [k, base])
			for b: Variant in row["builds"]:
				var parts: Dictionary = ZombieBody.base_parts(str(b), false, true)
				if parts.is_empty():
					continue   # a checkout without the GLBs imported
				assert_true(parts.has("Kit_" + str(base)), "the human base %s has Kit_%s" % [b, base])
	assert_eq(float((kits["volkssturm"] as Dictionary).get("female", 0.0)), 0.0, "the Volkssturm here are old men")
	assert_false((kits["volkssturm"] as Dictionary).has("armband"), "no Volkssturm armband")


func test_look_is_deterministic_and_tagged() -> void:
	var a: Dictionary = SoldierKits.roll_look("partisan", 1234)
	var b: Dictionary = SoldierKits.roll_look("partisan", 1234)
	assert_eq(str(a), str(b), "same kit and seed, same soldier (host and puppet)")
	assert_true(ZombieBody.KITS.has(str(a["base"])))
	var tag: String = SoldierKits.tag_of("partisan", 1234, false)
	var t: Dictionary = SoldierKits.parse_tag(tag)
	assert_eq(str(t["kit"]), "partisan")
	assert_eq(int(t["seed"]), 1234)
	assert_false(bool(t["marked"]))
	assert_true(bool(SoldierKits.parse_tag(SoldierKits.tag_of("volkssturm", 5, true))["marked"]))
	assert_eq(SoldierKits.zombie_variant(tag), str(a["base"]), "a risen soldier uses its body's kit rig")
	assert_eq(SoldierKits.parse_tag("rother"), {}, "a person id is not a tag")


func test_actor_budget_arithmetic() -> void:
	assert_eq(ZombieDirector.budget_for(24, 0), 24)
	assert_eq(ZombieDirector.budget_for(24, 6), 18, "each living soldier holds one slot")
	assert_eq(ZombieDirector.budget_for(4, 6), 0, "never below zero")
	var keep: Array = [RoundManager.state, RoundManager.to_spawn, RoundManager.alive, RoundManager.actor_reserve, RoundManager._holds.duplicate()]
	RoundManager.state = RoundManager.State.ROUND
	RoundManager._holds.clear()
	RoundManager.to_spawn = 10
	RoundManager.actor_reserve = 6
	RoundManager.alive = RoundManager.max_active() - 6
	assert_false(RoundManager.can_spawn(), "the cap is max_active - soldiers")
	RoundManager.alive = RoundManager.max_active() - 7
	assert_true(RoundManager.can_spawn())
	RoundManager.actor_reserve = 0
	RoundManager.alive = RoundManager.max_active() - 1
	assert_true(RoundManager.can_spawn(), "no soldiers: the plain cap")
	RoundManager.state = keep[0]
	RoundManager.to_spawn = keep[1]
	RoundManager.alive = keep[2]
	RoundManager.actor_reserve = keep[3]
	RoundManager._holds = keep[4]


func test_scrip_share() -> void:
	var g: Dictionary = _g()
	assert_eq(ReliefSquad.scrip_share_of(100, g), 25)
	assert_eq(ReliefSquad.scrip_share_of(130, g), 32, "rounded down")
	assert_eq(ReliefSquad.scrip_share_of(0, g), 0)
	assert_eq(ReliefSquad.scrip_share_of(2, g), 1, "a paying kill pays at least 1")
	var econ: Dictionary = GLData.table("economy")
	var head: int = Economy.kill_value(&"head", false, econ)
	assert_eq(ReliefSquad.scrip_share_of(head, g), int(floor(head * 0.25)), "a quarter of a headshot kill")


func test_pick_faction_weights() -> void:
	var fs: Array[Dictionary] = ReliefSquad.factions_for("map00", ReliefSquad.table())
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 11
	var count: Dictionary = {}
	for i: int in 1000:
		var f: Dictionary = ReliefSquad.pick_faction(fs, r)
		count[f["id"]] = int(count.get(f["id"], 0)) + 1
	assert_almost_eq(float(count.get("ak", 0)) / 1000.0, 0.6, 0.06, "Home Army weight 0.6")
