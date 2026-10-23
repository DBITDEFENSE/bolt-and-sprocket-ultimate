class_name MapBake
extends RefCounted
## Turns a level scan (MapScan) and the bake config (data/maps/bake_config.json) into MapData (Update 04 section 1,
## DECISIONS T-065): floors with their XZ limits, the world rectangle the images cover, zones, POIs with their floor,
## and the stairs / ladders / lifts between floors. The bake (tools_src/bake_minimap.gd) adds the images and writes
## the JSON; the check (MapCheck) uses the same code to see whether what is on disk still matches the scene.

const CONFIG: String = "res://data/maps/bake_config.json"


static func config() -> Dictionary:
	return MapScan._json(CONFIG)


## The bake settings of one map: the defaults with the map's own row on top (floors replace, they don't merge).
static func config_for(map_id: StringName, game: String) -> Dictionary:
	var c: Dictionary = config()
	var d: Dictionary = (c.get("defaults", {}) as Dictionary).duplicate(true)
	var row: Dictionary = (c.get("maps", {}) as Dictionary).get(String(map_id), {})
	for k: Variant in row.keys():
		d[k] = row[k]
	if not d.has("style"):
		d["style"] = str((d.get("style_for_game", {}) as Dictionary).get(game, "ink"))
	d["style_cfg"] = (c.get("styles", {}) as Dictionary).get(str(d["style"]), {})
	return d


## Scans a catalog row's level. GRAVELIGHT: instantiates the packed scene (never added to the tree) and frees it.
## B&S: reads the level json. Returns MapScan's dictionary plus "game".
static func scan_level(row: Dictionary, keep_root: bool = false) -> Dictionary:
	var game: String = str(row.get("game", "gravelight"))
	if game == "bs":
		var s: Dictionary = MapScan.scan_bs(String(row["map_id"]))
		s["game"] = game
		return s
	var ps: PackedScene = load(str(row["scene"])) as PackedScene
	if ps == null:
		return {"error": "scene %s does not load" % row["scene"]}
	var root: Node = ps.instantiate()
	var s2: Dictionary = MapScan.scan_gl(root)
	s2["game"] = game
	if keep_root:
		s2["root"] = root
	else:
		root.free()
	return s2


## MapData (everything except image paths / bake time) from a scan.
static func build(row: Dictionary, scan: Dictionary) -> MapData:
	var map_id: StringName = row["map_id"]
	var game: String = str(row.get("game", "gravelight"))
	var cfg: Dictionary = config_for(map_id, game)
	var md: MapData = MapData.new()
	md.map_id = map_id
	md.game = game
	md.style = str(cfg["style"])
	md.display_name = str(scan.get("name", row.get("display_name", map_id))) if game == "bs" else str(row.get("display_name", map_id))
	# zones
	var names: Dictionary = MapScan.gl_zone_names(map_id) if game == "gravelight" else {}
	for k: Variant in (cfg.get("zone_names", {}) as Dictionary).keys():
		names[str(k)] = str(cfg["zone_names"][k])
	if game == "gravelight":
		md.zones = MapScan.zones_from_boxes(scan.get("zone_boxes", []), names)
	else:
		for z: Dictionary in scan.get("zones", []):
			var polys: Array[PackedVector2Array] = [MapScan._rect_poly(z["rect"] as Rect2)]
			md.zones.append({"id": z["id"], "name": z["name"], "y_min": -INF, "y_max": INF, "polys": polys})
	# floors
	var i: int = 0
	for f: Variant in cfg.get("floors", []):
		var fd: Dictionary = (f as Dictionary).duplicate(true)
		var rects: Array[Rect2] = []
		for zid: Variant in fd.get("zones", []):
			for b: Dictionary in scan.get("zone_boxes", []):
				if str(b["id"]) == str(zid):
					var ab: AABB = b["aabb"]
					rects.append(Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z))
		fd.erase("zones")
		fd["rects"] = rects
		fd["index"] = i
		for k2: String in ["y_min", "y_max", "base_y", "cut"]:
			fd[k2] = float(fd.get(k2, 0.0))
		fd["depth"] = float(fd.get("depth", 0.6))
		fd["image"] = "floor_%d_%s.png" % [i, str(fd.get("id", "f%d" % i))]
		md.floors.append(fd)
		i += 1
	# world rect: walkable bounds + margin, snapped to whole pixels
	var b2: Rect2 = scan.get("bounds", Rect2(-50, -50, 100, 100))
	var margin: float = float(cfg.get("margin_m", 6.0))
	b2 = b2.grow(margin)
	var ppm: float = float(cfg.get("px_per_m", 6.0))
	var max_px: float = float(cfg.get("max_px", 1600))
	ppm = minf(ppm, max_px / maxf(b2.size.x, b2.size.y))
	var w: int = maxi(16, int(ceil(b2.size.x * ppm)))
	var h: int = maxi(16, int(ceil(b2.size.y * ppm)))
	var c: Vector2 = b2.get_center()
	md.px_per_m = ppm
	md.image_size = Vector2i(w, h)
	md.world_rect = Rect2(c.x - w / ppm * 0.5, c.y - h / ppm * 0.5, w / ppm, h / ppm)
	# POIs with their floors
	for p: Dictionary in scan.get("pois", []):
		var pd: Dictionary = p.duplicate(true)
		pd["floor"] = md.floor_at((pd["pos"] as Vector3) + Vector3.UP * 0.3)
		md.pois.append(pd)
		md._poi_index[str(pd["id"])] = pd
	md.poi_signature = MapScan.poi_signature(md.pois)
	# connectors between floors
	var raw: Array[Dictionary] = []
	for ab2: AABB in scan.get("stairs", []):
		raw.append({"kind": "stairs", "a": Vector3(ab2.get_center().x, ab2.position.y, ab2.get_center().z),
			"b": Vector3(ab2.get_center().x, ab2.end.y, ab2.get_center().z)})
	for l: Dictionary in scan.get("lifts", []):
		raw.append({"kind": "lift", "a": l["a"], "b": l["b"]})
	if game == "gravelight":
		for cl: Dictionary in MapScan.climb_links(map_id):
			raw.append({"kind": "ladder", "a": cl["a"], "b": cl["b"]})
	for ec: Variant in cfg.get("extra_connectors", []):
		var e: Dictionary = ec as Dictionary
		raw.append({"kind": str(e.get("kind", "stairs")), "a": MapScan._v3(e.get("a")), "b": MapScan._v3(e.get("b"))})
	for r: Dictionary in raw:
		var fa: int = md.floor_at((r["a"] as Vector3) + Vector3.UP * 0.3)
		var fb: int = md.floor_at((r["b"] as Vector3) + Vector3.UP * 0.3)
		if fa == fb:
			continue
		r["floor_a"] = mini(fa, fb)
		r["floor_b"] = maxi(fa, fb)
		md.connectors.append(r)
	return md
