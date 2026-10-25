extends Node3D
## Dev tool: renders viewmodel poses (hip, ADS, sprint, reload stages, firing) per weapon into contact sheets
## <out>/vm_sheet_N.png (default out = user://shots). Uses a Player that is never added to the tree, so the
## mouse is untouched. Run silently and off-screen:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/vm_shots.tscn -- --out=C:/some/dir [--only=mp40,mg42] [--rows=3] [--tw=384] [--inspect=hand_r|hand_l|muzzle] [--lit] [--poses=hip,ads]
## --wall=<m> puts a wall (with collision) that far in front of the eye, plus a zombie-sized post 0.15 m in
## front of it off to the right, to check the viewmodel never clips into geometry (D-062).
## --compress=<k> overrides feel.viewmodel_compress for the run (1.0 = the old, uncompressed viewmodel).
## --lit renders in a dim interior lit by a warm lantern (materials read like in the maps). Upgraded ids
## (mp40_up) work too. The camera uses the game's default FOV (80).
## Each row is one weapon; columns follow POSES.

const POSES: Array = [["hip", 0.0], ["ads", 0.0], ["sprint", 0.0], ["reload", 0.3], ["reload", 0.7], ["fire", 0.0], ["fire_ads", 0.0]]
## Extra poses, only via --poses=: swap (mid raise), melee (mid swing), nade (cooking), cycle (bolt / pump stroke),
## sprint_reload (T-083: reloading on the run, halfway; a gun that can't shows its plain sprint pose). An id may be
## a WeaponKit build string ("m1_garand:grip=quick_sling") to shoot a gun with attachments.
const EXTRA: Array = [["swap", 0.0], ["melee", 0.0], ["nade", 0.0], ["cycle", 0.0], ["sprint_reload", 0.5]]
var ROWS: int = 3
var TW: int = 384
var TH: int = 216

var _weapons: PackedStringArray = []
var _out: String = "user://shots"
var _cam: Camera3D
var _holder: WeaponHolder
var _fake: Player
var _wi: int = 0
var _pi: int = 0
var _wait: float = 0.0
var _sheet: Image
var _sheet_n: int = 0
var _fire_clock: float = 0.0
var _grabbing: bool = false
var _inspect: String = ""        # "hand_r" / "hand_l" / "muzzle": a close-up camera looks at that part instead
var _cam2: Camera3D
var _lit: bool = false
var _poses: Array = []
var _wall: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_weapons = PackedStringArray(a.substr(7).split(","))
		elif a.begins_with("--inspect="):
			_inspect = a.substr(10)
		elif a.begins_with("--rows="):
			ROWS = int(a.substr(7))
		elif a == "--lit":
			_lit = true
		elif a.begins_with("--wall="):
			_wall = float(a.substr(7))
		elif a.begins_with("--compress="):
			(GLData.table("weapons")["feel"] as Dictionary)["viewmodel_compress"] = float(a.substr(11))
		elif a.begins_with("--poses="):
			for k: String in a.substr(8).split(","):
				for pz: Array in POSES + EXTRA:
					if str(pz[0]) + ("" if str(pz[0]) != "reload" else str(int(float(pz[1]) * 100))) == k or str(pz[0]) == k:
						_poses.append(pz)
		elif a.begins_with("--tw="):
			TW = int(a.substr(5))
			TH = TW * 9 / 16
	if _poses.is_empty():
		_poses = POSES.duplicate()
	if _weapons.is_empty():
		for k: Variant in (GLData.table("weapons")["weapons"] as Dictionary).keys():
			_weapons.append(str(k))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("user://") else _out)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.24)
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
	if _lit:
		e.background_color = Color(0.05, 0.045, 0.04)
		e.ambient_light_color = Color(0.35, 0.33, 0.4)
		e.ambient_light_energy = 0.25
		sun.light_energy = 0.15
		var lantern: OmniLight3D = OmniLight3D.new()
		lantern.light_color = Color(1.0, 0.72, 0.42)
		lantern.light_energy = 2.2
		lantern.omni_range = 5.0
		lantern.position = Vector3(0.9, 0.5, -0.9)
		add_child(lantern)
		var wall: MeshInstance3D = MeshInstance3D.new()
		var wm: PlaneMesh = PlaneMesh.new()
		wm.size = Vector2(12, 6)
		wall.mesh = wm
		wall.rotation_degrees = Vector3(90, 0, 0)
		wall.position = Vector3(0, 0, -4)
		var wmat: StandardMaterial3D = StandardMaterial3D.new()
		wmat.albedo_color = Color(0.32, 0.26, 0.2)
		wall.material_override = wmat
		add_child(wall)
	if _wall > 0.0:
		var body: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var bs: BoxShape3D = BoxShape3D.new()
		bs.size = Vector3(8, 6, 0.2)
		cs.shape = bs
		body.add_child(cs)
		var wmi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = bs.size
		wmi.mesh = bm
		var wm2: StandardMaterial3D = StandardMaterial3D.new()
		wm2.albedo_color = Color(0.55, 0.5, 0.42)
		wm2.albedo_texture = WeaponModels._noise_tex("fabric", 31, 0.4, null, false)
		wm2.uv1_triplanar = true
		wmi.mesh.surface_set_material(0, wm2)
		body.add_child(wmi)
		body.position = Vector3(0, 0, -_wall - 0.1)
		add_child(body)
		var post: MeshInstance3D = MeshInstance3D.new()
		var cap: CapsuleMesh = CapsuleMesh.new()
		cap.radius = 0.22
		cap.height = 1.8
		post.mesh = cap
		var pmat: StandardMaterial3D = StandardMaterial3D.new()
		pmat.albedo_color = Color(0.35, 0.45, 0.3)
		post.material_override = pmat
		post.position = Vector3(0.28, -0.6, -_wall + 0.15 + 0.22)
		add_child(post)
	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(0, -1.6, 0)
	add_child(floor_mi)
	# Center crosshair reference so "is the middle of the screen clear" is easy to judge.
	var dot: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	dot.mesh = sm
	var dm: StandardMaterial3D = StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.2, 1.0, 0.3)
	dot.material_override = dm
	dot.position = Vector3(0, 0, -8)
	add_child(dot)
	_cam = Camera3D.new()
	_cam.fov = 80
	_cam.near = 0.01
	add_child(_cam)
	_fake = Player.new()
	_fake.camera = _cam
	_holder = WeaponHolder.new()
	_cam.add_child(_holder)
	_holder.setup(_fake)
	if _inspect != "":
		_cam2 = Camera3D.new()
		_cam2.fov = 40
		_cam2.near = 0.01
		add_child(_cam2)
		_cam2.make_current()
	_new_sheet()
	_start_weapon()


func _new_sheet() -> void:
	_sheet = Image.create(TW * _poses.size(), TH * ROWS, false, Image.FORMAT_RGBA8)


func _start_weapon() -> void:
	var id: String = _weapons[_wi]
	if id.contains(":"):
		_holder.slots.append(WeaponKit.from_build(id))   # a kitted gun (tools only: no slot limit)
		_holder.current_index = _holder.slots.size() - 1
	else:
		_holder.give_weapon(StringName(id))
		_holder.current_index = _holder.slots.find(_holder.find_weapon(StringName(id)))
	_holder.call("_rebuild_gun")
	_pi = 0
	_wait = 0.9


func _process(delta: float) -> void:
	if _grabbing:
		return
	var pose: Array = _poses[_pi]
	var kind: String = str(pose[0])
	var intent: Dictionary = {"ads": kind == "ads" or kind == "fire_ads", "sprinting": kind == "sprint" or kind == "sprint_reload", "lethal_held": kind == "nade"}
	var reload_pose: bool = kind == "reload" or kind == "sprint_reload"
	if kind.begins_with("fire"):
		# Sustained fire at ~600 rpm: drive the same viewmodel state a real shot sets (no hitscan / audio).
		_fire_clock -= delta
		if _fire_clock <= 0.0:
			_fire_clock = 0.1
			if _holder.has_method("_shot_feedback"):
				_holder.call("_shot_feedback", _holder.current())
			else:
				_holder.call("_on_shot_fx", 0.05)
	if kind == "swap":
		_holder.set("_swap_t", 0.2)
	elif kind == "melee":
		_holder.set("_melee_t", float(GLData.table("weapons")["melee"][String(_holder.melee_id)]["swing"]) * 0.5)
		_holder.set("_melee_hit_pending", false)
	elif kind == "nade":
		_holder.set("_cook_t", 0.5)
		_holder.grenades = 2
	elif kind == "cycle" and float(_holder.get("_cycle_t")) <= 0.0:
		_holder.call("_start_cycle", 0.8)
	if kind == "cycle":
		_holder.set("_cycle_t", 0.8 * 0.6)
	_holder.tick(delta, intent)
	if reload_pose and not _holder.is_reloading() and _wait > 0.85:
		var w: WeaponInstance = _holder.current()
		w.mag = 0
		_holder.start_reload()
	if reload_pose and _holder.is_reloading():
		_holder.set("_reload_t", float(_holder.get("_reload_total")) * (1.0 - float(pose[1])))
	if _cam2 != null:
		var node: Node3D = _holder.get("_hand_r" if _inspect == "hand_r" else ("_hand_l" if _inspect == "hand_l" else "_muzzle")) as Node3D
		var t: Vector3 = node.global_position
		var off: Vector3 = Vector3(0.17, 0.05, -0.06) if _inspect != "hand_l" else Vector3(-0.16, -0.05, -0.05)
		if _inspect == "muzzle":
			off = Vector3(0.1, 0.06, 0.3)
		# the viewmodel is shrunk toward the eye (D-062): keep the close-up framing the same
		var vmk: float = float(_holder.get("_vm_compress"))
		_cam2.near = 0.01 * vmk
		_cam2.global_position = t + off * vmk
		_cam2.look_at(t, Vector3.UP)
	_wait -= delta
	if _wait > 0:
		return
	if kind.begins_with("fire") and float(_holder.get("_flash_t")) <= 0.0:
		return   # capture on a frame with a live flash
	# The viewport texture holds the previous frame until this one is drawn, so grab after the draw.
	_grabbing = true
	await RenderingServer.frame_post_draw
	_grabbing = false
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TW, TH)
	_sheet.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i(_pi * TW, (_wi % ROWS) * TH))
	_pi += 1
	_wait = 0.9
	if _holder.is_reloading():
		_holder.call("_cancel_reload")
	if _pi >= _poses.size():
		_wi += 1
		if _wi % ROWS == 0 or _wi >= _weapons.size():
			_sheet.save_png(_out.path_join("vm_sheet_%d.png" % _sheet_n))
			_sheet_n += 1
			_new_sheet()
		if _wi >= _weapons.size():
			print("[vm_shots] wrote %d sheets to %s" % [_sheet_n, _out])
			_grabbing = true
			get_tree().quit()
			return
		_start_weapon()
