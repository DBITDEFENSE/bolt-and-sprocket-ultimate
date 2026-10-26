extends Node3D
## Dev tool (T-092, UPDATE_05 section 4): the character lineup. Row one: the squad (Dutch, Peg, Deacon, Wren) with
## their guns, Jakub with his shovel, the three Cousins; row two: the Map 0 patrons (Rother, Kubiak, Frau Pohl,
## Trudi, Sobotta) and the three survivors upstairs (Wiesner, Fräulein Brandt, Ida Kroll). Then face close-ups of
## every expression (neutral, blink, the lip flap, fear, determined, pain, smile) for the squad and Jakub, the
## Cousins' faces, and a risen patron beside the living one.
## `-- --legacy-people` gives the before shots (the primitive bodies). Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1920x1080 --path . res://gravelight/tools_src/shots_lineup.tscn -- --out=<dir> [--legacy-people] [--only=lineup,faces]
## -> <dir>/lineup.png, lineup_row2.png, lineup_back.png, faces_<expression>.png, cousins_faces.png, risen.png

const SQUAD: Array = [[&"dutch", &"bar"], [&"peg", &"thompson"], [&"deacon", &"trench_gun"], [&"wren", &"kar98k"], [&"jakub", &"coal_shovel"]]
const COUSINS: Array = ["hammer", "reach", "alix"]
const ROW2: Array = ["rother", "kubiak", "pohl", "trudi", "sobotta", "wiesner", "brandt", "kroll"]

var _out: String = "user://shots/lineup"
var _only: PackedStringArray = []
var _cam: Camera3D
var _squad: Array[RemoteBody] = []
var _cousins: Array[Node3D] = []
var _row2: Array[PatronBody] = []
var _tags: Array[Label3D] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_studio()
	_cast()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _studio() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.105, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	we.environment = env
	add_child(we)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 25, 0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.9, 0.78)   # warm lamplight key
	key.shadow_enabled = true
	add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.55, 0.62, 0.95)   # cold moonlight from behind
	add_child(rim)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	floor_mi.material_override = Interactable.greybox_mat(Color(0.26, 0.24, 0.22))
	add_child(floor_mi)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true


func _tag(text: String, at: Vector3) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = 30
	l.pixel_size = 0.004
	l.outline_size = 6
	l.modulate = Color(0.95, 0.9, 0.8)
	l.position = at
	add_child(l)
	_tags.append(l)


func _cast() -> void:
	# row one: the squad + Jakub, then the Cousins
	for i: int in SQUAD.size():
		var b: RemoteBody = RemoteBody.new()
		add_child(b)
		b.position = Vector3(-5.0 + 1.0 * float(i), 0, 0)
		b.rotation.y = PI
		b.setup(SQUAD[i][0], 10 + i)
		b.set_weapon(SQUAD[i][1])
		(b.get("_tag") as Label3D).visible = false
		_squad.append(b)
		_tag(String(SQUAD[i][0]).capitalize(), b.position + Vector3(0, 0.08, 0.6))
	for k: int in COUSINS.size():
		var hb: HomageBoss = CousinHammer.new() if COUSINS[k] == "hammer" else (CousinReach.new() if COUSINS[k] == "reach" else CousinAlix.new())
		add_child(hb)
		var at: Vector3 = Vector3(0.25 + 1.0 * float(k), 0, 0)
		hb.spawn_homage(at, 1000.0)
		hb.set_physics_process(false)   # posed: no brain; the idle clip still plays
		hb.global_position = at
		hb.rotation.y = PI
		_cousins.append(hb)
		_tag(HomageBoss.real_name("cousin_%d" % (k + 1)), at + Vector3(0, 0.08, 0.6))
	# row two: the patrons and the survivors upstairs
	var opening: Dictionary = GLData.load_json("res://data/gravelight/map00_opening.json")
	var surv: Dictionary = GLData.load_json("res://data/gravelight/map00_survivors.json")
	var rows: Dictionary = {}
	for r: Dictionary in opening.get("patrons", []):
		rows[str(r.get("id", ""))] = r
	for r2: Dictionary in surv.get("survivors", []):
		rows[str(r2.get("id", ""))] = r2
	for j: int in ROW2.size():
		var pb: PatronBody = PatronBody.new()
		add_child(pb)
		var row: Dictionary = (rows.get(ROW2[j], {"id": ROW2[j]}) as Dictionary).duplicate(true)
		row["pose"] = "stand"
		pb.setup(row)
		pb.position = Vector3(-3.3 + 0.95 * float(j), 0, -3.2)
		pb.rotation.y = PI
		_row2.append(pb)
		_tag(str(row.get("display", ROW2[j])), pb.position + Vector3(0, 0.08, 0.6))


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(file)
	img.save_png(path)
	print("shot ", path)


func _frames(n: int, each: Callable = Callable()) -> void:
	for f: int in n:
		for b: RemoteBody in _squad:
			b.set("_since_shot", 3.0)   # no idle fidgets (they bow the head), no "determined" face
			b.update_pose(1.0 / 60.0, 0.0, 0.0, 0)
		if each.is_valid():
			each.call(f)
		await get_tree().process_frame


func _want(k: String) -> bool:
	return _only.is_empty() or _only.has(k)


func _faces() -> Array[FaceDriver]:
	var out: Array[FaceDriver] = []
	for b: RemoteBody in _squad:
		if b.person != null:
			out.append(b.person.face)
	return out


func _run() -> void:
	await _frames(30)
	if _want("lineup"):
		_cam.fov = 30.0
		_cam.position = Vector3(-1.35, 1.3, 10.2)
		_cam.look_at(Vector3(-1.35, 0.92, 0.0), Vector3.UP)
		for t: Label3D in _tags:
			t.visible = t.position.z > -1.0
		for pb: PatronBody in _row2:
			pb.visible = false
		await _frames(10)
		await _shot("lineup.png")
		_cam.position = Vector3(0.0, 1.3, 5.6)
		_cam.look_at(Vector3(0.0, 0.95, -3.2), Vector3.UP)
		for t: Label3D in _tags:
			t.visible = t.position.z < -1.0
		for pb: PatronBody in _row2:
			pb.visible = true
		for b: RemoteBody in _squad:
			b.position.x += 40.0   # out of the way (update_pose keeps them visible)
		for c: Node3D in _cousins:
			c.visible = false
		await _frames(10)
		await _shot("lineup_row2.png")
		# the backs (silhouettes, packs, the braid, the slung rifle)
		for b: RemoteBody in _squad:
			b.rotation.y = 0.0
		for c: Node3D in _cousins:
			c.rotation.y = 0.0
		_cam.position = Vector3(-1.35, 1.3, 10.2)
		_cam.look_at(Vector3(-1.35, 0.92, 0.0), Vector3.UP)
		for t: Label3D in _tags:
			t.visible = false
		for pb: PatronBody in _row2:
			pb.visible = false
		for b: RemoteBody in _squad:
			b.position.x -= 40.0
		for c: Node3D in _cousins:
			c.visible = true
		await _frames(10)
		await _shot("lineup_back.png")
		for b: RemoteBody in _squad:
			b.rotation.y = PI
		for c: Node3D in _cousins:
			c.rotation.y = PI
	if _want("faces"):
		for t: Label3D in _tags:
			t.visible = false
		# shoulder to shoulder in a front row for the close-ups
		for i: int in _squad.size():
			_squad[i].position = Vector3(-0.84 + 0.42 * float(i), 0, 3.0)
		_cam.fov = 26.0
		_cam.position = Vector3(0.0, 1.66, 4.75)
		_cam.look_at(Vector3(0.0, 1.62, 3.0), Vector3.UP)
		var exprs: Array = ["neutral", "blink", "talk", "fear", "determined", "pain", "smile"]
		for e: String in exprs:
			for fd: FaceDriver in _faces():
				fd.hold = StringName(e) if e not in ["blink", "talk"] else &"neutral"
				fd.blink_range = Vector2(99.0, 99.0)
				fd.force_blink(2.0 if e == "blink" else 0.0)
				if e == "talk":
					fd.talking = true
					fd.set("_talk_len", 5.0)
					fd.set("_talk_t", 0.1)
					fd.set("_talk_rate", 3.0)
			await _frames(45)
			await _shot("faces_%s.png" % e)
		# the Cousins' faces
		for i: int in _squad.size():
			_squad[i].position = Vector3(-5.0 + 1.0 * float(i), 0, 0)
		for k: int in _cousins.size():
			_cousins[k].global_position = Vector3(-0.5 + 0.5 * float(k), 0, 3.0)
		_cam.position = Vector3(0.0, 1.66, 4.5)
		_cam.look_at(Vector3(0.0, 1.6, 3.0), Vector3.UP)
		await _frames(20)
		await _shot("cousins_faces.png")
	if _want("risen") and PeopleBodies.available("kubiak"):
		# a risen patron beside the living one (the zombie that gets up wears the same person)
		for pb2: PatronBody in _row2:
			pb2.visible = true
		_row2[2].visible = false
		var z: MeshInstance3D = MeshInstance3D.new()
		var sk: Skeleton3D = ZombieRig.build_skeleton()
		add_child(sk)
		sk.position = Vector3(-1.4, 0, -3.2)
		sk.rotation.y = PI
		sk.add_child(z)
		z.mesh = PeopleBodies.mesh("kubiak", true)
		z.skeleton = NodePath("..")
		z.skin = sk.create_skin_from_rest_transforms()
		for c: int in sk.get_bone_count():
			if sk.get_bone_name(c).ends_with("Arm"):
				sk.set_bone_pose_rotation(c, Quaternion(Vector3.RIGHT, -0.6 if sk.get_bone_name(c).ends_with("UpperArm") else -0.3))
		_cam.fov = 34.0
		for b2: RemoteBody in _squad:
			b2.position.x += 40.0
		_cam.position = Vector3(-1.9, 1.45, -0.7)
		_cam.look_at(Vector3(-1.9, 1.15, -3.2), Vector3.UP)
		await _frames(10)
		await _shot("risen.png")
	get_tree().quit()
