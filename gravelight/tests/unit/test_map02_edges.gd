extends GutTest
## Map 2 "Totenhafen" edges and reach (UPDATE 07 QA, T-103). The Phase 0 playtest found zombies falling out of the
## world off the quay's landing stages (the shingle and the sea bed have no colliders) and the playtest bot
## walking to the wrong face of the quay wall for the Cannery's wall-buys. These tests read the generated scene
## (never the live tree) and hold the rules the fixes rely on: every landing stage has kerb colliders on its three
## open sides, every wall-buy has navmesh in front of its board within reach, and every authored training route
## (routes_map00/01/02.json) sits on its map's navmesh.

const SCENE: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": SCENE,
}

var _nodes: Array = []   # [{name, path, props}] from the packed scene's state


func before_all() -> void:
	_nodes = _state_nodes(SCENE)


static func _state_nodes(scene: String) -> Array:
	var out: Array = []
	var st: SceneState = (load(scene) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		out.append({"name": String(st.get_node_name(i)), "path": String(st.get_node_path(i)), "type": st.get_node_type(i), "props": props})
	return out


## A StaticBody's world-space box (its position and its CollisionShape3D child's BoxShape3D), or {} when it has none.
func _body_box(n: Dictionary) -> Dictionary:
	var pos: Vector3 = (n["props"] as Dictionary).get("position", Vector3.ZERO)
	var xf: Variant = (n["props"] as Dictionary).get("transform", null)
	if xf is Transform3D:
		pos = (xf as Transform3D).origin
	for c: Dictionary in _nodes:
		if str(c["path"]).begins_with(str(n["path"]) + "/") and c["type"] == "CollisionShape3D":
			var shape: Variant = (c["props"] as Dictionary).get("shape", null)
			if shape is BoxShape3D:
				var half: Vector3 = (shape as BoxShape3D).size * 0.5
				return {"lo": pos - half, "hi": pos + half}
	return {}


## True when some rail collider stands along the segment a-b (both on the deck's top) at least `h` high.
func _kerb_along(a: Vector3, b: Vector3, deck_top: float, h: float) -> bool:
	for n: Dictionary in _nodes:
		if n["type"] != "StaticBody3D" or not str(n["name"]).trim_prefix("@").begins_with("Rail_Stage"):
			continue
		var bx: Dictionary = _body_box(n)
		if bx.is_empty():
			continue
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		if hi.y < deck_top + h:
			continue
		var covers_x: bool = lo.x - 0.1 <= minf(a.x, b.x) and hi.x + 0.1 >= maxf(a.x, b.x)
		var covers_z: bool = lo.z - 0.1 <= minf(a.z, b.z) and hi.z + 0.1 >= maxf(a.z, b.z)
		if covers_x and covers_z:
			return true
	return false


func test_landing_stages_have_kerbs_on_their_three_open_sides() -> void:
	var stages: int = 0
	for n: Dictionary in _nodes:
		if n["type"] != "StaticBody3D" or not str(n["name"]).trim_prefix("@").begins_with("Stage"):
			continue
		var bx: Dictionary = _body_box(n)
		if bx.is_empty():
			continue
		stages += 1
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		assert_true(_kerb_along(Vector3(lo.x, hi.y, lo.z), Vector3(lo.x, hi.y, hi.z), hi.y, 0.8), "%s: a kerb on its west side" % n["name"])
		assert_true(_kerb_along(Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), hi.y, 0.8), "%s: a kerb on its east side" % n["name"])
		assert_true(_kerb_along(Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), hi.y, 0.8), "%s: a kerb on its seaward end" % n["name"])
	assert_eq(stages, 2, "the two landing stages behind the parapet windows")


## Every navmesh vertex of a scene's NavigationRegion3D nodes, in world space (regions sit at the origin).
static func _nav_vertices(nodes: Array) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for n: Dictionary in nodes:
		if n["type"] != "NavigationRegion3D":
			continue
		var nm: Variant = (n["props"] as Dictionary).get("navigation_mesh", null)
		if nm is NavigationMesh:
			var off: Vector3 = (n["props"] as Dictionary).get("position", Vector3.ZERO)
			for v: Vector3 in (nm as NavigationMesh).get_vertices():
				out.append(v + off)
	return out


## The navmesh polygons of a scene as world-space vertex rings.
static func _nav_polys(nodes: Array) -> Array:
	var out: Array = []
	for n: Dictionary in nodes:
		if n["type"] != "NavigationRegion3D":
			continue
		var nm: Variant = (n["props"] as Dictionary).get("navigation_mesh", null)
		if not (nm is NavigationMesh):
			continue
		var off: Vector3 = (n["props"] as Dictionary).get("position", Vector3.ZERO)
		var verts: PackedVector3Array = (nm as NavigationMesh).get_vertices()
		for i: int in (nm as NavigationMesh).get_polygon_count():
			var ring: PackedVector3Array = PackedVector3Array()
			for idx: int in (nm as NavigationMesh).get_polygon(i):
				ring.append(verts[idx] + off)
			out.append(ring)
	return out


static func _in_poly_xz(p: Vector3, ring: PackedVector3Array) -> bool:
	var inside: bool = false
	var j: int = ring.size() - 1
	for i: int in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[j]
		if (a.z > p.z) != (b.z > p.z):
			var x: float = a.x + (p.z - a.z) * (b.x - a.x) / (b.z - a.z)
			if p.x < x:
				inside = not inside
		j = i
	return inside


## True when `p` (or a point within `slack` of it: a route's authored point may sit on a polygon edge) lies in a
## navmesh polygon at about its height.
static func _on_navmesh(p: Vector3, polys: Array, y_tol: float = 1.2, slack: float = 0.0) -> bool:
	if slack > 0.0:
		for o: Vector3 in [Vector3.ZERO, Vector3(slack, 0, 0), Vector3(-slack, 0, 0), Vector3(0, 0, slack), Vector3(0, 0, -slack)]:
			if _on_navmesh(p + o, polys, y_tol):
				return true
		return false
	for ring: PackedVector3Array in polys:
		var y_ok: bool = false
		for v: Vector3 in ring:
			if absf(v.y - p.y) <= y_tol:
				y_ok = true
				break
		if y_ok and _in_poly_xz(p, ring):
			return true
	return false


func test_every_wall_buy_has_navmesh_in_front_of_its_board() -> void:
	var polys: Array = _nav_polys(_nodes)
	assert_gt(polys.size(), 50, "the scene carries its baked navmeshes")
	var buys: int = 0
	for n: Dictionary in _nodes:
		if not str(n["name"]).begins_with("WallBuy_"):
			continue
		buys += 1
		var xf: Transform3D = (n["props"] as Dictionary).get("transform", Transform3D.IDENTITY)
		var pos: Vector3 = xf.origin
		var front: Vector3 = xf.basis * Vector3(0, 0, -1)
		front.y = 0.0
		front = front.normalized()
		var found: bool = false
		for d: float in [0.7, 1.1, 1.5, 1.9]:
			var p: Vector3 = pos + front * d
			p.y = pos.y - 1.5   # the board hangs 1.5 m over the floor it is bought from
			if _on_navmesh(p, polys, 1.2, 0.6):   # a board can sit on a region seam (Pier 2's at z 50)
				found = true
				break
		assert_true(found, "%s at %s has navmesh in front of its board within 2 m" % [n["name"], pos])
	assert_eq(buys, 9, "nine wall-buys on Totenhafen")


func test_every_training_route_sits_on_its_maps_navmesh() -> void:
	var checked: int = 0
	for key: String in SCENES.keys():
		var path: String = "res://data/gravelight/ai/routes_%s.json" % key
		if not FileAccess.file_exists(path):
			continue
		var polys: Array = _nav_polys(_state_nodes(str(SCENES[key])))
		assert_gt(polys.size(), 50, "%s carries its baked navmeshes" % key)
		var data: Dictionary = GLData.load_json(path)
		for r: Dictionary in data.get("routes", []):
			for pt: Array in r.get("points", []):
				var p: Vector3 = Vector3(float(pt[0]), float(pt[1]), float(pt[2]))
				assert_true(_on_navmesh(p, polys, 1.2, 0.5), "%s point %s is on the navmesh" % [r["id"], p])
				checked += 1
	assert_gt(checked, 20, "routes were checked")
