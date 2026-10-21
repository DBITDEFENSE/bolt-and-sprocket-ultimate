extends Node3D
## Dev tool: close-up renders of one WeaponModels model from several angles (what you see over the sights,
## left and right side, top, rear-quarter, muzzle) into <out>/model_<id>_<view>.png. Silent and off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://gravelight/tools_src/model_shots.tscn -- --id=m1911 [--out=C:/dir] [--up] [--lit]
## --lit renders in a dim interior lit by a warm lantern (how materials read in the maps).

const VIEWS: Array = [
	# name, camera offset from the model's center (model frame: barrel -Z), up hint
	["shooter", Vector3(-0.09, 0.14, 0.26)],
	["left", Vector3(-0.38, 0.03, 0.0)],
	["right", Vector3(0.38, 0.03, 0.0)],
	["top", Vector3(0.0, 0.38, 0.001)],
	["rearq", Vector3(-0.22, 0.16, 0.24)],
	["muzzle", Vector3(0.12, 0.08, -0.3)],
]

var _id: String = "m1911"
var _out: String = "user://shots"
var _up: bool = false
var _lit: bool = false
var _cam: Camera3D
var _model: Node3D
var _center: Vector3
var _vi: int = 0
var _wait: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--id="):
			_id = a.substr(5)
		elif a == "--up":
			_up = true
		elif a == "--lit":
			_lit = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.22, 0.24, 0.27)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.7)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 20, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.35
	add_child(fill)
	if _lit:
		e.background_color = Color(0.05, 0.045, 0.04)
		e.ambient_light_color = Color(0.35, 0.33, 0.4)
		e.ambient_light_energy = 0.25
		sun.light_energy = 0.15
		fill.light_energy = 0.0
		var lantern: OmniLight3D = OmniLight3D.new()
		lantern.light_color = Color(1.0, 0.72, 0.42)
		lantern.light_energy = 2.2
		lantern.omni_range = 5.0
		lantern.position = Vector3(0.5, 0.4, -0.4)
		add_child(lantern)
	_model = WeaponModels.build(StringName(_id), _up, &"")
	add_child(_model)
	var aabb: AABB = _bounds(_model)
	_center = aabb.get_center()
	_cam = Camera3D.new()
	_cam.fov = 45
	_cam.near = 0.005
	add_child(_cam)
	_aim()


func _bounds(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = c as MeshInstance3D
		var xf: Transform3D = mi.transform
		var p: Node = mi.get_parent()
		while p != null and p != n:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _aim() -> void:
	var v: Array = VIEWS[_vi]
	_cam.position = _center + (v[1] as Vector3)
	_cam.look_at(_center, Vector3.UP if str(v[0]) != "top" else Vector3.FORWARD)
	_wait = 6


func _process(_d: float) -> void:
	_wait -= 1
	if _wait > 0:
		return
	get_viewport().get_texture().get_image().save_png(_out.path_join("model_%s%s_%s.png" % [_id, "_up" if _up else "", str(VIEWS[_vi][0])]))
	_vi += 1
	if _vi >= VIEWS.size():
		print("[model_shots] wrote %d views to %s" % [VIEWS.size(), _out])
		get_tree().quit()
		return
	_aim()
