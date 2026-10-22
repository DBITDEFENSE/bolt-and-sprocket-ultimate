extends Node
## Dev tool: a zombie pathing soak over the whole of Map 0 (Update 02 section 8, T-053: "no new navmesh snags").
## Every door is opened (so the cellar breach opens too) and every spawn is live; a god-mode player is moved every
## `--hold=` seconds (default 30) round SPOTS, which cover every room: the taproom, the stair vestibule, the hall and
## the three guest rooms, the stable and the hayloft, the yard, the Helvetia cellar and the Old Cellar. Zombies that
## get within 2 m of the player are counted (per spot and per window they came in by) and killed, so the rounds keep
## coming; a zombie that moves less than 1 m in 20 s outside the window states is reported as idle.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/soak_map00.tscn -- [--minutes=10] [--hold=30] [--start-round=8]
## (it jumps to --start-round first, so there are enough zombies on the map to test every spot; 0 = from round 1)
## Prints "[soak] ..." lines and a RESULT line (FAIL if anything idled or a spot got no zombie at all). Windows that
## delivered nobody are listed (spawn weighting follows the player's zone, so compare against a master run).

const SPOTS: Array = [
	["taproom, spawn", Vector3(15.0, 0, 8.0)], ["upstairs hall, east end", Vector3(21.5, 3.8, 8.0)],
	["stable, east aisle", Vector3(20.5, 0, 28.0)], ["taproom, by the hearth", Vector3(12.0, 0, 2.6)],
	["room 1 (the cousins')", Vector3(4.0, 3.8, 3.4)], ["yard, by the well", Vector3(13.0, 0, 42.0)],
	["helvetia cellar", Vector3(30.0, -3.2, 25.0)], ["taproom, NE corner", Vector3(21.5, 0, 2.5)],
	["old cellar vault", Vector3(13.5, -3.2, 8.0)], ["hayloft", Vector3(10.5, 3.5, 27.0)],
	["stair vestibule", Vector3(4.8, 0, 13.0)], ["room 3", Vector3(19.0, 3.8, 3.0)],
	["taproom, south benches", Vector3(12.0, 0, 13.8)], ["stable, west end", Vector3(8.5, 0, 25.0)],
	["yard passage", Vector3(20.0, 0, 19.0)], ["room 2", Vector3(11.5, 3.8, 4.0)],
	["yard, south-east", Vector3(28.0, 0, 44.5)], ["taproom, by the bar", Vector3(10.0, 0, 6.0)],
	["old cellar, wine cellar", Vector3(5.0, -3.2, 10.5)], ["upstairs hall, stair head", Vector3(4.6, 3.8, 8.0)],
]

var minutes: float = 10.0
var hold: float = 30.0
var start_round: int = 8
var map: Node3D
var player: Player
var director: ZombieDirector
var _t: float = 0.0
var _spot_i: int = -1
var _spot_t: float = 0.0
var _arrived: Dictionary = {}     # spot label -> count
var _arrive_times: Dictionary = {}   # spot label -> Array[float]
var _by_window: Dictionary = {}   # window id ("ground" for ground spawns) -> arrivals
var _born: Dictionary = {}        # zombie instance id -> spawn time
var _came_by: Dictionary = {}     # zombie instance id -> window id
var _track: Dictionary = {}       # zombie instance id -> [pos, t, flagged]
var _idle: PackedStringArray = []
var _windows: PackedStringArray = []
var _ready_done: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = float(a.substr(10))
		elif a.begins_with("--hold="):
			hold = float(a.substr(7))
		elif a.begins_with("--start-round="):
			start_round = int(a.substr(14))
	ProfileSave.path = "user://_soak_map00_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	_setup.call_deferred()


func _setup() -> void:
	for i: int in 30:
		await get_tree().physics_frame
	GameState.god_mode = true
	# the homage boss round (the Cousins, round 10) is a boss fight with few zombies: it would leave the spots it
	# lasts through with nobody to count, so the soak plays it as a normal round (the setting's Off behaviour)
	GLSettings.values["homage_bosses"] = false
	player = map.get_node("Player1") as Player
	director = map.get_node("ZombieDirector") as ZombieDirector
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null:
			d.open(1)
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		sp.enabled = true
		if sp.window() != null:
			_windows.append(String(sp.window().window_id))
	director.kill_all(false)
	if start_round > 1:
		RoundManager.debug_set_round(start_round)
	print("[soak] all doors open, %d spawns live (%d windows)" % [get_tree().get_nodes_in_group(&"zombie_spawns").size(), _windows.size()])
	_ready_done = true


func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	_t += delta
	_spot_t -= delta
	if _spot_t <= 0.0:
		_next_spot()
	player.global_position = SPOTS[_spot_i][1]
	player.velocity = Vector3.ZERO
	var label: String = str(SPOTS[_spot_i][0])
	for z: Zombie in director.active_zombies():
		var id: int = z.get_instance_id()
		if not _born.has(id):
			_born[id] = _t
			_came_by[id] = String(z.window.window_id) if z.window != null else "ground"
		var flat: float = Vector2(z.global_position.x - player.global_position.x, z.global_position.z - player.global_position.z).length()
		if flat < 2.0 and absf(z.global_position.y - player.global_position.y) < 1.5:
			_arrived[label] = int(_arrived.get(label, 0)) + 1
			(_arrive_times.get_or_add(label, []) as Array).append(_t - float(_born[id]))
			var w: String = str(_came_by.get(id, "?"))
			_by_window[w] = int(_by_window.get(w, 0)) + 1
			_born.erase(id)
			_came_by.erase(id)
			_track.erase(id)
			z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
			continue
		var tr: Array = _track.get(id, [])
		if tr.is_empty() or z.global_position.distance_to(tr[0]) > 1.0:
			_track[id] = [z.global_position, 0.0, false]
			continue
		tr[1] = float(tr[1]) + delta
		var waiting: bool = z.state in [Zombie.State.WAIT_WINDOW, Zombie.State.TEAR, Zombie.State.CLIMB]
		if float(tr[1]) > 20.0 and not bool(tr[2]) and not waiting:
			tr[2] = true
			_idle.append("t=%.0f %s idle at %s in %s (player at %s, came by %s)" % [_t, z.enemy_id, str(z.global_position.snapped(Vector3.ONE * 0.1)),
				Zombie.State.keys()[z.state], label, str(_came_by.get(id, "?"))])
			print("[soak] IDLE: ", _idle[_idle.size() - 1])
	if _t >= minutes * 60.0:
		_finish()


func _next_spot() -> void:
	_spot_i = (_spot_i + 1) % SPOTS.size()
	_spot_t = hold
	print("[soak] t=%.0f round %d: player to %s" % [_t, RoundManager.current_round, SPOTS[_spot_i][0]])


func _finish() -> void:
	set_physics_process(false)
	var fails: int = _idle.size()
	print("[soak] REPORT after %.1f min, reached round %d" % [_t / 60.0, RoundManager.current_round])
	for s: Array in SPOTS:
		var label: String = str(s[0])
		var times: Array = _arrive_times.get(label, [])
		var mean: float = 0.0
		for v: Variant in times:
			mean += float(v)
		mean = mean / float(maxi(1, times.size()))
		print("[soak]   %-28s zombies reached the player: %3d   (mean %.1f s from spawn)" % [label, int(_arrived.get(label, 0)), mean])
		if int(_arrived.get(label, 0)) == 0 and _t >= minutes * 60.0 - 1.0:
			fails += 1
	var silent: PackedStringArray = []
	for w: String in _windows:
		print("[soak]   window %-12s delivered %3d" % [w, int(_by_window.get(w, 0))])
		if int(_by_window.get(w, 0)) == 0:
			silent.append(w)
	print("[soak]   ground spawns delivered %d" % int(_by_window.get("ground", 0)))
	print("[soak] windows that delivered nobody: %s" % (", ".join(silent) if not silent.is_empty() else "none"))
	print("[soak] idle zombies: %d" % _idle.size())
	print("[soak] RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_soak_map00_profile.json"))
	get_tree().quit(0 if fails == 0 else 1)
