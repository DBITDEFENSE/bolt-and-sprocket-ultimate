extends GutTest
## Outside forces on the dead (UPDATE 07, T-105): Zombie.external_push (turbulence, suction, the Lodestone's
## fling: landing damage, the wall bonus, the kill plane), Zombie.lift / drop / slam (the Lodestone's well).

var _host: Node3D
var _spawn: ZombieSpawn
var _round_before: int


func before_each() -> void:
	seed(3)
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
	Zombie.kill_plane_y = -15.0


func after_each() -> void:
	RoundManager.current_round = _round_before


func _zombie(hp: float = 400.0) -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": hp, "variant": "villager"}, _spawn, null)
	z.global_position = Vector3(0, 0, 0)
	z._enter(Zombie.State.CHASE)
	return z


func test_push_sets_and_clears() -> void:
	var z: Zombie = _zombie()
	assert_false(z.is_pushed())
	z.external_push(Vector3(3, 0, 0), 0.5)
	assert_true(z.is_pushed())
	z._push_t = 0.0
	assert_false(z.is_pushed())


func test_fling_damage_on_landing_and_the_wall_bonus() -> void:
	var z: Zombie = _zombie(1000.0)
	z._state_t = 1.0
	z.external_push(Vector3(6, 0, 0), 0.4, 1, &"lodestone", 300.0)
	z._push_wall_hit = false
	z._end_push()
	assert_almost_eq(z.hp, 700.0, 0.5, "landing: the land damage")
	assert_true(z.state == Zombie.State.STAGGER or z.state == Zombie.State.KNOCKDOWN, "and a stagger or a knockdown (an explosive-kind hit over 8% knocks down)")
	var w: Zombie = _zombie(1000.0)
	w.external_push(Vector3(6, 0, 0), 0.4, 1, &"lodestone", 300.0)
	w._push_wall_hit = true
	w._end_push()
	assert_almost_eq(w.hp, 550.0, 0.5, "into a wall: x1.5")


func test_kill_plane_is_a_returned_kill_worth_100() -> void:
	var z: Zombie = _zombie(5000.0)
	var before: int = Economy.get_scrip(1)
	z.external_push(Vector3(0, -2, 0), 2.0, 1, &"lodestone", 100.0)
	z._state_t = 0.2
	z.global_position.y = -20.0
	z._update_push(0.016)
	assert_eq(z.state, Zombie.State.DEAD, "gone below the kill plane")
	assert_eq(Economy.get_scrip(1) - before, int(GLData.table("economy").get("returned_kill", 100)) + 50, "100 for the return plus the body kill")


func test_lift_holds_then_drops_with_a_stagger() -> void:
	var z: Zombie = _zombie(1000.0)
	z.lift(3.0, 0.5, 1, &"lodestone", 200.0, 900.0)
	assert_true(z.is_lifted())
	assert_eq(z.state, Zombie.State.LIFTED)
	for i: int in 30:
		z._update_lifted(0.016)
	assert_gt(z.global_position.y, 2.0, "held three metres up")
	for i: int in 10:
		z._update_lifted(0.016)   # past the hold: drop()
	assert_false(z.is_lifted())
	assert_almost_eq(z.global_position.y, 0.0, 0.01, "back on its feet height")
	assert_almost_eq(z.hp, 800.0, 0.5, "the drop damage")
	assert_true(z.state == Zombie.State.STAGGER or z.state == Zombie.State.KNOCKDOWN)


func test_slam_kills_and_the_wave_hurts_the_rest() -> void:
	var z: Zombie = _zombie(500.0)
	var other: Zombie = _zombie(500.0)
	other.global_position = Vector3(1.0, 0, 0)
	var far: Zombie = _zombie(500.0)
	far.global_position = Vector3(6.0, 0, 0)
	z.director = _FakeDirector.new([z, other, far])
	z.lift(3.0, 1.0, 1, &"lodestone", 100.0, 900.0, 2.0, 60.0)
	z.slam()
	assert_eq(z.state, Zombie.State.DEAD, "the slam kills a 500 hp zombie")
	assert_almost_eq(other.hp, 440.0, 0.5, "the 2 m wave: 60 to the neighbour")
	assert_almost_eq(far.hp, 500.0, 0.5, "out of the wave")


class _FakeDirector:
	extends Node
	var zs: Array = []
	func _init(list: Array) -> void:
		zs = list
	func active_zombies() -> Array[Zombie]:
		var out: Array[Zombie] = []
		for z: Variant in zs:
			out.append(z as Zombie)
		return out
