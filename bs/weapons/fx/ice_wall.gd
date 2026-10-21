class_name IceWall
extends StaticBody3D
## Frostbyte's ICE WALL alt-fire: a width x height barrier on the solid-props layer (blocks pathing and bodies), with
## `hp` and `life`. Enemy projectiles (group "enemy_projectiles") that enter it are destroyed and chip its HP
## (their "dmg" / "damage", default 10). Enemies touching it gain frost (weapon.add_frost); Ω freezes on touch.
## Implements the damageable bits (take_damage / get_center / is_alive / radius) so enemies can punch it.

var weapon: BSWeapon
var width: float = 4.0
var height: float = 2.5
var depth: float = 0.5
var hp: float = 150.0
var life: float = 6.0
var frost_rate: float = 0.5
var touch: float = 0.8
var instant: bool = false
var radius: float = 1.0
var blocked: int = 0
var _mi: MeshInstance3D


func _ready() -> void:
	add_to_group(&"ice_walls")
	collision_layer = 1 << 5
	collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(width, height, depth)
	cs.shape = sh
	cs.position.y = height * 0.5
	add_child(cs)
	_mi = WeaponFX.block(self, Vector3(width, height, depth), Vector3(0, height * 0.5, 0), Color("#cdeeff"), 0.55)
	for i: int in 5:
		var spike: MeshInstance3D = WeaponFX.block(self, Vector3(0.25, 0.5, 0.25), Vector3(lerpf(-width * 0.45, width * 0.45, i / 4.0), height + 0.15, 0), Color("#eaf8ff"), 0.7)
		spike.rotation.z = 0.785
	radius = maxf(width, height) * 0.5


func get_center() -> Vector3:
	return global_position + Vector3(0, height * 0.5, 0)


func is_alive() -> bool:
	return hp > 0.0 and life > 0.0


func take_damage(hit: Combat.Hit) -> bool:
	hp -= hit.amount
	if hp <= 0.0:
		_shatter()
		return true
	return false


func _local(p: Vector3) -> Vector3:
	return global_transform.affine_inverse() * p


func inside(p: Vector3, margin: float) -> bool:
	var l: Vector3 = _local(p)
	return absf(l.x) < width * 0.5 + margin and l.y > -margin and l.y < height + margin and absf(l.z) < depth * 0.5 + margin


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or weapon == null or not is_instance_valid(weapon):
		_shatter()
		return
	for n: Node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		var ep: Node3D = n as Node3D
		if ep == null or not is_instance_valid(ep):
			continue
		var p: Vector3 = ep.call("get_center") if ep.has_method("get_center") else ep.global_position
		if inside(p, 0.25):
			var dmg: float = float(ep.get("dmg")) if "dmg" in ep else (float(ep.get("damage")) if "damage" in ep else 10.0)
			BSProjectile.deny_projectile(ep)
			blocked += 1
			hp -= dmg
	for e: Node3D in Combat.in_radius(get_tree(), get_center(), radius + touch):
		if not inside(e.global_position + Vector3(0, 0.5, 0), float(e.get("radius")) + touch):
			continue
		if instant:
			weapon.call("freeze", e)
		else:
			weapon.call("add_frost", e, frost_rate * dt)
	if hp <= 0.0:
		_shatter()


func _shatter() -> void:
	if is_queued_for_deletion():
		return
	if get_parent() != null:
		WeaponFX.blast(get_parent(), get_center(), 1.6, Color("#cdeeff"))
	queue_free()
