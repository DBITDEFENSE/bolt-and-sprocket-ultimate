extends RefCounted
## T-263: is this a good place for an arms locker (WeaponLocker)? Works on an instantiated map scene (nothing's
## _ready needs to run) or on a live one, from the baked navmesh polygons, the box colliders and the triangles of
## every mesh, with gravelight/tools_src/interactable_facing.gd's geometry index. Nothing here can see: it measures.
## (No class_name: callers preload it.)
##
## A spot is {at: the floor point on the wall's face under the locker's middle, yaw: where the doors face (deg,
## 0 = +z, 90 = +x)}: weapon_locker.json's row. check() returns a row of measurements and `problems` (empty = fine):
##   wall       the wall is behind the whole back (9 probes: 3 heights x 3 across), nothing of it in front of the face
##   floor      a floor collider under the foot
##   body       no collider inside the body box (0.92 x 1.9 x 0.45 m)
##   nav        no navmesh polygon under the body (the locker never stands on walkable ground: no rebake needed)
##   stand      the standing room in front (0.9 x 1.0 m, to 1.8 m up) is free of colliders
##   facing     interactable_facing's verdict for a wall-backed machine there is OK, its front open, the use box
##              reachable from the navmesh
##   room       metres of free space from the doors straight out to the next collider (a walkway needs it left over)
##   clutter    meshes with triangles inside the body box (a tack rail, a poster, a lamp: things without colliders)
##   front      meshes with triangles in the standing room above shin height
##   neighbours every other interactable, perk spot, spawn and bank counter nearer than its limit
## scan() walks a rectangle of floor and returns every wall spot in it, best first.

const Facing: GDScript = preload("res://gravelight/tools_src/interactable_facing.gd")

const W: float = 0.92
const H: float = 1.9
const D: float = 0.45
## The rule interactable_facing.gd checks a locker with (its RULES row "weapon_locker.gd" is the same).
const RULE: Dictionary = {"kind": "faced", "f": 0.45, "b": 0.0, "w": 0.46, "wall": true, "isize": Vector3(1.22, 1.8, 0.3),
	"ioff": Vector3(0, 1.0, -0.55), "script": "weapon_locker.gd"}
const NEAR_MACHINE: float = 1.6    # another machine, perk spot or wall buy nearer than this (plan, same floor) crowds it
const NEAR_DOOR: float = 2.4       # a door or a window (barricade) nearer than this: a walkway or a zombie's way in
const ROOM_MIN: float = 2.4        # free metres in front of the doors (0.45 m of locker out of a walkway of less is in the way)


static func spot_transform(at: Vector3, yaw_deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg + 180.0)), at)


## The geometry of a map: Facing's index plus every mesh ({name, aabb (world), xf, mesh} / multimesh instances).
static func index(map: Node) -> Dictionary:
	var geo: Dictionary = Facing.index_geometry(map)
	var meshes: Array = []
	for n: Node in map.find_children("*", "GeometryInstance3D", true, false):
		if n.has_meta("locker_own") or not (n as GeometryInstance3D).visible:
			continue
		var xf: Transform3D = Facing.gxf(n)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var m: Mesh = (n as MeshInstance3D).mesh
			meshes.append({"name": _path_name(map, n), "aabb": xf * m.get_aabb(), "xf": xf, "mesh": m})
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null and (n as MultiMeshInstance3D).multimesh.mesh != null:
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			for i: int in mm.instance_count:
				var ixf: Transform3D = xf * mm.get_instance_transform(i)
				meshes.append({"name": _path_name(map, n) + "[%d]" % i, "aabb": ixf * mm.mesh.get_aabb(), "xf": ixf, "mesh": mm.mesh})
	geo["meshes"] = meshes
	var others: Array = []
	for n2: Node in map.find_children("*", "Node3D", true, false):
		var s: Script = n2.get_script() as Script
		if s == null:
			continue
		var file: String = s.resource_path.get_file()
		var kind: String = ""
		if file == "weapon_locker.gd":
			continue
		if file in ["door.gd", "breach_door.gd", "barricade.gd", "gate_door.gd", "blast_door.gd"]:
			kind = "door"
		elif Facing.is_interactable(n2) or file in ["perk_spot.gd", "player_spawn.gd", "bank_counter.gd"]:
			kind = "machine"
		if kind != "":
			others.append({"name": str(n2.name), "kind": kind, "pos": Facing.gxf(n2).origin})
	geo["others"] = others
	return geo


static func _path_name(map: Node, n: Node) -> String:
	var p: String = str(map.get_path_to(n)) if map.is_ancestor_of(n) else str(n.name)
	return p if p.length() <= 70 else "..." + p.right(67)


## Adds a point the neighbour check knows (a bank counter from bank.json, a ladder's foot...).
static func add_other(geo: Dictionary, name: String, kind: String, pos: Vector3) -> void:
	(geo["others"] as Array).append({"name": name, "kind": kind, "pos": pos})


static func _inside(li: Dictionary, p: Vector3) -> String:
	for bb: Array in li["boxes"]:
		var q: Vector3 = (bb[0] as Transform3D) * p
		var h: Vector3 = bb[1]
		if absf(q.x) < h.x and absf(q.y) < h.y and absf(q.z) < h.z:
			return str(bb[3])
	return ""


static func check(geo: Dictionary, at: Vector3, yaw_deg: float, with_meshes: bool = true) -> Dictionary:
	var xf: Transform3D = spot_transform(at, yaw_deg)
	var fwd: Vector3 = -xf.basis.z          # out of the doors
	var side: Vector3 = xf.basis.x
	var li: Dictionary = Facing.local_index(geo, at, 0.0, RULE)
	var res: Dictionary = {"at": at, "yaw": yaw_deg, "problems": PackedStringArray()}
	var problems: PackedStringArray = []
	# the wall behind the whole back, flat
	var wall_hits: int = 0
	var proud: String = ""
	for hy: float in [0.3, 1.0, 1.7]:
		for lx: float in [-W * 0.5 + 0.06, 0.0, W * 0.5 - 0.06]:
			var p: Vector3 = at + Vector3.UP * hy + side * lx
			var ins: String = _inside(li, p + fwd * 0.04)
			if ins != "":
				proud = ins
			elif Facing.seg_blocked(li, p + fwd * 0.04, p - fwd * 0.1):
				wall_hits += 1
	res["wall"] = wall_hits
	if proud != "":
		problems.append("wall: %s stands in front of the face" % proud)
	elif wall_hits < 9:
		problems.append("wall: only %d of 9 probes have the wall behind" % wall_hits)
	# the floor under the foot
	var floor_ok: bool = true
	for lx2: float in [-W * 0.5 + 0.1, W * 0.5 - 0.1]:
		var fp: Vector3 = at + side * lx2 + fwd * 0.25
		if not Facing.seg_blocked(li, fp + Vector3.UP * 0.3, fp - Vector3.UP * 0.12) or _inside(li, fp + Vector3.UP * 0.12) != "":
			floor_ok = false
	res["floor"] = floor_ok
	if not floor_ok:
		problems.append("floor: no floor collider at this height under the foot (or the foot is inside one)")
	# the body box
	var body_c: Vector3 = at + Vector3.UP * (H * 0.5 + 0.04) + fwd * (D * 0.5 + 0.03)
	var body_b: Basis = Basis(side, Vector3.UP, -fwd)
	res["body"] = not Facing.body_clips(li, body_c, body_b, Vector3(W * 0.5, H * 0.5, D * 0.5))
	if not bool(res["body"]):
		problems.append("body: a collider inside the body box")
	# no navmesh under the body
	var nav_under: float = 0.0
	for dz: float in [0.05, 0.15, 0.25, 0.35, 0.45]:
		for lx3: float in [-0.4, -0.2, 0.0, 0.2, 0.4]:
			var np: Vector3 = at + fwd * dz + side * lx3
			if not is_nan(Facing.nav_height(li, np.x, np.z, at.y + 0.2, Facing.NAV_DY)):
				nav_under = maxf(nav_under, D - dz)
	res["nav_under"] = nav_under
	if nav_under > 0.12:
		problems.append("nav: the navmesh runs %.2f m under the body" % nav_under)
	# the standing room
	var stand_c: Vector3 = at + Vector3.UP * 0.95 + fwd * (D + 0.5)
	res["stand"] = not Facing.body_clips(li, stand_c, body_b, Vector3(0.45, 0.85, 0.5))
	if not bool(res["stand"]):
		problems.append("stand: a collider in the standing room in front")
	# free room straight out of the doors
	var room: float = 6.0
	for lx4: float in [-0.3, 0.0, 0.3]:
		var r0: Vector3 = at + Vector3.UP * Facing.CHEST + fwd * (D + 0.05) + side * lx4
		var d: float = 0.0
		while d < 6.0 and not Facing.seg_blocked(li, r0, r0 + fwd * (d + 0.1)):
			d += 0.1
		room = minf(room, d)
	res["room"] = room
	if room < ROOM_MIN:
		problems.append("room: only %.1f m free in front of the doors" % room)
	# the facing check's own verdict
	var fr: Dictionary = Facing.check_one(geo, {"name": "WeaponLocker", "path": "(weapon_locker.json)", "xf": xf, "rule": RULE.duplicate()})
	res["verdict"] = fr["verdict"]
	res["open"] = float((fr["open"] as Dictionary).get(0.0, 0.0))
	res["reachable"] = fr["reachable"]
	res["floor_y"] = fr["floor_y"]
	if str(fr["verdict"]) != "OK" or not bool(fr["reachable"]):
		problems.append("facing: %s (front %.0f%% open, reachable %s)" % [fr["verdict"], float(res["open"]) * 100.0, str(fr["reachable"])])
	elif float(res["open"]) < 0.8:
		problems.append("facing: the front is only %.0f%% open" % (float(res["open"]) * 100.0))
	# neighbours
	var near: PackedStringArray = []
	var nearest: float = INF
	for o: Dictionary in geo.get("others", []):
		var op: Vector3 = o["pos"]
		if absf(op.y - at.y) > 2.2:
			continue
		var dd: float = Vector2(op.x - at.x, op.z - at.z).length()
		nearest = minf(nearest, dd)
		if dd < (NEAR_DOOR if str(o["kind"]) == "door" else NEAR_MACHINE):
			near.append("%s %.1f m" % [o["name"], dd])
	res["nearest"] = nearest
	res["neighbours"] = near
	if not near.is_empty():
		problems.append("neighbours: " + ", ".join(near))
	# meshes without colliders
	if with_meshes:
		var inv: Transform3D = xf.affine_inverse()
		res["clutter"] = meshes_in(geo, inv, Vector3(-W * 0.5 - 0.03, 0.06, -D - 0.06), Vector3(W * 0.5 + 0.03, H + 0.3, -0.05))
		res["front"] = meshes_in(geo, inv, Vector3(-0.45, 0.3, -D - 1.0), Vector3(0.45, 1.8, -D - 0.06))
		if not (res["clutter"] as Array).is_empty():
			problems.append("clutter: " + ", ".join(PackedStringArray(res["clutter"])))
		if not (res["front"] as Array).is_empty():
			problems.append("front: " + ", ".join(PackedStringArray(res["front"])))
	res["problems"] = problems
	return res


## The names of the meshes with a triangle inside the box [lo, hi] of the locker's frame (inv = world -> frame).
static func meshes_in(geo: Dictionary, inv: Transform3D, lo: Vector3, hi: Vector3) -> Array:
	var out: Array = []
	var box: AABB = AABB(lo, hi - lo)
	var world_box: AABB = inv.affine_inverse() * box
	for m: Dictionary in geo.get("meshes", []):
		if not (m["aabb"] as AABB).intersects(world_box):
			continue
		var faces: PackedVector3Array = _faces(m["mesh"] as Mesh)
		var to_local: Transform3D = inv * (m["xf"] as Transform3D)
		var hit: bool = false
		var i: int = 0
		while i + 2 < faces.size() and not hit:
			hit = _tri_in_box(to_local * faces[i], to_local * faces[i + 1], to_local * faces[i + 2], box)
			i += 3
		if hit:
			out.append(str(m["name"]))
	return out


static var _face_cache: Dictionary = {}


static func _faces(mesh: Mesh) -> PackedVector3Array:
	var id: int = mesh.get_instance_id()
	if not _face_cache.has(id):
		_face_cache[id] = mesh.get_faces()
	return _face_cache[id]


## Does the triangle reach into the box? Sampled on a barycentric grid about 4 cm fine (capped): enough for props.
static func _tri_in_box(a: Vector3, b: Vector3, c: Vector3, box: AABB) -> bool:
	var tb: AABB = AABB(a, Vector3.ZERO).expand(b).expand(c)
	if not tb.grow(0.0001).intersects(box):
		return false
	var longest: float = maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
	var n: int = clampi(ceili(longest / 0.04), 1, 80)
	for i: int in n + 1:
		for j: int in n + 1 - i:
			var u: float = float(i) / n
			var v: float = float(j) / n
			if box.has_point(a * (1.0 - u - v) + b * u + c * v):
				return true
	return false


## Every wall spot of the floor rectangle [x0..x1] x [z0..z1] at height y: from each cell of a 0.25 m grid that is on
## the navmesh, a line to each of the four sides finds the wall's face; each face point is checked once. Sorted with
## the spots without problems first, the roomiest and the loneliest first among them.
static func scan(geo: Dictionary, x0: float, z0: float, x1: float, z1: float, y: float, step: float = 0.25) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	var z: float = z0
	while z <= z1 + 0.001:
		var x: float = x0
		while x <= x1 + 0.001:
			var q: Vector3 = Vector3(x, y, z)
			var li: Dictionary = Facing.local_index(geo, q, 0.0, RULE)
			if not is_nan(Facing.nav_height(li, x, z, y + 0.2, Facing.NAV_DY)):
				for yaw: float in [0.0, 90.0, 180.0, 270.0]:
					var fwd: Vector3 = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)
					var c0: Vector3 = q + Vector3.UP * Facing.CHEST
					var d: float = 0.0
					while d < 3.0 and not Facing.seg_blocked(li, c0, c0 - fwd * (d + 0.02)):
						d += 0.02
					if d >= 3.0 or d < 0.3:
						continue
					var at: Vector3 = (q - fwd * d).snapped(Vector3(0.01, 0.01, 0.01))
					at.y = y
					var key: String = "%.2f|%.2f|%d" % [snappedf(at.x, step), snappedf(at.z, step), int(yaw)]
					if seen.has(key):
						continue
					seen[key] = true
					var r: Dictionary = check(geo, at, yaw, false)
					if (r["problems"] as PackedStringArray).is_empty():
						r = check(geo, at, yaw, true)
					out.append(r)
			x += step
		z += step
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = (a["problems"] as PackedStringArray).size()
		var pb: int = (b["problems"] as PackedStringArray).size()
		if pa != pb:
			return pa < pb
		return float(a["room"]) + minf(float(a["nearest"]), 6.0) > float(b["room"]) + minf(float(b["nearest"]), 6.0))
	return out


static func line(r: Dictionary) -> String:
	var at: Vector3 = r["at"]
	var p: PackedStringArray = r["problems"]
	return "at [%.2f, %.2f, %.2f] yaw %3d  wall %d/9  room %.1f m  open %3.0f%%  nearest %.1f m  nav under %.2f  %s" % [at.x, at.y, at.z,
		int(r["yaw"]), int(r["wall"]), float(r["room"]), float(r.get("open", 0.0)) * 100.0, float(r["nearest"]), float(r["nav_under"]),
		"OK" if p.is_empty() else "; ".join(p)]
