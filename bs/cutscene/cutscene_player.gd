class_name CutscenePlayer
extends Node
## Plays cutscenes.json scenes and story-beat dialogue (runCutscene / csNext / updateCutscene / csAdvance /
## endCutscene / startDialogue / dlgAdvance / updateHoldSkip, index.html:11223-11945).
## Step types:
##   line  -> VOManager line by id (subtitle + voice); waits max(1.8, len*0.05 + 1.1) s or until advanced
##   cam   -> eased move of a cutscene camera: from/to/look/lookTo are [x,y,z] (level space) or helper
##            strings "pPos([x,y,z])" (Bolt + offset) and "<name>Pos([x,y,z])" (host.cutscene_anchor(name)
##            + offset); anything unparseable is skipped
##   act   -> host.cutscene_actor(name) does rise / drop / moveTo; a missing actor just holds for dur
##   fx    -> host.cutscene_fx(scene_id, index, step) if the host has it; the web build's JS is never run
##   wait  -> holds; any other type (notes) is skipped
## ui_advance skips to the next step; holding pause (Esc / Start) for 0.8 s skips the scene.
## BS.ui_block is held while it plays; the world is paused for cutscenes when pause_world is set.

signal started(id: String)
signal finished(id: String)
signal line_played(line_id: String)

const SKIP_HOLD: float = 0.8

var host: Node = null                 # the BSLevel (anchors, actors, fx, bolt)
var pause_world: bool = true
var playing: bool = false
var scene_id: String = ""
var steps: Array = []
var idx: int = -1
var step_t: float = 0.0
var dur: float = 0.0
var skip_t: float = 0.0
var is_dialogue: bool = false
var _data: Dictionary = {}
var _on_done: Callable = Callable()
var _cam: Camera3D = null
var _prev_cam: Camera3D = null
var _layer: CanvasLayer
var _top: ColorRect
var _bot: ColorRect
var _skip: Label
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	_top = _bar(true)
	_bot = _bar(false)
	_skip = BSStyle.label(BSText.text("html.skipLabel.001"), 20, BSStyle.CYAN, 5)
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.position = Vector2(1920 - 260, 1080 - 130)
	_skip.visible = false
	_layer.add_child(_skip)


func _bar(top: bool) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_right = 1.0
	if top:
		r.anchor_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	_layer.add_child(r)
	return r


static func scenes() -> Dictionary:
	var d: Variant = Data.table("bs/story/cutscenes")
	return d as Dictionary if d is Dictionary else {}


static func has_scene(id: String) -> bool:
	return scenes().has(id)


## Plays a cutscenes.json scene. Returns false (and calls on_done) if the id is unknown.
func play(id: String, on_done: Callable = Callable()) -> bool:
	var def: Dictionary = scenes().get(id, {})
	if def.is_empty():
		if on_done.is_valid():
			on_done.call()
		return false
	_start(id, def.get("steps", []), false, on_done)
	return true


## Plays dialogue lines ([{id, who, text}]) as in-game dialogue: no letterbox, no camera.
func play_lines(id: String, lines: Array, on_done: Callable = Callable()) -> bool:
	var st: Array = []
	for l: Variant in lines:
		var d: Dictionary = (l as Dictionary).duplicate()
		d["type"] = "line"
		st.append(d)
	if st.is_empty():
		if on_done.is_valid():
			on_done.call()
		return false
	_start(id, st, true, on_done)
	return true


func _start(id: String, st: Array, dialogue: bool, on_done: Callable) -> void:
	if playing:
		_finish(false)
	playing = true
	scene_id = id
	steps = st
	idx = -1
	skip_t = 0.0
	is_dialogue = dialogue
	_on_done = on_done
	BS.ui_block += 1
	EventBus.interact_prompt.emit("")
	if not dialogue:
		_letterbox(true)
		if pause_world and is_inside_tree():
			_was_paused = get_tree().paused
			get_tree().paused = true
	started.emit(id)
	_next()


func _letterbox(on: bool) -> void:
	for r: ColorRect in [_top, _bot]:
		var tw: Tween = r.create_tween()
		if r == _top:
			tw.tween_property(r, "offset_bottom", 85.0 if on else 0.0, 0.35)
		else:
			tw.tween_property(r, "offset_top", -85.0 if on else 0.0, 0.35)


func _host_bolt() -> Node3D:
	return host.get("bolt") as Node3D if host != null and "bolt" in host else null


func _ensure_cam() -> Camera3D:
	if _cam != null:
		return _cam
	var vp: Viewport = get_viewport()
	_prev_cam = vp.get_camera_3d() if vp != null else null
	_cam = Camera3D.new()
	_cam.name = "CutsceneCam"
	_cam.fov = 60.0
	var parent: Node = host if host is Node3D else (get_parent() if get_parent() is Node3D else null)
	if parent == null:
		parent = self
	parent.add_child(_cam)
	if _prev_cam != null:
		_cam.global_transform = _prev_cam.global_transform
	_cam.current = true
	return _cam


## Resolves a cutscene position: [x,y,z], "pPos([..])" or "<name>Pos([..])". Returns Vector3.INF if unknown.
func vec(v: Variant) -> Vector3:
	var base: Vector3 = Vector3.ZERO
	var off: Vector3
	if v is Array and (v as Array).size() >= 3:
		off = Vector3(float(v[0]), float(v[1]), float(v[2]))
		return (host as Node3D).to_global(off) if host is Node3D else off
	if not (v is String):
		return Vector3.INF
	var rx: RegEx = RegEx.create_from_string("^\\s*(\\w+)\\(\\s*\\[([^\\]]*)\\]\\s*\\)\\s*$")
	var m: RegExMatch = rx.search(str(v))
	if m == null:
		return Vector3.INF
	var nums: PackedStringArray = m.get_string(2).split(",")
	if nums.size() < 3:
		return Vector3.INF
	off = Vector3(nums[0].to_float(), nums[1].to_float(), nums[2].to_float())
	var fn: String = m.get_string(1)
	if fn == "pPos":
		var b: Node3D = _host_bolt()
		if b == null:
			return Vector3.INF
		base = b.global_position
	else:
		var anchor: String = fn.trim_suffix("Pos")
		if host != null and host.has_method("cutscene_anchor"):
			base = host.call("cutscene_anchor", anchor)
		elif host != null and "spawn_point" in host:
			base = host.get("spawn_point")
	return base + off


func _next() -> void:
	idx += 1
	step_t = 0.0
	_data = {}
	if idx >= steps.size():
		_finish(true)
		return
	var s: Dictionary = steps[idx]
	match str(s.get("type", "")):
		"line", "dlg":
			var id: String = str(s.get("id", ""))
			var text: String = BSText.text(id, str(s.get("text", "")))
			dur = float(s.get("dur", maxf(1.8, text.length() * 0.05 + 1.1)))
			if id != "" and BSText.has(id):
				BSText.say(id)
			else:
				EventBus.subtitle.emit(str(BSText.speaker(str(s.get("who", ""))).get("name", str(s.get("who", "")).to_upper())), text,
					Color.from_string(str(BSText.speaker(str(s.get("who", ""))).get("color", "#ffffff")), Color.WHITE), dur)
			if str(s.get("who", "")) == "sprocket" and host != null and "sprocket" in host and host.get("sprocket") != null:
				(host.get("sprocket") as Node).call("set_mood", &"smug", dur)
			line_played.emit(id)
		"cam":
			dur = float(s.get("dur", 2.0))
			var to: Vector3 = vec(s.get("to"))
			if to == Vector3.INF or not is_inside_tree():
				dur = 0.0
				_next()
				return
			var c: Camera3D = _ensure_cam()
			var from: Vector3 = vec(s["from"]) if s.has("from") else c.global_position
			_data = {"a": c.global_position if from == Vector3.INF else from, "b": to,
				"la": vec(s["look"]) if s.has("look") else Vector3.INF}
			_data["lb"] = vec(s["lookTo"]) if s.has("lookTo") else _data["la"]
		"act":
			dur = float(s.get("dur", 1.5))
			var a: Node3D = host.call("cutscene_actor", str(s.get("actor", ""))) as Node3D \
				if host != null and host.has_method("cutscene_actor") else null
			_data = {"actor": a}
			if a != null:
				var st: Vector3 = a.position
				if str(s.get("kind", "")) == "drop":
					st.y -= float(s.get("h", 0.0))
				_data["start"] = st
		"fx":
			dur = 0.01
			if host != null and host.has_method("cutscene_fx"):
				host.call("cutscene_fx", scene_id, idx, s)
		"wait":
			dur = float(s.get("dur", 1.0))
		_:
			dur = 0.0
			_next()


func _process(delta: float) -> void:
	if not playing:
		return
	var dt: float = minf(delta, 0.1)
	if Input.is_action_just_pressed(&"ui_advance"):
		advance()
		if not playing:
			return
	var held: bool = Input.is_action_pressed(&"pause")
	skip_t = skip_t + dt if held else 0.0
	_skip.visible = skip_t > 0.04
	if skip_t >= SKIP_HOLD:
		skip()
		return
	step(dt)


## Advances time by dt (the player calls it every frame; tests call it directly).
func step(dt: float) -> void:
	if not playing or idx < 0 or idx >= steps.size():
		return
	var s: Dictionary = steps[idx]
	step_t += dt
	var k: float = clampf(step_t / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var e: float = k * k * (3.0 - 2.0 * k)
	match str(s.get("type", "")):
		"cam":
			if _cam != null and _data.has("b"):
				_cam.global_position = (_data["a"] as Vector3).lerp(_data["b"], e)
				if _data["la"] != Vector3.INF:
					var lt: Vector3 = (_data["la"] as Vector3).lerp(_data["lb"] if _data["lb"] != Vector3.INF else _data["la"], e)
					if lt.distance_to(_cam.global_position) > 0.01:
						_cam.look_at(lt, Vector3.UP)
		"act":
			var a: Node3D = _data.get("actor") as Node3D
			if a != null and is_instance_valid(a):
				var st: Vector3 = _data["start"]
				match str(s.get("kind", "")):
					"rise":
						a.position.y = st.y + e * float(s.get("h", 0.0))
						a.rotation.y += dt * float(s.get("spin", 0.0))
					"drop":
						a.position.y = st.y + float(s.get("h", 0.0)) * (1.0 - e)
					"moveTo":
						var to: Vector3 = vec(s.get("to"))
						if to != Vector3.INF:
							a.global_position = a.get_parent().to_global(st).lerp(to, e) if a.get_parent() is Node3D else st.lerp(to, e)
	if step_t >= dur:
		_next()


## ui_advance: move on to the next step now.
func advance() -> void:
	if not playing:
		return
	step_t = dur + 1.0
	_next()


## Hold-to-skip: end the whole scene.
func skip() -> void:
	if playing:
		_finish(true)


func _finish(run_callback: bool) -> void:
	playing = false
	_skip.visible = false
	BS.ui_block = maxi(0, BS.ui_block - 1)
	if not is_dialogue:
		_letterbox(false)
		if pause_world and is_inside_tree():
			get_tree().paused = _was_paused
	if _cam != null:
		_cam.queue_free()
		_cam = null
		if _prev_cam != null and is_instance_valid(_prev_cam):
			_prev_cam.current = true
	var id: String = scene_id
	if not is_dialogue:
		BS.set_flag("cs." + id)
	var cb: Callable = _on_done
	_on_done = Callable()
	finished.emit(id)
	if run_callback and cb.is_valid():
		cb.call()
