extends GutTest
## Sprint vs reload (WeaponHolder): a sprint cancels a rifle's magazine reload with no ammo change, interrupts a
## round-by-round reload keeping the rounds already loaded, drops the pending sound cues, and a reload asked
## for while sprinting starts once the sprint ends. Ammo (mag + reserve) is conserved throughout.
## T-083: SMGs and pistols reload on the run (movement.json "sprint_reload"), and so does any gun wearing the
## Paratrooper Sling (attachments.json grip "quick_sling", props.sprint_reload); firing still waits for the sprint.

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


func test_sprint_cancels_rifle_mag_reload_without_ammo_change() -> void:
	var w: WeaponInstance = _arm(&"m1_carbine", 5, 100)
	var h: WeaponHolder = _p.weapons
	assert_false(WeaponHolder.sprint_reload_allowed(w), "a rifle does not reload on the run")
	h.start_reload()
	assert_true(h.is_reloading(), "reload started")
	_run(w.f("reload_partial") * 0.5)
	assert_true(h.is_reloading(), "still reloading halfway")
	_run(1.0 / 60.0, {"sprinting": true})
	assert_false(h.is_reloading(), "sprinting cancels a magazine reload")
	assert_eq(w.mag, 5, "the old magazine keeps its rounds")
	assert_eq(w.reserve, 100, "nothing taken from the reserve")
	assert_eq((h.get("_cues") as Array).size(), 0, "pending reload cues are dropped")
	var mag_part: Node3D = (h.get("_parts") as Dictionary).get("Mag") as Node3D
	if mag_part != null:
		assert_true(mag_part.visible, "the magazine is back in the gun after the cancel")
	_run(1.0)
	assert_false(h.is_reloading(), "a cancelled reload does not resume by itself")
	assert_eq(w.mag + w.reserve, 105, "ammo conserved")


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
	var w: WeaponInstance = _arm(&"m1_carbine", 5, 100)
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
	_arm(&"m1_carbine", 5, 100)
	var h: WeaponHolder = _p.weapons
	_run(1.0 / 60.0, {"sprinting": true, "reload": true})
	assert_true(bool(h.get("_reload_queued")), "queued while sprinting")
	var tg: WeaponInstance = _arm(&"trench_gun", 2, 20)
	h.call("_select", h.slots.find(tg))
	assert_false(bool(h.get("_reload_queued")), "switching weapons drops the queued reload")
	_run(1.0 / 60.0)
	assert_false(h.is_reloading(), "the queued reload was for the other gun")


# ---------------------------------------------------------------- T-083: reloading on the run

func test_sprint_reload_classes_in_data() -> void:
	var sr: Dictionary = GLData.table("movement").get("sprint_reload", {})
	assert_true(sr.has("default") and not bool(sr["default"]), "off by default")
	assert_true(bool(sr.get("pistol", false)) and bool(sr.get("smg", false)), "pistols and SMGs reload on the run")
	for cls: String in ["rifle", "bolt", "assault", "shotgun", "lmg", "sniper", "launcher", "special", "wonder"]:
		assert_false(bool(sr.get(cls, false)), "%s waits for the sprint to end" % cls)
	var t: Dictionary = GLData.table("weapons")
	for id: String in (t["weapons"] as Dictionary).keys():
		var w: WeaponInstance = WeaponInstance.create(StringName(id))
		var cls: StringName = w.weapon_class()
		assert_eq(WeaponHolder.sprint_reload_allowed(w), cls == &"pistol" or cls == &"smg", id)
		# every class that waits has the Paratrooper Sling at the bench (wonder weapons are refused there anyway)
		if cls != &"pistol" and cls != &"smg" and WeaponKit.accepts(w):
			assert_true(WeaponKit.is_known(w, "grip", "quick_sling"), "%s can buy a Paratrooper Sling" % id)
			assert_true(bool((WeaponKit.option_def(w, "grip", "quick_sling").get("props", {}) as Dictionary).get("sprint_reload", false)), id)
		elif WeaponKit.accepts(w):
			assert_false(WeaponKit.is_known(w, "grip", "quick_sling"), "%s has it by class, no sling to sell" % id)
	assert_false(WeaponHolder.sprint_reload_allowed(null))


func test_smg_reload_survives_a_sprint() -> void:
	var w: WeaponInstance = _arm(&"mp40", 10, 100)
	var h: WeaponHolder = _p.weapons
	assert_true(WeaponHolder.sprint_reload_allowed(w))
	h.start_reload()
	_run(w.f("reload_partial") * 0.5)
	assert_true(h.is_reloading(), "halfway")
	_run(0.2, {"sprinting": true})
	assert_true(h.is_reloading(), "an SMG keeps reloading while sprinting")
	assert_eq(w.mag, 10, "nothing moved yet")
	_run(w.f("reload_partial") * 0.5 + 0.1, {"sprinting": true})
	assert_false(h.is_reloading(), "and finishes on the run")
	assert_eq(w.mag, w.mag_size(), "full magazine")
	assert_eq(w.mag + w.reserve, 110, "ammo conserved")


func test_pistol_reload_starts_and_finishes_while_sprinting() -> void:
	for id: StringName in [&"m1911", &"webley", &"luger_p08"]:
		var w: WeaponInstance = _arm(id, 1, 40)
		var h: WeaponHolder = _p.weapons
		_run(1.0 / 60.0, {"sprinting": true, "reload": true})
		assert_true(h.is_reloading(), "%s: a reload starts while sprinting" % id)
		assert_false(bool(h.get("_reload_queued")), "%s: nothing queued" % id)
		var total: float = 0.0
		while h.is_reloading() and total < 8.0:
			_run(1.0 / 60.0, {"sprinting": true})
			total += 1.0 / 60.0
		assert_false(h.is_reloading(), "%s: finished while still sprinting (%.1f s)" % [id, total])
		assert_eq(w.mag, w.mag_size(), "%s: full" % id)
		assert_eq(w.mag + w.reserve, 41, "%s: ammo conserved" % id)


func test_rifle_with_paratrooper_sling_reloads_on_the_run() -> void:
	var w: WeaponInstance = _arm(&"m1_garand", 2, 40)
	var h: WeaponHolder = _p.weapons
	assert_false(WeaponHolder.sprint_reload_allowed(w), "a plain Garand waits")
	WeaponKit.install(w, "grip", "quick_sling")   # (fitting a part tops the magazine up: empty it again below)
	h.call("_rebuild_gun")
	h.set("_swap_t", 0.0)
	w.mag = 2
	w.reserve = 40
	assert_true(WeaponHolder.sprint_reload_allowed(w), "slung, it reloads on the run")
	assert_eq(WeaponKit.option_name(w, "grip", "quick_sling"), "Paratrooper Sling")
	h.start_reload()
	assert_true(h.is_reloading(), "reload started")
	_run(w.f("reload_partial") * 0.4)
	_run(0.2, {"sprinting": true})
	assert_true(h.is_reloading(), "the sprint does not cancel it")
	_run(w.f("reload_partial") * 0.6 + 0.1, {"sprinting": true})
	assert_false(h.is_reloading(), "finished")
	assert_eq(w.mag, w.mag_size(), "full")
	assert_eq(w.mag + w.reserve, 42, "ammo conserved")
	# an upgraded gun keeps the sling's flag through its upgraded block
	var up: WeaponInstance = WeaponInstance.create(&"m1_garand_up")
	WeaponKit.install(up, "grip", "quick_sling")
	assert_true(WeaponHolder.sprint_reload_allowed(up), "Pilgrim's Sling on the taught Garand")
	assert_eq(WeaponKit.option_name(up, "grip", "quick_sling", true), "Pilgrim's Sling")


func test_sprint_reload_never_fires_while_sprinting() -> void:
	var w: WeaponInstance = _arm(&"thompson", 10, 100)
	var h: WeaponHolder = _p.weapons
	_run(1.0 / 60.0, {"sprinting": true, "reload": true})
	assert_true(h.is_reloading())
	_run(0.1, {"sprinting": true, "fire_pressed": true, "fire_held": true})
	assert_true(h.is_reloading(), "the trigger does nothing at a run")
	assert_eq(w.mag, 10, "no shot while sprinting")
	# the sprint ends: the sprint-out still applies before the first shot can go
	_run(1.0 / 60.0, {"fire_pressed": true, "fire_held": true})
	assert_eq(w.mag, 10, "sprint-out: not yet")
	assert_gt(float(h.get("_sprint_out_t")), 0.0, "the sprint-out timer runs")
