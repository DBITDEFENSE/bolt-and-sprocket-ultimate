extends Node
## T-184 dev tool: plays one cutscene of the game the way the game starts it, so it can be filmed (WSL + Xvfb,
## tools/wsl_cutscene_clip.sh) or checked headless. Opens the cutscene's map with the squad (god mode, no homage
## bosses), stands the squad where the scene expects them (the beacon, the heart, the console), starts the cutscene
## through the game's own entry point and quits a moment after it ends (before the next map loads):
##   exfil_*                 the campaign hop (Campaign.begin_at, ExfilPoint.trigger_now + force_depart)
##   m2_letzte_fahrt_dive    Totenhafen's dive (the quest runner letzte_fahrt_ending.gd)
##   requiem                 Kaltenbrunn's Requiem ending (the quest runner requiem_ending.gd)
##   london                  the London window (FlightController.start_london)
##   cancel / renewal        Fernflug's two endings (MondlichtController.start_cancel / start_renewal)
## Prints "[clip] START frame=<n>" when the cutscene begins and "[clip] END frame=<n>" when it is over (the
## clip script trims the movie to them) and "[clip] RESULT: PASS" / "FAIL: ...".
## Usage: godot [--headless] --audio-driver Dummy [--write-movie x.avi --fixed-fps 24] --path . \
##        res://gravelight/tools_src/clip_cutscene.tscn -- --cut=exfil_m0_m1 [--bots=2] [--tail=1.5] [--skip-at=<s>]
##        [--stills=<abs dir> --every=<s> --until=<s>]
## --skip-at=<s> presses skip (holds [interact] for the hold time) <s> seconds into the cutscene (the skip check).
## --stills saves a PNG of the frame every <s> cutscene seconds (a quick look at the shots without a movie; run it with
## a low --fixed-fps, the cameras move on the cutscene clock either way); --until stops after that many seconds.
## FAILS when a CinemaDirector shot names a node the map does not have (`missing`).

const MAPS: Dictionary = {
	"exfil_m0_m1": ["map00_crossroads", 10], "exfil_m1_m2": ["map01_kaltenbrunn", 30],
	"exfil_m2_m4": ["map02_totenhafen", 40], "exfil_m4a_m4b": ["map04a_thalbach", 14],
	"exfil_m4b_m4c": ["map04b_kranich", 20], "exfil_m4c_m4d": ["map04c_groomlake", 29],
	"m2_letzte_fahrt_dive": ["map02_totenhafen", 20], "requiem": ["map01_kaltenbrunn", 25],
	"london": ["map04b_kranich", 16], "cancel": ["map04d_mondlicht", 30], "renewal": ["map04d_mondlicht", 30],
	"inn_opening": ["map00_crossroads", 0],   # a fresh match on Map 0: the opening's title card, until the cue
	# T-194: the LAZARUS reels in a match, started the game's way (LazarusCinema at the match start, forced on)
	"lazarus_campaign_start": ["map00_crossroads", 0],   # a new campaign: FOURTH DAY, GRAVELIGHT ONE, then the opening
	"lazarus_map01_arrival": ["map01_kaltenbrunn", 0],   # STAUB on Kaltenbrunn's first match start
	"lazarus_map00_standalone": ["map00_crossroads", 0],   # GRAVELIGHT ONE on a plain Map 0 start (Play.bat's button)
}
## T-194: every id of cutscenes_lazarus.json also plays on its own (CinemaReel, as the Archive and the prologue do).

var cut: String = "exfil_m0_m1"
var bots: int = 2
var tail: float = 1.5
var skip_at: float = -1.0
var _runner: Node = null
var _exfil: ExfilPoint = null
var _started: bool = false
var _start_frame: int = 0
var _t: float = 0.0
var _end_t: float = -1.0
var _skip_pressed: bool = false
var _result: String = ""
var stills: String = ""
var every: float = 1.0
var until: float = -1.0
var _next_still: float = 0.0
var _missing: PackedStringArray = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cut="):
			cut = a.substr(6)
		elif a.begins_with("--bots="):
			bots = clampi(int(a.substr(7)), 0, 3)
		elif a.begins_with("--tail="):
			tail = float(a.substr(7))
		elif a.begins_with("--skip-at="):
			skip_at = float(a.substr(10))
		elif a.begins_with("--stills="):
			stills = a.substr(9)
		elif a.begins_with("--every="):
			every = maxf(0.1, float(a.substr(8)))
		elif a.begins_with("--until="):
			until = float(a.substr(8))
	if not MAPS.has(cut) and not CinemaArchive.is_known(cut):
		_fail("unknown cutscene '%s' (one of %s)" % [cut, ", ".join(PackedStringArray(MAPS.keys() + CinemaLibrary.ids()))])
		return
	var tree: SceneTree = get_tree()
	if tree.current_scene == self:   # stay under the root so the map swap does not free the tool
		tree.root.remove_child.call_deferred(self)
		tree.root.add_child.call_deferred(self)
	ProfileSave.path = "user://_qa_clip_cutscene_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_clip_cutscene_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GLSettings.values["bot_local_ai"] = false
	GLSettings.values["vfx_quality"] = "high"
	for a2: String in OS.get_cmdline_user_args():
		if a2.begins_with("--gore="):
			GLSettings.values["gore"] = a2.substr(7)
		elif a2 == "--no-subs":   # a clean picture for the photoreal reel clips (no lettering for a video model to garble)
			GLSettings.values["subtitles"] = false
	if CinemaArchive.is_known(cut):
		Campaign.cutscene_speed = 1.0
		_reel_alone.call_deferred()
		return
	GameState.character_id = &"dutch"
	GameState.bot_count = bots
	GameState.bot_skill = "veteran"
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	var row: Array = MAPS[cut]
	var map_id: StringName = StringName(str(row[0]))
	if cut.begins_with("lazarus_"):
		LazarusCinema.force = true
		if cut == "lazarus_campaign_start":
			Campaign.begin()
		else:
			Campaign.reset()
			LazarusCinema.force_ids = ["gravelight_one"] if cut == "lazarus_map00_standalone" else ["staub"]
	elif cut == "inn_opening":
		Campaign.reset()
	else:
		Campaign.begin_at(map_id, int(row[1]), Campaign.arrival_kit(map_id))
	Campaign.cutscene_speed = 1.0
	_go.call_deferred(Campaign.scene_for(map_id))


## T-194: a LAZARUS cutscene on its own (the prologue's and the Archive's way: CinemaReel over nothing).
func _reel_alone() -> void:
	var reel: CinemaReel = CinemaReel.play(self, [cut], {"speed": 1.0, "roster": ["dutch", "peg", "deacon", "wren"]})
	_runner = reel
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="):   # T-194: start at this second of the cutscene (a look at one shot)
			await get_tree().process_frame
			reel.fast_forward(float(a.substr(7)))
	_started = true
	_start_frame = Engine.get_process_frames()
	print("[clip] START frame=%d cut=%s map=(stage)" % [_start_frame, cut])


func _go(scene: String) -> void:
	get_tree().change_scene_to_file(scene)
	var t: float = 0.0
	while _map() == null and t < 240.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	if _map() == null:
		_fail("the map never loaded (%s)" % scene)
		return
	if cut == "inn_opening":   # the opening runs from the first frame: no settle, nothing stopped
		_runner = _map().find_child("InnOpening", true, false)
		if _runner == null:
			for n: Node in _map().find_children("*", "Node3D", true, false):
				if n is InnOpening:
					_runner = n
					break
		if _runner == null:
			_fail("no InnOpening on Map 0")
			return
		_started = true
		_start_frame = Engine.get_process_frames()
		print("[clip] START frame=%d cut=%s map=%s" % [_start_frame, cut, _map().map_id])
		return
	if cut.begins_with("lazarus_"):   # T-194: the match start played it (LazarusCinema.on_rounds_started)
		var lc: LazarusCinema = LazarusCinema.of(_map())
		var w: float = 0.0
		while (lc == null or lc.reel == null) and w < 10.0:
			await get_tree().process_frame
			w += get_process_delta_time()
			lc = LazarusCinema.of(_map())
		if lc == null or lc.reel == null:
			_fail("the match start played no LAZARUS cutscene")
			return
		_runner = lc.reel
		_started = true
		_start_frame = Engine.get_process_frames()
		print("[clip] START frame=%d cut=%s map=%s (%s)" % [_start_frame, cut, _map().map_id, ", ".join(PackedStringArray(lc.playing))])
		return
	await get_tree().create_timer(4.0).timeout   # settle: shaders, the squad, the first round's intro
	var map: MapRoot = _map()
	RoundManager.stop()
	if map.director != null:
		map.director.kill_all(true)
	_start(map)


func _map() -> MapRoot:
	var m: MapRoot = get_tree().current_scene as MapRoot
	return m if m != null and m.player != null and m.player.is_inside_tree() else null


## Stands the human and the bots in a loose half-ring in front of `at`, facing `face`.
func _stand_squad(map: MapRoot, at: Vector3, face: Vector3) -> void:
	var i: int = 0
	for pid: Variant in map.players.keys():
		var p: Player = map.players[pid] as Player
		if p == null:
			continue
		var off: Vector3 = Vector3(1.2 * float(i % 3) - 1.2, 0, 0.9 * float(i / 3) + (0.4 if i % 2 == 1 else 0.0))
		p.global_position = at + off
		p.velocity = Vector3.ZERO
		var to: Vector3 = face - p.global_position
		p.rotation.y = atan2(-to.x, -to.z)
		i += 1


func _start(map: MapRoot) -> void:
	match cut:
		"requiem":
			var heart: Node3D = map.get_node_or_null("Geometry/Heart") as Node3D
			if heart != null:   # the core's floor is 7 m under the heart; the pit rim is 5 m round it
				_stand_squad(map, heart.global_position + Vector3(0, -6.9, 9.0), heart.global_position + Vector3(0, -6.9, 0))
			_runner = Node.new()
			_runner.set_script(load("res://gravelight/world/requiem_ending.gd"))
			_runner.set("params", {"seconds": 40.0})
			map.add_child(_runner)
		"m2_letzte_fahrt_dive":
			_runner = Node.new()
			_runner.set_script(load("res://gravelight/world/map02/letzte_fahrt_ending.gd"))
			_runner.set("params", {"cutscene": "m2_letzte_fahrt_dive", "seconds": 34.0, "dive_at": 20.0, "card_seconds": 6.0})
			map.add_child(_runner)
		"london":
			var fc: Node = get_tree().get_first_node_in_group(&"flight_controller")
			if fc == null:
				_fail("no FlightController on the Kranich")
				return
			fc.set("london_started", false)
			fc.call("start_london")
			_runner = map.find_child("LondonWindow", true, false)
		"cancel", "renewal":
			var ctl: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
			if ctl == null:
				_fail("no MondlichtController on Mondlicht")
				return
			var console: Node3D = get_tree().get_first_node_in_group(&"account_console") as Node3D
			if console != null:
				_stand_squad(map, console.global_position + Vector3(-2.0, 0, 3.0), console.global_position)
			if cut == "cancel":
				ctl.call("start_cancel", 1)
			else:
				ctl.call("start_renewal")
			_runner = ctl.get("ending") as Node
		_:
			_exfil = get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint
			if _exfil == null:
				_fail("no exfil beacon on %s" % map.map_id)
				return
			var front: Vector3 = _exfil.global_position + _exfil.global_basis * Vector3(0, 0, -1.8)
			_stand_squad(map, front, _exfil.global_position)
			var rf: String = str(_exfil.cfg.get("requires_flag", ""))
			if rf != "":
				GameState.set_flag(StringName(rf))
			_exfil.trigger_now()
			await get_tree().process_frame
			if not _exfil.force_depart():
				_fail("the beacon would not depart (state %d)" % int(_exfil.state))
				return
			_runner = _exfil.cutscene
	if _runner == null:
		_fail("the cutscene did not start")
		return
	_started = true
	_start_frame = Engine.get_process_frames()
	print("[clip] START frame=%d cut=%s map=%s" % [_start_frame, cut, map.map_id])


func _ended() -> bool:
	if _runner == null or not is_instance_valid(_runner) or not _runner.is_inside_tree():
		return true
	if _runner is InnOpening:   # the card has come and gone (or the cue played)
		return bool(_runner.get("_card_titled")) and float(_runner.get("_card_t")) < 0.0 or bool(_runner.get("cued"))
	if _runner is CinemaReel:   # T-194
		return (_runner as CinemaReel).done
	for key: String in ["_done", "finished"]:
		if key in _runner and bool(_runner.get(key)):
			return true
	return false


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _started or _result != "":
		return
	_t += delta
	if is_instance_valid(_runner) and _runner is CinemaReel:   # T-194: a stage that did not load
		for m0: String in (_runner as CinemaReel).missing:
			if not _missing.has(m0):
				_missing.append(m0)
	for d: Node in get_tree().get_nodes_in_group(&"cinema"):
		for m: String in d.get("missing"):
			if not _missing.has(m):
				_missing.append(m)
		if OS.get_cmdline_user_args().has("--trace") and int(_t * 2.0) != int((_t - delta) * 2.0):
			var ov: CinemaOverlay = d.get("overlay") as CinemaOverlay
			print("[clip] t=%.1f shot=%d black=%.2f bars=%.0f" % [_t, int(d.get("shot_i")), ov.black() if ov != null else -1.0, ov.bars_shown() if ov != null else -1.0])
	if stills != "" and _t >= _next_still:
		_next_still += every
		var img: Image = get_viewport().get_texture().get_image()
		if img != null:
			DirAccess.make_dir_recursive_absolute(stills)
			img.save_png(stills.path_join("%s_%05.1f.png" % [cut.replace(":", "_"), _t]))
	if until > 0.0 and _t >= until and _end_t < 0.0:
		_end_t = _t
		print("[clip] END (until) t=%.2f" % _t)
	if skip_at >= 0.0 and _t >= skip_at and not _skip_pressed:
		_skip_pressed = true
		var ev: InputEventAction = InputEventAction.new()
		ev.action = &"interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		Input.action_press(&"interact")
		print("[clip] skip pressed at %.1f s" % _t)
	if _end_t < 0.0 and _ended():
		_end_t = _t
		print("[clip] END frame=%d t=%.2f" % [Engine.get_process_frames(), _t])
	if _end_t >= 0.0 and _t >= _end_t + tail:
		_pass()
	elif _t > 400.0:
		_fail("the cutscene ran over 400 s")


func _pass() -> void:
	if not _missing.is_empty():
		_fail("shots name nodes the map does not have: %s" % ", ".join(_missing))
		return
	_result = "PASS"
	print("[clip] RESULT: PASS cut=%s seconds=%.2f%s" % [cut, _end_t, " (skipped)" if _skip_pressed else ""])
	_quit(0)


func _fail(why: String) -> void:
	_result = "FAIL"
	print("[clip] RESULT: FAIL: %s" % why)
	_quit(1)


func _quit(code: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(code)
