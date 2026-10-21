class_name CameraDrone
extends EnemyBase
## One of the Content Creator's three camera drones (BS_ENEMIES §4.3). 25 HP. While any drone is filming,
## the Content Creator's SPOTLIGHT SHIELD cuts all damage it takes to 25%. It orbits the boss and points its
## lens (a weak point) and a spotlight cone at it. It doesn't attack. The boss listens to `died`.

var boss: Node3D = null
var slot: int = 0
var dock: Vector3 = Vector3.INF     # a docking point (a mast top); INF = orbit the boss
var _lens_mat: StandardMaterial3D
var _cone: MeshInstance3D
var _rotors: Array[MeshInstance3D] = []


func OB() -> Dictionary:
	return def["orbit"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#232838"))))
	flash_mats.append(body)
	EnemyFx.box(visual, Vector3(0.5, 0.32, 0.4), Vector3.ZERO, body)
	_lens_mat = EnemyFx.mat(Color("#1c2333"), Color("#3ee6ff"), 1.8)
	EnemyFx.cyl(visual, 0.13, 0.2, Vector3(0, 0, 0.28), _lens_mat).rotation.x = PI / 2
	EnemyFx.box(visual, Vector3(0.08, 0.05, 0.03), Vector3(0.16, 0.12, 0.2), EnemyFx.mat(Color("#ff2222"), Color("#ff0000"), 2.0))   # REC
	for sx: float in [-0.36, 0.36]:
		_rotors.append(EnemyFx.cyl(visual, 0.18, 0.03, Vector3(sx, 0.2, 0), EnemyFx.mat(Color("#8b95a8"))))
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.9
	cm.height = 3.0
	_cone = MeshInstance3D.new()
	_cone.mesh = cm
	_cone.material_override = EnemyFx.glow(Color("#fff6c8"), 0.12)
	_cone.set_meta(&"no_rim", true)
	_cone.rotation.x = -PI / 2
	_cone.position = Vector3(0, 0, 1.7)
	visual.add_child(_cone)


func _on_activate() -> void:
	dock = Vector3.INF


func _initial_state() -> int:
	return State.CHASE


func _orbit_goal() -> Vector3:
	if dock != Vector3.INF:
		var ad: float = t * float(OB()["rate"]) * 2.0
		return dock + Vector3(cos(ad) * float(OB()["dock_radius"]), 0, sin(ad) * float(OB()["dock_radius"]))
	var c: Vector3 = boss.global_position if boss != null and is_instance_valid(boss) else home
	var a: float = t * float(OB()["rate"]) + TAU * slot / 3.0
	return c + Vector3(cos(a) * float(OB()["radius"]), float(OB()["height"]), sin(a) * float(OB()["radius"]))


func _position_update(dt: float) -> void:
	_idle_update(dt)


func _idle_update(dt: float) -> void:
	desired_vel = (_orbit_goal() - global_position) * float(OB()["follow"]) if can_move() else Vector3.ZERO
	if boss != null and is_instance_valid(boss):
		var look: Vector3 = (boss.call("get_center") as Vector3) - global_position
		face(look, dt, 6.0)


func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return global_position + forward() * 0.3


func _anim(delta: float) -> void:
	for r: MeshInstance3D in _rotors:
		r.rotation.y += delta * 28.0
	_lens_mat.emission_energy_multiplier = 1.8 + sin(t * 9.0) * 0.6
