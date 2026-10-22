class_name DripPoint
extends Node3D
## Water dripping from a cellar ceiling (Map 0's Old Cellar, T-051): every few seconds a drop falls from this
## point to the floor `height` below and lands with a plip (sound key "cellar_drip") and a tiny splash.
## Presentation only. The drop and the splash are one-shot CPUParticles3D, restarted per drip.

@export var height: float = 2.9
## Seconds between drips (random in [x, y]).
@export var interval: Vector2 = Vector2(1.6, 4.8)
@export var volume_db: float = -4.0

var _drop: CPUParticles3D
var _splash: CPUParticles3D
var _t: float = 0.0
var _fall: float = 0.75
var _plip_in: float = -1.0


func _ready() -> void:
	_fall = sqrt(2.0 * maxf(0.1, height) / 9.8)
	var water: StandardMaterial3D = StandardMaterial3D.new()
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.albedo_color = Color(0.7, 0.78, 0.9, 0.7)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop = _particles(1, _fall, Vector3(0.012, 0.03, 0.012), water)
	_drop.gravity = Vector3(0, -9.8, 0)
	add_child(_drop)
	_splash = _particles(6, 0.3, Vector3(0.01, 0.01, 0.01), water)
	_splash.position = Vector3(0, -height + 0.02, 0)
	_splash.direction = Vector3.UP
	_splash.spread = 60.0
	_splash.initial_velocity_min = 0.6
	_splash.initial_velocity_max = 1.1
	_splash.gravity = Vector3(0, -6.0, 0)
	add_child(_splash)
	_t = randf_range(0.0, interval.y)


func _particles(amount: int, life: float, size: Vector3, m: Material) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = m
	p.mesh = mesh
	return p


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = randf_range(interval.x, interval.y)
		_drop.restart()
		_plip_in = _fall
	if _plip_in > 0.0:
		_plip_in -= delta
		if _plip_in <= 0.0:
			_splash.restart()
			AudioDirector.play_3d("cellar_drip", global_position + Vector3(0, -height, 0), volume_db, 0.12)
