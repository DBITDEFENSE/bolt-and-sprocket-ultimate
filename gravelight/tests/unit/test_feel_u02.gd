extends GutTest
## Update 02 §1 (T-046) gunplay feel at the WeaponHolder level: no eaten inputs out of a sprint (a fire press is
## buffered and fires within the weapon's sprint-out + one frame; ADS starts on the first frame out of a sprint),
## per-class sprint-out times, the slide / mantle fire block, the deterministic recoil climb and its recovery,
## hip bloom, and the frame-rate independent crouch ease.

const DT: float = 1.0 / 60.0

var _p: Player


func before_each() -> void:
	_p = Player.new()
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _arm(id: StringName) -> WeaponInstance:
	var h: WeaponHolder = _p.weapons
	h.give_weapon(id)
	h.current_index = h.slots.find(h.find_weapon(id))
	h.call("_rebuild_gun")
	var w: WeaponInstance = h.current()
	w.refill()
	h.set("_swap_t", 0.0)
	h.set("_fire_cd", 0.0)
	return w


func _tick(intent: Dictionary = {}) -> void:
	_p.weapons.tick(DT, intent)


## Sprints a while, then on the first frame out of the sprint presses fire once (a tap: never held). Returns the
## seconds until the shot left the barrel, or -1.
func _tap_out_of_sprint(id: StringName, hold_fire: bool) -> float:
	var w: WeaponInstance = _arm(id)
	for i: int in 20:
		_tick({"sprinting": true})
	var mag0: int = w.mag
	_tick({"fire_pressed": true, "fire_held": hold_fire})
	var t: float = DT
	while t < 1.5:
		if w.mag < mag0:
			return t
		_tick({"fire_held": hold_fire})
		t += DT
	return -1.0 if w.mag >= mag0 else t


func test_sprint_out_times_per_class() -> void:
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"m1911")), 0.15, 0.001, "pistol")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"mp40")), 0.2, 0.001, "SMG")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"m1_garand")), 0.3, 0.001, "rifle")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"kar98k")), 0.3, 0.001, "bolt")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"stg44")), 0.3, 0.001, "assault")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"mg42")), 0.45, 0.001, "LMG")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"panzerschreck")), 0.5, 0.001, "launcher")
	assert_almost_eq(WeaponHolder.sprint_out_time(WeaponInstance.create(&"mp40_up")), 0.2, 0.001, "upgraded keeps its base class")


func test_fire_tap_out_of_sprint_is_never_eaten() -> void:
	for id: StringName in [&"m1911", &"mp40", &"thompson", &"m1_garand", &"bar", &"mg42", &"panzerschreck"]:
		var so: float = WeaponHolder.sprint_out_time(WeaponInstance.create(id))
		var t: float = _tap_out_of_sprint(id, false)
		assert_true(t > 0.0, "%s: a single-frame fire tap out of a sprint fires" % id)
		assert_true(t <= so + DT * 1.5, "%s: fires within sprint-out %.2f + one frame (took %.3f)" % [id, so, t])
		assert_true(t >= so - DT * 1.5, "%s: but not before the sprint-out (took %.3f)" % [id, t])


func test_fire_held_out_of_sprint_fires_on_time() -> void:
	var t: float = _tap_out_of_sprint(&"thompson", true)
	assert_true(t > 0.0 and t <= 0.2 + DT * 1.5, "held fire out of a sprint: first round at the sprint-out (took %.3f)" % t)


func test_fire_pressed_while_still_sprinting_is_buffered() -> void:
	# the press lands on a frame the holder still sees as sprinting (e.g. a bot / late intent): it must survive
	var w: WeaponInstance = _arm(&"m1911")
	for i: int in 10:
		_tick({"sprinting": true})
	var mag0: int = w.mag
	_tick({"sprinting": true, "fire_pressed": true, "fire_held": true})
	assert_true(_p.weapons.fire_pending(), "the press is pending")
	var t: float = 0.0
	while t < 0.6 and w.mag == mag0:
		_tick({})
		t += DT
	assert_eq(w.mag, mag0 - 1, "the buffered shot fired once the sprint ended")
	assert_false(_p.weapons.fire_pending(), "and the buffer is spent")


func test_ads_starts_on_the_first_frame_out_of_sprint() -> void:
	_arm(&"mp40")
	for i: int in 20:
		_tick({"sprinting": true, "ads": true})
	assert_eq(_p.weapons.ads_t, 0.0, "no ADS while sprinting")
	_tick({"ads": true})
	assert_gt(_p.weapons.ads_t, 0.0, "ADS starts the frame the sprint ends")
	var t: float = DT
	while _p.weapons.ads_t < 1.0 and t < 1.0:
		_tick({"ads": true})
		t += DT
	assert_almost_eq(t, 0.18, DT * 2.0, "SMG ADS in takes its ads_time (0.18 s)")


func test_slide_or_mantle_fire_block_buffers_the_press() -> void:
	var w: WeaponInstance = _arm(&"m1_garand")
	var mag0: int = w.mag
	_tick({"fire_pressed": true, "fire_held": true, "fire_block": true})
	for i: int in 10:
		_tick({"fire_block": true})
	assert_eq(w.mag, mag0, "no shot while blocked (early slide / mantle)")
	_tick({})
	assert_eq(w.mag, mag0 - 1, "the press fires the first frame the block lifts")


func test_recoil_climb_is_deterministic_and_recovers() -> void:
	_arm(&"thompson")
	var h: WeaponHolder = _p.weapons
	var climbs: Array = []
	for burst: int in 2:
		var start: float = float(_p.get("_pitch"))
		var seq: PackedFloat32Array = []
		var last: float = start
		var shots: int = 0
		var w: WeaponInstance = h.current()
		w.mag = w.mag_size()
		while shots < 8:
			var m: int = w.mag
			_tick({"fire_held": true})
			_p.call("_tick_recoil_recovery", DT)
			if w.mag < m:
				shots += 1
				var now: float = float(_p.get("_pitch"))
				seq.append(snappedf(rad_to_deg(now - last), 0.0001))
				last = now
		climbs.append(seq)
		var top: float = float(_p.get("_pitch"))
		assert_gt(top, start, "a burst climbs")
		for i: int in 120:
			_tick({})
			_p.call("_tick_recoil_recovery", DT)
		var settled: float = float(_p.get("_pitch"))
		assert_lt(settled, top - (top - start) * 0.5, "most of the climb recovers after you stop firing")
		assert_gt(settled, start - 0.0001, "but never past where you started")
	assert_eq(climbs[0], climbs[1], "the vertical climb is the same pattern every burst")
	assert_gt(float(climbs[0][5]), float(climbs[0][0]), "the climb steepens over the burst (v_growth)")


func test_hip_bloom_grows_while_firing_and_shrinks_after() -> void:
	var w: WeaponInstance = _arm(&"mp40")
	var h: WeaponHolder = _p.weapons
	var b0: float = h.spread_deg()
	for i: int in 30:
		_tick({"fire_held": true})
	assert_gt(h.bloom, 1.0, "bloom grows with a burst")
	assert_gt(h.spread_deg(), b0, "the hip cone (and the crosshair) opens")
	var peak: float = h.bloom
	for i: int in 30:
		_tick({})
	assert_lt(h.bloom, peak * 0.5, "and shrinks again when you stop")
	assert_true(w.mag < w.mag_size(), "it fired")


func test_last_round_click_key_exists() -> void:
	assert_true(AudioDirector.has_sound("last_round_click"), "the last-bullet click is in the audio bank")
	assert_true(AudioDirector.has_sound("footstep_hay"), "hay footsteps are in the audio bank")


func test_crouch_ease_is_frame_rate_independent() -> void:
	var eyes: Array = []
	for fps: int in [30, 60, 144]:
		_p.set("_eye", Player.EYE_STAND)
		var t: float = 0.0
		while t < 0.2 - 0.0001:
			_p.call("_shape_toward", Player.CROUCH_HEIGHT, Player.EYE_CROUCH, 1.0 / float(fps))
			t += 1.0 / float(fps)
		eyes.append(float(_p.get("_eye")))
	assert_almost_eq(float(eyes[0]), float(eyes[2]), 0.03, "30 fps and 144 fps reach the same eye height in 0.2 s")
	assert_lt(float(eyes[1]), Player.EYE_STAND - 0.4, "and most of the way down in 0.2 s")
