class_name DeployedTurret
extends Node3D
## Baseline deployable (THE MIDDLEMAN before its milestone): hovers, fires at the nearest enemy in range every
## shot_interval for `life` seconds. Its hits count as the weapon's own damage (use-XP).

var weapon: BSWeapon
var life: float = 12.0
var shot_interval: float = 0.35
var range_m: float = 22.0
var shot_dmg: float = 8.0
var _t: float = 0.0


func _ready() -> void:
	top_level = true
	var mi: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(0.5, 0.25, 0.5)
	mi.mesh = b
	mi.material_override = WeaponFX.glow_mat(WeaponData.color(weapon.id) if weapon != null else Color.ORANGE)
	add_child(mi)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = shot_interval
	var near: Array[Node3D] = Combat.in_radius(get_tree(), global_position, range_m)
	if near.is_empty():
		return
	var e: Node3D = near[0]
	var c: Vector3 = e.call("get_center")
	WeaponFX.tracer(get_parent(), global_position, c, WeaponData.color(weapon.id), 0.05, 0.06)
	weapon.deal(e, shot_dmg, c, c - global_position)
