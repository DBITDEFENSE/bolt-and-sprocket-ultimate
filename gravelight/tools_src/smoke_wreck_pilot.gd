extends Node
## Headless smoke for T-126: GRAVELIGHT ONE's hollow hull and Flt Lt Selwyn, the pinned pilot.
## 1. The cabin is on the navmesh and joined to the field through both starboard openings (a path from outside each
##    door ends inside, and is short: it goes in, not round), and a standing capsule fits in the cabin and in both
##    doorways. The cockpit is shut off (no path into it).
## 2. Selwyn won't take your only gun or a wonder weapon; he takes a second gun from your hands (it leaves them).
## 3. Zombies spawned in the field ahead of the nose: he kills some with that gun (scored to the giver), and fires
##    nothing while none is in sight.
## 4. Run dry, he asks for ammo; passing it costs the box price and fills the gun.
## A god-mode player stands in the cabin.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_wreck_pilot.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const GEN: Script = preload("res://gravelight/tools_src/gen_map00.gd")

var _map: Node3D
var _t: float = 0.0
var _frames: int = 0
var _fails: PackedStringArray = []
var _phase: int = 0
var _phase_t: float = 0.0
var _pilot: TrappedPilot
var _player: Player
var _giver_kills: int = 0
var _scrip_before: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true


func _w(local: Vector3) -> Vector3:
	return GEN.wreck_xf() * local


func _physics_process(delta: float) -> void:
	if not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	_frames += 1
	if _t > 150.0:
		_fail("timed out in phase %d" % _phase)
		_end()
		return
	match _phase:
		0:
			if _frames < 30 or NavigationServer3D.map_get_iteration_id(_map.get_world_3d().navigation_map) == 0:
				return
			_player = (_map as MapRoot).player
			_pilot = _map.find_child("TrappedPilot", true, false) as TrappedPilot
			if _pilot == null or _player == null:
				_fail("no TrappedPilot (%s) or player (%s)" % [str(_pilot), str(_player)])
				_end()
				return
			_check_hull()
			_check_gift_rules()
			_next()
		1:
			# spawn ahead of the nose, the player in the cabin
			_player.global_position = _w(Vector3(0.2, GEN.WRECK_FLOOR + 0.05, 1.0))
			var dirn: ZombieDirector = (_map as MapRoot).director
			var pts: Array = [_w(Vector3(0, 0, -15)), _w(Vector3(-4, 0, -13)), _w(Vector3(4, 0, -14))]
			var made: int = dirn.spawn_burst(pts, 6)
			print("[pilot] spawned %d ahead of the nose at t=%.1f" % [made, _t])
			_next()
		2:
			_player.global_position = _w(Vector3(0.2, GEN.WRECK_FLOOR + 0.05, 1.0))
			if _pilot.kills >= 3:
				print("[pilot] %d kills, %d shots after %.1f s; the giver's kills %d" % [_pilot.kills, _pilot.shots, _phase_t, _giver_kills])
				if _giver_kills < _pilot.kills:
					_fail("his kills were not scored to the giver (%d of %d)" % [_giver_kills, _pilot.kills])
				_pilot.gun.mag = 0
				_pilot.gun.reserve = 0
				_next()
			elif _phase_t > 60.0:
				_fail("Selwyn killed %d in 60 s (%d shots)" % [_pilot.kills, _pilot.shots])
				_end()
		3:
			if _phase_t < 1.0:
				return
			var pr: String = _pilot.get_prompt(_player)
			if not pr.contains("ammo"):
				_fail("dry, his prompt is '%s'" % pr)
			Economy.grant(_player.player_id, 5000)
			_scrip_before = Economy.get_scrip(_player.player_id)
			var price: int = _pilot.ammo_price(_player)
			_pilot.interact(_player)
			if not _pilot.gun.is_full():
				_fail("passing ammo didn't fill his gun")
			if _scrip_before - Economy.get_scrip(_player.player_id) != price:
				_fail("ammo cost %d, expected %d" % [_scrip_before - Economy.get_scrip(_player.player_id), price])
			print("[pilot] ammo passed for %d; lines said %d" % [price, _pilot.lines_said])
			_end()


func _next() -> void:
	_phase += 1
	_phase_t = 0.0


func _check_hull() -> void:
	var nav: RID = _map.get_world_3d().navigation_map
	var inside: Vector3 = _w(Vector3(0.1, GEN.WRECK_FLOOR, 0.5))
	for d: Array in [["cargo door", Vector3(4.0, 0, 3.1)], ["torn hole", Vector3(4.0, 0, -3.4)]]:
		var from: Vector3 = NavigationServer3D.map_get_closest_point(nav, _w(d[1]))
		var lp: Vector3 = d[1]
		var just_in: Vector3 = _w(Vector3(0.1, GEN.WRECK_FLOOR, lp.z))   # straight through that opening
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, from, just_in, true, 0xFFFFFFFF)
		var length: float = 0.0
		for i: int in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		var end_d: float = path[path.size() - 1].distance_to(just_in) if not path.is_empty() else INF
		print("[pilot] path in by the %s: %d points, %.1f m, ends %.2f m from the cabin" % [d[0], path.size(), length, end_d])
		if end_d > 0.8 or length > 6.5:
			var pts: PackedStringArray = []
			for q0: Vector3 in path:
				pts.append(str((GEN.wreck_xf().affine_inverse() * q0).snapped(Vector3.ONE * 0.05)))
			print("[pilot]   path (wreck frame): ", " ".join(pts))
			_fail("no short path into the cabin by the %s (%.1f m, ends %.2f m off)" % [d[0], length, end_d])
	var cockpit: Vector3 = _w(Vector3(0.3, GEN.WRECK_FLOOR, -5.6))
	var cp: Vector3 = NavigationServer3D.map_get_closest_point(nav, cockpit)
	if cp.distance_to(cockpit) < 0.5:
		var p2: PackedVector3Array = NavigationServer3D.map_get_path(nav, inside, cockpit, true, 0xFFFFFFFF)
		if not p2.is_empty() and p2[p2.size() - 1].distance_to(cockpit) < 0.5:
			_fail("the cockpit is reachable on the navmesh")
	# a standing capsule (radius 0.4, 1.8 m) in the cabin and in both doorways
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	for spot: Array in [["cabin", Vector3(0.1, 0, 0.5)], ["cabin aft", Vector3(0.1, 0, 3.4)], ["cabin fore", Vector3(0.1, 0, -3.6)],
			["cargo door", Vector3(1.3, 0, 3.1)], ["torn hole", Vector3(1.3, 0, -3.4)]]:
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = Player.MASK_MOVE
		var lp: Vector3 = spot[1]
		var floor_y: float = GEN.WRECK_FLOOR + 0.03
		q.transform = Transform3D(GEN.wreck_xf().basis, _w(Vector3(lp.x, floor_y + 0.95, lp.z)))
		var hits: Array[Dictionary] = space.intersect_shape(q, 4)
		var blockers: PackedStringArray = []
		for h: Dictionary in hits:
			var c: Node = h["collider"] as Node
			if c != null and c != _player:
				blockers.append(str(c.name))
		if not blockers.is_empty():
			_fail("a standing capsule doesn't fit at the %s: %s" % [spot[0], ", ".join(blockers)])


func _check_gift_rules() -> void:
	var hw: WeaponHolder = _player.weapons
	while hw.slots.size() > 1:
		hw.slots.pop_back()
	hw.current_index = 0
	if _pilot.can_interact(_player):
		_fail("he'd take the player's only gun")
	hw.give_weapon(&"ashlight")
	if _pilot.can_interact(_player):
		_fail("he'd take a wonder weapon")
	hw.remove_current()
	hw.give_weapon(&"m1_garand")
	if not _pilot.can_interact(_player):
		_fail("he won't take a second gun: '%s'" % _pilot.get_prompt(_player))
	var n: int = hw.slots.size()
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, w: StringName, by: int) -> void:
		if by == _player.player_id and w == &"m1_garand":
			_giver_kills += 1)
	_pilot.interact(_player)
	if _pilot.gun == null or _pilot.gun.id != &"m1_garand":
		_fail("he didn't take the Garand")
	if hw.slots.size() != n - 1:
		_fail("the Garand stayed in the player's hands")
	print("[pilot] armed with %s (%d/%d)" % [str(_pilot.gun.id) if _pilot.gun != null else "-", _pilot.gun.mag if _pilot.gun != null else 0, _pilot.gun.reserve if _pilot.gun != null else 0])


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[pilot] FAIL: ", msg)


func _end() -> void:
	print("[pilot] RESULT %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
