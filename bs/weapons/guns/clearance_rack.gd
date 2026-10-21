extends HitscanWeapon
## CLEARANCE RACK (BS_WEAPONS §9.4, new). A spin-up minigun: 0.6 s spin-up (holding alt spins without firing), then a
## 5-damage price-tag round every 0.06 s; spread 3°, widening to 5° after 2 s of continuous fire. Each hit adds 1
## MARKED DOWN stack (max 10; meta "bs_markdown" + status "marked_down"); stacks decay 1 per 0.5 s after 2 s without
## a hit. On bosses each stack raises the 45% non-weak-point damage by 2 points (WeaponRules). Ammo 150 (+50).
## Movement while spun up is -30% (meta "bs_move_mult" on Bolt; BoltMotor would read it).
## Alt-fire DOORBUSTER: after at least 1 s of spin-up, releasing alt fires a 6 m, 60° cone: 25, knockback 10,
## 3 stacks. 15 ammo, 4 s cooldown.
## V3: the barrels stay spun 1.5 s after release. V5: every 25th round is "50% OFF": x3 damage and 3 stacks.
## Ω EVERYTHING MUST GO: no spin-up, stack cap 20; at 20 stacks armour hits 0: plates fall off (pop_all_plates())
## and a boss takes full damage outside its weak point for 4 s, then the stacks reset.
## Signatures: final_sale (0.09 s, 2 stacks per hit), bogo (every 2nd hit ricochets a free tag within 8 m).

var spin_t: float = 0.0
var linger: float = 0.0
var fire_t: float = 0.0
var round_n: int = 0
var hit_n: int = 0
var door_cd: float = 0.0
var _tracked: Dictionary = {}     # target -> seconds since its last stack
var _decay_acc: Dictionary = {}
var _door_hinted: bool = false


func spin_time() -> float:
	return 0.0 if omega() else P("spin_time", 0.6)


func spun() -> bool:
	return spin_t >= spin_time()


func cap() -> int:
	return int(P("stacks_max_omega", 20)) if omega() else int(P("stacks_max", 10))


func _can_auto_fire() -> bool:
	return spun()


func _tick(dt: float, is_equipped: bool) -> void:
	door_cd = maxf(0.0, door_cd - dt)
	var spinning: bool = is_equipped and (fire_held or alt_held)
	if spinning:
		spin_t += dt
		linger = P("linger_v3", 1.5) if level() >= 3 else 0.0
	elif linger > 0.0:
		linger -= dt
	else:
		spin_t = 0.0
	fire_t = fire_t + dt if is_equipped and fire_held and spun() else 0.0
	if mgr != null and mgr.bolt != null:
		if is_equipped and spin_t > 0.0:
			mgr.bolt.set_meta(&"bs_move_mult", P("spun_move_mul", 0.7))
		elif mgr.bolt.has_meta(&"bs_move_mult"):
			mgr.bolt.remove_meta(&"bs_move_mult")
	_decay(dt)


func _on_holster() -> void:
	spin_t = 0.0
	linger = 0.0
	if mgr != null and mgr.bolt != null and mgr.bolt.has_meta(&"bs_move_mult"):
		mgr.bolt.remove_meta(&"bs_move_mult")


func _fire() -> void:
	var base_iv: float = P("final_sale_interval", 0.09) * WeaponData.rate_mul(mod_tier("rate")) if sig() == &"final_sale" else interval()
	cooldown = base_iv
	if not use_ammo(1):
		return
	round_n += 1
	var sale: bool = level() >= 5 and round_n % int(P("sale_every", 25)) == 0
	var amount: float = dmg(float(d.get("damage", 5))) * (P("sale_mul", 3.0) if sale else 1.0)
	var spread: float = lerpf(P("spread_deg", 3.0), P("spread_max", 5.0), clampf(fire_t / maxf(0.01, P("spread_after", 2.0)), 0.0, 1.0))
	var dir: Vector3 = spread_dir(aim(), spread)
	var res: Dictionary = mgr.hitscan(origin(), dir, P("range", 40.0))
	var end: Vector3 = res["end"]
	var hits: Array = res["hits"]
	if not hits.is_empty():
		var e: Node3D = hits[0][1]
		end = hits[0][2]
		deal(e, roundf(amount * falloff(float(hits[0][0]))), end, dir)
		var n: int = int(P("sale_stacks", 3)) if sale else (int(P("final_stacks", 2)) if sig() == &"final_sale" else 1)
		add_stacks(e, n)
		hit_n += 1
		if sale:
			popup.emit("bs.weapon.fx.sale", end)
		if sig() == &"bogo" and hit_n % int(P("bogo_every", 2)) == 0:
			var o: Node3D = nearest_enemy(center_of(e), P("bogo_range", 8.0), [e])
			if o != null:
				WeaponFX.tracer(mgr.world(), end, center_of(o), WeaponData.color(id), 0.03, 0.08)
				deal(o, roundf(amount), center_of(o), center_of(o) - end)
				add_stacks(o, 1)
	WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), end, Color("#ffd23e") if sale else WeaponData.color(id), 0.04 if sale else 0.025, 0.05)
	if round_n % 2 == 0:
		WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), WeaponData.color(id), 0.12 * tier_mul())
	recoil(float(d.get("recoil", 0.0015)))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func add_stacks(e: Node3D, n: int) -> void:
	if not alive(e):
		return
	var before: int = int(e.get_meta(&"bs_markdown", 0)) if mgr.has_status(e, &"marked_down") else 0
	var s: int = mini(cap(), before + n)
	e.set_meta(&"bs_markdown", s)
	mgr.apply_status(e, &"marked_down", P("stack_hold", 2.0) + P("stack_decay", 0.5) * s)
	_tracked[e] = 0.0
	_decay_acc[e] = 0.0
	if s / 5 > before / 5 and s < cap():
		popup.emit(WeaponText.text("bs.weapon.fx.markdown") % (s * 10), center_of(e))
	if omega() and s >= cap():
		e.set_meta(&"bs_markdown", 0)
		if e.has_method("pop_all_plates"):
			e.call("pop_all_plates")
		if e.is_in_group(&"bosses"):
			e.set_meta(&"bs_bare_until", WeaponRules.now() + P("omega_bare_time", 4.0))
		popup.emit("bs.weapon.fx.everything", center_of(e))


func markdown(e: Node) -> int:
	return WeaponRules.markdown_stacks(e)


func _decay(dt: float) -> void:
	for e: Variant in _tracked.keys():
		if not is_instance_valid(e) or not alive(e as Node):
			_tracked.erase(e)
			_decay_acc.erase(e)
			continue
		var t: float = float(_tracked[e]) + dt
		_tracked[e] = t
		if t < P("stack_hold", 2.0):
			continue
		var acc: float = float(_decay_acc.get(e, 0.0)) + dt
		if acc >= P("stack_decay", 0.5):
			acc -= P("stack_decay", 0.5)
			var s: int = int((e as Node).get_meta(&"bs_markdown", 0)) - 1
			(e as Node).set_meta(&"bs_markdown", maxi(0, s))
			if s <= 0:
				_tracked.erase(e)
				_decay_acc.erase(e)
				continue
		_decay_acc[e] = acc


# ---- DOORBUSTER

func _on_alt_released() -> void:
	if spin_t < P("door_min_spin", 1.0) or door_cd > 0.0:
		if not _door_hinted:
			_door_hinted = true
			WeaponText.hint("bs.weapon.hint.doorbuster", "doorbuster")
		return
	var cost: int = int(P("door_ammo", 15))
	if not has_ammo(cost):
		empty_feedback()
		return
	use_ammo(cost)
	door_cd = P("door_cooldown", 4.0)
	var from: Vector3 = mgr.bolt.global_position + Vector3.UP * 0.9
	var flat: Vector3 = Vector3(aim().x, 0, aim().z).normalized()
	var half: float = deg_to_rad(P("door_deg", 60.0) * 0.5)
	for e: Node3D in Combat.in_radius(get_tree(), from, P("door_r", 6.0)):
		var to: Vector3 = center_of(e) - from
		to.y = 0.0
		if to.length() > 0.3 and flat.angle_to(to.normalized()) > half:
			continue
		var h: Combat.Hit = make_hit(roundf(dmg(P("door_dmg", 25.0))), center_of(e), to)
		h.knock = P("door_knock", 10.0)
		mgr.deal_damage(e, h)
		add_stacks(e, int(P("door_stacks", 3)))
	WeaponFX.cone(mgr.world(), mgr.muzzle_pos(), flat, P("door_r", 6.0), P("door_deg", 60.0) * 0.5, WeaponData.color(id), 9)
	popup.emit("bs.weapon.fx.doorbuster", from + flat * 2.0)
	recoil(0.03)
	shake(0.3)
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["spin"] = 1.0 if spin_time() <= 0.0 else clampf(spin_t / spin_time(), 0.0, 1.0)
	s["alt_cd"] = door_cd
	s["door_ready"] = spin_t >= P("door_min_spin", 1.0) and door_cd <= 0.0
	return s
