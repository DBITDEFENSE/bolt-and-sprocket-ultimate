extends Node
## UPDATE 10 s6 item 6 (T-162) headless smoke: no black screen over 2 s. Walks the campaign chain map00 -> map01 ->
## map02 -> map04a -> map04b -> map04c -> map04d the way Campaign.travel does (the exfil cutscene's
## Campaign.preload_next first, then LoadingScreen.go with the transition's lore line) and, per hop, times
##   card_ms  = from the scene change to the loading card being the current scene (what the player sees first),
##   total_ms = from the scene change to the new map's first frame (its player in the tree),
##   gap_ms   = the longest single frame in between (a frozen card; the hitch where the loaded scene is built).
## FAILS if a hop shows no card, the card takes over 500 ms, or any frame in the transition is over 2000 ms. The
## timings are real time of a headless run (no rendering, the machine may be loaded). The smoke node lives under the
## root so the scene swaps do not free it. One RESULT line plus the timing table.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_transitions.tscn
## [-- --only=map04c --max-gap=2000]

const CHAIN: Array[String] = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]
const CARD_MAX_MS: float = 500.0

var only: String = ""
var max_gap_ms: float = 2000.0
var rows: Array[String] = []
var fails: int = 0
var _last_ms: int = 0
var _gap: float = 0.0
var _watching: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--max-gap="):
			max_gap_ms = float(a.substr(10))
	var tree: SceneTree = get_tree()
	if get_parent() != tree.root:
		get_parent().remove_child.call_deferred(self)
		tree.root.add_child.call_deferred(self)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if not _watching:
		return
	var now: int = Time.get_ticks_msec()
	_gap = maxf(_gap, float(now - _last_ms))
	_last_ms = now


func _is_card() -> bool:
	return get_tree().current_scene is LoadingScreen


func _map() -> MapRoot:
	var m: MapRoot = get_tree().current_scene as MapRoot
	return m if m != null and m.player != null and m.player.is_inside_tree() else null


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	ProfileSave.path = "user://_qa_transitions_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_transitions_settings.cfg"
	GLSettings.values["bot_local_ai"] = false
	GLSettings.values["homage_bosses"] = false
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.character_id = &"peg"
	GameState.god_mode = true
	var tree: SceneTree = get_tree()
	var prev: String = ""
	var hops: int = 0
	for id: String in CHAIN:
		if only != "" and not id.begins_with(only):
			prev = id
			continue
		var scene: String = Campaign.scene_for(StringName(id))
		if not ResourceLoader.exists(scene):
			rows.append("%-18s no scene" % id)
			fails += 1
			prev = id
			continue
		# the exfil cutscene starts the load (every hop but the first); a few seconds of it pass
		var preload_ok: bool = true
		if prev != "":
			preload_ok = Campaign.preload_next(StringName(id))
			await tree.create_timer(2.0).timeout
		Campaign.begin_at(StringName(id), 1, {})
		Campaign.preloading = Campaign.preloading   # (kept: LoadingScreen reuses it)
		var t0: int = Time.get_ticks_msec()
		_last_ms = t0
		_gap = 0.0
		_watching = true
		LoadingScreen.go(tree, scene, id, LoadingScreen.transition_line(prev, id))
		var card_ms: float = -1.0
		var total_ms: float = -1.0
		var guard: int = 0
		while total_ms < 0.0 and guard < 60000:
			await tree.process_frame
			guard += 1
			if card_ms < 0.0 and _is_card():
				card_ms = float(Time.get_ticks_msec() - t0)
			if _map() != null:
				total_ms = float(Time.get_ticks_msec() - t0)
			elif float(Time.get_ticks_msec() - t0) > 120000.0:
				break
		for i: int in 5:
			await tree.process_frame
		_watching = false
		var ok: bool = card_ms >= 0.0 and card_ms <= CARD_MAX_MS and total_ms >= 0.0 and _gap <= max_gap_ms
		if not ok:
			fails += 1
		hops += 1
		rows.append("%-18s %-4s card %6.0f ms  total %6.0f ms  longest frame %6.0f ms  preload %s" % [id, "ok" if ok else "FAIL", card_ms, total_ms, _gap, "yes" if prev != "" and preload_ok else ("-" if prev == "" else "NO")])
		prev = id
	for r: String in rows:
		print("[transitions] %s" % r)
	var pass_all: bool = fails == 0 and hops > 0
	print("[transitions] RESULT: %s (%d hops, %d failed; card <= %.0f ms, no frame over %.0f ms)" % ["PASS" if pass_all else "FAIL", hops, fails, CARD_MAX_MS, max_gap_ms])
	Campaign.reset()
	tree.quit(0 if pass_all else 1)
