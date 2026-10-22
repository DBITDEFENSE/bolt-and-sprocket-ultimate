extends Node3D
## Dev tool (U02 section 5, T-050): contact sheets of the four survivors' third-person bodies (RemoteBody) in a lit
## studio: each look from the front, the side and the back (silhouettes and gear), then every action and fidget
## pose: aim, reload, drink, buy, repair, revive, downed, and the per-character idle fidget.
## Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_bot_bodies.tscn -- --out=<dir>
## -> <dir>/body_<pose>.png (default dir user://shots)

var _out: String = "user://shots"
var _bodies: Array[RemoteBody] = []
var _cam: Camera3D
var CHARS: Array[StringName] = [&"dutch", &"peg", &"deacon", &"wren"]
var GUNS: Array[StringName] = [&"bar", &"thompson", &"trench_gun", &"kar98k"]
## --jakub: Jakub Ostrowski (U02 section 6.2) with his coal shovel, with a Kar98k and wounded (the bandage), beside
## Wren and Dutch for scale.
var _wounded: Array[bool] = [false, false, false, false]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--jakub":
			CHARS = [&"jakub", &"jakub", &"wren", &"dutch"]
			GUNS = [&"coal_shovel", &"kar98k", &"springfield", &"bar"]
			_wounded = [false, true, false, false]
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(30, 30)
	floor_mi.mesh = pm
	floor_mi.material_override = Interactable.greybox_mat(Color(0.3, 0.29, 0.27))
	add_child(floor_mi)
	for i: int in 4:
		var b: RemoteBody = RemoteBody.new()
		add_child(b)
		b.position = Vector3(-3.3 + 2.2 * float(i), 0, 0)
		b.setup(CHARS[i], 10 + i)
		b.set_weapon(GUNS[i])
		b.set_wounded(_wounded[i])
		(b.get("_tag") as Label3D).text = String(CHARS[i]).capitalize()
		_bodies.append(b)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 50.0
	_cam.position = Vector3(0, 1.5, 7.2)
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	_cam.current = true
	_run.call_deferred()


func _face(yaw: float) -> void:
	for b: RemoteBody in _bodies:
		b.rotation.y = yaw


## Runs `frames` pose frames with the given per-body setup, then saves the shot.
func _pose(shot: String, frames: int, speed: float, pitch: float, flags: int, each: Callable = Callable()) -> void:
	for f: int in frames:
		for b: RemoteBody in _bodies:
			if each.is_valid():
				each.call(b, f)
			b.update_pose(1.0 / 60.0, speed, pitch, flags)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join("body_%s.png" % shot)
	img.save_png(path)
	print("shot ", path)


func _run() -> void:
	await get_tree().process_frame
	# the looks: front (three-quarter), side, back
	_face(PI + 0.35)
	await _pose("look_front", 40, 0.0, 0.0, 0)
	_face(PI * 0.5)
	await _pose("look_side", 20, 0.0, 0.0, 0)
	_face(0.25)
	await _pose("look_back", 20, 0.0, 0.0, 0)
	_face(PI + 0.5)
	await _pose("aim_walk", 50, 2.0, 0.05, 0)
	await _pose("reload", 30, 0.0, 0.0, NetMatch.PF_RELOAD)
	await _pose("drink", 40, 0.0, 0.0, 0, func(b: RemoteBody, f: int) -> void:
		if f == 0:
			b.play_action(&"drink"))
	await _pose("buy", 30, 0.0, 0.0, 0, func(b: RemoteBody, _f: int) -> void: b.hold_action(&"buy"))
	_face(PI + 0.9)
	await _pose("repair", 40, 0.0, 0.0, 0, func(b: RemoteBody, _f: int) -> void: b.hold_action(&"repair"))
	await _pose("revive", 40, 0.0, 0.0, 0, func(b: RemoteBody, _f: int) -> void: b.hold_action(&"revive"))
	for b2: RemoteBody in _bodies:
		b2.set_weapon(&"m1911")
	await _pose("downed", 60, 0.0, 0.2, NetMatch.PF_DOWNED)
	for i: int in 4:
		_bodies[i].set_weapon(GUNS[i])
	_face(PI + 0.45)
	# fidgets: calm and still for a while (each body runs its own character's fidget)
	await _pose("settle", 30, 0.0, 0.0, 0)
	for b3: RemoteBody in _bodies:
		b3.set("_still_t", 3.0)
		b3.set("_fidget_t", 0.01)   # start the fidget now (normally after a few calm seconds)
	await _pose("fidget", 70, 0.0, 0.0, 0, func(b: RemoteBody, _f: int) -> void: b.calm = true)
	await _pose("fidget_b", 50, 0.0, 0.0, 0, func(b: RemoteBody, _f: int) -> void: b.calm = true)
	get_tree().quit()
