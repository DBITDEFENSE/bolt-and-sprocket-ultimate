extends GutTest
## T-177: the squad bots and the companions shop for themselves: the bank (their own match-only accounts), the
## Armorer's Bench (one part per slot), tonics and the Crucible (companions with their own Scrip).

const BOT: int = 902


func before_each() -> void:
	BankAccount.reset_bots()
	GLSettings.values["classic_rules"] = false


func after_all() -> void:
	BankAccount.reset_bots()


func test_bot_plan() -> void:
	# keep reserve + the next thing in the pocket, bank the rest (at least min_move)
	assert_eq(BankAccount.bot_plan(9000, 0, 2500, 1000, 1000), 5500, "banks all but reserve + the next tonic")
	assert_eq(BankAccount.bot_plan(4000, 0, 2500, 1000, 1000), 0, "under min_move over: stays in the pocket")
	assert_eq(BankAccount.bot_plan(9000, 0, 0, 1000, 1000), 8000, "nothing wanted: all but the reserve")
	# take out what makes the next thing affordable, never a part payment
	assert_eq(BankAccount.bot_plan(200, 20000, 2500, 1000, 1000), -3300, "out comes reserve + price - pocket")
	assert_eq(BankAccount.bot_plan(200, 1000, 2500, 1000, 1000), 0, "the bank can't cover it: it stays saved")
	assert_eq(BankAccount.bot_plan(200, 20000, 0, 1000, 1000), 0, "nothing wanted: nothing taken out")


func test_bot_accounts_are_not_the_profile() -> void:
	var prof0: int = BankAccount.balance()
	Economy.grant_raw(BOT, 5000)
	var s0: int = Economy.get_scrip(BOT)
	assert_eq(BankAccount.bot_deposit(BOT, 3000), 3000)
	assert_eq(BankAccount.bot_balance(BOT), 3000)
	assert_eq(Economy.get_scrip(BOT), s0 - 3000, "out of the pocket")
	assert_eq(BankAccount.balance(), prof0, "the human's profile savings never move")
	assert_eq(BankAccount.bot_withdraw(BOT, 5000), 3000, "at most the balance")
	assert_eq(Economy.get_scrip(BOT), s0)
	assert_eq(BankAccount.bot_deposit(BOT, 999999), s0, "at most the pocket")
	assert_gt(BankAccount.accrue_bots(), 0, "interest at a round start")
	assert_gt(BankAccount.bot_balance(BOT), s0)
	Economy.reset([1])
	assert_eq(BankAccount.bot_balance(BOT), 0, "a new match: the bots' savings are gone")


func test_classic_rules_shut_the_bots_bank() -> void:
	GLSettings.values["classic_rules"] = true
	Economy.grant_raw(BOT, 5000)
	assert_eq(BankAccount.bot_deposit(BOT, 1000), 0)
	GLSettings.values["classic_rules"] = false


func test_one_part_per_slot() -> void:
	var rows: Array = [
		{"slot": "sights", "option": "radium", "installed": true, "price": 600, "reason": ""},
		{"slot": "sights", "option": "aperture", "installed": false, "price": 750, "reason": ""},
		{"slot": "mag", "option": "extended", "installed": false, "price": 1250, "reason": ""},
	]
	var open: Array = BotEconomy.bench_rows_open(rows)
	assert_eq(open.size(), 1, "a fitted slot is never swapped (the radium / aperture loop)")
	assert_eq(str((open[0] as Dictionary)["slot"]), "mag")


func test_data() -> void:
	var eco: Dictionary = BotAIData.table("economy")
	assert_false((eco.get("bench", {}) as Dictionary).is_empty(), "economy.json bench")
	assert_false((eco.get("bank", {}) as Dictionary).is_empty(), "economy.json bank")
	var pr: Dictionary = eco.get("priorities", {})
	assert_lt(float(pr.get("bench", 1.0)), float(pr.get("perk", 0.0)), "tonics before parts")
	assert_lt(float(pr.get("bank", 1.0)), float(pr.get("bench", 0.0)), "parts before banking")
	var mc: Dictionary = (GLData.load_json("res://data/gravelight/companions.json") as Dictionary).get("brain", {})
	assert_true(bool(mc.get("shopping", false)) and bool(mc.get("perks", false)), "the map companions shop")
