extends GutTest
## THE ACCOUNT MANAGER's pure rules and data (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.7, T-113): the three
## contract phases by HP, the damage terms (the presented contract's weak torso, the shield-cells), the pricing
## stamp's cut, the cells' orbit and the shaft, her data block, and the trial's rules.


func test_boss_data() -> void:
	var b: Dictionary = GLData.table("bosses/map04")["bosses"].get("account_manager", {})
	assert_false(b.is_empty(), "bosses/map04.json account_manager")
	assert_eq(int(b["hp_base"]), 45000)
	assert_eq(int(b.get("kill_scrip_per_player", 1)), 0, "she never dies: no kill Scrip")
	assert_gt(int(b.get("escalate_scrip_per_player", 0)), 0, "the escalation pays")
	assert_eq(str(b["flag"]), "manager_escalated")
	assert_eq(str(b["spawn_vo"]), "WIV_M4D_INTRO_01")
	assert_almost_eq(float((b["phases"] as Dictionary)["renewal_at"]), 0.7, 0.001)
	assert_almost_eq(float((b["phases"] as Dictionary)["collections_at"]), 0.35, 0.001)
	assert_eq(int((b["shields"] as Dictionary)["count"]), 3)
	assert_eq(int((b["shields"] as Dictionary)["hp"]), 2000)
	assert_almost_eq(float((b["shields"] as Dictionary)["regen_seconds"]), 40.0, 0.001)
	assert_almost_eq(float((b["price"] as Dictionary)["scrip_fraction"]), 0.1, 0.001)
	assert_eq(int((b["price"] as Dictionary)["damage"]), 90)
	assert_almost_eq(float((b["trial"] as Dictionary)["offer_seconds"]), 60.0, 0.001)
	assert_almost_eq(HomageBoss.scaled_hp(45000.0, 3, 0.75), 112500.0, 0.5, "x2.5 for three")


func test_phases_by_hp() -> void:
	var ph: Dictionary = {"renewal_at": 0.7, "collections_at": 0.35}
	assert_eq(AccountManager.phase_of(1.0, ph), 1)
	assert_eq(AccountManager.phase_of(0.71, ph), 1)
	assert_eq(AccountManager.phase_of(0.7, ph), 2)
	assert_eq(AccountManager.phase_of(0.36, ph), 2)
	assert_eq(AccountManager.phase_of(0.35, ph), 3)
	assert_eq(AccountManager.phase_of(0.0, ph), 3)


func test_damage_terms() -> void:
	assert_almost_eq(AccountManager.damage_mult(&"torso", false, 0, 2.5, 0.2), 1.0, 0.001)
	assert_almost_eq(AccountManager.damage_mult(&"torso", true, 0, 2.5, 0.2), 2.5, 0.001, "the contract presented: the torso")
	assert_almost_eq(AccountManager.damage_mult(&"head", true, 0, 2.5, 0.2), 1.0, 0.001, "only the torso")
	assert_almost_eq(AccountManager.damage_mult(&"torso", false, 3, 2.5, 0.2), 0.2, 0.001, "cells up")
	assert_almost_eq(AccountManager.damage_mult(&"torso", true, 1, 2.5, 0.2), 0.5, 0.001, "both")


func test_price_cut() -> void:
	assert_eq(AccountManager.price_cut(0, 0.1), 0)
	assert_eq(AccountManager.price_cut(5, 0.1), 1, "at least one")
	assert_eq(AccountManager.price_cut(12345, 0.1), 1235, "a tenth, rounded")


func test_cells_orbit_and_the_shaft() -> void:
	var c: Vector3 = Vector3(28, 0, -34)
	var p0: Vector3 = ShieldCell.orbit_pos(c, 0.0, 0.0, 2.6, 1.7, 6.0)
	assert_almost_eq(p0.distance_to(Vector3(c.x, p0.y, c.z)), 2.6, 0.01, "on the orbit radius")
	assert_almost_eq(p0.y, 1.7, 0.3, "about orbit height")
	var p1: Vector3 = ShieldCell.orbit_pos(c, 0.0, 5.0, 2.6, 1.7, 6.0)
	assert_gt(p0.distance_to(p1), 1.0, "it moves (6 rpm: half a turn in 5 s)")
	var shaft: Vector3 = Vector3(28, 7, -30)
	assert_true(ShieldCell.in_shaft(Vector3(28.5, 8.0, -30.5), shaft, 2.5))
	assert_false(ShieldCell.in_shaft(Vector3(28, 2.0, -30), shaft, 2.5), "below the mouth")
	assert_false(ShieldCell.in_shaft(Vector3(34, 8.0, -30), shaft, 2.5), "beside it")
	assert_false(ShieldCell.in_shaft(Vector3(28, 8.0, -30), Vector3.INF, 2.5), "no shaft set")


func test_retained_rules() -> void:
	var r: Dictionary = RenewalEnding.retained_rules()
	assert_true(bool(r["perks_kept_on_down"]) and bool(r["special_every_round"]) and bool(r["egg_closed"]))
	assert_false(bool(r["second_wind"]) or bool(r["air_posts"]))
	GameState.retained = true
	var h1: int = RoundManager.current_health()
	GameState.retained = false
	var h0: int = RoundManager.current_health()
	assert_true(h1 > h0, "the dead one step tougher when retained (%d > %d)" % [h1, h0])
