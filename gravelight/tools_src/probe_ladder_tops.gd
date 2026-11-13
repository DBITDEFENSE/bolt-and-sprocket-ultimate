extends SceneTree
## Ladder audit (T-229): loads a generated map scene and, for a list of points (each drawn ladder's foot and head),
## prints how far the nearest baked navmesh polygon is, with every navigation layer open. A head with navmesh within
## 1.2 m is a ladder that can work (a LadderClimb at both ends, a climb link for the zombies); one with none leads to
## no floor at all (so it gets a guard, or is laid down, or its landing is built).
##   godot --headless --path . --script res://gravelight/tools_src/probe_ladder_tops.gd -- --map=map00 ["--pts=label:x,y,z;label:x,y,z"]
## Without --pts it checks the map json's ladders (both ends), zip lines (the landing) and climb links (both ends).

const SCENES: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
}


func _initialize() -> void:
	var map: String = "map00"
	var pts: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			map = a.substr(6)
		elif a.begins_with("--pts="):
			for row: String in a.substr(6).split(";", false):
				var lab: String = row.get_slice(":", 0)
				var xyz: PackedStringArray = row.get_slice(":", 1).split(",", false)
				pts.append([lab, Vector3(float(xyz[0]), float(xyz[1]), float(xyz[2]))])
	if pts.is_empty():   # no --pts: the map json's ladders (both ends) and zip lines (the landing)
		var jp: String = "res://data/gravelight/%s.json" % map
		if FileAccess.file_exists(jp):
			var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jp))
			for row: Dictionary in d.get("ladders", []):
				pts.append([str(row.get("name", "?")) + ".pos", _arr(row.get("pos", [0, 0, 0]))])
				pts.append([str(row.get("name", "?")) + ".to", _arr(row.get("to", [0, 0, 0]))])
			for row2: Dictionary in d.get("ziplines", []):
				pts.append([str(row2.get("name", "?")) + ".to", _arr(row2.get("to", [0, 0, 0]))])
			for row3: Dictionary in d.get("climb_links", []):
				pts.append([str(row3.get("name", "?")) + ".from", _arr(row3.get("from", [0, 0, 0]))])
				pts.append([str(row3.get("name", "?")) + ".to", _arr(row3.get("to", [0, 0, 0]))])
	var path: String = str(SCENES.get(map, map))
	var ps: PackedScene = load(path)
	if ps == null:
		push_error("no scene " + path)
		quit(2)
		return
	var scene: Node = ps.instantiate()
	# the baked polygons straight from the scene's NavigationRegion3Ds (the facing runner's way: no server sync needed)
	var polys: Array = []
	for r: Node in scene.find_children("*", "NavigationRegion3D", true, false):
		var nm: NavigationMesh = (r as NavigationRegion3D).navigation_mesh
		if nm == null:
			continue
		var rx: Transform3D = _gxf(r)
		var verts: PackedVector3Array = nm.get_vertices()
		for i: int in nm.get_polygon_count():
			var idx: PackedInt32Array = nm.get_polygon(i)
			var plan: PackedVector2Array = []
			var v3: PackedVector3Array = []
			for j: int in idx:
				var v: Vector3 = rx * verts[j]
				plan.append(Vector2(v.x, v.z))
				v3.append(v)
			polys.append([plan, v3])
	print("LADDER_PROBE %s (%d polygons)" % [map, polys.size()])
	for a2: String in OS.get_cmdline_user_args():   # --dump=x0,z0,x1,z1: every polygon centroid in that plan box
		if a2.begins_with("--dump="):
			var q: PackedStringArray = a2.substr(7).split(",", false)
			for poly: Array in polys:
				var c: Vector3 = Vector3.ZERO
				for v: Vector3 in (poly[1] as PackedVector3Array):
					c += v
				c /= float((poly[1] as PackedVector3Array).size())
				if c.x >= float(q[0]) and c.z >= float(q[1]) and c.x <= float(q[2]) and c.z <= float(q[3]):
					print("  poly centroid %s (%d verts)" % [_v(c), (poly[1] as PackedVector3Array).size()])
	for p: Array in pts:
		var at: Vector3 = p[1]
		var best: float = 1e9
		var near: Vector3 = Vector3.ZERO
		for poly: Array in polys:
			var v3: PackedVector3Array = poly[1]
			var ymid: float = 0.0
			for v: Vector3 in v3:
				ymid += v.y
			ymid /= float(v3.size())
			if absf(ymid - at.y) < 0.9 and Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), poly[0]):
				best = 0.0
				near = Vector3(at.x, ymid, at.z)
				break
			for v: Vector3 in v3:
				var d: float = v.distance_to(at)
				if d < best:
					best = d
					near = v
		print("  %-22s at %s  nav %s  d %.2f  %s" % [str(p[0]), _v(at), _v(near), best, "OK" if best < 1.2 else "NO FLOOR"])
	scene.free()
	quit(0)


func _gxf(n: Node) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _arr(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


func _v(v: Vector3) -> String:
	return "(%.2f %.2f %.2f)" % [v.x, v.y, v.z]
