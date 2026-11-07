extends Node
## Headless smoke test for the dev launcher's Map 4 buttons (UPDATE 07, T-116; PLAY.bat → ui/dev_launcher.tscn):
##   1. the launcher builds; the four Map 4 buttons exist ("full run", "skip to Act II / III / IV"), none disabled,
##      none marked "(not built yet)"
##   1b. UPDATE 09 section 8 (T-145): the Update 09 buttons exist (Online lobby, Host a test lobby (local), Web build
##       (serve locally), Totenhafen - rebuilt, Fernflug rebuilt Act I-IV, Main menu (new)), and each target resolves
##       without opening a window: scenes exist, the launch flags parse (--open=online, --auto-host / --auto-join,
##       --mock-online[-serve]=port), the web command is built, the Fernflug acts are built
##   2. "skip to Act II" (DevLauncher._start_act): Campaign.begin_at with the arrival kit; der Kranich loads in
##      campaign mode, round 15 next ("ACT II · 1"), the kit's guns, perks, grenades and the launcher's Scrip on
##      the human, the bots the launcher chose, the cradle beacon dormant and due at round 20
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_launcher.tscn

const TIMEOUT: float = 120.0
const WANT: Array = ["Map 4 — Fernflug (full run: Act I from round 1)", "Map 4 — skip to Act II: der Kranich (round 15)",
	"Map 4 — skip to Act III: Groom Lake (round 21)", "Map 4 — skip to Act IV: Mondlicht (round 30)"]

const WANT_U09: Array = ["Online lobby", "Host a test lobby (local)", "Web build (serve locally)", "Totenhafen — rebuilt",
	"Act I (round 1)", "Act II (round 15)", "Act III (round 21)", "Act IV (round 30)", "Main menu (new)",
	"Relief squad test (Map 0, round 6, a squad forced on the next round)", "Ledger Lager test (Map 0, 20,000 Scrip, power on, round 10)"]

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_launcher.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_launcher_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	Campaign.cutscene_speed = 12.0
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	print("[launcher] %-74s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _run() -> void:
	var launcher: Control = (load("res://ui/dev_launcher.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(launcher)
	get_tree().current_scene = launcher   # _start_act swaps the current scene (the launcher goes, this node stays)
	await _frames(3)
	var buttons: Dictionary = {}
	for n: Node in launcher.find_children("*", "Button", true, false):
		buttons[(n as Button).text] = n
	for w: String in WANT:
		var b: Button = buttons.get(w) as Button
		_check(b != null, "button exists: %s" % w)
		_check(b != null and not b.disabled, "button enabled: %s" % w)
	var unbuilt: PackedStringArray = []
	for t: Variant in buttons.keys():
		if str(t).begins_with("Map 4") and str(t).contains("not built"):
			unbuilt.append(str(t))
	_check(unbuilt.is_empty(), "no Map 4 button says '(not built yet)' (%s)" % ", ".join(unbuilt))
	for w3: String in WANT_U09:
		var b3: Button = buttons.get(w3) as Button
		_check(b3 != null and not b3.disabled, "Update 09 button exists and is enabled: %s" % w3)
	_check_u09_targets()
	var bots_chosen: int = (launcher.get("_bots") as OptionButton).selected
	launcher.call("_start_act", "map04b_kranich", 15)   # the "skip to Act II" button's call
	var loaded: bool = await _until(func() -> bool:
		var m: MapRoot = get_tree().current_scene as MapRoot
		return m != null and m.map_id == &"map04b_kranich" and m.is_node_ready(), 60.0)
	_check(loaded, "skip to Act II: der Kranich loaded")
	if not loaded:
		_finish()
		return
	await get_tree().create_timer(2.0).timeout
	var map: MapRoot = get_tree().current_scene as MapRoot
	var human: Player = map.player
	_check(Campaign.active and Campaign.pending_start_for(&"map04b_kranich").is_empty(), "campaign mode on, the pending start consumed")
	_check(RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.BREAK and RoundManager.act_start == 15, "round 15 is next (round %d, act start %d)" % [RoundManager.current_round, RoundManager.act_start])
	_check(RoundManager.act_label(15) == "ACT II · 1", "round 15 reads 'ACT II · 1' (" + RoundManager.act_label(15) + ")")
	var kit: Dictionary = Campaign.arrival_kit(&"map04b_kranich")
	for w2: Array in kit.get("weapons", []):
		_check(human.weapons.find_weapon(StringName(str(w2[0]))) != null, "the kit's gun %s is on the human" % str(w2[0]))
	for perk: Variant in kit.get("perks", []):
		_check(PerkManager.owned(1).has(StringName(str(perk))), "the kit's perk %s" % str(perk))
	_check(human.weapons.grenades == int(kit.get("grenades", 0)), "the kit's grenades (%d)" % human.weapons.grenades)
	_check(Economy.get_scrip(1) == DevLauncher.scrip_for_round(15), "the launcher's Scrip for round 15 (%d)" % Economy.get_scrip(1))
	_check(GameState.bot_count == BotConfig.clamp_bots(BotConfig.cfg(), bots_chosen) and get_tree().get_nodes_in_group(&"bots").size() == GameState.bot_count, "the launcher's bots (%d) are on the map" % GameState.bot_count)
	var x: ExfilPoint = get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint
	_check(x != null and x.state == ExfilPoint.State.DORMANT and x.next_round() == 20, "the autopilot cradle is dormant, due at round 20")
	_check(GameState.god_mode == false, "god mode follows the launcher's box (off)")
	_finish()


## The Update 09 buttons' targets, resolved without launching anything.
func _check_u09_targets() -> void:
	for scene: String in [DevLauncher.MAIN_MENU_NEW, DevLauncher.MAP02, "res://ui/dev_launcher.tscn"]:
		_check(ResourceLoader.exists(scene), "scene exists: " + scene)
	for act: Array in DevLauncher.U09_ACTS:
		var sc: String = Campaign.scene_for(StringName(str(act[1])))
		_check(ResourceLoader.exists(sc) and Campaign.scene_exists(StringName(str(act[1]))), "Fernflug %s scene resolves: %s" % [str(act[0]), sc])
	# UPDATE 10 section 9: the nine set-piece buttons' targets resolve and every setpiece name is one _force_setpiece knows
	for b: Array in DevLauncher.U10_BUTTONS:
		var kind: String = str(b[2])
		var target: String = str(b[3])
		if kind == "gl":
			_check(ResourceLoader.exists(target), "U10 '%s' scene exists" % str(b[0]))
		elif kind == "act":
			_check(Campaign.scene_exists(StringName(target)), "U10 '%s' act resolves" % str(b[0]))
		else:
			_check(kind == "egg" and target in ["map01", "map02"], "U10 '%s' egg map known" % str(b[0]))
		_check(str(b[7]) == "" or str(b[7]) in DevLauncher.U10_SETPIECES, "U10 '%s' setpiece known: %s" % [str(b[0]), str(b[7])])
	# UPDATE 11 FINISH: the six buttons' targets (cutscene ids in the library, the map scene, the review page script)
	_check(DevLauncher.U11_BUTTONS.size() == 6, "six Update 11 buttons")
	for b: Array in DevLauncher.U11_BUTTONS:
		var k: String = str(b[2])
		if k == "cut":
			_check(CinemaLibrary.data().get("cutscenes", {}).has(str(b[3])), "U11 '%s' cutscene exists" % str(b[0]))
		elif k in ["crash", "hard_truth"]:
			_check(ResourceLoader.exists(str(b[3])), "U11 '%s' scene exists" % str(b[0]))
		else:
			_check(k == "review" and FileAccess.file_exists("res://tools/voice/review.py"), "U11 '%s' review page script exists" % str(b[0]))
	_check(ResourceLoader.exists(CinemaTheatre.LAUNCHER), "the theatre's way back to the launcher exists")
	# the flags of the two test-lobby windows parse the way the game reads them
	for set: Array in [DevLauncher.HOST_ARGS, DevLauncher.GUEST_ARGS]:
		for a: Variant in set:
			_check(str(a).begins_with("--"), "flag shaped like a flag: " + str(a))
		_check(MenuLobby.open_mode(set) == "online", "%s opens the online lobby" % str(set))
	_check(MenuLobby.auto_mode(DevLauncher.HOST_ARGS) == "host" and MenuLobby.auto_mode(DevLauncher.GUEST_ARGS) == "join", "--auto-host / --auto-join parse")
	_check(MenuLobby.auto_mode([]) == "" and MenuLobby.open_mode([]) == "", "no flags: nothing opens or auto-runs (normal play and smokes unaffected)")
	var serve: String = str(DevLauncher.HOST_ARGS[0])
	var join: String = str(DevLauncher.GUEST_ARGS[0])
	_check(serve.begins_with("--mock-online-serve=") and join.begins_with("--mock-online=") and int(serve.get_slice("=", 1)) == DevLauncher.MOCK_PORT \
		and int(join.get_slice("=", 1)) == DevLauncher.MOCK_PORT and DevLauncher.MOCK_PORT > 1024, "the relay flags carry the same port (%d)" % DevLauncher.MOCK_PORT)
	_check(DevLauncher.web_command(true) == "tools/serve_web.sh --port=%d" % DevLauncher.WEB_PORT, "web command with a build: serve only")
	_check(DevLauncher.web_command(false).begins_with("tools/build_web.sh && tools/serve_web.sh"), "web command without a build: build, then serve")
	_check(FileAccess.file_exists(ProjectSettings.globalize_path("res://tools/build_web.sh")) and FileAccess.file_exists(ProjectSettings.globalize_path("res://tools/serve_web.sh")), "tools/build_web.sh and tools/serve_web.sh exist")
	_check(DevLauncher.WEB_URL == "http://127.0.0.1:%d/" % DevLauncher.WEB_PORT, "the web URL matches the port")


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[launcher] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
