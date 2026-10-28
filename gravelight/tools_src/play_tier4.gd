extends Node
## Dev launcher entry "Perk tier IV test (50,000 Scrip, power on)" (UPDATE 08 section 2, T-129): Map 0 at round 15
## (tier IV's min_round) with the power on, 50,000 Scrip and the mastery gate open for the session, so a tonic can be
## drunk and brewed I -> II -> III -> IV at its machine (the cellar's). Tier IV makes a tonic permanent: go down
## and it stays. Scene: res://gravelight/tools_src/play_tier4.tscn   Args (after --): --god  --bots=N (default 0)

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const ROUND: int = 15
const SCRIP: int = 50000

static var _god: bool = false


func _ready() -> void:
	_god = GameState.god_mode
	var bots: int = 0
	for a: String in OS.get_cmdline_user_args():
		if a == "--god":
			_god = true
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
	GameState.bot_count = BotConfig.clamp_bots(BotConfig.cfg(), bots)
	PerkManager.meta_gate_override = 0   # the session only: every tier unlocked
	Campaign.reset()
	if not GLBus.match_started.is_connected(_on_match_started):
		GLBus.match_started.connect(_on_match_started, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file.call_deferred(MAP)


static func _on_match_started(_map_id: StringName) -> void:
	GameState.god_mode = _god
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var map: Node = tree.current_scene
	if map != null:
		map.tree_exiting.connect(func() -> void: PerkManager.meta_gate_override = -1, CONNECT_ONE_SHOT)
	RoundManager.debug_set_round.call_deferred(ROUND)
	for pid: int in GameState.player_ids:
		Economy.grant.call_deferred(pid, SCRIP)
	GameState.set_deferred("power_on", true)
	GLBus.power_activated.emit.call_deferred()
	var hud: Node = tree.get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", "Tier IV test: 50,000 Scrip, power on, round 15. Brew a tonic to IV at its machine.", 4.0)
