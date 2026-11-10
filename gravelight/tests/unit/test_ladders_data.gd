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
