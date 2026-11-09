class_name KranichSunset
extends Node3D
## Der Kranich's golden hour and the bomb run as a trailer moment (T-221; the owner: "make the sunset look great, the
## bombs dropping, and the lighting around it"; data/gravelight/map04b_plane.json "golden"). Presentation only, every
## peer its own; the run's gameplay (timers, jams, cities, flags) is the FlightController's and is never touched.
##   golden      0 .. 1 from the act's sunrise (FlightSky.sunrise, the act's own night -> dawn clock: it reads as a
##               sunset, the story stays dawn), held at 1 while the bomb run is on, or set by the `tod` console
##               command: the key light deep gold and low behind the wing, a strong sky gradient and sun glow, the
##               cloud sheets below lit orange / pink over deep blue, the far deck likewise, the key light's specular up
##               (the hull's sheet metal glints)
##   the bay     while golden and the run (or the bay doors) are on: a shaft of low sun through the aft ramp's seam
##               (one shadowed spot, so the racks cut god rays in the volumetric fog), dust motes in the light; every
##               rack that drops leaves its release hatch glowing with the sunlit cloud below (a warm spot up)
##   the drop    BombRack.drop() calls the group bomb_drop_fx: a casing falls away under the hull lit by the low sun,
##               tumbling, trailing vapour, drifting aft and shrinking into the cloud deck; a dropped (not dud) rack's
##               casing ends in a distant violet flash under the clouds (Nachtglas; no city is shown)
## Pure rules (golden_for, fall_at) are static for the tests.

const DATA: String = "res://data/gravelight/map04b_plane.json"

static var disabled: bool = false

var cfg: Dictionary = {}
var golden: float = 0.0
var golden_override: float = -1.0     # `tod` holds it (captures, the trailer)
var drops_seen: int = 0
var _sky: Node = null
var _fc: Node = null
var _moon: DirectionalLight3D = null
var _ramp: SpotLight3D = null
var _motes: GPUParticles3D = null
var _hatches: Array = []              # [SpotLight3D, glow mesh, age]
var _falls: Array = []                # {node, trail, t, from, flash}
var _flashes: Array = []              # {node, t}
var _casing_mesh: ArrayMesh = null
var _casing_mat: StandardMaterial3D = null
var _flash_mat: StandardMaterial3D = null
var _t: float = 0.0
var _run_k: float = 0.0
var _env: Environment = null
var _fog_g: float = 0.0
var _flash_k: float = 0.0
var _frame: Dictionary = {}


# ---------------------------------------------------------------- pure rules

## The golden-hour amount for the act's `sunrise` (0 .. dawn_max) with the run's hold `run_k` (0 .. 1).
static func golden_for(sunrise: float, run_k: float, g: Dictionary) -> float:
	var k: float = smoothstep(float(g.get("from_sunrise", 0.45)), float(g.get("to_sunrise", 0.7)), sunrise)
	return clampf(maxf(k, run_k), 0.0, 1.0)


## Where a released casing is `t` s after it left the rack at `from` (map frame): it falls under gravity and drifts aft
## in the slipstream (the plane flies on; the casing slows), tumbling nose-down. Vector4(x, y, z, pitch radians).
static func fall_at(from: Vector3, t: float, drift: float = 6.5) -> Vector4:
	var y: float = from.y - 0.5 * 9.81 * t * t
	var z: float = from.z - 0.5 * drift * t * t
	var pitch: float = clampf(t * 0.55, 0.0, 1.35)
	return Vector4(from.x + sin(t * 0.7) * 0.4, y, z, pitch)


# ---------------------------------------------------------------- setup

func _ready() -> void:
	add_to_group(&"bomb_drop_fx")
	add_to_group(&"kranich_sunset")
	if disabled:
		set_process(false)
		return
	process_priority = 60   # after KranichAir (50) and MapAmbience: the golden light is the last word on the key light
	cfg = (GLData.load_json(DATA) as Dictionary).get("golden", {})
	_build_bay()
	_build_drop_assets()


func _build_bay() -> void:
	var bay: Dictionary = cfg.get("bay", {})
	var gc: Color = Color(str(bay.get("color", "#ffb066")))
	_ramp = SpotLight3D.new()
	_ramp.name = "RampSunShaft"
	_ramp.light_color = gc
	_ramp.light_energy = 0.0
	_ramp.spot_range = float(bay.get("range", 30.0))
	_ramp.spot_angle = float(bay.get("angle", 32.0))
	_ramp.spot_attenuation = 0.6
	_ramp.light_volumetric_fog_energy = float(bay.get("fog", 6.0))
	_ramp.shadow_enabled = true
	_ramp.visible = false
	var at: Array = bay.get("ramp_at", [0.0, 2.6, 0.3])
	_ramp.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	# pointing forward (+Z) and a little down, as the low sun comes in over the ramp's lip
	_ramp.basis = Basis.looking_at(Vector3(0, -0.22, 1).normalized(), Vector3.UP)
	_ramp.set_meta("zone", &"A_BOMBENSCHACHT")
	add_child(_ramp)
	# the dust in the light (lit particles: they show only where the shafts are)
	_motes = GPUParticles3D.new()
	_motes.name = "BayMotes"
	_motes.amount = int(bay.get("motes", 260))
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.emitting = false
	_motes.visible = false
	_motes.local_coords = false
	_motes.position = Vector3(0, 2.2, 12)
	_motes.visibility_aabb = AABB(Vector3(-9, -2.5, -12), Vector3(18, 5, 24))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(7.5, 2.0, 11.0)
	pm.gravity = Vector3(0, -0.02, 0)
	pm.direction = Vector3(0, 0.2, 1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	_motes.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.018, 0.018)
	var mm: StandardMaterial3D = StandardMaterial3D.new()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(0.95, 0.88, 0.75, 0.7)
	mm.roughness = 1.0
	q.material = mm
	_motes.draw_pass_1 = q
	add_child(_motes)


func _build_drop_assets() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body: CylinderMesh = CylinderMesh.new()
	body.top_radius = 0.45
	body.bottom_radius = 0.45
	body.height = 1.7
	body.radial_segments = 14
	st.append_from(body, 0, Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(90.0)), Vector3.ZERO))
	var nose: CylinderMesh = CylinderMesh.new()
	nose.top_radius = 0.05
	nose.bottom_radius = 0.45
	nose.height = 0.7
	nose.radial_segments = 14
	st.append_from(nose, 0, Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(90.0)), Vector3(0, 0, 1.2)))
	for k: int in 4:
		var fin: BoxMesh = BoxMesh.new()
		fin.size = Vector3(0.04, 0.55, 0.5)
		st.append_from(fin, 0, Transform3D(Basis(Vector3(0, 0, 1), k * PI * 0.5), Vector3(0, 0, -1.0)).translated_local(Vector3(0, 0.3, 0)))
	st.generate_normals()
	_casing_mesh = st.commit()
	_casing_mat = StandardMaterial3D.new()
	_casing_mat.albedo_color = Color(0.46, 0.46, 0.43)
	_casing_mat.metallic = 0.85
	_casing_mat.roughness = 0.28
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_mat.disable_fog = true
	var g: Gradient = Gradient.new()
	var vc: Color = Color(str(cfg.get("flash_color", "#8a4dff")))
	g.set_color(0, Color(vc.r, vc.g, vc.b, 1.0))
	g.set_color(1, Color(0, 0, 0, 0))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_flash_mat.albedo_texture = gt


# ---------------------------------------------------------------- the console / captures

## `tod`: hold the Kranich's time of day at `k` (0 night .. 1 the golden bomb-run light); negative releases it to the
## act's own clock.
func hold_tod(k: float) -> void:
	var air: Node = get_tree().get_first_node_in_group(&"kranich_air")
	if k < 0.0:
		golden_override = -1.0
		if air != null:
			air.call("preview_dawn", -1.0)
			if _sky != null:
				_sky.set("sunrise_hold", -1.0)
		return
	var dmax: float = float(cfg.get("dawn_max", 0.85))
	if air != null:
		air.call("preview_dawn", clampf(k, 0.0, 1.0) * dmax)
	golden_override = clampf(inverse_lerp(0.55, 1.0, k), 0.0, 1.0) if k < 1.0 else 1.0


## Capture hook ("call:KranichSunset:golden_now"): the full golden hour, held.
func golden_now() -> void:
	hold_tod(1.0)


## Capture / trailer hook ("call:KranichSunset:frame_bomber_sun"): stands the local (noclip) camera so formation
## bomber `index` crosses the low sun: on the line from the sun through the bomber, `dist` m short of it.
func frame_bomber_sun(index: int = 3, dist: float = 55.0) -> void:
	if _moon == null:
		return
	var b: Node3D = null
	var root: Node = get_parent()
	while root != null and root.get_parent() != null and not (root is MapRoot):
		root = root.get_parent()
	if root != null:
		b = root.find_child("Formation%d" % index, true, false) as Node3D
	var p: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if n is Player and (n as Player).is_local:
			p = n as Player
	if b == null or p == null:
		return
	p.noclip = true
	p.collision_mask = 0
	_frame = {"bomber": b, "player": p, "dist": dist, "left": float(cfg.get("frame_hold_s", 1.15))}
	_apply_frame()
	var cam3: Camera3D = get_viewport().get_camera_3d()
	print("[sunset] bomber %d crosses the sun: to_sun %s, bomber %s, camera fov %s keep %s" % [index, str(_moon.global_basis.z), str(b.global_position), str(cam3.fov if cam3 != null else -1.0), str(cam3.keep_aspect if cam3 != null else -1)])


## Holds the framing a moment (the capture tool places its camera after the hook runs; this wins for hold seconds).
func _apply_frame() -> void:
	var b: Node3D = _frame.get("bomber") as Node3D
	var p: Player = _frame.get("player") as Player
	if b == null or p == null or not is_instance_valid(b) or not is_instance_valid(p) or _moon == null:
		_frame = {}
		return
	var to_sun: Vector3 = _moon.global_basis.z.normalized()
	# a little under the line: the sun glares over the wing's upper edge
	var eye: Vector3 = b.global_position - to_sun * float(_frame.get("dist", 55.0)) + Vector3(0, -1.2, 0)
	p.global_position = eye - Vector3(0, 1.62, 0)
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(-to_sun.x, -to_sun.z)
	p.set("_pitch", asin(clampf(to_sun.y, -1.0, 1.0)))


## A purely visual drop (no gameplay): rack `index` (1..6) lets a casing go through the hull (captures, `bombrun fx`).
func drop_fx(index: int = 1, hit: bool = true) -> void:
	for r: Node in get_tree().get_nodes_in_group(&"bomb_racks"):
		if int(r.get("rack_index")) == index:
			_spawn_drop((r as Node3D).global_position, hit)
			return


## BombRack.drop() (group bomb_drop_fx): the real run released a rack.
func on_rack_dropped(rack: Node) -> void:
	if disabled or rack == null:
		return
	_spawn_drop((rack as Node3D).global_position, int(rack.get("state")) == 1)


func _spawn_drop(at: Vector3, hit: bool) -> void:
	drops_seen += 1
	var dc: Dictionary = cfg.get("drop", {})
	var gc: Color = Color(str((cfg.get("bay", {}) as Dictionary).get("color", "#ffb066")))
	# the release hatch under the rack glows with the sunlit cloud below
	var sp: SpotLight3D = SpotLight3D.new()
	sp.light_color = gc
	sp.light_energy = float(dc.get("hatch_energy", 5.0))
	sp.spot_range = 5.5
	sp.spot_angle = 28.0
	sp.light_volumetric_fog_energy = float(dc.get("hatch_fog", 5.0))
	sp.shadow_enabled = false
	sp.position = Vector3(at.x, 0.62, at.z)
	sp.basis = Basis.looking_at(Vector3.UP, Vector3.FORWARD)
	sp.set_meta("zone", &"A_BOMBENSCHACHT")
	add_child(sp)
	var gm: MeshInstance3D = MeshInstance3D.new()
	var pl: PlaneMesh = PlaneMesh.new()
	pl.size = Vector2(1.0, 1.9)
	gm.mesh = pl
	var gmat: StandardMaterial3D = StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = gc * 1.6
	gm.material_override = gmat
	gm.position = Vector3(at.x, 0.615, at.z)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gm)
	_hatches.append([sp, gm, 0.0, gmat])
	# the casing under the hull, falling away into the light
	var n: Node3D = Node3D.new()
	n.name = "FallingCasing"
	add_child(n)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _casing_mesh
	mi.material_override = _casing_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	# the low sun catching the casing's skin: a warm glint that reads against the cloud from the catwalk
	var gl: MeshInstance3D = MeshInstance3D.new()
	var gq: QuadMesh = QuadMesh.new()
	gq.size = Vector2.ONE * float((cfg.get("drop", {}) as Dictionary).get("glint_m", 2.6))
	gl.mesh = gq
	var glm: StandardMaterial3D = _flash_mat.duplicate() as StandardMaterial3D
	var gg: Gradient = Gradient.new()
	gg.set_color(0, Color(1.0, 0.78, 0.45, 1.0))
	gg.set_color(1, Color(0, 0, 0, 0))
	var ggt: GradientTexture2D = GradientTexture2D.new()
	ggt.gradient = gg
	ggt.fill = GradientTexture2D.FILL_RADIAL
	ggt.fill_from = Vector2(0.5, 0.5)
	ggt.fill_to = Vector2(1.0, 0.5)
	glm.albedo_texture = ggt
	glm.albedo_color = Color(1, 1, 1, 0.0)
	gl.material_override = glm
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(gl)
	var trail: GPUParticles3D = GPUParticles3D.new()
	trail.amount = int(dc.get("trail_amount", 240))
	trail.lifetime = float(dc.get("trail_life_s", 4.0))
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-400, -400, -400), Vector3(800, 800, 800))
	var tp: ParticleProcessMaterial = ParticleProcessMaterial.new()
	tp.gravity = Vector3.ZERO
	tp.initial_velocity_min = 0.0
	tp.initial_velocity_max = 0.4
	tp.scale_min = 0.6
	tp.scale_max = 1.0
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0, 0.35))
	sc.add_point(Vector2(1, 1.0))
	var sct: CurveTexture = CurveTexture.new()
	sct.curve = sc
	tp.scale_curve = sct
	var ag: Gradient = Gradient.new()
	ag.set_color(0, Color(1, 0.95, 0.88, 0.55))
	ag.set_color(1, Color(1, 0.95, 0.9, 0.0))
	var agt: GradientTexture1D = GradientTexture1D.new()
	agt.gradient = ag
	tp.color_ramp = agt
	trail.process_material = tp
	var pq: QuadMesh = QuadMesh.new()
	pq.size = Vector2.ONE * float(dc.get("trail_m", 2.4))
	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.vertex_color_use_as_albedo = true
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dot: GradientTexture2D = GradientTexture2D.new()
	var dg: Gradient = Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	pmat.albedo_texture = dot
	pq.material = pmat
	trail.draw_pass_1 = pq
	add_child(trail)
	var from: Vector3 = Vector3(at.x, float(dc.get("from_y", -1.4)), at.z)
	n.global_position = from
	trail.global_position = from
	_falls.append({"node": n, "trail": trail, "t": 0.0, "from": from, "hit": hit, "flashed": false, "glint": glm})


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	_t += delta
	if _sky == null or not is_instance_valid(_sky):
		_sky = get_tree().get_first_node_in_group(&"flight_sky")
	if _fc == null or not is_instance_valid(_fc):
		_fc = get_tree().get_first_node_in_group(&"flight_controller")
	if _moon == null or not is_instance_valid(_moon):
		var root: Node = get_parent()
		while root != null and root.get_node_or_null("Moon") == null:
			root = root.get_parent()
		if root != null:
			_moon = root.get_node_or_null("Moon") as DirectionalLight3D
			if _moon != null and not _moon.has_meta("golden_spec"):
				_moon.set_meta("golden_spec", _moon.light_specular)
				_moon.set_meta("golden_fog", _moon.light_volumetric_fog_energy)
	var run_on: bool = _fc != null and bool(_fc.get("run_on"))
	_run_k = move_toward(_run_k, 1.0 if run_on else 0.0, delta / maxf(0.1, float(cfg.get("run_ease_s", 6.0))))
	var sunrise: float = float(_sky.get("sunrise")) if _sky != null else 0.0
	golden = golden_override if golden_override >= 0.0 else golden_for(sunrise, _run_k * float(cfg.get("run_hold", 1.0)), cfg)
	_apply_light()
	_apply_sky()
	_tick_bay(delta, run_on)
	_tick_drops(delta)
	if not _frame.is_empty():
		_frame["left"] = float(_frame["left"]) - delta
		if float(_frame["left"]) <= 0.0:
			_frame = {}
		else:
			_apply_frame()


func _apply_light() -> void:
	if _moon == null:
		return
	var g: float = golden
	if g <= 0.001:
		_moon.light_specular = float(_moon.get_meta("golden_spec", 1.0))
		_moon.light_volumetric_fog_energy = float(_moon.get_meta("golden_fog", 1.0))
		_set_fog(0.0)
		return
	# after MapAmbience's dawn warming and KranichAir's sun swing: deepen to gold, brighten, glint
	var key: Color = Color(str(cfg.get("key_color", "#ffa250")))
	_moon.light_color = _moon.light_color.lerp(key, g)
	_moon.light_energy = lerpf(_moon.light_energy, float(cfg.get("key_energy", 2.4)), g)
	_moon.light_specular = lerpf(float(_moon.get_meta("golden_spec", 1.0)), float(cfg.get("key_specular", 2.2)), g)
	# the low sun scattering in the volumetric fog toward the camera: a haze, not a milk-white wash
	_moon.light_volumetric_fog_energy = lerpf(float(_moon.get_meta("golden_fog", 1.0)), float(cfg.get("key_fog", 0.1)), g)
	_set_fog(g)
	# the sun sits low: tip the key light toward the horizon behind the wing
	var low: Vector3 = Vector3(float((cfg.get("sun_dir", [0.24, 0.05, -1.0]) as Array)[0]), float((cfg.get("sun_dir", [0.24, 0.05, -1.0]) as Array)[1]), float((cfg.get("sun_dir", [0.24, 0.05, -1.0]) as Array)[2])).normalized()
	var bank: float = deg_to_rad(float(get_tree().get_first_node_in_group(&"kranich_air").get("bank_deg"))) if get_tree().get_first_node_in_group(&"kranich_air") != null else 0.0
	var target: Basis = Basis(Vector3(0, 0, 1), bank) * KranichAir.light_basis(low)
	_moon.basis = Basis(_moon.basis.get_rotation_quaternion().slerp(target.get_rotation_quaternion(), g))


## The air at the golden hour: the depth fog thinner and warm-grey (the far deck and the sky carry the distance), the
## volumetric fog a little thinner, so the low light reads crisp.
func _set_fog(g: float) -> void:
	if _env == null:
		var root: Node = get_parent()
		while root != null and root.get_node_or_null("WorldEnvironment") == null:
			root = root.get_parent()
		if root != null:
			_env = (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	var env: Environment = _env
	if env == null or absf(g - _fog_g) < 0.002:
		return   # only while it changes: the map's other fog users (decompression, the horror layer) keep theirs
	_fog_g = g
	if not env.has_meta("golden_base"):
		env.set_meta("golden_base", [env.fog_density, env.volumetric_fog_density, env.fog_light_color])
	var b: Array = env.get_meta("golden_base")
	var fc: Dictionary = cfg.get("fog", {})
	env.fog_density = lerpf(float(b[0]), float(b[0]) * float(fc.get("density_mult", 0.45)), g)
	env.volumetric_fog_density = lerpf(float(b[1]), float(b[1]) * float(fc.get("volumetric_mult", 0.6)), g)
	env.fog_light_color = (b[2] as Color).lerp(Color(str(fc.get("color", "#3a2f33"))), g)


func _apply_sky() -> void:
	if _sky == null:
		return
	var g: float = golden
	var sm: Variant = _sky.get("_sky_mat")
	if sm is ShaderMaterial:
		(sm as ShaderMaterial).set_shader_parameter("golden", g)
	var mats: Variant = _sky.get("_cloud_mats")
	if mats is Array:
		var c: Dictionary = cfg.get("clouds", {})
		if not has_meta("cloud_base") and not (mats as Array).is_empty():
			var base: Array = []
			for m: Variant in mats:
				base.append([(m as ShaderMaterial).get_shader_parameter("lit_color"), (m as ShaderMaterial).get_shader_parameter("dark_color")])
			set_meta("cloud_base", base)
		var bl: Array = get_meta("cloud_base", [])
		for i: int in (mats as Array).size():
			var m2: ShaderMaterial = (mats as Array)[i] as ShaderMaterial
			if m2 == null or i >= bl.size():
				continue
			var lit0: Variant = bl[i][0]
			var dark0: Variant = bl[i][1]
			if lit0 is Color:
				m2.set_shader_parameter("lit_color", (lit0 as Color).lerp(Color(str(c.get("lit", "#ffb27e"))), g))
			if dark0 is Color:
				m2.set_shader_parameter("dark_color", (dark0 as Color).lerp(Color(str(c.get("dark", "#1b2546"))), g * 0.9))
			# T-221 b: crisp cloud shapes (sharper edges, a little less cover) instead of a uniform haze
			if not m2.has_meta("gold_base"):
				m2.set_meta("gold_base", [m2.get_shader_parameter("softness"), m2.get_shader_parameter("coverage"), m2.get_shader_parameter("opacity")])
			var gb: Array = m2.get_meta("gold_base")
			if gb[0] != null:
				m2.set_shader_parameter("softness", lerpf(float(gb[0]), float(c.get("softness", 0.1)), g))
			if gb[1] != null and g > 0.0:
				m2.set_shader_parameter("coverage", float(gb[1]) * lerpf(1.0, float(c.get("coverage_mult", 0.82)), g))
			if gb[2] != null and g > 0.0:
				m2.set_shader_parameter("opacity", clampf(float(gb[2]) * lerpf(1.0, float(c.get("opacity_mult", 1.15)), g), 0.0, 0.97))
			# a violet flash under the deck lights the cloud violet; FlightSky's flak keeps its orange otherwise
			m2.set_shader_parameter("flash_color", Color(str(cfg.get("flash_color", "#8a4dff"))) * 1.6 if _flash_k > 0.0 else Color(1.0, 0.75, 0.45))


func _tick_bay(delta: float, run_on: bool) -> void:
	var bay: Dictionary = cfg.get("bay", {})
	var doors_open: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"bay_doors"):
		if bool(n.get("active")):
			doors_open = true
	var want: float = golden * (1.0 if (run_on or doors_open or golden_override >= 0.0) else float(bay.get("idle", 0.35)))
	var e: float = float(bay.get("energy", 9.0)) * want * (0.92 + 0.08 * sin(_t * 1.7))
	_ramp.light_energy = e
	_ramp.visible = e > 0.05
	var motes_on: bool = want > 0.25
	if _motes.emitting != motes_on:
		_motes.emitting = motes_on
	_motes.visible = motes_on or _motes.emitting
	for h: Array in _hatches.duplicate():
		h[2] = float(h[2]) + delta
		var k: float = 1.0 - smoothstep(float(bay.get("hatch_hold_s", 14.0)), float(bay.get("hatch_hold_s", 14.0)) + 4.0, float(h[2]))
		var sp: SpotLight3D = h[0] as SpotLight3D
		sp.light_energy = float((cfg.get("drop", {}) as Dictionary).get("hatch_energy", 5.0)) * k * maxf(0.35, golden)
		(h[3] as StandardMaterial3D).albedo_color = Color(str(bay.get("color", "#ffb066"))) * (1.6 * k)
		if k <= 0.0:
			sp.queue_free()
			(h[1] as Node).queue_free()
			_hatches.erase(h)


func _tick_drops(delta: float) -> void:
	var dc: Dictionary = cfg.get("drop", {})
	for f: Dictionary in _falls.duplicate():
		f["t"] = float(f["t"]) + delta
		var t: float = float(f["t"])
		var p: Vector4 = fall_at(f["from"] as Vector3, t, float(dc.get("drift", 6.5)))
		var n: Node3D = f["node"] as Node3D
		var tr: GPUParticles3D = f["trail"] as GPUParticles3D
		n.position = Vector3(p.x, p.y, p.z)
		n.rotation = Vector3(-p.w, sin(t * 0.9) * 0.15, sin(t * 1.3) * 0.25)
		tr.position = n.position
		tr.emitting = t > 0.25 and p.y > float(dc.get("cloud_y", -95.0))
		(f["glint"] as StandardMaterial3D).albedo_color = Color(1.6, 1.4, 1.1, clampf(maxf(golden, 0.4) * (0.7 + 0.3 * absf(sin(t * 7.0))) * (1.0 - smoothstep(4.5, 6.8, t)), 0.0, 1.0))
		if bool(f["hit"]) and not bool(f["flashed"]) and t > float(dc.get("flash_after_s", 8.5)):
			f["flashed"] = true
			_flash_under(n.position)
		if t > float(dc.get("life_s", 7.0)):
			n.visible = false
		if t > float(dc.get("life_s", 7.0)) + 3.0:
			n.queue_free()
			tr.queue_free()
			_falls.erase(f)
	_flash_k = 0.0
	for fl: Dictionary in _flashes.duplicate():
		fl["t"] = float(fl["t"]) + delta
		var ft: float = float(fl["t"])
		var q: MeshInstance3D = fl["node"] as MeshInstance3D
		var k: float = smoothstep(0.0, 0.25, ft) * (1.0 - smoothstep(0.6, 3.5, ft))
		_flash_k = maxf(_flash_k, k)
		if _sky != null:
			_sky.set("_flash", maxf(float(_sky.get("_flash")), k * 1.6))
			_sky.set("_flash_pos", q.global_position)
		q.scale = Vector3.ONE * (1.0 + ft * 0.8)
		(q.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, k)
		if ft > 3.6:
			q.queue_free()
			_flashes.erase(fl)


## A violet flash far below the cloud deck where a live casing came down (no city, no fire: a glow through cloud).
func _flash_under(last: Vector3) -> void:
	var dc: Dictionary = cfg.get("drop", {})
	var q: MeshInstance3D = MeshInstance3D.new()
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2.ONE * float(dc.get("flash_m", 140.0))
	q.mesh = qm
	var m: StandardMaterial3D = _flash_mat.duplicate() as StandardMaterial3D
	m.albedo_color = Color(1, 1, 1, 0)
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)
	q.global_position = Vector3(last.x, float(dc.get("flash_y", -240.0)), clampf(last.z - float(dc.get("flash_back", 160.0)), -230.0, 100.0))   # inside the camera's far plane (400 m)
	_flashes.append({"node": q, "t": 0.0})
	if _sky != null:
		_sky.set("_flash", 0.6)
		_sky.set("_flash_pos", q.global_position)
