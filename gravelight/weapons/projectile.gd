class_name Projectile
extends Node3D
## A fast physical shot that sweeps a ray each physics step: Panzerschreck rockets and Ashlight bolts.
## rocket: explodes on any hit. bolt: direct damage to a zombie it hits, splash on every impact,
## and bounces off world geometry `ricochets` times.

const MASK: int = 1 | (1 << 3) | (1 << 8)   # world | zombie_hitbox | door
const LIFETIME: float = 4.0

var kind: StringName = &"rocket"
var weapon_id: StringName = &"panzerschreck"
var by_player: int = 1
var velocity: Vector3 = Vector3.ZERO
var direct_damage: float = 0.0
var cfg: Dictionary = {}          # explosion cfg for Explosion.detonate
var ricochets: int = 0
var exclude: Array[RID] = []
var chain: int = 0              # Ashlight Corona: arcs to N more zombies after a direct hit
var chain_radius: float = 6.0
var chain_mult: float = 0.7
var cluster: Dictionary = {}    # Stovepipe Sermon: bomblets {count, dmg, r}
var _age: float = 0.0


func _ready() -> void:
	var glow: Color = Color(1.0, 0.6, 0.25) if kind == &"rocket" else Color(0.72, 0.35, 1.0)
	var body: MeshInstance3D = MeshInstance3D.new()
	if kind == &"rocket":
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.09, 0.09, 0.45)
		body.mesh = bm
		body.material_override = Interactable.greybox_mat(Color(0.25, 0.27, 0.2))
	else:
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		body.mesh = sm
		body.material_override = Interactable.greybox_mat(glow, 9.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = glow
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
	q.collide_with_areas = true
	var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		global_position = to
		if velocity.length_squared() > 0.01:
			look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.98 else Vector3.RIGHT)
		return
	var hit_pos: Vector3 = res["position"]
	var col: Object = res["collider"]
	if col is Hitbox:
		var z: Zombie = (col as Hitbox).enemy as Zombie
		if kind == &"bolt" and z != null and z.is_active():
			var killed: bool = z.take_damage(direct_damage, (col as Hitbox).limb, weapon_id, by_player, &"wonder")
			GLBus.enemy_hit_feedback.emit(by_player, killed, false)
			if chain > 0:
				_chain_from(z, hit_pos)
		_impact(hit_pos)
		queue_free()
		return
	# world / door (and quest shootables: bells, the drummer)
	var target: Node = WeaponHolder.shootable_of(col)
	if target != null:
		WeaponHolder.notify_shot(target, weapon_id, String(weapon_id).ends_with("_up"), by_player)
	_impact(hit_pos)
	if kind == &"bolt" and ricochets > 0:
		ricochets -= 1
		var n: Vector3 = res["normal"]
		velocity = velocity.bounce(n)
		global_position = hit_pos + n * 0.05
		return
	queue_free()


func _impact(pos: Vector3) -> void:
	var ctx: Node3D = self
	Explosion.detonate(ctx, pos, cfg, by_player, weapon_id)
	if not cluster.is_empty():
		_scatter_bomblets(pos)


## Arcs to up to `chain` more zombies near the first hit (each hit once), at chain_mult damage.
func _chain_from(first: Zombie, from: Vector3) -> void:
	var dir: ZombieDirector = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	if dir == null:
		return
	var done: Array = [first]
	var at: Vector3 = from
	for i: int in chain:
		var best: Zombie = null
		var best_d: float = chain_radius
		for z: Zombie in dir.active_zombies():
			if done.has(z):
				continue
			var d: float = at.distance_to(z.global_position + Vector3.UP)
			if d < best_d:
				best_d = d
				best = z
		if best == null:
			return
		done.append(best)
		var to: Vector3 = best.global_position + Vector3.UP
		Effects.tracer(at, to)
		var killed: bool = best.take_damage(direct_damage * chain_mult, &"torso", weapon_id, by_player, &"wonder")
		GLBus.enemy_hit_feedback.emit(by_player, killed, false)
		at = to


## Bomblets land around the impact over the next half second.
func _scatter_bomblets(pos: Vector3) -> void:
	var host: Node = get_parent()
	if host == null:
		return
	var count: int = int(cluster.get("count", 6))
	var bcfg: Dictionary = {"damage": float(cluster.get("dmg", 400)), "radius": float(cluster.get("r", 2.5)), "edge_mult": 0.4,
		"self_damage_near": 0, "self_damage_far": 0, "sound_db": -4.0}
	var pid: int = by_player     # locals: this projectile is freed before the bomblets go off
	var wid: StringName = weapon_id
	for i: int in count:
		var off: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(1.5, 4.5)
		var b: Node3D = Node3D.new()
		host.add_child(b)
		b.global_position = pos + off
		var t: SceneTreeTimer = host.get_tree().create_timer(0.15 + 0.07 * float(i))
		t.timeout.connect(func() -> void:
			if is_instance_valid(b):
				Explosion.detonate(b, b.global_position, bcfg, pid, wid)
				b.queue_free())
