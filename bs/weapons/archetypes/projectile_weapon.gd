class_name ProjectileWeapon
extends BSWeapon
## Shots that fly (spawnProjectile 4508). Params: speed, up, gravity, life, splash, homing + lock_range + lock_dot,
## pierce, status + status_time, size. Direct hit = damage (+status); splash > 0 = explodeAt on contact.


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	launch(dmg(float(d.get("damage", 0))), {})
	recoil(float(d.get("recoil", 0.008)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func launch(amount: float, extra: Dictionary) -> BSProjectile:
	var dir: Vector3 = fire_dir()
	var vel: Vector3 = dir * P("speed", 30.0) + Vector3.UP * P("up", 0.0)
	var tm: float = WeaponData.visual_mul(mod_tier("dmg"))
	var opts: Dictionary = {"gravity": P("gravity", 0.0), "life": P("life", 2.0), "size": P("size", 0.18) * tm,
		"dmg": amount, "splash": P("splash", 0.0), "pierce": int(P("pierce", 0))}
	opts.merge(extra, true)
	var pr: BSProjectile = spawn_projectile(mgr.muzzle_pos(), vel, opts)
	if P("homing", 0.0) > 0.0:
		pr.homing_target = lock_target(dir, P("lock_range", 26.0), P("lock_dot", 0.15))
		pr.homing_rate = P("homing", 0.0)
		pr.homing_speed = P("speed", 14.0)
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.22 * tm)
	return pr


## Nearest living enemy roughly in front (fireLawnDart 4644).
func lock_target(dir: Vector3, rng_m: float, min_dot: float) -> Node3D:
	var best: Node3D = null
	var bd: float = rng_m
	var from: Vector3 = mgr.bolt.global_position
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not bool(e.call("is_alive")):
			continue
		var to: Vector3 = (e.call("get_center") as Vector3) - from
		var dd: float = to.length()
		if dd < bd and to.normalized().dot(dir) > min_dot:
			bd = dd
			best = e
	return best


func _status() -> Dictionary:
	return {str(p["status"]): P("status_time", 1.0)} if p.has("status") else {}


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	var amount: float = float(pr.data.get("dmg", 0.0))
	if float(pr.data.get("splash", 0.0)) > 0.0:
		explode(point, float(pr.data["splash"]), amount, _status())
		return false
	deal(target, roundf(amount), point, pr.vel, _status())
	var left: int = int(pr.data.get("pierce", 0))
	if left > 0:
		pr.data["pierce"] = left - 1
		return true
	return false


func on_projectile_world(pr: BSProjectile, point: Vector3, _normal: Vector3) -> bool:
	if float(pr.data.get("splash", 0.0)) > 0.0:
		explode(point, float(pr.data["splash"]), float(pr.data.get("dmg", 0.0)), _status())
	else:
		WeaponFX.flash(mgr.world(), point, pr.color, 0.2)
	return false
