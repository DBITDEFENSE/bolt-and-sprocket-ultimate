extends GutTest
## T-181 Easter Egg Mode (EggMode): the round queue, the caps, the round clock, the crawler health, the profile
## guard, the data block; and that normal mode never changes (the counts and the rules return the normal value).

var c: Dictionary
var _saved_mode: String
var _saved_setting: Variant
var _saved_phase: int


func before_all() -> void:
	c = EggMode.cfg()


func before_each() -> void:
	_saved_mode = GameState.egg_mode
	_saved_setting = GLSettings.values.get(EggMode.SETTING, "off")
	_saved_phase = GameState.phase


func after_each() -> void:
	GameState.egg_mode = _saved_mode
	GLSettings.values[EggMode.SETTING] = _saved_setting
	GameState.phase = _saved_phase as GameState.Phase
	ProfileSave.practice = false


func test_data_block() -> void:
	assert_false(c.is_empty(), "rounds.json egg_mode")
	for k: String in ["count", "round_max_s", "round_s", "hold_active", "feed_active", "feed_interval_s", "feed_step_types", "health_round_cap"]:
		assert_true(c.has(k), "egg_mode.%s" % k)
	assert_eq(EggMode.MODES.size(), EggMode.MODE_LABELS.size())
	assert_eq(str(GLSettings.values.get(EggMode.SETTING, "off")) in EggMode.MODES, true)


func test_mode_of_falls_back_to_off() -> void:
	assert_eq(EggMode.mode_of({}), "off")
	assert_eq(EggMode.mode_of({"egg_mode": "sparse"}), "sparse")
	assert_eq(EggMode.mode_of({"egg_mode": "none"}), "none")
	assert_eq(EggMode.mode_of({"egg_mode": "lots"}), "off", "an unknown value is off")


func test_round_count() -> void:
	var cc: Dictionary = {"count": {"base": 2, "per_rounds": 10, "max": 4}}
	assert_eq(EggMode.round_count("off", 12, 40, cc), 40, "off: the normal count")
	assert_eq(EggMode.round_count("none", 12, 40, cc), 0, "none: no queue")
	assert_eq(EggMode.round_count("sparse", 1, 6, cc), 2)
	assert_eq(EggMode.round_count("sparse", 11, 40, cc), 3)
	assert_eq(EggMode.round_count("sparse", 21, 60, cc), 4)
	assert_eq(EggMode.round_count("sparse", 60, 300, cc), 4, "never past max")
	assert_eq(EggMode.round_count("sparse", 1, 1, cc), 1, "never past the normal count")


func test_extra_cap() -> void:
	var cc: Dictionary = {"feed_active": 6, "hold_active": {"sparse": 3, "none": 0}}
	assert_eq(EggMode.extra_cap("off", true, true, cc), -1, "off: not this rule")
	assert_eq(EggMode.extra_cap("sparse", false, false, cc), 0, "nothing open: no top-up")
	assert_eq(EggMode.extra_cap("sparse", true, false, cc), 3, "a hold: a few crawlers")
	assert_eq(EggMode.extra_cap("none", true, false, cc), 0, "No Zombies: a hold is quiet too")
	assert_eq(EggMode.extra_cap("none", false, true, cc), 6, "a kill-count step is fed in every mode")
	assert_eq(EggMode.extra_cap("sparse", true, true, cc), 6, "the feed beats the hold")


func test_round_over() -> void:
	var cc: Dictionary = {"round_max_s": 60.0, "round_s": 25.0}
	assert_false(EggMode.round_over("off", 999.0, 0, 0, false, cc), "off: the normal rules")
	assert_false(EggMode.round_over("sparse", 5.0, 1, 0, false, cc), "a queued crawler: not over")
	assert_true(EggMode.round_over("sparse", 61.0, 2, 4, false, cc), "out of time with crawlers still queued (the cap full of old ones): over")
	assert_true(EggMode.round_over("sparse", 5.0, 0, 0, false, cc), "the crawlers died: over")
	assert_false(EggMode.round_over("sparse", 30.0, 0, 2, false, cc), "two crawlers up, early: not yet")
	assert_true(EggMode.round_over("sparse", 61.0, 0, 2, false, cc), "the round ran its time: over, crawlers or not")
	assert_false(EggMode.round_over("sparse", 999.0, 0, 0, true, cc), "a hold keeps the round open")
	assert_false(EggMode.round_over("none", 10.0, 0, 0, false, cc), "No Zombies: the round lasts round_s")
	assert_true(EggMode.round_over("none", 26.0, 0, 3, false, cc), "then it ends")


func test_health_round_and_feed_types() -> void:
	assert_eq(EggMode.health_round(1, c), 1)
	assert_eq(EggMode.health_round(40, c), int(c["health_round_cap"]))
	assert_true(EggMode.feeds("kill_count", c), "Requiem's 30 Totenglocke kills are fed")
	assert_false(EggMode.feeds("flag", c))


func test_current_follows_the_match_then_the_setting() -> void:
	GameState.phase = GameState.Phase.PLAYING
	GameState.egg_mode = "sparse"
	GLSettings.values[EggMode.SETTING] = "off"
	assert_eq(EggMode.current(), "sparse", "in a match: the mode it started with (a mid-match change waits)")
	assert_true(EggMode.on())
	GameState.phase = GameState.Phase.MENU
	assert_eq(EggMode.current(), "off", "out of a match (a map loading): the setting")
	GLSettings.values[EggMode.SETTING] = "none"
	assert_eq(EggMode.current(), "none")


func test_round_manager_specs_are_crawlers_only_in_egg_mode() -> void:
	GameState.phase = GameState.Phase.PLAYING
	GameState.egg_mode = "off"
	var spec: Dictionary = RoundManager._egg_spec({"tier": &"sprint", "health": 5000})
	assert_false(spec.has("crawler"), "normal mode: the spec is untouched")
	assert_eq(int(spec["health"]), 5000)
	GameState.egg_mode = "sparse"
	spec = RoundManager._egg_spec({"tier": &"sprint", "health": 5000})
	assert_true(bool(spec.get("crawler", false)))
	assert_eq(spec["tier"], &"shamble")
	assert_lte(int(spec["health"]), RoundManager.zombie_health(int(c["health_round_cap"]), GLData.table("rounds")))


func test_practice_blocks_profile_progress() -> void:
	var saved: Dictionary = ProfileSave.profile.duplicate(true)
	var saved_path: String = ProfileSave.path
	ProfileSave.path = "user://test_egg_mode_profile.json"
	var xp0: int = int(ProfileSave.profile.get("xp", 0))
	ProfileSave.practice = true
	ProfileSave.add_xp(5000)
	assert_eq(int(ProfileSave.profile.get("xp", 0)), xp0, "no XP in practice")
	ProfileSave.unlock_map(&"map_t181_test")
	assert_false(ProfileSave.is_map_unlocked(&"map_t181_test"), "no map unlock in practice")
	ProfileSave._on_quest_completed(&"map01_requiem")
	assert_eq(bool((ProfileSave.profile.get("egg_rewards", {}) as Dictionary).get("map01_requiem", false)),
		bool((saved.get("egg_rewards", {}) as Dictionary).get("map01_requiem", false)), "no egg reward in practice")
	ProfileSave.profile = saved
	ProfileSave.path = saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_egg_mode_profile.json"))


func test_bank_shut_in_practice() -> void:
	GameState.phase = GameState.Phase.PLAYING
	GameState.egg_mode = "none"
	var classic: Variant = GLSettings.values.get("classic_rules", false)
	GLSettings.values["classic_rules"] = false
	assert_eq(BankAccount.closed_reason(), "practice")
	GameState.egg_mode = "off"
	assert_eq(BankAccount.closed_reason(), "")
	GLSettings.values["classic_rules"] = classic



func test_feed_points() -> void:
	assert_eq(EggMode.feed_points({}).size(), 0, "no feed_points: the map's own spawns")
	var pts: Array = EggMode.feed_points({"feed_points": [[1, 2, 3], [4, 5]]})
	assert_eq(pts.size(), 1, "a short entry is skipped")
	assert_eq(pts[0], Vector3(1, 2, 3))
	var q: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	for s: Variant in q.get("steps", []):
		if str((s as Dictionary).get("id", "")) == "s8b_charge":
			assert_gte(EggMode.feed_points((s as Dictionary).get("params", {})).size(), 3, "Requiem s8b feeds crawlers by the heart")
