extends GutTest
## UPDATE 11 (T-192): the fourth-day rule, Hard Truth. The toggle and its defaults (on in the story rules, off in
## Classic Rules, the player's own on / off), who rises (squad members, humans and bots; never a companion, never once
## the match is lost), the dormant body (no hitboxes, no damage, no collision, net sub state 1, the puppet lies still
## too), the rise on the fourth second of round time (a break holds the clock), the death crate when the risen body is
## put down, and the respawn rules unchanged.

class FakeDirector:
	extends Node3D
	var spawn: ZombieSpawn
	var made: Array[Zombie] = []

	func _ready() -> void:
		spawn = ZombieSpawn.new()
		spawn.kind = &"ground"
		add_child(spawn)

	func rise_dormant(at: Vector3, variant: String, yaw: float) -> Zombie:
		var z: Zombie = Zombie.new()
		z.net_id = 40 + made.size()
		add_child(z)
		spawn.global_position = at
		z.activate({"enemy_id": "ganger", "tier": "shamble", "health": 300, "variant": variant}, spawn, null)
		z.rotation.y = yaw
		z.lie_dormant()
		made.append(z)
		return z


var _host: Node3D
var _dir: FakeDirector
var _ht: HardTruth
var _saved: Dictionary = {}
var _state_before: int
var _phase_before: int


func before_each() -> void:
	for k: String in ["hard_truth", "classic_rules", "gore"]:
		_saved[k] = GLSettings.values.get(k)
	GLSettings.values["gore"] = "full"
	GLSettings.values["classic_rules"] = false
	GLSettings.values["hard_truth"] = "auto"
	_state_before = RoundManager.state
	_phase_before = GameState.phase
	RoundManager.state = RoundManager.State.ROUND
	GameState.phase = GameState.Phase.PLAYING
	_host = Node3D.new()
	add_child_autofree(_host)
	_dir = FakeDirector.new()
	_host.add_child(_dir)
	_ht = HardTruth.new()
	_ht.director = _dir
	_ht.world = _host
	_host.add_child(_ht)
	_ht.set_physics_process(false)   # the test steps it


func after_each() -> void:
	for k: String in _saved.keys():
		GLSettings.values[k] = _saved[k]
	RoundManager.state = _state_before
	GameState.phase = _phase_before


func _ticks(seconds: float, step: float = 0.1) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		_ht.tick(step)
		t += step


# ------------------------------------------------------------------ the toggle

func test_the_setting_exists_and_defaults_to_auto() -> void:
	assert_eq(str(_saved["hard_truth"]), "auto", "Settings ships hard_truth = auto")
	assert_eq(HardTruth.MODES, PackedStringArray(["auto", "on", "off"]))
	assert_eq(HardTruth.MODE_LABELS.size(), HardTruth.MODES.size())


func test_auto_is_on_in_the_story_rules_and_off_in_classic_rules() -> void:
	assert_true(HardTruth.enabled_for({"hard_truth": "auto", "classic_rules": false}), "story rules: on by default")
	assert_false(HardTruth.enabled_for({"hard_truth": "auto", "classic_rules": true}), "Classic Rules: off by default")
	assert_true(HardTruth.enabled_for({}), "an old settings file without the key: the story default")
	assert_eq(HardTruth.mode_of({"hard_truth": "nonsense"}), "auto")


func test_on_and_off_are_the_players_call_in_either_mode() -> void:
	assert_true(HardTruth.enabled_for({"hard_truth": "on", "classic_rules": true}), "on in Classic Rules when asked")
	assert_false(HardTruth.enabled_for({"hard_truth": "off", "classic_rules": false}), "off in the story rules when asked")


func test_who_rises() -> void:
	assert_true(HardTruth.should_rise(true, false, false, true), "a squad member, rule on, match on")
	assert_false(HardTruth.should_rise(false, false, false, true), "rule off")
	assert_false(HardTruth.should_rise(true, true, false, true), "never a companion (Jakub is never a zombie)")
	assert_false(HardTruth.should_rise(true, false, true, true), "not once everyone is down (the match is over)")
	assert_false(HardTruth.should_rise(true, false, false, false), "not outside play")
	assert_true(HardTruth.is_squad_person("dutch") and HardTruth.is_squad_person("wren"))
	assert_false(HardTruth.is_squad_person("jakub"), "Jakub's body never rises")


func test_the_data() -> void:
	var c: Dictionary = HardTruth.cfg()
	assert_almost_eq(float(c.get("rise_delay_s", 0.0)), 4.0, 0.001, "the fourth second")
	assert_gt(int(c.get("crate_uses", 0)), 0)
	assert_gt(float(c.get("crate_seconds", 0.0)), 0.0)


# ------------------------------------------------------------------ the body

func test_a_dormant_body_lies_still_and_takes_nothing() -> void:
	_ht.begin(2, "peg", Vector3(3, 0, 1), 0.5)
	var z: Zombie = _ht.body_of(2)
	assert_not_null(z, "a body lies where she fell")
	assert_true(z.is_dormant())
	assert_eq(z.state, Zombie.State.GETUP, "held on the first frame of the get-up")
	assert_eq(z.net_sub_state(), 1, "a client's puppet lies still too")
	assert_eq(z.collision_layer, 0, "nobody trips over it")
	for hb: Hitbox in z._hitboxes:
		assert_eq(hb.collision_layer, 0, "no hitbox while it lies")
	assert_eq(z.marke_site, &"", "the squad were never marked")
	var hp0: float = z.hp
	assert_false(z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet"))
	assert_eq(z.hp, hp0, "no damage while it lies")
	assert_eq(int(z.get_meta(&"hard_truth_pid", -1)), 2)


func test_it_rises_on_the_fourth_second() -> void:
	_ht.begin(3, "deacon", Vector3.ZERO, 0.0)
	var z: Zombie = _ht.body_of(3)
	_ticks(3.9)
	assert_true(z.is_dormant(), "still lying at 3.9 s")
	assert_almost_eq(_ht.rise_left(3), 0.1, 0.02)
	_ticks(0.2)
	assert_false(z.is_dormant(), "up at 4 s")
	assert_eq(z.state, Zombie.State.GETUP, "getting up off the floor")
	assert_eq(z.net_sub_state(), 0)
	assert_eq(z.collision_layer, Zombie.LAYER_ZBODY)
	var live: int = 0
	for hb: Hitbox in z._hitboxes:
		if hb.collision_layer != 0:
			live += 1
	assert_gt(live, 0, "it can be shot once it rises")
	assert_eq(int(_ht.stats["rises"]), 1)
	assert_true(_ht.events.has("rise:3"))


func test_the_break_holds_the_clock() -> void:
	RoundManager.state = RoundManager.State.BREAK
	_ht.begin(2, "wren", Vector3.ZERO, 0.0)
	_ticks(10.0, 0.5)
	assert_true(_ht.body_of(2).is_dormant(), "a body that bled out in the break waits for the round")
	RoundManager.state = RoundManager.State.ROUND
	_ticks(4.1)
	assert_false(_ht.body_of(2).is_dormant())


func test_putting_it_down_drops_the_death_crate() -> void:
	_ht.begin(2, "dutch", Vector3(5, 0, -2), 0.0)
	var z: Zombie = _ht.body_of(2)
	_ticks(4.2)
	assert_false(z.is_dormant())
	assert_null(_ht.last_crate, "no crate before it is put down")
	z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
	assert_eq(z.state, Zombie.State.DEAD)
	_ht.tick(0.1)
	var c: FallenCrate = _ht.last_crate
	assert_not_null(c, "the death crate")
	assert_true(c.is_inside_tree())
	assert_eq(c.owner_name, "Dutch")
	assert_eq(c.uses_left, int(HardTruth.cfg()["crate_uses"]))
	assert_lt(c.global_position.distance_to(z.global_position), 3.0, "where the body fell")
	assert_true(c.is_in_group(&"squad_loot"), "the bots know it as free ammunition")
	assert_string_contains(c.box_name, "Dutch")
	assert_eq(int(_ht.stats["crates"]), 1)
	_ht.tick(0.1)
	assert_eq(int(_ht.stats["crates"]), 1, "one crate per body")
	assert_false(z.has_meta(&"hard_truth_pid"))


func test_a_pooled_body_is_a_plain_zombie_again() -> void:
	_ht.begin(2, "peg", Vector3.ZERO, 0.0)
	var z: Zombie = _ht.body_of(2)
	z.deactivate()
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 150, "variant": "soldier"}, _dir.spawn, null)
	assert_false(z.is_dormant(), "reuse clears the dormant hold")
	assert_false(z.has_meta(&"hard_truth_pid"), "and the tag")
	_ht.tick(0.1)
	assert_null(_ht.body_of(2), "the rule lets go of it")
	assert_null(_ht.last_crate, "no crate for a body that was never put down")


func test_the_puppet_follows_the_sub_state() -> void:
	var z: Zombie = Zombie.new()
	z.net_id = 77
	_host.add_child(z)
	var sp: ZombieSpawn = ZombieSpawn.new()
	_host.add_child(sp)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 150, "variant": "soldier"}, sp, null)
	z._puppet_enter(int(Zombie.State.GETUP), 1)
	assert_true(z.is_dormant(), "sub state 1: the puppet lies still")
	for hb: Hitbox in z._hitboxes:
		assert_eq(hb.collision_layer, 0)
	z._puppet_enter(int(Zombie.State.GETUP), 0)
	assert_false(z.is_dormant(), "sub state 0: it gets up on the client too")


# ------------------------------------------------------------------ respawn unchanged

func test_respawn_rules_do_not_change() -> void:
	var coop: CoopState = CoopState.new()
	coop.add(1)
	coop.add(2)
	coop.down(2, 0.5)
	var out: Array[int] = coop.tick(1.0)
	assert_eq(out, [2] as Array[int], "bled out")
	_ht.begin(2, "peg", Vector3.ZERO, 0.0)
	_ticks(4.2)
	assert_true(coop.is_dead(2), "still out for the round while the body walks")
	assert_eq(coop.respawn_dead(), [2] as Array[int], "back at the next round exactly as before")
	assert_true(coop.is_alive(2))
