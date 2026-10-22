extends Node
## Dev tool: a zombie pathing soak in Map 0's Old Cellar (Update 02 section 6.1, T-051). Doors 3 and 5 open (so
## the breach is open too), every spawn but the Old Cellar's two light-well windows switched off, a god-mode player
## moved every `--hold=` seconds (default 40) round the new rooms. Zombies that get within 2 m of the player are
## counted and killed (so the rounds keep coming); a zombie that moves less than 1 m in 20 s outside the window
## states is reported as idle. Halfway through, the ice cellar's seal is opened and the player stands inside it.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/soak_old_cellar.tscn -- [--minutes=10] [--hold=40]
## Prints "[soak] ..." lines and a RESULT line (FAIL if anything idled or a spot got no zombie at all).

const SPOTS: Array = [
	["wine cellar, north aisle", Vector3(5.0, -3.2, 10.5)], ["vault, west of the stack", Vector3(13.5, -3.2, 8.0)],
	["coal room, by the cage", Vector3(3.6, -3.2, 6.3)], ["vault, north of the stack", Vector3(17.45, -3.2, 4.7)],
	["root cellar", Vector3(7.5, -3.2, 2.5)], ["vault, east of the stack", Vector3(21.3, -3.2, 8.0)],
	["wine cellar, by the casks", Vector3(9.0, -3.2, 16.6)], ["vault, south of the stack", Vector3(17.45, -3.2, 11.4)],
	["the stair foot", Vector3(-1.5, -3.2, 17.0)], ["the breach tunnel", Vector3(22.4, -3.2, 18.5)],
	["the ice cellar (seal open)", Vector3(6.6, -3.2, 6.6)], ["vault, under the window", Vector3(22.0, -3.2, 1.6)],
	["root cellar, east bay", Vector3(9.6, -3.2, 6.3)], ["vault, by the ammo box", Vector3(14.6, -3.2, 13.8)],
	["wine cellar, west end", Vector3(1.8, -3.2, 12.0)],
]
const OPEN_DOORS: Array = [&"door_old_cellar", &"door_cellar"]

var minutes: float = 10.0
var hold: float = 40.0
var map: Node3D
var player: Player
var director: ZombieDirector
var _t: float = 0.0
var _spot_i: int = -1
var _spot_t: float = 0.0
var _arrived: Dictionary = {}     # spot label -> count
var _arrive_times: Dictionary = {}   # spot label -> Array[float]
var _born: Dictionary = {}        # zombie instance id -> spawn time
var _track: Dictionary = {}       # zombie instance id -> [pos, t, flagged]
var _idle: PackedStringArray = []
var _ready_done: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			minutes = float(a.substr(10))
		elif a.begins_with("--hold="):
			hold = float(a.substr(7))
	ProfileSave.path = "user://_soak_old_cellar_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	_setup.call_deferred()


func _setup() -> void:
	for i: int in 30:
		await get_tree().physics_frame
	GameState.god_mode = true
	player = map.get_node("Player1") as Player
	director = map.get_node("ZombieDirector") as ZombieDirector
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and d.door_id in OPEN_DOORS:
			d.open(1)
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		sp.enabled = String(sp.name).begins_with("Spawn_W_CEL_")
	director.kill_all(false)
	var br: Node = map.find_child("CellarBreach", true, false)
	print("[soak] doors open, %d light-well spawns on, breach open: %s" % [2, str(br.get("is_open")) if br != null else "?"])
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
		var flat: float = Vector2(z.global_position.x - player.global_position.x, z.global_position.z - player.global_position.z).length()
		if flat < 2.0 and absf(z.global_position.y - player.global_position.y) < 1.5:
			_arrived[label] = int(_arrived.get(label, 0)) + 1
			(_arrive_times.get_or_add(label, []) as Array).append(_t - float(_born[id]))
			_born.erase(id)
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
			_idle.append("t=%.0f %s idle at %s in %s (player at %s)" % [_t, z.enemy_id, str(z.global_position.snapped(Vector3.ONE * 0.1)),
				Zombie.State.keys()[z.state], label])
			print("[soak] IDLE: ", _idle[_idle.size() - 1])
	if _t >= minutes * 60.0:
		_finish()


func _next_spot() -> void:
	_spot_i = (_spot_i + 1) % SPOTS.size()
	_spot_t = hold
	if str(SPOTS[_spot_i][0]).begins_with("the ice cellar"):
		var seal: Node = map.find_child("IceCellarSeal", true, false)
		if seal != null:
			seal.call("open")
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
		print("[soak]   %-30s zombies reached the player: %3d   (mean %.1f s from spawn)" % [label, int(_arrived.get(label, 0)), mean])
		if int(_arrived.get(label, 0)) == 0 and _t >= minutes * 60.0 - 1.0:
			fails += 1
	print("[soak] idle zombies: %d" % _idle.size())
	print("[soak] RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_soak_old_cellar_profile.json"))
	get_tree().quit(0 if fails == 0 else 1)
