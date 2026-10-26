extends Node
## Dev tool (rendered, off-screen, silent): the UI readability shots for UPDATE 05 section 7 (T-096). The HUD in the
## dark cellar, the taproom at night and the bright snow at the north edge, each with 6 perks, a timed power-up,
## subtitles (a story line and a player line), a hit-marker frame and the boss bar forced on; the boss title card;
## the front-door prompt; then the pause page's MAP / OBJECTIVES / LOADOUT tabs, the game-over page, and the main
## menu with its Credits, Muster and Settings pages. Run it at 1280x720 and 1920x1080 (--resolution) with a --tag:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_hud.tscn -- --out=<dir> [--tag=720]
## -> <dir>/hud_NN_<name>_<tag>.png. The profile and settings are never written (temp paths). Prints "[hud] done".

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MENU: String = "res://gravelight/ui/main_menu.tscn"
const SIX: Array = [&"ironhide_stout", &"second_wind", &"trigger_tonic", &"twin_barrel", &"marathon_malt", &"hawkeye_brandy"]

# [name, position, yaw deg (0 = looking north / -z), pitch deg]
const VIEWS: Array = [
	["cellar", Vector3(31.5, -1.6, 24.6), 90.0, -4.0],
	["taproom_night", Vector3(20.0, 0.1, 13.0), 40.0, -6.0],
	["snow_north_edge", Vector3(4.0, 0.1, -20.0), -90.0, 0.0],
	["snow_front_door", Vector3(19.0, 0.1, -5.0), 180.0, 4.0],
]

var _out: String = "user://shots_hud"
var _tag: String = ""
## The pixel size the shots are saved at (--size). The off-screen window is clamped / DPI-scaled to the monitor
## whatever --resolution says, so a capture that is not this size is resampled (Lanczos) to it: what a 720p or
## 1080p player sees, give or take the rasterizer.
var _size: Vector2i = Vector2i.ZERO
var _n: int = 0
var _map: Node3D
var _boss_hud: BossHud


## A stand-in boss for the forced bar (BossHud polls hp_fraction()).
class FakeBoss extends Node:
	var hp: float = 0.62

	func hp_fraction() -> float:
		return hp


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var want: Vector2i = Vector2i.ZERO
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a.begins_with("--size="):   # the window in pixels (the stretch keeps the 1920x1080 canvas)
			var parts: PackedStringArray = a.substr(7).split("x")
			if parts.size() == 2:
				want = Vector2i(int(parts[0]), int(parts[1]))
	if want.x > 0 and want.y > 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(want)
		_size = want
		if _tag == "":
			_tag = str(want.y)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	ProfileSave.path = "user://_shots_hud_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_shots_hud_settings.cfg"
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _shot(label: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if _n == 0:
		print("[hud] window %s mode %d, capture %s" % [DisplayServer.window_get_size(), DisplayServer.window_get_mode(), img.get_size()])
	if _size.x > 0 and img.get_size() != _size:
		img.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	var fn: String = "hud_%02d_%s%s.png" % [_n, label, ("_" + _tag) if _tag != "" else ""]
	img.save_png(_out.path_join(fn))
	print("[hud] %02d %s" % [_n, label])
	_n += 1


func _subtitles() -> void:
	GLBus.vo_line_started.emit(&"shots_story", &"FAS", "Crossroads, this is Fasbender. The Ledger's still counting. Keep the lamps lit and the doors shut.", 8.0)
	GLBus.vo_line_started.emit(&"shots_player", &"PEG", "Reloading! Somebody watch the window.", 8.0)


func _run() -> void:
	await _wait(9.0)
	var p: Player = _map.get_node("Player1") as Player
	for pk: StringName in SIX:
		PerkManager.grant(1, pk)
	PerkManager.set_tier(1, &"ironhide_stout", 2)
	PowerupManager.apply(&"double_scrip", 1)
	GLSettings.values["subtitles"] = true
	# the boss bar, forced on with a stand-in boss
	_boss_hud = BossHud.new()
	_map.add_child(_boss_hud)
	var fake: FakeBoss = FakeBoss.new()
	_map.add_child(fake)
	var tl: PackedStringArray = HomageBoss.title_for("cousin_1", true)
	_boss_hud.add_bar("cousin_1", fake, tl[0], tl[1])
	for v: Array in VIEWS:
		p.global_position = v[1]
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(float(v[2]))
		p.set("_pitch", deg_to_rad(float(v[3])))
		PowerupManager.apply(&"double_scrip", 1)   # keep the countdown high
		_subtitles()
		await _wait(0.7)
		GLBus.enemy_hit_feedback.emit(1, true, true)   # the kill + headshot marker
		await _shot(str(v[0]))
		if str(v[0]) == "taproom_night":
			GLBus.enemy_hit_feedback.emit(1, false, false)   # the plain hit tick
			await _shot("taproom_hit_tick")
			_boss_hud.title_card(tl[0], tl[1])
			await _wait(0.35)
			await _shot("taproom_title_card")
			await _wait(2.6)
	# the pause page
	var pm: PauseMenu = _map.get("pause_menu") as PauseMenu
	if pm != null:
		pm.toggle()
		await _frames(12)
		await _shot("pause_map")
		pm.set_tab(PauseMenu.TAB_OBJECTIVES)
		await _frames(8)
		await _shot("pause_objectives")
		pm.set_tab(PauseMenu.TAB_LOADOUT)
		await _frames(8)
		await _shot("pause_loadout")
		pm.set_tab(PauseMenu.TAB_SETTINGS)
		await _frames(8)
		await _shot("pause_settings")
		pm.toggle()
		await _frames(4)
	# game over
	if _map.has_method("show_game_over"):
		_map.call("show_game_over", {&"round": 7, &"kills": 143, &"headshots": 41, &"melee_kills": 6, &"scrip_earned": 9850, &"doors": 3, &"boards": 22}, 612.0)
		await _wait(2.8)
		await _shot("game_over")
	# the main menu and its pages
	GameState.phase = GameState.Phase.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)
	await _wait(1.2)
	await _shot("main_menu")
	var menu: Node = get_tree().current_scene
	for page: Array in [["credits", MenuCredits], ["muster", MenuMuster], ["settings", MenuSettings]]:
		if menu == null or not menu.has_method("_open"):
			break
		menu.call("_open", page[1])
		await _wait(0.6)
		if str(page[0]) == "credits":
			var sc: Control = menu.get("_screen") as Control
			var scroll: ScrollContainer = sc.get("_scroll") as ScrollContainer if sc != null else null
			if scroll != null:
				scroll.scroll_vertical = 100000
				await _frames(3)
		await _shot("menu_" + str(page[0]))
		var screen: MenuScreen = menu.get("_screen") as MenuScreen
		if screen != null:
			screen.close()
		await _wait(0.3)
	print("[hud] done -> ", _out)
	get_tree().quit()
