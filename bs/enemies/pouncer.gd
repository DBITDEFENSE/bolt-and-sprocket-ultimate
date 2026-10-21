class_name Pouncer
extends EnemyBase
## Shared `pounce` module (BS_ENEMIES §1.1, index.html:6487-6512): within range_max (not under range_min) a
## pouncer takes a melee token, telegraphs (0.45 s, raised from the source's 0.32 s), then leaps in a 1.5 m arc
## over leap_time. A dash through the leap makes it miss. Contact cooldown 1.4 s.
## Subclass hooks: _approach(dt) (how it closes in), _pounce_kind() -> StringName (the telegraph id),
## _pounce_landed(hit_landed: bool), _pounce_pose(k) (telegraph pose, k 0..1).

var pounces: int = 0
var pounce_hits: int = 0
var _from: Vector3
var _to: Vector3
var _leap_t: float = 0.0
var _landed_hit: bool = false
var retreat_t: float = 0.0


func P() -> Dictionary:
	return def["pounce"]


func _on_activate() -> void:
	pounces = 0
	pounce_hits = 0
	retreat_t = 0.0
	_pouncer_activate()


func _pouncer_activate() -> void:
	pass


func _position_update(dt: float) -> void:
	if retreat_t > 0.0:
		retreat_t -= dt
		var away: Vector3 = global_position - target_pos()
		away.y = 0.0
		steer_toward(global_position + away.normalized() * 3.0, speed * 0.6)
		return
	var d: float = flat_dist_to_target()
	var ready_: bool = contact_cd <= 0.0 and can_attack() and target_alive()
	if ready_ and d < float(P()["range_max"]) and d > float(P()["range_min"]):
		if AttackTokens.request_melee(self, target_onscreen()):
			var k: StringName = _pounce_kind()
			begin_telegraph(k, float(telegraph_def(k).get("dur", 0.45)))
			return
	if ready_ and d <= float(P()["range_min"]) + 0.2:
		var back: Vector3 = global_position - target_pos()            # too close to leap: hop back into range
		back.y = 0.0
		if back.length_squared() < 0.01:
			back = -forward()
		steer_toward(global_position + back.normalized() * 3.0, speed * 0.7)
		face(-back, dt)
		return
	_approach(dt)


func _approach(_dt: float) -> void:
	if flat_dist_to_target() > 1.2:
		steer_toward(target_pos(), speed)
	else:
		desired_vel = Vector3.ZERO


func _pounce_kind() -> StringName:
	return &"pounce"


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_pounce_pose(k)
	face(target_pos() - global_position, dt, 12.0)


func _pounce_pose(_k: float) -> void:
	visual.scale.y = 0.75


func _attack_begin() -> void:
	visual.scale = _base_scale
	visual.rotation.x = 0.0
	_from = global_position
	var tp: Vector3 = target_pos()
	_to = Vector3(tp.x, global_position.y, tp.z)
	_leap_t = 0.0
	_landed_hit = false
	pounces += 1


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
			if hurt_target(float(def["dmg"]), float(P()["knock"])) or not target.is_in_group(&"player"):
				pounce_hits += 1
			_landed_hit = true
	if k >= 1.0:
		contact_cd = maxf(contact_cd, float(P()["after_cd"]))
		_pounce_landed(_landed_hit)
		return true
	return false


func _pounce_landed(_hit_landed: bool) -> void:
	pass


func _recover_update(_dt: float) -> bool:
	desired_vel = Vector3.ZERO
	return state_t >= float(P()["recover"])


func _on_attack_cancelled() -> void:
	visual.scale = _base_scale
	visual.rotation.x = 0.0
