extends HitscanWeapon
## LATE FEE (BS_WEAPONS §9.1, new). A pump shotgun: 8 pellets x 7 in a 9° cone every 0.85 s; full damage to 4 m,
## 50% at 12 m, nothing past 16 m. INTEREST: +12.5% damage per second you DON'T fire it (while equipped), up to x2.0;
## firing resets it. Pellets pierce one GRAVITY-CLUMPED enemy. A blast at x1.75+ GARNISHES: SLOWED 3 s. Ammo 10 (+4).
## Alt-fire COLLECTIONS: a 9 m pull-shot that yanks one non-heavy enemy to 2 m in front of Bolt for 10 and stuns it
## 0.6 s on arrival; heavies are staggered 0.5 s instead; bosses and rooted targets can't be pulled. 1 ammo, 3 s
## cooldown, and it does NOT reset interest.
## V3: interest keeps accruing while holstered. V5: max x2.5; a full-interest blast staggers non-boss heavies 0.8 s.
## Ω COMPOUND INTEREST: 10 pellets; kills refund half the accrued interest (a killing x2.0 blast leaves x1.5).
## Signatures: penalty_apr (+25%/s, cap x1.6), grace_period (after 3 s idle the next shot is a slug: 80 x interest,
## pierce 2, accurate to 30 m).

var idle: float = 0.0
var collect_cd: float = 0.0
var last_mult: float = 1.0
var _shot_kills: int = 0


func rate() -> float:
	return P("apr_per_s", 0.25) if sig() == &"penalty_apr" else P("interest_per_s", 0.125)


func cap() -> float:
	if sig() == &"penalty_apr":
		return P("apr_max", 1.6)
	return P("interest_max_v5", 2.5) if level() >= 5 else P("interest_max", 2.0)


func interest() -> float:
	return minf(cap(), 1.0 + rate() * idle)


func pellets() -> int:
	return int(P("pellets_omega", 10)) if omega() else int(P("pellets", 8))


func grace_ready() -> bool:
	return sig() == &"grace_period" and idle >= P("grace_idle", 3.0)


func _tick(dt: float, is_equipped: bool) -> void:
	collect_cd = maxf(0.0, collect_cd - dt)
	if is_equipped or level() >= 3:
		idle += dt


## Full to 4 m, 50% at 12 m, 0 at 16 m.
func falloff(dist: float) -> float:
	var a: float = P("falloff_start", 4.0)
	var b: float = P("falloff_end", 12.0)
	var c: float = P("range", 16.0)
	if dist <= a:
		return 1.0
	if dist <= b:
		return lerpf(1.0, P("falloff_mul", 0.5), (dist - a) / maxf(0.01, b - a))
	return lerpf(P("falloff_mul", 0.5), 0.0, clampf((dist - b) / maxf(0.01, c - b), 0.0, 1.0))


func _fire() -> void:
	cooldown = interval()
	if not use_ammo(1):
		return
	var k: float = interest()
	last_mult = k
	_shot_kills = 0
	var full: bool = k >= cap() - 0.001
	var st: Dictionary = {}
	if k >= P("garnish_at", 1.75):
		st["slowed"] = P("garnish_slow", 3.0)
	var from: Vector3 = origin()
	var base: Vector3 = aim()
	var col: Color = WeaponData.color(id)
	if grace_ready():
		_slug(from, base, k, st)
	else:
		for i: int in pellets():
			var dir: Vector3 = spread_dir(base, P("cone_deg", 9.0))
			var res: Dictionary = mgr.hitscan(from, dir, P("range", 16.0))
			var end: Vector3 = res["end"]
			var pierced: int = 0
			for h: Array in res["hits"]:
				var e: Node3D = h[1]
				var amt: float = roundf(dmg(float(d.get("damage", 7))) * k * falloff(float(h[0])))
				if amt > 0.0:
					_pellet_hit(e, h[2], amt, dir, st, full)
				end = h[2]
				if mgr.has_status(e, &"gravity_clumped") and pierced < int(P("clump_pierce", 1)):
					pierced += 1
					continue
				break
			WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), end, col.lerp(Color("#ffd23e"), clampf(k - 1.0, 0.0, 1.0)), 0.035, 0.06)
		WeaponFX.cone(mgr.world(), mgr.muzzle_pos(), base, 1.4, P("cone_deg", 9.0) * 2.0, Color("#ffb44d"), 5)
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), col, 0.3 * tier_mul() * k)
	if k > 1.05:
		popup.emit(WeaponText.text("bs.weapon.fx.interest") % roundi((k - 1.0) * 100.0), mgr.muzzle_pos() + base)
	if k >= P("garnish_at", 1.75):
		popup.emit("bs.weapon.fx.garnish", mgr.muzzle_pos() + base * 3.0)
	recoil(float(d.get("recoil", 0.03)) * clampf(k, 1.0, 2.0))
	shake(P("shake", 0.22) * clampf(k, 1.0, 2.0))
	# Ω COMPOUND INTEREST: kills refund half of what had accrued
	if omega() and _shot_kills > 0:
		var after: float = 1.0 + (k - 1.0) * P("omega_refund", 0.5)
		idle = (after - 1.0) / maxf(0.0001, rate())
	else:
		idle = 0.0
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func _pellet_hit(e: Node3D, point: Vector3, amt: float, dir: Vector3, st: Dictionary, full: bool) -> void:
	var s2: Dictionary = st.duplicate()
	if full and level() >= 5 and WeaponData.prop_bool(e, "heavy") and not e.is_in_group(&"bosses"):
		s2["stun"] = P("stagger_heavy", 0.8)
	var h: Combat.Hit = make_hit(amt, point, dir)
	h.status = s2
	h.knock = 2.0
	if mgr.deal_damage(e, h):
		_shot_kills += 1


func _slug(from: Vector3, dir: Vector3, k: float, st: Dictionary) -> void:
	var res: Dictionary = mgr.hitscan(from, dir, P("slug_range", 30.0))
	var end: Vector3 = res["end"]
	var n: int = 0
	for h: Array in res["hits"]:
		_pellet_hit(h[1], h[2], roundf(dmg(P("slug_dmg", 80.0)) * k), dir, st, false)
		n += 1
		end = h[2]
		if n > int(P("slug_pierce", 2)):
			break
	WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), end, Color("#ffd23e"), 0.12, 0.12)
	popup.emit("bs.weapon.fx.grace", mgr.muzzle_pos() + dir)


# ---- COLLECTIONS

func _on_alt_pressed() -> void:
	if collect_cd > 0.0:
		WeaponText.hint("bs.weapon.hint.collections_cd", "collectcd")
		return
	var e: Node3D = aimed_enemy(P("collect_range", 9.0), P("collect_dot", 0.8))
	if e == null or e.is_in_group(&"bosses") or mgr.has_status(e, &"rooted"):
		return
	if not use_ammo(int(P("collect_ammo", 1))):
		return
	collect_cd = P("collect_cooldown", 3.0)
	var c: Vector3 = center_of(e)
	WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), c, Color("#ffd23e"), 0.05, 0.25)
	popup.emit("bs.weapon.fx.collections", c)
	if WeaponData.prop_bool(e, "heavy"):
		deal(e, roundf(dmg(P("collect_dmg", 10.0))), c, c - origin(), {"stun": P("collect_heavy_stagger", 0.5)})
		return
	deal(e, roundf(dmg(P("collect_dmg", 10.0))), c, c - origin())
	if not alive(e):
		return
	var flat: Vector3 = Vector3(aim().x, 0, aim().z).normalized()
	var dest: Vector3 = mgr.bolt.global_position + flat * P("collect_to", 2.0)
	dest.y = e.global_position.y
	var pull: WeaponPull = WeaponPull.new()
	pull.target = e
	pull.dest = dest
	pull.speed = P("collect_speed", 30.0)
	pull.on_arrive = func() -> void:
		if alive(e):
			mgr.apply_status(e, &"stun", P("collect_stun", 0.6))
	mgr.world().add_child(pull)
	recoil(0.01)
	fired.emit(id)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["interest"] = interest()
	s["interest_max"] = cap()
	s["grace"] = grace_ready()
	s["alt_cd"] = collect_cd
	return s
