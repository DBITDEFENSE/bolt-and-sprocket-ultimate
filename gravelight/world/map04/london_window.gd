class_name LondonWindow
extends Node
## THE LONDON WINDOW (UPDATE 07, docs/MAP4_FERNFLUG.md §4.6, §11.2): the Act II gut punch, in-scene and cutscene-lite
## on the Requiem ending's pattern: the players keep their place, the camera goes to the aft blister (the LondonCam
## marker) with a letterbox for ~50 s. The heading line; the coast with a rail battery firing three plumes; London
## from altitude (the LondonPlate dressing far below and behind, lit by searchlights); three air-bursts; violet
## snow falling over the plate; 4 s of silence; the Operator's two lines; one squad line each. After it the sky
## through the blisters stays violet to the east (the environment's horizon warms toward violet) for the act.
## Fired by the FlightController at act round `london_window_round` (or by a quest step as a cutscene runner:
## quest_id/step_id set → QuestManager.complete_step at the end). Skippable with [interact] after the first view
## (ProfileSave "seen_london_window").

var quest_id: StringName = &""
var step_id: StringName = &""
var params: Dictionary = {}
var cfg: Dictionary = {}

var _cam: Camera3D
var _layer: CanvasLayer
var _done: bool = false
var _t: float = 0.0
var _was_god: bool = false
var _plumes: Array[Node3D] = []
var _snow: CPUParticles3D
var _seen_before: bool = false
var _muted: bool = false


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad during a cutscene
	var map: Node = get_tree().current_scene
	cfg = (GLData.load_json("res://data/gravelight/map04b.json").get("flight", {}) as Dictionary).get("london", {}) if cfg.is_empty() else cfg
	_was_god = GameState.god_mode
	if Net.is_authority():
		GameState.god_mode = true
	GameState.set_flag(&"london_seen")
	_seen_before = bool(ProfileSave.profile.get("seen_london_window", false))
	ProfileSave.profile["seen_london_window"] = true
	var post: Node3D = map.find_child("LondonCam", true, false) as Node3D
	_cam = Camera3D.new()
	_cam.name = "LondonCamera"
	_cam.far = 1500.0
	_cam.fov = 58.0
	add_child(_cam)
	var at: Vector3 = post.global_position if post != null else Vector3(74, 1.5, 25.4)
	_cam.global_position = at
	_cam.look_at(at + Vector3(0, -0.35, -1.0), Vector3.UP)
	_cam.make_current()
	_build_letterbox()
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	var k: float = 1.0 / speed
	_at(0.2 * k, _beat_heading)
	_at(6.0 * k, _beat_battery)
	_at(18.0 * k, _beat_london)
	_at(24.0 * k, _beat_bursts)
	_at(30.0 * k, _beat_silence)
	_at(34.0 * k, _beat_operator)
	_at(42.0 * k, _beat_squad)
	_at(float(cfg.get("seconds", 50.0)) * k, _finish)


func _at(t: float, f: Callable) -> void:
	get_tree().create_timer(maxf(0.01, t)).timeout.connect(f)


func _build_letterbox() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 0.87
		bar.anchor_bottom = 0.13 if top else 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
	var hint: Label = Label.new()
	hint.name = "Skip"
	hint.text = "[%s] skip" % GLSettings.action_label(&"interact") if _seen_before else ""
	hint.anchor_left = 0.86
	hint.anchor_top = 0.9
	hint.anchor_right = 1.0
	hint.anchor_bottom = 1.0
	_layer.add_child(hint)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var sx: float = sin(_t * 0.6) * 0.004
	_cam.rotation.z = sx
	if _seen_before and _t > 3.0 and Input.is_action_just_pressed(&"interact"):
		_finish()


func _vo(id: String) -> void:
	if id != "" and Net.is_authority():
		GLVO.play(StringName(id))


func _banner(text: String, hold: float = 3.0) -> void:
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", text, hold)


func _plate() -> Node3D:
	return get_tree().current_scene.find_child("LondonPlate", true, false) as Node3D


func _beat_heading() -> void:
	_vo(str(cfg.get("vo_pa", "PA_M4B_HEADING_03")))
	_banner("THE AFT BLISTER", 2.5)


## Three violet-white columns climb from a dark coast, far below and behind.
func _beat_battery() -> void:
	var base: Vector3 = Vector3(74, -60, -40)
	for i: int in 3:
		var col: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 1.4
		cm.height = 1.0
		col.mesh = cm
		col.material_override = Mats.get_mat("nachtglas")
		col.position = base + Vector3(-12.0 + 12.0 * float(i), 0, -8.0 * float(i))
		col.scale = Vector3(1, 0.1, 1)
		add_child(col)
		_plumes.append(col)
		var tw: Tween = create_tween()
		tw.tween_interval(0.6 * float(i) / maxf(0.01, Campaign.cutscene_speed))
		tw.tween_property(col, "scale:y", 90.0, 6.0 / maxf(0.01, Campaign.cutscene_speed)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(col, "position:y", base.y + 45.0, 6.0 / maxf(0.01, Campaign.cutscene_speed))
	AudioDirector.play_2d("grenade_explode", -14.0, 0.0)
	_vo(str((cfg.get("squad", {}) as Dictionary).get("peg", "")))   # Peg: "That's not Morgenrot. That's a second battery."


## London from 8,000 m: the plate's searchlights swing up; the camera tilts down toward it.
func _beat_london() -> void:
	var plate: Node3D = _plate()
	if plate != null:
		for i: int in 3:
			var s: SpotLight3D = SpotLight3D.new()
			s.position = Vector3(-30.0 + 30.0 * float(i), 0.5, 10.0)
			s.rotation.x = deg_to_rad(80.0 - 10.0 * float(i))
			s.light_color = Color(0.85, 0.9, 1.0)
			s.light_energy = 6.0
			s.spot_range = 120.0
			s.spot_angle = 5.0
			s.light_volumetric_fog_energy = 2.0
			s.shadow_enabled = false
			plate.add_child(s)
	var tw: Tween = create_tween()
	tw.tween_method(func(k: float) -> void:
		_cam.look_at(_cam.global_position + Vector3(0, -0.35 - 0.45 * k, -1.0), Vector3.UP), 0.0, 1.0, 5.0 / maxf(0.01, Campaign.cutscene_speed)).set_trans(Tween.TRANS_SINE)


## Three air-bursts over the rooftops, then violet snow.
func _beat_bursts() -> void:
	var plate: Node3D = _plate()
	var base: Vector3 = plate.global_position + Vector3(0, 30, 0) if plate != null else Vector3(74, -10, -120)
	for i: int in 3:
		var l: OmniLight3D = OmniLight3D.new()
		l.position = base + Vector3(-25.0 + 25.0 * float(i), 0, -10.0 + 10.0 * float(i))
		l.light_color = Color(0.85, 0.6, 1.0)
		l.light_energy = 0.0
		l.omni_range = 90.0
		l.shadow_enabled = false
		add_child(l)
		var tw: Tween = create_tween()
		tw.tween_interval(0.5 * float(i) / maxf(0.01, Campaign.cutscene_speed))
		tw.tween_property(l, "light_energy", 24.0, 0.15)
		tw.tween_property(l, "light_energy", 2.0, 2.5)
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		n.set("_shake", 0.25)
	AudioDirector.play_2d("grenade_explode", -4.0, 0.0)
	_snow = CPUParticles3D.new()
	_snow.position = base
	_snow.amount = 600
	_snow.lifetime = 6.0
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(60, 2, 60)
	_snow.direction = Vector3(0, -1, 0)
	_snow.gravity = Vector3(0, -1.5, 0)
	_snow.initial_velocity_min = 0.5
	_snow.initial_velocity_max = 1.5
	_snow.scale_amount_min = 0.15
	_snow.scale_amount_max = 0.35
	_snow.mesh = BoxMesh.new()
	_snow.mesh.set("size", Vector3(0.3, 0.3, 0.3))
	_snow.material_override = Mats.get_mat("nachtglas")
	add_child(_snow)
	# the sky to the east stays violet for the act
	var we: WorldEnvironment = get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null and we.environment != null and we.environment.sky != null:
		var mat: ProceduralSkyMaterial = we.environment.sky.sky_material as ProceduralSkyMaterial
		if mat != null:
			var tw2: Tween = create_tween()
			tw2.tween_property(mat, "sky_horizon_color", Color(0.22, 0.08, 0.3), 8.0 / maxf(0.01, Campaign.cutscene_speed))
			tw2.parallel().tween_property(mat, "ground_horizon_color", Color(0.14, 0.05, 0.2), 8.0 / maxf(0.01, Campaign.cutscene_speed))


## Cut to silence: every bus muted for 4 s.
func _beat_silence() -> void:
	_set_mute(true)
	get_tree().create_timer(4.0 / maxf(0.01, Campaign.cutscene_speed)).timeout.connect(func() -> void: _set_mute(false))


func _set_mute(on: bool) -> void:
	_muted = on
	for i: int in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) != "Master":
			AudioServer.set_bus_mute(i, on)


func _beat_operator() -> void:
	var ids: Array = cfg.get("vo_opr", [])
	if ids.size() > 0:
		_vo(str(ids[0]))
	if ids.size() > 1:
		get_tree().create_timer(4.5 / maxf(0.01, Campaign.cutscene_speed)).timeout.connect(func() -> void: _vo(str(ids[1])))


## One line per character present, 2.5 s apart (Wren's is 3 s of silence subtitled "—"); Peg's second line last.
func _beat_squad() -> void:
	var squad: Dictionary = cfg.get("squad", {})
	var present: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.is_alive():
			var c: String = String(GameState.character_of(p.player_id))
			if squad.has(c) and not present.has(c) and c != "peg":
				present.append(c)
	if get_tree().get_first_node_in_group(&"jakub") != null and squad.has("jakub"):
		present.append("jakub")
	var i: int = 0
	for c2: String in present:
		var id: String = str(squad[c2])
		get_tree().create_timer((0.2 + 2.5 * float(i)) / maxf(0.01, Campaign.cutscene_speed)).timeout.connect(func() -> void: _vo(id))
		i += 1
	if str(cfg.get("peg_after", "")) != "":
		get_tree().create_timer((0.2 + 2.5 * float(i)) / maxf(0.01, Campaign.cutscene_speed)).timeout.connect(func() -> void: _vo(str(cfg["peg_after"])))


func _finish() -> void:
	if _done:
		return
	_done = true
	_set_mute(false)
	if Net.is_authority():
		GameState.god_mode = _was_god
	var map: Node = get_tree().current_scene
	if map != null and map.get("player") != null and (map.get("player") as Player).camera != null:
		(map.get("player") as Player).camera.current = true
	if quest_id != &"" and Net.is_authority():
		QuestManager.complete_step(quest_id, step_id)
	GLBus.flag_changed.emit(&"london_window_done", true)
	queue_free()
