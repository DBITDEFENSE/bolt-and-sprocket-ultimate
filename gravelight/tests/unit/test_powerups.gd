extends GutTest
## Power-up drop logic (GDD §11, D-010). Pure static functions on PowerupManager.

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.load_json("res://data/gravelight/powerups.json")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_bag_cycles_all_types_before_repeats() -> void:
	var r: RandomNumberGenerator = _rng(42)
	var source: Array = cfg["bag"]
	var bag: Array[StringName] = []
	var drawn: Array[StringName] = []
	for i: int in source.size():
		drawn.append(PowerupManager.draw_from_bag(bag, source, [], r))
	# One full cycle = exactly the bag's contents.
	var expected: Array = source.duplicate()
	expected.sort()
	var got: Array = []
	for d: StringName in drawn:
		got.append(String(d))
	got.sort()
	assert_eq(got, expected)
	# Every distinct type appeared in that cycle.
	var distinct: Dictionary = {}
	for d: StringName in drawn:
		distinct[d] = true
	assert_eq(distinct.size(), 5)


func test_clearance_absent_until_crate_moves() -> void:
	assert_eq(PowerupManager.conditional_extras(cfg, {}).size(), 0)
	assert_eq(PowerupManager.conditional_extras(cfg, {&"crate_has_moved": false}).size(), 0)
	var extra: Array[StringName] = PowerupManager.conditional_extras(cfg, {&"crate_has_moved": true})
	assert_eq(extra, [&"clearance"] as Array[StringName])
	assert_false((cfg["bag"] as Array).has("clearance"))


func test_clearance_joins_bag_when_flag_set() -> void:
	var r: RandomNumberGenerator = _rng(7)
	var bag: Array[StringName] = []
	var seen: Dictionary = {}
	var extra: Array[StringName] = PowerupManager.conditional_extras(cfg, {&"crate_has_moved": true})
	for i: int in (cfg["bag"] as Array).size() + extra.size():
		seen[PowerupManager.draw_from_bag(bag, cfg["bag"], extra, r)] = true
	assert_true(seen.has(&"clearance"))


func test_threshold_growth() -> void:
	assert_almost_eq(PowerupManager.threshold_after(0, cfg), 2000.0, 0.01)
	assert_almost_eq(PowerupManager.threshold_after(1, cfg), 2280.0, 0.01)
	assert_almost_eq(PowerupManager.threshold_after(3, cfg), 2000.0 * pow(1.14, 3), 0.01)


func test_max_per_round_respected() -> void:
	var max_n: int = int(cfg["max_per_round"])
	assert_true(PowerupManager.should_drop(true, max_n - 1, cfg, 0.0))
	assert_false(PowerupManager.should_drop(true, max_n, cfg, 0.0))
	assert_false(PowerupManager.should_drop(false, max_n, cfg, 0.0))


func test_eligibility_and_base_chance() -> void:
	# Eligible kills always drop (chance 1.0); otherwise only the 2% base roll.
	assert_true(PowerupManager.should_drop(true, 0, cfg, 0.99))
	assert_true(PowerupManager.should_drop(false, 0, cfg, 0.01))
	assert_false(PowerupManager.should_drop(false, 0, cfg, 0.5))


func test_timed_types() -> void:
	assert_true(PowerupManager.is_timed(&"double_scrip", cfg))
	assert_true(PowerupManager.is_timed(&"deaths_door", cfg))
	assert_false(PowerupManager.is_timed(&"blackout", cfg))
