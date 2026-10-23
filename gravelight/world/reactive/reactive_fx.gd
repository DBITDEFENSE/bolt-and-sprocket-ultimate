class_name ReactiveFx
extends Node3D
## Pooled particle bursts for reactive dressing (Update 02 section 8, T-053): glass shards (and a splash of what
## was in the bottle), hay chaff kicked up by feet, a puff of snow. One per scene tree, made on first use under the
## tree's root; a few CPUParticles3D per kind, reused round-robin, so a burst costs nothing to start and nothing at
## all while idle. Presentation only.

const POOL: int = 6

var _glass: Array[CPUParticles3D] = []
var _splash: Array[CPUParticles3D] = []
var _chaff: Array[CPUParticles3D] = []
var _ng: int = 0
var _nc: int = 0
## Bursts started, by kind (tests and the dev overlay).
var counts: Dictionary = {}


static func get_for(n: Node) -> ReactiveFx:
	if n == null or not n.is_inside_tree():
		return null
	var t: SceneTree = n.get_tree()
	var fx: ReactiveFx = t.get_first_node_in_group(&"reactive_fx") as ReactiveFx
	if fx == null:
		fx = ReactiveFx.new()
		fx.name = "ReactiveFx"
		t.root.add_child(fx)
	return fx


func _ready() -> void:
	add_to_group(&"reactive_fx")
	var shard_mat: StandardMaterial3D = StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.75, 0.85, 0.8, 0.55)
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_mat.roughness = 0.05
	shard_mat.metallic_specular = 1.0
	shard_mat.vertex_color_use_as_albedo = true
	var shard: BoxMesh = BoxMesh.new()
	shard.size = Vector3(0.025, 0.004, 0.018)
	shard.material = shard_mat
	var drop_mat: StandardMaterial3D = StandardMaterial3D.new()
	drop_mat.albedo_color = Color(1, 1, 1, 0.7)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.vertex_color_use_as_albedo = true
	drop_mat.roughness = 0.1
	var drop: SphereMesh = SphereMesh.new()
	drop.radius = 0.008
	drop.height = 0.016
	drop.radial_segments = 4
	drop.rings = 2
	drop.material = drop_mat
	var chaff_mat: StandardMaterial3D = StandardMaterial3D.new()
	chaff_mat.albedo_color = Color(0.78, 0.66, 0.36)
	chaff_mat.vertex_color_use_as_albedo = true
	chaff_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bit: QuadMesh = QuadMesh.new()
	bit.size = Vector2(0.05, 0.012)
	bit.material = chaff_mat
	for i: int in POOL:
		_glass.append(_make(shard, 22, 1.1, 1.5, 3.5, 70.0, Vector3(0, -9.8, 0)))
		_splash.append(_make(drop, 16, 0.6, 0.8, 2.0, 45.0, Vector3(0, -9.8, 0)))
		var c: CPUParticles3D = _make(bit, 16, 1.8, 0.4, 1.4, 70.0, Vector3(0, -0.6, 0))
		c.damping_min = 1.2
		c.damping_max = 2.0
		c.angular_velocity_min = -360.0
		c.angular_velocity_max = 360.0
		c.particle_flag_align_y = false
		c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		c.emission_sphere_radius = 0.18
		_chaff.append(c)


func _make(mesh: Mesh, amount: int, life: float, v0: float, v1: float, spread: float, grav: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.mesh = mesh
	p.direction = Vector3(0, 1, 0)
	p.spread = spread
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _fire(p: CPUParticles3D, at: Vector3, dir: Vector3, tint: Color) -> void:
	p.global_position = at
	p.direction = dir if dir.length_squared() > 0.001 else Vector3.UP
	p.color = tint
	p.restart()
	p.emitting = true


## One burst of each kind at `at`, a thousandth of the size (nothing shows), from throwaway copies of the emitters:
## the first draw of these materials compiles their shaders, which stalled the frame of the first real burst
## (RenderWarm calls this at map load, T-070). Not counted in `counts`.
func warm(at: Vector3) -> void:
	for src: CPUParticles3D in [_glass[0], _splash[0], _chaff[0]]:
		var p: CPUParticles3D = src.duplicate() as CPUParticles3D
		p.scale_amount_min = 0.001
		p.scale_amount_max = 0.001
		add_child(p)
		_fire(p, at, Vector3.UP, Color(1, 1, 1, 0.5))
		get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)


## A glass vessel bursting at `at`, the shot travelling along `dir`; `liquid` tints the splash (alpha 0 = empty).
func glass(at: Vector3, dir: Vector3, glass_tint: Color, liquid: Color) -> void:
	var away: Vector3 = (dir.normalized() * 0.6 + Vector3.UP * 0.8).normalized()
	_fire(_glass[_ng], at, away, glass_tint)
	if liquid.a > 0.01:
		_fire(_splash[_ng], at, away, liquid)
	_ng = (_ng + 1) % POOL
	counts["glass"] = int(counts.get("glass", 0)) + 1


## Hay chaff kicked up at `at` (feet in the straw, a shot into a bale).
func chaff(at: Vector3, tint: Color = Color(0.82, 0.7, 0.4)) -> void:
	_fire(_chaff[_nc], at, Vector3.UP, tint)
	_nc = (_nc + 1) % POOL
	counts["chaff"] = int(counts.get("chaff", 0)) + 1
