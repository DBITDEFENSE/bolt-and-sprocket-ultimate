extends GutTest
## Round scaling formulas (docs/GDD.md §Rounds).

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/rounds.json")


func test_health_linear_until_round_9() -> void:
	assert_eq(RoundManager.zombie_health(1, cfg), 150)
	assert_eq(RoundManager.zombie_health(2, cfg), 250)
	assert_eq(RoundManager.zombie_health(9, cfg), 950)


func test_health_exponential_from_round_10() -> void:
	assert_eq(RoundManager.zombie_health(10, cfg), 1045)
	assert_eq(RoundManager.zombie_health(11, cfg), 1149)


func test_count_solo_and_coop() -> void:
	assert_eq(RoundManager.zombie_count(1, 1, cfg), 6)
	assert_gt(RoundManager.zombie_count(1, 4, cfg), RoundManager.zombie_count(1, 1, cfg))
	assert_gt(RoundManager.zombie_count(20, 1, cfg), RoundManager.zombie_count(10, 1, cfg))


func test_spawn_interval_floor() -> void:
	assert_almost_eq(RoundManager.spawn_interval(1, cfg), 2.0, 0.001)
	assert_almost_eq(RoundManager.spawn_interval(200, cfg), 0.25, 0.001)


func test_round_1_is_all_shamblers() -> void:
	assert_eq(RoundManager.speed_weights(1, cfg), {"shamble": 1.0})


func test_never_more_than_three_sprinters_in_a_row() -> void:
	var w: Dictionary = {"run": 0.0001, "sprint": 0.9999}
	assert_eq(RoundManager.pick_tier(w, 0.99, 2, 3), &"sprint")
	assert_eq(RoundManager.pick_tier(w, 0.99, 3, 3), &"run")


func test_sprinters_only_from_round_12() -> void:
	assert_false(RoundManager.speed_weights(11, cfg).has("sprint"))
	assert_true(RoundManager.speed_weights(12, cfg).has("sprint"))


func test_every_round_band_sums_to_one() -> void:
	for band: Dictionary in cfg["speed_tiers"]["bands"]:
		var total: float = 0.0
		for v: Variant in band["weights"].values():
			total += float(v)
		assert_almost_eq(total, 1.0, 0.001, "band from %d" % int(band["from"]))
