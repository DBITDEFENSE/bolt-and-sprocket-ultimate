extends Node3D
## Dev tool (T-254): proof that the Crucible's room finds its own wall. A bare test cellar (no map): the same machine
## stood against the north wall under a 3.4 m ceiling, then against the east wall (0.9 m off it, a 2.9 m ceiling), then
## free in the middle of the floor; each time the room probes with rays and builds its housing into what it finds.
## WSL + Xvfb only:
##   tools/wsl_godot.sh --path . res://gravelight/tools_src/shots_u19_probe.tscn -- [--out=<dir>]
## -> docs/captures/u19_box_crucible/probe/probe_<north|east|free>_<front|side>.png, and the probe's numbers on stdout.

var _out: String = ""
var _cam: Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/u19_box_crucible/probe")
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.46)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	_slab(Vector3(-7, -0.4, -7), Vector3(7, 0, 7), "cellar_floor")
	_slab(Vector3(-7, 0, 1.3), Vector3(7, 6, 1.8), "cellar_stone")          # the north wall (+Z)
	_slab(Vector3(4.0, 0, -7), Vector3(4.5, 6, 7), "plaster_cellar")        # the east wall (+X)
	_slab(Vector3(-7, 3.4, -2), Vector3(2.0, 3.8, 7), "brick_cellar")       # a ceiling over the north half
	_slab(Vector3(2.0, 2.9, -7), Vector3(7, 3.3, 7), "planks")              # a lower one along the east wall
	for lp: Vector3 in [Vector3(-2, 2.9, -3.0), Vector3(1.2, 2.5, -3.6), Vector3(-3, 2.6, -5.5)]:
		var l: OmniLight3D = OmniLight3D.new()
		l.position = lp
		l.light_color = Color(1.0, 0.8, 0.6)
		l.light_energy = 1.4
		l.omni_range = 9.0
		add_child(l)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	GameState.power_on = true
	_run.call_deferred()


func _slab(lo: Vector3, hi: Vector3, key: String) -> void:
	var sb: StaticBody3D = StaticBody3D.new()
	sb.collision_layer = 1
	sb.position = (lo + hi) * 0.5
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = hi - lo
	cs.shape = bs
	sb.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = hi - lo
	mi.mesh = bm
	mi.material_override = Mats.get_mat(key)
	sb.add_child(mi)
	add_child(sb)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))
	print("[probe] ", _out.path_join(shot_name + ".png"))


func _run() -> void:
	var cr: Crucible = Crucible.new()
	cr.position = Vector3(-2.0, 0, 0)
	add_child(cr)
	var room: CrucibleRoom = CrucibleRoom.new()
	room.crucible = cr
	room.map_key = "map00"
	room.data = CrucibleRoom.config_for("map00")
	add_child(room)
	room.global_transform = cr.global_transform
	room.build()
	# [name, position, yaw: the machine's back (local +Z) to the wall]
	for stand: Array in [["north", Vector3(-2.0, 0, 0), 0.0], ["east", Vector3(3.1, 0, -2.0), 90.0], ["free", Vector3(-2.5, 0, -4.2), 200.0]]:
		cr.position = stand[1]
		cr.rotation_degrees.y = float(stand[2])
		for i: int in 4:
			await get_tree().physics_frame
		room.refit()
		print("[probe] %s: probe %s housing %s" % [stand[0], room.probe, room.sur])
		var xf: Transform3D = cr.global_transform
		await get_tree().create_timer(0.8).timeout
		_cam.fov = 70.0
		_cam.global_position = xf * Vector3(1.5, 1.6, -4.2)
		_cam.look_at(xf * Vector3(0, 1.7, 0.3), Vector3.UP)
		await get_tree().create_timer(0.5).timeout
		await _shot("probe_%s_front" % stand[0])
		_cam.global_position = xf * Vector3(-3.6, 1.5, -1.6)
		_cam.look_at(xf * Vector3(0, 1.7, 0.6), Vector3.UP)
		await get_tree().create_timer(0.5).timeout
		await _shot("probe_%s_side" % stand[0])
	get_tree().quit()
