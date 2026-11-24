extends Node
## T-271 headless smoke: Map 0's match systems on the other maps, each on its own map, loaded for real (solo, a
## god-mode human, a scratch profile, silent).
##   The horse and its tack (every map but Map 0 with "horses" rows: Kaltenbrunn, Thalbach, Groom Lake): it stands
##     tied at its rail in its first zone with its hooves on the ground and nothing solid in its body; the rail and
##     the chest stand on the floor, clear of colliders, on no zombie layer; the navmesh brings a player from the
##     spawn to its side; Use mounts; ridden across open ground it moves, stays in its zones and on its level; the
##     rider gets down onto the navmesh; a piece of tack is sold at the chest; left alone it walks back to its rail.
##   The raid only (every map but Map 0 whose "sherman_event" block says "tank": false: Totenhafen round 30; T-272
##     gave Kaltenbrunn the whole event, walked by smoke_map01_sherman): no tank and no round held for one, the raid's round is reserved; the console refuses
##     the tank's commands; each shelter point is a shelter and the navmesh reaches it from the open; open ground
##     is not a shelter; the round's start brings the dive bomber (where the block names its target) and then the
##     warning with this map's own words; bombs fall, every one on open ground in a bomb zone and never on a roof;
##     a player under a roof is never hurt; the all-clear ends it. (The countdown and the bombing are cut short.)
##   Thalbach's sky: the three sky-war kinds copied from Map 0 fire without a Landscape (bombers, fighters, the far gun).
##   The opening and the survivors read their file by map: Map 0's nodes find map00_opening / map00_survivors.
## The arms lockers of all seven maps are walked by smoke_weapon_locker.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map_detail.tscn [-- --only=map01]
## Prints "[detail] ..." and "[detail] RESULT: PASS/FAIL (n checks)"; exit code 0/1.

const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const SOLID: int = 1 | (1 << 5) | (1 << 8)   # world, barricades, doors
const TIMEOUT: float = 1100.0

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0
var _key: String = ""
var _held: Array[int] = []           # the rounds events had reserved when the map had loaded


func _ready() -> void:
	ProfileSave.path = "user://_qa_detail_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.save_profile()
	GLSettings.path = "user://_qa_detail_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(c: bool, what: String) -> void:
	_checks += 1
	print("[detail] %s %s: %s" % ["ok  " if c else "FAIL", _key, what])
	if not c:
		_fails.append("%s: %s" % [_key, what])


func _finish() -> void:
	print("[detail] RESULT: %s (%d checks, %d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size()])
	for f: String in _fails:
		print("[detail]   - " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


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


func _space() -> PhysicsDirectSpaceState3D:
	return _map.get_world_3d().direct_space_state


func _nav() -> RID:
	return _map.get_world_3d().navigation_map


## Flat metres from `p` to the navmesh on its own level (INF: none within a metre of its height).
func _nav_gap(p: Vector3) -> float:
	var q: Vector3 = NavigationServer3D.map_get_closest_point(_nav(), p + Vector3.UP * 0.3)
	return Vector2(q.x - p.x, q.z - p.z).length() if absf(q.y - p.y) < 1.0 else INF


func _floor_y(p: Vector3) -> float:
	var hit: Dictionary = _space().intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.8, p + Vector3.DOWN * 2.0, 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else INF


## Colliders of the world, the doors and the barricades inside a box at `xf` (names).
func _in_box(xf: Transform3D, size: Vector3) -> PackedStringArray:
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = size
	var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sq.shape = bx
	sq.transform = xf
	sq.collision_mask = SOLID
	var out: PackedStringArray = []
	for h: Dictionary in _space().intersect_shape(sq, 6):
		out.append(str((h["collider"] as Node).name) if h["collider"] is Node else "?")
	return out


## True when the navmesh path from `a` ends within `tol` (flat) of `b`.
func _path_reaches(a: Vector3, b: Vector3, tol: float = 1.2) -> bool:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_nav(), a, b, true, ClimbLink.WALK_MASK)
	if path.is_empty():
		return false
	var e: Vector3 = path[path.size() - 1]
	return Vector2(e.x - b.x, e.z - b.z).length() <= tol and absf(e.y - b.y) < 1.2


func _load(key: String) -> void:
	_key = key
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(SCENES[key]) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 30.0)
	await _secs(1.5)
	_held.clear()
	for r: int in range(1, 61):
		if RoundManager.is_reserved(r):
			_held.append(r)   # (read before stop(), which forgets them)
	RoundManager.stop()
	GameState.god_mode = true
	_p = _root().player
	_p.set_process_unhandled_input(false)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and not (n as BuyDoor).is_open:
			(n as BuyDoor).open(1)
	var waited: int = 0
	while waited < 600 and NavigationServer3D.map_get_random_point(_nav(), 0x7FFFFFFF, true) == Vector3.ZERO:
		await get_tree().physics_frame
		waited += 1
	await _secs(0.5)


static func _json(key: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s.json" % key)


func _run() -> void:
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	for key: String in SCENES:
		if key == "map00" or (only != "" and only != key):
			continue
		var d: Dictionary = _json(key)
		var horses: Array = d.get("horses", [])
		var ev: Dictionary = d.get("sherman_event", {}) if d.get("sherman_event", {}) is Dictionary else {}
		var raid_only: bool = not ev.is_empty() and not ShermanEvent.block_has_tank(ev)
		var sky: bool = key == "map04a"
		if horses.is_empty() and not raid_only and not sky:
			continue
		await _load(key)
		if not horses.is_empty():
			await _horse(horses[0])
		if sky:
			await _sky()
		if raid_only:
			await _raid(ev)
	if only == "" or only == "map00":
		await _load("map00")
		_opening()
	_finish()


# ================================================================== the horse

func _horse(row: Dictionary) -> void:
	var hs: Array = get_tree().get_nodes_in_group(&"horses")
	_check(hs.size() == 1, "one horse in the scene (%d)" % hs.size())
	if hs.is_empty():
		return
	var h: Horse = hs[0] as Horse
	var zones: Array = row.get("zones", [])
	for z: Variant in zones:
		GameState.open_zone(StringName(str(z)))
	var home: Vector3 = h.home_pos
	var zone_here: String = String(ZoneVolume.zone_at(get_tree(), home + Vector3.UP * 0.6))
	_check(h.mode == Horse.Mode.TIED and h.global_position.distance_to(home) < 0.3, "it stands tied at its place %s" % str(home))
	_check(zones.has(zone_here) and zone_here == str(zones[0]), "in its first zone (%s)" % zone_here)
	_check(absf(_floor_y(home) - home.y) < 0.12 and absf(h.global_position.y - home.y) < 0.15 and h.is_on_floor(), "its hooves are on the ground (floor %.2f, y %.2f)" % [_floor_y(home), h.global_position.y])
	var in_body: PackedStringArray = _in_box(Transform3D(Basis(Vector3.UP, h.home_yaw), home + Vector3.UP * 1.0), Vector3(0.9, 1.5, 2.5))
	_check(in_body.is_empty(), "nothing solid in its body %s" % str(in_body))
	_check(_nav_gap(home) < 0.6, "it stands on walkable ground (%.2f m from the navmesh)" % _nav_gap(home))
	_check(h.call("_may_stand", home) and h.call("_may_stand", home + Vector3.UP * 0.0 - h.global_transform.basis.z * 1.3), "its own rule lets it stand there")
	# the rail and the chest
	var rail: Node3D = _map.find_child("HitchingRail", true, false) as Node3D
	_check(rail != null and rail.global_position.distance_to(h.rail_pos) < 0.05, "the hitching rail is built at %s" % str(h.rail_pos))
	if rail != null:
		var in_rail: PackedStringArray = _in_box(rail.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.65, 0)), Vector3(2.4, 1.0, 0.14))
		_check(in_rail.is_empty() and absf(_floor_y(h.rail_pos) - h.rail_pos.y) < 0.12, "the rail stands on the floor, in nothing %s" % str(in_rail))
		var fwd: Vector3 = -Basis(Vector3.UP, h.home_yaw).z
		_check(fwd.dot((h.rail_pos - home).normalized()) > 0.95, "the horse faces its rail")
		var behind: PackedStringArray = _in_box(Transform3D(Basis(Vector3.UP, deg_to_rad(h.rail_yaw)), h.rail_pos + Vector3.UP * 1.2) * Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.2)), Vector3(2.0, 1.0, 0.5))
		_check(not behind.is_empty(), "a wall stands behind the rail %s" % str(behind))
	var rb: Node = _map.find_child("RailCollider", true, false)
	_check(rb is StaticBody3D and ((rb as StaticBody3D).collision_layer & (Zombie.LAYER_WORLD | Zombie.LAYER_ZBODY)) == 0, "the rail's collider is off the zombies' layers (navmesh-safe)")
	var t: Horse.HorseTack = h.tack
	_check(t != null and t.is_inside_tree(), "the tack chest stands by the rail")
	# every other machine, door, window and spawn keeps its distance
	var nearest: float = INF
	var nearest_name: String = ""
	for g: StringName in [&"interactables", &"zombie_spawns", &"doors", &"barricades", &"perk_spots", &"crate_spots"]:
		for n: Node in get_tree().get_nodes_in_group(g):
			var n3: Node3D = n as Node3D
			if n3 == null or n3 == h or h.is_ancestor_of(n3) or n3 == t or (t != null and t.is_ancestor_of(n3)) or absf(n3.global_position.y - home.y) > 3.0:
				continue
			var dd: float = minf(Vector2(n3.global_position.x - home.x, n3.global_position.z - home.z).length(), Vector2(n3.global_position.x - h.rail_pos.x, n3.global_position.z - h.rail_pos.z).length())
			if dd < nearest:
				nearest = dd
				nearest_name = String(n3.name)
	_check(nearest > 2.5, "nothing else within 2.5 m of the horse or its rail (nearest: %s at %.1f m)" % [nearest_name, nearest])
	# from the spawn to its side
	var side: Vector3 = h.global_transform * Vector3(-1.3, 0.05, 0.2)
	var spawn: Vector3 = _root().spawn_transform(1).origin
	_check(_path_reaches(spawn, side), "the navmesh leads from the spawn to its side (%.0f m away)" % spawn.distance_to(side))
	# mount
	var r: Dictionary = HorseRules.block("ride")
	_p.global_position = side
	_p.rotation.y = h.rotation.y - PI * 0.5
	_p.velocity = Vector3.ZERO
	await _frames(6)
	_check(_p.global_position.distance_to(side) < 0.4, "a player can stand beside it (moved %.2f m)" % _p.global_position.distance_to(side))
	_check(h.use.can_interact(_p) and h.use.get_prompt(_p).contains("ride"), "usable from beside it (\"%s\")" % h.use.get_prompt(_p))
	_p.use_interactable(h.use)
	await _secs(float(r.get("mount_s", 1.0)) + 0.4)
	_check(h.mode == Horse.Mode.RIDDEN and h.rider == _p and h.seated(), "Use mounts: the rider is in the saddle")
	# ridden across open ground: away from its wall
	var back: Vector3 = Basis(Vector3.UP, h.home_yaw).z   # away from the rail
	var start: Vector3 = home + back * 5.0
	h.global_position = start
	h.rotation.y = h.home_yaw + PI
	h.speed = 0.0
	h.pace = 0.0
	h.steer = 0.0
	h.set("_last_ok", start)
	h.set("_prev_pos", start)
	await _frames(3)
	h.input_override = Vector3(0, 1, 0)
	var out: int = 0
	for i: int in 150:
		await get_tree().physics_frame
		if not zones.has(String(ZoneVolume.zone_at(get_tree(), h.global_position + Vector3.UP * 0.6))) or absf(h.global_position.y - home.y) > 0.5:
			out += 1
	h.input_override = Vector3.ZERO
	var rode: float = Vector2(h.global_position.x - start.x, h.global_position.z - start.z).length()
	_check(rode > 2.0 and out == 0, "ridden 2.5 s it went %.1f m over open ground, in its zones, on its level (%d frames out, %d refusals)" % [rode, out, h.refusals])
	await _secs(1.0)
	# down again
	h.dismount_wanted = true
	await _secs(float(r.get("dismount_s", 0.7)) + 0.6)
	_check(h.rider == null and _p.carry == null and h.mode == Horse.Mode.LOOSE, "the rider gets down; the horse stands loose")
	_check(_nav_gap(_p.global_position) < 0.7 and absf(_p.global_position.y - home.y) < 0.5, "set down on the navmesh beside it (%s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
	# left alone it walks home
	var waited: bool = await _until(func() -> bool: return h.mode == Horse.Mode.TIED, 75.0)
	_check(waited and Vector2(h.global_position.x - home.x, h.global_position.z - home.z).length() < 0.7, "left alone it walks back to its rail (mode %d, %.2f m off)" % [h.mode, Vector2(h.global_position.x - home.x, h.global_position.z - home.z).length()])
	# the tack chest
	if t != null:
		var rows: Array = HorseRules.upgrade_rows()
		var tp: Vector3 = t.global_position
		_check(absf(_floor_y(tp) - tp.y) < 0.12 and _in_box(Transform3D(t.global_transform.basis, tp + Vector3.UP * 0.5), Vector3(0.7, 0.5, 0.45)).is_empty(), "the chest stands on the floor, in nothing")
		_check(t.find_children("*", "CollisionObject3D", true, false).size() == 1, "its only body is the Use area (nothing in a zombie's path)")
		var front: Vector3 = t.global_transform * Vector3(0.0, 0.05, 1.15)
		_p.global_position = front
		_p.rotation.y = t.global_rotation.y
		_p.velocity = Vector3.ZERO
		_p.set("_pitch", -0.15)
		await _frames(8)
		_check(_p.global_position.distance_to(front) < 0.3 and _nav_gap(_p.global_position) < 0.7, "a player can stand in front of it, on the navmesh (%s)" % str(_p.global_position.snapped(Vector3.ONE * 0.01)))
		Economy.grant_raw(_p.player_id, 5000)
		var before: int = Economy.get_scrip(_p.player_id)
		var first: Dictionary = rows[0]
		_check(t.can_interact(_p) and t.get_prompt(_p).contains(str(first["name"])), "on sale: \"%s\"" % t.get_prompt(_p))
		_p.use_interactable(t)
		await _frames(4)
		_check(h.upgrades == [str(first["id"])] and before - Economy.get_scrip(_p.player_id) == int(first["cost"]), "bought: %s for %d Scrip" % [first["name"], before - Economy.get_scrip(_p.player_id)])


# ================================================================== Thalbach's sky

func _sky() -> void:
	var amb: MapAmbience = _map.get_node_or_null(^"MapAmbience") as MapAmbience
	_check(amb != null and amb.land == null, "the living world runs without a Landscape")
	if amb == null:
		return
	for k: String in ["bombers", "fighters", "machine_guns", "intensity"]:
		_check(amb.cfg.has(k), "the file has Map 0's \"%s\"" % k)
	_check((amb.get("_timers") as Dictionary).has("bombers") and (amb.get("_timers") as Dictionary).has("fighters") and (amb.get("_timers") as Dictionary).has("machine_guns"), "the three kinds are on their timers")
	var f0: int = amb.flights.size()
	amb.call("_fire_event", "bombers")
	amb.call("_fire_event", "fighters")
	amb.call("_fire_event", "machine_guns")
	await _frames(20)
	_check(amb.flights.size() >= f0 + 2, "a bomber stream and a fighter pair are in the air (%d flights)" % amb.flights.size())
	_check(int(amb.counts.get("bombers", 0)) >= 1 and int(amb.counts.get("fighters", 0)) >= 1 and int(amb.counts.get("mg", 0)) >= 1, "counted: %s" % str(amb.counts))
	var low: float = INF
	for fl: SkyFlight in amb.flights:
		if is_instance_valid(fl):
			for pl: Node3D in fl.planes:
				if is_instance_valid(pl):
					low = minf(low, pl.global_position.y)
	_check(low > 30.0, "every flight is over the works' roofs (the hall's crane rails are at 15 m; the lowest flies at %.0f m)" % low)
	_check(int(amb.counts.get("act1_bell", 0)) >= 0 and amb.cfg.has("act1"), "Thalbach's own act1 kinds are still there")


# ================================================================== the raid only

func _raid(block: Dictionary) -> void:
	var ev: ShermanEvent = _map.get_node_or_null(^"ShermanEvent") as ShermanEvent
	_check(ev != null and not ev.has_tank, "the event is attached, without a tank")
	if ev == null:
		return
	var raid: AirRaid = ev.raid
	var sr: int = int(block.get("stuka_round", 40))
	_check(ev.stuka_round == sr and _held.has(sr), "round %d is the raid's (reserved: %s)" % [sr, str(_held)])
	_check(sr == 30 or block.has("arrive_round") or not _held.has(30) or not (_json(_key).get("round_bosses", []) as Array).is_empty(), "no round is held for a tank's arrival")
	_check(ev.tank == null and ev.phase == ShermanEvent.Phase.IDLE, "no tank stands on the map")
	_check(str(ev.call("_cmd", PackedStringArray(["30"]))).begins_with("No Sherman") and ev.tank == null, "the console's tank commands are refused")
	ev.call("_on_round_started", 30 if sr != 30 else 31, false)
	_check(ev.phase == ShermanEvent.Phase.IDLE and ev.tank == null, "another round's start brings nothing")
	_check(str(raid.cfg.get("warn_small", "")) == str((block.get("raid", {}) as Dictionary).get("warn_small", "?")) and not str(raid.cfg.get("warn_small", "")).contains("INN"), "the warning is this map's own: \"%s\"" % str(raid.cfg.get("warn_small", "")))
	_check(float(raid.cfg.get("radius", 0.0)) == float((ShermanEvent.table()["raid"] as Dictionary)["radius"]), "the bombs' numbers are sherman.json's")
	# the shelters
	var open_pt: Vector3 = Vector3.INF
	for k: int in 400:
		var q: Vector3 = NavigationServer3D.map_get_random_point(_nav(), 0x7FFFFFFF, true)
		# (open ground a player can walk to: the navmesh also has islands nobody reaches, a roof or a fenced corner)
		if raid.call("_bomb_ok", q, block.get("bomb_zones", []), []) and _path_reaches(_root().spawn_transform(1).origin, q):
			open_pt = q
			break
	_check(open_pt.is_finite() and not raid.is_sheltered(open_pt), "open ground in a bomb zone is no shelter (%s)" % str(open_pt.snapped(Vector3.ONE * 0.1)))
	var pts: Array = block.get("shelter_points", [])
	_check(pts.size() >= 2, "%d shelter points for the bots" % pts.size())
	for a: Variant in pts:
		var sp: Vector3 = ClimbLink._v3(a)
		var zone: String = String(ZoneVolume.zone_at(get_tree(), sp + Vector3.UP * 0.6))
		_check(raid.is_sheltered(sp) and _nav_gap(sp) < 0.5, "%s is a shelter on the navmesh (zone %s, %s)" % [str(sp), zone, "a roof over it" if raid.roof_over(sp) else "by its zone"])
		_check(open_pt.is_finite() and _path_reaches(open_pt, sp), "the navmesh leads there from the open")
	for z: Variant in block.get("bomb_zones", []):
		_check(not (block.get("shelter_zones", []) as Array).has(z), "%s is bombed, so it is no shelter zone" % str(z))
	# the round
	_p.global_position = ClimbLink._v3(pts[0]) + Vector3.UP * 0.05
	_p.velocity = Vector3.ZERO
	GameState.god_mode = false
	await _frames(10)
	var hp0: float = _p.hp
	_check(raid.is_sheltered(_p.global_position), "the player waits it out under the first shelter")
	raid.cfg["countdown"] = 3.0
	raid.cfg["duration"] = 14.0
	var roofless_bot_goal: Vector3 = Vector3.INF
	for nm0: Variant in block.get("stuka_hit_show", []):
		var hidden: Node3D = _map.find_child(str(nm0), true, false) as Node3D
		_check(hidden != null and not hidden.is_visible_in_tree(), "%s waits hidden for the bomb" % str(nm0))
	ev.call("_on_round_started", sr, false)
	if block.has("stuka_target"):
		_check(ev.phase == ShermanEvent.Phase.STUKA, "round %d: the dive bomber first" % sr)
		var came: bool = await _until(func() -> bool: return ev.plane != null and is_instance_valid(ev.plane), 6.0)
		_check(came, "the dive bomber is in the air")
		var hit: bool = await _until(func() -> bool: return ev.stuka_hit_at.is_finite(), 40.0)
		_check(hit and ev.stuka_hit_at.distance_to(ClimbLink._v3(block["stuka_target"])) < 8.0, "its bomb lands on the landmark (%s)" % str(ev.stuka_hit_at.snapped(Vector3.ONE * 0.1)))
		for nm: Variant in block.get("stuka_hit_show", []):   # T-273: what the bomb sets alight shows (Totenhafen: the patrol boat burns)
			var shown: Node3D = _map.find_child(str(nm), true, false) as Node3D
			_check(shown != null and shown.is_visible_in_tree(), "the hit shows %s" % str(nm))
	else:
		_check(ev.phase != ShermanEvent.Phase.STUKA and ev.plane == null, "round %d: no dive bomber, the siren at once" % sr)
	var warned: bool = await _until(func() -> bool: return raid.phase == AirRaid.Phase.WARN, 12.0)
	_check(warned and ev.phase == ShermanEvent.Phase.RAID, "the warning")
	if warned and open_pt.is_finite():
		var dummy: Player = _p
		var was: Vector3 = dummy.global_position
		dummy.global_position = open_pt + Vector3.UP * 0.05
		roofless_bot_goal = raid.shelter_for(dummy)
		dummy.global_position = was
		_check(roofless_bot_goal.is_finite() and pts.any(func(a: Variant) -> bool: return ClimbLink._v3(a).distance_to(roofless_bot_goal) < 0.1), "a bot in the open is sent to a shelter point; one under a roof is left alone (%s)" % str(raid.shelter_for(dummy) == Vector3.INF))
	var bombing: bool = await _until(func() -> bool: return raid.phase == AirRaid.Phase.BOMBING, 8.0)
	_check(bombing, "the bombs begin")
	var bad: PackedStringArray = []
	var seen: Dictionary = {}
	var end: float = _t + 30.0
	while _t < end and raid.phase == AirRaid.Phase.BOMBING:
		for bp: Vector3 in raid.last_impacts:
			if seen.has(bp):
				continue
			seen[bp] = true
			var bz: String = String(ZoneVolume.zone_at(get_tree(), bp + Vector3.UP * 0.6))
			if not (block.get("bomb_zones", []) as Array).has(bz) or raid.roof_over(bp) or raid.is_sheltered(bp):
				bad.append("%s in %s" % [str(bp.snapped(Vector3.ONE * 0.1)), bz])
		await get_tree().physics_frame
	_check(raid.bombs_landed >= 4 and bad.is_empty(), "%d bombs, every one on open ground in a bomb zone %s" % [raid.bombs_landed, str(bad)])
	_check(raid.hits_outside == 0 and _p.hp >= hp0 and _p.is_alive(), "under the roof the player was never hurt (%d bombs reached for them and were stopped)" % raid.spared_inside)
	var done: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.DONE, 20.0)
	_check(done and raid.phase == AirRaid.Phase.IDLE, "the all-clear ends it")
	GameState.god_mode = true


# ================================================================== Map 0: the opening and the survivors by map

func _opening() -> void:
	var op: InnOpening = _map.find_child("InnOpening", true, false) as InnOpening
	var sv: InnSurvivors = _map.find_child("InnSurvivors", true, false) as InnSurvivors
	_check(op != null and op.data_path == "" and not op.cfg.is_empty() and str(op.cfg.get("map", "")) == "map00_crossroads", "Map 0's opening found its file by the map's id")
	_check(op != null and op.phase != InnOpening.Phase.CANCELLED and (op.cfg.get("patrons", []) as Array).size() > 0, "and it is not cancelled (%d patrons)" % ((op.cfg.get("patrons", []) as Array).size() if op != null else 0))
	_check(sv != null and not sv.cfg.is_empty() and sv.survivors.size() == (sv.cfg.get("survivors", []) as Array).size() and sv.survivors.size() > 0, "Map 0's survivors found theirs (%d upstairs)" % (sv.survivors.size() if sv != null else 0))
	# (T-272: Kaltenbrunn has its own opening now, smoke_map01_opening; Totenhafen is a map without one)
	_check(InnOpening.data_path_for(&"map02_totenhafen") == "res://data/gravelight/map02_opening.json" and InnOpening.load_cfg(InnOpening.data_path_for(&"map02_totenhafen")).is_empty(), "a map without an opening file has none")
