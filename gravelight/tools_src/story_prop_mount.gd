extends RefCounted
## T-255 (UPDATE 19 fixes; the owner's screenshot: "Käthe's Drawing" hanging in the air a metre off its wall): are the
## hand-placed story items (data/gravelight/story_props.json) and the paper dressing (PaperDecor nodes) still on the
## surface they were placed on? A wall or a counter that a later layout pass moves leaves them behind: the data holds
## plain coordinates. Headless, from the scene file alone (the box colliders, like interactable_facing.gd).
##
## Wall styles (drawing, docket, clipping; a PaperDecor that is not flat): the back is at the origin, so a collider
## must start within WALL_GAP behind it, the origin must not be inside one, and the sheet's two edges must be on the
## same wall (not hanging past a corner or a door jamb). Flat styles (guest book, logbook, letter; a flat PaperDecor):
## a collider's top within FLAT_GAP under the origin and under the page's four corners. A surface that is only drawn
## (a library table, a shelf board) has no collider: those rows come back "UNSURE", never "OFF".
##
##   godot --headless --audio-driver Dummy --path . --script res://tools/tests/test_story_prop_mounts.gd [-- --maps=map00]

const Facing: GDScript = preload("res://gravelight/tools_src/interactable_facing.gd")
const DATA_PATH: String = "res://data/gravelight/story_props.json"
const WALL_STYLES: PackedStringArray = ["drawing", "docket", "clipping"]
const WALL_GAP: float = 0.035      # (the wainscot's boards and the timber trim stand up to 3 cm proud of the collider)
const FLAT_GAP: float = 0.04
const REACH: float = 1.6           # how far behind / below the search goes
const HALF_W: float = 0.14         # half the sheet's width (the narrowest wall item)
## Colliders that stand for open furniture: a sheet pinned inside one is on its drawn back board (Map 0's back-bar
## shelving, where Käthe's frequency slips hang by the wireless).
const OPEN_FURNITURE: PackedStringArray = ["BackShelf"]


## Rows for one instantiated (not entered) map scene: {name, kind ("wall" / "flat"), pos, gap, verdict, why}.
## verdict: "OK", "OFF" (no surface where it should be), "BURIED" (inside a collider), "UNSURE" (a flat item with no
## collider under it: the surface may be drawn only).
static func survey(map: Node, map_key: String) -> Array:
	var geo: Dictionary = Facing.index_geometry(map)
	var rows: Array = []
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if data is Dictionary:
		for e: Dictionary in (data as Dictionary).get("props", []):
			if str(e.get("map", "")) != map_key:
				continue
			var p: Array = e.get("position", [0, 0, 0])
			var xf: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(e.get("yaw", 0.0)))), Vector3(float(p[0]), float(p[1]), float(p[2])))
			rows.append(check_one(geo, "story:" + str(e.get("id", "?")), xf, WALL_STYLES.has(str(e.get("style", "")))))
	for n: Node in map.find_children("*", "Node3D", true, false):
		var sc: Script = n.get_script() as Script
		if sc == null or not sc.resource_path.ends_with("/paper_decor.gd"):
			continue
		rows.append(check_one(geo, "paper:" + str(n.name), Facing.gxf(n), not bool(n.get("flat"))))
	return rows


static func check_one(geo: Dictionary, name_: String, xf: Transform3D, wall: bool) -> Dictionary:
	var o: Vector3 = xf.origin
	var back: Vector3 = xf.basis.z.normalized()     # (the front is local -Z)
	var side: Vector3 = xf.basis.x.normalized()
	var row: Dictionary = {"name": name_, "kind": "wall" if wall else "flat", "pos": o, "gap": INF, "verdict": "OK", "why": ""}
	if wall:
		if OPEN_FURNITURE.has(_inside(geo, o - back * 0.02)):
			row["gap"] = 0.0
			row["why"] = "pinned inside open furniture (%s)" % _inside(geo, o - back * 0.02)
			return row
		if _inside(geo, o - back * 0.02) != "":
			row["verdict"] = "BURIED"
			row["why"] = "its face is inside %s" % _inside(geo, o - back * 0.02)
			row["gap"] = 0.0
			return row
		var g: float = _gap(geo, o, back)
		row["gap"] = g
		if g > WALL_GAP:
			row["verdict"] = "OFF"
			row["why"] = "no wall behind it" if g == INF else "the wall is %.2f m behind it" % g
			return row
		for s: float in [-1.0, 1.0]:
			var ge: float = _gap(geo, o + side * (s * HALF_W), back)
			if ge > WALL_GAP + 0.02:
				row["verdict"] = "OFF"
				row["why"] = "its %s edge hangs past the wall's end" % ("left" if s > 0.0 else "right")
				return row
			if _inside(geo, o + side * (s * HALF_W) - back * 0.02) != "":
				row["verdict"] = "BURIED"
				row["why"] = "its %s edge runs into %s" % ["left" if s > 0.0 else "right", _inside(geo, o + side * (s * HALF_W) - back * 0.02)]
				return row
	else:
		var worst: float = 0.0
		for c: Vector2 in [Vector2.ZERO, Vector2(-0.09, -0.12), Vector2(0.09, -0.12), Vector2(-0.09, 0.12), Vector2(0.09, 0.12)]:
			worst = maxf(worst, _gap(geo, o + side * c.x + back * c.y + Vector3.UP * 0.03, Vector3.DOWN) - 0.03)
		row["gap"] = worst
		if worst > FLAT_GAP:
			row["verdict"] = "UNSURE" if _gap(geo, o + Vector3.UP * 0.03, Vector3.DOWN) == INF else "OFF"
			row["why"] = "no collider under it (a drawn-only surface?)" if row["verdict"] == "UNSURE" else \
					("a corner of the page hangs over the edge" if _gap(geo, o + Vector3.UP * 0.03, Vector3.DOWN) - 0.03 <= FLAT_GAP else "the surface is %.2f m under it" % worst)
	return row


## Metres from `from` along `dir` to the first box collider (INF: none within REACH).
static func _gap(geo: Dictionary, from: Vector3, dir: Vector3) -> float:
	var d: float = 0.0
	while d <= REACH:
		if _inside(geo, from + dir * d) != "":
			return d
		d += 0.005
	return INF


static func _inside(geo: Dictionary, p: Vector3) -> String:
	for bb: Array in geo["boxes"]:
		var ab: AABB = bb[2]
		if not ab.grow(0.001).has_point(p):
			continue
		var q: Vector3 = (bb[0] as Transform3D) * p
		var h: Vector3 = bb[1]
		if absf(q.x) <= h.x and absf(q.y) <= h.y and absf(q.z) <= h.z:
			return str(bb[3])
	return ""


static func failures(rows: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rows:
		if str(r["verdict"]) == "OFF" or str(r["verdict"]) == "BURIED":
			out.append(r)
	return out
