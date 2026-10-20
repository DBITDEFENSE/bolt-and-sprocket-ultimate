class_name AmmoOrb
extends Node3D
## Ammo pickup orb (the original's purple ammoR / cyan ammoZ, plus the remake's paper family). Group "pickups";
## collect(bolt) grants one orb of its family to every owned gun in it (WeaponManager.add_family_ammo). Pops out
## with a velocity, falls onto world geometry, drifts to Bolt within 3.5 m and is collected within 1.2 m.
## Spawn with AmmoOrb.spawn(parent, pos, "void" | "charge" | "paper", vel).

var family: String = "void"
var vel: Vector3 = Vector3.ZERO
var life: float = 25.0
var collected: bool = false


static func spawn(parent: Node, pos: Vector3, fam: String, v: Vector3 = Vector3.ZERO) -> AmmoOrb:
	var o: AmmoOrb = AmmoOrb.new()
	o.family = fam
	o.vel = v
	o.position = pos
	parent.add_child(o)
	return o


func _ready() -> void:
	add_to_group(&"pickups")
	add_to_group(&"ammo_orbs")
	var mi: MeshInstance3D = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	mi.mesh = s
	var fams: Dictionary = WeaponData.doc()["ammo_families"]
	var col: Color = Color.from_string(str((fams.get(family, {}) as Dictionary).get("color", "#ffffff")), Color.WHITE)
	mi.material_override = WeaponFX.glow_mat(col)
	add_child(mi)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	var b: Bolt = get_tree().get_first_node_in_group(&"player") as Bolt
	if b != null and not b.dead:
		var d: float = b.global_position.distance_to(global_position)
		if d < 1.2:
			collect(b)
			return
		if d < 3.5:
			global_position = global_position.lerp(b.global_position, 1.0 - exp(-6.0 * dt))
			return
	vel.y -= 16.0 * dt
	var step: Vector3 = vel * dt
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + step + Vector3(0, -0.25 if vel.y < 0 else 0.0, 0), 1 | (1 << 5))
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		global_position += step
	else:
		global_position = (hit["position"] as Vector3) + Vector3(0, 0.25, 0)
		vel = Vector3.ZERO


func collect(b: Node) -> void:
	if collected:
		return
	collected = true
	var wm: WeaponManager = b.get_node_or_null("Weapons") as WeaponManager if b != null else null
	if wm != null:
		wm.add_family_ammo(family)
	queue_free()
