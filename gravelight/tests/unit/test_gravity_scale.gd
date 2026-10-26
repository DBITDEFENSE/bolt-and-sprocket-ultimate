extends GutTest
## Map 4 Act IV's gravity (UPDATE 07, docs/MAP4_FERNFLUG.md §6.2, T-112): one data source (world.json "gravity") scaled
## by GameState.gravity_scale, set from the act json; the Moon's 0.38 g makes a jump 2.6x higher with the jump
## velocity kept (jump_velocity_exponent 0), slides go farther by the act's multiplier, and a reset clears it all.


func after_each() -> void:
	GameState.gravity_scale = 1.0
	GameState.slide_distance_mult = 1.0
	GameState.vacuum_cfg = {}
	GameState.retained = false


func test_world_json_carries_the_gravity_block() -> void:
	var g: Dictionary = GLData.table("world").get("gravity", {})
	assert_almost_eq(float(g.get("player", 0.0)), 14.0, 0.001, "the survivors' 1 g rate (the old Player.GRAVITY)")
	assert_almost_eq(float(g.get("zombie", 0.0)), 18.0, 0.001, "the dead's 1 g rate (the old Zombie.GRAVITY)")
	assert_almost_eq(float(g.get("jump_velocity_exponent", 1.0)), 0.0, 0.001, "jump velocity is kept in low g")


func test_one_g_matches_the_old_constants() -> void:
	GameState.gravity_scale = 1.0
	assert_almost_eq(GameState.g_player(), Player.GRAVITY, 0.001)
	assert_almost_eq(GameState.g_zombie(), Zombie.GRAVITY, 0.001)
	assert_almost_eq(GameState.jump_mult(), 1.0, 0.001)


func test_the_moon_scales_every_body() -> void:
	GameState.apply_act_physics({"gravity_scale": 0.38, "slide_distance_mult": 1.4})
	assert_almost_eq(GameState.gravity_scale, 0.38, 0.001)
	assert_almost_eq(GameState.g_player(), 14.0 * 0.38, 0.001, "players and bots fall at 0.38 g")
	assert_almost_eq(GameState.g_zombie(), 18.0 * 0.38, 0.001, "the dead too")
	assert_almost_eq(GameState.slide_distance_mult, 1.4, 0.001, "slides 1.4x farther")
	assert_almost_eq(GameState.jump_mult(), 1.0, 0.001, "the take-off velocity is unchanged")


func test_jump_height_is_2_6x_on_the_moon() -> void:
	assert_almost_eq(GameState.jump_height_ratio(0.38, 0.0), 2.63, 0.02, "h = v^2 / 2g: 1/0.38")
	assert_almost_eq(GameState.jump_height_ratio(1.0, 0.0), 1.0, 0.001)
	assert_almost_eq(GameState.jump_height_ratio(0.38, -0.5), 6.93, 0.05, "the rejected 1/sqrt rule would hit every dome ceiling")


func test_apply_act_physics_defaults_and_clamps() -> void:
	GameState.apply_act_physics({})
	assert_almost_eq(GameState.gravity_scale, 1.0, 0.001, "no block: 1 g")
	assert_almost_eq(GameState.slide_distance_mult, 1.0, 0.001)
	assert_true(GameState.vacuum_cfg.is_empty())
	GameState.apply_act_physics({"gravity_scale": 0.0})
	assert_gt(GameState.gravity_scale, 0.0, "never zero g")


func test_reset_match_clears_the_act_physics() -> void:
	GameState.apply_act_physics({"gravity_scale": 0.38, "slide_distance_mult": 1.4, "vacuum": {"air_seconds": 25}})
	GameState.retained = true
	GameState.reset_match(&"map00_crossroads", "Crossroads Inn", &"TAPROOM")
	assert_almost_eq(GameState.gravity_scale, 1.0, 0.001)
	assert_almost_eq(GameState.slide_distance_mult, 1.0, 0.001)
	assert_true(GameState.vacuum_cfg.is_empty())
	assert_false(GameState.retained)


func test_the_moon_act_json_sets_0_38_g() -> void:
	var act: Dictionary = RoundManager.act_block_of(&"map04d_mondlicht")
	assert_almost_eq(float(act.get("gravity_scale", 1.0)), 0.38, 0.001, "map04d.json act.gravity_scale")
	assert_almost_eq(float(act.get("slide_distance_mult", 1.0)), 1.4, 0.001)
	assert_true((act.get("vacuum", {}) as Dictionary).has("air_seconds"), "the vacuum rules ride the act block")
	var other: Dictionary = RoundManager.act_block_of(&"map04b_kranich")
	assert_false(other.has("gravity_scale"), "the Kranich is 1 g")
