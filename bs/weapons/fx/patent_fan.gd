class_name PatentFan
extends Node3D
## The Patent Pending's cooling fan, ejected after every detonation ("as designed", updateProjectiles 5455): it pops
## up, falls and bounces off the ground. At Ω PATENT GRANTED it's a spinning saw that deals `amount` once to each
## enemy it touches.

var weapon: BSWeapon
var vel: Vector3 = Vector3.ZERO
var life: float = 2.5
var saw: bool = false
var amount: float = 20.0
var _hit: Array = []
var _mi: MeshInstance3D


func _ready() -> void:
	top_level = true
	_mi = MeshInstance3D.new()
	_mi.mesh = WeaponFX.shot_mesh("gear", 0.28)
	_mi.material_override = WeaponFX.glow_mat(Color("#ffd23e") if saw else Color("#8b95a8"))
	add_child(_mi)
	for i: int in 4:
		var blade: MeshInstance3D = WeaponFX.block(_mi, Vector3(0.05, 0.03, 0.22), Vector3.ZERO, Color("#d8dee9"))
		blade.rotation.y = TAU * i / 4.0


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	vel.y -= 18.0 * dt
	var from: Vector3 = global_position
	var to: Vector3 = from + vel * dt
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << 5))
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.1
		vel = vel.bounce(hit["normal"]) * 0.6
	else:
		global_position = to
	_mi.rotation.y += dt * (40.0 if saw else 18.0)
	_mi.rotation.x = 0.6
	if saw and weapon != null and is_instance_valid(weapon):
		for e: Node3D in Combat.in_radius(get_tree(), global_position, 0.35):
			if not _hit.has(e):
				_hit.append(e)
				weapon.deal(e, roundf(amount), global_position, vel)
