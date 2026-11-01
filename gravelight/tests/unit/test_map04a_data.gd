extends GutTest
## Map 4 Act I "Werk Thalbach" data (data/gravelight/map04a.json, UPDATE 07): the zone/door graph is connected from
## the spawn, prices are on the ladder, wall-buys / perks / enemies reference real ids, the act block is sane, the
## exfil block validates, the generated scene places what the table says (doors with the same ids, costs and zones;
## eight perk machines; four crate spots; the spawn table), and every placed id has its lore.

const SCENE: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"

var cfg: Dictionary
var _nodes: Dictionary = {}


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map04a.json")
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		_nodes[String(st.get_node_name(i))] = props


func test_zone_graph_connected_from_spawn() -> void:
	var zones: Dictionary = cfg["zones"]
	assert_eq(zones.size(), 8, "eight zones")
	var spawn: String = ""
	for z: String in zones.keys():
		if bool((zones[z] as Dictionary).get("spawn", false)):
			spawn = z
	assert_eq(spawn, "A_SIEDLUNG", "the Siedlung is the spawn zone")
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
			assert_eq(cost, 2000, "the powered door is the dearest")
	assert_eq(seen_ids.size(), 7, "seven distinct doors")
	assert_eq(total, 8750, "the door total is the design's 8,750")


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
	assert_eq((cfg["perks"] as Array).size(), 9, "eight perks on Act I and Ledger Lager (T-141)")
	var enemies: Dictionary = GLData.table("enemies")["enemies"]
	for e: String in cfg["roster"]:
		if e == "kranfuehrer":
			assert_true((GLData.table("bosses/map04")["bosses"] as Dictionary).has(e), "the boss is in bosses/map04.json")
			continue
		assert_true(enemies.has(e), "enemy %s exists" % e)
		if enemies.has(e):
			var maps: Array = (enemies[e] as Dictionary).get("maps", [])
			assert_true(maps.is_empty() or maps.has("map04a_thalbach"), "enemy %s may spawn on Act I" % e)
	assert_true((GLData.table("enemies")["enemies"]["ganger"]["variants_by_map"] as Dictionary).has("map04a_thalbach"), "Thalbach outfit kits")
	for kit: String in (GLData.table("enemies")["enemies"]["ganger"]["variants_by_map"]["map04a_thalbach"] as Dictionary).keys():
		assert_ne(kit, "laborer", "no labourer kit, ever")
		assert_true((GLData.table("anim")["kits"] as Dictionary).has(kit), "kit %s exists" % kit)


func test_act_block_and_exfil() -> void:
	var a: Dictionary = cfg["act"]
	assert_eq(int(a["index"]), 1)
	assert_eq(str(a["numeral"]), "I")
	assert_eq(int(a["length_rounds"]), 14, "Act I is 14 rounds")
	assert_eq(str(a["special_kind"]), "fliegeralarm")
	assert_true(int(a["halle_open_round"]) <= int(a["length_rounds"]), "the hangar opens inside the act")
	var b: Dictionary = a["boss"]
	assert_eq(str(b["id"]), "kranfuehrer")
	assert_true(int(b["round"]) < int(a["length_rounds"]) + 1 and int(b["round"]) > int(a["halle_open_round"]), "the boss comes after the hangar opens, before the turn")
	var e: Dictionary = cfg["exfil"]
	assert_eq(Campaign.validate_exfil(e), PackedStringArray(), "the exfil block validates")
	assert_eq(int(e["round"]), int(a["length_rounds"]) + 1, "the ramp lights on the turn's round")
	assert_eq(str(e["target"]), "map04b_kranich")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for key: String in ["vo_open", "vo_wait", "vo_missed"]:
		assert_true(lines.has(str(e[key])), "exfil line %s exists" % e[key])
	assert_true(lines.has(str(cfg["power"]["vo_line"])), "the power line exists")
	var f: Dictionary = cfg["fliegeralarm"]
	assert_true(lines.has(str(f["vo_start"])) and lines.has(str(f["vo_end"])), "the Fliegeralarm lines exist")
	assert_gt(float(f["telegraph_seconds"]), 2.0, "a circle is readable")
	for z: String in (f["circles"] as Dictionary).keys():
		assert_true((cfg["zones"] as Dictionary).has(z), "circle zone %s exists" % z)
	assert_eq(str(cfg["map_key"]), "4a")


func test_scene_matches_the_table() -> void:
	assert_gt(_nodes.size(), 50, "the scene loaded")
	var doors: Dictionary = {}
	var perks: int = 0
	var crates: int = 0
	var windows: Dictionary = {}
	var grounds: Dictionary = {}
	var catwalks: Dictionary = {}
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
	for d: Dictionary in cfg["doors"]:
		var id: String = str(d["id"])
		assert_true(doors.has(id), "door %s is in the scene" % id)
		if doors.has(id):
			assert_eq(int((doors[id] as Dictionary).get("cost", 750)), int(d["cost"]), "door %s costs the same in the scene (750 is the script default the packed scene omits)" % id)
			assert_eq(str((doors[id] as Dictionary).get("opens_zone", "")), str(d["to"]), "door %s opens %s" % [id, d["to"]])
			assert_eq(bool((doors[id] as Dictionary).get("requires_power", false)), bool(d.get("requires_power", false)), "door %s power rule" % id)
	assert_eq(str((doors["door_halle"] as Dictionary).get("requires_flag", "")), "halle_unlocked", "the hangar door waits for the act's unlock")
	assert_eq(perks, (cfg["perks"] as Array).size(), "perk machines placed")
	assert_eq(crates, 4, "four crate spots")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		assert_eq(int(windows.get(zone, 0)), int(want.get("windows", 0)), "%s windows" % zone)
		assert_eq(int(grounds.get(zone, 0)), int(want.get("ground", 0)), "%s ground spawns" % zone)
		assert_eq(int(catwalks.get(zone, 0)), int(want.get("catwalk", 0)), "%s catwalk spawns" % zone)
	assert_true(_nodes.has("ActController") and _nodes.has("Fliegeralarm") and _nodes.has("Hauptschalter") and _nodes.has("Crucible"), "the act's systems are placed")
	assert_true(_nodes.has("GreatDoors"), "the hangar doors node for the boarding cutscene's fx")


func test_every_placed_thing_has_lore() -> void:
	for pk: String in cfg["perks"]:
		var e: Dictionary = MachineLore.entry(&"map04a_thalbach", "perk." + pk)
		assert_ne(str(e.get("plate", "")), "", "%s has a plate line" % pk)
	for w: String in cfg["wall_buys"]:
		assert_ne(MachineLore.plate(&"map04a_thalbach", "chalk." + w), "", "wall gun %s has a chalk line" % w)
	assert_gt(str(MachineLore.entry(&"map04a_thalbach", "crucible").get("text", "")).length(), 200, "Crucible text")


func test_map_key_derivations() -> void:
	assert_eq(ClimbLink.json_path_for(&"map04a_thalbach"), "res://data/gravelight/map04a.json")
	assert_eq(ClimbLink.json_path_for(&"map02_totenhafen"), "res://data/gravelight/map02.json", "the old maps keep their path")
	assert_eq(MapScan.climb_links(&"map04a_thalbach").size(), 2, "two crane-rail climbs")
	assert_eq(MapScan.gl_zone_names(&"map04a_thalbach").get("H_HALLE", ""), "The Great Hangar")
	assert_eq(MapRoot.json_map_key(&"map04a_thalbach"), "4a")
	assert_eq(MapRoot.json_map_key(&"map02_totenhafen"), "?", "the old maps keep their hard-coded keys")
	assert_eq(RoundManager.act_block_of(&"map04a_thalbach").get("index", 0), 1)
	assert_true(RoundManager.act_block_of(&"map02_totenhafen").is_empty())
