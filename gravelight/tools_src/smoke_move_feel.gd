extends Node
## T-236 movement-feel probe: the real local Player, driven through its input actions, on a bare arena built
## here (a flat floor, kerbs of rising height, a stepped staircase, a wall, a box corner, a doorway, a ledge, a
## ramp). It measures what a player feels (time to top speed, stop distance, jump apex and hang time, air
## control, how many ticks late / early a jump press still jumps, what a kerb or a stair costs in speed and how
## far the eye moves in one tick on it, wall and corner slides, ramp crests) and pins the parts that are fixed.
## No map, no zombies: about ten seconds headless.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_move_feel.tscn
## Prints "[move-feel] <metric> = <value>" lines, "[move-feel] <check> ok|FAIL" and "[move-feel] RESULT PASS|FAIL".

const DT: float = 1.0 / 60.0
const KERBS: Array = [0.05, 0.10, 0.15, 0.25, 0.35, 0.45]
const STEP_RISE: float = 0.18
const STEP_RUN: float = 0.30
const STEPS: int = 8

var _p: Player
var _fails: PackedStringArray = []
var _walk: float = 4.5
var _sprint: float = 6.8


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["bots"] = 0
	GLSettings.values["sprint_mode"] = "hold"
	GLSettings.values["prone_enabled"] = false
	GameState.god_mode = true
	GameState.player_ids = [1]
	GLSettings.apply_bindings()   # Gravelight's input actions exist only once applied (T-024)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _m(what: String, value: Variant) -> void:
	print("[move-feel] %-58s = %s" % [what, str(value)])


func _check(cond: bool, what: String) -> void:
	print("[move-feel] %-74s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _release_all() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"fire", &"ads", &"crouch", &"jump"]:
		Input.action_release(a)


func _box(name_: String, a: Vector3, b: Vector3, rot_x_deg: float = 0.0) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = (b - a).abs()
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	body.global_position = (a + b) * 0.5
	body.rotation_degrees.x = rot_x_deg
	return body


func _place(pos: Vector3, yaw_deg: float = 0.0) -> void:
	_release_all()
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw_deg)
	_p.set("_pitch", 0.0)
	_p.crouching = false
	_p.sliding = false
	_p.sprinting = false
	_p.set("_stamina", 4.0)
	_p.set("_slide_cd", 0.0)
	_p.set("_jump_buf", 0.0)     # (a press still remembered from the last check must not jump here)
	_p.set("_view_off", Vector3.ZERO)
	await _ticks(12)


func _eye_y() -> float:
	return _p.camera.global_position.y


func _tap_jump() -> void:
	Input.action_press(&"jump")
	await _ticks(1)
	Input.action_release(&"jump")


func _build() -> void:
	_box("Floor", Vector3(-40, -1, -80), Vector3(170, 0, 40))
	for i: int in KERBS.size():
		var x: float = 10.0 + 6.0 * float(i)
		_box("Kerb%d" % i, Vector3(x - 2.0, 0, -20), Vector3(x + 2.0, float(KERBS[i]), 0))
	for i: int in STEPS:
		_box("Step%d" % i, Vector3(48, 0, -20), Vector3(52, STEP_RISE * float(i + 1), -STEP_RUN * float(i)))
	_box("Wall", Vector3(60, 0, -11), Vector3(80, 3, -10))
	_box("Corner", Vector3(90.25, 0, -6), Vector3(92, 3, -5))
	_box("JambL", Vector3(100, 0, -6), Vector3(103.55, 3, -5.7))
	_box("JambR", Vector3(104.45, 0, -6), Vector3(108, 3, -5.7))
	_box("Ledge", Vector3(118, 0, 0), Vector3(122, 2, 10))
	# a ramp up 3 m over 6 m (26.6 deg) toward -Z, then a flat top
	var ramp: StaticBody3D = _box("Ramp", Vector3(128, 0, 0), Vector3(132, 0.4, sqrt(45.0)), 0.0)
	ramp.rotation_degrees.x = rad_to_deg(atan2(3.0, 6.0))
	ramp.global_position = Vector3(130, 1.5, -3.0) - Vector3(0, 0.894427, 0.447214) * 0.2
	_box("RampTop", Vector3(128, 0, -18), Vector3(132, 3, -6))
	# a low crate grazed by its corner (a prop): 0.3 m high
	_box("LowCrate", Vector3(140.25, 0, -6), Vector3(142, 0.3, -5))


func _run() -> void:
	_build()
	_p = Player.new()
	_p.name = "Player1"
	add_child(_p)
	_p.global_position = Vector3(0, 0.05, 30)
	RoundManager.stop()
	GameState.phase = GameState.Phase.PLAYING
	GameState.input_blocked = false
	_p.set_process_unhandled_input(false)
	await _ticks(20)
	var cfg: Dictionary = GLData.table("player")
	_walk = float(cfg["walk_speed"]) * _p.weapons.move_mult()
	_sprint = float(cfg["sprint_speed"]) * _p.weapons.move_mult()
	_m("walk / sprint speed (m/s, with the gun in hand)", "%.2f / %.2f" % [_walk, _sprint])

	await _ground()
	await _jump()
	await _forgiveness()
	await _kerbs()
	await _stairs()
	await _slides()
	await _ramp()

	_release_all()
	print("[move-feel] RESULT %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (%d): %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)


# ---------------------------------------------------------------- flat ground

func _ground() -> void:
	# start
	await _place(Vector3(0, 0.02, 30))
	Input.action_press(&"move_forward")
	var n: int = 0
	while _p.horizontal_speed() < _walk * 0.95 and n < 120:
		await _ticks(1)
		n += 1
	_m("ticks to 95% walk speed", n)
	_check(n >= 3 and n <= 12, "walk: full speed in 0.05..0.2 s")
	await _ticks(30)
	# stop
	var z0: float = _p.global_position.z
	Input.action_release(&"move_forward")
	n = 0
	while _p.horizontal_speed() > 0.05 and n < 120:
		await _ticks(1)
		n += 1
	_m("walk stop: ticks / metres", "%d / %.2f" % [n, absf(_p.global_position.z - z0)])
	_check(n <= 14 and absf(_p.global_position.z - z0) < 0.6, "walk: stops within 0.23 s and 0.6 m (no ice)")
	# sprint start / stop
	await _place(Vector3(0, 0.02, 30))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	n = 0
	while _p.horizontal_speed() < _sprint * 0.95 and n < 120:
		await _ticks(1)
		n += 1
	_m("ticks to 95% sprint speed", n)
	await _ticks(20)
	z0 = _p.global_position.z
	_release_all()
	n = 0
	while _p.horizontal_speed() > 0.05 and n < 120:
		await _ticks(1)
		n += 1
	_m("sprint stop: ticks / metres", "%d / %.2f" % [n, absf(_p.global_position.z - z0)])
	_check(absf(_p.global_position.z - z0) < 0.9, "sprint: stops within 0.9 m")
	# strafe reversal (A -> D)
	await _place(Vector3(0, 0.02, 30))
	Input.action_press(&"move_left")
	await _ticks(30)
	Input.action_release(&"move_left")
	Input.action_press(&"move_right")
	n = 0
	while _p.global_basis.x.dot(_p.velocity) < _walk * 0.95 and n < 120:
		await _ticks(1)
		n += 1
	_m("strafe reversal: ticks to 95% the other way", n)
	_check(n <= 20, "strafe reversal within 0.33 s")
	# diagonal speed
	await _place(Vector3(0, 0.02, 30))
	Input.action_press(&"move_forward")
	Input.action_press(&"move_right")
	await _ticks(40)
	_m("diagonal speed / walk speed", "%.3f" % (_p.horizontal_speed() / _walk))
	_check(absf(_p.horizontal_speed() / _walk - 1.0) < 0.02, "diagonal movement is no faster than straight")


# ---------------------------------------------------------------- jump

## One jump from the current state. Returns [apex m, air ticks, horizontal metres].
func _one_jump() -> Array:
	var y0: float = _p.global_position.y
	var p0: Vector3 = _p.global_position
	await _tap_jump()
	var apex: float = 0.0
	var n: int = 0
	var left: bool = false
	while n < 240:
		await _ticks(1)
		n += 1
		apex = maxf(apex, _p.global_position.y - y0)
		if not _p.is_on_floor():
			left = true
		elif left:
			break
	var d: Vector3 = _p.global_position - p0
	return [apex, n, Vector2(d.x, d.z).length()]


func _jump() -> void:
	await _place(Vector3(0, 0.02, 30))
	var r: Array = await _one_jump()
	_m("standing jump: apex m / air ticks", "%.2f / %d" % [r[0], r[1]])
	_check(float(r[0]) > 0.5 and float(r[0]) < 0.8, "jump apex stays 0.5..0.8 m (ledges and mantles keep their reach)")
	_check(int(r[1]) <= 40, "a standing jump is back on the floor within 0.67 s")
	await _place(Vector3(0, 0.02, 30))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _ticks(40)
	r = await _one_jump()
	_m("sprint jump: metres / air ticks", "%.2f / %d" % [r[2], r[1]])
	# air control: a standing jump, then push forward
	await _place(Vector3(0, 0.02, 30))
	await _tap_jump()
	await _ticks(2)
	Input.action_press(&"move_forward")
	var z0: float = _p.global_position.z
	var left: bool = false
	var n: int = 0
	var top: float = 0.0
	while n < 240:
		await _ticks(1)
		n += 1
		if not _p.is_on_floor():
			left = true
			top = maxf(top, _p.horizontal_speed())
		elif left:
			break
	_m("air control: standing jump + forward, metres / top m/s", "%.2f / %.2f" % [absf(_p.global_position.z - z0), top])
	_check(top > _walk * 0.5, "air control reaches half walk speed from a standing jump")
	_check(top <= _walk * 1.02, "and never more than walk speed (no air gain)")
	# no bunny-hop gain: sprint, jump on every landing
	await _place(Vector3(0, 0.02, 30))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _ticks(40)
	var fastest: float = 0.0
	for hop: int in 4:
		await _one_jump()
		fastest = maxf(fastest, _p.horizontal_speed())
	_m("chained sprint jumps: top speed / sprint speed", "%.3f" % (fastest / _sprint))
	_check(fastest <= _sprint * 1.03, "chained jumps gain no speed")


# ---------------------------------------------------------------- coyote time and the jump buffer

## Walks off the 2 m ledge, presses jump `late` ticks after the feet left it. True if the press jumped.
func _coyote(late: int) -> bool:
	await _place(Vector3(120, 2.02, 3.0))
	Input.action_press(&"move_forward")
	var n: int = 0
	while _p.is_on_floor() and n < 200:
		await _ticks(1)
		n += 1
	if late > 1:
		await _ticks(late - 1)
	await _tap_jump()
	await _ticks(1)
	return _p.velocity.y > 1.5


## A jump on the flat, with a second press `early` ticks before the landing. True if the second press jumped.
func _buffered(early: int, air_ticks: int) -> bool:
	await _place(Vector3(0, 0.02, 30))
	await _tap_jump()
	await _ticks(maxi(1, air_ticks - early - 2))
	await _tap_jump()
	for i: int in early + 6:
		await _ticks(1)
		if _p.velocity.y > 1.5 and _p.global_position.y < 0.3:
			return true
	return false


func _forgiveness() -> void:
	var latest: int = 0
	for late: int in [1, 2, 3, 4, 5, 6, 8, 10, 14]:
		if await _coyote(late):
			latest = late
	_m("coyote: latest jump press after leaving a ledge (ticks)", latest)
	_check(latest >= 5 and latest <= 8, "a jump pressed up to ~0.1 s after walking off a ledge still jumps")
	await _place(Vector3(0, 0.02, 30))
	var air: int = int((await _one_jump())[1])
	var earliest: int = 0
	for early: int in [1, 2, 3, 4, 5, 6, 7, 8, 10, 14]:
		if await _buffered(early, air):
			earliest = early
	_m("jump buffer: earliest press before landing that jumps (ticks)", earliest)
	_check(earliest >= 5 and earliest <= 9, "a jump pressed up to ~0.12 s before landing jumps on landing")
	# the forgiveness must not hand out a second jump in the air
	await _place(Vector3(0, 0.02, 30))
	await _tap_jump()
	await _ticks(8)
	var vy: float = _p.velocity.y
	await _tap_jump()
	await _ticks(1)
	_check(_p.velocity.y < vy, "no second jump in mid-air")


# ---------------------------------------------------------------- kerbs and stairs

## Walks at a kerb of height h from 3 m out. Returns [climbed, ticks to 1.5 m past the edge (or -1), largest eye
## move in one tick (m), slowest speed on the way (m/s)].
func _walk_kerb(x: float, h: float, sprint: bool) -> Array:
	await _place(Vector3(x, 0.02, 3.0))
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint")
	var n: int = 0
	var jerk: float = 0.0
	var slow: float = 99.0
	var last: float = _eye_y()
	var bob: float = 0.0
	var reached: int = -1
	while n < 150:
		await _ticks(1)
		n += 1
		var e: float = _eye_y()
		if n > 12:
			if _p.global_position.z > 0.6:
				bob = maxf(bob, absf(e - last))        # the bob's own tick-to-tick move, measured before the kerb
			else:
				jerk = maxf(jerk, absf(e - last))
				slow = minf(slow, _p.horizontal_speed())
		last = e
		if _p.global_position.z < -1.5:
			reached = n
			break
	return [reached > 0 and absf(_p.global_position.y - h) < 0.03, reached, jerk, slow, bob]


func _kerbs() -> void:
	await _place(Vector3(0, 0.02, 3.0))
	Input.action_press(&"move_forward")
	var flat: int = 0
	while _p.global_position.z > -1.5 and flat < 150:
		await _ticks(1)
		flat += 1
	_m("flat reference: ticks to walk 4.5 m", flat)
	for i: int in KERBS.size():
		var h: float = float(KERBS[i])
		var r: Array = await _walk_kerb(10.0 + 6.0 * float(i), h, false)
		_m("kerb %.2f m: climbed / ticks lost / eye m per tick / slowest m/s" % h, "%s / %s / %.3f / %.2f" % [r[0], (int(r[1]) - flat) if int(r[1]) > 0 else "-", r[2], r[3]])
		if h <= 0.36:
			_check(bool(r[0]), "walks up a %.2f m kerb without a jump" % h)
			_check(int(r[1]) > 0 and int(r[1]) - flat <= 6, "a %.2f m kerb costs under 0.1 s" % h)
			_check(int(r[1]) - flat >= -1, "and gives no head start" )
			_check(float(r[2]) <= 0.06, "the eye moves under 6 cm in any tick on a %.2f m kerb (no camera jolt)" % h)
		else:
			_check(not bool(r[0]), "a %.2f m kerb still needs a jump or a mantle" % h)
	# stepping off the far end of the 0.35 m kerb: stays grounded, the eye eases down
	var x35: float = 10.0 + 6.0 * 4.0
	await _place(Vector3(x35, 0.37, -1.5), 180.0)
	Input.action_press(&"move_forward")
	var air: int = 0
	var jerk: float = 0.0
	var last: float = _eye_y()
	for n: int in 60:
		await _ticks(1)
		if not _p.is_on_floor():
			air += 1
		if n > 12:
			jerk = maxf(jerk, absf(_eye_y() - last))
		last = _eye_y()
	_m("step down 0.35 m: airborne ticks / eye m per tick", "%d / %.3f" % [air, jerk])
	_check(air <= 1, "a 0.35 m step down keeps the feet on the floor")
	_check(jerk <= 0.06, "and the eye eases down (under 6 cm in any tick)")


func _stairs() -> void:
	var top_y: float = STEP_RISE * float(STEPS)
	for sprint: bool in [false, true]:
		await _place(Vector3(50, 0.02, 2.0))
		Input.action_press(&"move_forward")
		if sprint:
			Input.action_press(&"sprint")
		var n: int = 0
		var jerk: float = 0.0
		var air: int = 0
		var last: float = _eye_y()
		var on_stairs: int = 0
		var slow: float = 99.0
		while n < 300 and _p.global_position.z > -STEP_RUN * float(STEPS) - 1.0:
			await _ticks(1)
			n += 1
			if _p.global_position.z < 0.3:
				on_stairs += 1
				jerk = maxf(jerk, absf(_eye_y() - last))
				slow = minf(slow, _p.horizontal_speed())
				if not _p.is_on_floor():
					air += 1
			last = _eye_y()
		var climbed: bool = absf(_p.global_position.y - top_y) < 0.03
		var run: float = STEP_RUN * float(STEPS) + 1.3
		var spd: float = run / (float(maxi(1, on_stairs)) * DT)
		var name_: String = "sprint" if sprint else "walk"
		_m("stairs up (%s): climbed / m/s / slowest / eye m per tick / air ticks" % name_, "%s / %.2f / %.2f / %.3f / %d" % [climbed, spd, slow, jerk, air])
		_check(climbed, "%s up a 0.18 m x 0.30 m staircase" % name_)
		_check(spd > (_sprint if sprint else _walk) * 0.6, "%s: keeps over 60%% of its speed on the stairs" % name_)
		_check(spd < (_sprint if sprint else _walk) * 1.02, "%s: and gains none from the steps" % name_)
		_check(jerk <= 0.12, "%s: the eye moves under 12 cm in any tick on the stairs" % name_)
	# down
	await _place(Vector3(50, top_y + 0.02, -STEP_RUN * float(STEPS) - 1.5), 180.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var air_d: int = 0
	var jerk_d: float = 0.0
	var last_d: float = _eye_y()
	var n_d: int = 0
	while n_d < 200 and _p.global_position.z < 1.0:
		await _ticks(1)
		n_d += 1
		if _p.global_position.z > -STEP_RUN * float(STEPS):
			jerk_d = maxf(jerk_d, absf(_eye_y() - last_d))
			if not _p.is_on_floor():
				air_d += 1
		last_d = _eye_y()
	_m("stairs down (sprint): air ticks / eye m per tick", "%d / %.3f" % [air_d, jerk_d])
	_check(air_d <= 4, "sprinting down the stairs keeps the feet on them")
	_check(jerk_d <= 0.12, "and the eye moves under 12 cm in any tick")


# ---------------------------------------------------------------- walls, corners, doorways

func _slides() -> void:
	# a wall met at 45 degrees: the body slides along it at walk x cos 45
	await _place(Vector3(70, 0.02, -7.0), 45.0)
	Input.action_press(&"move_forward")
	await _ticks(90)
	_m("wall at 45 deg: speed along it / walk speed", "%.2f" % (_p.horizontal_speed() / _walk))
	_check(_p.horizontal_speed() > _walk * 0.65, "slides along a wall met at 45 degrees (no sticking)")
	# a box corner clipped by 10 cm of the capsule
	for row: Array in [[90.0, "a wall corner"], [140.0, "a low crate's corner"]]:
		await _place(Vector3(float(row[0]), 0.02, 0.0))
		Input.action_press(&"move_forward")
		var n: int = 0
		var slow: float = 99.0
		while n < 300 and _p.global_position.z > -8.0:
			await _ticks(1)
			n += 1
			if n > 12:
				slow = minf(slow, _p.horizontal_speed())
		_m("%s clipped by 10 cm: ticks for 8 m / slowest m/s / height after" % str(row[1]), "%d / %.2f / %.2f" % [n, slow, _p.global_position.y])
		_check(n < 125, "%s: past it within 0.2 s of the clear walk" % str(row[1]))
	# a 0.9 m doorway entered 0.2 m off centre
	await _place(Vector3(104.2, 0.02, 0.0))
	Input.action_press(&"move_forward")
	var nd: int = 0
	while nd < 300 and _p.global_position.z > -8.0:
		await _ticks(1)
		nd += 1
	_m("0.9 m doorway, 0.2 m off centre: ticks for 8 m", nd)
	_check(nd < 125, "a doorway entered off centre lets you through within 0.2 s of the clear walk")


# ---------------------------------------------------------------- ramp

func _ramp() -> void:
	await _place(Vector3(130, 0.02, 4.0))
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var air: int = 0
	var n: int = 0
	var slow: float = 99.0
	var peak: float = 0.0
	while n < 300 and _p.global_position.z > -9.0:
		await _ticks(1)
		n += 1
		if _p.global_position.z < 0.0:
			if not _p.is_on_floor():
				air += 1
			slow = minf(slow, _p.horizontal_speed())
			peak = maxf(peak, _p.global_position.y)
	_m("ramp up + crest (sprint): air ticks / slowest m/s / peak y", "%d / %.2f / %.2f" % [air, slow, peak])
	_check(air <= 1 and peak < 3.05, "no launch off the crest of a ramp")
	await _place(Vector3(130, 3.02, -9.0), 180.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	air = 0
	n = 0
	while n < 300 and _p.global_position.z < 3.0:
		await _ticks(1)
		n += 1
		if not _p.is_on_floor():
			air += 1
	_m("ramp down (sprint): air ticks", air)
	_check(air <= 1, "sprinting down a ramp keeps the feet on it")
