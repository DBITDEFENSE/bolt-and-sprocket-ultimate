extends Node3D
## Dev tool: renders the crate (closed, cycling, Herr Tamtam, offered, an empty spot) and chalk wall-buys to
## <out>/crate_*.png (default user://shots). Silent, off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://gravelight/tools_src/crate_shots.tscn -- --out=C:/dir
## crate_0: the row (closed, cycling, drummer, empty spot) with the wall-buys behind; crate_1: the same with the
## drummer's crate now offering; crate_2: close-up of the offered crate; crate_3: close-up of a closed crate;
## crate_4: close-up of an empty spot (cold lantern, chalk footprint).

var _t: float = 0.0
var _shot: int = 0
var _c0: MysteryCrate
var _c1: MysteryCrate
var _c2: MysteryCrate
var _c3: MysteryCrate
var _cam: Camera3D
var _out: String = "user://shots"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.06, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.45, 0.52)
	e.ambient_light_energy = 0.35
	e.glow_enabled = true
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var l: OmniLight3D = OmniLight3D.new()
	l.position = Vector3(0, 2.8, -2.5)
	l.omni_range = 10
	l.light_energy = 1.0
	l.light_color = Color(1.0, 0.85, 0.7)
	add_child(l)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(10, 3, 0.2)
	wall.mesh = bm
	wall.position = Vector3(0, 1.5, 0.1)
	wall.material_override = Mats.get_mat("plaster")
	add_child(wall)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(10, 0.02, 10)
	floor_mi.mesh = fm
	floor_mi.position = Vector3(0, -0.01, -3)
	floor_mi.material_override = Mats.get_mat("floorboards")
	add_child(floor_mi)
	var ids: Array = ["kar98k", "mp40", "trench_gun", "m1911"]
	for i: int in ids.size():
		var wb: WallBuy = WallBuy.new()
		wb.weapon_id = StringName(ids[i])
		wb.position = Vector3(-3.0 + i * 2.0, 1.9, 0.0)
		add_child(wb)
	CrateManager.location_index = 0
	_c0 = _crate(0, Vector3(-3.0, 0, -1.2))
	_c1 = _crate(0, Vector3(-1.0, 0, -1.2))
	_c2 = _crate(0, Vector3(1.0, 0, -1.2))
	_c3 = _crate(1, Vector3(3.0, 0, -1.2))   # not where the crate is: the empty-spot look
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.7, -5.6)
	_cam.rotation_degrees = Vector3(-9, 180, 0)
	add_child(_cam)
	await get_tree().process_frame
	for c: MysteryCrate in [_c1, _c2]:
		c.call("_open_lid")
	_c1.phase = MysteryCrate.Phase.CYCLING
	_c1.get("_float").show()
	_c2.phase = MysteryCrate.Phase.DRUMMER
	_c2.get("_drummer").show()


func _crate(spot: int, pos: Vector3) -> MysteryCrate:
	var c: MysteryCrate = MysteryCrate.new()
	c.spot_index = spot
	c.position = pos
	add_child(c)
	return c


func _save(name: String) -> void:
	get_viewport().get_texture().get_image().save_png(_out.path_join(name))


func _process(delta: float) -> void:
	_t += delta
	if _t > 15.0:
		push_error("[crate_shots] gave up (a crate failed to build?)")
		get_tree().quit(1)
		return
	if _shot == 0 and _t > 1.8:
		_save("crate_0.png")
		_shot = 1
		_c2.phase = MysteryCrate.Phase.CLOSED
		_c2.set("_result", &"ppsh41")
	elif _shot == 1 and _t > 2.2:
		_c2.call("_finish_cycle")
		_c2.get("_float").show()
		_c2.get("_drummer").hide()
		_shot = 2
	elif _shot == 2 and _t > 3.2:
		_save("crate_1.png")
		_cam.position = Vector3(1.4, 1.5, -3.3)
		_cam.rotation_degrees = Vector3(-12, 170, 0)
		_shot = 3
	elif _shot == 3 and _t > 3.8:
		_save("crate_2.png")
		_cam.position = Vector3(-2.4, 1.1, -2.9)
		_cam.rotation_degrees = Vector3(-14, 160, 0)
		_shot = 4
	elif _shot == 4 and _t > 4.3:
		_save("crate_3.png")
		_cam.position = Vector3(2.6, 1.3, -3.2)
		_cam.rotation_degrees = Vector3(-14, 195, 0)
		_shot = 5
	elif _shot == 5 and _t > 4.8:
		_save("crate_4.png")
		print("[crate_shots] wrote 5 shots to %s" % _out)
		get_tree().quit()
