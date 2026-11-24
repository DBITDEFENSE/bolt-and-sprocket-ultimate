extends Node
## Ladders and the zip line (T-229): on Map 0 the sniper tower's ladder carries the player up to the deck and back, the
## zip line runs them from the roof post down to the landing by the stable wall, the cellar hatch behind the bar is
## bolted until the Old Cellar opens and then climbs both ways; on Map 2 the U-boat's engine-room escape hatch climbs
## both ways. Every climb must end on the baked navmesh (where a zombie can reach you), and the zombies' climb links for
## the same ladders must be in the scene. Headless, silent.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_ladders.tscn

var _fails: PackedStringArray = []
var _map: Node3D
var _p: Player


func _ready() -> void:
	ProfileSave.path = "user://_qa_ladders_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[ladders] %-60s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _load(path: String) -> void:
	if _map != null and is_instance_valid(_map):
		_map.free()
	Campaign.reset()
	_map = (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true


func _on_nav(pos: Vector3, tol: float = 0.6) -> bool:
	var nav_map: RID = _p.get_world_3d().navigation_map
	var near: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, pos)
	return near.distance_to(pos) < tol


func _ladder(name_: String) -> LadderClimb:
	for n: Node in get_tree().get_nodes_in_group(&"ladders"):
		if n.name == name_:
			return n as LadderClimb
	return null


func _climb_and_check(l: LadderClimb, label: String) -> void:
	_p.global_position = l.global_position + Vector3(0, 0.05, 0)
	_p.velocity = Vector3.ZERO
	await _frames(3)
	_check(l.can_interact(_p), label + ": usable (" + l.get_prompt(_p) + ")")
	var total: float = l.ride_seconds(_p.global_position.y)
	var y_start: float = _p.global_position.y
	l.climb(_p)
	await _secs(total * 0.5)
	# T-230: mid-climb the body is carried, between the ends, on the ladder's line, hands on the rungs, gun away
	var mid: Vector3 = _p.global_position
	_check(_p.carry == l and l.is_climbing(_p), label + ": mid-climb the player is carried by the ladder")
	_check(absf(mid.y - y_start) > 0.3 and absf(mid.y - l.to_pos.y) > 0.3, label + ": mid-climb the body is between the ends (y %.2f)" % mid.y)
	_check(Vector2(mid.x, mid.z).distance_to(l.line_pos()) < 0.05, label + ": mid-climb the body is on the ladder's line")
	_check(_p.weapons.hands_mode == &"climb", label + ": mid-climb the hands are on the rungs (%s)" % _p.weapons.hands_mode)
	await _secs(total * 0.5 + 0.9)
	_check(_p.global_position.distance_to(l.to_pos) < 0.3, label + ": the climb ended at to_pos (at %s, wanted %s)" % [str(_p.global_position), str(l.to_pos)])
	_check(_on_nav(_p.global_position, 0.7), label + ": the climb's end is on the navmesh")
	_check(_p.is_physics_processing() and _p.carry == null, label + ": the player moves again after it")
	_check(_p.weapons.hands_mode == &"", label + ": the gun is back after it")
	if _p.global_position.distance_to(l.to_pos) >= 0.3:
		for c: Node in _p.get_children():   # what overlaps the body at to_pos
			if c is CollisionShape3D:
				var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
				q.shape = (c as CollisionShape3D).shape
				q.transform = Transform3D(Basis.IDENTITY, l.to_pos + (c as CollisionShape3D).position)
				q.collision_mask = 0xFFFFFFFF
				for hit: Dictionary in _p.get_world_3d().direct_space_state.intersect_shape(q, 8):
					var col: Node = hit.get("collider")
					print("[ladders]   overlaps at to_pos: %s (%s)" % [str(col.get_path()) if col != null else "?", str(col.get("collision_layer")) if col != null else ""])


func _zip(name_: String) -> ZipLine:
	for n: Node in get_tree().get_nodes_in_group(&"ziplines"):
		if n.name == name_:
			return n as ZipLine
	return null


## True when a player standing at `feet` and looking at the zip line's bar gets it under the interaction ray.
func _zip_in_reach(z: ZipLine, feet: Vector3) -> bool:
	var eye: Vector3 = feet + Vector3.UP * 1.62
	var at: Vector3 = z.global_position + Vector3.UP * -0.9
	if eye.distance_to(at) > Player.INTERACT_RANGE:
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + (at - eye).normalized() * Player.INTERACT_RANGE, Player.MASK_INTERACT, [_p.get_rid()])
	q.collide_with_areas = true
	var res: Dictionary = _p.get_world_3d().direct_space_state.intersect_ray(q)
	return not res.is_empty() and (res["collider"] as Node).get_parent() == z


## What a hanging rider's body would touch along the line ("" = nothing): a 1.6 m capsule under the cable at 40
## places, on the world layer. The tower's own rail under the anchor and the landing post at the far end do not count.
func _zip_path_hit(zip: ZipLine) -> String:
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1 | (1 << 8)
	for i: int in range(1, 40):
		var at: Vector3 = zip.cable_point(float(i) / 40.0) - Vector3.UP * (zip.hang - 1.0)
		q.transform = Transform3D(Basis.IDENTITY, at)
		for hit: Dictionary in _p.get_world_3d().direct_space_state.intersect_shape(q, 6):
			var col: Node = hit.get("collider")
			var nm: String = String(col.name) if col != null else "?"
			if nm.begins_with("Tower") or nm.begins_with("ZipPost") or nm.begins_with("Rail_Balcony") or nm == "BalconyFloor":
				continue   # (T-273: Totenhafen's signal balcony is the anchor's own platform, like Map 0's tower)
			return "%s at %s" % [nm, str(at.snapped(Vector3(0.1, 0.1, 0.1)))]
	return ""


func _ride_and_check(zip: ZipLine, stand: Vector3) -> void:
	var label: String = "zip " + String(zip.name)
	var touch: String = _zip_path_hit(zip)
	_check(touch == "", label + ": nothing is in the hanging rider's way down the line" + ("" if touch == "" else " (" + touch + ")"))
	_p.global_position = stand + Vector3(0, 0.05, 0)
	_p.velocity = Vector3.ZERO
	await _frames(4)
	_check(_p.is_on_floor() and absf(_p.global_position.y - stand.y) < 0.2, label + ": its anchor is reached from the top platform (standing at %s)" % str(stand))
	_check(_zip_in_reach(zip, _p.global_position), label + ": the bar is under the interaction ray from there")
	_check(_on_nav(zip.to_pos, 0.7), label + ": the landing is on the navmesh")
	_check(zip.can_interact(_p) and zip.get_prompt(_p).contains(zip.target), label + ": usable, named for where it goes (" + zip.get_prompt(_p) + ")")
	var zt: float = zip.ride_seconds()
	_check(zt > 2.5 and zt < 9.0, label + ": the ride takes a few seconds (%.1f s over %.1f m, capped at %.1f m/s)" % [zt, zip.cable_length(), zip.speed])
	zip.ride(_p)
	await _secs(zt * 0.5)
	var zm: Vector3 = _p.global_position
	_check(_p.carry == zip and zip.is_riding(_p), label + ": mid-ride the player is carried by the line")
	_check(zm.y < zip.global_position.y - 1.0 and zm.y > zip.to_pos.y + 0.5, label + ": mid-ride the body hangs between the platform and the ground (y %.2f)" % zm.y)
	_check(_p.weapons.hands_mode == &"hang", label + ": mid-ride the hands are on the bar (%s)" % _p.weapons.hands_mode)
	await _secs(zt * 0.5 + 0.9)
	_check(_p.global_position.distance_to(zip.to_pos) < 0.3, label + ": the ride ended at its landing (at %s, wanted %s)" % [str(_p.global_position), str(zip.to_pos)])
	_check(_p.is_physics_processing() and _p.carry == null, label + ": the player moves again after it")
	_check(_p.weapons.hands_mode == &"", label + ": the gun is back after it")
	await _frames(20)
	_check(_p.is_on_floor() and _p.global_position.distance_to(zip.to_pos) < 0.6, label + ": the rider stands free at the landing (not in a post or a wall)")


func _stand(at: Vector3) -> void:
	_p.global_position = at + Vector3(0, 0.05, 0)
	_p.velocity = Vector3.ZERO
	await _frames(4)


## One zombie risen at `at` (it comes up out of the ground and chases). null when the pool gave none.
func _raise(at: Vector3) -> Zombie:
	var dir: ZombieDirector = _map.get("director")
	var before: Array[Zombie] = dir.active_zombies()
	dir.spawn_burst([at], 1)
	for z: Zombie in dir.active_zombies():
		if not before.has(z):
			return z
	return null


func _hips_y(z: Zombie) -> float:
	var sk: Skeleton3D = z.get("_skel")
	if sk == null or sk.find_bone("Hips") < 0:
		return z.global_position.y
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin.y


## T-268: the dead and the watchtower. They climb both ladders to a player on the top platform and hit them; with
## the player gone they drop back down; they follow a player up a ladder; a queue goes up one after another with room
## between; a climber killed on the rungs falls; a crawler does not climb and does not wait at the foot for good.
func _zombies_and_the_tower(top: Vector3, landing: Vector3) -> void:
	var dir: ZombieDirector = _map.get("director")
	var links: Node = _map.get_node_or_null("ClimbLinks")
	var lower: NavigationLink3D = links.get_node_or_null("Climb_Tower") as NavigationLink3D
	var upper: NavigationLink3D = links.get_node_or_null("Climb_TowerUpper") as NavigationLink3D
	_check(lower != null and upper != null and lower.has_meta(ClimbLink.LINE) and upper.has_meta(ClimbLink.LINE), "climb: both tower ladders are climb links with a line")
	if lower == null or upper == null:
		return
	var foot: Vector3 = lower.start_position
	# ---- a zombie climbs both stages to a player on the top platform and hits them
	await _stand(top)
	GameState.god_mode = false
	_p.hp = 100.0
	var z1: Zombie = _raise(foot + Vector3(1.5, 0, -4.0))
	_check(z1 != null, "climb: a zombie rises in the yard")
	var saw_lower: bool = false
	var saw_upper: bool = false
	var mid_ok: bool = false
	var t: float = 0.0
	while z1 != null and t < 60.0 and _p.hp >= 100.0:
		await _frames(6)
		t += 0.1
		if z1.on_rungs(lower):
			saw_lower = true
			if z1.global_position.y > 1.0 and z1.global_position.y < 5.5:
				var l2: Vector2 = lower.get_meta(ClimbLink.LINE)
				mid_ok = mid_ok or Vector2(z1.global_position.x, z1.global_position.z).distance_to(l2) < 0.05
		if z1.on_rungs(upper):
			saw_upper = true
	_check(saw_lower and saw_upper, "climb: it took the lower ladder, crossed the landing and took the upper one")
	_check(mid_ok, "climb: on the rungs its body is on the ladder's line")
	_check(_p.hp < 100.0, "climb: it reached the player on the top platform and hit them (hp %.0f after %.0f s)" % [_p.hp, t])
	_check(z1 != null and absf(z1.global_position.y - top.y) < 0.6, "climb: it stands on the top platform (y %.2f)" % (z1.global_position.y if z1 != null else -1.0))
	GameState.god_mode = true
	_p.hp = 100.0
	# ---- with the player gone to the ground, it comes back down by dropping (both stages)
	await _stand(Vector3(20.0, 0.0, 41.0))
	var dropped: bool = false
	t = 0.0
	while z1 != null and z1.is_active() and t < 30.0 and z1.global_position.y > 0.6:
		await _frames(6)
		t += 0.1
		dropped = dropped or (z1.on_ladder() and bool(z1.get("_ladder_drop")))
	_check(dropped and z1 != null and z1.is_active() and z1.global_position.y < 0.6, "drop: left on the platform, it dropped back down both stages and is on the ground (y %.2f after %.0f s)" % [z1.global_position.y if z1 != null else -1.0, t])
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a zombie follows a player up a ladder
	await _stand(foot)
	var z2: Zombie = _raise(foot + Vector3(3.0, 0, -5.0))
	await _secs(3.2)   # it is up and coming
	var up: LadderClimb = _ladder("TowerLadder_Foot")
	up.climb(_p)
	var followed: bool = false
	t = 0.0
	while z2 != null and t < 30.0 and not (z2.state == Zombie.State.CHASE and absf(z2.global_position.y - landing.y) < 0.5):
		await _frames(6)
		t += 0.1
		followed = followed or z2.on_rungs(lower)
	_check(followed and z2 != null and absf(z2.global_position.y - landing.y) < 0.5, "follow: the player went up the ladder and the zombie came up it after them (on the landing after %.0f s)" % t)
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a queue: four at the foot, the player on the landing: one after another, never stacked
	await _stand(landing)
	var pack: Array[Zombie] = []
	for i: int in 4:
		var zq: Zombie = _raise(foot + Vector3(-1.5 + i * 1.0, 0, -2.5))
		if zq != null:
			pack.append(zq)
	var min_gap: float = INF
	var most: int = 0
	var arrived: Dictionary = {}
	t = 0.0
	while t < 45.0 and arrived.size() < pack.size():
		await _frames(3)
		t += 0.05
		var ys: Array[float] = []
		for zq2: Zombie in pack:
			if zq2.on_rungs(lower):
				ys.append(zq2.global_position.y)
			elif zq2.state != Zombie.State.CLIMB_LINK and absf(zq2.global_position.y - landing.y) < 0.5:
				arrived[zq2] = true
		most = maxi(most, ys.size())
		ys.sort()
		for k: int in range(1, ys.size()):
			min_gap = minf(min_gap, ys[k] - ys[k - 1])
	_check(arrived.size() == pack.size() and pack.size() == 4, "queue: all four reached the landing (%d of %d in %.0f s)" % [arrived.size(), pack.size(), t])
	_check(most >= 2 and min_gap >= 1.5, "queue: they went up one after another with room between (up to %d on the rungs, never closer than %.2f m)" % [most, min_gap])
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a climber killed on the rungs falls; it can be shot there (its hitboxes are with it)
	var hung: Array[Zombie] = dir.debug_ladder("Climb_Tower", 1)
	_check(hung.size() == 1, "fall: a zombie is put on the lower ladder")
	if hung.size() == 1:
		var zk: Zombie = hung[0]
		t = 0.0
		while t < 8.0 and zk.global_position.y < 3.5:
			await _frames(3)
			t += 0.05
		var hb_ok: bool = false
		for hb: Hitbox in zk.get("_hitboxes"):
			if hb.collision_layer != 0 and hb.global_position.distance_to(zk.global_position + Vector3.UP * 0.9) < 1.6:
				hb_ok = true
		_check(zk.on_rungs(lower) and zk.global_position.y >= 3.5 and hb_ok, "fall: 3.5 m up the rungs its hitboxes are live and with the body")
		var y_dead: float = zk.global_position.y
		zk.take_damage(zk.hp + 1.0, &"torso", &"none", 1, &"bullet")
		_check(zk.state == Zombie.State.DEAD, "fall: shot there, it dies")
		await _secs(2.2)
		var low: float = minf(zk.global_position.y, _hips_y(zk))
		_check(low < 1.3, "fall: killed %.1f m up, the body fell off the ladder (now %.2f)" % [y_dead, low])
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a crawler does not climb, and does not wait at the foot for good
	var zc: Zombie = _raise(foot + Vector3(0.6, 0, -1.6))
	if zc != null:
		await _secs(3.0)
		zc.become_crawler()
		var climbed: bool = false
		t = 0.0
		while t < 60.0 and zc.is_active():
			await _frames(6)
			t += 0.1
			climbed = climbed or zc.state == Zombie.State.CLIMB_LINK
		_check(not climbed, "crawler: it never took the ladder")
		_check(not zc.is_active(), "crawler: it was put back in the round's queue instead of waiting at the foot (after %.0f s)" % t)
	dir.kill_all(true)
	await _secs(0.5)


## T-273: Totenhafen's catwalk ladders (up and down each, on the zombies' climb links' lines), the signal balcony's zip
## line (the rider's way clear, the bar reached from the balcony, the ride, the landing on the east apron), and a
## zombie that climbs the west catwalk's ladder to a player up there.
func _map02_t273(links: Node) -> void:
	GameState.open_zone(&"G_SIGNAL")
	await _frames(3)
	for side: String in ["W", "N", "E"]:
		var up: LadderClimb = _ladder("Catwalk%s_Up" % side)
		var down: LadderClimb = _ladder("Catwalk%s_Down" % side)
		var link: NavigationLink3D = links.get_node_or_null("Ladder_Catwalk" + side) as NavigationLink3D if links != null else null
		_check(up != null and down != null, "map02: the %s catwalk's two LadderClimbs are in the scene" % side)
		_check(link != null and link.has_meta(ClimbLink.LINE) and up != null and (link.get_meta(ClimbLink.LINE) as Vector2).distance_to(up.line_pos()) < 0.05,
			"map02: the %s catwalk's climb link is a ladder on the players' line" % side)
		if up == null or down == null:
			continue
		_check(_on_nav(up.global_position, 0.6) and _on_nav(down.global_position, 0.6), "map02 %s: both ends stand on the navmesh" % side)
		await _climb_and_check(up, "catwalk %s up" % side)
		await _climb_and_check(down, "catwalk %s down" % side)
	var zip: ZipLine = _zip("SignalZip")
	_check(zip != null, "map02: the signal balcony's zip line is in the scene")
	if zip != null:
		var floor_y: float = 7.0
		var m: Vector3 = zip.mount_pos(floor_y)
		var stand: Vector3 = m + Vector3(0, 0, -0.55)   # back from the anchor toward the tower's door
		await _ride_and_check(zip, stand)
		var zone: String = String(ZoneVolume.zone_at(get_tree(), zip.to_pos + Vector3.UP * 0.6))
		_check(zone == "D_PENHALL", "zip SignalZip: it lands in the Pen Hall, the zone the tower is reached through (%s)" % zone)
		_check(String(ZoneVolume.zone_at(get_tree(), stand + Vector3.UP * 0.6)) == "G_SIGNAL", "zip SignalZip: the balcony is the signal tower's zone")
	# a zombie climbs the west catwalk's ladder to a player on the catwalk
	var lw: NavigationLink3D = links.get_node_or_null("Ladder_CatwalkW") as NavigationLink3D if links != null else null
	if lw != null:
		var dir: ZombieDirector = _map.get("director")
		await _stand(Vector3(-19.0, 4.0, 63.0))
		var z1: Zombie = _raise(lw.start_position + Vector3(2.0, 0, 3.0))
		var climbed: bool = false
		var t: float = 0.0
		while z1 != null and t < 45.0 and not (climbed and absf(z1.global_position.y - 4.0) < 0.5 and z1.state != Zombie.State.CLIMB_LINK):
			await _frames(6)
			t += 0.1
			climbed = climbed or z1.on_rungs(lw)
		_check(climbed and z1 != null and absf(z1.global_position.y - 4.0) < 0.5, "map02: a zombie on pier 0 came up the west catwalk's ladder to the player (on the catwalk after %.0f s)" % t)
		dir.kill_all(true)
		await _secs(0.5)


func _run() -> void:
	await _load("res://gravelight/maps/map00_crossroads/map00.tscn")
	# the watchtower (T-229, T-268): two ladders in stages, three zip lines from the top
	var up: LadderClimb = _ladder("TowerLadder_Foot")
	var down: LadderClimb = _ladder("TowerLadder_Top")
	var up2: LadderClimb = _ladder("TowerLadder_Upper")
	var down2: LadderClimb = _ladder("TowerLadder_Head")
	_check(up != null and down != null and up2 != null and down2 != null, "map00: the tower's four LadderClimbs are in the scene")
	if up != null and down != null and up2 != null and down2 != null:
		GameState.open_zone(&"YARD")
		await _climb_and_check(up, "tower up to the landing")
		await _climb_and_check(up2, "tower up to the top")
		_check(up2.to_pos.y - up.global_position.y > 11.0, "the top platform is %.1f m up (the old deck was 6.2)" % (up2.to_pos.y - up.global_position.y))
		var zips: Array[Node] = get_tree().get_nodes_in_group(&"ziplines")
		_check(zips.size() == 3, "map00: three zip lines are in the scene (%d)" % zips.size())
		var top: Vector3 = up2.to_pos
		var landings: Array[Vector3] = []
		for zn: String in ["YardZip", "InnZip", "BankZip"]:
			var zip: ZipLine = _zip(zn)
			_check(zip != null, "map00: the zip line %s is in the scene" % zn)
			if zip == null:
				continue
			if zip.zone != &"" and not GameState.is_zone_open(zip.zone):
				await _stand(top)
				_check(not zip.can_interact(_p) and zip.get_prompt(_p) == zip.locked_text, "zip %s: chained while %s is shut (%s)" % [zn, zip.zone, zip.get_prompt(_p)])
				GameState.open_zone(zip.zone)
				await _frames(3)
			var m: Vector3 = zip.mount_pos(top.y)
			var c: Vector3 = Vector3(5.4, top.y, 45.0)   # the platform's middle
			await _ride_and_check(zip, m + (Vector3(c.x - m.x, 0, c.z - m.z)).normalized() * 0.55)
			for other: Vector3 in landings:
				_check(other.distance_to(zip.to_pos) > 15.0, "zip %s: its landing is a different place (%.0f m from another)" % [zn, other.distance_to(zip.to_pos)])
			landings.append(zip.to_pos)
		await _stand(top)
		await _climb_and_check(down2, "tower down to the landing")
		await _climb_and_check(down, "tower down to the yard")
		await _zombies_and_the_tower(top, up.to_pos)
	var links: Node = _map.get_node_or_null("ClimbLinks")
	_check(links != null and links.has_node("Climb_Tower") and links.has_node("Climb_TowerUpper") and links.has_node("Climb_CellarHatch"), "map00: the zombies' climb links (tower, tower upper, hatch) exist")
	# the cellar hatch: bolted until the Old Cellar opens
	var hup: LadderClimb = _ladder("CellarHatch_Up")
	var hdown: LadderClimb = _ladder("CellarHatch_Down")
	_check(hup != null and hdown != null, "map00: the cellar hatch's two LadderClimbs are in the scene")
	if hup != null and hdown != null:
		_check(not hdown.can_interact(_p) and hdown.get_prompt(_p).contains("bolted"), "hatch: bolted before the Old Cellar opens (" + hdown.get_prompt(_p) + ")")
		var td: Node = _map.get_node_or_null("Gameplay/CellarTrapdoor")
		if td == null:
			td = _map.find_child("CellarTrapdoor", true, false)
		_check(td != null and not bool(td.get("is_open")), "hatch: the trapdoor leaf is shut")
		GameState.open_zone(&"OLD_CELLAR")
		await _frames(3)
		_check(td != null and bool(td.get("is_open")), "hatch: the leaf opens with the Old Cellar")
		await _climb_and_check(hdown, "hatch down")
		await _climb_and_check(hup, "hatch up")
	# Totenhafen: the engine room's escape hatch
	await _load("res://gravelight/maps/map02_totenhafen/map02.tscn")
	GameState.open_zone(&"D_PENHALL")
	GameState.open_zone(&"E_UBOAT")
	await _frames(3)
	var eup: LadderClimb = _ladder("EngineHatch_Up")
	var edown: LadderClimb = _ladder("EngineHatch_Down")
	_check(eup != null and edown != null, "map02: the escape hatch's two LadderClimbs are in the scene")
	if eup != null and edown != null:
		await _climb_and_check(eup, "escape hatch up")
		await _climb_and_check(edown, "escape hatch down")
	var links2: Node = _map.get_node_or_null("ClimbLinks")
	_check(links2 != null and links2.has_node("Ladder_EngineHatch"), "map02: the zombies' climb link for the hatch exists")
	await _map02_t273(links2)
	print("[ladders] RESULT %s (%d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	for f: String in _fails:
		print("[ladders]   - " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)
