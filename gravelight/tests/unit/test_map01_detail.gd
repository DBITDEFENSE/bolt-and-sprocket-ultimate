extends GutTest
## T-272: Kaltenbrunn's map detail pass (docs/u21/t272_map01_detail.md), the data and the scene file.
##   the Sherman: the full round-30 event through the yard's north gate (map01.json sherman_event, YardGate); the
##   running event is walked by smoke_map01_sherman.

const SCENE: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const GATE_X0: float = 17.6
const GATE_X1: float = 22.4

static var _scene: Node = null


static func _json() -> Dictionary:
	return GLData.load_json("res://data/gravelight/map01.json")


static func _v3(a: Variant) -> Vector3:
	var v: Array = a
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


func before_all() -> void:
	_scene = (load(SCENE) as PackedScene).instantiate()


func after_all() -> void:
	if _scene != null:
		_scene.free()
		_scene = null


static func _gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var p: Node = n
	while p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Every box collider of the scene: [{name, lo, hi}] (axis-aligned; the generator builds no rotated ones).
static func _boxes(root: Node) -> Array:
	var out: Array = []
	for n: Node in root.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = n as CollisionShape3D
		if not (cs.shape is BoxShape3D) or not (cs.get_parent() is StaticBody3D):
			continue
		var c: Vector3 = _gxf(cs).origin
		var h: Vector3 = (cs.shape as BoxShape3D).size * 0.5
		out.append({"name": String(cs.get_parent().name), "lo": c - h, "hi": c + h})
	return out


static func _route() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for p: Variant in _json()["sherman_event"]["route"]:
		out.append(_v3(p))
	return out


# ================================================================== the Sherman

func test_the_full_event_is_on() -> void:
	var b: Dictionary = _json()["sherman_event"]
	assert_true(ShermanEvent.block_has_tank(b), "a tank (no more \"tank\": false)")
	assert_eq(int(b["arrive_round"]), 30)
	assert_eq(int(b["stuka_round"]), 40)
	assert_eq(Array(b["assault_zones"]), ["A_MINEHEAD"], "the dead rise in the squad's own zone: open from round 1, so the fight is always reachable")
	assert_eq(Array(b["drive_zones"]), ["A_MINEHEAD"])
	assert_true(bool(b["shelter_roof"]), "the raid's shelters are still any roof")
	assert_false(b.has("barrier"), "no crushed barrier: the gate swings (YardGate)")
	for row: Dictionary in _json()["round_bosses"]:
		if int(row["round"]) == 30:
			assert_true(row.has("arrival"), "der Fuhrmann's round-30 row has the tank's beats")


func test_the_route_comes_in_through_the_gateway() -> void:
	var r: PackedVector3Array = _route()
	assert_gte(r.size(), 3)
	assert_lt(r[0].z, -20.0, "it starts north of the yard, on the rail line's terrace")
	for p: Vector3 in r:
		assert_eq(p.y, 0.0, "on the flat shelf (the drive snaps to each point's height)")
		assert_true(p.x >= KaltenTerrain.SHELF_MIN.x and p.x <= KaltenTerrain.SHELF_MAX.x and p.z >= KaltenTerrain.SHELF_MIN.y, "inside the shelf: %s" % str(p))
	# the last leg: wherever any of the hull is between the pillars, the whole hull is
	var a: Vector3 = r[r.size() - 2]
	var e: Vector3 = r[r.size() - 1]
	assert_lt(a.z, -6.0, "the last leg is a long straight run at the gate (from z %.1f)" % a.z)
	var worst: float = 0.0
	for k: int in 101:
		var p2: Vector3 = a.lerp(e, float(k) / 100.0)
		if p2.z > -1.2 - ShermanRules.HULL_STERN and p2.z < 0.15 - ShermanRules.HULL_BOW:
			worst = maxf(worst, absf(p2.x - 20.0) + ShermanRules.HULL_HALF_W)
	assert_lt(worst, (GATE_X1 - GATE_X0) * 0.5 - 0.3, "the hull clears both pillars by 0.3 m or more (%.2f of %.2f m)" % [worst, (GATE_X1 - GATE_X0) * 0.5])


func test_where_it_parks() -> void:
	var b: Dictionary = _json()["sherman_event"]
	var r: PackedVector3Array = _route()
	var park: Vector3 = r[r.size() - 1]
	var yaw: float = ShermanEvent._leg_yaw(r, r.size() - 2)
	var hull: Transform3D = Transform3D(Basis(Vector3.UP, yaw), park)
	assert_gt((-hull.basis.z).dot(Vector3(0, 0, 1)), 0.99, "it faces the yard")
	assert_true(ShermanRules.may_stand(hull, [], b), "parked, it stands where a driver may")
	for pt: Vector3 in ShermanRules.footprint(hull):
		assert_true(pt.z > 0.4 and pt.z < 9.7 and pt.x > 15.2 and pt.x < 24.8, "the hull is in the forecourt, out of the lanes: %s" % str(pt))
	var box: Array = (b["drive_boxes"] as Array)[0]
	assert_eq(float(box[0]), 15.2, "the drive box is the hoist house's width (the lanes past the gatehouse and the winding house stay open)")
	assert_eq(float(box[2]), 24.8)
	# the campaign's exfil beacon: off the route, clear of the parked hull, kept clear of the driven one
	var ex: Vector3 = _v3(_json()["exfil"]["position"])
	for k: int in r.size() - 1:
		var q: Vector3 = Geometry3D.get_closest_point_to_segment(ex, r[k], r[k + 1])
		assert_gt(Vector2(q.x - ex.x, q.z - ex.z).length(), ShermanRules.HULL_HALF_W + 1.0, "the beacon is clear of the tank's way in (leg %d)" % k)
	assert_gt(ShermanRules.hull_dist(hull, ex), 2.0, "and of the parked hull")
	var disc: Array = (b["drive_no_go"] as Array)[0]
	assert_lt(Vector2(float(disc[0]) - ex.x, float(disc[1]) - ex.z).length(), 0.01, "a driver cannot run it down")


func test_the_map_rows_lie_over_the_table() -> void:
	var t: Dictionary = ShermanEvent.table()
	var m0: Dictionary = ShermanEvent.block_for(&"map00_crossroads")
	assert_true(is_same(ShermanEvent.with_map_rows(t, m0), t), "Map 0: the table itself, untouched")
	var m1: Dictionary = ShermanEvent.with_map_rows(t, _json()["sherman_event"])
	assert_eq(str(m1["arrival"]["banner"]), "ARMOUR AT THE NORTH GATE")
	assert_eq(float(m1["arrival"]["drive_at"]), float(t["arrival"]["drive_at"]), "the rest of the row is the table's")
	assert_ne(str(t["arrival"]["banner"]), "ARMOUR AT THE NORTH GATE", "the shared table is not written to")
	assert_eq(m1["assist"], t["assist"])


func test_the_gate_in_the_scene() -> void:
	var gate: Node = _scene.find_child("YardGate", true, false)
	assert_not_null(gate, "the scene has its gate")
	if gate == null:
		return
	assert_eq((gate.get_script() as Script).resource_path, "res://gravelight/maps/map01_kaltenbrunn/yard_gate.gd")
	for leaf: String in ["LeafW", "LeafE"]:
		var l: Node3D = gate.get_node_or_null(leaf) as Node3D
		assert_not_null(l, leaf)
		if l != null:
			assert_gt(l.find_children("*", "MeshInstance3D", true, false).size(), 0, "%s is drawn" % leaf)
			assert_lte(l.find_children("*", "MeshInstance3D", true, false).size(), 4, "%s is baked (a few draw calls)" % leaf)
			assert_eq(l.find_children("*", "CollisionShape3D", true, false).size(), 0, "%s has no collider (the gateway's never moves)" % leaf)
	var shut: bool = false
	for bx: Dictionary in _boxes(_scene):
		var lo: Vector3 = bx["lo"]
		var hi: Vector3 = bx["hi"]
		if str(bx["name"]) == "Gate":
			shut = lo.x <= GATE_X0 and hi.x >= GATE_X1 and hi.y >= 4.0 and lo.z < 0.0
		elif str(bx["name"]).begins_with("YardN"):
			var over: bool = hi.x > GATE_X0 + 0.01 and lo.x < GATE_X1 - 0.01 and lo.y < 3.9
			assert_false(over, "no wall left in the gateway (%s)" % str(bx["name"]))
	assert_true(shut, "the gateway's collider spans it, full height: nobody walks out")
