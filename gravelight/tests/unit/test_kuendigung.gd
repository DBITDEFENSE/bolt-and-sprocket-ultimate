extends GutTest
## Map 4's main egg "Kündigung" (UPDATE 07, docs/MAP4_FERNFLUG.md §9; T-114): the quest files validate and every
## bot task is well-formed; the hangar's PA extension is a seeded six-digit code the files spell out; a skip to a
## later act marks the earlier acts' steps done; the campaign carry (carry_snapshot / apply_carry) brings the real
## progress and the same code onto the Kranich; the ramp waits on the hangar key and the door code
## (requires_flags, missing_flags, the QuestInteract prompt); carried_flags honours exact names and prefixes;
## perk_tier_grant leaves its flag; the wind tunnel's pure rules; the files' digit slices; and on the generated
## scenes every quest object stands near navmesh so bots and players can reach it.

const MAIN: String = "res://data/gravelight/quests/map04_kuendigung.json"
const SIDE: String = "res://data/gravelight/quests/map04a_jette.json"
const EDGES: GDScript = preload("res://gravelight/tests/unit/test_map02_edges.gd")
const SCENE_A: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const SCENE_B: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"

var _saved_path: String = ""
var _saved_map: StringName = &""
var _saved_act: Dictionary = {}


func before_all() -> void:
	_saved_path = ProfileSave.path
	ProfileSave.path = "user://_test_profile_kuendigung.json"
	_saved_map = GameState.map_id
	_saved_act = RoundManager.act


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = _saved_path
	ProfileSave.load_profile()
	QuestManager.clear()
	GameState.map_id = _saved_map
	RoundManager.act = _saved_act
	Campaign.reset()


func before_each() -> void:
	QuestManager.clear()
	GameState.flags.clear()
	GameState.map_id = &"map00_crossroads"   # no act block: nothing is auto-completed
	RoundManager.act = {}
	QuestManager.match_seed = 4242


func _ids(path: String) -> Array:
	var out: Array = []
	for s: Dictionary in GLData.load_json(path)["steps"]:
		out.append(str(s["id"]))
	return out


# ---------------------------------------------------------------- data

func test_quest_files_validate_and_reference_real_vo() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for path: String in [MAIN, SIDE]:
		var def: Dictionary = GLData.load_json(path)
		assert_eq(QuestManager.validate(def), PackedStringArray(), path)
		for id: String in QuestManager.referenced_vo(def):
			assert_true(lines.has(id), "%s references missing VO %s" % [path, id])
	var main: Dictionary = GLData.load_json(MAIN)
	assert_eq(main["maps"], ["map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"], "the egg spans the four acts")
	assert_eq(_ids(MAIN), ["s1_power", "s2_files", "s3_pa_line", "s4_tunnel", "s5_kranfuehrer", "s6_board", "s7a_crew_tags", "s7_bordwart",
			"s8_london", "s9_bomb_run", "s10_autopilot"])
	for s: Dictionary in main["steps"]:
		assert_true(s.has("act") and int(s["act"]) in [1, 2], "%s names its act" % s["id"])


func test_every_step_has_a_valid_bot_task() -> void:
	for path: String in [MAIN, SIDE]:
		for s: Dictionary in GLData.load_json(path)["steps"]:
			var t: Dictionary = BotEECatalog.task_def(s)
			assert_eq(BotEECatalog.validate(t), PackedStringArray(), "%s/%s bot_task" % [path.get_file(), s["id"]])


func test_bot_knowledge_names_the_files_and_the_code() -> void:
	var bk: Dictionary = GLData.load_json(MAIN)["bot_knowledge"]
	assert_true(bk.has("files") and bk.has("code"))
	assert_eq(str(bk["files"]["on_collect"]["tag"]), "fernflug_file")
	assert_eq(bk["code"]["on_vo"], ["WIT_M4A_SWITCH_01"])
	var qid: StringName = QuestManager.load_quest(MAIN)
	assert_eq(QuestManager.definition(qid)["bot_knowledge"], bk, "the bots read the block off the loaded quest")


# ---------------------------------------------------------------- the seeded extension

func test_hangar_code_is_six_seeded_digits_the_files_spell() -> void:
	var qid: StringName = QuestManager.load_quest(MAIN)
	var code: String = str(QuestManager.random_value(qid, "files"))
	assert_eq(code.length(), 6)
	assert_true(code.is_valid_int(), "digits only: " + code)
	QuestManager.clear()
	assert_eq(str(QuestManager.random_value(QuestManager.load_quest(MAIN), "files")), code, "the same seed rolls the same code")
	QuestManager.match_seed = 7
	QuestManager.clear()
	var other: String = str(QuestManager.random_value(QuestManager.load_quest(MAIN), "files"))
	assert_ne(other, code, "another seed, another extension")
	# the three files carry two digits each, in order
	assert_eq(QuestNote.digits_text(code, 0, 2) + QuestNote.digits_text(code, 2, 2) + QuestNote.digits_text(code, 4, 2), code)
	assert_eq(QuestNote.digits_text([1, 2, 3, 4], 1, 2), "23", "an array of digits joins first")
	assert_eq(QuestNote.digits_text(null, 0, 2), "", "an unloaded quest gives no text")


func test_pa_board_takes_the_code_in_order_and_resets_on_a_wrong_digit() -> void:
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.debug_skipto(qid, &"s3_pa_line")
	assert_eq(QuestManager.status(qid, &"s3_pa_line"), "active")
	var code: String = str(QuestManager.random_value(qid, "files"))
	assert_eq(QuestManager.sequence_inputs(qid, &"s3_pa_line").size(), 6)
	assert_eq(str(QuestManager.submit(&"pa_switchboard", code[0])["result"]), "ok")
	var wrong: String = "0" if code[1] != "0" else "1"
	assert_eq(str(QuestManager.submit(&"pa_switchboard", wrong)["result"]), "wrong")
	assert_eq(int(QuestManager.progress(qid, &"s3_pa_line")), 0, "a wrong digit resets the line")
	for c: String in code:
		QuestManager.submit(&"pa_switchboard", c)
	assert_true(QuestManager.is_step_done(qid, &"s3_pa_line"))
	assert_true(GameState.has_flag(&"hangar_code_known"), "the completed line leaves the code flag")


# ---------------------------------------------------------------- acts, skips and the carry

func test_a_skip_to_act_two_marks_act_one_done() -> void:
	GameState.map_id = &"map04b_kranich"
	RoundManager.act = RoundManager.act_block_of(&"map04b_kranich")
	assert_eq(RoundManager.act_index(), 2)
	var qid: StringName = QuestManager.load_quest(MAIN)
	for sid: String in ["s1_power", "s2_files", "s3_pa_line", "s4_tunnel", "s5_kranfuehrer", "s6_board"]:
		assert_eq(QuestManager.status(qid, StringName(sid)), "complete", sid + " (Act I) is done on a skip to Act II")
	assert_eq(QuestManager.status(qid, &"s7a_crew_tags"), "active")
	assert_eq(QuestManager.status(qid, &"s7_bordwart"), "active")
	assert_eq(QuestManager.status(qid, &"s8_london"), "locked")


func test_act_one_on_its_own_map_auto_completes_nothing() -> void:
	GameState.map_id = &"map04a_thalbach"
	RoundManager.act = RoundManager.act_block_of(&"map04a_thalbach")
	var qid: StringName = QuestManager.load_quest(MAIN)
	assert_eq(QuestManager.status(qid, &"s1_power"), "active")
	assert_eq(QuestManager.status(qid, &"s6_board"), "locked")
	assert_eq(QuestManager.status(qid, &"s7a_crew_tags"), "locked")


func test_carry_snapshot_round_trip_onto_the_kranich() -> void:
	GameState.map_id = &"map04a_thalbach"
	RoundManager.act = RoundManager.act_block_of(&"map04a_thalbach")
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.load_quest(SIDE)
	var code: String = str(QuestManager.random_value(qid, "files"))
	QuestManager.debug_skipto(qid, &"s6_board")
	GameState.set_flag(&"hangar_key")
	GameState.set_flag(&"hangar_code_known")
	assert_true(QuestManager.interact(&"kranich_ramp", 1), "the ramp completes s6")
	var snap: Dictionary = QuestManager.carry_snapshot(&"map04b_kranich")
	assert_true(snap.has("map04_kuendigung"), "the main egg follows the squad")
	assert_false(snap.has("map04a_jette"), "the Act I side egg stays on Thalbach")
	assert_true(QuestManager.carry_snapshot(&"map00_crossroads").is_empty(), "nothing is carried to a map the egg does not name")
	var d: Dictionary = snap["map04_kuendigung"]
	for sid: String in ["s1_power", "s2_files", "s3_pa_line", "s4_tunnel", "s5_kranfuehrer", "s6_board"]:
		assert_true((d["done"] as Array).has(sid), sid + " carried as done")
	assert_false((d["done"] as Array).has("s7a_crew_tags"))
	assert_eq(str(d["random"]["files"]), code)
	assert_true((d["checkpoints"] as Array).size() >= 1, "the save points travel")
	# the Kranich: a fresh load (a different seed on purpose), then the carry
	QuestManager.clear()
	GameState.flags.clear()
	GameState.map_id = &"map04b_kranich"
	RoundManager.act = RoundManager.act_block_of(&"map04b_kranich")
	QuestManager.match_seed = 99
	var qid2: StringName = QuestManager.load_quest(MAIN)
	QuestManager.apply_carry(snap)
	assert_eq(str(QuestManager.random_value(qid2, "files")), code, "the same extension on the Kranich")
	assert_eq(QuestManager.status(qid2, &"s6_board"), "complete")
	assert_eq(QuestManager.status(qid2, &"s7a_crew_tags"), "active")
	assert_eq(QuestManager.status(qid2, &"s7_bordwart"), "active")
	assert_eq(QuestManager.status(qid2, &"s8_london"), "locked")
	assert_true(QuestManager.collect(&"crew_tag", &"tag_i", 1), "the tags are collectable on arrival")
	assert_eq(QuestManager.progress(qid2, &"s7a_crew_tags"), [&"tag_i"])


func test_carry_keeps_open_progress() -> void:
	GameState.map_id = &"map04a_thalbach"
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.debug_complete(qid, &"s1_power")
	QuestManager.collect(&"fernflug_file", &"file_1", 1)
	var snap: Dictionary = QuestManager.carry_snapshot(&"map04b_kranich")
	assert_eq(snap["map04_kuendigung"]["progress"], {"s2_files": [&"file_1"]})
	QuestManager.clear()
	var qid2: StringName = QuestManager.load_quest(MAIN)
	QuestManager.apply_carry(snap)
	assert_eq(QuestManager.progress(qid2, &"s2_files"), [&"file_1"])
	assert_eq(QuestManager.status(qid2, &"s2_files"), "active")


func test_carried_flags_take_exact_names_and_prefixes() -> void:
	var flags: Dictionary = {&"london_seen": true, &"bomb_boston_hit": true, &"bomb_norfolk_saved": true, &"power_on": true, &"hangar_key": true, &"tunnel_ran": true}
	var out: Dictionary = Campaign.carried_flags(flags, ["london_seen", "bomb_*", "hangar_key"])
	assert_eq(out.keys().size(), 4)
	assert_true(out.has("london_seen") and out.has("bomb_boston_hit") and out.has("bomb_norfolk_saved") and out.has("hangar_key"))
	assert_false(out.has("power_on"), "the works' power does not fly")
	assert_true(Campaign.carried_flags({}, ["bomb_*"]).is_empty())
	var spec: Array = Campaign.cfg().get("carry_flags", [])
	for want: String in ["london_seen", "bomb_*", "hangar_code_known", "hangar_key"]:
		assert_true(spec.has(want), "campaign.json carries " + want)


# ---------------------------------------------------------------- the ramp's gate

func test_the_ramp_waits_on_the_key_and_the_code() -> void:
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.debug_skipto(qid, &"s6_board")
	assert_eq(QuestManager.status(qid, &"s6_board"), "active")
	assert_true(GameState.has_flag(&"hangar_key") and GameState.has_flag(&"hangar_code_known"), "the skipped steps left both flags")
	GameState.flags.erase(&"hangar_key")   # the gate on its own
	GameState.flags.erase(&"hangar_code_known")
	assert_false(QuestManager.interact_ready(&"kranich_ramp"))
	assert_eq(QuestManager.missing_flags(&"kranich_ramp"), PackedStringArray(["hangar_key", "hangar_code_known"]))
	assert_false(QuestManager.interact(&"kranich_ramp", 1), "no key, no code: the ramp stays up")
	GameState.set_flag(&"hangar_key")
	assert_eq(QuestManager.missing_flags(&"kranich_ramp"), PackedStringArray(["hangar_code_known"]))
	GameState.set_flag(&"hangar_code_known")
	assert_true(QuestManager.interact_ready(&"kranich_ramp"))
	assert_true(QuestManager.interact(&"kranich_ramp", 1))
	assert_true(QuestManager.is_step_done(qid, &"s6_board"))
	assert_eq(QuestManager.missing_flags(&"kranich_ramp"), PackedStringArray(), "a done step asks for nothing")
	assert_true(QuestManager.flags_met_in({"requires_flags": ["a"]}, {&"a": true}))
	assert_false(QuestManager.flags_met_in({"requires_flags": ["a", "b"]}, {&"a": true}))
	assert_true(QuestManager.flags_met_in({}, {}), "no requirement, no gate")


func test_quest_interact_prompt_words() -> void:
	var labels: Dictionary = {"hangar_key": "the hangar key", "hangar_code_known": "the door code"}
	assert_eq(QuestInteract.prompt_for(false, PackedStringArray(), labels, "F", "board the Kranich", "Locked: %s"), "", "inactive: no prompt")
	assert_eq(QuestInteract.prompt_for(true, PackedStringArray(["hangar_key", "hangar_code_known"]), labels, "F", "board the Kranich", "Locked: %s"),
			"Locked: the hangar key, the door code")
	assert_eq(QuestInteract.prompt_for(true, PackedStringArray(["some_flag"]), {}, "F", "x", "Needs %s"), "Needs some flag", "an unlabelled flag reads as words")
	assert_eq(QuestInteract.prompt_for(true, PackedStringArray(), labels, "F", "board the Kranich", "Locked: %s"), "Hold [F] to board the Kranich")


# ---------------------------------------------------------------- the tunnel, the crane driver, the perk grant

func test_tunnel_kills_count_only_while_it_runs() -> void:
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.debug_complete(qid, &"s1_power")
	assert_eq(QuestManager.status(qid, &"s4_tunnel"), "active")
	assert_eq(QuestManager.kill_target(QuestManager.step_def(qid, &"s4_tunnel")), 20, "20 for one player")
	GLBus.enemy_killed.emit(&"ganger", &"torso", &"mp40", 1)
	GLBus.enemy_killed_at.emit(&"ganger", Vector3(20, 0, 115), 1)
	assert_eq(QuestManager.progress(qid, &"s4_tunnel"), null, "the fan is off (and no zone volumes here): nothing counts")


func test_wind_tunnel_pure_rules() -> void:
	assert_true(WindTunnel.can_start(true, true, 0.0, 0.0))
	assert_false(WindTunnel.can_start(false, true, 0.0, 0.0), "needs the power")
	assert_true(WindTunnel.can_start(false, false, 0.0, 0.0), "unless it does not")
	assert_false(WindTunnel.can_start(true, true, 3.0, 0.0), "already running")
	assert_false(WindTunnel.can_start(true, true, 0.0, 10.0), "spinning down")
	var lo: Vector3 = Vector3(6, 0, 112)
	var hi: Vector3 = Vector3(38, 2.4, 118)
	assert_true(WindTunnel.inside(Vector3(20, 0.5, 115), lo, hi))
	assert_false(WindTunnel.inside(Vector3(40, 0.5, 115), lo, hi), "past the fan")
	assert_false(WindTunnel.inside(Vector3(20, 0.5, 119), lo, hi), "beside the test section")
	assert_false(WindTunnel.inside(Vector3(20, 4.0, 115), lo, hi), "on the roof")


func test_crane_driver_counts_only_under_the_ramp() -> void:
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.debug_skipto(qid, &"s5_kranfuehrer")
	assert_eq(QuestManager.status(qid, &"s5_kranfuehrer"), "active")
	var p: Dictionary = QuestManager.step_def(qid, &"s5_kranfuehrer")["params"]
	assert_eq(str(p["world_flag"]), "under_ramp")
	assert_eq(str(p["zone"]), "H_HALLE")
	# no zone volumes in a unit test: the kill fails its conditions and the step stays retryable
	GLBus.enemy_killed_at.emit(&"kranfuehrer", Vector3(-20, 0, 150), 1)
	assert_eq(QuestManager.status(qid, &"s5_kranfuehrer"), "active", "a kill off the ramp does not take the key")
	assert_false(GameState.has_flag(&"hangar_key"))


func test_perk_tier_grant_leaves_its_flag_for_later_buyers() -> void:
	var qid: StringName = QuestManager.load_quest(MAIN)
	QuestManager.debug_complete(qid, &"s1_power")
	QuestManager.debug_complete(qid, &"s4_tunnel")
	assert_eq(int(GameState.flags.get(&"perk_tier_free_skyhook_sekt", 0)), 2, "Skyhook tier II is free for the match")
	var perks: Dictionary = GLData.table("perks")["perks"]
	assert_true(perks.has("skyhook_sekt") and perks.has("magpie_mead"), "the two UPDATE 07 perks exist")


func test_side_egg_rewards() -> void:
	var qid: StringName = QuestManager.load_quest(SIDE)
	assert_eq(QuestManager.status(qid, &"s1_models"), "active")
	for m: String in ["model_i", "model_ii", "model_iii"]:
		QuestManager.collect(&"glider_model", StringName(m), 1)
	assert_true(QuestManager.is_step_done(qid, &"s1_models"))
	assert_true(QuestManager.interact_ready(&"jette_hatch"))
	assert_true(QuestManager.interact(&"jette_hatch", 1))
	assert_true(QuestManager.is_complete(qid))
	assert_eq(int(GameState.flags.get(&"perk_tier_free_skyhook_sekt", 0)), 2)
	var found: bool = false
	for e: Dictionary in GLData.load_json("res://data/gravelight/intel.json")["intel"]:
		if str(e.get("id", "")) == "INT_M4_JETTE":
			found = true
	assert_true(found, "the logbook is an intel entry")


# ---------------------------------------------------------------- the objects on the generated scenes

func _placed(nodes: Array, name: String) -> Vector3:
	for n: Dictionary in nodes:
		if str(n["name"]) == name:
			var props: Dictionary = n["props"]
			var xf: Variant = props.get("transform", null)
			if xf is Transform3D:
				return (xf as Transform3D).origin
			return props.get("position", Vector3.ZERO)
	return Vector3.INF


func _assert_reachable(scene: String, names: Array) -> void:
	var nodes: Array = EDGES._state_nodes(scene)
	var polys: Array = EDGES._nav_polys(nodes)
	assert_gt(polys.size(), 50, "%s carries its baked navmeshes" % scene.get_file())
	for name: String in names:
		var p: Vector3 = _placed(nodes, name)
		assert_true(p != Vector3.INF, "%s is placed on %s" % [name, scene.get_file()])
		if p == Vector3.INF:
			continue
		assert_true(EDGES._on_navmesh(p, polys, 1.6, 1.5), "%s at %s stands by the navmesh (a player can reach it)" % [name, str(p)])


func test_act_one_quest_objects_stand_by_the_navmesh() -> void:
	_assert_reachable(SCENE_A, ["File1", "File2", "File3", "PASwitchboard", "WindTunnel", "RampSwitch", "Glider1", "Glider2", "Glider3", "JetteHatch"])


func test_act_two_quest_objects_stand_by_the_navmesh() -> void:
	_assert_reachable(SCENE_B, ["Tag1", "Tag2", "Tag3"])


func test_the_files_spell_the_extension_in_order() -> void:
	var nodes: Array = EDGES._state_nodes(SCENE_A)
	var froms: Dictionary = {}
	for n: Dictionary in nodes:
		var nm: String = str(n["name"])
		if nm.begins_with("File") and nm.length() == 5:
			var props: Dictionary = n["props"]
			assert_eq(str(props.get("random_key", "")), "map04_kuendigung:files", nm + " reads the seeded code")
			assert_eq(str(props.get("tag", "")), "fernflug_file")
			froms[nm] = int(props.get("digit_from", 0))   # 0 is the default and is not stored
	assert_eq(froms, {"File1": 0, "File2": 2, "File3": 4})
