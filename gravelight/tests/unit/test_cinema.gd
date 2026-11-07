extends GutTest
## T-184: the shared cutscene library (CinemaEase, CinemaShot, CinemaCamera, CinemaOverlay, CinemaDirector, CinemaCast)
## and every cutscene's data: the curves, the shot timing and paths, the hand-held drift and impact kicks, the blend,
## the letterbox height, hold-to-skip, the sequencer's clock, and that each cutscene in campaign.json validates and
## names only nodes its map has.

const EPS: float = 0.0005


func after_each() -> void:
	Campaign.cutscene_speed = 1.0
	GameState.input_blocked = false


# ---------------------------------------------------------------- easing

func test_every_curve_starts_at_0_and_ends_at_1() -> void:
	for n: String in CinemaEase.NAMES:
		assert_almost_eq(CinemaEase.apply(n, 0.0), 0.0, EPS, "%s(0)" % n)
		assert_almost_eq(CinemaEase.apply(n, 1.0), 1.0, EPS, "%s(1)" % n)
		assert_almost_eq(CinemaEase.apply(n, -3.0), 0.0, EPS, "%s clamps below" % n)
		assert_almost_eq(CinemaEase.apply(n, 7.0), 1.0, EPS, "%s clamps above" % n)


func test_smooth_is_a_camera_move_not_a_lerp() -> void:
	assert_almost_eq(CinemaEase.apply("smooth", 0.5), 0.5, EPS, "symmetric")
	assert_lt(CinemaEase.apply("smooth", 0.02), 0.001, "starts from rest (no snap)")
	assert_gt(CinemaEase.apply("smooth", 0.98), 0.999, "and comes to rest")
	assert_almost_eq(CinemaEase.apply("not-a-curve", 0.3), CinemaEase.apply("smooth", 0.3), EPS, "a typo still eases")
	var last: float = -1.0
	for i: int in 101:
		var v: float = CinemaEase.apply("smooth", float(i) / 100.0)
		assert_true(v >= last - EPS, "monotonic at %d" % i)
		last = v
	assert_gt(CinemaEase.apply("out_back", 0.8), 1.0, "out_back overshoots before it settles")
	assert_true(CinemaEase.known("quint") and not CinemaEase.known("bouncy"))


# ---------------------------------------------------------------- shots

func test_an_old_shot_still_reads_the_same() -> void:
	var s: CinemaShot = CinemaShot.from_dict({"t": 2.0, "from": [0, 2, 0], "to": [10, 2, 0], "look": [5, 0, 10], "fov": 55}, 8.0)
	assert_almost_eq(s.dur, 6.0, EPS, "the length is up to the next shot")
	assert_eq(s.move, "dolly")
	assert_eq(s.cut, "cut")
	assert_almost_eq(s.fov_to, 55.0, EPS, "no lens change unless asked")
	var a: Dictionary = s.sample(0.0)
	var b: Dictionary = s.sample(6.0)
	var m: Dictionary = s.sample(3.0)
	assert_almost_eq((a["pos"] as Vector3).distance_to(Vector3(0, 2, 0)), 0.0, EPS, "starts at from")
	assert_almost_eq((b["pos"] as Vector3).distance_to(Vector3(10, 2, 0)), 0.0, EPS, "ends at to")
	assert_almost_eq((m["pos"] as Vector3).x, 5.0, 0.01, "halfway at half time (a symmetric curve)")
	assert_almost_eq((s.sample(0.3)["pos"] as Vector3).x, 10.0 * CinemaEase.apply("smooth", 0.05), 0.001, "on the curve, not a lerp")


func test_lead_and_hold_rest_the_camera() -> void:
	var s: CinemaShot = CinemaShot.from_dict({"t": 0.0, "from": [0, 0, 0], "to": [4, 0, 0], "lead": 1.0, "hold": 2.0}, 7.0)
	assert_almost_eq((s.sample(0.8)["pos"] as Vector3).x, 0.0, EPS, "still during the lead")
	assert_almost_eq((s.sample(5.2)["pos"] as Vector3).x, 4.0, EPS, "arrived for the hold")
	assert_almost_eq(s.progress(3.0), 0.5, EPS, "the move takes what is left between them")


func test_crane_lifts_in_the_middle_and_lens_and_roll_ease() -> void:
	var s: CinemaShot = CinemaShot.from_dict({"t": 0.0, "move": "crane", "from": [0, 1, 0], "to": [0, 3, 10], "arc": 2.0,
		"fov": 60, "fov_to": 40, "roll": 0, "roll_to": 4}, 4.0)
	var m: Dictionary = s.sample(2.0)
	assert_almost_eq((m["pos"] as Vector3).y, 2.0 + 2.0, 0.01, "the arc's lift at the middle")
	assert_almost_eq(float(m["fov"]), 50.0, 0.01)
	assert_almost_eq(float(m["roll"]), 2.0, 0.01)
	assert_almost_eq((s.sample(4.0)["pos"] as Vector3).y, 3.0, EPS, "and lands where it was sent")


func test_orbit_keeps_its_distance() -> void:
	var s: CinemaShot = CinemaShot.from_dict({"t": 0.0, "move": "orbit", "from": [5, 2, 0], "look": [0, 1, 0], "sweep": 90.0}, 4.0)
	for i: int in 9:
		var p: Vector3 = s.sample(float(i) * 0.5)["pos"]
		assert_almost_eq(Vector2(p.x, p.z).length(), 5.0, 0.001, "radius at %d" % i)
		assert_almost_eq(p.y, 2.0, EPS, "height at %d" % i)
	var e: Vector3 = s.sample(4.0)["pos"]
	assert_almost_eq(e.distance_to(Vector3(0, 2, 5)), 0.0, 0.01, "a quarter turn round the look point")
	var s2: CinemaShot = CinemaShot.from_dict({"t": 0.0, "move": "orbit", "from": [4, 0, 0], "to": [0, 2, 6], "look": [0, 0, 0]}, 2.0)
	assert_almost_eq((s2.sample(2.0)["pos"] as Vector3).distance_to(Vector3(0, 2, 6)), 0.0, 0.01, "or from `from` to `to` the short way")


func test_rel_and_target_follow_moving_nodes() -> void:
	var s: CinemaShot = CinemaShot.from_dict({"t": 0.0, "from": [0, 5, -10], "look": [0, 0, 0], "rel": "Rocket"}, 2.0)
	var a: Dictionary = s.sample(1.0, Vector3(100, 50, 0))
	assert_almost_eq((a["pos"] as Vector3).distance_to(Vector3(100, 55, -10)), 0.0, EPS, "offsets from the node")
	assert_almost_eq((a["look"] as Vector3).distance_to(Vector3(100, 50, 0)), 0.0, EPS)
	var t: CinemaShot = CinemaShot.from_dict({"t": 0.0, "from": [0, 1, 0], "look": [0, 0, 9], "target": "Kranich", "target_offset": [0, 4, 0]}, 2.0)
	assert_almost_eq((t.sample(1.0, Vector3.ZERO, Vector3(30, 20, 200))["look"] as Vector3).distance_to(Vector3(30, 24, 200)), 0.0, EPS, "the target stays in frame")


func test_shot_list_timing_and_kicks() -> void:
	var shots: Array[CinemaShot] = CinemaShot.list_from({"seconds": 20.0, "shots": [
		{"t": 0.0, "from": [0, 0, 0]}, {"t": 6.0, "from": [0, 0, 0], "shake": [[1.0, 0.4], [3.0, 0.2]]}, {"t": 15.0, "from": [0, 0, 0]}]})
	assert_eq(shots.size(), 3)
	assert_almost_eq(shots[1].dur, 9.0, EPS)
	assert_almost_eq(shots[2].dur, 5.0, EPS, "the last runs to the end")
	assert_eq(CinemaShot.index_at(shots, -0.1), -1)
	assert_eq(CinemaShot.index_at(shots, 5.99), 0)
	assert_eq(CinemaShot.index_at(shots, 6.0), 1, "a cut lands on its frame")
	assert_eq(CinemaShot.index_at(shots, 19.0), 2)
	assert_eq(shots[1].kicks_between(0.0, 1.0).size(), 1)
	assert_eq(shots[1].kicks_between(1.0, 2.9).size(), 0, "each kick once")


# ---------------------------------------------------------------- the camera

func test_handheld_drift_is_subtle_and_bounded() -> void:
	var lim: float = deg_to_rad(CinemaCamera.HANDHELD_DEG) * 1.01
	for i: int in 200:
		var d: Dictionary = CinemaCamera.drift(float(i) * 0.137, 3.3, 1.0)
		var r: Vector3 = d["rot"]
		assert_true(absf(r.x) <= lim and absf(r.y) <= lim and absf(r.z) <= lim, "within a degree at %d" % i)
	assert_eq(CinemaCamera.drift(4.0, 1.0, 0.0)["rot"], Vector3.ZERO, "no hand: no drift")
	assert_eq(CinemaCamera.shake_rot(1.3, 0.0), Vector3.ZERO, "no trauma: no shake")
	assert_lt(CinemaCamera.shake_rot(1.3, 0.3).length(), CinemaCamera.shake_rot(1.3, 0.9).length() * 0.2 + 0.0001, "squared: a small kick stays small")


func test_camera_follows_its_shot_kicks_decay_and_blends_ease() -> void:
	GLSettings.values["screen_shake"] = 1.0
	var cam: CinemaCamera = CinemaCamera.new()
	add_child_autofree(cam)
	cam.play(CinemaShot.from_dict({"t": 0.0, "from": [0, 2, 0], "to": [10, 2, 0], "look": [5, 2, 20], "handheld": 0.0}, 4.0))
	cam.advance(4.0)
	assert_almost_eq(cam.frame().origin.distance_to(Vector3(10, 2, 0)), 0.0, 0.01, "at the end of its path")
	cam.impulse(0.8)
	assert_almost_eq(cam.trauma, 0.8, EPS)
	cam.advance(1.0)
	assert_lt(cam.trauma, 0.01, "a kick dies away within a second")
	var b: CinemaShot = CinemaShot.from_dict({"t": 0.0, "from": [0, 2, 30], "look": [0, 2, 40], "cut": "blend", "blend": 2.0, "handheld": 0.0}, 6.0)
	cam.play(b)
	cam.advance(1.0)
	var mid: Vector3 = cam.frame().origin
	assert_almost_eq(mid.distance_to(Vector3(5, 2, 15)), 0.0, 0.05, "a blend is halfway at half its time (eased)")
	cam.advance(1.5)
	assert_almost_eq(cam.frame().origin.distance_to(Vector3(0, 2, 30)), 0.0, 0.01, "and then the new shot owns the frame")
	cam.play(CinemaShot.from_dict({"t": 0.0, "from": [50, 2, 0], "look": [50, 2, 9], "handheld": 0.0}, 3.0))
	assert_almost_eq(cam.frame().origin.distance_to(Vector3(50, 2, 0)), 0.0, 0.01, "a cut is a cut")


func test_screen_shake_setting_zero_locks_the_camera_off() -> void:
	GLSettings.values["screen_shake"] = 0.0
	var cam: CinemaCamera = CinemaCamera.new()
	add_child_autofree(cam)
	cam.play(CinemaShot.from_dict({"t": 0.0, "move": "static", "from": [0, 2, 0], "look": [0, 2, 9], "handheld": 1.0}, 4.0))
	var x0: Transform3D = cam.frame()
	cam.impulse(1.0)
	cam.advance(0.37)
	assert_true(cam.frame().basis.is_equal_approx(x0.basis), "no drift, no shake for a player who turned shake off")
	GLSettings.values["screen_shake"] = 1.0


# ---------------------------------------------------------------- the overlay

func test_letterbox_is_scope_with_a_floor() -> void:
	assert_almost_eq(CinemaOverlay.bar_height(Vector2(1920, 1080)), (1080.0 - 1920.0 / 2.39) * 0.5, 0.01, "2.39:1 on 16:9")
	assert_almost_eq(CinemaOverlay.bar_height(Vector2(3440, 1440)), 1440.0 * CinemaOverlay.BAR_MIN, 0.01, "an ultra-wide still gets a frame")
	assert_eq(CinemaOverlay.bar_height(Vector2(100, 0)), 0.0)


func test_grade_presets_resolve() -> void:
	for n: String in CinemaOverlay.PRESETS.keys():
		var g: Dictionary = CinemaOverlay.grade_values(n)
		assert_true(float(g["exposure"]) > 0.5 and float(g["exposure"]) < 1.5, "%s exposure" % n)
		assert_true(g["tint"] is Vector3, "%s tint" % n)
	assert_eq(CinemaOverlay.grade_values("neutral")["tint"], Vector3.ONE, "neutral changes nothing")


func test_the_black_covers_the_frame_and_fades() -> void:
	var o: CinemaOverlay = CinemaOverlay.new()
	add_child_autofree(o)
	await wait_frames(2)
	var black: ColorRect = o.get("_black") as ColorRect
	var view: Vector2 = o.get_viewport().get_visible_rect().size
	assert_almost_eq(black.size.x, view.x, 1.0, "the full width (a rect anchored after add_child once stayed 0 x 0)")
	assert_almost_eq(black.size.y, view.y, 1.0, "and the full height")
	o.fade(1.0, 0.1)
	await wait_seconds(0.3)
	assert_almost_eq(o.black(), 1.0, 0.01, "faded to black")


func test_hold_to_skip_needs_a_full_hold_and_fires_once() -> void:
	var o: CinemaOverlay = CinemaOverlay.new()
	o.skip_hold = 1.0
	add_child_autofree(o)
	watch_signals(o)
	o.feed_skip(true, 0.6)
	o.feed_skip(false, 0.2)
	assert_almost_eq(o.skip_progress, 0.2, EPS, "letting go drains it")
	assert_signal_not_emitted(o, "skip")
	o.feed_skip(true, 0.5)
	o.feed_skip(true, 0.4)
	assert_signal_emitted(o, "skip", "a full hold skips")
	o.feed_skip(true, 2.0)
	assert_signal_emit_count(o, "skip", 1, "once")


# ---------------------------------------------------------------- the director

func _director(def: Dictionary) -> CinemaDirector:
	var d: CinemaDirector = CinemaDirector.make(self, def, null, {"speed": 1.0, "auto": false, "cast": false, "hide_hud": false, "vo": func(_id: String) -> void: pass})
	autofree(d)
	return d


func test_director_cuts_on_time_and_ends() -> void:
	var d: CinemaDirector = _director({"seconds": 10.0, "title": "PLACE", "title_at": 6.0, "fade_at": 8.0, "music": {"stop": false},
		"shots": [{"t": 0.0, "from": [0, 2, 0], "look": [0, 2, 5]}, {"t": 4.0, "from": [9, 2, 0], "look": [9, 2, 5], "cut": "dip", "blend": 0.5}]})
	watch_signals(d)
	d.step(0.1)
	assert_eq(d.shot_i, 0, "the first shot on the first step")
	d.step(3.85)
	assert_eq(d.shot_i, 0)
	d.step(0.1)
	assert_eq(d.shot_i, 1, "the cut at 4 s")
	assert_signal_emit_count(d, "shot_started", 2)
	d.step(4.0)
	assert_signal_not_emitted(d, "finished")
	d.step(2.0)
	assert_signal_emitted(d, "finished", "over at its length")
	assert_true(d.done)
	d.step(5.0)
	assert_signal_emit_count(d, "finished", 1, "once")


func test_director_fires_shot_events_once_and_forwards_skip() -> void:
	var said: Array = []
	var d: CinemaDirector = CinemaDirector.make(self, {"seconds": 6.0, "music": {"stop": false},
		"shots": [{"t": 0.0, "from": [0, 2, 0], "look": [0, 2, 5], "vo": "LINE_A", "vo_at": 1.0, "shake": [[2.0, 0.5]]}]},
		null, {"speed": 1.0, "auto": false, "cast": false, "hide_hud": false, "vo": func(id: String) -> void: said.append(id)})
	autofree(d)
	watch_signals(d)
	d.step(0.5)
	assert_eq(said.size(), 0)
	d.step(0.6)
	d.step(0.6)
	assert_eq(said, ["LINE_A"], "the line once, at its time")
	d.step(0.9)
	assert_gt(d.cam.trauma, 0.0, "the kick landed on the camera")
	d.overlay.feed_skip(true, 2.0)
	assert_signal_emitted(d, "skip_requested", "hold to skip reaches the owner")


func test_director_speed_scales_the_clock() -> void:
	var d: CinemaDirector = _director({"seconds": 24.0, "music": {"stop": false}, "shots": [{"t": 0.0, "from": [0, 2, 0]}, {"t": 12.0, "from": [1, 2, 0]}]})
	d.speed = 12.0
	d.auto = true
	d._process(1.05)
	assert_eq(d.shot_i, 1, "x12: twelve cutscene seconds in one")


func test_manual_shots_end_only_when_told() -> void:
	var d: CinemaDirector = _director({"music": {"stop": false}})
	watch_signals(d)
	d.play_shot({"from": [0, 1, 0], "look": [0, 1, 4]}, 3.0)
	d.step(40.0)
	assert_signal_not_emitted(d, "finished", "a script-driven cutscene has no length of its own")
	d.end_at(41.0)
	d.step(1.5)
	assert_signal_emitted(d, "finished")


func test_wedge_spreads_the_squad() -> void:
	var spots: Array[Vector3] = CinemaCast.wedge(Vector3(10, 0, 10), Vector3(0, 0, -1), 4, 1.1)
	assert_eq(spots.size(), 4)
	assert_almost_eq(spots[0].distance_to(Vector3(10, 0, 10)), 0.0, EPS, "the first at the mark")
	for i: int in spots.size():
		for j: int in range(i + 1, spots.size()):
			assert_gt(spots[i].distance_to(spots[j]), 0.6, "nobody stands in anybody (%d, %d)" % [i, j])
		assert_true(spots[i].z >= 10.0 - EPS, "nobody in front of the leader (%d)" % i)


# ---------------------------------------------------------------- every cutscene's data

func _cutscenes() -> Dictionary:
	return Campaign.cfg().get("cutscenes", {})


func test_every_cutscene_validates() -> void:
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	assert_gt(_cutscenes().size(), 6)
	for id: Variant in _cutscenes().keys():
		var errs: PackedStringArray = CinemaDirector.validate(_cutscenes()[id] as Dictionary, lines)
		assert_eq(errs.size(), 0, "%s: %s" % [str(id), ", ".join(errs)])


func test_validate_catches_bad_data() -> void:
	var errs: PackedStringArray = CinemaDirector.validate({"seconds": 10.0, "grade": "sepia_please", "shots": [
		{"t": 0.0, "from": [0, 0]}, {"t": 0.0, "from": [0, 0, 0], "move": "zoom", "ease": "wobble", "cut": "wipe", "fov": 150, "vo": "NO_SUCH_LINE"},
		{"t": 12.0, "from": [0, 0, 0], "sfx": [[0.0, "no_such_sound"]]}]}, {"A": {}})
	var all: String = " | ".join(errs)
	for want: String in ["no camera", "out of order", "unknown move", "unknown curve", "unknown cut", "lens", "NO_SUCH_LINE", "no sound", "opening grade"]:
		assert_true(all.contains(want), "reports '%s' (%s)" % [want, all])


## The map each cutscene plays on: the map whose exfil names it, or the dive's Totenhafen.
func _map_scene_for(id: String) -> String:
	if id == "m2_letzte_fahrt_dive":
		return Campaign.scene_for(&"map02_totenhafen")
	for m: Variant in Campaign.chain():
		if str(Campaign.exfil_cfg(StringName(str(m))).get("cutscene", "")) == id:
			return Campaign.scene_for(StringName(str(m)))
	return ""


func test_every_shot_names_nodes_its_map_has() -> void:
	var fx_nodes: Dictionary = {"doors": ["GreatDoors", "Gate"], "ramp": ["KranichRamp"], "kranich_takeoff": ["Kranich"], "crash": ["WingDiorama"], "launch": ["Rocket"]}
	for id: Variant in _cutscenes().keys():
		var scene: String = _map_scene_for(str(id))
		assert_ne(scene, "", "%s plays on a map" % str(id))
		if scene == "" or not FileAccess.file_exists(scene):
			continue
		var src: String = FileAccess.get_file_as_string(scene)
		for s: Variant in (_cutscenes()[id] as Dictionary).get("shots", []):
			var shot: Dictionary = s
			for key: String in ["target", "rel"]:
				var n: String = str(shot.get(key, ""))
				if n != "" and not n.begins_with("@"):
					assert_true(src.contains("name=\"%s\"" % n), "%s: the %s '%s' is in %s" % [str(id), key, n, scene.get_file()])
			var fx: String = str(shot.get("fx", ""))
			if fx_nodes.has(fx):
				var any: bool = false
				for fn: String in fx_nodes[fx]:
					any = any or src.contains("name=\"%s\"" % fn)
				assert_true(any, "%s: the %s effect's node is in %s" % [str(id), fx, scene.get_file()])


func test_lengths_stay_within_a_third_of_the_old_cut() -> void:
	var old: Dictionary = {"exfil_m0_m1": 30.0, "exfil_m1_m2": 30.0, "exfil_m2_m4": 24.0, "exfil_m4a_m4b": 38.0, "exfil_m4b_m4c": 40.0,
		"exfil_m4c_m4d": 40.0, "m2_letzte_fahrt_dive": 34.0}
	for id: String in old.keys():
		var secs: float = float((_cutscenes().get(id, {}) as Dictionary).get("seconds", 0.0))
		assert_true(secs >= float(old[id]) * 0.7 and secs <= float(old[id]) * 1.3, "%s: %.1f s against %.1f s" % [id, secs, float(old[id])])
