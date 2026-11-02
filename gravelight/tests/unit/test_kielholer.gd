extends GutTest
## The drowned of Totenhafen (UPDATE 10 contract C2 "Kielholer", C5; DECISIONS T-153): the data (enemies.json,
## bosses/map02.json, the kits), the controller's tagging shares and caps, the water edges, the grab's break rules
## and damage, the diver's helmet, and DER KIELHOLER's pure state-machine rules (submerge thresholds, the dock choice,
## the tide speed, the helmet break, the fail-safe, the chain sweep's line, HP by players and bots alone).

var tb: Dictionary
var b: Dictionary
var kc: Dictionary
var kd: Dictionary
var m2: Dictionary


func before_all() -> void:
	tb = GLData.table("bosses/map02")
	b = tb["bosses"]["der_kielholer"]
	kc = GLData.table("enemies")["enemies"]["kielholer"]
	kd = GLData.table("enemies")["enemies"]["kielholer_diver"]
	m2 = GLData.load_json("res://data/gravelight/map02.json")


# ------------------------------------------------------------------ data

func test_data_contract() -> void:
	assert_eq(str(b["boss_id"]), "der_kielholer", "the boss id (C5)")
	assert_eq(float(tb["failsafe_seconds"]), 420.0, "fail-safe 420 s (C5)")
	assert_eq(int(tb["round"]), 20, "standalone round 20")
	assert_eq(int(tb["campaign_round"]), 40, "campaign round 40")
	assert_eq(float(b["chain_sweep"]["telegraph"]), 1.2, "the sweep's 1.2 s telegraph (design 4)")
	assert_eq(float(b["chain_sweep"]["range"]), 9.0, "a 9 m line")
	assert_eq(float(b["chain_sweep"]["pull_m"]), 4.0, "pulls 4 m")
	assert_eq(float(b["tide_speed_mult"]), 1.3, "x1.3 at high tide")
	assert_eq(float(b["submerge_every"]), 0.25, "submerges every 25%")
	assert_eq(float(b["helmet_break_fraction"]), 0.15, "the glass breaks after 15%")
	assert_eq(float(b["limb_mult"]["helmet_glass"]), 1.0, "the glass x1.0")
	assert_eq(float(b["limb_mult"]["helmet_glow"]), 2.0, "the glow x2.0")
	assert_eq(float(b["limb_mult"]["back"]), 1.3, "the back x1.3")
	assert_true((tb["bots_alone"] as Dictionary).get("enabled", false), "bots-alone scaling on")
	assert_eq(str(kc["kind"]), "ganger_variant", "kielholer is a tagged kit")
	assert_eq(str(kd["kind"]), "ganger_variant", "kielholer_diver is a tagged kit")
	assert_eq(float(kc["pull_mps"]), 1.2, "pulls at 1.2 m/s (C2)")
	assert_eq(float(kc["arm_break_damage"]), 60.0, "60 damage to arm_grab frees (C2)")
	assert_eq(float(kc["grab_range"]), 2.0, "grabs within 2 m (C2)")
	assert_true((GLData.table("enemies")["status"] as Dictionary).has("kielholer_grab"), "the held status exists")
	var kits: Dictionary = GLData.table("anim")["kits"]
	assert_true(kits.has("drowned") and kits.has("drowned_diver"), "the drowned kits exist")
	assert_eq(str(kits["drowned_diver"]["gear"].keys()[0]), "diver_helmet", "the diver wears the brass helmet")
	assert_eq(str(GLData.table("anim")["emerge_by_spawn_prefix"]["map02_totenhafen"]["Surface_"]), "water", "surface points rise out of the water")
	for k: String in ["dock1", "dock2", "dock3"]:
		assert_true((m2["letzte_fahrt"]["boss_docks"] as Dictionary).has(k), "boss dock %s" % k)


func test_kits_build() -> void:
	for kit: String in ["drowned", "drowned_diver"]:
		var mesh: ArrayMesh = ZombieBody.build_skinned(kit, "medium", false)
		assert_not_null(mesh, "%s builds" % kit)
		assert_eq(mesh.get_surface_count(), 2, "%s: skin + kit surfaces" % kit)
	var g: Array = ZombieBody.gear_mesh("diver_helmet")
	assert_eq(str(g[0]), "Head", "the helmet rides the head")
	assert_not_null(g[1], "the helmet mesh")
	assert_eq(str(ZombieBody.gear_mesh("weed")[0]), "Chest", "the weed hangs off the shoulders")
	assert_false(ZombieBody.KITS.has("drowned"), "never rolled from variants_by_map (tagged only)")


# ------------------------------------------------------------------ the controller

func test_tagging_rules() -> void:
	assert_false(KielholerController.should_tag(true, true, false, 0.0, 0, 6, 0.35), "nothing while dry")
	assert_true(KielholerController.should_tag(true, false, true, 0.99, 0, 6, 0.35), "a surface riser always while flooded")
	assert_true(KielholerController.should_tag(false, true, true, 0.2, 0, 6, 0.35), "a Pen Hall riser under the share")
	assert_false(KielholerController.should_tag(false, true, true, 0.5, 0, 6, 0.35), "a Pen Hall riser over the share")
	assert_false(KielholerController.should_tag(false, false, true, 0.0, 0, 6, 0.35), "elsewhere: no")
	assert_false(KielholerController.should_tag(true, true, true, 0.0, 6, 6, 0.35), "the cap holds")
	var c: Dictionary = m2["kielholer"]
	assert_gt(KielholerController.cap_for(&"spring", c), KielholerController.cap_for(&"high", c), "most on a spring tide")
	assert_eq(KielholerController.kind_for(0.1, 0.25), "kielholer_diver", "a diver under the share")
	assert_eq(KielholerController.kind_for(0.9, 0.25), "kielholer", "else a Kielholer")
	assert_eq(KielholerController.standalone_round(tb, false), 20, "standalone round")
	assert_eq(KielholerController.standalone_round(tb, true), 40, "campaign round")


func test_water_edges() -> void:
	# a player in the middle of pier 2 (x 14..20) is pulled to the nearer side
	var e: Vector3 = KielholerController.edge_point(Vector3(15.0, 0, 60.0))
	assert_almost_eq(e.x, 14.0, 0.01, "pier 2's west edge")
	assert_almost_eq(e.z, 60.0, 0.01, "straight across")
	assert_almost_eq(KielholerController.edge_distance(Vector3(15.0, 0, 60.0)), 1.0, 0.01, "1 m from the edge")
	var n: Vector3 = KielholerController.edge_point(Vector3(5.0, 0, 35.0))
	assert_almost_eq(n.z, 38.0, 0.01, "the north apron pulls toward the dock (z 38)")
	for p: Variant in m2["kielholer"]["surface_points"]:
		var a: Array = p
		assert_lte(KielholerController.edge_distance(Vector3(float(a[0]), 0, float(a[2]))), 1.05, "surface point %s is at a water edge" % str(a))
	assert_gt(KielholerController.hold_dps(0.5, kc), KielholerController.hold_dps(4.0, kc), "the edge hurts more")
	assert_lt(KielholerController.hold_dps(0.5, kc) * float(kc["max_hold"]), 100.0, "a full hold at the edge never kills a 100 HP player by itself")


func test_grab_break_rules() -> void:
	var st: Dictionary = {"pid": 2, "t": 0.0}
	KielholerController.grab_hit(st, 30.0, &"torso", 3, &"bullet")
	assert_eq(KielholerController.grab_breaks(st, kc), "", "15 team damage off the arm: still held")
	KielholerController.grab_hit(st, 59.0, &"arm_grab", 3, &"bullet")
	assert_eq(KielholerController.grab_breaks(st, kc), "", "59 on the arm: still held")
	KielholerController.grab_hit(st, 2.0, &"arm_grab", 0, &"explosive")
	assert_eq(KielholerController.grab_breaks(st, kc), "arm", "60 on the arm from anyone frees him")
	var s2: Dictionary = {"pid": 2, "t": 0.0}
	KielholerController.grab_hit(s2, 40.0, &"torso", 2, &"melee")
	assert_eq(KielholerController.grab_breaks(s2, kc), "melee", "the held player's melee frees him")
	var s3: Dictionary = {"pid": 2, "t": 0.0}
	KielholerController.grab_hit(s3, 300.0, &"torso", 4, &"bullet")
	assert_eq(KielholerController.grab_breaks(s3, kc), "team", "teammates' damage (half off the arm) frees him")
	var s4: Dictionary = {"pid": 2, "t": float(kc["max_hold"])}
	assert_eq(KielholerController.grab_breaks(s4, kc), "time", "the hold times out")
	var s5: Dictionary = {"pid": 2, "t": 0.0}
	KielholerController.grab_hit(s5, 500.0, &"torso", 2, &"bullet")
	assert_eq(KielholerController.grab_breaks(s5, kc), "", "the held player's own gunfire (not melee) doesn't count as team")


func test_helmet_threshold() -> void:
	assert_almost_eq(KielholerController.helmet_threshold(1000.0, kd), 1000.0 * float(kd["helmet_break_fraction"]), 0.01, "the diver's glass threshold")
	assert_lt(float(kd["helmet_mult"]), 1.0, "the helmet soaks before it breaks")
	assert_eq(float(kd["glow_mult"]), 2.0, "the glow x2.0 (C2)")


# ------------------------------------------------------------------ the boss

func test_submerge_thresholds() -> void:
	var every: float = float(b["submerge_every"])
	assert_false(Kielholer.submerge_due(0.9, 0, every), "90%: not yet")
	assert_true(Kielholer.submerge_due(0.75, 0, every), "75%: the first dive")
	assert_false(Kielholer.submerge_due(0.7, 1, every), "70% after one dive: not yet")
	assert_true(Kielholer.submerge_due(0.5, 1, every), "50%: the second")
	assert_true(Kielholer.submerge_due(0.2, 2, every), "20%: the third (catches up)")
	assert_false(Kielholer.submerge_due(0.01, 3, every), "never a fourth dive at zero")
	var dives: int = 0
	var f: float = 1.0
	while f > 0.0:
		f -= 0.01
		if Kielholer.submerge_due(f, dives, every):
			dives += 1
	assert_eq(dives, 3, "three dives over the fight")


func test_dock_choice() -> void:
	var docks: Dictionary = m2["letzte_fahrt"]["boss_docks"]
	for i: int in 20:
		var d: String = Kielholer.pick_dock(docks, "dock2", Vector3.ZERO, false, float(i) / 20.0)
		assert_ne(d, "dock2", "never the dock he left")
		assert_true(docks.has(d), "a real dock")
	var near: String = Kielholer.pick_dock(docks, "dock2", Vector3(-8.0, 0, 60.0), true, 0.0)
	assert_eq(near, "dock1", "high tide: the dock nearest his target")
	assert_eq(Kielholer.pick_dock({"a": [0, 0, 0]}, "a", Vector3.ZERO, false, 0.5), "a", "one dock: stays")


func test_tide_speed_and_helmet() -> void:
	assert_eq(Kielholer.tide_mult(&"low", b), 1.0, "low: normal speed")
	assert_eq(Kielholer.tide_mult(&"half", b), 1.0, "half: normal")
	assert_eq(Kielholer.tide_mult(&"high", b), 1.3, "high: x1.3")
	assert_eq(Kielholer.tide_mult(&"spring", b), 1.3, "spring: x1.3")
	assert_false(Kielholer.helmet_breaks(1000.0, 10000.0, b), "10%: the glass holds")
	assert_true(Kielholer.helmet_breaks(1500.0, 10000.0, b), "15%: it breaks")


func test_failsafe_and_hp() -> void:
	assert_false(Kielholer.failsafe_due(419.0, tb), "419 s: still fighting")
	assert_true(Kielholer.failsafe_due(420.0, tb), "420 s: he dives and the key floats up")
	var base: float = float(b["hp_base"])
	assert_eq(Kielholer.boss_hp(1, false, tb), base, "solo HP")
	assert_almost_eq(Kielholer.boss_hp(4, false, tb), base * 3.25, 0.5, "4 players: x3.25 (HOMAGE_BOSSES 3.1)")
	assert_almost_eq(Kielholer.boss_hp(4, true, tb), base * 3.25 * 0.5, 0.5, "bots alone: half")


func test_sweep_line() -> void:
	var o: Vector3 = Vector3.ZERO
	var f: Vector3 = Vector3(0, 0, -1)
	assert_true(Kielholer.sweep_hits(o, f, Vector3(0, 0, -8.5), 9.0, 1.1), "8.5 m down the line: hit")
	assert_false(Kielholer.sweep_hits(o, f, Vector3(0, 0, -9.5), 9.0, 1.1), "beyond 9 m: missed")
	assert_true(Kielholer.sweep_hits(o, f, Vector3(1.0, 0, -4.0), 9.0, 1.1), "1 m off the line: hit")
	assert_false(Kielholer.sweep_hits(o, f, Vector3(1.5, 0, -4.0), 9.0, 1.1), "1.5 m off: missed")
	assert_false(Kielholer.sweep_hits(o, f, Vector3(0, 0, 3.0), 9.0, 1.1), "behind him: missed")


func test_weak_point_damage() -> void:
	# melee / wonder hits on the new weak points take the boss multiplier too (HomageBoss.WEAK_POINT_LIMBS)
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"back", &"melee", 1.3, 1.0, false), 130.0, 0.01, "a knife in the back x1.3")
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"helmet_glass", &"wonder", 2.0, 1.0, false), 200.0, 0.01, "a wonder hit on the glow x2.0")
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"helmet_glass", &"bullet", 2.0, 1.0, false), 200.0, 0.01, "a bullet on the glow x2.0 (no weapon table entry)")
	assert_almost_eq(HomageBoss.boss_damage(100.0, &"torso", &"bullet", 1.0, 0.0, false), 0.0, 0.01, "under water: nothing lands")
