class_name ReviewBomber
extends EnemyBase
## Review Bomber — NEW flyer (BS_ENEMIES §3.2). 30 HP / 6.0 m/s / 12 per bomb / 7 bolts.
## Cruises 8 m up between perches (opts["perches"]: Array of Vector3, else 3 points around home). Every 4.5 s it
## "posts a review" on Bolt's position: it hovers still with the bay open (a notification ping, then a
## descending "boo"), the pattern's decals glow on the ground, and 5 star-shaped bombs fall so they land 0.8 s
## later (decals glow the whole 0.4 s telegraph + 0.8 s fall). Odd cycles: a STAR (points 4 m out; the centre
## is safe). Even cycles: a tight RING of 5 (the centre is unsafe; step out through the gaps). It hovers 0.6 s
## after posting (shoot it then). Bombs are fragile: shooting one pops it harmlessly ("DENIED").
## Elite (Verified Purchaser, amber rim): posts star then ring back to back, 0.6 s apart.

var cycles: int = 0
var posts: int = 0
var bombs_dropped: int = 0
var last_pattern: StringName = &""
var last_points: Array[Vector3] = []
var _perches: Array[Vector3] = []
var _perch_i: int = 0
var _second_t: float = -1.0
var _bay_mat: StandardMaterial3D
var _bay: Node3D
var _display: Label3D


func RB() -> Dictionary:
	return def["review"]


func _build_visual() -> void:
	var body: StandardMaterial3D = EnemyFx.mat(EnemyFx.col(str(def.get("body_color", "#6a5acd"))))
	flash_mats.append(body)
	EnemyFx.sphere(visual, 0.55, Vector3.ZERO, body, 0.9)                                                    # chubby drone
	EnemyFx.cyl(visual, 0.12, 0.5, Vector3(0, 0.05, 0.6), EnemyFx.mat(Color("#ffb02e")), 0.28).rotation.x = -PI / 2  # megaphone beak
	_bay = Node3D.new()
	_bay.position.y = -0.4
	visual.add_child(_bay)
	_bay_mat = EnemyFx.mat(Color("#ffd23e"), Color("#ffb02e"), 0.3)
	EnemyFx.box(_bay, Vector3(0.5, 0.08, 0.5), Vector3.ZERO, _bay_mat)
	for sx: float in [-0.7, 0.7]:
		EnemyFx.cyl(visual, 0.28, 0.04, Vector3(sx, 0.32, 0), EnemyFx.mat(Color("#232838")))                 # rotors
	_display = Label3D.new()
	_display.text = "★☆☆☆☆"
	_display.font_size = 48
	_display.pixel_size = 0.006
	_display.modulate = Color("#ffd23e")
	_display.position = Vector3(0.58, 0.05, 0)
	_display.rotation.y = PI / 2
	visual.add_child(_display)


func _on_activate() -> void:
	cycles = 0
	posts = 0
	bombs_dropped = 0
	_second_t = -1.0
	fire_cd = float(RB()["first_delay"])
	_perches.clear()
	var given: Variant = opts.get("perches", [])
	if given is Array and not (given as Array).is_empty():
		for p: Variant in given:
			_perches.append(Vector3(p))
	else:
		for i: int in 3:
			var a: float = TAU * i / 3.0
			_perches.append(home + Vector3(cos(a) * float(RB()["perch_r"]), 0, sin(a) * float(RB()["perch_r"])))
	_perch_i = 0


func _idle_update(dt: float) -> void:
	_cruise(dt)


func _cruise(dt: float) -> void:
	if not can_move():
		desired_vel = Vector3.ZERO
		return
	var goal: Vector3 = _perches[_perch_i] if not _perches.is_empty() else home
	var fy: float = EnemyFx.floor_y(self, Vector3(goal.x, home.y, goal.z), home.y, 2.0, 40.0)
	goal.y = fy + float(RB()["altitude"])
	var to: Vector3 = goal - global_position
	if to.length() < 1.0:
		_perch_i = (_perch_i + 1) % maxi(1, _perches.size())
	desired_vel = to.normalized() * minf(speed, to.length() * 2.0) * move_mult()
	if desired_vel.length_squared() > 0.01:
		face(Vector3(desired_vel.x, 0, desired_vel.z), dt, 3.0)


func _timers(delta: float) -> void:
	super._timers(delta)
	if _second_t >= 0.0 and is_alive():
		_second_t -= delta
		if _second_t < 0.0:
			_post(&"ring")                     # Verified Purchaser: the ring 0.6 s after the star


func _position_update(dt: float) -> void:
	if _second_t >= 0.0:
		desired_vel = Vector3.ZERO           # still hovering between the two posts
		return
	_cruise(dt)
	if fire_cd <= 0.0 and can_attack() and target_alive() and flat_dist_to_target() < float(RB()["range"]):
		if AttackTokens.request_ranged():
			cycles += 1
			last_pattern = &"star" if cycles % 2 == 1 or elite else &"ring"
			_plan(last_pattern)
			begin_telegraph(&"review", float(telegraph_def(&"review").get("dur", 0.4)), -1.0, Vector3.INF, false)
		else:
			fire_cd = 0.5


func _plan(pattern: StringName) -> void:
	last_points.clear()
	var c: Vector3 = target_pos()
	var rr: float = float(RB()["star_r"]) if pattern == &"star" else float(RB()["ring_r"])
	var a0: float = randf() * TAU
	for i: int in 5:
		var a: float = a0 + TAU * i / 5.0
		last_points.append(c + Vector3(cos(a) * rr, 0, sin(a) * rr))
	var lit: float = float(telegraph_def(&"review").get("dur", 0.4)) + float(RB()["fall_time"])
	var col: Color = Color("#ffb02e") if pattern == &"star" else Color("#ff5d5d")
	for p: Vector3 in last_points:
		EnemyFx.ring(get_parent(), p, float(RB()["bomb_r"]), lit, col)


func _telegraph_update(_dt: float) -> void:
	desired_vel = Vector3.ZERO
	var k: float = 1.0 - clampf(tele_t / maxf(tele_dur, 0.01), 0.0, 1.0)
	_bay.rotation.x = k * 0.9                                           # bay opens
	_bay_mat.emission_energy_multiplier = 0.3 + k * 4.0


func _attack_begin() -> void:
	_drop(last_points)
	fire_cd = float(RB()["every"])
	if elite:
		_second_t = float(def["elite"]["gap"])


func _post(pattern: StringName) -> void:
	last_pattern = pattern
	_plan(pattern)
	telegraphed.emit(&"review", &"review_ping", float(telegraph_def(&"review").get("dur", 0.4)))
	var pts: Array[Vector3] = last_points.duplicate()
	get_tree().create_timer(float(telegraph_def(&"review").get("dur", 0.4)), false, true).timeout.connect(func() -> void:
		if is_alive():
			_drop(pts))


func _drop(points: Array[Vector3]) -> void:
	posts += 1
	var origin: Vector3 = global_position + Vector3(0, -0.5, 0)
	var g: float = float(RB()["bomb_gravity"])
	var T: float = float(RB()["fall_time"])
	for p: Vector3 in points:
		var gy: float = EnemyFx.floor_y(self, p, p.y)
		var dp: Vector3 = Vector3(p.x, gy + 0.2, p.z) - origin
		var v: Vector3 = Vector3(dp.x / T, (dp.y + 0.5 * g * T * T) / T, dp.z / T)
		EnemyProjectile.fire(get_parent(), origin, v, float(def["dmg"]) * out_mult(), Color("#ffb02e"), 0.28, T + 1.0,
			{"grav": g, "boom_r": float(RB()["bomb_r"]), "source": self, "fragile": true, "kind": &"review_bomb", "scale": Vector3(1.2, 0.6, 1.2)})
		bombs_dropped += 1


func _attack_update(_dt: float) -> bool:
	desired_vel = Vector3.ZERO
	return state_t >= float(RB()["hover_after"])


func _recover_update(_dt: float) -> bool:
	_bay.rotation.x = 0.0
	_bay_mat.emission_energy_multiplier = 0.3
	return state_t >= 0.1


func _on_attack_cancelled() -> void:
	_bay.rotation.x = 0.0
	_bay_mat.emission_energy_multiplier = 0.3


func _anim(_delta: float) -> void:
	_display.modulate.a = 0.6 + 0.4 * absf(sin(t * 7.0))                # flickering one-star display
	visual.position.y = sin(t * 2.2) * 0.12 if state != State.TELEGRAPH else 0.0


func _owns_visual_y() -> bool:
	return true
