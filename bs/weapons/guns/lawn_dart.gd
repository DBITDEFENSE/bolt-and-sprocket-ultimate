extends ProjectileWeapon
## LAWN DART (BS_WEAPONS §8.5). fireLawnDart (index.html:4637): locks the nearest enemy roughly in front (26 m,
## dot > 0.15), a slow homing dart (14 m/s, turn 2.2, life 6) that STICKS into the target and detonates after a
## beeping 1.0 s fuse: 55, splash 3 + 0.5 x dTier. A weak-point hit is a BULLSEYE: no fuse, x1.35 (updateProjectiles
## 5347 / 5507). Terrain hits detonate. Ammo 5 (+3 per tier).
## Remake: MARKED weak points are locked first and always bullseye (Read The Room); ROOTED targets are always a
## bullseye (Weed Whacker); detonations on SERVED targets are 50% wider.
## Alt-fire PAINT: hold and sweep the reticle across up to 3 targets (0.35 s each), then fire a volley: one dart per
## painted target at 75%, 1 ammo each.
## V3: fuse 0.7 s. V5: a dart whose target dies re-locks the nearest enemy within 12 m.
## Ω DOUBLE FAULT: two darts per trigger on different targets, both at full damage; Paint fires two per target.
## Signatures: lawn_ordinance (darts in SERVED / rooted targets split into 3 bomblets of 15, r1.5),
## express_delivery (22 m/s, turn 3.5, never sticks: always detonates on impact, no bullseye).

var painted: Array[Node3D] = []
var paint_cand: Node3D = null
var paint_t: float = 0.0
var paint_idle: float = 0.0


func express() -> bool:
	return sig() == &"express_delivery"


func fuse_time() -> float:
	return P("fuse_v3", 0.7) if level() >= 3 else P("fuse", 1.0)


func splash() -> float:
	return P("splash", 3.0) + P("splash_per_dmg_tier", 0.5) * mod_tier("dmg")


func dart_speed() -> float:
	return P("express_speed", 22.0) if express() else P("speed", 14.0)


## Read The Room: marked targets first, then the nearest enemy roughly in front.
func pick_lock(dir: Vector3, exclude: Array, min_dot: float) -> Node3D:
	var from: Vector3 = mgr.bolt.global_position
	var best: Node3D = null
	var bd: float = P("lock_range", 26.0)
	var marked_best: Node3D = null
	var md: float = P("lock_range", 26.0)
	for e: Node3D in enemies(exclude):
		var to: Vector3 = center_of(e) - from
		var dd: float = to.length()
		if dd >= P("lock_range", 26.0) or to.normalized().dot(dir) <= min_dot:
			continue
		if mgr.has_status(e, &"marked") and dd < md:
			md = dd
			marked_best = e
		if dd < bd:
			bd = dd
			best = e
	return marked_best if marked_best != null else best


func _fire() -> void:
	cooldown = interval()
	_prune_paint()
	if not painted.is_empty():
		_volley()
		return
	if not use_ammo(1):
		return
	var dir: Vector3 = fire_dir()
	var t1: Node3D = pick_lock(dir, [], P("lock_dot", 0.15))
	spawn_dart(dir, t1, dmg(float(d.get("damage", 55))), 0.0)
	if omega():
		var t2: Node3D = pick_lock(dir, [t1] if t1 != null else [], P("omega_second_dot", 0.0))
		spawn_dart(dir.rotated(Vector3.UP, P("omega_angle", 0.35)), t2 if t2 != null else t1, dmg(float(d.get("damage", 55))), P("omega_up", 2.0))
	_fire_fx()


func _fire_fx() -> void:
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.28 * tier_mul())
	WeaponFX.sparks(mgr.world(), mgr.muzzle_pos(), Color(0.75, 0.75, 0.78), 4, 0.3, mgr.rng)   # launch smoke
	recoil(float(d.get("recoil", 0.014)))
	shake(0.06)
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func spawn_dart(dir: Vector3, target: Node3D, amount: float, up: float) -> BSProjectile:
	var sp: float = dart_speed()
	var pr: BSProjectile = spawn_projectile(mgr.muzzle_pos(), dir * sp + Vector3.UP * up, {"gravity": 0.0, "life": P("life", 6.0),
		"size": P("size", 0.22) * tier_mul(), "stretch": P("stretch", 2.2), "dmg": amount, "splash": splash(), "dart": true, "shape": "dart",
		"had_target": target != null})
	pr.homing_target = target
	pr.homing_rate = P("express_homing", 3.5) if express() else P("homing", 2.2)
	pr.homing_speed = sp
	return pr


## PAINT volley: one dart per painted target at 75% (two each at Ω), 1 ammo per dart.
func _volley() -> void:
	var n: int = 0
	var base: Vector3 = fire_dir()
	for e: Node3D in painted:
		if not alive(e):
			continue
		for k: int in (2 if omega() else 1):
			if not use_ammo(1):
				break
			var spread: float = P("volley_spread", 0.25) * (float(n) - float(painted.size() - 1) * 0.5)
			spawn_dart(base.rotated(Vector3.UP, spread + 0.3 * k), e, dmg(float(d.get("damage", 55))) * P("paint_mul", 0.75), 1.0 + k)
			n += 1
	painted.clear()
	paint_cand = null
	if n > 0:
		_fire_fx()


func _prune_paint() -> void:
	var keep: Array[Node3D] = []
	for e: Node3D in painted:
		if alive(e):
			keep.append(e)
	painted = keep


func _alt_held(dt: float) -> void:
	paint_idle = 0.0
	if painted.size() >= int(P("paint_max", 3)):
		return
	var e: Node3D = aimed_enemy(P("lock_range", 26.0), P("paint_dot", 0.97))
	if e == null or painted.has(e):
		paint_cand = null
		paint_t = 0.0
		return
	if e != paint_cand:
		paint_cand = e
		paint_t = 0.0
	paint_t += dt
	if paint_t >= P("paint_dwell", 0.35):
		painted.append(e)
		paint_cand = null
		paint_t = 0.0
		popup.emit("bs.weapon.fx.painted", center_of(e))


func _tick(dt: float, _is_equipped: bool) -> void:
	if not alt_held:
		paint_idle += dt
		if paint_idle > P("paint_hold", 4.0) and not painted.is_empty():
			painted.clear()


func _on_holster() -> void:
	painted.clear()
	paint_cand = null


# ------------------------------------------------------------------ flight, stick, fuse

func on_projectile_tick(pr: BSProjectile, dt: float) -> void:
	if bool(pr.data.get("bomblet", false)):
		return
	var stuck: Node3D = pr.data.get("stuck", null) as Node3D
	if pr.data.has("stuck"):
		if stuck != null and alive(stuck):
			pr.global_position = center_of(stuck)
		pr.vel = Vector3.ZERO
		pr.data["fuse"] = float(pr.data["fuse"]) - dt
		var m: MeshInstance3D = pr.mesh()
		if m != null:
			m.scale = m.scale.lerp(Vector3.ONE * 1.6, dt * 1.5)
		if float(pr.data["fuse"]) <= 0.0:
			detonate(pr, pr.global_position, stuck, false)
			pr.kill()
		return
	# V5: re-acquire when the mark dies mid-flight
	if level() >= 5 and bool(pr.data.get("had_target", false)) and not alive(pr.homing_target):
		pr.homing_target = nearest_enemy(pr.global_position, P("relock_range", 12.0))


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	if bool(pr.data.get("bomblet", false)):
		explode(point, float(pr.data["splash"]), float(pr.data["dmg"]))
		return false
	if pr.data.has("stuck"):
		return true
	var bull: bool = false
	if not express():
		bull = mgr.has_status(target, &"rooted") or mgr.has_status(target, &"marked") \
			or (target.has_method("is_weak_point") and bool(target.call("is_weak_point", point)))
	if express() or bull:
		detonate(pr, center_of(target) if bull else point, target, bull)
		return false
	pr.data["stuck"] = target
	pr.data["fuse"] = fuse_time()
	pr.life = 99.0
	pr.homing_target = null
	pr.vel = Vector3.ZERO
	WeaponFX.sparks(mgr.world(), point, Color(0.9, 0.9, 0.9), 3, 0.2, mgr.rng)
	return true


func on_projectile_world(pr: BSProjectile, point: Vector3, normal: Vector3) -> bool:
	if bool(pr.data.get("bomblet", false)):
		explode(point + normal * 0.1, float(pr.data["splash"]), float(pr.data["dmg"]))
		return false
	if pr.data.has("stuck"):
		return true
	detonate(pr, point + normal * 0.1, null, false)
	return false


func on_projectile_expire(pr: BSProjectile) -> void:
	if bool(pr.data.get("bomblet", false)):
		explode(pr.global_position, float(pr.data["splash"]), float(pr.data["dmg"]))
		return
	detonate(pr, pr.global_position, pr.data.get("stuck", null) as Node3D, false)


func detonate(pr: BSProjectile, pos: Vector3, target: Node3D, bull: bool) -> void:
	if bool(pr.data.get("done", false)):
		return
	pr.data["done"] = true
	var amount: float = float(pr.data.get("dmg", 55.0)) * (P("bullseye_mul", 1.35) if bull else 1.0)
	var r: float = float(pr.data.get("splash", 3.0))
	var served: bool = target != null and alive(target) and mgr.has_status(target, &"served")
	var rooted: bool = target != null and alive(target) and mgr.has_status(target, &"rooted")
	if served:
		r *= P("served_splash_mul", 1.5)
	if bull:
		popup.emit("bs.weapon.fx.bullseye", pos)
	explode(pos, r, amount)
	if sig() == &"lawn_ordinance" and (served or rooted):
		for i: int in int(P("bomblets", 3)):
			var a: float = TAU * float(i) / P("bomblets", 3.0)
			var b: BSProjectile = spawn_projectile(pos + Vector3.UP * 0.3, Vector3(cos(a) * P("bomblet_speed", 4.0), P("bomblet_up", 5.0), sin(a) * P("bomblet_speed", 4.0)), {"gravity": 16.0,
				"life": P("bomblet_life", 0.6), "size": 0.1, "dmg": dmg(P("bomblet_dmg", 15.0)), "splash": P("bomblet_r", 1.5), "bomblet": true})
			b.hit_set.append(target)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["painted"] = painted.size()
	s["paint_max"] = int(P("paint_max", 3))
	s["paint_progress"] = clampf(paint_t / maxf(0.01, P("paint_dwell", 0.35)), 0.0, 1.0) if paint_cand != null else 0.0
	return s
