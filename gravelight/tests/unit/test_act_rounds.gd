extends GutTest
## Act-relative rounds (UPDATE 07, docs/MAP4_FERNFLUG.md §10): on an act map the act round is the match round minus
## the act's start plus one, standalone and after a campaign arrival; off act maps it is 0 and the HUD line is "".


func test_act_round_arithmetic() -> void:
	assert_eq(RoundManager.act_round_of(1, 1, true), 1, "standalone: round 1 is act round 1")
	assert_eq(RoundManager.act_round_of(15, 1, true), 15, "standalone: the turn is round 15")
	assert_eq(RoundManager.act_round_of(41, 41, true), 1, "arrived at round 41: act round 1")
	assert_eq(RoundManager.act_round_of(55, 41, true), 15, "arrived at 41: the turn is match round 55")
	assert_eq(RoundManager.act_round_of(12, 1, false), 0, "no act block: 0")
	assert_eq(ActController.match_round_of(13, 1), 13)
	assert_eq(ActController.match_round_of(13, 41), 53, "the boss's act round 13 is match round 53 after an arrival at 41")


func test_hangar_unlock_rule() -> void:
	assert_false(ActController.halle_due(5, 12, 0), "too early, no files")
	assert_true(ActController.halle_due(12, 12, 0), "the act round opens it")
	assert_true(ActController.halle_due(3, 12, 3), "the three files open it early")
	assert_false(ActController.halle_due(3, 12, 2), "two files are not enough")


func test_manager_helpers_off_an_act_map() -> void:
	var saved_act: Dictionary = RoundManager.act
	var saved_start: int = RoundManager.act_start
	RoundManager.act = {}
	assert_false(RoundManager.has_act())
	assert_eq(RoundManager.act_label(7), "")
	RoundManager.act = {"index": 1, "numeral": "I", "length_rounds": 14}
	RoundManager.act_start = 1
	assert_eq(RoundManager.act_label(7), "ACT I · 7")
	assert_eq(RoundManager.act_index(), 1)
	RoundManager.act = saved_act
	RoundManager.act_start = saved_start
