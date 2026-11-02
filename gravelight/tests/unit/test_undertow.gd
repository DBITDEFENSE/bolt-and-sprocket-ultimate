extends GutTest
## THE UNDERTOW (UPDATE 10 contract C4, DECISIONS T-153): the harpoon's pierce line, the reel's maths, the whirl's
## membership (water vs land, base vs Maelstrom), Maelstrom's chain pick, the data (C4's numbers), the buildable
## and the model's sight markers.

var base: Dictionary
var up: Dictionary


func before_all() -> void:
	var t: Dictionary = GLData.table("weapons")
	base = (t["weapons"] as Dictionary)["undertow"]
	up = (t["upgraded"] as Dictionary)["undertow_maelstrom"]


func test_data_matches_the_contract() -> void:
	var h: Dictionary = base["harpoon"]
	assert_eq(str(base["class"]), "wonder", "a wonder weapon")
	assert_true(bool(base["buildable"]), "buildable")
	assert_eq(int(base["mag"]), 1, "magazine 1")
	assert_eq(int(base["reserve"]), 12, "reserve 12")
	assert_almost_eq(float(base["reload_partial"]), 2.1, 0.001, "three pump strokes, 2.1 s")
	assert_eq(str(base["upgraded"]), "undertow_maelstrom", "the Crucible makes Maelstrom")
	assert_eq(float(h["range"]), 25.0, "the harpoon flies 25 m")
	assert_eq(int(h["pierce"]), 5, "skewers up to 5")
	assert_almost_eq(float(h["reel_s"]), 1.2, 0.001, "reels over 1.2 s")
	assert_eq(float(h["arrive_m"]), 2.0, "they arrive at 2 m")
	assert_eq(float(h["whirl_radius"]), 4.0, "the whirlpool is 4 m")
	assert_eq(float(h["whirl_seconds"]), 6.0, "for 6 s")
	assert_eq(float(h["whirl_dps"]), 40.0, "bosses take 40/s")
	assert_false(bool(h["whirl_land"]), "the base gun needs water")
	var uh: Dictionary = up["harpoon"]
	assert_eq(str(up["base"]), "undertow", "Maelstrom's base")
	assert_eq(int(up["reserve"]), 18, "Maelstrom reserve 18")
	assert_true(bool(uh["whirl_land"]), "Maelstrom whirls on land")
	assert_eq(float(uh["land_radius"]), 3.0, "a 3 m land vortex")
	assert_eq(float(uh["land_seconds"]), 5.0, "for 5 s")
	assert_eq(int(uh["chain"]), 3, "chains 3 times")
	assert_eq(float(uh["chain_radius"]), 6.0, "within 6 m")
	var w: WeaponInstance = WeaponInstance.create(&"undertow")
	assert_not_null(w, "the weapon instance builds")
	assert_eq(String(w.upgrade_id()), "undertow_maelstrom", "upgrade_id")
	var wu: WeaponInstance = WeaponInstance.create(&"undertow_maelstrom")
	assert_true(wu.upgraded, "Maelstrom is an upgraded instance")


func test_pierce_takes_the_line_nearest_first() -> void:
	var o: Vector3 = Vector3.ZERO
	var f: Vector3 = Vector3(0, 0, -1)
	var pts: Array = [
		Vector3(0, 0, -10),      # 0 in line
		Vector3(0.5, 0, -4),     # 1 in line (inside the corridor)
		Vector3(3.0, 0, -6),     # 2 off the line
		Vector3(0, 0, 5),        # 3 behind the shooter
		Vector3(0, 0, -30),      # 4 out of range
		Vector3(-0.4, 0, -14),   # 5 in line
		Vector3(0.2, 0, -18),    # 6 in line
		Vector3(0, 0.3, -21),    # 7 in line
		Vector3(0, 0, -24),      # 8 in line (sixth in line: past the pierce cap)
	]
	var got: Array = Undertow.pierce_line(o, f, pts, 25.0, 0.9, 5)
	assert_eq(got, [1, 0, 5, 6, 7], "five, nearest first, only the line (got %s)" % str(got))
	var walled: Array = Undertow.pierce_line(o, f, pts, 12.0, 0.9, 5)
	assert_eq(walled, [1, 0], "a wall at 12 m stops the harpoon")
	assert_eq(Undertow.pierce_line(o, f, [Vector3(0, 0, -0.1)], 25.0, 0.9, 5), [], "nothing at the muzzle itself")


func test_reel_maths() -> void:
	var start: Vector3 = Vector3(0, 0, -12)
	var shooter: Vector3 = Vector3.ZERO
	var end: Vector3 = Undertow.reel_position(start, shooter, 1.2, 1.2, 2.0)
	assert_almost_eq(end.distance_to(shooter), 2.0, 0.01, "they arrive at 2 m")
	var half: Vector3 = Undertow.reel_position(start, shooter, 0.6, 1.2, 2.0)
	assert_almost_eq(half.z, -7.0, 0.01, "halfway through the reel they are halfway in")
	assert_eq(Undertow.reel_position(Vector3(0, 0, -1.5), shooter, 1.0, 1.2, 2.0), Vector3(0, 0, -1.5), "already close: no reel")
	var v: Vector3 = Undertow.reel_velocity(start, shooter, 1.2, 2.0)
	assert_almost_eq(v.length() * 1.2, 10.0, 0.01, "the reel speed covers the 10 m in 1.2 s")
	assert_gt(v.z, 0.0, "toward the shooter")
	assert_eq(Undertow.reel_velocity(Vector3(0, 0, -2.0), shooter, 1.2, 2.0), Vector3.ZERO, "nothing to reel at 2 m")


func test_whirl_water_and_land() -> void:
	var h: Dictionary = base["harpoon"]
	var uh: Dictionary = up["harpoon"]
	var wet: Dictionary = Undertow.whirl_for(h, true)
	assert_eq(float(wet["radius"]), 4.0, "in water: a 4 m whirl")
	assert_eq(float(wet["seconds"]), 6.0, "6 s")
	assert_true(Undertow.whirl_for(h, false).is_empty(), "the base gun opens nothing on dry ground")
	var land: Dictionary = Undertow.whirl_for(uh, false)
	assert_eq(float(land["radius"]), 3.0, "Maelstrom on land: 3 m")
	assert_true(bool(land["land"]), "a land vortex")
	assert_eq(float(Undertow.whirl_for(uh, true)["radius"]), 4.0, "Maelstrom in water: the full 4 m")
	var c: Vector3 = Vector3(10, -3, 60)
	assert_true(Undertow.in_whirl(Vector3(12, -3, 61), c, 4.0), "inside")
	assert_false(Undertow.in_whirl(Vector3(15, -3, 60), c, 4.0), "outside the radius")
	assert_false(Undertow.in_whirl(Vector3(10, 4, 60), c, 4.0), "the catwalk above is not in the whirl")


func test_chain_pick() -> void:
	var pts: Array = [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(5, 0, 0), Vector3(20, 0, 0)]
	assert_eq(Undertow.chain_pick(Vector3.ZERO, pts, {0: true}, 6.0), 1, "the nearest free one")
	assert_eq(Undertow.chain_pick(Vector3.ZERO, pts, {0: true, 1: true}, 6.0), 2, "then the next")
	assert_eq(Undertow.chain_pick(Vector3.ZERO, pts, {0: true, 1: true, 2: true}, 6.0), -1, "nothing within 6 m")
	# a full Maelstrom chain from the line's last body hops along
	var from: Vector3 = Vector3.ZERO
	var taken: Dictionary = {0: true}
	var hops: int = 0
	for i: int in int((up["harpoon"] as Dictionary)["chain"]):
		var j: int = Undertow.chain_pick(from, pts, taken, 6.0)
		if j < 0:
			break
		taken[j] = true
		from = pts[j]
		hops += 1
	assert_eq(hops, 2, "two hops (the third target is 15 m away)")


func test_buildable_and_parts() -> void:
	assert_eq(BuildablePart.buildable_of(&"undertow_pump"), &"undertow", "the pump belongs to the Undertow")
	assert_eq(BuildablePart.buildable_of(&"undertow_shard"), &"undertow", "the shard too")
	var c: Dictionary = BuildablePart.cfg_of(&"undertow")
	assert_eq(StringName(c["quest"]), &"map02_letzte_fahrt", "Letzte Fahrt seeds the spots")
	assert_eq(str(c["random"]), "ut_parts", "the quest's random key")
	assert_eq((c["parts"] as Array).size(), 3, "three parts")
	for p: Variant in c["parts"]:
		assert_true(BuildablePart.NAMES.has(p), "%s has a name" % p)
	var spots: Dictionary = UndertowParts.cfg().get("spots", {})
	assert_eq((spots.get("undertow_pump", {}) as Dictionary).size(), 2, "two pump spots")
	assert_eq((spots.get("undertow_head", {}) as Dictionary).size(), 2, "two head spots")
	var a: Dictionary = UndertowParts.seeded_pick(spots, 1234)
	var b: Dictionary = UndertowParts.seeded_pick(spots, 1234)
	assert_eq(a, b, "the same seed picks the same spots")
	assert_true((spots["undertow_pump"] as Dictionary).has(a["undertow_pump"]), "the pick is a real spot")
	var bench: Array = UndertowParts.bench_spot({"bench": [47.6, 0.0, 53.0], "bench_yaw": 0.0})
	assert_false(float(bench[0]) > 44.0 and float(bench[0]) < 50.0 and float(bench[2]) > 52.0 and float(bench[2]) < 57.0,
		"a bench spot inside the solid crane office is moved out")


func test_model_has_sights_and_parts() -> void:
	for up_v: bool in [false, true]:
		var m: Node3D = autofree(WeaponModels.build(&"undertow", up_v)) as Node3D
		assert_not_null(m, "the model builds")
		if m == null:
			continue
		var sp: Node3D = m.find_child("SightPoint", true, false) as Node3D
		var fs: Node3D = m.find_child("FrontSight", true, false) as Node3D
		assert_true(sp != null and fs != null, "sight markers")
		if sp != null and fs != null:
			assert_almost_eq(sp.position.y, fs.position.y, 0.002, "the sight line is level")
			assert_almost_eq(sp.position.x, 0.0, 0.001, "centred")
		for n: String in ["Harpoon", "Pump", "Gauge", "Glow", "Muzzle"]:
			assert_not_null(m.find_child(n, true, false), "part %s" % n)
		assert_eq((m.find_child("Glow", true, false) as Node3D).visible, up_v, "Maelstrom's glow only on the upgrade")
		assert_eq(str(m.get_meta("reload", "")), "undertow", "the pump reload")
	assert_true(WeaponModels.known_ids().has("undertow"), "a known model id")
