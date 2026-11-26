extends Node
## T-283 item 7 (docs/perf/t281_zombie_count_2026-11.md, "Phase 2"): the frame a grenade kills a pack. A copy of T-280's
## bench_explosions.gd (branch claude/explosions; copied, not shared, so neither branch edits the other's file) with
## `--mode=kill` the default, BotProf on (the death path's sections in zombie.gd, every GLBus kill listener timed on
## its own), the sections of the blast's frame and of the worst frame after it printed per event, and
## `--defer=on|off|flip` (Zombie.t283_death; flip: on for odd events, off for even ones, an A/B from one map load).
## T-280's description follows.
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
var _mode: String = "kill"
var _defer: String = "on"
var _gore: String = ""
var _refill_due: bool = false
var _tick_texts: Dictionary = {}   # frame index -> the BotProf sections of that frame
var _part_pre: Dictionary = {}     # frame index -> microseconds from the last process step's end to the physics tick
var _part_phys: Dictionary = {}    # frame index -> microseconds of the physics tick (to this node's _process)
var _part_proc: Dictionary = {}    # frame index -> microseconds of the process step (this node's _process to the last)
var _phys_us: int = 0
var _end_us: int = 0
var _tail: Node = null
var _reps: int = 3
var _prev_us: int = 0
var _frames: PackedInt32Array = []   # wall microseconds of every frame since the pack formed
var _events: Array = []              # [{name, frame, call_us}]
var _next_t: float = 0.0
var _step: int = 0
var _done: bool = false
var _packed: bool = false
var _packed_step: bool = false


func _ready() -> void:
	process_priority = -1000
	process_physics_priority = -1000
	_tail = Node.new()   # runs last in every process step: the time the step ended
	_tail.process_priority = 100000
	_tail.process_mode = Node.PROCESS_MODE_ALWAYS
	_tail.set_script(_TailScript)
	add_child(_tail)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--reps="):
			_reps = maxi(1, int(a.substr(7)))
		elif a.begins_with("--defer="):
			_defer = a.substr(8)
		elif a.begins_with("--gore="):   # off / low / full (the Gore setting)
			_gore = a.substr(7)
	BotProf.on = true
	GLVO.set("async_start", true)   # (voice lines load on a thread as in the windowed game; headless loads them in the frame)
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
	seed(280)
	ProfileSave.path = "user://_bench_explosions_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_bench_explosions_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	if _gore != "":
		GLSettings.values["gore"] = _gore
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	print("[bench] mode %s, reps %d, vfx_quality %s" % [_mode, _reps, str(GLSettings.values.get("vfx_quality", "high"))])
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)


const _TailScript: GDScript = preload("res://gravelight/tools_src/bench_frame_tail.gd")


func _physics_process(_delta: float) -> void:
	_phys_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_end_us = int(_tail.get("end_us"))
	if _prev_us > 0 and _phase >= 3:
		_frames.append(now - _prev_us)
		# the interval from one process step to the next in three parts: the process step, the gap after it (deletions,
		# the renderer, audio, the engine's own frame end) and the next physics tick (scripts, physics and navigation servers)
		_part_pre[_frames.size() - 1] = _phys_us - _end_us
		_part_phys[_frames.size() - 1] = now - _phys_us
		_part_proc[_frames.size() - 1] = _end_us - _prev_us
		var tt: String = BotProf.tick_text(10)
		if tt != "":
			_tick_texts[_frames.size() - 1] = tt
	_prev_us = now
	BotProf.begin_tick()
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
				var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
				if _mode in ["kill", "deaths"]:   # T-283: room for every event's pack while the earlier ones still lie as corpses
					var free: Array = dir.get("_free")
					var pool: Array = dir.get("_pool")
					while pool.size() < 150:
						var nz: Zombie = Zombie.new()
						nz.name = "ZombieB%03d" % pool.size()
						nz.director = dir
						nz.net_id = pool.size()
						dir.add_child(nz)
						pool.append(nz)
						free.append(nz)
				dir.debug_spawn(24)
		1:
			_keep_alive()
			if _t > 6.0 and not _packed:   # stood in a pack 8 m in front of the player (they then walk in on him)
				_packed = true
				_pack()
			if _t > 9.0:
				_time_listeners()
				_phase = 3
				_next_t = _t + 2.0
				print("[bench] pack formed: %d zombies, spread %.1f m" % [_map.director.active_zombies().size(), _spread()])
		3:
			_keep_alive()
			if _refill_due and _t >= _next_t - 2.0:
				_refill_due = false
				(_map.get_node("ZombieDirector") as ZombieDirector).debug_spawn(24 - _map.director.active_zombies().size())
			if _mode in ["kill", "deaths"] and _t >= _next_t - 1.0 and not _packed_step:   # every event meets a packed 24
				_packed_step = true
				_pack()
			if _t >= _next_t:
				_packed_step = false
				_fire()
				_step += 1
				_next_t = _t + (4.0 if _mode in ["kill", "deaths"] else 3.0)
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
	if _mode in ["kill", "deaths"]:
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


## Every GLBus listener of a damage or a kill, timed on its own (BotProf "L.<signal>.<target>.<method>"), in the
## order they were connected.
func _time_listeners() -> void:
	for sig_name: String in ["enemy_killed", "enemy_killed_at", "enemy_damaged", "scrip_changed"]:
		var sig: Signal = GLBus.get(sig_name)
		for c: Dictionary in sig.get_connections():
			var cb: Callable = c["callable"]
			var obj: Object = cb.get_object()
			var label: StringName = StringName("L.%s.%s.%s" % [sig_name.trim_prefix("enemy_").replace("scrip_changed", "scrip"), (obj.get_script().resource_path.get_file().get_basename() if obj != null and obj.get_script() != null else str(obj)), cb.get_method()])
			sig.disconnect(cb)
			sig.connect(func(a: Variant = null, b: Variant = null, c2: Variant = null, d: Variant = null) -> void:
				var t0: int = BotProf.t()
				var args: Array = [a, b, c2, d].slice(0, cb.get_argument_count() if cb.get_argument_count() > 0 else 4)
				cb.callv(args)
				BotProf.add(label, t0))


func _fire() -> void:
	var six: bool = _step % 2 == 1
	if _defer == "flip":
		Zombie.t283_death = (_step / 2) % 2 == 0
	else:
		Zombie.t283_death = _defer != "off"
	if _mode in ["kill", "deaths"]:   # a fresh pack for every event (the last one died)
		for z: Zombie in _map.director.active_zombies():
			z.hp = minf(z.hp, 60.0)
	var c: Vector3 = _centre()
	var n: int = 6 if six else 1
	var alive0: int = _map.director.active_zombies().size()
	var dead0: int = 0
	for z0: Zombie in _map.director.active_zombies():
		if z0.state == Zombie.State.DEAD:
			dead0 += 1
	var t0: int = Time.get_ticks_usec()
	for i: int in n:
		var at: Vector3 = c + (Vector3(cos(i * 1.047), 0, sin(i * 1.047)) * 2.0 if six else Vector3.ZERO)
		if _mode == "fx":
			Effects.explosion(at, 6.0)
		elif _mode == "deaths":   # T-283: the deaths alone (no blast presentation, no line-of-sight rays): what dying costs
			for z: Zombie in _map.director.active_zombies():
				if z.global_position.distance_to(at) <= float(FRAG["radius"]):
					z.take_damage(z.hp + 1.0, &"torso", &"frag", _map.player.player_id, &"explosive")
		else:
			Explosion.detonate(_map.player, at, FRAG, _map.player.player_id, &"frag")
	var us: int = Time.get_ticks_usec() - t0
	_events.append({"name": "6 blasts" if six else "1 blast", "frame": _frames.size(), "call_us": us,
		"alive": _map.director.active_zombies().size(), "defer": Zombie.t283_death, "killed": alive0 - _map.director.active_zombies().size(), "up": alive0, "sections": BotProf.tick_text(14)})
	_refill_due = _mode in ["kill", "deaths"]   # T-283: the pack is put back 2 s later, not in the blast's frame


func _dead_now() -> int:
	var n: int = 0
	for z: Zombie in _map.director.active_zombies():
		if z.state == Zombie.State.DEAD:
			n += 1
	return n


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
		var wj: int = -1
		for j2: int in range(f + 1, mini(f + 31, _frames.size())):
			if wj < 0 or _frames[j2] > _frames[wj]:
				wj = j2
		print("[blast] %s %s (defer %s): killed %d of %d, frame %.2f ms (after its process step %.2f, then the next tick %.2f; the process step %.2f), worst of the next 30 %.2f ms (+%d), in the calls %.2f ms, median before %.2f ms" % [
			_mode, e["name"], str(e["defer"]), int(e["killed"]), int(e["up"]), blast_ms, int(_part_pre.get(f, 0)) / 1000.0, int(_part_phys.get(f, 0)) / 1000.0, int(_part_proc.get(f, 0)) / 1000.0, after, wj - f, int(e["call_us"]) / 1000.0, med])
		print("[blast]   in the call: %s" % str(e["sections"]))
		print("[blast]   the whole blast frame: %s" % str(_tick_texts.get(f, "")))
		for k: int in range(f + 1, mini(f + 4, _frames.size())):
			print("[blast]   +%d %.2f ms (after its process step %.2f, then the next tick %.2f; the process step %.2f): %s" % [k - f, _frames[k] / 1000.0, int(_part_pre.get(k, 0)) / 1000.0, int(_part_phys.get(k, 0)) / 1000.0, int(_part_proc.get(k, 0)) / 1000.0, str(_tick_texts.get(k, ""))])
		print("[blast]   the worst after (+%d): %s" % [wj - f, str(_tick_texts.get(wj, ""))])
		if str(e["name"]) == "1 blast":
			worst_one = maxf(worst_one, maxf(blast_ms, after))
		else:
			worst_six = maxf(worst_six, maxf(blast_ms, after))
	var all: PackedInt32Array = _frames.duplicate()
	all.sort()
	for line: String in BotProf.report():
		if line.contains(" z.") or line.contains(" L."):
			print("[blast-prof] " + line)
	print("[blast-summary] mode %s: worst frame with 1 blast %.2f ms, with 6 blasts %.2f ms; all frames p50 %.2f / p99 %.2f / max %.2f ms (%d frames)" % [
		_mode, worst_one, worst_six, all[all.size() / 2] / 1000.0, all[int(all.size() * 0.99)] / 1000.0, all[all.size() - 1] / 1000.0, all.size()])
