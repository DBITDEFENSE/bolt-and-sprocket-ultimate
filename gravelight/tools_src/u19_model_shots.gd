extends Node3D
## T-253 (UPDATE 19): turntables of the smaller models this pass rebuilt, in neutral light, four sides each
## (docs/captures/u19_models/<label>/): the six aircraft of the sky (PlaneModels) and the farm wagon (Props.cart).
##   sh tools/wsl_godot.sh --res=1280x720 --path . res://gravelight/tools_src/u19_model_shots.tscn -- --label=<label> [--planes=<script>] [--props=<script>]
## --planes / --props: another script to build them from (the "before" frames were made from the old files this way).
## Never with a window on the owner's PC (WSL / Xvfb only).

const PLANES: Array[String] = ["bomber", "fighter", "mosquito", "il2", "pe2", "nightfighter"]
## [suffix, yaw deg, camera height, distance]
const VIEWS: Array = [["quarter", 35.0, 5.0, 16.0], ["side", 90.0, 0.5, 16.0], ["below", 150.0, -7.0, 15.0], ["top", 10.0, 17.0, 5.0]]
const CART_VIEWS: Array = [["quarter", 40.0, 2.2, 6.5], ["side", 90.0, 1.2, 6.5], ["rear_quarter", 150.0, 2.4, 6.5], ["front", 5.0, 1.6, 7.0]]

var _out: String = ""
var _cam: Camera3D


func _ready() -> void:
	var label: String = "small"
	var planes_src: String = "res://gravelight/world/landscape/plane_models.gd"
	var props_src: String = "res://gravelight/world/props.gd"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--label="):
			label = a.substr(8)
		elif a.begins_with("--planes="):
			planes_src = a.substr(9)
		elif a.begins_with("--props="):
			props_src = a.substr(8)
	_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/u19_models").path_join(label)
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred(planes_src, props_src)


func _shoot(name_: String) -> void:
	var path: String = _out.path_join("%s.png" % name_)
	if DisplayServer.get_name() == "headless":
		print("[u19_model_shots] (headless: no frame) ", path)
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[u19_model_shots] ", path)


func _run(planes_src: String, props_src: String) -> void:
	get_tree().current_scene = self
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.55, 0.62)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.65, 0.72)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	add_child(_cam)
	_cam.current = true
	var planes: GDScript = load(planes_src) as GDScript
	var holder: MeshInstance3D = MeshInstance3D.new()
	holder.scale = Vector3.ONE * 10.0
	holder.position = Vector3(0, 6, 0)
	add_child(holder)
	# the sky's aircraft are dark for the night; a mid grey here so their shapes read
	var grey: StandardMaterial3D = StandardMaterial3D.new()
	grey.albedo_color = Color(0.42, 0.45, 0.42)
	grey.roughness = 0.6
	for p: String in PLANES:
		var m: ArrayMesh = planes.call(p) as ArrayMesh
		holder.mesh = m
		holder.set_surface_override_material(0, grey)
		print("[u19_model_shots] %s: %d triangles" % [p, ProcKit.mesh_tris(m)])
		for v: Array in VIEWS:
			await _look(Vector3(0, 6, 0), float(v[1]), float(v[2]), float(v[3]))
			await _shoot("plane_%s_%s" % [p, str(v[0])])
	holder.visible = false
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.7, 0.72, 0.76)
	fm.roughness = 0.95
	floor_mi.material_override = fm
	add_child(floor_mi)
	var props: GDScript = load(props_src) as GDScript
	var root: Node3D = Node3D.new()
	add_child(root)
	props.call("cart", root, Vector3.ZERO, 0.0)
	var tris: int = 0
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		tris += ProcKit.mesh_tris((n as MeshInstance3D).mesh)
	print("[u19_model_shots] cart: %d triangles in %d pieces" % [tris, root.find_children("*", "MeshInstance3D", true, false).size()])
	for v2: Array in CART_VIEWS:
		await _look(Vector3(0, 0.7, -0.6), float(v2[1]), float(v2[2]), float(v2[3]))
		await _shoot("cart_%s" % str(v2[0]))
	root.visible = false
	var root2: Node3D = Node3D.new()
	add_child(root2)
	props.call("crate", root2, Vector3.ZERO, 1.0, 20.0, "")
	props.call("crate", root2, Vector3(1.3, 0, 0.3), 0.7, -15.0, "")
	for v3: Array in [["quarter", 35.0, 1.6, 4.2], ["side", 110.0, 0.9, 4.2]]:
		await _look(Vector3(0.5, 0.5, 0), float(v3[1]), float(v3[2]), float(v3[3]))
		await _shoot("crate_%s" % str(v3[0]))
	print("RESULT u19_model_shots: done")
	get_tree().quit()


func _look(aim: Vector3, yaw_deg: float, height: float, dist: float) -> void:
	var yaw: float = deg_to_rad(yaw_deg)
	_cam.global_position = aim + Vector3(-sin(yaw) * dist, height, -cos(yaw) * dist)
	_cam.look_at(aim, Vector3.UP if absf(height) < dist * 2.0 else Vector3.FORWARD)
	await get_tree().process_frame
	await get_tree().process_frame
