extends Node
## Headless smoke for Update 02 section 7 (T-052), Map 0's living world: the Landscape builds (terrain layers,
## forests, sky, farmhouse), MapAmbience wires up (crows on the wires, frost on the windows, swinging lanterns paired
## with their lights, the chimney, the cook-off points, three searchlights), then every event fires once (bombers,
## fighters, a plane shot down and its crash, a barrage, flak, a flare, a gust, a cook-off, the dog, the midnight
## bell) and the rules hold: gunfire scatters the crows, a near shell swings the lamps, the dying hearth stops the
## chimney and thickens the frost, round 8 darkens the farmhouse, looking into the cockpit gets the pilot line, and
## the squad reacts (VO categories SKY_PLANE_DOWN, WRECK_PILOT, MIDNIGHT).
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_landscape.tscn

var map: Node3D
var amb: MapAmbience
var land: Landscape
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_landscape_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	GLVO.always_pass_chance = true
	map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("[landscape-smoke] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	await _wait(1.5)
	land = Landscape.find(get_tree())
	amb = map.get_node_or_null("MapAmbience") as MapAmbience
	_check(land != null and land.built, "Landscape built")
	_check(amb != null and amb.cfg.size() > 10, "MapAmbience loaded its config")
	if land == null or amb == null:
		_finish()
		return
	_check(land.get_node_or_null("Terrain") != null and land.get_node_or_null("RidgeBand1") != null, "terrain and ridge bands")
	_check(land.find_children("PineCards*", "MultiMeshInstance3D", false, false).size() > 0, "impostor forests")
	_check(land.sky_mat != null and land.farm_window != null and land.town_fires.size() > 0, "sky, farmhouse window, burning town")
	_check(amb.crows != null and amb.crows.perched_count() == int(amb.cfg["crows"]["count"]), "crows perched on the wires")
	_check(amb.frost != null and amb.frost.decals.size() >= 9, "frost panes on the walled windows (%d)" % (amb.frost.decals.size() if amb.frost else 0))
	var paired: int = 0
	for e: Array in amb.sway.lamps:
		if e[1] != null:
			paired += 1
	_check(amb.sway.lamps.size() >= 12 and paired >= 10, "swinging lanterns %d (%d with their light)" % [amb.sway.lamps.size(), paired])
	_check(amb.breath != null and amb.breath._puffs.size() >= 1, "breath fog attached to the survivors")
	_check(amb._chimney != null and amb._fire_light != null, "chimney smoke and hearth light found")
	_check(land.cookoff_points.size() > 0 and amb._beams.size() == 3, "cook-off points and searchlights")
	# gunfire scatters the crows
	GLBus.weapon_fired.emit(1, &"m1911", false, Vector3(5, 1.5, -10), Vector3.FORWARD)
	await _wait(0.5)
	_check(amb.crows.perched_count() == 0, "gunfire scattered the crows")
	# every event once (the bell fast)
	amb.cfg["bell"]["gap"] = 0.2
	amb.debug_set_round(6)
	for k: String in ["bombers", "fighters", "flare", "barrage", "tracers", "gust", "cookoff", "dog", "bell"]:
		amb.debug_trigger(k, 70.0)
	amb.debug_trigger("plane_down", 60.0)
	# a near shell swings the lamps
	amb.shell(80.0, 1.0)
	await _wait(3.6)
	var swung: bool = false
	for e2: Array in amb.sway.lamps:
		if (e2[0] as Node3D).rotation.length() > 0.002:
			swung = true
	_check(swung, "a near shell swung the lanterns")
	# the hearth dies (the Cousins' setup): smoke stops, frost thickens
	var frost0: float = amb.frost.level
	amb._fire_light.set("base_energy", 0.4)
	await _wait(2.0)
	_check(amb.fire_out and not amb._chimney.emitting, "the chimney stops when the fire dies")
	_check(amb.frost.level > frost0, "frost thickens once the fire is out")
	amb._fire_light.set("base_energy", amb._fire_base)
	# round 8: the farmhouse goes dark
	amb.debug_set_round(8)
	await _wait(2.5)
	_check(not land.farm_window.visible, "the farmhouse window went dark at round 8")
	# a look into the cockpit
	var p: Player = map.get("player") as Player
	if p != null:
		var seat: Vector3 = land.wreck_node.global_transform * Vector3(-0.45, 2.2, -5.6)
		p.global_position = Vector3(31.0, 0.0, 1.0)
		await _wait(0.2)
		p.camera.look_at(seat)
	await _wait(18.0)
	_check(amb.pilot_said, "the pilot's-seat line triggered")
	for k2: String in ["shell", "bombers", "fighters", "flare", "tracers", "gust", "cookoff", "dog", "bell", "plane_down", "crash", "farm_dark", "fire_out"]:
		_check(int(amb.counts.get(k2, 0)) > 0, "event %s happened (%d)" % [k2, int(amb.counts.get(k2, 0))])
	var said: Dictionary = {}
	for key: String in GLVO.fired.keys():
		for cat: String in ["SKY_PLANE_DOWN", "WRECK_PILOT", "MIDNIGHT"]:
			if key.ends_with(":" + cat):
				said[cat] = true
	for cat2: String in ["SKY_PLANE_DOWN", "WRECK_PILOT", "MIDNIGHT"]:
		_check(said.has(cat2), "the squad said a %s line" % cat2)
	_finish()


func _finish() -> void:
	print("[landscape-smoke] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " " + ", ".join(_fails)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_landscape_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)
