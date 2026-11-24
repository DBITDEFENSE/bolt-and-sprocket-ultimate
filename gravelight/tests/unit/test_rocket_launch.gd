extends GutTest
## T-276: the V2 launch at Map 0's site (RocketLaunch, map00.json "rocket_launch") and the site's layout
## (MapRocketGen, RocketSite). The pure rules: which rounds launch, what the main stage does to the dead and to a
## player, the climb; the data's timeline in order; the runtime's numbers agree with the generator's; the site's
## rects, gate and pockets hold together.

var cfg: Dictionary


func before_all() -> void:
	cfg = RocketLaunch.block_for(&"map00_crossroads")


func test_the_block_is_there() -> void:
	assert_false(cfg.is_empty(), "map00.json rocket_launch")
	for k: String in ["first_round", "every", "delay", "arm_down_at", "count_at", "ignite_at", "main_at", "liftoff_at", "kill_radius", "throw_radius", "fire"]:
		assert_true(cfg.has(k), k)


func test_launch_rounds() -> void:
	var c: Dictionary = {"first_round": 6, "every": 5}
	assert_false(RocketLaunch.is_launch_round(5, c))
	assert_true(RocketLaunch.is_launch_round(6, c))
	assert_false(RocketLaunch.is_launch_round(7, c))
	assert_true(RocketLaunch.is_launch_round(11, c))
	assert_true(RocketLaunch.is_launch_round(31, c))
	assert_true(RocketLaunch.is_launch_round(8, {"first_round": 8, "every": 0}), "every 0: once")
	assert_false(RocketLaunch.is_launch_round(13, {"first_round": 8, "every": 0}))


func test_the_timeline_runs_in_order() -> void:
	var order: Array = ["arm_down_at", "count_at", "ignite_at", "main_at", "liftoff_at"]
	for i: int in range(1, order.size()):
		assert_lt(float(cfg[order[i - 1]]), float(cfg[order[i]]), "%s before %s" % [order[i - 1], order[i]])
	assert_almost_eq(float(cfg["ignite_at"]) - float(cfg["count_at"]), 10.0, 0.01, "ten counted, then ignition")
	assert_lt(float(cfg["arm_down_at"]) + float(cfg["arm_down_seconds"]), float(cfg["count_at"]), "the arm is down before the count")


func test_the_blast_on_the_dead() -> void:
	assert_eq(RocketLaunch.blast_zombie(0.0, cfg), "kill")
	assert_eq(RocketLaunch.blast_zombie(float(cfg["kill_radius"]), cfg), "kill")
	assert_eq(RocketLaunch.blast_zombie(float(cfg["kill_radius"]) + 0.5, cfg), "throw")
	assert_eq(RocketLaunch.blast_zombie(float(cfg["throw_radius"]) + 0.5, cfg), "")


func test_the_blast_on_a_player() -> void:
	var r: float = float(cfg["player_radius"])
	var full: float = RocketLaunch.player_damage(0.0, cfg, false)
	assert_almost_eq(full, float(cfg["player_damage"]), 0.01)
	assert_lt(RocketLaunch.player_damage(r * 0.9, cfg, false), full, "falls off")
	assert_eq(RocketLaunch.player_damage(r + 0.1, cfg, false), 0.0, "nothing past the radius")
	assert_almost_eq(RocketLaunch.player_damage(1.0, cfg, true), RocketLaunch.player_damage(1.0, cfg, false) * 0.5, 0.01, "halved with Blastproof or Rocket Man")
	assert_lt(full, 100.0, "never a down from full health on its own")


func test_the_climb() -> void:
	assert_eq(RocketLaunch.climb_distance(0.0), 0.0)
	assert_lt(RocketLaunch.climb_distance(1.0), 1.0, "it leaves the table slowly")
	var prev: float = 0.0
	for s: float in [2.0, 5.0, 10.0, 15.0]:
		var d: float = RocketLaunch.climb_distance(s)
		assert_gt(d, prev, "it keeps accelerating")
		prev = d
	assert_gt(RocketLaunch.climb_distance(15.0), float(cfg.get("vanish_m", 380.0)), "out of sight within about 15 s")
	var low: Vector3 = RocketLaunch.path_point(15.0)
	assert_almost_eq(low.x, 0.0, 0.001, "straight up off the table")
	var high: Vector3 = RocketLaunch.path_point(380.0)
	assert_gt(high.x, 30.0, "pitching over toward the east")
	assert_gt(high.y, 250.0, "and still climbing")


func test_runtime_numbers_agree_with_the_generator() -> void:
	assert_eq(RocketSite.TABLE, MapRocketGen.TABLE)
	assert_almost_eq(RocketSite.TABLE_TOP, MapRocketGen.TABLE_TOP, 0.001)
	assert_almost_eq(RocketSite.HINGE_LOCAL, MapRocketGen.ERECTOR_HINGE - MapRocketGen.TABLE, Vector3(0.001, 0.001, 0.001))
	assert_almost_eq(RocketSite.LOX_LOCAL, MapRocketGen.LOX_TRAILER - MapRocketGen.TABLE, Vector3(0.001, 0.001, 0.001))
	var bunker_c: Vector2 = MapRocketGen.BUNKER_OUT.get_center() - Vector2(MapRocketGen.TABLE.x, MapRocketGen.TABLE.z)
	assert_almost_eq(Vector2(RocketSite.BUNKER_LOCAL.x, RocketSite.BUNKER_LOCAL.z), bunker_c, Vector2(0.01, 0.01))
	assert_almost_eq(V2Model.AXIS_OFF, -RocketSite.HINGE_LOCAL.x, 0.001, "the arm's clamps close on the rocket's axis")
	var table: Rect2 = Rect2(MapRocketGen.TABLE.x - MapRocketGen.TABLE_HALF, MapRocketGen.TABLE.z - MapRocketGen.TABLE_HALF, MapRocketGen.TABLE_HALF * 2.0, MapRocketGen.TABLE_HALF * 2.0)
	assert_true(MapRocketGen.SITE.encloses(table.grow(float(cfg["throw_radius"]) * 0.5)), "the table stands well inside the clearing")


func test_the_site_holds_together() -> void:
	var t: Rect2 = MapRocketGen.TRACK
	var s: Rect2 = MapRocketGen.SITE
	assert_almost_eq(t.position.x, 60.0, 0.001, "the track starts at the grounds' east fence")
	assert_almost_eq(t.end.x, s.position.x, 0.001, "and runs into the clearing")
	assert_true(t.has_point(Vector2(MapRocketGen.GATE.x + 0.1, MapRocketGen.GATE.z)), "the gate opens onto the track")
	assert_true(t.position.y < MapRocketGen.GATE.z - MapRocketGen.GATE_W * 0.5 and t.end.y > MapRocketGen.GATE.z + MapRocketGen.GATE_W * 0.5, "the track is wider than the gate")
	assert_true(MapRocketGen.ANNEX.encloses(Rect2(70.0, s.position.y, s.end.x - 70.0, s.size.y)), "the flat ground covers the clearing")
	for pk: Rect2 in MapRocketGen.pockets():
		assert_true(MapRocketGen.ANNEX.encloses(pk) or pk.position.x < 70.0, "pocket %s on the flat ground" % str(pk))
		assert_false(pk.intersects(t.grow(-0.01)) or pk.intersects(s.grow(-0.01)), "pocket %s outside the walls" % str(pk))
	for d: Rect2 in LandscapeTerrain.DEFAULT_ANNEX:
		assert_eq(d, MapRocketGen.ANNEX, "the terrain's hole is the site's slab")
		assert_eq(fmod(d.position.x, LandscapeTerrain.CELL), 0.0, "on the terrain lattice")
		assert_eq(fmod(d.size.y, LandscapeTerrain.CELL), 0.0)
	# the grounds' old edge pockets keep clear of the track (their navmesh must not join it)
	for gp: Rect2 in load("res://gravelight/tools_src/gen_map00.gd").edge_pockets():
		assert_false(gp.grow(0.5).intersects(t), "grounds pocket %s clear of the track" % str(gp))


func test_carve_trim() -> void:
	var r: Rect2 = Rect2(0, 0, 10, 10)
	var parts: Array[Rect2] = MapRocketGen.subtract(r, Rect2(3, 3, 2, 2))
	var area: float = 0.0
	for p: Rect2 in parts:
		area += p.get_area()
		assert_false(p.intersects(Rect2(3, 3, 2, 2)))
	assert_almost_eq(area, 96.0, 0.01, "r minus the hole")
	assert_eq(MapRocketGen.subtract(r, Rect2(20, 20, 1, 1)), [r] as Array[Rect2], "no overlap: unchanged")
