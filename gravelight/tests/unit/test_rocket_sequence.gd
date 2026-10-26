extends GutTest
## The rocket (UPDATE 07, docs/MAP4_FERNFLUG.md §5.9; gravelight/world/map04/silo_console.gd, story_radio.gd,
## cage_item.gd): the console's stages from the flags, the burn numbers seeded per match, Dee's cage rule, and
## the gantry lift's data (trigger and requirement on rocket_ready, the MONDLICHT cutscene).


func after_each() -> void:
	for f: StringName in [&"ignition_key", &"rocket_key_turned", &"burn_known", &"rocket_ready", &"cage_casing", &"cage_bomber_coil", &"cage_honey", &"dee_cage_done"]:
		GameState.flags.erase(f)


func test_console_stages_from_the_flags() -> void:
	assert_eq(SiloConsole.stage_of({}), "locked", "no key: the test pilot has it")
	assert_eq(SiloConsole.stage_of({&"ignition_key": true}), "key", "the key turns")
	assert_eq(SiloConsole.stage_of({&"ignition_key": true, &"rocket_key_turned": true}), "burn", "then the burn")
	assert_eq(SiloConsole.stage_of({&"ignition_key": true, &"rocket_key_turned": true, &"rocket_ready": true}), "ready")
	assert_eq(SiloConsole.stage_of({&"rocket_ready": true}), "ready", "the fallback sets it straight to ready")


func test_console_prompts_and_gates() -> void:
	var c: SiloConsole = SiloConsole.new()
	add_child_autofree(c)
	var p: Player = Player.new()
	p.player_id = 1
	add_child_autofree(p)
	p.set_physics_process(false)
	assert_true(c.get_prompt(p).contains("missing"), "locked: " + c.get_prompt(p))
	assert_false(c.can_interact(p))
	GameState.set_flag(&"ignition_key")
	assert_true(c.get_prompt(p).contains("turn the ignition key"))
	assert_true(c.can_interact(p))
	assert_almost_eq(c.hold_time(p), 2.0, 0.001, "the key is a 2 s hold")
	GameState.set_flag(&"rocket_key_turned")
	assert_true(c.get_prompt(p).contains("not known"), "the burn waits for Fasbender: " + c.get_prompt(p))
	assert_false(c.can_interact(p))
	GameState.set_flag(&"burn_known")
	GameState.flags[&"burn"] = [12, 34, 56]
	assert_true(c.get_prompt(p).contains("12 · 34 · 56"), "the numbers on the prompt: " + c.get_prompt(p))
	assert_true(c.can_interact(p))
	assert_almost_eq(c.hold_time(p), 4.0, 0.001, "the burn is a 4 s hold")
	GameState.set_flag(&"rocket_ready")
	assert_eq(c.get_prompt(p), "", "ready: nothing left to do")


func test_burn_numbers_are_seeded_two_digit_and_distinct() -> void:
	var a: Array[int] = StoryRadio.burn_numbers(42)
	var b: Array[int] = StoryRadio.burn_numbers(42)
	var c: Array[int] = StoryRadio.burn_numbers(43)
	assert_eq(a, b, "the same seed, the same numbers")
	assert_ne(a, c, "another seed, other numbers")
	assert_eq(a.size(), 3)
	for n: int in a:
		assert_true(n >= 10 and n <= 99, "two digits (%d)" % n)
	assert_true(a[0] != a[1] and a[1] != a[2] and a[0] != a[2], "never two alike")


func test_dees_cage_rule() -> void:
	assert_false(CageItem.all_done({}))
	assert_false(CageItem.all_done({&"cage_casing": true, &"cage_honey": true}), "two of three")
	assert_true(CageItem.all_done({&"cage_casing": true, &"cage_bomber_coil": true, &"cage_honey": true}))
	assert_eq(CageItem.ITEMS.size(), 3)


func test_gantry_lift_data() -> void:
	var e: Dictionary = Campaign.exfil_cfg(&"map04c_groomlake")
	assert_eq(Campaign.validate_exfil(e), PackedStringArray())
	assert_eq(str(e["trigger_flag"]), "rocket_ready", "the burn lights the lift")
	assert_eq(str(e["requires_flag"]), "rocket_ready", "and nobody rides it without the burn")
	assert_eq(str(e["zone"]), "G_SILO")
	assert_eq(int(e["act_round"]), 9, "the round clock's version: the act's last round")
	assert_almost_eq(float(e["hold_seconds"]), 3.0, 0.001)
	var cs: Dictionary = (Campaign.cfg()["cutscenes"] as Dictionary).get("exfil_m4c_m4d", {})
	assert_eq(str(cs.get("title", "")), "MONDLICHT.")
	assert_true(float(cs.get("title_at", 0.0)) < float(cs.get("fade_at", 0.0)) and float(cs.get("fade_at", 0.0)) <= float(cs.get("seconds", 0.0)), "title, fade, end in order")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for s: Dictionary in cs.get("shots", []):
		if str(s.get("vo", "")) != "":
			assert_true(lines.has(str(s["vo"])), "cutscene line %s exists" % str(s["vo"]))
	assert_true(lines.has("DEE_M4C_LAST_02"), "Dee's cage-egg gantry line exists for the ending's variant")
