extends Node
## T-280: what an explosion costs the frame it goes off in, headless. Map 0 at round 15, the player alone (god mode,
## no bots, no Jakub: less noise), 24 zombies spawned and set down in a 5 x 5 block 8 m in front of the player.
## Then, in turn: one blast at the pack's middle, a pause, six blasts in the same frame around the pack's middle, a
## pause; `--reps=N` times (3 by default). Run it with the engine flag `--fixed-fps 60` before the `--` (as
## tools/bot_perf.sh does): every frame is one physics tick + one process step with no sleep, so a frame's wall time
## is the CPU work of one 60 FPS frame without the renderer.
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://gravelight/tools_src/bench_explosions.tscn -- [--mode=fx|detonate|kill] [--reps=N]
## Modes: `fx` (the default) calls Effects.explosion(pos, radius) only: the presentation, what T-280 changed.
## `detonate` calls Explosion.detonate with the frag's numbers on zombies nobody can kill (the line-of-sight rays,
## the damage reactions, the effects and the bus). `kill` the same with zombies that die of it (ragdolls, gore,
## drops: the T-265 "explosions in a pack" hitch; most of that is the deaths, not the blast).
## Prints one `[blast]` line per event: the wall time of the frame the blast went off in, the worst of the next 30
## frames, the time inside the calls themselves, and the median frame before it. Ends with a `[blast-summary]` line.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const FRAG: Dictionary = {"damage": 300.0, "edge_mult": 0.2, "radius": 6.0, "stagger_radius": 8.0,
	"self_damage_near": 0.0, "self_near_m": 0.0, "self_damage_far": 0.0, "sound": "grenade_explode", "sound_db": 4.0}

var _map: MapRoot
var _t: float = 0.0
var _phase: int = 0
var _mode: String = "fx"
var _reps: int = 3
var _prev_us: int = 0
var _frames: PackedInt32Array = []   # wall microseconds of every frame since the pack formed
var _events: Array = []              # [{name, frame, call_us}]
var _next_t: float = 0.0
var _step: int = 0
var _done: bool = false
var _packed: bool = false


func _ready() -> void:
	process_priority = -1000
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--reps="):
			_reps = maxi(1, int(a.substr(7)))
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	seed(280)
	ProfileSave.path = "user://_bench_explosions_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_bench_explosions_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	print("[bench] mode %s, reps %d, vfx_quality %s" % [_mode, _reps, str(GLSettings.values.get("vfx_quality", "high"))])
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _prev_us > 0 and _phase >= 3:
		_frames.append(now - _prev_us)
	_prev_us = now
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _map == null or not _map.is_inside_tree() or _map.player == null or _done:
		return
	_t += delta
	match _phase:
		0:
			if _t > 3.0:
				_phase = 1
				RoundManager.debug_set_round(15)
				RoundManager.stop()
				(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn(24)
		1:
			_keep_alive()
			if _t > 6.0 and not _packed:   # stood in a pack 8 m in front of the player (they then walk in on him)
				_packed = true
				_pack()
			if _t > 9.0:
				_phase = 3
				_next_t = _t + 2.0
				print("[bench] pack formed: %d zombies, spread %.1f m" % [_map.director.active_zombies().size(), _spread()])
		3:
			_keep_alive()
			if _t >= _next_t:
				_fire()
				_step += 1
				_next_t = _t + 3.0
				if _step >= _reps * 2:
					_phase = 4
					_next_t = _t + 2.0
		4:
			_keep_alive()
			if _t >= _next_t:
				_report()
				_done = true
				get_tree().quit()


func _keep_alive() -> void:
	if _mode == "kill":
		return
	for z: Zombie in _map.director.active_zombies():
		z.hp = maxf(z.hp, 1.0e9)


func _pack() -> void:
	var p: Player = _map.player
	var fwd: Vector3 = -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	var c: Vector3 = p.global_position + fwd * 8.0
	var i: int = 0
	for z: Zombie in _map.director.active_zombies():
		var off: Vector3 = Vector3((i % 5) - 2.0, 0.0, (i / 5) - 2.0) * 1.2
		z.global_position = c + off + Vector3.UP * 0.1
		z.velocity = Vector3.ZERO
		i += 1


func _centre() -> Vector3:
	var zs: Array = _map.director.active_zombies()
	if zs.is_empty():
		return _map.player.global_position + Vector3(0, 0.3, -6)
	var c: Vector3 = Vector3.ZERO
	for z: Zombie in zs:
		c += z.global_position
	return c / float(zs.size()) + Vector3(0, 0.3, 0)


func _spread() -> float:
	var c: Vector3 = _centre()
	var m: float = 0.0
	for z: Zombie in _map.director.active_zombies():
		m = maxf(m, z.global_position.distance_to(c))
	return m


func _fire() -> void:
	var six: bool = _step % 2 == 1
	if _mode == "kill":   # a fresh pack for every event (the last one died)
		for z: Zombie in _map.director.active_zombies():
			z.hp = minf(z.hp, 60.0)
	var c: Vector3 = _centre()
	var n: int = 6 if six else 1
	var t0: int = Time.get_ticks_usec()
	for i: int in n:
		var at: Vector3 = c + (Vector3(cos(i * 1.047), 0, sin(i * 1.047)) * 2.0 if six else Vector3.ZERO)
		if _mode == "fx":
			Effects.explosion(at, 6.0)
		else:
			Explosion.detonate(_map.player, at, FRAG, _map.player.player_id, &"frag")
	var us: int = Time.get_ticks_usec() - t0
	_events.append({"name": "6 blasts" if six else "1 blast", "frame": _frames.size(), "call_us": us,
		"alive": _map.director.active_zombies().size()})
	if _mode == "kill":
		(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn.call_deferred(24 - _map.director.active_zombies().size())


func _report() -> void:
	var worst_one: float = 0.0
	var worst_six: float = 0.0
	for e: Dictionary in _events:
		var f: int = int(e["frame"])   # _frames[f] is the frame the blast was called in (its wall time is logged next frame)
		var blast_ms: float = (_frames[f] / 1000.0) if f < _frames.size() else -1.0
		var after: float = 0.0
		for j: int in range(f + 1, mini(f + 31, _frames.size())):
			after = maxf(after, _frames[j] / 1000.0)
		var before: PackedInt32Array = _frames.slice(maxi(0, f - 60), f)
		before.sort()
		var med: float = (before[before.size() / 2] / 1000.0) if not before.is_empty() else 0.0
		print("[blast] %s %s: frame %.2f ms, worst of the next 30 %.2f ms, in the calls %.2f ms, median before %.2f ms, zombies %d" % [
			_mode, e["name"], blast_ms, after, int(e["call_us"]) / 1000.0, med, int(e["alive"])])
		if str(e["name"]) == "1 blast":
			worst_one = maxf(worst_one, maxf(blast_ms, after))
		else:
			worst_six = maxf(worst_six, maxf(blast_ms, after))
	var all: PackedInt32Array = _frames.duplicate()
	all.sort()
	print("[blast-summary] mode %s: worst frame with 1 blast %.2f ms, with 6 blasts %.2f ms; all frames p50 %.2f / p99 %.2f / max %.2f ms (%d frames)" % [
		_mode, worst_one, worst_six, all[all.size() / 2] / 1000.0, all[int(all.size() * 0.99)] / 1000.0, all[all.size() - 1] / 1000.0, all.size()])
