class_name EnemyProjectile
extends Node3D
## Enemy shots (spawnEnemyProjectile index.html:4531, simulated in updateProjectiles :5559).
## Moves itself (no physics body): gravity, gentle homing, a swept ray against world/props, and a
## sphere test against Bolt (0.9 + r). Explosive shots (boom_r > 0) deal their damage as a blast
## instead. Pooled: up to POOL_MAX instances are recycled.
## opts (all optional): grav, boom_r, homing, speed, fragile, source, scale,
##   on_land: Callable(pos: Vector3, hit_player: bool)  called when the shot ends by impact or timeout (not deny)
##   on_deny: Callable(shot)                            called when a player shot/effect destroys it
##   hittable: bool   joins "enemies"/"damageable" while flying so the mallet (and guns) can hit it:
##                    take_damage(hit) -> on_struck(shot, hit) if given, else deny(). Fines batted back, bombs.
##   on_struck: Callable(shot, hit: Combat.Hit)
##   kind: StringName  a tag for tests/HUD (e.g. &"fine", &"chat", &"like_orb", &"review_bomb")

const POOL_MAX: int = 128
const WORLD_MASK: int = 1 | (1 << 5)

static var _pool: Array[EnemyProjectile] = []

var vel: Vector3 = Vector3.ZERO
var dmg: float = 10.0
var grav: float = 0.0
var life: float = 4.0
var r: float = 0.3
var boom_r: float = 0.0
var homing: float = 0.0
var speed: float = 0.0
var fragile: bool = false
var source: Node = null
var color: Color = Color(1.0, 0.36, 0.18)
var kind: StringName = &""
var hittable: bool = false
var radius: float = 0.3
var on_land: Callable = Callable()
var on_deny: Callable = Callable()
var on_struck: Callable = Callable()
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _active: bool = false


static func fire(parent: Node, pos: Vector3, vel_: Vector3, dmg_: float, color_: Color, size: float = 0.2,
		life_: float = 4.0, opts: Dictionary = {}) -> EnemyProjectile:
	var p: EnemyProjectile = null
	while not _pool.is_empty() and p == null:
		p = _pool.pop_back()
		if not is_instance_valid(p):
			p = null
	if p == null:
		p = EnemyProjectile.new()
	p.vel = vel_
	p.dmg = dmg_
	p.color = color_
	p.r = size + 0.1
	p.life = life_
	p.grav = float(opts.get("grav", 0.0))
	p.boom_r = float(opts.get("boom_r", 0.0))
	p.homing = float(opts.get("homing", 0.0))
	p.speed = float(opts.get("speed", vel_.length()))
	p.fragile = bool(opts.get("fragile", false))
	p.source = opts.get("source", null)
	p.kind = StringName(str(opts.get("kind", "")))
	p.hittable = bool(opts.get("hittable", false))
	p.radius = maxf(p.r, 0.35)
	p.on_land = opts.get("on_land", Callable())
	p.on_deny = opts.get("on_deny", Callable())
	p.on_struck = opts.get("on_struck", Callable())
	parent.add_child(p)
	p.global_position = pos
	p._activate(size, Vector3(opts.get("scale", Vector3.ONE)))
	return p


static func clear_pool() -> void:
	for p: EnemyProjectile in _pool:
		if is_instance_valid(p):
			p.free()
	_pool.clear()


func _activate(size: float, sc: Vector3) -> void:
	if _mesh == null:
		_mat = EnemyFx.glow(color)
		_mesh = EnemyFx.sphere(self, 1.0, Vector3.ZERO, _mat)
	_mat.albedo_color = color
	_mat.emission = color
	_mesh.scale = sc * size
	_active = true
	add_to_group(&"enemy_projectiles")
	if hittable:
		add_to_group(&"enemies")
		add_to_group(&"damageable")


func is_alive() -> bool:
	return _active


func get_center() -> Vector3:
	return global_position


func is_active() -> bool:
	return _active


## Hittable shots: the mallet or a gun struck it in flight.
func take_damage(hit: Combat.Hit) -> bool:
	if not _active:
		return false
	if on_struck.is_valid():
		on_struck.call(self, hit)
		if _active:
			deny()
	else:
		deny()
	return true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	life -= delta
	vel.y -= grav * delta
	var bolt: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var alive: bool = bolt != null and bool(bolt.call("is_alive"))
	if homing > 0.0 and alive:
		var want: Vector3 = ((bolt.call("get_center") as Vector3) + Vector3(0, 0.3, 0) - global_position).normalized() * speed
		vel = vel.lerp(want, minf(1.0, homing * delta))
	var from: Vector3 = global_position
	var to: Vector3 = from + vel * delta
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit["position"]
		_finish(bolt, alive)
		return
	global_position = to
	if alive and global_position.distance_to(bolt.call("get_center") as Vector3) < 0.9 + r:
		if boom_r <= 0.0:
			var h: Combat.Hit = Combat.Hit.make(dmg, Combat.Type.KINETIC, source)
			h.point = global_position
			h.dir = Vector3(vel.x, 0, vel.z).normalized()
			h.knock = 4.0
			var landed: bool = EnemyBase.hurt_player(bolt, h, source)
			if landed and on_land.is_valid():
				var cb: Callable = on_land
				var at: Vector3 = global_position
				on_land = Callable()
				_finish(bolt, alive)
				cb.call(at, true)
				return
		_finish(bolt, alive)
		return
	if life <= 0.0:
		_finish(bolt, alive)


## Destroyed by a player effect (B.O.O.M. Box's drop shreds fragile shots): no damage, no blast.
func deny() -> void:
	if not _active:
		return
	boom_r = 0.0
	var cb: Callable = on_deny
	on_land = Callable()
	_finish(null, false)
	if cb.is_valid():
		cb.call(self)


## Ends the shot quietly (no damage, no callbacks), e.g. a batted fine that the boss now owns.
func retire() -> void:
	if not _active:
		return
	boom_r = 0.0
	on_land = Callable()
	_finish(null, false)


func _finish(bolt: Node3D, alive: bool) -> void:
	var hit_player: bool = false
	if boom_r > 0.0 and alive:
		var c: Vector3 = bolt.call("get_center")
		if c.distance_to(global_position) < boom_r + 0.45:
			var h: Combat.Hit = Combat.Hit.make(dmg, Combat.Type.KINETIC, source)
			h.point = global_position
			h.dir = Vector3(c.x - global_position.x, 0, c.z - global_position.z).normalized()
			h.knock = 6.0
			hit_player = EnemyBase.hurt_player(bolt, h, source)
	if boom_r > 0.0:
		EnemyFx.ring(get_parent(), global_position, boom_r, 0.25, color)
	var land: Callable = on_land
	var at: Vector3 = global_position
	on_land = Callable()
	on_deny = Callable()
	on_struck = Callable()
	_active = false
	remove_from_group(&"enemy_projectiles")
	remove_from_group(&"enemies")
	remove_from_group(&"damageable")
	if land.is_valid():
		land.call(at, hit_player)
	if _pool.size() < POOL_MAX:
		get_parent().remove_child(self)
		_pool.append(self)
	else:
		queue_free()
