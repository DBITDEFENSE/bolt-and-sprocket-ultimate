extends GutTest
## Map 4 Act II "der Kranich" data (data/gravelight/map04b.json, UPDATE 07): the zone/door graph is connected from
## the aft bomb bay, prices are on the ladder (6,750 over six doors, the cockpit pair one link group), wall-buys /
## perks / enemies reference real ids, the act block is act-relative and sane (London 3 < Bordwart 4 < run 5 <
## fallback 6 = the act's length), the exfil block validates and lights on act round 6 (match 20 in a campaign
## run), the generated scene places what the table says (doors, eight perks, one crate spot, the spawn table, the
## flight systems, the four breach panels and six racks), and every placed id has its lore.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"

var cfg: Dictionary
var _nodes: Dictionary = {}
var _rack_defaults: Dictionary = {}


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map04b.json")
	var r: BombRack = BombRack.new()
	_rack_defaults = {"rack_index": r.rack_index, "city": r.city}
	r.free()
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		var nm: String = String(st.get_node_name(i))
		if _nodes.has(nm) and (_nodes[nm] as Dictionary).has("script") and not props.has("script"):
			continue   # a dressing node (the bomb casings are "Rack*" too) never shadows the gameplay node of that name
		_nodes[nm] = props


func test_zone_graph_connected_from_spawn() -> void:
	var zones: Dictionary = cfg["zones"]
	assert_eq(zones.size(), 7, "seven zones")
	var spawn: String = ""
	for z: String in zones.keys():
		if bool((zones[z] as Dictionary).get("spawn", false)):
			spawn = z
	assert_eq(spawn, "A_BOMBENSCHACHT", "the aft bomb bay is the spawn zone")
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
	assert_true(bool((zones["F_COCKPIT"] as Dictionary).get("requires_power", false)), "the flight deck needs the auxiliary bus")


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
		if bool(d.get("requires_power", false)):
			assert_eq(str(d["id"]), "door_cockpit", "only the cockpit door waits for the power")
			assert_eq(str(d.get("requires_flag", "")), "autopilot_key", "and for the engineer's key")
	assert_eq(seen_ids.size(), 6, "six distinct doors")
	assert_eq(total, 6750, "the door total is 6,750 (two ways into the cockpit, one price)")


func test_wall_buys_perks_and_roster_reference_real_ids() -> void:
	var weapons: Dictionary = GLData.load_json("res://data/gravelight/weapons.json")
	for w: String in cfg["wall_buys"]:
		var found: Dictionary = {}
		for key: String in ["weapons", "melee", "lethal"]:
			var v: Variant = weapons.get(key, {})
			if v is Dictionary and (v as Dictionary).has(w):
				found = (v as Dictionary)[w]
		assert_false(found.is_empty(), "wall-buy %s is a weapon" % w)
		if not found.is_empty():
			assert_gt(int(found.get("wall_price", found.get("price", 0))), 0, "wall-buy %s has a wall price" % w)
	var perks: Dictionary = GLData.table("perks")["perks"]
	for pk: String in cfg["perks"]:
		assert_true(perks.has(pk), "perk %s exists" % pk)
	assert_eq((cfg["perks"] as Array).size(), 9, "eight perks on Act II and Ledger Lager (T-141)")
	assert_true((cfg["perks"] as Array).has("skyhook_sekt"), "the Skyhook Sekt debuts on the Kranich")
	var enemies: Dictionary = GLData.table("enemies")["enemies"]
	for e: String in cfg["roster"]:
		if e == "bordwart":
			assert_true((GLData.table("bosses/map04")["bosses"] as Dictionary).has(e), "the boss is in bosses/map04.json")
			continue
		assert_true(enemies.has(e), "enemy %s exists" % e)
		if enemies.has(e):
			var maps: Array = (enemies[e] as Dictionary).get("maps", [])
			assert_true(maps.is_empty() or maps.has("map04b_kranich"), "enemy %s may spawn on Act II" % e)
	var kits: Dictionary = (GLData.table("enemies")["enemies"]["ganger"]["variants_by_map"] as Dictionary).get("map04b_kranich", {})
	assert_false(kits.is_empty(), "Kranich crew outfit kits")
	for kit: String in kits.keys():
		assert_ne(kit, "laborer", "no labourer kit, ever")
		assert_true((GLData.table("anim")["kits"] as Dictionary).has(kit), "kit %s exists" % kit)
	assert_eq(str((cfg["flight"]["climbers"] as Dictionary).get("kit", "")), "soldier", "the climbers wear the crew's soldier kit")


func test_act_block_is_act_relative_and_sane() -> void:
	var a: Dictionary = cfg["act"]
	assert_eq(int(a["index"]), 2)
	assert_eq(str(a["numeral"]), "II")
	assert_eq(int(a["length_rounds"]), 6, "Act II is 6 rounds (match 15-20)")
	assert_eq(str(a["special_kind"]), "druckabfall")
	var b: Dictionary = a["boss"]
	assert_eq(str(b["id"]), "bordwart")
	assert_eq(str(b["arena_zone"]), "D_TRIEBWERK")
	var ev: Dictionary = a["events"]
	var london: int = int(ev["london_window_round"])
	var run: int = int(ev["bomb_run_round"])
	var fallback: int = int(ev["autopilot_fallback_round"])
	assert_true(london < int(b["round"]) and int(b["round"]) < run and run < fallback, "London, the Bordwart, the run, then the way down")
	assert_true(fallback <= int(a["length_rounds"]), "the fallback key comes inside the act")
	assert_eq(ActController.match_round_of(int(b["round"]), 15), 18, "the Bordwart's round is match 18 in a campaign run")
	assert_eq(ActController.match_round_of(london, 15), 17, "London is match 17")
	assert_eq(ActController.match_round_of(run, 15), 19, "the bomb run is match 19")
	assert_eq(str(cfg["map_key"]), "4b")
	assert_true(int(cfg["flight"]["strafe"]["from_act_round"]) >= 1 and int(cfg["flight"]["breach"]["from_act_round"]) >= 1, "the set-pieces count act rounds")


func test_exfil_block_lights_on_act_round_six() -> void:
	var e: Dictionary = cfg["exfil"]
	assert_eq(Campaign.validate_exfil(e), PackedStringArray(), "the exfil block validates")
	assert_eq(str(e["target"]), "map04c_groomlake")
	assert_eq(str(e["zone"]), "F_COCKPIT")
	assert_eq(int(e["act_round"]), int(cfg["act"]["length_rounds"]), "the autopilot lights on the act's last round")
	assert_eq(Campaign.exfil_round_on(e, 0, 15, true), 20, "match round 20 after Act I's fourteen")
	assert_eq(Campaign.exfil_round_on(e, 0, 1, true), 6, "round 6 when the act is played on its own")
	assert_eq(Campaign.exfil_round_on(e, 1, 15, true), 20 + int(e["retry_rounds"]), "a missed window retries")
	assert_eq(Campaign.exfil_round_on(e, 0, 15, false), int(e["round"]), "off an act map the nominal round holds")
	assert_eq(Campaign.act_first_round(&"map04b_kranich"), 15, "Act II starts on match round 15")
	assert_eq(Campaign.act_first_round(&"map04a_thalbach"), 1)
	assert_eq(Campaign.act_first_round(&"map00_crossroads"), 1, "a map without an act starts at 1")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for key: String in ["vo_open", "vo_wait", "vo_missed", "vo_stage"]:
		assert_true(lines.has(str(e[key])), "exfil line %s exists" % e[key])
	assert_true(lines.has(str(cfg["power"]["vo_line"])), "the power line exists")
	assert_true(float(e["stage_hold"]) < float(e["hold_seconds"]), "unlock is quick, the rip-out is the long hold")


func test_scene_matches_the_table() -> void:
	assert_gt(_nodes.size(), 50, "the scene loaded")
	var doors: Dictionary = {}
	var perks: int = 0
	var crates: int = 0
	var windows: Dictionary = {}
	var grounds: Dictionary = {}
	var catwalks: Dictionary = {}
	var panels: int = 0
	var racks: Dictionary = {}
	for n: String in _nodes.keys():
		var p: Dictionary = _nodes[n]
		if n.begins_with("Door_"):
			doors[str(p.get("door_id", ""))] = p
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
		elif n.begins_with("Breach"):
			panels += 1
		elif n.begins_with("Rack") and p.has("script"):
			# the packed scene omits a property at its script default (rack 1 / Boston are the defaults)
			racks[int(p.get("rack_index", _rack_defaults["rack_index"]))] = str(p.get("city", _rack_defaults["city"]))
	for d: Dictionary in cfg["doors"]:
		var id: String = str(d["id"])
		assert_true(doors.has(id), "door %s is in the scene" % id)
		if doors.has(id):
			assert_eq(int((doors[id] as Dictionary).get("cost", 750)), int(d["cost"]), "door %s costs the same in the scene" % id)
			assert_eq(str((doors[id] as Dictionary).get("opens_zone", "")), str(d["to"]), "door %s opens %s" % [id, d["to"]])
			assert_eq(bool((doors[id] as Dictionary).get("requires_power", false)), bool(d.get("requires_power", false)), "door %s power rule" % id)
	assert_eq(str((doors["door_cockpit"] as Dictionary).get("requires_flag", "")), "autopilot_key", "the cockpit door waits for the engineer's key")
	assert_true(_nodes.has("Door_CockpitL") and _nodes.has("Door_CockpitR"), "two cockpit doors (port walkway, starboard walkway)")
	assert_eq(perks, (cfg["perks"] as Array).size(), "perk machines placed")
	assert_eq(crates, 2, "two crate spots (the galley; the gun blisters, T-156)")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		assert_eq(int(windows.get(zone, 0)), int(want.get("windows", 0)), "%s windows" % zone)
		assert_eq(int(grounds.get(zone, 0)), int(want.get("ground", 0)), "%s ground spawns" % zone)
		assert_eq(int(catwalks.get(zone, 0)), int(want.get("catwalk", 0)), "%s catwalk spawns" % zone)
	assert_true(_nodes.has("ActController") and _nodes.has("FlightController") and _nodes.has("AuxBus") and _nodes.has("Crucible"), "the act's systems are placed")
	assert_eq(panels, 4, "four breach panels")
	assert_eq(racks.size(), 6, "six bomb racks")
	var cities: Array = cfg["flight"]["bomb_run"]["cities"]
	for i: int in 6:
		assert_eq(racks.get(i + 1, ""), str(cities[i]), "rack %d is %s" % [i + 1, cities[i]])
	assert_true(_nodes.has("LondonCam") and _nodes.has("LondonPlate"), "the London window's camera post and plate")
	assert_true(_nodes.has("WingDiorama"), "the crash cutscene's diorama")


func test_every_placed_thing_has_lore() -> void:
	for pk: String in cfg["perks"]:
		var e: Dictionary = MachineLore.entry(&"map04b_kranich", "perk." + pk)
		assert_ne(str(e.get("plate", "")), "", "%s has a plate line" % pk)
	for w: String in cfg["wall_buys"]:
		assert_ne(MachineLore.plate(&"map04b_kranich", "chalk." + w), "", "wall gun %s has a chalk line" % w)
	assert_gt(str(MachineLore.entry(&"map04b_kranich", "crucible").get("text", "")).length(), 200, "Crucible text")


func test_map_key_derivations() -> void:
	assert_eq(ClimbLink.json_path_for(&"map04b_kranich"), "res://data/gravelight/map04b.json")
	assert_eq(MapScan.gl_zone_names(&"map04b_kranich").get("F_COCKPIT", ""), "Flight Deck")
	assert_eq(MapRoot.json_map_key(&"map04b_kranich"), "4b")
	assert_eq(RoundManager.act_block_of(&"map04b_kranich").get("index", 0), 2)
	assert_eq(RoundManager.act_round_of(17, 15, true), 3, "match 17 is act round 3")
	assert_eq(RoundManager.act_round_of(17, 1, true), 17, "played on its own the act counts from 1")
