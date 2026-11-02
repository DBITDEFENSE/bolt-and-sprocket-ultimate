class_name DevLauncher
extends Control
## The morning dev menu (PLAY.bat): one button per playable thing, with a skip-to-round field, god mode, the
## survivor, the bot squad and the local-AI bot for GRAVELIGHT. The full game menus are one button away.
## Choices are remembered in the GRAVELIGHT settings file where they already live there (bots, bot_local_ai).

const GL_MAPS: Array = [
	["CLAUDE ZOMBIES — Crossroads Inn (Map 0)", "res://gravelight/maps/map00_crossroads/map00.tscn"],
	["CLAUDE ZOMBIES — Kaltenbrunn (Map 1)", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"],
	["CLAUDE ZOMBIES — Totenhafen (Map 2)", "res://gravelight/maps/map02_totenhafen/map02.tscn"],
	["CLAUDE ZOMBIES — Map 4 Fernflug, Act I: Werk Thalbach", "res://gravelight/maps/map04_fernflug/map04a.tscn"],
	["CLAUDE ZOMBIES — Test Range (dev)", "res://gravelight/maps/test_range/test_range.tscn"],
]
## [label, scene, round, boss id] boss tests: a GRAVELIGHT map started at a late round, the boss summoned in
## front of the player a few seconds in (QuestManager.summon_boss, like the console's `boss`).
const BOSS_TESTS: Array = [
	["Boss test — The Foreman (Kaltenbrunn, round 12)", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", 12, "foreman"],
	["Boss test — The Screamer (Crossroads Inn, round 8)", "res://gravelight/maps/map00_crossroads/map00.tscn", 8, "screamer"],
	["Boss test — The Cousins (Crossroads Inn, round 10)", "res://gravelight/maps/map00_crossroads/map00.tscn", 10, "cousins"],
]
const BS_LEVELS: Array = [
	["Bolt & Sprocket — Scrapheap Junction", "res://bs/planets/scrapheap/scrapheap.tscn"],
	["Bolt & Sprocket — Rustvane Canyon", "res://bs/planets/rustvane/rustvane.tscn"],
	["Bolt & Sprocket — Nova Plaza", "res://bs/planets/nova_plaza/nova_plaza.tscn"],
	["Bolt & Sprocket — Verdant Sink", "res://bs/planets/verdant/verdant.tscn"],
]
const CHARACTERS: Array = ["dutch", "peg", "deacon", "wren"]

static var _pending_round: int = 0
static var _pending_god: bool = false
static var _pending_scrip: int = 0
static var _pending_boss: String = ""
static var _pending_squad: bool = false   # T-142: force a relief squad on the next round
static var _pending_power: bool = false   # T-145: power on once the map is up

## UPDATE 09 section 8 (T-145): the targets of the "Update 09 — online, web, rebuilt maps" buttons, as data so
## smoke_launcher can check that every scene exists and every flag parses without opening a window.
const MAIN_MENU_NEW: String = "res://gravelight/ui/main_menu.tscn"
const MAP02: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const MOCK_PORT: int = 28500
const WEB_PORT: int = 8060
const WEB_URL: String = "http://127.0.0.1:8060/"
## [label, act map id, start round] (the round numbers are the same as the "skip to Act" buttons above)
const U09_ACTS: Array = [["Act I", "map04a_thalbach", 1], ["Act II", "map04b_kranich", 15],
	["Act III", "map04c_groomlake", 21], ["Act IV", "map04d_mondlicht", 30]]
## the user args of the two windows of "Host a test lobby (local)": [host, guest]
const HOST_ARGS: Array = ["--mock-online-serve=28500", "--open=online", "--auto-host"]
const GUEST_ARGS: Array = ["--mock-online=28500", "--open=online", "--auto-join"]

var _round: SpinBox
var _god: CheckBox
var _bots: OptionButton
var _ai: CheckBox
var _char: OptionButton
var _status: Label


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.055, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_top = 30
	scroll.offset_right = -60
	scroll.offset_bottom = -20
	add_child(scroll)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	col.add_child(MenuKit.label("DEV LAUNCHER", 54, MenuKit.GOLD, true))
	col.add_child(MenuKit.para("Pick something to play. The options below apply to CLAUDE ZOMBIES maps. Esc in a match opens the pause menu; ` (backquote) opens the dev console.", 16, MenuKit.DIM))

	# ---- options row
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	row.add_child(MenuKit.label("Start at round", 18))
	_round = SpinBox.new()
	_round.min_value = 1
	_round.max_value = 100
	_round.value = 1
	_round.custom_minimum_size = Vector2(110, 0)
	row.add_child(_round)
	_god = CheckBox.new()
	_god.text = "God mode"
	row.add_child(_god)
	row.add_child(MenuKit.label("Survivor", 18))
	_char = OptionButton.new()
	for c: String in CHARACTERS:
		_char.add_item(c.capitalize())
	_char.select(0)
	row.add_child(_char)
	row.add_child(MenuKit.label("Bots", 18))
	_bots = OptionButton.new()
	for n: int in 4:
		_bots.add_item("%d" % n)
	_bots.select(clampi(int(GLSettings.values.get("bots", 2)), 0, 3))
	row.add_child(_bots)
	_ai = CheckBox.new()
	_ai.text = "One bot on local AI (Ollama)"
	_ai.button_pressed = bool(GLSettings.values.get("bot_local_ai", true))
	row.add_child(_ai)

	# ---- the things to play
	col.add_child(_header(Game.GAME_MODE_NAME))
	var first: Button = null
	for m: Array in GL_MAPS:
		var scene: String = str(m[1])
		var mb: Button = MenuKit.button(str(m[0]), func() -> void: _start_gl(scene, int(_round.value)), 22, "ui_confirm")
		col.add_child(mb)
		if first == null:
			first = mb
	col.add_child(_header("Map 4 — Fernflug (campaign mode: the act beacons, carry-over, act-relative rounds)"))
	col.add_child(MenuKit.button("Map 4 — Fernflug (full run: Act I from round 1)", func() -> void: _start_act("map04a_thalbach", 1), 22, "ui_confirm"))
	for act: Array in [["Map 4 — skip to Act II: der Kranich (round 15)", "map04b_kranich", 15], ["Map 4 — skip to Act III: Groom Lake (round 21)", "map04c_groomlake", 21],
			["Map 4 — skip to Act IV: Mondlicht (round 30)", "map04d_mondlicht", 30]]:
		var aid: String = str(act[1])
		var ar: int = int(act[2])
		var built: bool = Campaign.scene_exists(StringName(aid))
		var ab: Button = MenuKit.button(str(act[0]) + ("" if built else "   (not built yet)"), func() -> void: _start_act(aid, ar), 22, "ui_confirm")
		ab.disabled = not built
		col.add_child(ab)
	col.add_child(_header("Boss tests"))
	for b: Array in BOSS_TESTS:
		var bscene: String = str(b[1])
		var br: int = int(b[2])
		var boss: String = str(b[3])
		col.add_child(MenuKit.button(str(b[0]), func() -> void: _start_gl(bscene, br, boss), 22, "ui_confirm"))
	col.add_child(_header("Update 02 tests"))
	col.add_child(MenuKit.button("Map 0 — round 5 (Jakub: the Old Cellar is open, his cage breaks at round 5)", func() -> void: _start_jakub(), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Map 0 — round 10 (the Cousins)", func() -> void: _start_gl("res://gravelight/maps/map00_crossroads/map00.tscn", 10, "cousins"), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Weapon range — ADS check  ( [ / ] cycle guns )", func() -> void: AdsRange.launch(get_tree()), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Kaltenbrunn — Totenglocke test (round 15, god mode)", func() -> void: get_tree().change_scene_to_file("res://gravelight/tools_src/range_totenglocke.tscn"), 22, "ui_confirm"))
	col.add_child(_header("Update 03 bot tests"))
	var map0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
	col.add_child(MenuKit.button("Bot test — Map 0 round 15 (3 bots, you play)", func() -> void: _start_gl(map0, 15, "", 3), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Bot test — Map 0 round 15 (watch: chase camera + AI labels)", func() -> void: _spawn_tool("res://gravelight/tools_src/clip_bots.tscn", ["--shot=train"], false), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Bot test — Cousins round (3 bots, you play)", func() -> void: _start_gl(map0, 10, "cousins", 3), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Bot test — Cousins round (watch)", func() -> void: _spawn_tool("res://gravelight/tools_src/clip_bots.tscn", ["--shot=cousins"], false), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Bot soak (headless, writes CSV to logs/ai_runs/)", func() -> void: _spawn_tool("res://tools_src/ai_soak.tscn", ["--scenario=player3", "--runs=3"], true), 22, "ui_confirm"))
	col.add_child(_header("Update 04 tests"))
	col.add_child(MenuKit.button("Map 0 — Pause map & marks test (3 bots, marks placed, the map open)", func() -> void: _start_tool_scene("res://gravelight/tools_src/play_marks.tscn"), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Kaltenbrunn — Bots Full Partner EE test (3 bots work the egg)", func() -> void: _start_tool_scene("res://gravelight/tools_src/play_ee_full.tscn"), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Armorer's Bench test (Map 0, at the bench, 20,000 Scrip, power on)", func() -> void:
		Engine.set_meta(&"bench_play_map", "map00")
		_start_tool_scene("res://gravelight/tools_src/bench_shots.tscn"), 22, "ui_confirm"))
	col.add_child(_header("Update 05 — art slice (Crossroads Inn)"))
	col.add_child(MenuKit.button("Map 0 — art slice (round 1)", func() -> void: _start_gl(map0, 1), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Map 0 — art slice (round 12, 3 bots)", func() -> void: _start_gl(map0, 12, "", 3), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Weapon viewer — every gun in hand  ( [ / ] cycle guns )", func() -> void: AdsRange.launch(get_tree()), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Character lineup — renders the squad, Jakub, the Cousins, patrons and faces to morning/screenshots/u05/people/", func() -> void:
		_spawn_tool("res://gravelight/tools_src/shots_lineup.tscn", ["--out=" + ProjectSettings.globalize_path("res://morning/screenshots/u05/people")], false), 22, "ui_confirm"))
	col.add_child(_header("Update 06 — voice acting (your recordings replace the computer voices line by line)"))
	col.add_child(MenuKit.button("Voice review page (opens in your browser; close its console window to stop)", func() -> void: _open_voice_review(), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Map 0 — voice test (round 1–3; logs each line's source to logs/voice_test.txt)", func() -> void:
		GLVO.voice_test = true
		_start_gl("res://gravelight/maps/map00_crossroads/map00.tscn", 1), 22, "ui_confirm"))
	col.add_child(_header("Update 08 — tier IV perks, the bots' late kit, bots finish the egg"))
	col.add_child(MenuKit.button("Kaltenbrunn — bots finish the egg (watch: bot mode plays you, 3 Full Partner bots)", func() -> void:
		_spawn_tool("res://gravelight/tools_src/play_ee_full.tscn", ["--botmode", "--bots=3"], false), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Perk tier IV test (50,000 Scrip, power on, round 15)", func() -> void: _start_tool_scene("res://gravelight/tools_src/play_tier4.tscn"), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Round 25 bot kit test (Map 0, round 25, 3 bots)", func() -> void: _start_gl(map0, 25, "", 3), 22, "ui_confirm"))
	col.add_child(_header("Update 09 — a living war (relief squads from the map edge)"))
	col.add_child(MenuKit.button("Relief squad test (Map 0, round 6, a squad forced on the next round)", func() -> void:
		_pending_squad = true
		_start_gl(map0, 6), 22, "ui_confirm"))
	col.add_child(_header("Update 09 — Ledger Lager and the bank on every map"))
	col.add_child(MenuKit.button("Ledger Lager test (Map 0, 20,000 Scrip, power on, round 10)", func() -> void: _start_tool_scene("res://gravelight/tools_src/play_ledger.tscn"), 22, "ui_confirm"))
	col.add_child(_header("Update 09 — online, the web build, the rebuilt maps"))
	_add_u09_buttons(col, map0)
	col.add_child(_header("Muster (your sidearm and Field Habits; saved per survivor, used by every match)"))
	col.add_child(MenuKit.button("Muster — pick the sidearm and Field Habits for the survivor above", func() -> void: add_child(MenuMuster.new(CHARACTERS[_char.selected])), 22, "ui_confirm"))
	col.add_child(_header("Bot mode (an AI plays your survivor; F6 or any input takes over)"))
	col.add_child(MenuKit.button("Bot mode — Map 0 (bots from the field above)", func() -> void:
		GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), _bots.selected)
		_start_tool_scene("res://gravelight/tools_src/play_botmode.tscn"), 22, "ui_confirm"))
	col.add_child(_header("Bolt & Sprocket"))
	for l: Array in BS_LEVELS:
		var lscene: String = str(l[1])
		col.add_child(MenuKit.button(str(l[0]), func() -> void: _start_bs(lscene), 22, "ui_confirm"))
	col.add_child(_header("Menus"))
	col.add_child(MenuKit.button("The full game menu (Terms & Conditions hub)", func() -> void: get_tree().change_scene_to_file("res://ui/main_menu.tscn"), 22))
	col.add_child(MenuKit.button(Game.GAME_MODE_NAME + " menu (characters, campaign, archive)", func() -> void: get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn"), 22))
	col.add_child(MenuKit.button("Quit", func() -> void: get_tree().quit(), 22, "ui_back"))
	_status = MenuKit.para("", 16, MenuKit.VIOLET)
	col.add_child(_status)
	first.grab_focus.call_deferred()


## One hint label under each button, so the launcher says what a button does without opening it.
func _hinted(col: Control, text: String, hint: String, action: Callable) -> Button:
	var b: Button = MenuKit.button(text, action, 22, "ui_confirm")
	b.tooltip_text = hint
	col.add_child(b)
	col.add_child(MenuKit.para(hint, 16, MenuKit.DIM))
	return b


## UPDATE 09 section 8 (T-145).
func _add_u09_buttons(col: Control, _map0: String) -> void:
	_hinted(col, "Online lobby", "The new main menu opened straight on Play > Online (Quick Match, Create, Browse, Join by code).", func() -> void:
		MenuLobby.open_request = "online"
		get_tree().change_scene_to_file(MAIN_MENU_NEW))
	_hinted(col, "Host a test lobby (local)", "Two windows on this PC: one serves a local lobby relay and creates a lobby, the other opens Browse. No internet needed.",
		func() -> void: _host_test_lobby())
	_hinted(col, "Web build (serve locally)", "Builds build/web if it is missing (the first build takes minutes), serves it on %s and opens your browser there." % WEB_URL,
		func() -> void: _serve_web())
	_hinted(col, "Totenhafen — rebuilt", "Map 2 at round 5 with 3 bots, power on (the rebuilt harbour: walk the new routes).", func() -> void:
		_pending_power = true
		_start_gl(MAP02, 5, "", 3))
	col.add_child(MenuKit.label("Fernflug — rebuilt (each act; bots, survivor and god mode from the fields above)", 20, MenuKit.PAPER, false))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for act: Array in U09_ACTS:
		var aid: String = str(act[1])
		var ar: int = int(act[2])
		var ab: Button = MenuKit.button("%s (round %d)" % [str(act[0]), ar], func() -> void: _start_act(aid, ar), 22, "ui_confirm")
		ab.tooltip_text = "Fernflug %s as rebuilt, in campaign mode with the act's arrival kit." % str(act[0])
		ab.disabled = not Campaign.scene_exists(StringName(aid))
		row.add_child(ab)
	col.add_child(MenuKit.para("Each act opens in campaign mode with its arrival kit; Acts II to IV start with the launcher's Scrip for that round.", 16, MenuKit.DIM))
	_hinted(col, "Main menu (new)", "The rebuilt CLAUDE ZOMBIES main menu (the 3D inn scene, Play / Muster / Archive / Extras).",
		func() -> void: get_tree().change_scene_to_file(MAIN_MENU_NEW))


## Two game windows over the local mock relay: the host serves the relay and creates a public lobby, the guest
## (started 3 s later, once the relay listens) opens Browse. Both use the main menu with the --open=online /
## --auto-host / --auto-join flags (MenuLobby), silent only if you mute them: these are real windows.
func _host_test_lobby() -> void:
	var host_pid: int = _spawn_main_menu(HOST_ARGS)
	if host_pid <= 0:
		_status.text = "Could not start the host window."
		return
	_status.text = "Host window started (pid %d, relay on port %d); the guest window opens in 3 s." % [host_pid, MOCK_PORT]
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		var gp: int = _spawn_main_menu(GUEST_ARGS)
		_status.text = ("Host pid %d and guest pid %d are open: the guest is in Browse, join the lobby from there." % [host_pid, gp]) \
			if gp > 0 else "Could not start the guest window.")


func _spawn_main_menu(args: Array) -> int:
	var argv: PackedStringArray = ["--path", ProjectSettings.globalize_path("res://"), MAIN_MENU_NEW, "--"]
	for a: Variant in args:
		argv.append(str(a))
	return OS.create_process(OS.get_executable_path(), argv, false)


## The shell command that builds (when build/web/index.html is missing) and serves the web build: for a console window.
static func web_command(have_build: bool) -> String:
	return ("" if have_build else "tools/build_web.sh && ") + "tools/serve_web.sh --port=%d" % WEB_PORT


func _bash_path() -> String:
	for p: String in ["C:/Program Files/Git/bin/bash.exe", "C:/Program Files/Git/usr/bin/bash.exe"]:
		if FileAccess.file_exists(p):
			return p
	return "bash"


## Builds if needed, serves build/web in a console window and opens the browser once the port answers (polled for
## up to 30 minutes, since the first build takes minutes).
func _serve_web() -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	var have: bool = FileAccess.file_exists(root.path_join("build/web/index.html"))
	var cmd: String = "cd \"%s\" && %s" % [root, web_command(have)]
	var pid: int = OS.create_process(_bash_path(), ["-c", cmd], true)
	if pid <= 0:
		_status.text = "Could not start bash (Git Bash is needed): run tools/build_web.sh and tools/serve_web.sh by hand."
		return
	_status.text = ("Serving build/web on %s (console pid %d); the browser opens when it answers." % [WEB_URL, pid]) if have \
		else "Building the web build (first time: minutes, see the console, pid %d); the browser opens at %s when it is served." % [pid, WEB_URL]
	_open_when_up()


func _open_when_up() -> void:
	for i: int in 900:
		await get_tree().create_timer(2.0).timeout
		if not is_inside_tree():
			return
		var p: StreamPeerTCP = StreamPeerTCP.new()
		if p.connect_to_host("127.0.0.1", WEB_PORT) == OK:
			for k: int in 5:
				await get_tree().create_timer(0.1).timeout
				p.poll()
				if p.get_status() != StreamPeerTCP.STATUS_CONNECTING:
					break
			var up: bool = p.get_status() == StreamPeerTCP.STATUS_CONNECTED
			p.disconnect_from_host()
			if up:
				OS.shell_open(WEB_URL)
				_status.text = "Opened %s in your browser." % WEB_URL
				return


func _header(text: String) -> Label:
	var l: Label = MenuKit.label(text, 26, MenuKit.INK, true)
	return l


func _start_gl(scene: String, start_round: int, boss: String = "", force_bots: int = -1) -> void:
	if not ResourceLoader.exists(scene):
		_status.text = "Missing scene: %s" % scene
		return
	var bots: int = _bots.selected if force_bots < 0 else force_bots
	GLSettings.set_value("bots", bots)
	GLSettings.set_value("bot_local_ai", _ai.button_pressed)
	GameState.character_id = StringName(CHARACTERS[_char.selected])
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "regular"))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	Campaign.reset()
	_pending_round = start_round
	_pending_god = _god.button_pressed
	_pending_scrip = scrip_for_round(start_round)
	_pending_boss = boss
	if not GLBus.match_started.is_connected(DevLauncher._on_match_started):
		GLBus.match_started.connect(DevLauncher._on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file(scene)


## UPDATE 07: a Map 4 act in campaign mode (Campaign.begin_at): the act's beacon exists, the rounds are
## act-relative, and a skip past round 1 lands with the act's arrival kit (campaign.json "arrival_kits") plus
## the launcher's Scrip for that round. Bots, survivor and god mode from the fields above.
func _start_act(map_id: String, start_round: int) -> void:
	var scene: String = Campaign.scene_for(StringName(map_id))
	if not ResourceLoader.exists(scene):
		_status.text = "Missing scene: %s" % scene
		return
	var bots: int = _bots.selected
	GLSettings.set_value("bots", bots)
	GLSettings.set_value("bot_local_ai", _ai.button_pressed)
	GameState.character_id = StringName(CHARACTERS[_char.selected])
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "regular"))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	var kit: Dictionary = Campaign.arrival_kit(StringName(map_id)) if start_round > 1 else {}
	if not kit.is_empty() and not kit.has("scrip"):
		kit["scrip"] = scrip_for_round(start_round)
	Campaign.begin_at(StringName(map_id), start_round, kit)
	_pending_round = 0
	_pending_scrip = 0
	_pending_boss = ""
	_pending_god = _god.button_pressed
	if not GLBus.match_started.is_connected(DevLauncher._on_match_started):
		GLBus.match_started.connect(DevLauncher._on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file(scene)


func _start_bs(scene: String) -> void:
	if not ResourceLoader.exists(scene):
		_status.text = "Missing scene: %s" % scene
		return
	BS.god_mode = _god.button_pressed
	BSLevel.pending_cutscene = ""
	get_tree().change_scene_to_file(scene)


## Map 0 with the Old Cellar open, round 4 next (Jakub's breakout is round 5): the survivor, bots and god mode
## from the fields above (gravelight/tools_src/play_jakub.gd reads them from GameState).
func _start_jakub() -> void:
	var bots: int = _bots.selected
	GLSettings.set_value("bots", bots)
	GameState.character_id = StringName(CHARACTERS[_char.selected])
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.god_mode = _god.button_pressed
	Campaign.reset()
	get_tree().change_scene_to_file("res://gravelight/tools_src/play_jakub.tscn")


## Opens an Update 04 test scene in this process with the survivor and god mode from the fields above (each scene
## sets its own bots, Scrip and setup).
## Serves voice_review/ on http://127.0.0.1:8765 (a console window; close it to stop) and opens the browser (T-101).
func _open_voice_review() -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	var py: String = root.path_join("tools/venv/Scripts/python.exe")
	if not FileAccess.file_exists(py):
		py = root.path_join("tools/venv/bin/python")
	if not FileAccess.file_exists(py):
		py = "python"
	OS.create_process(py, [root.path_join("tools/voice/review.py")], true)


func _start_tool_scene(scene: String) -> void:
	GameState.character_id = StringName(CHARACTERS[_char.selected])
	GameState.god_mode = _god.button_pressed
	Campaign.reset()
	get_tree().change_scene_to_file(scene)


## Runs a tool scene in a second Godot process (this one keeps the launcher): windowed to watch it, or
## headless and silent for a soak (its results land in the project's logs/ folder).
func _spawn_tool(scene: String, args: Array, headless: bool) -> void:
	var argv: PackedStringArray = []
	if headless:
		argv.append_array(["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60"])
	argv.append_array(["--path", ProjectSettings.globalize_path("res://"), scene, "--"])
	for a: Variant in args:
		argv.append(str(a))
	if not headless and OS.get_cmdline_user_args().has("--frame-log"):
		argv.append("--frame-log")   # the frame logger follows a watched window too
	var pid: int = OS.create_process(OS.get_executable_path(), argv, false)
	if pid <= 0:
		_status.text = "Could not start %s" % scene
	elif headless:
		_status.text = "Soak running in the background (pid %d): results in logs/ai_runs/ when it finishes (about 15-30 min)." % pid
	else:
		_status.text = "Opened %s in a new window." % scene.get_file()


## Late-round Scrip so a skipped-to round can be played like one: about what a good player has by then (pure).
static func scrip_for_round(r: int) -> int:
	return 0 if r <= 1 else mini(60000, 900 * (r - 1) + 60 * (r - 1) * (r - 1))


## After the map's _ready: god mode, the round skip (the round manager started at round 1 in the same frame,
## so the skip goes in deferred), and the Scrip for it, for everyone.
static func _on_match_started(_map_id: StringName) -> void:
	GameState.god_mode = _pending_god
	if _pending_round > 1:
		RoundManager.debug_set_round.call_deferred(_pending_round)
	if _pending_scrip > 0:
		for pid: int in GameState.player_ids:
			Economy.grant.call_deferred(pid, _pending_scrip)
	_pending_round = 0
	_pending_scrip = 0
	if _pending_power:
		_pending_power = false
		GameState.set_deferred("power_on", true)
		GLBus.power_activated.emit.call_deferred()
	if _pending_squad:
		_pending_squad = false
		var t2: SceneTree = Engine.get_main_loop() as SceneTree
		t2.process_frame.connect(func() -> void:
			var rs: ReliefSquad = ReliefSquad.instance(t2)
			if rs != null:
				rs.force_next = true, CONNECT_ONE_SHOT)
	if _pending_boss == "cousins":
		_pending_boss = ""   # round 10 on Map 0 is the Cousins Round itself (HB1): nothing to summon
	if _pending_boss != "":
		var boss: StringName = StringName(_pending_boss)
		_pending_boss = ""
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		tree.create_timer(6.0).timeout.connect(func() -> void:
			var p: Player = tree.get_first_node_in_group(&"local_player") as Player
			if p == null:
				for n: Node in tree.get_nodes_in_group(&"players"):
					if (n as Player).is_local:
						p = n as Player
			if p != null:
				QuestManager.summon_boss(boss, p.global_position - p.global_basis.z * 8.0))
