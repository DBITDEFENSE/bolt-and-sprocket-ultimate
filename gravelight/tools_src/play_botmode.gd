extends Node
## Dev launcher entry "Bot mode" (T-071): starts a map with player bot mode switched on (PlayerBot.pending_on): the
## agent plays your survivor from the first round while you watch; press F6 (or move / shoot) to take over.
## Scene: res://gravelight/tools_src/play_botmode.tscn   Args (after --): --map=map00|map01  --bots=N  --round=R
##   --character=<id>  --god. Without args it keeps what the caller set (the dev launcher's fields: GameState.bot_count,
## GameState.character_id, GameState.god_mode).

const MAPS: Dictionary = {"map00": "res://gravelight/maps/map00_crossroads/map00.tscn", "map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"}

static var _round: int = 1
static var _god: bool = false


func _ready() -> void:
	_round = 1
	_god = GameState.god_mode
	var map_key: String = "map00"
	var bots: int = GameState.bot_count
	for a: String in OS.get_cmdline_user_args():
		if a == "--god":
			_god = true
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--map="):
			map_key = a.substr(6)
		elif a.begins_with("--character="):
			GameState.character_id = StringName(a.substr(12))
		elif a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "veteran"))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	Campaign.reset()
	PlayerBot.pending_on = true
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file.call_deferred(str(MAPS.get(map_key, MAPS["map00"])))


static func _on_match_started(_map_id: StringName) -> void:
	GameState.god_mode = _god
	if _round > 1:
		RoundManager.debug_set_round.call_deferred(_round)
		var scrip: int = DevLauncher.scrip_for_round(_round)
		for pid: int in GameState.player_ids:
			Economy.grant.call_deferred(pid, scrip)
