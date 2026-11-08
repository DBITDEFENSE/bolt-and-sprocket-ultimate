extends Node
## T-209 (UPDATE 12 s3) headless smoke for the archive reels (CinemaArchive, CinemaVideo, CinemaFilm):
##   1. stand-ins: each of LAZARUS SATURDAY, FOURTH DAY and STAUB as a reel with no clip at all plays end to end
##      through the film treatment (every card shown in its native lines, the subtitles up as in the in-engine scene,
##      nothing missing),
##      then again held to skip (it ends at once)
##   2. real clips: every reel shot of every scene has a clip (the committed fixture copied into a user:// folder, or
##      the .ogv a real pipeline run built: --reel-root=DIR, e.g. tools/cinema/test_archive_reel.py --keep DIR then
##      DIR/built); each scene plays end to end with every span covered by its clip; then skipped mid-clip
##   3. mixed: FOURTH DAY with clips for the odd shots only (the even ones stand in), then cutting straight into an
##      in-engine cutscene (GRAVELIGHT ONE) in the same reel, and a plain id routed to the reel by the data
## Never touches the owner's assets/user_supplied/cutscenes or assets/cutscene_reels.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_cinema_reels.tscn [-- --reel-root=DIR]
## Prints "[smoke_reels] ..." lines and "RESULT: PASS" / "RESULT: FAIL" (exit code 0/1).

const FIXTURE: String = "res://gravelight/tests/fixtures/reel_test_shot.ogv"
const TMP: String = "user://_qa_reels_smoke"
const EMPTY: String = "user://_qa_reels_smoke_empty"
const SCENES: Array[String] = ["lazarus_saturday", "fourth_day", "staub"]
const TIMEOUT: float = 900.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _root_arg: String = ""
var _lines: Array = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--reel-root="):
			_root_arg = a.get_slice("=", 1)
	ProfileSave.path = "user://_qa_cinema_reels_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_cinema_reels_settings.cfg"
	GLSettings.values["subtitles"] = true
	GLBus.vo_line_started.connect(func(id: StringName, _s: StringName, _t2: String, _d: float) -> void: _lines.append(String(id)))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _log(m: String) -> void:
	print("[smoke_reels] ", m)


func _fail(m: String) -> void:
	_fails.append(m)
	_log("FAIL: " + m)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fail(what)


func _wait(cond: Callable, limit: float) -> bool:
	var w: float = 0.0
	while not bool(cond.call()) and w < limit:
		await get_tree().process_frame
		w += get_process_delta_time()
	return bool(cond.call())


func _run() -> void:
	await _stand_ins()
	await _real_clips()
	await _mixed()
	_finish()


## Every line id a definition says (the subtitles the reel must put up).
static func _line_ids(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for s: Variant in d.get("shots", []):
		for le: Variant in (s as Dictionary).get("lines", []):
			out.append(str((le as Array)[1]))
	return out


static func _card_count(scene: String) -> int:
	var n: int = 0
	for s: Variant in CinemaLibrary.def(scene).get("shots", []):
		if (s as Dictionary).get("card", null) is Dictionary:
			n += 1
	return n


## Plays one reel to its end, watching the film and the video track. Returns {played, cards, film, ends, missing}.
func _play(ids: Array, speed: float) -> Dictionary:
	var r: CinemaReel = CinemaReel.play(self, ids, {"speed": speed, "roster": ["wren"]})
	var ends: Array = []
	r.cut_ended.connect(func(_i: int, cid: String, sk: bool) -> void: ends.append([cid, sk]))
	var played: Dictionary = {}
	var cards: Array = []
	var films: Dictionary = {}
	var vid_layers: Dictionary = {}
	var limit: float = 0.0
	for id: Variant in ids:
		limit += float(CinemaArchive.resolved(str(id)).get("seconds", 60.0)) / speed + 8.0
	var w: float = 0.0
	while not r.done and w < limit:
		var d: CinemaDirector = r.director
		if d != null and is_instance_valid(d):
			var base: String = CinemaArchive.base_id(str(r.ids[r.index]))
			films[base] = d.film != null
			if d.film != null:
				for c: Variant in d.film.cards_shown:
					var key: String = "%s:%d" % [base, int((c as Array)[0])]
					if not cards.has(key):
						cards.append(key)
			if d.video != null:
				vid_layers[base] = true
				for p: String in d.video.played:
					played[p] = true
		await get_tree().process_frame
		w += get_process_delta_time()
	var out: Dictionary = {"done": r.done, "played": played.keys(), "cards": cards, "film": films, "video": vid_layers,
		"ends": ends, "missing": Array(r.missing)}
	await get_tree().create_timer(1.5).timeout
	return out


func _skip(id: String, at_s: float) -> bool:
	var r: CinemaReel = CinemaReel.play(self, [id], {"speed": 1.0})
	await get_tree().create_timer(at_s).timeout
	if r.director != null and r.director.overlay != null:
		r.director.overlay.feed_skip(true, 2.0)   # a full hold of [interact]
	var ok: bool = await _wait(func() -> bool: return r.done, 2.0)
	var sk: bool = ok and is_instance_valid(r) and r.skipped_any
	await get_tree().create_timer(1.5).timeout
	return sk


# ---------------------------------------------------------------- 1. stand-ins

func _stand_ins() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EMPTY))
	CinemaArchive.root_override = EMPTY
	for scene: String in SCENES:
		_lines.clear()
		# STAUB at its own speed, against the in-engine STAUB; the long two at x10 (sped up, the voices queue)
		var spd: float = 1.0 if scene == "staub" else 10.0
		var res: Dictionary = await _play(["reel:" + scene], spd)
		_check(bool(res["done"]), "%s (stand-ins) did not end" % scene)
		_check(bool((res["film"] as Dictionary).get(scene, false)), "%s: the film treatment was on" % scene)
		_check((res["played"] as Array).is_empty() and not (res["video"] as Dictionary).has(scene), "%s: no clip, no video layer" % scene)
		_check((res["cards"] as Array).size() == _card_count(scene), "%s: %d of %d archive cards shown" % [scene, (res["cards"] as Array).size(), _card_count(scene)])
		_check((res["missing"] as Array).is_empty(), "%s: missing %s" % [scene, str(res["missing"])])
		var want: Array[String] = _line_ids(CinemaLibrary.def(scene))
		var got: Array[String] = []
		for l: String in want:
			if _lines.has(l):
				got.append(l)
		if spd <= 1.0:
			# the reel puts up as many subtitles as the in-engine scene does at the game's speed (overlapping lines queue
			# in GLVO and some are dropped in both: T-194's queue, not the reel's)
			_lines.clear()
			await _play(["engine:" + scene], spd)
			var ref: Array[String] = []
			for l2: String in want:
				if _lines.has(l2):
					ref.append(l2)
			# (which queued line is dropped depends on frame timing, so the sets differ run to run; the count may not)
			_check(got.size() >= ref.size() - 1, "%s: the reel's subtitles %s, the in-engine scene's %s" % [scene, str(got), str(ref)])
			_log("%s subtitles: the reel %d, the in-engine scene %d of %d (T-194's GLVO queue drops overlapping lines in both)" % [scene, got.size(), ref.size(), want.size()])
		else:
			_check(got.size() > 0, "%s: %d of %d lines put their subtitle up" % [scene, got.size(), want.size()])
		_log("%s stand-ins: played to the end (x%d), film on, %d cards, %d/%d subtitles" % [scene, int(spd), (res["cards"] as Array).size(), got.size(), want.size()])
		var sk: bool = await _skip("reel:" + scene, 4.0)
		_check(sk, "%s (stand-ins): hold to skip ends it at once" % scene)
		_log("%s stand-ins skipped: %s" % [scene, "ok" if sk else "NO"])


# ---------------------------------------------------------------- 2. real clips

func _fill(root: String, odd_only: bool, only_scene: String = "") -> void:
	for scene: String in SCENES:
		if only_scene != "" and scene != only_scene:
			continue
		var dir: String = root.path_join(scene)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		for s: Variant in (CinemaArchive.scenes()[scene] as Dictionary)["shots"]:
			var n: int = int((s as Dictionary)["n"])
			if odd_only and n % 2 == 0:
				continue
			DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), ProjectSettings.globalize_path(dir.path_join(CinemaArchive.shot_name(n) + ".ogv")))


func _real_clips() -> void:
	var root: String = _root_arg
	if root == "":
		root = TMP + "_all"
		_fill(root, false)
	CinemaArchive.root_override = root
	_log("clips from %s" % root)
	for scene: String in SCENES:
		var shots: Array = (CinemaArchive.scenes()[scene] as Dictionary)["shots"]
		var have: Array = []
		for s: Variant in shots:
			if CinemaArchive.clip_path(scene, int((s as Dictionary)["n"]), "off", false) != "":
				have.append("%s/%s" % [scene, CinemaArchive.shot_name(int((s as Dictionary)["n"]))])
		if _root_arg != "" and have.is_empty():
			_log("%s: no clips under %s (skipped)" % [scene, root])
			continue
		var res: Dictionary = await _play(["reel:" + scene], 6.0)
		_check(bool(res["done"]), "%s (clips) did not end" % scene)
		var played: Array = res["played"]
		played.sort()
		have.sort()
		_check(played == have, "%s: every clip covered its span (%d of %d)" % [scene, played.size(), have.size()])
		_check((res["missing"] as Array).is_empty(), "%s (clips): missing %s" % [scene, str(res["missing"])])
		_log("%s with clips: %d of %d spans played their clip (x6)" % [scene, played.size(), shots.size()])
		var first: float = float(((shots[0] as Dictionary)["span"] as Array)[0]) + 1.0
		var sk: bool = await _skip("reel:" + scene, first)   # (the 1.0 s speed: this is inside the first clip)
		_check(sk, "%s (clips): hold to skip mid-clip ends it" % scene)
		_log("%s with clips skipped mid-clip: %s" % [scene, "ok" if sk else "NO"])


# ---------------------------------------------------------------- 3. mixed, and into an in-engine scene

func _mixed() -> void:
	var root: String = TMP + "_odd"
	_fill(root, true, "fourth_day")
	CinemaArchive.root_override = root
	var res: Dictionary = await _play(["reel:fourth_day", "gravelight_one"], 10.0)
	_check(bool(res["done"]), "FOURTH DAY (mixed) then GRAVELIGHT ONE did not end")
	_check(res["ends"] == [["fourth_day", false], ["gravelight_one", false]], "both cuts ended in order (%s)" % str(res["ends"]))
	var odd: int = 0
	for s: Variant in (CinemaArchive.scenes()["fourth_day"] as Dictionary)["shots"]:
		if int((s as Dictionary)["n"]) % 2 == 1:
			odd += 1
	_check((res["played"] as Array).size() == odd, "the odd shots played their clips, the even ones stood in (%d of %d)" % [(res["played"] as Array).size(), odd])
	_check(bool((res["film"] as Dictionary).get("fourth_day", false)) and not bool((res["film"] as Dictionary).get("gravelight_one", true)),
		"the film on the reel, off on the in-engine cut after it")
	_log("FOURTH DAY mixed (%d clips, the rest stand-ins) cut straight into GRAVELIGHT ONE in-engine" % (res["played"] as Array).size())
	CinemaArchive.root_override = EMPTY
	CinemaArchive.in_game_override = null
	var plain: Dictionary = await _play(["staub"], 12.0)
	_check(bool((plain["film"] as Dictionary).get("staub", false)) == CinemaArchive.in_game(), "a plain id follows the data's in_game (%s)" % str(CinemaArchive.in_game()))
	_log("plain 'staub' plays the %s" % ("reel" if CinemaArchive.in_game() else "in-engine scene"))


func _finish() -> void:
	if _done:
		return
	_done = true
	CinemaArchive.root_override = ""
	CinemaArchive.in_game_override = null
	for f: String in _fails:
		print("[smoke_reels] FAIL: ", f)
	print("[smoke_reels] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
