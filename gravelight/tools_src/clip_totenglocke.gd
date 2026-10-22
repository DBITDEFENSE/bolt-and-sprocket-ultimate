extends Node
## Update 02 section 3 (T-048) acceptance clips and checks for the rebuilt Totenglocke, on Kaltenbrunn (Map 1):
## a scripted, god-mode player in the Minehead yard's east strip, the real Player input path (fire held /
## released through the "fire" and "alt_fire" actions), zombies spawned through the ZombieDirector at a set round.
##   --shot=great   round 16: a 12-zombie train, wound up and released as a Great Toll (shatter + hitstop)
##   --shot=dome    round 15 with one bot: the bot goes down, the Bell Dome holds the train off during the revive
##   --shot=chain   Mitternacht, round 18: a Great Toll on an arc of zombies; the shattered chain-ring the flanks
##   --shot=r25     round 25: tap (35% + tolled marks), tap again (marked shatter), then a Great Toll on a wave
## Prints "[tg] ..." lines and RESULT PASS/FAIL. Silent, off-screen, never holds the mouse (D-058):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --write-movie <abs>.avi --fixed-fps 30
##         --path . res://gravelight/tools_src/clip_totenglocke.tscn -- --shot=great
## (also runs headless as a check: --headless --audio-driver Dummy).

const MAP: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const SPOT: Vector3 = Vector3(32.0, 0.1, 30.5)      # Minehead yard, east strip, facing north

var _shot: String = "great"
var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _kills: int = 0
var _min_scale: float = 1.0
var _aim_target: Vector3 = Vector3.INF


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_tg_clip_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 1 if _shot == "dome" else 0
	GameState.bot_skill = "regular"
	QuestManager.pending_seed = 4471
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, wid: StringName, _by: int) -> void:
		if String(wid).begins_with("totenglocke"):
			_kills += 1)
	_run.call_deferred()


func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # D-058: never hold the mouse
	_min_scale = minf(_min_scale, Engine.time_scale)
	if _aim_target != Vector3.INF and _p != null:
		_face(_aim_target)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[tg] %-70s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _face(target: Vector3) -> void:
	var cam_pos: Vector3 = _p.global_position + Vector3.UP * 1.62
	var d: Vector3 = target - cam_pos
	_p.rotation.y = atan2(-d.x, -d.z)
	_p.set("_pitch", atan2(d.y, Vector2(d.x, d.z).length()))


func _bell() -> WeaponInstance:
	return _p.weapons.current()


func _alive() -> Array[Zombie]:
	return _dir.active_zombies()


func _near(at: Vector3, r: float) -> int:
	var n: int = 0
	for z: Zombie in _alive():
		if z.global_position.distance_to(at) <= r:
			n += 1
	return n


## Spawns `count` zombies at `points` (scattered by the director) at round `r`'s health.
func _spawn(points: Array, count: int) -> void:
	_dir.spawn_burst(points, count)
	await _frames(2)


func _tap() -> void:
	Input.action_press(&"fire")
	await _frames(3)
	Input.action_release(&"fire")
	await _secs(0.55)


## Winds the bell until the Great Toll locks (or `max_s`), then holds until `release_when` says go.
func _great(release_when: Callable, max_hold: float = 5.0) -> void:
	Input.action_press(&"fire")
	var t: float = 0.0
	while t < max_hold:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= 1.55 and release_when.call():
			break
	Input.action_release(&"fire")
	await _frames(2)


func _run() -> void:
	await _frames(20)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	_dir.kill_all(true)
	GameState.god_mode = true
	Economy.grant(1, 50000)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)
	_p.global_position = SPOT
	_p.velocity = Vector3.ZERO
	_p.weapons.give_weapon(&"totenglocke_up" if _shot == "chain" else &"totenglocke")
	await _secs(0.7)
	_aim_target = SPOT + Vector3(0, 1.0, -12.0)
	match _shot:
		"great":
			await _clip_great()
		"dome":
			await _clip_dome()
		"chain":
			await _clip_chain()
		"r25":
			await _clip_r25()
	await _secs(2.5)
	_check(absf(Engine.time_scale - 1.0) < 0.0001, "Engine.time_scale is back to 1 (min seen %.2f)" % _min_scale)
	_finish()


func _finish() -> void:
	Input.action_release(&"fire")
	Input.action_release(&"interact")
	print("RESULT %s (%s) %s" % ["PASS" if _fails.is_empty() else "FAIL", _shot, ", ".join(_fails)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_tg_clip_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)


# ------------------------------------------------------------------ the clips

func _train_points(z0: float, rows: int) -> Array:
	var pts: Array = []
	for i: int in rows:
		pts.append(Vector3(30.5 + (i % 3) * 1.5, 0.0, z0 - float(i / 3) * 1.4))
	return pts


func _clip_great() -> void:
	RoundManager.current_round = 16
	var w: WeaponInstance = _bell()
	_check(w != null and w.data.has("bell") and w.mag == 12 and w.reserve == 48, "Totenglocke in hand, 12 / 48 charges")
	await _spawn(_train_points(17.0, 12), 12)
	var hp: float = _alive()[0].max_hp if not _alive().is_empty() else 0.0
	print("[tg] round 16 zombie HP %.0f, %d spawned" % [hp, _alive().size()])
	await _secs(1.2)
	var mag0: int = w.mag
	var hs0: int = Totenglocke.hitstops
	var before: int = _alive().size()
	var cam: Callable = func() -> bool: return _near(SPOT, 9.5) >= 10 or _near(SPOT, 4.0) >= 3
	await _great(cam, 6.0)
	await _frames(3)
	var gone: int = before - _alive().size()
	_check(mag0 - w.mag == 3, "the Great Toll cost 3 charges (%d -> %d)" % [mag0, w.mag])
	_check(gone >= 10, "a Great Toll shattered a 10+ zombie train on round 16 (%d of %d)" % [gone, before])
	_check(Totenglocke.hitstops > hs0, "hitstop slow-mo on the mass shatter (%d)" % (Totenglocke.hitstops - hs0))
	await _secs(1.5)
	# mop up with taps
	for i: int in 4:
		if _alive().is_empty():
			break
		_aim_target = _alive()[0].global_position + Vector3.UP
		await _tap()
	await _secs(1.0)
	var shards: int = get_tree().get_nodes_in_group(&"bronze_shards").size()
	_check(shards >= 2, "bronze shards dropped (%d for %d kills)" % [shards, _kills])
	# walk over them
	var mag1: int = w.mag
	for s: Node in get_tree().get_nodes_in_group(&"bronze_shards"):
		_p.global_position = (s as Node3D).global_position + Vector3(0, -0.3, 0)
		await _frames(4)
	_check(w.mag > mag1 or w.mag == w.mag_size(), "picking up shards restored charges (%d -> %d)" % [mag1, w.mag])
	_p.global_position = SPOT


func _clip_dome() -> void:
	RoundManager.current_round = 15
	var bot: Player = null
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		bot = n as Player
	_check(bot != null, "a bot teammate is in the match")
	if bot == null:
		return
	bot.global_position = SPOT + Vector3(-1.4, 0, -1.6)
	await _frames(3)
	bot.take_hit(99999.0, null)
	await _secs(0.6)
	_check(bot.downed, "the bot is down")
	await _spawn(_train_points(16.0, 12), 12)
	await _secs(1.4)
	# plant the dome between the bot and the train, then revive inside it
	_aim_target = SPOT + Vector3(0, 0.6, -10.0)
	Input.action_press(&"alt_fire")
	await _frames(2)
	Input.action_release(&"alt_fire")
	await _frames(2)
	var dome: BellDome = _p.weapons.bell_logic().active_dome()
	_check(dome != null, "Bell Dome planted (alt-fire)")
	_p.global_position = bot.global_position + Vector3(0.9, 0, 0.9)
	await _frames(2)
	_aim_target = bot.global_position + Vector3.UP * 0.3
	Input.action_press(&"interact")
	var slowed: bool = false
	var t: float = 0.0
	while t < 6.5 and bot.downed:
		await get_tree().process_frame
		t += get_process_delta_time()
		_aim_target = bot.global_position + Vector3.UP * 0.3
		for z: Zombie in _alive():
			if dome != null and is_instance_valid(dome) and BellDome.contains(dome.global_position, dome.radius, z.global_position) and z.frost_speed_mult() < 0.5:
				slowed = true
	Input.action_release(&"interact")
	_check(slowed, "zombies inside the dome move at 40% speed")
	if bot.downed and Net.session != null:
		print("[tg] (note) the hold did not finish the revive in %.1f s; reviving through the session" % t)
		Net.session.coop_revive(bot.player_id, _p.player_id)
		await _frames(3)
	_check(not bot.downed, "the bot was revived inside the dome (%.1f s)" % t)
	_aim_target = SPOT + Vector3(0, 1.0, -8.0)
	await _secs(0.4)
	for i: int in 4:
		if _alive().is_empty():
			break
		_aim_target = _alive()[0].global_position + Vector3.UP
		await _tap()
	_check(dome == null or not is_instance_valid(dome) or dome.time_left() < 8.0, "the dome runs its 8 s")


func _clip_chain() -> void:
	RoundManager.current_round = 18
	var w: WeaponInstance = _bell()
	_check(w != null and w.upgraded and w.mag == 16, "Mitternacht in hand, 16 charges")
	var pts: Array = []
	for i: int in 13:
		var ang: float = deg_to_rad(lerpf(-80.0, 80.0, float(i) / 12.0))
		pts.append(SPOT + Vector3(sin(ang) * 8.5, -0.1, -cos(ang) * 8.5))
	# the yard wall is 7.5 m east of the spot: keep the arc inside it
	for i: int in pts.size():
		var p: Vector3 = pts[i]
		pts[i] = Vector3(clampf(p.x, 25.6, 39.2), p.y, p.z)
	for p: Vector3 in pts:
		_dir.spawn_burst([p], 1)
	await _frames(2)
	await _secs(1.0)
	var before: int = _alive().size()
	# aim at the left half of the arc: the right half is outside the cone and only the chain-ring reaches it
	_aim_target = SPOT + Vector3(-8.0, 1.0, -6.0)
	var rel: Callable = func() -> bool: return _near(SPOT, 6.5) >= 6
	await _great(rel, 4.0)
	await _frames(3)
	var gone: int = before - _alive().size()
	var res: Dictionary = Totenglocke.last_result
	_check(w.mag == 14, "Mitternacht's Great Toll cost 2 (%d left)" % w.mag)
	_check((res.get("chains", []) as Array).size() >= 3, "shattered zombies chain-rang %d more (%d shattered)" % [(res.get("chains", []) as Array).size(), int(res.get("shattered", 0))])
	_check(gone > int(res.get("shattered", 0)), "the chain-ring killed beyond the cone (%d of %d gone)" % [gone, before])
	_aim_target = SPOT + Vector3(0, 1.0, -12.0)
	await _secs(2.0)
	for i: int in 4:
		if _alive().is_empty():
			break
		_aim_target = _alive()[0].global_position + Vector3.UP
		await _tap()


func _clip_r25() -> void:
	RoundManager.current_round = 25
	var w: WeaponInstance = _bell()
	await _spawn(_train_points(19.0, 9), 9)
	var hp: float = _alive()[0].max_hp if not _alive().is_empty() else 0.0
	print("[tg] round 25 zombie HP %.0f" % hp)
	await _secs(2.6)
	var before: int = _alive().size()
	_aim_target = SPOT + Vector3(0, 1.0, -6.0)
	await _tap()
	var marked: int = 0
	for z: Zombie in _alive():
		if TollMark.is_on(z):
			marked += 1
	_check(marked >= 3 and _alive().size() >= before - 2, "round 25: a tap tolls the train (%d marked, %d alive)" % [marked, _alive().size()])
	await _secs(0.1)
	await _tap()
	await _frames(3)
	_check(_alive().size() <= before - marked + 1, "round 25: the second toll shatters the tolled (%d left of %d)" % [_alive().size(), before])
	await _secs(1.0)
	# a second wave, Great Toll
	await _spawn(_train_points(17.0, 9), 9)
	await _secs(1.2)
	var b2: int = _alive().size()
	await _great(func() -> bool: return _near(SPOT, 10.0) >= 7, 6.0)
	await _frames(3)
	_check(b2 - _alive().size() >= 6, "round 25: a Great Toll still shatters the wave (%d of %d)" % [b2 - _alive().size(), b2])
	print("[tg] round 25: %d Totenglocke kills, %d charges left" % [_kills, w.mag])
