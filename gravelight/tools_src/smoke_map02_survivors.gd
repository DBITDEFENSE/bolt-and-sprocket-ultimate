extends Node
## T-273: Totenhafen's survivors in the torpedo store (InnSurvivors / InnSurvivor, data map02_survivors.json), the
## same steps as smoke_inn_survivors on Map 0:
##   1. before the Torpedo Workshop's door they are not in the world (hidden, no prompt); their hiding spots in the
##      warhead cage and their posts are on the navmesh; nothing on them collides
##   2. buying the workshop door reveals them in the cage, cowering; near them a line plays; a shot close by makes a
##      hiding one flinch
##   3. a zombie in the cage goes for the hiding survivors, kills one, who warns (a squad line, M2_SURV_TURN) and rises
##      as a sailor
##   4. a player pays to arm the other: they walk out of the cage to their post and shoot a zombie in the workshop
##   5. an armed one knocked to 0 is downed, not dead, and a player helps them back up
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map02_survivors.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const TIMEOUT: float = 200.0

var _map: MapRoot
var _t: float = 0.0
var _step: String = "load"
var _step_t: float = 0.0
var _fails: PackedStringArray = []
var _notes: PackedStringArray = []
var _ss: InnSurvivors = null
var _player: Player = null
var _mine: Array[Zombie] = []
var _lines: Array = []   # [line id, speaker]
var _victim: InnSurvivor = null
var _armed: InnSurvivor = null
var _z2: Zombie = null
var _z2_hp0: float = 0.0
var _scrip0: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_m2_survivors_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m2_survivors_settings.cfg"
	GameState.bot_count = 0
	GameState.god_mode = true
	Campaign.reset()
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.vo_line_started.connect(func(id: StringName, sp: StringName, _tx: String, _d: float) -> void:
		_lines.append([String(id), String(sp)]))


func _go(s: String) -> void:
	print("[m2surv] %.1f s: %s" % [_t, s])
	_step = s
	_step_t = 0.0


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_t += delta
	_step_t += delta
	GameState.god_mode = true
	if _t > TIMEOUT:
		_fail("timed out in step %s" % _step)
		_end()
		return
	if RoundManager.current_round >= 2:
		RoundManager.to_spawn = 0
		RoundManager.set_hold(&"smoke_survivors", true)
		_cull()
	match _step:
		"load":
			if _step_t > 0.5:
				_ss = _map.find_child("InnSurvivors", true, false) as InnSurvivors
				_player = _map.player
				if _ss == null or _ss.survivors.size() != 2:
					_fail("no InnSurvivors with 2 survivors")
					_end()
					return
				_check_hidden()
				RoundManager.debug_set_round(2)
				_go("round2")
		"round2":
			if RoundManager.current_round == 2 and RoundManager.state == RoundManager.State.ROUND:
				var door: BuyDoor = _door()
				Economy.grant(1, 5000)
				_scrip0 = Economy.get_scrip(1)
				door.interact(_player)
				_go("revealed")
		"revealed":
			if _step_t > 0.3:
				for s: InnSurvivor in _ss.survivors.values():
					if s.state != InnSurvivor.State.HIDING or not s.visible or s.body.pose != &"cower":
						_fail("%s after the door: state %d visible %s pose %s" % [s.sid, s.state, str(s.visible), s.body.pose])
					if s.get_prompt(_player).find("arm") < 0:
						_fail("%s: no arm prompt (%s)" % [s.sid, s.get_prompt(_player)])
				print("[m2surv] prompt: %s" % (_ss.survivors["kahlke"] as InnSurvivor).get_prompt(_player))
				_player.global_position = Vector3(50.0, 0.05, 20.5)
				_lines.clear()
				_go("scared")
		"scared":
			if _said_any(["KAH", "PIE", "KAHLKE", "PIETSCH"]):
				print("[m2surv] heard: %s" % str(_lines))
				var k: InnSurvivor = _ss.survivors["pietsch"]
				GLBus.weapon_fired.emit(1, &"m1911", false, k.global_position + Vector3(2, 1.4, 3), Vector3.FORWARD)
				if float(k.body.get("_flinch")) < 0.5:
					_fail("pietsch did not flinch at a shot close by")
				_player.global_position = Vector3(38.0, 0.05, 24.0)
				_spawn(Vector3(54.4, 0.0, 19.6))
				_go("victim")
			elif _step_t > 20.0:
				_fail("no scared / reveal line near them (%s)" % str(_lines))
				_go("victim")
		"victim":
			for s2: InnSurvivor in _ss.survivors.values():
				if s2.state == InnSurvivor.State.DEAD and _victim == null:
					_victim = s2
					print("[m2surv] %s killed while hiding after %d swipes" % [s2.sid, s2.swipes_taken])
					_go("rise")
			if _victim == null and _step_t > 40.0:
				_fail("no hiding survivor was killed by the zombie in their room (prey: %s)" % str(_mine.map(func(z: Zombie) -> String: return str(z.prey))))
				_go("arm")
		"rise":
			if _victim.state == InnSurvivor.State.RISEN:
				if not _said_id("SURV_TURNING"):
					_fail("%s rose without the turning warning" % _victim.sid)
				if _victim.risen_zombie == null or not _victim.risen_zombie.is_active():
					_fail("%s rose but no zombie stands there" % _victim.sid)
				else:
					_mine.append(_victim.risen_zombie)
					print("[m2surv] %s rose as a zombie (state %s)" % [_victim.sid, str(Zombie.State.keys()[_victim.risen_zombie.state])])
				_kill_mine()
				_go("arm")
			elif _step_t > 20.0:
				_fail("%s never rose (state %d)" % [_victim.sid, _victim.state])
				_kill_mine()
				_go("arm")
		"arm":
			if _step_t < 1.0:
				return
			for s3: InnSurvivor in _ss.survivors.values():
				if s3.state == InnSurvivor.State.HIDING:
					_armed = s3
					break
			if _armed == null:
				_fail("nobody left to arm")
				_end()
				return
			var before: int = Economy.get_scrip(1)
			_armed.interact(_player)
			var paid: int = before - Economy.get_scrip(1)
			if paid != int((_ss.cfg["arm"] as Dictionary)["cost"]):
				_fail("arming cost %d" % paid)
			if _armed.state != InnSurvivor.State.WALKING:
				_fail("%s did not take the rifle (state %d)" % [_armed.sid, _armed.state])
			_go("to_post")
		"to_post":
			if _armed.state == InnSurvivor.State.ARMED:
				var post: Vector3 = InnSurvivor._v3(_armed.row["post"])
				print("[m2surv] %s at the post %s (%.1f m off) after %.1f s" % [_armed.sid, str(_armed.global_position), _armed.global_position.distance_to(post), _step_t])
				if _armed.global_position.distance_to(post) > 0.6:
					_fail("%s holds %s, not the post" % [_armed.sid, str(_armed.global_position)])
				_z2 = _spawn(Vector3(40.0, 0.0, 20.5))
				_z2_hp0 = _z2.hp if _z2 != null else 0.0
				_go("shoot")
			elif _step_t > 20.0:
				_fail("%s never reached the post (state %d at %s)" % [_armed.sid, _armed.state, str(_armed.global_position)])
				_go("downed")
		"shoot":
			if _z2 == null:
				_fail("could not spawn the hall zombie")
				_go("downed")
				return
			var hurt: bool = not _z2.is_active() or _z2.hp < _z2_hp0
			if _armed.shots > 0 and hurt:
				print("[m2surv] %s fired %d shots, the hall zombie %s (kills %d)" % [_armed.sid, _armed.shots, "is dead" if not _z2.is_active() else "is hit", _armed.kills])
				_kill_mine()
				_go("downed")
			elif _step_t > 25.0:
				_fail("%s did not shoot the hall zombie (shots %d, zombie hp %.0f of %.0f, state %s)" % [_armed.sid, _armed.shots, _z2.hp, _z2_hp0, str(Zombie.State.keys()[_z2.state])])
				_kill_mine()
				_go("downed")
		"downed":
			if _step_t < 0.5:
				return
			if _armed == null or _armed.state != InnSurvivor.State.ARMED:
				_end()
				return
			_armed.hp = 10.0
			_armed.struck(null)
			if _armed.state != InnSurvivor.State.DOWNED:
				_fail("an armed survivor at 0 hp should be downed (state %d)" % _armed.state)
			if _armed.get_prompt(_player).find("help") < 0:
				_fail("no help-up prompt on the downed survivor")
			_armed.interact(_player)
			if _armed.state != InnSurvivor.State.ARMED:
				_fail("helped up, they should hold again (state %d)" % _armed.state)
			_end()


func _door() -> BuyDoor:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if (n as BuyDoor).door_id == &"door_workshop":
			return n as BuyDoor
	return null


func _check_hidden() -> void:
	var nav: RID = _map.get_world_3d().navigation_map
	for s: InnSurvivor in _ss.survivors.values():
		if s.visible or s.state != InnSurvivor.State.HIDDEN or s.get_prompt(_player) != "" or s.is_catchable():
			_fail("%s is in the world before the workshop door" % s.sid)
		for key: String in ["hide", "post"]:
			var p: Vector3 = InnSurvivor._v3(s.row[key])
			var c: Vector3 = NavigationServer3D.map_get_closest_point(nav, p)
			if Vector2(c.x - p.x, c.z - p.z).length() > 0.5 or absf(c.y - p.y) > 0.75:   # the baked mesh floats ~0.5 m over the floor
				_fail("%s %s %s is off the navmesh (closest %s)" % [s.sid, key, str(p), str(c)])
		for n: Node in s.find_children("*", "CollisionObject3D", true, false):
			if not (n is Area3D):
				_fail("%s has a collider %s" % [s.sid, n.name])
	print("[m2surv] hidden before the workshop door, spots on the navmesh, nothing solid on them")


func _spawn(at: Vector3) -> Zombie:
	var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
	var spec: Dictionary = RoundManager.take_extra_spawn()
	var z: Zombie = dir.activate_reserved(spec, at)
	if z == null:
		RoundManager.release_alive(1)
		return null
	z.global_position = at
	_mine.append(z)
	return z


## Only the smoke's zombies (and survivors' risers) walk about.
func _cull() -> void:
	var dir: ZombieDirector = _map.get_node_or_null("ZombieDirector") as ZombieDirector
	if dir == null:
		return
	for z: Zombie in dir.active_zombies():
		if _mine.has(z):
			continue
		var is_riser: bool = false
		for s: InnSurvivor in (_ss.survivors.values() if _ss != null else []):
			if s.risen_zombie == z:
				is_riser = true
		if not is_riser:
			z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")


func _kill_mine() -> void:
	for z: Zombie in _mine:
		if is_instance_valid(z) and z.is_active():
			z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
	_mine.clear()


func _said_any(speakers: Array) -> bool:
	for l: Array in _lines:
		if speakers.has(str(l[1])):
			return true
	return false


func _said_id(id: String) -> bool:
	for l: Array in _lines:
		if str(l[0]) == id:
			return true
	return false


func _fail(s: String) -> void:
	_fails.append(s)
	print("[m2surv] FAIL ", s)


func _end() -> void:
	if _fails.is_empty():
		print("[m2surv] RESULT PASS")
	else:
		print("[m2surv] RESULT FAIL (%d): %s" % [_fails.size(), "; ".join(_fails)])
	set_physics_process(false)
	get_tree().quit(0 if _fails.is_empty() else 1)
