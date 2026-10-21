extends ProjectileWeapon
## PATENT PENDING (BS_WEAPONS §8.6). firePatent (index.html:4684): a slow 0.55 orb at 8 m/s for 4.5 s that forks a
## 10-damage homing lawsuit (26 m/s, life 0.8) at the nearest enemy within 13 m (> 0.5 m) every 0.45 s
## (updateProjectiles 5393), then detonates: 70, splash 5 + 0.6 x dTier. The cooling fan pops off and bounces away
## after each detonation (5455). Ammo 4 (+2 per tier); mods locked until Blartz is rescued.
## Remake: every lawsuit stamps SERVED 3 s. Alt-fire FILE EARLY: hold to grow the sphere (up to 1.5 s: size x1.8,
## detonation x1.5), release to place it as a slow 2 m/s hazard that forks for 6 s, then detonates. 1 ammo.
## Legal Precedent: a Cease & Desist document passing through the sphere makes every fork bounce once more.
## V3: forks every 0.35 s. V5: the detonation leaves a PENDING zone (r4, 4 s, one lawsuit per second).
## Ω PATENT GRANTED: forks every 0.22 s, splash +2 m, lawsuits SERVE for 6 s, the cooling fan becomes a bouncing
## 20-damage saw. Signatures: provisional (14 m/s, splash -1 m), prior_art (each fork victim forks once more, 6 dmg).

var growing: bool = false
var grow_t: float = 0.0


func provisional() -> bool:
	return sig() == &"provisional"


func splash() -> float:
	var s: float = P("splash", 5.0) + P("splash_per_dmg_tier", 0.6) * mod_tier("dmg")
	if omega():
		s += P("splash_omega", 2.0)
	if provisional():
		s += P("provisional_splash", -1.0)
	return s


func fork_interval() -> float:
	if omega():
		return P("fork_interval_omega", 0.22)
	return P("fork_interval_v3", 0.35) if level() >= 3 else P("fork_interval", 0.45)


func fork_served() -> float:
	return P("fork_served_omega", 6.0) if omega() else P("fork_served", 3.0)


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	launch_sphere(1.0, 1.0, false)


func launch_sphere(size_mul: float, dmg_mul: float, hazard: bool) -> BSProjectile:
	var sp: float = P("hazard_speed", 2.0) if hazard else (P("provisional_speed", 14.0) if provisional() else P("speed", 8.0))
	var pr: BSProjectile = spawn_projectile(mgr.muzzle_pos(), fire_dir() * sp, {"gravity": 0.0,
		"life": P("hazard_life", 6.0) if hazard else P("life", 4.5), "size": P("size", 0.55) * tier_mul() * size_mul,
		"r": 0.55 * size_mul, "dmg": dmg(float(d.get("damage", 70))) * dmg_mul, "splash": splash() * (1.0 + (size_mul - 1.0) * 0.5),
		"patent": true, "fork_acc": 0.0, "hazard": hazard})
	pr.add_to_group(&"patent_orbs")
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.5 * tier_mul())
	WeaponFX.sparks(mgr.world(), mgr.muzzle_pos(), Color(0.85, 0.87, 0.92), 4, 0.4, mgr.rng)   # overworked cooling steam
	recoil(float(d.get("recoil", 0.03)))
	shake(0.2)
	fired.emit(id)
	mgr.weapon_fired.emit(id)
	return pr


## One lawsuit at the nearest enemy within fork range of `from`. Returns the projectile (null when nobody's near).
func fork(from: Vector3, exclude: Array = [], bounces: int = 0, amount: float = -1.0, prior: bool = true) -> BSProjectile:
	var tgt: Node3D = nearest_enemy(from, P("fork_range", 13.0), exclude, P("fork_min", 0.5))
	if tgt == null:
		return null
	var c: Vector3 = center_of(tgt)
	WeaponFX.lightning(mgr.world(), from, c, WeaponData.color(id), mgr.rng)
	var pr: BSProjectile = spawn_projectile(from, (c - from).normalized() * P("fork_speed", 26.0), {"gravity": 0.0, "life": P("fork_life", 0.8),
		"size": 0.12, "stretch": 2.4, "lawsuit": true, "dmg": dmg(P("fork_dmg", 10.0)) if amount < 0.0 else amount, "bounces": bounces,
		"prior": prior, "color": Color("#d2ff8a")})
	pr.homing_target = tgt
	for x: Variant in exclude:
		pr.hit_set.append(x)
	pr.homing_rate = P("fork_homing", 8.0)
	pr.homing_speed = P("fork_speed", 26.0)
	return pr


func on_projectile_tick(pr: BSProjectile, dt: float) -> void:
	if not bool(pr.data.get("patent", false)):
		return
	pr.data["fork_acc"] = float(pr.data["fork_acc"]) + dt
	var m: MeshInstance3D = pr.mesh()
	if m != null:
		m.rotation.y += dt * 3.0
	if float(pr.data["fork_acc"]) > fork_interval():
		pr.data["fork_acc"] = 0.0
		fork(pr.global_position, [], int(P("precedent_bounces", 1)) if bool(pr.data.get("precedent", false)) else 0)


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	if bool(pr.data.get("lawsuit", false)):
		deal(target, roundf(float(pr.data["dmg"])), point, pr.vel, {"served": fork_served()})
		if bool(pr.data.get("prior", false)) and sig() == &"prior_art":
			var last: float = float(target.get_meta(&"bs_prior_art", -99.0))
			if WeaponRules.now() - last > P("prior_art_cd", 2.0):
				target.set_meta(&"bs_prior_art", WeaponRules.now())
				fork(center_of(target), [target], 0, dmg(P("prior_art_dmg", 6.0)), false)
		var b: int = int(pr.data.get("bounces", 0))
		if b > 0:
			var nxt: Node3D = nearest_enemy(point, P("fork_range", 13.0), pr.hit_set)
			if nxt != null:
				pr.data["bounces"] = b - 1
				pr.homing_target = nxt
				pr.vel = (center_of(nxt) - point).normalized() * P("fork_speed", 26.0)
				pr.life = P("fork_life", 0.8)
				return true
		return false
	if bool(pr.data.get("patent", false)):
		detonate(pr, point)
	return false


func on_projectile_world(pr: BSProjectile, point: Vector3, normal: Vector3) -> bool:
	if bool(pr.data.get("patent", false)):
		detonate(pr, point + normal * 0.2)
	return false


func on_projectile_expire(pr: BSProjectile) -> void:
	if bool(pr.data.get("patent", false)):
		detonate(pr, pr.global_position)


func detonate(pr: BSProjectile, pos: Vector3) -> void:
	if bool(pr.data.get("done", false)):
		return
	pr.data["done"] = true
	explode(pos, float(pr.data.get("splash", 5.0)), float(pr.data.get("dmg", 70.0)))
	shake(0.3)
	var fan: PatentFan = PatentFan.new()
	fan.weapon = self
	fan.saw = omega()
	fan.amount = dmg(P("fan_saw_dmg", 20.0))
	fan.life = P("fan_life", 2.5)
	fan.vel = Vector3(mgr.rng.randf_range(-1, 1), 1.4, mgr.rng.randf_range(-1, 1)).normalized() * P("fan_speed", 7.0)
	mgr.world().add_child(fan)
	fan.global_position = pos + Vector3.UP * 0.3
	if omega():
		popup.emit("bs.weapon.fx.granted", pos)
	if level() >= 5:
		var z: PendingZone = PendingZone.new()
		z.weapon = self
		z.radius = P("zone_r", 4.0)
		z.life = P("zone_time", 4.0)
		z.interval = P("zone_fork_interval", 1.0)
		mgr.world().add_child(z)
		z.global_position = pos
		popup.emit("bs.weapon.fx.pending", pos + Vector3.UP)


# ---- FILE EARLY

func _on_alt_pressed() -> void:
	if cooldown > 0.0 or growing:
		return
	if not has_ammo(1):
		empty_feedback()
		return
	growing = true
	grow_t = 0.0


func _alt_held(dt: float) -> void:
	if growing:
		grow_t = minf(P("grow_time", 1.5), grow_t + dt)


func _on_alt_released() -> void:
	if not growing:
		return
	growing = false
	cooldown = interval()
	if not use_ammo(1):
		return
	var k: float = grow_t / maxf(0.01, P("grow_time", 1.5))
	launch_sphere(lerpf(1.0, P("grow_size", 1.8), k), lerpf(1.0, P("grow_dmg", 1.5), k), true)


func _on_cancel() -> void:
	growing = false


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["charge"] = grow_t / maxf(0.01, P("grow_time", 1.5)) if growing else -1.0
	return s
