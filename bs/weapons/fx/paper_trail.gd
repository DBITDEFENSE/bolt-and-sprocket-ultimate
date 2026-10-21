class_name PaperTrail
extends Node3D
## Cease & Desist V5: a 1 s line of paperwork between two defendants. Anything walking through it is SERVED.

var weapon: BSWeapon
var a: Vector3 = Vector3.ZERO
var b: Vector3 = Vector3.ZERO
var life: float = 1.0
var width: float = 0.7
var secs: float = 6.0
var _served: Array = []


func _ready() -> void:
	top_level = true
	WeaponFX.tracer(get_parent(), a, b, Color("#f2f0e0"), 0.12, life)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0 or weapon == null or not is_instance_valid(weapon):
		queue_free()
		return
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or _served.has(e) or not BSWeapon.alive(e):
			continue
		var c: Vector3 = BSWeapon.center_of(e)
		if Geometry3D.get_closest_point_to_segment(c, a, b).distance_to(c) < width + float(e.get("radius")):
			_served.append(e)
			e.set_meta(&"bs_served_mult", float(weapon.call("served_mult")))
			var h: Combat.Hit = weapon.make_hit(0.0, c)
			h.status = weapon.call("stamp_status", secs)
			weapon.mgr.deal_damage(e, h)
