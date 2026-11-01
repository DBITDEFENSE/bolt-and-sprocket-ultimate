extends GutTest
## UPDATE 09 section 3 (T-141): Ledger Lager, the points tonic (docs/U09_LEDGER_LAGER.md, JINGLES.md section 16).
## The earn multiplier on every earning (and not on a bank move, a refund or a starting kit), the boosted "+N"
## number, interest stacking, the discount on every purchase path, the Marke tip, the golden parachute and the
## severance, permanence, the profile, Classic Rules, the data, the lore and the voice.

const PID: int = 1

var _saved_profile: Dictionary
var _saved_path: String
var _saved_settings: Dictionary


func before_each() -> void:
	_saved_profile = ProfileSave.profile.duplicate(true)
	_saved_path = ProfileSave.path
	_saved_settings = GLSettings.values.duplicate(true)
	ProfileSave.path = "user://_test_ledger_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.values["classic_rules"] = false
	GameState.player_ids = [PID]
	GameState.power_on = true
	RoundManager.current_round = 20
	PerkManager.reset_match()
	PerkManager.meta_gate_override = 0
	Economy.reset([PID])
	Economy._scrip[PID] = 0
	Economy.multiplier = 1


func after_each() -> void:
	ProfileSave.profile = _saved_profile
	ProfileSave.path = _saved_path
	GLSettings.values = _saved_settings
	PerkManager.meta_gate_override = -1
	PerkManager.reset_match()
	Economy.multiplier = 1
	GameState.power_on = false
	RoundManager.current_round = 0
	GameState.phase = GameState.Phase.MENU


func _hold(tier: int) -> void:
	PerkManager.grant(PID, &"ledger_lager")
	if tier > 1:
		PerkManager.set_tier(PID, &"ledger_lager", tier)


func _player() -> Player:
	var p: Player = Player.new()
	p.player_id = PID
	add_child_autofree(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return p


# ---------------------------------------------------------------- data

func test_the_perk_row_and_its_tiers() -> void:
	var row: Dictionary = PerkManager.perk_data(&"ledger_lager")
	assert_eq(str(row["name"]), "Ledger Lager")
	assert_eq(int(row["cost"]), 3000)
	assert_eq(str(row["shape"]), "register")
	assert_eq(str(row["abbr"]), "LL")
	assert_true(bool(row["needs_power"]))
	assert_eq(PerkManager.tier_name(&"ledger_lager", 2), "Ledger Lager II")
	assert_eq(str(PerkManager.tier_data(&"ledger_lager", 2)["name"]), "Compound Interest")
	assert_eq(str(PerkManager.tier_data(&"ledger_lager", 3)["name"]), "Insider Rate")
	assert_eq(str(PerkManager.tier_data(&"ledger_lager", 4)["name"]), "Golden Parachute")
	assert_eq(PerkManager.tier_price(&"ledger_lager", 2), 4000)
	assert_eq(PerkManager.tier_price(&"ledger_lager", 3), 7500)
	assert_eq(PerkManager.tier_price(&"ledger_lager", 4), 14000)
	assert_almost_eq(float(PerkManager.effects_for(&"ledger_lager", 1)["scrip_earn_mult"]), 1.2, 0.0001)
	assert_almost_eq(float(PerkManager.effects_for(&"ledger_lager", 2)["bank_interest_bonus"]), 0.02, 0.0001)
	var e3: Dictionary = PerkManager.effects_for(&"ledger_lager", 3)
	assert_almost_eq(float(e3["purchase_discount"]), 0.10, 0.0001)
	assert_eq(int(e3["marke_tip"]), 15)
	assert_almost_eq(float(e3["scrip_earn_mult"]), 1.2, 0.0001, "the tiers keep the lower ones' effects")
	var e4: Dictionary = PerkManager.effects_for(&"ledger_lager", 4)
	for k: String in ["golden_parachute_pct", "golden_parachute_cap", "severance_pct", "severance_cap", "no_scrip_loss_on_down"]:
		assert_true(e4.has(k), k)


func test_the_lore_the_voice_and_the_machine_are_filed() -> void:
	var lore: Dictionary = (GLData.load_json("res://data/gravelight/perk_lore.json") as Dictionary)["perks"]["ledger_lager"]
	assert_eq(str(lore["plan_id"]), "DMS-VP-DIV-09")
	assert_eq(str(lore["plan_name"]), "DIVIDEND")
	assert_string_contains(str(lore["human"]), "Fenske")
	assert_gt((lore["panel"] as Array).size(), 8)
	var ml: Dictionary = (GLData.load_json("res://data/gravelight/machine_lore.json") as Dictionary)["maps"]
	for m: String in ["map00_crossroads", "map01_kaltenbrunn", "map02_totenhafen", "map04a_thalbach", "map04b_kranich", "map04c_groomlake", "map04d_mondlicht"]:
		assert_true((ml[m]["entries"] as Dictionary).has("perk.ledger_lager"), "%s has the plate" % m)
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for spk: String in ["DUT", "PEG", "DEA", "WRN", "JAK"]:
		for n: String in ["01", "02"]:
			assert_true(lines.has("%s_PERK_LEDGER_%s" % [spk, n]), "%s first drink %s" % [spk, n])
			assert_eq(str(lines["%s_PERK_LEDGER_%s" % [spk, n]]["category"]), "PERK_LEDGER")
	assert_true(lines.has("OPR_PERK_TIER4_LEDGER_01"))
	assert_eq(str(GLVO.PERK_TOKENS.get(&"ledger_lager", "")), "LEDGER", "the first-drink hook reads PERK_LEDGER")
	assert_true(ProfileSave.CABINET_PERKS.has("ledger_lager"), "the Archive files the cabinet")
	assert_true(PerkCap.GLYPHS.has("ledger_lager"), "it has a cap glyph")
	assert_eq(PerkMachine._shape_footprint("register"), Vector3(1.0, 2.2, 0.75))


# ---------------------------------------------------------------- the earn multiplier

func test_no_tonic_no_boost() -> void:
	Economy.award(PID, 10)
	assert_eq(Economy.get_scrip(PID), 10)
	assert_almost_eq(Economy.earn_mult(PID), 1.0, 0.0001)


func test_every_earning_is_boosted() -> void:
	_hold(1)
	assert_almost_eq(Economy.earn_mult(PID), 1.2, 0.0001)
	var cfg: Dictionary = GLData.table("economy")
	# a non-lethal hit
	Economy.award(PID, int(cfg["hit_nonlethal"]))
	assert_eq(Economy.get_scrip(PID), 12, "a 10 point hit pays 12")
	Economy._scrip[PID] = 0
	# kills by zone and melee
	for row: Array in [[&"torso", false, 60], [&"head", false, 120], [&"neck", false, 72], [&"torso", true, 156]]:
		Economy._scrip[PID] = 0
		Economy.award(PID, Economy.kill_value(row[0], bool(row[1]), cfg))
		assert_eq(Economy.get_scrip(PID), int(row[2]), "kill %s melee=%s" % [row[0], row[1]])
	# the Marke bonus (C1) goes through award
	Economy._scrip[PID] = 0
	Economy.award(PID, 25)
	assert_eq(Economy.get_scrip(PID), 30, "a 25 point Marke bonus pays 30")
	# a board repair
	Economy._scrip[PID] = 0
	Economy.award_repair(PID)
	assert_eq(Economy.get_scrip(PID), 12, "a 10 point board pays 12")
	# a revive
	Economy._scrip[PID] = 0
	Economy.award(PID, int(cfg["revive_bonus"]))
	assert_eq(Economy.get_scrip(PID), 120)
	# round and clean-round bonuses and quest / egg rewards go through grant
	Economy._scrip[PID] = 0
	Economy.bonuses.pay(PID, &"round_pay", 100, "ROUND PAY")
	assert_eq(Economy.get_scrip(PID), 120, "the round pay")
	Economy._scrip[PID] = 0
	assert_eq(Economy.grant(PID, 500), 600, "a quest reward pays 600 and says so")
	assert_eq(Economy.get_scrip(PID), 600)
	# Double Scrip stacks (x2 then x1.2)
	Economy._scrip[PID] = 0
	Economy.multiplier = 2
	Economy.award(PID, 50)
	assert_eq(Economy.get_scrip(PID), 120, "50 x2 x1.2")
	Economy.multiplier = 1


func test_not_on_moves_refunds_or_charges() -> void:
	_hold(1)
	Economy._scrip[PID] = 1000
	Economy.bank_move(PID, 500)
	assert_eq(Economy.get_scrip(PID), 1500, "a bank withdrawal is not boosted")
	Economy.grant_raw(PID, 950)
	assert_eq(Economy.get_scrip(PID), 2450, "the crate's refund is not boosted")
	Economy.grant(PID, -100)
	assert_eq(Economy.get_scrip(PID), 2350, "a charge (the Account Manager's cut) is taken as it is")
	Economy._scrip[PID] = 0
	Economy.grant(PID, 1000)
	var got: int = BankAccount.deposit(PID, 1200)
	assert_eq(got, 1200)
	assert_eq(BankAccount.withdraw(PID, 1200), 1200)
	assert_eq(Economy.get_scrip(PID), 1200, "deposit and withdraw round-trip exactly")


func test_the_crates_refund_path_is_raw() -> void:
	var src: String = FileAccess.get_file_as_string("res://gravelight/world/mystery_crate.gd")
	assert_true(src.contains("Economy.grant_raw(_owner_player, _paid)"), "the drummer's refund never takes the multiplier")
	var dev: String = FileAccess.get_file_as_string("res://gravelight/ui/dev_console.gd")
	assert_true(dev.contains("Economy.grant_raw(_ctx_pid, n)"))


func test_the_hud_pop_shows_the_boosted_number() -> void:
	_hold(1)
	var seen: Array = []
	var cb: Callable = func(p: int, _total: int, delta: int) -> void:
		if p == PID:
			seen.append(delta)
	GLBus.scrip_changed.connect(cb)
	Economy.award(PID, 10)
	GLBus.scrip_changed.disconnect(cb)
	assert_eq(seen, [12], "the +N is the boosted number")


func test_boost_rounding() -> void:
	assert_eq(Economy.boosted(10, 1.2), 12)
	assert_eq(Economy.boosted(1, 1.2), 1)
	assert_eq(Economy.boosted(3, 1.2), 4, "3.6 to the nearest")
	assert_eq(Economy.boosted(0, 1.2), 0)
	assert_eq(Economy.boosted(-5, 1.2), -5)
	assert_eq(Economy.boosted(50, 1.0), 50)


# ---------------------------------------------------------------- the bank

func test_interest_stacks_one_and_two_percent() -> void:
	Economy.grant_raw(PID, 10000)
	BankAccount.deposit(PID, 10000)
	assert_almost_eq(BankAccount.rate_for(PID), 0.01, 0.00001)
	_hold(2)
	assert_almost_eq(BankAccount.rate_for(PID), 0.03, 0.00001, "1% + 2%")
	assert_eq(BankAccount.accrue(PID), 300, "3% of 10000")
	assert_eq(BankAccount.balance(), 10300)
	assert_eq(BankAccount.accrue(), 103, "without the saver's id: the base rate")
	assert_eq(BankAccount.interest_for(100000, 0.03, 1, 1000000), 3000, "no float dust on the exact sum")


func test_the_interest_is_for_the_holder_of_tier_two_only() -> void:
	_hold(1)
	assert_almost_eq(BankAccount.rate_for(PID), 0.01, 0.00001, "tier I does not raise the rate")


# ---------------------------------------------------------------- the discount

func test_the_insider_rate_on_every_purchase_path() -> void:
	assert_eq(Economy.price_for(PID, 1000), 1000, "no tonic, no discount")
	_hold(3)
	assert_eq(Economy.price_for(PID, 1000), 900)
	assert_eq(Economy.price_for(PID, 950), 855)
	assert_eq(Economy.price_for(PID, 1250), 1125)
	assert_eq(Economy.price_for(PID, 25), 23, "the house keeps the odd Scrip: the discount rounds down")
	assert_eq(Economy.price_text(PID, 1000), "900, was 1000")
	# each path goes through Economy.spend with its own item id
	for row: Array in [["door_cellar", 1500], ["kar98k", 500], ["kar98k_ammo", 250], ["thompson_box_ammo", 250], ["crate", 950], ["crucible", 5000],
			["trap_chandelier", 1000], ["pylon_a", 1500], ["second_wind", 500], ["ironhide_stout_t2", 4000]]:
		Economy._scrip[PID] = 10000
		var paid_seen: Array = []
		var cb: Callable = func(p: int, _item: StringName, c: int) -> void:
			if p == PID:
				paid_seen.append(c)
		GLBus.purchase_made.connect(cb)
		assert_true(Economy.spend(PID, StringName(row[0]), int(row[1])), str(row[0]))
		GLBus.purchase_made.disconnect(cb)
		var want: int = int(row[1]) - int(floor(float(row[1]) * 0.1))
		assert_eq(10000 - Economy.get_scrip(PID), want, "%s costs %d" % [row[0], want])
		assert_eq(paid_seen, [want], "purchase_made carries the discounted cost")
	# affordability is against the discounted price
	Economy._scrip[PID] = 855
	assert_true(Economy.spend(PID, &"crate", 950), "855 buys a 950 crate at the insider rate")
	assert_eq(Economy.get_scrip(PID), 0)


func test_the_prompts_show_the_discounted_price() -> void:
	_hold(3)
	var p: Player = _player()
	var door: BuyDoor = BuyDoor.new()
	door.cost = 1000
	door.label = "Test Door"
	add_child_autofree(door)
	assert_string_contains(door.get_prompt(p), "[900, was 1000]")
	PerkManager.reset_match()
	assert_string_contains(door.get_prompt(p), "[1000]", "without the tonic: the list price")


func test_a_tonic_bought_at_the_insider_rate() -> void:
	_hold(3)
	Economy._scrip[PID] = 5000
	assert_eq(PerkManager.buy_for(PID, &"hawkeye_brandy"), &"ok")
	assert_eq(5000 - Economy.get_scrip(PID), 1350, "1500 less 10%")


func test_the_marke_tip() -> void:
	assert_eq(PerkManager.marke_tip(PID), 0)
	_hold(2)
	assert_eq(PerkManager.marke_tip(PID), 0, "tier II has no tip")
	_hold(3)
	assert_eq(PerkManager.marke_tip(PID), 15)
	assert_eq(int(PerkManager.stat(PID, "marke_tip", 0)), 15, "what Zombie.marke_bonus_for reads")


# ---------------------------------------------------------------- the golden parachute

func test_the_pure_dividend_and_severance() -> void:
	assert_eq(ScripBonuses.parachute(10000, 0.05, 2500), 500)
	assert_eq(ScripBonuses.parachute(100000, 0.05, 2500), 2500, "capped")
	assert_eq(ScripBonuses.parachute(0, 0.05, 2500), 0)
	assert_eq(ScripBonuses.parachute(10000, 0.0, 2500), 0)
	assert_eq(BankAccount.severance_for(20000, 0.10, 2500), 2000)
	assert_eq(BankAccount.severance_for(900000, 0.10, 2500), 2500, "capped")
	assert_eq(BankAccount.severance_for(0, 0.10, 2500), 0)


func test_a_round_finished_standing_pays_a_dividend() -> void:
	_hold(4)
	var p: Player = _player()
	await get_tree().process_frame
	GameState.phase = GameState.Phase.PLAYING
	Economy.bonuses.reset()
	Economy._scrip[PID] = 20000
	var seen: Array = []
	var cb: Callable = func(pid: int, kind: StringName, amount: int, _label: String) -> void:
		if pid == PID and kind == &"dividend":
			seen.append(amount)
	GLBus.bonus_awarded.connect(cb)
	var earned_before: int = int(GameState.stats.get(&"scrip_earned", 0))
	Economy.bonuses._on_round_ended(5)
	GLBus.bonus_awarded.disconnect(cb)
	assert_eq(seen.size(), 1, "one dividend slip")
	var wallet_before_div: int = Economy.get_scrip(PID) - int(seen[0])
	assert_eq(int(seen[0]), int(floor(float(wallet_before_div) * 0.05)), "5% of the wallet after the round pay")
	assert_lte(int(seen[0]), 2500)
	assert_true(p != null)
	# a player downed in the round gets none
	Economy.bonuses.reset()
	Economy.bonuses._downed[PID] = true
	seen.clear()
	GLBus.bonus_awarded.connect(cb)
	Economy.bonuses._on_round_ended(6)
	GLBus.bonus_awarded.disconnect(cb)
	assert_eq(seen.size(), 0, "no dividend for a round with a down in it")
	assert_gte(int(GameState.stats.get(&"scrip_earned", 0)), earned_before)


func test_a_down_pays_a_severance_and_takes_nothing() -> void:
	_hold(4)
	Economy._scrip[PID] = 3000
	ProfileSave.profile["bank"] = {"balance": 20000, "deposited": 20000, "withdrawn": 0, "interest": 0}
	var paid: int = BankAccount.pay_severance(PID)
	assert_eq(paid, 2000, "10% of the savings")
	assert_eq(BankAccount.balance(), 18000, "out of the account")
	assert_eq(Economy.get_scrip(PID), 5000, "into the pocket; nothing is taken from it")
	# through the real signal path
	Economy.bonuses._on_player_downed(PID)
	assert_eq(Economy.get_scrip(PID), 5000 + 1800)
	# a big account is capped
	ProfileSave.profile["bank"] = {"balance": 900000}
	assert_eq(BankAccount.pay_severance(PID), 2500)
	# nothing without the tier
	PerkManager.reset_match()
	_hold(3)
	ProfileSave.profile["bank"] = {"balance": 20000}
	assert_eq(BankAccount.pay_severance(PID), 0)


func test_no_severance_in_classic_rules() -> void:
	_hold(4)
	ProfileSave.profile["bank"] = {"balance": 20000}
	GLSettings.values["classic_rules"] = true
	assert_eq(BankAccount.pay_severance(PID), 0, "the bank is shut")


# ---------------------------------------------------------------- permanence, profile, Classic Rules

func test_tier_four_survives_downs_and_the_campaign_carry() -> void:
	_hold(4)
	PerkManager.grant(PID, &"marathon_malt")
	assert_true(PerkManager.is_permanent(PID, &"ledger_lager"))
	PerkManager.on_player_downed(PID)
	assert_eq(PerkManager.owned(PID), [&"ledger_lager"], "only the permanent tonic is left after a down")
	assert_eq(PerkManager.tier_of(PID, &"ledger_lager"), 4)
	assert_almost_eq(Economy.earn_mult(PID), 1.2, 0.0001, "and it still pays")
	PerkManager.on_player_downed(PID)   # a bleed-out and a respawn go through the same down
	assert_eq(PerkManager.tier_of(PID, &"ledger_lager"), 4)
	assert_eq(int(PerkManager.tiers(PID).get("ledger_lager", 0)), 4, "the campaign snapshot's perk_tiers hold IV")


func test_a_lower_tier_is_lost_on_a_down() -> void:
	_hold(3)
	PerkManager.on_player_downed(PID)
	assert_false(PerkManager.has_perk(PID, &"ledger_lager"))
	assert_almost_eq(Economy.earn_mult(PID), 1.0, 0.0001, "and its boost goes with it")


func test_the_profile_keeps_the_mastery_and_the_account() -> void:
	PerkManager.add_mastery(&"ledger_lager", 300)
	Economy.grant_raw(PID, 4000)
	BankAccount.deposit(PID, 4000)
	ProfileSave.save_profile()
	ProfileSave.profile = {}
	ProfileSave.load_profile()
	assert_eq(PerkManager.mastery(&"ledger_lager"), 300, "mastery with the tonic in your system is saved")
	assert_eq(BankAccount.balance(), 4000)


func test_classic_rules_keep_tier_one_only() -> void:
	_hold(1)
	GLSettings.values["classic_rules"] = true
	assert_eq(PerkManager.can_upgrade(PID, &"ledger_lager"), &"classic", "no tiers in Classic Rules")
	assert_almost_eq(Economy.earn_mult(PID), 1.2, 0.0001, "the base tonic still pays 20%")
	assert_almost_eq(BankAccount.rate_for(PID), 0.01, 0.00001)
	assert_eq(Economy.price_for(PID, 1000), 1000)
	assert_eq(BankAccount.closed_reason(), "classic")


func test_the_upgrade_path_charges_the_tier_price() -> void:
	_hold(1)
	Economy._scrip[PID] = 20000
	assert_eq(PerkManager.upgrade_for(PID, &"ledger_lager"), &"ok")
	assert_eq(PerkManager.tier_of(PID, &"ledger_lager"), 2)
	assert_eq(20000 - Economy.get_scrip(PID), 4000)
