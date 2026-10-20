extends Node3D
## Dev tool (M7): renders the four survivors' third-person co-op bodies (RemoteBody) in a lit studio:
## standing with a rifle, walking, crouched, sprinting, and the last-stand crawl with a pistol.
## Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_coop.tscn -- --out=<dir>
## -> <dir>/coop_<pose>.png (default dir user://shots)

var _out: String = "user://shots"
var _bodies: Array[RemoteBody] = []
var _cam: Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 0.6
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
	var chars: Array[StringName] = [&"dutch", &"peg", &"deacon", &"wren"]
	var guns: Array[StringName] = [&"kar98k", &"mp40", &"trench_gun", &"stg44"]
	for i: int in 4:
		var b: RemoteBody = RemoteBody.new()
		add_child(b)
		b.position = Vector3(-3.0 + 2.0 * float(i), 0, 0)
		b.rotation.y = PI + 0.5   # three-quarter view toward the camera
		b.setup(chars[i], i + 1)
		b.set_weapon(guns[i])
		_bodies.append(b)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.position = Vector3(0, 1.6, 5.5)
	_cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	_cam.current = true
	var poses: Array = [["stand", 0.0, 0.0, 0], ["walk", 2.0, 0.1, 0], ["crouch", 0.0, -0.2, NetMatch.PF_CROUCH],
		["sprint", 5.5, 0.0, NetMatch.PF_SPRINT], ["laststand", 0.6, 0.2, NetMatch.PF_DOWNED]]
	for p: Array in poses:
		if str(p[0]) == "laststand":
			for b2: RemoteBody in _bodies:
				b2.set_weapon(&"m1911")
		for f: int in 90:
			for b3: RemoteBody in _bodies:
				b3.update_pose(1.0 / 60.0, float(p[1]), float(p[2]), int(p[3]))
			if f == 88 and str(p[0]) == "stand":
				for b4: RemoteBody in _bodies:
					b4.fire(0, &"", Vector3.ZERO, Vector3.ZERO)
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = _out.path_join("coop_%s.png" % str(p[0]))
		img.save_png(path)
		print("shot ", path)
	get_tree().quit()
