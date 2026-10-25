extends Node
## Headless smoke for "make Map 0 feel alive" (T-072): no geometry crosses a doorway (DoorClearance over every door,
## the yard passage, the guest rooms and the front door), the taproom's training loop keeps its width with the added
## tables, and the round 1 opening runs: the patrons flee, two escape, three fall and rise as zombies that are part
## of round 1's count (the round's kills equal its total), the front door ends shut and barred, and round 2 brings
## no second opening. A god-mode player stands at the spawn.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map00_alive.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: Node3D
var _t: float = 0.0
var _frames: int = 0
var _fails: PackedStringArray = []
var _r1_total: int = -1
var _r1_kills: int = 0
var _round: int = 0
var _r1_ended: bool = false
var _checked_opening: bool = false
var _rise_states: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		_round = r
		if r == 1:
			_r1_total = RoundManager.round_total)
	GLBus.round_ended.connect(func(r: int) -> void:
		if r == 1:
			_r1_ended = true)
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, _w: StringName, _b: int) -> void:
		if _round == 1:
			_r1_kills += 1)


## Map 0's doorways: every bought door, the yard passage's arch, the guest rooms' doorways (their ajar leaves are
## skipped) and the front door (its leaf and its invisible block are the door).
static func map00_openings(map: Node) -> Array[Dictionary]:
	var ops: Array[Dictionary] = DoorClearance.buy_door_openings(map)
	ops.append(DoorClearance.opening("PassageArch", Vector3(20, 0, 22), 0.0, 3.0, 2.6))
	for rd: Array in [[5.75, 1], [11.75, 2], [20.25, 3]]:
		ops.append(DoorClearance.opening("RoomDoorway%d" % int(rd[1]), Vector3(float(rd[0]), 3.8, 6.0), 0.0, 1.5, 2.2,
			map.find_child("RoomDoor%d" % int(rd[1]), true, false)))
	var fd: Node = map.find_child("InnFrontDoor", true, false)
	ops.append(DoorClearance.opening("FrontDoor", Vector3(20, 0, 0), 0.0, 1.6, 2.4, [fd, map.find_child("FrontDoorBlock", true, false)]))
	return ops


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_t += delta
	_frames += 1
	if _frames == 10:
		_check_doorways()
		_check_loop()
	var op: InnOpening = _map.find_child("InnOpening", true, false) as InnOpening
	if op == null:
		_fail("no InnOpening on the map")
		_end()
		return
	if _round == 1 and op.phase == InnOpening.Phase.RUNNING and op.t < 1.0 and not _rise_states.has("reserved"):
		_rise_states["reserved"] = true
		print("[alive] round 1 total %d, reserved risers %d, attackers %d, queue left %d" % [_r1_total, op.riser_specs.size(), op.attacker_specs.size(), RoundManager.to_spawn])
		if op.riser_specs.size() != 3 or op.attacker_specs.size() != 2:
			_fail("slots reserved: %d risers, %d attackers" % [op.riser_specs.size(), op.attacker_specs.size()])
	for id: Variant in op.risen.keys():
		var z: Zombie = op.risen[id]
		if is_instance_valid(z) and not _rise_states.has(id):
			_rise_states[id] = [str(Zombie.State.keys()[z.state]), z.global_position]
	# the opening: let it play (zombies leave the god-mode player alone to do their thing) until it's done
	if not _checked_opening and op.phase == InnOpening.Phase.DONE:
		_checked_opening = true
		_check_opening(op)
	# then clear round 1 and see round 2 start without a second opening
	if _checked_opening:
		var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
		for z2: Zombie in dir.active_zombies():
			z2.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
		if _round >= 2:
			print("[alive] round 1 kills %d of total %d" % [_r1_kills, _r1_total])
			if _r1_kills != _r1_total:
				_fail("round 1 kills %d != its total %d" % [_r1_kills, _r1_total])
			if op.phase != InnOpening.Phase.DONE:
				_fail("the opening restarted on round 2")
			_end()
			return
	if _t > 200.0:
		_fail("timed out (round %d, opening phase %d, alive %d, queued %d)" % [_round, op.phase, RoundManager.alive, RoundManager.to_spawn])
		_end()


func _check_doorways() -> void:
	var hits: PackedStringArray = DoorClearance.intrusions(_map, map00_openings(_map))
	print("[alive] doorway clearance: %d intrusions" % hits.size())
	for h: String in hits:
		print("[alive]   ", h)
	if not hits.is_empty():
		_fail("geometry crosses a doorway")


## The taproom's training loop round the tables (MAPS.md, routes_map00.json map00_taproom): a sample on each side is
## on the navmesh, the four link up, each corridor is at least 2.2 m wide (casts across it against the shell).
func _check_loop() -> void:
	var map_rid: RID = _map.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var ring: Array[Vector3] = [Vector3(10.4, 0, 8.0), Vector3(16.5, 0, 2.5), Vector3(22.2, 0, 6.5), Vector3(14.5, 0, 14.2)]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.BACK, Vector3.RIGHT, Vector3.BACK]
	var widths: PackedStringArray = []
	var ok: bool = true
	for i: int in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % ring.size()]
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map_rid, a, b, true)
		if path.is_empty() or path[path.size() - 1].distance_to(b) > 1.0:
			ok = false
		var w: float = 0.0
		for sgn: float in [1.0, -1.0]:
			var from: Vector3 = a + Vector3.UP * 0.5
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + axes[i] * sgn * 8.0, 1))
			w += 8.0 if hit.is_empty() else from.distance_to(hit["position"])
		widths.append("%.1f" % w)
		if w < 2.2:
			ok = false
	print("[alive] taproom loop round the tables (widths %s m) %s" % [", ".join(widths), "ok" if ok else "WRONG"])
	if not ok:
		_fail("the taproom's training loop")


func _check_opening(op: InnOpening) -> void:
	print("[alive] opening done at %.1f s: fates %s, slots returned %d" % [op.t, str(op.fates), op.slots_returned])
	for id: String in ["trudi", "pohl"]:
		if str(op.fates.get(id, "")) != "escaped":
			_fail("%s should have escaped (%s)" % [id, str(op.fates.get(id, "-"))])
	for id2: String in ["kubiak", "rother", "sobotta"]:
		if str(op.fates.get(id2, "")) != "risen":
			_fail("%s should have risen (%s)" % [id2, str(op.fates.get(id2, "-"))])
	print("[alive] risen: %s" % str(_rise_states))
	if _rise_states.has("sobotta") and ((_rise_states["sobotta"] as Array)[1] as Vector3).z < 0.5:
		_fail("Sobotta should rise inside the taproom")
	# T-076: the turns are where the squad can see them from the spawn (Sobotta mid-room, the porch in the doorway's line)
	var spawn: Vector3 = (_map.get_node("Gameplay/PlayerSpawn1") as Node3D).global_position
	for id4: String in ["sobotta", "kubiak", "rother"]:
		if _rise_states.has(id4) and not InnOpening.facing(spawn, Vector3(0, 0, -1), (_rise_states[id4] as Array)[1] as Vector3, 40.0):
			_fail("%s rises out of the starting view (%s)" % [id4, str((_rise_states[id4] as Array)[1])])
	for id3: String in ["kubiak", "rother"]:
		if _rise_states.has(id3) and ((_rise_states[id3] as Array)[1] as Vector3).z > -0.5:
			_fail("%s should rise outside" % id3)
		if _rise_states.has(id3) and str((_rise_states[id3] as Array)[0]) != "GETUP":
			_fail("%s did not rise with the get-up (%s)" % [id3, str((_rise_states[id3] as Array)[0])])
	for pb: PatronBody in op.patrons.values():
		if pb.visible:
			_fail("patron %s still visible after the opening" % pb.patron_id)
	if op.door == null or op.door.is_open or not op.door.barred:
		_fail("the front door should end shut and barred")
	# the doorway stays a wall: a ray from the taproom out through the front door hits the block
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(20, 1.2, 1.0), Vector3(20, 1.2, -1.0), 1))
	if hit.is_empty():
		_fail("the front doorway is not solid")
	var path: PackedVector3Array = NavigationServer3D.map_get_path(_map.get_world_3d().navigation_map, Vector3(20, 0, 2), Vector3(20, 0, -3), true)
	if not path.is_empty() and path[path.size() - 1].distance_to(Vector3(20, 0, -3)) < 1.0:
		_fail("the navmesh runs out of the front door")


func _fail(s: String) -> void:
	_fails.append(s)


func _end() -> void:
	if _fails.is_empty():
		print("[alive] RESULT PASS")
	else:
		for f: String in _fails:
			print("[alive] FAIL: ", f)
		print("[alive] RESULT FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_physics_process(false)
