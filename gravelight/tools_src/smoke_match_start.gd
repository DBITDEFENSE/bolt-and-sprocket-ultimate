extends Node
## T-267 headless check of what a match start shows, through the menu's own buttons (the main menu, Play > Solo or
## Play > Campaign, a character, a card), with the cutscenes switched ON for a headless run (LazarusCinema.force), so
## "nothing played" means the plan said nothing, not that headless skipped it:
##   1 solo, no clip file     the Solo page has no campaign card; the loading screen is the plain one (no video node);
##                            the map starts with no cutscene, no letterbox card, the player's input free
##   2 solo, a clip           (only when a clip folder is given or assets/video/loading has one) the clip plays while
##                            the map loads on its thread, the map is in no later than without it, and the screen
##                            leaves when the clip has played through (LoadingClips.min_show_s) or the map is in, whichever is later
##   3 solo, no clip again    the warm load time the clip run is compared with
##   4 campaign               the campaign's card; the loading screen plays no clip even with one on disk; the
##                            campaign's cutscenes play (the prologue first on a new profile)
##   Godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_match_start.tscn [-- --clips=<dir>]
## One RESULT line; exit code 0 = PASS.

const MENU: String = "res://gravelight/ui/main_menu.tscn"
const NO_CLIPS: String = "user://_smoke_match_start_no_clips"

var _tree: SceneTree = null
var _fails: PackedStringArray = []
var _checks: int = 0
var _clips: String = ""
var _notes: PackedStringArray = []


func _ready() -> void:
	if name != "MatchStartDriver":
		# the scene is replaced on the first change_scene; a driver under the root outlives it
		var d: Node = (load("res://gravelight/tools_src/smoke_match_start.gd") as GDScript).new() as Node
		d.name = "MatchStartDriver"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		return
	_tree = get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--clips="):
			_clips = a.substr(8)
	if _clips == "":
		LoadingClips.dir_override = ""
		if not LoadingClips.list().is_empty():
			_clips = LoadingClips.DIR
		elif FileAccess.file_exists("res://.smoke_logs/t267/clips/load_placeholder.ogv"):
			_clips = "res://.smoke_logs/t267/clips"   # the placeholder made for T-267 (not committed)
	ProfileSave.path = "user://_smoke_match_start_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_smoke_match_start_settings.cfg"
	GLSettings.values["bots"] = 0
	GLSettings.values[EggMode.SETTING] = EggMode.MODES[0]
	LazarusCinema.force = true
	_tree.create_timer(1100.0, true, false, true).timeout.connect(func() -> void:
		print("[match_start] RESULT: FAIL (timeout) %s" % "; ".join(_fails))
		_tree.quit(2))
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails.append(what)
	print("[match_start] %s %s" % ["ok  " if ok else "FAIL", what])


func _secs(s: float) -> void:
	await _tree.create_timer(s, true, false, true).timeout


func _wait(cond: Callable, limit: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if cond.call():
			return true
		await _tree.process_frame
	return bool(cond.call())


## The main menu, Play > Solo or Campaign, a character: the step 2 page.
func _to_cards(campaign: bool) -> MenuCharacter:
	_tree.paused = false
	GameState.input_blocked = false
	_tree.change_scene_to_file(MENU)
	await _wait(func() -> bool: return _tree.current_scene != null and _tree.current_scene.has_method("show_column"), 60.0)
	await _secs(1.0)
	var menu: Node = _tree.current_scene
	if campaign:
		menu.call("_open_campaign")
	else:
		menu.call("open_screen", MenuCharacter)
	await _secs(0.5)
	var mc: MenuCharacter = menu.get("_screen") as MenuCharacter
	if mc == null:
		return null
	mc.call("_pick", "wren")
	await _secs(0.5)
	return mc


## Presses `card`, follows the loading screen to the map. Returns {video, loaded_at, left_at, played, map}.
func _start(card: Button) -> Dictionary:
	var out: Dictionary = {"video": false, "loaded_at": -1.0, "left_at": -1.0, "played": false, "map": null, "pos": 0.0}
	LoadingScreen.last = {}
	card.pressed.emit()
	var got: bool = await _wait(func() -> bool: return _tree.current_scene is LoadingScreen, 20.0)
	if not got:
		return out
	var ls: LoadingScreen = _tree.current_scene as LoadingScreen
	out["video"] = ls.video != null
	out["clip"] = ls.clip_path
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(ls) and _tree.current_scene == ls and Time.get_ticks_msec() - t0 < 400000:
		if ls.video != null:
			out["played"] = bool(out["played"]) or ls.video.is_playing()
			out["pos"] = maxf(float(out["pos"]), ls.video.stream_position)
		await _tree.process_frame
	out["loaded_at"] = float(LoadingScreen.last.get("loaded_at", -1.0))
	out["left_at"] = float(LoadingScreen.last.get("left_at", -1.0))
	out["clip_s"] = float(LoadingScreen.last.get("clip_s", 0.0))
	await _wait(func() -> bool: return _tree.current_scene is MapRoot, 60.0)
	out["map"] = _tree.current_scene as MapRoot
	return out


func _solo(tag: String, clips: String) -> Dictionary:
	LoadingClips.dir_override = clips
	var mc: MenuCharacter = await _to_cards(false)
	_check(mc != null, "%s: Play > Solo opens the character and map page" % tag)
	if mc == null:
		return {}
	_check(mc.find_child("Card_Campaign", true, false) == null, "%s: the Solo page has no campaign card" % tag)
	var card: Button = null
	for c: Node in mc.find_child("MapCards", true, false).get_children():
		if str(c.get_meta("map_id", "")) == "map00_crossroads":
			card = c as Button
	_check(card != null and not card.disabled, "%s: the Crossroads Inn card is open" % tag)
	if card == null:
		return {}
	var r: Dictionary = await _start(card)
	var map: MapRoot = r["map"] as MapRoot
	_check(map != null, "%s: the map starts (loaded after %.2f s, left the loading screen at %.2f s)" % [tag, float(r["loaded_at"]), float(r["left_at"])])
	if map == null:
		return r
	_check(not Campaign.active, "%s: no campaign is running" % tag)
	await _secs(12.0)   # (past the map's own deferred start-up, which waits on the navigation map for up to 10 s)
	var lc: LazarusCinema = LazarusCinema.of(map)
	_check(lc != null and lc.reel == null and lc.history.is_empty() and lc.playing.is_empty(), "%s: no cutscene played (cutscenes forced on)" % tag)
	_check(not GameState.input_blocked, "%s: the player's input is free" % tag)
	_check(map.find_child("OpeningCard", true, false) == null, "%s: no letterbox title card" % tag)
	_check(map.find_child("ExfilCutscene", true, false) == null, "%s: no campaign hop" % tag)
	return r


func _run() -> void:
	# 1: solo, no clip file
	var a: Dictionary = await _solo("solo/no clip", NO_CLIPS)
	_check(not a.is_empty() and not bool(a["video"]), "solo/no clip: the plain loading screen (no video node)")
	_check(not a.is_empty() and float(a["left_at"]) >= LoadingScreen.MIN_SHOW_S - 0.05, "solo/no clip: it stayed its old minimum")
	# 2 + 3: solo with a clip, then without again (warm), when a clip is to hand
	if _clips != "":
		var b: Dictionary = await _solo("solo/clip", _clips)
		_check(not b.is_empty() and bool(b["video"]), "solo/clip: the loading screen plays %s" % str(b.get("clip", "")).get_file())
		_check(not b.is_empty() and bool(b["played"]) and float(b["pos"]) > 0.5, "solo/clip: the clip ran while the map loaded (%.2f s of it)" % float(b.get("pos", 0.0)))
		var want: float = LoadingClips.min_show_s(true, LoadingScreen.MIN_SHOW_S, float(b.get("clip_s", 0.0)))
		_check(not b.is_empty() and float(b.get("clip_s", 0.0)) > 1.0, "solo/clip: the stream reported its length (%.2f s)" % float(b.get("clip_s", 0.0)))
		_check(not b.is_empty() and float(b["left_at"]) >= want - 0.05, "solo/clip: the clip played through (%.2f s of a %.2f s clip, %.2f s wanted)" % [float(b.get("left_at", -1.0)), float(b.get("clip_s", 0.0)), want])
		_check(not b.is_empty() and float(b["left_at"]) <= maxf(want, float(b["loaded_at"])) + 1.0,
			"solo/clip: and then it left (loaded %.2f s, left %.2f s)" % [float(b.get("loaded_at", -1.0)), float(b.get("left_at", -1.0))])
		var c: Dictionary = await _solo("solo/no clip, warm", NO_CLIPS)
		if not b.is_empty() and not c.is_empty():
			var with_clip: float = float(b["loaded_at"])
			var without: float = float(c["loaded_at"])
			_notes.append("map load: cold no clip %.2f s, clip %.2f s, warm no clip %.2f s" % [float(a.get("loaded_at", -1.0)), with_clip, without])
			_check(with_clip <= maxf(without, float(a.get("loaded_at", 0.0))) * 1.5 + 2.0, "the clip does not stall the threaded load (%s)" % _notes[_notes.size() - 1])
	else:
		_notes.append("no clip on disk: stages 2 and 3 skipped")
	# 4: the campaign, with a clip on disk if there is one
	LoadingClips.dir_override = _clips if _clips != "" else NO_CLIPS
	var mc: MenuCharacter = await _to_cards(true)
	_check(mc != null, "campaign: Play > Campaign opens its page")
	var camp: Button = mc.find_child("Card_Campaign", true, false) as Button if mc != null else null
	_check(camp != null, "campaign: its card is there")
	if camp != null:
		_check(mc.find_child("MapCards", true, false).get_child_count() == 1, "campaign: and only its card")
		var r: Dictionary = await _start(camp)
		var map: MapRoot = r["map"] as MapRoot
		_check(map != null and Campaign.active, "campaign: the first map starts with the campaign running")
		_check(not bool(r["video"]), "campaign: the loading screen plays no clip")
		if map != null:
			var lc: LazarusCinema = LazarusCinema.of(map)
			var played: bool = await _wait(func() -> bool: return lc != null and (lc.reel != null or not lc.history.is_empty()), 40.0)
			_check(played, "campaign: its cutscenes still play (%s)" % (", ".join(PackedStringArray(lc.playing)) if lc != null else "-"))
			_check(lc != null and lc.playing.has("lazarus_saturday"), "campaign: a new profile's first campaign opens with the prologue")
	var ok: bool = _fails.is_empty()
	for n: String in _notes:
		print("[match_start] note: %s" % n)
	print("[match_start] RESULT: %s (%d checks%s)%s" % ["PASS" if ok else "FAIL", _checks, ", " + "; ".join(_notes) if not _notes.is_empty() else "",
		"" if ok else " failed: " + "; ".join(_fails)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GLSettings.path))
	_tree.paused = false
	_tree.quit(0 if ok else 1)
