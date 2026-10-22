extends GutTest
## Update 02 section 3 (T-048): the rebuilt Totenglocke's pure rules (gravelight/weapons/totenglocke.gd).


func _bell(up: bool = false) -> Dictionary:
	var w: Dictionary = GLData.table("weapons")
	return (w["upgraded"]["totenglocke_up"] if up else w["weapons"]["totenglocke"])["bell"]


func _hp(round_number: int) -> float:
	return float(RoundManager.zombie_health(round_number, GLData.table("rounds")))


func test_tap_kills_outright_through_round_20() -> void:
	var b: Dictionary = _bell()
	for r: int in [1, 9, 15, 19, 20]:
		var o: Dictionary = Totenglocke.outcome(_hp(r), _hp(r), false, false, false, b)
		assert_true(bool(o["kill"]), "round %d dies to one tap" % r)
		assert_false(bool(o["mark"]))
		assert_gt(float(o["damage"]), _hp(r))


func test_tap_after_round_20_is_35_percent_and_marks() -> void:
	var b: Dictionary = _bell()
	for r: int in [21, 25, 40]:
		var mx: float = _hp(r)
		var o: Dictionary = Totenglocke.outcome(mx, mx, false, false, false, b)
		assert_almost_eq(float(o["damage"]), mx * 0.35, 0.01, "round %d: 35%% of max HP" % r)
		assert_false(bool(o["kill"]))
		assert_true(bool(o["mark"]), "a survivor is tolled")
		assert_false(bool(o["shatter"]))
	# a wounded zombie that the 35% finishes is a kill, not a mark
	var mx2: float = _hp(25)
	var low: Dictionary = Totenglocke.outcome(mx2, mx2 * 0.3, false, false, false, b)
	assert_true(bool(low["kill"]))
	assert_false(bool(low["mark"]))


func test_tolled_always_shatters() -> void:
	var b: Dictionary = _bell()
	var mx: float = _hp(40)
	var o: Dictionary = Totenglocke.outcome(mx, mx * 0.65, true, false, false, b)
	assert_true(bool(o["shatter"]))
	assert_true(bool(o["kill"]))
	assert_gt(float(o["damage"]), mx * 0.65)


func test_great_toll_shatters_at_any_round() -> void:
	var b: Dictionary = _bell()
	for r: int in [5, 25, 60]:
		var o: Dictionary = Totenglocke.outcome(_hp(r), _hp(r), false, false, true, b)
		assert_true(bool(o["shatter"]), "round %d" % r)


func test_bosses_never_shatter_or_mark() -> void:
	var b: Dictionary = _bell()
	var tap: Dictionary = Totenglocke.outcome(20000.0, 20000.0, true, true, false, b)
	var great: Dictionary = Totenglocke.outcome(20000.0, 20000.0, true, true, true, b)
	assert_false(bool(tap["shatter"]))
	assert_false(bool(great["shatter"]))
	assert_false(bool(tap["mark"]))
	assert_almost_eq(float(tap["damage"]), 20000.0 * float(b["boss_tap_pct"]), 0.01)
	assert_almost_eq(float(great["damage"]), 20000.0 * float(b["boss_great_pct"]), 0.01)
	# the boss stagger values are the M4 ones, unchanged
	assert_almost_eq(float(b["stagger_bosses"]), 0.0, 0.001)
	assert_almost_eq(float(_bell(true)["stagger_bosses"]), 1.5, 0.001)


func test_great_toll_cost_and_release_kind() -> void:
	var b: Dictionary = _bell()
	assert_eq(Totenglocke.great_cost(b), 3)
	assert_eq(Totenglocke.great_cost(_bell(true)), 2)
	var wind: float = float(b["wind_seconds"])
	assert_almost_eq(wind, 1.5, 0.001)
	assert_eq(Totenglocke.release_kind(b, 0.1, 12), &"tap", "a tap")
	assert_eq(Totenglocke.release_kind(b, wind - 0.05, 12), &"tap", "released before the wind completes")
	assert_eq(Totenglocke.release_kind(b, wind, 12), &"great")
	assert_eq(Totenglocke.release_kind(b, wind + 2.0, 2), &"tap", "too few charges for a Great Toll")
	assert_eq(Totenglocke.release_kind(_bell(true), wind, 2), &"great", "Mitternacht's costs 2")


func test_cones() -> void:
	var b: Dictionary = _bell()
	assert_eq(Totenglocke.cone_for(b, false), Vector2(8.0, 50.0))
	assert_eq(Totenglocke.cone_for(b, true), Vector2(14.0, 70.0))
	# inside / outside the 50 deg quick-toll cone at 6 m, and the close radius ignores direction
	var fwd: Vector3 = Vector3.FORWARD
	assert_true(Totenglocke.in_cone(Vector3.ZERO, fwd, Vector3(sin(deg_to_rad(24.0)) * 6.0, 0, -cos(deg_to_rad(24.0)) * 6.0), 8.0, 50.0, 1.5))
	assert_false(Totenglocke.in_cone(Vector3.ZERO, fwd, Vector3(sin(deg_to_rad(26.0)) * 6.0, 0, -cos(deg_to_rad(26.0)) * 6.0), 8.0, 50.0, 1.5))
	assert_true(Totenglocke.in_cone(Vector3.ZERO, fwd, Vector3(0, 0, 1.2), 8.0, 50.0, 1.5), "behind but within the close radius")
	assert_true(Totenglocke.in_cone(Vector3.ZERO, fwd, Vector3(0, 0, -13.9), 14.0, 70.0, 1.5))


func test_upgraded_values() -> void:
	var b: Dictionary = _bell()
	var up: Dictionary = _bell(true)
	for k: String in ["range", "cone_deg", "great_range", "great_cone_deg"]:
		assert_almost_eq(float(up[k]), float(b[k]) * 1.3, 0.051, "Mitternacht %s +30%%" % k)
	assert_eq(int(up["chain"]), 3)
	assert_eq(int(b["chain"]), 0)
	assert_almost_eq(float(up["dome_seconds"]), 12.0, 0.001)
	assert_almost_eq(float(b["dome_seconds"]), 8.0, 0.001)
	assert_gt(float(up["dome_pull"]), 0.0)
	assert_almost_eq(float(b["dome_pull"]), 0.0, 0.001)
	assert_ne(str(up["chime_sound"]), "")


func test_ammo_and_dome_data() -> void:
	var w: Dictionary = GLData.table("weapons")
	var base: Dictionary = w["weapons"]["totenglocke"]
	assert_eq(int(base["mag"]), 12)
	assert_eq(int(base["reserve"]), 48)
	var b: Dictionary = base["bell"]
	assert_almost_eq(float(b["dome_radius"]), 6.0, 0.001)
	assert_almost_eq(float(b["dome_slow"]), 0.6, 0.001, "zombies in the dome move at 40% speed")
	assert_almost_eq(float(b["dome_damage_mult"]), 1.25, 0.001)
	assert_true(BellDome.contains(Vector3.ZERO, 6.0, Vector3(5.9, 1.0, 0.0)))
	assert_false(BellDome.contains(Vector3.ZERO, 6.0, Vector3(4.5, 0.0, 4.5)))
	assert_false(BellDome.contains(Vector3.ZERO, 6.0, Vector3(1.0, 5.0, 0.0)), "a floor above is outside")


func test_dome_bonus_counts_toward_a_kill() -> void:
	var b: Dictionary = _bell()
	var mx: float = _hp(30)
	# 35% x 1.25 = 43.75% kills a zombie at 40% HP inside the dome, but not outside
	assert_true(bool(Totenglocke.outcome(mx, mx * 0.4, false, false, false, b, 1.25)["kill"]))
	assert_false(bool(Totenglocke.outcome(mx, mx * 0.4, false, false, false, b, 1.0)["kill"]))


func test_shard_rate_limit() -> void:
	assert_eq(Totenglocke.shard_step(0, 4, 5), [0, 4])
	assert_eq(Totenglocke.shard_step(4, 1, 5), [1, 0])
	assert_eq(Totenglocke.shard_step(0, 12, 5), [2, 2], "a 12-kill toll drops 2, never more than 1 per 5")
	assert_eq(Totenglocke.shard_step(3, 0, 5), [0, 3])


func test_add_charge_fills_bell_then_reserve() -> void:
	var w: WeaponInstance = WeaponInstance.create(&"totenglocke")
	w.refill()
	assert_false(Totenglocke.add_charge(w), "full: nothing to add")
	w.mag = 5
	assert_true(Totenglocke.add_charge(w))
	assert_eq(w.mag, 6)
	w.mag = w.mag_size()
	w.reserve = 10
	assert_true(Totenglocke.add_charge(w))
	assert_eq(w.reserve, 11)


func test_refill_weapon_restores_the_bell() -> void:
	# the ammo box (section 4) goes through WeaponHolder.refill_weapon -> WeaponInstance.refill
	var w: WeaponInstance = WeaponInstance.create(&"totenglocke_up")
	w.mag = 0
	w.reserve = 0
	w.refill()
	assert_eq(w.mag, 16)
	assert_eq(w.reserve, 64)


func test_reload_crank_turns_six_times() -> void:
	assert_almost_eq(Totenglocke.reload_crank_angle(0.0), 0.0, 0.001)
	assert_almost_eq(Totenglocke.reload_crank_angle(1.0), TAU * 6.0, 0.001)
	assert_gt(Totenglocke.reload_crank_angle(0.6), Totenglocke.reload_crank_angle(0.4))


func test_hitstop_restores_time_scale() -> void:
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001)
	var ok: bool = Totenglocke.hitstop(get_tree(), 0.2, 0.05)
	if Net.session != null:
		assert_false(ok, "never in co-op")
		return
	assert_true(ok)
	assert_almost_eq(Engine.time_scale, 0.2, 0.0001)
	assert_false(Totenglocke.hitstop(get_tree(), 0.2, 0.05), "never stacks")
	await wait_seconds(0.3)
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "restored")
	Engine.time_scale = 3.0
	assert_false(Totenglocke.hitstop(get_tree(), 0.2, 0.05), "leaves a time scale someone else set alone")
	Engine.time_scale = 1.0
