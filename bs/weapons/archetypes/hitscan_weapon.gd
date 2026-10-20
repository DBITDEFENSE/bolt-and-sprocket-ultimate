class_name HitscanWeapon
extends BSWeapon
## Instant ray shots with a visible tracer. Params: range, falloff_start, falloff_end (default range), falloff_mul,
## pellets, cone_deg / spread_deg, pierce, status + status_time.


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	shoot(dmg(float(d.get("damage", 0))), int(P("pierce", 0)), {})
	recoil(float(d.get("recoil", 0.004)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func falloff(dist: float) -> float:
	var a: float = P("falloff_start", 9999.0)
	var b: float = P("falloff_end", P("range", 60.0))
	if dist <= a:
		return 1.0
	return lerpf(1.0, P("falloff_mul", 1.0), clampf((dist - a) / maxf(0.01, b - a), 0.0, 1.0))


func spread_dir(dir: Vector3, deg: float) -> Vector3:
	if deg <= 0.0:
		return dir
	var side: Vector3 = dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.99 else Vector3.RIGHT
	var up: Vector3 = side.cross(dir).normalized()
	var a: float = mgr.rng.randf() * TAU
	var r: float = sqrt(mgr.rng.randf()) * tan(deg_to_rad(deg))
	return (dir + (side * cos(a) + up * sin(a)) * r).normalized()


## One trigger pull (all pellets). Returns the enemies damaged.
func shoot(amount: float, pierce: int, status: Dictionary, tracer_col: Color = Color(0, 0, 0, 0), width: float = 0.05) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var from: Vector3 = origin()
	var base: Vector3 = aim()
	var pellets: int = int(P("pellets", 1))
	var spread: float = P("cone_deg", P("spread_deg", 0.0))
	var st: Dictionary = status.duplicate()
	if p.has("status") and not st.has(str(p["status"])):
		st[str(p["status"])] = P("status_time", 1.0)
	var col: Color = tracer_col if tracer_col.a > 0.0 else WeaponData.color(id)
	for i: int in pellets:
		var dir: Vector3 = spread_dir(base, spread) if pellets > 1 or spread > 0.0 else base
		var res: Dictionary = mgr.hitscan(from, dir, P("range", 60.0))
		var hits: Array = res["hits"]
		var end: Vector3 = res["end"]
		var n: int = 0
		for h: Array in hits:
			var e: Node3D = h[1]
			on_hitscan_hit(e, h[2], float(h[0]), amount * falloff(float(h[0])), dir, st, n)
			out.append(e)
			n += 1
			if n > pierce:
				end = h[2]
				break
		WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), end, col, width * WeaponData.visual_mul(mod_tier("dmg")), 0.07)
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), col, 0.18 * WeaponData.visual_mul(mod_tier("dmg")))
	return out


## Override for per-gun on-hit rules. `index` is 0 for the first target of this ray, 1 for the first pierced one...
func on_hitscan_hit(e: Node3D, point: Vector3, _dist: float, amount: float, dir: Vector3, status: Dictionary, _index: int) -> void:
	deal(e, roundf(amount), point, dir, status)
