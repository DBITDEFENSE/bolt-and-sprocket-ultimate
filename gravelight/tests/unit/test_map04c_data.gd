extends GutTest
## Map 4 Act III "Groom Lake" data (data/gravelight/map04c.json, UPDATE 07): the zone/door graph is connected from
## the wreck, prices are on the ladder (7,500 over the six paid doors; the hatch and the cable trench are one link
## group; Dee's side door is free by her flag), wall-buys / perks / enemies reference real ids, the act block is
## act-relative and sane (the Test Pilot on act round 6 in the lab, the rocket fallback on 9 = the act's length),
## the exfil block validates and lights on act round 9 (match 29 in a campaign run) or the rocket_ready flag, the
## generated scene places what the table says (doors, nine perks, three crate spots, the spawn table with the six
## burrow points, the controller, the parts and the workbench, the story objects, the launch points, the rocket),
## every placed id has its lore, the groom block's rounds are in order, and the cutscene is within the budget.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04c.tscn"

var cfg: Dictionary
var _nodes: Dictionary = {}


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map04c.json")
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		var nm: String = String(st.get_node_name(i))
		if _nodes.has(nm) and (_nodes[nm] as Dictionary).has("script") and not props.has("script"):
			continue
		_nodes[nm] = props


func test_zone_graph_connected_from_spawn() -> void:
	var zones: Dictionary = cfg["zones"]
	assert_eq(zones.size(), 7, "seven zones")
	var spawn: String = ""
	for z: String in zones.keys():
		if bool((zones[z] as Dictionary).get("spawn", false)):
			spawn = z
	assert_eq(spawn, "A_WRECK", "the wreck is the spawn zone")
	var adj: Dictionary = {}
	for d: Dictionary in cfg["doors"]:
		for pair: Array in [[d["from"], d["to"]], [d["to"], d["from"]]]:
			if not adj.has(pair[0]):
				adj[pair[0]] = []
			(adj[pair[0]] as Array).append(pair[1])
	var seen: Dictionary = {spawn: true}
	var queue: Array = [spawn]
	while not queue.is_empty():
		var z2: String = queue.pop_front()
		for n: String in adj.get(z2, []):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	assert_eq(seen.size(), zones.size(), "every zone is reachable from the wreck")
	assert_true(bool((zones["F_LAB"] as Dictionary).get("requires_power", false)), "the lab needs the generator")


func test_door_prices_on_the_ladder() -> void:
	var ladder: Array = []
	for v: Variant in GLData.table("economy").get("door_cost_by_depth", [750, 1000, 1250, 1500, 2000]):
		ladder.append(int(v))
	var total: int = 0
	var seen_ids: Dictionary = {}
	for d: Dictionary in cfg["doors"]:
		assert_true(ladder.has(int(d["cost"])), "door %s costs a ladder price (%d)" % [d["id"], int(d["cost"])])
		if not seen_ids.has(str(d["id"])):
			seen_ids[str(d["id"])] = true
			total += int(d["cost"])
	assert_eq(total, 8500, "the door total over the seven ids (Dee's side door is free with her radio)")
	assert_eq(str((cfg["doors"][3] as Dictionary).get("free_by_flag", "")), "dee_radio_done", "the side door's free flag")
	var lab: int = 0
	for d2: Dictionary in cfg["doors"]:
		if str(d2["id"]) == "door_lab":
			lab += 1
			assert_eq(str(d2.get("link_group", "")), "lab", "the hatch and the trench are one link group")
			assert_true(bool(d2.get("requires_power", false)), "the lab doors need the power")
	assert_eq(lab, 2, "two lab doors (the hatch from the motor pool, the trench from the radar rise)")


func test_wall_buys_perks_and_roster_reference_real_ids() -> void:
	var weapons: Dictionary = GLData.load_json("res://data/gravelight/weapons.json")["weapons"]
	for w: String in cfg["wall_buys"]:
		assert_true(weapons.has(w), "wall gun %s exists" % w)
	var perks: Dictionary = GLData.table("perks")["perks"]
	for pk: String in cfg["perks"]:
		assert_true(perks.has(pk), "perk %s exists" % pk)
	assert_eq((cfg["perks"] as Array).size(), 10, "nine cabinets (the two new tonics among them) and Ledger Lager (T-141)")
	assert_true((cfg["perks"] as Array).has("magpie_mead") and (cfg["perks"] as Array).has("skyhook_sekt"), "Magpie Mead and Skyhook Sekt are on the range")
	var enemies: Dictionary = GLData.table("enemies")["enemies"]
	for e: String in cfg["roster"]:
		if e == "testpilot":
			assert_true((GLData.table("bosses/map04")["bosses"] as Dictionary).has(e), "the boss is in bosses/map04.json")
		else:
			assert_true(enemies.has(e), "enemy %s exists" % e)
	for kind: String in ["burrower", "canary", "jumpjockey", "backorder"]:
		assert_eq(str((enemies[kind] as Dictionary).get("kind", "")), "ganger_variant", "%s is a tagged kit, not a pooled kind" % kind)
		assert_true(((enemies[kind] as Dictionary).get("maps", []) as Array).has("map04c_groomlake"), "%s is allowed on the range" % kind)
	var kits: Dictionary = (enemies["ganger"]["variants_by_map"] as Dictionary).get("map04c_groomlake", {})
	assert_false(kits.is_empty(), "the range has its own kits")
	var sum: float = 0.0
	for kit: String in kits.keys():
		assert_true((GLData.table("anim")["kits"] as Dictionary).has(kit), "kit %s exists" % kit)
		sum += float(kits[kit])
	assert_almost_eq(sum, 1.0, 0.001, "the kit weights sum to 1")
	assert_true(((enemies["glasshide"] as Dictionary).get("maps", []) as Array).has("map04c_groomlake"), "Glasshides come to the range")
	assert_true((GLData.table("enemies")["status"] as Dictionary).has("gas_slow"), "the hood gas status exists")


func test_act_block_is_act_relative_and_sane() -> void:
	var a: Dictionary = cfg["act"]
	assert_eq(int(a["index"]), 3)
	assert_eq(str(a["numeral"]), "III")
	assert_eq(int(a["length_rounds"]), 9, "nine act rounds (21-29)")
	assert_eq(str(a["special_kind"]), "dust_storm")
	var b: Dictionary = a["boss"]
	assert_eq(str(b["id"]), "testpilot")
	assert_eq(int(b["round"]), 6, "the Test Pilot on act round 6 (match 26)")
	assert_eq(str(b["arena_zone"]), "F_LAB")
	assert_lt(int(b["round"]), int(a["events"]["rocket_fallback_round"]), "the boss comes before the rocket's fallback")
	assert_eq(int(a["events"]["rocket_fallback_round"]), int(a["length_rounds"]), "the fallback is the act's last round")
	assert_eq(ActController.match_round_of(int(b["round"]), 21), 26)
	var g: Dictionary = cfg["groom"]
	assert_true(int(g["burrower"]["from_act_round"]) <= int(g["canary"]["from_act_round"]) and int(g["canary"]["from_act_round"]) <= int(g["jumpjockey"]["from_act_round"]) \
		and int(g["jumpjockey"]["from_act_round"]) <= int(g["backorder"]["from_act_round"]), "the kinds arrive in order: burrowers, canaries, jumpjockeys, backorders")
	assert_eq(int(g["backorder"]["max_active"]), 2, "the Backorders are rare")
	assert_eq(float(g["kill_plane_y"]), -25.0)
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: String in [str(g["dust_storm"]["vo_start"]), str(g["dust_storm"]["vo_end"]), str(cfg["power"]["vo_line"]), str(b.get("spawn_vo", "OPR_M4C_PILOT_SPAWN_01"))]:
		assert_true(lines.has(id), "line %s exists" % id)


func test_exfil_block_lights_on_act_round_nine_or_the_flag() -> void:
	var e: Dictionary = cfg["exfil"]
	assert_eq(Campaign.validate_exfil(e), PackedStringArray(), "the exfil block validates")
	assert_eq(str(e["target"]), "map04d_mondlicht")
	assert_eq(str(e["cutscene"]), "exfil_m4c_m4d")
	assert_eq(Campaign.exfil_round_on(e, 0, 21, true), 29, "match round 29 after Act I's fourteen and Act II's six")
	assert_eq(Campaign.exfil_round_on(e, 0, 1, true), 9, "round 9 when the act is played on its own")
	assert_eq(Campaign.exfil_round_on(e, 1, 21, true), 29 + int(e["retry_rounds"]), "a missed window retries")
	assert_eq(Campaign.act_first_round(&"map04c_groomlake"), 21, "Act III starts on match round 21")
	assert_eq(str(e["trigger_flag"]), "rocket_ready", "the console's burn lights it early")
	assert_eq(str(e["requires_flag"]), "rocket_ready", "and the lift needs it too")
	var cs: Dictionary = (Campaign.cfg()["cutscenes"] as Dictionary).get("exfil_m4c_m4d", {})
	assert_false(cs.is_empty(), "the MONDLICHT cutscene is in campaign.json")
	assert_true(float(cs["seconds"]) <= 40.0, "within the cutscene budget")
	assert_eq(str(cs["title"]), "MONDLICHT.")
	var launch: bool = false
	for s: Dictionary in cs["shots"]:
		if str(s.get("fx", "")) == "launch":
			launch = true
	assert_true(launch, "a shot carries the launch fx")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for id: String in [str(e["vo_open"]), str(e["vo_wait"]), str(e["vo_missed"])]:
		assert_true(lines.has(id), "line %s exists" % id)
	assert_true(Campaign.chain().has("map04c_groomlake"), "Act III is in the chain")
	assert_eq(Campaign.chain().find("map04c_groomlake"), Campaign.chain().find("map04b_kranich") + 1, "right after the Kranich")


func test_scene_matches_the_table() -> void:
	assert_gt(_nodes.size(), 60, "the scene loaded")
	var doors: Dictionary = {}
	var door_names: int = 0
	var perks: int = 0
	var crates: int = 0
	var windows: Dictionary = {}
	var grounds: Dictionary = {}
	var catwalks: Dictionary = {}
	var parts: Dictionary = {}
	var launches: int = 0
	for n: String in _nodes.keys():
		var p: Dictionary = _nodes[n]
		if n.begins_with("Door_"):
			doors[str(p.get("door_id", ""))] = p
			door_names += 1
		elif n.begins_with("Perk_"):
			perks += 1
		elif n.begins_with("Crate_"):
			crates += 1
		elif n.begins_with("Spawn_W_"):
			var z: String = str(p.get("zone_id", ""))
			windows[z] = int(windows.get(z, 0)) + 1
		elif n.begins_with("Ground_"):
			var z2: String = str(p.get("zone_id", ""))
			grounds[z2] = int(grounds.get(z2, 0)) + 1
		elif n.begins_with("Catwalk_"):
			var z3: String = str(p.get("zone_id", ""))
			catwalks[z3] = int(catwalks.get(z3, 0)) + 1
		elif n.begins_with("Part_ls_"):
			var pid: String = str(p.get("part_id", ""))
			parts[pid] = int(parts.get(pid, 0)) + 1
		elif n.begins_with("Launch_"):
			launches += 1
	for d: Dictionary in cfg["doors"]:
		var id: String = str(d["id"])
		assert_true(doors.has(id), "door %s is in the scene" % id)
		if doors.has(id):
			assert_eq(int((doors[id] as Dictionary).get("cost", 750)), int(d["cost"]), "door %s costs the same in the scene" % id)
			assert_eq(str((doors[id] as Dictionary).get("opens_zone", "")), str(d["to"]), "door %s opens %s" % [id, d["to"]])
			assert_eq(bool((doors[id] as Dictionary).get("requires_power", false)), bool(d.get("requires_power", false)), "door %s power rule" % id)
	assert_eq(door_names, 8, "eight door nodes (the lab's pair among them)")
	assert_eq(perks, (cfg["perks"] as Array).size(), "perk machines placed")
	assert_eq(crates, 3, "three crate spots (the wreck, the hangar, the lab)")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		assert_eq(int(windows.get(zone, 0)), int(want.get("windows", 0)), "%s windows" % zone)
		assert_eq(int(grounds.get(zone, 0)), int(want.get("ground", 0)), "%s ground spawns" % zone)
		assert_eq(int(catwalks.get(zone, 0)), int(want.get("catwalk", 0)), "%s burrow points" % zone)
	for n2: String in ["ActController", "GroomController", "Generator", "Crucible", "Workbench", "DeeRadio", "RadarRadio", "ImpellerCore", "HangarCradle", "RocketCradle", "SiloConsole",
			"CageItem_casing", "CageItem_bomber_coil", "CageItem_honey", "PilotAnchor_Hall", "PilotAnchor_Lake", "Rocket", "Trap_FuelDump"]:
		assert_true(_nodes.has(n2), "%s is placed" % n2)
	assert_eq(str((_nodes["Workbench"] as Dictionary).get("buildable_id", "")), "lodestone", "the workbench builds the Lodestone")
	for pid2: String in ["ls_part_coil", "ls_part_cradle", "ls_part_lens"]:
		assert_eq(int(parts.get(pid2, 0)), 2, "%s has two candidate spots" % pid2)
	assert_eq(launches, 4, "four launch points (the tower step's three, the gantry's foot)")


func test_every_placed_thing_has_lore() -> void:
	for pk: String in cfg["perks"]:
		var e: Dictionary = MachineLore.entry(&"map04c_groomlake", "perk." + pk)
		assert_ne(str(e.get("plate", "")), "", "%s has a plate line" % pk)
	for w: String in cfg["wall_buys"]:
		assert_ne(MachineLore.plate(&"map04c_groomlake", "chalk." + w), "", "wall gun %s has a chalk line" % w)
	assert_gt(str(MachineLore.entry(&"map04c_groomlake", "crucible").get("text", "")).length(), 200, "Crucible text")


func test_map_key_derivations_and_the_archive() -> void:
	assert_eq(ClimbLink.json_path_for(&"map04c_groomlake"), "res://data/gravelight/map04c.json")
	assert_eq(MapScan.gl_zone_names(&"map04c_groomlake").get("G_SILO", ""), "Test Silo")
	assert_eq(MapRoot.json_map_key(&"map04c_groomlake"), "4c")
	assert_eq(RoundManager.act_block_of(&"map04c_groomlake").get("index", 0), 3)
	assert_eq(RoundManager.act_round_of(26, 21, true), 6, "match 26 is act round 6")
	var fixed: int = 0
	for row: Dictionary in GLData.load_json("res://data/gravelight/intel.json").get("intel", []):
		if str(row.get("map", "")) == "4c" and str(row.get("placement", "")) == "fixed":
			fixed += 1
	assert_eq(fixed, 2, "the manifest and the program log are fixed Archive documents")
	var props: int = 0
	for e: Dictionary in GLData.load_json("res://data/gravelight/story_props.json").get("props", []):
		if str(e.get("map", "")) == "4c":
			props += 1
	assert_eq(props, 2, "both are placed in the hangar")
	assert_true((GLData.load_json("res://data/maps/bake_config.json")["maps"] as Dictionary).has("map04c_groomlake"), "the minimap bake knows the range")
	assert_true(((GLData.load_json("res://data/gravelight/objectives.json")["maps"] as Dictionary)).has("map04c_groomlake"), "the objectives block exists")
