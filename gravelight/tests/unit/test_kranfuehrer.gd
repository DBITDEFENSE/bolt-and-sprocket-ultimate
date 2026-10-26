extends GutTest
## DER KRANFÜHRER's rules (UPDATE 07, docs/MAP4_FERNFLUG.md §3.8): phases by health, the trolley on its rail, the
## hook sweep's hit test, the scaled health, and the data the act schedules him from.


func test_phases_by_health() -> void:
	var ph: Dictionary = {"sweep_at": 0.6, "park_at": 0.3}
	assert_eq(Kranfuehrer.phase_of(1.0, ph), 1)
	assert_eq(Kranfuehrer.phase_of(0.61, ph), 1)
	assert_eq(Kranfuehrer.phase_of(0.6, ph), 2)
	assert_eq(Kranfuehrer.phase_of(0.31, ph), 2)
	assert_eq(Kranfuehrer.phase_of(0.3, ph), 3)
	assert_eq(Kranfuehrer.phase_of(0.0, ph), 3)


func test_trolley_stays_on_the_rail() -> void:
	assert_almost_eq(Kranfuehrer.next_trolley_z(160.0, 170.0, 3.0, 1.0, 156.0, 212.0), 163.0, 0.001, "3 m/s toward the target")
	assert_almost_eq(Kranfuehrer.next_trolley_z(160.0, 100.0, 3.0, 2.0, 156.0, 212.0), 156.0, 0.001, "clamped at the near end")
	assert_almost_eq(Kranfuehrer.next_trolley_z(211.0, 300.0, 3.0, 1.0, 156.0, 212.0), 212.0, 0.001, "clamped at the far end")


func test_hook_sweep_hits_under_it_on_the_span() -> void:
	var hook: Vector3 = Vector3(-10.0, 0.4, 180.0)
	assert_true(Kranfuehrer.hook_hits(hook, Vector3(-10, 0, 181), 1.5, 2.0, -68.0, 28.0), "a player on the line")
	assert_false(Kranfuehrer.hook_hits(hook, Vector3(-10, 0, 183), 1.5, 2.0, -68.0, 28.0), "off the line")
	assert_false(Kranfuehrer.hook_hits(hook, Vector3(-10, 12, 180), 1.5, 2.0, -68.0, 28.0), "the catwalk is above it")
	assert_false(Kranfuehrer.hook_hits(hook, Vector3(-69, 0, 180), 1.5, 2.0, -68.0, 28.0), "beyond the bridge's span")


func test_scaled_health_and_data() -> void:
	var t: Dictionary = GLData.table("bosses/map04")
	var k: Dictionary = t["bosses"]["kranfuehrer"]
	assert_eq(int(k["hp_base"]), 24000)
	assert_almost_eq(HomageBoss.scaled_hp(float(k["hp_base"]), 1, float(t["hp_player_step"])), 24000.0, 0.1)
	assert_almost_eq(HomageBoss.scaled_hp(float(k["hp_base"]), 4, float(t["hp_player_step"])), 78000.0, 0.1, "4 players: x3.25")
	assert_gt(float(t["failsafe_seconds"]), 60.0, "a fail-safe so the round never softlocks")
	assert_true(bool(t["bots_alone"]["enabled"]))
	assert_eq(int(k["kill_scrip_per_player"]), 1500)
	assert_eq(str(k["flag"]), "hangar_key")
	var lines: Dictionary = GLData.load_json("res://data/gravelight/vo/lines.json")
	assert_true(lines.has(str(k["spawn_vo"])) and lines.has(str(k["death_vo"])), "his Operator lines exist")
	var rail: Dictionary = k["rail"]
	assert_lt(float(rail["z_min"]), float(rail["ramp_z"]), "the ramp is on the rail")
	assert_lt(float(rail["ramp_z"]), float(rail["z_max"]))
