extends Node
## "Kaltenbrunn — Totenglocke test" (Update 02 section 3, T-048): a playable Kaltenbrunn (Map 1) match that
## starts at round 15 with god mode, every unpowered door open, Scrip for the round, and the Totenglocke in hand.
## Tap fire = quick toll, hold fire 1.5 s and release = Great Toll, alt-fire = Bell Dome. Dev console: `round 25`,
## `give totenglocke_up` for Mitternacht, `spawn 20` for a train.
##   godot --path . res://gravelight/tools_src/range_totenglocke.tscn [-- --round=25] [-- --up] [-- --bots=1]
## Bots default to the GRAVELIGHT "bots" setting (the dev launcher's choice).

const MAP: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"

static var _round: int = 15
static var _weapon: StringName = &"totenglocke"


func _ready() -> void:
	var bots: int = int(GLSettings.values.get("bots", 0))
	_round = 15
	_weapon = &"totenglocke"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--round="):
			_round = maxi(1, int(a.substr(8)))
		elif a == "--up":
			_weapon = &"totenglocke_up"
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	GameState.bot_skill = str(GLSettings.values.get("bot_skill", "regular"))
	GameState.bot_ai_mode = BotConfig.ai_mode_from_settings(GLSettings.values, GameState.bot_count)
	Campaign.reset()
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file.call_deferred(MAP)


static func _on_match_started(_map_id: StringName) -> void:
	GameState.god_mode = true
	RoundManager.debug_set_round.call_deferred(_round)
	for pid: int in GameState.player_ids:
		Economy.grant.call_deferred(pid, DevLauncher.scrip_for_round(_round))
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.create_timer(1.0).timeout.connect(func() -> void:
		for n: Node in tree.get_nodes_in_group(&"doors"):
			var d: BuyDoor = n as BuyDoor
			if d != null and not d.requires_power:
				d.open(0)
		for n: Node in tree.get_nodes_in_group(&"players"):
			var p: Player = n as Player
			if p != null and p.is_local and not p.is_bot:
				p.weapons.give_weapon(_weapon)
				var w: WeaponInstance = p.weapons.find_weapon(_weapon)
				if w != null:
					p.weapons.current_index = p.weapons.slots.find(w)
					p.weapons.call("_rebuild_gun")
				print("[tg-range] P%d holds %s at round %d (god mode)" % [p.player_id, _weapon, _round]))
