extends GutTest
## The stranded-zombie fail-safe (UPDATE 07 QA, T-107, rounds.json "stranded"): a chasing zombie whose path end
## stays far from every living player while nothing is left to spawn is relocated near the players, so a round
## cannot hang on a zombie that can't reach them (a crawler jammed at Kaltenbrunn's Admin door held round 12 for
## 140 minutes in the bot-mode soak). Pure rules here; the live relocation is exercised by smoke_map01.

var cfg: Dictionary


func before_all() -> void:
	cfg = GLData.table("rounds").get("stranded", {})


func test_data_is_there_and_sane() -> void:
	assert_false(cfg.is_empty(), "rounds.json has a stranded block")
	assert_between(float(cfg.get("seconds", 0.0)), 20.0, 120.0, "patience in seconds")
	assert_between(float(cfg.get("far_m", 0.0)), 3.0, 12.0, "how far from a player counts as unreachable")
	assert_between(float(cfg.get("check_every_s", 0.0)), 0.25, 5.0)


func test_due_only_when_nothing_is_left_to_spawn() -> void:
	assert_false(ZombieDirector.stranded_due(100.0, 3, cfg), "still spawning: never")
	assert_false(ZombieDirector.stranded_due(float(cfg["seconds"]) - 1.0, 0, cfg), "not long enough yet")
	assert_true(ZombieDirector.stranded_due(float(cfg["seconds"]), 0, cfg), "nothing to spawn and the path end far long enough")


func test_far_from_all_players() -> void:
	var players: Array = [Vector3(39.0, -12.0, 72.1), Vector3(50.0, -12.0, 76.4)]
	assert_true(ZombieDirector.far_from_all(Vector3(39.0, 0.5, 31.2), players, 6.0), "the yard corner is far from the Generator Hall (41 m and 12 m up)")
	assert_true(ZombieDirector.far_from_all(Vector3(39.0, 0.5, 72.1), players, 6.0), "right above them but 12 m up: far")
	assert_false(ZombieDirector.far_from_all(Vector3(42.0, -11.5, 73.0), players, 6.0), "3 m from Dutch: reachable")
	assert_true(ZombieDirector.far_from_all(Vector3.ZERO, [], 6.0), "nobody alive: far (the caller skips that case)")
