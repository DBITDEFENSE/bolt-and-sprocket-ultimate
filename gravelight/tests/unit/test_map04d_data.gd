extends GutTest
## Map 4 Act IV "Mondlicht" data (data/gravelight/map04d.json, UPDATE 07): the zone/door graph is connected from
## Reception, prices are on the ladder (6,500 over five door ids, the store's two ways in one link group, the Account
## behind its flag), wall-buys / perks / enemies reference real ids (Act III's two by id only), the act block is
## act-relative and sane (start round 30, 0.38 g, the vacuum rules, the special, the boss on its zone, the renewal
## fallback inside the act), the generated scene places what the table says (doors, eight perks, two crate spots,
## the spawn table, the yard's vacuum volumes, two air posts, three columns, the sign, the console, the Earth,
## the controller and the flare), and every placed id has its lore.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04d.tscn"
const ACT3_IDS: Array = ["jumpjockey", "backorder"]   # Act III's types: listed by id, defined by the Groom Lake build

var cfg: Dictionary
var _nodes: Dictionary = {}


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map04d.json")
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		var nm: String = String(st.get_node_name(i))
		if _nodes.has(nm) and (_nodes[nm] as Dictionary).has("script") and not props.has("script"):
			continue
		_nodes[nm] = props


func test_zone_graph_connected_from_reception() -> void:
	var zones: Dictionary = cfg["zones"]
	assert_eq(zones.size(), 6, "six zones")
	var spawn: String = ""
	for z: String in zones.keys():
		if bool((zones[z] as Dictionary).get("spawn", false)):
			spawn = z
	assert_eq(spawn, "A_RECEPTION")
	var adj: Dictionary = {}
	for d: Dictionary in cfg["doors"]:
		assert_true(zones.has(str(d["from"])) and zones.has(str(d["to"])), "door %s joins known zones" % d["id"])
		(adj.get_or_add(str(d["from"]), [])).append(str(d["to"]))
		(adj.get_or_add(str(d["to"]), [])).append(str(d["from"]))
	var seen: Dictionary = {spawn: true}
	var queue: Array = [spawn]
	while not queue.is_empty():
		var z2: String = queue.pop_front()
		for n: String in adj.get(z2, []):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	for z3: String in zones.keys():
		assert_true(seen.has(z3), "%s is reachable through doors" % z3)
	assert_true(bool((zones["C_YARD"] as Dictionary).get("vacuum", false)), "the yard has no air")
	assert_eq(str((zones["F_CORE"] as Dictionary).get("requires_flag", "")), "account_open", "the Account opens with the columns")


func test_door_prices_on_the_ladder() -> void:
	var ladder: Array = []
	for v: Variant in GLData.table("economy").get("door_cost_by_depth", [750, 1000, 1250, 1500, 2000]):
		ladder.append(int(v))
	var seen_ids: Dictionary = {}
	var total: int = 0
	for d: Dictionary in cfg["doors"]:
		var cost: int = int(d["cost"])
		assert_true(ladder.has(cost), "%s costs %d (on the ladder)" % [d["id"], cost])
		if seen_ids.has(str(d["id"])):
			assert_eq(str(d.get("link_group", "")), str(seen_ids[str(d["id"])]), "a repeated door id is one link group")
		else:
			total += cost
		seen_ids[str(d["id"])] = str(d.get("link_group", ""))
		if d.has("requires_flag"):
			assert_eq(str(d["id"]), "door_account", "only the Account's door waits for a flag")
	assert_eq(seen_ids.size(), 5, "five distinct doors (the store's two are one link group)")
	assert_eq(total, 6500, "the door total is 6,500: 750 + 1000 + 1250 (both ways into the store, one price) + 1500 + 2000")


func test_wall_buys_perks_and_roster_reference_real_ids() -> void:
	var weapons: Dictionary = GLData.load_json("res://data/gravelight/weapons.json")
	var wtable: Dictionary = weapons.get("weapons", weapons)
	for w: String in cfg["wall_buys"]:
		assert_true(wtable.has(w), "wall buy %s is a weapon" % w)
	var perks: Dictionary = GLData.table("perks")["perks"]
	for p: String in cfg["perks"]:
		assert_true(perks.has(p), "perk %s exists" % p)
	assert_eq((cfg["perks"] as Array).size(), 9, "eight cabinets and Ledger Lager (T-141)")
	assert_true((cfg["perks"] as Array).has("skyhook_sekt") and (cfg["perks"] as Array).has("magpie_mead"), "both new tonics")
	var enemies: Dictionary = GLData.table("enemies")["enemies"]
	var bosses: Dictionary = GLData.table("bosses/map04").get("bosses", {})
	for e: String in cfg["roster"]:
		if ACT3_IDS.has(e):
			continue
		assert_true(enemies.has(e) or bosses.has(e), "roster id %s exists" % e)
	assert_true((cfg["roster"] as Array).has("suited") and (cfg["roster"] as Array).has("account_manager"))


func test_act_block_is_sane() -> void:
	var a: Dictionary = cfg["act"]
	assert_eq(int(a["index"]), 4)
	assert_eq(str(a["numeral"]), "IV")
	assert_eq(int(a["start_round"]), 30, "the launcher's skip and the chain agree on round 30")
	assert_eq(Campaign.act_first_round(&"map04d_mondlicht"), 30)
	assert_almost_eq(float(a["gravity_scale"]), 0.38, 0.001)
	assert_eq(str(a["special_kind"]), "solar_flare")
	assert_eq(str(a["transition"]), "ending", "no exfil: the act ends the campaign")
	assert_true(Campaign.exfil_cfg(&"map04d_mondlicht").is_empty(), "no exfil block")
	var b: Dictionary = a["boss"]
	assert_eq(str(b["id"]), "account_manager")
	assert_eq(str(b["on_zone"]), "F_CORE", "summoned when the Account opens, not on a round")
	var fb: int = int((a["events"] as Dictionary)["renewal_fallback_act_round"])
	assert_true(fb >= 10 and fb <= int(a["length_rounds"]), "the fallback renewal sits inside the act (%d of %d)" % [fb, int(a["length_rounds"])])


func test_data_blocks_for_the_systems() -> void:
	for k: String in ["earth", "solar_flare", "columns", "renewal", "arrival", "endings"]:
		assert_true(cfg.has(k), "map04d.json has %s" % k)
	var col: Dictionary = cfg["columns"]
	assert_eq((col["ids"] as Array).size(), 3)
	assert_eq((col["panels"] as Array).size(), 3)
	for st: String in (col["sign"] as Dictionary)["stages"]:
		assert_eq(st.length(), "NOBODY CANCELS".length(), "sign stage '%s' keeps every letter's place" % st)
	assert_eq(((col["sign"] as Dictionary)["stages"] as Array).size(), 4, "0..3 dark")
	var fl: Dictionary = cfg["solar_flare"]
	assert_gt((fl["rim_points"] as Array).size(), 2)
	assert_eq(str(fl["vo_start"]), "OPR_M4D_FLARE_01")
	assert_almost_eq(float((cfg["renewal"] as Dictionary)["seconds"]), 360.0, 0.001, "six real minutes")


func test_scene_places_what_the_table_says() -> void:
	var door_ids: Dictionary = {}
	var perks: int = 0
	var crates: int = 0
	var spawns: Dictionary = {}
	var vac_zones: int = 0
	var posts: int = 0
	var columns: int = 0
	var found: Dictionary = {}
	for nm: String in _nodes.keys():
		var p: Dictionary = _nodes[nm]
		var sc: Variant = p.get("script")
		var path: String = (sc as Resource).resource_path if sc is Resource else ""
		if path.ends_with("door.gd"):
			door_ids[String(p.get("door_id", ""))] = true
		elif path.ends_with("perk_machine.gd"):
			perks += 1
		elif path.ends_with("mystery_crate.gd"):
			crates += 1
		elif path.ends_with("zombie_spawn.gd"):
			var z: String = String(p.get("zone_id", ""))
			var row: Dictionary = spawns.get_or_add(z, {"windows": 0, "ground": 0, "catwalk": 0})
			if String(p.get("kind", "window")) == "window":
				row["windows"] = int(row["windows"]) + 1
			elif nm.begins_with("Catwalk"):
				row["catwalk"] = int(row["catwalk"]) + 1
			else:
				row["ground"] = int(row["ground"]) + 1
		elif path.ends_with("zone_volume.gd") and bool(p.get("vacuum", false)):
			vac_zones += 1
		elif path.ends_with("air_post.gd"):
			posts += 1
		elif path.ends_with("retention_column.gd"):
			columns += 1
		for key: String in ["cancel_sign.gd", "account_console.gd", "earth_sky.gd", "mondlicht_controller.gd", "solar_flare.gd"]:
			if path.ends_with(key):
				found[key] = true
	for d: Dictionary in cfg["doors"]:
		assert_true(door_ids.has(str(d["id"])), "door %s is placed" % d["id"])
	assert_eq(perks, 9, "eight perk machines and Ledger Lager (T-141)")
	assert_eq(crates, 2, "two crate spots")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		var have: Dictionary = spawns.get(zone, {"windows": 0, "ground": 0, "catwalk": 0})
		assert_eq(int(have["windows"]), int(want.get("windows", 0)), "%s windows" % zone)
		assert_eq(int(have["ground"]), int(want.get("ground", 0)), "%s ground" % zone)
		assert_eq(int(have["catwalk"]), int(want.get("catwalk", 0)), "%s catwalk" % zone)
	assert_eq(vac_zones, 1, "the yard's volume is vacuum")
	assert_eq(posts, 2, "two air posts")
	assert_eq(columns, 3, "three columns")
	for key2: String in ["cancel_sign.gd", "account_console.gd", "earth_sky.gd", "mondlicht_controller.gd", "solar_flare.gd"]:
		assert_true(found.has(key2), "%s is placed" % key2)
	assert_eq(String((_nodes.get("Door_Account", {}) as Dictionary).get("requires_flag", "")), "account_open", "the Account's door carries its flag")
	assert_true(bool((_nodes.get("Map04dMondlicht", {}) as Dictionary).get("power_on_at_start", false)), "the relay runs: power on from the start")


func test_lore_for_every_placed_thing() -> void:
	var m: StringName = &"map04d_mondlicht"
	for p: String in cfg["perks"]:
		assert_ne(MachineLore.plate(m, "perk." + p), "", "perk %s has a plate" % p)
		assert_gt(str(MachineLore.entry(m, "perk." + p).get("text", "")).length(), 200, "perk %s has its Archive text" % p)
	for w: String in cfg["wall_buys"]:
		assert_ne(MachineLore.plate(m, "chalk." + w), "", "wall gun %s has a scratch line" % w)
	assert_string_contains(MachineLore.plate(m, "crucible"), "UNIT 001", "the first Crucible's plate")
	assert_false(MachineLore.row(m, "chalk").is_empty())
	var ids: Array = []
	for row: Dictionary in GLData.load_json("res://data/gravelight/intel.json").get("intel", []):
		if str(row.get("map", "")) == "4d":
			ids.append(str(row["id"]))
	for want: String in ["INT_M4_RELAY", "INT_M4_PILCH", "INT_M4_SMILE", "INT_M4_CREWTAGS"]:
		assert_true(ids.has(want), "%s files under 4d" % want)
	var props: Array = []
	for e: Dictionary in GLData.load_json("res://data/gravelight/story_props.json").get("props", []):
		if str(e.get("map", "")) == "4d":
			props.append(str(e["id"]))
	assert_eq(props.size(), 5, "the four documents and the Terms of the Mark (T-137) are hand-placed")


func test_objectives_bake_and_menu_know_the_act() -> void:
	assert_true((GLData.load_json("res://data/gravelight/objectives.json")["maps"] as Dictionary).has("map04d_mondlicht"))
	assert_true((GLData.load_json("res://data/maps/bake_config.json")["maps"] as Dictionary).has("map04d_mondlicht"))
	assert_eq(Campaign.scene_for(&"map04d_mondlicht"), SCENE)
	assert_true(Campaign.scene_exists(&"map04d_mondlicht"))
	assert_eq(Campaign.display_name(&"map04d_mondlicht"), "Fernflug — Act IV: Mondlicht")
	var kit: Dictionary = Campaign.arrival_kit(&"map04d_mondlicht")
	assert_true(not kit.is_empty() and (kit.get("perks", []) as Array).has("skyhook_sekt"), "the skip-to-Act-IV kit")
