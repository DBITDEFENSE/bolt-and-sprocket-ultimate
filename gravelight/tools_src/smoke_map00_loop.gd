extends Node
## Headless smoke for Map 0's grounds (T-080: "make it bigger and make it so you can go around the whole building").
##   A. static: a navmesh path walks all the way round the inn, the stable and the yard on open ground (every leg
##      reaches its waypoint, crosses no door and no window, stays in zone GROUNDS) and a player-sized capsule swept
##      along it hits nothing; nothing past the edge is reachable; the inn reaches the grounds only through Door_Front
##      and the yard only through Door_Gate; every grounds spawn and field window spawn is on the grounds' navmesh;
##      the zones are right (GROUNDS is open ground, the ledges and the yard are not).
##   B. the gate bought (GROUNDS + YARD open), round 4, a god-mode player out in the north-east field: zombies from the
##      edge spawns reach the player, a window zombie on its way in turns on the player, nothing appears in sight.
##   C. the player back in the taproom (front door shut): the zombies outside leave the chase for the windows.
##   D. the front door bought: it swings open and stays open; the taproom now reaches the grounds through it.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map00_loop.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
## Round the inn clockwise from the crossroads: the front, the crash field, the carters' road, the woodshed, the
## west road.
const LOOP: Array[Vector3] = [Vector3(-6, 0, -7), Vector3(12, 0, -7), Vector3(31, 0, -7), Vector3(31.5, 0, 4), Vector3(31, 0, 12),
	Vector3(31.5, 0, 20), Vector3(36, 0, 28), Vector3(40, 0, 44), Vector3(42, 0, 53), Vector3(34, 0, 58.5), Vector3(18, 0, 56), Vector3(1, 0, 55),
	Vector3(-8, 0, 46), Vector3(-8, 0, 28), Vector3(-8, 0, 10)]   # (routes_map00.json map00_grounds_ring)
const FIELD: Vector3 = Vector3(28, 0, -11.5)
const TAPROOM: Vector3 = Vector3(14, 0, 8)

var _map: Node3D
var _t: float = 0.0
var _frames: int = 0
var _phase: String = "static"
var _phase_t: float = 0.0
var _fails: PackedStringArray = []
var _first: Dictionary = {}       # zombie instance id -> [first position, spawn kind "edge"/"window"/"ground"/"?"]
var _edge_reached: int = 0
var _diverted: int = 0
var _fell_back: int = 0
var _too_close: int = 0
var _was_chasing_out: Dictionary = {}
var _counted: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	_frames += 1
	match _phase:
		"static":
			if _frames == 12:
				_check_static()
				_start_field()
		"field":
			_watch(delta)
			if _phase_t > 75.0 or (_edge_reached >= 1 and _diverted >= 1 and _phase_t > 25.0):
				print("[loop] field: edge zombies reached the player %d, window zombies turned on the player %d, appeared within 8 m %d" % [_edge_reached, _diverted, _too_close])
				if _edge_reached < 1:
					_fail("no zombie from the edge spawns reached the player out in the field")
				if _diverted < 1:
					_fail("no window zombie turned on the player out on the grounds")
				if _too_close > 0:
					_fail("%d zombies appeared within 8 m of the player out on the grounds" % _too_close)
				_start_inside()
		"inside":
			_watch(delta)
			if _phase_t > 40.0 or (_fell_back >= 1 and _phase_t > 6.0):
				print("[loop] inside: zombies outside that left the chase for a window %d" % _fell_back)
				if _fell_back < 1:
					_fail("no zombie outside left its chase for a window when the player went back in")
				_phase = "door"
				_check_front_door()


# ---------------------------------------------------------------- A. static

func _check_static() -> void:
	var map_rid: RID = _map.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var total: float = 0.0
	var legs_ok: int = 0
	for i: int in LOOP.size():
		var a: Vector3 = LOOP[i]
		var b: Vector3 = LOOP[(i + 1) % LOOP.size()]
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, a, b, true)
		var ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(b) < 1.0
		var why: String = "" if ok else "doesn't reach"
		if ok and _crosses_door_or_window(path):
			ok = false
			why = "crosses a door or a window"
		if ok:
			for k: int in path.size():
				var p: Vector3 = path[k]
				var z: StringName = ZoneVolume.zone_at(get_tree(), p)
				if z != &"GROUNDS":
					ok = false
					why = "leaves the grounds at %s (zone '%s')" % [str(p), String(z)]
					break
		if ok:
			var hit: String = _sweep(space, path)
			if hit != "":
				ok = false
				why = "a capsule swept along it hits %s" % hit
		var l: float = _len(path)
		total += l
		print("[loop] leg %2d %s -> %s  %5.1f m  %s" % [i, str(a), str(b), l, "ok" if ok else "WRONG: " + why])
		if ok:
			legs_ok += 1
		else:
			_fail("loop leg %d (%s -> %s): %s" % [i, str(a), str(b), why])
	print("[loop] round the whole building on open ground: %d / %d legs, %.0f m" % [legs_ok, LOOP.size(), total])
	if total < 180.0:
		_fail("the loop round the building is only %.0f m" % total)
	# nothing past the edge but the spawn pockets (T-084): points between the pockets, on the road exits and beyond
	# a pocket's far end are shut; each pocket is reached from inside (the spawn check below) and a body can't follow
	for q: Vector3 in [Vector3(-26, 0, 0), Vector3(66, 0, 30), Vector3(20, 0, -36), Vector3(20, 0, 70), Vector3(-10.75, 0, -36), Vector3(66, 0, -7.75), Vector3(-26, 0, -7.75), Vector3(38, 0, 70),
			Vector3(70, 0, 22), Vector3(5, 0, -40), Vector3(-30, 0, 16), Vector3(24, 0, 74)]:
		var path2: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, Vector3(20, 0, -8), q, true)
		var reached: bool = not path2.is_empty() and path2[path2.size() - 1].distance_to(q) < 2.0
		print("[loop] past the edge %s: %s" % [str(q), "reachable (WRONG)" if reached else "shut ok"])
		if reached:
			_fail("the grounds' edge leaks at %s" % str(q))
	# the edge wall and its gates stop a player's capsule and let a shot through (T-084)
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	var qs: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	qs.shape = cap
	qs.collision_mask = Player.MASK_MOVE
	for probe: Array in [[Vector3(5, 1.15, -29.0), Vector3(0, 0, -3.0), "the north pocket's gate"], [Vector3(14, 1.15, -29.0), Vector3(0, 0, -3.0), "the north wall"],
			[Vector3(64.5 - 5.5, 1.15, 22), Vector3(3.0, 0, 0), "the east pocket's gate"]]:
		qs.transform = Transform3D(Basis.IDENTITY, probe[0])
		qs.motion = probe[1]
		var cm: PackedFloat32Array = space.cast_motion(qs)
		var stopped: bool = cm.size() == 2 and cm[0] < 1.0
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create((probe[0] as Vector3) + Vector3.UP * 0.4, (probe[0] as Vector3) + (probe[1] as Vector3) * 2.0 + Vector3.UP * 0.4, WeaponHolder.MASK_SHOT)
		var shot_hit: Dictionary = space.intersect_ray(ray)
		var shot_through: bool = shot_hit.is_empty() or ((shot_hit["collider"] as CollisionObject3D).collision_layer & (1 << 10)) == 0
		print("[loop] %s: body stopped %s, shot through %s" % [probe[2], str(stopped), str(shot_through)])
		if not stopped:
			_fail("%s lets a body through" % probe[2])
		if not shot_through:
			_fail("%s stops a shot (%s)" % [probe[2], String((shot_hit["collider"] as Node).name)])
	# the inn and the yard reach the grounds only through their bought doors
	for c: Array in [["taproom -> the front", TAPROOM, Vector3(20, 0, -6), "Door_Front"], ["yard -> the carters' road", Vector3(18, 0, 44), Vector3(18, 0, 55), "Door_Gate"],
			["stable -> the crash field", Vector3(15, 0, 29), Vector3(32, 0, 4), "Door_Front|Door_Gate"]]:
		var path3: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, c[1], c[2], true)
		var reached3: bool = not path3.is_empty() and path3[path3.size() - 1].distance_to(c[2]) < 1.0
		var via: Array[String] = []
		for n: Node in get_tree().get_nodes_in_group(&"doors"):
			var d: BuyDoor = n as BuyDoor
			if d != null and ZombieDirector.door_crossed(d, path3):
				via.append(String(d.name))
		var ok3: bool = reached3 and not via.is_empty()
		for v: String in via:
			ok3 = ok3 and (str(c[3]).split("|").has(v) or v in ["Door_Stable", "Door_Yard"])
		var want_one: bool = false
		for w: String in str(c[3]).split("|"):
			want_one = want_one or via.has(w)
		ok3 = ok3 and want_one and not _crosses_window(path3)
		print("[loop] %-30s via %s  %s" % [c[0], ", ".join(via), "ok" if ok3 else "WRONG"])
		if not ok3:
			_fail("%s: via %s (reached %s)" % [c[0], str(via), str(reached3)])
	# every spawn out here is on the grounds' navmesh
	var bad: PackedStringArray = []
	var n_sp: int = 0
	for n2: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n2 as ZombieSpawn
		if sp == null or not (sp.zone_id == &"GROUNDS" or (sp.window() != null and ZoneVolume.zone_at(get_tree(), sp.global_position) == &"GROUNDS")):
			continue
		n_sp += 1
		var path4: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, LOOP[0], sp.global_position, true)
		if path4.is_empty() or path4[path4.size() - 1].distance_to(sp.global_position) > 1.2:
			bad.append(String(sp.name))
	print("[loop] spawns on the grounds' navmesh: %d / %d %s" % [n_sp - bad.size(), n_sp, str(bad) if not bad.is_empty() else ""])
	if not bad.is_empty() or n_sp < 20:
		_fail("grounds spawns off the navmesh: %s (of %d)" % [str(bad), n_sp])
	# zones
	for zc: Array in [[Vector3(20, 0, -8), &"GROUNDS", true], [Vector3(45, 0, 30), &"GROUNDS", true], [Vector3(18, 0, 56), &"GROUNDS", true],
			[Vector3(3.45, -1.3, -1.0), &"GROUNDS", true], [TAPROOM, &"TAPROOM", false], [Vector3(18, 0, 41), &"YARD", false],
			[Vector3(19.5, 3.8, -1.5), &"", false], [Vector3(30, -3.2, 25), &"CELLAR", false], [Vector3(12, -3.2, 8), &"OLD_CELLAR", false],
			# T-251: the two rooms past the vault are zones of their own; the yard and the field over them are not cellar
			[Vector3(30, -3.2, 34.9), &"LAGERKELLER", false], [Vector3(41.5, -3.2, 36.5), &"MASCHINENRAUM", false],
			[Vector3(30, 0, 35.5), &"YARD", false], [Vector3(40, 0, 35.5), &"GROUNDS", true]]:
		var zid: StringName = ZoneVolume.zone_at(get_tree(), zc[0])
		var roam: bool = ZoneVolume.roam_at(get_tree(), zc[0])
		var okz: bool = zid == zc[1] and roam == bool(zc[2])
		if not okz:
			_fail("zone at %s is '%s' (roam %s), want '%s' (roam %s)" % [str(zc[0]), String(zid), str(roam), String(zc[1]), str(zc[2])])
	print("[loop] zones checked")


func _crosses_door_or_window(path: PackedVector3Array) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and ZombieDirector.door_crossed(d, path):
			return true
	return _crosses_window(path)


func _crosses_window(path: PackedVector3Array) -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"barricades"):
		var b: Barricade = n as Barricade
		if b != null and ZombieDirector.window_crossed(b, path):
			return true
	return false


## A standing player's capsule (r 0.35, 1.7 m, a hand's breadth off the snow) swept along the path against the world,
## the doors and the windows: the name of the first thing it hits, or "".
func _sweep(space: PhysicsDirectSpaceState3D, path: PackedVector3Array) -> String:
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | (1 << 5) | (1 << 8)
	for k: int in range(1, path.size()):
		var a: Vector3 = path[k - 1] + Vector3(0, 0.3 + 0.85, 0)
		var b: Vector3 = path[k] + Vector3(0, 0.3 + 0.85, 0)
		q.transform = Transform3D(Basis.IDENTITY, a)
		q.motion = b - a
		var r: PackedFloat32Array = space.cast_motion(q)
		if r.size() == 2 and r[0] < 1.0:
			var at: Vector3 = a.lerp(b, r[1])
			q.transform = Transform3D(Basis.IDENTITY, at)
			q.motion = Vector3.ZERO
			var hits: Array[Dictionary] = space.intersect_shape(q, 1)
			var nm: String = String((hits[0]["collider"] as Node).name) if not hits.is_empty() and hits[0]["collider"] is Node else "something"
			return "%s at %s" % [nm, str(at)]
	return ""


# ---------------------------------------------------------------- B. out in the field

func _start_field() -> void:
	var op: InnOpening = _map.find_child("InnOpening", true, false) as InnOpening
	if op != null:
		op.cancel()
	var gate: BuyDoor = _map.find_child("Door_Gate", true, false) as BuyDoor
	if gate == null:
		_fail("no Door_Gate")
		_end()
		return
	gate.open(1)
	if not GameState.is_zone_open(&"GROUNDS") or not GameState.is_zone_open(&"YARD"):
		_fail("the gate did not open GROUNDS and YARD")
	var pl: Player = (_map as MapRoot).player
	pl.global_position = FIELD
	var dir: ZombieDirector = (_map as MapRoot).director
	dir.kill_all(true)
	# no relief squad in this check: round 4 is the event's first round (35 %), and a patrol coming in from the
	# north-east kills the edge zombies before they reach the player (every FAIL of this check had one)
	var rs: ReliefSquad = ReliefSquad.instance(get_tree())
	if rs != null:
		rs.last_round = 4
	RoundManager.debug_set_round(4)
	_phase = "field"
	_phase_t = 0.0
	# one window zombie for certain (T-084): the round's own rolls favour the 17 grounds spawns 4:1, so the only
	# window whose walk-in passes within aggro range of the field spot (W_TAP_E) may never come up in 75 s. A
	# spawn bound to that window, 12 m from the player on the open snow east of the inn.
	var win: Barricade = _map.find_child("W_TAP_E", true, false) as Barricade
	if win != null and not dir._free.is_empty():
		var sp: ZombieSpawn = ZombieSpawn.new()
		sp.kind = &"window"
		sp.zone_id = &"TAPROOM"
		dir.add_child(sp)
		sp.global_position = Vector3(30.0, 0, 0.0)
		sp.window_path = sp.get_path_to(win)
		var z: Zombie = dir._free.pop_back()
		z.activate(RoundManager.take_extra_spawn(), sp, pl)
		GLBus.enemy_spawned.emit(z.enemy_id, z.get_instance_id())
		_first[z.get_instance_id()] = [z.global_position, "window"]
		sp.queue_free()
	print("[loop] gate bought, round 4, the player out in the field at %s" % str(FIELD))


func _watch(_delta: float) -> void:
	var pl: Player = (_map as MapRoot).player
	if _phase == "field":
		pl.global_position = FIELD
		pl.velocity = Vector3.ZERO
	var spawns: Array[ZombieSpawn] = []
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		if n is ZombieSpawn:
			spawns.append(n as ZombieSpawn)
	for z: Zombie in (_map as MapRoot).director.active_zombies():
		var id: int = z.get_instance_id()
		if not _first.has(id):
			var kind: String = "?"
			var best: float = 3.5
			for sp: ZombieSpawn in spawns:
				var d: float = Vector2(sp.global_position.x - z.global_position.x, sp.global_position.z - z.global_position.z).length()
				if d < best:
					best = d
					kind = String(sp.kind)
			_first[id] = [z.global_position, kind]
			var dp: float = Vector2(pl.global_position.x - z.global_position.x, pl.global_position.z - z.global_position.z).length()
			if _phase == "field" and dp < 8.0:
				_too_close += 1
				print("[loop]   zombie appeared %.1f m from the player at %s (%s)" % [dp, str(z.global_position), kind])
		var kind2: String = str(_first[id][1])
		var out: bool = ZoneVolume.roam_at(get_tree(), z.global_position)
		var st: Zombie.State = z.state
		if _phase == "field":
			if kind2 == "edge" and z.global_position.distance_to(pl.global_position) < 2.5 and not _counted.has(id):
				_counted[id] = true
				_edge_reached += 1
			if kind2 == "window" and st == Zombie.State.CHASE and out and not _counted.has(-id):
				_counted[-id] = true
				_diverted += 1
			if z.global_position.distance_to(pl.global_position) < 2.0:
				z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")   # keep the field moving
		elif _phase == "inside":
			if st == Zombie.State.CHASE and out:
				_was_chasing_out[id] = true
			elif _was_chasing_out.has(id) and st in [Zombie.State.TO_WINDOW, Zombie.State.WAIT_WINDOW, Zombie.State.TEAR] and out:
				_was_chasing_out.erase(id)
				_fell_back += 1


# ---------------------------------------------------------------- C. back inside

func _start_inside() -> void:
	var pl: Player = (_map as MapRoot).player
	pl.global_position = TAPROOM
	_phase = "inside"
	_phase_t = 0.0
	# four more rise out in the field (on top of the round): they chase someone they can't walk to now
	var dir: ZombieDirector = (_map as MapRoot).director
	for at: Vector3 in [Vector3(30, 0, -8), Vector3(40, 0, 20), Vector3(10, 0, -10), Vector3(-8, 0, 20)]:
		dir._activate_at(RoundManager.take_extra_spawn(), at)
	for z: Zombie in dir.active_zombies():
		if z.state == Zombie.State.CHASE and ZoneVolume.roam_at(get_tree(), z.global_position):
			_was_chasing_out[z.get_instance_id()] = true
	print("[loop] the player back in the taproom; %d zombies chasing outside, 4 rising in the field" % _was_chasing_out.size())


# ---------------------------------------------------------------- D. the front door

func _check_front_door() -> void:
	var df: BuyDoor = _map.find_child("Door_Front", true, false) as BuyDoor
	var fd: InnFrontDoor = _map.find_child("InnFrontDoor", true, false) as InnFrontDoor
	if df == null or fd == null:
		_fail("no Door_Front / InnFrontDoor")
		_end()
		return
	df.open(1)
	await get_tree().create_timer(2.0).timeout
	fd.close()
	fd.bar()
	var ok: bool = df.is_open and fd.is_open and fd.held_open and not fd.barred and absf(fd.angle) > 100.0
	print("[loop] Out Front bought: door open %s, leaf held open %s at %.0f deg  %s" % [str(df.is_open), str(fd.held_open), fd.angle, "ok" if ok else "WRONG"])
	if not ok:
		_fail("the front door did not open and stay open (open %s, held %s, barred %s, angle %.0f)" % [str(fd.is_open), str(fd.held_open), str(fd.barred), fd.angle])
	_end()


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[loop] FAIL: ", msg)


func _end() -> void:
	set_physics_process(false)
	await get_tree().create_timer(0.1).timeout
	if _fails.is_empty():
		print("[loop] RESULT: PASS")
	else:
		print("[loop] RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


static func _len(path: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in range(1, path.size()):
		l += path[i - 1].distance_to(path[i])
	return l
