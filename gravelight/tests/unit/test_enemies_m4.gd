extends GutTest
## M4 enemies: special-round scheduling, Glasshide share, armor, Foreman health, Bellringer counts.

var rounds: Dictionary
var enemies: Dictionary


func before_all() -> void:
	rounds = GLData.load_json("res://data/gravelight/rounds.json")
	enemies = GLData.load_json("res://data/gravelight/enemies.json")["enemies"]


func test_first_special_round_is_5_or_6() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	var sr: Dictionary = rounds["special_round"]
	for i: int in 200:
		r.seed = i
		var first: int = r.randi_range(int(sr["first_min"]), int(sr["first_max"]))
		assert_between(first, 5, 6)


func test_special_gap_is_5_to_7() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	var sr: Dictionary = rounds["special_round"]
	for i: int in 200:
		r.seed = i
		var nxt: int = RoundManager.next_after(10, int(sr["interval_min"]), int(sr["interval_max"]), r)
		assert_between(nxt, 15, 17)


func test_round_manager_flags_special_round() -> void:
	RoundManager.start_game(1)
	RoundManager.next_special = 1
	RoundManager.advance_round()
	assert_true(RoundManager.is_special_round)
	assert_eq(RoundManager.round_total, RoundManager.bell_count(1, 1, rounds))
	assert_between(RoundManager.next_special, 6, 8)
	RoundManager.stop()


func test_bellringer_count_formula_and_cap() -> void:
	assert_eq(RoundManager.bell_count(6, 1, rounds), 6 + 3)
	assert_eq(RoundManager.bell_count(11, 2, rounds), 12 + 5)
	assert_eq(RoundManager.bell_count(80, 1, rounds), 30, "capped at 24 + 6p")


func test_glasshide_chance_gate_growth_cap() -> void:
	var g: Dictionary = enemies["glasshide"]
	assert_eq(RoundManager.glasshide_chance(14, g), 0.0)
	assert_almost_eq(RoundManager.glasshide_chance(15, g), 0.04, 0.0001)
	assert_almost_eq(RoundManager.glasshide_chance(21, g), 0.07, 0.0001)
	assert_almost_eq(RoundManager.glasshide_chance(60, g), 0.12, 0.0001)


func test_screamer_chance() -> void:
	var s: Dictionary = enemies["screamer"]
	assert_eq(RoundManager.screamer_chance(19, s), 0.0)
	assert_almost_eq(RoundManager.screamer_chance(20, s), 0.35, 0.0001)
	assert_almost_eq(RoundManager.screamer_chance(40, s), 0.75, 0.0001)


func test_foreman_health_scaling() -> void:
	var f: Dictionary = enemies["foreman"]
	assert_eq(RoundManager.foreman_health(12, 1, f), 30000)
	assert_eq(RoundManager.foreman_health(12, 2, f), 52500)
	assert_eq(RoundManager.foreman_health(14, 4, f), 113750)


func test_glasshide_config_and_torso_armor() -> void:
	var c: Dictionary = Zombie.kind_config(&"glasshide")
	assert_almost_eq(float(c["armor_mult"]), 0.5, 0.0001)
	assert_false(bool(c["can_crawl"]))
	assert_false(bool(c["bullet_stagger"]))
	assert_eq(int(c["damage"]), 60)
	assert_eq(int(c["tear_interval"] * 10), 12, "inherits Ganger keys it doesn't override")
	var z: Zombie = Zombie.new()
	add_child_autofree(z)
	var sp: ZombieSpawn = ZombieSpawn.new()
	sp.kind = &"ground"
	add_child_autofree(sp)
	z.activate({"enemy_id": &"glasshide", "tier": &"walk", "health": 1000.0}, sp, null)
	z.take_damage(100.0, &"torso", &"mp40", 0, &"bullet")
	assert_almost_eq(z.hp, 950.0, 0.01, "torso bullets do half")
	z.take_damage(100.0, &"torso", &"mp40", 0, &"bullet", true)
	assert_almost_eq(z.hp, 850.0, 0.01, "armor-piercing ignores the plate")
	z.take_damage(100.0, &"torso", &"frag", 0, &"explosive")
	assert_almost_eq(z.hp, 750.0, 0.01, "explosives ignore the plate")
	z.take_damage(100.0, &"head", &"mp40", 0, &"bullet")
	assert_almost_eq(z.hp, 650.0, 0.01, "head is unarmored")
	assert_false(z.is_crawler)


func test_bellringer_config() -> void:
	var c: Dictionary = Zombie.kind_config(&"bellringer")
	assert_almost_eq(float(c["speed"]), 5.4, 0.001)
	assert_eq(int(c["damage"]), 35)
	assert_eq(int(c["scrip"]["head"]), 110)
