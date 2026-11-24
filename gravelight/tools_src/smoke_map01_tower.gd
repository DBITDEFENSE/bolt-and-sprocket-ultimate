extends Node
## T-272: Kaltenbrunn's tower, the headframe deck (gen_map01 HF_*, map01.json ladders / ziplines / climb_links), headless,
## silent, solo. As smoke_ladders does for Map 0's watchtower:
##   the ladder carries the player up the west face onto the deck and back down, both ends on the navmesh; the deck's
##   navmesh goes all the way round the shaft collar from the ladder's head; the HUD's zone up there is the yard's; the
##   horse's siege counts the whole deck as a ladder platform;
##   each zip line: nothing in a hanging rider's way, its anchor reached on foot on the deck, the bar under the Use ray,
##   usable and named, the ride carried and hanging, the landing where the data says, the rider standing free there; the
##   two landings are different places;
##   the dead: one climbs to a player in the deck's far corner and hits them; left up there it drops back down; one
##   follows a player up the ladder; four at the foot go up one after another with room between; a climber killed on
##   the rungs falls; a crawler never climbs and is put back in the round's queue.
## Prints "[tower] ..." lines and "[tower] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map01_tower.tscn

const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const FAR: Vector3 = Vector3(23.6, 6.0, 15.0)     # the deck's east side, across the shaft collar from the ladder's head

var _fails: PackedStringArray = []
var _checks: int = 0
var _map: Node3D
var _p: Player


func _ready() -> void:
	ProfileSave.path = "user://_qa_m1tower_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m1tower_settings.cfg"
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[tower] %-96s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _on_nav(pos: Vector3, tol: float = 0.6) -> bool:
	var near: Vector3 = NavigationServer3D.map_get_closest_point(_p.get_world_3d().navigation_map, pos)
	return near.distance_to(pos) < tol


func _ladder(name_: String) -> LadderClimb:
	for n: Node in get_tree().get_nodes_in_group(&"ladders"):
		if n.name == name_:
			return n as LadderClimb
	return null


func _zip(name_: String) -> ZipLine:
	for n: Node in get_tree().get_nodes_in_group(&"ziplines"):
		if n.name == name_:
			return n as ZipLine
	return null


func _stand(at: Vector3) -> void:
	_p.global_position = at + Vector3(0, 0.05, 0)
	_p.velocity = Vector3.ZERO
	await _frames(4)


func _climb_and_check(l: LadderClimb, label: String) -> void:
	await _stand(l.global_position)
	_check(l.can_interact(_p), label + ": usable (" + l.get_prompt(_p) + ")")
	var total: float = l.ride_seconds(_p.global_position.y)
	var y_start: float = _p.global_position.y
	l.climb(_p)
	await _secs(total * 0.5)
	var mid: Vector3 = _p.global_position
	_check(_p.carry == l and l.is_climbing(_p) and absf(mid.y - y_start) > 0.3 and absf(mid.y - l.to_pos.y) > 0.3, label + ": mid-climb carried by the ladder, between the ends (y %.2f)" % mid.y)
	_check(Vector2(mid.x, mid.z).distance_to(l.line_pos()) < 0.05 and _p.weapons.hands_mode == &"climb", label + ": on the ladder's line, hands on the rungs")
	await _secs(total * 0.5 + 0.9)
	_check(_p.global_position.distance_to(l.to_pos) < 0.3 and _on_nav(_p.global_position, 0.7), label + ": it ends at to_pos, on the navmesh (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.01)))
	_check(_p.is_physics_processing() and _p.carry == null and _p.weapons.hands_mode == &"", label + ": the player moves again, the gun back")


func _zip_in_reach(z: ZipLine, feet: Vector3) -> bool:
	var eye: Vector3 = feet + Vector3.UP * 1.62
	var at: Vector3 = z.global_position + Vector3.UP * -0.9
	if eye.distance_to(at) > Player.INTERACT_RANGE:
		return false
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, eye + (at - eye).normalized() * Player.INTERACT_RANGE, Player.MASK_INTERACT, [_p.get_rid()])
	q.collide_with_areas = true
	var res: Dictionary = _p.get_world_3d().direct_space_state.intersect_ray(q)
	return not res.is_empty() and (res["collider"] as Node).get_parent() == z


## What a hanging rider's body touches along the line ("" = nothing): a 1.6 m capsule under the cable at 40 places on the
## world and door layers. The deck's own railing under the anchor and the landing post do not count.
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
			if nm.begins_with("HFRail") or nm.begins_with("ZipPost") or nm.begins_with("TowerBase"):
				continue
			return "%s at %s" % [nm, str(at.snapped(Vector3(0.1, 0.1, 0.1)))]
	return ""


func _ride_and_check(zip: ZipLine, stand: Vector3) -> void:
	var label: String = "zip " + String(zip.name)
	var touch: String = _zip_path_hit(zip)
	_check(touch == "", label + ": nothing is in the hanging rider's way down the line" + ("" if touch == "" else " (" + touch + ")"))
	await _stand(stand)
	_check(_p.is_on_floor() and absf(_p.global_position.y - stand.y) < 0.2, label + ": its anchor is reached on foot on the deck (standing at %s)" % str(stand.snapped(Vector3.ONE * 0.01)))
	_check(_zip_in_reach(zip, _p.global_position), label + ": the bar is under the interaction ray from there")
	_check(_on_nav(zip.to_pos, 0.7), label + ": the landing is on the navmesh")
	_check(zip.can_interact(_p) and zip.get_prompt(_p).contains(zip.target), label + ": usable, named for where it goes (" + zip.get_prompt(_p) + ")")
	var zt: float = zip.ride_seconds()
	_check(zt > 1.8 and zt < 9.0, label + ": the ride takes a few seconds (%.1f s over %.1f m, capped at %.1f m/s)" % [zt, zip.cable_length(), zip.speed])
	zip.ride(_p)
	await _secs(zt * 0.5)
	var zm: Vector3 = _p.global_position
	_check(_p.carry == zip and zip.is_riding(_p) and _p.weapons.hands_mode == &"hang", label + ": mid-ride carried by the line, hands on the bar")
	_check(zm.y < zip.global_position.y - 1.0 and zm.y > zip.to_pos.y + 0.3, label + ": mid-ride the body hangs between the deck and the ground (y %.2f)" % zm.y)
	await _secs(zt * 0.5 + 0.9)
	_check(_p.global_position.distance_to(zip.to_pos) < 0.3 and _p.carry == null and _p.weapons.hands_mode == &"", label + ": the ride ends at its landing, the gun back (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.01)))
	await _frames(20)
	_check(_p.is_on_floor() and _p.global_position.distance_to(zip.to_pos) < 0.6, label + ": the rider stands free at the landing (not in a post or a wall)")


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


func _run() -> void:
	Campaign.reset()
	_map = (load(MAP1) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	var up: LadderClimb = _ladder("HeadframeLadder_Foot")
	var down: LadderClimb = _ladder("HeadframeLadder_Top")
	_check(up != null and down != null, "map01: the headframe's two LadderClimbs are in the scene")
	if up == null or down == null:
		_finish()
		return
	await _climb_and_check(up, "headframe up")
	var deck: Vector3 = up.to_pos
	_check(absf(deck.y - 6.0) < 0.05, "the deck is the hoist house's roof, 6 m up")
	# the deck's navmesh: from the ladder's head all the way round the shaft collar (every corner, the far side)
	var nav: RID = _p.get_world_3d().navigation_map
	var round_ok: int = 0
	var spots: Array[Vector3] = [Vector3(16.6, 6.0, 11.6), Vector3(20.0, 6.0, 11.1), Vector3(23.4, 6.0, 11.6), FAR, Vector3(23.4, 6.0, 18.4), Vector3(20.0, 6.0, 18.9), Vector3(16.6, 6.0, 18.4)]
	for sp: Vector3 in spots:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, deck, sp, true, 1)
		if not path.is_empty() and path[path.size() - 1].distance_to(sp) < 0.6:
			var ok: bool = true
			for q: Vector3 in path:
				ok = ok and q.y > 5.5   # (it stays on the deck)
			if ok:
				round_ok += 1
	_check(round_ok == spots.size(), "the deck's navmesh goes all the way round the shaft collar from the ladder's head (%d of %d places)" % [round_ok, spots.size()])
	_check(String(ZoneVolume.zone_at(get_tree(), FAR + Vector3.UP * 0.6)) == "A_MINEHEAD", "up there is the Minehead yard's zone")
	_check(ClimbLink.on_perch(_map, FAR) and ClimbLink.on_perch(_map, Vector3(24.3, 6.0, 10.7)) and not ClimbLink.on_perch(_map, Vector3(20.0, 0.0, 22.0)), "the horse's siege counts the whole deck as a ladder platform (the far corner too), not the yard")
	# the zip lines
	var zips: Array[Node] = get_tree().get_nodes_in_group(&"ziplines")
	_check(zips.size() == 2, "map01: two zip lines are in the scene (%d)" % zips.size())
	var landings: Array[Vector3] = []
	for zn: String in ["EastZip", "WestZip"]:
		var zip: ZipLine = _zip(zn)
		_check(zip != null and zip.zone == &"", "the zip line %s is in the scene, never chained (it lands in the yard)" % zn)
		if zip == null:
			continue
		var m: Vector3 = zip.mount_pos(deck.y)
		var c: Vector3 = Vector3(20.0, deck.y, zip.global_position.z)
		await _ride_and_check(zip, m + (Vector3(c.x - m.x, 0, c.z - m.z)).normalized() * 0.55)
		_check(String(ZoneVolume.zone_at(get_tree(), zip.to_pos + Vector3.UP * 0.6)) == "A_MINEHEAD", "zip %s: it lands in the Minehead yard (no paid door skipped)" % zn)
		for other: Vector3 in landings:
			_check(other.distance_to(zip.to_pos) > 15.0, "zip %s: its landing is a different place (%.0f m from the other)" % [zn, other.distance_to(zip.to_pos)])
		landings.append(zip.to_pos)
		await _climb_and_check(up, "headframe up again")
	await _climb_and_check(down, "headframe down")
	await _the_dead(up)
	_finish()


func _finish() -> void:
	print("[tower] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _the_dead(up: LadderClimb) -> void:
	var dir: ZombieDirector = _map.get("director")
	var links: Node = _map.get_node_or_null("ClimbLinks")
	var link: NavigationLink3D = links.get_node_or_null("Climb_Headframe") as NavigationLink3D if links != null else null
	_check(link != null and link.has_meta(ClimbLink.LINE) and bool(link.get_meta(ClimbLink.DROP)), "climb: the headframe's ladder is a climb link with a line, both ways")
	if link == null:
		return
	var foot: Vector3 = link.start_position
	var deck_y: float = link.end_position.y
	# ---- one climbs to a player in the deck's far corner and hits them
	await _stand(FAR)
	GameState.god_mode = false
	_p.hp = 100.0
	var z1: Zombie = _raise(foot + Vector3(-4.0, 0, 1.5))
	_check(z1 != null, "climb: a zombie rises in the yard")
	var saw: bool = false
	var mid_ok: bool = false
	var t: float = 0.0
	while z1 != null and t < 60.0 and _p.hp >= 100.0:
		await _frames(6)
		t += 0.1
		if z1.on_rungs(link):
			saw = true
			if z1.global_position.y > 1.0 and z1.global_position.y < 5.0:
				mid_ok = mid_ok or Vector2(z1.global_position.x, z1.global_position.z).distance_to(link.get_meta(ClimbLink.LINE)) < 0.05
	_check(saw and mid_ok, "climb: it took the ladder, its body on the ladder's line")
	_check(_p.hp < 100.0, "climb: it came round the deck to the player and hit them (hp %.0f after %.0f s)" % [_p.hp, t])
	_check(z1 != null and absf(z1.global_position.y - deck_y) < 0.6, "climb: it stands on the deck (y %.2f)" % (z1.global_position.y if z1 != null else -1.0))
	GameState.god_mode = true
	_p.hp = 100.0
	# ---- the player leaves (down in the yard): it drops back down
	await _stand(Vector3(10.0, 0.0, 22.0))
	var dropped: bool = false
	t = 0.0
	while z1 != null and z1.is_active() and t < 30.0 and z1.global_position.y > 0.6:
		await _frames(6)
		t += 0.1
		dropped = dropped or (z1.on_ladder() and bool(z1.get("_ladder_drop")))
	_check(dropped and z1 != null and z1.is_active() and z1.global_position.y < 0.6, "drop: left on the deck, it dropped back down and is on the ground (y %.2f after %.0f s)" % [z1.global_position.y if z1 != null else -1.0, t])
	dir.kill_all(true)
	await _secs(0.5)
	# ---- one follows a player up the ladder
	await _stand(foot)
	var z2: Zombie = _raise(foot + Vector3(-5.0, 0, 3.0))
	await _secs(3.2)
	up.climb(_p)
	var followed: bool = false
	t = 0.0
	while z2 != null and t < 30.0 and not (z2.state == Zombie.State.CHASE and absf(z2.global_position.y - deck_y) < 0.5):
		await _frames(6)
		t += 0.1
		followed = followed or z2.on_rungs(link)
	_check(followed and z2 != null and absf(z2.global_position.y - deck_y) < 0.5, "follow: the player went up and the zombie came up the ladder after them (on the deck after %.0f s)" % t)
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a queue: four at the foot, the player on the deck: one after another, never stacked
	await _stand(FAR)
	var pack: Array[Zombie] = []
	for i: int in 4:
		var zq: Zombie = _raise(foot + Vector3(-2.5, 0, -1.5 + i * 1.0))
		if zq != null:
			pack.append(zq)
	var min_gap: float = INF
	var most: int = 0
	var arrived: Dictionary = {}
	t = 0.0
	while t < 50.0 and arrived.size() < pack.size():
		await _frames(3)
		t += 0.05
		var ys: Array[float] = []
		for zq2: Zombie in pack:
			if zq2.on_rungs(link):
				ys.append(zq2.global_position.y)
			elif zq2.state != Zombie.State.CLIMB_LINK and absf(zq2.global_position.y - deck_y) < 0.5:
				arrived[zq2] = true
		most = maxi(most, ys.size())
		ys.sort()
		for k: int in range(1, ys.size()):
			min_gap = minf(min_gap, ys[k] - ys[k - 1])
	_check(arrived.size() == pack.size() and pack.size() == 4, "queue: all four reached the deck (%d of %d in %.0f s)" % [arrived.size(), pack.size(), t])
	_check(most >= 2 and min_gap >= 1.5, "queue: one after another with room between (up to %d on the rungs, never closer than %.2f m)" % [most, min_gap])
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a climber killed on the rungs falls
	var hung: Array[Zombie] = dir.debug_ladder("Climb_Headframe", 1)
	_check(hung.size() == 1, "fall: a zombie is put on the ladder")
	if hung.size() == 1:
		var zk: Zombie = hung[0]
		t = 0.0
		while t < 8.0 and zk.global_position.y < 3.5:
			await _frames(3)
			t += 0.05
		var y_dead: float = zk.global_position.y
		zk.take_damage(zk.hp + 1.0, &"torso", &"none", 1, &"bullet")
		await _secs(2.2)
		var low: float = minf(zk.global_position.y, _hips_y(zk))
		_check(y_dead >= 3.0 and low < 1.3, "fall: killed %.1f m up the rungs, the body fell off the ladder (now %.2f)" % [y_dead, low])
	dir.kill_all(true)
	await _secs(0.5)
	# ---- a crawler does not climb, and does not wait at the foot for good
	await _stand(FAR)
	var zc: Zombie = _raise(foot + Vector3(-1.6, 0, 0.6))
	if zc != null:
		await _secs(3.0)
		zc.become_crawler()
		var climbed: bool = false
		t = 0.0
		while t < 60.0 and zc.is_active():
			await _frames(6)
			t += 0.1
			climbed = climbed or zc.state == Zombie.State.CLIMB_LINK
		_check(not climbed and not zc.is_active(), "crawler: it never took the ladder and was put back in the round's queue (after %.0f s)" % t)
	dir.kill_all(true)
