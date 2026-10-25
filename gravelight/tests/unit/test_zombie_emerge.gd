extends GutTest
## The rise from the ground (T-085, ZombieEmerge): the variant draw is deterministic from the seed and biased by
## tier, every variant's stage times are monotonic, the clips bake at the table's lengths and nothing pokes
## through the ground before its stage, the hitboxes enable at head-out (and come back on every early exit),
## the rise length is the variant's seconds times the round multiplier, crawlers rise on their elbows, a kill
## mid-rise sinks the body back, and the surface class follows the spawn.

var _host: Node3D
var _spawn: ZombieSpawn
var _round_before: int


func before_each() -> void:
	seed(1)   # the body's height and sex are rolled from the global RNG; the bone-height checks need the same body every run
	GLSettings.values["gore"] = "full"
	_round_before = RoundManager.current_round
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"ground"
	_host.add_child(_spawn)


func after_each() -> void:
	RoundManager.current_round = _round_before


func _zombie(spec: Dictionary = {}) -> Zombie:
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	var s: Dictionary = {"enemy_id": "ganger", "tier": "walk", "health": 400, "variant": "villager"}
	s.merge(spec, true)
	z.activate(s, _spawn, null)
	return z


func _bone_y(z: Zombie, bone: String) -> float:
	var sk: Skeleton3D = z.skeleton()
	return z.to_local(sk.to_global(sk.get_bone_global_pose(sk.find_bone(bone)).origin)).y


func _max_bone_y(z: Zombie) -> float:
	var sk: Skeleton3D = z.skeleton()
	var hi: float = -INF
	for i: int in sk.get_bone_count():
		if sk.get_bone_name(i) == "Root":
			continue   # the root-motion bone sits on the ground by definition
		hi = maxf(hi, z.to_local(sk.to_global(sk.get_bone_global_pose(i).origin)).y)
	return hi


func test_table_shape_and_variants() -> void:
	var vs: PackedStringArray = ZombieEmerge.variants()
	for v: String in ["fast", "standard", "slow", "roll", "crawler"]:
		assert_true(vs.has(v), "variant " + v)
	assert_almost_eq(ZombieEmerge.variant_seconds("fast"), 1.4, 0.001)
	assert_gt(ZombieEmerge.variant_seconds("slow"), ZombieEmerge.variant_seconds("standard"))
	assert_eq(float(ZombieEmerge.variant_cfg("crawler").get("weight", 1.0)), 0.0, "walkers never draw the crawler rise")
	# the weighted mean rise stays in the old 1.4 s neighbourhood once the round multiplier has ramped
	var mean: float = ZombieEmerge.mean_seconds(&"walk")
	assert_between(mean, 1.6, 2.4, "mean rise at round 1 %.2f s" % mean)
	assert_between(mean * ZombieEmerge.round_multiplier(20), 1.1, 1.7, "mean rise at round 20 %.2f s" % (mean * ZombieEmerge.round_multiplier(20)))


func test_stage_times_monotonic() -> void:
	for v: String in ZombieEmerge.variants():
		var list: Array = ZombieEmerge.stage_list(v)
		assert_gt(list.size(), 4, v + " has stages")
		assert_eq(str((list[0] as Array)[0]), "bulge", v + " starts with bulge")
		assert_eq(float((list[0] as Array)[1]), 0.0)
		assert_eq(str((list[list.size() - 1] as Array)[0]), "done", v + " ends with done")
		assert_eq(float((list[list.size() - 1] as Array)[1]), 1.0)
		for i: int in range(1, list.size()):
			assert_gt(float((list[i] as Array)[1]), float((list[i - 1] as Array)[1]), "%s: %s after %s" % [v, (list[i] as Array)[0], (list[i - 1] as Array)[0]])
		for name: String in ZombieEmerge.CORE_STAGES:
			assert_true(ZombieEmerge.stages(v).has(name), "%s has %s" % [v, name])
		if v == "crawler":
			assert_false(ZombieEmerge.stages(v).has("stand"), "crawlers stay down")
		else:
			assert_true(ZombieEmerge.stages(v).has("stand"))


func test_pick_is_deterministic_from_the_seed_and_biased_by_tier() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 4242
	b.seed = 4242
	var seq_a: PackedStringArray = []
	var seq_b: PackedStringArray = []
	for i: int in 60:
		seq_a.append(ZombieEmerge.pick(a, &"walk", false))
		seq_b.append(ZombieEmerge.pick(b, &"walk", false))
	assert_eq(seq_a, seq_b, "the same seed draws the same rises")
	var c: RandomNumberGenerator = RandomNumberGenerator.new()
	c.seed = 99
	var seq_c: PackedStringArray = []
	for i: int in 60:
		seq_c.append(ZombieEmerge.pick(c, &"walk", false))
	assert_ne(seq_c, seq_a, "another seed draws differently")
	assert_eq(ZombieEmerge.pick(a, &"walk", true), "crawler")
	var fast: int = 0
	var slow: int = 0
	var s: RandomNumberGenerator = RandomNumberGenerator.new()
	s.seed = 7
	for i: int in 400:
		var v: String = ZombieEmerge.pick(s, &"sprint", false)
		if v == "fast":
			fast += 1
		elif v == "slow":
			slow += 1
	assert_gt(fast, 240, "sprinters mostly lunge out (%d / 400)" % fast)
	assert_eq(slow, 0, "sprinters never claw slowly")
	var z1: Zombie = _zombie()
	var z2: Zombie = _zombie()
	assert_true(ZombieEmerge.variants().has(z1.emerge_variant()))
	assert_ne(z1.emerge_variant(), "crawler")
	assert_ne(z2.emerge_variant(), "crawler")


func test_duration_is_variant_seconds_times_round_multiplier() -> void:
	var rs: Dictionary = ZombieEmerge.cfg()["round_scale"]
	assert_almost_eq(ZombieEmerge.round_multiplier(int(rs["start_round"])), float(rs["start"]), 0.001)
	assert_almost_eq(ZombieEmerge.round_multiplier(int(rs["end_round"])), float(rs["end"]), 0.001)
	assert_almost_eq(ZombieEmerge.round_multiplier(int(rs["end_round"]) + 30), float(rs["end"]), 0.001)
	var mid: float = ZombieEmerge.round_multiplier(int((int(rs["start_round"]) + int(rs["end_round"])) / 2.0))
	assert_between(mid, minf(float(rs["start"]), float(rs["end"])), maxf(float(rs["start"]), float(rs["end"])))
	for r: int in [1, 12, 25]:
		RoundManager.current_round = r
		var z: Zombie = _zombie()
		var want: float = ZombieEmerge.variant_seconds(z.emerge_variant()) * ZombieEmerge.round_multiplier(r)
		assert_almost_eq(z._emerge_seconds(), want, 0.001, "round %d: %s rise %.2f s" % [r, z.emerge_variant(), want])
		var ts: float = float(z._tree.get("parameters/SM/Emerge/TimeScale/scale"))
		assert_almost_eq(ts, ZombieClips.length_of(z._emerge_clip) / want, 0.001, "the clip is rescaled to the rise")
		z.deactivate()


func test_clips_bake_at_table_length_and_nothing_pokes_through_before_its_stage() -> void:
	var lib: AnimationLibrary = ZombieClips.library()
	var z: Zombie = _zombie()
	for v: String in ZombieEmerge.variants():
		var clip: String = ZombieEmerge.clip_for(v)
		assert_true(lib.has_animation(clip), clip + " baked")
		assert_almost_eq(lib.get_animation(clip).length, ZombieEmerge.variant_seconds(v), 0.001, clip + " length")
		assert_eq(lib.get_animation(clip).loop_mode, Animation.LOOP_NONE)
		var hand: float = ZombieEmerge.stage(v, "hand", 0.1)
		var head: float = ZombieEmerge.stage(v, "head_out", 0.4)
		z.debug_emerge_seek(v, 0.0)
		assert_lt(_max_bone_y(z), -0.1, "%s: everything under the ground at the start (max bone y %.2f)" % [v, _max_bone_y(z)])
		z.debug_emerge_seek(v, hand * 0.7)
		assert_lt(_max_bone_y(z), -0.05, "%s: still under before the hand bursts (max bone y %.2f)" % [v, _max_bone_y(z)])
		z.debug_emerge_seek(v, hand + 0.02)
		assert_gt(_bone_y(z, "RightHand"), -0.05, "%s: the right hand is out at 'hand' (%.2f)" % [v, _bone_y(z, "RightHand")])
		assert_lt(_bone_y(z, "Head"), -0.1, "%s: the head is still under at 'hand' (%.2f)" % [v, _bone_y(z, "Head")])
		z.debug_emerge_seek(v, head)
		assert_gt(_bone_y(z, "Head"), 0.05, "%s: the head is out at 'head_out' (%.2f)" % [v, _bone_y(z, "Head")])
		z.debug_emerge_seek(v, 1.0)
		if v == "crawler":
			assert_lt(_bone_y(z, "Head"), 0.6, "crawlers stay down at the end")
		else:
			assert_between(_bone_y(z, "Hips"), 0.8, 1.1, "%s: standing at the end (hips %.2f)" % [v, _bone_y(z, "Hips")])
	z.deactivate()


func test_hitboxes_enable_at_head_out_and_on_every_early_exit() -> void:
	var z: Zombie = _zombie()
	assert_eq(z.state, Zombie.State.EMERGE)
	for hb: Hitbox in z._hitboxes:
		assert_eq(hb.collision_layer, 0, "no hitbox before the head is out")
	var head: float = ZombieEmerge.stage(z.emerge_variant(), "head_out", 0.4)
	z._state_t = (head - 0.03) * z._emerge_seconds()
	z._emerge_tick(0.0)
	assert_eq(z._hitboxes[0].collision_layer, 0, "still off just before head_out")
	z._state_t = head * z._emerge_seconds()
	z._emerge_tick(0.0)
	for hb: Hitbox in z._hitboxes:
		assert_eq(hb.collision_layer, Hitbox.LAYER_HITBOX, "every hitbox live at head_out")
	assert_true(z._mound.visible, "the mound shows through the rise")
	z._state_t = z._emerge_seconds() + 0.01
	z._physics_process(0.016)
	assert_eq(z.state, Zombie.State.CHASE, "the chase starts at the end of the rise")
	assert_false(z._mound.visible, "the mound goes when the rise ends")
	z.deactivate()
	# a risen patron (InnOpening.rise_from_floor right after activate) leaves the rise for the get-up: boxes on
	var p: Zombie = _zombie()
	assert_eq(p._hitboxes[0].collision_layer, 0)
	p.rise_from_floor(1.0)
	assert_eq(p.state, Zombie.State.GETUP)
	for hb: Hitbox in p._hitboxes:
		assert_eq(hb.collision_layer, Hitbox.LAYER_HITBOX, "the patron path keeps its hitboxes")
	assert_false(p._mound.visible)
	p.deactivate()
	# a window spawn never waits
	var wsp: ZombieSpawn = ZombieSpawn.new()
	wsp.kind = &"window"
	_host.add_child(wsp)
	var w: Zombie = Zombie.new()
	_host.add_child(w)
	w.activate({"enemy_id": "ganger", "tier": "walk", "health": 100, "variant": "soldier"}, wsp, null)
	assert_ne(w.state, Zombie.State.EMERGE)
	assert_eq(w._hitboxes[0].collision_layer, Hitbox.LAYER_HITBOX)
	w.deactivate()


func test_crawlers_rise_on_their_elbows() -> void:
	var c: Zombie = _zombie({"crawler": true})
	assert_true(c.is_crawler)
	assert_eq(c.emerge_variant(), "crawler")
	assert_true(c.is_severed("LeftUpperLeg") and c.is_severed("RightUpperLeg"), "a spawned crawler has no legs")
	var head: float = ZombieEmerge.stage("crawler", "head_out", 0.4)
	c._state_t = head * c._emerge_seconds()
	c._emerge_tick(0.0)
	for hb: Hitbox in c._hitboxes:
		if hb.limb == &"legs":
			assert_eq(hb.collision_layer, 0, "no leg boxes on a crawler")
		else:
			assert_eq(hb.collision_layer, Hitbox.LAYER_HITBOX)
	c._state_t = c._emerge_seconds() + 0.01
	c._physics_process(0.016)
	assert_eq(c.state, Zombie.State.CHASE)
	assert_eq(c.current_clip_state(), "Crawl", "it crawls off")
	c.deactivate()
	# legs lost mid-rise: the rise switches to the crawler variant at the same progress
	var z: Zombie = _zombie()
	z.debug_emerge_seek("standard", 0.5)
	var k: float = z._emerge_k()
	z.become_crawler()
	assert_eq(z.state, Zombie.State.EMERGE)
	assert_eq(z.emerge_variant(), "crawler")
	assert_almost_eq(z._emerge_k(), k, 0.01, "same progress after the switch")
	z.deactivate()


func test_killed_mid_rise_sinks_back() -> void:
	var z: Zombie = _zombie()
	z._state_t = 0.5 * z._emerge_seconds()
	z._emerge_tick(0.0)
	var alive_before: int = RoundManager.alive
	z.take_damage(z.hp + 1.0, &"torso", &"kar98k", 0, &"bullet")
	assert_eq(z.state, Zombie.State.DEAD)
	assert_true(z._death_sink, "a kill mid-rise sinks the body back")
	assert_lt(float(z._tree.get("parameters/SM/Emerge/TimeScale/scale")), 0.0, "the rise clip runs backward")
	assert_eq(z.current_clip_state(), "Emerge", "no death clip")
	assert_true(z._mound.visible, "the mound stays while it sinks")
	assert_eq(z._hitboxes[0].collision_layer, 0)
	z._state_t = z._sink_corpse_s + 0.1
	z._update_dead(0.016)
	assert_eq(z.state, Zombie.State.INACTIVE, "back in the pool once it is under")
	assert_null(z._ragdoll, "no ragdoll for a sunk body")
	assert_lte(RoundManager.alive, alive_before)
	# a kill once it stands plays a normal death
	var s: Zombie = _zombie()
	s._state_t = s._emerge_seconds() + 0.01
	s._physics_process(0.016)
	assert_eq(s.state, Zombie.State.CHASE)
	s.take_damage(s.hp + 1.0, &"torso", &"kar98k", 0, &"bullet")
	assert_false(s._death_sink)
	assert_eq(s.current_clip_state(), "Death")
	s.deactivate()


func test_surface_class_follows_the_spawn() -> void:
	assert_eq(ZombieEmerge.surface_class("", &"map00_crossroads"), "snow")
	assert_eq(ZombieEmerge.surface_class("", &"map01_kaltenbrunn"), "earth")
	assert_eq(ZombieEmerge.surface_class("wood", &"map00_crossroads"), "earth", "a wooden floor is earth, not snow")
	assert_eq(ZombieEmerge.surface_class("snow", &"map01_kaltenbrunn"), "snow")
	assert_eq(ZombieEmerge.surface_class("metal", &"map02_totenhafen"), "stone")
	assert_eq(ZombieEmerge.sound_key("burst", "stone"), "emerge_burst_earth", "stone shares the earth samples")
	for key: String in ["emerge_burst_snow", "emerge_burst_earth", "emerge_dig_snow", "emerge_dig_earth", "emerge_settle_snow", "emerge_settle_earth"]:
		assert_true((AudioDirector.bank.get("sounds", {}) as Dictionary).has(key), "audio.json has " + key)
	var map_before: StringName = GameState.map_id
	GameState.map_id = &"map00_crossroads"
	_spawn.set_meta("surface", "stone")
	var z: Zombie = _zombie()
	assert_eq(z.emerge_surface(), "stone", "a spawn's surface meta wins")
	z.deactivate()
	_spawn.remove_meta("surface")
	var z2: Zombie = _zombie()
	assert_eq(z2.emerge_surface(), "snow", "Map 0 defaults to snow")
	z2.deactivate()
	GameState.map_id = map_before
	assert_true(ZombieEmerge.mound_material("snow") != ZombieEmerge.mound_material("earth"))
	assert_same(ZombieEmerge.mound_material("snow"), ZombieEmerge.mound_material("snow"), "materials are shared")
