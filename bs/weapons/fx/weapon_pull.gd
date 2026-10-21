class_name WeaponPull
extends Node
## Drags one target to `dest` at `speed` m/s (Late Fee COLLECTIONS): EnemyBase via override_point, anything else by
## moving it directly. Calls on_arrive when it gets there (or after max_time), then frees itself.

var target: Node3D
var dest: Vector3 = Vector3.ZERO
var speed: float = 30.0
var max_time: float = 0.8
var on_arrive: Callable


func _physics_process(dt: float) -> void:
	max_time -= dt
	if target == null or not is_instance_valid(target) or not BSWeapon.alive(target):
		queue_free()
		return
	var to: Vector3 = dest - target.global_position
	var step: float = speed * dt
	if to.length() <= step or max_time <= 0.0:
		if "override_point" in target:
			target.set("override_point", dest)
		else:
			target.global_position = dest
		if on_arrive.is_valid():
			on_arrive.call()
		queue_free()
		return
	var nxt: Vector3 = target.global_position + to.normalized() * step
	if "override_point" in target:
		target.set("override_point", nxt)
	else:
		target.global_position = nxt
