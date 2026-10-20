class_name BSProjectile
extends Node3D
## A player shot in flight (updateProjectiles, index.html:5341). Swept every physics frame: world geometry by ray
## (layers world + solid props), enemies by segment-vs-sphere against their get_center()/radius (as the original
## tested distance to enemyCenter), fragile enemy shots ("DENIED"). The owning BSWeapon decides what a hit does.
## Fragile enemy projectiles: nodes in group "enemy_projectiles" with `fragile == true` (deny() if they have it).

var weapon: BSWeapon
var vel: Vector3 = Vector3.ZERO
var gravity: float = 0.0
var life: float = 2.0
var radius: float = 0.25
var size: float = 0.15
var color: Color = Color.WHITE
var stretch: float = 0.0
var data: Dictionary = {}           # free-form per-weapon payload (charge, damage, flags)
var hit_set: Array = []             # enemies already hit (pierce / saws)
var homing_target: Node3D = null
var homing_rate: float = 0.0
var homing_speed: float = 0.0
var age: float = 0.0
var dead: bool = false
var _mesh: MeshInstance3D


func _ready() -> void:
	top_level = true
	_mesh = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	s.radial_segments = 10
	s.rings = 6
	_mesh.mesh = s
	_mesh.material_override = WeaponFX.glow_mat(color)
	if stretch > 0.0:
		_mesh.scale = Vector3(1, 1, stretch)
	add_child(_mesh)


func _physics_process(dt: float) -> void:
	if dead:
		return
	age += dt
	life -= dt
	vel.y -= gravity * dt
	if homing_target != null and is_instance_valid(homing_target) and bool(homing_target.call("is_alive")):
		var want: Vector3 = ((homing_target.call("get_center") as Vector3) - global_position).normalized() * homing_speed
		vel = vel.lerp(want, minf(1.0, homing_rate * dt))
	if weapon != null and is_instance_valid(weapon):
		weapon.on_projectile_tick(self, dt)
	if dead:
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + vel * dt
	# world first: clip the step at the wall
	var wall: Dictionary = {}
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << 5))
	wall = space.intersect_ray(q)
	var seg_end: Vector3 = wall["position"] if not wall.is_empty() else to
	# enemies along the (clipped) step, nearest first
	var hits: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or hit_set.has(e) or not bool(e.call("is_alive")):
			continue
		var c: Vector3 = e.call("get_center")
		var cp: Vector3 = Geometry3D.get_closest_point_to_segment(c, from, seg_end)
		if cp.distance_to(c) < float(e.get("radius")) + radius:
			hits.append([from.distance_squared_to(cp), e, cp])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for h: Array in hits:
		var e2: Node3D = h[1]
		hit_set.append(e2)
		global_position = h[2]
		if not weapon.on_projectile_hit(self, e2, h[2]):
			kill()
			return
	if not wall.is_empty():
		global_position = wall["position"]
		if not weapon.on_projectile_world(self, wall["position"], wall["normal"]):
			kill()
			return
		return
	global_position = to
	if stretch > 0.0 and vel.length_squared() > 0.01:
		look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)
	# shoot down fragile enemy projectiles (5478)
	for n2: Node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var ep: Node3D = n2 as Node3D
		if ep == null or not WeaponData.prop_bool(ep, "fragile"):
			continue
		var ec: Vector3 = ep.call("get_center") if ep.has_method("get_center") else ep.global_position
		if ec.distance_to(global_position) < radius + float(ep.get("r") if "r" in ep else 0.2) + 0.25:
			deny_projectile(ep)
			weapon.popup.emit("bs.weapon.fx.denied", ec)
			kill()
			return
	if life <= 0.0:
		weapon.on_projectile_expire(self)
		kill()


## Destroys a fragile enemy shot: its deny() if it has one, else expire it harmlessly next frame.
static func deny_projectile(ep: Node3D) -> void:
	if ep.has_method("deny"):
		ep.call("deny")
		return
	if "boom_r" in ep:
		ep.set("boom_r", 0.0)
	if "life" in ep:
		ep.set("life", 0.0)
	else:
		ep.queue_free()


func kill() -> void:
	if dead:
		return
	dead = true
	queue_free()
