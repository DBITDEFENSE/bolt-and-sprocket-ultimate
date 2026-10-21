class_name SurgeDrone
extends EnemyBase
## Surge Drone — surge-pricing flyer (BS_ENEMIES §3.3; makeSurgeDrone index.html:6091; legacy flyer :6774-6800).
## 26 HP / 10 per shot / 6 bolts. Legacy flyer orbit (4 m out, 3 m up) and shot: within 17 m every 2.4 s, a
## 10-damage shot at 10 m/s; telegraph 0.45 s (the gun glows, a cash-register "ding", the ticker flashes).
## SURGE PRICING (declared but never coded in v14; implemented here): for every other enemy alive within 15 m
## (up to 6) it gets +15% damage and +8% fire rate (max +90% / +48%). Its ticker shows the multiplier ("1.6x").
## Elite (Peak Hours, magenta rim): the surge also buffs every other enemy within 15 m by +5% per enemy.

var surge_n: int = 0
var shots_fired: int = 0
var _gun_mat: StandardMaterial3D
var _ticker: Label3D
var _rotor: MeshInstance3D
var _scan_t: float = 0.0


func FL() -> Dictionary:
	return def["flyer"]


func SG() -> Dictionary:
	return def["surge"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#ff4d9d"))))
	flash_mats.append(body)
	EnemyFx.sphere(visual, 0.3, Vector3.ZERO, body, 0.52)
	_rotor = EnemyFx.cyl(visual, 0.4, 0.04, Vector3(0, 0.28, 0), EnemyFx.mat(Color("#232838")))
	EnemyFx.box(visual, Vector3(0.3, 0.08, 0.04), Vector3(0, 0, 0.26), EnemyFx.mat(Color("#ffd23e"), Color("#ffd23e"), 1.8))   # price-ticker eye
	EnemyFx.cyl(visual, 0.05, 0.2, Vector3(0, -0.28, 0), EnemyFx.mat(Color("#232838")))
	_gun_mat = EnemyFx.mat(Color("#ff4d9d"), Color("#ff2277"), 0.0)
	_gun_mat.emission_enabled = true
	EnemyFx.sphere(visual, 0.06, Vector3(0, -0.4, 0), _gun_mat)
	_ticker = Label3D.new()
	_ticker.text = "1.0x"
	_ticker.font_size = 40
	_ticker.pixel_size = 0.005
	_ticker.modulate = Color("#ffd23e")
	_ticker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ticker.position.y = 0.55
	visual.add_child(_ticker)


func _on_activate() -> void:
	surge_n = 0
	shots_fired = 0
	_scan_t = 0.0


## Other living enemies (EnemyBase only, not hittable shots) within the surge radius, capped.
func count_crowd() -> int:
	var n: int = 0
	var rr: float = float(SG()["radius"])
	for o: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: EnemyBase = o as EnemyBase
		if e == null or e == self or not e.is_alive() or e.arch == &"prop":
			continue
		if e.global_position.distance_to(global_position) < rr:
			n += 1
	return mini(n, int(SG()["max_others"]))


func surge_damage_mult() -> float:
	return 1.0 + float(SG()["dmg_per"]) * surge_n


func surge_rate_mult() -> float:
	return 1.0 + float(SG()["rate_per"]) * surge_n


func attack_rate() -> float:
	return super.attack_rate() * surge_rate_mult()


func _timers(delta: float) -> void:
	super._timers(delta)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		surge_n = count_crowd()
		_ticker.text = "%.1fx" % surge_damage_mult()
		if elite:
			var bonus: float = float(def["elite"]["aura_per"]) * surge_n
			for o: Node in get_tree().get_nodes_in_group(&"enemies"):
				var e: EnemyBase = o as EnemyBase
				if e != null and e != self and e.is_alive() and e.global_position.distance_to(global_position) < float(SG()["radius"]):
					e.aura_bonus = maxf(e.aura_bonus if e.aura_t > 0.0 else 0.0, bonus)
					e.aura_t = 0.5


func _idle_update(dt: float) -> void:
	_orbit(home, dt)


func _orbit(anchor: Vector3, dt: float) -> void:
	var goal: Vector3 = anchor + Vector3(cos(t * float(FL()["orbit_rate"])) * float(FL()["orbit_radius"]),
		float(FL()["orbit_height"]) + sin(t * 2.0) * 0.6, sin(t * float(FL()["orbit_rate"])) * float(FL()["orbit_radius"]))
	desired_vel = (goal - global_position) * float(FL()["follow"]) * move_mult() if can_move() else Vector3.ZERO
	if target != null:
		face(target_pos() - global_position, dt, 4.0)


func _position_update(dt: float) -> void:
	var d: float = dist_to_target()
	_orbit(target_pos() if d < float(FL()["anchor_radius"]) else home, dt)
	var tele: float = float(telegraph_def(&"shot").get("dur", 0.45))
	if d < float(FL()["fire_radius"]) and fire_cd <= tele and can_attack() and target_alive():
		if AttackTokens.request_ranged():
			begin_telegraph(&"shot", tele, -1.0, Vector3.INF, false)
		else:
			fire_cd = tele + 0.15


func _telegraph_update(dt: float) -> void:
	_orbit(target_pos(), dt)
	desired_vel *= 0.4
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_gun_mat.emission_energy_multiplier = k * 3.2
	_ticker.modulate = Color("#ffffff") if fmod(t * 8.0, 1.0) > 0.5 else Color("#ffd23e")


func _attack_begin() -> void:
	_gun_mat.emission_energy_multiplier = 0.0
	_ticker.modulate = Color("#ffd23e")
	fire_cd = float(FL()["fire_every"])
	var origin: Vector3 = global_position + Vector3(0, -0.4, 0)
	var aim: Vector3 = (target_center() + Vector3(0, 0.3, 0) - origin).normalized()
	EnemyProjectile.fire(get_parent(), origin, aim * float(FL()["shot_speed"]), float(def["dmg"]) * out_mult() * surge_damage_mult(),
		Color("#ff4d9d"), 0.18, 3.5, {"source": self})
	shots_fired += 1


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	return state_t >= 0.15


func _on_attack_cancelled() -> void:
	_gun_mat.emission_energy_multiplier = 0.0


func _anim(delta: float) -> void:
	_rotor.rotation.y += delta * 30.0
