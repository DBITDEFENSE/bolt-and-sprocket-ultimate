extends Node
## Dev launcher entry "Ledger Lager test (Map 0, 20,000 Scrip, power on, round 10)" (UPDATE 09 section 3, T-141):
## Map 0 at round 10 with the power on and 20,000 Scrip, the mastery gate open for the session, so Ledger Lager can
## be drunk at the cellar's east row (the register, south-east corner) and brewed I -> II -> III -> IV (II needs round
## 8, III and IV round 15: use the dev console's `round 15`). The bank is the woodshed by the west road.
## Scene: res://gravelight/tools_src/play_ledger.tscn   Args (after --): --god  --bots=N (default 0)

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const ROUND: int = 10
const SCRIP: int = 20000

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
		Economy.grant_raw.call_deferred(pid, SCRIP)
	GameState.set_deferred("power_on", true)
	GLBus.power_activated.emit.call_deferred()
	var hud: Node = tree.get_first_node_in_group(&"hud")
	if hud != null and hud.has_method("show_banner"):
		hud.call("show_banner", "Ledger Lager test: 20,000 Scrip, power on, round 10. The register is in the cellar's east row; the bank is the woodshed.", 5.0)
