class_name SkyFlight
extends Node3D
## One flight crossing Map 0's sky (Update 02 section 7, T-052), made by MapAmbience: a bomber stream droning
## high over in loose vics, or a low pair of fighters, the second chasing the first with tracer. Either can lose a
## plane: it catches fire, peels away trailing smoke and goes down behind the hills; `crashed` fires where it hit
## (MapAmbience then flashes the horizon, plays the delayed boom and has the squad react). Frees itself at the end.

signal crashed(position: Vector3)
signal hit(plane: Node3D)

enum Kind { BOMBERS, FIGHTERS }

var kind: Kind = Kind.BOMBERS
var cfg: Dictionary = {}
var speed: float = 9.0
var heading: Vector3 = Vector3.RIGHT
var start: Vector3 = Vector3.ZERO
var length: float = 700.0
var planes: Array[Node3D] = []
var engine: AudioStreamPlayer3D
## Fighters: the curve the pair flies.
var curve: Array[Vector3] = []
var duration: float = 15.0
## Called as sound(key, position, volume_db) for sounds out past the pool's audible range (MapAmbience.far_sound).
var sound: Callable
var t: float = 0.0
var _faller: Node3D = null
var _fall_t: float = -1.0
var _fall_path: Array[Vector3] = []
var _fall_secs: float = 11.0
var _burst_t: float = 0.0
var _bursts_left: int = 0
var _tracers: Array = []          # [MeshInstance3D, velocity, life]
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## A bomber stream: `count` aircraft in vics of three, spacing apart, flying `heading` from `from` for `dist`
## metres. Call after the flight is in the tree.
func setup_bombers(c: Dictionary, from: Vector3, dir: Vector3, dist: float, count: int, seed_v: int) -> void:
	cfg = c
	kind = Kind.BOMBERS
	_rng.seed = seed_v
	start = from
	heading = dir.normalized()
	speed = float(c.get("speed", 9.0))
	length = dist
	transform = Transform3D(Basis.looking_at(heading, Vector3.UP), from)
	var span: float = float(c.get("wingspan", 3.6))
	var sp: float = float(c.get("spacing", 11.0))
	var mesh: ArrayMesh = PlaneModels.bomber()
	for i: int in count:
		var vic: int = i / 3
		var slot: int = i % 3
		var off: Vector3 = Vector3((slot - 1) * sp * 0.9 + _rng.randf_range(-2, 2), _rng.randf_range(-3, 3) + (vic % 2) * 4.0,
			vic * sp * 1.6 + absf(slot - 1) * sp * 0.6 + _rng.randf_range(-2, 2))
		var p: MeshInstance3D = MeshInstance3D.new()
		p.mesh = mesh
		p.scale = Vector3.ONE * span
		p.position = off
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		planes.append(p)
	_engine(str(c.get("sound", "")), float(c.get("volume_db", 0.0)), float(c.get("unit_size", 70.0)), float(c.get("max_distance", 900.0)), self)


## A fighter pair on a curve of four control points (a cubic Bezier) over `secs` seconds.
func setup_fighters(c: Dictionary, ctrl: Array[Vector3], secs: float, seed_v: int) -> void:
	cfg = c
	kind = Kind.FIGHTERS
	_rng.seed = seed_v
	curve = ctrl
	duration = secs
	var span: float = float(c.get("wingspan", 1.9))
	for i: int in 2:
		var p: MeshInstance3D = MeshInstance3D.new()
		p.mesh = PlaneModels.mosquito() if str(c.get("model", "")) == "mosquito" else PlaneModels.fighter()   # T-154
		p.scale = Vector3.ONE * span
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.set_meta("lag", float(i))
		add_child(p)
		planes.append(p)
	var b: Array = c.get("bursts", [2, 5])
	if planes.size() > int(c.get("count", 2)):   # T-154: the json may ask for one plane
		for k: int in range(planes.size() - 1, int(c.get("count", 2)) - 1, -1):
			planes[k].queue_free()
			planes.remove_at(k)
	_bursts_left = _rng.randi_range(int(b[0]), int(b[1]))
	_burst_t = _rng.randf_range(1.0, 3.0)
	_engine(str(c.get("sound", "")), float(c.get("volume_db", 0.0)), float(c.get("unit_size", 45.0)), float(c.get("max_distance", 700.0)), planes[0])
	_place_fighters()


func _engine(key: String, vol: float, unit: float, max_d: float, parent: Node) -> void:
	if key == "" or parent == null or not parent.is_inside_tree():
		return
	engine = AudioDirector.make_loop_3d(key, parent, vol)
	if engine != null:
		engine.unit_size = unit
		engine.max_distance = max_d
		engine.attenuation_filter_cutoff_hz = 2500.0
		engine.attenuation_filter_db = -12.0
		engine.play()


static func bezier(p: Array[Vector3], u: float) -> Vector3:
	var v: float = 1.0 - u
	return p[0] * v * v * v + p[1] * 3.0 * v * v * u + p[2] * 3.0 * v * u * u + p[3] * u * u * u


func _place_fighters() -> void:
	var lag: float = float(cfg.get("chase_lag", 0.9)) / maxf(duration, 0.1)
	for i: int in planes.size():
		var u: float = clampf(t / duration - lag * float(planes[i].get_meta("lag", float(i))), 0.0, 1.0)
		var p: Vector3 = bezier(curve, u)
		var q: Vector3 = bezier(curve, minf(u + 0.01, 1.0))
		if q.is_equal_approx(p):
			q = p + (curve[3] - curve[2]).normalized()
		var fwd: Vector3 = (q - p).normalized()
		var bank: float = clampf((bezier(curve, minf(u + 0.03, 1.0)) - q).normalized().cross(fwd).y * 3.0, -1.1, 1.1)
		planes[i].global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3(0, 0, 1), bank), p)
		planes[i].scale = Vector3.ONE * float(cfg.get("wingspan", 1.9))


func _process(delta: float) -> void:
	t += delta
	if kind == Kind.BOMBERS:
		position += heading * speed * delta
		if (position - start).length() > length:
			queue_free()
	else:
		_place_fighters()
		_fire_tracers(delta)
		if t > duration + 2.0 and _faller == null:
			queue_free()
	_update_fall(delta)
	_update_tracers(delta)


# ================================================================== tracer bursts (fighters)

func _fire_tracers(delta: float) -> void:
	if planes.size() < 2 or _bursts_left <= 0:
		return
	_burst_t -= delta
	if _burst_t > 0.0:
		return
	_bursts_left -= 1
	_burst_t = _rng.randf_range(1.2, 3.0)
	var chaser: Node3D = planes[1]
	var target: Node3D = planes[0]
	var n: int = _rng.randi_range(5, 9)
	for k: int in n:
		var dir: Vector3 = (target.global_position - chaser.global_position).normalized()
		dir = (dir + Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.03, 0.04), _rng.randf_range(-0.04, 0.04))).normalized()
		var tr: MeshInstance3D = MeshInstance3D.new()
		tr.mesh = Props.unit_box()
		tr.material_override = PlaneModels.tracer_material()
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tr)
		var p0: Vector3 = chaser.global_position + dir * (2.0 + k * 9.0)
		tr.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3(0.16, 0.16, 6.0)), p0)
		_tracers.append([tr, dir * 320.0, 0.9])
	if sound.is_valid():
		sound.call(str(cfg.get("mg_sound", "")), chaser.global_position, 0.0)


func _update_tracers(delta: float) -> void:
	for i: int in range(_tracers.size() - 1, -1, -1):
		var e: Array = _tracers[i]
		var tr: MeshInstance3D = e[0]
		e[2] = float(e[2]) - delta
		if float(e[2]) <= 0.0 or not is_instance_valid(tr):
			if is_instance_valid(tr):
				tr.queue_free()
			_tracers.remove_at(i)
			continue
		tr.global_position += (e[1] as Vector3) * delta


# ================================================================== a plane goes down

## Sets plane `index` on fire and sends it down toward `crash_at` (behind the hills) over `secs`.
func shoot_down(index: int, crash_at: Vector3, secs: float) -> Node3D:
	if index < 0 or index >= planes.size() or _faller != null:
		return null
	_faller = planes[index]
	planes.remove_at(index)
	_fall_secs = secs
	var p0: Vector3 = _faller.global_position
	var fwd: Vector3 = -_faller.global_transform.basis.z.normalized()
	var xf: Transform3D = _faller.global_transform
	remove_child(_faller)
	get_parent().add_child(_faller)
	_faller.global_transform = xf
	_fall_path = [p0, p0 + fwd * 60.0 + Vector3(0, -6, 0), crash_at + Vector3(0, 70, 0) + (p0 - crash_at).normalized() * 40.0, crash_at]
	_fall_t = 0.0
	var fire: GPUParticles3D = Props.flames(_faller, Vector3(0.25, 0.0, -0.1), 0.4, 0.7, 26)
	fire.local_coords = true
	var trail: GPUParticles3D = _trail(_faller)
	trail.emitting = true
	hit.emit(_faller)
	return _faller


func _trail(parent: Node3D) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "SmokeTrail"
	p.amount = 90
	p.lifetime = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(-0.3, 0.6, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.4
	pm.scale_curve = Props._curve_tex([[0.0, 0.25], [1.0, 1.0]])
	pm.color_ramp = Props._ramp_tex([[0.0, Color(0.9, 0.45, 0.15, 0.8)], [0.08, Color(0.18, 0.15, 0.14, 0.7)], [1.0, Color(0.1, 0.1, 0.12, 0.0)]])
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(9, 9)
	var m: StandardMaterial3D = Props._particle_mat(Color(0, 0, 0), Color(0, 0, 0), 0.0, false)
	m.disable_fog = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p


func _update_fall(delta: float) -> void:
	if _fall_t < 0.0 or _faller == null or not is_instance_valid(_faller):
		return
	_fall_t += delta
	var u: float = clampf(_fall_t / _fall_secs, 0.0, 1.0)
	var e: float = u * u * (1.6 - 0.6 * u)   # it gathers speed
	var p: Vector3 = bezier(_fall_path, e)
	var q: Vector3 = bezier(_fall_path, minf(e + 0.01, 1.0))
	var fwd: Vector3 = (q - p).normalized() if not q.is_equal_approx(p) else Vector3.DOWN
	var up: Vector3 = Vector3.UP if absf(fwd.y) < 0.98 else Vector3.RIGHT
	var s: Vector3 = _faller.scale
	_faller.global_transform = Transform3D(Basis.looking_at(fwd, up) * Basis(Vector3(0, 0, 1), _fall_t * 1.3), p)
	_faller.scale = s
	if u >= 1.0:
		_fall_t = -1.0
		crashed.emit(p)
		var trail: Node = _faller.get_node_or_null("SmokeTrail")
		if trail != null:   # keep the trail hanging in the air after the plane is gone
			var xf: Transform3D = (trail as Node3D).global_transform
			_faller.remove_child(trail)
			get_parent().add_child(trail)
			(trail as Node3D).global_transform = xf
			(trail as GPUParticles3D).emitting = false
			get_tree().create_timer(10.0).timeout.connect(trail.queue_free)
		_faller.queue_free()
		_faller = null
		if kind == Kind.FIGHTERS and t > duration:
			queue_free()
