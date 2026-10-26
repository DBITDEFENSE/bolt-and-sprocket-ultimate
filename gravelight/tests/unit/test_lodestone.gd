extends GutTest
## THE LODESTONE (UPDATE 07, T-105; docs/MAP4_FERNFLUG.md section 8): the data rows, the pure rules (the well, the
## damages, the fling's reach under gravity, target picking), and the scene rules on pooled zombies (lift, slam,
## fling, the kill plane, bosses never lifted).

var _host: Node3D
var _spawn: ZombieSpawn
var _dir: _FakeDirector
var _round_before: int


func before_each() -> void:
	seed(5)
	GLSettings.values["gore"] = "off"
	_round_before = RoundManager.current_round
	RoundManager.current_round = 10
	GameState.player_ids = [1]
	Economy.reset([1])
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)
	_dir = _FakeDirector.new()
	_dir.add_to_group(&"director")
	_host.add_child(_dir)


func after_each() -> void:
	RoundManager.current_round = _round_before


func _g(up: bool = false) -> Dictionary:
	var w: Dictionary = GLData.table("weapons")
	return (w["upgraded"]["lodestone_up"] if up else w["weapons"]["lodestone"])["gravity"]


func _zombie(at: Vector3, hp: float = 400.0) -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": hp, "variant": "villager"}, _spawn, null)
	z.global_position = at
	z._enter(Zombie.State.CHASE)
	z.director = _dir
	_dir.zs.append(z)
	return z


class _FakeDirector:
	extends Node
	var zs: Array = []
	func active_zombies() -> Array[Zombie]:
		var out: Array[Zombie] = []
		for z: Variant in zs:
			if is_instance_valid(z):
				out.append(z as Zombie)
		return out


# ---------------------------------------------------------------- data

func test_rows() -> void:
	var w: Dictionary = GLData.table("weapons")
	var row: Dictionary = w["weapons"]["lodestone"]
	assert_eq(str(row["class"]), "wonder")
	assert_eq(str(row["mode"]), "gravity")
	assert_true(bool(row["buildable"]))
	assert_eq(int(row["mag"]), 8)
	assert_eq(int(row["reserve"]), 24)
	assert_eq(int(row["wall_price"]), 0, "no wall ammo")
	assert_eq(str(row["upgraded"]), "lodestone_up")
	var up: Dictionary = w["upgraded"]["lodestone_up"]
	assert_eq(str(up["name"]), "Lodestone: Escape Velocity")
	assert_eq(int(up["mag"]), 12)
	assert_eq(int(up["reserve"]), 36)
	assert_almost_eq(float(_g(true)["pull_from_m"]), 10.0, 0.001)
	assert_eq(int(_g(true)["fling_chain"]), 2)
	var inst: WeaponInstance = WeaponInstance.create(&"lodestone")
	assert_eq(inst.weapon_class(), &"wonder")
	assert_eq(inst.mag, 8)
	assert_false(CrateManager.pool_ids().has("lodestone") if CrateManager.has_method("pool_ids") else false, "never in the crate")
	for part: String in ["ls_part_coil", "ls_part_cradle", "ls_part_lens"]:
		assert_true(BuildablePart.NAMES.has(StringName(part)), part)
	assert_eq(BuildablePart.buildable_of(&"ls_part_lens"), &"lodestone")
	assert_eq(BuildablePart.buildable_of(&"tg_part_bell"), &"totenglocke", "the Totenglocke's parts still resolve")
	assert_eq(BuildablePart.parts_of(&"lodestone").size(), 3)


# ---------------------------------------------------------------- pure rules

func test_well_geometry() -> void:
	var g: Dictionary = _g()
	var o: Vector3 = Vector3(0, 1.6, 0)
	assert_eq(Lodestone.well_center(o, Vector3.FORWARD, g, false), o + Vector3.FORWARD * 5.0, "5 m ahead from the hip")
	assert_eq(Lodestone.well_center(o, Vector3.FORWARD, g, true), o + Vector3.FORWARD * 7.0, "7 m aimed")
	assert_almost_eq(Lodestone.well_radius(g, false), 4.0, 0.001)
	assert_almost_eq(Lodestone.well_radius(g, true), 2.5, 0.001, "a tighter well aimed")
	assert_almost_eq(Lodestone.well_radius(_g(true), false), 6.0, 0.001, "Escape Velocity's wider well")


func test_damages_follow_the_round() -> void:
	var g: Dictionary = _g()
	var hr: float = float(RoundManager.zombie_health(10, GLData.table("rounds")))
	assert_almost_eq(Lodestone.slam_damage(hr, g), 2.2 * hr, 0.01, "a slam kills a Gänger of its round twice over")
	assert_almost_eq(Lodestone.drop_damage(hr, g), 0.8 * hr, 0.01)
	assert_almost_eq(Lodestone.fling_damage(hr, g), 1.0 * hr, 0.01)
	assert_almost_eq(Lodestone.slam_damage(hr, _g(true)), 2.8 * hr, 0.01)


func test_fling_reach_and_low_gravity() -> void:
	var g: Dictionary = _g()
	assert_almost_eq(Lodestone.fling_distance(g, 1.0), 12.0, 0.001)
	assert_almost_eq(Lodestone.fling_distance(g, 0.38), 30.0, 0.001, "the Moon: x2.5")
	assert_almost_eq(Lodestone.fling_distance(_g(true), 1.0), 18.0, 0.001)
	var v: Vector3 = Lodestone.fling_velocity(Vector3.FORWARD, 12.0, 1.0)
	assert_almost_eq(Vector2(v.x, v.z).length() * Lodestone.fling_seconds(1.0), 12.0, 0.01, "the velocity carries 12 m over the flight")
	assert_gt(v.y, 0.0, "with a lift")
	var vm: Vector3 = Lodestone.fling_velocity(Vector3.FORWARD, 30.0, 0.38)
	assert_gt(Lodestone.fling_seconds(0.38), Lodestone.fling_seconds(1.0), "a longer, slower arc in low gravity")
	assert_almost_eq(Vector2(vm.x, vm.z).length() * Lodestone.fling_seconds(0.38), 30.0, 0.01)
	assert_almost_eq(Lodestone.gravity_scale(), 1.0, 0.001, "no GameState.gravity_scale yet: 1 g")


func test_pick_targets_nearest_first_never_bosses_or_lifted() -> void:
	var zs: Array = [_zombie(Vector3(1, 0, 0)), _zombie(Vector3(3, 0, 0)), _zombie(Vector3(2, 0, 0)), _zombie(Vector3(9, 0, 0))]
	var picked: Array = Lodestone.pick_targets(zs, Vector3.ZERO, 4.0, 2)
	assert_eq(picked.size(), 2)
	assert_eq(picked[0], zs[0], "nearest first")
	assert_eq(picked[1], zs[2])
	(zs[0] as Zombie).lift(3.0, 1.0, 1, &"lodestone", 1.0, 1.0)
	var again: Array = Lodestone.pick_targets(zs, Vector3.ZERO, 4.0, 8)
	assert_eq(again.size(), 2, "a lifted zombie is skipped, the far one is out of the well")
	assert_false(again.has(zs[0]))


# ---------------------------------------------------------------- scene rules

func test_lift_then_slam_through_the_rules() -> void:
	var w: WeaponInstance = WeaponInstance.create(&"lodestone")
	var a: Zombie = _zombie(Vector3(0, 0, -5), 500.0)
	var b: Zombie = _zombie(Vector3(1.5, 0, -5), 500.0)
	var far: Zombie = _zombie(Vector3(0, 0, -20), 500.0)
	var res: Dictionary = Lodestone.resolve_lift(_host, Vector3(0, 1.6, 0), Vector3.FORWARD, w, 1, false)
	assert_eq((res["lifted"] as Array).size(), 2, "both in the well")
	assert_true(a.is_lifted())
	assert_true(b.is_lifted())
	assert_false(far.is_lifted())
	assert_almost_eq(a.vulnerability(), 1.5, 0.001, "limb x1.5 while lifted")
	for z: Zombie in res["lifted"]:
		z.slam()
	assert_eq(a.state, Zombie.State.DEAD, "the slam kills a round-10 zombie")
	assert_eq(b.state, Zombie.State.DEAD)
	assert_eq(far.state, Zombie.State.CHASE)


func test_fling_pushes_the_cone() -> void:
	var w: WeaponInstance = WeaponInstance.create(&"lodestone")
	var inside: Zombie = _zombie(Vector3(0, 0, -3), 5000.0)
	var beside: Zombie = _zombie(Vector3(-8, 0, -3), 5000.0)
	var res: Dictionary = Lodestone.resolve_fling(_host, Vector3(0, 1.6, 0), Vector3.FORWARD, w, 1)
	assert_eq(int(res["flung"]), 1, "only the cone")
	assert_true(inside.is_pushed())
	assert_false(beside.is_pushed())
	assert_almost_eq(inside._push_land_dmg, float(RoundManager.zombie_health(10, GLData.table("rounds"))), 0.5, "the landing damage waits")


func test_bots_lift_and_slam() -> void:
	var p: Player = Player.new()
	p.player_id = 1
	_host.add_child(p)
	p.set_physics_process(false)
	var w: WeaponInstance = WeaponInstance.create(&"lodestone")
	var a: Zombie = _zombie(Vector3(0, 0, -5), 300.0)
	var res: Dictionary = Lodestone.bot_lift(p, w, Vector3(0, 1.6, 0), Vector3.FORWARD)
	assert_eq(w.mag, 7, "one charge")
	assert_eq((res["lifted"] as Array).size(), 1)
	assert_eq(Lodestone.bot_slam(p, w, res), 1)
	assert_eq(a.state, Zombie.State.DEAD)
	assert_eq(Lodestone.bot_clump(p, w, Vector3(0, 1.6, 0), Vector3.FORWARD, [a]), 0, "a dead one no longer counts")
	p.queue_free()
