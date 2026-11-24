extends Node
## T-270 captures: the Solo page's war map (WorldMap) on three profiles (everything open, part of the road open, a
## new profile), with the focus on different places, plus the sheet alone. Rendered only through WSL + Xvfb:
##   sh tools/wsl_godot.sh --res=1920x1080 --path . res://gravelight/tools_src/shots_t270.tscn -- --out=docs/captures/t270 [--only=open,part,fresh,campaign]
## Headless it walks the same pages and saves nothing (a crash check).

const MENU: String = "res://gravelight/ui/main_menu.tscn"

var _out: String = "res://docs/captures/t270"
var _only: PackedStringArray = []
var _saved: int = 0
var _menu: Control = null
var _headless: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",", false)
	if not _out.begins_with("res://") and not _out.is_absolute_path():
		_out = "res://" + _out
	_headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_shots_t270_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_shots_t270_settings.cfg"
	get_tree().create_timer(1500.0).timeout.connect(func() -> void:
		print("[shots_t270] RESULT: FAIL (timeout)")
		get_tree().quit(2))
	_run.call_deferred()


func _process(_d: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## "open": every map, bests and eggs; "part": the road as far as Werk Thalbach; "fresh": a new profile.
static func _profile(kind: String) -> Dictionary:
	var p: Dictionary = ProfileSave.new_profile()
	p["xp"] = 42000
	match kind:
		"open":
			p["maps_unlocked"] = Array(MapCards.ids())
			p["best_round"] = {"map00_crossroads": 31, "map01_kaltenbrunn": 33, "map02_totenhafen": 41, "map04a_thalbach": 18,
				"map04b_kranich": 22, "map04c_groomlake": 30, "map04d_mondlicht": 12}
			p["eggs_done"] = {"map00_radio": true}
			p["egg_rewards"] = {"map01_requiem": true}
		"part":
			p["maps_unlocked"] = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach"]
			p["best_round"] = {"map00_crossroads": 23, "map01_kaltenbrunn": 14, "map02_totenhafen": 6}
			p["eggs_done"] = {"map00_radio": true}
		_:
			p["xp"] = 0
	return p


func _want(key: String) -> bool:
	return _only.is_empty() or _only.has(key)


func _settle(secs: float, min_frames: int = 4) -> void:
	var t0: int = Time.get_ticks_msec()
	var f: int = 0
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0) or f < min_frames:
		await get_tree().process_frame
		f += 1


func _shot(name_: String, crop: Rect2 = Rect2()) -> void:
	if _headless:
		print("[shots_t270] (headless) would save %s" % name_)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if crop.size.x > 0.0:   # `crop` is in the layout's pixels (1920 x 1080): scale it to the window
		var k: float = float(img.get_width()) / get_viewport().get_visible_rect().size.x
		var r: Rect2i = Rect2i(Vector2i(crop.position * k), Vector2i(crop.size * k)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img = img.get_region(r)
	img.save_png(ProjectSettings.globalize_path(_out.path_join(name_ + ".png")))
	_saved += 1
	print("[shots_t270] saved %s (%dx%d)" % [name_, img.get_width(), img.get_height()])


func _screen() -> MenuScreen:
	return _menu.get("_screen") as MenuScreen


func _close() -> void:
	var s: MenuScreen = _screen()
	if s != null and is_instance_valid(s):
		s.close()
	await _settle(0.6)


## Opens Solo on `kind`'s profile, picks a character, and shoots the page with the focus on each of `places`.
func _solo(kind: String, who: String, places: PackedStringArray, sheet_too: bool = false) -> void:
	ProfileSave.profile = _profile(kind)
	var mc: MenuCharacter = _menu.call("open_screen", MenuCharacter) as MenuCharacter
	await _settle(1.0)
	mc.call("_pick", who)
	await _settle(1.5)
	var w: WorldMap = mc.world
	print("[shots_t270] %s: the sheet is %s at %s, the page %s" % [kind, w.size, w.global_position, (mc.get("_page_root") as Control).size])
	for id: String in places:
		var b: Button = w.buttons[WorldMap.index_of(id)]
		b.grab_focus()
		await _settle(0.9)
		await _shot("%s_%s" % [kind, id.get_slice("_", 1)])
		if sheet_too and id == places[0]:
			await _shot("%s_sheet_only" % kind, Rect2(w.global_position, w.size))
	await _close()


func _run() -> void:
	_menu = (load(MENU) as PackedScene).instantiate() as Control
	get_tree().root.add_child(_menu)
	get_tree().current_scene = _menu
	await _settle(6.0, 8)
	_menu.call("show_column", "main", false)
	if _want("open"):
		await _solo("open", "dutch", ["map00_crossroads", "map02_totenhafen", "map04b_kranich", "map04d_mondlicht"], true)
	if _want("part"):
		GLSettings.set_value("bots", 2)   # the bots' paragraph under the sheet
		await _solo("part", "wren", ["map04a_thalbach", "map04b_kranich"])
		GLSettings.set_value("bots", 0)
	if _want("fresh"):
		await _solo("fresh", "peg", ["map00_crossroads", "map01_kaltenbrunn", "map04d_mondlicht"], true)
	if _want("reduced"):
		MenuMotion.force_reduced = 1
		await _solo("reduced", "deacon", ["map04c_groomlake"])
		MenuMotion.force_reduced = -1
	if _want("campaign"):
		ProfileSave.profile = _profile("part")
		_menu.call("_open_campaign")
		await _settle(1.0)
		(_screen() as MenuCharacter).call("_pick", "wren")
		await _settle(1.2)
		await _shot("campaign_unchanged")
		await _close()
	print("[shots_t270] RESULT: PASS (%d saved)" % _saved)
	for p: String in [ProfileSave.path, GLSettings.path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	get_tree().quit(0)
