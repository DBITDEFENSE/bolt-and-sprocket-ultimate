extends Node
## Update 03 section 10 acceptance clips (T-055), Map 0, 3 bots + the soak's scripted player (tools_src/
## soak_dummy.gd) in god mode, seen from a chase camera behind and above the player (pulled in off walls), with the
## AI debug labels over the bots (`--labels=0` hides them):
##   --shot=train    round 15: the squad trains with the player round the taproom; a bot is downed on purpose in
##                   the middle of it (a revive under pressure) and a Resupply drops (a callout with its ping)
##   --shot=cousins  round 10, the Cousins: who shoots the Hammer while her mallet is in the air, who breaks a
##                   Reach grab, how close anyone gets to Alix
##   --shot=perf     the performance check: round 15, the horde kept at 24 zombies, 3 bots; after a warm-up the
##                   frame times (average fps, 1% low) and the brains' cost per bot per frame (run it rendered,
##                   without --write-movie and without --fixed-fps)
## Prints "[clip] ..." lines and RESULT PASS/FAIL. Silent, off-screen, never holds the mouse:
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>.avi --fixed-fps 30
##         --quit-after 1500 --path . res://gravelight/tools_src/clip_bots.tscn -- --shot=train
## (also runs headless as a check: --headless --audio-driver Dummy --fixed-fps 60).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const Dummy: GDScript = preload("res://tools_src/soak_dummy.gd")

var _shot: String = "train"
var _labels: bool = true
var _secs_total: float = 48.0
var _map: MapRoot
var _dummy: RefCounted = null
var _cam: Camera3D
var _t: float = 0.0
var _live: bool = false
var _fails: PackedStringArray = []
var _downed_bot: Player = null
var _down_t: float = -1.0
var _revived_t: float = -1.0
var _revive_threat: float = 0.0
var _pings: int = 0
var _callouts: PackedStringArray = []
var _dropped: bool = false
# cousins
var _hammer_hits_airborne: int = 0
var _hammer_hits: int = 0
var _grab_list: Array[Dictionary] = []
var _grab_breaks: Array = []
var _alix_min: float = INF
var _cousin_kills: Array = []
# perf
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _zmax: int = 0
var _zsum: int = 0
var _brain_us0: float = 0.0
var _brain_frames0: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--labels="):
			_labels = a.substr(9) != "0"
		elif a.begins_with("--secs="):
			_secs_total = float(a.substr(7))
	if _shot == "cousins" and not Array(OS.get_cmdline_user_args()).any(func(x: Variant) -> bool: return str(x).begins_with("--secs=")):
		_secs_total = 70.0
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_clip_bots_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_clip_bots_settings.cfg"
	GLSettings.values["homage_bosses"] = true
	GLSettings.values["homage_names"] = "real"
	Campaign.reset()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "veteran"
	GameState.bot_ai_mode = "off"
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.vo_line_started.connect(func(id: StringName, _spk: StringName, text: String, _d: float) -> void:
		if String(id).contains("_SQ3_") or String(id).contains("REVIVE") or String(id).contains("POWERUP"):
			_callouts.append("%s \"%s\"" % [id, text])
			print("[clip] t=%.1f line %s: %s" % [_t, id, text]))
	GLBus.player_revived.connect(func(pid: int, by: int) -> void:
		print("[clip] t=%.1f P%d revived by P%d" % [_t, pid, by])
		if _downed_bot != null and pid == _downed_bot.player_id and _revived_t < 0.0:
			_revived_t = _t)
	GLBus.enemy_damaged.connect(_on_enemy_damaged)
	GLBus.enemy_killed.connect(func(eid: StringName, _l: StringName, _w: StringName, by: int) -> void:
		if String(eid).begins_with("cousin_"):
			_cousin_kills.append([eid, by, _t])
			print("[clip] t=%.1f %s killed by P%d" % [_t, eid, by]))


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # never hold the mouse
	_process_perf_frame(delta)


func _physics_process(delta: float) -> void:
	if _map == null or not _map.is_inside_tree():
		return
	if not _live:
		_try_live()
		return
	_t += delta
	if _dummy != null:
		_dummy.call("tick", delta)
	_drive_camera(delta)
	if _map.squad != null and _map.squad.pings != null:
		_pings = maxi(_pings, _map.squad.pings.active_count())
	match _shot:
		"train":
			_tick_train()
		"cousins":
			_tick_cousins()
		"perf":
			_tick_perf(delta)
	if _t >= _secs_total:
		_finish()


func _try_live() -> void:
	if _map.player == null or not _map.player.is_inside_tree() or _map.squad == null:
		return
	if NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) == 0:
		return
	_live = true
	GameState.god_mode = true
	_dummy = Dummy.new()
	_dummy.call("setup", _map.player, _map, 7)
	for pid: int in GameState.player_ids:
		Economy.award(pid, 4000)
	if _shot == "train" or _shot == "perf":
		RoundManager.debug_set_round(15)
	else:
		RoundManager.debug_set_round(10)
	_map.director.kill_all(true)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_map.add_child(_cam)
	_cam.global_position = _map.player.global_position + Vector3(0, 3, 4)
	_cam.make_current()
	if _labels:
		GLConsole.call("run", "ai_debug 1")
		GLConsole.call("run", "ai_debug panel")   # labels and path lines only, no blackboard panel
	print("[clip] live: shot %s, round %d" % [_shot, RoundManager.current_round + 1])


## Behind and above the player, looking at the squad (and the nearest boss), pulled in when a wall is in the way.
func _drive_camera(delta: float) -> void:
	var h: Player = _map.player
	if _cam == null or h == null:
		return
	_cam.make_current()
	var pts: Array[Vector3] = [h.global_position]
	for b: BotBrain in _map.squad.brains:
		if not b.player.spectating:
			pts.append(b.player.global_position)
	for z: Zombie in _map.director.active_zombies():
		if z is HomageBoss and z.global_position.distance_to(h.global_position) < 18.0:
			pts.append(z.global_position)
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in pts:
		c += p
	c /= float(pts.size())
	var back: Vector3 = (h.global_position - c)
	back.y = 0.0
	back = back.normalized() if back.length() > 0.5 else h.global_basis.z
	var want: Vector3 = h.global_position + back * 4.2 + Vector3.UP * 2.6
	var from: Vector3 = h.global_position + Vector3.UP * 1.6
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, want, 1, [h.get_rid()])
	var r: Dictionary = h.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		want = from.lerp(r["position"], 0.85)
	_cam.global_position = _cam.global_position.lerp(want, clampf(delta * 2.5, 0.0, 1.0))
	var look: Vector3 = c.lerp(h.global_position, 0.35) + Vector3.UP * 1.0
	if _cam.global_position.distance_to(look) > 0.5:
		_cam.look_at(look, Vector3.UP)


# ---------------------------------------------------------------- the train shot

func _tick_train() -> void:
	# a Resupply drop beside the squad (a callout with a ping)
	if not _dropped and _t > 9.0 and RoundManager.state == RoundManager.State.ROUND:
		_dropped = true
		var b0: Player = _map.squad.brains[0].player
		PowerupManager.spawn(&"resupply", NavigationServer3D.map_get_closest_point(b0.get_world_3d().navigation_map, b0.global_position + Vector3(2.5, 0, 1.5)))
		print("[clip] t=%.1f dropped a Resupply by %s" % [_t, Net.display_name(b0.player_id)])
	# down the bot with the most zombies about it: a revive under pressure
	if _downed_bot == null and _t > 17.0 and _map.director.active_zombies().size() >= 6:
		var best: Player = null
		var best_n: int = -1
		for b: BotBrain in _map.squad.brains:
			var n: int = 0
			for z: Zombie in _map.director.active_zombies():
				if z.global_position.distance_to(b.player.global_position) < 8.0:
					n += 1
			if n > best_n and b.player.is_alive():
				best_n = n
				best = b.player
		if best != null:
			_downed_bot = best
			best.take_hit(99999.0, null)
			_down_t = _t
			_revive_threat = float(best_n)
			print("[clip] t=%.1f downed %s on purpose, %d zombies within 8 m" % [_t, Net.display_name(best.player_id), best_n])


# ---------------------------------------------------------------- the perf shot

func _process_perf_frame(delta: float) -> void:
	if _shot == "perf" and _live and _t > 12.0:
		_frame_ms.append(delta * 1000.0)


func _tick_perf(_delta: float) -> void:
	var n: int = _map.director.active_zombies().size()
	if _t > 12.0:
		if _brain_frames0 == 0:
			for b: BotBrain in _map.squad.brains:
				_brain_us0 += b.us_total
				_brain_frames0 += b.frames
		_zmax = maxi(_zmax, n)
		_zsum += n
	# keep the horde topped up to the round's cap (24 alive)
	if n < 24 and RoundManager.state == RoundManager.State.ROUND and Engine.get_physics_frames() % 20 == 0:
		var pts: Array = []
		for s: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
			pts.append((s as Node3D).global_position)
		if not pts.is_empty():
			_map.director.spawn_burst(pts.slice(0, 4), mini(4, 24 - n))


# ---------------------------------------------------------------- the Cousins shot

func _on_enemy_damaged(eid: StringName, _limb: StringName, _amount: float, by: int) -> void:
	if not GameState.is_bot(by):
		return
	if eid == &"cousin_hammer":
		_hammer_hits += 1
		for z: Zombie in _map.director.active_zombies():
			if z is CousinHammer and (z as CousinHammer).maul_out:
				_hammer_hits_airborne += 1
				break


func _tick_cousins() -> void:
	for z: Zombie in _map.director.active_zombies():
		if z is CousinAlix:
			for b: BotBrain in _map.squad.brains:
				if not b.player.spectating and not b.player.downed:
					_alix_min = minf(_alix_min, Vector2(z.global_position.x - b.player.global_position.x, z.global_position.z - b.player.global_position.z).length())
		if z is CousinReach:
			for g: Dictionary in (z as CousinReach).grabs():
				if not g.has("_clip_seen"):
					g["_clip_seen"] = true
					_grab_list.append(g)
					print("[clip] t=%.1f the Reach grabbed P%d" % [_t, int(g["pid"])])
	for g2: Dictionary in _grab_list:
		if str(g2.get("broken", "")) != "" and not g2.has("_clip_logged"):
			g2["_clip_logged"] = true
			_grab_breaks.append(str(g2["broken"]))
			print("[clip] t=%.1f the Reach's grab on P%d broken: %s" % [_t, int(g2["pid"]), str(g2["broken"])])


func _check(cond: bool, what: String) -> void:
	print("[clip] %-72s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	_live = false
	set_physics_process(false)
	if _dummy != null:
		_dummy.call("shutdown")
	if _shot == "perf":
		var sorted: PackedFloat32Array = _frame_ms.duplicate()
		sorted.sort()
		var avg: float = 0.0
		for f: float in _frame_ms:
			avg += f
		avg /= float(maxi(1, _frame_ms.size()))
		var p99: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
		var us: float = 0.0
		var fr: int = 0
		for b: BotBrain in _map.squad.brains:
			us += b.us_total
			fr += b.frames
		var per_bot: float = (us - _brain_us0) / 1000.0 / float(maxi(1, (fr - _brain_frames0) / maxi(1, _map.squad.brains.size()))) / float(maxi(1, _map.squad.brains.size()))
		print("[clip] perf: %d frames, average %.2f ms (%.0f fps), 1%% low %.2f ms (%.0f fps); zombies alive max %d, mean %.1f; brain %.3f ms per bot per frame" % [
			_frame_ms.size(), avg, 1000.0 / maxf(0.01, avg), p99, 1000.0 / maxf(0.01, p99), _zmax, float(_zsum) / float(maxi(1, int((_t - 12.0) * 60.0))), per_bot])
		_check(_zmax >= 20, "the horde reached 20+ alive (%d)" % _zmax)
		_check(per_bot <= 0.5, "the brain stays within 0.5 ms per bot per frame (%.3f)" % per_bot)
	elif _shot == "train":
		_check(RoundManager.current_round >= 15, "round 15+ (round %d)" % RoundManager.current_round)
		_check(_down_t >= 0.0, "a bot went down under pressure (%.0f zombies within 8 m)" % _revive_threat)
		_check(_revived_t >= 0.0, "and was revived (%.1f s after going down)" % (_revived_t - _down_t if _revived_t >= 0.0 else -1.0))
		_check(_pings > 0, "a callout ping showed (%d at once)" % _pings)
	else:
		_check(_hammer_hits > 0, "bots shot the Hammer (%d hits, %d while the mallet was in the air)" % [_hammer_hits, _hammer_hits_airborne])
		_check(_alix_min >= 1.0, "no bot stood in Alix's hand reach (closest %.1f m)" % _alix_min)
		print("[clip] Reach grabs %d, broken: %s; cousins down: %s" % [_grab_list.size(), str(_grab_breaks), str(_cousin_kills)])
	for l: String in _callouts.slice(0, 20):
		print("[clip]   ", l)
	for line: String in _map.squad.report():
		print("[clip]   ", line)
	print("RESULT %s (%s) %s" % ["PASS" if _fails.is_empty() else "FAIL", _shot, ", ".join(_fails)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_clip_bots_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)
