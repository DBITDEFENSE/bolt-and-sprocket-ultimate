extends GutTest
## Letzte Fahrt (UPDATE 10 contract C3, DECISIONS T-153) and the Totenhafen stations: the quest graph (validates, the
## contract's step ids exist, every step is reachable from a root, every step has a bot_task or a player-only reason,
## knowledge keys exist, every VO id exists), the cipher roll and its solver, the radio message, the sail's maths,
## the searchlight's beam and the Crane Drop's box.

const PATH: String = "res://data/gravelight/quests/map02_letzte_fahrt.json"
const CONTRACT_IDS: Array = ["s0_power", "s1_ballast", "s2_cipher", "s3_log", "s4_parts", "s5_diesels", "s6_boss", "s7_key",
	"s8_curtain", "s9_sail", "s10_ending"]

var def: Dictionary


func before_all() -> void:
	def = GLData.load_json(PATH)


func test_validates_and_has_the_contract_ids() -> void:
	assert_eq(QuestManager.validate(def), PackedStringArray(), "the quest validates")
	var ids: Array = []
	for s: Dictionary in def["steps"]:
		ids.append(str(s["id"]))
	for id: String in CONTRACT_IDS:
		assert_true(ids.has(id), "contract step %s exists" % id)


func test_every_step_reachable() -> void:
	var done: Dictionary = {}
	var steps: Array = def["steps"]
	var changed: bool = true
	while changed:
		changed = false
		for s: Dictionary in steps:
			if done.has(s["id"]):
				continue
			var ok: bool = true
			for r: Variant in s.get("requires", []):
				if not done.has(str(r)):
					ok = false
			if ok:
				done[s["id"]] = true
				changed = true
	for s2: Dictionary in steps:
		assert_true(done.has(s2["id"]), "%s is reachable" % s2["id"])
	assert_eq(done.size(), steps.size(), "no cycles, nothing stranded")


func test_every_step_has_a_bot_task_or_a_reason() -> void:
	var know: Dictionary = def.get("bot_knowledge", {})
	for s: Dictionary in def["steps"]:
		var t: Dictionary = s.get("bot_task", {})
		assert_false(t.is_empty(), "%s has a bot_task" % s["id"])
		if BotEECatalog.is_player_only(t):
			assert_eq(str(s["id"]), "s10_ending", "only the cutscene is player-only")
			continue
		assert_eq(BotEECatalog.validate(t), PackedStringArray(), "%s's bot_task is valid" % s["id"])
		for k: Variant in t.get("needs", []):
			assert_true(know.has(str(k)), "%s needs %s, which bot_knowledge defines" % [s["id"], k])


func test_vo_ids_exist() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var ids: Array = []
	for s: Dictionary in def["steps"]:
		for key: String in ["on_start", "on_complete"]:
			for a: Variant in s.get(key, []):
				if (a as Dictionary).has("vo"):
					ids.append(str(a["vo"]))
	for id: String in ids:
		assert_true(lines.has(id), "VO %s exists" % id)
	for extra: String in ["RAD_M2_CODE_01", "RAD_M2_CODE_02", "RAD_M2_CODE_03", "DEA_LF_DIESELS_01", "PET_LF_HELM_01",
			"DEA_LF_CUT_01", "OPR_LF_CUT_01", "PEG_LF_TELEGRAM_01", "OPR_LF_CIPHER_WRONG_01", "OPR_LF_SAIL_01"]:
		assert_true(lines.has(extra), "VO %s exists" % extra)


func test_cipher_roll_is_seeded_and_solvable() -> void:
	var spec: Dictionary = def["random"]
	var a: Dictionary = QuestManager.roll_random(spec, 1234, "map02_letzte_fahrt")
	var b: Dictionary = QuestManager.roll_random(spec, 1234, "map02_letzte_fahrt")
	assert_eq(a["cipher"], b["cipher"], "the same seed rolls the same cipher")
	var c: Dictionary = a["cipher"]
	assert_eq((c["groups"] as Dictionary).size(), 3, "three radio groups")
	assert_eq((c["order"] as Array).size(), 3, "a keying order over the three radios")
	var firsts: Dictionary = {}
	for g: Variant in (c["groups"] as Dictionary).values():
		assert_eq(str(g).length(), 4, "a 4-letter group")
		firsts[str(g)[0]] = true
	assert_eq(firsts.size(), 3, "the three first letters differ")
	assert_eq(a["cipher_inputs"], CipherMachine.solve(c), "the solver reads the inputs off the groups and the order")
	assert_true(CipherMachine.solves(CipherMachine.solve(c), a["cipher_inputs"]), "and that setting solves it")
	assert_false(CipherMachine.solves(["A", "A", "A"], ["K", "R", "T"]), "a wrong setting does not")
	var other: Dictionary = QuestManager.roll_random(spec, 99, "map02_letzte_fahrt")
	var differ: int = 0
	for s: int in [7, 8, 9, 10, 11]:
		if QuestManager.roll_random(spec, s, "map02_letzte_fahrt")["cipher_inputs"] != other["cipher_inputs"]:
			differ += 1
	assert_gt(differ, 0, "different seeds give different settings")


func test_wheel_and_radio_rules() -> void:
	assert_eq(CipherMachine.next_letter("A"), "B", "A -> B")
	assert_eq(CipherMachine.next_letter("H"), "J", "the wheels skip I")
	assert_eq(CipherMachine.next_letter("Z"), "A", "and wrap")
	var roll: Dictionary = {"order": ["radio_uboat", "radio_cannery", "radio_workshop"], "groups": {"radio_uboat": "KXRT", "radio_cannery": "MBLE", "radio_workshop": "SNAV"}}
	assert_eq(LfRadio.message_for(&"radio_cannery", roll), [2, "MBLE"], "the cannery set says message 2 of 3")
	assert_eq(LfRadio.message_for(&"radio_uboat", roll), [1, "KXRT"], "the boat's set says message 1")


func test_spots_and_parts_seeded() -> void:
	var m: Dictionary = GLData.load_json("res://data/gravelight/map02.json")
	var spots: Dictionary = m["letzte_fahrt"]["log_spots"]
	var groups: Dictionary = def["random"]["log_spots"]["groups"]
	for page: Variant in groups.keys():
		assert_true(spots.has(page), "%s has spots in map02.json" % page)
		for name: Variant in groups[page]:
			assert_true((spots[page] as Dictionary).has(str(name)), "%s spot %s is placed" % [page, name])
	var ut: Dictionary = def["random"]["ut_parts"]["groups"]
	for part: Variant in ["undertow_pump", "undertow_head"]:
		for name2: Variant in ut[part]:
			assert_true((m["undertow"]["spots"][part] as Dictionary).has(str(name2)), "%s spot %s is placed" % [part, name2])


func test_sail_maths() -> void:
	assert_almost_eq(UboatSail.advance(0.0, 75.0, 150.0), 0.5, 0.0001, "half the time: half way")
	assert_eq(UboatSail.advance(0.9, 60.0, 150.0), 1.0, "never past the depth mark")
	assert_almost_eq(UboatSail.card_z(100.0, 0.5, 220.0, 1.0), -10.0, 0.001, "a card scrolls north as she sails south")
	assert_almost_eq(UboatSail.card_z(120.0, 1.0, 220.0, 0.35), 43.0, 0.001, "the far town scrolls slower")
	var box: AABB = AABB(Vector3(3.8, -2.6, 37.4), Vector3(6.4, 8.6, 49.4))
	assert_true(UboatSail.aboard(Vector3(7, 1.2, 60), box), "on the deck is aboard")
	assert_true(UboatSail.aboard(Vector3(7, -1.8, 76), box), "the engine room is aboard")
	assert_false(UboatSail.aboard(Vector3(17, 0.2, 60), box), "pier 2 is not")


func test_searchlight_beam() -> void:
	var o: Vector3 = Vector3(47, 8.6, 37)
	var f: Vector3 = (Vector3(40, 0, 66) - o).normalized()
	assert_true(Searchlight.in_beam(o, f, Vector3(40, 1, 66), 48.0, 9.0), "a zombie on the aim point is lit")
	assert_false(Searchlight.in_beam(o, f, Vector3(-10, 1, 66), 48.0, 9.0), "one across the hall is not")
	assert_false(Searchlight.in_beam(o, f, o + f * 80.0, 48.0, 9.0), "nor one past the range")
	var aim: Vector2 = Searchlight.aim_at(o, Vector3(47, 0, 60), PI)
	assert_almost_eq(aim.x, 0.0, 0.01, "straight ahead of a station facing south")
	assert_lt(aim.y, 0.0, "and down")
	var c: Vector2 = Searchlight.clamp_aim(Vector2(3.0, 1.0), {"yaw_limit_deg": 80.0, "pitch_min_deg": -55.0, "pitch_max_deg": 5.0})
	assert_almost_eq(c.x, deg_to_rad(80.0), 0.001, "yaw is clamped")
	assert_almost_eq(c.y, deg_to_rad(5.0), 0.001, "pitch is clamped")
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map02.json")["searchlight"]
	assert_almost_eq(float(cfg["lit_damage_mult"]), 1.25, 0.001, "+25% damage in the beam (C2)")


func test_crane_drop_box() -> void:
	var c: Vector3 = Vector3(40, 0, 70)
	assert_true(CraneTrap.in_box(Vector3(42.9, 0, 71.9), c, Vector2(6, 4)), "inside the 6 x 4 m box")
	assert_false(CraneTrap.in_box(Vector3(43.2, 0, 70), c, Vector2(6, 4)), "3.2 m east is outside")
	assert_false(CraneTrap.in_box(Vector3(40, 0, 72.2), c, Vector2(6, 4)), "2.2 m south is outside")
	assert_true(CraneTrap.can_fire(0, 0.0), "idle and cool: it fires")
	assert_false(CraneTrap.can_fire(0, 12.0), "cooling down: not yet")
	assert_false(CraneTrap.can_fire(2, 0.0), "falling: not again")
	assert_eq(float(TrapLever.cfg_for("crane_drop")["cooldown"]), 60.0, "a 60 s cooldown (C2)")


func test_holdout_step() -> void:
	var r: Array = HoldoutStation.step(0.0, 15.0, true, 0.0, 30.0, 20.0)
	assert_almost_eq(float(r[0]), 0.5, 0.0001, "15 s of a 30 s hold: half")
	r = HoldoutStation.step(0.5, 5.0, false, 0.0, 30.0, 20.0)
	assert_almost_eq(float(r[0]), 0.5, 0.0001, "empty: it pauses")
	assert_false(bool(r[2]), "5 s empty is not abandoned")
	r = HoldoutStation.step(0.5, 21.0, false, 0.0, 30.0, 20.0)
	assert_true(bool(r[2]), "20 s empty fails it (retry next round)")
