extends GutTest
## T-209 (UPDATE 12 s3): the archive reels. The reel data (data/gravelight/cinema_reels.json) against the in-engine
## timelines; the routing of reel: / engine: / plain ids; the clip pick (desktop / web / Gore full) from a test folder
## (never the owner's); VideoStreamTheora loads and plays an .ogv headless (the committed fixture
## gravelight/tests/fixtures/reel_test_shot.ogv, made by tools/cinema/archive_reel.py); the cinema_video shot type in a
## plain director (a video shot that ends in "return", the cut straight back to gameplay); the film treatment and the
## native cards in a reel; the web export ships .ogv.

const FIXTURE: String = "res://gravelight/tests/fixtures/reel_test_shot.ogv"
const TMP: String = "user://_qa_reels_unit"
const SCENES: Array[String] = ["lazarus_saturday", "fourth_day", "staub"]
const STYLE: String = "Black-and-white 1930s/1940s archival film footage, heavy film grain, flicker, scratches and dust, hand-cranked camera judder, documentary realism"

var _gore_was: String = "full"


func before_all() -> void:
	_gore_was = str(GLSettings.values.get("gore", "full"))


func after_each() -> void:
	CinemaArchive.root_override = ""
	CinemaArchive.in_game_override = null
	CinemaArchive.platform_override = ""
	GLSettings.values["gore"] = _gore_was
	Campaign.cutscene_speed = 1.0
	_wipe(TMP)


func _wipe(dir: String) -> void:
	var g: String = ProjectSettings.globalize_path(dir)
	var da: DirAccess = DirAccess.open(g)
	if da == null:
		return
	for sub: String in da.get_directories():
		_wipe(dir.path_join(sub))
	for f: String in da.get_files():
		DirAccess.remove_absolute(g.path_join(f))
	DirAccess.remove_absolute(g)


## Copies the fixture clip to TMP/<scene>/<name>.ogv for each name.
func _clips(scene: String, names: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP.path_join(scene)))
	for n: Variant in names:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), ProjectSettings.globalize_path(TMP.path_join(scene).path_join(str(n) + ".ogv")))
	CinemaArchive.root_override = TMP


func _cut(scene: String) -> Dictionary:
	return CinemaLibrary.def(scene)


# ---------------------------------------------------------------- the data

func test_three_scenes_of_about_fifteen_to_twenty_shots() -> void:
	for scene: String in SCENES:
		assert_true(CinemaArchive.has_scene(scene), scene)
		var n: int = ((CinemaArchive.scenes()[scene] as Dictionary)["shots"] as Array).size()
		assert_between(n, 12, 22, "%s: %d reel shots" % [scene, n])


func test_prompts_durations_priorities() -> void:
	var d: Dictionary = CinemaArchive.data()
	assert_eq(str(d["style_block"]), STYLE, "the style block is the work order's, word for word")
	var md: String = FileAccess.get_file_as_string("res://docs/cutscenes/SHOT_PROMPTS.md")
	for scene: String in SCENES:
		var shots: Array = (CinemaArchive.scenes()[scene] as Dictionary)["shots"]
		var prios: Array = []
		for s: Variant in shots:
			var sh: Dictionary = s
			var secs: int = int(sh["seconds"])
			assert_between(secs, 4, 10, "%s shot %d asks for 4-10 s" % [scene, int(sh["n"])])
			var span: float = float(sh["span"][1]) - float(sh["span"][0])
			assert_true(span / float(secs) <= float(CinemaArchive.treatment()["max_stretch"]) + 0.001,
				"%s shot %d: a %d s clip can fill its %.1f s span" % [scene, int(sh["n"]), secs, span])
			assert_true(str(sh["prompt"]).length() > 80 and str(sh["must_show"]) != "", "%s shot %d has a prompt and a note" % [scene, int(sh["n"])])
			var full: String = "%s. %s" % [STYLE, str(sh["prompt"]).strip_edges()]
			assert_true(md.contains(full), "%s shot %d: SHOT_PROMPTS.md carries the prompt after the style block" % [scene, int(sh["n"])])
			prios.append(int(sh["priority"]))
		prios.sort()
		var want: Array = []
		for i: int in shots.size():
			want.append(i + 1)
		assert_eq(prios, want, scene + ": priorities 1..N")


func test_spans_cover_every_picture_shot_and_no_card() -> void:
	for scene: String in SCENES:
		var cut: Dictionary = _cut(scene)
		var cs: Array = cut["shots"]
		var secs: float = float(cut["seconds"])
		var spans: Array = []
		for s: Variant in (CinemaArchive.scenes()[scene] as Dictionary)["shots"]:
			spans.append(s)
		spans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["span"][0]) < float(b["span"][0]))
		var last_end: float = -1.0
		for i: int in spans.size():
			var sh: Dictionary = spans[i]
			assert_eq(int(sh["n"]), i + 1, "%s: shots numbered in timeline order" % scene)
			var a: float = float(sh["span"][0])
			var b: float = float(sh["span"][1])
			assert_true(a >= last_end - 0.001 and b > a and b <= secs, "%s shot %d: in order inside the cut" % [scene, int(sh["n"])])
			last_end = b
			for r: Variant in sh["replaces"]:
				var ri: int = int(r)
				var rt0: float = float((cs[ri] as Dictionary)["t"])
				var rt1: float = float((cs[ri + 1] as Dictionary)["t"]) if ri + 1 < cs.size() else secs
				assert_true(rt0 < b and rt1 > a, "%s shot %d replaces in-engine shot %d (it overlaps)" % [scene, int(sh["n"]), ri])
				assert_false(bool((cs[ri] as Dictionary).get("black", false)), "%s: a card shot is never generated" % scene)
		for i: int in cs.size():
			var c: Dictionary = cs[i]
			var t0: float = float(c["t"])
			var t1: float = float((cs[i + 1] as Dictionary)["t"]) if i + 1 < cs.size() else secs
			var covered: float = 0.0
			for s2: Variant in spans:
				covered += maxf(0.0, minf(t1, float(s2["span"][1])) - maxf(t0, float(s2["span"][0])))
			if bool(c.get("black", false)):
				assert_almost_eq(covered, 0.0, 0.01, "%s: card shot %d stays ours" % [scene, i])
			else:
				assert_almost_eq(covered, t1 - t0, 0.01, "%s: picture shot %d is covered by reel shots" % [scene, i])


func test_cards_have_native_lines_over_the_english() -> void:
	for scene: String in SCENES:
		var sc: Dictionary = CinemaArchive.scenes()[scene]
		var cs: Array = _cut(scene)["shots"]
		for i: int in cs.size():
			if not ((cs[i] as Dictionary).get("card", null) is Dictionary):
				continue
			var native: Array = ((sc.get("cards", {}) as Dictionary).get(str(i), {}) as Dictionary).get("native", [])
			assert_gt(native.size(), 0, "%s card %d has native lines" % [scene, i])
			if str(sc["lang"]) == "ru":
				var cyr: bool = false
				for ch: int in str(native[0]).length():
					var u: int = str(native[0]).unicode_at(ch)
					cyr = cyr or (u >= 0x400 and u <= 0x4FF)
				assert_true(cyr, "%s card %d is in Cyrillic" % [scene, i])
	var f: Font = CinemaFilm.native_font(false)
	assert_true(f != null and f.has_char("Ч".unicode_at(0)) and f.has_char("ё".unicode_at(0)), "the card face has Cyrillic (Old Standard TT)")


# ---------------------------------------------------------------- routing

func test_ids_route_to_the_reel_or_the_scene() -> void:
	assert_eq(CinemaArchive.base_id("reel:staub"), "staub")
	assert_eq(CinemaArchive.base_id("engine:staub"), "staub")
	assert_true(CinemaArchive.is_known("reel:fourth_day"))
	assert_false(CinemaArchive.is_known("reel:nope"))
	assert_true(CinemaArchive.plays_as_reel("reel:staub"))
	assert_false(CinemaArchive.plays_as_reel("engine:staub"))
	assert_false(CinemaArchive.plays_as_reel("reel:gravelight_one"), "GRAVELIGHT ONE stays in-engine (the squad's scene)")
	CinemaArchive.in_game_override = true
	assert_true(CinemaArchive.plays_as_reel("staub"))
	CinemaArchive.in_game_override = false
	assert_false(CinemaArchive.plays_as_reel("staub"))
	assert_true(CinemaArchive.plays_as_reel("reel:staub"))


func test_reel_definition_validates_and_carries_the_film() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for scene: String in SCENES:
		var d: Dictionary = CinemaArchive.resolved("reel:" + scene, ["dutch"])
		assert_eq(CinemaDirector.validate(d, lines).size(), 0, "%s reel validates: %s" % [scene, ", ".join(CinemaDirector.validate(d, lines))])
		assert_true(d.get("archive", null) is Dictionary and not bool(d.get("bars", true)), scene + ": film on, bars off")
		assert_eq(((d["archive"] as Dictionary)["spans"] as Array).size(), ((CinemaArchive.scenes()[scene] as Dictionary)["shots"] as Array).size())
		assert_eq(float(d["seconds"]), float(_cut(scene)["seconds"]), scene + ": the reel keeps the scene's timeline")
		var cards: int = 0
		for s: Variant in d["shots"]:
			assert_false((s as Dictionary).has("card"), scene + ": the overlay's card is replaced")
			if (s as Dictionary).has("archive_card"):
				cards += 1
		assert_gt(cards, 0, scene + ": archive cards")
		var e: Dictionary = CinemaArchive.resolved("engine:" + scene, ["dutch"])
		assert_false(e.has("archive"), scene + ": engine: is the in-engine scene")


func test_clip_pick_desktop_web_gore() -> void:
	assert_eq(CinemaArchive.clip_path("staub", 99, "full", false), "", "no clip: a stand-in")
	_clips("staub", ["shot_01", "shot_01_720"])
	assert_eq(CinemaArchive.clip_path("staub", 1, "full", false), TMP + "/staub/shot_01.ogv")
	assert_eq(CinemaArchive.clip_path("staub", 1, "full", true), TMP + "/staub/shot_01_720.ogv", "the web takes the 720p variant")
	_clips("staub", ["shot_02_720", "shot_03", "shot_03_gore"])
	assert_eq(CinemaArchive.clip_path("staub", 2, "off", false), TMP + "/staub/shot_02_720.ogv", "the desktop falls back to 720p")
	assert_eq(CinemaArchive.clip_path("staub", 3, "full", false), TMP + "/staub/shot_03_gore.ogv", "Gore full takes the _gore clip")
	assert_eq(CinemaArchive.clip_path("staub", 3, "low", false), TMP + "/staub/shot_03.ogv", "Gore low never does")
	assert_eq(CinemaArchive.clip_path("staub", 3, "off", false), TMP + "/staub/shot_03.ogv", "Gore off never does")
	GLSettings.values["gore"] = "off"
	var d: Dictionary = CinemaArchive.resolved("reel:staub")
	var ids: Array = []
	for v: Variant in d["videos"]:
		ids.append(str((v as Dictionary)["id"]))
	assert_eq(ids, ["staub/shot_01", "staub/shot_02", "staub/shot_03"], "the built clips become the video track, the rest stay stand-ins")
	var rows: Array = CinemaArchive.report()
	assert_eq(rows.size(), 3)


# ---------------------------------------------------------------- Theora

func test_theora_loads_headless() -> void:
	var r: Resource = load(FIXTURE)
	assert_true(r is VideoStreamTheora, "ResourceLoader loads an .ogv as VideoStreamTheora (what the exports do)")
	var s: VideoStream = CinemaVideo.load_stream(FIXTURE)
	assert_not_null(s)
	_clips("staub", ["shot_01"])
	var u: VideoStream = CinemaVideo.load_stream(TMP + "/staub/shot_01.ogv")
	assert_true(u is VideoStreamTheora, "a raw .ogv on disk loads too")


func test_theora_plays_and_seeks_headless() -> void:
	var p: VideoStreamPlayer = VideoStreamPlayer.new()
	p.stream = CinemaVideo.load_stream(FIXTURE)
	add_child_autofree(p)
	p.play()
	assert_almost_eq(p.get_stream_length(), 4.0, 0.3, "the fixture is 4 s")
	await wait_seconds(0.5)
	assert_true(p.is_playing())
	assert_gt(p.stream_position, 0.1, "it decodes forward")
	p.stream_position = 2.5
	await wait_frames(2)
	assert_almost_eq(p.stream_position, 2.5, 0.3, "it seeks (the director keeps a clip on its clock)")


# ---------------------------------------------------------------- the cinema_video shot type

func test_video_track_from_shots_and_the_track() -> void:
	var d: Dictionary = {"seconds": 10.0, "videos": [{"t0": 6.0, "t1": 9.0, "path": "res://b.ogv"}],
		"shots": [{"t": 0.0, "from": [0, 2, 0], "video": "res://a.ogv", "video_from": 1.0}, {"t": 4.0, "from": [0, 2, 0]}]}
	var tr: Array = CinemaVideo.track_of(d, CinemaShot.list_from(d))
	assert_eq(tr.size(), 2)
	assert_eq(str(tr[0]["path"]), "res://a.ogv")
	assert_almost_eq(float(tr[0]["t1"]), 4.0, 0.001, "a video shot lasts its shot")
	assert_eq(CinemaVideo.index_at(tr, 1.0), 0)
	assert_eq(CinemaVideo.index_at(tr, 5.0), -1, "between videos: the in-engine shot")
	assert_eq(CinemaVideo.index_at(tr, 7.0), 1)
	assert_eq(CinemaDirector.validate({"seconds": 5.0, "shots": [{"t": 0.0, "from": [0, 2, 0], "video": "x.mp4"}]}).size(), 1, "only .ogv")


## A plain director (no reel, no stage): an in-engine shot, a video shot, then "return" back to the game.
func test_director_mixes_video_and_in_engine_then_returns() -> void:
	var stage: Node3D = Node3D.new()
	add_child_autofree(stage)
	var d: Dictionary = {"seconds": 6.0, "end": "return", "fade_in_s": 0.0,
		"shots": [{"t": 0.0, "from": [0, 2, 4], "look": [0, 1, 0]},
			{"t": 2.0, "from": [0, 2, 4], "look": [0, 1, 0], "video": FIXTURE, "video_from": 0.5},
			{"t": 4.5, "from": [0, 2, 4], "look": [0, 1, 0]}]}
	var dir: CinemaDirector = CinemaDirector.make(self, d, stage, {"speed": 1.0, "cast": false, "hide_hud": false, "auto": false})
	autofree(dir)
	assert_not_null(dir.video, "a definition with a video shot gets the video layer")
	assert_null(dir.film, "no archive: no film")
	dir.step(1.0)
	assert_false(dir.video.showing(), "the in-engine shot first")
	dir.step(1.5)
	assert_true(dir.video.showing(), "then the clip")
	assert_true(get_viewport().disable_3d or dir.get_viewport().disable_3d, "the 3D under the clip is off")
	assert_eq(dir.video.played, PackedStringArray(["reel_test_shot"]))
	dir.step(2.5)
	assert_false(dir.video.showing(), "back in-engine after the clip")
	assert_false(dir.get_viewport().disable_3d, "and the 3D is back")
	dir.step(2.0)
	assert_true(dir.done, "the cutscene ends ('return': the bars go, the player's camera comes back)")


# ---------------------------------------------------------------- a reel

func test_film_seed_follows_the_reel_shot() -> void:
	var spans: Array = [[5.0, 12.0, 111, 1], [12.0, 17.0, 222, 2]]
	assert_eq(CinemaFilm.seed_at(spans, 6.0, 1), 111)
	assert_eq(CinemaFilm.seed_at(spans, 12.0, 2), 222)
	assert_ne(CinemaFilm.seed_at(spans, 2.0, 0), 111, "a card / black shot has its own")
	assert_eq(CinemaArchive.seed_of("staub", 3), CinemaArchive.seed_of("staub", 3))
	assert_ne(CinemaArchive.seed_of("staub", 3), CinemaArchive.seed_of("staub", 4))


func test_staub_reel_plays_with_a_clip_and_stand_ins() -> void:
	_clips("staub", ["shot_02"])
	var r: CinemaReel = CinemaReel.play(self, ["reel:staub"], {"speed": 6.0})
	var ends: Array = []
	r.cut_ended.connect(func(_i: int, id: String, sk: bool) -> void: ends.append([id, sk]))
	await wait_frames(3)
	assert_not_null(r.director)
	assert_not_null(r.director.film, "the film treatment is on")
	assert_not_null(r.director.video, "one clip: a video track")
	assert_eq(r.director.overlay._black.self_modulate.a, 0.0, "the film draws the black (grain on leader)")
	var film: CinemaFilm = r.director.film
	var vid: CinemaVideo = r.director.video
	var played: PackedStringArray = []
	var cards: Array = []
	var t0: int = Time.get_ticks_msec()
	while not r.done and Time.get_ticks_msec() - t0 < 60000:   # (wall clock: never spins past a minute)
		if is_instance_valid(vid):
			played = vid.played.duplicate()
		if is_instance_valid(film):
			cards = film.cards_shown.duplicate()
		await wait_frames(1)
	assert_true(r.done, "STAUB as a reel plays to its end")
	assert_eq(ends, [["staub", false]], "the signals carry the plain id")
	assert_eq(played, PackedStringArray(["staub/shot_02"]), "the clip covered its span")
	assert_eq(cards.size(), 1, "the opening card")
	assert_eq(str(cards[0][1]) if not cards.is_empty() else "", "KALTENBRUNN")
	assert_true(r.missing.is_empty(), "nothing missing: %s" % ", ".join(r.missing))
	await wait_seconds(1.6)   # the reel frees itself after its closing fade


func test_web_export_ships_ogv() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	for sec: String in cfg.get_sections():
		if not sec.ends_with(".options") and str(cfg.get_value(sec, "platform", "")) in ["Web", "Windows Desktop"]:
			assert_true(str(cfg.get_value(sec, "include_filter", "")).contains("*.ogv"), "%s exports .ogv" % sec)
			assert_false(str(cfg.get_value(sec, "exclude_filter", "")).contains("cutscene_reels"), "%s keeps the built reels" % sec)
			assert_true(str(cfg.get_value(sec, "exclude_filter", "")).contains("assets/user_supplied/*"), "%s never ships the raw clips" % sec)
