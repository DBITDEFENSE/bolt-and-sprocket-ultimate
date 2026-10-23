extends Node
## Performance check for Update 04 section 3 (DECISIONS T-069): Map 0 at round 15 with the minimap on, 3 bots +
## Jakub, 24 zombies (kept alive, so the squad fires the whole time), and marks in play (3 personal marks, a Danger
## mark, a Defend order and a Buy order: the in-world chalk X markers, the minimap pins, the bots' order work).
## Then the pause map opened (solo: the world frozen) to price the MAP tab itself.
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/perf_marks.tscn
## `-- --no-marks` runs the same without any mark (the A/B). Vsync is off; it prints average FPS, the worst frame, the 1% low, the minimap's cost and the brains' cost.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: MapRoot
var _t: float = 0.0
var _samples: PackedFloat32Array = []
var _map_samples: PackedFloat32Array = []
var _phase: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	ProfileSave.path = "user://_perf_marks_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_perf_marks_settings.cfg"
	GLSettings.values["classic_hud"] = false
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _map == null or not _map.is_inside_tree() or _map.player == null:
		return
	_t += delta
	match _phase:
		0:
			if _t > 3.0 and _map.squad != null:
				_phase = 1
				RoundManager.debug_set_round(15)
				GLConsole.call("run", "jakub join")
		1:
			if _t > 5.0:
				_phase = 2
				RoundManager.stop()
				(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn(24)
				if not ("--no-marks" in OS.get_cmdline_user_args()):
					_place_marks()
				print("[perf] round %d, bots %d, jakub %s, marks %d" % [RoundManager.current_round, GameState.bot_ids.size(),
					str(JakubCompanion.instance(get_tree()) != null), MapMarks.current().marks().size()])
		2:
			for z: Zombie in _map.director.active_zombies():
				z.hp = maxf(z.hp, 1.0e9)
			if _t > 9.0 and _t < 24.0:
				_samples.append(delta)
			if _t >= 24.0:
				_report("in play", _samples)
				_phase = 3
				_map.pause_menu.toggle()
		3:
			if _t > 26.0 and _t < 34.0:
				_map_samples.append(delta)
			if _t >= 34.0:
				_report("pause map open", _map_samples)
				var mm: Minimap = _map.find_child("Minimap", true, false) as Minimap
				if mm != null:
					print("[perf] minimap %.0f us per frame" % mm.perf_usec())
				var ts: Dictionary = _map.squad.think_stats()
				print("[perf] brains %.3f ms per bot per frame (%d brains incl. Jakub)" % [float(ts["ms_per_bot_frame"]), _map.squad.brains.size()])
				print("[perf] active zombies %d   GPU: %s" % [_map.director.active_zombies().size(), RenderingServer.get_video_adapter_name()])
				get_tree().paused = false
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
				get_tree().quit()


func _place_marks() -> void:
	var mm: MapMarks = MapMarks.current()
	var me: Player = _map.player
	var b0: BotBrain = _map.squad.brains[0]
	for i: int in 3:
		mm.place({"kind": "go", "pos": b0.snap(me.global_position + Vector3(2.0 + i * 2.5, 0, 1.5)), "target": "me"})
	mm.place({"kind": "danger", "pos": b0.snap(me.global_position + Vector3(-3, 0, 3))})
	mm.place({"kind": "defend", "pos": b0.snap(me.global_position + Vector3(-2, 0, -2)), "target": int(GameState.bot_ids[0])})
	var wb: Node3D = _map.get_node_or_null(^"Gameplay/WallBuy_kar98k") as Node3D
	if wb != null:
		mm.place({"kind": "buy", "pos": wb.global_position, "node": wb, "target": int(GameState.bot_ids[1])})


func _report(what: String, s: PackedFloat32Array) -> void:
	if s.is_empty():
		return
	var total: float = 0.0
	var worst: float = 0.0
	var sorted: Array = Array(s)
	sorted.sort()
	for x: float in s:
		total += x
		worst = maxf(worst, x)
	var low_n: int = maxi(1, int(s.size() * 0.01))
	var low: float = 0.0
	for i: int in low_n:
		low += float(sorted[sorted.size() - 1 - i])
	low /= float(low_n)
	print("[perf] %s: avg FPS %.1f, worst frame %.1f ms, 1%% low %.1f FPS, frames %d" % [what, float(s.size()) / total, worst * 1000.0, 1.0 / low, s.size()])
