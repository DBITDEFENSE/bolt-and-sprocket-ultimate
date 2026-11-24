extends Node
## Dev tool (T-274): re-reads the POIs of a level's scene into its data/maps/<id>/mapdata.json (and the signature
## over them), headless, keeping the floors, the zones and the baked floor images as they are. For a change that only
## moves buyables (the perk deal's seed-0 machines, a wall-buy) where the floor pictures do not change; a change to
## walls or floors still needs the real bake (tools/bake_minimap.sh, a rendered run).
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/refresh_mapdata_pois.tscn -- --map=<id>[,<id>...]


func _ready() -> void:
	var ids: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			ids = a.trim_prefix("--map=").split(",", false)
	var fails: int = 0
	for id: String in ids:
		MapData.clear_cache()
		var row: Dictionary = MapCatalog.level(StringName(id))
		var md: MapData = MapData.for_map(StringName(id))
		if row.is_empty() or md == null:
			print("[refresh_pois] %s: no level row or no map data (bake it first)" % id)
			fails += 1
			continue
		var scan: Dictionary = MapBake.scan_level(row)
		if scan.has("error"):
			print("[refresh_pois] %s: %s" % [id, scan["error"]])
			fails += 1
			continue
		var now: MapData = MapBake.build(row, scan)
		var diff: String = MapCheck.poi_diff(md.pois, now.pois)
		md.pois = now.pois
		md.poi_signature = now.poi_signature
		var fa: FileAccess = FileAccess.open(ProjectSettings.globalize_path(MapData.path_for(StringName(id))), FileAccess.WRITE)
		if fa == null:
			print("[refresh_pois] %s: could not write" % id)
			fails += 1
			continue
		fa.store_string(JSON.stringify(md.to_dict(), "  ", false))
		fa.close()
		print("[refresh_pois] %s: %d POIs (%s)" % [id, md.pois.size(), diff if diff != "" else "no change"])
	print("[refresh_pois] RESULT %s" % ("PASS" if fails == 0 else "FAIL %d" % fails))
	get_tree().quit(fails)
