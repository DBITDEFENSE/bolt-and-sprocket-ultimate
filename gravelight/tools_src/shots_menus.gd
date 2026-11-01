extends Node
## UPDATE 09 section 7 acceptance captures (DECISIONS T-144): every menu screen over the live MenuScene, the scene's
## two camera shots and its MONDLICHT hook, the loading screen, the pause menu and the game-over ledger in a match,
## saved as PNGs, plus the menu scene's census (RenderingServer draw calls, objects, primitives, lights, zombies).
##   01_main  02_play  03_extras  04_map_select  05_campaign  06_online_home  07_online_browse  08_online_room
##   09_muster  10_archive  11_settings_video  12_scene_a  13_scene_b  14_mondlicht  15_loading  16_pause  17_game_over
## Rendered runs only through WSL + Xvfb (contract C8):
##   sh tools/wsl_godot.sh --res=1920x1080 --path . res://gravelight/tools_src/shots_menus.tscn -- --out=morning/screenshots/u09_menus [--only=main,maps] [--suffix=_720]
## Headless (no PNGs, the census only): godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/shots_menus.tscn

const MENU: String = "res://gravelight/ui/main_menu.tscn"
const MAP00: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MOCK_PORT: int = 47391

var _out: String = "res://morning/screenshots/u09_menus"
var _only: PackedStringArray = []
var _suffix: String = ""
var _saved: PackedStringArray = []
var _menu: Control = null
var _headless: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--suffix="):
			_suffix = a.substr(9)
		elif a == "--desktop":
			MenuScene.override_web = 0   # the desktop variant even on the Compatibility renderer (the census)
	if not _out.begins_with("res://") and not _out.is_absolute_path():
		_out = "res://" + _out
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_menus_profile.json"
	ProfileSave.profile = _demo_profile()
	GLSettings.path = "user://_qa_shots_menus_settings.cfg"
	get_tree().create_timer(1500.0).timeout.connect(func() -> void:
		print("[shots_menus] RESULT: FAIL (timeout)")
		get_tree().quit(2))
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse


## A profile with some progress, so the map cards show best rounds, eggs done and locked maps.
static func _demo_profile() -> Dictionary:
	var p: Dictionary = ProfileSave.new_profile()
	p["maps_unlocked"] = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach"]
	p["best_round"] = {"map00_crossroads": 23, "map01_kaltenbrunn": 14, "map02_totenhafen": 6}
	p["eggs_done"] = {"map00_radio": true}
	p["xp"] = 42000
	return p


func _want(key: String) -> bool:
	return _only.is_empty() or _only.has(key)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Real seconds, at least `min_frames` frames (software GL draws a few frames a second).
func _settle(secs: float, min_frames: int = 4) -> void:
	var t0: int = Time.get_ticks_msec()
	var f: int = 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0) or f < min_frames:
		await get_tree().process_frame
		f += 1


func _shot(name_: String) -> void:
	if _headless:
		print("[shots_menus] (headless) would save %s" % name_)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name_ + _suffix + ".png"))
	img.save_png(path)
	_saved.append(path)
	print("[shots_menus] saved ", path)


func _census(tag: String) -> void:
	var sc: MenuScene = _menu.get("scene") as MenuScene if _menu != null else null
	if sc == null:
		return
	await RenderingServer.frame_post_draw
	print("[shots_menus] CENSUS %s %s" % [tag, JSON.stringify(sc.census())])


func _open_menu() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.queue_free()
		await _frames(2)
	_menu = (load(MENU) as PackedScene).instantiate() as Control
	get_tree().root.add_child(_menu)
	get_tree().current_scene = _menu


func _screen() -> MenuScreen:
	return _menu.get("_screen") as MenuScreen


func _close_screen() -> void:
	var s: MenuScreen = _screen()
	if s != null and is_instance_valid(s):
		s.close()
	await _settle(0.5)


func _run() -> void:
	await _open_menu()
	await _settle(6.0, 8)
	await _census("main")
	if _want("main"):
		await _shot("01_main")
	if _want("play"):
		_menu.call("show_column", "play", true)
		await _settle(1.0)
		await _shot("02_play")
	if _want("extras"):
		_menu.call("show_column", "extras", true)
		await _settle(1.0)
		await _shot("03_extras")
	_menu.call("show_column", "main", false)
	if _want("maps"):
		var mc: MenuCharacter = _menu.call("open_screen", MenuCharacter) as MenuCharacter
		await _settle(0.8)
		if mc != null:
			mc.call("_pick", "dutch")
			await _settle(1.5)
			await _shot("04_map_select")
		await _close_screen()
	if _want("campaign"):
		_menu.call("_open_campaign")
		await _settle(0.8)
		var cc: MenuCharacter = _screen() as MenuCharacter
		if cc != null:
			cc.call("_pick", "wren")
			await _settle(1.2)
			await _shot("05_campaign")
		await _close_screen()
	if _want("online"):
		Lobbies.use_mock(MOCK_PORT, true)
		Lobbies.set_display_name("Dutch")
		var lb: MenuLobby = _menu.call("open_screen", MenuLobby) as MenuLobby
		await _settle(1.0)
		await _shot("06_online_home")
		if lb != null:
			lb.call("_go", "browse")
			await _settle(1.5)
			await _shot("07_online_browse")
			var code: String = Lobbies.create("map00_crossroads", true, "Dutch", 4, true)
			var t: float = 0.0
			while t < 10.0 and not Net.is_online():
				await get_tree().process_frame
				t += get_process_delta_time()
			lb.call("rebuild")
			await _settle(1.5)
			print("[shots_menus] online room: code %s, online %s" % [code, Net.is_online()])
			await _shot("08_online_room")
			Lobbies.leave()
			await _settle(0.5)
		await _close_screen()
	if _want("muster"):
		_menu.call("open_screen", MenuMuster)
		await _settle(1.2)
		await _shot("09_muster")
		await _close_screen()
	if _want("archive"):
		_menu.call("open_screen", MenuArchive)
		await _settle(1.2)
		await _shot("10_archive")
		await _close_screen()
	if _want("settings"):
		var st: MenuSettings = _menu.call("open_screen", MenuSettings) as MenuSettings
		await _settle(0.6)
		if st != null:
			st.call("_set_tab", MenuSettings.TABS.find("Video"))
			await _settle(1.0)
			await _shot("11_settings_video")
		await _close_screen()
	var sc: MenuScene = _menu.get("scene") as MenuScene
	if sc != null and _want("scene"):
		for n: String in ["Shade", "FootShade", "Masthead", "ColumnHolder", "Footer"]:
			var h: CanvasItem = _menu.get_node_or_null(n) as CanvasItem
			if h != null:
				h.visible = false
		await _settle(1.0)
		await _shot("12_scene_a")
		await _census("scene_a")
		sc.set("_shot_t", 999.0)
		await _frames(8)
		await _settle(1.6)
		await _shot("13_scene_b")
		await _census("scene_b")
		sc.set("_shot_t", 999.0)
		await _frames(8)
		sc.mondlicht.visible = true
		await _settle(1.6)
		await _shot("14_mondlicht")
		print("[shots_menus] scene loops %d, shot %d, load %d ms" % [sc.loops, sc.shot, sc.load_ms])
	if _want("loading"):
		var ls: LoadingScreen = LoadingScreen.new()
		ls.demo_map = "map02_totenhafen"
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 50
		get_tree().root.add_child(layer)
		layer.add_child(ls)
		await _settle(1.2)
		await _shot("15_loading")
		layer.queue_free()
	_menu.queue_free()
	_menu = null
	await _frames(2)
	if _want("pause") or _want("gameover"):
		await _match()
	print("[shots_menus] %d screenshots in %s" % [_saved.size(), ProjectSettings.globalize_path(_out)])
	print("[shots_menus] RESULT: PASS")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0)


## Map 0 at round 1 with god mode: the pause menu, then the game-over ledger.
func _match() -> void:
	GameState.character_id = &"dutch"
	GameState.bot_count = 1
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	var map: MapRoot = (load(MAP00) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	GameState.god_mode = true
	await _settle(8.0, 8)
	if _want("pause") and map.pause_menu != null:
		map.pause_menu.toggle()
		await _settle(1.5)
		await _shot("16_pause")
		map.pause_menu.toggle()
		await _settle(0.5)
	if _want("gameover"):
		var st: Dictionary = GameState.stats.duplicate()
		st[&"round"] = 17
		st[&"players"] = {1: {&"kills": 412, &"headshots": 131, &"marke_kills": 38, &"scrip": 18450, &"downs": 2, &"revives": 3},
			2: {&"kills": 377, &"headshots": 96, &"marke_kills": 29, &"scrip": 15920, &"downs": 4, &"revives": 1}}
		map.show_game_over(st, 1934.0)
		await _settle(9.0, 40)   # the fade (2.5 s) and the closing line typed out (1.3 s), at software-GL frame rates
		await _shot("17_game_over")
	get_tree().paused = false
	map.queue_free()
	await _frames(2)
