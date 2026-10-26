extends GutTest
## Bots on Map 4's four acts (UPDATE 07, T-115): each act has its training loops (routes_map04a..d.json) and every
## authored point sits on that act's baked navmesh; the loops name doors the act really has; the player-bot plans
## (player_bot.json "plans") buy doors, guns and perks the act really sells, train on loops that exist and point
## their egg block at KÜNDIGUNG from the act's first door; the map key keeps the act letter; the power plan never
## routes through the Moon's vacuum yard.

const EDGES: GDScript = preload("res://gravelight/tests/unit/test_map02_edges.gd")
const SCENES: Dictionary = {
	"map04a": "res://gravelight/maps/map04_fernflug/map04a.tscn", "map04b": "res://gravelight/maps/map04_fernflug/map04b.tscn",
	"map04c": "res://gravelight/maps/map04_fernflug/map04c.tscn", "map04d": "res://gravelight/maps/map04_fernflug/map04d.tscn"}
const MAP_IDS: Dictionary = {"map04a": "map04a_thalbach", "map04b": "map04b_kranich", "map04c": "map04c_groomlake", "map04d": "map04d_mondlicht"}


func _map_json(key: String) -> Dictionary:
	return GLData.load_json("res://data/gravelight/%s.json" % key)


func _ids(rows: Variant, k: String = "id") -> Array:
	var out: Array = []
	for r: Variant in (rows if rows is Array else []):
		out.append(str(r) if r is String else str((r as Dictionary).get(k, "")))
	return out


func test_map_key_keeps_the_act_letter() -> void:
	assert_eq(TrainingRoute.map_key_of("map04a_thalbach"), "map04a")
	assert_eq(TrainingRoute.map_key_of("map04d_mondlicht"), "map04d")
	assert_eq(TrainingRoute.map_key_of("map04d"), "map04d")
	assert_eq(TrainingRoute.map_key_of("map02_totenhafen"), "map02", "the older maps keep their five-letter key")
	assert_eq(TrainingRoute.map_key_of("map00"), "map00")


func test_every_act_has_loops_on_its_own_navmesh() -> void:
	var checked: int = 0
	for key: String in SCENES.keys():
		var routes: Array[TrainingRoute] = TrainingRoute.all_for_map(str(MAP_IDS[key]))
		assert_gt(routes.size(), 1, "%s has training loops" % key)
		var polys: Array = EDGES._nav_polys(EDGES._state_nodes(str(SCENES[key])))
		assert_gt(polys.size(), 50, "%s carries its baked navmeshes" % key)
		var data: Dictionary = GLData.load_json("res://data/gravelight/ai/routes_%s.json" % key)
		var doors: Array = _ids(_map_json(key).get("doors", []))
		for r: Dictionary in data.get("routes", []):
			assert_true(str(r["id"]).begins_with(key + "_"), "%s is named after its act" % r["id"])
			for pt: Array in r.get("points", []):
				var p: Vector3 = Vector3(float(pt[0]), float(pt[1]), float(pt[2]))
				assert_true(EDGES._on_navmesh(p, polys, 1.2, 0.6), "%s point %s is on the navmesh" % [r["id"], p])
				checked += 1
			for d: Variant in r.get("requires_doors", []):
				assert_true(doors.has(str(d)), "%s needs a door the act has (%s)" % [r["id"], str(d)])
	assert_gt(checked, 50, "route points were checked")


func test_plans_buy_what_the_acts_sell() -> void:
	var plans: Dictionary = BotAIData.table("player_bot").get("plans", {})
	for key: String in SCENES.keys():
		assert_true(plans.has(key), "a plan for " + key)
		if not plans.has(key):
			continue
		var plan: Dictionary = plans[key]
		var mj: Dictionary = _map_json(key)
		var doors: Array = _ids(mj.get("doors", []))
		var guns: Array = _ids(mj.get("wall_buys", []), "weapon")
		var perks: Array = _ids(mj.get("perks", []))
		var routes: Array = []
		for r: TrainingRoute in TrainingRoute.all_for_map(str(MAP_IDS[key])):
			routes.append(r.id)
		var n_doors: int = 0
		for st: Dictionary in plan.get("steps", []):
			if st.has("door"):
				assert_true(doors.has(str(st["door"])), "%s: door %s exists" % [key, st["door"]])
				n_doors += 1
			if st.has("gun"):
				assert_true(guns.has(str(st["gun"])), "%s: %s is on a wall" % [key, st["gun"]])
			if st.has("perk"):
				assert_true(perks.has(str(st["perk"])), "%s: %s is on the map" % [key, st["perk"]])
			if st.has("power"):
				assert_true(mj.has("power") or key == "map04b", "%s: a power step on a map with a switch" % key)
		assert_gt(n_doors, 2, "%s: the plan opens the act's rooms" % key)
		assert_false((plan.get("train_at", []) as Array).is_empty(), "%s: train_at" % key)
		for t: Variant in plan.get("train_at", []):
			assert_true(routes.has(str(t)), "%s: trains on a loop that exists (%s)" % [key, str(t)])
		var egg: Dictionary = plan.get("egg", {})
		assert_eq(str(egg.get("quest", "")), "map04_kuendigung", "%s: the egg block names KÜNDIGUNG" % key)
		var after: Array = egg.get("after", [])
		assert_true(after.size() == 1 and str((after[0] as Dictionary).get("door", "")) == str((plan["steps"] as Array).filter(func(x: Dictionary) -> bool: return x.has("door"))[0]["door"]),
				"%s: the egg starts after the act's first door" % key)
	assert_true(plans.has("map04c") and plans.has("map04d"), "the perks of the late acts")
	var late: Array = []
	for st: Dictionary in (plans["map04c"] as Dictionary).get("steps", []) + (plans["map04d"] as Dictionary).get("steps", []):
		if st.has("perk"):
			late.append(str(st["perk"]))
	assert_true(late.has("skyhook_sekt") and late.has("magpie_mead"), "the bots drink the two new perks where they stand")


func test_the_power_plan_never_crosses_the_vacuum_yard() -> void:
	var eco: Dictionary = BotAIData.table("economy")
	var avoid: Array = (eco.get("power", {}) as Dictionary).get("plan_avoid_zones", [])
	assert_true(avoid.has("C_YARD"), "economy.json power.plan_avoid_zones names the Moon's yard")
	var d: Dictionary = _map_json("map04d")
	assert_true(d.has("vacuum") or str(d).contains("C_YARD"), "the yard is a zone of Act IV")
