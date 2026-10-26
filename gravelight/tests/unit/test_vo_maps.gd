extends GutTest
## Map lines only play on their own map (T-057): on Map 0 a bot said "Kaltenbrunn. Right. Weapons ready..." (a
## Map 1 spawn line). Every category's draw is checked on every map, so no line tagged for another map is picked.

const MAPS: Array[StringName] = [&"map00_crossroads", &"map01_kaltenbrunn", &"map02_totenhafen", &"map04a_thalbach", &"map04b_kranich", &"map04c_groomlake", &"map04d_mondlicht"]

var _map_before: StringName


func before_each() -> void:
	_map_before = GameState.map_id
	GLVO.always_pass_chance = true
	GLVO.reset_match()


func after_each() -> void:
	GameState.map_id = _map_before
	GLVO.always_pass_chance = false
	GLVO.reset_match()


func test_tagging() -> void:
	var r: Dictionary = GLVO.rules
	assert_eq(GLVO.line_map_of("PEG_SPAWN_01", GLVO.lines["PEG_SPAWN_01"], r), "map01", "listed in rules.json map_lines")
	assert_eq(GLVO.line_map_of("PEG_SPAWN_02", GLVO.lines["PEG_SPAWN_02"], r), "", "a generic spawn line")
	assert_eq(GLVO.line_map_of("FAS_M0_R6_01", GLVO.lines["FAS_M0_R6_01"], r), "map00", "M0 token in the category")
	assert_eq(GLVO.line_map_of("OPR_POWER_ON_M2_01", GLVO.lines["OPR_POWER_ON_M2_01"], r), "map02", "M2 token")
	assert_eq(GLVO.line_map_of("OPR_ROUND_END_06", GLVO.lines["OPR_ROUND_END_06"], r), "map01", "'Map 1, power on' condition")


## The survivors' Kaltenbrunn lines (and every other line that names the place) are map lines.
func test_every_kaltenbrunn_line_is_a_map_line() -> void:
	# rules.json any_map_lines: the place named as the past or a destination (Jakub escaped from it), not as here
	var any_map: Array = (GLVO.rules.get("any_map_lines", {}) as Dictionary).get("ids", [])
	for id: Variant in GLVO.lines.keys():
		var rec: Dictionary = GLVO.lines[id]
		if str(rec.get("text", "")).contains("Kaltenbrunn") and not any_map.has(str(id)):
			assert_ne(GLVO.line_map_of(str(id), rec, GLVO.rules), "", "%s names Kaltenbrunn but plays on any map" % id)


## Draw every category dry on every map: nothing tagged for another map ever comes out.
func test_no_other_map_line_is_drawn() -> void:
	var keys: Array = GLVO._index.keys()
	assert_gt(keys.size(), 100)
	for m: StringName in MAPS:
		GameState.map_id = m
		GLVO.reset_match()
		var bad: Array[String] = []
		for key: Variant in keys:
			var n: int = (GLVO._index[key] as Array).size()
			for i: int in n + 1:
				var id: StringName = GLVO._draw(str(key))
				if id == &"":
					break
				var lm: String = GLVO.line_map_of(String(id), GLVO.lines[String(id)], GLVO.rules)
				if lm != "" and not String(m).begins_with(lm):
					bad.append(String(id))
		assert_eq(bad, [] as Array[String], "%s drew other maps' lines: %s" % [m, bad])


## The bug itself: Peg's spawn line on Map 0, many times over.
func test_peg_spawn_on_map0_never_kaltenbrunn() -> void:
	GameState.map_id = &"map00_crossroads"
	for i: int in 12:
		GLVO.reset_match()
		var id: StringName = GLVO._draw("PEG:SPAWN")
		assert_ne(id, &"PEG_SPAWN_01")
		assert_ne(id, &"")
	GameState.map_id = &"map01_kaltenbrunn"
	var seen: Dictionary = {}
	for i: int in 12:
		GLVO.reset_match()
		seen[GLVO._draw("PEG:SPAWN")] = true
	assert_true(seen.has(&"PEG_SPAWN_01"), "still plays on Map 1")


## Round-specific Operator lines (round 25's "...at Kaltenbrunn") skip other maps too.
func test_round_line_respects_map() -> void:
	GameState.map_id = &"map00_crossroads"
	assert_false(GLVO.map_ok(&"OPR_ROUND_START_09"))
	GameState.map_id = &"map01_kaltenbrunn"
	assert_true(GLVO.map_ok(&"OPR_ROUND_START_09"))
