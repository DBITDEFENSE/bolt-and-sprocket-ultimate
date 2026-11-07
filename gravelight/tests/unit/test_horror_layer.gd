extends GutTest
## UPDATE 11 (T-192): the horror pass's presentation layer (HorrorLayer) and its data on every map: the chant bed
## rising with the round inside the AUDIO_MIX rule, the frost on the screen edges only in the cold, breathing when
## hurt, the whisperers (Soviet risen on their feet only), the Gore setting on the blood decals, the sounds in the
## bank on the existing buses, the Operator's jingles untouched, the Map 0 column and the menu lane.

const MAPS: PackedStringArray = ["map00", "map01", "map02", "map04a", "map04b", "map04c", "map04d"]


func _amb(m: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s_ambience.json" % m)


func test_every_map_has_a_horror_block() -> void:
	for m: String in MAPS:
		var h: Dictionary = _amb(m).get("horror", {})
		assert_false(h.is_empty(), m + " has its horror block")
		assert_true(h.has("chant"), m + ": the chant bed")
		assert_true(h.has("grade"), m + ": the darker night")
		assert_true(h.has("decals"), m + ": blood and mud")
	assert_false(_amb("map04d")["horror"].has("bells"), "no bells in a vacuum")
	assert_false(_amb("map04d")["horror"].has("flies"), "no flies on the Moon")
	assert_true(_amb("map04c")["horror"].has("flies"), "flies in the desert heat")
	assert_false(_amb("map04c")["horror"].has("frost_edges"), "no frost in the desert")
	assert_true(_amb("map00")["horror"].has("whispers") and _amb("map01")["horror"].has("whispers"), "whispers where the Returned walk")
	for m2: String in ["map00", "map01", "map02"]:
		assert_true(_amb(m2).has("breath"), m2 + ": breath fog in the cold")


func test_the_bed_rises_with_the_round_and_keeps_the_mix_rule() -> void:
	var ch: Dictionary = _amb("map00")["horror"]["chant"]
	var a: float = HorrorLayer.bed_db(1, ch)
	var b: float = HorrorLayer.bed_db(12, ch)
	var c: float = HorrorLayer.bed_db(40, ch)
	assert_lt(a, b, "louder as the night goes on")
	assert_lt(b, c)
	assert_almost_eq(c, float(ch["db"][1]), 0.001, "capped at full_round")
	# AUDIO_MIX.md: the bed file measures -20 LUFS; at its loudest it must sit at least 8 dB under a footstep (-33)
	# with the map bed (-42) under it: -20 + db[1] <= -49 keeps the pair at -41.2
	for m: String in MAPS:
		assert_lte(-20.0 + float(_amb(m)["horror"]["chant"]["db"][1]), -49.0, m + ": the chant at its loudest stays a bed")
	assert_eq(HorrorLayer.bed_db(1, {"from_round": 3}), -80.0, "silent before from_round")


func test_fragments_come_more_often_later() -> void:
	var ch: Dictionary = _amb("map01")["horror"]["chant"]
	var early: Vector2 = HorrorLayer.interval_at(1, ch["frag"], ch)
	var late: Vector2 = HorrorLayer.interval_at(30, ch["frag"], ch)
	assert_lt(late.y, early.x, "late in the night the fragments crowd in")


func test_frost_only_in_the_cold() -> void:
	var fe: Dictionary = _amb("map00")["horror"]["frost_edges"]
	assert_eq(HorrorLayer.frost_strength(5, fe, true), 0.0, "none by the hearth")
	assert_gt(HorrorLayer.frost_strength(5, fe, false), 0.0)
	assert_gt(HorrorLayer.frost_strength(20, fe, false), HorrorLayer.frost_strength(1, fe, false), "the cold deepens")
	assert_true(float(_amb("map01")["horror"]["frost_edges"]["cold_min_y"]) > -12.0, "Kaltenbrunn's depths are not the cold")


func test_breathing_when_hurt() -> void:
	var bh: Dictionary = _amb("map00")["horror"]["breath"]
	assert_eq(HorrorLayer.breath_period(1.0, bh), INF, "not when well")
	assert_eq(HorrorLayer.breath_period(0.6, bh), INF)
	assert_lt(HorrorLayer.breath_period(0.1, bh), HorrorLayer.breath_period(0.45, bh), "faster the lower")


func test_gore_setting_on_the_blood() -> void:
	assert_eq(HorrorLayer.blood_kind("full"), "blood")
	assert_eq(HorrorLayer.blood_kind("low"), "stain")
	assert_eq(HorrorLayer.blood_kind("off"), "", "no blood with Gore off")
	assert_not_null(HorrorLayer.blood_texture())
	assert_not_null(HorrorLayer.mud_texture())


func test_only_the_returned_whisper() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var sp: ZombieSpawn = ZombieSpawn.new()
	host.add_child(sp)
	var z: Zombie = Zombie.new()
	host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 150, "variant": "soviet"}, sp, null)
	z.state = Zombie.State.CHASE
	assert_true(HorrorLayer.whisperer(z), "a Returned on its feet")
	z.lie_dormant()
	assert_false(HorrorLayer.whisperer(z), "not a body still lying")
	var g: Zombie = Zombie.new()
	host.add_child(g)
	g.activate({"enemy_id": "ganger", "tier": "walk", "health": 150, "variant": "soldier"}, sp, null)
	assert_false(HorrorLayer.whisperer(g), "a German Ganger says nothing in Russian")


func test_the_sounds_are_banked_on_the_existing_buses() -> void:
	var s: Dictionary = GLData.load_json("res://data/gravelight/audio.json")["sounds"]
	var want: Dictionary = {"horror_chant_bed": "Ambience", "horror_chant_frag": "Ambience", "horror_bell_far": "SFX",
		"horror_whisper": "SFX", "player_breath_hurt": "SFX", "horror_flies_loop": "SFX"}
	for k: String in want.keys():
		assert_true(s.has(k), k + " is in the bank")
		assert_eq(str((s[k] as Dictionary).get("bus", "")), want[k], k + " bus")
		for f: Variant in (s[k] as Dictionary)["files"]:
			assert_true(ResourceLoader.exists(str(f)), str(f))
		assert_false(str((s[k] as Dictionary).get("bus", "")) == "Jingles", "the Operator's jingles stay bright")
	assert_true(bool(s["horror_chant_bed"].get("loop", false)))
	var rules: Dictionary = GLData.load_json("res://data/gravelight/vo/rules.json")
	assert_true((rules["player_speakers"] as Array).has("RTN"), "the Returned speak positionally, never as a story line")


func test_the_map00_column_and_the_menu_lane() -> void:
	var rc: Dictionary = _amb("map00").get("risen_column", {})
	assert_false(rc.is_empty(), "Map 0's background war has its column")
	assert_lte(int(rc.get("count_web", 99)), int(rc.get("count", 0)))
	assert_eq(MenuScene.risen_count(false), MenuScene.RISEN_COUNT)
	assert_lt(MenuScene.risen_count(true), MenuScene.RISEN_COUNT, "fewer in the browser")


func test_grade_darkens_through_the_brightness_base() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	add_child_autofree(we)
	var b0: float = we.environment.adjustment_brightness
	HorrorLayer.apply_grade(get_tree(), {"brightness_mult": 0.9, "contrast_add": 0.05})
	assert_true(we.environment.adjustment_enabled)
	assert_almost_eq(float(we.environment.get_meta("gl_base_brightness")), b0 * 0.9, 0.001, "the slider's base, darkened")
	var c1: float = we.environment.adjustment_contrast
	HorrorLayer.apply_grade(get_tree(), {"brightness_mult": 0.9, "contrast_add": 0.05})
	assert_almost_eq(we.environment.adjustment_contrast, c1, 0.0001, "applied once")
