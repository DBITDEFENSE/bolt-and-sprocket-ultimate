extends GutTest
## Groom Lake's dead (UPDATE 07, docs/MAP4_FERNFLUG.md §5.5; gravelight/world/map04/groom_controller.gd): the pure
## rules of the GroomController (the burrow points, the leap, the kind rolls, the Backorder gate, the rocket
## fallback), the GasCloud's tick, and a live Canary / Jumpjockey / Backorder on a pooled Gänger by console.

var _host: Node3D
var _spawn: ZombieSpawn
var _round_before: int
var _rng: RandomNumberGenerator


func before_each() -> void:
	seed(7)
	GLSettings.values["gore"] = "off"
	_round_before = RoundManager.current_round
	RoundManager.current_round = 5
	GameState.player_ids = [1]
	Economy.reset([1])
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)
	_rng = RandomNumberGenerator.new()
	_rng.seed = 11


func after_each() -> void:
	RoundManager.current_round = _round_before
	GameState.flags.erase(&"part_ls_part_coil")
	GameState.flags.erase(&"relay_coil_taken")
	GameState.flags.erase(&"rocket_ready")


func _cfg() -> Dictionary:
	return GLData.load_json("res://data/gravelight/map04c.json")["groom"]


func _zombie(hp: float = 400.0) -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": hp, "variant": "technician"}, _spawn, null)
	z.global_position = Vector3(0, 0, 0)
	z._enter(Zombie.State.CHASE)
	return z


func _controller() -> GroomController:
	var gc: GroomController = GroomController.new()
	_host.add_child(gc)
	gc.cfg = _cfg()
	return gc


# ---------------------------------------------------------------- pure rules

func test_burrow_point_is_near_the_player_and_inside_the_box() -> void:
	var box_min: Vector3 = Vector3(-60, 0, -4)
	var box_max: Vector3 = Vector3(60, 0, 60)
	for i: int in 40:
		var p: Vector3 = GroomController.burrow_point(Vector3(10, 0, 30), Vector3(0, 0, 20), _rng, 6.0, 12.0, box_min, box_max)
		var d: float = Vector2(p.x - 10.0, p.z - 30.0).length()
		assert_true(d >= 5.99 and d <= 12.01, "6..12 m away (%.2f)" % d)
		assert_true(p.x >= box_min.x and p.x <= box_max.x and p.z >= box_min.z and p.z <= box_max.z, "inside the lake bed")
	var edge: Vector3 = GroomController.burrow_point(Vector3(59, 0, 59), Vector3.ZERO, _rng, 11.0, 12.0, box_min, box_max)
	assert_true(edge.x <= 58.0 and edge.z <= 58.0, "clamped off the berm")


func test_leap_velocity_covers_the_distance_in_the_air_time() -> void:
	var v: Vector3 = GroomController.leap_velocity(Vector3.ZERO, Vector3(16, 0, 0), 1.6)
	assert_almost_eq(v.x, 10.0, 0.001, "16 m in 1.6 s")
	assert_almost_eq(v.y, 0.5 * 9.8 * 1.6, 0.001, "the rise that lands after 1.6 s")
	var capped: Vector3 = GroomController.leap_velocity(Vector3.ZERO, Vector3(0, 0, 60), 1.6)
	assert_almost_eq(capped.z, 14.0, 0.001, "capped at the max horizontal speed")
	assert_eq(GroomController.leap_velocity(Vector3.ZERO, Vector3.ZERO, 1.6).x, 0.0, "no distance, no flat velocity")


func test_kind_roll_respects_round_zone_chance_and_cap() -> void:
	var cc: Dictionary = _cfg()["canary"]
	assert_false(GroomController.kind_roll(cc, "F_LAB", 2, 0.0, 0), "before its act round")
	assert_true(GroomController.kind_roll(cc, "F_LAB", 3, 0.1, 0), "in the lab on act round 3 under the chance")
	assert_true(GroomController.kind_roll(cc, "C_HANGAR", 5, 0.1, 0), "the hangar too")
	assert_false(GroomController.kind_roll(cc, "B_LAKEBED", 5, 0.1, 0), "never on the salt")
	assert_false(GroomController.kind_roll(cc, "F_LAB", 5, 0.9, 0), "over the chance")
	assert_false(GroomController.kind_roll(cc, "F_LAB", 5, 0.1, int(cc["max_active"])), "at the cap")
	var jc: Dictionary = _cfg()["jumpjockey"]
	assert_true(GroomController.kind_roll(jc, "G_SILO", 4, 0.1, 0), "jumpjockeys in the silo from act round 4")
	assert_false(GroomController.kind_roll(jc, "G_SILO", 3, 0.1, 0))


func test_backorders_wait_for_the_relay_coil() -> void:
	var oc: Dictionary = _cfg()["backorder"]
	assert_false(GroomController.backorder_allowed(oc, 6, {}, 0), "no coil, no Backorders")
	assert_true(GroomController.backorder_allowed(oc, 5, {&"part_ls_part_coil": true}, 0), "the part flag")
	assert_true(GroomController.backorder_allowed(oc, 5, {&"relay_coil_taken": true}, 0), "the egg's flag")
	assert_false(GroomController.backorder_allowed(oc, 4, {&"part_ls_part_coil": true}, 0), "before act round 5")
	assert_false(GroomController.backorder_allowed(oc, 6, {&"part_ls_part_coil": true}, 2), "max two")


func test_rocket_fallback_on_the_last_act_round() -> void:
	assert_false(GroomController.rocket_fallback_due(8, 9, {}))
	assert_true(GroomController.rocket_fallback_due(9, 9, {}))
	assert_false(GroomController.rocket_fallback_due(9, 9, {&"rocket_ready": true}), "already ready: nothing to give")
	assert_true(GroomController.rocket_fallback_due(12, 9, {}), "and every round after")


func test_gas_cloud_tick() -> void:
	assert_almost_eq(GasCloud.tick_damage(15.0, 0.5), 7.5, 0.001)
	assert_eq(GasCloud.tick_damage(15.0, -1.0), 0.0, "never heals")


# ---------------------------------------------------------------- live kinds

func test_canary_is_tougher_and_hooded() -> void:
	var gc: GroomController = _controller()
	var z: Zombie = _zombie(400.0)
	gc.make("canary", z)
	assert_eq(str(z.get_meta("groom", "")), "canary")
	assert_almost_eq(z.max_hp, 520.0, 0.01, "health x1.3")
	assert_almost_eq(z.armor_torso_mult, 1.5, 0.001, "torso x1.5: body shots are the clean kill")
	assert_true(z.has_meta("groom_hood"), "a hood on the head")
	assert_eq(int(gc.counts["canary"]), 1)
	gc.make("canary", z)
	assert_eq(int(gc.counts["canary"]), 1, "never tagged twice")


func test_jumpjockey_leaps_when_told() -> void:
	var gc: GroomController = _controller()
	var z: Zombie = _zombie(400.0)
	gc.make("jumpjockey", z)
	assert_almost_eq(z.max_hp, 480.0, 0.01, "health x1.2")
	assert_true(z.has_meta("groom_rig"))
	gc.leap(z, Vector3(12, 0, 0))
	assert_true(z.is_pushed(), "the leap is an outside push")
	assert_true(bool(gc.jj[z]["airborne"]))
	assert_almost_eq(float(gc.jj[z]["cd"]), float(_cfg()["jumpjockey"]["cooldown"]), 0.001, "the cooldown restarts")


func test_backorder_phases_and_solidifies() -> void:
	var gc: GroomController = _controller()
	var z: Zombie = _zombie(400.0)
	gc.make("backorder", z)
	assert_true(bool(gc.bo[z]["phased"]), "born phased")
	assert_eq(z.collision_layer, 0, "no body collision while phased")
	assert_false(z.is_physics_processing(), "the controller moves it")
	for hb: Hitbox in z._hitboxes:
		assert_eq(hb.collision_layer, 0, "immune while phased")
	assert_true(z.has_meta("groom_stamp"))
	gc._set_phased(z, false)
	assert_eq(z.collision_layer, Zombie.LAYER_ZBODY, "solid: the body is back")
	assert_true(z.is_physics_processing())
	var on: int = 0
	for hb2: Hitbox in z._hitboxes:
		if hb2.collision_layer == Hitbox.LAYER_HITBOX:
			on += 1
	assert_gt(on, 0, "solid: the hitboxes are back")
	assert_eq(z.tier, &"walk", "slow")


func test_untag_frees_the_costume() -> void:
	var gc: GroomController = _controller()
	var z: Zombie = _zombie(400.0)
	gc.make("canary", z)
	gc._untag(z)
	assert_false(z.has_meta("groom"))
	assert_false(gc.tagged.has(z))
