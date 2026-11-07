extends GutTest
## T-194 (UPDATE 11 "LAZARUS"): the four LAZARUS cutscenes and the Moscow 1953 card (data/gravelight/cutscenes_lazarus.json,
## docs/CUTSCENES_LAZARUS.md). Each definition validates; every shot's stage, effect and aimed-at node exists on its built
## stage; every line is a cutscene line in lines.json and none talks over another at reading speed; the lengths are the
## shot lists' (+-15 %); the cards read exactly; the hooks (first launch, the campaign's start and Kaltenbrunn's
## arrival, the standalone rule); the GL1 seats; the Gore setting's variants; a reel plays and skips to its end.

const SHOT_LIST_SECONDS: Dictionary = {"lazarus_saturday": 224.0, "fourth_day": 95.0, "staub": 64.0, "gravelight_one": 78.0, "epilogue_1953": 22.0}
const CATEGORIES: Dictionary = {"lazarus_saturday": "LZS", "fourth_day": "FTD", "staub": "STB", "gravelight_one": "GL1"}

var _lines: Dictionary = {}
var _gore_was: String = "full"


func before_all() -> void:
	_lines = GLData.load_json("res://data/gravelight/vo/lines.json")
	_gore_was = str(GLSettings.values.get("gore", "full"))


func after_each() -> void:
	Campaign.cutscene_speed = 1.0
	GLSettings.values["gore"] = _gore_was
	LazarusCinema.force = false
	LazarusCinema.force_ids = []
	CinemaTheatre.force_prologue = false


func _defs() -> Dictionary:
	return CinemaLibrary.data().get("cutscenes", {})


func _stage(set_id: String, gore: String = "full", roster: Array = []) -> CinemaSet:
	GLSettings.values["gore"] = gore
	var ps: PackedScene = load(CinemaLibrary.stage_path(set_id)) as PackedScene
	var s: CinemaSet = ps.instantiate() as CinemaSet
	s.variant = str((CinemaLibrary.data().get("set_variants", {}) as Dictionary).get(set_id, ""))
	s.set_meta("roster", CinemaLibrary.seat_roster(roster))
	s.build()
	return s


# ---------------------------------------------------------------- the definitions

func test_all_five_are_there() -> void:
	for id: String in SHOT_LIST_SECONDS.keys():
		assert_true(CinemaLibrary.has_cut(id), id)


func test_every_definition_validates() -> void:
	for id: Variant in _defs().keys():
		var d: Dictionary = CinemaLibrary.resolved(str(id), ["dutch"])
		var errs: PackedStringArray = CinemaDirector.validate(d, _lines)
		assert_eq(errs.size(), 0, "%s: %s" % [str(id), ", ".join(errs)])


func test_lengths_are_the_shot_lists_within_15_percent() -> void:
	for id: String in SHOT_LIST_SECONDS.keys():
		var secs: float = float((_defs()[id] as Dictionary).get("seconds", 0.0))
		var want: float = float(SHOT_LIST_SECONDS[id])
		assert_true(absf(secs - want) <= want * 0.15, "%s: %.1f s against the shot list's %.1f s" % [id, secs, want])


func test_lenses_stay_between_24_and_70() -> void:
	for id: Variant in _defs().keys():
		for s: Variant in (_defs()[id] as Dictionary).get("shots", []):
			var f: float = float((s as Dictionary).get("fov", 60.0))
			assert_true(f >= 24.0 and f <= 70.0, "%s at %.1f: fov %.0f" % [str(id), float(s["t"]), f])


func test_every_line_is_a_cutscene_line_in_lines_json() -> void:
	for id: Variant in _defs().keys():
		var ids: Array[String] = CinemaLibrary.line_ids(_defs()[id] as Dictionary)
		if CATEGORIES.has(str(id)):
			assert_gt(ids.size(), 0, "%s says something" % str(id))
		for lid: String in ids:
			assert_true(_lines.has(lid), "%s: %s is in lines.json" % [str(id), lid])
			var cat: String = str(CATEGORIES.get(str(id), "-"))
			assert_true(lid.contains("_%s_" % cat) or lid.begins_with("RTN_CLOSE_"), "%s: %s is one of its own lines" % [str(id), lid])
	assert_eq(CinemaLibrary.line_ids(_defs()["epilogue_1953"] as Dictionary).size(), 0, "the Moscow card is not voiced")


## The subtitles keep to the timeline: no line starts while another of the same voice channel is still being read
## (the reading-speed estimate when a line has no audio yet; T-201 bakes them later), so nothing queues and drifts.
func test_no_line_talks_over_another_at_reading_speed() -> void:
	var rules: Dictionary = GLData.load_json("res://data/gravelight/vo/rules.json")
	var player: Array = rules.get("player_speakers", [])
	for id: Variant in _defs().keys():
		for who: String in CinemaLibrary.SQUAD:
			var d: Dictionary = CinemaLibrary.resolved(str(id), [who, "peg" if who != "peg" else "wren"])
			var ev: Array = []
			for s: Variant in d.get("shots", []):
				for le: Variant in (s as Dictionary).get("lines", []):
					ev.append([float(s["t"]) + float(le[0]), str(le[1])])
			ev.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			var busy: Dictionary = {}
			for e: Array in ev:
				var rec: Dictionary = _lines.get(e[1], {})
				var spk: String = str(rec.get("speaker", ""))
				var ch: String = spk if player.has(spk) else "story"
				var dur: float = GLVO.duration_for(GLVO.strip_tags(str(rec.get("text", ""))), rules)
				assert_true(float(e[0]) >= float(busy.get(ch, -1.0)) - 0.05, "%s (%s): %s at %.1f starts before the last line ends (%.1f)" % [str(id), who, e[1], float(e[0]), float(busy.get(ch, -1.0))])
				busy[ch] = float(e[0]) + dur
			assert_true(float(busy.get("story", 0.0)) <= float(d["seconds"]), "%s: the last line ends before the cutscene" % str(id))


func test_the_cards_read_exactly() -> void:
	var want: Dictionary = {
		"lazarus_saturday": [["CHETVERODNEVO", "a village a long day's cart from the district town", "Lazarus Saturday  ·  12 April 1930"], ["The fourth day.", "", ""], ["Chetverodnevo is not on any map.", "", ""]],
		"fourth_day": [["EAST PRUSSIA", "the East Prussian line · the German line", "October 1944  ·  rain"], ["Four days later.", "", ""]],
		"staub": [["KALTENBRUNN", "Staubmühle II · Projekt Wiederkehr", "20 December 1944  ·  21:50"]],
		"gravelight_one": [["GRAVELIGHT ONE", "a C-47 out of Brindisi · over the Silesian front", "23 December 1944  ·  23:10"]],
		"epilogue_1953": [["MOSCOW", "Laboratory No. 4 · the vault", "1953"], ["The vessel is still there.", "", ""], ["It is still wet.", "", ""]],
	}
	for id: String in want.keys():
		assert_eq(CinemaLibrary.cards(_defs()[id] as Dictionary), want[id], id)


func test_cards_and_captions_are_latin_letters_only() -> void:
	for id: Variant in _defs().keys():
		var texts: Array = []
		for c: Variant in CinemaLibrary.cards(_defs()[id] as Dictionary):
			texts.append_array(c as Array)
		for s: Variant in (_defs()[id] as Dictionary).get("shots", []):
			if (s as Dictionary).has("caption"):
				texts.append(str(s["caption"].get("text", "")))
		for t: Variant in texts:
			for i: int in str(t).length():
				var u: int = str(t).unicode_at(i)
				assert_false(u >= 0x0400 and u <= 0x04FF, "%s: no Cyrillic in a UI face (%s)" % [str(id), str(t)])


func test_the_moscow_card_is_cards_m4_moscow53() -> void:
	var m4: Dictionary = GLData.load_json("res://data/gravelight/cards_m4.json")
	var m53: Array = (m4.get("cards", {}) as Dictionary).get("moscow53", [])
	assert_eq(m53.size(), 3, "cards.moscow53 has the three cards of MAP4_FERNFLUG §12.11")
	assert_false((m4.get("card_order", []) as Array).has("moscow53"), "never among KÜNDIGUNG's own cards: it plays after the credits")
	var cap: String = ""
	for s: Variant in (_defs()["epilogue_1953"] as Dictionary).get("shots", []):
		if (s as Dictionary).has("caption"):
			cap = str(s["caption"]["text"])
	assert_eq(cap, str(m53[1]), "the image's caption is the second card")
	var last: Array = CinemaLibrary.cards(_defs()["epilogue_1953"] as Dictionary)
	assert_eq("%s %s" % [last[1][0], last[2][0]], str(m53[2]), "the last two cards are the third")


# ---------------------------------------------------------------- the stages

func test_every_shot_has_its_stage_its_effects_and_its_nodes() -> void:
	for id: Variant in _defs().keys():
		var d: Dictionary = _defs()[id]
		for sid: String in CinemaLibrary.sets_in(d):
			var path: String = CinemaLibrary.stage_path(sid)
			assert_true(path != "" and ResourceLoader.exists(path), "%s: the stage %s (%s)" % [str(id), sid, path])
			if path == "" or not ResourceLoader.exists(path):
				continue
			var st: CinemaSet = _stage(sid)
			for s: Variant in d.get("shots", []):
				var sh: Dictionary = s
				if str(sh.get("_set", "")) != sid:
					continue
				var fxs: Array = []
				var f: Variant = sh.get("fx", null)
				if f is String:
					fxs.append(f)
				elif f is Array:
					fxs.append_array(f)
				for fa: Variant in sh.get("fx_at", []):
					fxs.append(str((fa as Array)[1]))
				for fn: Variant in fxs:
					assert_true(st.has_fx(str(fn)), "%s at %.1f: the stage %s has the effect %s" % [str(id), float(sh["t"]), sid, str(fn)])
				for key: String in ["target", "rel"]:
					var n: String = str(sh.get(key, ""))
					if n != "":
						assert_not_null(st.find_child(n, true, false), "%s at %.1f: %s '%s' is on the stage %s" % [str(id), float(sh["t"]), key, n, sid])
			st.free()


func test_the_gl1_seats_are_the_squad() -> void:
	assert_eq(CinemaLibrary.seat_roster(["wren"]), ["wren", "dutch", "peg", "deacon"] as Array[String], "the window seat is the first human's; the rest fill in")
	assert_eq(CinemaLibrary.seat_roster(["peg", "peg", "deacon", "jakub"]), ["peg", "deacon", "dutch", "wren"] as Array[String], "no one twice, only the four")
	var d: Dictionary = CinemaLibrary.resolved("gravelight_one", ["deacon", "wren"])
	var said: Array = []
	for s: Variant in d["shots"]:
		for le: Variant in (s as Dictionary).get("lines", []):
			said.append(str(le[1]))
	assert_true(said.has("DEA_GL1_01"), "the window line is the first seat's")
	assert_true(said.has("WRN_GL1_02"), "the second line is the second seat's")
	var c47: CinemaSet = _stage("c47", "full", ["deacon", "wren"])
	assert_not_null(c47.find_child("Passenger_0", true, false), "four passengers")
	assert_not_null(c47.find_child("Passenger_3", true, false))
	c47.free()


func test_the_risen_come_from_the_one_seam() -> void:
	var r: CinemaRisen = CinemaRisen.make("soviet_greatcoat", 7)
	assert_not_null(r.body, "a body on the zombie rig")
	assert_false(r.is_in_group(&"zombies"), "presentation only")
	assert_eq(r.find_children("*", "CollisionObject3D", true, false).size(), 0, "no hitboxes, no collider")
	r.free()
	assert_eq(str(CinemaLibrary.data().get("risen_kind", "")), "soviet_greatcoat", "the data key T-192's skins plug into")


# ---------------------------------------------------------------- gore

func test_the_vessel_follows_the_gore_setting() -> void:
	for g: String in ["off", "low", "full"]:
		var st: CinemaSet = _stage("crypt", g)
		var dark: Node3D = st.find_child("Dark", true, false) as Node3D
		var red: Node3D = st.find_child("Red", true, false) as Node3D
		var drop: Node3D = st.find_child("DropBead", true, false) as Node3D
		assert_eq(dark.visible, g == "off", "%s: dark and wet only with Gore off" % g)
		assert_eq(red.visible, g != "off", "%s: red on low and full" % g)
		assert_eq(drop.visible, g == "full", "%s: the drop runs only on full" % g)
		st.free()
	for g2: String in ["off", "low", "full"]:
		var w: CinemaSet = _stage("ward", g2)
		assert_eq((w.find_child("Stain", true, false) as Node3D).visible, g2 == "full", "%s: the sheet's stain only on full" % g2)
		w.free()
		var r: CinemaSet = _stage("rear", g2)
		assert_eq((r.find_child("Stain", true, false) as Node3D).visible, g2 == "full", "%s: the mound's stain only on full" % g2)
		r.free()


# ---------------------------------------------------------------- the hooks

func test_the_plan_for_a_match_start() -> void:
	var h: Dictionary = LazarusCinema.hooks()
	assert_eq(LazarusCinema.plan("map00_crossroads", {"campaign": true, "fresh_start": true}, h), ["fourth_day", "gravelight_one"] as Array[String], "a new campaign")
	assert_eq(LazarusCinema.plan("map01_kaltenbrunn", {"campaign": true, "arriving_from": "map00_crossroads"}, h), ["staub"] as Array[String], "Kaltenbrunn's arrival")
	assert_eq(LazarusCinema.plan("map01_kaltenbrunn", {"campaign": true, "arriving_from": "map00_crossroads", "seen": ["staub"]}, h), ["staub"] as Array[String], "the campaign arrival plays it every time")
	assert_eq(LazarusCinema.plan("map00_crossroads", {"campaign": true, "fresh_start": false}, h).size(), 0, "a dev start elsewhere in the chain")
	assert_eq(LazarusCinema.plan("map02_totenhafen", {"campaign": true, "arriving_from": "map01_kaltenbrunn"}, h).size(), 0, "no other arrival")
	assert_eq(LazarusCinema.plan("map00_crossroads", {"campaign": false, "seen": []}, h), ["gravelight_one"] as Array[String], "standalone, the first time")
	assert_eq(LazarusCinema.plan("map00_crossroads", {"campaign": false, "seen": ["gravelight_one"]}, h).size(), 0, "standalone, once")
	var always: Dictionary = h.duplicate(true)
	always["map00_crossroads"]["standalone_rule"] = "always"
	assert_eq(LazarusCinema.plan("map00_crossroads", {"campaign": false, "seen": ["gravelight_one"]}, always).size(), 1, "the rule is data")


func test_the_first_launch_flag() -> void:
	assert_true(CinemaTheatre.prologue_due(ProfileSave.new_profile()), "a new profile sees the prologue")
	assert_false(CinemaTheatre.prologue_due({"prologue_seen": true}), "never again")
	assert_false(CinemaTheatre.wants_prologue(), "headless runs never start it on their own")
	var path_was: String = ProfileSave.path
	var prof_was: Dictionary = ProfileSave.profile.duplicate(true)
	ProfileSave.path = "user://_test_cinema_lazarus_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	CinemaTheatre.force_prologue = true
	assert_true(CinemaTheatre.wants_prologue(), "the first launch")
	CinemaTheatre.mark_prologue_seen()   # (the prologue ended or was skipped)
	assert_false(CinemaTheatre.wants_prologue(), "played once")
	assert_true((ProfileSave.profile.get("cutscenes_seen", []) as Array).has("lazarus_saturday"), "and in the Archive as seen")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	ProfileSave.path = path_was
	ProfileSave.profile = prof_was


func test_headless_match_starts_play_nothing_unless_forced() -> void:
	assert_false(LazarusCinema.enabled(), "tests and smokes are not held up by cutscenes")
	LazarusCinema.force = true
	assert_true(LazarusCinema.enabled())


func test_the_archive_gallery() -> void:
	var ids: Array = []
	for r: Variant in CinemaLibrary.gallery():
		var row: Dictionary = r
		ids.append(str(row["id"]))
		if str(row["kind"]) == "lazarus":
			assert_true(CinemaLibrary.has_cut(str(row["id"])), "%s plays from the Archive" % str(row["id"]))
		else:
			assert_ne(String(CinemaTheatre.exfil_map(str(row["id"]))), "", "%s: the map whose beacon plays it" % str(row["id"]))
	for id: String in SHOT_LIST_SECONDS.keys():
		assert_true(ids.has(id), "%s is in the gallery" % id)


# ---------------------------------------------------------------- a reel

func test_a_reel_plays_to_its_end_and_a_skip_ends_it_at_once() -> void:
	var r: CinemaReel = CinemaReel.play(self, ["epilogue_1953"], {"speed": 30.0})
	watch_signals(r)
	var t: float = 0.0
	while not r.done and t < 10.0:
		await wait_frames(1)
		t += get_process_delta_time()
	assert_true(r.done, "23 s at x30")
	assert_signal_emitted_with_parameters(r, "cut_ended", [0, "epilogue_1953", false])
	assert_eq(r.missing.size(), 0, "no missing stage or node: %s" % ", ".join(r.missing))
	await wait_seconds(1.6)
	var r2: CinemaReel = CinemaReel.play(self, ["staub", "epilogue_1953"], {"speed": 1.0})
	watch_signals(r2)
	await wait_frames(3)
	r2.skip_current()
	assert_eq(r2.index, 1, "a skip ends the cut playing; the next follows")
	r2.skip_current()
	assert_true(r2.done, "the last skip ends the reel")
	assert_signal_emitted(r2, "finished")
	await wait_seconds(1.6)
