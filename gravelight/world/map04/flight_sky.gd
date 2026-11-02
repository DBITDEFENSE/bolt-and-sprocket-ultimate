class_name FlightSky
extends Node3D
## The outside of der Kranich (UPDATE 09 section 5.3, DECISIONS T-147): everything the squad sees through the
## blisters, the flight-deck glass, the portholes, the breaches and the bay's torn door, and the swaying inside.
## Presentation only, local on every peer, no gameplay state; data: map04b.json "flight" > "sky".
##   the night     a sky shader on the act's WorldEnvironment: stars, the moon's disc where the Moon light comes from,
##                 the violet in the east after the London window (london_window.gd's own sky tween targets the old
##                 ProceduralSkyMaterial, so FlightSky does it), the dawn for the crash
##   clouds        2-3 sheets far below, quads that follow the camera with the pattern in world space, each scrolling
##                 aft at its own speed (no volumetrics: the web profile's depth fog is all it needs)
##   below         a ground plane that follows the camera: the North Sea, the English coast, London, the coast out,
##                 the Atlantic, the American coast, the dark land west; the leg follows the act round (`legs`), a
##                 coast sweeps past over `coast_s` seconds of its leg
##   London        while the LondonWindow runs (its own clock `_t`, never changed): searchlight beams from the city,
##                 flak bursts round the aft blister between flak_from_s and flak_to_s; beams stay for the leg
##   fighters      passes_per_round silhouettes streak past per round (and one with every FlightController strafe):
##                 a dark shape with an exhaust glow, a tracer burst, the war_fighter_pass roar following it
##   turbulence    the FlightController's bank swings everything in the group "flight_swing" (lamps, harness straps)
##                 as damped pendulums and keeps a small shake on the local camera; "flight_spin" nodes turn (the
##                 impeller, gyros), "flight_rod" nodes slide (control rods)
##   the crash     when the exfil cutscene starts: the salt flat at dawn, a hangar and a flag, the WingDiorama shown
## Pure rules are static for the tests (leg_index_for, ground_state, pass_times, london_phase, swing_step).

const DATA: String = "res://data/gravelight/map04b.json"
const SKY_SHADER: String = "res://gravelight/world/map04/flight_sky_bg.gdshader"
const CLOUD_SHADER: String = "res://gravelight/world/map04/cloud_layer.gdshader"
const GROUND_SHADER: String = "res://gravelight/world/map04/ground_below.gdshader"
const BEAM_SHADER: String = "res://gravelight/world/map04/light_beam.gdshader"
const WING_Z: float = 37.0
const FAR: float = 100000.0

var cfg: Dictionary = {}
var legs: Array = []
var leg: Dictionary = {}
var leg_index: int = -1
var leg_t: float = 0.0
var flight_t: float = 0.0
var round_t: float = 0.0
var desert: bool = false
var passes_done: int = 0
var passes_left: Array[float] = []

var _sky_mat: ShaderMaterial = null
var _clouds: Array[MeshInstance3D] = []
var _cloud_mats: Array[ShaderMaterial] = []
var _cloud_cfg: Array = []
var _ground: MeshInstance3D = null
var _ground_mat: ShaderMaterial = null
var _ground_y: float = -300.0
var _ground_y_target: float = -300.0
var _east: float = 0.0
var _dawn: float = 0.0
var _flash: float = 0.0
var _flash_pos: Vector3 = Vector3(0, -1000, 0)
var _fc: Node = null
var _last_strafes: int = 0
var _fighters: Array[Dictionary] = []
var _fighter_mesh: ArrayMesh = null
var _fighter_mat: StandardMaterial3D = null
var _glow_mat: StandardMaterial3D = null
var _tracer_mat: StandardMaterial3D = null
var _beams: Array[Node3D] = []
var _beam_mat: ShaderMaterial = null
var _flak: Array[Dictionary] = []
var _flak_mat: StandardMaterial3D = null
var _smoke_mat: StandardMaterial3D = null
var _flak_t: float = 0.0
var _london: Node = null
var _desert_set: Node3D = null
var _swing: Dictionary = {}       # instance id -> {node, base, angle, vel, omega}
var _spin: Array[Node3D] = []
var _rods: Array = []             # [node, base_pos]
var _scan_t: float = 0.0
var _shake_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ---------------------------------------------------------------- pure rules

## The leg the act round flies (the last leg whose act_round <= the round; the first leg before round 1).
static func leg_index_for(leg_list: Array, act_round: int) -> int:
	var best: int = 0
	for i: int in leg_list.size():
		if int((leg_list[i] as Dictionary).get("act_round", 1)) <= act_round:
			best = i
	return best


## What lies below at `t` seconds into a leg: {"coast_z": world z of the coastline, "land_ahead": 1 when the land is
## on the +Z (nose) side of the line}. sea / land are all one thing; a coast sweeps from coast_span ahead of the wing
## to coast_span behind it over coast_s seconds.
static func ground_state(a_leg: Dictionary, t: float) -> Dictionary:
	var kind: String = str(a_leg.get("below", "sea"))
	match kind:
		"land":
			return {"coast_z": -FAR, "land_ahead": 1.0}
		"coast_in", "coast_out":
			var s: float = maxf(1.0, float(a_leg.get("coast_s", 150.0)))
			var span: float = float(a_leg.get("coast_span", 900.0))
			var k: float = clampf(t / s, 0.0, 1.0)
			return {"coast_z": WING_Z + lerpf(span, -span, k), "land_ahead": 1.0 if kind == "coast_in" else 0.0}
	return {"coast_z": FAR, "land_ahead": 1.0}


## True when a point at world z is over land in that ground state (tests; the shader's side test without the wiggle).
static func is_land(state: Dictionary, z: float) -> bool:
	var line: float = z - float(state.get("coast_z", FAR))
	return (line if float(state.get("land_ahead", 1.0)) > 0.5 else -line) > 0.0


## The seconds into a round the fighter passes come at: `count` of them, one per equal slot of the window after
## first_s, jittered inside its slot, deterministic per round (every peer sees them at the same moments).
static func pass_times(round_number: int, count: int, first_s: float, window_s: float) -> Array[float]:
	var out: Array[float] = []
	if count <= 0:
		return out
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = hash("kranich_fighters_%d" % round_number)
	var slot: float = maxf(1.0, window_s / float(count))
	for i: int in count:
		out.append(first_s + slot * float(i) + r.randf_range(0.1, 0.8) * slot)
	return out


## The London window's outside, by the window's own clock (beat seconds): searchlights, flak.
static func london_phase(beat_t: float, lc: Dictionary) -> Dictionary:
	return {"beams": beat_t >= float(lc.get("beams_from_s", 12.0)),
		"flak": beat_t >= float(lc.get("flak_from_s", 16.0)) and beat_t < float(lc.get("flak_to_s", 29.5))}


## One step of a damped pendulum toward `target` (radians): returns Vector2(angle, velocity).
static func swing_step(angle: float, vel: float, target: float, omega: float, damping: float, dt: float) -> Vector2:
	var acc: float = -omega * omega * (angle - target) - damping * vel
	vel += acc * dt
	angle += vel * dt
	return Vector2(angle, vel)


# ---------------------------------------------------------------- setup

func _ready() -> void:
	add_to_group(&"flight_sky")
	_rng.randomize()
	var d: Dictionary = GLData.load_json(DATA)
	cfg = (d.get("flight", {}) as Dictionary).get("sky", {})
	legs = cfg.get("legs", [])
	_cloud_cfg = cfg.get("cloud_layers", [])
	_build_sky()
	_build_clouds()
	_build_ground()
	_build_materials()
	_build_desert()
	var wd: Node3D = _scene_find("WingDiorama") as Node3D
	if wd != null:
		wd.visible = false
	if not GLBus.round_started.is_connected(_on_round_started):
		GLBus.round_started.connect(_on_round_started)
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started)
	_set_leg(leg_index_for(legs, _act_round()))
	_ground_y = _ground_y_target
	passes_left = pass_times(_round_number(), int((cfg.get("fighters", {}) as Dictionary).get("passes_per_round", 3)),
		float((cfg.get("fighters", {}) as Dictionary).get("first_s", 20.0)), float((cfg.get("fighters", {}) as Dictionary).get("window_s", 150.0)))
	_rescan()


func _scene_find(n: String) -> Node:
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if root == null:
		return null
	return root.find_child(n, true, false)


func _act_round() -> int:
	var ar: int = 1
	if RoundManager != null and RoundManager.has_method("act_round"):
		ar = int(RoundManager.act_round())
	return maxi(1, ar)


func _round_number() -> int:
	return int(RoundManager.current_round) if RoundManager != null else 1


func _on_match_started(_map: StringName) -> void:
	_set_leg(leg_index_for(legs, _act_round()))


func _on_round_started(_r: int, _special: bool) -> void:
	round_t = 0.0
	var fc: Dictionary = cfg.get("fighters", {})
	passes_left = pass_times(_round_number(), int(fc.get("passes_per_round", 3)), float(fc.get("first_s", 20.0)), float(fc.get("window_s", 150.0)))
	var i: int = leg_index_for(legs, _act_round())
	if i != leg_index:
		_set_leg(i)


func _set_leg(i: int) -> void:
	if legs.is_empty():
		leg = {"below": "sea"}
		leg_index = 0
	else:
		leg_index = clampi(i, 0, legs.size() - 1)
		leg = legs[leg_index]
	leg_t = 0.0
	_ground_y_target = float(leg.get("ground_y", cfg.get("ground_y", -300.0)))
	if leg_index >= 0 and _ground == null:
		_ground_y = _ground_y_target
	var cys: Array = leg.get("cloud_y", [])
	for k: int in _clouds.size():
		var base: Dictionary = _cloud_cfg[k] if k < _cloud_cfg.size() else {}
		_clouds[k].position.y = float(cys[k]) if k < cys.size() else float(base.get("y", -80.0 - 60.0 * k))
		_cloud_mats[k].set_shader_parameter("coverage", float(base.get("coverage", 0.5)) * float(leg.get("clouds", 1.0)))
	if _ground_mat != null:
		var lights: String = str(leg.get("lights", "blackout"))
		_ground_mat.set_shader_parameter("lights", {"none": 0.0, "blackout": 0.06, "towns": 0.45, "london": 0.15}.get(lights, 0.06))
		_ground_mat.set_shader_parameter("city", 1.0 if lights == "london" else 0.0)
		_ground_mat.set_shader_parameter("world_scale", float(leg.get("world_scale", 1.0)))
		var plate: Node3D = _scene_find("LondonPlate") as Node3D
		if plate != null:
			_ground_mat.set_shader_parameter("city_pos", plate.global_position)
	_set_beams(str(leg.get("lights", "")) == "london")
	print("[sky] leg %d: %s" % [leg_index, str(leg.get("below", "sea"))])


func _build_sky() -> void:
	var we: WorldEnvironment = _scene_find("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	var sh: Shader = load(SKY_SHADER) as Shader
	if sh == null:
		return
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sh
	var haze: Color = Color(str(cfg.get("haze", "#080a10")))
	_sky_mat.set_shader_parameter("haze_color", haze)
	if we.environment.sky == null:
		we.environment.sky = Sky.new()
	we.environment.sky.sky_material = _sky_mat
	we.environment.background_mode = Environment.BG_SKY


func _quad(size: float) -> PlaneMesh:
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	return pm


func _build_clouds() -> void:
	var sh: Shader = load(CLOUD_SHADER) as Shader
	var r: float = float(cfg.get("radius", 380.0))
	for k: int in _cloud_cfg.size():
		var c: Dictionary = _cloud_cfg[k]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "CloudSheet%d" % k
		mi.mesh = _quad(r * 2.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(0, float(c.get("y", -80.0)), WING_Z)
		mi.extra_cull_margin = r
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("scale", float(c.get("scale", 420.0)))
		m.set_shader_parameter("coverage", float(c.get("coverage", 0.5)))
		m.set_shader_parameter("opacity", float(c.get("opacity", 0.75)))
		m.set_shader_parameter("radius", r)
		m.render_priority = -k   # the lower sheet draws first
		mi.material_override = m
		add_child(mi)
		_clouds.append(mi)
		_cloud_mats.append(m)


func _build_ground() -> void:
	var sh: Shader = load(GROUND_SHADER) as Shader
	var r: float = float(cfg.get("radius", 380.0))
	_ground = MeshInstance3D.new()
	_ground.name = "GroundBelow"
	_ground.mesh = _quad(r * 2.2)
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.extra_cull_margin = r
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = sh
	_ground_mat.set_shader_parameter("haze_color", Color(str(cfg.get("haze", "#080a10"))))
	_ground_mat.set_shader_parameter("radius", r)
	_ground.material_override = _ground_mat
	_ground_y = float(cfg.get("ground_y", -300.0))
	_ground.position = Vector3(0, _ground_y, WING_Z)
	add_child(_ground)
	var moon: DirectionalLight3D = _scene_find("Moon") as DirectionalLight3D
	if moon != null:
		_ground_mat.set_shader_parameter("moon_dir", moon.global_basis.z.normalized())


func _soft_dot(inner: Color, outer: Color) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


func _build_materials() -> void:
	_fighter_mat = StandardMaterial3D.new()
	_fighter_mat.albedo_color = Color(0.035, 0.037, 0.04)
	_fighter_mat.roughness = 0.6
	_fighter_mat.metallic = 0.3
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glow_mat.albedo_texture = _soft_dot(Color(1.0, 0.7, 0.35, 1.0), Color(0, 0, 0, 0))
	_glow_mat.disable_fog = true
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.62, 0.25)
	_tracer_mat.emission_enabled = true
	_tracer_mat.emission = Color(1.0, 0.6, 0.25)
	_tracer_mat.emission_energy_multiplier = 4.0
	_tracer_mat.disable_fog = true
	_flak_mat = StandardMaterial3D.new()
	_flak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flak_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flak_mat.albedo_texture = _soft_dot(Color(1.0, 0.85, 0.6, 1.0), Color(0, 0, 0, 0))
	_flak_mat.disable_fog = true
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_smoke_mat.albedo_texture = _soft_dot(Color(0.06, 0.06, 0.07, 0.85), Color(0.06, 0.06, 0.07, 0.0))
	_smoke_mat.disable_fog = true
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = load(BEAM_SHADER) as Shader
	_fighter_mesh = _make_fighter_mesh()


## A generic single-engine fighter silhouette (no markings): fuselage, wings, tailplane, fin; nose toward -Z.
func _make_fighter_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = [
		[Vector3(0, 0, 0), Vector3(1.1, 1.2, 9.0)],          # fuselage
		[Vector3(0, -0.2, -0.6), Vector3(11.0, 0.18, 2.0)],  # wings
		[Vector3(0, 0.1, 3.9), Vector3(4.0, 0.12, 1.1)],     # tailplane
		[Vector3(0, 0.95, 4.0), Vector3(0.14, 1.5, 1.2)],    # fin
		[Vector3(0, 0.55, -1.2), Vector3(0.8, 0.5, 1.6)],    # canopy
	]
	for p: Array in parts:
		var bm: BoxMesh = BoxMesh.new()
		bm.size = p[1]
		st.append_from(bm, 0, Transform3D(Basis.IDENTITY, p[0]))
	return st.commit()


func _build_desert() -> void:
	# the crash's set dressing (gen_map04b's SaltFlat / HangarDio / FlagDio are hidden boxes): shown only at the crash
	_desert_set = Node3D.new()
	_desert_set.name = "DesertSet"
	_desert_set.visible = false
	add_child(_desert_set)
	var y0: float = -186.0
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.3, 0.24)
	wood.roughness = 0.9
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.12, 0.12)
	var items: Array = [
		[Vector3(15, y0 + 5.0, -5), Vector3(30, 10, 30), wood],        # the hangar
		[Vector3(15, y0 + 11.0, -5), Vector3(31, 2, 31), dark],        # its roof
		[Vector3(-10, y0 + 4.0, -30), Vector3(0.2, 8, 0.2), dark],     # the flag pole
		[Vector3(-9, y0 + 7.5, -30), Vector3(2.0, 1.0, 0.05), dark],   # the flag
	]
	for it: Array in items:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = it[1]
		mi.mesh = bm
		mi.position = it[0]
		mi.material_override = it[2]
		_desert_set.add_child(mi)


func _set_beams(on: bool) -> void:
	if on and _beams.is_empty():
		var plate: Node3D = _scene_find("LondonPlate") as Node3D
		var base: Vector3 = plate.global_position if plate != null else Vector3(74, -40, -120)
		var lc: Dictionary = cfg.get("london", {})
		var n: int = int(lc.get("beams", 6))
		for i: int in n:
			var pivot: Node3D = Node3D.new()
			pivot.name = "Searchlight%d" % i
			pivot.position = base + Vector3(-80.0 + 160.0 * float(i) / maxf(1.0, float(n - 1)), 0.3, _rng.randf_range(-40.0, 40.0))
			var mi: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			var h: float = float(lc.get("beam_length", 170.0))
			cm.top_radius = 7.0
			cm.bottom_radius = 0.5
			cm.height = h
			cm.cap_top = false
			cm.cap_bottom = false
			cm.radial_segments = 12
			cm.rings = 1
			mi.mesh = cm
			mi.position = Vector3(0, h * 0.5, 0)
			mi.material_override = _beam_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(mi)
			pivot.set_meta("phase", _rng.randf_range(0.0, TAU))
			pivot.set_meta("tilt", _rng.randf_range(12.0, 38.0))
			add_child(pivot)
			_beams.append(pivot)
	for b: Node3D in _beams:
		b.visible = on


func _rescan() -> void:
	_fc = get_tree().get_first_node_in_group(&"flight_controller")
	for n: Node in get_tree().get_nodes_in_group(&"flight_swing"):
		var n3: Node3D = n as Node3D
		if n3 == null or _swing.has(n3.get_instance_id()):
			continue
		var length: float = float(n3.get_meta("swing_len", 1.0))
		_swing[n3.get_instance_id()] = {"node": n3, "base": n3.transform.basis, "angle": 0.0, "vel": 0.0,
			"omega": sqrt(9.81 / maxf(0.2, length)), "phase": _rng.randf_range(0.0, TAU)}
	_spin.clear()
	for n2: Node in get_tree().get_nodes_in_group(&"flight_spin"):
		if n2 is Node3D:
			_spin.append(n2 as Node3D)
	if _rods.is_empty():
		for n4: Node in get_tree().get_nodes_in_group(&"flight_rod"):
			if n4 is Node3D:
				_rods.append([n4, (n4 as Node3D).position])
	if _london == null or not is_instance_valid(_london):
		_london = null
		var root: Node = get_tree().current_scene
		if root != null:
			for c: Node in root.get_children():
				if c is LondonWindow:
					_london = c
	if not desert:
		var root2: Node = get_tree().current_scene
		if root2 != null:
			for c2: Node in root2.get_children():
				if c2 is ExfilCutscene:
					_go_desert()


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	flight_t += delta
	leg_t += delta
	round_t += delta
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_rescan()
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cp: Vector3 = cam.global_position if cam != null else Vector3(0, 1.6, WING_Z)
	_tick_layers(delta, cp)
	_tick_turbulence(delta)
	_tick_fighters(delta)
	_tick_london(delta)
	_tick_flak(delta)
	_flash = maxf(0.0, _flash - delta * 3.0)
	if _sky_mat != null:
		_sky_mat.set_shader_parameter("east_glow", _east)
		_sky_mat.set_shader_parameter("dawn", _dawn)
		_sky_mat.set_shader_parameter("flash", _flash)


func _tick_layers(delta: float, cp: Vector3) -> void:
	var speed_k: float = 0.0 if desert else float(leg.get("speed_k", 1.0))
	for k: int in _clouds.size():
		var c: Dictionary = _cloud_cfg[k] if k < _cloud_cfg.size() else {}
		var mi: MeshInstance3D = _clouds[k]
		mi.position.x = cp.x
		mi.position.z = cp.z
		var m: ShaderMaterial = _cloud_mats[k]
		m.set_shader_parameter("scroll", Vector2(0.0, fmod(flight_t * float(c.get("speed", 20.0)) * speed_k, 40000.0)))
		m.set_shader_parameter("center", cp)
		m.set_shader_parameter("violet", _east)
		m.set_shader_parameter("flash", _flash)
		m.set_shader_parameter("flash_pos", _flash_pos)
		if desert:
			m.set_shader_parameter("opacity", maxf(0.0, float(m.get_shader_parameter("opacity")) - delta * 0.3))
	if _ground != null:
		_ground_y = move_toward(_ground_y, _ground_y_target, delta * 60.0)
		_ground.position = Vector3(cp.x, _ground_y, cp.z)
		var gs: Dictionary = ground_state(leg, leg_t)
		_ground_mat.set_shader_parameter("coast_z", float(gs["coast_z"]))
		_ground_mat.set_shader_parameter("land_ahead", float(gs["land_ahead"]))
		_ground_mat.set_shader_parameter("scroll", Vector2(0.0, fmod(flight_t * float(cfg.get("ground_speed", 9.0)) * speed_k, 40000.0)))
		_ground_mat.set_shader_parameter("center", cp)
		_ground_mat.set_shader_parameter("desert", _dawn)
		_ground_mat.set_shader_parameter("fires", _east)
	if not desert and GameState.has_flag(&"london_seen") and _london == null and _east < 1.0:
		_east = minf(1.0, _east + delta / 8.0)


func _tick_turbulence(delta: float) -> void:
	var banking: bool = _fc != null and bool(_fc.get("banking"))
	var side: float = float(_fc.get("bank_side")) if _fc != null else 1.0
	var sw: Dictionary = cfg.get("swing", {})
	var max_rad: float = deg_to_rad(float(sw.get("max_deg", 10.0)))
	var damping: float = float(sw.get("damping", 0.9))
	for id: int in _swing.keys():
		var e: Dictionary = _swing[id]
		var n: Node3D = e["node"] as Node3D
		if not is_instance_valid(n):
			_swing.erase(id)
			continue
		# the bank throws the hangings outboard of the turn; a slow sway the rest of the time (the wing breathes)
		var target: float = (-side * max_rad if banking else 0.0) + sin(flight_t * 0.7 + float(e["phase"])) * max_rad * 0.12
		var r: Vector2 = swing_step(float(e["angle"]), float(e["vel"]), target, float(e["omega"]), damping, delta)
		e["angle"] = r.x
		e["vel"] = r.y
		n.transform.basis = Basis(Vector3(0, 0, 1), r.x) * (e["base"] as Basis)
	for s: Node3D in _spin:
		if is_instance_valid(s):
			var ax: Vector3 = s.get_meta("spin_axis", Vector3(1, 0, 0))
			s.rotate_object_local(ax.normalized(), TAU * float(s.get_meta("spin_rps", 0.5)) * delta)
	for rd: Array in _rods:
		var rn: Node3D = rd[0] as Node3D
		if is_instance_valid(rn):
			rn.position = (rd[1] as Vector3) + rn.transform.basis.x.normalized() * sin(flight_t * float(rn.get_meta("rod_speed", 0.8))) * float(rn.get_meta("rod_amp", 0.06))
	# a small shake on the local camera through the whole bank (the FlightController gives the onset jolt)
	if banking:
		_shake_t -= delta
		if _shake_t <= 0.0:
			_shake_t = 0.35
			var map: Node = get_tree().current_scene
			var p: Node = map.get("player") if map != null else null
			if p != null and is_instance_valid(p):
				p.set("_shake", maxf(float(p.get("_shake")) if p.get("_shake") != null else 0.0, float((cfg.get("shake", {}) as Dictionary).get("bank", 0.06))))


func _tick_fighters(delta: float) -> void:
	if desert:
		return
	var strafes: int = int(_fc.get("strafes_done")) if _fc != null and _fc.get("strafes_done") != null else 0
	if strafes > _last_strafes:
		_last_strafes = strafes
		spawn_pass(true)
	while not passes_left.is_empty() and round_t >= passes_left[0]:
		passes_left.remove_at(0)
		spawn_pass(false)
	var fcfg: Dictionary = cfg.get("fighters", {})
	for f: Dictionary in _fighters.duplicate():
		f["t"] = float(f["t"]) + delta
		var k: float = float(f["t"]) / float(f["dur"])
		var node: Node3D = f["node"] as Node3D
		if k >= 1.0:
			node.queue_free()
			_fighters.erase(f)
			continue
		var pos: Vector3 = (f["from"] as Vector3).lerp(f["to"] as Vector3, k)
		node.global_position = pos
		var snd: Variant = f.get("snd")
		if snd != null and is_instance_valid(snd):
			(snd as AudioStreamPlayer3D).global_position = pos
		# the tracer burst in the first part of the pass: dashes racing ahead of the nose
		var tr: Array = f["tracers"]
		for i: int in tr.size():
			var tm: MeshInstance3D = tr[i] as MeshInstance3D
			var tk: float = fmod(float(f["t"]) * 3.0 + float(i) / float(tr.size()), 1.0)
			tm.visible = float(f["t"]) < float(fcfg.get("guns_s", 0.9))
			tm.position = Vector3(0, 0, -6.0 - tk * 90.0)


## One fighter streaks past outside: alongside from aft to fore, across the nose, or diving past the blisters.
func spawn_pass(with_strafe: bool) -> void:
	if _fighter_mesh == null:
		return
	var fcfg: Dictionary = cfg.get("fighters", {})
	var kind: int = _rng.randi_range(0, 2)
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var a: Vector3
	var b: Vector3
	match kind:
		0:
			var x: float = side * _rng.randf_range(95.0, 170.0)
			var y: float = _rng.randf_range(-30.0, 25.0)
			a = Vector3(x, y - 10.0, WING_Z - 330.0)
			b = Vector3(x * 0.8, y + 10.0, WING_Z + 330.0)
		1:
			var z: float = WING_Z + _rng.randf_range(110.0, 220.0)
			var y2: float = _rng.randf_range(-10.0, 35.0)
			a = Vector3(-side * 330.0, y2, z)
			b = Vector3(side * 330.0, y2 - 15.0, z - 40.0)
		_:
			var x3: float = _rng.randf_range(40.0, 110.0) * (1.0 if _rng.randf() < 0.7 else -1.0)
			a = Vector3(x3, 180.0, WING_Z - 90.0)
			b = Vector3(x3 + side * 30.0, -200.0, WING_Z - 160.0)
	var node: Node3D = Node3D.new()
	node.name = "Fighter%d" % passes_done
	add_child(node)
	node.global_position = a
	node.look_at_from_position(a, b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.FORWARD)
	node.rotate_object_local(Vector3(0, 0, 1), deg_to_rad(_rng.randf_range(-35.0, 35.0)))
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _fighter_mesh
	body.material_override = _fighter_mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	var glow: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	glow.mesh = q
	glow.material_override = _glow_mat
	glow.position = Vector3(0, 0, 4.8)
	node.add_child(glow)
	var tracers: Array = []
	for i: int in 6:
		var tm: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.12, 0.12, 5.0)
		tm.mesh = bm
		tm.material_override = _tracer_mat
		tm.position = Vector3((i % 2) * 2.0 - 1.0, 0, -6.0)
		node.add_child(tm)
		tracers.append(tm)
	var dur: float = float(fcfg.get("seconds", 2.6)) * (1.4 if kind == 2 else 1.0)
	var snd: AudioStreamPlayer3D = AudioDirector.play_3d(str(fcfg.get("sound", "war_fighter_pass")), a, float(fcfg.get("sound_db", 4.0)))
	if with_strafe or _rng.randf() < 0.5:
		AudioDirector.play_3d(str(fcfg.get("guns", "war_fighter_mg")), a.lerp(b, 0.2), float(fcfg.get("guns_db", -2.0)))
	_fighters.append({"node": node, "t": 0.0, "dur": dur, "from": a, "to": b, "snd": snd, "tracers": tracers})
	passes_done += 1


func _tick_london(_delta: float) -> void:
	if _london == null or not is_instance_valid(_london):
		return
	var lc: Dictionary = cfg.get("london", {})
	var speed: float = maxf(0.01, Campaign.cutscene_speed)
	var beat_t: float = float(_london.get("_t")) * speed
	var ph: Dictionary = london_phase(beat_t, lc)
	_set_beams(bool(ph["beams"]) or str(leg.get("lights", "")) == "london")
	if bool(ph["flak"]):
		_flak_t -= _delta * speed
		if _flak_t <= 0.0:
			_flak_t = float(lc.get("flak_every_s", 0.55)) * _rng.randf_range(0.6, 1.4)
			var cam: Camera3D = get_viewport().get_camera_3d()
			var origin: Vector3 = cam.global_position if cam != null else Vector3(74, 1.5, 25.4)
			var fwd: Vector3 = -cam.global_basis.z if cam != null else Vector3(0, -0.35, -1).normalized()
			var p: Vector3 = origin + fwd * _rng.randf_range(60.0, 170.0) + Vector3(_rng.randf_range(-60.0, 60.0), _rng.randf_range(-15.0, 30.0), _rng.randf_range(-30.0, 30.0))
			burst(p)
	if beat_t >= float(lc.get("violet_from_s", 24.0)):
		_east = minf(1.0, _east + _delta / 8.0)


func _tick_flak(delta: float) -> void:
	# the London leg keeps a little flak going after the window (far off, every few seconds)
	if _london == null and str(leg.get("lights", "")) == "london" and not desert:
		_flak_t -= delta
		if _flak_t <= 0.0:
			_flak_t = _rng.randf_range(2.5, 6.0)
			var base: Vector3 = Vector3(_rng.randf_range(-200.0, 200.0), _rng.randf_range(-20.0, 40.0), WING_Z + _rng.randf_range(-260.0, 260.0))
			burst(base, true)
	for f: Dictionary in _flak.duplicate():
		f["t"] = float(f["t"]) + delta
		var t: float = float(f["t"])
		var fl: MeshInstance3D = f["flash"] as MeshInstance3D
		var sm: MeshInstance3D = f["smoke"] as MeshInstance3D
		fl.scale = Vector3.ONE * (1.0 + t * 30.0) if t < 0.18 else Vector3.ZERO
		sm.scale = Vector3.ONE * (0.4 + t * 1.6)
		if t > 4.0:
			fl.queue_free()
			sm.queue_free()
			_flak.erase(f)


## One flak burst at p: a flash, a dark puff that lingers and grows, a thump, the clouds lit for a moment.
func burst(p: Vector3, far: bool = false) -> void:
	var fl: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	fl.mesh = q
	fl.material_override = _flak_mat
	add_child(fl)
	fl.global_position = p
	var sm: MeshInstance3D = MeshInstance3D.new()
	var q2: QuadMesh = QuadMesh.new()
	q2.size = Vector2(6.0, 6.0)
	sm.mesh = q2
	sm.material_override = _smoke_mat
	add_child(sm)
	sm.global_position = p
	_flak.append({"flash": fl, "smoke": sm, "t": 0.0})
	_flash = 1.0 if not far else 0.4
	_flash_pos = p
	var key: String = str((cfg.get("london", {}) as Dictionary).get("flak_sound", "kranich_flak"))
	if not AudioDirector.has_sound(key):
		key = "grenade_explode"
	AudioDirector.play_3d(key, p, -6.0 if not far else -14.0, 0.15)


func _go_desert() -> void:
	desert = true
	_ground_y_target = float(cfg.get("desert_y", -186.5))
	_set_beams(false)
	if _desert_set != null:
		_desert_set.visible = true
	var wd: Node3D = _scene_find("WingDiorama") as Node3D
	if wd != null:
		wd.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "_dawn", 1.0, float(cfg.get("dawn_s", 10.0)) / maxf(0.01, Campaign.cutscene_speed))
	print("[sky] the crash: the salt flat at dawn")
