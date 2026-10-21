extends Node3D
## Pooled, cheap greybox VFX: bullet impacts, blood puffs, tracers, explosions, Overclock static bursts.
## Presentation only.

const IMPACTS: int = 48
const BLOOD: int = 16
const TRACERS: int = 12
const BLASTS: int = 4
const STATICS: int = 4
const STATIC_LIFE: float = 0.42
const STATIC_TEAL: Color = Color(0.25, 0.85, 0.8)
const STATIC_VIOLET: Color = Color(0.72, 0.42, 1.0)

var _impacts: Array[MeshInstance3D] = []
var _impact_life: Array[float] = []
var _blood: Array[CPUParticles3D] = []
var _tracers: Array[MeshInstance3D] = []
var _tracer_life: Array[float] = []
var _blasts: Array[Node3D] = []
var _blast_life: Array[float] = []
var _statics: Array[Node3D] = []
var _static_life: Array[float] = []
var _ni: int = 0
var _nb: int = 0
var _nt: int = 0
var _nx: int = 0
var _ns: int = 0


func _ready() -> void:
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.05, 0.85)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	for i: int in IMPACTS:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = dark
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.hide()
		add_child(mi)
		_impacts.append(mi)
		_impact_life.append(0.0)
	var blood_mat: StandardMaterial3D = StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.32, 0.03, 0.04)
	var blood_mesh: BoxMesh = BoxMesh.new()
	blood_mesh.size = Vector3(0.04, 0.04, 0.04)
	blood_mesh.material = blood_mat
	for i: int in BLOOD:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 10
		p.lifetime = 0.45
		p.explosiveness = 1.0
		p.mesh = blood_mesh
		p.direction = Vector3(0, 0, 1)
		p.spread = 35.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.5
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.4
		add_child(p)
		_blood.append(p)
	var tracer_mat: StandardMaterial3D = StandardMaterial3D.new()
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.55, 0.5)
	tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tracer_mesh: BoxMesh = BoxMesh.new()
	tracer_mesh.size = Vector3(0.008, 0.008, 1.0)
	for i: int in TRACERS:
		var t: MeshInstance3D = MeshInstance3D.new()
		t.mesh = tracer_mesh
		t.material_override = tracer_mat
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.hide()
		add_child(t)
		_tracers.append(t)
		_tracer_life.append(0.0)
	var fire_mat: StandardMaterial3D = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.8)
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	for i: int in BLASTS:
		var root: Node3D = Node3D.new()
		var ball: MeshInstance3D = MeshInstance3D.new()
		ball.mesh = sphere
		ball.material_override = fire_mat.duplicate()
		ball.name = "Ball"
		root.add_child(ball)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = Color(1.0, 0.6, 0.3)
		light.omni_range = 12.0
		root.add_child(light)
		root.hide()
		add_child(root)
		_blasts.append(root)
		_blast_life.append(0.0)
	# Overclock Cordial's static burst: a flat ring that races out to the burst radius, a core flash, sparks
	# and a violet light (WEAPONS.md section 20.2 "a teal-violet ring pulse").
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(STATIC_TEAL, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = STATIC_TEAL
	ring_mat.emission_energy_multiplier = 2.5
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.9
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 6
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.03, 0.03, 0.2)
	spark_mesh.material = ring_mat
	for i: int in STATICS:
		var root: Node3D = Node3D.new()
		var ring_: MeshInstance3D = MeshInstance3D.new()
		ring_.name = "Ring"
		ring_.mesh = ring_mesh
		ring_.material_override = ring_mat.duplicate()
		ring_.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring_)
		var core: MeshInstance3D = MeshInstance3D.new()
		core.name = "Core"
		core.mesh = sphere
		core.material_override = ring_mat.duplicate()
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(core)
		var sparks: CPUParticles3D = CPUParticles3D.new()
		sparks.name = "Sparks"
		sparks.emitting = false
		sparks.one_shot = true
		sparks.amount = 36
		sparks.lifetime = 0.35
		sparks.explosiveness = 1.0
		sparks.mesh = spark_mesh
		sparks.direction = Vector3(0, 0.3, 0)
		sparks.spread = 180.0
		sparks.initial_velocity_min = 6.0
		sparks.initial_velocity_max = 14.0
		sparks.gravity = Vector3(0, -4.0, 0)
		sparks.scale_amount_min = 0.5
		sparks.scale_amount_max = 1.6
		root.add_child(sparks)
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "Light"
		light.light_color = STATIC_VIOLET
		light.omni_range = 9.0
		root.add_child(light)
		root.hide()
		add_child(root)
		_statics.append(root)
		_static_life.append(0.0)


func _process(delta: float) -> void:
	for i: int in IMPACTS:
		if _impact_life[i] > 0.0:
			_impact_life[i] -= delta
			if _impact_life[i] <= 0.0:
				_impacts[i].hide()
	for i: int in TRACERS:
		if _tracer_life[i] > 0.0:
			_tracer_life[i] -= delta
			if _tracer_life[i] <= 0.0:
				_tracers[i].hide()
	for i: int in BLASTS:
		if _blast_life[i] > 0.0:
			_blast_life[i] -= delta
			var k: float = clampf(_blast_life[i] / 0.45, 0.0, 1.0)
			var ball: MeshInstance3D = _blasts[i].get_node("Ball")
			var r: float = float(_blasts[i].get_meta("radius", 3.0)) * lerpf(0.55, 0.15, k)
			ball.scale = Vector3.ONE * r
			(ball.material_override as StandardMaterial3D).albedo_color.a = k * 0.8
			(_blasts[i].get_node("Light") as OmniLight3D).light_energy = k * 6.0
			if _blast_life[i] <= 0.0:
				_blasts[i].hide()
	for i: int in STATICS:
		if _static_life[i] > 0.0:
			_static_life[i] -= delta
			var k: float = clampf(_static_life[i] / STATIC_LIFE, 0.0, 1.0)   # 1 at birth -> 0
			var grow: float = 1.0 - k * k
			var radius: float = float(_statics[i].get_meta("radius", 3.0))
			var ring_: MeshInstance3D = _statics[i].get_node("Ring")
			ring_.scale = Vector3(1, 1, 1) * maxf(0.05, radius * grow)
			var tint: Color = STATIC_TEAL.lerp(STATIC_VIOLET, 1.0 - k)
			var rm: StandardMaterial3D = ring_.material_override
			rm.albedo_color = Color(tint, k * 0.9)
			rm.emission = tint
			var core: MeshInstance3D = _statics[i].get_node("Core")
			core.scale = Vector3.ONE * lerpf(0.15, 0.9, 1.0 - k) * 0.5
			(core.material_override as StandardMaterial3D).albedo_color = Color(STATIC_VIOLET, k * k * 0.8)
			(_statics[i].get_node("Light") as OmniLight3D).light_energy = k * 5.0
			if _static_life[i] <= 0.0:
				_statics[i].hide()


func impact(pos: Vector3, normal: Vector3) -> void:
	var mi: MeshInstance3D = _impacts[_ni]
	_impact_life[_ni] = 8.0
	_ni = (_ni + 1) % IMPACTS
	mi.show()
	mi.global_position = pos + normal * 0.01
	if absf(normal.dot(Vector3.UP)) > 0.99:
		mi.look_at(pos + normal, Vector3.FORWARD)
	else:
		mi.look_at(pos + normal, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)


func blood(pos: Vector3, toward: Vector3) -> void:
	var p: CPUParticles3D = _blood[_nb]
	_nb = (_nb + 1) % BLOOD
	p.global_position = pos
	if toward.length_squared() > 0.001:
		var fwd: Vector3 = toward.normalized()
		var up: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		p.global_basis = Basis.looking_at(-fwd, up)
	p.restart()
	p.emitting = true


func tracer(from: Vector3, to: Vector3) -> void:
	var dist: float = from.distance_to(to)
	if dist < 1.5:
		return
	var t: MeshInstance3D = _tracers[_nt]
	_tracer_life[_nt] = 0.04
	_nt = (_nt + 1) % TRACERS
	t.show()
	t.global_position = from.lerp(to, 0.5)
	t.look_at(to, Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.98 else Vector3.RIGHT)
	t.scale = Vector3(1, 1, dist)


func explosion(pos: Vector3, radius: float) -> void:
	var b: Node3D = _blasts[_nx]
	_blast_life[_nx] = 0.45
	_nx = (_nx + 1) % BLASTS
	b.set_meta("radius", radius)
	b.global_position = pos
	b.show()


## Overclock Cordial's static burst at `pos`, racing out to `radius` (WEAPONS.md section 20.2).
func static_burst(pos: Vector3, radius: float) -> void:
	var b: Node3D = _statics[_ns]
	_static_life[_ns] = STATIC_LIFE
	_ns = (_ns + 1) % STATICS
	b.set_meta("radius", radius)
	b.global_position = pos
	b.show()
	(b.get_node("Ring") as MeshInstance3D).scale = Vector3.ONE * 0.05   # a TorusMesh already lies flat (XZ)
	var sparks: CPUParticles3D = b.get_node("Sparks")
	sparks.restart()
	sparks.emitting = true
