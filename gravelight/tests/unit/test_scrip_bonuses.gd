extends GutTest
## In-match Scrip bonuses (T-078, docs/gravelight/ECONOMY.md): the pure rules on ScripBonuses, against the shipped
## economy.json numbers and against a fixed table, plus the ledger side (pay, has_account).

const PID: int = 42

var cfg: Dictionary


func before_all() -> void:
	cfg = (GLData.load_json("res://data/gravelight/economy.json") as Dictionary)["bonuses"]


func before_each() -> void:
	GameState.player_ids = [PID]
	Economy.reset([PID])
	Economy.bonuses.reset()


func after_all() -> void:
	GameState.player_ids = [1]
	Economy.reset([1])


func _fixed() -> Dictionary:
	return {
		"round_pay": {"base": 50, "per_round": 25, "max": 400},
		"clean_round": {"untouched": 100, "untouched_per_round": 10, "untouched_max": 250, "no_down": 50},
		"headshot_streak": {"every": 5, "base": 100, "step": 50, "max": 300},
		"salvage": {"chance": 0.07, "chance_late": 0.035, "late_from_round": 11, "value_base": 75, "value_per_round": 15,
			"value_max": 300, "max_alive": 6, "max_per_round": 4},
	}


func test_round_pay_grows_and_caps() -> void:
	var c: Dictionary = _fixed()
	assert_eq(ScripBonuses.round_pay(1, c), 75)
	assert_eq(ScripBonuses.round_pay(5, c), 175)
	assert_eq(ScripBonuses.round_pay(14, c), 400)
	assert_eq(ScripBonuses.round_pay(30, c), 400, "capped")
	assert_eq(ScripBonuses.round_pay(0, c), 0)
	assert_eq(ScripBonuses.round_pay(5, {}), 0, "no data, no pay")


func test_clean_round_parts() -> void:
	var c: Dictionary = _fixed()
	assert_eq(ScripBonuses.clean_bonus(5, false, false, c), [150, 50] as Array[int], "untouched and on their feet")
	assert_eq(ScripBonuses.clean_bonus(5, true, false, c), [0, 50] as Array[int], "hit, never down")
	assert_eq(ScripBonuses.clean_bonus(5, true, true, c), [0, 0] as Array[int], "went down")
	assert_eq(ScripBonuses.clean_bonus(5, false, true, c), [0, 0] as Array[int], "a down always counts as hit")
	assert_eq(ScripBonuses.clean_bonus(40, false, false, c)[0], 250, "untouched is capped")


func test_headshot_streak_pays_every_fifth() -> void:
	var c: Dictionary = _fixed()
	for s: int in [1, 2, 3, 4, 6, 9]:
		assert_eq(ScripBonuses.streak_bonus(s, c), 0, "streak %d" % s)
	assert_eq(ScripBonuses.streak_bonus(5, c), 100)
	assert_eq(ScripBonuses.streak_bonus(10, c), 150)
	assert_eq(ScripBonuses.streak_bonus(15, c), 200)
	assert_eq(ScripBonuses.streak_bonus(50, c), 300, "capped")


func test_salvage_chance_value_and_limits() -> void:
	var c: Dictionary = _fixed()
	assert_almost_eq(ScripBonuses.tag_chance(3, c), 0.07, 0.0001)
	assert_almost_eq(ScripBonuses.tag_chance(11, c), 0.035, 0.0001, "late rounds drop less often")
	assert_eq(ScripBonuses.tag_value(1, c), 90)
	assert_eq(ScripBonuses.tag_value(5, c), 150)
	assert_eq(ScripBonuses.tag_value(30, c), 300, "capped")
	assert_true(ScripBonuses.should_drop_tag(3, 0, 0, 0.05, c))
	assert_false(ScripBonuses.should_drop_tag(3, 0, 0, 0.08, c), "roll over the chance")
	assert_false(ScripBonuses.should_drop_tag(3, 4, 0, 0.0, c), "the round's limit")
	assert_false(ScripBonuses.should_drop_tag(3, 0, 6, 0.0, c), "the map's limit")


func test_shipped_numbers_keep_early_rounds_richer() -> void:
	# What a solo survivor can add by round 5 from round pay and a clean round each time: a sanity bound on the data.
	var sum: int = 0
	for r: int in range(1, 6):
		sum += ScripBonuses.round_pay(r, cfg)
		var cl: Array[int] = ScripBonuses.clean_bonus(r, false, false, cfg)
		sum += cl[0] + cl[1]
	assert_between(sum, 800, 2500, "rounds 1-5 round pay + clean rounds")
	assert_lt(ScripBonuses.round_pay(30, cfg), 1000, "late-round pay stays small next to kill Scrip")


func test_pay_grants_without_double_scrip_and_toasts() -> void:
	var got: Array = []
	var cb: Callable = func(p: int, kind: StringName, amount: int, label: String) -> void: got.append([p, kind, amount, label])
	GLBus.bonus_awarded.connect(cb)
	Economy.multiplier = 2
	var before: int = Economy.get_scrip(PID)
	Economy.bonuses.pay(PID, &"round_pay", 175, "ROUND 5 PAY")
	Economy.multiplier = 1
	GLBus.bonus_awarded.disconnect(cb)
	assert_eq(Economy.get_scrip(PID), before + 175, "no Double Scrip on a bonus")
	assert_eq(got.size(), 1)
	assert_eq(got[0][1], &"round_pay")
	assert_eq(got[0][3], "ROUND 5 PAY")


func test_headshot_streak_through_kill_events() -> void:
	var before: int = Economy.get_scrip(PID)
	for i: int in 4:
		GLBus.enemy_killed.emit(&"ganger", &"head", &"m1_garand", PID)
	GLBus.enemy_killed.emit(&"ganger", &"torso", &"m1_garand", PID)   # breaks it
	for i: int in 5:
		GLBus.enemy_killed.emit(&"ganger", &"head", &"m1_garand", PID)
	assert_eq(Economy.get_scrip(PID) - before, int(cfg["headshot_streak"]["base"]), "one streak of five paid, the broken one not")


func test_down_resets_the_streak() -> void:
	var before: int = Economy.get_scrip(PID)
	for i: int in 3:
		GLBus.enemy_killed.emit(&"ganger", &"head", &"m1_garand", PID)
	GLBus.player_downed.emit(PID)
	for i: int in 3:
		GLBus.enemy_killed.emit(&"ganger", &"head", &"m1_garand", PID)
	assert_eq(Economy.get_scrip(PID), before)


func test_accounts() -> void:
	assert_true(Economy.has_account(PID))
	assert_false(Economy.has_account(9), "Jakub keeps no ledger")
