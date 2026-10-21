class_name Ambassadog
extends Pouncer
## Ambassadog — fast polite pouncer (BS_ENEMIES §3.2; makeAmbassadog index.html:5915, pounce :6487-6512).
## 26 HP / 5.6 m/s / 9 dmg / 6 bolts. Runs a wide arc to flank (it comes in from the side or from behind the
## camera when it can), then BOWS before it pounces: a formal bow with a head dip, a two-note "ding-dong"
## chime and a pink visor glow for 0.45 s. After a pounce that connects it hands Bolt a "loyalty card"
## (an on-screen sticker for 1 s) and trots back for a moment.
## Elite (Referral Bonus, pink rim): when it dies, the nearest Ambassadog gets +50% speed for 5 s.

var cards_given: int = 0
var _side: float = 1.0
var _head: Node3D
var _visor_mat: StandardMaterial3D
var _legs: Array[Node3D] = []
var _tail: Node3D


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#d8d0c4"))))
	flash_mats.append(body)
	EnemyFx.box(visual, Vector3(0.46, 0.36, 0.9), Vector3(0, 0.44, 0), body)
	EnemyFx.box(visual, Vector3(0.5, 0.22, 0.52), Vector3(0, 0.58, 0.12), EnemyFx.mat(Color("#ff4d9d")))     # tiny corporate vest
	EnemyFx.box(visual, Vector3(0.1, 0.1, 0.03), Vector3(0.2, 0.62, 0.38), EnemyFx.mat(Color("#3ee6ff"), Color("#0899bb"), 1.0))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.66, 0.55)
	visual.add_child(_head)
	EnemyFx.box(_head, Vector3(0.34, 0.28, 0.36), Vector3.ZERO, body)
	_visor_mat = EnemyFx.mat(Color("#1c2333"), Color("#ff4d9d"), 0.8)
	EnemyFx.box(_head, Vector3(0.3, 0.1, 0.06), Vector3(0, 0.04, 0.19), _visor_mat)                          # visor band
	var pink: StandardMaterial3D = EnemyFx.mat(Color("#ff4d9d"))
	EnemyFx.cyl(_head, 0.06, 0.2, Vector3(-0.12, 0.22, 0), pink, 0.0)                                          # ear cones
	EnemyFx.cyl(_head, 0.06, 0.2, Vector3(0.12, 0.22, 0), pink, 0.0)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.62, -0.5)
	visual.add_child(_tail)
	EnemyFx.cyl(_tail, 0.02, 0.35, Vector3(0, 0.15, 0), EnemyFx.mat(Color("#8b95a8"))).rotation.x = -0.5      # antenna tail
	for lp: Vector2 in [Vector2(0.2, 0.32), Vector2(-0.2, 0.32), Vector2(0.2, -0.32), Vector2(-0.2, -0.32)]:
		var leg: Node3D = Node3D.new()
		leg.position = Vector3(lp.x, 0.34, lp.y)
		visual.add_child(leg)
		EnemyFx.box(leg, Vector3(0.1, 0.36, 0.1), Vector3(0, -0.17, 0), EnemyFx.mat(Color("#9a9288")))
		_legs.append(leg)


func _pouncer_activate() -> void:
	cards_given = 0
	_side = 1.0 if get_instance_id() % 2 == 0 else -1.0


func move_mult() -> float:
	var m: float = super.move_mult()
	if status.has(&"referral"):
		m *= float(def["elite"]["referral_speed_mult"])
	return m


## Flank: aim at a point beside / behind Bolt relative to his camera, tightening as it closes in.
func _approach(_dt: float) -> void:
	var F: Dictionary = def["flank"]
	var d: float = flat_dist_to_target()
	var tp: Vector3 = target_pos()
	if d < float(F["commit"]):
		steer_toward(tp, speed)
		return
	var fwd: Vector3 = _view_forward()
	var right: Vector3 = Vector3(-fwd.z, 0, fwd.x)
	var side_dir: Vector3 = (right * _side - fwd * float(F["behind_bias"])).normalized()
	var goal: Vector3 = tp + side_dir * clampf(d * 0.6, float(F["min_offset"]), float(F["max_offset"]))
	steer_toward(goal, speed)


func _view_forward() -> Vector3:
	if target != null and "camera" in target:
		var c: Node = target.get("camera")
		if c != null and c.has_method("view_dir"):
			var v: Vector3 = c.call("view_dir")
			v.y = 0.0
			if v.length_squared() > 0.001:
				return v.normalized()
	var to: Vector3 = target_pos() - global_position
	to.y = 0.0
	return to.normalized() if to.length_squared() > 0.001 else Vector3.FORWARD


func _pounce_kind() -> StringName:
	return &"bow"


func _pounce_pose(k: float) -> void:
	visual.rotation.x = sin(minf(k * 1.4, 1.0) * PI) * 0.45             # formal bow, head dip
	_head.rotation.x = 0.5 * minf(k * 2.0, 1.0)
	_visor_mat.emission_energy_multiplier = 1.0 + k * 5.0


func _pounce_landed(hit_landed: bool) -> void:
	_head.rotation.x = 0.0
	if hit_landed and target != null and target.is_in_group(&"player"):
		cards_given += 1
		var dbf: PlayerDebuffs = PlayerDebuffs.of(target)
		if dbf != null:
			dbf.sticker(EnemyBase.line_text(str(def["card_line"])), float(def["card_time"]))
		retreat_t = float(def["trot_back"])


func _on_attack_cancelled() -> void:
	super._on_attack_cancelled()
	_head.rotation.x = 0.0


func _on_died(_hit: Combat.Hit) -> void:
	if not elite:
		return
	var best: Ambassadog = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var o: Ambassadog = n as Ambassadog
		if o == null or o == self or not o.is_alive():
			continue
		var dd: float = o.global_position.distance_to(global_position)
		if dd < bd:
			bd = dd
			best = o
	if best != null:
		best.status.apply(&"referral", float(def["elite"]["referral_time"]))


func _anim(_delta: float) -> void:
	var hv: float = Vector2(velocity.x, velocity.z).length()
	var sk: float = sin(t * (11.0 + hv * 2.0)) * (0.45 if hv > 0.3 else 0.1)
	for i: int in _legs.size():
		_legs[i].rotation.x = sk if (i == 0 or i == 3) else -sk
	_tail.rotation.z = sin(t * 12.0) * 0.4
	if state != State.TELEGRAPH:
		_visor_mat.emission_energy_multiplier = 0.8
		if state != State.ATTACK:
			visual.rotation.x = 0.0
