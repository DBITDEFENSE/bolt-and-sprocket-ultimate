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
	assert_true(BankBranch.branch_for("map02_totenhafen").is_empty())
	var people: Dictionary = (GLData.load_json("res://data/gravelight/art/people.json") as Dictionary).get("people", {})
	assert_true(people.has("teller"))
	var cast: Dictionary = (GLData.load_json("res://data/gravelight/vo/voice_cast.json") as Dictionary).get("cast", {})
	assert_true(cast.has("TEL"))
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	for c: String in ["BANK_GREET", "BANK_GREET_M1", "BANK_DEPOSIT", "BANK_WITHDRAW", "BANK_BROKE", "BANK_SCARED", "BANK_CLOSED"]:
		assert_true(lines.has("TEL_%s_01" % c), c)
