extends Node
## Morning screenshots: opens each playable scene in a real (off-screen, silent) window, lets it settle and saves
## 2-3 PNGs per scene into morning/screenshots/<milestone>/: the spawn view, combat with zombies / enemies on
## screen, and a boss when the scene has one. GRAVELIGHT maps run with two bots and god mode.
## Silent, off-screen, no mouse capture:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://tools_src/capture.tscn \
##     [-- --milestone=overnight --only=map00,scrapheap]
## (tools/capture.sh does exactly that.)

## [key, scene, kind, boss id ("" = none)]
const TARGETS: Array = [
	["map00", "res://gravelight/maps/map00_crossroads/map00.tscn", "gl", "screamer"],
	["map01", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", "gl", "foreman"],
	["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn", "gl", ""],
	["scrapheap", "res://bs/planets/scrapheap/scrapheap.tscn", "bs", ""],
	["verdant", "res://bs/planets/verdant/verdant.tscn", "bs", ""],
]

var _out: String = ""
var _only: PackedStringArray = []
var _scene: Node = null
var _saved: PackedStringArray = []


func _ready() -> void:
	var milestone: String = "overnight"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--milestone="):
			milestone = a.substr(12)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		_out = ProjectSettings.globalize_path("res://").path_join("morning/screenshots").path_join(milestone)
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_capture_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(name + ".png")
	img.save_png(path)
	_saved.append(path)
	print("[capture] ", path)


func _run() -> void:
	for t: Array in TARGETS:
		var key: String = str(t[0])
		if not _only.is_empty() and not _only.has(key):
			continue
		if not ResourceLoader.exists(str(t[1])):
			print("[capture] missing %s" % t[1])
			continue
		if str(t[2]) == "gl":
			await _gl(key, str(t[1]), str(t[3]))
		else:
			await _bs(key, str(t[1]))
		if _scene != null and is_instance_valid(_scene):
			_scene.queue_free()
			_scene = null
		await _secs(1.0)
	print("[capture] %d screenshots in %s" % [_saved.size(), _out])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit()


func _load(path: String) -> Node:
	var n: Node = (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(n)
	get_tree().current_scene = n
	_scene = n
	return n


func _gl(key: String, path: String, boss: String) -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 2
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var map: MapRoot = _load(path) as MapRoot
	GameState.god_mode = true
	await _secs(4.0)
	await _shot("%s_1_spawn" % key)
	var p: Player = map.player
	var dir: ZombieDirector = map.director
	if p != null and dir != null:
		RoundManager.stop()
		var fwd: Vector3 = -p.camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
		var nav: RID = p.get_world_3d().navigation_map
		var pts: Array = []
		for i: int in 6:
			var want: Vector3 = p.global_position + fwd * (6.0 + float(i % 3) * 1.5) + fwd.cross(Vector3.UP) * (float(i) - 2.5) * 0.9
			pts.append(NavigationServer3D.map_get_closest_point(nav, want))
		dir.spawn_burst(pts, 6)
		await _secs(3.5)
		await _shot("%s_2_combat" % key)
		if boss != "":
			dir.kill_all(true)
			QuestManager.summon_boss(StringName(boss), NavigationServer3D.map_get_closest_point(nav, p.global_position + fwd * 6.0))
			await _secs(2.0)
			await _shot("%s_3_boss_%s" % [key, boss])
			await _secs(2.5)
			await _shot("%s_4_boss_%s" % [key, boss])
	GameState.god_mode = false


func _bs(key: String, path: String) -> void:
	BSLevel.pending_cutscene = ""
	BS.god_mode = true
	_load(path)
	await _secs(5.0)
	await _shot("%s_1_spawn" % key)
	await _secs(6.0)
	await _shot("%s_2_play" % key)
	BS.god_mode = false
