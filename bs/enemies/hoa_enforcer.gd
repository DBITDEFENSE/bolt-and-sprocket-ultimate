class_name HOAEnforcer
extends EnemyBase
## HOA Enforcer — plated turret (BS_ENEMIES §3.3; makeHOAEnforcer index.html:6074; plates in damageEnemy :5268).
## 70 HP / 12 per shot / 11 bolts, heavy, `plated`: a riot shield is its single plate. Fires a 12-damage shot
## every 2.2 s from behind the shield (telegraph: shield braced, head lifts, gavel knock, crest glows red,
## 0.55 s). Every 8 s it issues a VIOLATION (0.8 s): the 4 m ring around a random nearby walkway glows, and if
## Bolt is on that walkway it reverses direction.
##   Walkway contract (Nova Plaza, builder C): nodes in group "nova_walkways" with reverse(); optional
##   contains_point(p: Vector3) -> bool (else: within 4 m of the walkway's origin). With no walkways in range the
##   ring goes under Bolt (it still reads, it just reverses nothing).
## Plates: guns ping off ("ARMORED", signal pinged); each mallet hit strips one plate for 40% chip damage (full
## damage at 5+ MARKED DOWN stacks); Buzzkill pops a plate every 4 blade hits (2 when marked down); pop_plate()
## is public for weapons. `armored` is true while a plate is on. Weak point: the head lamp, exposed above the
## shield while it fires (crits get through the shield).
## Elite (Special Assessment, slate rim): two shields (front and back), and a VIOLATION fines Bolt 10 bolts.

signal pinged
signal plate_popped(left: int)
signal violation_issued(at: Vector3, walkway: Node)

var plates: int = 1
var armored: bool = true
var violations: int = 0
var shots_fired: int = 0
var _buzz_hits: int = 0
var _viol_t: float = 8.0
var _viol_at: Vector3 = Vector3.ZERO
var _viol_walk: Node = null
var _fire_open: float = 0.0
var _head: Node3D
var _lamp: MeshInstance3D
var _crest_mat: StandardMaterial3D
var _muzzle_mat: StandardMaterial3D
var _shields: Array[MeshInstance3D] = []


func TU() -> Dictionary:
	return def["turret"]


func VI() -> Dictionary:
	return def["violation"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#3a4658"))))
	flash_mats.append(body)
	EnemyFx.cyl(visual, 0.7, 0.3, Vector3(0, 0.15, 0), EnemyFx.mat(Color("#2a3242")))                        # bolted base
	for i: int in 6:
		var a: float = TAU * i / 6.0
		EnemyFx.sphere(visual, 0.06, Vector3(cos(a) * 0.6, 0.3, sin(a) * 0.6), EnemyFx.mat(Color("#9fb3c8")))
	EnemyFx.cyl(visual, 0.5, 1.3, Vector3(0, 0.95, 0), body)
	_head = Node3D.new()
	_head.position.y = 1.75
	visual.add_child(_head)
	EnemyFx.sphere(_head, 0.3, Vector3.ZERO, body, 0.56)
	EnemyFx.cyl(_head, 0.09, 0.6, Vector3(0, 0, 0.4), EnemyFx.mat(Color("#232838"))).rotation.x = PI / 2
	_muzzle_mat = EnemyFx.mat(Color("#ff5d2e"), Color("#ff3300"), 0.0)
	_muzzle_mat.emission_enabled = true
	EnemyFx.cyl(_head, 0.11, 0.1, Vector3(0, 0, 0.72), _muzzle_mat).rotation.x = PI / 2
	_lamp = EnemyFx.sphere(_head, 0.14, Vector3(0, 0.3, -0.05), EnemyFx.mat(Color("#ff5d5d"), Color("#ff2222"), 2.0))   # weak-point lamp
	EnemyFx.box(visual, Vector3(0.3, 0.4, 0.04), Vector3(-0.55, 1.1, 0.2), EnemyFx.mat(Color("#c8b48a")))     # clipboard
	_crest_mat = EnemyFx.mat(Color("#9fb3c8"), Color("#ff2222"), 0.0)
	_crest_mat.emission_enabled = true
	for side: float in [1.0, -1.0]:
		var sh: MeshInstance3D = EnemyFx.box(visual, Vector3(1.1, 1.5, 0.14), Vector3(0, 0.95, 0.62 * side), EnemyFx.mat(Color("#9fb3c8")))
		EnemyFx.box(sh, Vector3(0.36, 0.36, 0.05), Vector3(0, 0.25, 0.08 * side), _crest_mat)               # HOA crest
		var lbl: Label3D = Label3D.new()
		lbl.text = "HOA"
		lbl.font_size = 40
		lbl.pixel_size = 0.005
		lbl.modulate = Color("#1c2333")
		lbl.position = Vector3(0, -0.2, 0.08 * side)
		if side < 0.0:
			lbl.rotation.y = PI
		sh.add_child(lbl)
		_shields.append(sh)


func _on_activate() -> void:
	plates = int(def["elite"]["plates"]) if elite else int(def["plates"])
	armored = plates > 0
	violations = 0
	shots_fired = 0
	_buzz_hits = 0
	_viol_t = float(VI()["first"])
	_fire_open = 0.0
	_sync_shields()


func _sync_shields() -> void:
	if _shields.size() == 2:
		_shields[0].visible = plates >= 1
		_shields[1].visible = plates >= 2


func _position_update(dt: float) -> void:
	desired_vel = Vector3.ZERO
	var d: float = dist_to_target()
	if _viol_t <= 0.0 and can_attack() and target_alive() and d < float(VI()["range"]):
		_viol_t = float(VI()["every"])
		_plan_violation()
		begin_telegraph(&"violation", float(telegraph_def(&"violation").get("dur", 0.8)), float(VI()["ring_r"]), _viol_at)
		return
	if d < float(TU()["track_radius"]) and target_alive():
		face(target_pos() - global_position, dt, float(TU()["turn_rate"]))
		var tele: float = float(telegraph_def(&"shot").get("dur", 0.55))
		if d < float(TU()["fire_radius"]) and fire_cd <= tele and can_attack():
			if AttackTokens.request_ranged():
				begin_telegraph(&"shot", tele, -1.0, Vector3.INF, false)
			else:
				fire_cd = tele + 0.15


func _timers(delta: float) -> void:
	super._timers(delta)
	if aggro:
		_viol_t -= delta * attack_rate()


func _plan_violation() -> void:
	_viol_walk = null
	var best: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group(&"nova_walkways"):
		var w: Node3D = n as Node3D
		if w != null and w.global_position.distance_to(global_position) < float(VI()["walkway_search"]):
			best.append(w)
	if not best.is_empty():
		_viol_walk = best[randi() % best.size()]
		_viol_at = (_viol_walk as Node3D).global_position
	else:
		_viol_at = target_pos()


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_crest_mat.emission_energy_multiplier = k * 4.0
	if attack_kind == &"shot":
		_head.position.y = 1.75 + k * 0.35                              # head lifts above the shield
		_muzzle_mat.emission_energy_multiplier = k * 3.3
		_fire_open = 0.4
		if target_alive():
			face(target_pos() - global_position, dt, float(TU()["turn_rate"]))


func _attack_begin() -> void:
	_crest_mat.emission_energy_multiplier = 0.0
	if attack_kind == &"violation":
		_issue_violation()
		return
	_muzzle_mat.emission_energy_multiplier = 0.0
	fire_cd = float(TU()["fire_every"])
	var origin: Vector3 = _head.global_position + forward() * 0.8
	var aim: Vector3 = (target_center() + Vector3(0, 0.3, 0) - origin).normalized()
	EnemyProjectile.fire(get_parent(), origin, aim * float(TU()["shot_speed"]), float(def["dmg"]) * out_mult(),
		EnemyFx.col(str(TU()["shot_color"])), float(TU()["shot_size"]), 4.0, {"source": self})
	shots_fired += 1
	_fire_open = 0.5


func _issue_violation() -> void:
	violations += 1
	var bolt_in: bool = false
	if target != null and target.is_in_group(&"player"):
		if _viol_walk != null and is_instance_valid(_viol_walk) and _viol_walk.has_method("contains_point"):
			bolt_in = bool(_viol_walk.call("contains_point", target.global_position))
		else:
			bolt_in = Vector2(target.global_position.x - _viol_at.x, target.global_position.z - _viol_at.z).length() < float(VI()["ring_r"])
	if bolt_in and _viol_walk != null and is_instance_valid(_viol_walk) and _viol_walk.has_method("reverse"):
		_viol_walk.call("reverse")
	if bolt_in and elite and target.is_in_group(&"player"):
		var fine: int = mini(int(def["elite"]["fine"]), BS.bolts)
		if fine > 0:
			BS.add_bolts(-fine)
			EventBus.hint.emit("-%d BOLTS (HOA FINE)" % fine, "")
	violation_issued.emit(_viol_at, _viol_walk)


func _attack_update(_dt: float) -> bool:
	return true


func _recover_update(_dt: float) -> bool:
	return state_t >= 0.15


func _on_attack_cancelled() -> void:
	_muzzle_mat.emission_energy_multiplier = 0.0
	_crest_mat.emission_energy_multiplier = 0.0


func weak_point_exposed() -> bool:
	return _fire_open > 0.0 or state == State.TELEGRAPH and attack_kind == &"shot"


func _weak_point_pos() -> Vector3:
	return _lamp.global_position if _lamp != null else get_center()


## Weapons (Buzzkill, Clearance Rack at 20 stacks) may call this directly.
func pop_plate() -> void:
	if plates <= 0:
		return
	plates -= 1
	armored = plates > 0
	_buzz_hits = 0
	_sync_shields()
	EnemyFx.chunks(get_parent(), get_center() + forward() * 0.6, Color("#9fb3c8"), 0.8, 2, 3)
	plate_popped.emit(plates)


func _modify_damage(amount: float, hit: Combat.Hit, crit: bool) -> float:
	if plates <= 0 or crit:
		return amount
	var marked: bool = status.has(&"marked_down") and int(get_meta(&"marked_down_stacks", 5)) >= 5
	if hit.is_melee and hit.source != null and hit.source.is_in_group(&"player"):
		pop_plate()                                            # each mallet hit strips one plate
		return amount if marked else amount * float(def["plate_chip"])
	if hit.weapon_id == &"buzzkill":
		_buzz_hits += 1
		if _buzz_hits >= (int(def["buzzkill_pop"][1]) if marked else int(def["buzzkill_pop"][0])):
			pop_plate()
	pinged.emit()                                              # ARMORED: guns ping off
	return 0.0


func _anim(delta: float) -> void:
	_fire_open -= delta
	if state != State.TELEGRAPH:
		_head.position.y = lerpf(_head.position.y, 1.75, 0.15)
