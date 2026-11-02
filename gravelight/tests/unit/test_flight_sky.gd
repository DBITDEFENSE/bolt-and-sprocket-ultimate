extends GutTest
## Act II's outside and shell (UPDATE 09 section 5.3, DECISIONS T-147): FlightSky's flight clock (the leg per act
## round, the coast sweeping past, the fighter passes, the London window's beats by the window's own clock, the swing),
## the sky data's sanity against the act block, the KranichShell's rooms (GLBs, paperwork, the slots mapped) and that
## both nodes are in the generated scene; the ambience file names zones and keys that exist.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"

var cfg: Dictionary
var sky: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map04b.json")
	sky = (cfg.get("flight", {}) as Dictionary).get("sky", {})


func test_leg_follows_the_act_round() -> void:
	var legs: Array = sky["legs"]
	assert_eq(FlightSky.leg_index_for(legs, 0), 0, "before round 1 the first leg")
	assert_eq(FlightSky.leg_index_for(legs, 1), 0)
	assert_eq(str((legs[FlightSky.leg_index_for(legs, 3)] as Dictionary)["lights"]), "london", "act round 3 is London")
	assert_eq(FlightSky.leg_index_for(legs, 99), legs.size() - 1, "past the last leg the last leg holds")


func test_sky_legs_match_the_act() -> void:
	var legs: Array = sky["legs"]
	var events: Dictionary = cfg["act"]["events"]
	var rounds: Array = []
	for l: Dictionary in legs:
		assert_true(["sea", "land", "coast_in", "coast_out"].has(str(l["below"])), "leg %s: a known kind" % str(l))
		rounds.append(int(l["act_round"]))
	for i: int in range(1, rounds.size()):
		assert_gt(int(rounds[i]), int(rounds[i - 1]), "legs in act-round order")
	assert_eq(int(rounds[0]), 1, "the first leg starts on act round 1")
	assert_eq(int(rounds[rounds.size() - 1]), int(cfg["act"]["length_rounds"]), "a leg for the act's last round")
	var london: Dictionary = legs[FlightSky.leg_index_for(legs, int(events["london_window_round"]))]
	assert_eq(str(london.get("lights", "")), "london", "the London leg is the window's round")
	var run: Dictionary = legs[FlightSky.leg_index_for(legs, int(events["bomb_run_round"]))]
	assert_eq(str(run["below"]), "coast_in", "the bomb run comes in over a coast")
	assert_eq(int(sky["fighters"]["passes_per_round"]), 3, "three fighter passes a round")
	assert_eq((sky["cloud_layers"] as Array).size(), 3, "three cloud sheets")


func test_coast_sweeps_under_the_wing() -> void:
	var leg_in: Dictionary = {"below": "coast_in", "coast_s": 100.0, "coast_span": 900.0}
	var s0: Dictionary = FlightSky.ground_state(leg_in, 0.0)
	assert_false(FlightSky.is_land(s0, FlightSky.WING_Z), "coming in: the sea under the wing at first")
	assert_true(FlightSky.is_land(s0, FlightSky.WING_Z + 1000.0), "and the land ahead")
	assert_true(FlightSky.is_land(FlightSky.ground_state(leg_in, 100.0), FlightSky.WING_Z), "the land under the wing at the end")
	var leg_out: Dictionary = {"below": "coast_out", "coast_s": 100.0, "coast_span": 900.0}
	assert_true(FlightSky.is_land(FlightSky.ground_state(leg_out, 0.0), FlightSky.WING_Z), "going out: land first")
	assert_false(FlightSky.is_land(FlightSky.ground_state(leg_out, 100.0), FlightSky.WING_Z), "the sea at the end")
	assert_false(FlightSky.is_land(FlightSky.ground_state({"below": "sea"}, 50.0), FlightSky.WING_Z), "the sea is sea")
	assert_true(FlightSky.is_land(FlightSky.ground_state({"below": "land"}, 50.0), FlightSky.WING_Z), "the land is land")
	var mid: float = float(FlightSky.ground_state(leg_in, 50.0)["coast_z"])
	assert_almost_eq(mid, FlightSky.WING_Z, 0.01, "half way through the leg the coast is under the wing")


func test_fighter_passes_are_three_deterministic_in_the_window() -> void:
	var a: Array[float] = FlightSky.pass_times(17, 3, 20.0, 150.0)
	var b: Array[float] = FlightSky.pass_times(17, 3, 20.0, 150.0)
	assert_eq(a.size(), 3)
	assert_eq(a, b, "every peer sees the same passes in a round")
	for i: int in a.size():
		assert_true(a[i] >= 20.0 and a[i] <= 170.0, "inside the window: %.1f" % a[i])
		if i > 0:
			assert_gt(a[i], a[i - 1], "in order")
	assert_ne(FlightSky.pass_times(18, 3, 20.0, 150.0), a, "another round, other moments")
	assert_eq(FlightSky.pass_times(1, 0, 20.0, 150.0).size(), 0)


func test_london_beats_by_the_windows_clock() -> void:
	var lc: Dictionary = sky["london"]
	assert_false(bool(FlightSky.london_phase(6.0, lc)["beams"]), "the battery beat: no searchlights yet")
	assert_true(bool(FlightSky.london_phase(18.0, lc)["beams"]), "London: the searchlights")
	assert_true(bool(FlightSky.london_phase(24.0, lc)["flak"]), "the air-bursts: flak")
	assert_false(bool(FlightSky.london_phase(30.5, lc)["flak"]), "the silence (30 s): no flak")
	assert_lt(float(lc["flak_to_s"]), 30.0, "the flak stops before london_window.gd's 4 s of silence at 30 s")


func test_swing_settles_on_its_target() -> void:
	var st: Vector2 = Vector2.ZERO
	for i: int in 600:
		st = FlightSky.swing_step(st.x, st.y, 0.15, 4.0, 1.2, 1.0 / 60.0)
	assert_almost_eq(st.x, 0.15, 0.01, "a damped pendulum comes to rest at the bank's angle")


func test_shell_rooms_have_their_glbs_and_paperwork() -> void:
	var rooms: Array = _rooms()
	assert_eq(rooms.size(), 7, "seven rooms")
	for r: Array in rooms:
		var folder: String = str(r[0])
		assert_true(ResourceLoader.exists(WorldArt.glb_path(folder)), "%s has its GLB" % folder)
		for f: String in ["LICENSE.txt", "SOURCE.txt"]:
			assert_true(FileAccess.file_exists("res://assets/ours/world/%s/%s" % [folder, f]), "%s has %s" % [folder, f])


func test_shell_builds_and_maps_its_slots() -> void:
	KranichShell.reset()
	var shell: KranichShell = KranichShell.new()
	shell.build_on_ready = false
	shell.rooms = [["kranich_bay", "A_BOMBENSCHACHT", 0.75, 1.5, 95.0]]
	add_child_autofree(shell)
	shell.build()
	assert_eq(shell.get_child_count(), 1, "the bay's GLB is instanced")
	var mapped: int = 0
	var glass_shadow_off: bool = true
	for mi: MeshInstance3D in WorldArt.meshes(shell):
		assert_eq(StringName(str(mi.get_meta("zone", ""))), &"A_BOMBENSCHACHT", "%s carries its zone" % mi.name)
		assert_eq(mi.visibility_range_end, 95.0, "a visibility range")
		for s: int in mi.mesh.get_surface_count():
			if mi.get_surface_override_material(s) != null:
				mapped += 1
		if mi.name.contains("Glass") and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			glass_shadow_off = false
	assert_gt(mapped, 2, "the kskin / kframe / kgrate slots are mapped")
	assert_true(glass_shadow_off, "perspex never casts")


func test_scene_has_the_sky_and_the_shell() -> void:
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	var names: Dictionary = {}
	for i: int in st.get_node_count():
		names[String(st.get_node_name(i))] = true
	assert_true(names.has("FlightSky"), "the FlightSky node")
	assert_true(names.has("Shell"), "the KranichShell node")
	assert_true(names.has("LondonPlate") and names.has("WingDiorama"), "the window's plate and the crash's diorama stay")


func test_sky_node_builds_its_layers_and_runs_its_set_pieces() -> void:
	var fs: FlightSky = FlightSky.new()
	add_child_autofree(fs)
	assert_eq(_count_prefix(fs, "CloudSheet"), 3, "three cloud sheets")
	assert_not_null(fs.find_child("GroundBelow", false, false), "the ground below")
	fs.spawn_pass(false)
	assert_eq(fs.passes_done, 1, "a fighter pass")
	fs.burst(Vector3(0, -20, -60))
	fs._go_desert()
	assert_true(fs.desert, "the crash switches to the salt flat")


func test_ambience_file_names_zones_and_keys_that_exist() -> void:
	var amb: Dictionary = GLData.load_json("res://data/gravelight/ambience/map04b.json")
	var sounds: Dictionary = GLData.load_json("res://data/gravelight/audio.json").get("sounds", {})
	var zones: Dictionary = amb.get("zones", {})
	assert_eq(zones.size(), (cfg["zones"] as Dictionary).size(), "every zone has its ambience")
	for z: String in zones.keys():
		assert_true((cfg["zones"] as Dictionary).has(z), "%s is an Act II zone" % z)
		var e: Dictionary = zones[z]
		assert_true(sounds.has(str(e["bed"])), "%s bed %s exists" % [z, e["bed"]])
		for o: Dictionary in e.get("oneshots", []):
			assert_true(sounds.has(str(o["key"])), "%s one-shot %s exists" % [z, o["key"]])
			assert_eq((o["every_s"] as Array).size(), 2)
	assert_true(sounds.has(str(GLData.load_json("res://data/gravelight/audio.json")["music"]["ambient"].get("map04b_kranich", ""))), "the act's base bed")
	# T-145's ZoneAmbience picks the file up for the act and accepts it
	var path: String = ZoneAmbience.config_path(&"map04b_kranich")
	assert_eq(path, "res://data/gravelight/ambience/map04b.json", "MapRoot will attach it to der Kranich")
	assert_eq(ZoneAmbience.validate(ZoneAmbience.load_config(path)).size(), 0, "the schema holds")
	for z2: String in zones.keys():
		assert_true(ZoneAmbience.resolvable(str((zones[z2] as Dictionary)["bed"])), "%s bed resolves" % z2)


func _rooms() -> Array:
	var gen: GDScript = load("res://gravelight/tools_src/gen_map04b.gd") as GDScript
	return gen.get_script_constant_map().get("SHELL_ROOMS", [])


func _count_prefix(n: Node, prefix: String) -> int:
	var k: int = 0
	for c: Node in n.get_children():
		if c.name.begins_with(prefix):
			k += 1
	return k
