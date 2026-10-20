extends Node
## Windowed perf + screenshots on Map 1: power on, every door open, 24 zombies around the player in the
## Salt Chapel and then the Generator Hall. Prints FPS per area and saves shots to user://shots/.
## Usage: godot --path . res://gravelight/tools_src/perf_map01.tscn   (the mouse is NOT captured)

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _t: float = 0.0
var _phase: int = -1
var _samples: PackedFloat32Array = []
var _worst: float = 0.0
const AREAS: Array = [
	["chapel", Vector3(12, -11.8, 88.5), 0.0, 8.0],
	["generator", Vector3(42, -11.8, 80), -60.0, 2.0],
	["yard", Vector3(20, 0.2, 31), 0.0, 12.0],
	["lab", Vector3(53, -11.8, 90), -90.0, 0.0],
	["core", Vector3(34, -17.8, 104), 180.0, 10.0],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	_map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
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
		(_map.get_node("Gameplay/Hauptschalter")).call("run_sequence", 1)
		RoundManager.debug_set_round(14)
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
			print("[perf1] %-10s active=%d avg FPS=%.0f worst=%.1f ms" % [AREAS[_phase][0], _dir.active_zombies().size(),
				float(_samples.size()) / maxf(total, 0.001), _worst * 1000.0])
			get_viewport().get_texture().get_image().save_png("user://shots/map01_%s.png" % AREAS[_phase][0])
			if _phase + 1 < AREAS.size():
				_start_area(_phase + 1)
			else:
				print("[perf1] GPU: ", RenderingServer.get_video_adapter_name())
				get_tree().quit()


func _start_area(i: int) -> void:
	_phase = i
	_t = 0.0
	_samples.clear()
	_worst = 0.0
	_dir.kill_all(true)
	var a: Array = AREAS[i]
	_p.global_position = a[1]
	_p.rotation.y = deg_to_rad(float(a[2]))
	_p.set("_pitch", deg_to_rad(float(a[3])))
	await get_tree().create_timer(2.6).timeout
	get_viewport().get_texture().get_image().save_png("user://shots/map01_%s_empty.png" % a[0])
	_dir.debug_spawn(24)
