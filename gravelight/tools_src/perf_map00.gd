extends Node
## Performance check: 24 active zombies chasing a god-mode player in the taproom. Reports FPS.
## Usage: godot --path . res://gravelight/tools_src/perf_map00.tscn   (opens a window; the mouse is NOT captured)
## Add `-- --fire` to hold the trigger on an MG42 aimed at the floor for the whole measurement (casings,
## impact dust, muzzle smoke, flash light) to price the gun effects.
## `-- --novsync` measures uncapped (vsync off); `-- --look=east` turns the player to face the east window (the
## wreck, the landscape and the distant war on screen; Update 02 section 7) and `--look=north` the north windows.
## `--no-landscape` strips the Landscape and MapAmbience nodes first (the A/B for section 7's cost).

var _map: Node3D
var _t: float = 0.0
var _samples: PackedFloat32Array = []
var _spawned: bool = false
var _fire: bool = "--fire" in OS.get_cmdline_user_args()
var _look: String = ""


func _ready() -> void:
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	if "--no-landscape" in OS.get_cmdline_user_args():
		for n: String in ["Landscape", "MapAmbience"]:
			var c: Node = _map.get_node_or_null(n)
			if c != null:
				_map.remove_child(c)
				c.free()
	get_tree().root.add_child.call_deferred(_map)
	GameState.god_mode = true
	for a: String in OS.get_cmdline_user_args():
		if a == "--novsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		elif a.begins_with("--look="):
			_look = a.substr(7)


func _process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Player = _map.get_node_or_null("Player1") as Player
	if p != null:
		p.set_process_unhandled_input(false)
		if _look == "east":
			p.rotation.y = -PI * 0.5
			p.set("_pitch", 0.12)
		elif _look == "north":
			p.rotation.y = 0.0
			p.set("_pitch", 0.15)
	_t += delta
	if delta > 0.025 and _t > 0.5:
		print("[perf] HITCH %.1f ms at t=%.2f" % [delta * 1000.0, _t])
	if _t > 2.0 and not _spawned:
		_spawned = true
		RoundManager.stop()
		(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn(24)
		print("[perf] spawned 24")
		if _fire and p != null:
			p.weapons.give_weapon(&"mg42")
			print("[perf] firing an MG42 at the floor throughout")
	if _fire and _spawned and p != null and p.weapons.current() != null:
		p.set("_pitch", -1.1)
		p.weapons.current().mag = maxi(p.weapons.current().mag, 40)
		p.weapons.current().heat = 0.0
		Input.action_press(&"fire")
		for z: Zombie in (_map.get_node("ZombieDirector") as ZombieDirector).active_zombies():
			z.hp = 1.0e9      # same 24 zombies as the baseline: only the gun effects differ
	if _spawned and int(_t * 2.0) != int((_t - delta) * 2.0):
		var dd: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
		var hist: Dictionary = {}
		for z: Zombie in dd.active_zombies():
			var k: String = str(Zombie.State.keys()[z.state])
			hist[k] = int(hist.get(k, 0)) + 1
		print("[perf] t=%.1f active=%d %s" % [_t, dd.active_zombies().size(), hist])
	if _t > 12.0 and _t < 27.0:
		_samples.append(delta)
	if _t >= 27.0:
		var total: float = 0.0
		var worst: float = 0.0
		for s: float in _samples:
			total += s
			worst = maxf(worst, s)
		var d: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
		print("[perf] active=%d  avg FPS=%.1f  worst frame=%.1f ms  frames=%d" % [d.active_zombies().size(), float(_samples.size()) / total, worst * 1000.0, _samples.size()])
		print("[perf] GPU: ", RenderingServer.get_video_adapter_name())
		get_tree().quit()
