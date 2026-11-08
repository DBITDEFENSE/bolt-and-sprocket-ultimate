extends SceneTree
## The interactables' facing test (UPDATE 13 Part 3, DECISIONS T-218): for every interactable of each map (perk
## machines, wall buys, ammo boxes, the mystery crate's spots, the Crucible, the power switch, the bench, trap levers,
## doors, the bank counter, quest and egg objects) the front must face open walkable navmesh and the interaction area
## must be reachable from the navmesh. Headless, from the scene files alone (gravelight/tools_src/interactable_facing.gd).
##
##   godot --headless --audio-driver Dummy --path . --script res://tools/tests/test_interactable_facing.gd
##       [-- --maps=map04a,map04b,map04c,map04d] [--report-only] [--md=<file>] [--json=<file>] [--cams=<file>] [--quiet]
##
## Default maps: Fernflug's four acts. Exit code = the number of failing interactables (BACKWARDS, SIDEWAYS or
## UNREACHABLE; the Crucible is locked and only reported), 0 with --report-only. UNSURE is reported, never failed.
## --md writes the tables, --json the rows, --cams the approach cameras (2.75 m out on the open side, eye height,
## looking at the object; plus capture_cams.json-style sets, one per map).

const Facing: GDScript = preload("res://gravelight/tools_src/interactable_facing.gd")

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
	"test_range": "res://gravelight/maps/test_range/test_range.tscn",
}
const TITLES: Dictionary = {
	"map00": "Map 0 Crossroads Inn", "map01": "Map 1 Kaltenbrunn", "map02": "Map 2 Totenhafen",
	"map04a": "Fernflug Act I, Werk Thalbach (map04a)", "map04b": "Fernflug Act II, der Kranich (map04b)",
	"map04c": "Fernflug Act III, Groom Lake (map04c)", "map04d": "Fernflug Act IV, Mondlicht (map04d)", "test_range": "Test range",
}
const FERNFLUG: Array = ["map04a", "map04b", "map04c", "map04d"]
## Listed exceptions ("<map>/<node>": why): problems that are not the facing and need a layout change the facing
## pass may not make (docs/captures/fernflug/facing_after.md lists them for the owner). Reported, never failed.
const KNOWN: Dictionary = {}


func _initialize() -> void:
	var maps: Array = FERNFLUG.duplicate()
	var report_only: bool = false
	var md_path: String = ""
	var json_path: String = ""
	var cams_path: String = ""
	var quiet: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			maps = Array(a.substr(7).split(",", false))
		elif a == "--report-only":
			report_only = true
		elif a.begins_with("--md="):
			md_path = a.substr(5)
		elif a.begins_with("--json="):
			json_path = a.substr(7)
		elif a.begins_with("--cams="):
			cams_path = a.substr(7)
		elif a == "--quiet":
			quiet = true
		elif a.begins_with("--debug="):
			pass   # read by the checker itself (interactable_facing.gd debug_name())
	var md: String = ""
	var all_rows: Dictionary = {}
	var cams: Array = []
	var sets: Dictionary = {}
	var fails: int = 0
	for key: String in maps:
		if not MAPS.has(key):
			push_error("test_interactable_facing: unknown map %s (known: %s)" % [key, ", ".join(PackedStringArray(MAPS.keys()))])
			fails += 1
			continue
		var t0: int = Time.get_ticks_msec()
		var map: Node = (load(MAPS[key]) as PackedScene).instantiate()
		var rows: Array = Facing.survey(map, key)
		for r0: Dictionary in rows:
			var kk: String = "%s/%s" % [key, r0["name"]]
			if KNOWN.has(kk) and str(r0["verdict"]) != "OK":
				r0["note"] = "known: " + str(KNOWN[kk])
		map.free()
		all_rows[key] = rows
		var bad: Array = Facing.failures(rows)
		var c: Dictionary = Facing.counts(rows)
		print("== %s: %d interactables  OK %d  BACKWARDS %d  SIDEWAYS %d  UNSURE %d  UNREACHABLE %d  (%d ms)" % [key, rows.size(),
			c["OK"], c["BACKWARDS"], c["SIDEWAYS"], c["UNSURE"], c["UNREACHABLE"], Time.get_ticks_msec() - t0])
		for r: Dictionary in rows:
			var o: Dictionary = r["open"]
			var flag: String = "" if str(r["verdict"]) in ["OK", "LAYOUT"] else "  <-- " + str(r["verdict"])
			if (quiet and flag == "") or str(r["verdict"]) == "LAYOUT":
				continue
			var wl: Dictionary = r.get("walls", {})
			var ws: String = ""
			for t: float in [0.0, 180.0, 90.0, -90.0]:
				ws += "#" if bool(wl.get(t, false)) else "."
			print("   %-28s %-22s pos (%7.2f %6.2f %7.2f) yaw %6.1f  open F %.2f B %.2f +90 %.2f -90 %.2f  walls %s  reach %s  -> %s%s" % [str(r["name"]).left(28),
				str(r["script"]).left(22), (r["pos"] as Vector3).x, (r["pos"] as Vector3).y, (r["pos"] as Vector3).z, float(r["yaw"]),
				float(o[0.0]), float(o[180.0]), float(o[90.0]), float(o[-90.0]), ws, "yes" if r["reachable"] else "NO",
				"%.0f" % float(r["suggested_yaw"]) if float(r["turn"]) != 0.0 else "keep", flag])
		if not report_only:
			fails += bad.size()
		md += Facing.markdown_table(str(TITLES.get(key, key)), rows)
		var set_cams: Array = []
		for r2: Dictionary in rows:
			var cam: Dictionary = r2["cam"]
			cams.append({"act": key, "scene": MAPS[key], "name": r2["name"], "verdict": r2["verdict"],
				"cam_pos": _v(cam["cam_pos"]), "look_at": _v(cam["look_at"]), "on_navmesh": cam["on_nav"]})
			set_cams.append({"name": str(r2["name"]).to_snake_case(), "pos": _v(cam["feet"]), "yaw": cam["yaw"], "pitch": cam["pitch"],
				"note": "facing check: %s (%s)" % [r2["name"], r2["script"]]})
		sets["facing_" + key] = {"map": MAPS[key], "bots": 0, "settle_s": 4.0, "cams": set_cams}
	if md_path != "":
		_write(md_path, md)
	if json_path != "":
		var jrows: Dictionary = {}
		for k: String in all_rows:
			var arr: Array = []
			for r3: Dictionary in all_rows[k]:
				arr.append({"name": r3["name"], "path": r3["path"], "script": r3["script"], "kind": r3["kind"], "pos": _v(r3["pos"]),
					"yaw": r3["yaw"], "verdict": r3["verdict"], "suggested_yaw": r3["suggested_yaw"], "reachable": r3["reachable"],
					"open": {"front": r3["open"][0.0], "back": r3["open"][180.0], "plus90": r3["open"][90.0], "minus90": r3["open"][-90.0]},
					"wall_back": r3.get("wall_back_now", null), "clips": r3.get("clips_now", null), "note": r3.get("note", ""),
					"back_gap": null if float(r3.get("back_gap_now", INF)) == INF else snappedf(float(r3["back_gap_now"]), 0.01)})
			jrows[k] = arr
		_write(json_path, JSON.stringify(jrows, "  "))
	if cams_path != "":
		_write(cams_path, JSON.stringify({"_doc": "Approach cameras for every interactable (tools/tests/test_interactable_facing.gd --cams): cam_pos is the eye (1.65 m over the navmesh, 2.75 m out on the open side when it fits), look_at the object's centre ~1.1 m up. capture_sets are the same cameras in data/gravelight/capture_cams.json's set format (pos = feet, yaw 0 = -Z, positive turns toward -X, pitch): paste a set into that file to shoot it with tools_src/capture.gd --set=<name>.",
			"cams": cams, "capture_sets": sets}, "  "))
	print("RESULT test_interactable_facing %s (%d failing%s)" % ["PASS" if fails == 0 else "FAIL", fails, ", report only" if report_only else ""])
	quit(0 if report_only else mini(fails, 125))


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


static func _write(path: String, text: String) -> void:
	var abs_path: String = path if path.is_absolute_path() and not path.begins_with("res://") else ProjectSettings.globalize_path("res://" + path.trim_prefix("res://"))
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		push_error("test_interactable_facing: cannot write %s" % abs_path)
		return
	f.store_string(text)
	f.close()
	print("wrote ", path)
