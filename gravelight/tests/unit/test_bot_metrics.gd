extends GutTest
## The bot metrics logger's rules (Update 03 sections 0 and 9, gravelight/bots/bot_metrics.gd): blocking
## detection, the stuck-time threshold, revive success accounting, purchase categories and the wasted-Scrip rules.


# ---------------------------------------------------------------- blocking

func test_blocking_needs_the_bubble_and_a_moving_human() -> void:
	var h: Vector3 = Vector3(0, 0, 0)
	assert_true(BotMetrics.blocking(Vector3(0.8, 0, 0.5), h, 3.0), "0.94 m from a walking human")
	assert_false(BotMetrics.blocking(Vector3(1.3, 0, 0), h, 3.0), "outside 1.2 m")
	assert_false(BotMetrics.blocking(Vector3(0.5, 0, 0), h, 0.8), "the human is standing still (<= 1 m/s)")
	assert_false(BotMetrics.blocking(Vector3(0.5, 3.0, 0), h, 3.0), "a floor apart")


func _feed(st: Dictionary, cond: bool, seconds: float, dt: float = 1.0 / 60.0) -> Vector2i:
	var total: Vector2i = Vector2i.ZERO
	var n: int = roundi(seconds / dt)
	for i: int in n:
		total += BotMetrics.block_step(st, cond, dt)
	return total


func test_a_brush_is_not_an_event() -> void:
	var st: Dictionary = {}
	assert_eq(_feed(st, true, 0.4), Vector2i(0, 0), "0.4 s inside: nothing")
	assert_eq(_feed(st, false, 0.1), Vector2i(0, 0))
	assert_eq(_feed(st, true, 0.4), Vector2i(0, 0), "the break reset the episode")


func test_one_event_per_half_second_and_sustained_past_two_seconds() -> void:
	var st: Dictionary = {}
	var r: Vector2i = _feed(st, true, 1.6)
	assert_eq(r.x, 3, "1.6 s = three half seconds")
	assert_eq(r.y, 0, "not sustained yet")
	r = _feed(st, true, 0.6)
	assert_eq(r.x, 1, "2.2 s: the fourth")
	assert_eq(r.y, 1, "past 2 s: one sustained event")
	r = _feed(st, true, 3.0)
	assert_eq(r.y, 0, "one sustained event per episode")
	assert_eq(r.x, 6)
	_feed(st, false, 0.1)
	r = _feed(st, true, 2.5)
	assert_eq(r, Vector2i(5, 1), "a new episode after a break counts again")


# ---------------------------------------------------------------- stuck time and empty mags

func test_stuck_time_counts_only_stretches_past_half_a_second() -> void:
	var dt: float = 0.1
	var total: float = 0.0
	var run: float = 0.0
	for i: int in 4:   # 0.4 s: a hitch, nothing
		run += dt
		total += BotMetrics.stuck_credit(run, dt)
	assert_almost_eq(total, 0.0, 0.0001)
	for i: int in 6:   # on to 1.0 s: all of it counts once past 0.5
		run += dt
		total += BotMetrics.stuck_credit(run, dt)
	assert_almost_eq(total, 1.0, 0.0001)


func test_empty_mag_moment() -> void:
	assert_true(BotMetrics.empty_mag_moment(0, 4.0))
	assert_false(BotMetrics.empty_mag_moment(0, 7.0), "nothing within 6 m")
	assert_false(BotMetrics.empty_mag_moment(3, 1.0), "rounds in the mag")


# ---------------------------------------------------------------- revives

func test_revive_success_accounting() -> void:
	var eps: Array = [
		{"pid": 2, "t_down": 10.0, "outcome": "revived", "t_end": 16.0, "attempts": 1, "attempts_ok": 1},
		{"pid": 3, "t_down": 20.0, "outcome": "revived", "t_end": 30.0, "attempts": 2, "attempts_ok": 1},
		{"pid": 4, "t_down": 40.0, "outcome": "bled", "t_end": 85.0, "attempts": 1, "attempts_ok": 0},
		{"pid": 2, "t_down": 80.0, "outcome": "pending", "t_end": -1.0, "attempts": 0, "attempts_ok": 0},   # 20 s old: failed
		{"pid": 1, "t_down": 97.0, "outcome": "pending", "t_end": -1.0, "attempts": 0, "attempts_ok": 0},   # the wipe: not judged
	]
	var s: Dictionary = BotMetrics.revive_summary(eps, 100.0)
	assert_eq(int(s["downs"]), 5)
	assert_eq(int(s["revived"]), 2)
	assert_eq(int(s["bled"]), 1)
	assert_eq(int(s["pending"]), 2)
	assert_eq(int(s["pending_failed"]), 1)
	assert_almost_eq(float(s["success_rate"]), 0.5, 0.0001, "2 revived of 4 judged")
	assert_almost_eq(float(s["ttr_mean"]), 8.0, 0.0001, "(6 + 10) / 2")
	assert_eq(int(s["attempts"]), 4)
	assert_eq(int(s["attempts_ok"]), 2)


func test_revive_summary_of_nothing() -> void:
	var s: Dictionary = BotMetrics.revive_summary([], 50.0)
	assert_eq(int(s["downs"]), 0)
	assert_eq(float(s["success_rate"]), 0.0)
	assert_eq(float(s["ttr_mean"]), 0.0)


# ---------------------------------------------------------------- purchases

func test_purchase_categories_from_item_ids() -> void:
	var perks: Dictionary = {"ironhide_stout": {}, "second_wind": {}}
	var weapons: Dictionary = {"kar98k": {}, "thompson": {}}
	var upgraded: Dictionary = {"thompson_up": {}}
	assert_eq(BotMetrics.category_of("ironhide_stout", perks, weapons, upgraded), "perk")
	assert_eq(BotMetrics.category_of("kar98k", perks, weapons, upgraded), "wall_gun")
	assert_eq(BotMetrics.category_of("thompson_ammo", perks, weapons, upgraded), "ammo")
	assert_eq(BotMetrics.category_of("thompson_box_ammo", perks, weapons, upgraded), "ammo_box")
	assert_eq(BotMetrics.category_of("ammo_box_grenades", perks, weapons, upgraded), "ammo_box")
	assert_eq(BotMetrics.category_of("thompson_up_ammo", perks, weapons, upgraded), "crucible", "upgraded ammo")
	assert_eq(BotMetrics.category_of("crucible", perks, weapons, upgraded), "crucible")
	assert_eq(BotMetrics.category_of("crate", perks, weapons, upgraded), "crate")
	assert_eq(BotMetrics.category_of("door_stable", perks, weapons, upgraded), "door")
	assert_eq(BotMetrics.category_of("pylon_a", perks, weapons, upgraded), "pylon")
	assert_eq(BotMetrics.category_of("something_else", perks, weapons, upgraded), "other")


func test_category_of_the_real_tables() -> void:
	var w: Dictionary = GLData.table("weapons")
	var perks: Dictionary = GLData.table("perks").get("perks", {})
	assert_false(perks.is_empty(), "perks.json has a perks table")
	for pid: Variant in perks.keys():
		assert_eq(BotMetrics.category_of(str(pid), perks, w["weapons"], w["upgraded"]), "perk", str(pid))
	assert_eq(BotMetrics.category_of("mp40", perks, w["weapons"], w["upgraded"]), "wall_gun")


func test_gun_quality() -> void:
	assert_eq(BotMetrics.gun_quality("kar98k", {"class": "bolt", "wall_price": 200}, false), 200.0)
	assert_eq(BotMetrics.gun_quality("m1911", {"class": "pistol", "wall_price": 0}, false), 0.0)
	assert_eq(BotMetrics.gun_quality("mg42", {"class": "lmg", "wall_price": 0}, false), 1500.0, "crate-only guns rank high")
	assert_eq(BotMetrics.gun_quality("thompson_up", {}, true), 5000.0)


func test_waste_rules() -> void:
	var q: Dictionary = {"m1911": 0.0, "kar98k": 200.0, "m1_garand": 600.0, "mp40": 1000.0, "thompson": 1200.0, "trench_gun": 1500.0}
	assert_eq(BotMetrics.gun_waste_rule("kar98k", 11, ["m1911"], -1, q), "late_weak", "a Kar98k after round 10")
	assert_eq(BotMetrics.gun_waste_rule("kar98k", 10, ["m1911"], -1, q), "", "round 10 itself is fine")
	assert_eq(BotMetrics.gun_waste_rule("mp40", 6, ["m1911", "thompson"], -1, q), "worse", "worse than the Thompson it carries")
	assert_eq(BotMetrics.gun_waste_rule("trench_gun", 6, ["m1911", "thompson"], -1, q), "", "an upgrade")
	assert_eq(BotMetrics.gun_waste_rule("m1_garand", 4, ["m1911", "kar98k"], 6, q), "dropped", "gone 2 rounds later")
	assert_eq(BotMetrics.gun_waste_rule("m1_garand", 4, ["m1911", "kar98k"], 7, q), "", "kept 3 rounds")
	assert_eq(BotMetrics.gun_waste_rule("thompson", 4, ["m1911", "thompson"], -1, q), "", "a rebuy of the held gun isn't 'worse'")
	assert_eq(BotMetrics.gun_waste_rule("kar98k", 12, ["thompson"], 12, q), "late_weak", "the first matching rule only")


func test_hooks_are_harmless_without_a_logger() -> void:
	BotMetrics.note(2, &"stuck")
	BotMetrics.note(2, &"stuck_time", 0.1)
	BotMetrics.command_issued(2, &"follow")
	BotMetrics.command_done(2, &"follow")
	assert_true(true, "no logger running: the hooks do nothing")
