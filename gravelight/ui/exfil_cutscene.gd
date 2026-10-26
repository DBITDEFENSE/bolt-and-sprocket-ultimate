class_name ExfilCutscene
extends Node
## The in-engine transition between two campaign maps (DECISIONS T-033), in the Requiem ending's pattern
## (requiem_ending.gd): timed shots, a free camera, banners, VO. The shots are data (campaign.json
## "cutscenes": camera from/to/look per shot in the departing map's frame, VO ids, effects):
##   "doors"  the map's exit opens: Map 0's great doors fall outward, Map 1's gate rises
##   "dawn"   the moon becomes a low winter sun and the environment warms (the squad leaves at first light)
## plus the letterbox, a title card ("KALTENBRUNN" / "TOTENHAFEN"), a fade to black, and a skip prompt after
## skip_after_seconds (Use; in co-op every human). Every peer runs its own copy for presentation; the host's
## copy ends the transition (ExfilPoint.finish_travel), which loads the next map on everyone.
## Campaign.cutscene_speed > 1 fast-forwards it (tests).

var cutscene_id: String = ""
var exfil: ExfilPoint = null

var _def: Dictionary = {}
var _cam: Camera3D
var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _fade: ColorRect
var _title: Label
var _sub: Label
var _skip: Label
var _t: float = 0.0
var _shot_i: int = -1
var _tween: Tween = null
var _skip_shown: bool = false
var _done: bool = false
var _hidden_hud: Dictionary = {}   # CanvasLayer -> its offset
var _perk_hud_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_def = (Campaign.cfg().get("cutscenes", {}) as Dictionary).get(cutscene_id, {})
	if _def.is_empty():
		push_warning("[campaign] no cutscene '%s' in campaign.json; skipping" % cutscene_id)
	_cam = Camera3D.new()
	_cam.name = "CutsceneCamera"
	_cam.far = 500.0
	add_child(_cam)
	_cam.make_current()
	_build_overlay()
	_hide_hud()
	AudioDirector.stop_all_music()
	AudioDirector.play_stinger("round_end", -4.0)
	if _def.is_empty():
		_finish.call_deferred()


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_top = ColorRect.new()
	_top.color = Color.BLACK
	_top.anchor_right = 1.0
	_top.anchor_bottom = 0.0
	_top.offset_bottom = 0.0
	_layer.add_child(_top)
	_bottom = ColorRect.new()
	_bottom.color = Color.BLACK
	_bottom.anchor_top = 1.0
	_bottom.anchor_right = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.offset_top = 0.0
	_layer.add_child(_bottom)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	var stamp: Font = MenuKit.stamp_font()
	var type_font: Font = MenuKit.type_font()
	MenuKit.apply_theme(_fade)
	_title = Label.new()
	_title.text = str(_def.get("title", ""))
	_title.add_theme_font_override("font", stamp)
	_title.add_theme_font_size_override("font_size", MenuKit.px(112))
	_title.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.custom_minimum_size = Vector2(1400, 0)
	_title.position = Vector2(-700, -110)
	_title.modulate.a = 0.0
	_layer.add_child(_title)
	_sub = Label.new()
	_sub.text = str(_def.get("subtitle", ""))
	_sub.add_theme_font_override("font", type_font)
	_sub.add_theme_font_size_override("font_size", MenuKit.size("subheading"))
	MenuKit.outline(_sub, "menu")
	_sub.add_theme_color_override("font_color", Color(0.62, 0.45, 0.85))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.custom_minimum_size = Vector2(1400, 0)
	_sub.position = Vector2(-700, 20)
	_sub.modulate.a = 0.0
	_layer.add_child(_sub)
	_skip = Label.new()
	_skip.text = ""
	_skip.add_theme_font_override("font", type_font)
	_skip.add_theme_font_size_override("font_size", MenuKit.size("body_large"))
	MenuKit.outline(_skip, "menu")
	_skip.add_theme_color_override("font_color", Color(0.93, 0.89, 0.8, 0.85))
	_skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.position = Vector2(-520, -46)
	_skip.custom_minimum_size = Vector2(500, 0)
	_layer.add_child(_skip)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar: float = vp.y * 0.12
	var tw: Tween = create_tween()
	tw.tween_property(_top, "offset_bottom", bar, 0.6)
	tw.parallel().tween_property(_bottom, "offset_top", -bar, 0.6)


## The gameplay HUD layers are slid off-screen for the transition (they re-assert `visible` themselves; the
## perk HUD lives under PerkManager).
func _hide_hud() -> void:
	var map: Node = get_parent()
	for c: Node in map.get_children():
		if c is CanvasLayer and c != _layer:
			var cl: CanvasLayer = c as CanvasLayer
			_hidden_hud[cl] = cl.offset
			cl.offset = Vector2(0, -8000)
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	if ph != null:
		_perk_hud_offset = ph.offset
		ph.offset = Vector2(0, -8000)


func _restore_hud() -> void:
	for c: Variant in _hidden_hud.keys():
		if is_instance_valid(c):
			(c as CanvasLayer).offset = _hidden_hud[c]
	_hidden_hud.clear()
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	if ph != null:
		ph.offset = _perk_hud_offset


func _process(delta: float) -> void:
	if _done or _def.is_empty():
		return
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	_t += delta * speed
	var shots: Array = _def.get("shots", [])
	while _shot_i + 1 < shots.size() and _t >= float((shots[_shot_i + 1] as Dictionary).get("t", 0.0)):
		_shot_i += 1
		_start_shot(shots[_shot_i] as Dictionary, _shot_i + 1 < shots.size())
	if _title.modulate.a == 0.0 and _t >= float(_def.get("title_at", 20.0)) and not _title.has_meta("shown"):
		_title.set_meta("shown", true)
		_show_title()
	if _t >= float(_def.get("fade_at", 27.0)) and not _fade.has_meta("fading"):
		_fade.set_meta("fading", true)
		var tw: Tween = create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 2.0 / speed)
	if not _skip_shown and _t >= float(Campaign.cfg().get("skip_after_seconds", 3.0)):
		_skip_shown = true
		refresh_skip()
	if _skip_shown and Input.is_action_just_pressed(&"interact") and exfil != null and not exfil.skip_votes.has(Net.local_player_id()):
		exfil.request_skip_local()
	if _t >= float(_def.get("seconds", 30.0)):
		_finish()


func _start_shot(s: Dictionary, has_next: bool) -> void:
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	var shots: Array = _def.get("shots", [])
	var end_t: float = float((shots[_shot_i + 1] as Dictionary).get("t", 0.0)) if has_next else float(_def.get("seconds", 30.0))
	var dur: float = maxf(0.5, end_t - float(s.get("t", 0.0)))
	var from: Vector3 = _v3(s.get("from", [0, 2, 0]))
	var to: Vector3 = _v3(s.get("to", from))
	var look: Vector3 = _v3(s.get("look", to + Vector3.FORWARD))
	_cam.fov = float(s.get("fov", 60.0))
	_cam.global_position = from
	_cam.look_at(look, _up_for(from, look))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(k: float) -> void:
		_cam.global_position = from.lerp(to, k)
		_cam.look_at(look, _up_for(_cam.global_position, look)), 0.0, 1.0, dur / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var vo: String = str(s.get("vo", ""))
	if vo != "":
		get_tree().create_timer(float(s.get("vo_at", 0.5)) / speed).timeout.connect(func() -> void:
			if not _done:
				GLVO.play_local(StringName(vo)))
	match str(s.get("fx", "")):
		"doors":
			_fx_doors()
		"dawn":
			_fx_dawn(dur / speed)
		"ramp":
			_fx_ramp(dur / speed)
		"kranich_takeoff":
			_fx_kranich_takeoff(dur / speed)
		"crash":
			_fx_crash(dur / speed)
		"launch":
			_fx_launch(dur / speed)


static func _v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


## The way out opens: Map 0's barred great doors fall outward; Map 1's yard gate rises.
func _fx_doors() -> void:
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	var map: Node = get_parent()
	var gd: Node3D = map.find_child("GreatDoors", true, false) as Node3D
	if gd != null:
		AudioDirector.play_3d("board_break", gd.global_position + Vector3.UP * 2.0, 4.0, 0.0)
		var tw: Tween = create_tween()
		tw.tween_interval(0.8 / speed)
		tw.tween_property(gd, "rotation:x", deg_to_rad(88.0), 3.6 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			AudioDirector.play_3d("board_slam", gd.global_position + Vector3(0, 0.5, 3.0), 6.0, 0.0)
			for n: Node in get_tree().get_nodes_in_group(&"players"):
				n.set("_shake", 0.7))
		return
	var gate: Node3D = map.find_child("Gate", true, false) as Node3D
	if gate != null:
		AudioDirector.play_3d("door_open", gate.global_position + Vector3.UP * 2.0, 4.0, 0.0)
		var tw2: Tween = create_tween()
		tw2.tween_interval(0.8 / speed)
		tw2.tween_property(gate, "position:y", gate.position.y + 4.6, 4.0 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## First light: the moon turns into a low winter sun, the sky and fog warm up over the shot.
func _fx_dawn(seconds: float) -> void:
	var map: Node = get_parent()
	var moon: DirectionalLight3D = map.find_child("Moon", true, false) as DirectionalLight3D
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	if moon != null:
		tw.tween_property(moon, "light_color", Color(1.0, 0.72, 0.5), seconds)
		tw.tween_property(moon, "light_energy", 1.6, seconds)
		tw.tween_property(moon, "rotation", Vector3(deg_to_rad(-12), deg_to_rad(-70), 0), seconds)
	var we: WorldEnvironment = map.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment.duplicate() as Environment
		we.environment = env
		tw.tween_property(env, "background_color", Color(0.42, 0.27, 0.3), seconds)
		tw.tween_property(env, "ambient_light_color", Color(0.6, 0.48, 0.5), seconds)
		tw.tween_property(env, "ambient_light_energy", 0.9, seconds)
		tw.tween_property(env, "fog_light_color", Color(0.55, 0.38, 0.4), seconds)
		tw.tween_property(env, "fog_density", 0.012, seconds)
		if env.volumetric_fog_enabled:
			tw.tween_property(env, "volumetric_fog_albedo", Color(0.95, 0.8, 0.75), seconds)


## UPDATE 07 Map 4 (docs/MAP4_FERNFLUG.md §11): the Kranich's ramp closes on its own (a node named KranichRamp,
## hinged at its top edge, swings up), the wing rolls out and lifts (a node named Kranich tweens forward and up),
## the wing comes down on the lake bed (a node named WingDiorama slides and sinks, dust and a 1.0 shake), and the
## LANTERN rocket leaves its silo (a node named Rocket climbs). Each is a no-op when its node is missing.
func _fx_ramp(seconds: float) -> void:
	var ramp: Node3D = get_parent().find_child("KranichRamp", true, false) as Node3D
	if ramp == null:
		return
	AudioDirector.play_3d("door_open", ramp.global_position + Vector3.UP, 4.0, -0.6)
	var tw: Tween = create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(ramp, "rotation:x", deg_to_rad(-82.0), maxf(1.0, seconds - 1.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		AudioDirector.play_3d("board_slam", ramp.global_position + Vector3.UP, 5.0, -0.4))


func _fx_kranich_takeoff(seconds: float) -> void:
	var wing: Node3D = get_parent().find_child("Kranich", true, false) as Node3D
	if wing == null:
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		n.set("_shake", 0.4)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(wing, "position:z", wing.position.z + 200.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(wing, "position:y", wing.position.y + 60.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(wing, "rotation:x", deg_to_rad(-8.0), seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _fx_crash(seconds: float) -> void:
	var wing: Node3D = get_parent().find_child("WingDiorama", true, false) as Node3D
	if wing == null:
		return
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(wing, "position:y", wing.position.y - 12.0, seconds * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(wing, "position:z", wing.position.z + 70.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(wing, "rotation:z", deg_to_rad(6.0), seconds * 0.7)
	get_tree().create_timer(seconds * 0.55).timeout.connect(func() -> void:
		if _done:
			return
		AudioDirector.play_3d("board_slam", wing.global_position, 10.0, -0.9)
		for n: Node in get_tree().get_nodes_in_group(&"players"):
			n.set("_shake", 1.0)
		Effects.dust_puff(wing.global_position, "earth", 40))


func _fx_launch(seconds: float) -> void:
	var rocket: Node3D = get_parent().find_child("Rocket", true, false) as Node3D
	if rocket == null:
		return
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		n.set("_shake", 0.8)
	var tw: Tween = create_tween()
	tw.tween_property(rocket, "position:y", rocket.position.y + 400.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _show_title() -> void:
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	AudioDirector.play_stinger("round_start", -3.0)
	var tw: Tween = create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.0 / speed)
	tw.parallel().tween_property(_sub, "modulate:a", 1.0, 1.4 / speed).set_delay(0.4 / speed)


## The skip prompt (and in co-op the tally), shown after skip_after_seconds.
func refresh_skip() -> void:
	if not _skip_shown or _skip == null:
		return
	var key: String = GLSettings.action_label(&"interact")
	var humans: int = GameState.human_ids().size()
	if humans > 1 and exfil != null:
		_skip.text = "[%s] skip  (%d/%d ready)" % [key, exfil.skip_votes.size(), humans]
	else:
		_skip.text = "[%s] skip" % key


## The authority's copy ends the transition; the others are torn down by the scene change or stop().
func _finish() -> void:
	if _done:
		return
	_done = true
	if exfil != null and Net.is_authority():
		exfil.finish_travel()


## Presentation over without a scene change (the target map is missing): back to the map's camera.
func stop() -> void:
	_done = true
	_restore_hud()
	var map: MapRoot = get_parent() as MapRoot
	if map != null and map.player != null and map.player.camera != null:
		map.player.camera.current = true
	queue_free()


## A shot looking straight up or down (the rocket's climb) has no usable world-up; use north as up then.
static func _up_for(eye: Vector3, target: Vector3) -> Vector3:
	var d: Vector3 = target - eye
	if d.length_squared() < 0.0001 or absf(d.normalized().dot(Vector3.UP)) > 0.999:
		return Vector3.FORWARD
	return Vector3.UP
