extends Node3D
## Fit sheets for the downloaded guns (T-089): renders every GLB-backed weapon (or --only=a,b) as built by
## WeaponModels.build in its own frame, left side and top, orthographic, over a 5 cm grid through the origin,
## with the markers drawn as dots (Muzzle red, SightPoint green, FrontSight blue, LeftHand yellow, grip_r magenta,
## Mag / part pivots cyan) so model_fit.json can be corrected by eye. Off-screen, silent:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/glb_fit_shots.tscn -- --out=DIR [--only=ids] [--up]
## Writes <out>/<id>_side.png and <out>/<id>_top.png.

var _ids: PackedStringArray = []
var _out: String = "user://fit"
var _up: bool = false
var _cam: Camera3D
var _i: int = 0
var _view: int = 0
var _model: Node3D
var _grid: Node3D
var _label: Label
var _busy: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_ids = PackedStringArray(a.substr(7).split(","))
		elif a == "--up":
			_up = true
	if _ids.is_empty():
		var keys: Array = (WeaponGLB.models().get("weapons", {}) as Dictionary).keys()
		keys.sort()
		for k: String in keys:
			if WeaponGLB.glb_path(StringName(k)) != "":
				_ids.append(k)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.2, 0.22, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 0.01
	_cam.far = 10.0
	add_child(_cam)
	_cam.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(10, 6)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)
	_start()


func _start() -> void:
	if _model != null:
		_model.queue_free()
	if _grid != null:
		_grid.queue_free()
	var id: String = _ids[_i]
	_model = WeaponModels.build(StringName(id), _up)
	add_child(_model)
	var bb: AABB = WeaponModels.model_bounds(_model)
	_grid = Node3D.new()
	add_child(_grid)
	var span: float = maxf(bb.size.z, 0.3) * 0.6 + 0.1
	for k: int in range(-30, 31):
		var z: float = k * 0.05
		if absf(z) > span:
			continue
		var major: bool = k % 2 == 0
		_line(Vector3(-0.2, -0.3, z), Vector3(-0.2, 0.3, z), Color(0.5, 0.5, 0.5) if major else Color(0.33, 0.33, 0.35), 0.0012 if major else 0.0006)
		_line(Vector3(-0.25, -0.2, z), Vector3(0.25, -0.2, z), Color(0.5, 0.5, 0.5) if major else Color(0.33, 0.33, 0.35), 0.0012 if major else 0.0006)
	for k2: int in range(-6, 7):
		var y: float = k2 * 0.05
		_line(Vector3(-0.2, y, -span), Vector3(-0.2, y, span), Color(0.5, 0.5, 0.5) if k2 % 2 == 0 else Color(0.33, 0.33, 0.35), 0.0012 if k2 % 2 == 0 else 0.0006)
		_line(Vector3(k2 * 0.05, -0.2, -span), Vector3(k2 * 0.05, -0.2, span), Color(0.5, 0.5, 0.5) if k2 % 2 == 0 else Color(0.33, 0.33, 0.35), 0.0012 if k2 % 2 == 0 else 0.0006)
	# origin cross (white), axes
	_line(Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), Color.WHITE, 0.0015)
	_line(Vector3(0, -0.1, 0), Vector3(0, 0.1, 0), Color.WHITE, 0.0015)
	_line(Vector3(0, 0, -0.1), Vector3(0, 0, 0.1), Color.WHITE, 0.0015)
	for m: Array in [["Muzzle", Color.RED], ["SightPoint", Color.GREEN], ["FrontSight", Color(0.3, 0.5, 1.0)], ["LeftHand", Color.YELLOW]]:
		var n: Node3D = _model.find_child(str(m[0]), true, false) as Node3D
		if n != null:
			_dot(_root_pos(n), m[1], 0.005)
	for part: String in ["Mag", "Bolt", "Slide", "Pump", "Cover", "Barrels", "Cylinder", "Handle"]:
		var n2: Node3D = _model.find_child(part, true, false) as Node3D
		if n2 != null:
			_dot(_root_pos(n2), Color.CYAN, 0.004)
	if _model.has_meta("grip_r"):
		var g: Transform3D = _model.get_meta("grip_r")
		_dot(g.origin, Color.MAGENTA, 0.006)
		_line(g.origin, g.origin + g.basis.y * 0.05, Color.MAGENTA, 0.0015)
	if _model.has_meta("port"):
		_dot(_model.get_meta("port"), Color.ORANGE, 0.004)
	_view = 0
	_aim(bb)


func _root_pos(n: Node3D) -> Vector3:
	var xf: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p != null and p != _model:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf.origin


func _aim(bb: AABB) -> void:
	var c: Vector3 = bb.get_center()
	var size: float = maxf(bb.size.z, bb.size.y * 1.78) * 1.1 + 0.05
	_cam.size = size / 1.78 * 1.0
	if _view == 0:
		_cam.position = Vector3(-2.0, c.y, c.z)
		_cam.look_at(Vector3(0, c.y, c.z), Vector3.UP)
	else:
		_cam.position = Vector3(c.x, 2.0, c.z)
		_cam.look_at(Vector3(c.x, 0, c.z), Vector3(-1, 0, 0))
	var marks: Array = []
	for m: String in ["Muzzle", "SightPoint", "FrontSight", "LeftHand"]:
		var n: Node3D = _model.find_child(m, true, false) as Node3D
		if n != null:
			var p: Vector3 = _root_pos(n)
			marks.append("%s(%.3f,%.3f,%.3f)" % [m.substr(0, 2), p.x, p.y, p.z])
	var g: Transform3D = _model.get_meta("grip_r", Transform3D())
	_label.text = "%s  %s  reload=%s len=%.3f  grip(%.3f,%.3f,%.3f) lh_axis=%s\n%s\nbbox %.3f..%.3f y %.3f..%.3f  grid 5 cm, white = origin" % [
		_ids[_i], "side (left)" if _view == 0 else "top", _model.get_meta("reload", ""), float(_model.get_meta("length", 0.0)),
		g.origin.x, g.origin.y, g.origin.z, _model.get_meta("lh_axis", ""), " ".join(marks), bb.position.z, bb.end.z, bb.position.y, bb.end.y]


func _process(_d: float) -> void:
	if _busy:
		return
	_busy = true
	_shoot()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var out_dir: String = ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out
	img.save_png(out_dir.path_join("%s_%s.png" % [_ids[_i], "side" if _view == 0 else "top"]))
	if _view == 0:
		_view = 1
		_aim(WeaponModels.model_bounds(_model))
		_busy = false
		return
	_i += 1
	if _i >= _ids.size():
		print("[glb_fit_shots] wrote %d guns to %s" % [_ids.size(), out_dir])
		get_tree().quit()
		return
	_start()
	_busy = false


func _line(a: Vector3, b: Vector3, col: Color, r: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 4
	mi.mesh = cm
	mi.material_override = _unlit(col)
	mi.transform = WeaponModels._seg_xf(a, b)
	_grid.add_child(mi)


func _dot(p: Vector3, col: Color, r: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _unlit(col)
	mi.position = p
	_grid.add_child(mi)


static func _unlit(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.no_depth_test = true
	return m
