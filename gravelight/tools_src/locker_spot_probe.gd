extends SceneTree
## T-263: the arms locker's spot check, headless, from the scene files (gravelight/tools_src/locker_spot.gd).
##
##   godot --headless --audio-driver Dummy --path . --script res://gravelight/tools_src/locker_spot_probe.gd
##       [-- --maps=map00,map01] [--scan=x0,z0,x1,z1,y] [--top=25] [--all]
##
## Without --scan: checks every map's weapon_locker.json row (exit code = rows with problems). With --scan (one map):
## lists the wall spots of that floor rectangle, the ones without problems first (--all: the others too, with why).

const Spot: GDScript = preload("res://gravelight/tools_src/locker_spot.gd")
const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}


static func rows() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gravelight/weapon_locker.json"))
	return (d as Dictionary).get("lockers", {}) if d is Dictionary else {}


## The map's index with the data-built things a scene file does not hold (the bank counter).
static func index_for(map: Node, key: String) -> Dictionary:
	var geo: Dictionary = Spot.index(map)
	var bank: Dictionary = Spot.Facing.bank_row(key)
	if (bank.get("at", []) as Array).size() == 3:
		var a: Array = bank["at"]
		Spot.add_other(geo, "BankCounter", "machine", Vector3(float(a[0]), float(a[1]), float(a[2])))
	return geo


func _initialize() -> void:
	var maps: Array = MAPS.keys()
	var scan: PackedStringArray = []
	var top: int = 25
	var all: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			maps = Array(a.substr(7).split(",", false))
		elif a.begins_with("--scan="):
			scan = a.substr(7).split(",", false)
		elif a.begins_with("--top="):
			top = int(a.substr(6))
		elif a == "--all":
			all = true
	var fails: int = 0
	var all_rows: Dictionary = rows()
	for key: String in maps:
		if not MAPS.has(key):
			push_error("locker_spot_probe: unknown map %s" % key)
			fails += 1
			continue
		var map: Node = (load(MAPS[key]) as PackedScene).instantiate()
		var geo: Dictionary = index_for(map, key)
		if scan.size() == 5:
			var found: Array = Spot.scan(geo, float(scan[0]), float(scan[1]), float(scan[2]), float(scan[3]), float(scan[4]))
			var shown: int = 0
			for r: Dictionary in found:
				if (r["problems"] as PackedStringArray).is_empty() or all:
					print("[locker-spot] %s %s" % [key, Spot.line(r)])
					shown += 1
					if shown >= top:
						break
			print("[locker-spot] %s: %d wall spots, %d shown" % [key, found.size(), shown])
		elif all_rows.has(key):
			var row: Dictionary = all_rows[key]
			var at: Array = row.get("at", [0, 0, 0])
			var r2: Dictionary = Spot.check(geo, Vector3(float(at[0]), float(at[1]), float(at[2])), float(row.get("yaw", 0.0)))
			print("[locker-spot] %s %s" % [key, Spot.line(r2)])
			if not (r2["problems"] as PackedStringArray).is_empty():
				fails += 1
		else:
			print("[locker-spot] %s: no row" % key)
		map.free()
	print("[locker-spot] RESULT: %s" % ("PASS" if fails == 0 else "FAIL (%d)" % fails))
	quit(fails)
