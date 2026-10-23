class_name MapCheck
extends RefCounted
## The map-data bake check (Update 04 section 1, DECISIONS T-065): no playable level ships without its map.
## For every level in MapCatalog (the campaign chain + the B&S star map) it fails when:
##   - data/maps/<map_id>/mapdata.json is missing or does not belong to that map / game;
##   - a floor image is missing or not the size the data says;
##   - the floors differ from the bake config (data/maps/bake_config.json changed, not re-baked);
##   - (with scan) the POIs differ from what the scene has now (moved, added, removed, re-priced).
## Run by tools_src/check_mapdata.tscn (tools/check_mapdata.sh) and the GUT test test_mapdata.gd.
## Fix: tools/bake_minimap.sh <map_id>.


## Problems over every playable level ([] = all good).
static func check_all(scan: bool = true) -> PackedStringArray:
	var out: PackedStringArray = []
	for row: Dictionary in MapCatalog.playable_levels():
		out.append_array(check_level(row, scan))
	return out


static func check_level(row: Dictionary, scan: bool = true) -> PackedStringArray:
	var out: PackedStringArray = []
	var id: StringName = row["map_id"]
	var fix: String = " (run tools/bake_minimap.sh %s)" % id
	MapData.clear_cache()
	var md: MapData = MapData.for_map(id)
	if md == null:
		out.append("%s: no map data at %s%s" % [id, MapData.path_for(id), fix])
		return out
	if md.map_id != id or md.game != str(row["game"]):
		out.append("%s: mapdata.json is for %s (%s)%s" % [id, md.map_id, md.game, fix])
	if md.floors.is_empty():
		out.append("%s: no floors%s" % [id, fix])
	for i: int in md.floors.size():
		var path: String = md.floor_image_path(i)
		if not FileAccess.file_exists(path):
			out.append("%s: floor %d image missing: %s%s" % [id, i, path, fix])
			continue
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null or img.is_empty() or Vector2i(img.get_width(), img.get_height()) != md.image_size:
			out.append("%s: floor %d image is not %s%s" % [id, i, md.image_size, fix])
	var want: Array = []
	for f: Variant in MapBake.config_for(id, str(row["game"])).get("floors", []):
		want.append(str((f as Dictionary).get("id", "")))
	var have: Array = md.floors.map(func(f: Dictionary) -> String: return str(f.get("id", "")))
	if want != have:
		out.append("%s: floors %s, the bake config says %s%s" % [id, have, want, fix])
	if scan:
		var s: Dictionary = MapBake.scan_level(row)
		if s.has("error"):
			out.append("%s: %s" % [id, s["error"]])
			return out
		var now: MapData = MapBake.build(row, s)
		if now.poi_signature != md.poi_signature:
			out.append("%s: POIs out of date with the scene: %s%s" % [id, poi_diff(md.pois, now.pois), fix])
	return out


## A short human diff of two POI lists (added / removed / changed ids).
static func poi_diff(old: Array, new: Array) -> String:
	var a: Dictionary = {}
	var b: Dictionary = {}
	for p: Dictionary in old:
		a[str(p["id"])] = p
	for p2: Dictionary in new:
		b[str(p2["id"])] = p2
	var parts: PackedStringArray = []
	for k: String in b.keys():
		if not a.has(k):
			parts.append("+" + k)
		elif (a[k]["pos"] as Vector3).distance_to(b[k]["pos"] as Vector3) > 0.1 or int(a[k].get("price", 0)) != int(b[k].get("price", 0)) \
				or str(a[k].get("label", "")) != str(b[k].get("label", "")):
			parts.append("~" + k)
	for k2: String in a.keys():
		if not b.has(k2):
			parts.append("-" + k2)
	if parts.size() > 8:
		return "%s and %d more" % [", ".join(parts.slice(0, 8)), parts.size() - 8]
	return ", ".join(parts)
