extends GutTest
## T-136: the savings bank. Interest is 1% a round (rounded down, at least 1, capped), deposits and withdrawals
## move Scrip and the profile's balance (kept between matches: it is in the saved profile), never count as
## earnings, and the bank is shut in Classic Rules. Branches on Map 0 and Kaltenbrunn only; the teller has a body,
## a voice and lines.

var _saved_profile: Dictionary
var _saved_path: String
var _saved_settings: Dictionary


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_path = ProfileSave.path
	_saved_settings = GLSettings.values.duplicate(true)
	ProfileSave.path = "user://_test_bank_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["classic_rules"] = false
	Economy.reset([1])
	Economy._scrip[1] = 0   # (no starting Scrip: the sums are exact)


func after_each() -> void:
	ProfileSave.profile = _saved_profile
	ProfileSave.path = _saved_path
	GLSettings.values = _saved_settings


func test_interest_is_one_percent_rounded_down_at_least_one_capped() -> void:
	assert_eq(BankAccount.interest_for(10000, 0.01, 1, 1000000), 100)
	assert_eq(BankAccount.interest_for(1999, 0.01, 1, 1000000), 19)
	assert_eq(BankAccount.interest_for(50, 0.01, 1, 1000000), 1, "something on any balance")
	assert_eq(BankAccount.interest_for(0, 0.01, 1, 1000000), 0)
	assert_eq(BankAccount.interest_for(999990, 0.01, 1, 1000000), 10, "never past the cap")
	assert_eq(BankAccount.interest_for(1000000, 0.01, 1, 1000000), 0)


func test_deposit_withdraw_and_interest_move_the_profile_balance() -> void:
	Economy.grant(1, 5000)
	assert_eq(BankAccount.deposit(1, 3000), 3000)
	assert_eq(Economy.get_scrip(1), 2000)
	assert_eq(BankAccount.balance(), 3000)
	assert_eq(BankAccount.deposit(1, 9999), 2000, "only what you have")
	assert_eq(BankAccount.accrue(), 50, "1% of 5000")
	assert_eq(BankAccount.balance(), 5050)
	assert_eq(BankAccount.withdraw(1, 1000), 1000)
	assert_eq(Economy.get_scrip(1), 1000)
	assert_eq(BankAccount.withdraw(1, 999999), 4050, "only what is saved")
	assert_eq(BankAccount.balance(), 0)
	var rec: Dictionary = ProfileSave.profile["bank"]
	assert_eq(int(rec["deposited"]), 5000)
	assert_eq(int(rec["interest"]), 50)


func test_the_balance_is_saved_with_the_profile() -> void:
	Economy.grant(1, 2000)
	BankAccount.deposit(1, 2000)
	ProfileSave.profile = {}
	ProfileSave.load_profile()
	assert_eq(BankAccount.balance(), 2000, "back from the saved file: a later match has it")


func test_moving_scrip_is_no_earning() -> void:
	Economy.grant(1, 1000)
	BankAccount.deposit(1, 1000)
	var before: int = int(GameState.stats.get(&"scrip_earned", 0))
	BankAccount.withdraw(1, 1000)
	assert_eq(int(GameState.stats.get(&"scrip_earned", 0)), before, "a withdrawal is not earned Scrip")
	assert_false(Economy.moving)


func test_shut_in_classic_rules() -> void:
	Economy.grant(1, 1000)
	GLSettings.values["classic_rules"] = true
	assert_eq(BankAccount.closed_reason(), "classic")
	assert_eq(BankAccount.deposit(1, 1000), 0)
	assert_eq(BankAccount.accrue(), 0)


func test_branches_and_the_teller() -> void:
	assert_false(BankBranch.branch_for("map00_crossroads").is_empty())
	assert_false(BankBranch.branch_for("map01_kaltenbrunn").is_empty())
	var people: Dictionary = (GLData.load_json("res://data/gravelight/art/people.json") as Dictionary).get("people", {})
	assert_true(people.has("teller"))
	var cast: Dictionary = (GLData.load_json("res://data/gravelight/vo/voice_cast.json") as Dictionary).get("cast", {})
	assert_true(cast.has("TEL"))
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for c: String in ["BANK_GREET", "BANK_GREET_M1", "BANK_DEPOSIT", "BANK_WITHDRAW", "BANK_BROKE", "BANK_SCARED", "BANK_CLOSED"]:
		assert_true(lines.has("TEL_%s_01" % c), c)


## T-141 (UPDATE 09 contract C6): a branch on every map, a teller per map, 6-8+ lines each.
func test_a_branch_and_a_teller_on_every_map() -> void:
	var people: Dictionary = (GLData.load_json("res://data/gravelight/art/people.json") as Dictionary).get("people", {})
	var cast: Dictionary = (GLData.load_json("res://data/gravelight/vo/voice_cast.json") as Dictionary).get("cast", {})
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	var maps: Array = ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]
	var seen_spk: Dictionary = {}
	for m: String in maps:
		var br: Dictionary = BankBranch.branch_for(m)
		assert_false(br.is_empty(), "%s has a branch" % m)
		assert_true(br.has("at") and br.has("yaw") and br.has("width") and br.has("greet") and br.has("title"), "%s: a complete row" % m)
		var t: Dictionary = BankAccount.teller_for(m)
		assert_false(t.is_empty(), "%s has a teller" % m)
		var spk: String = str(t["speaker"])
		if not bool(t.get("construct", false)):
			assert_true(people.has(str(t["id"])), "%s: the teller %s has a body row" % [m, t["id"]])
			assert_true(cast.has(spk), "%s: %s has a voice" % [m, spk])
		else:
			assert_eq(spk, "OPR", "the Accounts window answers in the Operator's voice")
		var greet: String = str(br["greet"])
		var greet_n: int = 0
		for id: String in lines.keys():
			var rec: Dictionary = lines[id]
			if str(rec.get("speaker", "")) == spk and str(rec.get("category", "")) == greet:
				greet_n += 1
		assert_gte(greet_n, 1, "%s: %s has %s lines" % [m, spk, greet])
		for c: String in ["BANK_DEPOSIT", "BANK_WITHDRAW", "BANK_BROKE", "BANK_SCARED", "BANK_CLOSED"]:
			assert_true(lines.has("%s_%s_01" % [spk, c]), "%s: %s_%s_01" % [m, spk, c])
		seen_spk[spk] = true
	assert_true(seen_spk.has("TEL") and seen_spk.has("JES") and seen_spk.has("RUH") and seen_spk.has("PRU") and seen_spk.has("OPR"))
	# each new teller has at least six lines (the Operator's Accounts window and the three clerks)
	for spk2: String in ["JES", "RUH", "PRU", "OPR"]:
		var n: int = 0
		for id2: String in lines.keys():
			if id2.begins_with(spk2 + "_BANK_"):
				n += 1
		assert_gte(n, 6, "%s has 6+ bank lines" % spk2)
	assert_eq(str(BankAccount.teller_for("map00_crossroads")["speaker"]), "TEL")
	assert_eq(str(BankAccount.teller_for("map04b_kranich")["speaker"]), "RUH", "the Thalbach clerk stowed away on the Kranich")


func test_every_branch_has_a_footprint_the_generators_cut_out() -> void:
	for m: String in ["map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]:
		var br: Dictionary = BankBranch.branch_for(m)
		assert_true(br.has("nav_block"), "%s: nav_block" % m)
		var nb: Array = br["nav_block"]
		var at: Array = br["at"]
		assert_true(float(nb[0][0]) <= float(at[0]) and float(at[0]) <= float(nb[1][0]), "%s: the counter is inside its footprint (x)" % m)
		assert_true(float(nb[0][2]) <= float(at[2]) and float(at[2]) <= float(nb[1][2]), "%s: ... (z)" % m)


func test_the_interest_rate_follows_the_savers_tonic() -> void:
	assert_almost_eq(BankAccount.rate_for(-1), 0.01, 0.00001)
	assert_almost_eq(BankAccount.rate_for(1), 0.01, 0.00001)
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0
	PerkManager.grant(1, &"ledger_lager")
	PerkManager.set_tier(1, &"ledger_lager", 2)
	assert_almost_eq(BankAccount.rate_for(1), 0.03, 0.00001, "Ledger Lager II: 3% a round")
	Economy._scrip[1] = 0
	Economy.grant_raw(1, 20000)
	BankAccount.deposit(1, 20000)
	assert_eq(BankAccount.accrue(1), 600)
	PerkManager.reset_match()
	PerkManager.meta_gate_override = -1


func test_the_bank_poi_is_in_the_scan() -> void:
	var ps: PackedScene = load("res://gravelight/maps/map02_totenhafen/map02.tscn") as PackedScene
	var root: Node = ps.instantiate()
	var scan: Dictionary = MapScan.scan_gl(root)
	root.free()
	var found: Array = (scan["pois"] as Array).filter(func(p: Dictionary) -> bool: return str(p["type"]) == "bank")
	assert_eq(found.size(), 1, "one bank POI on Totenhafen")
	assert_eq(str(found[0]["node_path"]), "BankBranch/Counter")
