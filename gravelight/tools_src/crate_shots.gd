extends Node3D
## Dev tool: renders the crate (cycling, offered, Herr Tamtam) and chalk wall-buys to user://shots/crate_*.png.

var _t: float = 0.0
var _shot: int = 0
var _c1: MysteryCrate
var _c2: MysteryCrate
var _cam: Camera3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.08, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_energy = 0.6
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var l: OmniLight3D = OmniLight3D.new()
	l.position = Vector3(0, 2.5, -1.5)
	l.omni_range = 8
	l.light_energy = 1.5
	add_child(l)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(8, 3, 0.2)
	wall.mesh = bm
	wall.position = Vector3(0, 1.5, 0.1)
	add_child(wall)
	var ids: Array = ["kar98k", "mp40", "trench_gun", "m1911"]
	for i: int in ids.size():
		var wb: WallBuy = WallBuy.new()
		wb.weapon_id = StringName(ids[i])
		wb.position = Vector3(-2.4 + i * 1.6, 1.9, 0.0)
		wb.rotation_degrees = Vector3(0, 0, 0)
		add_child(wb)
	CrateManager.location_index = 0
	_c1 = MysteryCrate.new()
	_c1.spot_index = 0
	_c1.position = Vector3(-1.0, 0, -1.2)
	add_child(_c1)
	_c2 = MysteryCrate.new()
	_c2.spot_index = 0
	_c2.position = Vector3(1.2, 0, -1.2)
	add_child(_c2)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.6, -4.2)
	_cam.rotation_degrees = Vector3(-8, 180, 0)
	add_child(_cam)
	await get_tree().process_frame
	for c: MysteryCrate in [_c1, _c2]:
		c.call("_open_lid")
	_c1.phase = MysteryCrate.Phase.CYCLING
	_c1.get("_float").show()
	_c2.phase = MysteryCrate.Phase.DRUMMER
	_c2.get("_drummer").show()


func _process(delta: float) -> void:
	_t += delta
	if _shot == 0 and _t > 1.5:
		get_viewport().get_texture().get_image().save_png("user://shots/crate_0.png")
		_shot = 1
		_c2.phase = MysteryCrate.Phase.CLOSED
		_c2.set("_result", &"ppsh41")
	elif _shot == 1 and _t > 2.0:
		_c2.call("_finish_cycle")
		_c2.get("_float").show()
		_c2.get("_drummer").hide()
		_shot = 2
	elif _shot == 2 and _t > 3.0:
		get_viewport().get_texture().get_image().save_png("user://shots/crate_1.png")
		_cam.position = Vector3(-0.8, 1.9, -1.6)
		_shot = 3
	elif _shot == 3 and _t > 3.5:
		get_viewport().get_texture().get_image().save_png("user://shots/crate_2.png")
		get_tree().quit()
