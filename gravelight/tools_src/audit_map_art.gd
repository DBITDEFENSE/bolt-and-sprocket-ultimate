extends Node
## Runs MapArtAudit (T-180) on one map, headless: materials, invisible walls, ViewCells hiding art in front of you,
## bought doors that leave a collider in their opening.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/audit_map_art.tscn -- ##     [--map=map02 | --scene=res://path.tscn] [--doors-open] [--probe=x,y,z/x,y,z] [--ray=ax,ay,az,bx,by,bz/...]
## The rays run with the doors shut unless --doors-open; afterwards every door is opened and its opening checked.
## --probe lists the meshes round a point (and the material findings), --ray what one ray hits (collider and art).
## Prints one AUDIT line per finding and an AUDIT_SUMMARY line; exit code = the number of findings (capped at 100).

const MAPS: Dictionary = {
	"map00": "res://gravelight/maps/map00_crossroads/map00.tscn",
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}

var _map: Node3D


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_artaudit.json"
	ProfileSave.profile = ProfileSave.new_profile()
	var key: String = "map02"
	var path: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			key = a.substr(6)
		elif a.begins_with("--scene="):
			path = a.substr(8)
	if path == "":
		path = str(MAPS.get(key, MAPS["map02"]))
	_map = (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _run() -> void:
	for i: int in 30:
		await get_tree().physics_frame
	RoundManager.stop()
	GameState.god_mode = true
	var doors_open: bool = OS.get_cmdline_user_args().has("--doors-open")
	var audit: MapArtAudit = MapArtAudit.new(_map)
	audit.run(doors_open)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--probe="):
			for pt: String in a.substr(8).split("/"):
				var v: PackedStringArray = pt.split(",")
				print("PROBE == %s" % pt)
				audit.probe(Vector3(float(v[0]), float(v[1]), float(v[2])))
			audit.report()   # the material findings (no rays in probe mode)
			get_tree().quit(0)
			return
	for i: int in 3:
		await get_tree().physics_frame
	for a2: String in OS.get_cmdline_user_args():
		if a2.begins_with("--ray="):
			for rs: String in a2.substr(6).split("/"):
				var r: PackedStringArray = rs.split(",")
				print("RAY == %s" % rs)
				audit.probe_ray(Vector3(float(r[0]), float(r[1]), float(r[2])), Vector3(float(r[3]), float(r[4]), float(r[5])))
			get_tree().quit(0)
			return
	audit.run_rays()
	audit.open_doors()   # then every bought door must leave its opening clear
	for i: int in 3:
		await get_tree().physics_frame
	audit.door_check()
	audit.report()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(mini(audit.findings.size(), 100))
