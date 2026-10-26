extends Node
## Dev tool: rewrites the "poi_signature" field of every data/maps/<id>/mapdata.json with MapScan.poi_signature of
## the file's own POIs (run after the signature formula changes; nothing else in the file is touched).
## Headless: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/resign_mapdata.tscn


func _ready() -> void:
	var dir: DirAccess = DirAccess.open("res://data/maps")
	for d: String in dir.get_directories():
		var path: String = "res://data/maps/%s/mapdata.json" % d
		if not FileAccess.file_exists(path):
			continue
		var md: MapData = MapData.for_map(StringName(d))
		if md == null:
			print("[resign] %s: no MapData" % d)
			continue
		var sig: String = MapScan.poi_signature(md.pois)
		var raw: String = FileAccess.get_file_as_string(path)
		var re: RegEx = RegEx.create_from_string("(\"poi_signature\"\\s*:\\s*\")[0-9a-f]*(\")")
		var m: RegExMatch = re.search(raw)
		if m == null:
			print("[resign] %s: no signature field" % d)
			continue
		raw = raw.substr(0, m.get_start()) + m.get_string(1) + sig + m.get_string(2) + raw.substr(m.get_end())
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string(raw)
		f.close()
		print("[resign] %-20s %s" % [d, sig])
	get_tree().quit()
