extends Node3D
## Dev tool (T-090): in-hand shots of the wonder weapons in their states, one row per weapon, one column per pose,
## into <out>/<name>.png. Like vm_shots (a Player that is never in the tree: the mouse is untouched), plus the states
## only these weapons have. Run silently and off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/wonder_shots.tscn
##       -- --out=C:/dir --name=ashlight_inhand --only=ashlight,ashlight_up --poses=hip,ads,fire,low,reload30,reload70 [--greybox] [--tw=640]
## Poses: hip, ads, fire (a live shot: flash, the fluid / coil / arc flare), low (magazine at 25 %: the Ashlight's
## fluid, the Elmsfeuer's dial), empty, sprint, reload30 / reload50 / reload70 (that far through an empty reload),
## wind (the Totenglocke held 0.9 s: crank spinning, hammer cocking, hum), great (held past the wind: the Great Toll
## locked), toll (a moment after a ring: the bell shaking, the hammer struck), dome (the Bell Dome's long ring),
## inspect (a slow three-quarter turn of the hip pose so the side reads), side (the gun turned 70 deg to show its
## left side).
## --gramophone instead throws the Siren Gramophone onto a floor and shoots it landing, with the needle up, the
## needle down and playing (record and crank turned), and a close-up: <out>/<name>.png.

var TW: int = 640
var TH: int = 360
var _weapons: PackedStringArray = []
var _poses: PackedStringArray = []
var _out: String = "user://wonder_shots"
var _name: String = "wonder"
var _cam: Camera3D
var _holder: WeaponHolder
var _fake: Player
var _wi: int = 0
var _pi: int = 0
var _t: float = 0.0
var _sheet: Image
var _grabbing: bool = false
var _fired: bool = false
var _gramo: bool = false
var _gramo_node: Node3D
var _gramo_marks: Array = [0.35, 1.0, 1.45, 3.2, 3.3]

const WAIT: float = 1.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--name="):
			_name = a.substr(7)
		elif a.begins_with("--only="):
			_weapons = PackedStringArray(a.substr(7).split(","))
		elif a.begins_with("--poses="):
			_poses = PackedStringArray(a.substr(8).split(","))
		elif a == "--gramophone":
			_gramo = true
		elif a == "--greybox":
			GLSettings.values["greybox_guns"] = true
		elif a.begins_with("--tw="):
			TW = int(a.substr(5))
			TH = TW * 9 / 16
	if _poses.is_empty():
		_poses = PackedStringArray(["hip", "ads", "fire", "reload30", "reload70"])
	DirAccess.make_dir_recursive_absolute(_out)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.06, 0.075)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.38, 0.4, 0.5)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	add_child(env)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 1.4
	add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_color = Color(0.6, 0.7, 1.0)
	rim.light_energy = 0.6
	add_child(rim)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.72, 0.42)
	lamp.light_energy = 1.2
	lamp.omni_range = 4.0
	lamp.position = Vector3(-0.8, 0.4, -0.6)
	add_child(lamp)
	var wall: MeshInstance3D = MeshInstance3D.new()
	var wm: PlaneMesh = PlaneMesh.new()
	wm.size = Vector2(14, 8)
	wall.mesh = wm
	wall.rotation_degrees = Vector3(90, 0, 0)
	wall.position = Vector3(0, 0, -4)
	var wmat: StandardMaterial3D = StandardMaterial3D.new()
	wmat.albedo_color = Color(0.2, 0.17, 0.14)
	wall.material_override = wmat
	add_child(wall)
	_cam = Camera3D.new()
	_cam.fov = 80
	_cam.near = 0.01
	add_child(_cam)
	if _gramo:
		_start_gramophone()
		return
	_fake = Player.new()
	_fake.camera = _cam
	_holder = WeaponHolder.new()
	_cam.add_child(_holder)
	_holder.setup(_fake)
	_sheet = Image.create(TW * _poses.size(), TH * _weapons.size(), false, Image.FORMAT_RGBA8)
	_start_weapon()


func _start_gramophone() -> void:
	var floor_b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(8, 0.2, 8)
	cs.shape = bs
	floor_b.add_child(cs)
	var fm: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = bs.size
	fm.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.27, 0.24)
	fm.material_override = mat
	floor_b.add_child(fm)
	floor_b.position = Vector3(0, -0.1, 0)
	add_child(floor_b)
	var g: Gramophone = Gramophone.new()
	g.cfg = (GLData.table("weapons")["tactical"] as Dictionary)["gramophone"]
	g.visual_only = true
	add_child(g)
	g.position = Vector3(0.0, 0.35, -0.6)
	g.linear_velocity = Vector3(0.0, 0.2, -0.3)
	_gramo_node = g
	_cam.position = Vector3(0.35, 0.55, 0.45)
	_cam.look_at(Vector3(0.0, 0.08, -0.55))
	_sheet = Image.create(TW * _gramo_marks.size(), TH, false, Image.FORMAT_RGBA8)


func _tick_gramophone(delta: float) -> void:
	_t += delta
	if _pi >= _gramo_marks.size() or _t < float(_gramo_marks[_pi]):
		return
	var gp: Vector3 = _gramo_node.global_position
	var off: Vector3 = Vector3(0.32, 0.4, -0.55) if _pi < _gramo_marks.size() - 1 else Vector3(0.16, 0.26, -0.28)
	_cam.position = gp + _gramo_node.global_basis * off
	_cam.look_at(gp + Vector3(0, 0.03, 0))
	_grabbing = true
	await RenderingServer.frame_post_draw
	_grabbing = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TW, TH)
	_sheet.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i(_pi * TW, 0))
	_pi += 1
	if _pi >= _gramo_marks.size():
		_sheet.save_png(_out.path_join(_name + ".png"))
		print("[wonder_shots] wrote ", _out.path_join(_name + ".png"))
		_grabbing = true
		get_tree().quit()


func _start_weapon() -> void:
	var id: String = _weapons[_wi]
	_holder.slots.clear()
	_holder.give_weapon(StringName(id))
	_holder.current_index = 0
	_holder.call("_rebuild_gun")
	_begin_pose()


func _begin_pose() -> void:
	_t = 0.0
	_fired = false
	var w: WeaponInstance = _holder.current()
	w.mag = w.mag_size()
	w.reserve = 999
	if _holder.is_reloading():
		_holder.call("_cancel_reload")
	_holder.set("_bell", null)
	_holder.call("_rebuild_gun")
	_cam.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if _grabbing:
		return
	if _gramo:
		_tick_gramophone(delta)
		return
	_t += delta
	var pose: String = _poses[_pi]
	var w: WeaponInstance = _holder.current()
	var intent: Dictionary = {"ads": pose == "ads", "sprinting": pose == "sprint"}
	var bell: Totenglocke = _holder.bell_logic() if w.data.has("bell") else null
	match pose:
		"low":
			w.mag = maxi(1, int(ceil(w.mag_size() * 0.25)))
		"empty":
			w.mag = 0
		"fire":
			if _t > WAIT - 0.12 and not _fired:
				_fired = true
				if bell != null:
					w.mag -= 1
					bell._vibe_amp = 1.0
					bell._vibe_total = 1.0
					bell._vibe_t = 1.0
					_holder.call("_vm_kick", 1.0)
				else:
					w.mag -= 1
					_holder.call("_shot_feedback", w)
		"wind":
			intent["fire_held"] = _t > 0.1 and bell != null
			intent["fire_pressed"] = _t > 0.1 and _t < 0.13 and bell != null
		"great":
			intent["fire_held"] = bell != null
			intent["fire_pressed"] = _t < 0.03 and bell != null
		"toll", "dome":
			if _t > WAIT - 0.25 and not _fired and bell != null:
				_fired = true
				w.mag -= 1 if pose == "toll" else 2
				bell._vibe_amp = 1.0 if pose == "toll" else 0.8
				bell._vibe_total = 1.0 if pose == "toll" else 1.2
				bell._vibe_t = bell._vibe_total
				_holder.call("_vm_kick", 1.0 if pose == "toll" else 1.4)
		"side", "inspect":
			pass
	if pose.begins_with("reload"):
		if not _holder.is_reloading() and _t < 0.5:
			w.mag = 0
			_holder.start_reload()
		if _holder.is_reloading():
			var p: float = float(pose.substr(6)) / 100.0
			_holder.set("_reload_t", float(_holder.get("_reload_total")) * (1.0 - p))
	if bell != null and pose == "great" and _t > 1.6 and bell != null:
		intent["fire_held"] = true
	_holder.tick(delta, intent)
	if pose == "side":
		_cam.rotation = Vector3.ZERO
		_holder.rotation_degrees = Vector3(0, 0, 0)
	if _t < WAIT:
		return
	if pose == "great" and _t < 1.9:
		return
	_grabbing = true
	if pose == "side":
		var gun: Node3D = _holder.get("_vm") as Node3D
		gun.rotation_degrees += Vector3(0, 70, 0)
		gun.position += Vector3(-0.05, 0.02, 0.02)
	elif pose == "inspect":
		var gun2: Node3D = _holder.get("_vm") as Node3D
		gun2.rotation_degrees += Vector3(15, 35, -20)
		gun2.position += Vector3(-0.04, 0.04, 0.03)
	await RenderingServer.frame_post_draw
	_grabbing = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TW, TH)
	_sheet.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i(_pi * TW, _wi * TH))
	_pi += 1
	if _pi >= _poses.size():
		_pi = 0
		_wi += 1
		if _wi >= _weapons.size():
			_sheet.save_png(_out.path_join(_name + ".png"))
			print("[wonder_shots] wrote ", _out.path_join(_name + ".png"))
			_grabbing = true
			get_tree().quit()
			return
		_start_weapon()
		return
	_begin_pose()
