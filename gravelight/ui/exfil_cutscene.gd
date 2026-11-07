class_name ExfilCutscene
extends Node
## The in-engine transition between two campaign maps (DECISIONS T-033), shot like film since T-184: the data
## (campaign.json "cutscenes": shots with a camera path, a lens, a curve, a grade, the squad's direction, VO, sound
## and effects; CinemaShot documents the keys) plays on the shared CinemaDirector (eased dollies, cranes and orbits,
## cuts and blends, hand-held drift and impact kicks, the letterbox, the grade, the title card, the HUD hidden, the
## squad played by stand-ins, "hold to skip"). The effects stay here, one per `fx` name:
##   "doors"  the map's exit opens: Map 0's great doors fall outward, Map 1's gate rises
##   "dawn"   the moon becomes a low winter sun and the environment warms (the squad leaves at first light)
##   "ramp", "kranich_takeoff", "crash", "launch"   Map 4's boarding, take-off, crash and rocket (UPDATE 07)
## Every peer runs its own copy for presentation; the host's copy ends the transition (ExfilPoint.finish_travel),
## which loads the next map on everyone. Skipping is a vote: solo at once, co-op when every human has held [interact]
## (ExfilPoint.request_skip_local). With no `exfil` (a quest runner borrows the player, the Letzte Fahrt dive) a skip
## emits `skipped` for the runner and the end emits `ended`. Campaign.cutscene_speed > 1 fast-forwards it (tests).

signal skipped
signal ended

var cutscene_id: String = ""
var exfil: ExfilPoint = null

var _def: Dictionary = {}
var _dir: CinemaDirector = null
var _cam: Camera3D
var _t: float = 0.0
var _shot_i: int = -1
var _done: bool = false
var _perk_hud_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	GameState.hold_flag_while(&"cutscene", self)   # T-142: no relief squad during a cutscene
	_def = (Campaign.cfg().get("cutscenes", {}) as Dictionary).get(cutscene_id, {})
	if _def.is_empty():
		push_warning("[campaign] no cutscene '%s' in campaign.json; skipping" % cutscene_id)
		_finish.call_deferred()
		return
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	if ph != null:
		_perk_hud_offset = ph.offset   # T-122: the perk row outlives a scene change; _exit_tree puts it back
	_dir = CinemaDirector.make(self, _def, get_parent(), {"speed": Campaign.cutscene_speed, "vo": _say})
	_cam = _dir.cam
	_dir.shot_started.connect(_on_shot)
	_dir.skip_requested.connect(_on_skip)
	_dir.finished.connect(_finish)


func _say(id: String) -> void:
	if not _done:
		GLVO.play_local(StringName(id))


func _process(_delta: float) -> void:
	if _dir != null:
		_t = _dir.t


func _on_shot(i: int, shot: CinemaShot) -> void:
	_shot_i = i
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	var dur: float = shot.dur / speed
	match str(shot.raw.get("fx", "")):
		"doors":
			_fx_doors()
		"dawn":
			_fx_dawn(dur)
		"ramp":
			_fx_ramp(dur)
		"kranich_takeoff":
			_fx_kranich_takeoff(dur)
		"crash":
			_fx_crash(dur)
		"launch":
			_fx_launch(dur)
		"moon":
			_fx_moon(shot)


func _on_skip() -> void:
	if exfil == null:
		skipped.emit()
		return
	if not exfil.skip_votes.has(Net.local_player_id()):
		exfil.request_skip_local()


func _kick(strength: float) -> void:
	if _dir != null and _dir.cam != null:
		_dir.cam.impulse(strength)


## The way out opens: Map 0's barred great doors fall outward; Map 1's yard gate rises.
func _fx_doors() -> void:
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	var map: Node = get_parent()
	var gd: Node3D = map.find_child("GreatDoors", true, false) as Node3D
	if gd != null:
		AudioDirector.play_3d("board_break", gd.global_position + Vector3.UP * 2.0, 4.0, 0.0)
		var tw: Tween = create_tween()
		tw.tween_interval(0.9 / speed)
		tw.tween_property(gd, "rotation:x", deg_to_rad(88.0), 2.6 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			AudioDirector.play_3d("board_slam", gd.global_position + Vector3(0, 0.5, 3.0), 6.0, 0.0)
			Effects.dust_puff(gd.global_position + Vector3(0, 0.3, 3.5), "snow", 24)
			_kick(0.55))
		return
	var gate: Node3D = map.find_child("Gate", true, false) as Node3D
	if gate != null:
		AudioDirector.play_3d("door_open", gate.global_position + Vector3.UP * 2.0, 4.0, 0.0)
		AudioDirector.play_3d("lift_winch", gate.global_position + Vector3.UP * 3.0, 2.0, 0.0)
		var tw2: Tween = create_tween()
		tw2.tween_interval(0.8 / speed)
		tw2.tween_property(gate, "position:y", gate.position.y + 4.6, 4.0 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw2.tween_callback(func() -> void: _kick(0.18))


## First light: the moon turns into a low winter sun, the sky and fog warm up over the shot.
func _fx_dawn(seconds: float) -> void:
	var map: Node = get_parent()
	var moon: DirectionalLight3D = map.find_child("Moon", true, false) as DirectionalLight3D
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	if moon != null:
		tw.tween_property(moon, "light_color", Color(1.0, 0.72, 0.5), seconds).set_trans(Tween.TRANS_SINE)
		tw.tween_property(moon, "light_energy", 1.6, seconds).set_trans(Tween.TRANS_SINE)
		tw.tween_property(moon, "rotation", Vector3(deg_to_rad(-12), deg_to_rad(-70), 0), seconds).set_trans(Tween.TRANS_SINE)
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
## the wing comes down on the lake bed (a node named WingDiorama slides and sinks, dust and a kick), and the
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
		AudioDirector.play_3d("board_slam", ramp.global_position + Vector3.UP, 5.0, -0.4)
		_kick(0.3))


func _fx_kranich_takeoff(seconds: float) -> void:
	var wing: Node3D = get_parent().find_child("Kranich", true, false) as Node3D
	if wing == null:
		return
	_kick(0.25)
	AudioDirector.play_2d("war_bomber_drone", -2.0, 0.0)
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
		AudioDirector.play_2d("war_crash_boom", 0.0, 0.0)
		_kick(1.0)
		Effects.dust_puff(wing.global_position, "earth", 40))


func _fx_launch(seconds: float) -> void:
	var rocket: Node3D = get_parent().find_child("Rocket", true, false) as Node3D
	if rocket == null:
		return
	_kick(0.7)
	AudioDirector.play_2d("m4d_pad_launch", 0.0, 0.0)
	var tw: Tween = create_tween()
	tw.tween_property(rocket, "position:y", rocket.position.y + 400.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## T-184: the Moon for MONDLICHT's last shot (the range's sky has none): a pale, pitted disc where the shot looks,
## presentation only, gone with the scene change.
func _fx_moon(shot: CinemaShot) -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = "CutsceneMoon"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 95.0
	sm.height = 190.0
	sm.radial_segments = 48
	sm.rings = 24
	m.mesh = sm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 128
	tex.seamless = true
	mat.albedo_color = Color(0.86, 0.85, 0.88)
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.55, 0.6)
	mat.emission_energy_multiplier = 0.18   # (lit by the range's sun: a phase, not a flat disc)
	mat.roughness = 1.0
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = shot.look_to + (shot.look_to - shot.from).normalized() * 30.0


## The skip prompt's co-op tally (ExfilPoint calls it when the votes change).
func refresh_skip() -> void:
	if _dir == null or _dir.overlay == null:
		return
	var humans: int = GameState.human_ids().size()
	_dir.overlay.skip_note = "(%d/%d ready)" % [exfil.skip_votes.size(), humans] if humans > 1 and exfil != null else ""


## The authority's copy ends the transition; the others are torn down by the scene change or stop().
func _finish() -> void:
	if _done:
		return
	_done = true
	ended.emit()
	if exfil != null and Net.is_authority():
		exfil.finish_travel()


## T-122: the perk row lives under PerkManager and outlives the scene change that ends a transition, so it is put
## back whenever the cutscene leaves the tree (it stayed 8000 px up for the rest of the run: "perks disappear").
func _exit_tree() -> void:
	var ph: CanvasLayer = PerkManager.get("_hud") as CanvasLayer
	if ph != null and is_instance_valid(ph) and ph.offset.y <= -4000.0:
		ph.offset = _perk_hud_offset


## Presentation over without a scene change (the target map is missing, a quest runner's card): back to the map.
func stop() -> void:
	_done = true
	if _dir != null and is_instance_valid(_dir):
		_dir.release()
	var map: MapRoot = get_parent() as MapRoot
	if map != null and map.player != null and map.player.camera != null:
		map.player.camera.current = true
	queue_free()


## A shot looking straight up or down (the rocket's climb) has no usable world-up; use north as up then.
static func _up_for(eye: Vector3, target: Vector3) -> Vector3:
	return CinemaCamera.up_for(eye, target)
