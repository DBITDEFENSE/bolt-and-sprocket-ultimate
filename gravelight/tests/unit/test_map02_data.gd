extends GutTest
## Map 2 "Totenhafen" data (data/gravelight/map02.json, T-036): the zone/door graph is connected from the spawn,
## prices are on the ladder, wall-buys / perks / enemies reference real ids, the tide block is sane and its rules
## hold, the generated scene places what the table says (doors with the same ids, costs and zones; six perk
## machines; five crate spots; the spawn points the tide switches), and the wading status exists.

const SCENE: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"

var cfg: Dictionary
var _nodes: Dictionary = {}   # node name -> {property: value} from the packed scene's state


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/map02.json")
	var st: SceneState = (load(SCENE) as PackedScene).get_state()
	for i: int in st.get_node_count():
		var props: Dictionary = {}
		for j: int in st.get_node_property_count(i):
			props[st.get_node_property_name(i, j)] = st.get_node_property_value(i, j)
		_nodes[String(st.get_node_name(i))] = props


func _ids(table: String, key: String) -> Array:
	var out: Array = []
	var d: Dictionary = GLData.load_json("res://data/gravelight/%s.json" % table)
	var v: Variant = d.get(key, {})
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			var row: Variant = (v as Dictionary)[k]
			out.append(str((row as Dictionary).get("id", k)) if row is Dictionary else str(k))
	elif v is Array:
		for row: Variant in v:
			out.append(str((row as Dictionary).get("id", "")))
	return out


func test_zone_graph_connected_from_spawn() -> void:
	var zones: Dictionary = cfg["zones"]
	assert_eq(zones.size(), 7, "seven zones")
	var spawn: String = ""
	for z: String in zones.keys():
		if bool((zones[z] as Dictionary).get("spawn", false)):
			spawn = z
	assert_eq(spawn, "A_QUAY", "the quay is the spawn zone")
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
	var seen_ids: Dictionary = {}
	for d: Dictionary in cfg["doors"]:
		var cost: int = int(d["cost"])
		assert_true(cost >= 1000 and cost <= 2500 and cost % 250 == 0, "%s costs %d (1000..2500, steps of 250)" % [d["id"], cost])
		if seen_ids.has(str(d["id"])):
			assert_eq(str(d.get("link_group", "")), str(seen_ids[str(d["id"])]), "a repeated door id is one link group")
		seen_ids[str(d["id"])] = str(d.get("link_group", ""))
		if bool(d.get("requires_power", false)):
			assert_eq(cost, 2500, "the powered door is the dearest")
	assert_true(seen_ids.size() >= 6, "at least six distinct doors")


func test_wall_buys_perks_and_roster_reference_real_ids() -> void:
	var weapons: Dictionary = GLData.load_json("res://data/gravelight/weapons.json")
	for w: String in cfg["wall_buys"]:
		var found: Dictionary = {}
		for key: String in ["weapons", "melee", "lethal"]:
			var v: Variant = weapons.get(key, {})
			if v is Dictionary and (v as Dictionary).has(w):
				found = (v as Dictionary)[w]
			elif v is Array:
				for row: Dictionary in v:
					if str(row.get("id", "")) == w:
						found = row
		assert_false(found.is_empty(), "wall-buy %s is a weapon" % w)
		if not found.is_empty():
			assert_gt(int(found.get("wall_price", found.get("price", 0))), 0, "wall-buy %s has a wall price" % w)
	var perks: Dictionary = GLData.table("perks")["perks"]
	for pk: String in cfg["perks"]:
		assert_true(perks.has(pk), "perk %s exists" % pk)
	assert_true((cfg["perks"] as Array).has("overclock_cordial"), "Overclock Cordial is on the map")
	assert_true((cfg["perks"] as Array).size() >= 5 and (cfg["perks"] as Array).size() <= 7, "5-7 perks (Ledger Lager T-141)")
	var enemies: Dictionary = GLData.table("enemies")["enemies"]
	for e: String in cfg["roster"]:
		assert_true(enemies.has(e), "enemy %s exists" % e)
		if enemies.has(e):
			var maps: Array = (enemies[e] as Dictionary).get("maps", [])
			assert_true(maps.is_empty() or maps.has("map02_totenhafen"), "enemy %s may spawn on Map 2" % e)
	assert_true((GLData.table("enemies")["status"] as Dictionary).has(str(cfg["tide"]["player_status"])), "the wading status exists")


func test_tide_block_and_rules() -> void:
	var t: Dictionary = cfg["tide"]
	assert_lt(float(t["low_y"]), float(t["high_y"]), "low water is below high water")
	assert_gte(int(t["every_rounds"]), 2, "a tide cycle is at least two rounds")
	assert_gt(float(t["rise_seconds"]), 0.0)
	assert_gt(float(t["fall_seconds"]), 0.0)
	for b: Array in t["flood_boxes"]:
		assert_eq(b.size(), 2, "a flood box is [min, max]")
		for k: int in 3:
			assert_lt(float((b[0] as Array)[k]), float((b[1] as Array)[k]), "flood box min < max")
	for key: String in ["vo_warn", "vo_rising", "vo_falling"]:
		assert_gt((t[key] as Array).size(), 0, "%s has lines" % key)
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for key2: String in ["vo_warn", "vo_rising", "vo_falling"]:
		for id: String in t[key2]:
			assert_true(lines.has(id), "VO line %s exists" % id)
	assert_true(lines.has(str(cfg["power"]["vo_line"])), "the pumps' power line exists")
	assert_true(TideController.is_high_round(33, t) and TideController.is_high_round(3, t), "33 and 3 are high tides")
	assert_false(TideController.is_high_round(34, t) or TideController.is_high_round(1, t), "34 and 1 are not")
	assert_true(TideController.warns_next(32, t), "the forecast at 32")
	assert_false(TideController.warns_next(33, t), "no forecast during the flood")


func test_scene_matches_the_table() -> void:
	assert_gt(_nodes.size(), 50, "the scene loaded")
	var doors: Dictionary = {}
	var perks: int = 0
	var crates: int = 0
	var spawns: Dictionary = {}
	for n: String in _nodes.keys():
		var p: Dictionary = _nodes[n]
		if n.begins_with("Door_"):
			doors[str(p.get("door_id", ""))] = p
		elif n.begins_with("Perk_"):
			perks += 1
		elif n.begins_with("Crate_"):
			crates += 1
		elif n.begins_with("Ground_") or n.begins_with("Catwalk_"):
			spawns[n] = p
	for d: Dictionary in cfg["doors"]:
		var id: String = str(d["id"])
		assert_true(doors.has(id), "door %s is in the scene" % id)
		if doors.has(id):
			assert_eq(int((doors[id] as Dictionary).get("cost", 0)), int(d["cost"]), "door %s costs the same in the scene" % id)
			assert_eq(str((doors[id] as Dictionary).get("opens_zone", "")), str(d["to"]), "door %s opens %s" % [id, d["to"]])
			assert_eq(bool((doors[id] as Dictionary).get("requires_power", false)), bool(d.get("requires_power", false)), "door %s power rule" % id)
	assert_eq(perks, (cfg["perks"] as Array).size(), "perk machines placed")
	assert_eq(crates, 5, "five crate spots")
	for sn: String in (cfg["tide"]["flood_disable"] as Array) + (cfg["tide"]["flood_enable"] as Array):
		assert_true(spawns.has(sn), "tide-switched spawn %s exists" % sn)
	for cn: String in cfg["tide"]["flood_enable"]:
		assert_false(bool((spawns.get(cn, {}) as Dictionary).get("enabled", true)), "%s starts off" % cn)
	assert_true(_nodes.has("Pumpenschalter") and str((_nodes["Pumpenschalter"] as Dictionary).get("config_table", "")) == "map02", "the Pumpenschalter reads map02.json")
	assert_true(_nodes.has("Tide") and _nodes.has("TideWater"), "the tide controller and its water plane")
	assert_true(_nodes.has("Crucible") and bool((_nodes["Crucible"] as Dictionary).get("needs_power", false)), "the Crucible needs the pumps")
	var b: Dictionary = cfg["ballast"]
	assert_true(_nodes.has("BallastHook"), "the crane hook is placed")
	var coffins: int = 0
	for n2: String in _nodes.keys():
		if n2.begins_with("Coffin_"):
			coffins += 1
	assert_eq(coffins, (b["coffin_spots"] as Array).size(), "every coffin spot has a BallastCoffin")
	assert_gte(coffins, int(b["needed"]), "enough coffins for the crane")
	assert_eq(str((_nodes["Pumpenschalter"] as Dictionary).get("requires_flag", "")), str(b["flag"]), "the Pumpenschalter waits for the crane's flag")
	assert_true((GLData.table("enemies")["status"] as Dictionary).has(str(b["carry_status"])), "the ballast carry status exists")
