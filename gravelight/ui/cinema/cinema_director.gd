class_name CinemaDirector
extends Node
## T-184: the shot sequencer every cutscene runs on. It owns a CinemaCamera, a CinemaOverlay and (optionally) a
## CinemaCast, and plays a cutscene definition (campaign.json "cutscenes" or a runner's own dictionary) on a clock:
##   seconds, shots[]            the timeline (CinemaShot keys); a shot's events fire at shot-local times:
##                               vo + vo_at, sfx [[t, key, db]], sfx3d [[t, key, [x, y, z], db]], stinger [t, key, db],
##                               caption {text, at, hold}, shake [[t, strength]], squad {...} (CinemaCast.direct),
##                               light {pos, color, energy, range} or a list (a motivated lamp for the shot)
##   grade                       the opening grade (a preset name or values); a shot's own `grade` blends over
##                               `grade_s` (default 1.2 s, 0 on a cut without one)
##   title, subtitle, time, title_at, title_hold    the title card (CinemaOverlay.title_card)
##   fade_at, fade_s             the fade to black at the end; `end` "black" (stay black: a map change follows) or
##                               "return" (the bars and the grade go, the player's camera comes back)
##   music {stop, stinger, stinger_at, bed, bed_db, out_at}   the score: what stops, the opening stinger, an
##                               ambience bed for the scene that swells in and out
## T-194 (UPDATE 11, the LAZARUS cutscenes) adds three shot events:
##   lines [[t, id], ...]        more lines than vo / vo2 (each once, at its shot-local time)
##   card {title, subtitle, time, at, hold}   a title card mid-timeline (once per shot; a title-only card is fine)
##   black true                  the shot is black (a card on black, a sound over black): the picture fades out over
##                               `black_in` (0.4 s); the next shot that is not black fades back in over its `blend`
## T-209 (UPDATE 12 s3, the archive reels) adds video and the film:
##   video, video_from, video_graded   a cinema_video shot: the clip plays for the length of the shot (CinemaVideo)
##   videos [{t0, t1, path, offset, id, graded}]   a video track over the timeline (CinemaArchive's built clips); the
##                               in-engine shots under a span keep running (lines, cards, sounds), only their picture
##                               is covered
##   archive {...}               the archive-film treatment over the picture (CinemaFilm); `archive_card` per shot
##   bars false                  no letterbox (a reel has its own Academy-ratio gate)
## Script-driven cutscenes (the endings) call `play_shot(dict, seconds)` instead of a timeline.
## Signals: shot_started(i, shot), skip_requested, finished. `step(dt)` is the whole update (tests drive it; the
## node drives itself with `auto` on), scaled by `speed` (Campaign.cutscene_speed). `missing` lists any `target` /
## `rel` node name that did not resolve in the map (the clip tool fails on it).

signal shot_started(index: int, shot: CinemaShot)
signal skip_requested
signal finished

const MOVES: Array[String] = ["dolly", "crane", "orbit", "static"]
const CUTS: Array[String] = ["cut", "blend", "dip"]

var def: Dictionary = {}
var shots: Array[CinemaShot] = []
var seconds: float = 30.0
var t: float = 0.0
var speed: float = 1.0
var auto: bool = true
var camera_now: bool = true   # false: the player's view stays until the first shot (an insert in an in-game ending)
var use_cast: bool = true
var hide_hud: bool = true
var vo_func: Callable = Callable()
var map: Node = null
var cam: CinemaCamera = null
var overlay: CinemaOverlay = null
var cast: CinemaCast = null
var shot_i: int = -1
var done: bool = false
var missing: PackedStringArray = []
var _shot_t0: float = 0.0
var _fired: Dictionary = {}
var _lights: Array[Node] = []
var _bed: AudioStreamPlayer = null
var _cache: Dictionary = {}
var _title_shown: bool = false
var _fading: bool = false
var _manual_end: float = -1.0
var _in_black: bool = false   # T-194: the last shot was a black one
var video: CinemaVideo = null   # T-209: the cinema_video track (null: the definition has no video)
var film: CinemaFilm = null     # T-209: the archive-reel treatment (null: not a reel)


## Builds a director under `parent` for `d` over `map_node` (where the shots' node names are found).
static func make(parent: Node, d: Dictionary, map_node: Node, opts: Dictionary = {}) -> CinemaDirector:
	var c: CinemaDirector = CinemaDirector.new()
	c.name = "CinemaDirector"
	c.def = d
	c.map = map_node
	c.speed = maxf(0.01, float(opts.get("speed", Campaign.cutscene_speed)))
	c.use_cast = bool(opts.get("cast", true))
	c.hide_hud = bool(opts.get("hide_hud", true))
	c.vo_func = opts.get("vo", Callable()) as Callable
	c.auto = bool(opts.get("auto", true))
	c.camera_now = bool(opts.get("camera_now", true))
	parent.add_child(c)
	return c


func _ready() -> void:
	add_to_group(&"cinema")
	shots = CinemaShot.list_from(def)
	seconds = float(def.get("seconds", 30.0))
	cam = CinemaCamera.new()
	cam.name = "CinemaCamera"
	cam.far = float(def.get("far", 2000.0))
	cam.resolve = _find
	add_child(cam)
	if camera_now:
		cam.make_current()
	overlay = CinemaOverlay.new()
	overlay.name = "CinemaOverlay"
	overlay.speed = speed
	overlay.skip_after = float(def.get("skip_after", Campaign.cfg().get("skip_after_seconds", 3.0)))
	add_child(overlay)
	overlay.skip.connect(func() -> void: skip_requested.emit())
	if hide_hud:
		overlay.hide_hud(map)
	if use_cast and map != null:
		cast = CinemaCast.gather(map)
	var fade_in: float = float(def.get("fade_in_s", 0.9))   # 0: no fade from black (an in-game ending)
	var opens_black: bool = not shots.is_empty() and bool(shots[0].raw.get("black", false))
	overlay.set_black(1.0 if fade_in > 0.0 or opens_black else 0.0)
	if fade_in > 0.0 and not opens_black:   # (a cutscene that opens on black stays black until its first picture)
		overlay.fade(0.0, fade_in)
	_in_black = opens_black
	if bool(def.get("bars", true)):
		overlay.bars(true, 0.8)
	var vt: Array = CinemaVideo.track_of(def, shots)
	if not vt.is_empty():
		video = CinemaVideo.make(self, vt, speed)
	if def.get("archive", null) is Dictionary:
		film = CinemaFilm.make(self, def["archive"] as Dictionary)
	overlay.grade(def.get("grade", "neutral"), 0.0)
	_music_open()   # (the first shot starts on the first step, after the owner has connected shot_started)


func _process(delta: float) -> void:
	if auto:
		step(delta * speed)


## The clock: shots, their events, the title, the fade, the end. `dt` is cutscene seconds (already scaled).
func step(dt: float) -> void:
	if done:
		return
	t += dt
	var cut: bool = false
	while shot_i + 1 < shots.size() and t >= shots[shot_i + 1].t:
		_next_shot()
		cut = true
	if cam != null:
		cam.advance(t - _shot_t0 - cam.shot_t if cut else dt)   # a new shot starts from its own first frame
	if shot_i >= 0 and shot_i < shots.size():
		_shot_events(shots[shot_i], t - _shot_t0)   # (after the move: a kick lands at full strength on its frame)
	if video != null:
		video.at(t)
	if film != null:
		film.at(t, shot_i)
	if not _title_shown and def.has("title") and t >= float(def.get("title_at", seconds - 8.0)):
		_title_shown = true
		overlay.title_card(str(def.get("title", "")), str(def.get("subtitle", "")), str(def.get("time", "")), float(def.get("title_hold", 6.0)))
	var fade_at: float = float(def.get("fade_at", -1.0))
	if not _fading and fade_at >= 0.0 and t >= fade_at:
		_fading = true
		overlay.fade(1.0, float(def.get("fade_s", maxf(0.5, seconds - fade_at))))
		_music_close()
	var bed_out: float = float((def.get("music", {}) as Dictionary).get("out_at", -1.0))
	if bed_out >= 0.0 and t >= bed_out and not _fired.has("bed_out"):
		_fired["bed_out"] = true
		_music_close()
	if _manual_end >= 0.0 and t >= _manual_end:
		_end()
	elif def.has("shots") and t >= seconds:
		_end()


func _next_shot() -> void:
	shot_i += 1
	var s: CinemaShot = shots[shot_i]
	_begin_shot(s)
	shot_started.emit(shot_i, s)


func _begin_shot(s: CinemaShot) -> void:
	_shot_t0 = s.t
	_clear_lights()
	if cast != null:
		cast.direct(s.raw.get("squad", {}) as Dictionary)
		cast._place_centre()
	if s.target != "":
		_find(s.target)
	if s.rel != "":
		_find(s.rel)
	if not cam.current:
		cam.make_current()
	cam.play(s)
	var is_black: bool = bool(s.raw.get("black", false))
	if is_black:
		if not _in_black:
			overlay.fade(1.0, float(s.raw.get("black_in", 0.4)))
	elif _in_black:
		overlay.fade(0.0, maxf(0.3, s.blend if s.cut != "cut" else 0.6))   # out of black into the picture
	elif s.cut == "dip":
		overlay.dip(maxf(0.2, s.blend))
	_in_black = is_black
	if s.grade != null:
		overlay.grade(s.grade, float(s.raw.get("grade_s", 1.2 if s.cut != "cut" else 0.0)))
	var lt: Variant = s.raw.get("light", null)
	if lt is Dictionary:
		_add_light(lt as Dictionary)
	elif lt is Array:
		for l: Variant in lt as Array:
			if l is Dictionary:
				_add_light(l as Dictionary)


## A script-driven shot (the endings): plays `d` for `secs` from now. Returns the shot.
func play_shot(d: Dictionary, secs: float) -> CinemaShot:
	var dd: Dictionary = d.duplicate()
	dd["t"] = t
	var s: CinemaShot = CinemaShot.from_dict(dd, t + secs)
	shots.append(s)
	shot_i = shots.size() - 1
	_begin_shot(s)
	shot_started.emit(shot_i, s)
	return s


## Ends a script-driven cutscene at `at` cutscene seconds (the timeline ends at `seconds` by itself).
func end_at(at: float) -> void:
	_manual_end = at


func _shot_events(s: CinemaShot, lt: float) -> void:
	var key: String = str(shot_i) + ":"
	var vo: String = str(s.raw.get("vo", ""))
	if vo != "" and lt >= float(s.raw.get("vo_at", 0.5)) and _once(key + "vo"):
		_say(vo)
	var vo2: String = str(s.raw.get("vo2", ""))
	if vo2 != "" and lt >= float(s.raw.get("vo2_at", 3.0)) and _once(key + "vo2"):
		_say(vo2)
	var sfx: Variant = s.raw.get("sfx", [])
	if sfx is Array:
		for i: int in (sfx as Array).size():
			var e: Variant = sfx[i]
			if e is Array and (e as Array).size() >= 2 and lt >= float(e[0]) and _once(key + "sfx%d" % i):
				if AudioDirector.has_sound(str(e[1])):
					AudioDirector.play_2d(str(e[1]), float(e[2]) if (e as Array).size() > 2 else 0.0, 0.0)
	var sfx3: Variant = s.raw.get("sfx3d", [])
	if sfx3 is Array:
		for i: int in (sfx3 as Array).size():
			var e3: Variant = sfx3[i]
			if e3 is Array and (e3 as Array).size() >= 3 and lt >= float(e3[0]) and _once(key + "s3d%d" % i):
				if AudioDirector.has_sound(str(e3[1])):
					AudioDirector.play_3d(str(e3[1]), CinemaShot.v3(e3[2]), float(e3[3]) if (e3 as Array).size() > 3 else 0.0, 0.0)
	var st: Variant = s.raw.get("stinger", null)
	if st is Array and (st as Array).size() >= 2 and lt >= float(st[0]) and _once(key + "stinger"):
		if AudioDirector.has_sound(str(st[1])):
			AudioDirector.play_stinger(str(st[1]), float(st[2]) if (st as Array).size() > 2 else -3.0)
	var cap: Variant = s.raw.get("caption", null)
	if cap is Dictionary and lt >= float((cap as Dictionary).get("at", 0.3)) and _once(key + "cap"):
		overlay.caption(str(cap.get("text", "")), float(cap.get("hold", 4.0)))
	var ln: Variant = s.raw.get("lines", [])
	if ln is Array:
		for li: int in (ln as Array).size():
			var e2: Variant = ln[li]
			if e2 is Array and (e2 as Array).size() >= 2 and str(e2[1]) != "" and lt >= float(e2[0]) and _once(key + "ln%d" % li):
				_say(str(e2[1]))
	var cd: Variant = s.raw.get("card", null)
	if cd is Dictionary and lt >= float((cd as Dictionary).get("at", 0.5)) and _once(key + "card"):
		overlay.title_card(str(cd.get("title", "")), str(cd.get("subtitle", "")), str(cd.get("time", "")), float(cd.get("hold", 5.0)))
	for kv: Variant in s.shake:
		if kv is Array and (kv as Array).size() >= 2 and lt >= float(kv[0]) and _once(key + "kick%.2f" % float(kv[0])):
			cam.impulse(float(kv[1]))


func _once(key: String) -> bool:
	if _fired.has(key):
		return false
	_fired[key] = true
	return true


func _say(id: String) -> void:
	if vo_func.is_valid():
		vo_func.call(id)
	else:
		GLVO.play_local(StringName(id))


## A node of the map by name (cached; first match anywhere under the map). Records names that do not resolve.
func _find(n: String) -> Node3D:
	if n == "@squad":   # the cast's centre (none cast: the shot keeps its own look point)
		return cast.centre_node if cast != null and not cast.actors.is_empty() else null
	if _cache.has(n) and is_instance_valid(_cache[n]):
		return _cache[n] as Node3D
	var found: Node3D = null
	if map != null:
		found = map.find_child(n, true, false) as Node3D
	if found == null and not missing.has(n):
		missing.append(n)
		push_warning("[cinema] no node '%s' for a shot" % n)
	_cache[n] = found
	return found


func _add_light(d: Dictionary) -> void:
	if map == null:
		return
	var l: OmniLight3D = OmniLight3D.new()
	var c: Vector3 = CinemaShot.v3(d.get("color", null), Vector3(1.0, 0.85, 0.65))
	l.light_color = Color(c.x, c.y, c.z)
	l.light_energy = 0.0
	l.omni_range = float(d.get("range", 6.0))
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.light_specular = 0.3
	map.add_child(l)
	l.global_position = CinemaShot.v3(d.get("pos", [0, 2, 0]))
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", float(d.get("energy", 1.2)), 0.6 / maxf(0.01, speed))
	_lights.append(l)


func _clear_lights() -> void:
	for l: Node in _lights:
		if is_instance_valid(l):
			l.queue_free()
	_lights.clear()


func _music_open() -> void:
	var m: Dictionary = def.get("music", {})
	if bool(m.get("stop", true)):
		AudioDirector.stop_all_music()
	var st: String = str(m.get("stinger", ""))
	if st != "" and AudioDirector.has_sound(st):
		AudioDirector.play_stinger(st, float(m.get("stinger_db", -4.0)))
	var bed: String = str(m.get("bed", ""))
	if bed != "" and AudioDirector.has_sound(bed):
		_bed = AudioDirector.make_loop_2d(bed, self, -40.0)
		if _bed != null:
			var tw: Tween = create_tween()
			tw.tween_property(_bed, "volume_db", float(m.get("bed_db", -12.0)), 3.0 / speed).set_trans(Tween.TRANS_SINE)


func _music_close() -> void:
	if _bed != null and is_instance_valid(_bed):
		var tw: Tween = create_tween()
		tw.tween_property(_bed, "volume_db", -40.0, 2.0 / speed).set_trans(Tween.TRANS_SINE)


func _end() -> void:
	if done:
		return
	done = true
	_clear_lights()
	if str(def.get("end", "black")) == "return":
		release()
	finished.emit()


## Back to the game: the bars and the grade go, the black lifts, the stand-ins leave, the HUD and the player's
## camera come back. With `free_after` the director frees itself once the bars are out (keep it under the map, not
## under a runner that frees itself first, or the bars pop instead of sliding).
func release(free_after: bool = false) -> void:
	_clear_lights()
	done = true
	if overlay != null:
		overlay.restore_hud()
		overlay.bars(false, 0.6)
		overlay.grade("neutral", 0.6)
		overlay.fade(0.0, 0.7)
		overlay.skip_enabled = false
	if cast != null and is_instance_valid(cast):
		cast.release()
		cast = null
	var mr: MapRoot = map as MapRoot
	if mr != null and mr.player != null and mr.player.camera != null:
		mr.player.camera.current = true
	_music_close()
	if free_after and is_inside_tree():
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free())


## An insert is over: the player's own camera again (the bars, the grade and the HUD stay as they are).
func back_to_player() -> void:
	var mr: MapRoot = map as MapRoot
	if mr != null and mr.player != null and mr.player.camera != null:
		mr.player.camera.current = true


func _exit_tree() -> void:
	_clear_lights()
	if cast != null and is_instance_valid(cast):
		cast.release()


# ---------------------------------------------------------------- data checks (unit tests, the clip tool)

## Everything wrong with a cutscene definition that can be checked without its map: the timeline in order and inside
## its length, every shot's camera, move, curve, cut, grade and lens, the title / fade times, the sounds (AudioDirector)
## and the VO ids (`lines`, lines.json; skipped when empty). Pure apart from the sound table.
static func validate(d: Dictionary, lines: Dictionary = {}) -> PackedStringArray:
	var out: PackedStringArray = []
	var secs: float = float(d.get("seconds", 0.0))
	if secs <= 0.0:
		out.append("no length")
	var last: float = -1.0
	var shots_a: Array = d.get("shots", [])
	for i: int in shots_a.size():
		var s: Dictionary = shots_a[i]
		var tag: String = "shot %d" % i
		var st: float = float(s.get("t", -1.0))
		if st < 0.0 or st <= last or st >= secs:
			out.append("%s starts at %.2f (out of order or past the end)" % [tag, st])
		last = st
		if not (s.get("from", null) is Array) or (s.get("from") as Array).size() != 3:
			out.append("%s has no camera (from)" % tag)
		for k: String in ["to", "look", "look_to", "target_offset"]:
			if s.has(k) and (not (s[k] is Array) or (s[k] as Array).size() != 3):
				out.append("%s: %s is not a point" % [tag, k])
		if not MOVES.has(str(s.get("move", "dolly"))):
			out.append("%s: unknown move %s" % [tag, str(s.get("move"))])
		for ek: String in ["ease", "look_ease"]:
			if s.has(ek) and not CinemaEase.known(str(s[ek])):
				out.append("%s: unknown curve %s" % [tag, str(s[ek])])
		if not CUTS.has(str(s.get("cut", "cut"))):
			out.append("%s: unknown cut %s" % [tag, str(s.get("cut"))])
		var g: Variant = s.get("grade", null)
		if g is String and not CinemaOverlay.PRESETS.has(g):
			out.append("%s: unknown grade %s" % [tag, g])
		var f0: float = float(s.get("fov", 60.0))
		var f1: float = float(s.get("fov_to", f0))
		if f0 < 15.0 or f0 > 100.0 or f1 < 15.0 or f1 > 100.0:
			out.append("%s: lens out of range (%.0f -> %.0f)" % [tag, f0, f1])
		for key: String in ["vo", "vo2"]:
			if str(s.get(key, "")) != "" and not lines.is_empty() and not lines.has(str(s[key])):
				out.append("%s: VO line %s is not in lines.json" % [tag, str(s[key])])
		for le: Variant in s.get("lines", []):
			if not (le is Array) or (le as Array).size() < 2:
				out.append("%s: a lines entry is not [t, id]" % tag)
			elif not lines.is_empty() and not lines.has(str(le[1])):
				out.append("%s: VO line %s is not in lines.json" % [tag, str(le[1])])
		var cdv: Variant = s.get("card", null)
		if cdv != null and (not (cdv is Dictionary) or str((cdv as Dictionary).get("title", "")) == ""):
			out.append("%s: a card has no title" % tag)
		for e: Variant in s.get("sfx", []):
			if e is Array and (e as Array).size() >= 2 and not AudioDirector.has_sound(str(e[1])):
				out.append("%s: no sound %s" % [tag, str(e[1])])
		for e3: Variant in s.get("sfx3d", []):
			if e3 is Array and (e3 as Array).size() >= 3 and not AudioDirector.has_sound(str(e3[1])):
				out.append("%s: no sound %s" % [tag, str(e3[1])])
		var sg: Variant = s.get("stinger", null)
		if sg is Array and (sg as Array).size() >= 2 and not AudioDirector.has_sound(str(sg[1])):
			out.append("%s: no stinger %s" % [tag, str(sg[1])])
		var vd: Variant = s.get("video", null)
		if vd != null and (not (vd is String) or not str(vd).ends_with(".ogv")):
			out.append("%s: a video is not an .ogv path" % tag)
	for v: Variant in d.get("videos", []):
		if not (v is Dictionary) or not str((v as Dictionary).get("path", "")).ends_with(".ogv") 				or float((v as Dictionary).get("t1", 0.0)) <= float((v as Dictionary).get("t0", 0.0)):
			out.append("a videos entry is not {t0 < t1, path .ogv}")
	var g0: Variant = d.get("grade", null)
	if g0 is String and not CinemaOverlay.PRESETS.has(g0):
		out.append("unknown opening grade %s" % g0)
	if d.has("title_at") and float(d["title_at"]) >= secs:
		out.append("the title comes after the end")
	if d.has("fade_at") and float(d["fade_at"]) > secs:
		out.append("the fade comes after the end")
	var m: Dictionary = d.get("music", {})
	for mk: String in ["stinger", "bed"]:
		if str(m.get(mk, "")) != "" and not AudioDirector.has_sound(str(m[mk])):
			out.append("no music %s %s" % [mk, str(m[mk])])
	return out
