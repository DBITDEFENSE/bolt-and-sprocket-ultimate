extends GutTest
## T-229: the maps' ladders and zip lines (data/gravelight/<map>.json "ladders" / "ziplines", spawned by MapRoot as
## LadderClimb / ZipLine) are well formed: every row names its ends, a climb rises or falls by more than a step, a
## gated ladder names a zone the map has, and a ladder's zombies have a climb link up the same line (within a metre of
## the climb's ends), so no ladder is a safe route for players alone. The ends' navmesh is probe_ladder_tops.gd's and
## smoke_ladders' business.

const MAPS: Array = ["map00", "map02", "map04a", "map04c"]


func _rows(map: String, key: String) -> Array:
	var path: String = "res://data/gravelight/%s.json" % map
	if not FileAccess.file_exists(path):
		return []
	return (GLData.load_json(path) as Dictionary).get(key, [])


func _v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func test_ladder_rows_are_well_formed() -> void:
	var total: int = 0
	for map: String in MAPS:
		var zones: Dictionary = (GLData.load_json("res://data/gravelight/%s.json" % map) as Dictionary).get("zones", {})
		for row: Dictionary in _rows(map, "ladders"):
			total += 1
			var nm: String = "%s/%s" % [map, str(row.get("name", "?"))]
			assert_true(row.has("pos") and row.has("to"), nm + " names both ends")
			var rise: float = _v3(row["to"]).y - _v3(row["pos"]).y
			if bool(row.get("down", false)):
				assert_lt(rise, -0.5, nm + " climbs down more than a step")
			else:
				assert_gt(rise, 0.5, nm + " climbs up more than a step")
			var zone: String = str(row.get("zone", ""))
			if zone != "" and not zones.is_empty():
				assert_true(zones.has(zone), nm + " gates on a zone the map has (%s)" % zone)
	assert_gt(total, 3, "the maps list ladders")


func test_every_ladder_has_a_zombie_climb_link() -> void:
	for map: String in MAPS:
		var links: Array = _rows(map, "climb_links")
		for row: Dictionary in _rows(map, "ladders"):
			if bool(row.get("down", false)):
				continue   # the head's node shares the foot's link
			var foot: Vector3 = _v3(row["pos"])
			var head: Vector3 = _v3(row["to"])
			var found: bool = false
			for l: Dictionary in links:
				if _v3(l["from"]).distance_to(foot) < 1.0 and _v3(l["to"]).distance_to(head) < 1.0:
					found = true
			assert_true(found, "%s/%s: the zombies have a climb link up the same ladder" % [map, str(row.get("name", "?"))])


func test_zip_lines_run_downhill_to_a_landing() -> void:
	var total: int = 0
	for map: String in MAPS:
		for row: Dictionary in _rows(map, "ziplines"):
			total += 1
			var nm: String = "%s/%s" % [map, str(row.get("name", "?"))]
			var top: Vector3 = _v3(row["pos"])
			var end: Vector3 = _v3(row["end"])
			var to: Vector3 = _v3(row["to"])
			assert_gt(top.y - end.y, 1.0, nm + " runs downhill")
			assert_lt(end.distance_to(to), 3.5, nm + " lands by its post")
			assert_gt(float(row.get("speed", 7.0)), 2.0, nm + " moves")
	assert_gt(total, 0, "there is a zip line")


# ---------------------------------------------------------------- T-268: the watchtower, its three zip lines, the ladders the dead climb

const MAP00: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _m0: Node = null
var _m0_polys: Array = []     # [plan (PackedVector2Array), mean y]


func after_all() -> void:
	if _m0 != null:
		_m0.free()
		_m0 = null


## The generated Map 0 (not in the tree) and its baked polygons, once.
func _map00() -> Node:
	if _m0 == null:
		_m0 = (load(MAP00) as PackedScene).instantiate()
		var r: NavigationRegion3D = _m0.get_node_or_null("Navigation") as NavigationRegion3D
		if r != null and r.navigation_mesh != null:
			var verts: PackedVector3Array = r.navigation_mesh.get_vertices()
			for i: int in r.navigation_mesh.get_polygon_count():
				var plan: PackedVector2Array = []
				var y: float = 0.0
				var idx: PackedInt32Array = r.navigation_mesh.get_polygon(i)
				for j: int in idx:
					plan.append(Vector2(verts[j].x, verts[j].z))
					y += verts[j].y
				_m0_polys.append([plan, y / float(idx.size())])
	return _m0


## True when `p` stands on Map 0's baked navmesh (inside a polygon within 0.9 m of its height).
func _on_nav00(p: Vector3) -> bool:
	_map00()
	for poly: Array in _m0_polys:
		if absf(float(poly[1]) - p.y) < 0.9 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), poly[0]):
			return true
	return false


## The zone of the first zone volume of Map 0 that holds `p` ("" outside them all), as ZoneVolume.zone_at reads it.
func _zone00(p: Vector3) -> String:
	for n: Node in _map00().find_children("Zone_*", "", true, false):
		var c: Vector3 = (n as Node3D).position
		var s: Vector3 = n.get("size")
		if absf(p.x - c.x) <= s.x * 0.5 and absf(p.z - c.z) <= s.z * 0.5 and p.y - c.y >= -0.5 and p.y - c.y <= s.y:   # (ZoneVolume.contains)
			return str(n.get("zone_id"))
	return ""


func test_map00_has_three_zip_lines_from_the_tower_top_to_three_places() -> void:
	var rows: Array = _rows("map00", "ziplines")
	assert_eq(rows.size(), 3, "three zip lines")
	var ladders: Dictionary = {}
	for l: Dictionary in _rows("map00", "ladders"):
		ladders[str(l["name"])] = l
	assert_true(ladders.has("TowerLadder_Upper"), "the tower has a second stage")
	if rows.size() != 3 or not ladders.has("TowerLadder_Upper"):
		return
	var top: Vector3 = _v3(ladders["TowerLadder_Upper"]["to"])
	assert_gt(top.y, 11.0, "the top platform is about twice the old deck's 6.2 m (%.1f)" % top.y)
	var names: Dictionary = {}
	var targets: Dictionary = {}
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var nm: String = str(row["name"])
		names[nm] = true
		targets[str(row.get("target", ""))] = true
		var a: Vector3 = _v3(row["pos"])
		var e: Vector3 = _v3(row["end"])
		var to: Vector3 = _v3(row["to"])
		assert_almost_eq(a.y, top.y + 2.0, 0.05, nm + ": the anchor is 2 m over the top platform (a standing rider's hands reach the bar)")
		assert_lt(Vector2(a.x - top.x, a.z - top.z).length(), 5.5, nm + ": the anchor is on the tower's top")
		var run: float = Vector2(e.x - a.x, e.z - a.z).length()
		var slope: float = rad_to_deg(atan2(a.y - e.y, run))
		assert_between(slope, 15.0, 30.0, nm + ": a cable's slope, not a drop (%.1f degrees over %.1f m)" % [slope, run])
		assert_lt(9.8 * sin(deg_to_rad(slope)), 5.0, nm + ": the trolley's brake (5 m/s2) holds the speed cap on this slope")
		var back: Vector3 = to - e
		assert_between(Vector2(back.x, back.z).length(), 0.5, 1.5, nm + ": the rider is set down a step short of the post")
		assert_gt(Vector2(back.x, back.z).normalized().dot(Vector2(a.x - e.x, a.z - e.z).normalized()), 0.95, nm + ": ...on the line, tower side of the post")
		assert_almost_eq(e.y - to.y, float(row.get("hang", 2.7)), 0.3, nm + ": the feet come in just over the ground")
		assert_true(_on_nav00(to), nm + ": the landing is on the baked navmesh")
		# a landing beyond a paid door needs that door: its zone is the tower's own (YARD) or the row's `zone`
		var lz: String = _zone00(to + Vector3.UP * 0.6)
		assert_ne(lz, "", nm + ": the landing is inside a zone")
		if lz != "YARD":
			assert_eq(str(row.get("zone", "")), lz, nm + ": it lands in %s, so it is chained until %s is open" % [lz, lz])
			assert_ne(str(row.get("locked_text", "")), "", nm + ": the chained line says so")
		# no landing in a spawn: every spawn marker and every barricade is well clear
		for sp: Node in _map00().find_children("*", "Marker3D", true, false):
			if sp.get("zone_id") != null and sp.get("kind") != null:
				var sp_at: Vector3 = (sp as Node3D).position
				assert_gt(Vector2(sp_at.x - to.x, sp_at.z - to.z).length(), 3.5, "%s: clear of the spawn %s" % [nm, sp.name])
		# the generator built this line's post where the row ends
		var post: bool = false
		for b: Node in _map00().find_children("ZipPost_*", "StaticBody3D", true, false):
			var bp: Vector3 = (b as Node3D).position
			if Vector2(bp.x - e.x, bp.z - e.z).length() < 0.05:
				post = true
		assert_true(post, nm + ": gen_map00 built a post where the cable ends")
		for j: int in i:
			assert_gt(_v3(rows[j]["to"]).distance_to(to), 15.0, "%s and %s land in different places" % [nm, str(rows[j]["name"])])
	assert_eq(names.size(), 3, "three names")
	for stage: String in ["TowerLadder_Foot", "TowerLadder_Upper"]:
		assert_eq(_zone00(_v3(ladders[stage]["to"])), "YARD", "the tower's %s is in the yard's zone (spawns, the horse's siege, the minimap's label)" % ("landing" if stage == "TowerLadder_Foot" else "top platform"))
	assert_eq(targets.size(), 3, "each line is named for where it goes")


func test_ladder_climb_links_are_valid() -> void:
	var ladder_links: int = 0
	for map: String in MAPS:
		var by_name: Dictionary = {}
		for l: Dictionary in _rows(map, "climb_links"):
			by_name[str(l.get("name", ""))] = l
			var nm: String = "%s/%s" % [map, str(l.get("name", "?"))]
			assert_true(l.has("from") and l.has("to"), nm + " names both ends")
			if not l.has("line"):
				assert_false(bool(l.get("drop", false)), nm + ": only a ladder (a row with a line) may be dropped down")
				continue
			ladder_links += 1
			var from: Vector3 = _v3(l["from"])
			var to: Vector3 = _v3(l["to"])
			var line: Vector2 = Vector2(float(l["line"][0]), float(l["line"][1]))
			assert_gt(to.y - from.y, 1.5, nm + ": a ladder goes up")
			assert_lt(Vector2(from.x, from.z).distance_to(line), 1.8, nm + ": the foot is a step from the ladder's line")
			assert_lt(Vector2(to.x, to.z).distance_to(line), 2.0, nm + ": the head is a step from the ladder's line")
			assert_gt(float(l.get("space", ClimbLink.SPACE)), 1.7, nm + ": two climbers are a body apart")
			if bool(l.get("drop", false)):
				assert_true(bool(l.get("bidirectional", false)), nm + ": a ladder they drop down is a two-way link")
			# the players' ladder on the same rungs shares the line
			var shared: bool = false
			for row: Dictionary in _rows(map, "ladders"):
				if row.has("line") and Vector2(float(row["line"][0]), float(row["line"][1])).distance_to(line) < 0.05:
					shared = true
			assert_true(shared, nm + ": the players' LadderClimb is on the same line")
			if map == "map00":
				assert_true(_on_nav00(from), nm + ": the foot is on the baked navmesh")
				assert_true(_on_nav00(to), nm + ": the head is on the baked navmesh")
		if map == "map00":
			assert_true(by_name.has("Climb_Tower") and by_name.has("Climb_TowerUpper"), "the tower's two stages each have a link")
			if by_name.has("Climb_Tower") and by_name.has("Climb_TowerUpper"):
				assert_almost_eq(_v3(by_name["Climb_TowerUpper"]["from"]).y, _v3(by_name["Climb_Tower"]["to"]).y, 0.01, "the upper ladder starts on the landing the lower one ends on")
				assert_true(bool(by_name["Climb_Tower"].get("drop", false)) and bool(by_name["Climb_TowerUpper"].get("drop", false)), "the dead can come back down both stages")
	assert_gt(ladder_links, 1, "Map 0's tower ladders are ladder links")


func test_climb_queue_keeps_room_between_climbers() -> void:
	var link: NavigationLink3D = NavigationLink3D.new()
	var a: _Climber = _Climber.new()
	var b: _Climber = _Climber.new()
	add_child_autofree(a)
	add_child_autofree(b)
	assert_true(ClimbLink.try_enter(link, a, 0.0) and ClimbLink.try_enter(link, b, 0.0), "a link without a line never queues")
	link.set_meta(ClimbLink.LINE, Vector2.ZERO)
	a.link = link
	b.link = link
	assert_true(ClimbLink.try_enter(link, a, 0.0), "the first body takes the ladder")
	a.climbing = true
	a.position.y = 0.4
	assert_false(ClimbLink.try_enter(link, b, 0.0), "the second waits while the first is at the foot")
	a.position.y = ClimbLink.SPACE - 0.1
	assert_false(ClimbLink.try_enter(link, b, 0.0), "...and until it is a body up")
	a.position.y = ClimbLink.SPACE + 0.1
	assert_true(ClimbLink.try_enter(link, b, 0.0), "then it follows")
	b.climbing = true
	b.position.y = 0.2
	assert_eq(ClimbLink.on_ladder(link), 2, "two on the rungs")
	a.climbing = false   # over the edge, or dead
	assert_eq(ClimbLink.on_ladder(link), 1, "a body that left the rungs no longer counts")
	link.free()


class _Climber extends Node3D:
	var link: NavigationLink3D = null
	var climbing: bool = false

	func on_rungs(l: NavigationLink3D) -> bool:
		return climbing and l == link


## T-268: the tower's lights. The lanterns burn from the start and cast no shadows; the searchlight is electric (dark
## until the lever's sweep reaches its zone, which must be one the sweep visits) and is the only one that asks for one.
func test_map00_tower_lights() -> void:
	var m: Node = _map00()
	var lamps: int = 0
	for n: Node in m.get_children():
		if n is OmniLight3D and (String(n.name).begins_with("YardTower") or String(n.name).begins_with("YardZipLamp")):
			lamps += 1
			assert_false((n as Light3D).shadow_enabled, "%s casts no shadow" % n.name)
			assert_true((n as Light3D).visible and not n.is_in_group(&"power_lights"), "%s is an oil lantern: it burns without the power" % n.name)
			assert_lte((n as OmniLight3D).omni_range, 16.0, "%s has a lantern's reach" % n.name)
	assert_eq(lamps, 9, "five lanterns and the masthead lamp on the tower, one lantern at each of the three landing posts")
	var sl: SpotLight3D = m.get_node_or_null("YardTowerSearchlight") as SpotLight3D
	assert_not_null(sl, "the searchlight")
	if sl == null:
		return
	assert_true(sl.is_in_group(&"power_lights") and not sl.visible, "the searchlight is dark until the power is on")
	var order: PackedStringArray = []
	for sw: Node in m.find_children("*", "", true, false):
		if sw.get("zone_order") != null:
			order = sw.get("zone_order")
	assert_true(order.has(str(sl.get_meta("zone", ""))), "its zone (%s) is one the lever's sweep lights" % str(sl.get_meta("zone", "")))
	assert_gt(sl.position.y, 14.0, "it is over the top platform's heads (y %.1f)" % sl.position.y)
