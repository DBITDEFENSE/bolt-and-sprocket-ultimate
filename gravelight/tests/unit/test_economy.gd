extends GutTest
## Scrip rules (docs/GDD.md §Economy).

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/economy.json")


func test_kill_values_by_limb() -> void:
	assert_eq(Economy.kill_value(&"torso", false, cfg), 50)
	assert_eq(Economy.kill_value(&"neck", false, cfg), 60)
	assert_eq(Economy.kill_value(&"head", false, cfg), 100)
	assert_eq(Economy.kill_value(&"head", true, cfg), 130)


func test_repair_cap() -> void:
	assert_eq(Economy.repair_value(0, cfg), 10)
	assert_eq(Economy.repair_value(495, cfg), 5)
	assert_eq(Economy.repair_value(500, cfg), 0)


func test_award_and_spend() -> void:
	Economy.reset([7])
	assert_eq(Economy.get_scrip(7), 500)
	Economy.award(7, 100)
	assert_eq(Economy.get_scrip(7), 600)
	assert_false(Economy.spend(7, &"thing", 1000))
	assert_true(Economy.spend(7, &"thing", 600))
	assert_eq(Economy.get_scrip(7), 0)


func test_double_scrip_multiplier() -> void:
	Economy.reset([8])
	Economy.multiplier = 2
	Economy.award(8, 50)
	assert_eq(Economy.get_scrip(8), 600)
	Economy.multiplier = 1


func test_repair_cap_per_round() -> void:
	Economy.reset([9])
	for i: int in 60:
		Economy.award_repair(9)
	assert_eq(Economy.get_scrip(9), 500 + 500)
