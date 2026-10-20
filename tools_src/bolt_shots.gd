extends Node3D
## Dev tool: renders Bolt performing his moves on a small course into a contact sheet. Each cell is one
## moment of a scripted move, seen through the real gameplay camera.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/bolt_shots.tscn -- --out=C:/dir
## Output: <out>/bolt_moves.png (4 columns x N rows, 480x270 cells). Never captures the mouse.

const CW: int = 480
const CH: int = 270
const COLS: int = 4

## [label, frames to run before capture, scripted input per frame (Callable(f) -> Dictionary), camera yaw]
var MOVES: Array = []
var _out: String = "user://shots"
var _bolt: Bolt
var _cam: BoltCamera
var _sheet: Image
var _cell: int = 0
var _move: int = -1
var _f: int = 0
var _grab: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if not _out.begins_with("user://") else ProjectSettings.globalize_path(_out))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_env()
	_course()
	_bolt = Bolt.new()
	_bolt.position = Vector3(0, 0.95, 0)
	add_child(_bolt)
	_cam = BoltCamera.new()
	_cam.target = _bolt
	add_child(_cam)
	_bolt.camera = _cam
	var dummy: TestDummy = TestDummy.new()
	dummy.hp = 99999.0
	dummy.position = Vector3(0, 0, -3)
	add_child(dummy)
	var dm: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.8
	dm.mesh = cap
	dm.position.y = 0.9
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.6, 0.7)
	dm.material_override = mat
	dummy.add_child(dm)
	MOVES = [
		["idle", 30, func(_f: int) -> Dictionary: return {"dir": Vector3.ZERO}],
		["run", 40, func(_f: int) -> Dictionary: return {"dir": Vector3(1, 0, 0)}],
		["jump (apex)", 34, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "jump_pressed": f == 0, "jump_held": true}],
		["double jump", 50, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "jump_pressed": f == 0 or f == 28, "jump_held": f < 45}],
		["hover", 95, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "jump_pressed": f == 0 or f == 28, "jump_held": true}],
		["dash", 6, func(f: int) -> Dictionary: return {"dir": Vector3(-1, 0, 0), "dash_pressed": f == 0}],
		["slide", 12, func(f: int) -> Dictionary: return {"dir": Vector3(0, 0, 1), "sprint": true, "crouch_pressed": f == 10, "crouch_held": true}],
		["long jump", 40, func(f: int) -> Dictionary: return {"dir": Vector3(0, 0, 1), "sprint": true, "crouch_pressed": f == 10, "jump_pressed": f == 16}],
		["mallet 1", 8, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "melee_pressed": f == 0}],
		["mallet 3 (finisher)", 46, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "melee_pressed": f == 0 or f == 18 or f == 36}],
		["slam (flip)", 52, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "jump_pressed": f == 0 or f == 28, "jump_held": f < 45, "crouch_pressed": f == 50}],
		["slam (landing)", 110, func(f: int) -> Dictionary: return {"dir": Vector3.ZERO, "jump_pressed": f == 0 or f == 28, "jump_held": f < 45, "crouch_pressed": f == 50}],
	]
	var rows: int = ceili(float(MOVES.size()) / COLS)
	_sheet = Image.create(CW * COLS, CH * rows, false, Image.FORMAT_RGBA8)
	_next_move()


func _env() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.5, 0.8)            # Scrapheap: warm sunset junkyard
	sm.sky_horizon_color = Color(1.0, 0.62, 0.38)
	sm.ground_horizon_color = Color(0.55, 0.38, 0.25)
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.95, 0.65, 0.42)
	e.fog_density = 0.006
	we.environment = e
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)


func _course() -> void:
	_block(Vector3(80, 1, 80), Vector3(0, -0.5, 0), Color(0.42, 0.33, 0.25))
	_block(Vector3(6, 0.5, 6), Vector3(10, 0.25, 0), Color(0.6, 0.45, 0.3))
	_block(Vector3(4, 6, 1), Vector3(-6, 3, -8), Color(0.35, 0.36, 0.4))
	for i: int in 6:
		_block(Vector3(1.2, 1.2, 1.2), Vector3(-8 + i * 2.5, 0.6, 7), Color(0.55, 0.2 + i * 0.05, 0.15))


func _block(size: Vector3, pos: Vector3, c: Color) -> void:
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	mi.material_override = m
	b.add_child(mi)
	b.position = pos
	add_child(b)


func _next_move() -> void:
	_move += 1
	_f = 0
	if _move >= MOVES.size():
		var path: String = _out.path_join("bolt_moves.png")
		_sheet.save_png(path)
		print("[bolt_shots] wrote ", path)
		get_tree().quit()
		return
	_bolt.respawn_at(Vector3(0, 0.95, 0))
	_bolt.motor.yaw = 0.0
	_cam.yaw = 0.6
	_cam.pitch = 0.3
	_cam.snap_to(_bolt)
	Game.hitstop_t = 0.0
	Game.slowmo_t = 0.0
	Engine.time_scale = 1.0


func _physics_process(_d: float) -> void:
	if _grab or _move >= MOVES.size():
		return
	var mv: Array = MOVES[_move]
	if _f < int(mv[1]):
		_bolt.scripted = (mv[2] as Callable).call(_f)
		if _bolt.scripted.is_empty():
			_bolt.scripted = {"dir": Vector3.ZERO}
		_f += 1
		return
	_capture(str(mv[0]))


func _capture(label: String) -> void:
	_grab = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(CW, CH)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_cell % COLS) * CW, (_cell / COLS) * CH))
	print("[bolt_shots] %s  feet_y=%.2f vel=%s ground=%s slam=%s" % [label, _bolt.global_position.y - _bolt.motor.hy, _bolt.motor.vel.snapped(Vector3.ONE * 0.1), _bolt.motor.on_ground, _bolt.motor.slam])
	_cell += 1
	_grab = false
	_next_move()
