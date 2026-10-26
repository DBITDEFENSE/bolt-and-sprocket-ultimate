extends GutTest
## UPDATE_05 section 1 (T-088): the same-camera capture list. Every camera in data/gravelight/capture_cams.json has
## a unique name, lies inside Map 0's bounds, and stands on or just above the baked navmesh (its feet over a navmesh
## polygon, within 1.5 m horizontally, from 0.6 m below to 2 m above the polygon), so a "before" and an "after"
## always frame the same thing. The subject points of the close-ups are checked the same way. The test reads the
## NavigationMesh resource straight out of map00.tscn (no server sync needed): polygons are convex, so a 2D
## point-in-polygon on XZ plus a height check does it.

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const SET: String = "u05"

var _verts: PackedVector3Array = []
var _polys: Array = []   # Array[PackedInt32Array]


func before_all() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var region: NavigationRegion3D = map.find_child("Navigation", false, false) as NavigationRegion3D
	if region != null and region.navigation_mesh != null:
		var nm: NavigationMesh = region.navigation_mesh
		_verts = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			_polys.append(nm.get_polygon(i))
	map.free()


## Over a navmesh polygon (grown by `pad` metres) with the polygon's height within -2 m .. +0.6 m of the point.
func _near_navmesh(p: Vector3, pad: float = 1.5) -> bool:
	var p2: Vector2 = Vector2(p.x, p.z)
	for poly: PackedInt32Array in _polys:
		var n: int = poly.size()
		if n < 3:
			continue
		var ymin: float = INF
		var ymax: float = -INF
		var far: bool = false
		for k: int in n:
			var v: Vector3 = _verts[poly[k]]
			ymin = minf(ymin, v.y)
			ymax = maxf(ymax, v.y)
		if ymin > p.y + 0.6 or ymax < p.y - 2.0:
			continue
		var pts: PackedVector2Array = []
		for k: int in n:
			var v: Vector3 = _verts[poly[k]]
			pts.append(Vector2(v.x, v.z))
		if Geometry2D.is_point_in_polygon(p2, pts):
			return true
		# within pad of an edge
		for k: int in n:
			var a: Vector2 = pts[k]
			var b: Vector2 = pts[(k + 1) % n]
			if Geometry2D.get_closest_point_to_segment(p2, a, b).distance_to(p2) <= pad:
				return true
	return false


func test_set_is_well_formed() -> void:
	var cfg: Dictionary = _load()
	assert_true(cfg.has("sets") and (cfg["sets"] as Dictionary).has(SET), "capture_cams.json has the %s set" % SET)
	var s: Dictionary = cfg["sets"][SET]
	assert_eq(str(s["map"]), MAP)
	var cams: Array = s["cams"]
	assert_gte(cams.size(), 20, "about 20 cameras")
	var names: Dictionary = {}
	for c: Dictionary in cams:
		var n: String = str(c["name"])
		assert_false(names.has(n), "camera name %s is unique" % n)
		names[n] = true
		assert_eq((c["pos"] as Array).size(), 3, "%s has a position" % n)
		assert_true(c.has("yaw") and c.has("pitch"), "%s has yaw and pitch" % n)
		var kind: String = str(c.get("kind", "view"))
		assert_true(["view", "zombie", "squad", "viewmodel"].has(kind), "%s kind %s is known" % [n, kind])
	for want: String in ["taproom_spawn", "taproom_bar", "stairs", "hayloft_west", "hayloft_gallery", "cellar_vault", "old_cellar_cage", "yard", "wreck", "field_edge", "close_zombie", "close_squad", "close_viewmodel"]:
		assert_true(names.has(want), "the order's %s view is in the list" % want)


func test_every_camera_stands_on_the_navmesh_inside_the_map() -> void:
	assert_gt(_polys.size(), 100, "Map 0's navmesh loaded")
	var cams: Array = _load()["sets"][SET]["cams"]
	for c: Dictionary in cams:
		var n: String = str(c["name"])
		var p: Vector3 = _v3(c["pos"])
		assert_true(p.x > -22.0 and p.x < 62.0 and p.z > -32.0 and p.z < 66.0 and p.y > -4.0 and p.y < 8.0, "%s inside Map 0's bounds" % n)
		assert_true(_near_navmesh(p), "%s at %s stands on or just above the navmesh" % [n, p])
		if c.has("subject"):
			assert_true(_near_navmesh(_v3(c["subject"])), "%s's subject is on the navmesh" % n)
		for s: Variant in c.get("subjects", []):
			assert_true(_near_navmesh(_v3(s)), "%s's subjects are on the navmesh" % n)


## T-094: the world-object set (one camera per object type, before / after) stands on the same floor, and its
## "do" steps are ones capture.gd knows.
func test_objects_set_stands_on_the_navmesh() -> void:
	var s: Dictionary = (_load()["sets"] as Dictionary).get("u05_objects", {})
	assert_false(s.is_empty(), "capture_cams.json has the u05_objects set")
	if s.is_empty():
		return
	assert_eq(str(s["map"]), MAP)
	var names: Dictionary = {}
	for c: Dictionary in s["cams"]:
		var n: String = str(c["name"])
		assert_false(names.has(n), "%s is unique" % n)
		names[n] = true
		assert_true(_near_navmesh(_v3(c["pos"])), "%s at %s stands on or just above the navmesh" % [n, str(c["pos"])])
		for op: Variant in c.get("do", []):
			assert_true(["power", "open", "tear", "exfil"].has(str(op).split(":")[0]), "%s: a known step (%s)" % [n, op])
	for want: String in ["perk_dark", "perk_powered", "crate", "ammo_box", "wall_buy_trench", "barricade_torn", "door_unbought",
			"door_bought", "bench", "crucible", "radio", "lever", "gate", "exfil_beacon"]:
		assert_true(names.has(want), "the objects set shows %s" % want)


func _load() -> Dictionary:
	var f: FileAccess = FileAccess.open("res://data/gravelight/capture_cams.json", FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
