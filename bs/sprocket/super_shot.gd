class_name SuperShot
extends Node3D
## One of Super Sprocket's twin-cannon rounds (spawnProjectile in updateSuperSprocket, index.html:4085):
## 30 m/s, 1.4 s life, 6 damage (x2 while the protocol runs). Hits the first living enemy it touches
## through the Combat contract (take_damage), stops on world geometry (layer 1). weapon_id = &"super_sprocket".

var vel: Vector3 = Vector3.ZERO
var damage: float = 6.0
var life: float = 1.4
var source: Node = null
var hit_count: int = 0


func _ready() -> void:
	var m: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.06
	cap.height = 0.4
	m.mesh = cap
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color("#ff6a4a")
	mat.emission_enabled = true
	mat.emission = Color("#ff9a6a")
	mat.emission_energy_multiplier = 3.0
	m.material_override = mat
	m.rotation.x = PI * 0.5
	add_child(m)


## Call after adding it to the tree.
func launch(pos: Vector3, v: Vector3) -> void:
	global_position = pos
	vel = v
	if vel.length_squared() > 0.0001:
		look_at(pos + vel, Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT)


func _physics_process(dt: float) -> void:
	step(dt)


## Moves one tick; returns true if it hit something (and is being freed).
func step(dt: float) -> bool:
	life -= dt
	if life <= 0.0:
		queue_free()
		return false
	var from: Vector3 = global_position
	var to: Vector3 = from + vel * dt
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if is_inside_tree() else null
	var wall: Vector3 = Vector3.INF
	if space != null:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
		var r: Dictionary = space.intersect_ray(q)
		if not r.is_empty():
			wall = r["position"]
	# enemies along the segment (sampled every 0.25 m)
	var seg: float = from.distance_to(to if wall == Vector3.INF else wall)
	var n: int = maxi(1, ceili(seg / 0.25))
	for i: int in n + 1:
		var p: Vector3 = from.lerp(to, float(i) / float(n)) if wall == Vector3.INF else from.lerp(wall, float(i) / float(n))
		var hits: Array[Node3D] = Combat.in_radius(get_tree(), p, 0.2, &"enemies")
		if not hits.is_empty():
			_hit(hits[0], p)
			return true
	if wall != Vector3.INF:
		queue_free()
		return false
	global_position = to
	return false


func _hit(e: Node3D, p: Vector3) -> void:
	var h: Combat.Hit = Combat.Hit.make(damage, Combat.Type.ENERGY, source)
	h.weapon_id = &"super_sprocket"
	h.point = p
	h.dir = vel.normalized()
	e.call("take_damage", h)     # enemies emit EventBus.enemy_hit / enemy_killed themselves (M1 contract)
	hit_count += 1
	queue_free()
