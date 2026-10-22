extends Node
## Dev launcher entry "Map 0 — round 5 (Jakub)" (Update 02 section 6.2): starts the Crossroads Inn with Door 5 (the Old
## Cellar) already open and the round set so round 4 is next; round 5's breakout follows a round later. Late-round
## Scrip like the launcher's skip, optional god mode and bots, your survivor (Wren for the Wren scene).
## Scene: res://gravelight/tools_src/play_jakub.tscn   Args (after --): --god  --bots=N  --character=wren  --round=R
## (R = the first round to play, default 4; 5 starts on the breakout round itself).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

static var _round: int = 4
static var _god: bool = false


func _ready() -> void:
	_round = 4
	_god = false
	var bots: int = 0
	for a: String in OS.get_cmdline_user_args():
		if a == "--god":
			_god = true
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--character="):
			GameState.character_id = StringName(a.substr(12))
		elif a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "veteran"))
	GameState.bot_ai_mode = "off"
	Campaign.reset()
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file.call_deferred(MAP)


static func _on_match_started(_map_id: StringName) -> void:
	GameState.god_mode = _god
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if _round > 1:
		RoundManager.debug_set_round.call_deferred(_round)
	var scrip: int = DevLauncher.scrip_for_round(_round)
	for pid: int in GameState.player_ids:
		Economy.grant.call_deferred(pid, scrip)
	_open_cellar.call_deferred(tree)


static func _open_cellar(tree: SceneTree) -> void:
	for n: Node in tree.get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and d.door_id == &"door_old_cellar" and not d.is_open:
			d.open(1)
