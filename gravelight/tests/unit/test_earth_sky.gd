extends GutTest
## The Earth over the yard (UPDATE 07 Map 4 Act IV, docs/MAP4_FERNFLUG.md §6.2, T-112): which cities glow violet comes
## from the bomb run's flags and the London window, the signal's spread grows per act round from a start round to a
## cap, a cut freezes it, a renewal floods it.


func test_violet_cities_follow_the_flags() -> void:
	assert_eq(EarthSky.violet_cities({}), [] as Array[String], "nothing before London")
	assert_eq(EarthSky.violet_cities({&"london_seen": true}), ["london"] as Array[String])
	var f: Dictionary = {&"london_seen": true, &"bomb_boston_hit": true, &"bomb_new_york_hit": true, &"bomb_washington_saved": true}
	var c: Array[String] = EarthSky.violet_cities(f)
	assert_true(c.has("boston") and c.has("new_york"), "burned cities")
	assert_false(c.has("washington"), "a saved city stays dark")
	assert_eq(c.size(), 3)


func test_spread_grows_per_round_to_the_cap() -> void:
	assert_almost_eq(EarthSky.spread_for(1, 3, 0.04, 0.6), 0.0, 0.001, "before the start round")
	assert_almost_eq(EarthSky.spread_for(3, 3, 0.04, 0.6), 0.04, 0.001)
	assert_almost_eq(EarthSky.spread_for(7, 3, 0.04, 0.6), 0.2, 0.001)
	assert_almost_eq(EarthSky.spread_for(40, 3, 0.04, 0.6), 0.6, 0.001, "capped")


func test_sky_node_builds_points_and_cuts() -> void:
	var sky: EarthSky = EarthSky.new()
	sky.cfg = {"spread_points": 10, "fade_seconds": 0.2}
	add_child_autofree(sky)
	assert_eq(sky.points.size(), EarthSky.CITIES.size(), "a point per city")
	assert_false((sky.points["boston"] as MeshInstance3D).visible, "dark until bombed")
	GameState.flags[&"bomb_boston_hit"] = true
	sky.refresh_from_flags()
	assert_true((sky.points["boston"] as MeshInstance3D).visible)
	GameState.flags.erase(&"bomb_boston_hit")
	sky.set_spread(0.5)
	assert_almost_eq(sky.spread, 0.5, 0.001)
	var vis: int = 0
	for m: MeshInstance3D in sky._spread_nodes:
		if m.visible:
			vis += 1
	assert_eq(vis, 5, "half the spread points lit")
	sky.cut()
	assert_true(sky.frozen, "the relay cut: frozen")
	sky.set_spread(1.0)   # a later round can't widen it
	await wait_seconds(0.5)
	assert_true(sky.faded, "faded after fade_seconds")
	var sky2: EarthSky = EarthSky.new()
	sky2.cfg = {"spread_points": 4}
	add_child_autofree(sky2)
	sky2.renew()
	assert_true(sky2.renewed and sky2.frozen)
	assert_almost_eq(sky2.spread, 1.0, 0.001, "the whole night side")
