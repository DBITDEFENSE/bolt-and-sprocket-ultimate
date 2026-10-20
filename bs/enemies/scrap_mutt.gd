class_name ScrapMutt
extends EnemyBase
## Scrap Mutt — pack chaser (BS_ENEMIES §3.1; makeScrapMutt index.html:5839, pounce :6487-6512).
## Packs circle Bolt at 5-7 m. Holders of a melee token (the leaders) close in and POUNCE: a 0.45 s
## crouch telegraph (body squashed to 72%, eye flicker, growl), then a 0.38 s leap in a 1.5 m arc
## (10 damage, 1.4 s contact cooldown). The rest FEINT: a 0.25 s half-lunge with no damage.
## A lone mutt chases and pounces straight in. A finisher stagger scatters the pack for 1.5 s.
## Elite (Alpha Lease): a missed pounce chains straight into a second one.

var _orbit: float = 0.0
var _orbit_dir: float = 1.0
var _feint_cd: float = 2.0
var _feint_t: float = 0.0
var scatter_t: float = 0.0
var _from: Vector3
var _to: Vector3
var _leap_t: float = 0.0
var _landed_hit: bool = false
var _chained: bool = false
var feints: int = 0
var pounces: int = 0
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _eye_mat: StandardMaterial3D


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#9c5a2e"))))
	flash_mats.append(body)
	var dark: StandardMaterial3D = EnemyFx.mat(Color("#50241a"))
	EnemyFx.box(visual, Vector3(0.55, 0.4, 0.95), Vector3(0, 0.42, 0), body)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0.55)
	visual.add_child(_head)
	EnemyFx.box(_head, Vector3(0.4, 0.32, 0.4), Vector3.ZERO, body)
	EnemyFx.box(_head, Vector3(0.34, 0.12, 0.34), Vector3(0, -0.14, 0.14), dark)          # underbite
	EnemyFx.box(_head, Vector3(0.26, 0.07, 0.05), Vector3(0, -0.07, 0.3), EnemyFx.mat(Color("#d8dee9")))
	_eye_mat = EnemyFx.mat(Color("#ffd23e"), Color("#ffd23e"), 2.0)
	EnemyFx.sphere(_head, 0.085, Vector3(0, 0.08, 0.21), _eye_mat)
	var teal: StandardMaterial3D = EnemyFx.mat(Color("#3aa8a0"))
	EnemyFx.cyl(_head, 0.07, 0.22, Vector3(-0.14, 0.26, 0), teal, 0.0)
	EnemyFx.cyl(_head, 0.07, 0.22, Vector3(0.14, 0.26, 0), teal, 0.0)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.6, -0.52)
	visual.add_child(_tail)
	EnemyFx.torus(_tail, 0.08, 0.16, Vector3.ZERO, EnemyFx.mat(Color("#232323"))).rotation.x = PI / 2
	for lp: Vector2 in [Vector2(0.24, 0.32), Vector2(-0.24, 0.32), Vector2(0.24, -0.32), Vector2(-0.24, -0.32)]:
		var leg: Node3D = Node3D.new()
		leg.position = Vector3(lp.x, 0.34, lp.y)
		visual.add_child(leg)
		EnemyFx.box(leg, Vector3(0.12, 0.34, 0.12), Vector3(0, -0.17, 0), dark)
		_legs.append(leg)


func _on_activate() -> void:
	scatter_t = 0.0
	_feint_cd = randf_range(1.0, 2.5)
	_feint_t = 0.0
	_orbit_dir = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_chained = false
	feints = 0
	pounces = 0


func P() -> Dictionary:
	return def["pounce"]


func K() -> Dictionary:
	return def["pack"]


## Living, aggro'd mutts within the pack radius hunting the same target (self included).
func pack() -> Array[ScrapMutt]:
	var out: Array[ScrapMutt] = []
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var m: ScrapMutt = n as ScrapMutt
		if m != null and m.is_alive() and m.aggro and m.target == target \
				and m.global_position.distance_to(global_position) < float(K()["radius"]):
			out.append(m)
	return out


func _position_update(dt: float) -> void:
	var d: float = flat_dist_to_target()
	var to_t: Vector3 = target_pos() - global_position
	to_t.y = 0.0
	if scatter_t > 0.0:
		scatter_t -= dt
		steer_toward(global_position - to_t.normalized() * 4.0, speed * 1.2)
		return
	var pk: Array[ScrapMutt] = pack()
	var lone: bool = pk.size() <= 1
	var ready_: bool = contact_cd <= 0.0 and can_attack() and target_alive()
	var leader: bool = AttackTokens.holds_melee(self)
	if ready_ and not leader and (lone or d < float(K()["circle_max"]) + 1.5):
		leader = AttackTokens.request_melee(self, target_onscreen())
	if leader and ready_:
		if d < float(P()["range_max"]) and d > float(P()["range_min"]):
			_start_pounce()
			return
		steer_toward(target_pos(), speed)
		return
	if lone:
		if d > 1.2:
			steer_toward(target_pos(), speed)
		else:
			desired_vel = Vector3.ZERO
		return
	# circle and feint
	if _feint_t > 0.0:
		_feint_t -= dt
		if can_move():
			desired_vel = to_t.normalized() * float(K()["feint_speed"]) * move_mult()
			face(to_t, dt)
		if _feint_t <= 0.0:
			desired_vel = Vector3.ZERO
		return
	_orbit += float(K()["orbit_speed"]) * _orbit_dir * dt
	var cr: float = (float(K()["circle_min"]) + float(K()["circle_max"])) * 0.5
	if is_zero_approx(_orbit) or state_t < dt * 1.5:
		_orbit = atan2(-to_t.z, -to_t.x)
	var goal: Vector3 = target_pos() + Vector3(cos(_orbit), 0, sin(_orbit)) * cr
	goal += _separation()
	steer_toward(goal, speed)
	face(to_t, dt)
	_feint_cd -= dt
	if _feint_cd <= 0.0 and d < float(K()["circle_max"]) + 0.5:
		var fe: Array = K()["feint_every"]
		_feint_cd = randf_range(float(fe[0]), float(fe[1]))
		_feint_t = float(K()["feint_time"])
		feints += 1
		telegraphed.emit(&"feint", &"mutt_yip", float(K()["feint_time"]))


func _separation() -> Vector3:
	var push: Vector3 = Vector3.ZERO
	var sep: float = float(K()["separation"])
	for m: ScrapMutt in pack():
		if m == self:
			continue
		var dd: Vector3 = global_position - m.global_position
		dd.y = 0.0
		if dd.length() < sep and dd.length() > 0.001:
			push += dd.normalized() * (sep - dd.length()) * 2.0
	return push


func _start_pounce() -> void:
	begin_telegraph(&"pounce", float(telegraph_def(&"pounce").get("dur", 0.45)) if not _chained else 0.4)


func _telegraph_update(dt: float) -> void:
	visual.scale.y = 0.72 + sin(t * 30.0) * 0.05
	if _eye_mat != null:
		_eye_mat.emission_energy_multiplier = 4.0 + sin(t * 40.0) * 1.5
	face(target_pos() - global_position, dt, 12.0)


func _attack_begin() -> void:
	visual.scale = _base_scale
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
			hurt_target(float(def["dmg"]), float(P()["knock"]))
			_landed_hit = true
	if k >= 1.0:
		contact_cd = maxf(contact_cd, float(P()["after_cd"]))
		if elite and not _landed_hit and not _chained and target_alive():
			_chained = true                  # Alpha Lease: chain into a second pounce
			contact_cd = 0.0
			_start_pounce()
			return false
		_chained = false
		return true
	return false


func _recover_update(dt: float) -> bool:
	desired_vel = Vector3.ZERO
	if state_t > float(P()["recover"]) * 0.5:
		var away: Vector3 = global_position - target_pos()
		away.y = 0.0
		steer_toward(global_position + away.normalized() * 3.0, speed)
	var _u: float = dt
	return state_t >= float(P()["recover"])


func _on_attack_cancelled() -> void:
	visual.scale = _base_scale
	_chained = false


func _on_hurt(hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	if hit.status.has("stun"):
		for m: ScrapMutt in pack():
			m.scatter_t = float(K()["scatter_time"])


func _anim(_delta: float) -> void:
	var hv: float = Vector2(velocity.x, velocity.z).length()
	var sk: float = sin(t * (10.0 + hv * 2.2)) * (0.4 if hv > 0.3 else 0.12)
	for i: int in _legs.size():
		_legs[i].rotation.x = sk if (i == 0 or i == 3) else -sk
	if _tail != null:
		_tail.rotation.z = sin(t * (9.0 if aggro else 2.5)) * 0.5
	if _eye_mat != null and state != State.TELEGRAPH:
		_eye_mat.emission_energy_multiplier = 2.0
