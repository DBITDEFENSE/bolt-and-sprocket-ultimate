extends GutTest
## T-185: an outside push is a speed, not an acceleration (the Kranich launch), and BoundsGuard's pure rules (the
## bounds from the navmesh, the verdicts, the downed and the exempt).

const PID: int = 1

var _floor: StaticBody3D


func before_each() -> void:
	GameState.player_ids = [PID]
	PerkManager.reset_match()
	_floor = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bs: BoxShape3D = BoxShape3D.new()
	bs.size = Vector3(200, 1, 200)
	cs.shape = bs
	_floor.add_child(cs)
	_floor.position = Vector3(0, -0.5, 0)
	add_child_autofree(_floor)


func after_each() -> void:
	PerkManager.reset_match()


func _player() -> Player:
	var p: Player = Player.new()
	p.player_id = PID
	add_child_autofree(p)
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	p.is_local = false
	p.is_bot = true   # driven by a MoveIntent (drive_bot: the shared movement code, no input actions in the test runner)
	p.global_position = Vector3(0, 0.05, 0)
	return p


func _step(p: Player) -> void:
	p.drive_bot(1.0 / 60.0, MoveIntent.new())


func test_push_removed_gives_the_own_velocity_back() -> void:
	var pv: Vector3 = Vector3(2, 0, 0)
	assert_eq(Player.push_removed(Vector3(2, 0, 0), Vector3(2, 0, 0), pv), Vector3.ZERO, "standing, a free move: nothing of your own")
	assert_eq(Player.push_removed(Vector3(-3, 0, 1), Vector3(-3, 0, 1), pv), Vector3(-5, 0, 1), "walking into it: your own speed back")
	assert_eq(Player.push_removed(Vector3(1, 0, 0), Vector3(1, 0, 0), pv), Vector3(-1, 0, 0), "walking against a stronger push")
	assert_eq(Player.push_removed(Vector3(2, 0, 0), Vector3(0, 0, 0), pv), Vector3.ZERO, "a wall that stopped it: no bounce back off it")
	assert_eq(Player.push_removed(Vector3(6, -0.5, 0), Vector3(3, 0, 0), Vector3(4, 0, 0)), Vector3(1, 0, 0), "half stopped: half of it taken back")


func test_a_held_push_never_builds_up() -> void:
	var p: Player = _player()
	await wait_physics_frames(3)
	var top: float = 0.0
	var top_y: float = 0.0
	for i: int in 60:
		p.external_push(Vector3(5, 0, 0), 0.3)   # the bomb-bay doors' throw, renewed every frame
		_step(p)
		top = maxf(top, Vector2(p.velocity.x, p.velocity.z).length())
		top_y = maxf(top_y, p.velocity.y)
		await wait_physics_frames(1)
	assert_lt(top, 0.5, "the body's own speed stays ~0 under a push (%.2f; it was 30 m/s before T-185)" % top)
	assert_lt(top_y, 0.1, "and nothing lifts it")
	assert_gt(p.global_position.x, 4.0, "the push still moves it: 5 m/s for a second (%.2f m)" % p.global_position.x)
	assert_lt(p.global_position.x, 5.6, "and not farther than 5 m/s for a second")


func test_a_push_lift_is_one_take_off() -> void:
	var p: Player = _player()
	await wait_physics_frames(3)
	p.external_push(Vector3(7, 3, 0), 0.5)   # the Moon's shaft grate: out and up
	assert_almost_eq(p.velocity.y, 3.0, 0.001, "the lift is the take-off speed")
	assert_eq(p.push_velocity().y, 0.0, "and no part of the push held every frame")
	var top: float = 0.0
	for i: int in 40:
		_step(p)
		top = maxf(top, p.global_position.y)
		await wait_physics_frames(1)
	assert_lt(top, 0.6, "a hop (%.2f m), not the 90 m/s launch it was" % top)


func test_derive_from_the_navmesh() -> void:
	var c: Dictionary = {"below_m": 8.0, "ceiling_m": 8.0, "edge_m": 15.0, "fall_extra_s": 1.5}
	var d: Dictionary = BoundsGuard.derive(Vector3(-80, 0, -2), Vector3(80, 3.4, 76), 2.8, -INF, 14.0, c)
	assert_almost_eq(float(d["kill_y"]), -8.0, 0.001)
	assert_almost_eq(float(d["ceiling_y"]), 3.4 + 2.8 + 8.0, 0.001)
	var r: Rect2 = d["rect"]
	assert_eq(r, Rect2(-95, -17, 190, 108))
	assert_almost_eq(float(d["max_fall_s"]), sqrt(2.0 * (14.2 + 8.0) / 14.0) + 1.5, 0.001)
	var moon: Dictionary = BoundsGuard.derive(Vector3(0, 0, 0), Vector3(10, 4, 10), 2.0, 20.0, 14.0 * 0.38, c)
	assert_almost_eq(float(moon["ceiling_y"]), 28.0, 0.001, "a launch plate's arc lifts the ceiling")
	assert_gt(float(moon["max_fall_s"]), float(BoundsGuard.derive(Vector3(0, 0, 0), Vector3(10, 4, 10), 2.0, 20.0, 14.0, c)["max_fall_s"]), "low gravity: longer falls")
	var o: Dictionary = BoundsGuard.derive(Vector3.ZERO, Vector3.ONE, 1.0, -INF, 14.0, {"kill_y": -70.0, "ceiling_y": 50.0, "max_fall_s": 9.0, "rect": [0, 0, 10, 20]})
	assert_eq(float(o["kill_y"]), -70.0, "per-map overrides")
	assert_eq(float(o["ceiling_y"]), 50.0)
	assert_eq(float(o["max_fall_s"]), 9.0)
	assert_eq(o["rect"], Rect2(0, 0, 10, 20))


func test_verdicts() -> void:
	var b: Dictionary = {"kill_y": -8.0, "ceiling_y": 14.0, "rect": Rect2(-95, -17, 190, 108), "max_fall_s": 3.0, "off_nav_s": 2.0}
	assert_eq(BoundsGuard.verdict(Vector3(0, 0, 10), 0.0, 0.0, false, b), &"", "on the deck: fine")
	assert_eq(BoundsGuard.verdict(Vector3(0, 13.9, 10), 0.0, 0.0, false, b), &"", "high, but under the ceiling")
	assert_eq(BoundsGuard.verdict(Vector3(0, 40, 10), 0.0, 0.0, false, b), &"above")
	assert_eq(BoundsGuard.verdict(Vector3(0, -9, 10), 0.0, 0.0, false, b), &"below")
	assert_eq(BoundsGuard.verdict(Vector3(200, 0, 10), 0.0, 0.0, false, b), &"outside")
	assert_eq(BoundsGuard.verdict(Vector3(0, 2, 10), 3.5, 0.0, false, b), &"falling")
	assert_eq(BoundsGuard.verdict(Vector3(0, 0, 10), 0.0, 2.5, false, b), &"off_nav")
	assert_eq(BoundsGuard.verdict(Vector3(0, 40, 10), 9.0, 9.0, true, b), &"", "a downed body: never for its fall, its crawl or a height")
	assert_eq(BoundsGuard.verdict(Vector3(0, -30, 10), 0.0, 0.0, true, b), &"below", "but brought back from under the floor")
	assert_true(BoundsGuard.off_nav_now(6.0, 5.0, false, true), "off the navmesh, outside every zone")
	assert_false(BoundsGuard.off_nav_now(6.0, 5.0, true, true), "inside a zone volume: walkable dressing, not off the map")
	assert_false(BoundsGuard.off_nav_now(3.0, 5.0, false, true), "close to the navmesh")
	assert_true(BoundsGuard.off_nav_now(6.0, 5.0, true, false), "a map without zone volumes: the distance alone")


func test_merged_cfg_map_overrides_world() -> void:
	var w: Dictionary = (GLData.table("world") as Dictionary).get("play_bounds", {})
	assert_false(w.is_empty(), "world.json has the defaults")
	for k: String in ["check_s", "below_m", "ceiling_m", "edge_m", "fall_extra_s", "off_nav_m", "off_nav_s"]:
		assert_true(w.has(k), "world.json play_bounds." + k)
	var m: Dictionary = BoundsGuard.merged_cfg(w, {"below_m": 30.0, "enabled": false})
	assert_eq(float(m["below_m"]), 30.0)
	assert_false(bool(m["enabled"]))
	assert_eq(float(m["edge_m"]), float(w["edge_m"]))


func test_check_brings_a_body_back_to_its_last_floor() -> void:
	var p: Player = _player()
	var g: BoundsGuard = BoundsGuard.new()
	add_child_autofree(g)
	g.set_physics_process(false)
	await wait_physics_frames(3)
	g.ready_done = true
	g.has_nav = false
	g.kill_y = -8.0
	g.ceiling_y = 14.0
	g.rect = Rect2(-50, -50, 100, 100)
	g.max_fall_s = 3.0
	for i: int in 5:
		_step(p)   # settle on the floor (is_on_floor)
		await wait_physics_frames(1)
	var before: int = g.rescues
	assert_eq(g.check(p, 0.25, false), &"", "standing on the floor")
	p.global_position = Vector3(3, 60, 4)
	p.velocity = Vector3(0, 25, 0)
	assert_eq(g.check(p, 0.25, false), &"above", "launched into the sky")
	assert_eq(g.rescues, before + 1)
	assert_lt(p.global_position.distance_to(Vector3(0, 0.05, 0)), 0.2, "back on the floor it stood on (%s)" % str(p.global_position))
	assert_eq(p.velocity, Vector3.ZERO, "still")
	assert_false(p.downed, "no down")
	assert_eq(p.hp, p.max_hp, "no damage")
	p.spectating = true
	p.global_position = Vector3(0, 60, 0)
	assert_eq(g.check(p, 0.25, false), &"", "a spectator is left alone")
	p.spectating = false
	p.noclip = true
	assert_eq(g.check(p, 0.25, false), &"", "so is noclip")
	p.noclip = false
	p.global_position = Vector3(0, 0.05, 0)
