extends GutTest
## T-284 (the owner: "MAKE THE ZOMBIES MORE TERRIFYING"): the scare is presentation only. These tests pin that the
## switch puts every body back as it was, that the scare never draws from the game's global random generator (which
## decides crawlers, death clips and the like), that a body's first sight plays once a life, that screams are capped
## across the horde, that twitches and the snap only touch the additive springs and the look-at, and that the
## promoted recorded take is used only with the switch on.

var _host: Node3D
var _spawn: ZombieSpawn
var _cam: Camera3D
var _saved: Array = []


func before_each() -> void:
	_saved = [Zombie.t284_terror, RoundManager.current_round]
	Zombie.t284_terror = true
	GLSettings.values["gore"] = "off"
	RoundManager.current_round = 5
	GameState.player_ids = [1]
	Economy.reset([1])
	_host = Node3D.new()
	add_child_autofree(_host)
	_spawn = ZombieSpawn.new()
	_spawn.kind = &"window"
	_host.add_child(_spawn)
	_cam = Camera3D.new()
	_host.add_child(_cam)
	_cam.current = true
	_cam.global_position = Vector3(0.4, 1.5, 5.0)
	_cam.look_at(Vector3(0, 1.1, 0))


func after_each() -> void:
	Zombie.t284_terror = _saved[0]
	RoundManager.current_round = _saved[1]


func _zombie(rng_seed: int) -> Zombie:
	seed(rng_seed)
	var z: Zombie = Zombie.new()
	_host.add_child(z)
	z.activate({"enemy_id": "ganger", "tier": "walk", "health": 400.0, "variant": "villager"}, _spawn, null)
	z.set_process(false)
	z.set_physics_process(false)
	z.global_position = Vector3.ZERO
	return z


func test_the_look_is_rolled_from_the_body_and_switched_off_is_the_old_look() -> void:
	var a: Vector4 = ZombieTerror.look_vec(1234)
	assert_eq(a, ZombieTerror.look_vec(1234), "the same body, the same eyes (co-op peers agree)")
	assert_ne(a, ZombieTerror.look_vec(1235), "another body, another roll")
	assert_gt(a.x, 0.0, "the eyes glow")
	var z: Zombie = _zombie(3)
	var on: Vector4 = (z.get("_inst") as Dictionary).get("inst_terror", Vector4.ZERO)
	assert_gt(on.x, 0.0, "switched on: the body carries the eyes, the rot and the wet")
	Zombie.t284_terror = false
	z._apply_look()
	assert_eq((z.get("_inst") as Dictionary).get("inst_terror"), Vector4.ZERO, "switched off: zero, which the shader turns into the T-269 look")
	z.queue_free()


func test_the_scare_never_draws_from_the_global_random_generator() -> void:
	# (the camera far off: no sound plays, so AudioDirector's own pitch jitter, which every sound in the game draws from
	# the global generator, is not in the measured stretch; the scare's own choices are)
	_cam.global_position = Vector3(0, 1.5, 40.0)
	var z: Zombie = _zombie(7)
	z.state = Zombie.State.CHASE
	Zombie._vl_frame = -1
	z._process(1.0 / 60.0)
	ZombieTerror._next_scream_ms = Time.get_ticks_msec() + 600000   # (no scream: its sound's pitch jitter, see above)
	seed(99)
	var want: Array = [randf(), randf(), randf()]
	seed(99)
	for i: int in 400:
		z._terror_tick(1.0 / 60.0)
		z._twitch(ZombieTerror.sec("twitch"))
	z._first_sight(ZombieTerror.sec("first_sight"))
	z._terror_reset()
	assert_eq([randf(), randf(), randf()], want, "the global sequence is untouched by twitches, the first sight and the resets")
	ZombieTerror._next_scream_ms = 0
	z.queue_free()


func test_a_twitch_kicks_only_the_springs_and_a_first_sight_snaps_the_look_once_a_life() -> void:
	var z: Zombie = _zombie(11)
	var mod: ZombieBodyModifier = z.get("_modifier") as ZombieBodyModifier
	assert_false(mod.springs_active())
	var before: Vector3 = z.global_position
	var st: Zombie.State = z.state
	z._twitch(ZombieTerror.sec("twitch"))
	assert_true(mod.springs_active(), "a twitch is a spring kick (additive on the recorded pose)")
	assert_eq(z.global_position, before, "the body does not move")
	assert_eq(z.state, st, "and keeps its state")
	var look: LookAtModifier3D = z.get("_look") as LookAtModifier3D
	var smooth: float = float(GLData.table("anim")["look_at"]["smooth_s"])
	var fs0: int = ZombieTerror.first_sights
	z._first_sight(ZombieTerror.sec("first_sight"))
	assert_eq(ZombieTerror.first_sights, fs0 + 1)
	assert_almost_eq(look.duration, float(ZombieTerror.sec("first_sight")["look_snap_s"]), 0.0001, "the look-at snaps")
	for i: int in 60:
		z._terror_tick(1.0 / 60.0)
	assert_almost_eq(look.duration, smooth, 0.0001, "and turns at its own speed again after the hold")
	z._terror_reset()
	assert_false(bool(z.get("_terror_seen")), "a new life sees its prey for the first time again")
	z.queue_free()


func test_screams_are_capped_across_the_horde() -> void:
	ZombieTerror._next_scream_ms = 0
	assert_true(ZombieTerror.scream_ok(), "the first scream plays")
	for i: int in 10:
		assert_false(ZombieTerror.scream_ok(), "the next ones wait scream_gap_s")
	ZombieTerror._next_scream_ms = 0


func test_the_barricade_queue_reaches_with_the_recorded_take_only_when_switched_on() -> void:
	ZombieClips.library()
	if not ZombieClips.mocap_enabled():
		pending("the licensed bank is not built in this checkout")
		return
	assert_eq(ZombieClips.visual_clip("window_wait"), "mco_reach", "switched on: the recorded reach loop")
	Zombie.t284_terror = false
	assert_ne(ZombieClips.visual_clip("window_wait"), "mco_reach", "switched off: as before")


func test_the_sounds_are_in_the_bank() -> void:
	var sounds: Dictionary = AudioDirector.bank.get("sounds", {})
	for key: String in ["zombie_scream", "zombie_growl_low", "zombie_breath_close", "zombie_wet", "zombie_twitch", "zombie_gurgle", "horde_swell"]:
		assert_true(sounds.has(key), key)
		for f: String in (sounds[key] as Dictionary)["files"]:
			assert_true(ResourceLoader.exists(f), f)
