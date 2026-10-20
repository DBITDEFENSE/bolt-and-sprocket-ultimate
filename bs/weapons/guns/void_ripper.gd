extends ChargedWeapon
## VOID RIPPER (BS_WEAPONS §8.2). releaseRipper (index.html:4729): hold to charge (full after 0.87 s), release an
## implosion orb: 30 + 35 x charge damage, splash 3.5 + 2 x charge, speed 20 + 6 x charge, gravity 4, life 3.
## On impact it sucks non-armoured enemies in (implodeAt: r + 2, 9 m/s) then blasts (explodeAt falloff).
## In flight it drags bolt pickups within 4.5 m. Ammo 12 (+6 per tier).
## Alt-fire RIFT: a 3 s tear at the aim point (<= 15 m) pulling non-heavy enemies within 5 m at 6 m/s (status
## gravity_clumped), 2 ammo, 6 s cooldown; an orb that detonates inside a Rift gets +50% splash (RIFT COLLAPSE).
## V3: charge 0.65 s, drag 8 m. V5: a full orb pierces the first enemy and implodes on the second (or terrain).
## Ω SECOND OPINION: charge > 50% -> 0.4 s re-collapse then a 0.22 s blast at splash + 1.5 for 70% (AFTERSHOCK).
## Signatures: pocket_universe (Rift 5 s, 7 m, 4 m/s), quick_collapse (tap = instant 50% orb +20%, hold caps 75%).

var rift_cd: float = 0.0


func charge_time() -> float:
	return P("charge_time_v3", 0.65) if level() >= 3 else P("charge_time", 0.87)


func charge_cap() -> float:
	return P("quick_cap", 0.75) if sig() == &"quick_collapse" else 1.0


func _tick(dt: float, is_equipped: bool) -> void:
	super._tick(dt, is_equipped)
	rift_cd = maxf(0.0, rift_cd - dt)


func release(c: float, held: float) -> void:
	var mul: float = 1.0
	if sig() == &"quick_collapse" and held < P("quick_tap", 0.15):
		c = P("quick_charge", 0.5)
		mul = P("quick_dmg_mul", 1.2)
	cooldown = interval()
	if not use_ammo(1):
		return
	var tm: float = WeaponData.visual_mul(mod_tier("dmg"))
	var dir: Vector3 = aim()
	var pr: BSProjectile = spawn_projectile(mgr.muzzle_pos(), dir * (P("speed", 20.0) + P("speed_per_charge", 6.0) * c), {
		"gravity": P("gravity", 4.0), "life": P("life", 3.0), "size": (0.32 + c * 0.26) * tm * 0.6,
		"dmg": dmg(float(d.get("damage", 30)) + P("dmg_per_charge", 35.0) * c) * mul,
		"splash": P("splash", 3.5) + P("splash_per_charge", 2.0) * c, "charge": c, "full": c >= 0.999})
	pr.radius = maxf(pr.radius, 0.3)
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), (0.35 + c * 0.25) * tm)
	recoil(float(d.get("recoil", 0.015)) + P("recoil_per_charge", 0.02) * c)
	if mgr.bolt != null and mgr.bolt.camera != null:
		mgr.bolt.camera.shake(0.15 + c * 0.15)
	fired.emit(id)
	mgr.weapon_fired.emit(id)


## The orb warps space: nearby bolt pickups get dragged along (5398).
func on_projectile_tick(pr: BSProjectile, dt: float) -> void:
	var r: float = P("drag_radius_v3", 8.0) if level() >= 3 else P("drag_radius", 4.5)
	var k: float = 1.0 - exp(-P("drag_rate", 3.5) * dt)
	for n: Node in get_tree().get_nodes_in_group(&"pickups"):
		var pk: Node3D = n as Node3D
		if pk == null or pk is AmmoOrb:
			continue
		if pk.global_position.distance_to(pr.global_position) < r:
			pk.global_position = pk.global_position.lerp(pr.global_position, k)


func on_projectile_hit(pr: BSProjectile, target: Node3D, point: Vector3) -> bool:
	if level() >= 5 and bool(pr.data.get("full", false)) and not bool(pr.data.get("pierced", false)):
		pr.data["pierced"] = true
		deal(target, roundf(float(pr.data["dmg"])), point, pr.vel)
		return true
	detonate(point, pr.data)
	return false


func on_projectile_world(pr: BSProjectile, point: Vector3, normal: Vector3) -> bool:
	detonate(point + normal * 0.1, pr.data)
	return false


func detonate(pos: Vector3, data: Dictionary) -> void:
	var splash: float = float(data.get("splash", 3.5))
	var amount: float = float(data.get("dmg", 30.0))
	for n: Node in get_tree().get_nodes_in_group(&"void_rifts"):
		var rift: VoidRift = n as VoidRift
		if rift != null and rift.global_position.distance_to(pos) < rift.radius:
			splash *= P("rift_splash_mul", 1.5)
			popup.emit("bs.weapon.fx.rift_collapse", pos)
			break
	implode(pos, splash)
	explode(pos, splash, amount)
	if omega() and float(data.get("charge", 0.0)) > P("aftershock_min_charge", 0.5):
		var sp: float = splash + P("aftershock_extra_r", 1.5)
		var dm: float = amount * P("aftershock_mul", 0.7)
		get_tree().create_timer(P("aftershock_delay", 0.4), false, true).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			implode(pos, sp)
			get_tree().create_timer(P("aftershock_blast_delay", 0.22), false, true).timeout.connect(func() -> void:
				if not is_instance_valid(self):
					return
				explode(pos, sp, dm)
				popup.emit("bs.weapon.fx.aftershock", pos)))


## implodeAt (5212): non-armoured enemies within r + 2 get a 9 m/s shove toward the centre.
func implode(pos: Vector3, r: float) -> void:
	for e: Node3D in Combat.in_radius(get_tree(), pos, r + P("implode_extra_r", 2.0)):
		if e.is_in_group(&"bosses") or WeaponData.prop_bool(e, "heavy") or WeaponData.prop_bool(e, "armored"):
			continue
		var to: Vector3 = pos - e.global_position
		to.y = 0.0
		if to.length_squared() < 0.0001:
			continue
		var kv: Vector3 = to.normalized() * P("implode_knock", 9.0)
		if e.has_method("apply_knock"):
			e.call("apply_knock", kv)
		elif "knock_vel" in e:
			e.set("knock_vel", (e.get("knock_vel") as Vector3) + kv)
	WeaponFX.ring(mgr.world(), pos, r * 1.6, Color("#c07dff"), 0.22)


func _on_alt_pressed() -> void:
	if rift_cd > 0.0:
		WeaponText.hint("bs.weapon.hint.rift_cd", "riftcd")
		return
	var cost: int = int(P("rift_ammo", 2))
	if not has_ammo(cost):
		empty_feedback()
		return
	var from: Vector3 = origin()
	var to: Vector3 = from + aim() * P("rift_range", 15.0)
	var hit: Dictionary = mgr.ray_world(from, to)
	var at: Vector3 = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.6 if not hit.is_empty() else to
	use_ammo(cost)
	rift_cd = P("rift_cooldown", 6.0)
	var pocket: bool = sig() == &"pocket_universe"
	var rift: VoidRift = VoidRift.new()
	rift.weapon = self
	rift.life = P("pocket_time", 5.0) if pocket else P("rift_time", 3.0)
	rift.radius = P("pocket_radius", 7.0) if pocket else P("rift_radius", 5.0)
	rift.pull = P("pocket_pull", 4.0) if pocket else P("rift_pull", 6.0)
	rift.refresh = P("clump_refresh", 0.4)
	mgr.world().add_child(rift)
	rift.global_position = at
	fired.emit(id)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["alt_cd"] = rift_cd
	return s
