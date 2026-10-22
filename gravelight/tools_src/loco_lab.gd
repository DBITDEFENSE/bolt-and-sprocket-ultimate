extends Node
## Locomotion lab (Update 03 section 3, T-056): Map 0 with a god-mode human and 3 bots whose brains are paused, so
## this script drives each bot's BotLocomotion directly and checks it, headless, printing PASS/FAIL per check:
##   routes     every Map 0 training route validates on the navmesh (TrainingRoute.validate_on)
##   follow     the wedge round a standing human: close, out of their bubble, spread apart, out of chokes
##   moving     the human walks the taproom loop: the bots keep up, never block them, never moonwalk
##   yield      the human walks straight at a holding bot: it steps aside, the human walks through unhindered
##   hold       a hold spot reached and faced
##   mantle     a waist-high box across the way (not in the navmesh) is vaulted with the shared mantle
##   door       a goal behind the shut stable door: the bot never walks through the door
##   train      one bot trains a horde round the taproom loop: laps it ahead of the train, keeps it tight, stays in
##              the ring, and turns back when zombies cut it off
##   stuck      a wall across the way (not in the navmesh): repath, nudge, then a teleport only once no human sees it
##   budget     the layer's average tick cost per bot
## Scenes: loco_lab.tscn (this; args below) and smoke_bot_loco.tscn (the same script, the smoke set).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/loco_lab.tscn [-- --only=train --clip]
## --clip: windowed run for the movie maker: just the train phase, 10 zombies, an overhead camera in the taproom.
## Prints "[loco] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 400.0
const LOOP: Array[Vector3] = [Vector3(10.5, 0, 3.0), Vector3(16.5, 0, 2.4), Vector3(22.2, 0, 2.6), Vector3(22.2, 0, 9.0),
	Vector3(19.4, 0, 14.4), Vector3(14.5, 0, 14.2), Vector3(10.2, 0, 13.6), Vector3(10.4, 0, 6.5)]

var _map: Node3D
var _t: float = 0.0
var _phase: String = "boot"
var _phase_t: float = 0.0
var _queue: Array[String] = ["routes", "follow", "moving", "yield", "hold", "mantle", "door", "train", "stuck", "budget"]
var _fails: PackedStringArray = []
var _passes: int = 0
var _done: bool = false
var _only: String = ""
var _clip: bool = false
var _human: Player
var _bots: Array[Player] = []
var _brains: Array[BotBrain] = []
var _locos: Array[BotLocomotion] = []
# per-phase scratch
var _s: Dictionary = {}
var _loop_i: int = 0
var _props: Array[Node] = []
var _cam: Camera3D = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
		elif a == "--clip":
			_clip = true
	if _clip:
		_only = "train"
	if _only != "":
		_queue.clear()
		_queue.append(_only)
	ProfileSave.path = "user://_qa_loco_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_ai_mode = "off"
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true


func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
		print("[loco] PASS ", what)
	else:
		_fails.append(what)
		print("[loco] FAIL ", what)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _root() -> MapRoot:
	return _map as MapRoot


func _physics_process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	if _clip:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _t > TIMEOUT:
		_check(false, "timeout in phase " + _phase)
		_finish()
		return
	# no natural spawns: the lab places every zombie itself
	RoundManager.to_spawn = 0
	if RoundManager.state != RoundManager.State.ROUND:
		RoundManager.break_left = maxf(RoundManager.break_left, 60.0)
	if _phase == "boot":
		if _phase_t < 2.5:
			return
		if not _boot():
			return
		_next()
		return
	call("_ph_" + _phase, delta)
	if OS.get_cmdline_user_args().has("--debug") and Engine.get_physics_frames() % 30 == 0:
		var l0: BotLocomotion = _locos[0]
		var b0: Player = _bots[0]
		print("[loco] dbg t=%.1f pos=%s yaw=%.2f arrived=%s look=%s goal=%s block=%.2f probe=%s path=%d/%d floor=%s v=%.2f" % [_phase_t, b0.global_position, b0.rotation.y,
			l0._arrived, l0._look_set, l0._goal, l0._block_t, not b0.probe_mantle().is_empty(), l0._path_i, l0._path.size(), b0.is_on_floor(), b0.horizontal_speed()])
	for i: int in _bots.size():
		_brains[i]._pose(delta)   # the paused brain's body pose (RemoteBody, net flags; the layer owns the facing)


func _boot() -> bool:
	var root: MapRoot = _root()
	if root == null or root.squad == null or root.player == null:
		return false
	_human = root.player
	for b: BotBrain in root.squad.brains:
		b.set_physics_process(false)
		if b.loco == null:
			b.loco = BotLocomotion.new()
			b.loco.setup(b.player, root.squad)
		_brains.append(b)
		_bots.append(b.player)
		_locos.append(b.loco)
		b.loco.clear_look()   # (the brain aimed before it was paused)
		b.loco.stop()
		b.player.bot_damage_mult = 0.0
	root.director.kill_all(true)
	print("[loco] %d bots, locomotion %s" % [_bots.size(), str(BotConfig.cfg().get("locomotion", "?"))])
	return _bots.size() == 3


func _next() -> void:
	_release_inputs()
	for p: Node in _props:
		if is_instance_valid(p):
			p.queue_free()
	_props.clear()
	if _queue.is_empty():
		_finish()
		return
	_phase = _queue.pop_front()
	_phase_t = 0.0
	_s = {}
	print("[loco] -- %s (t=%.0fs)" % [_phase, _t])
	call("_setup_" + _phase)


func _place(p: Player, at: Vector3, yaw: float = 0.0) -> void:
	p.global_position = NavigationServer3D.map_get_closest_point(p.get_world_3d().navigation_map, at) + Vector3.UP * 0.05
	p.velocity = Vector3.ZERO
	p.rotation.y = yaw


func _release_inputs() -> void:
	for a: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint"]:
		Input.action_release(a)


## Walks the human toward `p` like a person: turns to it, holds forward. True when there.
func _walk_human(p: Vector3, delta: float, tol: float = 0.8) -> bool:
	var to: Vector3 = p - _human.global_position
	to.y = 0.0
	if to.length() < tol:
		Input.action_release(&"move_forward")
		return true
	var want: float = atan2(-to.x, -to.z)
	_human.rotation.y = rotate_toward(_human.rotation.y, want, 8.0 * delta)
	Input.action_press(&"move_forward")
	return false


func _stop_all() -> void:
	for l: BotLocomotion in _locos:
		l.stop()
		l.clear_look()


func _tick_locos(delta: float) -> void:
	for l: BotLocomotion in _locos:
		l.tick(delta)


func _wall(name_: String, a: Vector3, b: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = name_
	body.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = (b - a).abs()
	cs.shape = box
	body.add_child(cs)
	_map.add_child(body)
	body.global_position = (a + b) * 0.5
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = box.size
	mi.mesh = bm
	body.add_child(mi)
	_props.append(body)
	return body


## Moonwalk sampler: a bot moving > 1.5 m/s with no look set should face within 60 degrees of where it goes.
func _sample_facing(key: String) -> void:
	for i: int in _bots.size():
		var b: Player = _bots[i]
		var v: Vector3 = Vector3(b.velocity.x, 0, b.velocity.z)
		if v.length() < 1.5 or _locos[i]._look_set:
			continue
		var fwd: Vector3 = -b.global_basis.z
		fwd.y = 0.0
		_s[key + "_n"] = int(_s.get(key + "_n", 0)) + 1
		if rad_to_deg(fwd.normalized().angle_to(v.normalized())) > 60.0:
			_s[key + "_bad"] = int(_s.get(key + "_bad", 0)) + 1


## Blocking as BotMetrics measures it: a bot inside the moving human's 1.2 m.
func _sample_block(delta: float) -> void:
	var hv: float = Vector2(_human.velocity.x, _human.velocity.z).length()
	var blocked: bool = false
	for b: Player in _bots:
		if hv > 1.0 and _flat(b.global_position, _human.global_position) < 1.2 and absf(b.global_position.y - _human.global_position.y) < 1.5:
			blocked = true
	if blocked:
		_s["block_t"] = float(_s.get("block_t", 0.0)) + delta
		_s["block_run"] = float(_s.get("block_run", 0.0)) + delta
		_s["block_max"] = maxf(float(_s.get("block_max", 0.0)), float(_s["block_run"]))
	else:
		_s["block_run"] = 0.0


# ================================================================== routes

func _setup_routes() -> void:
	pass


func _ph_routes(_delta: float) -> void:
	for r: TrainingRoute in TrainingRoute.all_for_map("map00"):
		var res: Dictionary = r.validate_on(_map.get_world_3d())
		_check(bool(res["ok"]), "route %s on the navmesh (%.1f m, min width %.1f m)%s" % [r.id, float(res["length"]), float(res["min_width"]),
			"" if bool(res["ok"]) else ": " + str((res["problems"] as PackedStringArray).slice(0, 3))])
	_next()


# ================================================================== follow (standing)

func _setup_follow() -> void:
	_place(_human, Vector3(15.0, 0, 8.0), 0.0)
	for i: int in _bots.size():
		_place(_bots[i], Vector3(11.0 + 4.0 * float(i), 0, 3.0))


func _ph_follow(delta: float) -> void:
	for i: int in _locos.size():
		_locos[i].follow(_human, i)
	_tick_locos(delta)
	_sample_facing("f")
	if _phase_t < 8.0:
		return
	var hp: Vector3 = _human.global_position
	var near_ok: bool = true
	var bubble_ok: bool = true
	var apart_ok: bool = true
	var choke_ok: bool = true
	var angles: Array[float] = []
	for i: int in _bots.size():
		var d: float = _flat(_bots[i].global_position, hp)
		near_ok = near_ok and d < 5.0
		bubble_ok = bubble_ok and d >= 1.2
		choke_ok = choke_ok and _root().squad.choke_at(_bots[i].global_position).is_empty()
		var off: Vector3 = _bots[i].global_position - hp
		angles.append(atan2(off.x, off.z))
		for j: int in range(i + 1, _bots.size()):
			apart_ok = apart_ok and _flat(_bots[i].global_position, _bots[j].global_position) >= 0.9
	var min_sep: float = INF
	for a: int in angles.size():
		for b: int in range(a + 1, angles.size()):
			min_sep = minf(min_sep, rad_to_deg(absf(wrapf(angles[a] - angles[b], -PI, PI))))
	_check(near_ok, "follow: every bot within 5 m of the standing human")
	_check(bubble_ok, "follow: no bot inside the human's 1.2 m bubble")
	_check(apart_ok, "follow: bots at least 0.9 m apart")
	_check(min_sep >= 25.0, "follow: slots spread round the human (min %.0f deg between bots)" % min_sep)
	_check(choke_ok, "follow: nobody parked in a doorway or on stairs")
	_next()


# ================================================================== moving (the human trains, bots follow)

func _setup_moving() -> void:
	_loop_i = 0
	_place(_human, LOOP[0], 0.0)


func _ph_moving(delta: float) -> void:
	if _walk_human(LOOP[_loop_i], delta):
		_loop_i = (_loop_i + 1) % LOOP.size()
	for i: int in _locos.size():
		_locos[i].follow(_human, i)
	_tick_locos(delta)
	_sample_facing("m")
	_sample_block(delta)
	_s["n"] = int(_s.get("n", 0)) + 1
	for b: Player in _bots:
		if _flat(b.global_position, _human.global_position) < 7.0:
			_s["near"] = int(_s.get("near", 0)) + 1
	if _phase_t < 25.0:
		return
	var near_frac: float = float(_s.get("near", 0)) / float(maxi(1, int(_s["n"]) * _bots.size()))
	var mw: float = float(_s.get("m_bad", 0)) / float(maxi(1, int(_s.get("m_n", 0))))
	_check(near_frac >= 0.8, "moving: bots within 7 m of the training human %.0f%% of the time" % (near_frac * 100.0))
	_check(float(_s.get("block_max", 0.0)) < 2.0, "moving: no sustained blocking (longest %.2f s inside the moving human's 1.2 m)" % float(_s.get("block_max", 0.0)))
	_check(float(_s.get("block_t", 0.0)) < 2.0, "moving: %.2f s of blocking in 25 s" % float(_s.get("block_t", 0.0)))
	var fw: float = float(_s.get("f_bad", 0)) / float(maxi(1, int(_s.get("f_n", 0))))
	_check(int(_s.get("m_n", 0)) > 300, "moving: %d moving frames sampled for the facing check" % int(_s.get("m_n", 0)))
	_check(mw <= 0.1 and fw <= 0.1, "no moonwalking: %.0f%% / %.0f%% of moving frames faced > 60 deg off the way they went" % [mw * 100.0, fw * 100.0])
	_next()


# ================================================================== yield (a human walks at a bot)

func _setup_yield() -> void:
	_place(_human, Vector3(10.5, 0, 8.0), -PI * 0.5)
	_place(_bots[0], Vector3(15.5, 0, 8.0))
	_place(_bots[1], Vector3(12.0, 0, 13.5))
	_place(_bots[2], Vector3(14.0, 0, 13.5))
	_s["min_d"] = INF


func _ph_yield(delta: float) -> void:
	_locos[0].hold(Vector3(15.5, 0, 8.0), Vector3(0, 0, -1))
	_locos[1].stop()
	_locos[2].stop()
	_tick_locos(delta)
	var arrived: bool = false
	if _phase_t > 1.5:
		arrived = _walk_human(Vector3(20.5, 0, 8.0), delta, 0.6)
		_s["min_d"] = minf(float(_s["min_d"]), _flat(_bots[0].global_position, _human.global_position))
		_sample_block(delta)
	if arrived and not _s.has("arrive_t"):
		_s["arrive_t"] = _phase_t - 1.5
	if _phase_t < 9.0 and not arrived:
		return
	if not _s.has("arrive_t") and _phase_t < 9.0:
		return
	var at: float = float(_s.get("arrive_t", 99.0))
	_check(at < 3.4, "yield: the human walked 10 m through the bot's spot in %.1f s (4.5 m/s walk: ~2.3 s)" % at)
	_check(float(_s["min_d"]) >= 0.75, "yield: the bot stepped aside (closest %.2f m)" % float(_s["min_d"]))
	_check(_locos[0].yields >= 1, "yield: it counted %d step-asides" % _locos[0].yields)
	_next()


# ================================================================== hold

func _setup_hold() -> void:
	_place(_bots[0], Vector3(18.0, 0, 11.0), PI)


func _ph_hold(delta: float) -> void:
	_locos[0].hold(Vector3(12.0, 0, 4.5), Vector3(1, 0, 0))
	_locos[1].stop()
	_locos[2].stop()
	_tick_locos(delta)
	if _phase_t < 6.0:
		return
	var b: Player = _bots[0]
	var fwd: Vector3 = -b.global_basis.z
	_check(_flat(b.global_position, Vector3(12.0, 0, 4.5)) < 0.9, "hold: reached the spot (%.2f m off)" % _flat(b.global_position, Vector3(12.0, 0, 4.5)))
	_check(rad_to_deg(Vector3(fwd.x, 0, fwd.z).normalized().angle_to(Vector3(1, 0, 0))) < 20.0, "hold: facing the hold direction")
	_next()


# ================================================================== mantle

func _setup_mantle() -> void:
	_place(_bots[0], Vector3(12.5, 0, 8.0), -PI * 0.5)
	_wall("LabLedge", Vector3(15.0, 0, 4.0), Vector3(15.5, 0.85, 12.0))
	_s["start_m"] = _locos[0].mantles_started


func _ph_mantle(delta: float) -> void:
	_locos[0].move_to(Vector3(18.5, 0, 8.0), 0.5, 0.5)
	_locos[1].stop()
	_locos[2].stop()
	_tick_locos(delta)
	var there: bool = _flat(_bots[0].global_position, Vector3(18.5, 0, 8.0)) < 0.8
	if not there and _phase_t < 8.0:
		return
	_check(there, "mantle: crossed a waist-high box the navmesh doesn't know about")
	_check(_locos[0].mantles_started > int(_s["start_m"]) and _bots[0].mantles > 0, "mantle: with the shared vault (%d mantles)" % _bots[0].mantles)
	_next()


# ================================================================== door

func _setup_door() -> void:
	_place(_bots[0], Vector3(19.5, 0, 13.0))


func _ph_door(delta: float) -> void:
	_locos[0].move_to(Vector3(20.5, 0, 27.0), 1.0, 0.5)
	_tick_locos(delta)
	_s["max_z"] = maxf(float(_s.get("max_z", -INF)), _bots[0].global_position.z)
	if _phase_t < 5.0:
		return
	var open: bool = false
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and (n as BuyDoor).door_id == &"door_stable":
			open = (n as BuyDoor).is_open
	_check(not open and float(_s["max_z"]) < 15.6, "door: never walked through the shut stable door (furthest z %.1f)" % float(_s["max_z"]))
	_next()


# ================================================================== train

func _setup_train() -> void:
	var route: TrainingRoute = null
	for r: TrainingRoute in TrainingRoute.all_for_map("map00"):
		if r.id == "map00_taproom":
			route = r
	_s["route"] = route
	var start: Vector3 = route.point_at(0.0)
	_place(_bots[0], start)
	# everyone else out of the zombies' minds (zombies chase the nearest player in the group)
	_place(_human, Vector3(3.0, 0, 2.0), PI)
	_place(_bots[1], Vector3(2.0, 0, 5.0))
	_place(_bots[2], Vector3(3.5, 0, 5.0))
	for p: Player in [_human, _bots[1], _bots[2]]:
		p.remove_from_group(&"players")
	var pts: Array = []
	var n: int = 10 if _clip else 6
	for k: int in n:
		pts.append(route.point_at(route.length() - 5.0 - float(k) * 0.9))
	_s["spawned"] = _root().director.spawn_burst(pts, n)
	_s["prev_param"] = route.closest_param(start)
	_s["travel"] = 0.0
	_s["in_ring"] = 0
	_s["n"] = 0
	_s["caught"] = 0
	_s["head_d"] = []
	if _clip:
		_cam = Camera3D.new()
		_map.add_child(_cam)
		_cam.global_position = Vector3(8.6, 2.5, 15.2)
		_cam.look_at(Vector3(17.5, 0.3, 6.5))
		_cam.fov = 78.0
		_cam.current = true


func _ph_train(delta: float) -> void:
	var route: TrainingRoute = _s["route"]
	var l: BotLocomotion = _locos[0]
	l.train(route)
	var face: Vector3 = l.train_face_dir()
	if face != Vector3.ZERO and l._t_urg < 0.6:
		l.look_at_dir(face)   # what the aim layer does: turn and fire at the train's head when it falls back
	else:
		l.clear_look()
	_locos[1].stop()
	_locos[2].stop()
	_tick_locos(delta)
	var b: Player = _bots[0]
	var p: float = route.closest_param(b.global_position)
	var dp: float = wrapf(p - float(_s["prev_param"]), -route.length() * 0.5, route.length() * 0.5)
	_s["travel"] = float(_s["travel"]) + absf(dp)
	_s["prev_param"] = p
	_s["n"] = int(_s["n"]) + 1
	if route.contains_ring(b.global_position) or route.distance_to_line(b.global_position) < route.ring_width:
		_s["in_ring"] = int(_s["in_ring"]) + 1
	var nearest: float = INF
	for z: Zombie in _root().director.active_zombies():
		nearest = minf(nearest, _flat(z.global_position, b.global_position))
	if nearest < 1.0:
		_s["caught"] = int(_s["caught"]) + 1
	if nearest < INF and int(_s["n"]) % 30 == 0:
		(_s["head_d"] as Array).append(nearest)
	var lap_t: float = 40.0 if not _clip else 34.0
	if _phase_t < lap_t:
		return
	if not _s.has("cut_setup"):
		_s["cut_setup"] = true
		_s["rev0"] = l.reversals
		_s["cut_t"] = _phase_t
		# zombies ahead on the loop: it should turn back (or say it can't train) rather than run into them
		var me_p: float = route.closest_param(b.global_position)
		var pts: Array = []
		for k: int in 3:
			pts.append(route.point_at(route.advance(me_p, 5.0 + float(k) * 0.8, l._t_dir)))
		_root().director.spawn_burst(pts, 3)
		return
	if not l.train_ok():
		_s["not_ok"] = true
	if _phase_t - float(_s["cut_t"]) < 4.0:
		return
	var heads: Array = _s["head_d"]
	heads.sort()
	var med: float = float(heads[heads.size() / 2]) if not heads.is_empty() else INF
	_check(int(_s["spawned"]) >= 6, "train: %d zombies spawned behind the bot" % int(_s["spawned"]))
	_check(float(_s["travel"]) >= route.length(), "train: ran %.0f m of the %.0f m loop (at least a lap)" % [float(_s["travel"]), route.length()])
	_check(float(_s["in_ring"]) / float(maxi(1, int(_s["n"]))) >= 0.85, "train: in the loop's ring %.0f%% of the time" % (100.0 * float(_s["in_ring"]) / float(maxi(1, int(_s["n"])))))
	_check(float(_s["caught"]) / float(maxi(1, int(_s["n"]))) <= 0.1, "train: a zombie within 1 m only %.0f%% of the time" % (100.0 * float(_s["caught"]) / float(maxi(1, int(_s["n"])))))
	_check(med < 9.0, "train: kept the train tight (median distance to its head %.1f m)" % med)
	_check(l.reversals > int(_s["rev0"]) or _s.has("not_ok"), "train: cut off ahead -> turned back (%d reversals) or reported it (train_ok false: %s)" % [l.reversals - int(_s["rev0"]), str(_s.has("not_ok"))])
	for p2: Player in [_human, _bots[1], _bots[2]]:
		p2.add_to_group(&"players")
	_root().director.kill_all(true)
	if _clip:
		_finish()
		return
	_next()


# ================================================================== stuck

func _setup_stuck() -> void:
	_root().director.kill_all(true)
	# a wall right across the taproom that the navmesh doesn't know about
	_wall("LabWall", Vector3(16.0, 0, 0.2), Vector3(16.4, 3.4, 15.4))
	_place(_bots[0], Vector3(13.0, 0, 8.0), -PI * 0.5)
	_place(_bots[1], Vector3(4.0, 0, 3.0))
	_place(_bots[2], Vector3(5.0, 0, 3.0))
	# the human watches the bot from its own side of the wall
	_place(_human, Vector3(10.0, 0, 8.0), -PI * 0.5)
	_s["tp0"] = _locos[0].teleports
	_s["nudge0"] = _locos[0].nudges
	_s["rep0"] = _locos[0].repaths


func _ph_stuck(delta: float) -> void:
	_locos[0].move_to(Vector3(20.0, 0, 8.0), 0.5, 0.6)
	_locos[1].stop()
	_locos[2].stop()
	_tick_locos(delta)
	var b: Player = _bots[0]
	if _phase_t < 11.0:
		# keep looking at it
		var to: Vector3 = b.global_position - _human.global_position
		_human.rotation.y = atan2(-to.x, -to.z)
		return
	if not _s.has("watched_tp"):
		_s["watched_tp"] = _locos[0].teleports - int(_s["tp0"])
		_check(int(_s["watched_tp"]) == 0, "stuck: no teleport while the human watches (11 s stuck)")
		_check(_locos[0].nudges > int(_s["nudge0"]), "stuck: it nudged (local random walk) after 4 s (%d)" % (_locos[0].nudges - int(_s["nudge0"])))
		_check(_locos[0].is_stuck(), "stuck: is_stuck() says so")
		_human.rotation.y = PI * 0.5   # look away (west)
	var tp: int = _locos[0].teleports - int(_s["tp0"])
	if tp == 0 and _phase_t < 20.0:
		return   # one full ladder: a nudge made while still watched (at 8 s) counts as progress and restarts it
	_check(tp >= 1, "stuck: teleported once nobody saw it (%.1f s after the human looked away)" % (_phase_t - 11.0))
	_check(b.global_position.x > 16.5, "stuck: it ended up past the wall (x %.1f)" % b.global_position.x)
	_next()


# ================================================================== budget

func _setup_budget() -> void:
	pass


func _ph_budget(_delta: float) -> void:
	var worst: float = 0.0
	var worst_ratio: float = 0.0
	var line: PackedStringArray = []
	for l: BotLocomotion in _locos:
		worst = maxf(worst, l.avg_tick_us())
		worst_ratio = maxf(worst_ratio, (l.avg_tick_us() - l.avg_body_us()) / maxf(1.0, l.avg_body_us()))
		line.append("%.0f us (body movement %.0f us; %d ticks, %d plans)" % [l.avg_tick_us(), l.avg_body_us(), l._ticks, l.repaths])
	print("[loco] tick cost per bot: ", ", ".join(line))
	# Wall-clock: on a loaded machine (other headless runs sharing the CPU) every number grows together, so the
	# layer's own cost is also measured against the shared body movement it drives in the same run (about 1.8x
	# on a quiet machine); either keeps it honest (T-059).
	_check(worst < 250.0 or worst_ratio < 2.5, "budget: the locomotion tick averages %.0f us per bot (< 250 us of the 0.5 ms budget), the layer's own share %.1fx the body movement (< 2.5x on a loaded machine)" % [worst, worst_ratio])
	_next()


func _finish() -> void:
	if _done:
		return
	_done = true
	_release_inputs()
	print("[loco] %d checks passed, %d failed" % [_passes, _fails.size()])
	for f: String in _fails:
		print("[loco] FAILED: ", f)
	print("[loco] RESULT %s" % ("PASS" if _fails.is_empty() else "FAIL"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_loco_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)
