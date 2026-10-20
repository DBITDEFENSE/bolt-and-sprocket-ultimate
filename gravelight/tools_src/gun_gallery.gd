extends Node3D
## Renders every WeaponModels model in side view (right side, the side you see in first person) into
## <out>/guns_*.png (default user://shots). Every 7th model is shown upgraded. Silent, off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://gravelight/tools_src/gun_gallery.tscn -- --out=C:/dir [--up]
## --up shows every model upgraded.

var _cam: Camera3D
var _frame: int = 0
var _out: String = "user://shots"
var _all_up: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--up":
			_all_up = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.36, 0.44)
	sm.sky_horizon_color = Color(0.6, 0.58, 0.55)
	sm.ground_bottom_color = Color(0.12, 0.1, 0.09)
	sm.ground_horizon_color = Color(0.4, 0.37, 0.33)
	sky.sky_material = sm
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.3, 0.31, 0.33)
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var ids: PackedStringArray = WeaponModels.known_ids()
	var row: int = 0
	var col: int = 0
	for i: int in ids.size():
		var m: Node3D = WeaponModels.build(StringName(ids[i]), _all_up or i % 7 == 6, &"")
		m.rotation_degrees = Vector3(0, -90, 0)
		add_child(m)
		var page: int = i / 9
		var slot: int = i % 9
		m.position = Vector3(page * 20.0 + float(slot % 3) * 1.6 + 0.55, -float(slot / 3) * 0.55, 0)
		var l: Label3D = Label3D.new()
		l.text = ids[i] + (" (up)" if _all_up or i % 7 == 6 else "")
		l.font_size = 20
		l.pixel_size = 0.002
		l.position = m.position + Vector3(0.3, 0.2, 0.2)
		add_child(l)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2.7
	add_child(_cam)


func _process(_d: float) -> void:
	_frame += 1
	var page: int = (_frame - 20) / 20
	if _frame >= 20 and (_frame - 20) % 20 == 0:
		_cam.position = Vector3(page * 20.0 + 2.75, -0.55, 3.0)
	if _frame >= 30 and (_frame - 30) % 20 == 0:
		var p: int = (_frame - 30) / 20
		get_viewport().get_texture().get_image().save_png(_out.path_join("guns_%d.png" % p))
		if p >= 2:
			get_tree().quit()
