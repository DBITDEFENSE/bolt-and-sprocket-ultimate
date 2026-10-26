extends GutTest
## UPDATE 07: Campaign.begin_at (the launcher's act skips), the chain through Map 4's acts, the arrival kits, the
## act exfils (a flag-lit beacon, the autopilot's stages) and the new cutscene fx names.

func after_each() -> void:
	Campaign.reset()


func test_chain_runs_into_map4_and_morgenrot_is_noted() -> void:
	var c: Dictionary = Campaign.cfg()
	assert_eq(Campaign.chain(), ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake"])
	assert_true(str(c["_doc"]).contains("map03"), "the doc says where Morgenrot slots in")
	assert_false((c.get("standalone", []) as Array).has("map04a_thalbach"), "Act I left the standalone list when it joined the chain")
	for id: String in ["map04a_thalbach", "map04b_kranich", "map04c_groomlake"]:
		assert_true((c["scenes"] as Dictionary).has(id) and (c["display_names"] as Dictionary).has(id), "%s registered" % id)


func test_totenhafen_exfil_leads_to_thalbach_at_round_40() -> void:
	var e: Dictionary = Campaign.exfil_cfg(&"map02_totenhafen")
	assert_eq(Campaign.validate_exfil(e), PackedStringArray(), "map02.json exfil block is valid")
	assert_eq(int(e["round"]), 40)
	assert_eq(str(e["target"]), "map04a_thalbach")
	assert_true((Campaign.cfg()["cutscenes"] as Dictionary).has(str(e["cutscene"])))
	var unlock: Dictionary = GLData.load_json("res://data/gravelight/progression.json")["map_unlock_rounds"]
	assert_eq(int(unlock["map04a_thalbach"]["round"]), 40)


func test_act_exfils_validate_and_carry_the_new_fields() -> void:
	var a: Dictionary = Campaign.exfil_cfg(&"map04a_thalbach")
	assert_eq(Campaign.validate_exfil(a), PackedStringArray())
	assert_eq(str(a["target"]), "map04b_kranich")
	var b: Dictionary = Campaign.exfil_cfg(&"map04b_kranich")
	assert_eq(Campaign.validate_exfil(b), PackedStringArray())
	assert_eq(str(b["target"]), "map04c_groomlake")
	assert_eq(str(b["requires_flag"]), "autopilot_key", "the autopilot needs the key")
	assert_eq(str(b["stage_flag"]), "autopilot_unlocked", "unlock first, then the rip-out hold")
	assert_eq(float(b["hold_seconds"]), 6.0)
	assert_eq(str(b["trigger_flag"]), "autopilot_now", "the egg can light it early")
	for id: String in ["exfil_m4a_m4b", "exfil_m4b_m4c", "exfil_m2_m4"]:
		var cs: Dictionary = (Campaign.cfg()["cutscenes"] as Dictionary).get(id, {})
		assert_false(cs.is_empty(), "cutscene %s defined" % id)
		assert_gt((cs.get("shots", []) as Array).size(), 2, "%s has shots" % id)


func test_cutscene_fx_names_are_known() -> void:
	var src: String = FileAccess.get_file_as_string("res://gravelight/ui/exfil_cutscene.gd")
	var used: Dictionary = {}
	for cs: Variant in (Campaign.cfg()["cutscenes"] as Dictionary).values():
		for s: Variant in (cs as Dictionary).get("shots", []):
			var fx: String = str((s as Dictionary).get("fx", ""))
			if fx != "":
				used[fx] = true
	for fx2: String in used.keys():
		assert_true(src.contains("\"%s\":" % fx2), "fx '%s' has a case in the cutscene player" % fx2)
	for fx3: String in ["ramp", "kranich_takeoff", "crash", "launch"]:
		assert_true(src.contains("func _fx_%s" % fx3), "the %s fx exists" % fx3)


func test_begin_at_sets_a_pending_start_and_a_kit() -> void:
	Campaign.begin_at(&"map04b_kranich", 15, {"weapons": [["thompson_up", 1], "mp40"], "perks": ["ironhide_stout"], "scrip": 9000})
	assert_true(Campaign.active)
	var ps: Dictionary = Campaign.pending_start_for(&"map04b_kranich")
	assert_eq(int(ps["round"]), 15)
	assert_true(Campaign.pending_start_for(&"map00_crossroads").is_empty(), "only for that map")
	var inv: Dictionary = Campaign.kit_to_net(ps["kit"], GLData.table("weapons"))
	assert_eq((inv["s"] as Array).size(), 2, "both weapons made it")
	var first: Array = (inv["s"] as Array)[0]
	assert_eq(str(first[0]), "thompson_up")
	assert_gt(int(first[1]), 0, "a full magazine from the weapon table")
	assert_gt(int(first[2]), 0, "a reserve")
	assert_eq(int(inv["g"]), 2, "the default grenades")
	Campaign.reset()
	assert_true(Campaign.pending_start_for(&"map04b_kranich").is_empty(), "reset clears it")


func test_arrival_kits_reference_real_ids() -> void:
	var w: Dictionary = GLData.table("weapons")
	var perks: Dictionary = GLData.table("perks")["perks"]
	var kits: Dictionary = Campaign.cfg().get("arrival_kits", {})
	assert_true(kits.has("map04b_kranich"), "Act II has an arrival kit")
	for k: String in kits.keys():
		if k.begins_with("_"):
			continue
		var kit: Dictionary = kits[k]
		for wv: Variant in kit.get("weapons", []):
			var id: String = str((wv as Array)[0])
			assert_true((w["weapons"] as Dictionary).has(id) or (w["upgraded"] as Dictionary).has(id), "kit weapon %s exists" % id)
		for pk: Variant in kit.get("perks", []):
			assert_true(perks.has(str(pk)), "kit perk %s exists" % str(pk))
		var inv: Dictionary = Campaign.kit_to_net(kit, w)
		assert_eq((inv["s"] as Array).size(), (kit.get("weapons", []) as Array).size(), "%s: every weapon resolves" % k)


func test_act_first_round_and_act_relative_exfil_rounds() -> void:
	assert_eq(Campaign.act_first_round(&"map04a_thalbach"), 1)
	assert_eq(Campaign.act_first_round(&"map04b_kranich"), 15, "after Act I's fourteen rounds")
	assert_eq(Campaign.act_first_round(&"map02_totenhafen"), 1, "no act, no offset")
	var e: Dictionary = {"round": 20, "act_round": 6, "retry_rounds": 2}
	assert_eq(Campaign.exfil_round_on(e, 0, 15, true), 20)
	assert_eq(Campaign.exfil_round_on(e, 0, 1, true), 6, "the act on its own")
	assert_eq(Campaign.exfil_round_on(e, 2, 15, true), 24, "two misses")
	assert_eq(Campaign.exfil_round_on(e, 0, 15, false), 20, "no act: the nominal round")
	assert_eq(Campaign.exfil_round_on({"round": 10, "retry_rounds": 3}, 1, 5, true), 13, "no act_round: the old rule")
