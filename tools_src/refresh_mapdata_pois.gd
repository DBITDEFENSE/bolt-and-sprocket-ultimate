extends Node
## Dev tool (T-141): rewrites the POIs and the POI signature of data/maps/<map_id>/mapdata.json from the scene as it
## is now, WITHOUT the GPU bake (floor images, floors, zones, world rect and connectors stay as they are). Use it
## when a change only adds, moves or removes points of interest (a new machine, a bank branch) and the map's
## footprint did not change: it refuses a map whose world rect or image size would change (that needs a real
## `tools/bake_minimap.sh <map_id>`). A scene, not a --script run: the scan needs the autoloads.
##   godot --headless --audio-driver Dummy --path . res://tools_src/refresh_mapdata_pois.tscn [-- --maps=map00_crossroads,map02_totenhafen]
## Prints "[refresh_pois] RESULT PASS|FAIL".


func _ready() -> void:
	var only: PackedStringArray = PackedStringArray()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			only = a.substr(7).split(",")
	var fails: int = 0
	for row: Dictionary in MapCatalog.playable_levels():
		var id: StringName = row["map_id"]
		if not only.is_empty() and not only.has(String(id)):
			continue
		MapData.clear_cache()
		var md: MapData = MapData.for_map(id)
		if md == null:
			print("[refresh_pois] %s: no map data (bake it first)" % id)
			fails += 1
			continue
		var scan: Dictionary = MapBake.scan_level(row)
		if scan.has("error"):
			print("[refresh_pois] %s: %s" % [id, scan["error"]])
			fails += 1
			continue
		var now: MapData = MapBake.build(row, scan)
		if now.world_rect.position.distance_to(md.world_rect.position) > 0.01 or now.world_rect.size.distance_to(md.world_rect.size) > 0.01 \
				or now.image_size != md.image_size or now.floors.size() != md.floors.size():
			print("[refresh_pois] %s: the map's extent changed (%s -> %s): run tools/bake_minimap.sh %s" % [id, md.world_rect, now.world_rect, id])
			fails += 1
			continue
		var diff: String = MapCheck.poi_diff(md.pois, now.pois)
		md.pois = now.pois
		md._poi_index.clear()
		for p: Dictionary in md.pois:
			md._poi_index[str(p["id"])] = p
		md.poi_signature = MapScan.poi_signature(md.pois)
		var path: String = ProjectSettings.globalize_path(MapData.path_for(id))
		var fa: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if fa == null:
			print("[refresh_pois] %s: cannot write %s" % [id, path])
			fails += 1
			continue
		fa.store_string(JSON.stringify(md.to_dict(), "  ", false))
		fa.close()
		print("[refresh_pois] %-20s %d POIs  %s" % [id, md.pois.size(), diff if diff != "" else "(no change)"])
	MapData.clear_cache()
	print("[refresh_pois] RESULT %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(0 if fails == 0 else 1)
