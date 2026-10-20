extends Node
## Dev tool: a screenshot tour of Scrapheap Junction through the real gameplay camera and HUD. One cell per
## zone probe, plus a combat shot, REPO-TRON and the shop UI. Silent and off-screen; never captures the mouse:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://tools_src/shots_scrapheap.tscn -- --out=C:/dir
## Output: <out>/scrapheap_tour.png (4 columns, 400x225 cells) and <out>/scrapheap_<n>.png full-size shots.
## Uses its own save profile (deleted afterwards).

const PROFILE: String = "user://shots_scrapheap_profile.json"
const LEVEL_SCENE: String = "res://bs/planets/scrapheap/scrapheap.tscn"
const CW: int = 400
const CH: int = 225
const COLS: int = 4

var level: Node3D
var bolt: Bolt
var _out: String = "user://shots"
var _sheet: Image
var _n: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if not _out.begins_with("user://") else ProjectSettings.globalize_path(_out))
	SaveProfile.path = PROFILE
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.god_mode = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		_skip()
		await get_tree().physics_frame


func _skip() -> void:
	if level != null and is_instance_valid(level):
		var cs: Node = level.get("cutscenes") as Node
		if cs != null and bool(cs.get("playing")):
			cs.call("skip")
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _run() -> void:
	BSLevel.pending_cutscene = ""
	level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(level)
	await _frames(30)
	bolt = level.get("bolt") as Bolt
	var D: Dictionary = Data.table("bs/levels/scrapheap")
	var zones: Array = D["zones"]
	var rows: int = ceili(float(zones.size() + 3) / COLS)
	_sheet = Image.create(CW * COLS, CH * rows, false, Image.FORMAT_RGBA8)
	for z: Variant in zones:
		var zd: Dictionary = z
		var p: Array = zd.get("probe", zd.get("center"))
		await _shot(Vector3(float(p[0]), float(p[1]) + 0.5, float(p[2])), 0.6, str(zd["id"]))
	# combat: a pack of mutts and a turret around Bolt in the junction yard
	var yard: Vector3 = Vector3(0, 1.7, 12)
	for i: int in 4:
		EnemySpawner.spawn(&"scrap_mutt", yard + Vector3(cos(i * 1.6) * 6.0, 0, -6.0 + sin(i * 1.6) * 3.0), level)
	EnemySpawner.spawn(&"tinker_turret", yard + Vector3(4, 0, -10), level, {"revealed": true})
	await _shot(yard, 0.4, "combat", 70)
	# boss
	var lot: Vector3 = Vector3(0, 3.2, -118)
	var boss: Node3D = EnemySpawner.spawn(&"repo_tron", lot + Vector3(0, 0, -12), level)
	if boss != null and boss.has_method("start_fight"):
		boss.call("start_fight")
	await _shot(lot, 0.15, "repo_tron", 90)
	# shop UI
	var kiosk: Node = get_tree().get_first_node_in_group(&"shop_kiosk")
	if kiosk != null and kiosk.has_method("open_shop"):
		kiosk.call("open_shop")
	elif level.has_method("open_shop"):
		level.call("open_shop")
	await _shot(bolt.global_position, 0.6, "shop", 20, false)
	var path: String = _out.path_join("scrapheap_tour.png")
	_sheet.save_png(path)
	print("[shots] wrote ", path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit()


func _shot(at: Vector3, yaw: float, label: String, settle: int = 40, move: bool = true) -> void:
	if move:
		bolt.global_position = at
		bolt.motor.vel = Vector3.ZERO
		bolt.last_safe = at
		bolt.scripted = {"dir": Vector3.ZERO}
		var cam: BoltCamera = bolt.camera
		cam.yaw = yaw
		cam.pitch = 0.32
		cam.snap_to(bolt)
	await _frames(settle)
	if not move:
		get_tree().paused = false
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(_out.path_join("scrapheap_%02d_%s.png" % [_n, label]))
	img.resize(CW, CH)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	print("[shots] %02d %s" % [_n, label])
	_n += 1
