extends Node
## T-135 headless smoke: the map companions (MapCompanion, data/gravelight/companions.json). Silent, solo, a
## god-mode human. On each of Map 0, Kaltenbrunn, Totenhafen and Fernflug act I:
##   the companion is there, waiting on the navmesh within 6 m of its spot, in the zone its spot is in, not a match
##   player (the round size never counts it); the talk opens the choice card; GIVE A GUN takes the human's second
##   gun; it joins the squad (players + bots groups, a brain) and kills zombies beside the human; the next round it
##   brings its gift.
## Map 0 also: downed with nobody coming it bleeds out (60 s) and stays out cold. Fernflug: joined in act I, it
## arrives with you in act II (the carried flag) already with you and armed.
## Prints "[comp-smoke] ..." and "[comp-smoke] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map_companions.tscn [-- --only=trudi]

const CASES: Array = [
	["trudi", "res://gravelight/maps/map00_crossroads/map00.tscn"],
	["ammer", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"],
	["petersen", "res://gravelight/maps/map02_totenhafen/map02.tscn"],
	["jette", "res://gravelight/maps/map04_fernflug/map04a.tscn"],
]
const MAP04B: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"
const TIMEOUT: float = 1500.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _only: String = ""
var _kills: Dictionary = {}   # pid -> kills
var _tl: float = 0.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
	ProfileSave.path = "user://_qa_comp_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_comp_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	GLVO.always_pass_chance = true
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, _w: StringName, by: int) -> void:
		_kills[by] = int(_kills.get(by, 0)) + 1)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(msg: String) -> void:
	print("[comp-smoke] " + msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[comp-smoke] FAIL " + msg)


func _check(cond: bool, what: String) -> void:
	if cond:
		_note("ok   " + what)
	else:
		_fail(what)


func _finish() -> void:
	print("[comp-smoke] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _secs(s: float) -> void:
	var end: float = _t + s
	while _t < end:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float) -> bool:
	var end: float = _t + seconds
	while _t < end:
		if pred.call():
			return true
		await get_tree().physics_frame
	return bool(pred.call())


func _root() -> MapRoot:
	return _map as MapRoot


func _human() -> Player:
	return _root().player


func _comp(cid: String) -> MapCompanion:
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		if c.id == cid:
			return c
	return null


func _load(scene: String) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(scene) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 30.0)
	await _secs(1.0)
	GameState.god_mode = true
	_human().set_process_unhandled_input(false)


func _nearest_z(p: Vector3) -> float:
	var best: float = 999.0
	if _root().director != null:
		for z: Variant in _root().director.active_zombies():
			if is_instance_valid(z):
				best = minf(best, (z as Node3D).global_position.distance_to(p))
	return best


func _probe(mc: MapCompanion) -> String:
	if _root().director == null or mc.brain == null:
		return ""
	var best: Zombie = null
	var bd: float = 999.0
	for z: Variant in _root().director.active_zombies():
		if is_instance_valid(z) and (z as Node3D).global_position.distance_to(mc.player.global_position) < bd:
			bd = (z as Node3D).global_position.distance_to(mc.player.global_position)
			best = z as Zombie
	if best == null:
		return ""
	var e: Vector3 = mc.brain.aim.eye()
	var to: Vector3 = best.global_position - mc.player.global_position
	to.y = 0
	var ang: float = rad_to_deg(mc.brain.facing().slide(Vector3.UP).normalized().angle_to(to.normalized()))
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(e, best.global_position + Vector3.UP * 1.3, BotPerception.MASK_LOS, [mc.player.get_rid()])
	var hit: Dictionary = mc.player.get_world_3d().direct_space_state.intersect_ray(q)
	return " | z %.1fm angle %.0f eye=%s ray=%s targetable=%s" % [bd, ang, str(e.snapped(Vector3.ONE * 0.1)), (str((hit["collider"] as Node).get_path()) if not hit.is_empty() else "clear"), str(BotPerception.targetable(best))]


func _run() -> void:
	for c: Array in CASES:
		if _only != "" and _only != str(c[0]):
			continue
		await _case(str(c[0]), str(c[1]))
	_finish()


func _case(cid: String, scene: String) -> void:
	_note("---- %s on %s" % [cid, scene.get_file()])
	await _load(scene)
	var mc: MapCompanion = _comp(cid)
	var appear: int = int(MapCompanion.entry(cid).get("appear_round", 1))
	if appear > 1 and mc != null:
		_check(mc.player == null, "%s: not there before round %d" % [cid, appear])
		await _secs(3.0)
		while RoundManager.current_round < appear:
			RoundManager.advance_round()   # (the human here doesn't fight: skip ahead to the round it turns up)
		await _secs(1.0)
	_check(mc != null and mc.player != null, "%s: is on the map" % cid)
	var opened: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and not (n as BuyDoor).is_open:
			(n as BuyDoor).open(1)   # the way a player would have bought them to reach it
			opened += 1
	_note("%s: opened %d doors" % [cid, opened])
	if mc == null or mc.player == null:
		return
	var e: Dictionary = MapCompanion.entry(cid)
	var a: Array = e.get("spot", [0, 0, 0])
	var want: Vector3 = Vector3(float(a[0]), float(a[1]), float(a[2]))
	var at: Vector3 = mc.player.global_position
	var z_spot: StringName = ZoneVolume.zone_at(get_tree(), want + Vector3(0, 0.6, 0))
	var z_at: StringName = ZoneVolume.zone_at(get_tree(), at + Vector3(0, 0.6, 0))
	_note("%s waits at %s (spot %s), zone %s (spot zone %s)" % [cid, str(at.snapped(Vector3.ONE * 0.1)), str(want), z_at, z_spot])
	_check(at.distance_to(want) < 6.0, "%s: waits within 6 m of its spot" % cid)
	_check(z_at != &"" and (z_spot == &"" or z_at == z_spot), "%s: waits inside its zone" % cid)
	_check(mc.state == MapCompanion.State.WAITING, "%s: waiting" % cid)
	_check(not mc.player.is_in_group(&"players"), "%s: no match player while waiting" % cid)
	await _secs(2.0)
	_check(is_equal_approx(mc.player.global_position.y, at.y) or absf(mc.player.global_position.y - at.y) < 0.6, "%s: stands (no fall through the floor)" % cid)
	# the talk: stand beside it with two guns, the choice card opens, GIVE A GUN
	var h: Player = _human()
	h.global_position = mc.player.global_position + Vector3(1.2, 0.2, 0.0)
	h.velocity = Vector3.ZERO
	h.weapons.give_weapon(&"thompson")
	await _secs(0.5)
	_check(mc.can_talk(h), "%s: the human can talk to it" % cid)
	mc.on_talk(h)
	await _secs(0.3)
	_check(mc._choice != null, "%s: the choice card opens" % cid)
	if mc._choice != null:
		mc._choice._close(true)
	await _secs(0.3)
	_check(mc.state == MapCompanion.State.JOINED, "%s: joined" % cid)
	_check(mc.player.is_in_group(&"players") and mc.brain != null, "%s: a squad bot with a brain" % cid)
	_check(not mc.player.weapons.slots.is_empty() and mc.player.weapons.current().id == &"thompson", "%s: carries the Thompson" % cid)
	_check(GameState.input_blocked == false, "%s: input free again" % cid)
	# it fights: the human walks back to the start (as a player would, the companion following) and holds there
	var pid: int = mc.player.player_id
	h.global_position = _root().spawn_transform(1).origin
	h.velocity = Vector3.ZERO
	await _until(func() -> bool: return mc.player.global_position.distance_to(h.global_position) < 6.0, 40.0)
	_check(mc.player.global_position.distance_to(h.global_position) < 6.0, "%s: follows you back to the start" % cid)
	var r0: int = RoundManager.current_round
	var g0: int = mc.events.size()
	var tr: Callable = func() -> void:
		var w: WeaponInstance = mc.player.weapons.current()
		_note("  trace t=%.0f %s hp=%.0f down=%s action=%s pos=%s mag=%s/%s dist_h=%.1f zombies=%d known=%d nearest_z=%.1f tgt=%s blocks=%s" % [_t, cid, mc.player.hp, str(mc.player.downed),
			mc.brain.action if mc.brain != null else "-", str(mc.player.global_position.snapped(Vector3.ONE * 0.1)),
			str(w.mag if w != null else -1), str(w.reserve if w != null else -1), mc.player.global_position.distance_to(h.global_position),
			_root().director.active_zombies().size() if _root().director != null else -1,
			mc.brain.perception.known.size() if mc.brain != null else -1, _nearest_z(mc.player.global_position), str(mc.brain.aim.target != null) if mc.brain != null else "-", str(mc.brain.aim.fire_blocks) if mc.brain != null else "-"] + _probe(mc))
	_tl = _t
	var fought: bool = await _until(func() -> bool:
		if _t - _tl > 10.0 and OS.get_environment("COMP_TRACE") != "":
			_tl = _t
			tr.call()
		return int(_kills.get(pid, 0)) >= 1, 240.0)
	_check(fought, "%s: kills zombies beside you (%d)" % [cid, int(_kills.get(pid, 0))])
	await _until(func() -> bool: return RoundManager.current_round > maxi(r0, 1), 200.0)
	var gifted: bool = false
	for i: int in range(g0, mc.events.size()):
		if mc.events[i].begins_with("gift:"):
			gifted = true
	_note("%s events: %s" % [cid, ",".join(mc.events)])
	_check(gifted or str(e.get("gift", "")) == "grenade" and h.weapons.grenades >= h.weapons.grenade_max(), "%s: brought its gift at the round start" % cid)
	if cid == "trudi":
		mc.player.take_hit(9999.0, null)
		await _secs(0.5)
		_check(mc.player.downed, "trudi: downed")
		h.global_position = mc.player.global_position + Vector3(30, 0, 0)   # nobody comes
		var fell: bool = await _until(func() -> bool: return mc.state == MapCompanion.State.FALLEN, 80.0)
		_check(fell, "trudi: bled out, out cold")
	if cid == "jette":
		_check(MapCompanion.flag_on(GameState.flags, "jette_with_you"), "jette: the carried flag is set")
		var keep: Dictionary = Campaign.carried_flags(GameState.flags, GLData.table("campaign").get("carry_flags", []))
		_check(keep.has(&"jette_with_you") or keep.has("jette_with_you"), "jette: campaign.json carries her flag")
		_note("jette: loading act II")
		await _load(MAP04B)
		_note("jette: act II loaded")
		for k: Variant in keep.keys():
			GameState.flags[StringName(str(k))] = keep[k]   # (what Campaign.restore_flags does on an arrival)
		MapCompanion.attach(_root())
		var j2: MapCompanion = _comp("jette")
		_check(j2 != null and j2.state == MapCompanion.State.JOINED, "jette: arrives with you in act II")
		_check(j2 != null and not j2.player.weapons.slots.is_empty(), "jette: still armed")
