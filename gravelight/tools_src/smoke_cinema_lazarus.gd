extends Node
## T-194 headless smoke for the LAZARUS cutscenes (docs/CUTSCENES_LAZARUS.md, DECISIONS T-194):
##   1. each of the five plays on its own to its end (x12), no missing stage or node, and each again skipped
##      (hold to skip: the overlay's full hold) ends at once
##   2. the first launch: the CLAUDE ZOMBIES menu opens the prologue (CinemaTheatre), a skip ends it, the menu comes back
##      and the profile has prologue_seen; the menu does not play it again
##   3. a new campaign on Map 0: FOURTH DAY then GRAVELIGHT ONE play at the match start (x10); while they play the round's
##      intro is held, the input blocked and Map 0's opening waits (no settled-view clock); after them the opening runs
##      as built and round 1 starts
##   4. Kaltenbrunn on its own: STAUB plays first (the profile has not seen it), then the match goes on
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_cinema_lazarus.tscn
## Prints "[smoke_cinema] ..." lines and "RESULT: PASS" / "RESULT: FAIL" (exit code 0/1).

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 900.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	if get_parent() != get_tree().root or name != "SmokeCinemaDriver":   # survive the scene changes
		var d: Node = (load("res://gravelight/tools_src/smoke_cinema_lazarus.gd") as GDScript).new() as Node
		d.name = "SmokeCinemaDriver"
		get_tree().root.add_child.call_deferred(d)
		queue_free.call_deferred()
		set_process(false)
		return
	ProfileSave.path = "user://_qa_cinema_lazarus_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_cinema_lazarus_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GLSettings.values["bot_local_ai"] = false
	GameState.character_id = &"wren"
	GameState.bot_count = 1
	GameState.bot_ai_mode = "off"
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _log(m: String) -> void:
	print("[smoke_cinema] ", m)


func _fail(m: String) -> void:
	_fails.append(m)
	_log("FAIL: " + m)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fail(what)


func _wait(cond: Callable, limit: float) -> bool:
	var w: float = 0.0
	while not bool(cond.call()) and w < limit:
		await get_tree().process_frame
		w += get_process_delta_time()
	return bool(cond.call())


func _run() -> void:
	await _alone()
	await _prologue()
	await _campaign_start()
	await _kaltenbrunn()
	_finish()


# ---------------------------------------------------------------- 1. on their own, then skipped

func _alone() -> void:
	for id: String in ["lazarus_saturday", "fourth_day", "staub", "gravelight_one", "epilogue_1953"]:
		var r: CinemaReel = CinemaReel.play(self, [id], {"speed": 12.0, "roster": ["wren", "dutch"]})
		var ends: Array = []
		r.cut_ended.connect(func(_i: int, cid: String, sk: bool) -> void: ends.append([cid, sk]))
		var ok: bool = await _wait(func() -> bool: return r.done, 60.0)
		_check(ok, "%s did not end on its own" % id)
		_check(ends.size() == 1 and not bool(ends[0][1]), "%s ended once, unskipped (%s)" % [id, str(ends)])
		_check(r.missing.is_empty(), "%s: missing %s" % [id, ", ".join(r.missing)])
		_log("%s played to its end (x12)%s" % [id, "" if r.missing.is_empty() else " MISSING " + ", ".join(r.missing)])
		await get_tree().create_timer(1.5).timeout
		var r2: CinemaReel = CinemaReel.play(self, [id], {"speed": 1.0})
		await get_tree().create_timer(0.5).timeout
		if r2.director != null and r2.director.overlay != null:
			r2.director.overlay.feed_skip(true, 2.0)   # a full hold of [interact]
		var ok2: bool = await _wait(func() -> bool: return r2.done, 2.0)
		_check(ok2 and r2.skipped_any, "%s: hold to skip ends it at once" % id)
		_log("%s skipped: %s" % [id, "ok" if ok2 else "NO"])
		await get_tree().create_timer(1.5).timeout


# ---------------------------------------------------------------- 2. the first launch

func _prologue() -> void:
	CinemaTheatre.force_prologue = true
	ProfileSave.profile = ProfileSave.new_profile()
	get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn")
	var reached: bool = await _wait(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene is CinemaTheatre, 20.0)
	_check(reached, "the first launch did not open the prologue")
	if not reached:
		return
	var th: CinemaTheatre = get_tree().current_scene as CinemaTheatre
	await _wait(func() -> bool: return th.reel != null and th.reel.director != null, 10.0)
	await get_tree().create_timer(1.0).timeout
	th.reel.director.overlay.feed_skip(true, 2.0)
	var back: bool = await _wait(func() -> bool: return get_tree().current_scene != null and String(get_tree().current_scene.scene_file_path).ends_with("gravelight/ui/main_menu.tscn"), 20.0)
	_check(back, "the menu did not come back after the prologue")
	_check(bool(ProfileSave.profile.get("prologue_seen", false)), "prologue_seen not set after a skip")
	await get_tree().create_timer(2.0).timeout
	_check(not (get_tree().current_scene is CinemaTheatre), "the menu played the prologue again")
	_log("the first launch: prologue, skip, menu, prologue_seen=%s" % str(ProfileSave.profile.get("prologue_seen", false)))
	CinemaTheatre.force_prologue = false


# ---------------------------------------------------------------- 3. a new campaign on Map 0

func _map() -> MapRoot:
	return get_tree().current_scene as MapRoot


func _campaign_start() -> void:
	LazarusCinema.force = true
	Campaign.begin()
	Campaign.cutscene_speed = 10.0
	GameState.god_mode = true
	get_tree().change_scene_to_file(Campaign.scene_for(&"map00_crossroads"))
	var got: bool = await _wait(func() -> bool: return _map() != null and LazarusCinema.of(_map()) != null and LazarusCinema.of(_map()).reel != null, 120.0)
	_check(got, "the campaign's start played no cutscene on Map 0")
	if not got:
		return
	var lc: LazarusCinema = LazarusCinema.of(_map())
	_check(lc.playing == ["fourth_day", "gravelight_one"], "the campaign start plays FOURTH DAY then GRAVELIGHT ONE (%s)" % str(lc.playing))
	var opening: InnOpening = null
	for n: Node in _map().find_children("*", "Node3D", true, false):
		if n is InnOpening:
			opening = n
	var held_ok: bool = true
	var cut_seen: Array = []
	lc.reel.cut_started.connect(func(_i: int, id: String) -> void: cut_seen.append(id))
	while lc.reel != null:
		if RoundManager.current_round != 0 or not GameState.input_blocked or (opening != null and opening.settle_t > 0.0):
			held_ok = false
		await get_tree().process_frame
	_check(held_ok, "the intro, the input and the opening were held while the cutscenes played")
	_check(lc.history == ["fourth_day", "gravelight_one"], "both played (%s)" % str(lc.history))
	_check(not GameState.input_blocked, "input back after the cutscenes")
	var r1: bool = await _wait(func() -> bool: return RoundManager.current_round >= 1, 120.0)
	_check(r1, "round 1 never started after the cutscenes")
	_check(opening == null or opening.settle_t > 0.0, "Map 0's opening ran its settled view after the cutscenes")
	_log("campaign start: %s, then round %d (opening settle %.1f s)" % [", ".join(PackedStringArray(lc.history)), RoundManager.current_round, opening.settle_t if opening != null else -1.0])


# ---------------------------------------------------------------- 4. Kaltenbrunn on its own

func _kaltenbrunn() -> void:
	Campaign.reset()
	LazarusCinema.force = true
	Campaign.cutscene_speed = 10.0
	get_tree().change_scene_to_file(Campaign.scene_for(&"map01_kaltenbrunn"))
	var got: bool = await _wait(func() -> bool: return _map() != null and String(_map().map_id) == "map01_kaltenbrunn" and LazarusCinema.of(_map()) != null and LazarusCinema.of(_map()).reel != null, 150.0)
	_check(got, "Kaltenbrunn's first match start played no STAUB")
	if not got:
		return
	var lc: LazarusCinema = LazarusCinema.of(_map())
	_check(lc.playing == ["staub"], "STAUB (%s)" % str(lc.playing))
	var held: bool = true
	while lc.reel != null:
		if RoundManager.current_round != 0:
			held = false
		await get_tree().process_frame
	_check(held, "the intro waited for STAUB")
	var r1: bool = await _wait(func() -> bool: return RoundManager.current_round >= 1, 90.0)
	_check(r1, "round 1 never started after STAUB")
	_log("Kaltenbrunn: staub, then round %d" % RoundManager.current_round)


func _finish() -> void:
	if _done:
		return
	_done = true
	LazarusCinema.force = false
	Campaign.cutscene_speed = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	for f: String in _fails:
		print("[smoke_cinema] FAIL: ", f)
	print("[smoke_cinema] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
