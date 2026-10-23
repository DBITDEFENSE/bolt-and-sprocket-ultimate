extends GutTest
## The Update 03 bot brain (T-055): the utility AI picks the expected action for hand-built scenarios, revive
## claims are exclusive, spending follows its priorities, the never-touch rule, no Kar98k after round 10, the
## pistol-trap fix, threat, grenades, roles, orders, skills and the data tables themselves. Pure rules only
## (bot_utility.gd, bot_blackboard.gd, bot_economy.gd, bot_aim.gd, bot_perception.gd, bot_squad.gd).

var acts: Dictionary
var curves: Dictionary
var eco: Dictionary
var combat: Dictionary


func before_all() -> void:
	BotAIData.reload()
	acts = BotAIData.table("actions")
	curves = BotAIData.table("curves")
	eco = BotAIData.table("economy")
	combat = BotAIData.table("combat")


## A neutral context: a standing bot following the human mid-round with a full Thompson, nothing close.
func _ctx(over: Dictionary = {}) -> Dictionary:
	var c: Dictionary = {"hp": 1.0, "mag": 1.0, "mag_reserve": 0.0, "ammo": 0.9, "any_ammo": 1.0, "armed": 1.0, "reloading": 0.0,
		"pressure": 0.0, "near": 1.0, "n5": 0.0, "n10": 0.0, "known": 0.0, "sprinter_close": 0.0, "has_target": 0.0,
		"revive_mine": 0.0, "revive_bleed": 1.0, "revive_blocked": 0.0, "revive_path": 0.2, "revive_speed": 1.0, "reviving": 0.0,
		"cover_need": 0.0, "leader_far": 0.1, "is_leader": 0.0, "squad_far": 0.1, "break": 0.0, "round": 0.3, "loop": 1.0,
		"hold_spot": 0.0, "repair_task": 0.0, "buy_task": 0.0, "crate_task": 0.0, "resupply_task": 0.0, "powerup_task": 0.0, "trap_task": 0.0,
		"chatter_ok": 0.0, "objective": 0.0, "order": 0.0, "escort": 0.0, "escort_far": 0.0, "stand_fast": 0.0, "ee_task": 0.0, "mark_order": 0.0}
	c.merge(over, true)
	return c


func _best(ctx: Dictionary, current: String = "follow", mods: Dictionary = {}) -> String:
	var s: Dictionary = BotUtility.score_all(acts, ctx, curves, mods)
	return str(BotUtility.choose(s, current, float(acts.get("hysteresis", 0.1)))[0])


# ---------------------------------------------------------------- the brief's scenarios (section 9)

func test_low_ammo_and_low_threat_reloads() -> void:
	var c: Dictionary = _ctx({"mag": 0.1, "mag_reserve": 1.0, "pressure": 0.05, "has_target": 1.0, "known": 0.1, "near": 0.8})
	assert_eq(_best(c, "fight"), "reload", "a nearly empty mag, a far zombie: reload safely (even while fighting)")
	c["pressure"] = 0.8
	c["sprinter_close"] = 1.0
	assert_ne(_best(c, "fight"), "reload", "never reload with a sprinter in its face")


func test_downed_player_with_a_sprinter_near_is_covered_first_then_revived() -> void:
	var c: Dictionary = _ctx({"revive_mine": 1.0, "revive_blocked": 1.0, "cover_need": 1.0, "revive_bleed": 0.8, "pressure": 0.4, "has_target": 1.0, "known": 0.3})
	assert_eq(_best(c, "fight"), "cover", "a sprinter near the downed one, time left: cover first")
	c["revive_blocked"] = 0.0
	c["cover_need"] = 0.0
	assert_eq(_best(c, "cover"), "revive", "the sprinter is dealt with: revive")
	assert_eq(_best(c, "fight"), "revive", "revive beats the fight it was in, hysteresis and all")


func test_last_chance_revive_goes_anyway() -> void:
	# under 8 s the brain clears revive_blocked (BotBrain.context); the score then wins even under pressure
	var c: Dictionary = _ctx({"revive_mine": 1.0, "revive_blocked": 0.0, "revive_bleed": 0.12, "pressure": 0.9, "has_target": 1.0, "known": 0.7})
	assert_eq(_best(c, "fight"), "revive")


func test_high_threat_with_a_loop_trains() -> void:
	var c: Dictionary = _ctx({"pressure": 0.75, "known": 0.7, "n10": 0.6, "has_target": 1.0, "round": 0.4, "hp": 0.8, "mag": 0.6, "loop": 1.0})
	assert_eq(_best(c, "fight"), "train")
	c["loop"] = 0.0
	assert_ne(_best(c, "fight"), "train", "no loop, no training")


func test_swarmed_hurt_and_dry_retreats() -> void:
	var c: Dictionary = _ctx({"pressure": 1.0, "known": 0.6, "has_target": 1.0, "hp": 0.25, "mag": 0.0, "mag_reserve": 1.0, "loop": 0.0, "sprinter_close": 1.0})
	assert_eq(_best(c, "fight"), "retreat")


func test_quiet_break_repairs_and_shops() -> void:
	var c: Dictionary = _ctx({"break": 1.0, "repair_task": 0.8})
	assert_eq(_best(c), "repair")
	c["repair_task"] = 0.0
	c["buy_task"] = 0.9
	assert_eq(_best(c), "buy")


func test_orders_boost_their_action_and_save_scrip_stops_buying() -> void:
	var c: Dictionary = _ctx({"hold_spot": 1.0, "has_target": 1.0, "pressure": 0.4})
	var m: Dictionary = BotUtility.order_mods(acts, "hold", 1.0)
	assert_eq(_best(c, "fight", m), "hold")
	var c2: Dictionary = _ctx({"break": 1.0, "buy_task": 0.9})
	assert_eq(_best(c2, "follow", BotUtility.order_mods(acts, "save_scrip", 1.0)), "follow", "Save Scrip: no shopping")
	assert_eq(BotUtility.order_strength(30.0, 60.0), 1.0)
	assert_eq(BotUtility.order_strength(61.0, 60.0), 0.0, "an order decays after 60 s")


func test_an_order_never_revives_a_gated_action() -> void:
	var s: Dictionary = BotUtility.score_all(acts, _ctx({"hold_spot": 0.0}), curves, BotUtility.order_mods(acts, "hold", 1.0))
	assert_eq(float(s["hold"]), 0.0, "no hold spot: the boost doesn't apply")


func test_hysteresis_keeps_the_running_action() -> void:
	var s: Dictionary = {"fight": 0.6, "train": 0.65}
	assert_eq(str(BotUtility.choose(s, "fight", 0.1)[0]), "fight")
	assert_eq(str(BotUtility.choose(s, "follow", 0.1)[0]), "train")


# ---------------------------------------------------------------- curves and data

func test_curves() -> void:
	assert_almost_eq(BotUtility.curve("identity", 0.3, curves), 0.3, 0.001)
	assert_almost_eq(BotUtility.curve("inverse", 0.3, curves), 0.7, 0.001)
	assert_eq(BotUtility.curve("gate", 0.4, curves), 0.0)
	assert_eq(BotUtility.curve("gate", 0.6, curves), 1.0)
	assert_almost_eq(BotUtility.curve({"type": "points", "points": [[0.0, 0.0], [1.0, 1.0]]}, 0.25), 0.25, 0.001)
	assert_almost_eq(BotUtility.curve({"type": "logistic", "m": 10.0, "c": 0.5, "k": 1.0, "b": 0.0}, 0.5), 0.5, 0.001)
	assert_almost_eq(BotUtility.curve("rising", 0.5, curves), 0.25, 0.001)
	assert_eq(BotUtility.curve("rising", 2.0, curves), 1.0, "inputs clamp to 0..1")


func test_every_action_uses_known_curves_and_inputs() -> void:
	var inputs: Dictionary = acts.get("_inputs", {})
	for id: Variant in (acts["actions"] as Dictionary).keys():
		for c: Variant in (acts["actions"][id] as Dictionary).get("considerations", []):
			var cd: Dictionary = c
			assert_true(inputs.has(str(cd["input"])), "%s: input %s is documented" % [id, cd["input"]])
			if cd["curve"] is String:
				assert_true(curves.has(str(cd["curve"])), "%s: curve %s exists" % [id, cd["curve"]])
	for o: Variant in (acts.get("orders", {}) as Dictionary).keys():
		if str(o) == "_doc":
			continue
		assert_true(BotConfig.order_ids(BotConfig.cfg()).has(StringName(str(o))), "order %s is on the wheel" % o)


func test_the_context_covers_every_input() -> void:
	var c: Dictionary = _ctx()
	for k: Variant in (acts.get("_inputs", {}) as Dictionary).keys():
		assert_true(c.has(str(k)), "the test context has %s" % k)


func test_personalities_exist_and_name_real_actions() -> void:
	for ch: String in ["dutch", "peg", "deacon", "wren", "bolt", "vendelin", "jakub"]:
		var p: Dictionary = BotAIData.table("personality_" + ch)
		assert_false(p.is_empty(), "personality_%s.json" % ch)
		for a: Variant in (p.get("actions", {}) as Dictionary).keys():
			assert_true((acts["actions"] as Dictionary).has(str(a)), "%s: action %s" % [ch, a])
	assert_gt(float(BotAIData.personality("deacon")["actions"]["revive"]), 1.0, "Deacon revives first")
	assert_lt(float(BotAIData.personality("dutch")["actions"]["retreat"]), 1.0, "Dutch is slow to retreat")
	assert_eq(float(BotAIData.personality("jakub")["actions"]["buy"]), 0.0, "Jakub refuses to shop (perks)")
	assert_gt(float(BotAIData.personality("wren")["aim"]["class_pref"]["rifle"]), 1.0, "Wren prefers rifles")


func test_counters_have_defaults_and_future_enemies() -> void:
	var g: Dictionary = BotAIData.counter(&"ganger")
	assert_true(g.has("keep_distance_m") and g.has("never_melee"))
	assert_true(bool(BotAIData.counter(&"cousin_alix")["never_melee"]))
	assert_gte(float(BotAIData.counter(&"cousin_alix")["keep_distance_m"]), 2.0, "never within 2 m of Alix")
	assert_true(bool(BotAIData.counter(&"cousin_reach")["break_grab"]), "shoot the Reach's wrists when she grabs")
	assert_true(bool(BotAIData.counter(&"cousin_hammer")["focus_when_vulnerable"]), "shoot the Hammer while the mallet flies")
	for future: String in ["paul", "slender", "frostbiss", "bergwacht", "treibstoff_ganger"]:
		assert_true((BotAIData.table("ai_counters") as Dictionary).has(future), "counters ready for %s" % future)
	assert_false(BotAIData.counter(&"nobody_yet").is_empty(), "an unknown enemy gets the defaults")


func test_skills_recruit_to_elite_and_old_names() -> void:
	var c: Dictionary = BotConfig.cfg()
	var r: Dictionary = BotConfig.skill(c, "recruit")
	var e: Dictionary = BotConfig.skill(c, "elite")
	assert_gt(float(r["reaction_s"][0]), float(e["reaction_s"][0]))
	assert_lte(float(e["reaction_s"][0]), 0.15 + 0.001, "reaction 150..300 ms by skill")
	assert_gte(float(r["reaction_s"][1]), 0.3 - 0.04)
	assert_gt(float(r["aim_error_deg"]), float(e["aim_error_deg"]))
	assert_gt(float(r["decision_noise"]), float(e["decision_noise"]))
	assert_lt(float(r["spend_smartness"]), float(e["spend_smartness"]))
	assert_eq(BotConfig.skill_key(c, "regular"), "veteran", "a saved 'regular' plays Veteran")
	assert_eq(BotConfig.skill_key(c, "green"), "recruit")
	assert_eq(str(c["skill_default"]), "veteran")
	for k: String in ["recruit", "veteran", "elite"]:
		assert_eq(float(BotConfig.skill(c, k).get("damage_taken_mult", 1.0)), 1.0, "%s: no hidden health buff" % k)
	assert_false((c.get("combat", {}) as Dictionary).has("round_start_pistol_refill"), "no free pistol refills")


# ---------------------------------------------------------------- the blackboard

func test_revive_claims_are_exclusive() -> void:
	var bb: BotBlackboard = BotBlackboard.new()
	assert_true(bb.claim("revive:1", 2, "revive", 0.0))
	assert_false(bb.claim("revive:1", 3, "revive", 0.0), "a second bot can't take the same revive")
	assert_false(bb.can_claim("revive:1", 3, 0.0))
	assert_true(bb.claim("revive:1", 2, "revive", 0.5), "the holder keeps it")
	assert_eq(bb.claimer("revive:1", 1.0), 2)
	bb.release_all(2)
	assert_true(bb.claim("revive:1", 3, "revive", 1.0), "free again once the holder lets go")
	assert_eq(bb.held_by(3, "revive:"), ["revive:1"])


func test_window_pairs_and_claim_expiry() -> void:
	var bb: BotBlackboard = BotBlackboard.new()
	assert_true(bb.claim("hold:7", 2, "hold", 0.0, 10.0, null, 2))
	assert_true(bb.claim("hold:7", 3, "hold", 0.0, 10.0, null, 2), "two bots hold one window")
	assert_false(bb.claim("hold:7", 4, "hold", 0.0, 10.0, null, 2), "not three")
	assert_true(bb.claim("hold:7", 4, "hold", 11.0, 20.0, null, 2), "the claims ran out")
	bb.claim("revive:1", 2, "revive", 0.0)
	bb.claim("repair:9", 3, "repair", 0.0)
	bb.clear_round_claims()
	assert_eq(bb.claimer("revive:1", 0.0), 2, "revives survive the round change")
	assert_eq(bb.claimer("repair:9", 0.0), 0)


func test_memory_decays_and_danger_zones() -> void:
	var bb: BotBlackboard = BotBlackboard.new()
	bb.memory_s = 4.0
	var o: RefCounted = RefCounted.new()
	bb.sight(o, Vector3(1, 0, 1), 0.0, 2)
	assert_eq(bb.known(3.0).size(), 1)
	assert_eq(bb.known(4.5).size(), 0, "forgotten after 4 s: no wallhacks")
	bb.add_danger(Vector3.ZERO, 3.0, 2.0, 5.0, "boss:1")
	bb.add_danger(Vector3(1, 0, 0), 3.0, 2.0, 5.0, "boss:1")
	assert_eq(bb.danger_zones.size(), 1, "a keyed zone refreshes, it doesn't stack")
	var z: Dictionary = bb.danger_zones[0]
	for k: String in ["pos", "radius", "cost", "until"]:
		assert_true(z.has(k), "the shape the locomotion layer reads: %s" % k)
	assert_gt(bb.danger_at(Vector3(2, 0, 0), 1.0), 0.0)
	assert_eq(bb.danger_at(Vector3(9, 0, 0), 1.0), 0.0)
	bb.prune_danger(6.0)
	assert_true(bb.danger_zones.is_empty())


# ---------------------------------------------------------------- economy

func test_perks_in_plan_order_with_the_weapon_perk() -> void:
	var plan: Array = eco["perk_plan"]
	var all: Dictionary = {"ironhide_stout": 2500, "second_wind": 500, "trigger_tonic": 3000, "twin_barrel": 2000, "hawkeye_brandy": 1500}
	assert_eq(BotEconomy.perk_wanted(eco, plan, [], all, "smg", true, 4, 9000, 500), &"ironhide_stout", "Ironhide first")
	assert_eq(BotEconomy.perk_wanted(eco, plan, ["ironhide_stout"], all, "smg", true, 4, 9000, 500), &"second_wind", "then Second Wind in co-op")
	assert_eq(BotEconomy.perk_wanted(eco, plan, ["ironhide_stout"], all, "smg", false, 4, 9000, 500), &"trigger_tonic", "solo: no Second Wind")
	assert_eq(BotEconomy.perk_wanted(eco, plan, ["ironhide_stout", "second_wind"], all, "smg", true, 4, 9000, 500), &"trigger_tonic", "an SMG: Trigger Tonic (T-058: magazine-bound, the half reload)")
	assert_eq(BotEconomy.perk_wanted(eco, plan, ["ironhide_stout", "second_wind"], all, "rifle", true, 4, 9000, 500), &"twin_barrel", "a semi rifle: Twin Barrel")
	assert_eq(BotEconomy.perk_wanted(eco, plan, ["ironhide_stout", "second_wind"], all, "lmg", true, 4, 9000, 500), &"trigger_tonic", "an LMG: Trigger Tonic")
	assert_eq(BotEconomy.perk_wanted(eco, plan, [], all, "smg", true, 0, 9000, 500), &"", "the cap is full")
	assert_eq(BotEconomy.perk_wanted(eco, plan, [], all, "smg", true, 4, 2800, 500), &"", "it saves for Ironhide instead of skipping to a cheaper perk")
	assert_eq(BotEconomy.perk_wanted(eco, plan, [], {"hawkeye_brandy": 1500}, "smg", true, 4, 9000, 500), &"hawkeye_brandy", "an unpowered / missing machine is passed over")


func test_reserve_is_kept() -> void:
	assert_eq(BotEconomy.reserve_scrip(eco, 500, 250, 1.0), 750, "one revive-critical rebuy + one ammo box")
	assert_eq(BotEconomy.reserve_scrip(eco, 500, 250, 1.5), 1125, "Peg saves more")
	assert_eq(BotEconomy.reserve_scrip(eco, 0, 0, 1.0), int(eco["reserve"]["min_scrip"]))


func test_no_kar98k_after_round_ten_and_a_gun_good_for_the_round() -> void:
	var walls: Dictionary = {"kar98k": 200}
	var classes: Dictionary = {"kar98k": "bolt", "m1_garand": "rifle", "mp40": "smg", "trench_gun": "shotgun", "thompson": "smg"}
	var pistol_only: Array = [{"id": "m1911", "tier": 0.5}]
	assert_eq(BotEconomy.gun_wanted(eco, pistol_only, walls, classes, {}, 3, 5000, 750, true), &"kar98k", "early on a Kar98k beats the pistol")
	assert_eq(BotEconomy.gun_wanted(eco, pistol_only, walls, classes, {}, 11, 5000, 750, true), &"", "never a Kar98k after round 10")
	assert_false(BotEconomy.gun_allowed("kar98k", 11, eco))
	assert_true(BotEconomy.gun_allowed("thompson", 25, eco))
	var map0: Dictionary = {"kar98k": 200, "m1_garand": 600, "mp40": 1000, "trench_gun": 1500, "thompson": 1200, "bar": 1800}
	var kit: Array = [{"id": "m1911", "tier": 0.5, "q": 0}, {"id": "thompson", "tier": 3.6, "q": 1200}]
	assert_eq(BotEconomy.gun_wanted(eco, kit, map0, classes, {}, 8, 5000, 750, false), &"bar", "only a gun better than the kit's Thompson")
	map0.erase("bar")
	assert_eq(BotEconomy.gun_wanted(eco, kit, map0, classes, {}, 8, 5000, 750, false), &"", "nothing on Map 0 beats it: no Scrip wasted on a worse gun")
	var mp40: Array = [{"id": "m1911", "tier": 0.5, "q": 0}, {"id": "mp40", "tier": 3.2, "q": 1000}]
	assert_eq(BotEconomy.gun_wanted(eco, mp40, map0, classes, {}, 8, 5000, 750, false), &"thompson", "an MP40 carrier upgrades to the Thompson")
	assert_eq(BotEconomy.gun_wanted(eco, mp40, map0, classes, {}, 8, 1300, 750, false), &"", "not into the reserve")
	var garand: Array = [{"id": "m1911", "tier": 0.5, "q": 0}, {"id": "m1_garand", "tier": 2.4, "q": 600}]
	assert_eq(BotEconomy.gun_wanted(eco, garand, map0, classes, {"shotgun": 1.3}, 8, 5000, 750, false), &"trench_gun", "Deacon likes the trench gun")


func test_crate_doors_and_the_never_touch_rule() -> void:
	assert_true(BotEconomy.crate_wanted(eco, 4000, 950, 3.6, 15, 750), "Scrip to spare, a Thompson at round 15: pull")
	assert_false(BotEconomy.crate_wanted(eco, 2000, 950, 3.6, 15, 750), "under 2,500: no")
	assert_false(BotEconomy.crate_wanted(eco, 9000, 950, 6.0, 15, 750), "a wonder weapon in hand: no")
	assert_true(BotEconomy.door_allowed(eco, true, false, 0, 99.0), "ordered")
	assert_false(BotEconomy.door_allowed(eco, false, false, 0, 2.0), "the human hasn't opened anything: no")
	assert_true(BotEconomy.door_allowed(eco, false, false, 1, 4.0), "the human opens doors and stands by this one")
	assert_false(BotEconomy.door_allowed(eco, false, false, 1, 30.0))
	assert_true(BotEconomy.door_allowed(eco, false, true, 0, INF), "no human leads: the bots decide")
	for k: String in ["quest", "part", "power"]:
		assert_false(BotEconomy.may_touch(k, false, false, false), "never %s on its own" % k)
		assert_true(BotEconomy.may_touch(k, true, false, false), "%s when ordered" % k)
		assert_true(BotEconomy.may_touch(k, false, true, false), "%s for the local-AI planner bot" % k)
	assert_false(BotEconomy.may_touch("trap", false, false, false))
	assert_true(BotEconomy.may_touch("trap", false, false, true), "a trap the human already used")
	assert_true(BotEconomy.may_touch("perk", false, false, false))


# ---------------------------------------------------------------- aim and weapons

func test_the_pistol_trap_is_fixed() -> void:
	var wc: Dictionary = combat["weapons"]
	var calm: Dictionary = {"crowd": 1, "boss": false, "close": false, "danger": false}
	var hot: Dictionary = {"crowd": 3, "boss": false, "close": true, "danger": true}
	var pistol_calm: float = BotAim.weapon_value("pistol", 8, 40, 8, calm, wc, {})
	var tommy_empty_calm: float = BotAim.weapon_value("smg", 0, 180, 30, calm, wc, {})
	assert_gt(tommy_empty_calm, pistol_calm, "nothing close: the empty Thompson (to reload) beats the pistol")
	var pistol_hot: float = BotAim.weapon_value("pistol", 8, 40, 8, hot, wc, {})
	var tommy_empty_hot: float = BotAim.weapon_value("smg", 0, 180, 30, hot, wc, {})
	assert_gt(pistol_hot, tommy_empty_hot, "a sprinter in its face with the Thompson dry: the pistol")
	# holding the pistol: back to the Thompson as soon as nothing is within swap_back_safe_m
	assert_eq(BotAim.preferred_slot([pistol_calm, tommy_empty_calm], 0, 8, 8.0, wc), 1)
	assert_eq(BotAim.preferred_slot([pistol_calm, tommy_empty_calm], 0, 8, 1.5, wc), 0, "not mid-brawl")
	assert_eq(BotAim.preferred_slot([pistol_calm, tommy_empty_calm], 0, 0, 1.5, wc), 1, "the pistol is dry too: swap anyway")


func test_weapon_choice_by_situation() -> void:
	var wc: Dictionary = combat["weapons"]
	var crowd: Dictionary = {"crowd": 8, "boss": false, "close": false, "danger": false}
	assert_gt(BotAim.weapon_value("wonder", 10, 40, 12, crowd, wc, {}), BotAim.weapon_value("smg", 30, 100, 30, crowd, wc, {}), "a wonder weapon for crowds")
	var boss: Dictionary = {"crowd": 1, "boss": true, "close": false, "danger": false}
	assert_gt(BotAim.weapon_value("rifle", 8, 40, 8, boss, wc, {"rifle": 1.45}), BotAim.weapon_value("smg", 30, 100, 30, boss, wc, {"rifle": 1.45}), "Wren takes the rifle to a boss")
	assert_eq(BotAim.weapon_value("smg", 0, 0, 30, crowd, wc, {}), 0.0, "no ammo, no value")


func test_grenades_only_into_groups_clear_of_teammates() -> void:
	var g: Dictionary = combat["grenades"]
	var group: Array = []
	for i: int in 5:
		group.append({"pos": Vector3(12.0 + 0.5 * i, 0, 0.4 * i), "node": null, "boss": false})
	var none: Array[Vector3] = []
	assert_ne(BotAim.grenade_spot(group, Vector3.ZERO, none, g, 1.0), Vector3.INF, "five bunched 12 m off: throw")
	var mate: Array[Vector3] = [Vector3(13, 0, 1)]
	assert_eq(BotAim.grenade_spot(group, Vector3.ZERO, mate, g, 1.0), Vector3.INF, "a teammate is in it")
	assert_eq(BotAim.grenade_spot(group.slice(0, 2), Vector3.ZERO, none, g, 1.0), Vector3.INF, "two isn't a group")
	assert_eq(BotAim.grenade_spot(group, Vector3(11, 0, 0), none, g, 1.0), Vector3.INF, "too close to itself")


# ---------------------------------------------------------------- threat, roles, locomotion

func test_threat_by_tier_targeting_and_facing() -> void:
	var t: Dictionary = combat["threat"]
	var walker: float = BotPerception.threat_score(5.0, &"walk", false, 1.0, false, false, false, false, t)
	var runner: float = BotPerception.threat_score(5.0, &"run", false, 1.0, false, false, false, false, t)
	var sprinter: float = BotPerception.threat_score(5.0, &"sprint", false, 1.0, false, false, false, false, t)
	assert_gt(sprinter, runner)
	assert_gt(runner, walker)
	assert_gt(BotPerception.threat_score(5.0, &"walk", false, 1.0, true, false, false, false, t), walker, "coming for me")
	assert_gt(BotPerception.threat_score(5.0, &"walk", false, 1.0, false, false, true, false, t), walker, "behind me")
	assert_lt(BotPerception.threat_score(5.0, &"walk", false, 1.0, false, false, false, true, t), walker, "still outside a window")
	assert_gt(BotPerception.threat_score(5.0, &"walk", false, 2.5, false, false, false, false, t), walker, "a boss weighs more")
	assert_gt(BotPerception.threat_score(2.0, &"walk", false, 1.0, false, false, false, false, t), walker, "closer is worse")
	assert_eq(BotPerception.threat_score(30.0, &"sprint", false, 1.0, true, false, true, false, t), 0.0, "out of range")


func test_roles_follow_the_personalities() -> void:
	var b: Array = [BotAIData.personality("dutch")["role_bias"], BotAIData.personality("deacon")["role_bias"], BotAIData.personality("peg")["role_bias"]]
	var roles: Array = BotSquad.best_roles(b, ["medic", "anchor", "builder", "runner"])
	assert_eq(roles, ["anchor", "medic", "runner"], "Dutch anchors, Deacon is the medic, Peg runs")


func test_personal_space_bubble() -> void:
	var h: Vector3 = Vector3.ZERO
	assert_eq(BotLocomotion.personal_space_push(Vector3(2.0, 0, 0), h, Vector3.ZERO), Vector3.ZERO, "outside 1.2 m: nothing")
	var p: Vector3 = BotLocomotion.personal_space_push(Vector3(0.6, 0, 0), h, Vector3.ZERO)
	assert_gt(p.x, 0.0, "pushed away from the human")
	var ahead: Vector3 = BotLocomotion.personal_space_push(Vector3(0, 0, -1.5), h, Vector3(0, 0, -3.0))
	assert_gt(ahead.length(), 0.0, "in front of a walking human the bubble is longer")
	assert_eq(BotLocomotion.personal_space_push(Vector3(0, 0, 1.5), h, Vector3(0, 0, -3.0)), Vector3.ZERO, "behind them it isn't")


func test_the_spending_plan_names_real_perks_and_weapons() -> void:
	var perks: Dictionary = GLData.table("perks")["perks"]
	for p: Variant in eco["perk_plan"]:
		if str(p) != "@weapon":
			assert_true(perks.has(str(p)), "perk %s" % p)
	for k: Variant in (eco["weapon_perk"] as Dictionary).keys():
		assert_true(perks.has(str(k)), "weapon perk %s" % k)
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	for w: Variant in (eco["weapon_tiers"] as Dictionary).keys():
		assert_true(weapons.has(str(w)), "weapon %s" % w)
	for w2: Variant in weapons.keys():
		if not str(w2).ends_with("_up"):
			assert_true((eco["weapon_tiers"] as Dictionary).has(str(w2)), "a tier for %s" % w2)


func test_running_dry_mid_round_goes_for_ammo() -> void:
	var c: Dictionary = _ctx({"ammo": 0.08, "resupply_task": 1.0, "pressure": 0.35, "has_target": 1.0, "known": 0.3, "mag": 0.3})
	assert_eq(_best(c, "fight"), "resupply", "nearly dry with zombies about but not swarmed: to the ammo box")
	c["pressure"] = 1.0
	assert_ne(_best(c, "fight"), "resupply", "not through a swarm")


func test_bunched_in_with_everything_dry_it_still_reloads_the_best_gun() -> void:
	# the swap-instead-of-reload rule needs a loaded gun to swap to; the brain's _weapon_logic reloads the best
	# gun when nothing is loaded. Here the pure part: an empty Thompson outranks an empty pistol even in danger.
	var wc: Dictionary = combat["weapons"]
	var hot: Dictionary = {"crowd": 6, "boss": false, "close": true, "danger": true, "near": true}
	assert_gt(BotAim.weapon_value("smg", 0, 180, 30, hot, wc, {}), BotAim.weapon_value("pistol", 0, 60, 8, hot, wc, {}))
