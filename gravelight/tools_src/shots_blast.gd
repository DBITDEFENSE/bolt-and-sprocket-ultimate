extends Node
## T-280: the explosions on Map 0's open snow north of the inn, at night and at noon, with a fixed camera, driven
## through the call the game makes (Effects.explosion): a hand grenade (three Gangers standing by it for scale), a
## 75 mm shell, a big bomb seen from further off, and a grenade a few metres from the camera (the screen's flash and
## blur). Frames at fixed times after each blast (<scene>_<nn>.png). Run it with --write-movie and --fixed-fps so
## game time is the same on every run (software rendering is far slower than real time):
##   tools/wsl_godot.sh --write-movie <dir>/blast.avi --fixed-fps 24 --path . res://gravelight/tools_src/shots_blast.tscn -- --out=<abs dir> [--only=grenade_night,bomb_day]
## On a build before T-280 (no Effects.blast) it calls the old two-argument Effects.explosion: the "before" frames.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const SPOT: Vector3 = Vector3(12.0, 0.0, -14.0)
const TIMES: Array = [0.03, 0.08, 0.16, 0.3, 0.55, 0.9, 1.5, 2.5, 4.0, 6.0]
## scene -> [radius, kind, hour, camera offset from the spot, look-at height, fov]
const SCENES: Dictionary = {
	"grenade_night": [6.0, "grenade", 0.0, Vector3(-8.0, 2.6, -8.5), 1.4, 58.0],
	"shell_night": [4.5, "", 0.0, Vector3(-10.0, 3.0, -10.5), 2.0, 60.0],
	"bomb_night": [7.0, "bomb", 0.0, Vector3(-14.0, 3.5, -14.5), 5.0, 72.0],
	"grenade_day": [6.0, "grenade", 12.0, Vector3(-8.0, 2.6, -8.5), 1.4, 58.0],
	"shell_day": [4.5, "", 12.0, Vector3(-10.0, 3.0, -10.5), 2.0, 60.0],
	"bomb_day": [7.0, "bomb", 12.0, Vector3(-14.0, 3.5, -14.5), 5.0, 72.0],
	"near_day": [6.0, "grenade", 12.0, Vector3(-3.6, 1.7, -4.0), 1.0, 70.0],
}

var _out: String = ""
var _only: PackedStringArray = PackedStringArray()
var _map: MapRoot
var _cam: Camera3D
var _saved: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("docs/captures/t280/after")
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_blast_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_shots_blast_settings.cfg"
	GLSettings.values["vfx_quality"] = "high"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	seed(2800)
	get_viewport().scaling_3d_scale = 0.67
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _skip(s: float) -> void:
	if s <= 0.0:
		return
	RenderingServer.render_loop_enabled = false
	await get_tree().create_timer(s).timeout
	RenderingServer.render_loop_enabled = true
	await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("[shots_blast] (headless: no picture) ", name)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	_saved += 1
	print("[shots_blast] ", path)


func _hide_layers() -> void:
	for cl: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if not (cl is LookPost) and str(cl.name) != "BlastScreen":
			(cl as CanvasLayer).visible = false


## Three Gangers standing round the spot (for scale), awake and still; nothing hurts them (presentation only).
func _stand(spots: Array) -> void:
	_map.director.spawn_burst(spots, spots.size())
	await _skip(6.0)
	var i: int = 0
	for z: Zombie in _map.director.active_zombies():
		if i >= spots.size():
			z.deactivate()
			continue
		z.global_position = spots[i] as Vector3
		var d: Vector3 = (SPOT + Vector3(-8.0, 0.0, -8.5)) - z.global_position
		z.rotation.y = atan2(-d.x, -d.z)
		z.velocity = Vector3.ZERO
		z.hp = 1.0e9
		z.set_physics_process(false)
		i += 1


func _blast(at: Vector3, radius: float, kind: String) -> void:
	if Effects.get("blast") != null:
		Effects.call("explosion", at, radius, kind)
	else:
		Effects.call("explosion", at, radius)   # the build before T-280


func _run() -> void:
	await _skip(14.0)     # the map's opening plays out
	RoundManager.stop()
	_map.director.kill_all(true)
	_hide_layers()
	_cam = Camera3D.new()
	_map.add_child(_cam)
	var p: Player = _map.player
	if p != null:
		p.global_position = Vector3(8.0, 0.2, 3.0)   # out of every frame
	var dc: DayCycle = DayCycle.of(_map)
	for scene: String in SCENES.keys():
		if not (_only.is_empty() or _only.has(scene)):
			continue
		var s: Array = SCENES[scene]
		if dc != null:
			dc.hold_hour(float(s[2]))
		var gangers: Array = [SPOT + Vector3(2.6, 0, 1.2), SPOT + Vector3(-1.8, 0, 2.4), SPOT + Vector3(3.4, 0, -2.0)]
		if scene.begins_with("grenade") or scene == "near_day":
			await _stand(gangers)
		_cam.fov = float(s[5])
		_cam.global_position = SPOT + (s[3] as Vector3)
		_cam.look_at(SPOT + Vector3.UP * float(s[4]), Vector3.UP)
		_cam.make_current()
		_hide_layers()
		await _skip(1.5)   # the light settles at the held hour
		await _shot("%s_00" % scene)
		_blast(SPOT + Vector3.UP * 0.3, float(s[0]), str(s[1]))
		var t: float = 0.0
		for i: int in TIMES.size():
			var wait: float = float(TIMES[i]) - t
			if wait > 0.0:
				await _secs(wait)
			t = float(TIMES[i])
			await _shot("%s_%02d" % [scene, i + 1])
		for z: Zombie in _map.director.active_zombies():
			z.deactivate()
		Effects.clear_marks()
		await _skip(0.5)
	print("[shots_blast] stats ", str(Effects.get("blast").get("stats")) if Effects.get("blast") != null else "(before T-280)")
	print("[shots_blast] %d screenshots in %s" % [_saved, _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()
