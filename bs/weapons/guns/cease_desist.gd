extends ProjectileWeapon
## CEASE & DESIST (BS_WEAPONS §8.7). fireCease (index.html:4711): a legal document at 30 m/s (life 2.4) for 24 that
## stamps SERVED (6 s, +40% damage taken from everything) and ricochets to the nearest un-hit enemy within 16 m,
## 2 + dTier times (updateProjectiles 5528; the remake moves the extra ricochets to V3/V5). Ammo 6 (+3 per tier).
## SERVED itself is applied by EnemyBase (x1.4); variants are stamped as meta "bs_served_mult" (WeaponRules).
## Alt-fire CLASS ACTION: one heavy notice, 60 to the target, everything within 6 m SERVED 8 s; no ricochet;
## 2 ammo, 1.5 s cooldown. Hostile Work Environment: documents can hit your own subsidiaries (no damage; they get
## SERVED: +40% damage, +4 s contract). Legal Precedent: passing through a Patent Pending sphere marks it.
## V3: +1 ricochet, range 20 m. V5: +1 ricochet (4); each hop leaves a 1 s paper trail that SERVES walkers.
## Ω INJUNCTION: 6 ricochets, life 3.4, SERVED = +70%, and every stamp blocks abilities for 2 s (status "silenced").
## Signatures: cease (SERVED 10 s), desist (SERVED also SLOWED, but +30%).

var class_cd: float = 0.0


func ricochets() -> int:
	if omega():
		return int(P("ricochets_omega", 6))
	if level() >= 5:
		return int(P("ricochets_v5", 4))
	return int(P("ricochets_v3", 3)) if level() >= 3 else int(P("ricochets", 2))


func rico_range() -> float:
	return P("ricochet_range_v3", 20.0) if level() >= 3 else P("ricochet_range", 16.0)


func served_time() -> float:
	return P("cease_time", 10.0) if sig() == &"cease" else P("served_time", 6.0)


func served_mult() -> float:
	if omega():
		return P("served_mult_omega", 1.7)
	return P("desist_mult", 1.3) if sig() == &"desist" else P("served_mult", 1.4)


## The statuses one stamp applies (SERVED, + silenced at Ω, + SLOWED with Desist).
func stamp_status(secs: float) -> Dictionary:
	var st: Dictionary = {"served": secs}
	if omega():
		st["silenced"] = P("silence_time", 2.0)
	if sig() == &"desist":
		st["slowed"] = P("desist_slow", 3.0)
	return st


func stamp(target: Node3D) -> void:
	target.set_meta(&"bs_served_mult", served_mult())
	popup.emit("bs.weapon.fx.injunction" if omega() else "bs.weapon.fx.served", center_of(target))


func _tick(dt: float, _is_equipped: bool) -> void:
	class_cd = maxf(0.0, class_cd - dt)


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	spawn_projectile(mgr.muzzle_pos(), fire_dir() * P("speed", 30.0), {"gravity": 0.0, "life": P("life_omega", 3.4) if omega() else P("life", 2.4),
		"size": P("size", 0.2) * tier_mul(), "stretch": P("stretch", 1.6), "shape": "card", "dmg": dmg(float(d.get("damage", 24))),
		"rico": ricochets(), "cease": true, "last": Vector3.INF})
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.22 * tier_mul())
	recoil(float(d.get("recoil", 0.005)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func on_projectile_tick(pr: BSProjectile, dt: float) -> void:
	# Legal Precedent: the document copies itself onto any Patent Pending sphere it passes through
	for n: Node in get_tree().get_nodes_in_group(&"patent_orbs"):
		var orb: BSProjectile = n as BSProjectile
		if orb != null and not orb.dead and orb.global_position.distance_to(pr.global_position) < orb.radius + 0.4:
			orb.data["precedent"] = true
	# Hostile Work Environment: your subsidiaries (out of the "enemies" group while acquired) can be served too
	for s: Node in get_tree().get_nodes_in_group(&"subsidiaries"):
		var sub: Node3D = s as Node3D
		if sub != null and not pr.hit_set.has(sub) and alive(sub) and center_of(sub).distance_to(pr.global_position) < float(sub.get("radius")) + pr.radius:
			pr.hit_set.append(sub)
			_serve_subsidiary(sub)
	var m: MeshInstance3D = pr.mesh()
	if m != null:
		m.rotation.z += dt * 12.0


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	if bool(pr.data.get("class", false)):
		class_action(point, target, float(pr.data["dmg"]))
		return false
	if target.has_meta(&"bs_subsidiary"):
		_serve_subsidiary(target)
	else:
		stamp(target)
		deal(target, roundf(float(pr.data["dmg"])), point, pr.vel, stamp_status(served_time()))
	var last: Vector3 = pr.data.get("last", Vector3.INF)
	if level() >= 5 and last != Vector3.INF:
		_trail(last, point)
	pr.data["last"] = point
	var left: int = int(pr.data.get("rico", 0))
	if left > 0:
		var nxt: Node3D = _next_defendant(point, pr.hit_set)
		if nxt != null:
			pr.data["rico"] = left - 1
			var c: Vector3 = center_of(nxt)
			pr.vel = (c - point).normalized() * P("speed", 30.0)
			WeaponFX.lightning(mgr.world(), point, c, WeaponData.color(id), mgr.rng)
			return true
	return false


## The nearest un-hit enemy within ricochet range, preferring ones not yet SERVED.
func _next_defendant(from: Vector3, done: Array) -> Node3D:
	var best: Node3D = null
	var bd: float = INF
	for e: Node3D in enemies(done):
		var dd: float = center_of(e).distance_to(from)
		if dd > rico_range():
			continue
		if mgr.has_status(e, &"served"):
			dd += 1000.0
		if dd < bd:
			bd = dd
			best = e
	return best


func _serve_subsidiary(target: Node3D) -> void:
	mgr.apply_status(target, &"served", served_time())
	var ht: BSWeapon = mgr.weapons.get(&"hostile_takeover", null) as BSWeapon
	if ht != null and ht.has_method("served_subsidiary"):
		ht.call("served_subsidiary", target, P("subsidiary_bonus", 4.0), P("subsidiary_dmg", 1.4))
	popup.emit("bs.weapon.fx.served", center_of(target))


func _trail(a: Vector3, b: Vector3) -> void:
	var t: PaperTrail = PaperTrail.new()
	t.weapon = self
	t.a = a
	t.b = b
	t.life = P("trail_life", 1.0)
	t.width = P("trail_width", 0.7)
	t.secs = served_time()
	mgr.world().add_child(t)


func on_projectile_world(pr: BSProjectile, point: Vector3, normal: Vector3) -> bool:
	if bool(pr.data.get("class", false)):
		class_action(point + normal * 0.2, null, 0.0)
		return false
	WeaponFX.sparks(mgr.world(), point, WeaponData.color(id), 5, 0.4, mgr.rng)   # a flurry of documents
	return false


# ---- CLASS ACTION

func _on_alt_pressed() -> void:
	if class_cd > 0.0:
		WeaponText.hint("bs.weapon.hint.class_cd", "classcd")
		return
	var cost: int = int(P("class_ammo", 2))
	if not has_ammo(cost):
		empty_feedback()
		return
	use_ammo(cost)
	class_cd = P("class_cooldown", 1.5)
	spawn_projectile(mgr.muzzle_pos(), fire_dir() * P("speed", 30.0), {"gravity": 0.0, "life": P("life", 2.4), "size": P("class_size", 0.34) * tier_mul(),
		"stretch": 1.3, "shape": "card", "dmg": dmg(P("class_dmg", 60.0)), "class": true, "color": Color("#fff6c8")})
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.4 * tier_mul())
	recoil(float(d.get("recoil", 0.005)) * 4.0)
	shake(0.15)
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func class_action(pos: Vector3, target: Node3D, amount: float) -> void:
	var secs: float = P("class_served", 8.0)
	if target != null and alive(target) and not target.has_meta(&"bs_subsidiary"):
		stamp(target)
		deal(target, roundf(amount), pos, Vector3.ZERO, stamp_status(secs))
	for e: Node3D in Combat.in_radius(get_tree(), pos, P("class_radius", 6.0)):
		if e == target:
			continue
		e.set_meta(&"bs_served_mult", served_mult())
		var h: Combat.Hit = make_hit(0.0, center_of(e))
		h.status = stamp_status(secs)
		mgr.deal_damage(e, h)
	WeaponFX.ring(mgr.world(), pos, P("class_radius", 6.0), WeaponData.color(id), 0.45)
	WeaponFX.blast(mgr.world(), pos, 1.6, WeaponData.color(id))
	popup.emit("bs.weapon.fx.class_action", pos)
	shake(0.25)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["alt_cd"] = class_cd
	return s
