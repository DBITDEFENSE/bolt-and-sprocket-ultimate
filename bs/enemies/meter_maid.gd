class_name MeterMaid
extends Pouncer
## Meter Maid — ticketing pouncer (BS_ENEMIES §3.3; makeMeterMaid index.html:6058). 34 HP / 6.2 / 10 / 7 bolts.
## Chases and pounces (10 damage). If Bolt has stood still (moved under 1 m) for 1.5 s while she's within 8 m,
## her pounce becomes a BOOT CLAMP: 10 damage and Bolt can't move (he can still aim and shoot) for 1.0 s, or
## until he mashes free (0.6 s). Telegraph: clamp raised overhead, pen click, ticket-printer chatter, amber
## badge light, 0.45 s. A slam scatters her; finishers stun her out of the telegraph (the base rule).
## Elite (Double Parked, hi-vis rim): a clamp also tickets every enemy within 6 m of Bolt: +20% damage for 3 s.

var still_t: float = 0.0
var clamps: int = 0
var _anchor: Vector3 = Vector3.INF
var _clamp_pounce: bool = false
var _head: Node3D
var _badge_mat: StandardMaterial3D
var _clamp_arm: Node3D
var _legs: Array[Node3D] = []


func CL() -> Dictionary:
	return def["clamp"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#2e5aa8"))))
	flash_mats.append(body)
	EnemyFx.box(visual, Vector3(0.5, 0.9, 0.36), Vector3(0, 0.75, 0), body)
	_badge_mat = EnemyFx.mat(Color("#ffd23e"), Color("#ffb02e"), 0.6)
	EnemyFx.box(visual, Vector3(0.4, 0.2, 0.04), Vector3(0, 1.0, 0.19), _badge_mat)                         # hi-vis badge
	_head = Node3D.new()
	_head.position = Vector3(0, 1.35, 0)
	visual.add_child(_head)
	EnemyFx.cyl(_head, 0.2, 0.24, Vector3.ZERO, body)
	EnemyFx.cyl(_head, 0.26, 0.05, Vector3(0, 0.15, 0.04), EnemyFx.mat(Color("#1c2333")))                    # flat cap brim
	EnemyFx.box(_head, Vector3(0.26, 0.06, 0.04), Vector3(0, 0.02, 0.2), EnemyFx.mat(Color("#ff5d5d"), Color("#ff2222"), 1.6))
	_clamp_arm = Node3D.new()
	_clamp_arm.position = Vector3(0.34, 1.05, 0.05)
	visual.add_child(_clamp_arm)
	EnemyFx.box(_clamp_arm, Vector3(0.12, 0.45, 0.12), Vector3(0, -0.2, 0), body)
	EnemyFx.torus(_clamp_arm, 0.1, 0.2, Vector3(0, -0.48, 0.1), EnemyFx.mat(Color("#ff7a1a"))).rotation.x = PI / 2   # orange boot clamp
	for sx: float in [-1.0, 1.0]:
		var l: Node3D = Node3D.new()
		l.position = Vector3(sx * 0.16, 0.34, 0)
		visual.add_child(l)
		EnemyFx.box(l, Vector3(0.14, 0.34, 0.14), Vector3(0, -0.17, 0), EnemyFx.mat(Color("#1c2333")))
		_legs.append(l)


func _pouncer_activate() -> void:
	still_t = 0.0
	clamps = 0
	_anchor = Vector3.INF
	_clamp_pounce = false


func _timers(delta: float) -> void:
	super._timers(delta)
	if target == null or not is_instance_valid(target):
		return
	var p: Vector3 = target_pos()
	if _anchor == Vector3.INF or Vector2(p.x - _anchor.x, p.z - _anchor.z).length() > float(CL()["still_move"]):
		_anchor = p
		still_t = 0.0
	else:
		still_t += delta


func bolt_loitering() -> bool:
	return still_t >= float(CL()["still_time"]) and flat_dist_to_target() < float(CL()["range"])


func _pounce_kind() -> StringName:
	_clamp_pounce = bolt_loitering()
	return &"clamp" if _clamp_pounce else &"pounce"


func _pounce_pose(k: float) -> void:
	_clamp_arm.rotation.x = -2.6 * minf(k * 2.0, 1.0)                 # clamp raised overhead
	_badge_mat.emission_energy_multiplier = 0.6 + k * 4.0
	visual.scale.y = 0.85


func _pounce_landed(hit_landed: bool) -> void:
	_clamp_arm.rotation.x = 0.0
	if not (hit_landed and _clamp_pounce and target != null and target.is_in_group(&"player")):
		return
	clamps += 1
	var dbf: PlayerDebuffs = PlayerDebuffs.of(target)
	if dbf != null:
		dbf.clamp_for(float(CL()["time"]), float(CL()["mash"]))
	if elite:
		for n: Node in get_tree().get_nodes_in_group(&"enemies"):
			var o: EnemyBase = n as EnemyBase
			if o != null and o.is_alive() and o.global_position.distance_to(target_pos()) < float(def["elite"]["radius"]):
				o.status.apply(&"double_parked", float(def["elite"]["time"]))


func _on_attack_cancelled() -> void:
	super._on_attack_cancelled()
	_clamp_arm.rotation.x = 0.0


func _on_hurt(hit: Combat.Hit, _amount: float, _crit: bool) -> void:
	if hit.is_slam and is_alive():
		var away: Vector3 = global_position - target_pos()
		away.y = 0.0
		knock_vel += away.normalized() * float(def["slam_scatter"])
		stagger(float(def["slam_stun"]))


func _anim(_delta: float) -> void:
	var hv: float = Vector2(velocity.x, velocity.z).length()
	var sk: float = sin(t * (10.0 + hv * 2.0)) * (0.5 if hv > 0.3 else 0.1)
	if _legs.size() == 2:
		_legs[0].rotation.x = sk
		_legs[1].rotation.x = -sk
	if state != State.TELEGRAPH:
		_badge_mat.emission_energy_multiplier = 0.6 + (1.5 if bolt_loitering() else 0.0)
