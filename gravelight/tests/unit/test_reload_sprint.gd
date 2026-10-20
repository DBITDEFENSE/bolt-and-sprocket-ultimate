extends GutTest
## Sprint vs reload (WeaponHolder): a sprint cancels a magazine reload with no ammo change, interrupts a
## round-by-round reload keeping the rounds already loaded, drops the pending sound cues, and a reload asked
## for while sprinting starts once the sprint ends. Ammo (mag + reserve) is conserved throughout.

var _p: Player


func before_each() -> void:
	_p = Player.new()
	add_child_autofree(_p)
	_p.set_physics_process(false)
	_p.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _arm(id: StringName, mag: int, reserve: int) -> WeaponInstance:
	var h: WeaponHolder = _p.weapons
	h.give_weapon(id)
	h.current_index = h.slots.find(h.find_weapon(id))
	h.call("_rebuild_gun")
	var w: WeaponInstance = h.current()
	w.mag = mag
	w.reserve = reserve
	h.set("_swap_t", 0.0)
	return w


## Advances the holder `seconds` in 1/60 s steps with the same intent each frame.
func _run(seconds: float, intent: Dictionary = {}) -> void:
	var t: float = 0.0
	while t < seconds:
		_p.weapons.tick(1.0 / 60.0, intent)
		t += 1.0 / 60.0


func test_sprint_cancels_mag_reload_without_ammo_change() -> void:
	var w: WeaponInstance = _arm(&"mp40", 10, 100)
	var h: WeaponHolder = _p.weapons
	h.start_reload()
	assert_true(h.is_reloading(), "reload started")
	_run(w.f("reload_partial") * 0.5)
	assert_true(h.is_reloading(), "still reloading halfway")
	_run(1.0 / 60.0, {"sprinting": true})
	assert_false(h.is_reloading(), "sprinting cancels a magazine reload")
	assert_eq(w.mag, 10, "the old magazine keeps its rounds")
	assert_eq(w.reserve, 100, "nothing taken from the reserve")
	assert_eq((h.get("_cues") as Array).size(), 0, "pending reload cues are dropped")
	var mag_part: Node3D = (h.get("_parts") as Dictionary).get("Mag") as Node3D
	if mag_part != null:
		assert_true(mag_part.visible, "the magazine is back in the gun after the cancel")
	_run(1.0)
	assert_false(h.is_reloading(), "a cancelled reload does not resume by itself")
	assert_eq(w.mag + w.reserve, 110, "ammo conserved")


func test_mag_reload_completes_and_conserves_ammo() -> void:
	var w: WeaponInstance = _arm(&"mp40", 10, 100)
	var h: WeaponHolder = _p.weapons
	h.start_reload()
	_run(w.f("reload_partial") + 0.1)
	assert_false(h.is_reloading(), "finished")
	assert_eq(w.mag, w.mag_size(), "full magazine")
	assert_eq(w.mag + w.reserve, 110, "ammo conserved")


func test_sprint_interrupts_shell_reload_keeping_loaded_shells() -> void:
	var w: WeaponInstance = _arm(&"trench_gun", 1, 20)
	var h: WeaponHolder = _p.weapons
	h.start_reload()
	# two shells' worth of time plus a bit into the third
	_run(w.f("reload_partial") * 2.0 + 0.15)
	assert_true(h.is_reloading(), "still loading shells")
	assert_eq(w.mag, 3, "two shells loaded")
	_run(1.0 / 60.0, {"sprinting": true})
	assert_false(h.is_reloading(), "sprinting interrupts the shell reload")
	assert_eq(w.mag, 3, "loaded shells stay in the gun")
	assert_eq(w.reserve, 18, "the shell in hand was not taken")
	_run(1.0, {"sprinting": true})
	assert_eq(w.mag + w.reserve, 21, "ammo conserved")


func test_reload_requested_while_sprinting_starts_after() -> void:
	var w: WeaponInstance = _arm(&"mp40", 5, 100)
	var h: WeaponHolder = _p.weapons
	_run(1.0 / 60.0, {"sprinting": true, "reload": true})
	assert_false(h.is_reloading(), "no reload while sprinting")
	_run(0.2, {"sprinting": true})
	assert_false(h.is_reloading(), "still sprinting")
	_run(1.0 / 60.0)
	assert_true(h.is_reloading(), "the queued reload starts when the sprint ends")
	_run(w.f("reload_partial") + 0.1)
	assert_eq(w.mag, w.mag_size(), "and completes")
	assert_eq(w.mag + w.reserve, 105, "ammo conserved")


func test_queued_reload_dropped_on_weapon_switch() -> void:
	_arm(&"mp40", 5, 100)
	var h: WeaponHolder = _p.weapons
	_run(1.0 / 60.0, {"sprinting": true, "reload": true})
	assert_true(bool(h.get("_reload_queued")), "queued while sprinting")
	var tg: WeaponInstance = _arm(&"trench_gun", 2, 20)
	h.call("_select", h.slots.find(tg))
	assert_false(bool(h.get("_reload_queued")), "switching weapons drops the queued reload")
	_run(1.0 / 60.0)
	assert_false(h.is_reloading(), "the queued reload was for the other gun")
