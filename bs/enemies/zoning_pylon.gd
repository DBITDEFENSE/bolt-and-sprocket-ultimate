class_name ZoningPylon
extends EnemyBase
## One of the Zoning Board's three linked pylons (BS_ENEMIES §3.3; see zoning_board.gd). 40 HP, 4 bolts.
## A waist-high civic pylon with a clipboard head and a permit-stamp top. It sits on a rail (up to 5 m either
## way). RE-ZONE: the board calls start_rezone(to); the pylon telegraphs 1.0 s (the permit stamp rises, a
## council-chamber gavel triple-knock; the board paints the new triangle), then slides along its rail.
## Weak point: the permit stamp on top, exposed (crit) during the re-zone.

var board: Node = null
var rail_origin: Vector3 = Vector3.ZERO
var rail_dir: Vector3 = Vector3.RIGHT
var slide_from: Vector3 = Vector3.ZERO
var slide_to: Vector3 = Vector3.ZERO
var rezones: int = 0
var _stamp: Node3D
var _stamp_mat: StandardMaterial3D


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#c8b48a"))))
	flash_mats.append(body)
	EnemyFx.cyl(visual, 0.32, 0.14, Vector3(0, 0.07, 0), EnemyFx.mat(Color("#3a4658")))
	EnemyFx.cyl(visual, 0.18, 0.75, Vector3(0, 0.5, 0), body, 0.15)                                         # civic post
	EnemyFx.box(visual, Vector3(0.42, 0.5, 0.06), Vector3(0, 1.05, 0), EnemyFx.mat(Color("#8a6a3a")))      # clipboard head
	EnemyFx.box(visual, Vector3(0.34, 0.36, 0.02), Vector3(0, 1.03, 0.04), EnemyFx.mat(Color("#f2ebe0")))
	EnemyFx.box(visual, Vector3(0.12, 0.04, 0.04), Vector3(0, 1.3, 0.03), EnemyFx.mat(Color("#9fb3c8")))   # clip
	EnemyFx.sphere(visual, 0.09, Vector3(0, 0.6, 0.0), EnemyFx.mat(Color("#ffe84d"), Color("#ffe84d"), 2.0)).set_meta(&"no_rim", true)  # beam emitter
	_stamp = Node3D.new()
	_stamp.position.y = 1.36
	visual.add_child(_stamp)
	EnemyFx.cyl(_stamp, 0.05, 0.16, Vector3(0, 0.08, 0), EnemyFx.mat(Color("#2a2a30")))
	_stamp_mat = EnemyFx.mat(Color("#d42f2f"), Color("#ff2222"), 0.5)
	EnemyFx.box(_stamp, Vector3(0.26, 0.1, 0.18), Vector3(0, 0.2, 0), _stamp_mat)                           # permit stamp


func _on_activate() -> void:
	rezones = 0
	slide_to = global_position if is_inside_tree() else position


func _initial_state() -> int:
	return State.CHASE


func _position_update(_dt: float) -> void:
	desired_vel = Vector3.ZERO
	if target != null:
		face(target_pos() - global_position, _dt, 1.5)


func start_rezone(to: Vector3, dur: float) -> bool:
	if not is_alive() or not can_attack() or state == State.TELEGRAPH or state == State.ATTACK:
		return false
	slide_to = to
	begin_telegraph(&"rezone", dur)
	return true


func _telegraph_update(_dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_stamp.position.y = 1.36 + k * 0.45                                  # the permit stamp rises
	_stamp_mat.emission_energy_multiplier = 0.5 + k * 4.0


func _attack_begin() -> void:
	slide_from = global_position
	rezones += 1


func _attack_update(_dt: float) -> bool:
	var st: float = float(def["slide_time"])
	var k: float = clampf(state_t / st, 0.0, 1.0)
	override_point = slide_from.lerp(slide_to, k)
	return k >= 1.0


func _recover_update(_dt: float) -> bool:
	_stamp.position.y = lerpf(_stamp.position.y, 1.36, 0.3)
	_stamp_mat.emission_energy_multiplier = 0.5
	return state_t >= 0.2


func _on_attack_cancelled() -> void:
	_stamp.position.y = 1.36
	_stamp_mat.emission_energy_multiplier = 0.5


func weak_point_exposed() -> bool:
	return state == State.TELEGRAPH and attack_kind == &"rezone"


func _weak_point_pos() -> Vector3:
	return _stamp.global_position if _stamp != null else get_center()


func _on_died(_hit: Combat.Hit) -> void:
	if board != null and is_instance_valid(board) and board.has_method("_on_pylon_died"):
		board.call("_on_pylon_died", self)
