extends GutTest
## T-175: the Crucible's room on every map (gravelight/world/crucible_room.gd, data/gravelight/crucible_rooms.json).
## Every map's config loads and builds; its props stay clear of the machine's approach (the use box and the bots'
## stand point, BotBrain._front_of) and off the baked navmesh unless they lie flat on the floor or hang over head height,
## so no path to the machine (or anywhere) runs through one; the stand point is on the navmesh; one shadowed light per
## room; a room is a handful of draw calls; the room reacts to the Crucible's signals without touching its timings.
## The navmesh is read straight out of each map's .tscn (no server sync): polygons are convex, so a 2D
## point-in-polygon on XZ with a height check does it (test_capture_cams.gd's method).

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const STAND: Vector3 = Vector3(0.0, 0.0, -1.95)   # 0.95 (the use box) + 1 m out, BotBrain._front_of
const SHRINK: float = 0.05                         # a footprint's edge may graze the navmesh's border cells
const DRAW_BUDGET: int = 24                        # meshes + labels a room may add (C4: <= 2500 a frame in view)

var _free: Array = []


func after_each() -> void:
	for n: Variant in _free:
		if is_instance_valid(n):
			(n as Node).free()
	_free.clear()


static func _gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## The navmesh polygons (world XZ points) whose height is within 1.2 m of `floor_y`.
static func _polys(map: Node, floor_y: float) -> Array:
	var out: Array = []
	for r: Node in map.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var rx: Transform3D = _gxf(r)
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var idx: PackedInt32Array = nm.get_polygon(i)
			var pts: PackedVector2Array = []
			var ys: float = 0.0
			for j: int in idx:
				var v: Vector3 = rx * verts[j]
				pts.append(Vector2(v.x, v.z))
				ys += v.y
			if absf(ys / maxf(1.0, idx.size()) - floor_y) < 1.2:
				out.append(pts)
	return out


static func _on_nav(polys: Array, p: Vector3) -> bool:
	for pts: PackedVector2Array in polys:
		if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), pts):
			return true
	return false


func test_every_map_has_a_room_that_builds() -> void:
	for key: String in MAPS:
		var d: Dictionary = CrucibleRoom.config_for(key)
		assert_false(d.is_empty(), "%s has a Crucible room" % key)
		var lay: Array = CrucibleRoom.layout(key)
		assert_gt(lay.size(), 4, "%s builds its pieces" % key)
		for e: Array in lay:
			assert_gt((e[2] as Array).size(), 0, "%s: piece %s builds something" % [key, str((e[1] as Dictionary).get("kind"))])
		var keys: int = 0
		var shadowed: int = 0
		for l: Dictionary in d.get("lights", []):
			if str(l.get("role", "")) == "key":
				keys += 1
			if bool(l.get("shadow", false)):
				shadowed += 1
		assert_eq(keys, 1, "%s has one key light on the machine" % key)
		assert_lte(shadowed, 1, "%s adds at most one shadowed light to its zone (C4: <= 6 a zone)" % key)
		assert_true(str(d.get("zone", "")) != "", "%s names its zone" % key)


func test_props_stay_out_of_the_approach() -> void:
	for key: String in MAPS:
		for e: Array in CrucibleRoom.layout(key):
			for ab: AABB in e[2]:
				if CrucibleRoom.is_standing(ab):
					assert_false(ab.intersects(CrucibleRoom.APPROACH), "%s: a %s part %s stands in the approach" % [key, str((e[1] as Dictionary).get("kind")), ab])


func test_props_stay_off_the_navmesh_and_the_stand_point_is_on_it() -> void:
	for key: String in MAPS:
		var map: Node = (load(MAPS[key]) as PackedScene).instantiate()
		var cru: Node3D = map.find_child("Crucible", true, false) as Node3D
		assert_not_null(cru, "%s has a Crucible" % key)
		if cru == null:
			map.free()
			continue
		var cx: Transform3D = _gxf(cru)
		var polys: Array = _polys(map, cx.origin.y)
		assert_true(_on_nav(polys, cx * STAND), "%s: the bots' stand point in front of the machine is on the navmesh" % key)
		var bad: int = 0
		for e: Array in CrucibleRoom.layout(key):
			for ab: AABB in e[2]:
				if not CrucibleRoom.is_standing(ab):
					continue
				var x0: float = ab.position.x + SHRINK
				var x1: float = ab.end.x - SHRINK
				var z0: float = ab.position.z + SHRINK
				var z1: float = ab.end.z - SHRINK
				var x: float = x0
				while x <= x1 + 0.001:
					var z: float = z0
					while z <= z1 + 0.001:
						if _on_nav(polys, cx * Vector3(x, 0.0, z)):
							bad += 1
							if bad < 6:
								fail_test("%s: a %s part %s stands on the navmesh at local (%.2f, %.2f)" % [key, str((e[1] as Dictionary).get("kind")), ab, x, z])
						z += maxf(0.1, minf(0.2, (z1 - z0) * 0.5))
					x += maxf(0.1, minf(0.2, (x1 - x0) * 0.5))
		assert_eq(bad, 0, "%s: every standing prop is off the navmesh" % key)
		map.free()


func test_room_builds_lights_draws_and_reacts() -> void:
	var cr: Crucible = Crucible.new()
	add_child(cr)
	_free.append(cr)
	var room: CrucibleRoom = CrucibleRoom.new()
	room.crucible = cr
	room.map_key = "map04a"
	room.data = CrucibleRoom.config_for("map04a")
	add_child(room)
	_free.append(room)
	room.build()
	var meshes: int = room.find_children("*", "MeshInstance3D", true, false).size()
	var labels: int = room.find_children("*", "Label3D", true, false).size()
	assert_gt(meshes, 3, "the props fold into a few material meshes")
	assert_lte(meshes + labels, DRAW_BUDGET, "a room is a handful of draw calls (%d meshes, %d labels)" % [meshes, labels])
	var shadowed: int = 0
	for e: Array in room.lights:
		if (e[0] as Light3D).shadow_enabled:
			shadowed += 1
	assert_eq(room.lights.size(), 3)
	assert_eq(shadowed, 1, "the key light is the room's only shadowed light")
	# idle -> forging: the glow ramps; ready: the sparks fire and the glow flares; the timers are the Crucible's own
	room._process(0.1)
	var idle_e: float = room.marke_mat.emission_energy_multiplier
	var forge_s: float = cr.forge_seconds
	GLBus.crucible_started.emit(1, &"kar98k_up")
	var steam_on: int = 0
	for f: Array in room.fx:
		if (f[0] as CPUParticles3D).visible and (f[0] as CPUParticles3D).name.contains("steam"):
			steam_on += 1
	assert_gt(steam_on, 0, "steam vents when a weapon goes in")
	cr.phase = Crucible.Phase.FORGING
	room._process(4.0)
	assert_gt(room.marke_mat.emission_energy_multiplier, idle_e, "the Marke glow ramps with the forge")
	cr.phase = Crucible.Phase.OFFERED
	GLBus.crucible_ready.emit(&"kar98k_up")
	var sparks: bool = false
	for f2: Array in room.fx:
		if (f2[0] as CPUParticles3D).visible and (f2[0] as CPUParticles3D).name.contains("sparks"):
			sparks = true
	assert_true(sparks, "sparks fly when the weapon comes out")
	room._process(5.0)
	for f3: Array in room.fx:
		assert_false((f3[0] as CPUParticles3D).visible, "the bursts hide again when spent")
	assert_eq(cr.forge_seconds, forge_s, "the room never touches the forge's timing")
	cr.phase = Crucible.Phase.IDLE


func test_unknown_map_gets_no_room() -> void:
	assert_true(CrucibleRoom.config_for("test").is_empty())
	assert_eq(CrucibleRoom.key_of(&"map04a_thalbach"), "map04a")
	assert_eq(CrucibleRoom.key_of(&"map00_crossroads"), "map00")
