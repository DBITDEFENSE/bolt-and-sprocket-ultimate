extends Node
## Dev launcher entry "Kaltenbrunn — Bots Full Partner EE test" (Update 04 sections 3 and 5, DECISIONS T-069 /
## T-067): Kaltenbrunn with 3 bots and "Bot Easter-Egg Help" on Full Partner for this session only (the saved
## setting is put back when the match ends), Scrip for the squad. The bots pick open Requiem steps they can do and
## call out what they are doing; mark more from the pause map or with the ping key.
## Scene: res://gravelight/tools_src/play_ee_full.tscn   Args (after --): --bots=N (default 3)  --god
## --character=wren  --round=R (start round, default 1)  --power (start with the power on)
## --map=map01|map02 (UPDATE 10: Totenhafen's Letzte Fahrt with the same Full Partner squad; default Kaltenbrunn)

const MAP: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const MAPS: Dictionary = {"map01": MAP, "map02": "res://gravelight/maps/map02_totenhafen/map02.tscn"}
static var _map_scene: String = MAP

static var _god: bool = false
static var _round: int = 1
static var _power: bool = false
static var _prev: Variant = null


func _ready() -> void:
	_god = GameState.god_mode
	_round = 1
	_power = false
	var bots: int = 3
	for a: String in OS.get_cmdline_user_args():
		if a == "--god":
			_god = true
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--character="):
			GameState.character_id = StringName(a.substr(12))
		elif a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
		elif a == "--power":
			_power = true
		elif a.begins_with("--map="):
			_map_scene = str(MAPS.get(a.substr(6), MAP))
	_prev = GLSettings.values.get("bot_ee_help", null)
	GLSettings.values["bot_ee_help"] = "full"   # the session only: never saved (restored when the match ends)
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "veteran"))
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file.call_deferred(_map_scene)


static func _on_match_started(_map_id: StringName) -> void:
	GameState.god_mode = _god
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var map: Node = tree.current_scene
	if map != null:
		map.tree_exiting.connect(_restore, CONNECT_ONE_SHOT)
	if _round > 1:
		RoundManager.debug_set_round.call_deferred(_round)
	for pid: int in GameState.player_ids:
		Economy.grant.call_deferred(pid, maxi(3000, DevLauncher.scrip_for_round(_round)))
	if _power and map != null:
		var sw: Node = map.get_node_or_null(^"Gameplay/Hauptschalter")
		if sw != null and sw.has_method("run_sequence"):
			sw.call_deferred("run_sequence", 1)
		elif not GameState.power_on:   # Totenhafen: no Hauptschalter sequence; the flag and the signal
			GameState.set_deferred("power_on", true)
			GLBus.power_activated.emit.call_deferred()
	var hud: Node = tree.get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", "Bot Easter-Egg Help: Full Partner (this session)", 3.0)


static func _restore() -> void:
	if _prev == null:
		GLSettings.values.erase("bot_ee_help")
	else:
		GLSettings.values["bot_ee_help"] = _prev
