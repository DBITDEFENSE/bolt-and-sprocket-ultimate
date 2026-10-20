extends HitscanWeapon
## OMNI-BLASTER (BS_WEAPONS §8.1). fireBlaster (index.html:4552): 8 damage every 0.13 s, every 5th shot a HOT ROUND
## (16, pierce 2). Remake: hitscan with a tracer, and a heat bar instead of infinite spam: +6 per shot, 100 max
## (+20 per Heat Sink tier), vents 40/s after 0.35 s idle, 100 = OVERHEAT (forced 1.0 s vent).
## Alt-fire HOT ROUND: needs 25 heat; 16 + 0.5 x heat damage, pierce 3, heat to 0.
## V3: vent 55/s, auto Hot Round every 4th. V5: alt at 90+ heat = MAX HOT ROUND (ignites everything it pierces).
## Ω OVERTIME: every 3rd shot is hot, hot rounds fork 2 sparks (6) at bystanders within 6 m, sparks apply CONDUCTIVE.
## Signatures: cool_customer (no lockout, half fire rate at 100 until < 70), thermal_debt (alt at any heat,
## 16 + 1.0 x heat, then a 1.0 s overheat).

var heat: float = 0.0
var overheat_t: float = 0.0
var idle_t: float = 99.0
var shot_n: int = 0
var throttled: bool = false
var _overheat_warned: bool = false


func heat_max() -> float:
	return WeaponData.heat_capacity(id, mod_tier("ammo"), level())


func vent_rate() -> float:
	return P("vent_rate_v3", 55.0) if level() >= 3 else P("vent_rate", 40.0)


func hot_every() -> int:
	if omega():
		return int(P("hot_every_omega", 3))
	return int(P("hot_every_v3", 4)) if level() >= 3 else int(P("hot_every", 5))


func overheated() -> bool:
	return overheat_t > 0.0


func _can_auto_fire() -> bool:
	return not overheated()


func _fire() -> void:
	cooldown = interval() * (2.0 if throttled else 1.0)
	shot_n += 1
	var hot: bool = shot_n % hot_every() == 0
	var base: float = P("hot_damage", 16.0) if hot else float(d.get("damage", 8))
	_shot_kind = 1 if hot else 0
	shoot(dmg(base), int(P("hot_pierce", 2)) if hot else 0, {}, Color("#ff8a2e") if hot else Color(0, 0, 0, 0), 0.09 if hot else 0.05)
	if hot:
		popup.emit("bs.weapon.fx.hot_round", mgr.muzzle_pos())
		if mgr.bolt != null and mgr.bolt.camera != null:
			mgr.bolt.camera.shake(0.08)
	recoil(float(d.get("recoil", 0.0035)) * (1.8 if hot else 1.0))
	_add_heat(P("heat_per_shot", 6.0))
	fired.emit(id)
	mgr.weapon_fired.emit(id)


var _shot_kind: int = 0    # 0 normal, 1 hot (auto), 2 alt hot round, 3 MAX hot round


func _add_heat(h: float) -> void:
	idle_t = 0.0
	heat = minf(heat_max(), heat + h)
	if heat >= heat_max() - 0.001:
		if sig() == &"cool_customer":
			throttled = true
		else:
			_overheat()


func _overheat() -> void:
	heat = heat_max()
	overheat_t = P("overheat_time", 1.0)
	popup.emit("bs.weapon.fx.overheat", mgr.muzzle_pos())
	WeaponFX.flash(mgr.world(), mgr.muzzle_pos(), Color(0.9, 0.9, 0.95), 0.45, 0.4)   # steam burst
	if not _overheat_warned:
		_overheat_warned = true
		WeaponText.hint("bs.weapon.hint.heat", "blasterheat")


func _tick(dt: float, _is_equipped: bool) -> void:
	idle_t += dt
	if overheat_t > 0.0:
		overheat_t = maxf(0.0, overheat_t - dt)
		heat = heat_max() * overheat_t / maxf(0.01, P("overheat_time", 1.0))
	elif idle_t > P("vent_delay", 0.35):
		heat = maxf(0.0, heat - vent_rate() * dt)
	if throttled and heat < P("cool_resume_heat", 70.0):
		throttled = false


## HOT ROUND alt-fire: cash the heat bar in for one big piercing shot.
func _on_alt_pressed() -> void:
	if overheated() or cooldown > 0.0:
		return
	var debt: bool = sig() == &"thermal_debt"
	if not debt and heat < P("alt_min_heat", 25.0):
		WeaponText.hint("bs.weapon.hint.hot_round_cold", "hotcold")
		return
	var per: float = P("thermal_debt_per_heat", 1.0) if debt else P("alt_per_heat", 0.5)
	var is_max: bool = level() >= 5 and heat >= P("max_hot_heat", 90.0)
	_shot_kind = 3 if is_max else 2
	var amount: float = dmg(P("alt_base", 16.0) + per * heat)
	shoot(amount, int(P("alt_pierce", 3)), {}, Color("#ff5a12"), 0.14)
	popup.emit("bs.weapon.fx.max_hot_round" if is_max else "bs.weapon.fx.hot_round", mgr.muzzle_pos())
	recoil(P("alt_recoil", 0.02))
	if mgr.bolt != null and mgr.bolt.camera != null:
		mgr.bolt.camera.shake(0.18)
	cooldown = interval()
	if debt:
		_overheat()
	else:
		heat = 0.0
		idle_t = 99.0
	fired.emit(id)
	mgr.weapon_fired.emit(id)


func on_hitscan_hit(e: Node3D, point: Vector3, dist: float, amount: float, dir: Vector3, status: Dictionary, index: int) -> void:
	var st: Dictionary = status.duplicate()
	var hot: bool = _shot_kind >= 1
	if _shot_kind == 3 or (hot and mgr.has_status(e, &"served")):
		st["burning"] = P("burn_time", 3.0)
		popup.emit("bs.weapon.fx.ignite", point)
	super.on_hitscan_hit(e, point, dist, amount, dir, st, index)
	if hot and omega():
		_fork_sparks(e, point)


func _fork_sparks(from_e: Node3D, point: Vector3) -> void:
	var n: int = int(P("omega_sparks", 2))
	for o: Node3D in Combat.in_radius(mgr.get_tree(), point, P("omega_spark_range", 6.0)):
		if o == from_e or n <= 0:
			continue
		n -= 1
		var c: Vector3 = o.call("get_center")
		WeaponFX.lightning(mgr.world(), point, c, Color("#ffb44d"), mgr.rng)
		deal(o, roundf(dmg(P("omega_spark_dmg", 6.0))), c, c - point, {"conductive": P("conductive_time", 4.0)})


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	s["heat"] = heat
	s["heat_max"] = heat_max()
	s["overheated"] = overheated()
	s["throttled"] = throttled
	return s
