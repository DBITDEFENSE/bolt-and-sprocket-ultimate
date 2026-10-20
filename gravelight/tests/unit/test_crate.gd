extends GutTest
## Lost Requisition Crate rules (WEAPONS.md §10).

var c: Dictionary


func before_all() -> void:
	c = GLData.load_json("res://data/gravelight/crate.json")


func _st(pulls: int, c_streak: int = 0, since_a: int = 0) -> Dictionary:
	return {"pulls": pulls, "c_streak": c_streak, "since_a": since_a, "since_wonder": 0}


func test_gentle_start_only_a_and_b() -> void:
	assert_eq(CrateManager.allowed_tiers(_st(0), c), PackedStringArray(["A", "B"]))
	assert_eq(CrateManager.allowed_tiers(_st(2), c), PackedStringArray(["A", "B"]))
	assert_eq(CrateManager.allowed_tiers(_st(3), c), PackedStringArray())


func test_dud_breaker_and_a_breaker() -> void:
	assert_eq(CrateManager.allowed_tiers(_st(6, 2, 1), c), PackedStringArray(["A", "B"]))
	assert_eq(CrateManager.allowed_tiers(_st(9, 0, 5), c), PackedStringArray(["A"]))


func test_never_rolls_held_weapon() -> void:
	for i: int in 200:
		var r: Dictionary = CrateManager.pick(c["pool"], ["ppsh41", "mg42_up"], PackedStringArray(), 0, randf())
		assert_ne(r["id"], &"ppsh41")
		assert_ne(r["id"], &"mg42")


func test_tier_filter_respected() -> void:
	for i: int in 200:
		var r: Dictionary = CrateManager.pick(c["pool"], [], PackedStringArray(["A", "B"]), 0, randf())
		assert_ne(str(r["tier"]), "C")


func test_wonder_bonus_grows_and_caps() -> void:
	assert_eq(CrateManager.wonder_bonus(5, c), 0)
	assert_eq(CrateManager.wonder_bonus(6, c), 1)
	assert_eq(CrateManager.wonder_bonus(60, c), 10)   # the weight itself is capped at 9 in pick()


func test_drummer_not_on_first_pull_or_early_at_location() -> void:
	CrateManager.reset_match()
	CrateManager.uses_until_move = 1
	CrateManager.location_index = 0
	CrateManager.uses_at_location = 0
	var first: Dictionary = CrateManager.roll(50, [])
	assert_ne(first["id"], CrateManager.DRUMMER, "never on a player's first pull")
	var second: Dictionary = CrateManager.roll(50, [])
	assert_ne(second["id"], CrateManager.DRUMMER, "never in the first 2 pulls at a location")
	var third: Dictionary = CrateManager.roll(50, [])
	assert_eq(third["id"], CrateManager.DRUMMER)


func test_move_picks_a_new_spot_and_sets_flag() -> void:
	CrateManager.reset_match()
	CrateManager.location_index = 1
	GameState.flags.erase(&"crate_has_moved")
	CrateManager.move(3)
	assert_ne(CrateManager.location_index, 1)
	assert_true(GameState.has_flag(&"crate_has_moved"))
	var u: int = CrateManager.uses_until_move
	assert_between(u, 4, 12)
