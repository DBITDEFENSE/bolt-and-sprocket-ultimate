extends Node
## T-239: what a player strafing backwards catches on, and what they walk through. Headless, on the live map:
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_snags.tscn -- [--map=map01]
##       [--cell=0.5] [--no-ghosts] [--at=x,y,z[,r]]
## From every reachable spot of the baked navmesh (a `cell` grid), the player's capsule (0.35 x 1.8 m, the player's
## movement mask less the zombies) is moved 1.5 m in 16 directions the way move_and_slide would:
##   LOW       the capsule is stopped by a collider whose top is under 0.75 m above the floor (an ankle or knee high
##             block: a step, a plinth, a low prop: the thing you back into without having seen it)
##   OVERHANG  ... by a collider whose underside is over 0.5 m above the floor (a shelf, a sill, a rail end)
##   CATCH     sliding along one collider the capsule is stopped dead by another that is not a wall (under 2.2 m tall
##             or under 3 m long): a prop's corner standing out of a wall line, a machine's corner, a frame
##   SMALL     ... is stopped by a collider under 1.2 m on both horizontal sides (a post, a drum, a box in the open)
## and, with the art copied into physics shapes (MapArtAudit's), the capsule's body (0.35 .. 1.75 m above the floor,
## 0.3 m radius) is tested against the art alone where the player can stand:
##   GHOST     drawn things the player walks straight through (no collider), clustered, with the cluster's box
## One line per collider / cluster, worst first; SNAG_SUMMARY at the end. Exit code 0 (a survey, not a gate).
## `--at` prints every hit round one point (radius r, default 1.5 m).

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
}
const MASK: int = 1 | (1 << 5) | (1 << 8) | (1 << 10)   # world, barricades, doors, the map's edge
const R: float = 0.35
const H: float = 1.8
const REACH: float = 1.5
const DIRS: int = 16

var _map: Node3D
var _cell: float = 0.5
var _ghosts: bool = true
var _at: Vector3 = Vector3.INF
var _at_r: float = 1.5


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_snags.json"
	ProfileSave.profile = ProfileSave.new_profile()
	var key: String = "map01"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			key = a.substr(6)
		elif a.begins_with("--cell="):
			_cell = float(a.substr(7))
		elif a == "--no-ghosts":
			_ghosts = false
		elif a.begins_with("--at="):
			var v: PackedStringArray = a.substr(5).split(",")
			_at = Vector3(float(v[0]), float(v[1]), float(v[2]))
			if v.size() > 3:
				_at_r = float(v[3])
	GameState.bot_count = 0
	_map = (load(str(MAPS.get(key, key))) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _run() -> void:
	for i: int in 30:
		await get_tree().physics_frame
	RoundManager.stop()
	GameState.god_mode = true
	var audit: MapArtAudit = MapArtAudit.new(_map)
	if _ghosts:
		audit.run(false)
	audit.open_doors()   # bought doors out of the way: their frames are what is swept
	for i: int in 6:
		await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = _map.get_world_3d().direct_space_state
	var pts: Array = _points()
	print("probe_snags: %d navmesh spots (cell %.2f)" % [pts.size(), _cell])
	pts = _reachable(pts)
	print("probe_snags: %d reachable" % pts.size())
	var body: CharacterBody3D = CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = MASK
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = R
	cap.height = H
	cs.shape = cap
	cs.position = Vector3(0, H * 0.5, 0)
	body.add_child(cs)
	_map.add_child(body)
	await get_tree().physics_frame
	var rq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	rq.collision_mask = 1
	var par: PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	par.margin = 0.001
	var res: PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
	var found: Dictionary = {}   # collider key -> {path, box, LOW, OVERHANG, CATCH, SMALL, pos}
	var floors: Array = []
	for p: Vector3 in pts:
		rq.from = p + Vector3(0, 0.6, 0)
		rq.to = p + Vector3(0, -0.8, 0)
		var fh: Dictionary = space.intersect_ray(rq)
		if fh.is_empty() or (fh["normal"] as Vector3).y < 0.98:
			continue   # ramps and stairs: a level sweep runs into the slope itself
		var fy: float = (fh["position"] as Vector3).y
		var o: Vector3 = Vector3(p.x, fy + 0.04, p.z)
		floors.append(Vector3(p.x, fy, p.z))
		par.from = Transform3D(Basis.IDENTITY, o)
		par.motion = Vector3.ZERO
		if PhysicsServer3D.body_test_motion(body.get_rid(), par, res) and res.get_travel().length() > 0.01:
			continue   # the spot itself is not free (a navmesh rim under a ledge)
		for k: int in DIRS:
			var az: float = TAU * float(k) / float(DIRS)
			var d: Vector3 = Vector3(cos(az), 0, sin(az))
			par.from = Transform3D(Basis.IDENTITY, o)
			par.motion = d * REACH
			if not PhysicsServer3D.body_test_motion(body.get_rid(), par, res):
				continue
			var n1: Vector3 = res.get_collision_normal()
			if n1.y > 0.35:
				continue
			var c1: Object = res.get_collider()
			var b1: AABB = _box(c1, res.get_collider_shape())
			var hit_at: Vector3 = o + res.get_travel()
			if b1.end.y - fy < 0.75:
				_note(found, c1, b1, "LOW", hit_at)
			elif b1.position.y - fy > 0.5:
				_note(found, c1, b1, "OVERHANG", hit_at)
			elif maxf(b1.size.x, b1.size.z) < 1.2:
				_note(found, c1, b1, "SMALL", hit_at)
			var rem: Vector3 = res.get_remainder()
			rem.y = 0.0
			var nh: Vector3 = Vector3(n1.x, 0, n1.z).normalized()
			var sl: Vector3 = rem - nh * rem.dot(nh)
			if sl.length() < 0.25:
				continue
			par.from = Transform3D(Basis.IDENTITY, hit_at + nh * 0.004)
			par.motion = sl
			if not PhysicsServer3D.body_test_motion(body.get_rid(), par, res):
				continue
			var c2: Object = res.get_collider()
			var n2: Vector3 = res.get_collision_normal()
			if c2 == c1 or n2.y > 0.35 or res.get_travel().length() > sl.length() * 0.5 or n2.dot(sl.normalized()) > -0.5:
				continue
			var b2: AABB = _box(c2, res.get_collider_shape())
			if b2.size.y >= 2.2 and maxf(b2.size.x, b2.size.z) >= 3.0 and b2.position.y - fy < 0.3:
				continue   # two walls: a room's corner
			_note(found, c2, b2, "CATCH", hit_at + res.get_travel())
	body.queue_free()
	var rows: Array = found.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _score(a) > _score(b))
	for f: Dictionary in rows:
		var bx: AABB = f["box"]
		print("SNAG %-44s LOW %-4d OVERHANG %-4d CATCH %-4d SMALL %-4d box (%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f) at %s" % [str(f["path"]).right(44),
			int(f["LOW"]), int(f["OVERHANG"]), int(f["CATCH"]), int(f["SMALL"]), bx.position.x, bx.position.y, bx.position.z, bx.end.x, bx.end.y, bx.end.z,
			str((f["pos"] as Vector3).snapped(Vector3.ONE * 0.1))])
	var nghost: int = 0
	if _ghosts:
		nghost = _ghost_pass(space, floors)
	print("SNAG_SUMMARY colliders %d ghosts %d spots %d" % [rows.size(), nghost, floors.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0)


func _score(f: Dictionary) -> int:
	return int(f["CATCH"]) * 3 + int(f["LOW"]) * 2 + int(f["OVERHANG"]) * 2 + int(f["SMALL"])


func _note(found: Dictionary, c: Object, b: AABB, kind: String, pos: Vector3) -> void:
	var key: String = "%s|%s" % [str((c as Node).get_path()) if c is Node else str(c), str(b.position.snapped(Vector3.ONE * 0.01))]
	if not found.has(key):
		found[key] = {"path": str(_map.get_path_to(c as Node)) if c is Node else str(c), "box": b, "LOW": 0, "OVERHANG": 0, "CATCH": 0, "SMALL": 0, "pos": pos}
	(found[key] as Dictionary)[kind] = int((found[key] as Dictionary)[kind]) + 1
	if _at != Vector3.INF and pos.distance_to(_at) < _at_r:
		print("  AT %s %s %s box %s .. %s" % [kind, str(pos.snapped(Vector3.ONE * 0.01)), str(_map.get_path_to(c as Node)) if c is Node else "?", str(b.position.snapped(Vector3.ONE * 0.01)), str(b.end.snapped(Vector3.ONE * 0.01))])


## The world box of one shape of a collider (the whole body's when the shape is not a simple one).
func _box(c: Object, shape_idx: int) -> AABB:
	var co: CollisionObject3D = c as CollisionObject3D
	if co == null:
		return AABB()
	var out: AABB = AABB()
	var first: bool = true
	var owners: PackedInt32Array = co.get_shape_owners()
	for ow: int in owners:
		for s: int in co.shape_owner_get_shape_count(ow):
			if shape_idx >= 0 and co.shape_owner_get_shape_index(ow, s) != shape_idx:
				continue
			var sh: Shape3D = co.shape_owner_get_shape(ow, s)
			var xf: Transform3D = co.global_transform * co.shape_owner_get_transform(ow)
			var m: ArrayMesh = sh.get_debug_mesh()
			var lb: AABB = m.get_aabb() if m != null else AABB()
			var wb: AABB = xf * lb
			out = wb if first else out.merge(wb)
			first = false
	return out


## Drawn things with no collider where the player can stand: the art copies against the capsule's body.
func _ghost_pass(space: PhysicsDirectSpaceState3D, floors: Array) -> int:
	var art: int = 0
	for i: int in MapArtAudit.GROUPS.size():
		art |= 1 << (MapArtAudit.ART_LAYER0 + i)
	var sq: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var lowc: CylinderShape3D = CylinderShape3D.new()
	lowc.radius = 0.3
	lowc.height = 0.65
	sq.collision_mask = art
	var cells: Dictionary = {}   # Vector3i -> [low, high]
	for f: Vector3 in floors:
		var lo: bool = false
		var hi: bool = false
		sq.shape = lowc
		sq.transform = Transform3D(Basis.IDENTITY, f + Vector3(0, 0.35 + 0.325, 0))
		lo = not space.intersect_shape(sq, 1).is_empty()
		sq.transform = Transform3D(Basis.IDENTITY, f + Vector3(0, 1.05 + 0.325, 0))
		hi = not space.intersect_shape(sq, 1).is_empty()
		if lo or hi:
			cells[Vector3i(roundi(f.x / _cell), roundi(f.y), roundi(f.z / _cell))] = [lo, hi, f]
	# clusters (8-neighbour on the grid, same storey)
	var seen: Dictionary = {}
	var clusters: Array = []
	for k: Vector3i in cells.keys():
		if seen.has(k):
			continue
		var stack: Array = [k]
		seen[k] = true
		var lo_n: int = 0
		var hi_n: int = 0
		var mn: Vector3 = Vector3.INF
		var mx: Vector3 = -Vector3.INF
		var n: int = 0
		while not stack.is_empty():
			var c: Vector3i = stack.pop_back()
			var e: Array = cells[c]
			n += 1
			lo_n += 1 if e[0] else 0
			hi_n += 1 if e[1] else 0
			mn = mn.min(e[2])
			mx = mx.max(e[2])
			for dx: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var nb: Vector3i = c + Vector3i(dx, 0, dz)
					if cells.has(nb) and not seen.has(nb):
						seen[nb] = true
						stack.append(nb)
		clusters.append({"n": n, "lo": lo_n, "hi": hi_n, "mn": mn, "mx": mx})
	clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["n"]) > int(b["n"]))
	for c: Dictionary in clusters:
		var mn2: Vector3 = c["mn"]
		var mx2: Vector3 = c["mx"]
		print("GHOST spots %-4d body %-4d head %-4d x %.1f..%.1f z %.1f..%.1f y %.1f" % [int(c["n"]), int(c["lo"]), int(c["hi"]), mn2.x, mx2.x, mn2.z, mx2.z, mn2.y])
	return clusters.size()


## A grid of points on the baked navmesh (every region), world space.
func _points() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for nd: Node in _map.find_children("*", "NavigationRegion3D", true, false):
		var nr: NavigationRegion3D = nd as NavigationRegion3D
		var nm: NavigationMesh = nr.navigation_mesh
		if nm == null:
			continue
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var poly: PackedInt32Array = nm.get_polygon(i)
			if poly.size() < 3:
				continue
			var p2: PackedVector2Array = PackedVector2Array()
			var mn: Vector2 = Vector2.INF
			var mx: Vector2 = -Vector2.INF
			var ysum: float = 0.0
			for vi: int in poly:
				var w: Vector3 = nr.global_transform * verts[vi]
				p2.append(Vector2(w.x, w.z))
				mn = mn.min(Vector2(w.x, w.z))
				mx = mx.max(Vector2(w.x, w.z))
				ysum += w.y
			var y: float = ysum / float(poly.size())
			var gx: int = ceili(mn.x / _cell)
			while gx * _cell <= mx.x:
				var gz: int = ceili(mn.y / _cell)
				while gz * _cell <= mx.y:
					var q: Vector2 = Vector2(gx * _cell, gz * _cell)
					var key: Vector3i = Vector3i(gx, roundi(y / 1.5), gz)
					if not seen.has(key) and Geometry2D.is_point_in_polygon(q, p2):
						seen[key] = true
						var plane: Plane = Plane(nr.global_transform * verts[poly[0]], nr.global_transform * verts[poly[1]], nr.global_transform * verts[poly[2]])
						var hit: Variant = plane.intersects_ray(Vector3(q.x, y + 50.0, q.y), Vector3.DOWN)
						out.append(Vector3(q.x, (hit as Vector3).y if hit != null else y, q.y))
					gz += 1
				gx += 1
	return out


## Spots a path from the first player spawn reaches (the closets behind the windows are navmesh too).
func _reachable(points: Array) -> Array:
	var from: Node3D = _map.find_child("PlayerSpawn1", true, false) as Node3D
	if from == null:
		return points
	var map: RID = _map.get_world_3d().navigation_map
	var a: Vector3 = NavigationServer3D.map_get_closest_point(map, from.global_position)
	var out: Array = []
	var memo: Dictionary = {}
	for p: Vector3 in points:
		# one path per 2 m block is enough: the blocks' spots share their reachability unless a wall splits them
		var key: Vector3i = Vector3i(floori(p.x / 2.0), roundi(p.y / 1.5), floori(p.z / 2.0))
		if not memo.has(key):
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, a, p, true, 0xFFFFFFFF)
			memo[key] = not path.is_empty() and path[path.size() - 1].distance_to(p) < 0.6
		if memo[key]:
			out.append(p)
	return out
