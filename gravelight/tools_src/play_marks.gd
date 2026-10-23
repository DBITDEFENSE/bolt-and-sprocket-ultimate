extends Node
## Dev launcher entry "Map 0 — Pause map & marks test" (Update 04 section 3, DECISIONS T-069): the Crossroads Inn
## with 3 bots, the cellar open and the power on, Scrip for everyone (you 6,000, each bot 3,000), and a few marks
## already placed: a Go here of yours in the taproom, a Danger mark by the stable door, Peg ordered to buy Marathon
## Malt (she can afford it) and Deacon ordered to buy Packmule Porter (he is short: watch him say so and wait). The
## pause page opens on the MAP tab a moment after the match starts.
## Scene: res://gravelight/tools_src/play_marks.tscn   Args (after --): --bots=N (default 3)  --god  --character=wren
## --no-open (don't open the map)  --no-marks (no pre-placed marks).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

static var _god: bool = false
static var _open: bool = true
static var _marks: bool = true


func _ready() -> void:
	_god = GameState.god_mode
	_open = true
	_marks = true
	var bots: int = 3
	for a: String in OS.get_cmdline_user_args():
		if a == "--god":
			_god = true
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--character="):
			GameState.character_id = StringName(a.substr(12))
		elif a == "--no-open":
			_open = false
		elif a == "--no-marks":
			_marks = false
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
	tree.create_timer(1.2).timeout.connect(func() -> void: _setup(tree))


static func _setup(tree: SceneTree) -> void:
	var map: MapRoot = tree.current_scene as MapRoot
	if map == null:
		return
	for n: Node in tree.get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and d.door_id == &"door_cellar" and not d.is_open:
			d.open(1)
	if not GameState.power_on:
		var sw: Node = map.get_node_or_null(^"Gameplay/Kellerschalter")
		if sw != null and sw.has_method("run_sequence"):
			sw.call("run_sequence", 1)
		else:
			GameState.power_on = true
			GLBus.power_activated.emit()
	for pid: int in GameState.player_ids:
		Economy.grant(pid, 6000 if GameState.human_ids().has(pid) else 3000)
	var mm: MapMarks = MapMarks.current()
	if mm != null and _marks:
		var me: Player = map.player
		mm.place({"kind": "go", "pos": me.global_position + Vector3(2.5, 0, 1.5), "target": "me", "label": "Taproom"})
		var stable: Node3D = map.get_node_or_null(^"Gameplay/Door_Stable") as Node3D
		if stable != null:
			mm.place({"kind": "danger", "pos": stable.global_position + Vector3(0, 0, -1.5), "label": "Stable door"})
		var ids: Array = GameState.bot_ids
		var mal: Node3D = map.get_node_or_null(^"Gameplay/Perk_marathon_malt") as Node3D
		if mal != null and ids.size() >= 1:
			mm.place({"kind": "buy", "pos": mal.global_position, "node": mal, "target": int(ids[0])})
		var pack: Node3D = map.get_node_or_null(^"Gameplay/Perk_packmule_porter") as Node3D
		if pack != null and ids.size() >= 2:
			mm.place({"kind": "buy", "pos": pack.global_position, "node": pack, "target": int(ids[1])})
	if _open and map.pause_menu != null:
		tree.create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(map) and not map.pause_menu.visible:
				map.pause_menu.toggle())
