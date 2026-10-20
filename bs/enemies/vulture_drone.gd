class_name VultureDrone
extends EnemyBase
## Vulture Drone — bolt-thief flyer (BS_ENEMIES §3.1; makeVultureDrone index.html:5890, dive :6673-6712).
## Orbits 5 m above Bolt (r5, anchor = Bolt within 18 m, else home). Every 5 s within 14 m it
## telegraphs 0.5 s (wings tuck, beak down, red eye flare, screech) and DIVES at 15 m/s: 8 damage and
## steals 5 bolts (they show in its cage), then climbs 1.2 s at 6 m/s. Remake: after a steal it FLEES
## away from Bolt at 9 m/s for 6 s and despawns with the loot; killing it first drops the loot + its
## own drops. Dashing through the dive makes it miss. Elite (Compound Theft): steals 10 and splits
## into two smaller drones when it flees, each carrying half.

var fleeing: bool = false
var flee_t: float = 0.0
var stole_total: int = 0
var dives: int = 0
var _dive_to: Vector3
var _dive_hit: bool = false
var _stole_this_dive: bool = false
var _is_split: bool = false
var _wings: Array[Node3D] = []
var _cage_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _cage_fill: MeshInstance3D


func FL() -> Dictionary:
	return def["flyer"]


func DV() -> Dictionary:
	return def["dive"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#5e4a38"))))
	flash_mats.append(body)
	var hull: MeshInstance3D = EnemyFx.cyl(visual, 0.3, 0.7, Vector3(0, 0, -0.1), body, 0.02)
	hull.rotation.x = PI / 2 + 0.3
	EnemyFx.sphere(visual, 0.16, Vector3(0, 0.22, 0.32), EnemyFx.mat(Color("#d88a8a")))
	_eye_mat = EnemyFx.mat(Color("#ff5d5d"), Color("#ff2222"), 2.0)
	EnemyFx.sphere(visual, 0.05, Vector3(-0.07, 0.26, 0.44), _eye_mat)
	EnemyFx.sphere(visual, 0.05, Vector3(0.07, 0.26, 0.44), _eye_mat)
	EnemyFx.cyl(visual, 0.05, 0.16, Vector3(0, 0.18, 0.52), EnemyFx.mat(Color("#ffd23e")), 0.0).rotation.x = PI / 2
	for sx: float in [-1.0, 1.0]:
		var w: Node3D = Node3D.new()
		w.position = Vector3(0.12 * sx, 0.15, 0)
		visual.add_child(w)
		EnemyFx.box(w, Vector3(0.6, 0.06, 0.3), Vector3(0.3 * sx, 0, 0), EnemyFx.mat(Color("#3a2e22")))
		_wings.append(w)
	_cage_mat = EnemyFx.mat(Color("#ffd23e"), Color("#ffd23e"), 0.0)
	_cage_mat.emission_enabled = true
	var cage: MeshInstance3D = EnemyFx.box(visual, Vector3(0.24, 0.18, 0.24), Vector3(0, -0.24, -0.28), _cage_mat)
	cage.transparency = 0.4
	_cage_fill = EnemyFx.box(visual, Vector3(0.18, 0.12, 0.18), Vector3(0, -0.26, -0.28), EnemyFx.glow(Color("#ffd23e")))
	_cage_fill.visible = false


func _on_activate() -> void:
	fleeing = false
	flee_t = 0.0
	stole_total = 0
	dives = 0
	_is_split = bool(opts.get("split", false))
	fire_cd = float(DV()["first_delay"])
	visual.scale = Vector3.ONE * (float(def["elite"]["split_scale"]) if _is_split else 1.0)
	_base_scale = visual.scale


func steal_amount() -> int:
	return int(def["elite"]["steal"]) if elite and not _is_split else int(def.get("steal", 5))


func _idle_update(dt: float) -> void:
	_orbit(home, dt)


func _orbit(anchor: Vector3, dt: float) -> void:
	var a: float = t * float(FL()["orbit_rate"])
	var r: float = float(FL()["orbit_radius"])
	var goal: Vector3 = anchor + Vector3(cos(a) * r, float(FL()["orbit_height"]), sin(a) * r)
	desired_vel = (goal - global_position) * float(FL()["follow"]) * move_mult()
	if not can_move():
		desired_vel = Vector3.ZERO
	if target != null:
		face(target_pos() - global_position, dt, 4.0)


func _position_update(dt: float) -> void:
	if fleeing:
		_flee(dt)
		return
	var d: float = dist_to_target()
	var anchor: Vector3 = target_pos() if d < float(FL()["anchor_radius"]) else home
	_orbit(anchor, dt)
	if d < float(DV()["range"]) and fire_cd <= 0.0 and can_attack() and target_alive():
		if AttackTokens.request_melee(self, target_onscreen()):
			begin_telegraph(&"dive", float(telegraph_def(&"dive").get("dur", 0.5)))
		else:
			fire_cd = 0.5


func _telegraph_update(dt: float) -> void:
	desired_vel = Vector3.ZERO
	visual.rotation.x = lerpf(visual.rotation.x, 0.7, 1.0 - exp(-10.0 * dt))     # beak points down
	for i: int in _wings.size():
		_wings[i].rotation.z = (0.9 if i == 0 else -0.9)                            # wings tuck
	_eye_mat.emission_energy_multiplier = 5.0 + sin(t * 40.0) * 1.5
	if target_alive():
		face(target_pos() - global_position, dt, 10.0)


func _attack_begin() -> void:
	_dive_to = target_center() + Vector3(0, 0.3, 0)
	_dive_hit = false
	_stole_this_dive = false
	fire_cd = float(DV()["every"])
	dives += 1


func _attack_update(dt: float) -> bool:
	var to: Vector3 = _dive_to - global_position
	var dd: float = to.length()
	desired_vel = to.normalized() * float(DV()["speed"]) if dd > 0.05 else Vector3.ZERO
	if dd < float(DV()["speed"]) * dt:
		desired_vel = to / maxf(dt, 0.0001)
	face(to, dt, 8.0)
	if not _dive_hit and contact_cd <= 0.0 and target_alive() \
			and global_position.distance_to(target_center() + Vector3(0, 0.3, 0)) < float(DV()["hit_reach"]):
		_dive_hit = true
		if not target_dodging():
			contact_cd = float(DV()["contact_cd"])
			hurt_target(float(def["dmg"]), float(DV()["knock"]))
			_steal()
		return true
	return dd < 0.6 or state_t > 1.6


func _steal() -> void:
	if not target.is_in_group(&"player"):
		return
	var n: int = mini(steal_amount(), BS.bolts)
	if n <= 0:
		return
	BS.add_bolts(-n)
	stolen += n
	stole_total += n
	_stole_this_dive = true
	EventBus.hint.emit("-%d BOLTS!" % n, "")


func _recover_update(_dt: float) -> bool:
	# climb
	visual.rotation.x = lerpf(visual.rotation.x, -0.3, 1.0 - exp(-6.0 * _dt))
	desired_vel = Vector3(0, float(DV()["climb_speed"]), 0)
	if state_t >= float(DV()["climb_time"]):
		visual.rotation.x = 0.0
		if _stole_this_dive or (stolen > 0 and not fleeing):
			_start_flee()
		return true
	return false


func _start_flee() -> void:
	fleeing = true
	flee_t = float(def["flee"]["time"])
	telegraphed.emit(&"flee", &"vulture_cackle", flee_t)
	if elite and not _is_split and stolen > 1 and get_parent() != null:
		var half: int = stolen / 2
		var twin: Node3D = EnemySpawner.spawn(&"vulture_drone", global_position + Vector3(1.0, 0.3, 0), get_parent(),
			{"split": true, "aggro": true, "spawn_time": 0.0})
		var tv: VultureDrone = twin as VultureDrone
		if tv != null:
			tv.max_hp = ceilf(max_hp * 0.5)
			tv.hp = tv.max_hp
			tv.stolen = half
			tv.stole_total = half
			tv.fleeing = true
			tv.flee_t = flee_t
			tv.state = State.CHASE
			tv.home = home
		stolen -= half
		max_hp = ceilf(max_hp * 0.5)
		hp = minf(hp, max_hp)
		visual.scale = Vector3.ONE * float(def["elite"]["split_scale"])
		_base_scale = visual.scale


func _flee(dt: float) -> void:
	flee_t -= dt
	var away: Vector3 = global_position - target_pos()
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -forward()
	away = away.normalized()
	desired_vel = away * float(def["flee"]["speed"]) * move_mult() + Vector3(0, maxf(0.0, home.y + 6.0 - global_position.y), 0)
	face(away, dt, 6.0)
	if flee_t <= 0.0:
		despawn()


func _on_attack_cancelled() -> void:
	visual.rotation.x = 0.0
	desired_vel = Vector3.ZERO


func _anim(_delta: float) -> void:
	if state != State.TELEGRAPH:
		var f: float = sin(t * 8.0) * 0.35
		if _wings.size() == 2:
			_wings[0].rotation.z = 0.35 + f
			_wings[1].rotation.z = -0.35 - f
		_eye_mat.emission_energy_multiplier = 2.0
	_cage_fill.visible = stolen > 0
	_cage_mat.emission_energy_multiplier = (1.5 + sin(t * 8.0)) if stolen > 0 else 0.0
