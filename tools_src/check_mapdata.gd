extends Node
## The map-data bake check as a tool (Update 04 section 1, DECISIONS T-065): every playable level (MapCatalog) has
## its map data, floor images and POIs up to date with its scene (MapCheck). A scene, not a --script run: the scan
## needs the autoloads the level scripts use.
##   godot --headless --audio-driver Dummy --path . res://tools_src/check_mapdata.tscn [-- --quick]
## --quick skips the scene scans (data and images only). Prints "[check_mapdata] RESULT PASS|FAIL"; exit code 0/1.


func _ready() -> void:
	var quick: bool = OS.get_cmdline_user_args().has("--quick")
	var t0: int = Time.get_ticks_msec()
	var problems: PackedStringArray = MapCheck.check_all(not quick)
	for p: String in problems:
		print("[check_mapdata]   ", p)
	print("[check_mapdata] %d levels, %.1fs" % [MapCatalog.playable_levels().size(), (Time.get_ticks_msec() - t0) / 1000.0])
	print("[check_mapdata] RESULT %s" % ("PASS" if problems.is_empty() else "FAIL"))
	get_tree().quit(0 if problems.is_empty() else 1)
