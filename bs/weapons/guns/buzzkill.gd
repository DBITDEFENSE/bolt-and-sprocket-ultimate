extends ProjectileWeapon
## BUZZKILL (BS_WEAPONS §8.8). fireBuzzkill (index.html:5617): a saw blade at 34 m/s (r0.4, life 2.2) every 0.24 s,
## 14 to every enemy it passes through (once each per pass, 5494), bouncing off geometry 3 times (updateProjectiles
## 5420). The remake reflects off the hit normal and clears the per-pass hit list on each bounce. Ammo 20 (+8).
## Plate shred: blades deal 50% THROUGH plating (Hit meta "plate_pierce"), and every 4 blade hits on a plated
## enemy pop one plate (target.pop_plate(), when it has one); 2 hits on MARKED DOWN 5+ targets.
## Alt-fire MANUAL OVERRIDE: hold to steer the newest blade with the camera for up to 1.5 s, at 22 m/s.
## V3: blades split on the first bounce (+-0.6 rad; the twin deals 70%, 2 bounces, life 1.5). V5: plates pop every
## 2 hits; split blades keep 100%. Ω MOOD KILLER: 5 bounces, and each split blade splits once more (4 blades).
## Signatures: hedge_trimmer (blades orbit Bolt at 1.5 m for 1.2 s first), bank_shot (+25% per bounce).

var last_blade: BSProjectile = null
var steer_t: float = 0.0


func bounces() -> int:
	return int(P("bounces_omega", 5)) if omega() else int(P("bounces", 3))


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	var dir: Vector3 = fire_dir()
	var orbit: bool = sig() == &"hedge_trimmer"
	last_blade = blade(mgr.muzzle_pos(), dir * P("speed", 34.0), dmg(float(d.get("damage", 14))), bounces(),
		level() >= 3 or omega(), omega(), P("life", 2.2))
	steer_t = 0.0
	if orbit:
		last_blade.data["orbit_t"] = P("orbit_time", 1.2)
		last_blade.data["orbit_a"] = atan2(dir.z, dir.x)
		last_blade.data["orbit_reset"] = 0.0
		last_blade.vel = Vector3.ZERO
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.2 * tier_mul())
	recoil(float(d.get("recoil", 0.004)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func blade(pos: Vector3, vel: Vector3, amount: float, n_bounces: int, split: bool, resplit: bool, life: float) -> BSProjectile:
	return spawn_projectile(pos, vel, {"gravity": 0.0, "life": life, "size": P("size", 0.28) * tier_mul(), "r": P("r", 0.4),
		"shape": "disc", "dmg": amount, "bounces": n_bounces, "split": split, "resplit": resplit, "bounced": 0, "saw": true})


func on_projectile_tick(pr: BSProjectile, dt: float) -> void:
	var m: MeshInstance3D = pr.mesh()
	if m != null:
		m.rotation.y += dt * 40.0
	var ot: float = float(pr.data.get("orbit_t", 0.0))
	if ot > 0.0 and mgr.bolt != null:
		ot -= dt
		pr.data["orbit_t"] = ot
		var a: float = float(pr.data["orbit_a"]) + P("orbit_rate", 9.0) * dt
		pr.data["orbit_a"] = a
		var c: Vector3 = mgr.bolt.global_position + Vector3(0, P("orbit_h", 0.2), 0)
		var want: Vector3 = c + Vector3(cos(a), 0, sin(a)) * P("orbit_r", 1.5)
		pr.vel = (want - pr.global_position) / maxf(dt, 0.001)
		pr.life = maxf(pr.life, P("life", 2.2))
		pr.data["orbit_reset"] = float(pr.data["orbit_reset"]) + dt
		if float(pr.data["orbit_reset"]) > 0.4:      # a fresh pass every 0.4 s: it shreds swarms, not just once
			pr.data["orbit_reset"] = 0.0
			pr.hit_set.clear()
		if ot <= 0.0:
			pr.vel = fire_dir() * P("speed", 34.0)
			pr.global_position = mgr.muzzle_pos()
			pr.hit_set.clear()
		return
	if pr == last_blade and alt_held and steer_t < P("steer_time", 1.5):
		steer_t += dt
		pr.vel = aim() * P("steer_speed", 22.0)


func blade_damage(pr: BSProjectile) -> float:
	var a: float = float(pr.data.get("dmg", 14.0))
	if sig() == &"bank_shot":
		a *= 1.0 + P("bank_per_bounce", 0.25) * int(pr.data.get("bounced", 0))
	return a


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	var h: Combat.Hit = make_hit(roundf(blade_damage(pr)), point, pr.vel)
	h.set_meta(&"plate_pierce", P("plate_pierce", 0.5))
	mgr.deal_damage(target, h)
	WeaponFX.sparks(mgr.world(), point, WeaponData.color(id), 3, 0.3, mgr.rng)
	_shred(target, point)
	return true     # saws pass through


## Every N blade hits on a plated enemy pop one plate.
func _shred(target: Node3D, point: Vector3) -> void:
	if not alive(target) or not target.has_method("pop_plate"):
		return
	if "plates" in target and int(target.get("plates")) <= 0:
		return
	var need: int = int(P("plate_hits", 4))
	if level() >= 5:
		need = int(P("plate_hits_v5", 2))
	if WeaponRules.markdown_stacks(target) >= int(P("markdown_stacks", 5)):
		need = mini(need, int(P("plate_hits_markdown", 2)))
	var n: int = int(target.get_meta(&"bs_buzz_hits", 0)) + 1
	if n >= need:
		n = 0
		target.call("pop_plate")
		popup.emit("bs.weapon.fx.plate", point)
	target.set_meta(&"bs_buzz_hits", n)


func on_projectile_world(pr: BSProjectile, point: Vector3, normal: Vector3) -> bool:
	var left: int = int(pr.data.get("bounces", 0))
	WeaponFX.sparks(mgr.world(), point, Color("#ffe08a"), 4, 0.35, mgr.rng)
	if left <= 0:
		return false
	pr.data["bounces"] = left - 1
	pr.data["bounced"] = int(pr.data.get("bounced", 0)) + 1
	pr.vel = pr.vel.bounce(normal)
	pr.global_position = point + normal * 0.08
	pr.hit_set.clear()
	if bool(pr.data.get("split", false)):
		pr.data["split"] = false
		var keep: bool = level() >= 5
		var a: float = P("split_angle", 0.6)
		var twin: BSProjectile = blade(pr.global_position, pr.vel.rotated(Vector3.UP, a), float(pr.data["dmg"]) * (1.0 if keep else P("split_mul", 0.7)),
			int(P("split_bounces", 2)), bool(pr.data.get("resplit", false)), false, P("split_life", 1.5))
		twin.data["bounced"] = pr.data["bounced"]
		pr.vel = pr.vel.rotated(Vector3.UP, -a)
		# Ω: the parent splits once more on its next bounce and the twin on its first: 4 blades per shot
		pr.data["split"] = bool(pr.data.get("resplit", false))
		pr.data["resplit"] = false
	return true


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["steering"] = alt_held and last_blade != null and is_instance_valid(last_blade) and not last_blade.dead and steer_t < P("steer_time", 1.5)
	return s
