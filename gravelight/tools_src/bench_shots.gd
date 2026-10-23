extends Node
## The Armorer's Bench on the real maps (UPDATE_04 section 6, T-068).
##   Captures (off-screen, silent, the mouse is never held):
##     godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . \
##         res://gravelight/tools_src/bench_shots.tscn -- --out=<dir> [--only=map00,map01,map02]
##     For each map: the bench in its spot (third-person view from the room), the player at the bench (first
##     person), the bench screen opened there, then a few builds bought through the API and fired once.
##   Playable test ("Armorer's Bench test" on the launcher):
##     godot --path . res://gravelight/tools_src/bench_shots.tscn -- --play [--map=map00]
##     Starts the map with you in front of the bench, 20,000 Scrip and the power on (the Nachtglas rounds are
##     under the counter until then). Rounds run as usual.

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
}

var _out: String = ""
var _only: PackedStringArray = ["map00", "map01", "map02"]
var _play: bool = false
var _play_map: String = "map00"
var _scene: Node = null
var _saved: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a == "--play":
			_play = true
		elif a.begins_with("--map="):
			_play_map = a.substr(6)
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots/u04/pistol")
	if not _play:
		DirAccess.make_dir_recursive_absolute(_out)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
		ProfileSave.path = "user://_qa_bench_profile.json"
		ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	if not _play:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out.path_join(n + ".png"))
	_saved += 1
	print("[bench_shots] ", n)


func _load(path: String) -> MapRoot:
	var n: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	_scene = n
	return n as MapRoot


## Puts `p` in front of the bench, facing it, looking slightly down at the top.
static func stand_at(p: Player, bench: ArmorersBench, pitch_deg: float = -18.0) -> void:
	p.global_position = bench.stand_point() + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.rotation.y = bench.global_rotation.y + PI
	p.set("_pitch", deg_to_rad(pitch_deg))


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	Campaign.reset()
	if _play:
		await _play_test()
		return
	for key: String in _only:
		if not MAPS.has(key):
			continue
		await _map(key, str(MAPS[key]))
		if _scene != null and is_instance_valid(_scene):
			_scene.queue_free()
			_scene = null
		await _secs(1.0)
	print("[bench_shots] RESULT %d screenshots in %s" % [_saved, _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()


func _map(key: String, path: String) -> void:
	var map: MapRoot = _load(path)
	GameState.god_mode = true
	await _secs(3.0)
	RoundManager.stop()
	var p: Player = map.player
	var bench: ArmorersBench = ArmorersBench.nearest(get_tree(), p.global_position)
	if p == null or bench == null:
		print("[bench_shots] %s: no player or no bench" % key)
		return
	# 1. the bench from the room: a camera of our own, over the player's shoulder height
	var cam: Camera3D = Camera3D.new()
	cam.fov = 62.0
	map.add_child(cam)
	var from: Vector3 = bench.global_transform * Vector3(1.4, 1.75, -2.6)
	cam.global_position = from
	cam.look_at(bench.global_transform * Vector3(0, 1.0, -0.3), Vector3.UP)
	cam.make_current()
	p.visible = false
	await _secs(0.6)
	await _shot("%s_bench_room" % key)
	cam.queue_free()
	p.camera.make_current()
	# 2. first person at the bench, then the bench screen
	stand_at(p, bench)
	Economy.grant(p.player_id, 12000)
	await _secs(0.8)
	await _shot("%s_bench_fp" % key)
	bench.interact(p)
	await _secs(1.2)
	await _shot("%s_bench_ui" % key)
	var ui: Node = bench.get("_ui")
	if ui != null and is_instance_valid(ui):
		ui.queue_free()
	await _secs(0.3)
	# 3. buy a build through the API (the bots' path) and show it in hand at the bench
	GameState.power_on = true
	for so: Array in [["mag", "drum"], ["barrel", "compensator"], ["sights", "radium"], ["ammo", "nachtglas"]]:
		var r: Dictionary = ArmorersBench.buy(p, str(so[0]), str(so[1]))
		print("[bench_shots] %s buy %s/%s -> %s" % [key, so[0], so[1], r])
	stand_at(p, bench, -6.0)
	p.global_position = bench.global_transform * Vector3(0.0, 0.05, -1.6)
	p.rotation.y = bench.global_rotation.y   # turned round: the kitted pistol against the room
	await _secs(1.0)
	await _shot("%s_bench_kitted" % key)
	GameState.power_on = false
	GameState.god_mode = false


func _play_test() -> void:
	var map: MapRoot = _load(str(MAPS.get(_play_map, MAPS["map00"])))
	await _secs(1.0)
	var p: Player = map.player
	var bench: ArmorersBench = ArmorersBench.nearest(get_tree(), p.global_position) if p != null else null
	if p == null or bench == null:
		return
	stand_at(p, bench)
	Economy.grant(p.player_id, 20000)
	GameState.power_on = true
	GLBus.power_activated.emit()
	if map.hud != null:
		map.hud.show_banner("ARMORER'S BENCH TEST\n20,000 Scrip, the power is on. Hold Use at the bench.", 5.0)
