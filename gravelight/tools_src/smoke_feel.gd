extends Node
## Update 02 §1 (T-046) movement-feel QA on the Test Range: drives the real Player through its input actions and
## checks there are no eaten inputs (fire / ADS out of a sprint, fire during a slide), Hold and Toggle sprint, the
## acceleration curve, prone, and mantling: a vault over a 1.1 m block, a climb onto a deep 0.9 m platform, and
## refusals for a 1.6 m wall and a zombie barricade window; never ending inside geometry.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_feel.tscn
## Prints "[feel-qa] ..." lines and "[feel-qa] RESULT PASS|FAIL".

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []
var _shots: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["bots"] = 0
	GLSettings.values["sprint_mode"] = "hold"
	GLSettings.values["prone_enabled"] = false
	GameState.god_mode = true
	_map = (load("res://gravelight/maps/test_range/test_range.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	GLBus.weapon_fired.connect(func(_pid: int, _w: StringName, _u: bool, _o: Vector3, _d: Vector3) -> void: _shots += 1)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	print("[feel-qa] %-64s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _release_all() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint", &"fire", &"ads", &"crouch", &"jump"]:
		Input.action_release(a)


func _place(pos: Vector3, yaw_deg: float) -> void:
	_release_all()
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw_deg)
	_p.set("_pitch", 0.0)
	_p.crouching = false
	_p.prone = false
	_p.set("_stamina", 4.0)      # every check starts rested
	await _frames(4)


func _arm(id: StringName) -> void:
	var h: WeaponHolder = _p.weapons
	if h.current() == null or h.current().id != id:
		h.give_weapon(id)
	h.current().refill()
	h.set("_swap_t", 0.0)


func _box(name_: String, a: Vector3, b: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = (b - a).abs()
	cs.shape = bs
	body.add_child(cs)
	_map.add_child(body)
	body.global_position = (a + b) * 0.5
	return body


## The player is inside nothing that blocks it (a capsule overlap test at its own size).
func _embedded() -> bool:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.05
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Player.MASK_MOVE
	q.exclude = [_p.get_rid()]
	q.transform = Transform3D(Basis(), _p.global_position + Vector3.UP * 0.6)
	return not _p.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _run() -> void:
	await _frames(20)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.phase = GameState.Phase.PLAYING
	_p.set_process_unhandled_input(false)
	# extra geometry: a 1.6 m wall, a deep 0.9 m platform, and a barricaded window in a 0.9 m sill wall
	_box("TallWall", Vector3(30.0, 0, 20.0), Vector3(32.0, 1.6, 20.4))
	_box("Platform", Vector3(36.0, 0, 18.0), Vector3(40.0, 0.9, 21.0))
	_box("SillWall", Vector3(3.2, 0, 20.0), Vector3(4.8, 0.9, 20.3))
	var bar: Barricade = Barricade.new()
	bar.name = "QAWindow"
	bar.position = Vector3(4.0, 0, 20.15)
	# local +Z (into the room) is world +Z: the player's side
	_map.add_child(bar)
	await _frames(5)

	# ---- acceleration: ~0.12 s to walk speed, a short slide to a stop
	await _place(Vector3(20.0, 0.05, 28.0), 0.0)
	_arm(&"thompson")
	Input.action_press(&"move_forward")
	await _frames(4)
	var early: float = _p.horizontal_speed()
	await _frames(8)
	var walk: float = float(GLData.table("player")["walk_speed"]) * _p.weapons.move_mult()
	_check(early > 0.5 and early < walk * 0.85, "accelerates over a few frames (%.2f m/s after 4)" % early)
	_check(_p.horizontal_speed() > walk * 0.95, "full walk speed by ~0.2 s (%.2f)" % _p.horizontal_speed())
	Input.action_release(&"move_forward")
	await _frames(3)
	_check(_p.horizontal_speed() > 0.3, "keeps a little speed just after letting go (slide on stop)")
	await _frames(15)
	_check(_p.horizontal_speed() < 0.05, "and stops within ~0.3 s")

	# ---- sprint -> fire (sprint still held): sprint cancels at once, the shot leaves at the sprint-out
	await _place(Vector3(14.0, 0.05, 28.0), 0.0)
	_arm(&"thompson")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(40)
	_check(_p.sprinting, "sprinting")
	var s0: int = _shots
	Input.action_press(&"fire")
	await _frames(1)
	_check(not _p.sprinting, "fire input cancels the sprint on the same frame")
	var n: int = 1
	while _shots == s0 and n < 60:
		await _frames(1)
		n += 1
	var so: float = WeaponHolder.sprint_out_time(_p.weapons.current())
	_check(_shots > s0 and n <= int(ceil(so * 60.0)) + 1, "the shot fires within sprint-out (%.2f s) + 1 frame (%d frames)" % [so, n])
	Input.action_release(&"fire")
	await _frames(30)
	_check(_p.sprinting, "Hold mode: the sprint comes back after fire is released")

	# ---- a single-frame tap of a semi-auto pistol during a sprint is not lost
	_arm(&"m1911")
	await _frames(30)
	_check(_p.sprinting, "sprinting again (pistol)")
	s0 = _shots
	Input.action_press(&"fire")
	await _frames(1)
	Input.action_release(&"fire")
	await _frames(int(ceil(0.15 * 60.0)) + 3)
	_check(_shots == s0 + 1, "a one-frame pistol tap out of a sprint fires exactly once")

	# ---- ADS during a sprint starts ADS
	await _frames(30)
	_check(_p.sprinting, "sprinting before ADS")
	Input.action_press(&"ads")
	await _frames(2)
	_check(not _p.sprinting and _p.weapons.ads_t > 0.0, "ADS input cancels the sprint and starts aiming")
	await _frames(20)
	var ads_speed: float = _p.horizontal_speed()
	_check(ads_speed < float(GLData.table("player")["walk_speed"]) * 0.7, "ADS-walk is slower than walking (%.2f m/s)" % ads_speed)
	Input.action_release(&"ads")
	_release_all()

	# ---- Toggle sprint
	GLSettings.values["sprint_mode"] = "toggle"
	await _place(Vector3(14.0, 0.05, 28.0), 0.0)
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(2)
	Input.action_release(&"sprint")
	await _frames(20)
	_check(_p.sprinting, "Toggle mode: a tap keeps sprinting")
	Input.action_press(&"fire")
	await _frames(2)
	Input.action_release(&"fire")
	await _frames(40)
	_check(not _p.sprinting, "Toggle mode: firing ends the sprint until a new press")
	GLSettings.values["sprint_mode"] = "hold"
	_release_all()

	# ---- slide: fire held from the start fires only in the last half
	await _place(Vector3(14.0, 0.05, 28.0), 0.0)
	_arm(&"m1_garand")
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await _frames(40)
	Input.action_press(&"crouch")
	await _frames(2)
	Input.action_release(&"crouch")
	_check(_p.sliding, "sprint + crouch slides")
	s0 = _shots
	Input.action_press(&"fire")
	await _frames(1)
	Input.action_release(&"fire")
	var early_shot: bool = false
	for i: int in 90:
		await _frames(1)
		if _shots > s0:
			early_shot = _p.sliding and not _p.slide_fire_ok()
			break
	_check(not early_shot and _shots > s0, "a fire press early in the slide waits for the last half, then fires")
	_release_all()

	# ---- mantle: vault the 1.1 m cover block (Cover0, z 17..18)
	await _place(Vector3(10.75, 0.05, 20.2), 0.0)
	Input.action_press(&"move_forward")
	await _frames(6)
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	var m0: int = _p.mantles
	await _frames(45)
	_check(_p.mantles == m0 + 1 or _p.mantles > 0, "jumping at a 1.1 m block mantles")
	_check(_p.global_position.z < 17.0, "vaulted to the far side (z %.2f)" % _p.global_position.z)
	_check(not _embedded() and _p.global_position.y > -0.1 and _p.global_position.y < 0.3, "landed on the floor, not inside anything (y %.2f, embedded %s)" % [_p.global_position.y, _embedded()])
	_release_all()

	# ---- climb onto a deep 0.9 m platform
	await _place(Vector3(38.0, 0.05, 23.0), 0.0)
	Input.action_press(&"move_forward")
	await _frames(4)
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(20)
	Input.action_release(&"move_forward")
	await _frames(25)
	_check(absf(_p.global_position.y - 0.9) < 0.1, "climbed onto the 0.9 m platform (y %.2f)" % _p.global_position.y)
	_check(not _embedded(), "standing on it, not inside it")
	_release_all()

	# ---- refusals: a 1.6 m wall, and a barricaded zombie window
	await _place(Vector3(31.0, 0.05, 21.2), 0.0)
	m0 = _p.mantles
	Input.action_press(&"move_forward")
	await _frames(6)
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(40)
	_check(_p.mantles == m0 and _p.global_position.z > 20.3, "no mantle over a 1.6 m wall")
	_release_all()
	await _place(Vector3(4.0, 0.05, 21.2), 0.0)
	m0 = _p.mantles
	_check(_p.probe_mantle().is_empty(), "the window probe is refused")
	Input.action_press(&"move_forward")
	await _frames(6)
	Input.action_press(&"jump")
	await _frames(2)
	Input.action_release(&"jump")
	await _frames(40)
	_check(_p.mantles == m0 and _p.global_position.z > 20.3, "a barricade window is never a player exit (z %.2f)" % _p.global_position.z)
	_release_all()

	# ---- prone (behind the setting)
	GLSettings.values["prone_enabled"] = true
	await _place(Vector3(20.0, 0.05, 26.0), 0.0)
	Input.action_press(&"crouch")
	await _frames(40)
	Input.action_release(&"crouch")
	await _frames(20)
	_check(_p.prone, "holding crouch goes prone")
	_check(float(_p.get("_eye")) < 0.75, "prone eye is low (%.2f)" % float(_p.get("_eye")))
	Input.action_press(&"crouch")
	await _frames(2)
	Input.action_release(&"crouch")
	await _frames(20)
	_check(not _p.prone and _p.crouching, "a crouch tap gets up to a crouch")
	GLSettings.values["prone_enabled"] = false
	_release_all()

	print("[feel-qa] RESULT %s (%d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)
