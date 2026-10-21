extends Node
## Windowed perf + screenshots on Map 2: power on, every door open, 24 zombies around the player in each area.
## Prints FPS per area and saves shots to user://shots/ (or --out=<dir>).
## Usage (silent, off-screen): godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/perf_map02.tscn

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _t: float = 0.0
var _phase: int = -1
var _samples: PackedFloat32Array = []
var _worst: float = 0.0
var _out: String = "user://shots"
const AREAS: Array = [
	["quay", Vector3(16, 0.2, 20), 180.0, 4.0],
	["penhall", Vector3(16, 0.2, 35), 180.0, 6.0],
	["crane_bay", Vector3(36, 0.2, 62), -60.0, 2.0],
	["uboat", Vector3(7, -1.8, 60), 0.0, 0.0],
	["lowerpens_flood", Vector3(36, -2.8, 54), 180.0, 4.0],
	["cannery", Vector3(-3, 0.2, 15), 90.0, 2.0],
]


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	_map = (load("res://gravelight/maps/map02_totenhafen/map02.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _p == null:
		_p = _map.get_node_or_null("Player1") as Player
		_dir = _map.get_node_or_null("ZombieDirector") as ZombieDirector
		if _p == null:
			return
		_p.set_process_unhandled_input(false)
		GameState.god_mode = true
		RoundManager.stop()
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			(n as BuyDoor).open(0)
		(_map.get_node("Gameplay/Pumpenschalter")).call("run_sequence", 1)
		RoundManager.debug_set_round(34)
		RoundManager.stop()
	_t += delta
	if _phase == -1 and _t > 10.0:
		_start_area(0)
	elif _phase >= 0:
		if _t > 3.0 and _t < 13.0:
			_samples.append(delta)
			_worst = maxf(_worst, delta)
		if _t >= 13.0:
			var total: float = 0.0
			for s: float in _samples:
				total += s
			print("[perf2] %-16s active=%d avg FPS=%.0f worst=%.1f ms" % [AREAS[_phase][0], _dir.active_zombies().size(),
				float(_samples.size()) / maxf(total, 0.001), _worst * 1000.0])
			get_viewport().get_texture().get_image().save_png(_out.path_join("map02_%s.png" % AREAS[_phase][0]))
			if _phase + 1 < AREAS.size():
				_start_area(_phase + 1)
			else:
				print("[perf2] GPU: ", RenderingServer.get_video_adapter_name())
				get_tree().quit()


func _start_area(i: int) -> void:
	_phase = i
	_t = 0.0
	_samples.clear()
	_worst = 0.0
	_dir.kill_all(true)
	var a: Array = AREAS[i]
	if str(a[0]) == "lowerpens_flood":
		(_map.get_node("Gameplay/Tide")).call("on_round", 33)
	_p.global_position = a[1]
	_p.rotation.y = deg_to_rad(float(a[2]))
	_p.set("_pitch", deg_to_rad(float(a[3])))
	await get_tree().create_timer(2.6).timeout
	get_viewport().get_texture().get_image().save_png(_out.path_join("map02_%s_empty.png" % a[0]))
	_dir.debug_spawn(24)
