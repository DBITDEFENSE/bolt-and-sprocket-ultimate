class_name BurningGround
extends Node3D
## A patch of burning ground (Furnace Warrant). Damages zombies standing in it for `duration` seconds.

var dps: float = 150.0
var duration: float = 4.0
var radius: float = 1.6
var by_player: int = 1
var weapon_id: StringName = &"flamethrower_up"
var _t: float = 0.0
var _tick: float = 0.0
var _fx: CPUParticles3D


func _ready() -> void:
	_fx = CPUParticles3D.new()
	_fx.amount = 24
	_fx.lifetime = 0.6
	_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fx.emission_sphere_radius = radius
	_fx.direction = Vector3.UP
	_fx.spread = 20.0
	_fx.initial_velocity_min = 0.8
	_fx.initial_velocity_max = 2.0
	_fx.gravity = Vector3(0, 1.0, 0)
	var m: SphereMesh = SphereMesh.new()
	m.radius = 0.1
	m.height = 0.2
	m.material = Interactable.greybox_mat(Color(1.0, 0.45, 0.12), 5.0)
	_fx.mesh = m
	add_child(_fx)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 1.2
	light.omni_range = radius * 2.5
	light.position = Vector3.UP * 0.4
	add_child(light)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	for z: Zombie in dir.active_zombies():
		var flat: Vector2 = Vector2(z.global_position.x - global_position.x, z.global_position.z - global_position.z)
		if flat.length() <= radius and absf(z.global_position.y - global_position.y) < 1.5:
			z.take_damage(dps * 0.25, &"torso", weapon_id, by_player, &"fire")
