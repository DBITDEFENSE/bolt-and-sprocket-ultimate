class_name DevLauncher
extends Control
## The morning dev menu (PLAY.bat): one button per playable thing, with a skip-to-round field, god mode, the
## survivor, the bot squad and the local-AI bot for GRAVELIGHT. The full game menus are one button away.
## Choices are remembered in the GRAVELIGHT settings file where they already live there (bots, bot_local_ai).

const GL_MAPS: Array = [
	["GRAVELIGHT — Crossroads Inn (Map 0)", "res://gravelight/maps/map00_crossroads/map00.tscn"],
	["GRAVELIGHT — Kaltenbrunn (Map 1)", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"],
	["GRAVELIGHT — Totenhafen (Map 2)", "res://gravelight/maps/map02_totenhafen/map02.tscn"],
	["GRAVELIGHT — Test Range (dev)", "res://gravelight/maps/test_range/test_range.tscn"],
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
	col.add_child(MenuKit.para("Pick something to play. The options below apply to GRAVELIGHT maps. Esc in a match opens the pause menu; ` (backquote) opens the dev console.", 16, MenuKit.DIM))

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
	col.add_child(_header("GRAVELIGHT"))
	var first: Button = null
	for m: Array in GL_MAPS:
		var scene: String = str(m[1])
		var mb: Button = MenuKit.button(str(m[0]), func() -> void: _start_gl(scene, int(_round.value)), 22, "ui_confirm")
		col.add_child(mb)
		if first == null:
			first = mb
	col.add_child(_header("Boss tests"))
	for b: Array in BOSS_TESTS:
		var bscene: String = str(b[1])
		var br: int = int(b[2])
		var boss: String = str(b[3])
		col.add_child(MenuKit.button(str(b[0]), func() -> void: _start_gl(bscene, br, boss), 22, "ui_confirm"))
	col.add_child(_header("Update 02 tests"))
	col.add_child(MenuKit.button("Weapon range — ADS check  ( [ / ] cycle guns )", func() -> void: AdsRange.launch(get_tree()), 22, "ui_confirm"))
	col.add_child(MenuKit.button("Kaltenbrunn — Totenglocke test (round 15, god mode)", func() -> void: get_tree().change_scene_to_file("res://gravelight/tools_src/range_totenglocke.tscn"), 22, "ui_confirm"))
	col.add_child(_header("Bolt & Sprocket"))
	for l: Array in BS_LEVELS:
		var lscene: String = str(l[1])
		col.add_child(MenuKit.button(str(l[0]), func() -> void: _start_bs(lscene), 22, "ui_confirm"))
	col.add_child(_header("Menus"))
	col.add_child(MenuKit.button("The full game menu (Terms & Conditions hub)", func() -> void: get_tree().change_scene_to_file("res://ui/main_menu.tscn"), 22))
	col.add_child(MenuKit.button("GRAVELIGHT menu (characters, campaign, archive)", func() -> void: get_tree().change_scene_to_file("res://gravelight/ui/main_menu.tscn"), 22))
	col.add_child(MenuKit.button("Quit", func() -> void: get_tree().quit(), 22, "ui_back"))
	_status = MenuKit.para("", 16, MenuKit.VIOLET)
	col.add_child(_status)
	first.grab_focus.call_deferred()


func _header(text: String) -> Label:
	var l: Label = MenuKit.label(text, 26, MenuKit.INK, true)
	return l


func _start_gl(scene: String, start_round: int, boss: String = "") -> void:
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
	Campaign.reset()
	_pending_round = start_round
	_pending_god = _god.button_pressed
	_pending_scrip = scrip_for_round(start_round)
	_pending_boss = boss
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
