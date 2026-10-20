class_name TinkerTurret
extends EnemyBase
## Tinker Turret — ambush turret (BS_ENEMIES §3.1; makeTinkerTurret index.html:5862, turret :6584-6636).
## HIDDEN under a junk lid (the lid jitters, the periscope pokes out) until Bolt is within 11 m or it's
## hit; RISES for 0.55 s; then tracks within 24 m and fires a 12-damage shot at 11 m/s every 2.2 s
## within 20 m. Each shot telegraphs 0.55 s (barrel lowers, muzzle glows orange, whine).
## Remake: after 3 shots it RELOADS for 1.6 s with its coil exposed (crit x2.5; 3 coil crits kill it).
## LIEN on Bolt: fires 30% faster. Elite (Union Rules): a 3-round spread, reloading every 2 bursts.

var shots: int = 0
var reloading: bool = false
var reload_t: float = 0.0
var coil_crits: int = 0
var shots_fired: int = 0
var _rise: float = 0.0
var _lid: Node3D
var _pop: Node3D
var _head: Node3D
var _barrel: Node3D
var _muzzle_mat: StandardMaterial3D
var _coil: MeshInstance3D
var _coil_mat: StandardMaterial3D
var _hatch: MeshInstance3D


func TU() -> Dictionary:
	return def["turret"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#8a7a42"))))
	flash_mats.append(body)
	_lid = Node3D.new()
	visual.add_child(_lid)
	EnemyFx.sphere(_lid, 0.8, Vector3(0, 0.16, 0), EnemyFx.mat(Color("#7a6a58")), 0.84)
	EnemyFx.box(_lid, Vector3(0.34, 0.16, 0.44), Vector3(0.32, 0.36, 0.1), EnemyFx.mat(Color("#9a8a6a")))
	EnemyFx.cyl(_lid, 0.09, 0.3, Vector3(-0.25, 0.42, -0.2), EnemyFx.mat(Color("#5e6a72")))
	_pop = Node3D.new()
	_pop.position.y = -1.15
	visual.add_child(_pop)
	EnemyFx.cyl(_pop, 0.3, 0.7, Vector3(0, 0.55, 0), body)
	EnemyFx.sphere(_pop, 0.34, Vector3(0, 0.98, 0), body, 0.56)
	_head = Node3D.new()
	_head.position.y = 0.98
	_pop.add_child(_head)
	_barrel = Node3D.new()
	_head.add_child(_barrel)
	EnemyFx.cyl(_barrel, 0.07, 0.72, Vector3(0, 0, 0.42), EnemyFx.mat(Color("#232838"))).rotation.x = PI / 2
	_muzzle_mat = EnemyFx.mat(Color("#ff5d2e"), Color("#ff3300"), 0.0)
	_muzzle_mat.emission_enabled = true
	EnemyFx.cyl(_barrel, 0.09, 0.1, Vector3(0, 0, 0.8), _muzzle_mat).rotation.x = PI / 2
	EnemyFx.cyl(_head, 0.025, 0.55, Vector3(0.2, 0.3, 0), EnemyFx.mat(Color("#3aa8a0")))          # periscope
	EnemyFx.sphere(_head, 0.05, Vector3(0.2, 0.6, 0), EnemyFx.mat(Color("#3aa8a0"), Color("#1a8880"), 1.4))
	_coil_mat = EnemyFx.mat(Color("#ff5d5d"), Color("#ff2222"), 0.4)
	_coil = EnemyFx.torus(_head, 0.06, 0.16, Vector3(0, 0.18, -0.32), _coil_mat)
	_coil.rotation.x = PI / 2
	_hatch = EnemyFx.box(_head, Vector3(0.36, 0.3, 0.06), Vector3(0, 0.18, -0.36), body)


func _on_activate() -> void:
	shots = 0
	reloading = false
	reload_t = 0.0
	coil_crits = 0
	shots_fired = 0
	_rise = 0.0 if not bool(opts.get("revealed", false)) else 1.0
	_pose_rise()


func _initial_state() -> int:
	return State.CHASE if _rise >= 1.0 else State.HIDDEN


func _pose_rise() -> void:
	if _pop == null:
		return
	_pop.position.y = -1.15 * (1.0 - _rise)
	_lid.rotation.z = _rise * 1.15
	_lid.position.x = _rise * 0.7


func _hidden_update(_dt: float) -> void:
	desired_vel = Vector3.ZERO
	_lid.position.y = sin(t * 2.5) * 0.015
	_perceive(_dt)
	if target_alive() and (dist_to_target() < float(def["ambush"]["wake_radius"]) or aggro):
		aggro = true
		telegraphed.emit(&"reveal", &"turret_pop", float(def["ambush"]["rise_time"]))
		_set_state(State.REVEAL)


func _reveal_update(dt: float) -> void:
	_rise = minf(1.0, _rise + dt / float(def["ambush"]["rise_time"]))
	_pose_rise()
	if _rise >= 1.0:
		fire_cd = maxf(fire_cd, 0.8)
		_set_state(State.CHASE)


func fire_interval() -> float:
	var iv: float = float(TU()["fire_every"])
	if target != null and EnemyBase.player_status(target).has(&"lien") and target.is_in_group(&"player"):
		iv /= float(S["lien"]["turret_rate_mult"])
	return iv


func reload_every() -> int:
	if elite:
		return int(def["elite"]["bursts_per_reload"])
	return int(TU()["shots_per_reload"])


func _position_update(dt: float) -> void:
	desired_vel = Vector3.ZERO
	var d: float = dist_to_target()
	if reloading:
		reload_t -= dt * attack_rate()
		if reload_t <= 0.0:
			reloading = false
			shots = 0
			fire_cd = maxf(fire_cd, 0.6)
		return
	if d < float(TU()["track_radius"]) and target_alive():
		var to: Vector3 = target_pos() - global_position
		face(to, dt, float(TU()["turn_rate"]))
		var tele: float = float(telegraph_def(&"shot").get("dur", 0.55))
		if d < float(TU()["fire_radius"]) and fire_cd <= tele and can_attack():
			if AttackTokens.request_ranged():
				begin_telegraph(&"shot", tele, -1.0, Vector3.INF, false)
			else:
				fire_cd = tele + 0.15        # wait for a token
	else:
		rotation.y += cos(t * 0.6) * dt * 0.7     # idle sweep


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_muzzle_mat.emission_energy_multiplier = k * 3.3
	_barrel.rotation.x = k * 0.12                    # barrel lowers
	if target_alive():
		face(target_pos() - global_position, dt, float(TU()["turn_rate"]))


func _attack_begin() -> void:
	_muzzle_mat.emission_energy_multiplier = 0.0
	_barrel.rotation.x = 0.0
	fire_cd = fire_interval()
	var f: Vector3 = forward()
	var origin: Vector3 = global_position + Vector3(0, height * 0.63, 0) + f * 1.0
	var aim: Vector3 = (target_center() + Vector3(0, 0.3, 0) - origin).normalized()
	var spd: float = float(TU()["shot_speed"])
	var c: Color = EnemyFx.col(str(TU()["shot_color"]))
	var dirs: Array[Vector3] = [aim]
	if elite:
		var sp: float = deg_to_rad(float(def["elite"]["spread_deg"]))
		dirs = [aim.rotated(Vector3.UP, -sp), aim, aim.rotated(Vector3.UP, sp)]
	for dv: Vector3 in dirs:
		EnemyProjectile.fire(get_parent(), origin, dv * spd, float(def["dmg"]) * dmg_mult, c, float(TU()["shot_size"]), 4.0, {"source": self})
	shots_fired += 1
	shots += 1
	if shots >= reload_every():
		reloading = true
		reload_t = float(TU()["reload_time"])
		telegraphed.emit(&"reload", &"turret_reload", reload_t)


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	return state_t >= 0.1


func _on_attack_cancelled() -> void:
	_muzzle_mat.emission_energy_multiplier = 0.0
	_barrel.rotation.x = 0.0


func weak_point_exposed() -> bool:
	return reloading and _rise >= 1.0


func _weak_point_pos() -> Vector3:
	return _coil.global_position if _coil != null else get_center()


func _on_hurt(_hit: Combat.Hit, _amount: float, crit: bool) -> void:
	if crit and weak_point_exposed():
		coil_crits += 1
		if coil_crits >= int(def["weak_point"]["breaks_after"]) and hp > 0.0:
			hp = 0.0                        # the coil breaks: take_damage finishes it


func _anim(_delta: float) -> void:
	var open: bool = weak_point_exposed()
	_hatch.visible = not open
	_coil_mat.emission_energy_multiplier = (2.0 + sin(t * 6.0) * 0.8) if open else 0.4
