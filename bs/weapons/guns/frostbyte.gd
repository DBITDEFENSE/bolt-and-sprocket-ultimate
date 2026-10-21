extends BeamWeapon
## FROSTBYTE (BS_WEAPONS §8.11). updateFrostbyte (index.html:5735): a held coolant beam, 18 m in a narrow cone
## (dot > 0.9), draining 1 ammo per 0.12 s; 6 damage per second; the target's frost meter builds at
## 1.4 + 0.25 x dTier per second and at 1.0 a non-armoured enemy FREEZES for 6 s (freezeEnemy 5770). A mallet hit on
## a frozen enemy SHATTERS it (bolt_melee: 2.5x, status "shatter"); this gun adds the 5-bolt fountain. Ammo 40 (+16).
## Remake: heavies need frost 2.0; targets building frost are SLOWED; frost thaws 0.5/s after 1 s off the beam.
## Alt-fire ICE WALL: a 4 x 2.5 m barrier at the aim point (<= 10 m), 150 HP, 6 s; blocks enemy projectiles and
## pathing; enemies touching it gain 0.5 frost per second. 8 ammo, 5 s cooldown.
## V3: a SHATTER spreads freeze to everything within 5 m. V5: the beam passes through frozen targets to the next.
## Ω DEEP FREEZE: 26 m beam, freeze x1.6, statues stay iced 9 s, ice walls 2x wider and freeze on touch.
## Signatures: cold_storage (shatter drops 8 bolts), flash_freeze (dot 0.95, freeze x1.5, heavies at 1.0).

var wall_cd: float = 0.0
var beam_on: bool = false
var beam_end: Vector3 = Vector3.ZERO
var _dmg_acc: Dictionary = {}
var _frosted: Dictionary = {}     # target -> seconds since last frost gain


func beam_range() -> float:
	return P("range_omega", 26.0) if omega() else P("range", 18.0)


func beam_dot() -> float:
	return P("flash_dot", 0.95) if sig() == &"flash_freeze" else P("dot", 0.9)


func frost_rate() -> float:
	var r: float = P("frost_rate", 1.4) + P("frost_per_dmg_tier", 0.25) * mod_tier("dmg")
	if omega():
		r *= P("frost_omega_mul", 1.6)
	if sig() == &"flash_freeze":
		r *= P("flash_mul", 1.5)
	return r


func freeze_time() -> float:
	return P("freeze_time_omega", 9.0) if omega() else P("freeze_time", 6.0)


func threshold(e: Node) -> float:
	if WeaponData.prop_bool(e, "heavy") and sig() != &"flash_freeze":
		return P("freeze_heavy", 2.0)
	return P("freeze_at", 1.0)


func frost_of(e: Node) -> float:
	return float(e.get_meta(&"bs_frost", 0.0)) if e != null else 0.0


## Adds frost to a target (beam, ice wall); freezes it at its threshold. Returns true when it froze.
func add_frost(e: Node3D, amount: float) -> bool:
	if not alive(e) or mgr.has_status(e, &"frozen"):
		return false
	var f: float = frost_of(e) + amount
	_frosted[e] = 0.0
	if f >= threshold(e):
		e.set_meta(&"bs_frost", 0.0)
		freeze(e)
		return true
	e.set_meta(&"bs_frost", f)
	mgr.apply_status(e, &"slowed", P("slow_refresh", 0.3))
	return false


func freeze(e: Node3D) -> void:
	if e.is_in_group(&"bosses") or WeaponData.prop_bool(e, "armored") or mgr.has_status(e, &"frozen"):
		return
	var h: Combat.Hit = make_hit(0.0, center_of(e))
	h.status = {"frozen": freeze_time()}
	mgr.deal_damage(e, h)
	WeaponFX.flash(mgr.world(), center_of(e), WeaponData.color(id), 0.6, 0.25)
	popup.emit("bs.weapon.fx.frozen", center_of(e))


func _tick(dt: float, is_equipped: bool) -> void:
	wall_cd = maxf(0.0, wall_cd - dt)
	_thaw(dt)
	beam_on = false
	if not is_equipped or not fire_held:
		target = null
		return
	if not drain_ammo(dt / maxf(0.01, interval())):
		target = null
		return
	beam_on = true
	var from: Vector3 = mgr.muzzle_pos()
	target = _pick_beam()
	beam_end = from + aim() * beam_range()
	var wall: Dictionary = mgr.ray_world(origin(), origin() + aim() * beam_range())
	if not wall.is_empty():
		beam_end = wall["position"]
	if target != null:
		beam_end = center_of(target)
		var acc: float = float(_dmg_acc.get(target, 0.0)) + dmg(P("dps", float(d.get("damage", 6)))) * dt
		if acc >= 1.0:
			var whole: float = floorf(acc)
			acc -= whole
			deal(target, whole, beam_end, beam_end - from)
		_dmg_acc[target] = acc
		if alive(target):
			add_frost(target, frost_rate() * dt)
	WeaponFX.tracer(mgr.world(), from, beam_end, WeaponData.color(id), 0.12 * tier_mul(), dt * 1.5)
	WeaponFX.tracer(mgr.world(), from, beam_end, Color.WHITE, 0.04, dt * 1.5)
	if mgr.rng.randf() < dt * 20.0:
		WeaponFX.flash(mgr.world(), beam_end, WeaponData.color(id), 0.18, 0.2)


## Nearest enemy in the cone with line of sight; a frozen target stops the beam (V5: it passes through them).
func _pick_beam() -> Node3D:
	var from: Vector3 = origin()
	var dir: Vector3 = aim()
	var cands: Array = []
	for e: Node3D in enemies():
		var to: Vector3 = center_of(e) - from
		var dd: float = to.length()
		if dd < beam_range() and to.normalized().dot(dir) > beam_dot() and mgr.ray_world(from, center_of(e)).is_empty():
			cands.append([dd, e])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for c: Array in cands:
		var e2: Node3D = c[1]
		if level() >= 5 and mgr.has_status(e2, &"frozen"):
			continue
		return e2
	return null


func _thaw(dt: float) -> void:
	for e: Variant in _frosted.keys():
		if not is_instance_valid(e) or not alive(e as Node):
			_frosted.erase(e)
			_dmg_acc.erase(e)
			continue
		var t: float = float(_frosted[e]) + dt
		_frosted[e] = t
		if t > P("frost_decay_delay", 1.0):
			var f: float = maxf(0.0, frost_of(e as Node) - P("frost_decay", 0.5) * dt)
			(e as Node).set_meta(&"bs_frost", f)
			if f <= 0.0:
				_frosted.erase(e)


## The mallet SHATTERED a frozen enemy (WeaponManager relays status "shatter"): bolt fountain; V3 spreads the freeze.
func on_shatter(e: Node3D) -> void:
	var c: Vector3 = center_of(e) if is_instance_valid(e) else Vector3.ZERO
	var n: int = int(P("cold_storage_bolts", 8)) if sig() == &"cold_storage" else int(P("shatter_bolts", 5))
	Pickup.fountain(mgr.world(), c, n)
	popup.emit("bs.weapon.fx.shatter", c)
	WeaponFX.blast(mgr.world(), c, 1.5, WeaponData.color(id))
	if level() >= 3:
		for o: Node3D in Combat.in_radius(get_tree(), c, P("shatter_spread", 5.0)):
			if o != e:
				freeze(o)


# ---- ICE WALL

func _on_alt_pressed() -> void:
	if wall_cd > 0.0:
		WeaponText.hint("bs.weapon.hint.ice_wall_cd", "icewallcd")
		return
	var cost: int = int(P("wall_ammo", 8))
	if not has_ammo(cost):
		empty_feedback()
		return
	use_ammo(cost)
	wall_cd = P("wall_cooldown", 5.0)
	var from: Vector3 = origin()
	var to: Vector3 = from + aim() * P("wall_range", 10.0)
	var hit: Dictionary = mgr.ray_world(from, to)
	var at: Vector3 = (hit["position"] as Vector3) - aim() * 0.6 if not hit.is_empty() else to
	var down: Dictionary = mgr.ray_world(at + Vector3.UP * 0.5, at + Vector3.DOWN * 6.0)
	if not down.is_empty():
		at = down["position"]
	var w: IceWall = IceWall.new()
	w.weapon = self
	w.width = P("wall_w", 4.0) * (P("wall_omega_w_mul", 2.0) if omega() else 1.0)
	w.height = P("wall_h", 2.5)
	w.depth = P("wall_d", 0.5)
	w.hp = P("wall_hp", 150.0)
	w.life = P("wall_life", 6.0)
	w.frost_rate = P("wall_frost", 0.5)
	w.touch = P("wall_touch", 0.8)
	w.instant = omega()
	mgr.world().add_child(w)
	w.global_position = at
	w.rotation.y = atan2(aim().x, aim().z)
	popup.emit("bs.weapon.fx.ice_wall", at + Vector3.UP * 2.0)
	fired.emit(id)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["alt_cd"] = wall_cd
	s["beam"] = beam_on
	if target != null and alive(target):
		s["frost"] = clampf(frost_of(target) / threshold(target), 0.0, 1.0)
	return s
