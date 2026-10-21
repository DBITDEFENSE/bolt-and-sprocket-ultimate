class_name LifeguardBot
extends EnemyBase
## Lifeguard Bot — heavy lobber (BS_ENEMIES §3.2; makeLifeguardBot index.html:5960, lob :6571-6582, contact :6563).
## 85 HP / 2.3 m/s / 14 contact / 11 bolts, heavy (no launch or clump; 2.0 frost to freeze; thumps the ground).
## Lumbers toward Bolt. At 4-16 m, every 3.4 s it LOBS an exploding flotation ring (an arc with gravity 13;
## 12 damage, r2.6 blast). Telegraph: arm fully back, a sustained whistle (2100 -> 2350 Hz, extended from the
## source's 0.16 s chirp), the ring glows red, 0.5 s, plus a landing decal for the whole flight.
## Remake: the ring leaves a 3 s "NO RUNNING" puddle (r2.6) that SLOWS Bolt by 30%.
## Elite (Adult Swim, red rim): lobs 3 rings in a fan.

var lobs: int = 0
var puddles: int = 0
var _land_at: Array[Vector3] = []
var _arm: Node3D
var _ring_mat: StandardMaterial3D
var _thump_t: float = 0.0


func LB() -> Dictionary:
	return def["lob"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#e8e0d4"))))
	flash_mats.append(body)
	var red: StandardMaterial3D = EnemyFx.mat(Color("#d42f2f"))
	EnemyFx.cyl(visual, 0.62, 1.2, Vector3(0, 0.95, 0), body, 0.55)                                          # stocky barrel torso
	EnemyFx.box(visual, Vector3(0.34, 0.34, 0.1), Vector3(0, 1.1, 0.58), red)
	EnemyFx.box(visual, Vector3(0.12, 0.5, 0.09), Vector3(0, 1.1, 0.58), red)
	var head: Node3D = Node3D.new()
	head.position.y = 1.8
	visual.add_child(head)
	EnemyFx.sphere(head, 0.26, Vector3.ZERO, body, 0.46)
	EnemyFx.box(head, Vector3(0.56, 0.08, 0.56), Vector3(0, 0.2, 0.04), red)                                 # red visor cap
	EnemyFx.cyl(head, 0.05, 0.14, Vector3(0, -0.06, 0.26), EnemyFx.mat(Color("#ffd23e"))).rotation.x = PI / 2   # yellow whistle
	EnemyFx.box(head, Vector3(0.3, 0.07, 0.05), Vector3(0, 0.04, 0.22), EnemyFx.mat(Color("#1c2333"), Color("#3ee6ff"), 1.0))
	_arm = Node3D.new()
	_arm.position = Vector3(0.7, 1.45, 0)
	visual.add_child(_arm)
	EnemyFx.box(_arm, Vector3(0.18, 0.7, 0.18), Vector3(0, -0.35, 0), body)
	_ring_mat = EnemyFx.mat(Color("#d42f2f"), Color("#ff2222"), 0.0)
	_ring_mat.emission_enabled = true
	for i: int in 3:
		var fr: MeshInstance3D = EnemyFx.torus(_arm, 0.12, 0.24, Vector3(0, -0.2 - i * 0.17, 0), _ring_mat if i % 2 == 0 else EnemyFx.mat(Color("#f2ebe0")))
		fr.rotation.x = 0.0
	for sx: float in [-0.3, 0.3]:
		EnemyFx.box(visual, Vector3(0.3, 0.35, 0.42), Vector3(sx, 0.17, 0.04), EnemyFx.mat(Color("#9a9288")))      # stumpy feet


func _on_activate() -> void:
	lobs = 0
	puddles = 0
	fire_cd = float(LB()["first_delay"])
	_thump_t = 0.0


func _position_update(dt: float) -> void:
	var d: float = flat_dist_to_target()
	# contact damage (non-pouncer heavy): 14 on touch, 1.1 s cooldown
	if d < radius + 1.0 and contact_cd <= 0.0 and target_alive():
		contact_cd = float(G["contact_cd"])
		hurt_target(float(def["dmg"]), 7.0)
	if d > float(LB()["min"]) and d < float(LB()["max"]) and fire_cd <= 0.0 and can_attack() and target_alive():
		if AttackTokens.request_ranged():
			_plan_landing()
			begin_telegraph(&"lob", float(telegraph_def(&"lob").get("dur", 0.5)))
			return
		fire_cd = 0.5
	if d > 1.4:
		steer_toward(target_pos(), speed)
	else:
		desired_vel = Vector3.ZERO
	_thump_t -= dt
	if _thump_t <= 0.0 and desired_vel.length_squared() > 0.1:
		_thump_t = float(def["thump_every"])
		telegraphed.emit(&"thump", &"lifeguard_thump", 0.0)


func _plan_landing() -> void:
	_land_at.clear()
	var tp: Vector3 = target_pos()
	_land_at.append(tp)
	if elite:
		var spread: float = deg_to_rad(float(def["elite"]["fan_deg"]))
		var rel: Vector3 = tp - global_position
		rel.y = 0.0
		_land_at.append(global_position + rel.rotated(Vector3.UP, spread) + Vector3(0, tp.y - global_position.y, 0))
		_land_at.append(global_position + rel.rotated(Vector3.UP, -spread) + Vector3(0, tp.y - global_position.y, 0))
	var flight: float = _flight_time(tp)
	for p: Vector3 in _land_at:
		EnemyFx.ring(get_parent(), p, float(LB()["blast_r"]), float(telegraph_def(&"lob").get("dur", 0.5)) + flight, Color("#d42f2f"))


func _flight_time(p: Vector3) -> float:
	var d: float = Vector2(p.x - global_position.x, p.z - global_position.z).length()
	return clampf(d / float(LB()["h_speed"]), float(LB()["flight_min"]), float(LB()["flight_max"]))


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_arm.rotation.x = -2.4 * minf(1.0, k * 1.6)                          # arm fully back
	_ring_mat.emission_energy_multiplier = k * 4.0
	face(target_pos() - global_position, dt, 6.0)


func _attack_begin() -> void:
	_ring_mat.emission_energy_multiplier = 0.0
	fire_cd = float(LB()["every"])
	var origin: Vector3 = global_position + Vector3(0, 1.6, 0) + forward() * 0.4
	var g: float = float(LB()["gravity"])
	for p: Vector3 in _land_at:
		var T: float = _flight_time(p)
		var dxz: Vector3 = p - origin
		var v: Vector3 = Vector3(dxz.x / T, (p.y - origin.y + 0.5 * g * T * T) / T, dxz.z / T)
		EnemyProjectile.fire(get_parent(), origin, v, float(LB()["dmg"]) * out_mult(), Color("#d42f2f"), 0.3, T + 1.5,
			{"grav": g, "boom_r": float(LB()["blast_r"]), "source": self, "kind": &"flotation_ring", "on_land": _on_ring_land, "scale": Vector3(1.5, 0.5, 1.5)})
	lobs += 1


func _on_ring_land(pos: Vector3, _hit_player: bool) -> void:
	if get_parent() == null:
		return
	puddles += 1
	SlowPuddle.spawn(get_parent(), pos, float(LB()["blast_r"]), float(LB()["puddle_time"]), float(LB()["puddle_slow"]), &"lifeguard_puddle")


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	_arm.rotation.x = lerpf(_arm.rotation.x, 0.0, 0.2)
	return state_t >= 0.35


func _on_attack_cancelled() -> void:
	_arm.rotation.x = 0.0
	_ring_mat.emission_energy_multiplier = 0.0


func _anim(_delta: float) -> void:
	if state != State.TELEGRAPH:
		_arm.rotation.x = lerpf(_arm.rotation.x, 0.0, 0.1)
	var hv: float = Vector2(velocity.x, velocity.z).length()
	visual.rotation.z = sin(t * 5.0) * 0.06 * minf(1.0, hv)
