extends Node
## T-267 captures: every menu page the rework changed, each sidearm in the Loadout's 3D view (the whole page, and
## the view's own picture at two points of its turn), each character in the Solo page's view, and the loading screen
## with and without a clip. Rendered only through WSL + Xvfb:
##   sh tools/wsl_godot.sh --res=1280x720 --path . res://gravelight/tools_src/shots_t267.tscn -- --out=docs/captures/t267/after [--clips=<dir>] [--only=loadout,views]
## Keys: main play extras solo campaign loadout views pages coop loading
## Headless it walks the same pages and saves nothing (a crash check).

const MENU: String = "res://gravelight/ui/main_menu.tscn"
const MOCK_PORT: int = 47393

var _out: String = "res://docs/captures/t267/after"
var _only: PackedStringArray = []
var _clips: String = ""
var _saved: int = 0
var _menu: Control = null
var _headless: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
		elif a.begins_with("--clips="):
			_clips = a.substr(8)
	if not _out.begins_with("res://") and not _out.is_absolute_path():
		_out = "res://" + _out
	if _clips == "" and FileAccess.file_exists("res://.smoke_logs/t267/clips/load_placeholder.ogv"):
		_clips = "res://.smoke_logs/t267/clips"
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_t267_profile.json"
	ProfileSave.profile = _demo_profile()
	GLSettings.path = "user://_qa_shots_t267_settings.cfg"
	get_tree().create_timer(1500.0).timeout.connect(func() -> void:
		print("[shots_t267] RESULT: FAIL (timeout)")
		get_tree().quit(2))
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Some progress: a few maps open, a rank that unlocks every sidearm and two perk slots, M1911 kills for its
## finishes and its fitted attachment.
static func _demo_profile() -> Dictionary:
	var p: Dictionary = ProfileSave.new_profile()
	p["maps_unlocked"] = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach"]
	p["best_round"] = {"map00_crossroads": 23, "map01_kaltenbrunn": 14, "map02_totenhafen": 6}
	p["eggs_done"] = {"map00_radio": true}
	p["xp"] = 42000
	p["weapon_kills"] = {"m1911": 300}
	return p


func _want(key: String) -> bool:
	return _only.is_empty() or _only.has(key)


func _settle(secs: float, min_frames: int = 4) -> void:
	var t0: int = Time.get_ticks_msec()
	var f: int = 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0) or f < min_frames:
		await get_tree().process_frame
		f += 1


func _shot(name_: String) -> void:
	if _headless:
		print("[shots_t267] (headless) would save %s" % name_)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out.path_join(name_ + ".png")))
	_saved += 1
	print("[shots_t267] saved %s" % name_)


## The 3D view's own picture (its SubViewport), with how much of it the model covers and how bright it is, so a
## missing, black or tiny model shows in the log as well as in the PNG.
func _view_shot(view: MenuModelView, name_: String) -> void:
	if _headless or view == null:
		print("[shots_t267] (headless) would save %s" % name_)
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = view.viewport.get_texture().get_image()
	var covered: int = 0
	var luma: float = 0.0
	var lo: Vector2i = Vector2i(img.get_width(), img.get_height())
	var hi: Vector2i = Vector2i(-1, -1)
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				covered += 1
				luma += c.get_luminance()
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	var total: int = (img.get_width() / 2) * (img.get_height() / 2)
	var edge: bool = covered > 0 and (lo.x <= 1 or lo.y <= 1 or hi.x >= img.get_width() - 3 or hi.y >= img.get_height() - 3)
	print("[shots_t267] VIEW %s: %dx%d, model covers %.1f%% of the view, box %s..%s, mean luma %.3f%s%s%s" % [name_, img.get_width(), img.get_height(),
		100.0 * covered / maxf(1.0, total), lo, hi, luma / maxf(1.0, covered),
		"  MISSING" if covered == 0 else "", "  TOUCHES THE EDGE" if edge else "", "  DARK" if covered > 0 and luma / covered < 0.06 else ""])
	# on a dark card, as the page shows it
	var bg: Image = Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.05, 0.05, 0.07))
	img.convert(Image.FORMAT_RGBA8)
	bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	bg.save_png(ProjectSettings.globalize_path(_out.path_join(name_ + ".png")))
	_saved += 1


func _open_menu() -> void:
	_menu = (load(MENU) as PackedScene).instantiate() as Control
	get_tree().root.add_child(_menu)
	get_tree().current_scene = _menu


func _screen() -> MenuScreen:
	return _menu.get("_screen") as MenuScreen


func _close() -> void:
	var s: MenuScreen = _screen()
	if s != null and is_instance_valid(s):
		s.close()
	await _settle(0.6)


func _run() -> void:
	await _open_menu()
	await _settle(6.0, 8)
	if _want("main"):
		await _shot("01_main")
		(_menu.call("link", "Loadout") as Button).grab_focus()
		await _settle(0.8)
		await _shot("01b_main_loadout_focus")
	if _want("play"):
		_menu.call("show_column", "play", true)
		await _settle(1.0)
		await _shot("02_play")
	if _want("extras"):
		_menu.call("show_column", "extras", true)
		await _settle(1.0)
		await _shot("03_extras")
	_menu.call("show_column", "main", false)
	if _want("solo"):
		var mc: MenuCharacter = _menu.call("open_screen", MenuCharacter) as MenuCharacter
		await _settle(1.2)
		for c: Array in MenuCharacter.CHARACTERS:
			var b: Button = mc.find_child("Character_" + str(c[0]), true, false) as Button
			b.grab_focus()
			await _settle(1.2)
			await _shot("04_solo_character_%s" % str(c[0]))
			if _want("views"):
				mc.view.set_time(0.0)
				await _view_shot(mc.view, "view_character_%s" % str(c[0]))
		mc.call("_pick", "dutch")
		await _settle(1.5)
		await _shot("05_solo_maps")
		var kb: Button = mc.find_child("MapCards", true, false).get_child(1) as Button
		kb.grab_focus()
		await _settle(1.0)
		await _shot("05b_solo_maps_second_card_focus")
		await _close()
	if _want("campaign"):
		_menu.call("_open_campaign")
		await _settle(1.0)
		var cc: MenuCharacter = _screen() as MenuCharacter
		cc.call("_pick", "wren")
		await _settle(1.2)
		await _shot("06_campaign")
		await _close()
	if _want("loadout"):
		var m: MenuMuster = _menu.call("open_screen", MenuMuster) as MenuMuster
		await _settle(1.5)
		await _shot("07_loadout_open")
		for id: String in Muster.pistol_ids():
			var b: Button = m.find_child("Pistol_" + id, true, false) as Button
			b.grab_focus()
			await _settle(1.0)
			m.view.set_time(0.0)
			await _settle(0.3, 3)
			await _shot("07_loadout_%s" % id)
			if _want("views"):
				await _view_shot(m.view, "view_%s_a" % id)
				m.view.set_time(2.86)   # the swing's two ends
				await _settle(0.2, 3)
				await _view_shot(m.view, "view_%s_b" % id)
				m.view.set_time(8.57)
				await _settle(0.2, 3)
				await _view_shot(m.view, "view_%s_c" % id)
		# the M1911 with a finish and its fitted attachment
		M1911Kit.set_finish(&"nickel")
		M1911Kit.set_loadout_pick("mag:extended")
		m.rebuild(true)
		await _settle(0.6)
		(m.find_child("M1911_Finish", true, false) as Button).grab_focus()
		await _settle(1.0)
		m.view.set_time(0.0)
		await _settle(0.3, 3)
		await _shot("07_loadout_m1911_nickel_extended_mag")
		if _want("views"):
			await _view_shot(m.view, "view_m1911_nickel_extended_mag")
		M1911Kit.set_finish(&"blued")
		M1911Kit.set_loadout_pick("grip:checkered")
		m.rebuild(true)
		await _settle(1.0)
		m.view.set_time(0.0)
		await _settle(0.3, 3)
		if _want("views"):
			await _view_shot(m.view, "view_m1911_blued_checkered_grips")
		M1911Kit.set_finish(&"")
		M1911Kit.set_loadout_pick("")
		# the perks, further down the list
		(m.find_child("Perk_cool_head", true, false) as Button).grab_focus()
		await _settle(1.0)
		await _shot("07_loadout_perks")
		await _close()
	if _want("pages"):
		for row: Array in [["08_collection", MenuArchive], ["09_characters", MenuDossiers], ["10_stats", MenuStats], ["11_challenges", MenuChallenges]]:
			_menu.call("open_screen", row[1])
			await _settle(1.2)
			await _shot(str(row[0]))
			await _close()
		var st: MenuSettings = _menu.call("open_screen", MenuSettings) as MenuSettings
		await _settle(0.6)
		st.call("_set_tab", MenuSettings.TABS.find("Accessibility"))
		await _settle(1.0)
		await _shot("12_settings_accessibility")
		st.call("_set_tab", MenuSettings.TABS.find("Gameplay"))
		await _settle(1.0)
		await _shot("12b_settings_gameplay")
		await _close()
	if _want("coop"):
		Lobbies.use_mock(MOCK_PORT, true)
		Lobbies.set_display_name("Dutch")
		var lb: MenuLobby = _menu.call("open_screen", MenuLobby) as MenuLobby
		await _settle(1.0)
		await _shot("13_coop_home")
		lb.call("_go", "create")
		await _settle(1.0)
		await _shot("13b_coop_host")
		Lobbies.create("map00_crossroads", true, "Dutch", 4, true)
		var t: float = 0.0
		while t < 10.0 and not Net.is_online():
			await get_tree().process_frame
			t += get_process_delta_time()
		lb.call("rebuild")
		await _settle(1.5)
		await _shot("13c_coop_room")
		Lobbies.leave()
		await _settle(0.5)
		await _close()
	_menu.queue_free()
	_menu = null
	await _settle(0.3)
	if _want("loading"):
		for row: Array in [["14_loading_no_clip", "user://_t267_no_clips", 1.5], ["15_loading_clip", _clips, 2.5], ["15b_loading_clip_later", _clips, 4.5]]:
			if str(row[1]) == "":
				print("[shots_t267] no clip folder: %s skipped" % row[0])
				continue
			LoadingClips.dir_override = str(row[1])
			Campaign.reset()
			var ls: LoadingScreen = (load(LoadingScreen.SCENE) as PackedScene).instantiate() as LoadingScreen
			ls.demo_map = "map00_crossroads"
			var layer: CanvasLayer = CanvasLayer.new()
			layer.layer = 50
			get_tree().root.add_child(layer)
			layer.add_child(ls)
			await _settle(float(row[2]), 12)
			print("[shots_t267] loading %s: clip '%s', playing %s at %.2f s" % [row[0], ls.clip_path.get_file(), ls.video != null and ls.video.is_playing(),
				ls.video.stream_position if ls.video != null else 0.0])
			await _shot(str(row[0]))
			layer.queue_free()
			await _settle(0.2)
	print("[shots_t267] %d screenshots in %s" % [_saved, ProjectSettings.globalize_path(_out)])
	print("[shots_t267] RESULT: PASS")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0)
