extends Node
## Movement at different frame rates and tick rates (docs/perf/movement_perf_2026-11.md). The real local Player on
## a flat floor, driven through its input actions like smoke_move_feel, with smooth motion forced on (the camera
## and the viewmodel at the render rate; headless turns it off, so this is the only place it runs without a
## window). It measures what should NOT change with the frame rate:
##   the body      seconds to top speed, metres in 2 s, the stop, the jump, the sprint jump, a strafe reversal
##   the eye       how evenly the camera moves per rendered frame at a steady walk, and how long after a key
##                 press it first moves
##   the springs   the recoil kick's peak and the landing dip's depth, the sprint FOV's ease, the head bob's ease
##   the gun       the viewmodel's look sway under a steady turn
##   the pad       the right stick's turn rate and the share of rendered frames in which the view turns
## Run it at a fixed frame rate (the engine flag before the `--`): tools/move_rates.sh runs 30 / 60 / 144 / 240
## and tools/move_rates_table.py prints them side by side.
##   godot --headless --audio-driver Dummy --fixed-fps 144 --path . res://gravelight/tools_src/move_rates.tscn
## `-- --ticks=N` also changes the physics tick rate (the game ships at 60: this shows what the movement code
## itself does with another step, not something a player can reach).
## Prints "[move-rates] <metric> = <value>" lines and "[move-rates] RESULT PASS".

## Emitted at the end of every rendered frame, after the player's own _process (this node runs last): a read after
## it sees what that frame would have drawn.
signal rendered

var _p: Player
var _dt: float = 1.0 / 60.0     # one physics tick (s)
var _walk: float = 4.5
var _sprint: float = 6.8


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			Engine.physics_ticks_per_second = clampi(int(a.substr(8)), 10, 480)
	_dt = 1.0 / float(Engine.physics_ticks_per_second)
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["bots"] = 0
	GLSettings.values["sprint_mode"] = "hold"
	GLSettings.values["prone_enabled"] = false
	GLSettings.values["screen_shake"] = 1.0
	GameState.god_mode = true
	GameState.player_ids = [1]
	GLSettings.apply_bindings()
	process_priority = 1000
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rendered.emit()


func _m(what: String, value: Variant) -> void:
	print("[move-rates] %-52s = %s" % [what, str(value)])


func _ticks(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await _ticks(maxi(1, roundi(s / _dt)))


func _frames(n: int) -> void:
	for i: int in n:
		await rendered


func _release_all() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"fire", &"ads", &"crouch", &"jump",
			&"look_left", &"look_right", &"look_up", &"look_down"]:
		Input.action_release(a)


func _place() -> void:
	_release_all()
	_p.global_position = Vector3(0, 0.02, 0)
	_p.velocity = Vector3.ZERO
	_p.rotation.y = 0.0
	_p.set("_pitch", 0.0)
	_p.crouching = false
	_p.sliding = false
	_p.sprinting = false
	_p.set("_stamina", 4.0)
	_p.set("_slide_cd", 0.0)
	_p.set("_jump_buf", 0.0)
	_p.set("_view_off", Vector3.ZERO)
	await _secs(0.4)


func _run() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(400, 1, 400)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(0, -0.5, 0)
	_p = Player.new()
	_p.name = "Player1"
	add_child(_p)
	_p.global_position = Vector3(0, 0.05, 0)
	RoundManager.stop()
	GameState.phase = GameState.Phase.PLAYING
	GameState.input_blocked = false
	_p.set_process_unhandled_input(false)
	_p.set_smooth_view(true)   # what a window runs (Settings > Video > Smooth motion, on by default)
	await _secs(0.4)
	var cfg: Dictionary = GLData.table("player")
	_walk = float(cfg["walk_speed"]) * _p.weapons.move_mult()
	_sprint = float(cfg["sprint_speed"]) * _p.weapons.move_mult()
	var fdt: float = get_process_delta_time()
	_m("frames per second / physics ticks per second", "%.0f / %d" % [1.0 / maxf(fdt, 0.0001), Engine.physics_ticks_per_second])
	await _body()
	await _eye()
	await _latency()
	await _springs()
	await _sway()
	await _pad()
	print("[move-rates] RESULT PASS")
	get_tree().quit()


# ---------------------------------------------------------------- the body (per physics tick)

func _body() -> void:
	await _place()
	var z0: float = _p.global_position.z
	Input.action_press(&"move_forward")
	var n: int = 0
	var t95: float = -1.0
	var total: int = roundi(2.0 / _dt)
	while n < total:
		await _ticks(1)
		n += 1
		if t95 < 0.0 and _p.horizontal_speed() >= _walk * 0.95:
			t95 = float(n) * _dt
	await _ticks(1)   # (the tick the last press-frame's move lands in)
	_m("walk: seconds to 95% speed", "%.3f" % t95)
	_m("walk: metres in 2 s", "%.3f" % absf(_p.global_position.z - z0))
	z0 = _p.global_position.z
	Input.action_release(&"move_forward")
	n = 0
	while _p.horizontal_speed() > 0.05 and n < 2000:
		await _ticks(1)
		n += 1
	_m("walk stop: seconds / metres", "%.3f / %.3f" % [float(n) * _dt, absf(_p.global_position.z - z0)])
	# sprint
	await _place()
	z0 = _p.global_position.z
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _ticks(total + 1)
	_m("sprint: metres in 2 s", "%.3f" % absf(_p.global_position.z - z0))
	# sprint jump
	var p0: Vector3 = _p.global_position
	var y0: float = p0.y
	Input.action_press(&"jump")
	await _ticks(1)
	Input.action_release(&"jump")
	var apex: float = 0.0
	n = 0
	var left: bool = false
	while n < 4000:
		await _ticks(1)
		n += 1
		apex = maxf(apex, _p.global_position.y - y0)
		if not _p.is_on_floor():
			left = true
		elif left:
			break
	_m("sprint jump: metres", "%.3f" % Vector2(_p.global_position.x - p0.x, _p.global_position.z - p0.z).length())
	z0 = _p.global_position.z
	_release_all()
	n = 0
	while _p.horizontal_speed() > 0.05 and n < 2000:
		await _ticks(1)
		n += 1
	_m("sprint stop: seconds / metres", "%.3f / %.3f" % [float(n) * _dt, absf(_p.global_position.z - z0)])
	# standing jump
	await _place()
	y0 = _p.global_position.y
	Input.action_press(&"jump")
	await _ticks(1)
	Input.action_release(&"jump")
	apex = 0.0
	n = 0
	left = false
	while n < 4000:
		await _ticks(1)
		n += 1
		apex = maxf(apex, _p.global_position.y - y0)
		if not _p.is_on_floor():
			left = true
		elif left:
			break
	_m("standing jump: apex m / seconds in the air", "%.3f / %.3f" % [apex, float(n) * _dt])
	# strafe reversal
	await _place()
	Input.action_press(&"move_left")
	await _secs(0.5)
	Input.action_release(&"move_left")
	Input.action_press(&"move_right")
	n = 0
	while _p.global_basis.x.dot(_p.velocity) < _walk * 0.95 and n < 2000:
		await _ticks(1)
		n += 1
	_m("strafe reversal: seconds to 95% the other way", "%.3f" % (float(n) * _dt))


# ---------------------------------------------------------------- the eye (per rendered frame)

func _eye_pos() -> Vector3:
	return _p.camera.global_position


## At a steady walk the eye should cover walk speed x the frame's time in every rendered frame. Reports the
## slowest and the fastest frame as a share of that (1.000 = even; 0 = the picture stood still for a frame).
func _eye() -> void:
	await _place()
	Input.action_press(&"move_forward")
	await _secs(1.0)
	await _frames(2)
	var fdt: float = get_process_delta_time()
	var frames: int = maxi(30, roundi(2.0 / fdt))
	var prev: float = _eye_pos().z
	var lo: float = INF
	var hi: float = 0.0
	var still: int = 0
	var sum: float = 0.0
	for i: int in frames:
		await _frames(1)
		var z: float = _eye_pos().z
		var v: float = absf(z - prev) / fdt / _walk
		prev = z
		lo = minf(lo, v)
		hi = maxf(hi, v)
		sum += v
		if v < 0.05:
			still += 1
	_m("eye at a walk: slowest / fastest frame (x walk speed)", "%.3f / %.3f" % [lo, hi])
	_m("eye at a walk: mean (x walk speed)", "%.3f" % (sum / float(frames)))
	_m("eye at a walk: frames the picture stood still (%)", "%.1f" % (100.0 * float(still) / float(frames)))
	_release_all()


## Milliseconds from the frame a key is pressed in to the first rendered frame in which the eye has moved,
## over presses at different moments of the tick.
func _latency() -> void:
	var fdt: float = get_process_delta_time()
	var worst: float = 0.0
	var sum: float = 0.0
	var trials: int = 12
	for trial: int in trials:
		await _place()
		await _frames(1 + trial % 7)
		var z0: float = _eye_pos().z
		Input.action_press(&"move_forward")
		var f: int = 0
		while f < 400:
			await _frames(1)
			f += 1
			if absf(_eye_pos().z - z0) > 0.0005:
				break
		var ms: float = float(f) * fdt * 1000.0   # (the press lands after frame 0 was drawn: frame f is the f-th after it)
		worst = maxf(worst, ms)
		sum += ms
		_release_all()
	_m("key press to the eye moving: mean / worst ms", "%.1f / %.1f" % [sum / float(trials), worst])


# ---------------------------------------------------------------- springs and eases (per rendered frame)

func _springs() -> void:
	var fdt: float = get_process_delta_time()
	# the recoil kick: 3 degrees, none kept, on a soft (10) and a stiff (22) recovery
	for w: float in [10.0, 22.0]:
		await _place()
		await _frames(2)
		_p.kick_camera(3.0, 0.0, 0.0, w, 0.0, 0.0)
		var peak: float = 0.0
		var t_peak: float = 0.0
		var t_back: float = -1.0
		var f: int = 0
		while f < int(2.0 / fdt):
			await _frames(1)
			f += 1
			var x: float = rad_to_deg((_shown(_p, "_rk_show", "_rk") as Vector2).x)
			if x > peak:
				peak = x
				t_peak = float(f) * fdt
			elif t_back < 0.0 and x < peak * 0.1 and peak > 0.5:
				t_back = float(f) * fdt
		_m("recoil kick 3 deg, recover %.0f: peak deg / s to peak / s to 10%%" % w, "%.3f / %.3f / %.3f" % [peak, t_peak, t_back])
	# the landing dip: a 7 m/s landing
	await _place()
	await _frames(2)
	_p.land_dip(7.0)
	var deep: float = 0.0
	var f2: int = 0
	var t_deep: float = 0.0
	while f2 < int(1.5 / fdt):
		await _frames(1)
		f2 += 1
		var d: float = -float(_shown(_p, "_land_show", "_land_dip"))
		if d > deep:
			deep = d
			t_deep = float(f2) * fdt
	_m("landing dip at 7 m/s: depth cm / s to the bottom", "%.2f / %.3f" % [deep * 100.0, t_deep])
	# the gun's own spring: the take-off dip of a jump (the same spring as the shot kick and the landing)
	await _place()
	await _frames(2)
	_p.weapons.on_jump()
	var low: float = 0.0
	var back: float = 0.0
	var t_low: float = 0.0
	var f3: int = 0
	while f3 < int(1.5 / fdt):
		await _frames(1)
		f3 += 1
		var y: float = (_shown(_p.weapons, "_vk_p_show", "_vk_p") as Vector3).y
		if y < low:
			low = y
			t_low = float(f3) * fdt
		back = maxf(back, y)
	_m("gun take-off dip: depth mm / s to the bottom / overshoot mm", "%.2f / %.3f / %.2f" % [-low * 1000.0, t_low, back * 1000.0])
	# the sprint FOV and the head bob: seconds to 90% of the change
	await _place()
	await _frames(2)
	var fov0: float = _p.camera.fov
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var fov_s: PackedFloat32Array = []
	var bob_s: PackedFloat32Array = []
	for i: int in int(2.0 / fdt):
		await _frames(1)
		fov_s.append(_p.camera.fov)
		bob_s.append(float(_p.get("_bob_k")))
	_m("sprint FOV: degrees gained / s to 90%", "%.2f / %.3f" % [fov_s[fov_s.size() - 1] - fov0, _t90(fov_s, fov0, fdt)])
	_m("head bob: s to 90% of the sprint bob", "%.3f" % _t90(bob_s, 0.0, fdt))
	_release_all()


## What a frame draws of a spring: its shown value where the build has one (TickSpring), else its state.
func _shown(o: Object, shown: String, state: String) -> Variant:
	return o.get(shown) if shown in o else o.get(state)


func _t90(s: PackedFloat32Array, from: float, fdt: float) -> float:
	var to: float = s[s.size() - 1]
	for i: int in s.size():
		if absf(s[i] - from) >= absf(to - from) * 0.9:
			return float(i + 1) * fdt
	return -1.0


# ---------------------------------------------------------------- the viewmodel's look sway

## A steady mouse turn (the same degrees a second at every frame rate, one motion event a rendered frame, as a
## mouse gives): how far the gun lags behind it.
func _sway() -> void:
	var fdt: float = get_process_delta_time()
	var sens: float = 0.0022 * GLSettings.get_f("sensitivity")
	for rate: float in [45.0, 180.0]:
		await _place()
		await _frames(2)
		var sum: float = 0.0
		var cnt: int = 0
		var hi: float = 0.0
		var total: int = int(1.5 / fdt)
		for i: int in total:
			var px: float = deg_to_rad(rate) * fdt / sens
			_p.call("_apply_look", Vector2(px, 0.0) * sens)
			_p.set("_look_delta", (_p.get("_look_delta") as Vector2) + Vector2(px, 0.0))
			if "_look_frame" in _p:   # (the mouse handler feeds both; a build before the per-frame sway has only the first)
				_p.set("_look_frame", (_p.get("_look_frame") as Vector2) + Vector2(px, 0.0))
			await _frames(1)
			var s: float = absf((_shown(_p.weapons, "_sway_show", "_sway") as Vector2).x)
			if i >= total / 2:
				sum += s
				cnt += 1
				hi = maxf(hi, s)
		_m("gun sway at a %.0f deg/s turn: mean / peak (x1000)" % rate, "%.2f / %.2f" % [sum / float(maxi(1, cnt)) * 1000.0, hi * 1000.0])


# ---------------------------------------------------------------- the pad's right stick

func _pad() -> void:
	var fdt: float = get_process_delta_time()
	await _place()
	await _frames(2)
	Input.action_press(&"look_right", 1.0)
	await _frames(3)
	var y0: float = _p.rotation.y
	var prev: float = y0
	var turned: int = 0
	var total: int = int(1.0 / fdt)
	var acc: float = 0.0
	for i: int in total:
		await _frames(1)
		var y: float = _p.rotation.y
		var d: float = absf(angle_difference(prev, y))
		acc += d
		if d > 0.00001:
			turned += 1
		prev = y
	Input.action_release(&"look_right")
	_m("pad look, stick held: deg/s", "%.1f" % (rad_to_deg(acc) / (float(total) * fdt)))
	_m("pad look: rendered frames in which the view turned (%)", "%.1f" % (100.0 * float(turned) / float(total)))
