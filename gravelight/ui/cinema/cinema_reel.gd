class_name CinemaReel
extends Node
## T-194 (UPDATE 11 "LAZARUS"): plays one or more of the LAZARUS cutscenes (CinemaLibrary ids) in a row on the T-184
## cinema library. The picture is a world of its own: a SubViewport with own_world_3d holds the stage (CinemaSet,
## swapped at the shots whose `_set` changes, the dips and blacks hiding the swap) and the CinemaDirector (its camera,
## its overlay: letterbox, grade, cards, captions, hold to skip); a CanvasLayer shows it full screen. So a stage never
## touches the map it plays over (its own sky, sun and fog), costs the map nothing when it is not playing, and the
## same reel plays in a match (GRAVELIGHT ONE before Map 0's opening, STAUB on Kaltenbrunn's arrival), over the main
## menu (the prologue) and from the Archive. While it plays the map's own 3D view is not drawn (root disable_3d).
## The director runs by hand (`auto` off): the reel swaps the stage first, then steps the clock, so a shot's lights,
## targets and effects land on its own stage. Lines go through GLVO (a line's audio when baked, else its subtitle on
## the reading-speed clock; the timeline never waits for either). Signals: cut_started(i, id), cut_ended(i, id,
## skipped), skip_pressed (the local hold: solo skips at once with `auto_skip`; a co-op owner votes instead),
## finished (after the last cut; with `hold_at_end` the reel waits on black for `end_now()`, an online client waiting
## for the host). The reel frees itself after its closing fade.
## T-209 (UPDATE 12 s3): ids go through CinemaArchive: "reel:<id>" plays the archive-reel version (clips where they are
## built, the in-engine shots through the film treatment where not), "engine:<id>" the in-engine scene, a plain id
## whichever the reels data says the game plays. The signals carry the plain library id either way.

signal cut_started(index: int, id: String)
signal cut_ended(index: int, id: String, skipped: bool)
signal skip_pressed
signal finished

const DISPLAY_LAYER: int = 28   # over the HUD (hidden anyway), under the cinema subtitles (31)

var ids: Array[String] = []
var map: Node = null
var speed: float = 1.0
var roster: Array = []
var auto_skip: bool = true
var hold_at_end: bool = false
var index: int = -1
var director: CinemaDirector = null
var def: Dictionary = {}
var done: bool = false
var skipped_any: bool = false
var missing: PackedStringArray = []
var stage: CinemaSet = null
var stage_id: String = ""
var _vp: SubViewport = null
var _layer: CanvasLayer = null
var _tex: TextureRect = null
var _black: ColorRect = null
var _stages: Dictionary = {}
var _seen_shot: int = -1
var _fired: Dictionary = {}
var _beds: Array = []
var _hidden_hud: Dictionary = {}
var _root_3d_was: bool = false
var _waiting_end: bool = false
var _vo_held: bool = false
var _room_set: bool = false


## A reel of `cut_ids` under `parent` (in a match: the MapRoot, whose HUD it hides).
static func play(parent: Node, cut_ids: Array, opts: Dictionary = {}) -> CinemaReel:
	var r: CinemaReel = CinemaReel.new()
	r.name = "CinemaReel"
	for c: Variant in cut_ids:
		if CinemaArchive.is_known(str(c)):
			r.ids.append(str(c))
	r.map = opts.get("map", null)
	r.speed = maxf(0.01, float(opts.get("speed", Campaign.cutscene_speed)))
	r.roster = opts.get("roster", [])
	r.auto_skip = bool(opts.get("auto_skip", true))
	r.hold_at_end = bool(opts.get("hold_at_end", false))
	parent.add_child(r)
	return r


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad; T-194: Map 0's opening waits
	_build_view()
	if map != null:
		_hide_hud()
		GLVO.stop_all()   # T-203: the match's own lines wait for the reel (GLVO.cinema_hold)
		GLVO.cinema_hold += 1
		_vo_held = true
	_root_3d_was = get_tree().root.disable_3d
	get_tree().root.disable_3d = true
	if ids.is_empty():
		_finish.call_deferred()
		return
	_start(0)


func _build_view() -> void:
	_vp = SubViewport.new()
	_vp.name = "Stage"
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.audio_listener_enable_3d = false
	var root: Window = get_tree().root
	var logical: Vector2 = root.get_visible_rect().size
	_vp.size = Vector2i(maxi(64, int(logical.x)), maxi(64, int(logical.y)))
	var win: Vector2 = Vector2(root.size)
	_vp.scaling_3d_scale = clampf(win.x / maxf(1.0, logical.x), 0.4, 1.0)   # a small window renders the 3D small
	_vp.msaa_3d = root.msaa_3d
	_vp.screen_space_aa = root.screen_space_aa
	add_child(_vp)
	_layer = CanvasLayer.new()
	_layer.name = "CinemaScreen"
	_layer.layer = DISPLAY_LAYER
	add_child(_layer)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_tex)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	_layer.add_child(_black)


## The map's HUD layers go off screen for the reel (not the PostFx film look, not the reel's own screen).
func _hide_hud() -> void:
	for c: Node in map.find_children("*", "CanvasLayer", true, false):
		if not (c is PostFx) and not is_ancestor_of(c) and not _hidden_hud.has(c):
			_hidden_hud[c] = (c as CanvasLayer).offset
			(c as CanvasLayer).offset = Vector2(0, -8000)
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	if ph != null and not _hidden_hud.has(ph):
		_hidden_hud[ph] = ph.offset
		ph.offset = Vector2(0, -8000)
	for w: Node in get_tree().root.find_children("WorldMarks", "", true, false):
		if w is Node3D and (w as Node3D).visible:
			(w as Node3D).visible = false
			_hidden_hud[w] = true


func _restore_hud() -> void:
	for c: Variant in _hidden_hud.keys():
		if not is_instance_valid(c):
			continue
		if c is CanvasLayer:
			(c as CanvasLayer).offset = _hidden_hud[c]
		elif c is Node3D:
			(c as Node3D).visible = true
	_hidden_hud.clear()


# ================================================================== the cuts

func _start(i: int) -> void:
	index = i
	var id: String = ids[i]
	def = CinemaArchive.resolved(id, roster)
	_fired.clear()
	_seen_shot = -1
	for sid: String in CinemaLibrary.sets_in(def):
		_stage_for(sid)
	var shots: Array = def.get("shots", [])
	var first: String = str((shots[0] as Dictionary).get("_set", "black")) if not shots.is_empty() else "black"
	_swap(first)
	_room(shots[0] if not shots.is_empty() else {})
	director = CinemaDirector.make(_vp, def, stage, {"speed": speed, "cast": false, "hide_hud": false, "auto": false, "vo": _say})
	director.shot_started.connect(_on_shot)
	director.skip_requested.connect(_on_skip)
	director.finished.connect(_on_finished)
	cut_started.emit(i, CinemaArchive.base_id(id))
	print("[cinema] %s: %.1f s, %d shots, stages %s%s" % [id, float(def.get("seconds", 0.0)), shots.size(), ", ".join(CinemaLibrary.sets_in(def)),
		" (archive reel, %d of %d shots filmed)" % [(def.get("videos", []) as Array).size(), ((def["archive"] as Dictionary).get("spans", []) as Array).size()] if def.has("archive") else ""])


## The built stage for a set id (cached for the reel; "black" or an unknown id: an empty dark stage).
func _stage_for(sid: String) -> CinemaSet:
	if _stages.has(sid):
		return _stages[sid]
	var s: CinemaSet = null
	var path: String = CinemaLibrary.stage_path(sid)
	if path != "" and ResourceLoader.exists(path):
		var ps: PackedScene = load(path) as PackedScene
		s = ps.instantiate() as CinemaSet if ps != null else null
	if s == null:
		if path != "":
			push_warning("[cinema] no stage scene for set %s (%s)" % [sid, path])
			if not missing.has("set:" + sid):
				missing.append("set:" + sid)
		s = CinemaSet.new()
		s.name = "BlackStage"
		s.env({"bg": [0, 0, 0], "ambient": [0, 0, 0], "ambient_e": 0.0, "glow": false})
	s.variant = str((data_set_variants().get(sid, "")))
	s.set_meta("roster", CinemaLibrary.seat_roster(roster))
	s.set_meta("speed", speed)
	s.build()
	LookGrade.apply_stage(s, LookGrade.cinema_id(map, ids[index] if index >= 0 and index < ids.size() else ""))   # UPDATE 12 (T-207): the host map's grade, or the reel's
	_stages[sid] = s
	return s


static func data_set_variants() -> Dictionary:
	return CinemaLibrary.data().get("set_variants", {})


func _swap(sid: String) -> void:
	var s: CinemaSet = _stage_for(sid)
	if s == stage:
		return
	if stage != null and stage.get_parent() == _vp:
		_vp.remove_child(stage)
	stage = s
	stage_id = sid
	_vp.add_child(s)
	_vp.move_child(s, 0)
	if director != null:
		director.map = s
		director._cache.clear()


func _process(delta: float) -> void:
	if done or director == null or director.done:
		return
	var dt: float = delta * speed
	_pre_dip(dt)
	var i: int = CinemaShot.index_at(director.shots, director.t + dt)
	if i != _seen_shot and i >= 0:
		_seen_shot = i
		_swap(str(director.shots[i].raw.get("_set", stage_id)))
		_room(director.shots[i].raw)
	var d: CinemaDirector = director
	d.step(dt)
	for m: String in d.missing:
		if not missing.has(m):
			missing.append(m)
	if d.video != null:
		for vf: String in d.video.failed:
			if not missing.has("video:" + vf):
				missing.append("video:" + vf)
	if director != d or director == null:   # (the cut ended in that step: the next one has started, or the reel is done)
		return
	_timed_fx()
	_tick_beds()


## A cut to another stage by a dip or a blend: the picture goes to black over the first half of the dip *before*
## the shot starts, so the swap happens on black (the director's dip then holds and fades back in).
func _pre_dip(dt: float) -> void:
	var nx: int = director.shot_i + 1
	if nx <= 0 or nx >= director.shots.size() or _fired.has("pre%d" % nx):
		return
	var ns: CinemaShot = director.shots[nx]
	var cur: CinemaShot = director.shots[director.shot_i]
	if bool(ns.raw.get("black", false)) or bool(cur.raw.get("black", false)) or ns.cut == "cut":
		return
	if str(ns.raw.get("_set", stage_id)) == str(cur.raw.get("_set", stage_id)):
		return
	var half: float = maxf(0.2, ns.blend) * 0.5
	if director.t + dt >= ns.t - half:
		_fired["pre%d" % nx] = true
		director.overlay.fade(1.0, half)


## Tools: run the current cut's clock forward to `t` seconds (stage swaps and effects fire on the way; the clip tool's
## --from= looks at one shot without filming the whole cutscene).
func fast_forward(to_t: float) -> void:
	var guard: int = 0
	while director != null and not done and director.t < to_t and guard < 20000:
		_process(0.05 / speed)
		guard += 1


func _on_shot(_i: int, s: CinemaShot) -> void:
	var f: Variant = s.raw.get("fx", null)
	var secs: float = s.dur / speed
	if f is String and str(f) != "":
		stage.fx(str(f), secs)
	elif f is Array:
		for n: Variant in f:
			stage.fx(str(n), secs)


func _timed_fx() -> void:
	var i: int = director.shot_i
	if i < 0 or i >= director.shots.size():
		return
	var s: CinemaShot = director.shots[i]
	var lt: float = director.t - s.t
	var fa: Variant = s.raw.get("fx_at", [])
	if fa is Array:
		for k: int in (fa as Array).size():
			var e: Variant = fa[k]
			var key: String = "%d:fx%d" % [i, k]
			if e is Array and (e as Array).size() >= 2 and lt >= float(e[0]) and not _fired.has(key):
				_fired[key] = true
				var left: float = maxf(0.05, (s.dur - float(e[0])) / speed)
				stage.fx(str(e[1]), float(e[2]) / speed if (e as Array).size() > 2 else left)


## The scene's ambience loops: in at their time, out at theirs (or at the end).
func _tick_beds() -> void:
	var t: float = director.t
	for k: int in (def.get("beds", []) as Array).size():
		var b: Array = def["beds"][k]
		var key: String = "bed%d" % k
		if t >= float(b[0]) and not _fired.has(key) and AudioDirector.has_sound(str(b[1])):
			_fired[key] = true
			var p: AudioStreamPlayer = AudioDirector.make_loop_2d(str(b[1]), self, -40.0)
			if p != null:
				_beds.append([p, b])
				create_tween().tween_property(p, "volume_db", float(b[2]) if b.size() > 2 else -12.0, 2.0 / speed).set_trans(Tween.TRANS_SINE)
	for pb: Array in _beds:
		var p2: AudioStreamPlayer = pb[0]
		var b2: Array = pb[1]
		var out_t: float = float(b2[3]) if b2.size() > 3 else -1.0
		if out_t >= 0.0 and t >= out_t and is_instance_valid(p2) and not p2.has_meta("out"):
			p2.set_meta("out", true)
			create_tween().tween_property(p2, "volume_db", -40.0, 1.5 / speed).set_trans(Tween.TRANS_SINE)


func _stop_beds(seconds: float) -> void:
	for pb: Array in _beds:
		var p: AudioStreamPlayer = pb[0]
		if is_instance_valid(p):
			var tw: Tween = p.create_tween()
			tw.tween_property(p, "volume_db", -40.0, maxf(0.05, seconds)).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(p.queue_free)
	_beds.clear()


func _say(id: String) -> void:
	if not done:
		GLVO.cinema_pass = true
		GLVO.play_local(StringName(id))
		GLVO.cinema_pass = false


## T-205: the lines sit in the shot's space (VORoomAcoustics: the shot's `vo_room`, else its set's preset in
## data/gravelight/vo_rooms.json cinema_sets); the reel's end hands the room back to the map (or dry over the menu).
func _room(shot: Dictionary) -> void:
	if GLVO.rooms == null:
		return
	_room_set = true
	GLVO.rooms.set_cinema(GLVO.rooms.preset_for_shot(str(shot.get("_set", stage_id)), shot))


func _release_vo() -> void:
	if _room_set and GLVO.rooms != null:
		_room_set = false
		GLVO.rooms.clear_cinema()
	if _vo_held:
		_vo_held = false
		GLVO.cinema_hold = maxi(0, GLVO.cinema_hold - 1)


func _on_skip() -> void:
	skip_pressed.emit()
	if auto_skip:
		skip_current()


## Ends the cut playing now (a skip): its lines stop, the next cut (or the end) follows at once.
func skip_current() -> void:
	if done or director == null:
		return
	skipped_any = true
	_end_cut(true)


func _on_finished() -> void:
	_end_cut(false)


func _end_cut(was_skipped: bool) -> void:
	if director == null:
		return
	var id: String = CinemaArchive.base_id(ids[index])
	var d: CinemaDirector = director
	director = null
	if was_skipped:
		GLVO.stop_all()
	_stop_beds(0.4 if was_skipped else 1.2)
	d.queue_free()
	cut_ended.emit(index, id, was_skipped)
	if index + 1 < ids.size():
		_free_unused(index + 1)
		_start(index + 1)
		return
	if hold_at_end and not was_skipped:
		_waiting_end = true
		_black.modulate.a = 1.0
		return
	_finish()


func _free_unused(next_i: int) -> void:
	var keep: Array[String] = CinemaLibrary.sets_in(CinemaLibrary.def(CinemaArchive.base_id(ids[next_i])))
	for sid: Variant in _stages.keys():
		if not keep.has(str(sid)):
			var s: CinemaSet = _stages[sid]
			_stages.erase(sid)
			if s == stage:
				stage = null
			if is_instance_valid(s):
				if s.get_parent() != null:
					s.get_parent().remove_child(s)
				s.queue_free()


## An online client's reel waiting on black: the host's copy has ended, so does this one.
func end_now() -> void:
	if done:
		return
	if director != null:
		var d: CinemaDirector = director
		director = null
		GLVO.stop_all()
		d.queue_free()
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	_stop_beds(0.8)
	_black.modulate.a = 1.0
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_tex.visible = false
	for s: Variant in _stages.values():
		if is_instance_valid(s):
			(s as Node).queue_free()
	_stages.clear()
	stage = null
	get_tree().root.disable_3d = _root_3d_was
	_restore_hud()
	_release_vo()
	finished.emit()
	var tw: Tween = create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(_black, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)


func _exit_tree() -> void:
	_release_vo()
	if not done:
		get_tree().root.disable_3d = _root_3d_was
		_restore_hud()
