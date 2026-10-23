extends GutTest
## The pause OBJECTIVES tab's model (ObjectiveLog, Update 04 section 4, T-066): the spoiler filters at all three
## levels (and that no level ever shows a future step's words), the current-objective rules, side quests (QuestManager
## and flag-tracked), seeded values, B&S, the text data's coverage, and the pause menu's tab shell / map hook.

var data: Dictionary


func before_all() -> void:
	data = ObjectiveLog.load_data()


## A Kaltenbrunn snapshot mid-egg: power on, vault open, the radios / Totenglocke / key steps running.
func _kalt(done: Array, active: Array, extra: Dictionary = {}) -> Dictionary:
	var def: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	var steps: Array = []
	for s: Variant in def["steps"]:
		var sid: String = str((s as Dictionary)["id"])
		var st: String = "complete" if done.has(sid) else ("active" if active.has(sid) else "locked")
		steps.append({"id": sid, "type": str(s["type"]), "status": st, "n": 1 if sid == "s2a_radios" else 0, "target": 3 if sid == "s2a_radios" else (6 if sid == "s2b_switchboard" else -1)})
	var snap: Dictionary = {"map_id": "map01_kaltenbrunn", "round": 12, "power": true, "flags": {"power_on": true, "pylons_attuned": 3, "core_vault_open": true},
		"zones": ["A_MINEHEAD", "E_LIFT", "F_CHAPEL", "G_GENERATOR"], "jakub": "", "exfil_active": false, "settings": {"homage_bosses": true},
		"intel_match": [], "challenges": [],
		"quests": {"map01_requiem": {"title": "Requiem", "complete": false, "steps": steps,
			"random": {"code": "123456", "radios": {"1_surface": "radio_mess_kitchen", "2_depths": "radio_gen_foreman_desk", "3_lab": "radio_lab_intake"}}},
			"map01_song": {"title": "Song", "complete": false, "random": {}, "steps": [
				{"id": "s1_cylinders", "type": "collect", "status": "active", "n": 0, "target": 3},
				{"id": "s2_phonograph", "type": "interact", "status": "locked", "n": -1, "target": -1}]},
			"map01_wren_tag": {"title": "KB", "complete": false, "random": {}, "steps": [{"id": "s1_tag", "type": "interact", "status": "active", "n": -1, "target": -1}]}}}
	snap.merge(extra, true)
	return snap


func _step_text(qid: String, sid: String, key: String) -> String:
	return str(((data["quests"][qid] as Dictionary)["steps"] as Dictionary)[sid].get(key, ""))


func _filled(qid: String, sid: String, key: String) -> String:
	return ObjectiveLog.fill(_step_text(qid, sid, key), {"n": 0, "target": -1}, false)


# ---------------------------------------------------------------- data coverage

func test_every_step_of_every_quest_has_three_texts() -> void:
	var dir: DirAccess = DirAccess.open("res://data/gravelight/quests")
	var n: int = 0
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var def: Dictionary = GLData.load_json("res://data/gravelight/quests/" + f)
		var q: Dictionary = (data["quests"] as Dictionary).get(str(def["id"]), {})
		assert_false(q.is_empty(), "objectives.json has text for %s" % def["id"])
		for s: Variant in def["steps"]:
			var t: Dictionary = (q.get("steps", {}) as Dictionary).get(str(s["id"]), {})
			for key: String in ["done", "hint", "guide"]:
				assert_ne(str(t.get(key, "")).strip_edges(), "", "%s.%s has %s" % [def["id"], s["id"], key])
			n += 1
		var listed: bool = false
		for m: Variant in (data["maps"] as Dictionary).values():
			var md: Dictionary = m
			if (md.get("easter_egg", []) as Array).has(str(def["id"])):
				listed = true
			for sq: Variant in md.get("side", []):
				if str((sq as Dictionary).get("quest", "")) == str(def["id"]):
					listed = true
		assert_true(listed, "%s is on a map's OBJECTIVES tab" % def["id"])
	assert_gt(n, 10, "steps checked")


func test_every_existing_map_has_rules_ending_in_survive() -> void:
	for m: String in ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen"]:
		var rules: Array = data["maps"][m]["current"]
		assert_false((rules.back() as Dictionary).has("done"), "%s ends with an unconditional rule" % m)


# ---------------------------------------------------------------- spoiler filters

func test_hidden_shows_only_completed_steps() -> void:
	var log: Dictionary = ObjectiveLog.build(_kalt(["s0_power", "s1_vault"], ["s2a_radios", "s3_build", "s4_key"]), data, "hidden")
	var txt: String = ObjectiveLog.all_text(log)
	assert_true(txt.contains(_filled("map01_requiem", "s0_power", "done")))
	assert_true(txt.contains(_filled("map01_requiem", "s1_vault", "done")))
	for sid: String in ["s2a_radios", "s3_build", "s4_key"]:
		assert_false(txt.contains(_filled("map01_requiem", sid, "hint")), "no hint for %s" % sid)
		assert_false(txt.contains(_step_text("map01_requiem", sid, "where")), "no location for %s" % sid)
	assert_false(txt.contains(ObjectiveLog.UNKNOWN), "no ??? lines at Hidden")
	# side quests nobody has touched are not listed at all
	assert_false(txt.contains("Lanterns Down Below"))
	assert_false(txt.contains("KB-4471"))


func test_hints_shows_current_hint_and_future_as_unknown() -> void:
	var log: Dictionary = ObjectiveLog.build(_kalt(["s0_power", "s1_vault"], ["s2a_radios", "s3_build", "s4_key"]), data, "hints")
	var txt: String = ObjectiveLog.all_text(log)
	assert_true(txt.contains("Fasbender said the codes are in the radios"), "the radio hint, in character")
	assert_true(txt.contains("(1/3)"), "the hint carries the step's count")
	assert_false(txt.contains("you hear them within 12 m"), "not the Full Guide text")
	assert_true(txt.contains(ObjectiveLog.UNKNOWN))
	var ee: Array = log["sections"][0]["entries"]
	for e: Variant in ee:
		if str((e as Dictionary)["status"]) == "current":
			assert_false(bool(e["locatable"]), "Hints never point at the map")


func test_full_guide_gives_instruction_and_location() -> void:
	var log: Dictionary = ObjectiveLog.build(_kalt(["s0_power", "s1_vault"], ["s2a_radios", "s3_build", "s4_key"]), data, "full")
	var radio: Dictionary = {}
	for e: Variant in log["sections"][0]["entries"]:
		if str((e as Dictionary)["step_id"]) == "s2a_radios":
			radio = e
	assert_true(str(radio["text"]).contains("12 m"))
	assert_eq(str(radio["where"]), _step_text("map01_requiem", "s2a_radios", "where"))
	assert_true(bool(radio["locatable"]))
	assert_true((radio["nodes"] as PackedStringArray).has("Radio_radio_mess_kitchen"), "the seeded radios become map nodes")
	assert_true(bool(radio["bot_candidate"]))


func test_no_level_leaks_a_future_step() -> void:
	var done: Array = ["s0_power", "s1_vault", "s3_build"]
	var active: Array = ["s2a_radios", "s4_key"]
	var def: Dictionary = GLData.load_json("res://data/gravelight/quests/map01_requiem.json")
	for lv: String in ObjectiveLog.LEVELS:
		var txt: String = ObjectiveLog.all_text(ObjectiveLog.build(_kalt(done, active), data, lv))
		for s: Variant in def["steps"]:
			var sid: String = str(s["id"])
			if done.has(sid) or active.has(sid):
				continue
			for key: String in ["done", "hint", "guide", "where"]:
				var t: String = _filled("map01_requiem", sid, key)
				if t.length() > 6:
					assert_false(txt.contains(t), "%s leaks future %s.%s" % [lv, sid, key])


func test_step_view_levels() -> void:
	var t: Dictionary = {"done": "D", "hint": "H {n}/{target}", "guide": "G", "where": "W"}
	assert_eq(ObjectiveLog.step_view(t, "current", "hidden"), {})
	assert_eq(ObjectiveLog.step_view(t, "future", "hidden"), {})
	assert_eq(str(ObjectiveLog.step_view(t, "current", "hints", {"n": 2, "target": 3})["text"]), "H 2/3")
	assert_eq(str(ObjectiveLog.step_view(t, "current", "full")["where"]), "W")
	assert_eq(str(ObjectiveLog.step_view(t, "future", "full")["text"]), ObjectiveLog.UNKNOWN)
	assert_eq(str(ObjectiveLog.step_view(t, "done", "hidden")["text"]), "D")
	assert_eq(ObjectiveLog.level("bogus"), "hints", "junk falls back to the default")


func test_seeded_code_only_in_full_guide() -> void:
	var done: Array = ["s0_power", "s1_vault", "s2a_radios"]
	var full: String = ObjectiveLog.all_text(ObjectiveLog.build(_kalt(done, ["s2b_switchboard"]), data, "full"))
	assert_true(full.contains("12 34 56"), "the heard code, in pairs")
	for lv: String in ["hidden", "hints"]:
		assert_false(ObjectiveLog.all_text(ObjectiveLog.build(_kalt(done, ["s2b_switchboard"]), data, lv)).contains("12 34 56"))
	assert_eq(ObjectiveLog.fill("x {rand:code}", {"rand": {"code": "1"}}, false), "x ???")


# ---------------------------------------------------------------- current objective

func test_current_objective_kaltenbrunn() -> void:
	var rules: Array = data["maps"]["map01_kaltenbrunn"]["current"]
	var s: Dictionary = {"round": 3, "power": false, "flags": {}, "zones": ["A_MINEHEAD"]}
	assert_string_contains(str(ObjectiveLog.current_objective(s, rules)["title"]), "Generator Hall")
	s["zones"] = ["A_MINEHEAD", "G_GENERATOR"]
	assert_string_contains(str(ObjectiveLog.current_objective(s, rules)["title"]), "Hauptschalter")
	s["power"] = true
	s["flags"] = {"power_on": true, "pylons_attuned": 1}
	var cur: Dictionary = ObjectiveLog.current_objective(s, rules)
	assert_eq(str(cur["title"]), "Attune the 3 Resonance Pylons (1/3)")
	assert_almost_eq(float(cur["progress"]), 1.0 / 3.0, 0.01)
	s["flags"]["core_vault_open"] = true
	assert_string_contains(str(ObjectiveLog.current_objective(s, rules)["title"]), "Survive to round 30 (round 3 of 30)")
	s["exfil_active"] = true
	assert_string_contains(str(ObjectiveLog.current_objective(s, rules)["title"]), "North Gate")


func test_current_objective_inn_and_unknown_map() -> void:
	var rules: Array = data["maps"]["map00_crossroads"]["current"]
	assert_string_contains(str(ObjectiveLog.current_objective({"zones": ["TAPROOM"]}, rules)["title"]), "cellar")
	assert_string_contains(str(ObjectiveLog.current_objective({"zones": ["TAPROOM", "CELLAR"]}, rules)["title"]), "cellar lever")
	assert_string_contains(str(ObjectiveLog.current_objective({"power": true, "round": 11}, rules)["title"]), "Survive.")
	var log: Dictionary = ObjectiveLog.build({"map_id": "map_future"}, data, "hints")
	assert_eq(str(log["current"]["title"]), "Survive.", "a map without data still builds")


# ---------------------------------------------------------------- side quests

func test_jakub_escape_tracking() -> void:
	var def: Dictionary = (data["maps"]["map00_crossroads"]["side"] as Array)[0]
	assert_eq(str(def["id"]), "jakub_escape")
	var caged: Array = ObjectiveLog.tracked_entries(def, {"jakub": "caged", "zones": []}, "hints")
	assert_eq(str(caged[1]["status"]), "current")
	assert_string_contains(str(caged[1]["title"]), "calling from under the floor")
	assert_eq(str(caged[2]["title"]), ObjectiveLog.UNKNOWN)
	var waiting: Array = ObjectiveLog.tracked_entries(def, {"jakub": "waiting", "zones": ["OLD_CELLAR"]}, "full")
	assert_eq(str(waiting[1]["status"]), "done")
	assert_eq(str(waiting[2]["status"]), "done")
	assert_eq(str(waiting[3]["status"]), "current")
	assert_true(bool(waiting[3]["locatable"]))
	var joined: Array = ObjectiveLog.tracked_entries(def, {"jakub": "joined", "zones": ["OLD_CELLAR"]}, "hidden")
	assert_string_contains(str(joined[0]["title"]), "✔")
	assert_eq(ObjectiveLog.tracked_entries(def, {"jakub": ""}, "full"), [], "no Jakub on this map, no entry")
	assert_eq(ObjectiveLog.tracked_entries(def, {"jakub": "caged"}, "hidden").size(), 2, "public: header + nothing yet")


func test_cousins_room_respects_the_setting() -> void:
	var def: Dictionary = (data["maps"]["map00_crossroads"]["side"] as Array)[1]
	assert_eq(ObjectiveLog.tracked_entries(def, {"settings": {"homage_bosses": false}}, "hidden"), [])
	var off: Array = ObjectiveLog.tracked_entries(def, {"settings": {"homage_bosses": false}}, "hints")
	assert_string_contains(str(off[1]["title"]), "Off in Settings")
	var done: Array = ObjectiveLog.tracked_entries(def, {"settings": {"homage_bosses": true}, "round": 10, "flags": {"passage_ice_cellar_open": true}}, "hints")
	assert_string_contains(str(done[2]["title"]), "chalk drawings")
	assert_eq(ObjectiveLog.tracked_entries(def, {"settings": {"homage_bosses": true}, "round": 2}, "hidden"), [], "an untouched secret stays unlisted")


func test_quest_side_quest_listed_once_started_at_hidden() -> void:
	var s: Dictionary = _kalt([], ["s0_power"])
	s["quests"]["map01_song"]["steps"][0]["status"] = "complete"
	s["quests"]["map01_song"]["steps"][1]["status"] = "active"
	var txt: String = ObjectiveLog.all_text(ObjectiveLog.build(s, data, "hidden"))
	assert_true(txt.contains("Lanterns Down Below"))
	assert_true(txt.contains(_filled("map01_song", "s1_cylinders", "done")))
	assert_false(txt.contains("Reinholt's office"))


func test_conditions() -> void:
	var s: Dictionary = {"flags": {"a": true, "n": 2, "z": 0}, "zones": ["X"], "round": 4, "jakub": "joined"}
	assert_true(ObjectiveLog.eval({"flag": "a"}, s))
	assert_false(ObjectiveLog.eval({"flag": "z"}, s))
	assert_true(ObjectiveLog.eval({"flag_at_least": ["n", 2]}, s))
	assert_true(ObjectiveLog.eval({"all": [{"zone_open": "X"}, {"round_at_least": 4}]}, s))
	assert_true(ObjectiveLog.eval({"not": {"jakub_in": ["caged"]}}, s))
	assert_false(ObjectiveLog.eval({"typo_key": true}, s), "unknown conditions never pass")


func test_challenges_and_intel_entries() -> void:
	var ch: Array = ObjectiveLog.challenge_entries([{"id": "c", "name": "Last Orders", "desc": "Reach round 10", "progress": 4, "target": 10, "scope": "match", "xp": 2000}])
	assert_eq(str(ch[0]["progress_text"]), "4/10")
	assert_almost_eq(float(ch[0]["progress"]), 0.4, 0.001)
	assert_string_contains(str(ObjectiveLog.challenge_entries([])[0]["title"]), "No challenges")
	var it: Array = ObjectiveLog.intel_entries([{"id": "INT_M0_01", "title": "The Innkeeper's Notebook", "text": "..."}])
	assert_eq(str(it[0]["intel_id"]), "INT_M0_01")
	assert_string_contains(str(ObjectiveLog.intel_entries([])[0]["title"]), "No intel")


# ---------------------------------------------------------------- Bolt & Sprocket

func test_bs_planet_log() -> void:
	var snap: Dictionary = {"game": "bs", "planet": "Nova Plaza", "mission": "Get an HOA Variance",
		"quests": [{"id": "q1", "name": "Mutt Census", "state": "active", "k": 2, "n": 4, "npc": "Rusty"},
			{"id": "q2", "name": "Secret Thing", "state": "none", "npc": "Gus", "npc_pos": [1, 0, 2]}],
		"gold": [{"id": "g1", "found": true, "how": "x"}, {"id": "g2", "found": false, "how": "HOA Clubhouse roof (source left gold (-30, 11, -66)): Tether-Hook along the lamp posts", "p": [0, 1, 2]}],
		"memos": [{"id": "m1", "found": false, "where": "the fountain"}], "challenges": []}
	var hints: Dictionary = ObjectiveLog.build(snap, data, "hints")
	var ht: String = ObjectiveLog.all_text(hints)
	assert_eq(str(hints["current"]["title"]), "Get an HOA Variance")
	assert_true(ht.contains("Mutt Census (2/4)"))
	assert_false(ht.contains("Secret Thing"), "an unstarted quest is ??? at Hints")
	assert_false(ht.contains("Clubhouse"), "gold spots only at Full Guide")
	assert_true(ht.contains("Gold bolts found: 1 / 2"))
	var ft: String = ObjectiveLog.all_text(ObjectiveLog.build(snap, data, "full"))
	assert_true(ft.contains("HOA Clubhouse roof: Tether-Hook along the lamp posts"), "the dev coordinates are stripped")
	assert_false(ft.contains("source"))
	assert_true(ft.contains("Secret Thing: talk to Gus"))
	assert_false(ObjectiveLog.all_text(ObjectiveLog.build(snap, data, "hidden")).contains("???"))


# ---------------------------------------------------------------- the pause menu shell

class FakeGun:
	extends RefCounted
	var attachments: Dictionary = {"barrel": "compensator", "magazine": "drum_mag", "sights": ""}


class FakeMapView:
	extends Control
	var marks: Array = []
	func highlight_location(p: Vector3, f: StringName, label: String) -> void:
		marks.append([p, f, label])


func test_attachment_text() -> void:
	assert_eq(PauseMenu.attachment_text(FakeGun.new()), "Barrel: Compensator, Magazine: Drum Mag")
	assert_eq(PauseMenu.attachment_text(null), "")


func test_pause_tabs_and_map_hook() -> void:
	var pm: PauseMenu = PauseMenu.new()
	add_child_autofree(pm)
	assert_eq(pm.tab_name(), "MAP", "opens on the map")
	pm.set_tab(PauseMenu.TAB_QUIT + 1)
	assert_eq(pm.tab_name(), "MAP", "tabs wrap")
	pm.set_tab(-1)
	assert_eq(pm.tab_name(), "QUIT")
	pm.set_tab(PauseMenu.TAB_OBJECTIVES)
	assert_eq(pm.tab_name(), "OBJECTIVES")
	var view: FakeMapView = FakeMapView.new()
	pm.set_map_view(view)
	assert_eq(pm.map_view(), view)
	watch_signals(pm)
	pm.show_location(Vector3(1, 2, 3), &"", "Pylon", true)
	assert_signal_emitted(pm, "location_requested")
	assert_eq(view.marks.size(), 1)
	assert_eq(pm.tab_name(), "MAP", "Show on map switches to the MAP tab")
	assert_false(get_tree().paused, "building the menu never pauses")
