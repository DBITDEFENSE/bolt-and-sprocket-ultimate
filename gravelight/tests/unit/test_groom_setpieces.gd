extends GutTest
## Groom Lake's U10 set-pieces (UPDATE 10 §3 Act III, DECISIONS T-157): the dust storm's schedule and fog, how a
## stalker hears (SoundHunter), the wreck's collapse schedule and the fire's spread, the radar's ping timer.


func after_each() -> void:
	SoundHunter.reset()


# ---------------------------------------------------------------- the storm's schedule

func test_storm_every_fifth_act_round() -> void:
	for ar: int in [5, 10, 15, 20]:
		assert_true(GroomController.storm_round_due(ar, 5), "act round %d is a storm" % ar)
	for ar2: int in [0, 1, 4, 6, 9, 11]:
		assert_false(GroomController.storm_round_due(ar2, 5), "act round %d is not" % ar2)
	assert_false(GroomController.storm_round_due(5, 0), "every 0 = never")


func test_next_storm_round_is_act_relative() -> void:
	# a campaign arrival on match round 21: act round 5 is match 25, then 30
	assert_eq(GroomController.next_storm_round(20, 21, 5), 25)
	assert_eq(GroomController.next_storm_round(24, 21, 5), 25)
	assert_eq(GroomController.next_storm_round(25, 21, 5), 30)
	# standalone (act_start 1): rounds 5, 10, 15 ... past the act's nine rounds (the loop)
	assert_eq(GroomController.next_storm_round(0, 1, 5), 5)
	assert_eq(GroomController.next_storm_round(12, 1, 5), 15)
	assert_eq(GroomController.next_storm_round(30, 1, 5), 35)


func test_fog_for_visibility() -> void:
	assert_almost_eq(GroomController.fog_for_visibility(15.0), 0.2, 0.0001)
	assert_almost_eq(GroomController.fog_for_visibility(30.0), 0.1, 0.0001)
	assert_true(exp(-GroomController.fog_for_visibility(15.0) * 15.0) < 0.06, "~5 % of the light gets through at 15 m")


func test_stalker_kinds_and_zones() -> void:
	var hc: Dictionary = {"kinds": ["burrower", ""], "zones": ["B_LAKEBED", "C_HANGAR"]}
	assert_true(GroomController.is_stalker("burrower", "B_LAKEBED", hc))
	assert_true(GroomController.is_stalker("", "C_HANGAR", hc), "a plain Gänger on the surface")
	assert_false(GroomController.is_stalker("canary", "C_HANGAR", hc), "the hooded Canaries keep their eyes")
	assert_false(GroomController.is_stalker("", "F_LAB", hc), "underground the storm is not heard")


func test_map04c_storm_data() -> void:
	var dc: Dictionary = GLData.load_json("res://data/gravelight/map04c.json")["groom"]["dust_storm"]
	assert_eq(int(dc["every_act_rounds"]), 5)
	assert_eq(float(dc["visibility_m"]), 15.0)
	assert_eq(str(dc["hud_line"]), "DUST STORM: they hunt by sound")
	assert_eq(float(dc["hear"]["loud_mult"]), 3.0)


# ---------------------------------------------------------------- hearing

func test_hear_radius_triples_when_loud() -> void:
	assert_eq(SoundHunter.hear_radius(6.0, false, 3.0), 6.0)
	assert_eq(SoundHunter.hear_radius(6.0, true, 3.0), 18.0)
	assert_true(SoundHunter.is_loud(true, false), "sprinting is loud")
	assert_true(SoundHunter.is_loud(false, true), "a shot is loud")
	assert_false(SoundHunter.is_loud(false, false), "walking is quiet")


func test_can_hear_on_the_flat_and_not_through_floors() -> void:
	assert_true(SoundHunter.can_hear(Vector3.ZERO, Vector3(12, 0, 0), 18.0))
	assert_false(SoundHunter.can_hear(Vector3.ZERO, Vector3(12, 0, 0), 6.0), "12 m off, quiet: not heard")
	assert_false(SoundHunter.can_hear(Vector3.ZERO, Vector3(2, -6, 0), 18.0), "the lab under the salt")


func test_fire_window() -> void:
	SoundHunter.note_fire(2, 10000)
	assert_true(SoundHunter.fired_recently(2, 11000, 1.5))
	assert_false(SoundHunter.fired_recently(2, 12000, 1.5), "1.5 s later the shot has faded")
	assert_false(SoundHunter.fired_recently(3, 10000, 1.5), "another player never fired")


func test_heard_player_picks_the_nearest_loud() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var z: Node3D = Node3D.new()
	host.add_child(z)
	z.global_position = Vector3.ZERO
	var far_quiet: Player = Player.new()
	far_quiet.player_id = 1
	var near_loud: Player = Player.new()
	near_loud.player_id = 2
	host.add_child(far_quiet)
	host.add_child(near_loud)
	far_quiet.global_position = Vector3(10, 0, 0)
	near_loud.global_position = Vector3(15, 0, 0)
	near_loud.sprinting = true
	var heard: Node3D = SoundHunter.heard_player(z, 6.0, [far_quiet, near_loud])
	assert_eq(heard, near_loud, "the quiet one at 10 m is not heard; the sprinter at 15 m is")
	near_loud.sprinting = false
	assert_null(SoundHunter.heard_player(z, 6.0, [far_quiet, near_loud]), "nobody loud, nobody within 6 m")


# ---------------------------------------------------------------- the wreck

func test_collapse_schedule() -> void:
	var wc: Dictionary = GLData.load_json("res://data/gravelight/map04c.json")["groom"]["wreck_collapse"]
	assert_eq(float(wc["warn_s"]), 10.0, "telegraphed 10 s ahead")
	var r3: Array = GroomController.collapse_due(3, wc, {})
	assert_eq(r3.size(), 1)
	assert_eq(str((r3[0] as Dictionary)["id"]), "bay_roof", "act round 3 = match 23 in the campaign")
	var r6: Array = GroomController.collapse_due(6, wc, {})
	assert_eq(str((r6[0] as Dictionary)["id"]), "hull_west", "act round 6 = match 26")
	assert_true(GroomController.collapse_due(3, wc, {"bay_roof": true}).is_empty(), "a section falls once")
	for ar: int in [1, 2, 4, 5, 7, 9, 23, 26]:
		assert_true(GroomController.collapse_due(ar, wc, {}).is_empty(), "nothing on act round %d" % ar)


func test_collapse_box() -> void:
	var box: Array = [[-13.7, 0.0, -12.2], [-8.4, 4.2, -4.6]]
	assert_true(GroomController.in_box(Vector3(-11, 0, -8), box))
	assert_false(GroomController.in_box(Vector3(-3, 0, -8.5), box), "push_to is outside")
	assert_false(GroomController.in_box(Vector3(-11, 6, -8), box), "above the roof")


func test_fire_spread_grows_per_round() -> void:
	var sp: Dictionary = GLData.load_json("res://data/gravelight/map04c.json")["groom"]["fire"]["spread"]
	assert_eq(GroomController.spread_count(1, sp), 0, "nothing before act round 2")
	assert_eq(GroomController.spread_count(2, sp), 1)
	assert_eq(GroomController.spread_count(4, sp), 3)
	assert_eq(GroomController.spread_count(40, sp), 5, "capped at the path's end on the loop")
	assert_eq(GroomController.spread_count(5, {}), 0, "no spread block, no spread")


# ---------------------------------------------------------------- the radar

func test_ping_timer() -> void:
	var rc: Dictionary = GLData.load_json("res://data/gravelight/map04c.json")["radar"]
	assert_eq(float(rc["every_s"]), 60.0, "a ping every minute")
	assert_eq(float(rc["seconds"]), 10.0, "for 10 s")
	var times: Array[float] = RadarDish.ping_times(float(rc["first_after_s"]), float(rc["every_s"]), 3)
	assert_eq(times, [8.0, 68.0, 128.0] as Array[float])
	assert_false(RadarDish.ping_due(7.9, 8.0))
	assert_true(RadarDish.ping_due(8.0, 8.0))


func test_map_state_radar_ping_window() -> void:
	var ms: MapState = MapState.new()
	add_child_autofree(ms)
	assert_false(ms.radar_active())
	ms.radar_ping(10.0)
	assert_true(ms.radar_active())
	ms._process(9.5)
	assert_true(ms.radar_active(), "still on at 9.5 s")
	ms._process(0.6)
	assert_false(ms.radar_active(), "off after 10 s")
