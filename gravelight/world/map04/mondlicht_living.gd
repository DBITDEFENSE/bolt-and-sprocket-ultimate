class_name MondlichtLiving
extends Node3D
## Mondlicht's living world (UPDATE 10 §3 Act IV, contract C1, T-158; data data/gravelight/map04d_ambience.json),
## made by MapAmbience's `# ---- U10 Act IV ----` block (its `_ev_<kind>` functions hand each section here).
## Presentation only: nothing here touches gameplay, so each peer runs its own. Kinds:
##   dust_settle     every shot that hits the regolith or the rim in the open lifts a slow puff that hangs and settles
##                   in the low gravity (a pool of CPU particle emitters; at most max_per_s a second)
##   crater_shadows  the long shadows move with the terminator (the Sun swings); the yard's earthshine fill rises as
##                   the night side grows so the shadowed regolith reads blue, not black
##   relay_mast      the mast's beacon (RelayMast) pulses at `period`; the dish's red warning lamp blinks in time
##   vacuum_muffle   tunes AudioDirector's suit muffle (cutoff_hz, db) used while in a vacuum zone
##   earth_violet    the Earth's violet points breathe slowly (a twinkle across the black)
##   field_units     Darkmatter's field units: `count` constructs with lamps walking the far rim slowly along
##                   `path`, never coming in (the Bar's row 19 on the Moon: the living war's equivalent)
##   meteors         now and then a distant meteor streaks across the black (not the shower: far, silent)
## Pure rules static for the tests.

var cfg: Dictionary = {}
var counts: Dictionary = {}
var units: Array[Node3D] = []
var _dust: Array[CPUParticles3D] = []
var _dust_i: int = 0
var _dust_budget: float = 0.0
var _mast_t: float = 0.0
var _warn_lamp: OmniLight3D = null
var _earthshine: OmniLight3D = null
var _earthshine_base: float = 0.0
var _meteor_t: float = 20.0
var _unit_t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The point at distance `d` along a polyline (and its heading), looping back and forth (ping-pong).
static func patrol_point(path: Array, d: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	var lens: Array[float] = []
	var total: float = 0.0
	for i: int in path.size() - 1:
		var l: float = (path[i] as Vector3).distance_to(path[i + 1] as Vector3)
		lens.append(l)
		total += l
	if total <= 0.0:
		return path[0]
	var t: float = fposmod(d, total * 2.0)
	if t > total:
		t = total * 2.0 - t
	for i2: int in lens.size():
		if t <= lens[i2]:
			return (path[i2] as Vector3).lerp(path[i2 + 1] as Vector3, t / maxf(0.001, lens[i2]))
		t -= lens[i2]
	return path.back()


## True when a shot's hit lands on open ground the dust can rise from (low enough, in a vacuum zone).
static func dusty_hit(hit_y: float, in_vacuum: bool, max_y: float) -> bool:
	return in_vacuum and hit_y <= max_y


func _ready() -> void:
	name = "MondlichtLiving"
	add_to_group(&"mondlicht_living")
	_rng.seed = 4045


func setup(c: Dictionary) -> void:
	cfg = c
	var map: Node = get_tree().current_scene
	if cfg.has("dust_settle"):
		_build_dust()
		GLBus.weapon_fired.connect(_on_shot)
	if cfg.has("vacuum_muffle"):
		var vm: Dictionary = cfg["vacuum_muffle"]
		AudioDirector.vacuum_muffle = {"cutoff_hz": float(vm.get("cutoff_hz", 420.0)), "db": float(vm.get("db", -12.0))}
	if map != null:
		_warn_lamp = map.find_child("Lamp_C_DishWarning", true, false) as OmniLight3D
		_earthshine = map.find_child("Lamp_C_Earthshine", true, false) as OmniLight3D
		if _earthshine != null:
			_earthshine_base = _earthshine.light_energy
	if cfg.has("relay_mast"):
		for m: Node in get_tree().get_nodes_in_group(&"relay_mast"):
			m.set("period", float((cfg["relay_mast"] as Dictionary).get("period", 3.2)))
	if cfg.has("field_units"):
		_build_units()
	var mt: Dictionary = cfg.get("meteors", {})
	_meteor_t = _rng.randf_range(float((mt.get("first_after", [15, 40]) as Array)[0]), float((mt.get("first_after", [15, 40]) as Array)[1]))


func _count(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


# ---------------------------------------------------------------- dust after every shot

func _build_dust() -> void:
	var dc: Dictionary = cfg["dust_settle"]
	var pm: StandardMaterial3D = StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var qm: QuadMesh = QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	qm.material = pm
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(0.62, 0.6, 0.62, 0.0))
	grad.add_point(0.12, Color(0.62, 0.6, 0.62, 0.55))
	grad.set_color(grad.get_point_count() - 1, Color(0.55, 0.54, 0.56, 0.0))
	for i: int in int(dc.get("pool", 10)):
		var p: CPUParticles3D = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = int(dc.get("amount", 14))
		p.lifetime = float(dc.get("lifetime", 6.0))
		p.explosiveness = 0.9
		p.mesh = qm
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = float(dc.get("speed_min", 0.4))
		p.initial_velocity_max = float(dc.get("speed_max", 1.4))
		p.gravity = Vector3(0, -float(dc.get("gravity", 0.35)), 0)
		p.damping_min = 0.1
		p.damping_max = 0.3
		p.scale_amount_min = 0.8
		p.scale_amount_max = 2.2
		p.color_ramp = grad
		p.local_coords = false
		add_child(p)
		_dust.append(p)


func _on_shot(_pid: int, _w: StringName, _u: bool, origin: Vector3, dir: Vector3) -> void:
	var dc: Dictionary = cfg.get("dust_settle", {})
	if _dust.is_empty() or _dust_budget >= float(dc.get("max_per_s", 6.0)):
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir.normalized() * float(dc.get("range_m", 70.0)), 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return
	var at: Vector3 = hit["position"]
	if not dusty_hit(at.y, ZoneVolume.vacuum_at(get_tree(), at + Vector3.UP * 0.2), float(dc.get("max_y", 3.5))):
		return
	puff(at)


## One slow puff at `at` (also the smoke).
func puff(at: Vector3) -> void:
	if _dust.is_empty():
		return
	_dust_budget += 1.0
	var p: CPUParticles3D = _dust[_dust_i % _dust.size()]
	_dust_i += 1
	p.global_position = at + Vector3.UP * 0.05
	p.restart()
	p.emitting = true
	_count("dust")


# ---------------------------------------------------------------- the field units on the far rim

func _unit_path() -> Array:
	var out: Array = []
	for a: Variant in (cfg.get("field_units", {}) as Dictionary).get("path", []):
		var v: Array = a
		out.append(Vector3(float(v[0]), float(v[1]), float(v[2])))
	return out


func _build_units() -> void:
	var fc: Dictionary = cfg["field_units"]
	var lamp_c: Array = fc.get("lamp_color", [1.0, 0.82, 0.55])
	var body_m: StandardMaterial3D = StandardMaterial3D.new()
	body_m.albedo_color = Color(0.13, 0.12, 0.15)
	body_m.metallic = 0.5
	body_m.roughness = 0.5
	var glow_m: StandardMaterial3D = StandardMaterial3D.new()
	glow_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_m.albedo_color = Color(float(lamp_c[0]), float(lamp_c[1]), float(lamp_c[2]))
	glow_m.disable_fog = true
	var violet_m: StandardMaterial3D = StandardMaterial3D.new()
	violet_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	violet_m.albedo_color = Color(0.72, 0.42, 1.0)
	for i: int in int(fc.get("count", 3)):
		var u: Node3D = Node3D.new()
		u.name = "FieldUnit_%d" % (i + 1)
		add_child(u)
		# a construct, not a person: a squat graphite carriage on four jointed legs, a sensor dome, a lamp on a boom
		_box(u, Vector3(1.6, 0.9, 1.1), Vector3(0, 1.9, 0), body_m)
		_box(u, Vector3(1.2, 0.08, 0.8), Vector3(0, 2.38, 0), violet_m)
		var dome: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.38
		sm.height = 0.5
		sm.is_hemisphere = true
		dome.mesh = sm
		dome.material_override = body_m
		dome.position = Vector3(0, 2.4, 0.2)
		u.add_child(dome)
		for lx: float in [-0.65, 0.65]:
			for lz: float in [-0.4, 0.4]:
				var leg: Node3D = Node3D.new()
				leg.name = "Leg"
				leg.position = Vector3(lx, 1.6, lz)
				u.add_child(leg)
				_box(leg, Vector3(0.12, 0.9, 0.12), Vector3(lx * 0.4, -0.35, 0), body_m)
				_box(leg, Vector3(0.1, 0.9, 0.1), Vector3(lx * 0.55, -1.15, 0), body_m)
		_box(u, Vector3(0.08, 0.08, 1.0), Vector3(0, 2.2, 0.9), body_m)
		_box(u, Vector3(0.3, 0.2, 0.18), Vector3(0, 2.2, 1.45), glow_m)
		var lamp: SpotLight3D = SpotLight3D.new()
		lamp.light_color = Color(float(lamp_c[0]), float(lamp_c[1]), float(lamp_c[2]))
		lamp.light_energy = float(fc.get("lamp_energy", 3.0))
		lamp.spot_range = 26.0
		lamp.spot_angle = 22.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, 2.2, 1.55)
		lamp.rotation_degrees = Vector3(-28, 0, 0)
		lamp.set_meta("zone", &"C_YARD")
		u.add_child(lamp)
		units.append(u)
	_place_units(0.0)


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	u_noshadow(mi)
	parent.add_child(mi)


func u_noshadow(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _place_units(dt: float) -> void:
	var fc: Dictionary = cfg.get("field_units", {})
	var path: Array = _unit_path()
	if path.size() < 2:
		return
	_unit_t += dt
	var speed: float = float(fc.get("speed", 1.1))
	var gap: float = float(fc.get("spacing_m", 9.0))
	for i: int in units.size():
		var d: float = _unit_t * speed + float(i) * gap
		var p: Vector3 = patrol_point(path, d)
		var ahead: Vector3 = patrol_point(path, d + 0.5)
		var u: Node3D = units[i]
		u.global_position = p
		var fl: Vector3 = Vector3(ahead.x - p.x, 0, ahead.z - p.z)
		if fl.length_squared() > 0.0001:
			u.rotation.y = atan2(fl.x, fl.z)
		var k: int = 0
		for leg: Node in u.get_children():
			if leg.name.begins_with("Leg"):
				(leg as Node3D).rotation.x = sin(_unit_t * 2.2 + float(k) * PI * 0.5 + float(i)) * 0.35
				k += 1


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_dust_budget = maxf(0.0, _dust_budget - delta * float((cfg.get("dust_settle", {}) as Dictionary).get("max_per_s", 6.0)))
	if not units.is_empty():
		_place_units(delta)
	_mast_t += delta
	if _warn_lamp != null and cfg.has("relay_mast"):
		var per: float = float((cfg["relay_mast"] as Dictionary).get("period", 3.2))
		_warn_lamp.light_energy = 1.2 * (0.2 + 0.8 * RelayMast.pulse_at(_mast_t + per * 0.5, per))
	var term: Terminator = get_tree().get_first_node_in_group(&"terminator") as Terminator
	if _earthshine != null and term != null and cfg.has("crater_shadows"):
		var cs: Dictionary = cfg["crater_shadows"]
		_earthshine.light_energy = _earthshine_base * (1.0 + float(cs.get("earthshine_gain", 1.4)) * term.progress())
	if cfg.has("earth_violet"):
		var sky: Node = get_tree().get_first_node_in_group(&"earth_sky")
		var pm: StandardMaterial3D = sky.get("_point_mat") as StandardMaterial3D if sky != null else null
		if pm != null and not bool(sky.get("dark_blue")):
			var a: float = float((cfg["earth_violet"] as Dictionary).get("breath", 0.18))
			pm.albedo_color = Color(0.85, 0.55, 1.0) * (1.0 - a + a * (0.5 + 0.5 * sin(_mast_t * 0.7)))
	if cfg.has("meteors"):
		_meteor_t -= delta
		if _meteor_t <= 0.0:
			var iv: Array = (cfg["meteors"] as Dictionary).get("interval", [20, 60])
			_meteor_t = _rng.randf_range(float(iv[0]), float(iv[1]))
			far_meteor()


## A distant meteor: a thin bright line across the black, far beyond the rim (presentation, silent).
func far_meteor() -> void:
	_count("meteor")
	var a: float = _rng.randf_range(-1.2, 1.2)
	var from: Vector3 = Vector3(sin(a) * 300.0, _rng.randf_range(120.0, 220.0), 150.0 + cos(a) * 300.0)
	var dir: Vector3 = Vector3(_rng.randf_range(-1, 1), -_rng.randf_range(0.3, 0.7), _rng.randf_range(-1, 1)).normalized()
	var s: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.6
	cm.height = 1.0
	s.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.95, 0.85, 0.9)
	m.disable_fog = true
	s.material_override = m
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	var length: float = 40.0
	var step: Callable = func(t: float) -> void:
		if not is_instance_valid(s):
			return
		var head: Vector3 = from + dir * 160.0 * t
		s.global_transform = Transform3D(Basis(side, -dir, side.cross(-dir)).scaled(Vector3(1, length, 1)), head - dir * length * 0.5)
		m.albedo_color.a = 0.9 * sin(PI * t)
	step.call(0.0)
	var tw: Tween = s.create_tween()
	tw.tween_method(step, 0.0, 1.0, 1.3)
	tw.tween_callback(s.queue_free)
