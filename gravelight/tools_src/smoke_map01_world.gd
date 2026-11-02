extends Node
## Headless smoke for UPDATE 10 section 5 (T-161), Kaltenbrunn's living world: KaltenLandscape builds (terrain, the
## two ridge bands, the forest, the rail line, the cable car, the siren), MapAmbience loads map01_ambience.json and
## wires up, then the timed beats are forced the way the rounds would: round 7 the dogfight (circling pair, MG bursts,
## smoke), round 10 the siren, round 20 the harder snow; a plane shot down onto the ridge, an avalanche with its plume,
## the swinging gondola; and the underground reacts to the surface: a shell lands, dust falls and the lift chains
## clank, the lift moving clanks them too, a drip falls in the gallery, the salt materials carry the glint pass.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map01_world.tscn

var map: Node3D
var amb: MapAmbience
var land: KaltenLandscape
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_map01world_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.god_mode = true
	GLVO.always_pass_chance = true
	map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
	map.set("auto_rounds", false)
	get_tree().root.add_child.call_deferred(map)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("[map01-world] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	await _wait(2.0)
	land = Landscape.find(get_tree()) as KaltenLandscape
	amb = map.get_node_or_null("MapAmbience") as MapAmbience
	_check(land != null and land.built, "KaltenLandscape built")
	_check(amb != null and amb.cfg.size() > 10, "MapAmbience loaded map01_ambience.json")
	if land == null or amb == null:
		_finish()
		return
	_check(MapAmbience.validate(amb.cfg).is_empty(), "the config validates")
	_check(land.get_node_or_null("Terrain") != null and land.get_node_or_null("RidgeBand1") != null, "terrain and ridge bands")
	_check(land.find_children("PineCards*", "MultiMeshInstance3D", false, false).size() > 0, "impostor forest (%d cards, %d mesh trees)" % [int(land.tree_counts.get("cards", 0)), int(land.tree_counts.get("mesh", 0))])
	_check(land.get_node_or_null("Static/../CableCar") != null and land.cable_pivot != null, "the cable car hangs over the valley")
	_check(land.siren_node != null and land.siren_lamp != null, "the siren is on the headframe")
	_check(amb._beams.size() == 2 and amb.crows == null and amb.frost == null, "searchlights on, Map 0's inn pieces off")
	_check(amb._k_dust.size() == 4 and amb._k_chains.size() == 3, "dust emitters and lift chains built")
	_check(int(amb.counts.get("glint_materials", 0)) > 0, "the salt materials carry the glint pass (%d)" % int(amb.counts.get("glint_materials", 0)))
	# Map 0's config still validates with the same rules
	_check(MapAmbience.validate(GLData.load_json("res://data/gravelight/map00_ambience.json")).is_empty(), "Map 0's config still validates")
	# --- the timed beats, as the rounds would fire them (delays cut short)
	(amb.cfg["dogfight"] as Dictionary)["delay"] = 0.2
	(amb.cfg["siren"] as Dictionary)["delay"] = 0.2
	(amb.cfg["snow_harder"] as Dictionary)["ramp_seconds"] = 2.0
	GLBus.round_started.emit(7, false)
	await _wait(0.8)
	_check(int(amb.counts.get("dogfight", 0)) == 1 and amb._k_dog != null, "round 7: the dogfight started")
	await _wait(5.0)
	_check(amb._k_dog_planes.size() == 2 and amb._k_dog_planes[0].get_node_or_null("LeadSmoke") != null, "two fighters, the lead trailing smoke")
	_check(int(amb.counts.get("dogfight_burst", 0)) > 0 and amb._k_dog_tracers.size() >= 0, "MG bursts (%d)" % int(amb.counts.get("dogfight_burst", 0)))
	GLBus.round_started.emit(10, false)
	await _wait(1.0)
	_check(int(amb.counts.get("siren", 0)) == 1 and land.siren_lamp.visible, "round 10: the siren wails and its lamp pulses")
	var snow0: Node = map.find_child("SnowHarder", true, false)
	GLBus.round_started.emit(20, false)
	await _wait(4.0)
	_check(snow0 == null and map.find_child("SnowHarder", true, false) != null and amb.blizzard_level() > 0.9, "round 20: the snow thickens (level %.2f)" % amb.blizzard_level())
	# --- the sky and the ridge
	amb.debug_trigger("avalanche", 10.0)
	await _wait(1.0)
	_check(int(amb.counts.get("avalanche", 0)) == 1 and amb._k_plumes.size() > 0, "avalanche: plume sliding down the ridge")
	amb.debug_trigger("plane_down_ridge", 40.0)
	await _wait(20.0)
	var glow: Node3D = amb.get_node_or_null("CrashGlow") as Node3D
	_check(int(amb.counts.get("plane_down", 0)) > 0 and int(amb.counts.get("crash", 0)) > 0, "a plane went down (%d crash)" % int(amb.counts.get("crash", 0)))
	_check(glow != null and glow.global_position.y > 30.0, "...onto the ridge, with a glow after (y %.0f)" % (glow.global_position.y if glow else -1.0))
	# --- the gondola swings
	amb._k_cable_va = 0.25
	await _wait(5.0)
	_check(int(amb.counts.get("cable_creak", 0)) > 0 or absf(amb._k_cable_a) > 0.003, "the gondola swings (angle %.3f, %d creaks)" % [amb._k_cable_a, int(amb.counts.get("cable_creak", 0))])
	# --- the surface is shelled: dust and chains underground
	var dust0: int = int(amb.counts.get("dust_fall", 0))
	var chain0: int = int(amb.counts.get("chains", 0))
	amb.shell(250.0, 1.0)
	await _wait(3.6)
	_check(int(amb.counts.get("dust_fall", 0)) > dust0, "a shell landed: dust fell from the ceilings")
	_check(int(amb.counts.get("chains", 0)) > chain0, "...and the lift chains clanked")
	# the lift moving clanks the chains too
	await _wait(1.0)
	var chain1: int = int(amb.counts.get("chains", 0))
	if amb._k_lift != null:
		amb._k_lift_y = float(amb._k_lift.call("cage_y")) + 1.0
	await _wait(0.4)
	_check(amb._k_lift != null and int(amb.counts.get("chains", 0)) > chain1, "the lift moved: the chains clanked")
	# --- a drip in the chapel
	var p: Player = map.get("player") as Player
	if p != null:
		p.global_position = Vector3(10.0, -11.9, 66.0)
	await _wait(0.5)
	for i: int in 30:
		if not amb._k_drops.is_empty():
			break
		amb._ev_drip(true)
		await get_tree().physics_frame
	_check(not amb._k_drops.is_empty(), "a drop is falling in the chapel")
	await _wait(2.5)
	_check(int(amb.counts.get("drip", 0)) > 0, "...and it landed (%d)" % int(amb.counts.get("drip", 0)))
	_finish()


func _finish() -> void:
	print("[map01-world] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " " + ", ".join(_fails)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_map01world_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)
