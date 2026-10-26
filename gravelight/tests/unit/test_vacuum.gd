extends GutTest
## The vacuum and the AIR gauge (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.2, T-112): a zone volume can be
## vacuum, an AirPost makes a circle of air in it, the gauge runs down in vacuum and refills in pressure, the
## `vacuum` status exists, and the Solar Flare picks the rim when the yard is open and the domes' points otherwise.

var _zone: ZoneVolume
var _post: AirPost


func before_each() -> void:
	_zone = ZoneVolume.new()
	_zone.zone_id = &"C_YARD"
	_zone.size = Vector3(20, 6, 20)
	_zone.vacuum = true
	add_child_autofree(_zone)
	_zone.global_position = Vector3(100, 0, 100)
	_post = AirPost.new()
	_post.radius = 2.0
	add_child_autofree(_post)
	_post.global_position = Vector3(104, 0, 100)


func after_each() -> void:
	GameState.vacuum_cfg = {}
	GameState.retained = false


func test_vacuum_at_and_air_posts() -> void:
	assert_true(ZoneVolume.vacuum_at(get_tree(), Vector3(100, 0.5, 100)), "inside the yard")
	assert_false(ZoneVolume.vacuum_at(get_tree(), Vector3(130, 0.5, 100)), "outside every volume")
	assert_true(AirPost.near(get_tree(), Vector3(104.5, 0.5, 100.5), 2.0), "at the post")
	assert_false(AirPost.near(get_tree(), Vector3(100, 0.5, 100), 2.0), "4 m away")
	assert_eq(AirPost.count_active(get_tree()), 1)
	_post.set_active(false)
	assert_false(AirPost.near(get_tree(), Vector3(104.5, 0.5, 100.5), 2.0), "a failed post gives no air")
	AirPost.set_all(get_tree(), true)
	assert_true(_post.active)


func test_air_runs_down_and_refills() -> void:
	assert_almost_eq(Player.air_after(25.0, 10.0, true, 25.0, 3.0), 15.0, 0.001, "10 s in vacuum")
	assert_almost_eq(Player.air_after(5.0, 10.0, true, 25.0, 3.0), 0.0, 0.001, "never below zero")
	assert_almost_eq(Player.air_after(0.0, 1.5, false, 25.0, 3.0), 12.5, 0.001, "half a refill in 1.5 s")
	assert_almost_eq(Player.air_after(24.0, 5.0, false, 25.0, 3.0), 25.0, 0.001, "capped at full")


func test_the_vacuum_status_is_defined() -> void:
	var st: Dictionary = GLData.table("enemies").get("status", {})
	assert_true(st.has("vacuum"), "enemies.json status.vacuum")
	assert_almost_eq(float((st["vacuum"] as Dictionary).get("move_mult", 0.0)), 1.0, 0.001, "no slow: the gauge is the cost")


func test_act_vacuum_rules() -> void:
	GameState.apply_act_physics(RoundManager.act_block_of(&"map04d_mondlicht"))
	var vc: Dictionary = GameState.vacuum_cfg
	assert_almost_eq(float(vc.get("air_seconds", 0.0)), 25.0, 0.001, "25 s of air")
	assert_almost_eq(float(vc.get("refill_seconds", 0.0)), 3.0, 0.001, "refilled in 3 s")
	assert_almost_eq(float(vc.get("damage_per_second", 0.0)), 20.0, 0.001, "20/s at zero")
	assert_almost_eq(float(vc.get("air_post_radius", 0.0)), 2.0, 0.001)
	assert_almost_eq(float(vc.get("bot_leave_air", 0.0)), 8.0, 0.001, "bots leave with 8 s left")


func test_solar_flare_points() -> void:
	var rim: Array = [[0, 0, 100], [10, 0, 100]]
	var fb: Dictionary = {"A_RECEPTION": [[0, 0, 5]], "B_CONCOURSE": [[0, 0, 40]]}
	var open_pts: Array = SolarFlare.wave_points(rim, true, fb, {&"A_RECEPTION": true})
	assert_eq(open_pts.size(), 2, "the yard open: the rim")
	assert_true(bool(open_pts[0][1]), "rim points are vacuum (the Suited)")
	var shut: Array = SolarFlare.wave_points(rim, false, fb, {&"A_RECEPTION": true})
	assert_eq(shut.size(), 1, "the yard shut: only the open domes' points")
	assert_false(bool(shut[0][1]), "pressurized: plain Gängers")
	assert_eq(SolarFlare.wave_points(rim, false, fb, {}).size(), 0)
