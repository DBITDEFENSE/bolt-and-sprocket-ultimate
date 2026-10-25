extends GutTest
## Meta progression (GDD §16): rank curve, prestige, dossiers, mastery camos, challenges, migration, keybinds.

var _saved_path: String = ""
var _saved_settings_path: String = ""
var _saved_overrides: Dictionary = {}


func before_all() -> void:
	_saved_path = ProfileSave.path
	# Per-process files: a concurrent test run (another checkout / agent) can't clobber or read ours.
	ProfileSave.path = "user://_test_profile_prog_%d.json" % OS.get_process_id()
	_saved_settings_path = GLSettings.path
	_saved_overrides = GLSettings.overrides.duplicate(true)
	GLSettings.path = "user://_test_settings_%d.cfg" % OS.get_process_id()


func before_each() -> void:
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.cur_match = {}


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GLSettings.path))
	ProfileSave.path = _saved_path
	ProfileSave.cur_match = {}
	ProfileSave.load_profile()
	GLSettings.path = _saved_settings_path
	GLSettings.overrides = _saved_overrides
	GLSettings.apply_bindings()


func test_rank_curve() -> void:
	var c: Dictionary = ProfileSave.curve()
	assert_eq(ProfileSave.xp_to_next(1, c), 800)
	assert_eq(ProfileSave.rank_for_xp(799, c), 1)
	assert_eq(ProfileSave.rank_for_xp(800, c), 2)
	var total60: int = ProfileSave.total_for_rank(60, c)
	assert_between(total60, 640000, 665000, "rank 60 total ~653k")
	assert_eq(ProfileSave.rank_for_xp(total60, c), 60)
	assert_eq(ProfileSave.rank_for_xp(total60 * 3, c), 60, "capped at 60")


func test_rank_up_grants_unlocks() -> void:
	ProfileSave.add_xp(800)
	assert_eq(ProfileSave.rank(), 2)
	assert_true(ProfileSave.is_unlocked("card_snow_fence"))
	assert_true(ProfileSave.is_unlocked("emblem_shovel_and_pick"))


func test_prestige_resets_rank_and_grants_commendation() -> void:
	assert_false(ProfileSave.can_prestige())
	ProfileSave.add_xp(ProfileSave.total_for_rank(60, ProfileSave.curve()))
	assert_eq(ProfileSave.rank(), 60)
	assert_true(ProfileSave.can_prestige())
	assert_true(ProfileSave.do_prestige())
	assert_eq(ProfileSave.rank(), 1)
	assert_eq(ProfileSave.prestige(), 1)
	assert_true(ProfileSave.is_unlocked("commendation_1"))
	assert_true(ProfileSave.is_unlocked("cap_gold"), "earlier unlocks are kept")


func test_dossier_levels() -> void:
	var th: Array = ProfileSave.dossier_thresholds()
	assert_eq(ProfileSave.dossier_level_for(0, th), 1)
	assert_eq(ProfileSave.dossier_level_for(int(th[1]) - 1, th), 1)
	assert_eq(ProfileSave.dossier_level_for(int(th[1]), th), 2)
	assert_eq(ProfileSave.dossier_level_for(int(th[9]) * 2, th), 10)
	assert_eq(ProfileSave.dossier_pages(&"peg").size(), 10)
	assert_string_contains(str(ProfileSave.dossier_pages(&"peg")[9]["text"]), "LANTERN")


func test_camo_thresholds_and_nachtglas() -> void:
	var th: Array = GLData.load_json("res://data/gravelight/progression.json")["camos"]["thresholds"]
	assert_eq(ProfileSave.camo_tier(99, th), &"")
	assert_eq(ProfileSave.camo_tier(100, th), &"olive_drab")
	assert_eq(ProfileSave.camo_tier(1999, th), &"silver")
	assert_eq(ProfileSave.camo_tier(2000, th), &"gold")
	ProfileSave.profile["weapon_kills"] = {"mp40": 2000}
	assert_eq(ProfileSave.camo_for(&"mp40_up"), &"gold", "upgraded variants share the base kills")
	assert_false(ProfileSave.nachtglas_unlocked())
	var all: Dictionary = {}
	for w: Variant in GLData.table("weapons")["weapons"].keys():
		all[str(w)] = 2000
	ProfileSave.profile["weapon_kills"] = all
	assert_true(ProfileSave.nachtglas_unlocked())
	assert_eq(ProfileSave.camo_for(&"kar98k"), &"nachtglas")


func test_challenge_filters() -> void:
	var c: Dictionary = {"event": "kill", "filter": {"weapon_prefix": "trap_"}}
	assert_true(ProfileSave.challenge_matches(c, "kill", {"weapon_id": "trap_ore_cart"}, {}))
	assert_false(ProfileSave.challenge_matches(c, "kill", {"weapon_id": "mp40"}, {}))
	var np: Dictionary = {"event": "round", "filter": {"no_perks": true}}
	assert_true(ProfileSave.challenge_matches(np, "round", {}, {"perks": false}))
	assert_false(ProfileSave.challenge_matches(np, "round", {}, {"perks": true}))


func test_challenge_progress_and_completion() -> void:
	GameState.map_id = &"map00_crossroads"
	ProfileSave._on_match_started(&"map00_crossroads")
	assert_eq(ProfileSave.active_challenges(&"map00_crossroads").size(), 3)
	# Pin the active list instead of patching the random pick: overwriting one slot used to leave a
	# second "m0_boards" in the list ~1 run in 3 (when the shuffle had already drawn it), double-counting.
	ProfileSave.profile["challenges"]["map00_crossroads"] = ["m0_boards", "m0_round10", "m0_knife"]
	for i: int in 59:
		ProfileSave._challenge_event("boards")
	assert_eq(ProfileSave.challenge_progress("m0_boards"), 59)
	assert_false((ProfileSave.profile["challenges_done"] as Array).has("m0_boards"))
	ProfileSave._challenge_event("boards")
	assert_true((ProfileSave.profile["challenges_done"] as Array).has("m0_boards"))
	assert_false(ProfileSave.active_challenges(&"map00_crossroads").has("m0_boards"))
	assert_eq(ProfileSave.active_challenges(&"map00_crossroads").size(), 3, "replaced with a new one")
	assert_true(ProfileSave.is_unlocked("card_carpenters"))
	assert_eq(int(ProfileSave.cur_match["xp"]), 1500, "challenge XP joins the match XP")
	ProfileSave.finish_match()
	assert_eq(int(ProfileSave.last_summary["xp"]), 1500)
	assert_eq((ProfileSave.last_summary["challenges"] as Array).size(), 1)


func test_match_xp_from_events() -> void:
	GameState.map_id = &"map00_crossroads"
	GameState.character_id = &"wren"
	ProfileSave._on_match_started(&"map00_crossroads")
	ProfileSave._on_enemy_killed(&"ganger", &"torso", &"mp40", 1)
	ProfileSave._on_enemy_killed(&"ganger", &"head", &"mp40_up", 1)
	ProfileSave._on_enemy_killed(&"ganger", &"head", &"mp40", 2)
	ProfileSave._on_round_started(3, false)
	assert_eq(int(ProfileSave.cur_match["xp"]), 10 + 15 + 100)
	ProfileSave.finish_match()
	assert_eq(ProfileSave.weapon_kills(&"mp40"), 2)
	assert_eq(ProfileSave.dossier_xp(&"wren"), 125)
	assert_eq(int(ProfileSave.profile["stats"]["kills"]), 2)
	GameState.character_id = &"dutch"


func test_no_progress_on_test_range() -> void:
	GameState.map_id = &"test_range"
	ProfileSave._on_match_started(&"test_range")
	ProfileSave._on_enemy_killed(&"ganger", &"head", &"mp40", 1)
	ProfileSave.finish_match()
	assert_eq(int(ProfileSave.profile["xp"]), 0)


func test_v1_to_v2_migration() -> void:
	var v1: Dictionary = {"version": 1, "xp": 5000, "rank": 4, "prestige": 0, "dossiers": {"dutch": 0, "peg": 0, "deacon": 0, "wren": 0},
		"weapon_kills": {"kar98k": 12}, "maps_unlocked": ["map00_crossroads", "map01_kaltenbrunn"], "best_round": {"map00_crossroads": 11},
		"intel": ["INT_M0_01"], "stats": {}, "egg_rewards": {}}
	var m: Dictionary = ProfileSave.migrate(v1)
	assert_eq(int(m["version"]), ProfileSave.CURRENT_VERSION, "v1 runs every step (v3: the Muster, T-079)")
	assert_eq(int(m["xp_lifetime"]), 5000)
	assert_eq(int(m["weapon_kills"]["kar98k"]), 12)
	assert_true((m["maps_unlocked"] as Array).has("map01_kaltenbrunn"))
	assert_true(m.has("challenges") and m.has("unlocked") and m.has("equipped"))
	assert_eq(int(m["stats"]["kills"]), 0)


func test_keybind_override_roundtrip() -> void:
	GLSettings.activate()   # Gravelight's bindings exist only in Gravelight mode (T-024)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_K
	assert_true(GLSettings.rebind(&"reload", ev))
	assert_eq(GLSettings.binding_label(&"reload", false), "K")
	GLSettings.overrides = {}
	GLSettings.apply_bindings()
	assert_eq(GLSettings.binding_label(&"reload", false), "R")
	GLSettings.load_settings()
	GLSettings.apply_bindings()
	assert_eq(GLSettings.binding_label(&"reload", false), "K", "override survives a save/load")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	GLSettings.rebind(&"reload", pad)
	assert_eq(GLSettings.binding_label(&"reload", true), "Y")
	assert_eq(GLSettings.binding_label(&"reload", false), "K", "pad rebind leaves the keyboard slot")
	GLSettings.reset_bindings()
	assert_eq(GLSettings.binding_label(&"reload", false), "R")


func test_intel_table() -> void:
	var rows: Array = ProfileSave.intel_rows()
	assert_gt(rows.size(), 30)
	var before: int = int(ProfileSave.profile["xp"])
	ProfileSave._on_intel_found(&"INT_M1_02")
	assert_true(ProfileSave.has_intel("INT_M1_02"))
	assert_eq(int(ProfileSave.profile["xp"]), before + 150)
	ProfileSave._on_intel_found(&"INT_M1_02")
	assert_eq(int(ProfileSave.profile["xp"]), before + 150, "no XP for duplicates")
