extends Node
## Headless smoke for Werk Thalbach's wind tunnel (UPDATE 10 Act I, contract C6 `wind_tunnel`, DECISIONS T-155):
## the trap, the shortcut and the toy. With the power on the lever runs the fan for 20 s: a zombie in the test
## section is blown down the tunnel into the outlet screen and shredded (the trap); a player is pushed at about
## 3 m/s and never hurt (the toy); the plenum hatch between the Windkanal and Montage 2 opens (the plug's collider
## off, Link_TunnelHatch on: a short path F <-> E) and shuts again when the fan stops (the shortcut).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_wind_tunnel.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const E_SIDE: Vector3 = Vector3(-2.5, 0, 102.5)
const F_SIDE: Vector3 = Vector3(2.5, 0, 102.5)

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _hits: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_tunnel.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.player_damaged.connect(func(_pid: int, a: float) -> void:
		if a > 0.0:
			_hits += 1)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _check(cond: bool, what: String) -> void:
	print("[tunnel] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _path_len(from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_map.get_world_3d().navigation_map, from, to, true, 0xFF)
	if path.is_empty() or path[path.size() - 1].distance_to(to) > 1.5:
		return INF
	var l: float = 0.0
	for i: int in range(1, path.size()):
		l += path[i - 1].distance_to(path[i])
	return l


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	_dir.kill_all(true)
	var tunnel: WindTunnel = _map.get_node_or_null("Gameplay/WindTunnel") as WindTunnel
	var hatch: TunnelHatch = _map.get_node_or_null("Gameplay/TunnelHatch") as TunnelHatch
	var link: NavigationLink3D = _map.get_node_or_null("Navigation/Link_TunnelHatch") as NavigationLink3D
	var plug: CollisionObject3D = _map.find_child("TunnelHatchPlug", true, false) as CollisionObject3D
	_check(tunnel != null and hatch != null and link != null and plug != null, "WindTunnel, TunnelHatch, its link and plug are placed")
	if tunnel == null or hatch == null or link == null or plug == null:
		_finish()
		return
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		(n as BuyDoor).open(1)
	(_map.get_node("Gameplay/Hauptschalter")).call("run_sequence", 1)
	var w: int = 0
	while not GameState.power_on and w < 600:
		await _frames(1)
		w += 1
	await _frames(60)
	_dir.kill_all(true)
	_check(not hatch.is_open and plug.collision_layer == 1 and not link.enabled, "the hatch is shut (plug on, link off)")
	var long_way: float = _path_len(E_SIDE, F_SIDE)
	_check(long_way > 30.0, "Montage 2 -> Windkanal the long way round (%.0f m)" % long_way)
	_check(tunnel.can_interact(_p), "with the power the fan can run")
	tunnel.interact(_p)
	await _frames(4)
	_check(GameState.has_flag(&"tunnel_running") and tunnel.running > 19.0, "the fan runs (tunnel_running)")
	_check(hatch.is_open and plug.collision_layer == 0 and link.enabled and GameState.has_flag(&"tunnel_hatch_open"), "the draft opens the plenum hatch")
	await _frames(6)
	var short_way: float = _path_len(E_SIDE, F_SIDE)
	_check(short_way < 8.0, "Montage 2 -> Windkanal through the hatch (%.1f m)" % short_way)
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(-1.5, 1.0, 102.5), Vector3(1.5, 1.0, 102.5), 1 | (1 << 8))
	_check(space.intersect_ray(q).is_empty(), "a body can walk through the hatch")
	# the toy: the player drifts down the tunnel at about 3 m/s and is not hurt
	_p.global_position = Vector3(12.0, 0.2, 115.0)
	_p.velocity = Vector3.ZERO
	await _frames(3)
	var x0: float = _p.global_position.x
	await get_tree().create_timer(1.0).timeout
	var v: float = _p.global_position.x - x0
	_check(v > 1.6 and v < 4.6, "the wind pushes a player at about 3 m/s (%.2f m in 1 s)" % v)
	# the trap: a zombie in the test section is blown into the outlet screen and shredded
	_dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	var z: Zombie = zs[zs.size() - 1]
	z.global_position = Vector3(18.0, 0.1, 115.0)
	z.velocity = Vector3.ZERO
	if z.window != null:
		z.window.release(z)
		z.window = null
	z.state = Zombie.State.CHASE   # (a fresh spawn is still on its way in, and those ignore pushes)
	_p.global_position = Vector3(4.6, 0.2, 124.0)   # out of the way, at the fan control
	var t0: int = Time.get_ticks_msec()
	var fr: int = 0
	while z.is_active() and Time.get_ticks_msec() - t0 < 9000:
		await _frames(1)
		fr += 1
		if fr % 30 == 0:
			print("[tunnel]   zombie %s state %d pushed %s physics %s" % [str(z.global_position), z.state, z.is_pushed(), z.is_physics_processing()])
	var secs: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_check(not z.is_active() and tunnel.shredded >= 1, "a zombie is blown into the screen and shredded (%.1f s, %d)" % [secs, tunnel.shredded])
	_check(secs < WindTunnel.seconds_to_screen(18.0, tunnel.lo, tunnel.hi, tunnel.screen_depth, tunnel.push_mps) * 2.5 + 1.0, "it took about the push maths' time")
	_check(_hits == 0, "nobody living got hurt (%d)" % _hits)
	# the fan stops: the hatch shuts
	tunnel.running = 0.05
	await _frames(6)
	_check(not GameState.has_flag(&"tunnel_running") and tunnel.cooldown > 25.0, "the fan stops and spins down")
	_check(not hatch.is_open and plug.collision_layer == 1 and not link.enabled and not GameState.has_flag(&"tunnel_hatch_open"), "the hatch shuts again")
	_finish()


func _finish() -> void:
	if _fails.is_empty():
		print("[tunnel] RESULT: PASS")
		get_tree().quit(0)
	else:
		print("[tunnel] RESULT: FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)])
		get_tree().quit(1)
