extends GutTest
## T-265 (the scripts' cost per tick): the pure rules behind the pass. What the local camera does not see is
## animated at a quarter of the rate with the skipped time handed on; looks that need not happen every tick happen
## at a named rate and count the time between them.


func after_each() -> void:
	Zombie.view_lod = true


# ------------------------------------------------------------------ the view cone

func test_the_view_cone_holds_the_screens_corner_and_a_margin() -> void:
	# 75 degrees of vertical field at 16:9: the corner is 57.4 degrees off the axis, the cone 10 degrees wider
	var c: float = Zombie.view_cone_cos(75.0, 16.0 / 9.0)
	assert_almost_eq(rad_to_deg(acos(c)), 57.4 + rad_to_deg(Zombie.VIEW_MARGIN_RAD), 0.3)
	assert_lt(Zombie.view_cone_cos(110.0, 21.0 / 9.0), Zombie.view_cone_cos(75.0, 16.0 / 9.0), "a wider picture, a wider cone")
	assert_gt(Zombie.view_cone_cos(170.0, 3.0), 0.0, "never as wide as the half space: what is behind is always out of view")


func test_out_of_view_is_outside_the_cone_and_not_near() -> void:
	var fwd: Vector3 = Vector3.FORWARD
	var cone: float = Zombie.view_cone_cos(75.0, 16.0 / 9.0)
	assert_false(Zombie.out_of_view(Vector3(0, 0, -10), fwd, cone), "straight ahead")
	assert_false(Zombie.out_of_view(Vector3(10, 0, -10), fwd, cone), "45 degrees off: on screen")
	assert_false(Zombie.out_of_view(Vector3(17.5, 0, -10), fwd, cone), "60 degrees off: past the edge, inside the margin")
	assert_true(Zombie.out_of_view(Vector3(40, 0, -10), fwd, cone), "76 degrees off: out")
	assert_true(Zombie.out_of_view(Vector3(0, 0, 10), fwd, cone), "behind")
	assert_false(Zombie.out_of_view(Vector3(0, 0, 2.5), fwd, cone), "behind but within VIEW_NEAR_M: its shadow, the screen's edge")
	assert_true(Zombie.out_of_view(Vector3(0, 0, 3.5), fwd, cone))


func test_the_animation_rate_by_distance_and_view() -> void:
	assert_eq(Zombie.anim_div(10.0 * 10.0, 15.0, 35.0, false), 1, "near and seen: every frame")
	assert_eq(Zombie.anim_div(20.0 * 20.0, 15.0, 35.0, false), 2)
	assert_eq(Zombie.anim_div(40.0 * 40.0, 15.0, 35.0, false), 4)
	assert_eq(Zombie.anim_div(10.0 * 10.0, 15.0, 35.0, true), Zombie.VIEW_OUT_DIV, "near and not seen: every 4th frame")
	assert_eq(Zombie.anim_div(40.0 * 40.0, 15.0, 35.0, true), 4)



func test_a_body_behind_the_camera_is_posed_every_fourth_frame() -> void:
	var host: Node3D = Node3D.new()
	add_child_autofree(host)
	var n: Node3D = Node3D.new()
	host.add_child(n)
	var cam: Camera3D = Camera3D.new()
	host.add_child(cam)
	cam.make_current()
	n.global_position = cam.global_position + Vector3(0, 0, -6)
	assert_eq(PatronBody.lod_div(n), 1, "in front: every frame")
	n.global_position = cam.global_position + Vector3(0, 0, 6)
	assert_eq(PatronBody.lod_div(n), 4, "behind: every 4th frame")
	n.global_position = cam.global_position + Vector3(0, 0, 2)
	assert_eq(PatronBody.lod_div(n), 1, "behind but at arm's length: every frame")
	Zombie.view_lod = false
	n.global_position = cam.global_position + Vector3(0, 0, 6)
	assert_eq(PatronBody.lod_div(n), 1, "the switch off: by distance only")


# ------------------------------------------------------------------ the day at rest writes nothing

func _day_rig() -> Array:
	var m: Node3D = Node3D.new()
	m.set_script(load("res://gravelight/tests/unit/day_cycle_map_stub.gd"))
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = Environment.new()
	we.environment.ambient_light_energy = 0.3
	we.environment.tonemap_exposure = 1.3
	m.add_child(we)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_energy = 0.42
	moon.rotation_degrees = Vector3(-40, 28, 0)
	m.add_child(moon)
	add_child_autofree(m)
	return [we.environment, moon, DayCycle.attach(m)]


func test_a_day_that_stands_still_writes_nothing() -> void:
	var rig: Array = _day_rig()
	var env: Environment = rig[0]
	var moon: DirectionalLight3D = rig[1]
	var d: DayCycle = rig[2]
	assert_not_null(d)
	d.hold_hour(12.0)
	d._process(0.016)
	assert_eq(d.full_frames, 1, "the first frame at noon writes the day")
	var amb: float = env.ambient_light_energy
	for i: int in 5:
		d._process(0.016)
	assert_eq(d.full_frames, 1, "the same hour, the same roof, nothing touched: nothing written")
	assert_eq(d.skipped_frames, 5)
	assert_eq(env.ambient_light_energy, amb)
	env.ambient_light_energy = 0.15   # a zone's own night value arrives
	d._process(0.016)
	assert_eq(d.full_frames, 2, "another script's write makes the next frame a full one")
	assert_almost_eq(float(d.night_value("ambient_light_energy")), 0.15, 0.0001)
	d._process(0.016)
	assert_eq(d.full_frames, 2, "and its own write is not taken for one")
	moon.light_energy = 0.0   # a room switches the key light off
	d._process(0.016)
	assert_eq(d.full_frames, 3)
	assert_eq(moon.light_energy, 0.0)
	moon.rotation_degrees = Vector3(-10, 0, 0)   # something turns the key light
	d._process(0.016)
	assert_eq(d.full_frames, 4, "a moved key light is put back")
	d.hold_hour(13.0)
	d._process(0.016)
	assert_eq(d.full_frames, 5, "a new hour is a full frame")


func test_a_walking_hour_is_applied_in_steps_and_exactly_on_arrival() -> void:
	assert_true(DayCycle.hour_settled(13.0005, 13.0, false), "a frame's worth of hour: the light stands")
	assert_false(DayCycle.hour_settled(13.0021, 13.0, false), "HOUR_STEP later it is written again")
	assert_true(DayCycle.hour_settled(0.0005, 23.9995, false), "over midnight the gap is the short way round")
	assert_false(DayCycle.hour_settled(14.0, 13.9995, true), "arrived at the round's hour: written once more, exactly")
	assert_true(DayCycle.hour_settled(14.0, 14.0, true))


func test_the_roof_share_arrives() -> void:
	var rig: Array = _day_rig()
	var d: DayCycle = rig[2]
	d.hold_hour(12.0)
	d._process(0.016)
	d._roofed = true
	var frames: int = 0
	while d.indoor < 1.0 and frames < 600:
		d._process(1.0 / 60.0)
		frames += 1
	assert_eq(d.indoor, 1.0, "the share lands on its target (within SETTLE_EPS it is set there)")
	assert_lt(frames, 400, "in a few seconds")
	var full: int = d.full_frames
	d._process(1.0 / 60.0)
	assert_eq(d.full_frames, full, "and then the frames are free again")


# ------------------------------------------------------------------ whole-map searches from groups

class _Thing extends Interactable:
	func build_greybox() -> void:
		pass


func test_the_interactables_come_from_their_group_in_tree_order() -> void:
	var map: Node3D = Node3D.new()
	add_child_autofree(map)
	var other: Node3D = Node3D.new()
	add_child_autofree(other)
	var a: Node3D = Node3D.new()
	map.add_child(a)
	for parent: Node in [a, map, a, other]:
		var t: Interactable = _Thing.new()
		parent.add_child(t)
	var want: Array[Node] = map.find_children("*", "Interactable", true, false)
	var got: Array[Node] = BotEEHub.interactables_of(map)
	assert_eq(got.size(), 3, "the three under the map, not the one beside it")
	assert_eq(got, want, "the same nodes in the same order as the walk over the map gave")


# ------------------------------------------------------------------ rates

func test_the_named_rates() -> void:
	assert_eq(BotLocomotion.NAV_LOOK_S, 0.2, "a walking bot asks the navmesh under it five times a second")
	assert_eq(CoopHud.ROWS_EVERY_S, 0.1, "the squad panel's rows are gathered ten times a second")
	assert_eq(Zombie.VIEW_OUT_DIV, 4)


# ------------------------------------------------------------------ sounds and voices are not loaded in the frame

func test_the_bank_is_loaded_ahead_but_for_the_beds() -> void:
	assert_true(AudioDirector.warm_wanted("SFX", false))
	assert_true(AudioDirector.warm_wanted("SFX", true), "a machine's hum, an engine: short loops")
	assert_true(AudioDirector.warm_wanted("Ambience", false), "a gust, a creak")
	assert_true(AudioDirector.warm_wanted("Music", false), "a round's stinger")
	assert_false(AudioDirector.warm_wanted("Ambience", true), "the map's bed starts with the map")
	assert_false(AudioDirector.warm_wanted("Music", true))


## A story line with an imported file that nothing has loaded yet ("" when this checkout has none left).
func _unloaded_line() -> String:
	for id: String in GLVO.lines.keys():
		var rec: Dictionary = GLVO.lines[id]
		if str(rec.get("speaker", "")) != "OPR" or rec.has("exchange"):
			continue
		var path: String = GLVO.audio_path(StringName(id))
		if path != "" and ResourceLoader.exists(path) and not ResourceLoader.has_cached(path) and not GLVO._streams.has(path) \
				and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return id
	return ""


func test_a_line_waits_for_its_file_and_starts_without_loading_it_in_the_frame() -> void:
	GLVO.reset_match()
	var id: String = _unloaded_line()
	if id == "":
		pass_test("no unloaded Operator line with an imported file in this run")
		return
	var was: bool = GLVO.async_start
	var was_w: bool = StreamWarm.enabled
	GLVO.async_start = true
	StreamWarm.enabled = true
	var late0: int = GLVO.late_starts
	var sync0: int = GLVO.sync_loads
	watch_signals(GLBus)
	assert_true(GLVO.play_local(StringName(id)), "accepted")
	assert_eq(GLVO.current_line(GLVO.GROUP_STORY), StringName(id), "it is the channel's line at once")
	assert_eq(get_signal_emit_count(GLBus, "vo_line_started"), 0, "but it has not started: its file is on a loader thread")
	assert_eq(GLVO.late_starts, late0 + 1)
	var guard: int = 0
	while get_signal_emit_count(GLBus, "vo_line_started") == 0 and guard < 240:
		await get_tree().process_frame
		guard += 1
	GLVO.async_start = was
	StreamWarm.enabled = was_w
	assert_eq(get_signal_emit_count(GLBus, "vo_line_started"), 1, "it starts once the file is there")
	assert_eq(GLVO.sync_loads, sync0, "and nothing was loaded on the main thread")
	assert_eq(GLVO.late_starts, late0 + 1, "counted once however many frames it waited")
	GLVO.stop_all()
	GLVO.reset_match()


func test_with_the_switch_off_a_line_starts_in_the_call() -> void:
	GLVO.reset_match()
	var was: bool = GLVO.async_start
	GLVO.async_start = false
	assert_true(GLVO.stream_ready("res://gravelight/audio/vo/opr/_no_such_line.ogg"))
	watch_signals(GLBus)
	assert_true(GLVO.play(&"OPR_ROUND_START_02"))
	assert_eq(get_signal_emit_count(GLBus, "vo_line_started"), 1, "as the tests and the smokes expect")
	GLVO.async_start = was
	GLVO.stop_all()
	GLVO.reset_match()


func test_a_world_line_is_called_when_its_file_is_there() -> void:
	var was: bool = GLVO.async_start
	var was_w: bool = StreamWarm.enabled
	var calls: Array = []
	GLVO.async_start = false
	GLVO.when_ready("res://gravelight/audio/vo/opr/_no_such_line.ogg", func() -> void: calls.append("now"))
	assert_eq(calls, ["now"], "the switch off (a headless run): called in the call")
	var id: String = _unloaded_line()
	if id == "":
		GLVO.async_start = was
		pass_test("no unloaded line left to wait for")
		return
	GLVO.async_start = true
	StreamWarm.enabled = true
	GLVO.when_ready(GLVO.audio_path(StringName(id)), func() -> void: calls.append("later"))
	assert_eq(calls, ["now"], "its file is not in memory: not yet")
	var guard: int = 0
	while calls.size() < 2 and guard < 240:
		await get_tree().process_frame
		guard += 1
	GLVO.async_start = was
	StreamWarm.enabled = was_w
	assert_eq(calls, ["now", "later"], "called once a loader thread has brought it")
