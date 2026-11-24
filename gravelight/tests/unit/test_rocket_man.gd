extends GutTest
## T-276: Rocket Man, the V2 site's tonic (perks.json "rocket_man", PerkManager explosive_mults / explosive_after /
## blast_jump / v2_immune, Explosion.detonate). The data, the multipliers on the owner's own blast only, the tiers,
## the blast jump's rule, the pinned spot in the deal (the other twelve dealt as before), the cap, the cabinet shape
## and the lore.

const PID: int = 1
const OTHER: int = 2


func before_each() -> void:
	GameState.player_ids = [PID, OTHER]
	GameState.power_on = true
	RoundManager.current_round = 20
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0


func after_each() -> void:
	PerkManager.meta_gate_override = -1
	PerkManager.reset_match()
	GameState.power_on = false
	RoundManager.current_round = 0
	GameState.phase = GameState.Phase.MENU


func _hold(tier: int) -> void:
	PerkManager.grant(PID, &"rocket_man")
	if tier > 1:
		PerkManager.set_tier(PID, &"rocket_man", tier)


func test_the_row() -> void:
	var p: Dictionary = GLData.table("perks")["perks"]["rocket_man"]
	assert_eq(str(p["name"]), "Rocket Man", "named as the owner asked")
	assert_eq(int(p["cost"]), 2500)
	assert_false(bool(p.get("needs_power", true)), "runs on the site's own generator")
	assert_eq(str(p["shape"]), "rocket")
	for k: String in ["explosive_damage_mult", "explosive_radius_mult", "self_explosive_immune", "blast_jump", "blast_jump_up", "blast_jump_m"]:
		assert_true((p["effects"] as Dictionary).has(k), "effect %s" % k)
	assert_true(PerkCap.has_glyph(&"rocket_man"), "the cap draws a glyph")
	assert_true(PerkCap.ENAMEL.has("rocket_man"), "and has its own enamel")
	assert_true(AudioDirector.has_sound("perk_hum_rocket_man") and AudioDirector.has_sound("jingle_rocket_man"), "the hum and the jingle")
	assert_true(GLVO.PERK_TOKENS.has(&"rocket_man"), "a voice token")


func test_footprint_fits_the_dugout() -> void:
	var fp: Vector3 = PerkMachine._shape_footprint("rocket")
	assert_lte(fp.y, MapRocketGen.BUNKER_H - 0.15, "under the dugout's ceiling")
	assert_lte(fp.x, 1.7)
	assert_lte(fp.z, 1.2)
	assert_eq(load("res://gravelight/tools_src/gen_map00.gd").MACHINE_FOOTPRINTS["rocket"], fp, "the generator's copy agrees")


func test_nobody_without_it_gets_the_multipliers() -> void:
	assert_eq(PerkManager.explosive_mults(PID), Vector2.ONE)
	assert_eq(PerkManager.explosive_mults(0), Vector2.ONE, "a blast nobody owns")
	_hold(1)
	assert_eq(PerkManager.explosive_mults(OTHER), Vector2.ONE, "another player's blast is not boosted")


func test_base_multipliers_and_immunity() -> void:
	_hold(1)
	var m: Vector2 = PerkManager.explosive_mults(PID)
	assert_almost_eq(m.x, 1.3, 0.001, "30 % harder")
	assert_almost_eq(m.y, 1.25, 0.001, "25 % further")
	assert_true(bool(PerkManager.stat(PID, "self_explosive_immune", false)), "own blasts cannot hurt")
	assert_false(PerkManager.v2_immune(PID), "the launch still reaches the holder below tier IV")


func test_tiers_add_their_own() -> void:
	_hold(2)
	assert_true(bool(PerkManager.stat(PID, "explosive_stagger", false)), "II staggers")
	assert_almost_eq(float(PerkManager.stat(PID, "explosive_ignite_frac", 0.0)), 0.0, 0.001, "not yet alight")
	_hold(3)
	assert_almost_eq(float(PerkManager.stat(PID, "explosive_ignite_frac", 0.0)), 0.2, 0.001, "III sets alight")
	assert_true(bool(PerkManager.stat(PID, "explosive_stagger", false)), "and keeps II")
	assert_almost_eq(PerkManager.explosive_mults(PID).y, 1.35, 0.001, "III reaches further")
	_hold(4)
	assert_almost_eq(PerkManager.explosive_mults(PID).x, 1.5, 0.001, "IV hits half again as hard")
	assert_true(PerkManager.v2_immune(PID), "IV: the launch cannot hurt")


func test_blast_jump_rule() -> void:
	var fwd: Vector3 = Vector3(0, 0, -1)
	var v: Vector3 = PerkManager.blast_jump_velocity(Vector3(0, 0, 0), Vector3(1.0, 0, 0), 7.5, 5.5, 3.5, fwd)
	assert_almost_eq(v.x, 7.5, 0.001, "thrown away from the blast")
	assert_almost_eq(v.y, 5.5, 0.001, "and up")
	var under: Vector3 = PerkManager.blast_jump_velocity(Vector3(0, 0, 0), Vector3(0.1, 0, 0), 7.5, 5.5, 3.5, fwd)
	assert_almost_eq(under.z, -7.5, 0.001, "a blast right under the feet throws forward")
	assert_eq(PerkManager.blast_jump_velocity(Vector3(0, 0, 0), Vector3(5.0, 0, 0), 7.5, 5.5, 3.5, fwd), Vector3.ZERO, "too far: nothing")
	# the height it gives (on the ground only) never clears the 2.3 m fence colliders the bought doors sit in
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	assert_lt(5.5 * 5.5 / (2.0 * g), 2.3 - 0.5, "the throw's height stays well under a fence")


func test_blast_jump_only_for_the_owner() -> void:
	_hold(1)
	var p: Player = Player.new()
	p.player_id = PID
	add_child_autofree(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert_false(PerkManager.blast_jump(p, p.global_position, OTHER), "somebody else's blast does not throw you")


func test_the_deal_pins_it_and_keeps_the_other_twelve() -> void:
	var rules: Dictionary = GLData.load_json("res://data/gravelight/perk_layout.json")
	var table: Dictionary = GLData.table("perks")["perks"]
	var spots: Array = []
	for sp: Array in load("res://gravelight/tools_src/gen_map00.gd").PERK_SPOTS:
		var f: Dictionary = sp[4]
		spots.append({"id": str(sp[0]), "zone": str(sp[1]), "outdoor": bool(f.get("outdoor", false)), "start": bool(f.get("start", false)), "near": bool(f.get("near", false))})
	var perks: Array = []
	for id: String in rules["maps"]["map00"]["perks"]:
		perks.append({"id": id, "cost": int(table[id]["cost"]), "shape": str(table[id]["shape"])})
	var old_spots: Array = spots.filter(func(s: Dictionary) -> bool: return str(s["id"]) != "launch_bunker")
	var old_perks: Array = perks.filter(func(p: Dictionary) -> bool: return str(p["id"]) != "rocket_man")
	var no_fixed: Dictionary = rules.duplicate(true)
	no_fixed.erase("fixed")
	for seed_v: int in [0, 1, 2, 7, 99, 12345, 4294967295]:
		var deal: Dictionary = PerkShuffle.assign(seed_v, spots, perks, rules)
		var before: Dictionary = PerkShuffle.assign(seed_v, old_spots, old_perks, no_fixed)
		assert_eq(str(deal.get("rocket_man", "")), "launch_bunker", "seed %d: Rocket Man in the dugout" % seed_v)
		var rest: Dictionary = deal.duplicate()
		rest.erase("rocket_man")
		assert_eq(rest, before, "seed %d: the other twelve stand where they stood before T-276" % seed_v)
		assert_true(PerkShuffle.valid(deal, spots, perks, rules), "seed %d: a valid deal" % seed_v)


func test_the_lore() -> void:
	var lore: Dictionary = GLData.load_json("res://data/gravelight/perk_lore.json")["perks"]
	assert_true(lore.has("rocket_man"))
	var r: Dictionary = lore["rocket_man"]
	assert_true(str(r["plan_id"]).begins_with("DMS-VP-"))
	assert_gt((r["panel"] as Array).size(), 5)
	assert_ne(str(r["human"]), "")
	var ml: Dictionary = GLData.load_json("res://data/gravelight/machine_lore.json")["maps"]
	var m0: Dictionary = (ml.get("map00_crossroads", {}) as Dictionary).get("entries", {})
	assert_true(m0.has("perk.rocket_man"), "a maker's plate on Map 0")
