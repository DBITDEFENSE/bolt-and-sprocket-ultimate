extends SceneTree
## T-255: are the story items and the paper dressing still on their walls and tables? (gravelight/tools_src/
## story_prop_mount.gd). Headless, from the scene files:
##
##   godot --headless --audio-driver Dummy --path . --script res://tools/tests/test_story_prop_mounts.gd
##       [-- --maps=map00,map01] [--report-only]
##
## Default: every map. Exit code = the number of items OFF their surface or BURIED in one (0 with --report-only).
## UNSURE (a flat item on a surface that is only drawn) is reported, never failed.

const Mount: GDScript = preload("res://gravelight/tools_src/story_prop_mount.gd")

## map id -> [scene, the story_props.json "map" key]
const MAPS: Dictionary = {
	"map00": ["res://gravelight/maps/map00_crossroads/map00.tscn", "0"],
	"map01": ["res://gravelight/maps/map01_kaltenbrunn/map01.tscn", "1"],
	"map02": ["res://gravelight/maps/map02_totenhafen/map02.tscn", "2"],
	"map04a": ["res://gravelight/maps/map04_fernflug/map04a.tscn", "4a"],
	"map04b": ["res://gravelight/maps/map04_fernflug/map04b.tscn", "4b"],
	"map04c": ["res://gravelight/maps/map04_fernflug/map04c.tscn", "4c"],
	"map04d": ["res://gravelight/maps/map04_fernflug/map04d.tscn", "4d"],
}


func _initialize() -> void:
	var maps: Array = MAPS.keys()
	var report_only: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			maps = Array(a.substr(7).split(",", false))
		elif a == "--report-only":
			report_only = true
	var bad: int = 0
	for m: String in maps:
		if not MAPS.has(m):
			print("MOUNT %s: unknown map" % m)
			continue
		var ps: PackedScene = load(str(MAPS[m][0])) as PackedScene
		if ps == null:
			print("MOUNT %s: the scene did not load" % m)
			bad += 1
			continue
		var map: Node = ps.instantiate()
		var rows: Array = Mount.survey(map, str(MAPS[m][1]))
		for r: Dictionary in rows:
			var p: Vector3 = r["pos"]
			print("MOUNT %-7s %-34s %-4s (%.2f, %.2f, %.2f) gap %s  %s  %s" % [m, str(r["name"]), str(r["kind"]), p.x, p.y, p.z,
				"-" if float(r["gap"]) == INF else "%.3f" % float(r["gap"]), str(r["verdict"]), str(r["why"])])
		var f: int = Mount.failures(rows).size()
		print("MOUNT_RESULT %s: %d items, %d off their surface" % [m, rows.size(), f])
		bad += f
		map.free()
	quit(0 if report_only else mini(bad, 100))
