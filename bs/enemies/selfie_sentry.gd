class_name SelfieSentry
extends EnemyBase
## Selfie Sentry — flash-blinder flyer (BS_ENEMIES §3.2; makeSelfieSentry index.html:5939, flash :6751-6772).
## 30 HP / 7 bolts. A flying ring light with a lens. Orbits 4 m out, 3 m up (anchor: Bolt within 18 m, else
## home). Every 2.7 s within 16 m it telegraphs 0.5 s (the ring light swells, a 1900 Hz shutter click, glow to
## max), FLASHES, then fires a 3-shot burst (7 damage each, 0.13 s apart, 13 m/s).
## Remake: if Bolt's camera faces the lens within 25 degrees when the flash fires (and the lens is in sight),
## he is BLINDED (1.2 s white-out). Looking away or cover avoids it. Shooting the lens (weak point) during the
## telegraph cancels the flash and the burst.
## Elite (Going Viral, white rim): each successful blind spawns a "like" drone that orbits it and absorbs one hit.

var flashes: int = 0
var blinds: int = 0
var shots_fired: int = 0
var like_shields: int = 0
var _burst_n: int = 0
var _burst_t: float = 0.0
var _ring_mat: StandardMaterial3D
var _ringlight: MeshInstance3D
var _lens: MeshInstance3D
var _likes: Array[MeshInstance3D] = []


func FL() -> Dictionary:
	return def["flyer"]


func FS() -> Dictionary:
	return def["flash"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#f2ebe0"))))
	flash_mats.append(body)
	EnemyFx.box(visual, Vector3(0.36, 0.5, 0.14), Vector3.ZERO, body)                                       # phone body
	_ring_mat = EnemyFx.mat(Color.WHITE, Color("#ffeedd"), 1.2)
	_ringlight = EnemyFx.torus(visual, 0.24, 0.36, Vector3(0, 0.08, 0.1), _ring_mat)
	_ringlight.rotation.x = PI / 2
	_lens = EnemyFx.cyl(visual, 0.1, 0.06, Vector3(0, 0.08, 0.12), EnemyFx.mat(Color("#1c2333"), Color("#3ee6ff"), 1.5))
	_lens.rotation.x = PI / 2
	EnemyFx.cyl(visual, 0.05, 0.35, Vector3(0, -0.42, 0), EnemyFx.mat(Color("#8b95a8")))                      # gimbal handle
	for sx: float in [-0.26, 0.26]:
		EnemyFx.box(visual, Vector3(0.24, 0.03, 0.06), Vector3(sx, 0.32, 0), EnemyFx.mat(Color("#ff4d9d")))  # props
	EnemyFx.box(visual, Vector3(0.08, 0.05, 0.03), Vector3(0.12, 0.28, 0.08), EnemyFx.mat(Color("#ff2222"), Color("#ff0000"), 1.5))  # REC


func _on_activate() -> void:
	flashes = 0
	blinds = 0
	shots_fired = 0
	like_shields = 0
	_burst_n = 0
	fire_cd = float(FS()["first_delay"])
	_sync_likes()


func _idle_update(dt: float) -> void:
	_orbit(home, dt)


func _orbit(anchor: Vector3, dt: float) -> void:
	var a: float = t * float(FL()["orbit_rate"])
	var r: float = float(FL()["orbit_radius"])
	var goal: Vector3 = anchor + Vector3(cos(a) * r, float(FL()["orbit_height"]) + sin(t * 2.0) * 0.6, sin(a) * r)
	desired_vel = (goal - global_position) * float(FL()["follow"]) * move_mult() if can_move() else Vector3.ZERO
	if target != null:
		face(target_pos() - global_position, dt, 4.0)


func _position_update(dt: float) -> void:
	var d: float = dist_to_target()
	_orbit(target_pos() if d < float(FL()["anchor_radius"]) else home, dt)
	if _burst_n > 0:
		return
	if d < float(FS()["range"]) and fire_cd <= 0.0 and can_attack() and target_alive():
		if AttackTokens.request_ranged():
			begin_telegraph(&"flash", float(telegraph_def(&"flash").get("dur", 0.5)))
		else:
			fire_cd = 0.4


func _telegraph_update(dt: float) -> void:
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_ringlight.scale = Vector3.ONE * (1.0 + k * 0.6)                      # the ring light swells
	_ring_mat.emission_energy_multiplier = 1.2 + k * 6.0
	_orbit(target_pos(), dt)
	desired_vel *= 0.3


func _attack_begin() -> void:
	_ringlight.scale = Vector3.ONE
	_ring_mat.emission_energy_multiplier = 8.0
	flashes += 1
	fire_cd = float(FS()["every"])
	_burst_n = int(FS()["burst"])
	_burst_t = 0.05
	if target != null and target.is_in_group(&"player") and facing_lens():
		blinds += 1
		var dbf: PlayerDebuffs = PlayerDebuffs.of(target)
		if dbf != null:
			dbf.blind(float(FS()["blind_time"]))
		if elite and like_shields < int(def["elite"]["max_likes"]):
			like_shields += 1
			_sync_likes()


## Bolt's camera looks at the lens within 25 degrees and nothing blocks the view.
func facing_lens() -> bool:
	if target == null or not "camera" in target:
		return false
	var bc: Node = target.get("camera")
	if bc == null or not bc.has_method("view_dir"):
		return false
	var cam: Camera3D = bc.get("cam") as Camera3D
	var eye: Vector3 = cam.global_position if cam != null and cam.is_inside_tree() else target_center()
	var to: Vector3 = _lens.global_position - eye
	if to.length_squared() < 0.01:
		return true
	var vd: Vector3 = (bc.call("view_dir") as Vector3).normalized()
	if rad_to_deg(vd.angle_to(to.normalized())) > float(FS()["blind_cone_deg"]):
		return false
	return EnemyFx.los_clear(self, eye, _lens.global_position)


func _attack_update(dt: float) -> bool:
	_orbit(target_pos(), dt)
	_burst_t -= dt
	if _burst_t <= 0.0 and _burst_n > 0:
		_burst_t = float(FS()["burst_gap"])
		_burst_n -= 1
		var origin: Vector3 = _lens.global_position
		var aim: Vector3 = (target_center() + Vector3(0, 0.3, 0) - origin).normalized()
		EnemyProjectile.fire(get_parent(), origin, aim * float(FS()["shot_speed"]), float(def["dmg"]) * out_mult(),
			Color.WHITE, float(FS()["shot_size"]), 3.0, {"source": self})
		shots_fired += 1
	return _burst_n <= 0


func _recover_update(_dt: float) -> bool:
	_orbit(target_pos(), _dt)
	return state_t >= 0.2


func _on_attack_cancelled() -> void:
	_ringlight.scale = Vector3.ONE
	_ring_mat.emission_energy_multiplier = 1.2
	_burst_n = 0
	fire_cd = maxf(fire_cd, float(FS()["every"]))


func weak_point_exposed() -> bool:
	return true


func _weak_point_pos() -> Vector3:
	return _lens.global_position if _lens != null else get_center()


func _modify_damage(amount: float, _hit: Combat.Hit, _crit: bool) -> float:
	if like_shields > 0 and amount > 0.0:
		like_shields -= 1                       # a like drone takes the hit
		_sync_likes()
		return 0.0
	return amount


func _on_hurt(_hit: Combat.Hit, _amount: float, crit: bool) -> void:
	if crit and state == State.TELEGRAPH:
		cancel_attack()                        # lens shot: no flash, no burst


func _sync_likes() -> void:
	while _likes.size() < like_shields:
		var m: MeshInstance3D = EnemyFx.sphere(self, 0.14, Vector3.ZERO, EnemyFx.mat(Color("#ff4d9d"), Color("#ff4d9d"), 2.0))
		m.set_meta(&"no_rim", true)
		_likes.append(m)
	while _likes.size() > like_shields:
		_likes.pop_back().queue_free()


func _anim(_delta: float) -> void:
	if state != State.TELEGRAPH and state != State.ATTACK:
		_ring_mat.emission_energy_multiplier = 1.2 + sin(t * 3.0) * 0.3
	for i: int in _likes.size():
		var a: float = t * 3.0 + TAU * i / maxf(1.0, _likes.size())
		_likes[i].position = Vector3(cos(a) * 0.8, 0.3, sin(a) * 0.8)
