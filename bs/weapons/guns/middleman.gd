extends BSWeapon
## THE MIDDLEMAN (BS_WEAPONS §8.10). fireMiddleman / updateOneMiddleman (index.html:5689-5733): deploys one hovering
## drone 3 m ahead + 1.5 up for 12 s that fires 8 every 0.35 s at the nearest enemy within 22 m. One at a time
## ("Union rules"), two at Ω ("SUBCONTRACTED"). Ammo 3 (+1 per tier).
## Remake: the drone has 120 HP and really draws aggro (group "enemy_decoys"; each non-boss enemy within 15 m has a
## 70% chance to retarget it, re-rolled every 3 s). Its shots count as the gun's own damage.
## Alt-fire REASSIGN: point at an enemy; every drone focuses it for 4 s and enemies within 10 m of it are taunted
## onto the nearest drone. 4 s cooldown.
## V3: at contract end the drone explodes for 45 (r5), "OUTSOURCED!". V5: 60-point shield; Reassign has no cooldown.
## Ω MIDDLE MANAGEMENT: two drones that argue in barks; when a contract ends, the drone with more kills explodes
## for double. Signatures: consultant (20 s, no aggro), scapegoat (r25, 100% retarget, 50% damage taken, half rate).

var drones: Array[MiddlemanDrone] = []
var reassign_cd: float = 0.0
var _argued_first: bool = false
var _argue_cd: float = 0.0


func _prune() -> void:
	var keep: Array[MiddlemanDrone] = []
	for dr: MiddlemanDrone in drones:
		if dr != null and is_instance_valid(dr) and not dr.ended:
			keep.append(dr)
	drones = keep


func max_active() -> int:
	return int(P("max_active_omega", 2)) if omega() else int(P("max_active", 1))


func _tick(dt: float, _is_equipped: bool) -> void:
	reassign_cd = maxf(0.0, reassign_cd - dt)
	_argue_cd = maxf(0.0, _argue_cd - dt)
	_prune()
	if omega() and drones.size() == 2 and _argue_cd <= 0.0:
		var a: MiddlemanDrone = drones[0]
		if a.age > P("argue_late", 10.0) and not a.argued_late:
			a.argued_late = true
			_argue("bs.weapon.middleman.argue.04")
		elif a.idle_t > P("argue_interval", 6.0):
			a.idle_t = 0.0
			_argue("bs.weapon.middleman.argue.03")


func _argue(line: String) -> void:
	_argue_cd = 2.5
	WeaponText.say(line)


func _fire() -> void:
	cooldown = interval()
	_prune()
	if drones.size() >= max_active():
		WeaponText.hint("code.fireMiddleman.03" if omega() else "code.fireMiddleman.04", "")
		return
	if not use_ammo(1):
		return
	var second: bool = drones.size() == 1
	var dr: MiddlemanDrone = MiddlemanDrone.new()
	dr.weapon = self
	var consultant: bool = sig() == &"consultant"
	var scapegoat: bool = sig() == &"scapegoat"
	dr.life = P("consultant_duration", 20.0) if consultant else P("duration", 12.0)
	dr.shot_interval = P("shot_interval", 0.35) * (P("scapegoat_fire_mul", 2.0) if scapegoat else 1.0)
	dr.range_m = P("range", 22.0)
	dr.shot_dmg = dmg(float(d.get("damage", 8)))
	dr.max_hp = P("hp", 120.0)
	dr.hp = dr.max_hp
	dr.shield = P("shield_v5", 60.0) if level() >= 5 else 0.0
	dr.aggro = not consultant
	dr.aggro_radius = P("scapegoat_radius", 25.0) if scapegoat else P("aggro_radius", 15.0)
	dr.aggro_chance = P("scapegoat_chance", 1.0) if scapegoat else P("aggro_chance", 0.7)
	dr.aggro_reroll = P("aggro_reroll", 3.0)
	dr.dmg_taken = P("scapegoat_dmg_taken", 0.5) if scapegoat else 1.0
	dr.clip_on = second
	dr.details = level() - 1
	dr.gold = omega()
	var flat: Vector3 = Vector3(aim().x, 0, aim().z).normalized()
	if flat == Vector3.ZERO:
		flat = Vector3.FORWARD
	var base: Vector3 = mgr.bolt.global_position + Vector3.UP * P("height", 1.5)
	var want: Vector3 = base + flat * P("forward", 3.0) + (flat.cross(Vector3.UP) * 1.2 if second else Vector3.ZERO)
	var wall: Dictionary = mgr.ray_world(base, want)
	mgr.world().add_child(dr)
	dr.global_position = (wall["position"] as Vector3) - flat * 0.5 if not wall.is_empty() else want
	drones.append(dr)
	WeaponFX.flash(mgr.world(), dr.global_position, WeaponData.color(id), 0.5)
	recoil(float(d.get("recoil", 0.008)))
	if second:
		EventBus.banner.emit(WeaponText.text("code.fireMiddleman.05"), WeaponText.text("code.fireMiddleman.06"), 1.4)
		_argue("bs.weapon.middleman.argue.01")
		get_tree().create_timer(1.6, false).timeout.connect(func() -> void: WeaponText.say("bs.weapon.middleman.argue.01b"))
		if not _argued_first:
			_argued_first = true
			get_tree().create_timer(3.4, false).timeout.connect(func() -> void: WeaponText.say("bs.weapon.middleman.argue.06"))
	else:
		WeaponText.hint("code.fireMiddleman.07", "midtut")
	fired.emit(id)
	mgr.weapon_fired.emit(id)


## A drone's kill (Ω barks).
func on_drone_kill(_dr: MiddlemanDrone) -> void:
	if omega() and drones.size() == 2 and _argue_cd <= 0.0:
		_argue("bs.weapon.middleman.argue.02")


## Contract end: V3 OUTSOURCED! (45, r5); at Ω the drone with more kills goes out with double the bang.
func on_drone_end(dr: MiddlemanDrone) -> void:
	if level() < 3 and not omega():
		return
	var mul: float = 1.0
	if omega():
		var best: bool = true
		for o: MiddlemanDrone in drones:
			if o != dr and is_instance_valid(o) and not o.ended and o.kills >= dr.kills:
				best = false
		if best and dr.kills > 0:
			mul = P("omega_explode_mul", 2.0)
		if drones.size() >= 2:
			_argue("bs.weapon.middleman.argue.05")
	explode(dr.global_position, P("explode_r", 5.0), dmg(P("explode_dmg", 45.0)) * mul)
	EventBus.banner.emit(WeaponText.text("code.updateOneMiddleman.01"), WeaponText.text("code.updateOneMiddleman.02"), 1.4)


# ---- REASSIGN

func _on_alt_pressed() -> void:
	_prune()
	if drones.is_empty():
		return
	if reassign_cd > 0.0 and level() < 5:
		WeaponText.hint("bs.weapon.hint.reassign_cd", "reassigncd")
		return
	var e: Node3D = aimed_enemy(P("reassign_range", 30.0), P("reassign_dot", 0.93))
	if e == null:
		return
	for dr: MiddlemanDrone in drones:
		dr.focus(e, P("reassign_time", 4.0))
	for o: Node3D in Combat.in_radius(get_tree(), center_of(e), P("reassign_radius", 10.0)):
		if o.is_in_group(&"bosses") or not ("target" in o):
			continue
		var nd: MiddlemanDrone = null
		var bd: float = INF
		for dr2: MiddlemanDrone in drones:
			var dd: float = dr2.global_position.distance_to(o.global_position)
			if dd < bd:
				bd = dd
				nd = dr2
		if nd != null:
			o.set("target", nd)
	reassign_cd = 0.0 if level() >= 5 else P("reassign_cooldown", 4.0)
	popup.emit("bs.weapon.fx.reassign", center_of(e))
	WeaponFX.tracer(mgr.world(), mgr.muzzle_pos(), center_of(e), WeaponData.color(id), 0.03, 0.2)


func hud_state() -> Dictionary:
	var s: Dictionary = super.hud_state()
	_prune()
	s["drones"] = drones.size()
	s["drones_max"] = max_active()
	s["alt_cd"] = reassign_cd if level() < 5 else 0.0
	return s
