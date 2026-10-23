extends Node3D
## Captures for the M1911 attachments (UPDATE_04 section 6, T-068). Off-screen and silent:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . \
##       res://gravelight/tools_src/kit_shots.tscn -- --mode=<models|fp|ui|world|bench> --out=<dir> [--builds=...]
## A build is "<weapon>[:slot=option,...][,finish=<id>]", e.g. "m1911_up:mag=drum,barrel=compensator,finish=nickel";
## builds are separated by ";". Modes:
##   models  a contact sheet of side views (both sides) of every build: <out>/kit_models.png
##   fp      first person, hip and aimed, in a lamp-lit room: <out>/fp_<n>_<build>.png
##   ui      the Armorer's Bench screen on a few states: <out>/bench_ui_<n>.png
##   world   third person (a squad-mate's body holding each build) and the bench itself: <out>/world_<n>.png
## Uses Players that never enter the tree (the mouse is never touched).

const W: int = 1280
const H: int = 720
const DEFAULT_BUILDS: String = "m1911;m1911:mag=extended;m1911:mag=drum;m1911:barrel=match;m1911:barrel=compensator;m1911:barrel=suppressor;m1911:sights=radium;m1911:sights=raised_target;m1911:grip=stock;m1911:grip=checkered;m1911:ammo=hollow_points;m1911:ammo=nachtglas;m1911_up:mag=drum,barrel=compensator,sights=radium,grip=checkered,ammo=nachtglas;m1911_up:mag=extended,barrel=suppressor,sights=raised_target,grip=stock;m1911:finish=nickel;m1911:finish=engraved,barrel=match;m1911:finish=nachtglas_inlay,sights=radium;m1911:finish=battle_worn,mag=drum,grip=stock"
const FP_BUILDS: String = "m1911;m1911:mag=drum,barrel=compensator,sights=radium;m1911:mag=extended,barrel=suppressor,sights=raised_target,grip=stock,ammo=hollow_points;m1911_up:mag=drum,barrel=compensator,sights=radium,grip=checkered,ammo=nachtglas;m1911:barrel=match,grip=checkered,finish=nickel;m1911_up:mag=extended,barrel=suppressor,sights=raised_target,grip=stock"

var _mode: String = "models"
var _out: String = "res://morning/screenshots/u04/pistol"
var _builds: PackedStringArray = []
var _cam: Camera3D
var _step: int = 0
var _wait: int = 0
var _busy: bool = false
var _sheet: Image
var _holder: WeaponHolder
var _fake: Player
var _ui: ArmorersBenchUI
var _scene: Node3D
var _label: Label
var _reload_at: float = 0.62


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var builds: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--reload_at="):
			_reload_at = float(a.substr(12))
		elif a.begins_with("--builds="):
			builds = a.substr(9)
	if builds == "":
		builds = FP_BUILDS if _mode == "fp" else DEFAULT_BUILDS
	_builds = PackedStringArray(builds.split(";", false))
	if _out.begins_with("res://") or _out.begins_with("user://"):
		_out = ProjectSettings.globalize_path(_out)
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.phase = GameState.Phase.PLAYING
	_scene = Node3D.new()
	add_child(_scene)
	_cam = Camera3D.new()
	_cam.fov = 80.0
	_cam.near = 0.01
	_scene.add_child(_cam)
	_cam.make_current()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(_label)
	print("[kit_shots] mode %s, %d builds -> %s" % [_mode, _builds.size(), _out])


## A WeaponInstance from a build string.
static func make(build: String) -> WeaponInstance:
	return M1911Kit.from_build(build)


static func file_name(build: String) -> String:
	return M1911Kit.build_file_name(build)


func _room(lit_dim: bool) -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.045, 0.04) if lit_dim else Color(0.4, 0.42, 0.46)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.48, 0.46)
	e.ambient_light_energy = 0.25 if lit_dim else 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	_scene.add_child(env)
	if lit_dim:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.48)
		lamp.light_energy = 2.2
		lamp.omni_range = 9.0
		lamp.position = Vector3(1.2, 1.4, -0.8)
		_scene.add_child(lamp)
		Props.block(_scene, Vector3(-4, -1.7, -6), Vector3(4, -1.6, 2), "floorboards")
		Props.block(_scene, Vector3(-4, -1.6, -6.2), Vector3(4, 2.5, -6), "planks")
	else:
		var sun: DirectionalLight3D = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 30, 0)
		sun.light_energy = 1.2
		_scene.add_child(sun)


func _process(_delta: float) -> void:
	if _busy:
		return
	_busy = true
	match _mode:
		"models":
			await _do_models()
		"fp":
			await _do_fp()
		"ui":
			await _do_ui()
		"world":
			await _do_world()
	print("[kit_shots] RESULT done")
	if _fake != null:
		_fake.free()
	get_tree().quit(0)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() != W:
		img.resize(W, H)
	return img


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


# ================================================================== models: side views

func _do_models() -> void:
	_room(false)
	var cols: int = 3
	var tw: int = 640
	var th: int = 300
	var rows: int = ceili(float(_builds.size()) / float(cols))
	_sheet = Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	_sheet.fill(Color(0.1, 0.1, 0.1))
	var holder: Node3D = Node3D.new()
	_scene.add_child(holder)
	_cam.fov = 25.0
	var key: OmniLight3D = OmniLight3D.new()
	key.light_energy = 1.6
	key.omni_range = 6.0
	key.position = Vector3(-1.0, 0.5, 0.4)
	_scene.add_child(key)
	for i: int in _builds.size():
		var b: String = _builds[i]
		var w: WeaponInstance = make(b)
		for c: Node in holder.get_children():
			c.free()
		var m: Node3D = WeaponModels.build(w.base_id(), w.upgraded, &"", M1911KitModels.look_of(w))
		holder.add_child(m)
		var kf: Node3D = m.get_node_or_null("KitFlash") as Node3D
		if kf != null:
			kf.show()   # show the comp's jets in the sheet
		# left side (the viewmodel side): the camera on -X looking +X, so the muzzle points left on screen
		m.position = Vector3(0, 0, -0.05)
		_cam.position = Vector3(-1.4, 0.0, 0.0)
		_cam.look_at(Vector3(0, -0.05, 0.0), Vector3.UP)
		_cam.position.z = 0.0
		_label.text = b
		var img: Image = await _grab()
		var tile: Image = img.get_region(Rect2i(W / 2 - 480, H / 2 - 225, 960, 450))
		tile.resize(tw, th)
		_sheet.blit_rect(tile, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	_sheet.save_png(_out.path_join("kit_models.png"))
	print("[kit_shots] saved kit_models.png (%d builds)" % _builds.size())


# ================================================================== first person

func _do_fp() -> void:
	_room(true)
	_fake = Player.new()
	_fake.camera = _cam
	_holder = WeaponHolder.new()
	_cam.add_child(_holder)
	_holder.setup(_fake)
	_holder.steady = true
	for i: int in _builds.size():
		var b: String = _builds[i]
		_holder.slots = [make(b)]
		_holder.current_index = 0
		_holder.call("_rebuild_gun")
		_holder.set("_swap_t", 0.0)
		for pose: String in ["hip", "ads"]:
			_holder.ads_t = 0.0 if pose == "hip" else 1.0
			for f: int in 30:
				_holder.tick(1.0 / 30.0, {"ads": pose == "ads"})
				_cam.fov = 80.0 * _holder.fov_mult()
				await get_tree().process_frame
			_label.text = "%s   %s" % [b, pose.to_upper()]
			var img: Image = await _grab()
			img.save_png(_out.path_join("fp_%02d_%s_%s.png" % [i, file_name(b), pose]))
		# a bigger magazine shows best in the reload: the fresh one comes up from the pouch in the left hand
		var w: WeaponInstance = _holder.current()
		if w.kit.has("mag"):
			_holder.ads_t = 0.0
			w.mag = 0
			_holder.start_reload()
			var total: float = w.f("reload_empty", 1.8)
			var t: float = 0.0
			while t < total * _reload_at:
				_holder.tick(1.0 / 30.0, {})
				t += 1.0 / 30.0
				await get_tree().process_frame
			_label.text = "%s   RELOAD" % b
			var img2: Image = await _grab()
			img2.save_png(_out.path_join("fp_%02d_%s_reload.png" % [i, file_name(b)]))
	print("[kit_shots] saved the first-person shots")


# ================================================================== the bench screen

func _do_ui() -> void:
	_room(true)
	_fake = Player.new()
	_fake.player_id = 1
	_fake.camera = _cam
	_holder = WeaponHolder.new()
	_cam.add_child(_holder)
	_holder.setup(_fake)
	_fake.weapons = _holder
	var ids: Array[int] = [1]
	Economy.reset(ids)
	Economy.grant(1, 6000)
	var states: Array = [
		["m1911:sights=radium", "mag", "drum", false],
		["m1911:mag=drum,sights=radium", "barrel", "compensator", false],
		["m1911:mag=extended,barrel=suppressor", "grip", "stock", false],
		["m1911:mag=extended,barrel=suppressor,grip=stock", "ammo", "nachtglas", false],
		["m1911:mag=extended,barrel=suppressor,grip=stock", "ammo", "nachtglas", true],
		["m1911_up:mag=drum,barrel=compensator,sights=radium", "sights", "raised_target", true],
	]
	for i: int in states.size():
		var s: Array = states[i]
		GameState.power_on = bool(s[3])
		_holder.slots = [make(str(s[0]))]
		_holder.current_index = 0
		_ui = ArmorersBenchUI.new()
		_ui.player = _fake
		_ui.start_slot = str(s[1])
		_ui.start_option = str(s[2])
		add_child(_ui)
		_label.text = ""
		await _frames(40)
		var img: Image = await _grab()
		img.save_png(_out.path_join("bench_ui_%02d.png" % i))
		if is_instance_valid(_ui):
			_ui.queue_free()
		await _frames(2)
	GameState.power_on = false
	print("[kit_shots] saved %d bench screens" % states.size())


# ================================================================== third person and the bench

func _do_world() -> void:
	_room(true)
	var bench: ArmorersBench = ArmorersBench.new()
	_scene.add_child(bench)
	bench.position = Vector3(-1.6, -1.6, -2.4)
	bench.rotation_degrees = Vector3(0, 30, 0)
	var bodies: Array = []
	var builds: Array = ["m1911:mag=drum,barrel=compensator,sights=radium", "m1911:mag=extended,barrel=suppressor,sights=raised_target,grip=stock",
		"m1911_up:mag=drum,barrel=compensator,grip=checkered,ammo=nachtglas"]
	var chars: Array = [&"dutch", &"peg", &"deacon"]
	for i: int in builds.size():
		var w: WeaponInstance = make(str(builds[i]))
		var rb: RemoteBody = RemoteBody.new()
		rb.look_weapon = w
		_scene.add_child(rb)
		rb.setup(chars[i], 10 + i)
		rb.set_weapon(w.id)
		rb.refresh_weapon()
		rb.position = Vector3(0.6 + i * 0.95, -1.6, -2.6 + i * 0.25)
		rb.rotation_degrees = Vector3(0, -150 + i * 12, 0)
		bodies.append(rb)
	_cam.fov = 50.0
	_cam.position = Vector3(0.7, -0.3, 0.2)
	_cam.look_at(Vector3(0.4, -0.55, -2.4), Vector3.UP)
	await _frames(20)
	(await _grab()).save_png(_out.path_join("world_00_squad.png"))
	# close on the middle body's gun
	_cam.fov = 30.0
	_cam.position = Vector3(1.3, -0.35, -1.5)
	_cam.look_at((bodies[1] as Node3D).position + Vector3(-0.1, 1.15, -0.2), Vector3.UP)
	await _frames(5)
	(await _grab()).save_png(_out.path_join("world_01_close.png"))
	# the bench
	_cam.fov = 55.0
	_cam.position = bench.position + Vector3(0.6, 1.55, 1.2)
	_cam.look_at(bench.global_transform * Vector3(0, 1.0, -0.35), Vector3.UP)
	await _frames(5)
	(await _grab()).save_png(_out.path_join("world_02_bench.png"))
	print("[kit_shots] saved world shots")
