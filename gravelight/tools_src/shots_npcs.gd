extends Node3D
## Dev tool (T-246): the NPCs' bodies in a moonlit snow studio, for the owner's "little bugs" screenshots (Trudi's
## stocking leg through her skirt, the knife held flat on the chest, the gun slung through the chest) and the
## "more alive" idles. Row 1: the companions and Jakub (RemoteBody, as they wait: their melee or a long gun);
## row 2: the people standing about (PatronBody: Pohl, Kroll, Kubiak, Trudi in the opening).
## Shots: front, the waiting fidgets, walking (side, front), the PatronBody poses, a close crop per person.
## Rendered only through WSL (invisible):
##   sh tools/wsl_godot.sh --res=1920x1080 --path . res://gravelight/tools_src/shots_npcs.tscn -- --out=res://docs/captures/u18_npcs/after
## -> <out>/npcs_<shot>.png

var _out: String = "user://shots/npcs"
var _remote: Array[RemoteBody] = []
var _patrons: Array[PatronBody] = []
var _cam: Camera3D
const REMOTE: Array = [[&"trudi", &"trench_knife"], [&"trudi", &"kar98k"], [&"jakub", &"coal_shovel"], [&"jakub", &"kar98k"]]
const PATRONS: Array = [["pohl", "stand"], ["kroll", "stand"], ["kubiak", "stand"], ["trudi", "stand"]]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	RemoteBody.pose_lod = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() and not _out.begins_with("res://") else ProjectSettings.globalize_path(_out))
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, 25, 0)
	moon.light_energy = 1.1
	moon.light_color = Color(0.75, 0.82, 1.0)
	moon.shadow_enabled = true
	add_child(moon)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.position = Vector3(0, 3.0, 5.0)
	fill.omni_range = 14.0
	fill.light_energy = 0.6
	fill.light_color = Color(1.0, 0.8, 0.6)
	add_child(fill)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mi.mesh = pm
	floor_mi.material_override = Interactable.greybox_mat(Color(0.72, 0.74, 0.8))
	add_child(floor_mi)
	for i: int in REMOTE.size():
		var b: RemoteBody = RemoteBody.new()
		add_child(b)
		b.position = Vector3(-2.7 + 1.8 * float(i), 0, 0)
		b.setup(REMOTE[i][0], 20 + i)
		b.set_weapon(REMOTE[i][1])
		(b.get("_tag") as Label3D).visible = false
		_remote.append(b)
	for j: int in PATRONS.size():
		var pb: PatronBody = PatronBody.new()
		add_child(pb)
		pb.position = Vector3(-2.7 + 1.8 * float(j), 0, -3.0)
		pb.setup({"id": PATRONS[j][0], "person": PATRONS[j][0], "pose": PATRONS[j][1]})
		_patrons.append(pb)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.fov = 40.0
	_cam.current = true
	_run.call_deferred()


func _aim(at: Vector3, from: Vector3) -> void:
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)


func _face(yaw: float) -> void:
	for b: RemoteBody in _remote:
		b.rotation.y = yaw
	for p: PatronBody in _patrons:
		p.rotation.y = yaw


func _frames(n: int, speed: float, each: Callable = Callable()) -> void:
	for f: int in n:
		for b: RemoteBody in _remote:
			if each.is_valid():
				each.call(b, f)
			b.update_pose(1.0 / 60.0, speed, 0.0, NetMatch.PF_FLOOR)
		await get_tree().process_frame


func _save(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join("npcs_%s.png" % shot)
	img.save_png(path if not path.begins_with("res://") else ProjectSettings.globalize_path(path))
	print("[shots_npcs] ", path)


func _force_fidget(kind: StringName) -> void:
	for b: RemoteBody in _remote:
		b.set("_still_t", 3.0)
		b.set("_fidget_t", 0.01)
		b.set("_fidget_kind", kind)


func _force_idle(p: PatronBody, kind: StringName) -> void:
	if p.life == null:
		return
	p.life.idle = kind
	p.life.set("_idle_t", 0.0)
	p.life.set("_idle_len", 999.0)
	p.life.set("_last_idle", kind)


func _run() -> void:
	await get_tree().process_frame
	var probe: RemoteBody = RemoteBody.new()
	var after: bool = probe.has_method("set_life")   # (the same tool made the before shots on master)
	probe.free()
	# row 1, front three-quarter, standing, then the waiting fidgets (calm, still)
	_face(PI + 0.3)
	_aim(Vector3(0, 1.0, 0), Vector3(0.6, 1.5, 7.5))
	await _frames(40, 0.0)
	await _save("remote_front")
	_force_fidget(&"watch" if not after else &"warm")
	await _frames(60, 0.0, func(b: RemoteBody, _f: int) -> void: b.calm = true)
	await _save("remote_fidget")
	if after:
		_force_fidget(&"hug")
		await _frames(60, 0.0, func(b: RemoteBody, _f: int) -> void:
			b.calm = true
			b.set("_fidget_t", 1.0))
		await _save("remote_fidget_hug")
	# walking: side and front (the legs inside a long skirt)
	_face(PI * 0.5)
	await _frames(37, 1.6, func(b: RemoteBody, _f: int) -> void: b.calm = false)
	await _save("remote_walk_side")
	_face(PI + 0.15)
	await _frames(23, 1.6)
	await _save("remote_walk_front")
	# close-ups of Trudi and Jakub in their own fidget
	_face(PI + 0.4)
	_force_fidget(&"watch" if not after else &"warm")
	await _frames(70, 0.0, func(b: RemoteBody, _f: int) -> void:
		b.calm = true
		b.set("_fidget_t", 1.0))
	_aim(Vector3(-2.7, 0.95, 0), Vector3(-2.2, 1.35, 2.6))
	await _save("trudi_fidget_close")
	_aim(Vector3(2.7, 0.95, 0), Vector3(3.2, 1.35, 2.6))
	await _save("jakub_fidget_close")
	# row 2: the PatronBody people
	for b3: RemoteBody in _remote:
		b3.cinema_hidden = true
		b3.visible = false
	_face(PI + 0.3)
	_aim(Vector3(0, 1.0, -3.0), Vector3(0.6, 1.5, 4.5))
	await _frames(40, 0.0)
	await _save("patrons_stand")
	for p: PatronBody in _patrons:
		p.set_pose(&"panic")
	await _frames(40, 0.0)
	await _save("patrons_panic")
	for p3: PatronBody in _patrons:
		p3.set_pose(&"stand")
	await _frames(40, 0.0)
	_aim(Vector3(2.7, 0.95, -3.0), Vector3(3.2, 1.35, -0.4))
	await _save("trudi_patron_close")
	if not after:
		get_tree().quit()
		return
	# T-246: the life on the PatronBody people (breath fog forced on: the studio has no map to say it is cold)
	for p4: PatronBody in _patrons:
		var l: NpcLife = p4.enable_life()
		l.cold = true
		l.set("_fog", l._make_fog(l.get("_head")))
	_aim(Vector3(0, 1.0, -3.0), Vector3(0.6, 1.5, 4.5))
	var kinds: Array[StringName] = [&"warm", &"hug", &"adjust", &"warm"]
	for i: int in _patrons.size():
		_force_idle(_patrons[i], kinds[i])
	await _frames(90, 0.0)
	await _save("patrons_idles")
	_aim(Vector3(-2.7, 1.1, -3.0), Vector3(-2.3, 1.45, -1.2))
	await _save("pohl_warm_close")
	_aim(Vector3(-0.9, 1.1, -3.0), Vector3(-0.5, 1.45, -1.2))
	await _save("kroll_hug_close")
	_aim(Vector3(0, 1.0, -3.0), Vector3(0.6, 1.5, 4.5))
	for i2: int in _patrons.size():
		_patrons[i2].life.idle = &""
	await _frames(70, 0.0, func(_b: RemoteBody, _f: int) -> void:
		for p5: PatronBody in _patrons:
			p5.life.set("_aimed", true))
	await _save("patrons_hands_up")
	get_tree().quit()
