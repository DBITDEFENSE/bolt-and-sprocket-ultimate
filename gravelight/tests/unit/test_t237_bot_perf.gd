extends GutTest
## T-237 ("while there's bots the game gets laggy"): the pieces that took the bots' frame cost and hitches down.
## The planner asks its model only when there is something new to decide; a body keeps the gun models it held
## instead of rebuilding one on every swap; a body the camera does not see is posed every 4th tick with the
## skipped time handed on; sounds are loaded in the background; the profiler costs nothing while it is off.

const FLOOR: int = 16   # NetMatch.PF_FLOOR


func after_each() -> void:
	BotProf.on = false
	BotProf.opt = true
	BotProf.reset()
	RemoteBody.pose_lod = true


func _body() -> RemoteBody:
	var b: RemoteBody = RemoteBody.new()
	add_child_autofree(b)
	b.setup(&"dutch", 41)
	return b


# ------------------------------------------------------------------ the planner's model calls

func test_the_model_is_asked_when_there_is_something_new_to_decide() -> void:
	var ids: Array = ["follow", "gun:WallBuy_mp40", "perk:Ironhide"]
	assert_true(BotPlanner.ask_due(true, ids, ids, "follow", "follow", 1.0, 20.0), "no objective: ask")
	assert_false(BotPlanner.ask_due(false, ids, ids, "follow", "follow", 4.0, 20.0), "the same options, the same built-in pick, 4 s on: the last answer stands")
	assert_false(BotPlanner.ask_due(false, ["perk:Ironhide", "follow", "gun:WallBuy_mp40"], ids, "follow", "follow", 8.0, 20.0), "the same options in another order are the same options")
	assert_true(BotPlanner.ask_due(false, ids, ids, "follow", "follow", 20.0, 20.0), "reask_every_s later: ask again")
	assert_true(BotPlanner.ask_due(false, ids, ids, "perk:Ironhide", "follow", 4.0, 20.0), "the built-in brain changed its own pick: ask")
	assert_true(BotPlanner.ask_due(false, ["follow", "gun:WallBuy_mp40", "door:Cellar"], ids, "follow", "follow", 4.0, 20.0), "an option came and one went: ask")
	assert_true(BotPlanner.ask_due(false, ["follow", "gun:WallBuy_mp40"], ids, "follow", "follow", 4.0, 20.0), "an option went: ask")
	# the gap: nothing but a lost objective asks again within ask_gap_s
	assert_false(BotPlanner.ask_due(false, ids, ids, "perk:Ironhide", "follow", 4.0, 20.0, 8.0), "a changed mind inside the gap waits")
	assert_true(BotPlanner.ask_due(false, ids, ids, "perk:Ironhide", "follow", 8.0, 20.0, 8.0), "and asks once the gap is over")
	assert_true(BotPlanner.ask_due(true, ids, ids, "follow", "follow", 0.5, 20.0, 8.0), "no objective asks at once, gap or not")


func test_reask_every_s_is_in_the_data() -> void:
	var lc: Dictionary = BotConfig.cfg().get("local_ai", {})
	assert_true(lc.has("reask_every_s"), "bots.json local_ai.reask_every_s")
	assert_gt(float(lc["reask_every_s"]), float(lc["decide_every_s"]), "the refresh is rarer than the decision tick")
	assert_true(lc.has("ask_gap_s"), "bots.json local_ai.ask_gap_s")
	assert_lt(float(lc["ask_gap_s"]), float(lc["reask_every_s"]))


# ------------------------------------------------------------------ the third-person body

func test_a_body_keeps_the_guns_it_held() -> void:
	var b: RemoteBody = _body()
	b.set_weapon(&"thompson")
	var first: Node3D = b.get("_gun") as Node3D
	assert_not_null(first)
	b.set_weapon(&"m1911")
	var second: Node3D = b.get("_gun") as Node3D
	assert_ne(first, second)
	assert_true(is_instance_valid(first), "the Thompson's model is kept")
	assert_false(first.visible, "and hidden while the pistol is out")
	assert_true(second.visible)
	b.set_weapon(&"thompson")
	assert_eq(b.get("_gun"), first, "the same model comes back: nothing is rebuilt")
	assert_true(first.visible)
	assert_false(second.visible)
	var flash: Node = b.get("_flash") as Node
	assert_true(first.is_ancestor_of(flash), "the muzzle flash moved to the gun in hand")
	assert_eq(str((b.get("_gun_hold") as Dictionary).get("kind", "")), "long", "with its own hold")


func test_the_kept_guns_are_capped() -> void:
	var b: RemoteBody = _body()
	var ids: Array = [&"thompson", &"m1911", &"kar98k", &"mp40", &"trench_gun", &"m1_garand"]
	for id: StringName in ids:
		b.set_weapon(id)
	assert_eq((b.get("_gun_cache") as Dictionary).size(), RemoteBody.GUN_CACHE_MAX, "at most GUN_CACHE_MAX models are kept")
	assert_eq(b.get("_weapon_id"), &"m1_garand")
	assert_true((b.get("_gun") as Node3D).visible, "the gun in hand is never the one dropped")


func test_refresh_weapon_rebuilds_the_gun() -> void:
	var b: RemoteBody = _body()
	b.set_weapon(&"thompson")
	var first: Node3D = b.get("_gun") as Node3D
	b.refresh_weapon()
	var again: Node3D = b.get("_gun") as Node3D
	assert_not_null(again)
	assert_ne(again, first, "the bench changed the gun: a kept model would be stale")
	assert_true(again.visible)


func test_the_muzzle_light_is_hidden_while_dark() -> void:
	var b: RemoteBody = _body()
	b.set_weapon(&"thompson")
	var l: OmniLight3D = b.get("_flash_light") as OmniLight3D
	assert_false(l.visible, "no light for the renderer while the gun is quiet")
	b.fire(0, &"thompson", Vector3.ZERO, Vector3(0, 0, -5))
	assert_true(l.visible, "lit for the flash")
	for i: int in 6:
		b.update_pose(1.0 / 60.0, 0.0, 0.0, FLOOR)
	assert_false(l.visible, "and gone again after it")


func _cam(at: Vector3, look: Vector3) -> Camera3D:
	var c: Camera3D = Camera3D.new()
	add_child_autofree(c)
	c.global_position = at
	c.look_at(look)
	c.current = true
	return c


func test_pose_rate_follows_the_camera() -> void:
	var b: RemoteBody = _body()
	b.global_position = Vector3(0, 0, -10)
	var c: Camera3D = _cam(Vector3(0, 1.6, 0), Vector3(0, 1.0, -10))
	assert_eq(get_viewport().get_camera_3d(), c)
	assert_eq(b.pose_div(), 1, "in view at 10 m: every tick")
	b.global_position = Vector3(0, 0, -30)
	assert_eq(b.pose_div(), 2, "in view at 30 m: every 2nd tick")
	b.global_position = Vector3(0, 0, -60)
	assert_eq(b.pose_div(), 4, "in view at 60 m: every 4th tick")
	b.global_position = Vector3(0, 0, 10)
	assert_eq(b.pose_div(), 4, "behind the camera: every 4th tick")
	b.global_position = Vector3(0, 0, 2)
	assert_eq(b.pose_div(), 1, "within arm's reach it is always posed (the screen's edge, its shadow)")
	RemoteBody.pose_lod = false
	b.global_position = Vector3(0, 0, 10)
	assert_eq(b.pose_div(), 1, "pose_lod off: every tick")


func test_a_skipped_pose_hands_its_time_on() -> void:
	# two bodies walk for a second: one posed every tick, one out of view. Their walk cycles end at the same phase.
	var seen: RemoteBody = _body()
	var unseen: RemoteBody = _body()
	_cam(Vector3(0, 1.6, 0), Vector3(0, 1.0, -10))
	seen.global_position = Vector3(0, 0, -8)
	unseen.global_position = Vector3(0, 0, 12)
	assert_eq(unseen.pose_div(), 4)
	# the loop below runs inside one physics frame: put this body off the frame its slot falls on, or one run in four
	# poses it on every call (the frame counter never moves here) and the last assert fails
	unseen.set("_lod_phase", (5 - int(Engine.get_physics_frames() % 4)) % 4)
	var poses_before: float = float(unseen.get("_phase"))
	var full_poses: int = 0
	for i: int in 60:
		seen.update_pose_lod(1.0 / 60.0, 3.0, 0.0, FLOOR)
		var ph: float = float(unseen.get("_phase"))
		unseen.update_pose_lod(1.0 / 60.0, 3.0, 0.0, FLOOR)
		if float(unseen.get("_phase")) != ph:
			full_poses += 1
	assert_ne(float(unseen.get("_phase")), poses_before, "it was posed")
	assert_lt(full_poses, 60, "but not on every tick")
	# (in a test the engine's tick counter stands still, so the body is posed whenever 0.12 s have piled up, or on
	# every call when the counter happens to sit on its turn; either way no walked time may be lost)
	unseen.update_pose(float(unseen.get("_lod_dt")), 3.0, 0.0, FLOOR)
	assert_almost_eq(float(unseen.get("_phase")), float(seen.get("_phase")), 0.01, "the walk cycle kept its pace")


func test_the_flash_ends_on_time_on_a_skipped_tick() -> void:
	var b: RemoteBody = _body()
	_cam(Vector3(0, 1.6, 0), Vector3(0, 1.0, -10))
	b.global_position = Vector3(0, 0, 12)
	b.set_weapon(&"thompson")
	b.fire(0, &"thompson", Vector3.ZERO, Vector3(0, 0, -5))
	var l: OmniLight3D = b.get("_flash_light") as OmniLight3D
	assert_true(l.visible)
	for i: int in 5:
		b.update_pose_lod(1.0 / 60.0, 0.0, 0.0, FLOOR)
	assert_false(l.visible, "the flash went out after 0.05 s, posed or not")


# ------------------------------------------------------------------ background loading

func test_stream_warm_loads_a_file_once() -> void:
	var files: Array = (AudioDirector.bank.get("sounds", {}) as Dictionary).get("footstep_stone", {}).get("files", [])
	if files.is_empty() or not ResourceLoader.exists(str(files[0])):
		pass_test("no footstep_stone file in this checkout")
		return
	var w: StreamWarm = StreamWarm.new()
	var was: bool = StreamWarm.enabled
	StreamWarm.enabled = true
	w.add(str(files[0]))
	w.add(str(files[0]))
	w.add("res://gravelight/audio/sfx/final/_no_such_file.wav")
	assert_eq(w.pending(), 2, "a path is queued once")
	var guard: int = 0
	while w.busy() and guard < 600:
		w.tick()
		await get_tree().process_frame
		guard += 1
	StreamWarm.enabled = was
	assert_false(w.busy(), "the queue drains")
	assert_true(w.kept.has(str(files[0])), "the stream is kept (the manager's later load() is a cache hit)")
	assert_true(w.kept[str(files[0])] is AudioStream)
	assert_eq(w.kept.size(), 1, "a missing file is skipped")


func test_stream_warm_off_queues_nothing() -> void:
	var w: StreamWarm = StreamWarm.new()
	var was: bool = StreamWarm.enabled
	StreamWarm.enabled = false
	w.add("res://anything.wav")
	StreamWarm.enabled = was
	assert_eq(w.pending(), 0)
	assert_false(w.busy())


func test_the_bank_warm_up_leaves_the_beds_alone() -> void:
	var was: bool = StreamWarm.enabled
	StreamWarm.enabled = true
	var saved: StreamWarm = AudioDirector.warm
	AudioDirector.warm = StreamWarm.new()
	AudioDirector.warm_bank()
	var w: StreamWarm = AudioDirector.warm
	AudioDirector.warm = saved
	StreamWarm.enabled = was
	var asked: Dictionary = w.get("_asked")
	assert_gt(asked.size(), 50, "the one-shot sounds are queued")
	var sounds: Dictionary = AudioDirector.bank.get("sounds", {})
	for bed: String in ["ambient_map00", "music_menu", "score_dread"]:
		for f: Variant in (sounds.get(bed, {}) as Dictionary).get("files", []):
			assert_false(asked.has(str(f)), "%s is not preloaded" % bed)


# ------------------------------------------------------------------ the profiler

func test_the_profiler_is_free_while_off() -> void:
	assert_false(BotProf.on)
	assert_eq(BotProf.t(), 0)
	BotProf.add(&"x", 0)
	assert_eq(BotProf.report().size(), 0, "nothing is recorded while it is off")
	BotProf.on = true
	var t0: int = BotProf.t()
	assert_gt(t0, 0)
	BotProf.begin_tick()
	BotProf.add(&"x", t0)
	assert_eq(BotProf.report().size(), 1)
	assert_true(BotProf.tick_text().begins_with("prof: x "))
