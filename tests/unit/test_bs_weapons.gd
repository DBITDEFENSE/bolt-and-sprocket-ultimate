extends GutTest
## B&S weapon framework + the four M1 guns, headless with real physics (Bolt, camera, TestDummy targets).
## Input is scripted through WeaponManager.scripted / aim_override, so no window or devices are involved.

var _world: Node3D
var _bolt: Bolt
var _cam: BoltCamera
var _wm: WeaponManager
var _saved: Dictionary = {}


func _box(size: Vector3, pos: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	_world.add_child(b)
	return b


func before_each() -> void:
	_saved = {"weapons": BS.weapons.duplicate(true), "order": BS.weapon_order.duplicate(), "cur": BS.current_weapon,
		"bolts": BS.bolts, "flags": BS.flags.duplicate(true), "block": BS.ui_block}
	BS.weapons = {}
	BS.weapon_order = []
	BS.current_weapon = &""
	BS.bolts = 0
	BS.ui_block = 0
	BS.god_mode = false
	BeatClock.t = 0.0
	_world = Node3D.new()
	add_child_autofree(_world)
	_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_bolt = Bolt.new()
	_bolt.position = Vector3(0, 0.95, 0)
	_world.add_child(_bolt)
	_cam = BoltCamera.new()
	_cam.target = _bolt
	_world.add_child(_cam)
	_bolt.camera = _cam
	_cam.yaw = 0.0
	_bolt.scripted = {"dir": Vector3.ZERO}
	_wm = WeaponManager.attach_to(_bolt, false)
	_wm.aim_override = Vector3(0, 0, -1)
	_wm.ammo_drops_enabled = false
	_wm.rng.seed = 7


func after_each() -> void:
	Game.wheel_open = false
	Engine.time_scale = 1.0
	BS.weapons = _saved["weapons"]
	BS.weapon_order = _saved["order"]
	BS.current_weapon = _saved["cur"]
	BS.bolts = _saved["bolts"]
	BS.flags = _saved["flags"]
	BS.ui_block = _saved["block"]


func _dummy(pos: Vector3, hp: float = 9999.0) -> TestDummy:
	var d: TestDummy = TestDummy.new()
	d.hp = hp
	d.max_hp = hp
	d.position = pos
	_world.add_child(d)
	return d


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _no_gun_model() -> void:
	# muzzle = aim origin + 0.6 m (deterministic spawn point for projectile tests)
	if _wm.gun_visual != null:
		_wm.gun_visual.queue_free()
		_wm.gun_visual = null


func _equip(id: StringName) -> BSWeapon:
	if not _wm.owns(id):
		_wm.give(id)
	_wm.select(id)
	return _wm.weapon(id)


func _set_level(id: StringName, lv: int) -> void:
	var st: Dictionary = BS.weapons[String(id)]
	st["xp"] = float(WeaponData.thresholds()[lv - 1])
	st["level"] = lv


func _tap_fire(frames_held: int = 2) -> void:
	_wm.scripted = {"fire": true}
	await _frames(frames_held)
	_wm.scripted = {"fire": false}
	await _frames(2)


# ------------------------------------------------------------------ data + progression

func test_data_covers_all_16_guns_with_original_numbers() -> void:
	var ids: Array[StringName] = WeaponData.ids()
	assert_eq(ids.size(), 16, "16 guns in wheel order")
	var base: Array = Data.table("bs_source/AMMO_BASE")
	var per: Array = Data.table("bs_source/AMMO_PER_TIER")
	var wbd: Array = Data.table("bs_source/W_BASE_DMG")
	for id: StringName in ids:
		var d: Dictionary = WeaponData.def(id)
		assert_true(d.has("damage") and d.has("interval") and d.has("price") and d.has("unlock"), "%s has core stats" % id)
		assert_true(WeaponData.signature(id, 0).has("id") and WeaponData.signature(id, 1).has("id"), "%s has Signature A/B" % id)
		var si: int = int(d["src_index"])
		if si > 0:
			assert_eq(int(d["ammo_base"]), int(base[si]), "%s AMMO_BASE" % id)
			assert_eq(int(d["ammo_per_tier"]), int(per[si]), "%s AMMO_PER_TIER" % id)
			assert_eq(int(d["w_base_dmg"]), int(wbd[si]), "%s W_BASE_DMG" % id)
	assert_eq(WeaponData.max_ammo(&"omni_blaster", 3), -1, "the Omni-Blaster has no ammo (heat)")
	assert_eq(WeaponData.mod_price("dmg", 1), 60)
	assert_eq(WeaponData.mod_price("rate", 3), 140)
	assert_eq(WeaponData.mod_price("ammo", 2), 70)


func test_xp_thresholds() -> void:
	assert_eq(WeaponData.level_for_xp(0), 1)
	assert_eq(WeaponData.level_for_xp(599), 1)
	assert_eq(WeaponData.level_for_xp(600), 2)
	assert_eq(WeaponData.level_for_xp(1799), 2)
	assert_eq(WeaponData.level_for_xp(1800), 3)
	assert_eq(WeaponData.level_for_xp(4000), 4)
	assert_eq(WeaponData.level_for_xp(7999), 4)
	assert_eq(WeaponData.level_for_xp(8000), 5)
	assert_eq(WeaponData.level_for_xp(1e9), 5)


func test_xp_level_ups_and_catch_up() -> void:
	watch_signals(EventBus)
	_wm.add_xp(&"void_ripper", 600.0)
	assert_eq(int(BS.weapons["void_ripper"]["level"]), 2, "600 XP = V2")
	assert_signal_emitted_with_parameters(EventBus, "weapon_leveled", [&"void_ripper", 2])
	# catch-up: the Zap (V1) is below the floor of the others' average -> x2
	_set_level(&"omni_blaster", 3)
	_set_level(&"void_ripper", 3)
	_wm.add_xp(&"sprocket_zap", 300.0)
	assert_eq(float(BS.weapons["sprocket_zap"]["xp"]), 600.0, "catch-up doubles XP")
	_wm.xp_enabled = false
	_wm.add_xp(&"sprocket_zap", 5000.0)
	assert_eq(float(BS.weapons["sprocket_zap"]["xp"]), 600.0, "no XP in the Firing Range")


func test_damage_gives_xp_per_hp_plus_kill() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6), 20.0)
	await _frames(2)
	var w: BSWeapon = _wm.weapon(&"sprocket_zap")
	var killed: bool = w.deal(d, 50.0, d.get_center())
	assert_true(killed)
	assert_eq(float(BS.weapons["sprocket_zap"]["xp"]), 20.0 + 10.0, "overkill doesn't count; +10 per kill")


func test_mod_multipliers_are_pure_stats() -> void:
	assert_almost_eq(WeaponData.dmg_mul(0, 1), 1.0, 0.0001)
	assert_almost_eq(WeaponData.dmg_mul(3, 1), 1.75, 0.0001, "+25% per damage tier")
	assert_almost_eq(WeaponData.dmg_mul(1, 5), 1.25 * 1.24, 0.0001, "V5 adds +24%")
	assert_almost_eq(WeaponData.rate_mul(3), 0.55, 0.0001, "-15% interval per tier")
	assert_eq(WeaponData.max_ammo(&"void_ripper", 2, 1), 24, "12 + 6 x 2")
	assert_eq(WeaponData.max_ammo(&"void_ripper", 2, 2), 27, "V2 +10% (rounded up)")
	assert_eq(WeaponData.max_ammo(&"sprocket_zap", 0, 5), 36, "V5 +20%")
	assert_almost_eq(WeaponData.heat_capacity(&"omni_blaster", 1), 120.0, 0.001, "Heat Sink +20")
	BS.bolts = 1000
	assert_true(_wm.buy_mod(&"void_ripper", "dmg"))
	assert_eq(BS.bolts, 940, "tier 1 damage costs 60")
	var w: BSWeapon = _wm.weapon(&"void_ripper")
	assert_almost_eq(w.dmg(30.0), 37.5, 0.001)
	assert_true(_wm.buy_mod(&"void_ripper", "rate"))
	assert_almost_eq(w.interval(1.0), 0.85, 0.0001)


func test_signature_and_omega_hooks() -> void:
	BS.bolts = 100000
	assert_false(_wm.install_signature(&"omni_blaster", 0), "Signature Mods unlock at V3")
	_set_level(&"omni_blaster", 3)
	assert_true(_wm.install_signature(&"omni_blaster", 1))
	assert_eq(BS.bolts, 100000 - 200, "200 bolts to install")
	assert_eq(_wm.weapon(&"omni_blaster").sig(), &"thermal_debt")
	assert_true(_wm.install_signature(&"omni_blaster", 0))
	assert_eq(BS.bolts, 100000 - 200, "swapping is free")
	assert_eq(_wm.can_evolve(&"omni_blaster"), "bs.forge.deny.01", "below V5")
	_set_level(&"omni_blaster", 5)
	assert_eq(_wm.can_evolve(&"omni_blaster"), "bs.forge.deny.02", "mods missing")
	for s: String in WeaponData.MOD_SLOTS:
		for i: int in 3:
			assert_true(_wm.buy_mod(&"omni_blaster", s))
	assert_eq(_wm.can_evolve(&"omni_blaster"), "")
	assert_true(_wm.evolve(&"omni_blaster"))
	assert_true(_wm.weapon(&"omni_blaster").omega())
	assert_eq(_wm.weapon(&"omni_blaster").call("hot_every"), 3, "Ω OVERTIME: every 3rd shot is hot")


# ------------------------------------------------------------------ ammo + heat

func test_ammo_counts_spend_and_pickups() -> void:
	_no_gun_model()
	var w: BSWeapon = _equip(&"void_ripper")
	assert_eq(w.ammo(), 12, "Void Ripper starts with 12")
	assert_eq(_wm.weapon(&"sprocket_zap").ammo(), 30, "Zap starts with 30")
	await _tap_fire()
	assert_eq(w.ammo(), 11)
	w.set_ammo(0)
	watch_signals(EventBus)
	await _tap_fire()
	assert_eq(w.ammo(), 0)
	assert_signal_emitted(EventBus, "hint", "empty gun shows the original hint")
	assert_eq(_wm.add_family_ammo("void"), 6, "a purple orb gives +6 Void Ripper")
	w.set_ammo(10)
	_wm.add_family_ammo("void")
	assert_eq(w.ammo(), 12, "capped at max ammo")
	_wm.weapon(&"sprocket_zap").set_ammo(0)
	var orb: AmmoOrb = AmmoOrb.spawn(_world, Vector3(0, 1.0, -0.5), "charge")
	await _frames(3)
	assert_false(is_instance_valid(orb) and not orb.collected, "Bolt picks up the orb")
	assert_eq(_wm.weapon(&"sprocket_zap").ammo(), 10, "a cyan orb gives +10 Zap")


func test_blaster_heat_overheat_and_vent() -> void:
	var b: BSWeapon = _equip(&"omni_blaster")
	assert_eq(b.get("heat"), 0.0)
	for i: int in 16:
		b.call("_fire")
	assert_almost_eq(float(b.get("heat")), 96.0, 0.01, "+6 heat per shot")
	assert_false(b.call("overheated"))
	b.call("_fire")
	assert_true(b.call("overheated"), "17 shots overheat")
	b.tick(0.5)
	assert_true(b.call("overheated"), "1.0 s forced vent")
	b.tick(0.51)
	assert_false(b.call("overheated"))
	assert_almost_eq(float(b.get("heat")), 0.0, 0.01, "vented to zero")
	b.set("heat", 50.0)
	b.set("idle_t", 0.0)
	b.tick(0.3)
	assert_almost_eq(float(b.get("heat")), 50.0, 0.01, "no vent within 0.35 s of a shot")
	b.tick(0.1)
	b.tick(0.5)
	assert_almost_eq(float(b.get("heat")), 50.0 - 40.0 * 0.6, 0.5, "vents at 40/s")
	_set_level(&"omni_blaster", 3)
	assert_almost_eq(float(b.call("vent_rate")), 55.0, 0.001, "V3 vents 55/s")


# ------------------------------------------------------------------ the four guns on a dummy

func test_blaster_hitscan_damage_and_hot_round() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	_equip(&"omni_blaster")
	_wm.scripted = {"fire": true}
	await _frames(45)                    # 0.75 s at 0.13 s per shot = 6 shots
	_wm.scripted = {"fire": false}
	assert_gte(d.hits.size(), 5, "rapid hitscan bolts hit the dummy")
	assert_eq((d.hits[0] as Combat.Hit).amount, 8.0, "8 per bolt")
	assert_eq((d.hits[4] as Combat.Hit).amount, 16.0, "every 5th is a 16-damage HOT ROUND")
	assert_eq((d.hits[0] as Combat.Hit).weapon_id, &"omni_blaster")


func test_blaster_alt_hot_round_cashes_in_heat() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	var b: BSWeapon = _equip(&"omni_blaster")
	b.set("heat", 10.0)
	_wm.scripted = {"alt": true}
	await _frames(2)
	_wm.scripted = {}
	assert_eq(d.hits.size(), 0, "needs at least 25 heat")
	b.set("heat", 60.0)
	b.set("idle_t", 0.0)
	await _frames(1)
	_wm.scripted = {"alt": true}
	await _frames(2)
	_wm.scripted = {"alt": false}
	assert_eq(d.hits.size(), 1)
	assert_eq((d.hits[0] as Combat.Hit).amount, 16.0 + 0.5 * 60.0, "16 + 0.5 x heat")
	assert_almost_eq(float(b.get("heat")), 0.0, 0.01, "heat drops to 0, no overheat")
	assert_false(b.call("overheated"))


func test_hot_round_ignites_served_target() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	var b: BSWeapon = _equip(&"omni_blaster")
	(d.get_node("Status") as StatusEffects).apply(&"served", 6.0)
	b.set("heat", 40.0)
	_wm.scripted = {"alt": true}
	await _frames(2)
	_wm.scripted = {}
	assert_true((d.get_node("Status") as StatusEffects).has(&"burning"), "Due Process: Hot Round ignites SERVED")


func test_void_charge_scales_damage() -> void:
	_no_gun_model()
	var tap: TestDummy = _dummy(Vector3(-4, 0, -8))
	var full: TestDummy = _dummy(Vector3(4, 0, -8))
	await _frames(2)
	_equip(&"void_ripper")
	_wm.aim_override = (tap.get_center() - _bolt.aim_origin()).normalized()
	await _tap_fire(2)
	await _frames(90)
	_wm.aim_override = (full.get_center() - _bolt.aim_origin()).normalized()
	await _tap_fire(65)                  # > 0.87 s: full charge
	await _frames(90)
	assert_gt(tap.total_damage(), 0.0, "tap orb hits")
	assert_gt(full.total_damage(), 0.0, "charged orb hits")
	assert_gt(full.total_damage(), tap.total_damage() * 1.8, "full charge ~65 vs ~30")
	assert_lte(full.total_damage(), 65.0, "max 65 at the core")
	assert_lte(tap.total_damage(), 33.0, "a tap is ~30")


func test_void_splash_hits_bystanders() -> void:
	_no_gun_model()
	var a: TestDummy = _dummy(Vector3(0, 0, -8))
	var b: TestDummy = _dummy(Vector3(2.2, 0, -8))
	await _frames(2)
	_equip(&"void_ripper")
	_wm.aim_override = (a.get_center() - _bolt.aim_origin()).normalized()
	await _tap_fire(65)
	await _frames(90)
	assert_gt(a.total_damage(), 0.0)
	assert_gt(b.total_damage(), 0.0, "splash 5.5 m at full charge")
	assert_lt(b.total_damage(), a.total_damage(), "falloff with distance")


func test_void_rift_clumps_and_costs_two() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -15))
	await _frames(2)
	var w: BSWeapon = _equip(&"void_ripper")
	_wm.aim_override = Vector3(0, -0.02, -1).normalized()
	_wm.scripted = {"alt": true}
	await _frames(3)
	_wm.scripted = {}
	assert_eq(w.ammo(), 10, "a Rift costs 2 ammo")
	assert_true((d.get_node("Status") as StatusEffects).has(&"gravity_clumped"), "enemies in the Rift are gravity-clumped")
	assert_eq(d.total_damage(), 0.0, "the Rift deals no damage")
	assert_gt(float(w.get("rift_cd")), 5.0, "6 s cooldown")


func test_zap_chains_to_three_with_falling_damage() -> void:
	var ds: Array[TestDummy] = []
	for i: int in 4:
		ds.append(_dummy(Vector3(i * 3.0, 0, -5)))
	await _frames(2)
	_equip(&"sprocket_zap")
	await _tap_fire()
	var hit: Array = []
	for d: TestDummy in ds:
		if d.hits.size() > 0:
			hit.append(d.total_damage())
	assert_eq(hit.size(), 3, "chains to 3 targets at V1")
	assert_eq(hit, [18.0, 14.0, 11.0], "18 / 14 / 11 down the chain")
	assert_eq(_wm.weapon(&"sprocket_zap").ammo(), 29)


func test_zap_v3_four_targets_conductive_and_fizzle() -> void:
	var ds: Array[TestDummy] = []
	for i: int in 5:
		ds.append(_dummy(Vector3(i * 3.0, 0, -5)))
	await _frames(2)
	var z: BSWeapon = _equip(&"sprocket_zap")
	_set_level(&"sprocket_zap", 3)
	await _tap_fire()
	var n: int = 0
	for d: TestDummy in ds:
		if d.hits.size() > 0:
			n += 1
			assert_true((d.get_node("Status") as StatusEffects).has(&"conductive"), "V3 hits are CONDUCTIVE")
	assert_eq(n, 4, "V3: 4 targets")
	for d2: TestDummy in ds:
		d2.queue_free()
	await _frames(40)
	var before: int = z.ammo()
	await _tap_fire()
	assert_eq(z.ammo(), before, "fizzles with no ammo cost when nothing is in range")


func test_zap_residue_ticks() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -5))
	await _frames(2)
	_equip(&"sprocket_zap")
	await _tap_fire()
	var after_arc: float = d.total_damage()
	assert_eq(after_arc, 18.0)
	await _frames(60)
	assert_gt(d.total_damage(), after_arc, "the residue patch ticks 4 per 0.4 s")


func test_boom_box_makes_enemies_dance_then_drops() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -12))
	var boss: TestDummy = _dummy(Vector3(2.5, 0, -13))
	boss.add_to_group(&"bosses")
	await _frames(2)
	var w: BSWeapon = _equip(&"boom_box")
	assert_eq(w.ammo(), 8, "8 complimentary mixtapes")
	await _tap_fire()
	var danced: bool = false
	for i: int in 60:
		await get_tree().physics_frame
		if (d.get_node("Status") as StatusEffects).has(&"dancing"):
			danced = true
			break
	assert_true(danced, "enemies on the floor DANCE")
	assert_eq(d.total_damage(), 0.0, "no damage until the drop")
	assert_eq(boss.total_damage(), 31.0, "bosses don't dance: 70% of 45 at once (45 x 0.7 rounds to 31, as in JS)")
	assert_false((boss.get_node("Status") as StatusEffects).has(&"dancing"))
	var dancing_hit: bool = false
	for h: Variant in d.hits:
		if (h as Combat.Hit).status.has("dancing"):
			dancing_hit = true
	assert_true(dancing_hit, "dancing arrives through a Combat.Hit with status too")
	await _frames(int((1.6 + 0.8) * 60))
	assert_eq(d.total_damage(), 45.0, "45 on the beat after the 1.6 s dance")
	assert_false((d.get_node("Status") as StatusEffects).has(&"dancing"), "the drop ends the dance")
	assert_eq(w.ammo(), 7)


func test_drop_the_bass_detonates_early() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -12))
	await _frames(2)
	_equip(&"boom_box")
	await _tap_fire()
	for i: int in 60:
		await get_tree().physics_frame
		if (d.get_node("Status") as StatusEffects).has(&"dancing"):
			break
	_wm.scripted = {"alt": true}
	await _frames(2)
	_wm.scripted = {}
	assert_eq(d.total_damage(), 36.0, "Drop the Bass: 80% of 45 right now")
	assert_false((d.get_node("Status") as StatusEffects).has(&"dancing"))


# ------------------------------------------------------------------ selection, wheel, visuals

func test_select_cycle_and_quick_swap() -> void:
	assert_eq(_wm.current, &"omni_blaster", "starts on the Omni-Blaster")
	assert_true(BS.owns(&"void_ripper") and BS.owns(&"sprocket_zap"), "three starting guns")
	watch_signals(EventBus)
	_wm.cycle(1)
	assert_eq(_wm.current, &"void_ripper")
	assert_signal_emitted(EventBus, "weapon_changed")
	_wm.select_slot(2)
	assert_eq(_wm.current, &"sprocket_zap")
	_wm.quick_swap()
	assert_eq(_wm.current, &"void_ripper", "quick-swap returns to the last weapon")
	_wm.cycle(-1)
	assert_eq(_wm.current, &"omni_blaster")
	_wm.select_slot(5)
	assert_eq(_wm.current, &"omni_blaster", "unowned slot does nothing")
	_wm.repossess(&"omni_blaster")
	assert_ne(_wm.current, &"omni_blaster", "Repo-Tron takes the equipped gun")
	_wm.return_weapon(&"omni_blaster")
	var cur: StringName = _wm.current
	assert_eq(_wm.steal_current(), cur, "Repo-Tron hook returns the stolen id")
	assert_true(_wm.locked.has(cur))
	_wm.return_stolen()
	assert_false(_wm.locked.has(cur), "smashing the hook returns it")


func test_wheel_slows_world_blocks_input_and_equips() -> void:
	_wm.open_wheel("kb")
	assert_true(_wm.wheel_open)
	assert_true(Game.wheel_open, "world slows while the wheel is open")
	assert_eq(BS.ui_block, 1, "the wheel owns the input")
	assert_false(_wm.can_fire())
	_wm.wheel_point(Vector2(1, 0))      # right = slot index 2 of 8
	assert_eq(_wm.wheel_sel, 2)
	_wm.close_wheel(true)
	assert_false(Game.wheel_open)
	assert_eq(BS.ui_block, 0)
	assert_eq(_wm.current, &"sprocket_zap")
	assert_eq(_wm.pages(), 2, "16 guns = 2 pages of 8")
	_wm.open_wheel("pad")
	_wm.wheel_page_step(1)
	assert_eq(_wm.page_ids(_wm.wheel_page)[0], &"grav_grenade", "page 2 starts at slot 9")
	_wm.close_wheel(false)
	assert_eq(_wm.current, &"sprocket_zap", "closing without a pick keeps the gun")


func test_ui_scenes_and_gun_model_attach() -> void:
	var wm2: WeaponManager = _wm
	var ret: Control = (load("res://ui/bs/reticle.tscn") as PackedScene).instantiate()
	ret.set("mgr", wm2)
	add_child_autofree(ret)
	var wh: Control = (load("res://ui/bs/weapon_wheel.tscn") as PackedScene).instantiate()
	wh.set("mgr", wm2)
	add_child_autofree(wh)
	await _frames(3)
	var gun: Node = _bolt.get_node("Visual").find_child("BoltGun", true, false)
	assert_not_null(gun, "greybox gun parented in Bolt's right hand")
	assert_true(_wm.gun_visual.has_muzzle())
	_wm.open_wheel("kb")
	await _frames(2)
	assert_true(wh.visible, "wheel UI shows while open")
	_wm.close_wheel(false)
	assert_eq(WeaponManager.attach_to(_bolt), _wm, "attach_to is idempotent")
