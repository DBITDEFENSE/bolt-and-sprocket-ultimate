extends GutTest
## T-271: Map 0's match systems on the other six maps, the data rows. An arms locker on every map (each row measured
## on its scene file like Map 0's); a rideable horse with a rail where the setting allows (Kaltenbrunn, Thalbach,
## Groom Lake; not the aircraft, the pens or the Moon); the raid-only set piece on Kaltenbrunn (round 40) and
## Totenhafen (round 30) with Map 0's block and behaviour untouched; the opening and the survivors read their file
## by map; three of Map 0's sky-war kinds on Thalbach; Groom Lake's day stays off, and why.
## The running maps are walked by smoke_map_detail and smoke_weapon_locker.

const Spot: GDScript = preload("res://gravelight/tools_src/locker_spot.gd")
const SCENES: Dictionary = {
	"map01": "res://gravelight/maps/map01_kaltenbrunn/map01.tscn",
	"map02": "res://gravelight/maps/map02_totenhafen/map02.tscn",
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn",
	"map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn",
	"map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn",
}
const HORSE_MAPS: Array = ["map01", "map04a", "map04c"]
const NO_HORSE_MAPS: Array = ["map02", "map04b", "map04d"]
const RAID_MAPS: Dictionary = {"map01": 40, "map02": 30}


static func _json(key: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s.json" % key)


static func _v3(a: Variant) -> Vector3:
	var v: Array = a
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


## The zone volumes of a scene that is not in the tree: [{id, lo, hi}].
static func _zones(map: Node) -> Array:
	var out: Array = []
	for n: Node in map.find_children("*", "Node3D", true, false):
		var s: Script = n.get_script() as Script
		if s == null or s.resource_path.get_file() != "zone_volume.gd":
			continue
		var p: Vector3 = Spot.Facing.gxf(n).origin
		var sz: Vector3 = n.get("size")
		out.append({"id": String(n.get("zone_id")), "lo": Vector3(p.x - sz.x * 0.5, p.y - 0.5, p.z - sz.z * 0.5), "hi": Vector3(p.x + sz.x * 0.5, p.y + sz.y, p.z + sz.z * 0.5)})
	return out


static func _zone_at(zones: Array, p: Vector3) -> String:
	for z: Dictionary in zones:
		var lo: Vector3 = z["lo"]
		var hi: Vector3 = z["hi"]
		if p.x >= lo.x and p.x <= hi.x and p.z >= lo.z and p.z <= hi.z and p.y >= lo.y and p.y <= hi.y:
			return str(z["id"])
	return ""


static func _zone_ids(zones: Array) -> Array:
	var out: Array = []
	for z: Dictionary in zones:
		if not out.has(z["id"]):
			out.append(z["id"])
	return out


# ================================================================== the rows against the scene files

func test_every_map_has_an_arms_locker_row() -> void:
	var rows: Dictionary = GLData.load_json("res://data/gravelight/weapon_locker.json")["lockers"]
	for key: String in ["map00", "map01", "map02", "map04a", "map04b", "map04c", "map04d"]:
		assert_true(rows.has(key), "%s has a locker" % key)
		if not rows.has(key):
			continue
		var row: Dictionary = rows[key]
		assert_eq((row["at"] as Array).size(), 3, key)
		assert_true([0.0, 90.0, 180.0, 270.0].has(float(row["yaw"])), "%s: the doors face along an axis" % key)
		assert_gt(str(row.get("where", "")).length(), 30, "%s: a note for people" % key)
	for id: String in ["map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]:
		assert_false(WeaponLocker.row_for(id).is_empty(), "%s finds its row by the map id" % id)


## One load of each scene file: the locker's spot measured as Map 0's is, the horse's row and the raid's block
## against the zones the scene really has.
func test_rows_fit_their_scene_files() -> void:
	var lockers: Dictionary = GLData.load_json("res://data/gravelight/weapon_locker.json")["lockers"]
	for key: String in SCENES:
		var map: Node = (load(SCENES[key]) as PackedScene).instantiate()
		var geo: Dictionary = Spot.index(map)
		var zones: Array = _zones(map)
		var ids: Array = _zone_ids(zones)
		map.free()
		# the locker
		var row: Dictionary = lockers[key]
		var r: Dictionary = Spot.check(geo, _v3(row["at"]), float(row["yaw"]))
		assert_eq(Array(r["problems"]), [], "%s locker: %s" % [key, Spot.line(r)])
		assert_eq(int(r["wall"]), 9, "%s locker: the wall behind the whole back" % key)
		assert_lt(float(r["nav_under"]), 0.12, "%s locker: no navmesh under it" % key)
		assert_gte(float(r["room"]), Spot.ROOM_MIN, "%s locker: room in front" % key)
		assert_gte(float(r["nearest"]), Spot.NEAR_MACHINE, "%s locker: no machine crowds it" % key)
		var d: Dictionary = _json(key)
		# the horse
		if HORSE_MAPS.has(key):
			var h: Dictionary = (d["horses"] as Array)[0]
			for z: Variant in h["zones"]:
				assert_true(ids.has(str(z)), "%s horse: zone %s is one of the map's" % [key, str(z)])
			assert_eq(_zone_at(zones, _v3(h["pos"]) + Vector3.UP * 0.6), str((h["zones"] as Array)[0]), "%s horse: it stands in its first zone" % key)
			assert_eq(_zone_at(zones, _v3(h["rail"]) + Vector3.UP * 0.6), str((h["zones"] as Array)[0]), "%s horse: so does its rail" % key)
		# the raid
		if RAID_MAPS.has(key):
			var b: Dictionary = d["sherman_event"]
			for z2: Variant in (b["shelter_zones"] as Array) + (b["bomb_zones"] as Array):
				assert_true(ids.has(str(z2)), "%s raid: zone %s is one of the map's" % [key, str(z2)])
			for id: String in ids:
				assert_true((b["shelter_zones"] as Array).has(id) or (b["bomb_zones"] as Array).has(id), "%s raid: zone %s is either bombed or a shelter" % [key, id])
			for sp: Variant in b["shelter_points"]:
				assert_ne(_zone_at(zones, _v3(sp) + Vector3.UP * 0.6), "", "%s raid: shelter point %s is in a zone" % [key, str(sp)])
			if b.has("stuka_target"):
				# (in a bombed zone, or outside every zone: T-273, Totenhafen's patrol boat lies out on the water off the quay)
				var tz: String = _zone_at(zones, Vector3(float(b["stuka_target"][0]), 0.6, float(b["stuka_target"][2])))
				assert_true((b["bomb_zones"] as Array).has(tz) or tz == "", "%s raid: the dive bomber's landmark stands in open ground (%s)" % [key, tz])


# ================================================================== the horse

func test_horse_rows() -> void:
	for key: String in HORSE_MAPS:
		var rows: Array = _json(key).get("horses", [])
		assert_eq(rows.size(), 1, "%s has one horse" % key)
		if rows.is_empty():
			continue
		var h: Dictionary = rows[0]
		var pos: Vector3 = _v3(h["pos"])
		var rail: Vector3 = _v3(h["rail"])
		assert_almost_eq(pos.distance_to(rail), 1.25, 0.01, "%s: it stands 1.25 m from its rail, as on Map 0" % key)
		assert_eq(float(h["yaw"]), float(h["rail_yaw"]), "%s: tied square to the rail" % key)
		var fwd: Vector3 = -Basis(Vector3.UP, deg_to_rad(float(h["yaw"]))).z
		assert_gt(fwd.dot((rail - pos).normalized()), 0.99, "%s: it faces its rail" % key)
		assert_eq(pos.y, rail.y, "%s: on the rail's level" % key)
		assert_false((h["zones"] as Array).is_empty(), "%s: it has zones (it never leaves them)" % key)
		assert_eq(str(h.get("look", "")), "noriker", key)
	assert_false(HorseRules.upgrade_rows().is_empty(), "the tack chest has pieces to sell (a rail gets a chest)")
	var m0: Dictionary = (_json("map00")["horses"] as Array)[0]
	assert_eq(_v3(m0["pos"]), Vector3(24.15, 0.0, 37.2), "Map 0's horse stands where it stood")
	assert_eq(_v3(m0["rail"]), Vector3(24.15, 0.0, 35.95))


func test_no_horse_aboard_the_aircraft_in_the_pens_or_on_the_moon() -> void:
	for key: String in NO_HORSE_MAPS:
		assert_true((_json(key).get("horses", []) as Array).is_empty(), "%s has no horse" % key)


func test_the_way_home_uses_the_zones_layers() -> void:
	assert_eq(Horse.layers_for(["YARD", "GROUNDS"], {}, []), 1, "a map without per-zone layers (Map 0): layer 1, as before")
	assert_eq(Horse.layers_for(["B_LAKEBED"], {"A_WRECK": 1, "B_LAKEBED": 2, "C_HANGAR": 3}, []), 0b010, "Groom Lake: the lakebed's own layer")
	assert_eq(Horse.layers_for(["A", "B"], {"A": 1, "B": 2, "C": 3}, [5]), 0b10011, "its zones and the always-walkable layers")
	assert_eq(Horse.layers_for(["NOPE"], {"A": 1}, [5]), 1, "zones the map does not know: layer 1")


# ================================================================== the raid only

func test_raid_only_blocks() -> void:
	for key: String in RAID_MAPS:
		var b: Dictionary = _json(key).get("sherman_event", {})
		assert_false(b.is_empty(), "%s has the block" % key)
		assert_false(ShermanEvent.block_has_tank(b), "%s: no tank" % key)
		assert_eq(int(b["stuka_round"]), int(RAID_MAPS[key]), key)
		assert_false(b.has("route") or b.has("drive_zones") or b.has("barrier"), "%s: nothing of the tank's" % key)
		assert_true(bool(b["shelter_roof"]), "%s: any roof shelters" % key)
		assert_gte((b["shelter_points"] as Array).size(), 2, "%s: places for the bots" % key)
		for z: Variant in b["bomb_zones"]:
			assert_false((b["shelter_zones"] as Array).has(z), "%s: %s is bombed, so no shelter zone" % [key, str(z)])
		var raid: Dictionary = ShermanEvent.merged(ShermanEvent.table(), b, "raid")
		for t: String in ["warn_small", "outside_text"]:
			assert_false(str(raid[t]).contains("INN"), "%s: %s is this map's (\"%s\")" % [key, t, str(raid[t])])
			assert_eq(str(raid[t]), str(raid[t]).to_upper(), "%s: banners are capitals" % key)
		assert_eq(float(raid["radius"]), float(ShermanEvent.table()["raid"]["radius"]), "%s: the bombs are Map 0's bombs" % key)
		assert_eq(float(raid["duration"]), float(ShermanEvent.table()["raid"]["duration"]), key)
		if b.has("stuka_target"):
			assert_false(str(ShermanEvent.merged(ShermanEvent.table(), b, "stuka")["banner_small"]).contains("SHERMAN"), "%s: the dive bomber's banner does not name a tank" % key)
	assert_true(_json("map01")["sherman_event"].has("stuka_target"), "Kaltenbrunn: the dive bomber has a landmark")
	assert_true(_json("map02")["sherman_event"].has("stuka_target"), "Totenhafen: the dive bomber has a landmark (T-273: the moored patrol boat)")
	assert_ne(int(_json("map02")["sherman_event"]["stuka_round"]), int(_json("map02")["exfil"]["round"]), "Totenhafen: not on the campaign's exfil round")
	for row: Dictionary in _json("map01")["round_bosses"]:
		assert_ne(int(row["round"]), int(_json("map01")["sherman_event"]["stuka_round"]), "Kaltenbrunn: not on a horse's round")
	for act: String in ["map04a", "map04b", "map04c", "map04d"]:
		assert_false(_json(act).has("sherman_event"), "%s: none (the acts count their own rounds and have their own set pieces)" % act)
		assert_false(_json(act).has("round_bosses"), act)


func test_map0_block_and_behaviour_are_untouched() -> void:
	var b: Dictionary = _json("map00")["sherman_event"]
	for k: String in ["tank", "raid", "stuka", "shelter_roof", "stuka_target"]:
		assert_false(b.has(k), "Map 0's block has no \"%s\"" % k)
	assert_true(ShermanEvent.block_has_tank(b))
	assert_eq(ShermanEvent.merged(ShermanEvent.table(), b, "raid"), ShermanEvent.table()["raid"], "its raid is sherman.json's, row for row")
	assert_eq(ShermanEvent.merged(ShermanEvent.table(), b, "stuka"), ShermanEvent.table()["stuka"])
	assert_eq(int(b["arrive_round"]), 30)
	assert_eq(int(b["stuka_round"]), 40)


func test_merged_lays_the_maps_rows_over_the_tables() -> void:
	var base: Dictionary = {"raid": {"radius": 6.5, "warn_small": "GET INSIDE THE INN"}}
	var m: Dictionary = ShermanEvent.merged(base, {"raid": {"warn_small": "GET INTO THE PENS"}}, "raid")
	assert_eq(m, {"radius": 6.5, "warn_small": "GET INTO THE PENS"})
	assert_eq(str(base["raid"]["warn_small"]), "GET INSIDE THE INN", "the table itself is not written to")
	assert_eq(ShermanEvent.merged(base, {}, "raid"), base["raid"])
	assert_eq(ShermanEvent.merged(base, {"raid": "nonsense"}, "raid"), base["raid"])
	assert_eq(ShermanEvent.merged({}, {"stuka": {"a": 1}}, "stuka"), {"a": 1})


func test_a_raid_only_event_holds_no_round_for_a_tank() -> void:
	RoundManager.unreserve_round(30)
	RoundManager.unreserve_round(7)
	var e: ShermanEvent = ShermanEvent.new()
	e.map_cfg = {"tank": false, "stuka_round": 7, "bomb_zones": ["A"], "shelter_zones": ["B"], "raid": {"warn_small": "GET UNDER A ROOF"}}
	e.cfg = ShermanEvent.table()
	add_child_autofree(e)
	assert_false(e.has_tank)
	assert_true(RoundManager.is_reserved(7), "the raid's round is its own")
	assert_false(RoundManager.is_reserved(30), "no round is held for a tank that never comes")
	assert_eq(str(e.raid.cfg["warn_small"]), "GET UNDER A ROOF")
	assert_eq(float(e.raid.cfg["countdown"]), float(ShermanEvent.table()["raid"]["countdown"]))
	e._on_round_started(30, false)
	assert_eq(e.phase, ShermanEvent.Phase.IDLE, "round 30 is a round like any other")
	assert_null(e.tank)
	assert_true(e._cmd(PackedStringArray(["drive"])).begins_with("No Sherman"))
	e.force_assist()
	assert_null(e.tank, "nothing can conjure a tank here")
	e._on_round_started(7, false)
	assert_ne(e.phase, ShermanEvent.Phase.STUKA, "no landmark: no dive bomber")
	assert_null(e.plane)
	e._process(0.6)
	assert_eq(e.phase, ShermanEvent.Phase.RAID, "the siren at once")
	assert_eq(e.raid.phase, AirRaid.Phase.WARN)
	RoundManager.unreserve_round(7)


func test_a_tank_event_still_holds_both_rounds() -> void:
	RoundManager.unreserve_round(30)
	RoundManager.unreserve_round(40)
	var e: ShermanEvent = ShermanEvent.new()
	e.map_cfg = _json("map00")["sherman_event"]
	e.cfg = ShermanEvent.table()
	add_child_autofree(e)
	assert_true(e.has_tank)
	assert_true(RoundManager.is_reserved(30) and RoundManager.is_reserved(40), "Map 0: rounds 30 and 40, as before")
	assert_eq(e.raid.cfg, ShermanEvent.table()["raid"])
	RoundManager.unreserve_round(30)
	RoundManager.unreserve_round(40)


func test_a_roof_is_a_shelter_only_where_the_map_says_so() -> void:
	var roof: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(6, 0.2, 6)
	cs.shape = bx
	roof.add_child(cs)
	roof.position = Vector3(500, 3.5, 500)
	add_child_autofree(roof)
	var raid: AirRaid = AirRaid.new()
	add_child_autofree(raid)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var under: Vector3 = Vector3(500, 0, 500)
	var out: Vector3 = Vector3(520, 0, 500)
	assert_true(raid.roof_over(under), "something solid overhead")
	assert_false(raid.roof_over(out), "open sky")
	raid.map_cfg = {"shelter_zones": [], "bomb_zones": [""]}
	assert_false(raid.is_sheltered(under), "Map 0's rule: zones and the inn's box only, a roof alone is nothing")
	assert_true(raid._bomb_ok(under, [""], []), "and a bomb may be laid there")
	raid.map_cfg = {"shelter_zones": [], "bomb_zones": [""], "shelter_roof": true}
	assert_true(raid.is_sheltered(under), "shelter_roof: under the roof you are safe")
	assert_false(raid.is_sheltered(out))
	assert_false(raid._bomb_ok(under, [""], []), "and no bomb is laid on it")
	assert_true(raid._bomb_ok(out, [""], []))
	assert_true(AirRaid.is_sheltered_at(&"TAPROOM", Vector3.ZERO, ["TAPROOM"], []), "the zone rule is unchanged")


# ================================================================== the opening and the survivors, by map

func test_opening_and_survivors_read_their_file_by_map() -> void:
	assert_eq(InnOpening.data_path_for(&"map00_crossroads"), InnOpening.DATA_PATH, "Map 0: the file it always read")
	assert_eq(InnSurvivors.data_path_for(&"map00_crossroads"), InnSurvivors.DATA_PATH)
	assert_eq(InnOpening.data_path_for(&"map04a_thalbach"), "res://data/gravelight/map04a_opening.json")
	assert_eq(InnSurvivors.data_path_for(&"map01_kaltenbrunn"), "res://data/gravelight/map01_survivors.json")
	assert_eq(InnOpening.load_cfg(), GLData.load_json(InnOpening.DATA_PATH), "without a path: Map 0's, as every caller had it")
	assert_eq(str(InnOpening.load_cfg().get("map", "")), "map00_crossroads")
	assert_eq(str(InnSurvivors.load_cfg().get("map", "")), "map00_crossroads")
	# (T-273: Totenhafen has both files now: test_map02_detail checks them)
	for id: StringName in [&"map01_kaltenbrunn", &"map04a_thalbach", &"map04b_kranich", &"map04c_groomlake", &"map04d_mondlicht"]:
		assert_eq(InnOpening.load_cfg(InnOpening.data_path_for(id)), {}, "%s has no opening file yet: no opening" % id)
		assert_eq(InnSurvivors.load_cfg(InnSurvivors.data_path_for(id)), {}, "%s has no survivors file yet" % id)
	var op: InnOpening = InnOpening.new()
	assert_eq(op.data_path, "", "the node's own path is empty: it asks its map")
	op.free()


# ================================================================== Thalbach's sky, Groom Lake's day

func test_thalbach_has_three_of_map0s_sky_kinds() -> void:
	var a: Dictionary = GLData.load_json("res://data/gravelight/map04a_ambience.json")
	var m0: Dictionary = GLData.load_json("res://data/gravelight/map00_ambience.json")
	assert_false(bool(a.get("needs_landscape", true)), "Thalbach has no Landscape node")
	for k: String in ["intensity", "bombers", "fighters", "machine_guns"]:
		assert_eq(a.get(k), m0[k], "\"%s\" is Map 0's, row for row" % k)
	for k2: String in ["artillery", "tracers", "flares", "searchlights", "town", "plane_down", "crows", "dog", "inn_sign", "shutter", "bell", "farm_light", "chimney", "cookoff", "pilot_line", "frost", "gusts"]:
		assert_false(a.has(k2), "\"%s\" needs Map 0's Landscape or is the inn's: not copied" % k2)
	assert_true(a.has("act1") and (a["act1"] as Dictionary).size() >= 10, "its own living world is still there")
	assert_gt(float((m0["bombers"]["altitude"] as Array)[0]), 100.0, "the bombers fly far over the works")
	assert_gt(float((m0["fighters"]["altitude"] as Array)[0]), 30.0, "the fighters clear the hall's roof")


func test_groom_lakes_day_stays_off_and_why() -> void:
	DayCycle.reset_cache()
	var c: Dictionary = DayCycle.config_for("map04c_groomlake")
	assert_false(bool(c.get("enabled", true)), "off")
	# its authored hour is first light (start_hour 6): there the cycle would have put the authored key light out
	# and the sun in at a fiftieth, in round 1
	var f: Dictionary = DayCycle.factors(DayCycle.hour_for_round(1, c), c)
	assert_almost_eq(float(c.get("start_hour", 0.0)), 6.0, 0.001)
	assert_lt(float(f["moon"]), 0.05, "the authored light would be gone at the first round")
	assert_lt(float(f["sun"]), 0.05, "and the sun not yet up")
	for id: String in ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach"]:
		assert_true(bool(DayCycle.config_for(id).get("enabled", false)), "%s keeps its day" % id)
