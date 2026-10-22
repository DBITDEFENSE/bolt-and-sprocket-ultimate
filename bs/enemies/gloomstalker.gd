class_name Gloomstalker
extends EnemyBase
## Gloomstalker — cloaked pouncer (BS_ENEMIES §3.5). 32 HP / 6.0 / 12 / 7 bolts. A lean moss-dark quadruped.
## CLOAKED (90% transparent, a heat-haze shimmer) while it moves more than `cloak_range` (6 m) from Bolt; it
## DECLOAKS to pounce (a 0.5 s crouch telegraph: the shimmer drops, two green eye-points light, a wet clicking
## purr), leaps 0.38 s in an arc for 12 damage, and re-cloaks `recloak_after` (2 s) after the pounce. Any damage
## decloaks it for `hurt_reveal` (3 s). The Fine Print's MARKED status reveals it too (status "marked").
## Elite (Ghost Account, bog-green rim visible through the cloak): on its first pounce it leaves a decoy shimmer
## that pounces for 0 damage (an EnemyFx chunk burst and a fake ring), then the real one comes from the side.

var cloaked: bool = false
var reveal_t: float = 0.0
var pounces: int = 0
var cloak_changes: int = 0
var _from: Vector3
var _to: Vector3
var _leap_t: float = 0.0
var _landed_hit: bool = false
var _recloak_t: float = 0.0
var _decoy_done: bool = false
var _mats: Array[StandardMaterial3D] = []
var _eye_mat: StandardMaterial3D
var _head: Node3D
var _legs: Array[Node3D] = []


func C() -> Dictionary:
	return def["cloak"]


func P() -> Dictionary:
	return def["pounce"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#243a2a"))))
	body.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mats.append(body)
	var dark: StandardMaterial3D = EnemyFx.mat(Color("#141f18"))
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats = [body, dark]
	EnemyFx.box(visual, Vector3(0.5, 0.36, 1.2), Vector3(0, 0.46, 0), body)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0.7)
	visual.add_child(_head)
	EnemyFx.box(_head, Vector3(0.32, 0.26, 0.7), Vector3(0, 0, 0.1), body)          # the long head
	_eye_mat = EnemyFx.mat(Color("#5affc8"), Color("#5affc8"), 0.0)
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	EnemyFx.sphere(_head, 0.06, Vector3(-0.1, 0.08, 0.3), _eye_mat)
	EnemyFx.sphere(_head, 0.06, Vector3(0.1, 0.08, 0.3), _eye_mat)
	for lp: Vector2 in [Vector2(0.2, 0.42), Vector2(-0.2, 0.42), Vector2(0.2, -0.42), Vector2(-0.2, -0.42)]:
		var leg: Node3D = Node3D.new()
		leg.position = Vector3(lp.x, 0.34, lp.y)
		visual.add_child(leg)
		EnemyFx.box(leg, Vector3(0.1, 0.36, 0.1), Vector3(0, -0.18, 0), dark)
		_legs.append(leg)
	EnemyFx.box(visual, Vector3(0.08, 0.08, 0.6), Vector3(0, 0.62, -0.85), dark)      # tail


func _on_activate() -> void:
	cloaked = false
	reveal_t = 0.0
	pounces = 0
	cloak_changes = 0
	_recloak_t = 0.0
	_decoy_done = false
	_set_cloak(true)


func _set_cloak(on: bool) -> void:
	if cloaked == on:
		return
	cloaked = on
	cloak_changes += 1
	var a: float = (1.0 - float(C().get("transparency", 0.9))) if on else 1.0
	for m: StandardMaterial3D in _mats:
		m.albedo_color.a = a
	if _eye_mat != null:
		_eye_mat.albedo_color.a = 1.0 if not on else 0.15
		_eye_mat.emission_energy_multiplier = 0.0 if on else 2.0
	if _rim_mat != null and elite:
		_rim_mat.albedo_color.a = 1.0          # the elite's rim shows through the cloak


func is_cloaked() -> bool:
	return cloaked


func _timers(delta: float) -> void:
	super._timers(delta)
	reveal_t -= delta
	_recloak_t -= delta


## Cloak rules: revealed by damage, by MARKED, while winding up / pouncing / recovering, and near Bolt.
func _update_cloak() -> void:
	var want: bool = true
	if reveal_t > 0.0 or status.has(&"marked") or _recloak_t > 0.0:
		want = false
	elif state == State.TELEGRAPH or state == State.ATTACK or state == State.RECOVER or state == State.STAGGER:
		want = false
	elif target != null and flat_dist_to_target() < float(C().get("range", 6.0)):
		want = false
	_set_cloak(want)


func _idle_update(dt: float) -> void:
	super._idle_update(dt)
	_update_cloak()


func _position_update(dt: float) -> void:
	_update_cloak()
	var d: float = flat_dist_to_target()
	if contact_cd <= 0.0 and can_attack() and target_alive() and d < float(P()["range_max"]) and d > float(P()["range_min"]):
		if AttackTokens.request_melee(self, target_onscreen()):
			_set_cloak(false)
			begin_telegraph(&"pounce", float(telegraph_def(&"pounce").get("dur", 0.5)))
			return
	steer_toward(target_pos(), speed)
	var _u: float = dt


func _telegraph_update(dt: float) -> void:
	visual.scale.y = 0.72 + sin(t * 30.0) * 0.05
	if _eye_mat != null:
		_eye_mat.emission_energy_multiplier = 3.0 + sin(t * 40.0) * 1.5
	face(target_pos() - global_position, dt, 12.0)


func _attack_begin() -> void:
	visual.scale = _base_scale
	_from = global_position
	var tp: Vector3 = target_pos()
	_to = Vector3(tp.x, global_position.y, tp.z)
	_leap_t = 0.0
	_landed_hit = false
	pounces += 1
	if elite and not _decoy_done and get_parent() != null:
		# Ghost Account: a decoy shimmer pounces from where it stood (0 damage) and bursts
		_decoy_done = true
		EnemyFx.chunks(get_parent(), get_center(), Color("#2a4a3a"), 0.8, 3, 4)
		EnemyFx.ring(get_parent(), _to, 1.2, 0.4, Color("#2a4a3a"))
		telegraphed.emit(&"ghost_decoy", &"gloom_shimmer", 0.0)


func _attack_update(dt: float) -> bool:
	var leap: float = float(P()["leap_time"])
	_leap_t += dt
	var k: float = clampf(_leap_t / leap, 0.0, 1.0)
	var p: Vector3 = _from.lerp(_to, k)
	p.y = _from.y + sin(k * PI) * float(P()["arc_height"])
	override_point = p
	if not _landed_hit and contact_cd <= 0.0 and target_alive() \
			and get_center().distance_to(target_center()) < radius + float(P()["hit_reach"]):
		if not target_dodging():
			contact_cd = float(P()["contact_cd"])
			hurt_target(float(def["dmg"]), float(P()["knock"]))
			_landed_hit = true
	if k >= 1.0:
		contact_cd = maxf(contact_cd, float(P()["after_cd"]))
		_recloak_t = float(C().get("recloak_after", 2.0))
		return true
	return false


func _recover_update(dt: float) -> bool:
	desired_vel = Vector3.ZERO
	if state_t > float(P()["recover"]) * 0.5:
		var away: Vector3 = global_position - target_pos()
		away.y = 0.0
		steer_toward(global_position + away.normalized() * 4.0, speed)
	var _u: float = dt
	return state_t >= float(P()["recover"])


func _on_attack_cancelled() -> void:
	visual.scale = _base_scale


func _on_hurt(_hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	reveal_t = float(C().get("hurt_reveal", 3.0))
	_set_cloak(false)


func _anim(_delta: float) -> void:
	var hv: float = Vector2(velocity.x, velocity.z).length()
	var sk: float = sin(t * (10.0 + hv * 2.2)) * (0.4 if hv > 0.3 else 0.1)
	for i: int in _legs.size():
		_legs[i].rotation.x = sk if (i == 0 or i == 3) else -sk
	if _eye_mat != null and state != State.TELEGRAPH:
		_eye_mat.emission_energy_multiplier = 0.0 if cloaked else 2.0
	if cloaked:
		# the heat-haze shimmer: a slow breathing of the faint alpha
		var a: float = (1.0 - float(C().get("transparency", 0.9))) * (0.8 + 0.4 * sin(t * 7.0))
		for m: StandardMaterial3D in _mats:
			m.albedo_color.a = a
