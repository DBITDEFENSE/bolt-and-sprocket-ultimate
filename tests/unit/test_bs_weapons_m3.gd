extends GutTest
## M3 arsenal: the 12 remaining guns' real behaviour, V-level changes, Signature Mods, Ω, the cross-weapon rules
## (WeaponRules) and the Super Sprocket damage multiplier. Headless, real physics, scripted input, TestDummy targets.

var _world: Node3D
var _bolt: Bolt
var _cam: BoltCamera
var _wm: WeaponManager
var _saved: Dictionary = {}


class WeakDummy extends TestDummy:
	## A dummy with a weak point 0.6 m above its centre (EnemyBase-style duck typing for WeaponRules).
	func _weak_point_pos() -> Vector3:
		return get_center() + Vector3(0, 0.8, 0)

	func weak_radius() -> float:
		return 0.3

	func crit_mult() -> float:
		return 2.5

	func is_weak_point(p: Vector3) -> bool:
		return p.distance_to(_weak_point_pos()) < weak_radius()


class PlatedDummy extends TestDummy:
	var plates: int = 2
	var popped: int = 0

	func pop_plate() -> void:
		plates -= 1
		popped += 1


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
	_wm.callouts_enabled = false
	_wm.rng.seed = 11


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
	if _wm.gun_visual != null:
		_wm.gun_visual.queue_free()
		_wm.gun_visual = null


func _equip(id: StringName) -> BSWeapon:
	if not _wm.owns(id):
		_wm.give(id)
	_wm.select(id)
	return _wm.weapon(id)


func _set_level(id: StringName, lv: int) -> void:
	if not BS.weapons.has(String(id)):
		_wm.give(id)
	var st: Dictionary = BS.weapons[String(id)]
	st["xp"] = float(WeaponData.thresholds()[lv - 1])
	st["level"] = lv


func _sig(id: StringName, choice: int) -> void:
	(BS.weapons[String(id)] as Dictionary)["sig"] = choice


func _omega(id: StringName) -> void:
	_set_level(id, 5)
	(BS.weapons[String(id)] as Dictionary)["omega"] = true


func _aim_at(p: Vector3) -> void:
	_wm.aim_override = (p - _bolt.aim_origin()).normalized()


func _hold(input: String, frames: int) -> void:
	_wm.scripted = {input: true}
	await _frames(frames)
	_wm.scripted = {input: false}
	await _frames(1)


func _st(d: Node) -> StatusEffects:
	return d.get_node("Status") as StatusEffects


# ------------------------------------------------------------------ all 16

func test_all_16_guns_have_real_scripts() -> void:
	for id: StringName in WeaponData.ids():
		var path: String = str(WeaponData.def(id).get("script", ""))
		assert_true(ResourceLoader.exists(path), "%s has its own script (%s)" % [id, path])
		var w: BSWeapon = _wm.give(id)
		assert_not_null(w)
		assert_eq((w.get_script() as Script).resource_path, path, "%s runs its gun script" % id)


func test_every_weapon_fires_and_damages_a_dummy() -> void:
	_no_gun_model()
	for id: StringName in WeaponData.ids():
		for n: Node in get_tree().get_nodes_in_group(&"enemies"):
			n.queue_free()
		await _frames(2)
		var ds: Array[TestDummy] = [_dummy(Vector3(0, 0, -6)), _dummy(Vector3(1.6, 0, -6.5)), _dummy(Vector3(-1.6, 0, -6.5))]
		await _frames(2)
		_equip(id)
		# each gun's quickest proof (the full V1..V5 / Ω / Signature sweep is tools_src/smoke_arsenal)
		match String(id):
			"grav_grenade":
				_omega(id)          # 0 direct damage; Ω crushes from the moment it opens
			"boom_box", "lawn_dart":
				_set_level(id, 3)
				_sig(id, 1)         # Radio Edit: drops 0.8 s after landing; Express Delivery: no fuse
			"patent_pending":
				_set_level(id, 3)
				_sig(id, 0)         # Provisional: 14 m/s
		_aim_at(ds[0].get_center())
		match String(id):
			"void_ripper":
				await _hold("fire", 6)
				await _frames(24)
			"boom_box", "grav_grenade":
				_aim_at(ds[0].global_position)
				await _hold("fire", 2)
				await _frames(80 if id == &"boom_box" else 55)
			"lawn_dart", "patent_pending":
				await _hold("fire", 2)
				await _frames(30)
			"root_canal":
				_aim_at(ds[0].global_position + Vector3(0, 0.1, 0.6))
				await _hold("fire", 2)
				await _frames(45)
			"middleman":
				await _hold("fire", 2)
				await _frames(30)
			"frostbyte", "hostile_takeover":
				await _hold("fire", 25)
			"clearance_rack":
				await _hold("fire", 45)
			_:
				await _hold("fire", 10)
				await _frames(4)
		var total: float = 0.0
		for d: TestDummy in ds:
			total += d.total_damage()
		assert_gt(total, 0.0, "%s fires and damages a dummy" % id)
		var own: bool = false
		for d2: TestDummy in ds:
			for h: Variant in d2.hits:
				if (h as Combat.Hit).amount > 0.0 and (h as Combat.Hit).weapon_id == id:
					own = true
		assert_true(own, "%s's hits carry its weapon id" % id)
		_wm.select(&"omni_blaster")
		for g: StringName in [&"middleman_drones", &"root_plants", &"singularities", &"zap_residue", &"void_rifts", &"pending_zones", &"ice_walls", &"subsidiaries"]:
			for n2: Node in get_tree().get_nodes_in_group(g):
				n2.queue_free()


# ------------------------------------------------------------------ level / signature / Ω rules (pure)

func test_level_and_signature_rules_per_gun() -> void:
	var ld: BSWeapon = _wm.give(&"lawn_dart")
	assert_almost_eq(float(ld.call("fuse_time")), 1.0, 0.001)
	_set_level(&"lawn_dart", 3)
	assert_almost_eq(float(ld.call("fuse_time")), 0.7, 0.001, "Lawn Dart V3 fuse 0.7")
	_sig(&"lawn_dart", 1)
	assert_almost_eq(float(ld.call("dart_speed")), 22.0, 0.001, "Express Delivery 22 m/s")

	var pp: BSWeapon = _wm.give(&"patent_pending")
	assert_almost_eq(float(pp.call("fork_interval")), 0.45, 0.001)
	_set_level(&"patent_pending", 3)
	assert_almost_eq(float(pp.call("fork_interval")), 0.35, 0.001, "Patent V3 forks 0.35")
	assert_almost_eq(float(pp.call("splash")), 5.0, 0.001)
	_sig(&"patent_pending", 0)
	assert_almost_eq(float(pp.call("splash")), 4.0, 0.001, "Provisional -1 m")
	_omega(&"patent_pending")
	assert_almost_eq(float(pp.call("fork_interval")), 0.22, 0.001, "Ω forks 0.22")
	assert_almost_eq(float(pp.call("fork_served")), 6.0, 0.001, "Ω lawsuits SERVE 6 s")

	var cd: BSWeapon = _wm.give(&"cease_desist")
	assert_eq(int(cd.call("ricochets")), 2)
	_set_level(&"cease_desist", 3)
	assert_eq(int(cd.call("ricochets")), 3, "C&D V3 +1 ricochet")
	assert_almost_eq(float(cd.call("rico_range")), 20.0, 0.001)
	_set_level(&"cease_desist", 5)
	assert_eq(int(cd.call("ricochets")), 4, "C&D V5 4 ricochets")
	_sig(&"cease_desist", 0)
	assert_almost_eq(float(cd.call("served_time")), 10.0, 0.001, "Cease: SERVED 10 s")
	_sig(&"cease_desist", 1)
	assert_almost_eq(float(cd.call("served_mult")), 1.3, 0.001, "Desist: +30%")
	assert_true((cd.call("stamp_status", 6.0) as Dictionary).has("slowed"), "Desist slows")
	_omega(&"cease_desist")
	assert_eq(int(cd.call("ricochets")), 6)
	assert_almost_eq(float(cd.call("served_mult")), 1.7, 0.001, "Ω INJUNCTION +70%")
	assert_true((cd.call("stamp_status", 6.0) as Dictionary).has("silenced"), "Ω blocks abilities")

	var bz: BSWeapon = _wm.give(&"buzzkill")
	assert_eq(int(bz.call("bounces")), 3)
	_omega(&"buzzkill")
	assert_eq(int(bz.call("bounces")), 5, "Ω MOOD KILLER 5 bounces")

	var gg: BSWeapon = _wm.give(&"grav_grenade")
	assert_almost_eq(float(gg.call("duration")), 3.0, 0.001)
	_set_level(&"grav_grenade", 3)
	assert_almost_eq(float(gg.call("duration")), 5.0, 0.001)
	_sig(&"grav_grenade", 0)
	assert_almost_eq(float(gg.call("radius")), 9.0, 0.001, "Tidy Up r9")
	_sig(&"grav_grenade", 1)
	assert_almost_eq(float(gg.call("radius")), 4.5, 0.001, "Compactor r4.5")
	_omega(&"grav_grenade")
	assert_almost_eq(float(gg.call("duration")), 6.5, 0.001)

	var mm: BSWeapon = _wm.give(&"middleman")
	assert_eq(int(mm.call("max_active")), 1)
	_omega(&"middleman")
	assert_eq(int(mm.call("max_active")), 2, "Ω two Middlemen")

	var fb: BSWeapon = _wm.give(&"frostbyte")
	var heavy: TestDummy = _dummy(Vector3(30, 0, 30))
	heavy.set_meta(&"_", 0)
	assert_almost_eq(float(fb.call("beam_range")), 18.0, 0.001)
	assert_almost_eq(float(fb.call("freeze_time")), 6.0, 0.001)
	_sig(&"frostbyte", 1)
	assert_almost_eq(float(fb.call("beam_dot")), 0.95, 0.001, "Flash Freeze narrows")
	assert_almost_eq(float(fb.call("frost_rate")), 1.4 * 1.5, 0.001, "Flash Freeze x1.5")
	_omega(&"frostbyte")
	assert_almost_eq(float(fb.call("beam_range")), 26.0, 0.001, "Ω 26 m beam")
	assert_almost_eq(float(fb.call("freeze_time")), 9.0, 0.001, "Ω 9 s statues")

	var rc: BSWeapon = _wm.give(&"root_canal")
	assert_eq(int(rc.call("max_plants")), 3)
	_omega(&"root_canal")
	assert_eq(int(rc.call("max_plants")), 5, "Ω five gardens")

	var lf: BSWeapon = _wm.give(&"late_fee")
	assert_almost_eq(float(lf.call("cap")), 2.0, 0.001)
	lf.set("idle", 4.0)
	assert_almost_eq(float(lf.call("interest")), 1.5, 0.001, "+12.5% per idle second")
	_set_level(&"late_fee", 5)
	assert_almost_eq(float(lf.call("cap")), 2.5, 0.001, "V5 cap x2.5")
	_sig(&"late_fee", 0)
	assert_almost_eq(float(lf.call("cap")), 1.6, 0.001, "Penalty APR caps x1.6")
	assert_almost_eq(float(lf.call("interest")), 1.6, 0.001, "and accrues 2x faster")
	assert_eq(int(lf.call("pellets")), 8)
	_omega(&"late_fee")
	assert_eq(int(lf.call("pellets")), 10)

	var ht: BSWeapon = _wm.give(&"hostile_takeover")
	var mutt: TestDummy = _dummy(Vector3(40, 0, 40), 30.0)
	assert_almost_eq(float(ht.call("acq_time", mutt)), 0.9, 0.001, "a 30-HP Scrap Mutt takes 0.9 s")
	assert_almost_eq(float(ht.call("contract")), 10.0, 0.001)
	_set_level(&"hostile_takeover", 5)
	assert_almost_eq(float(ht.call("contract")), 12.0, 0.001)
	assert_almost_eq(float(ht.call("acq_time", mutt)), 0.63, 0.001, "V5 -30%")
	_sig(&"hostile_takeover", 0)
	assert_almost_eq(float(ht.call("contract")), 6.0, 0.001, "Hostile Bid 6 s")

	var cr: BSWeapon = _wm.give(&"clearance_rack")
	assert_almost_eq(float(cr.call("spin_time")), 0.6, 0.001)
	assert_eq(int(cr.call("cap")), 10)
	_omega(&"clearance_rack")
	assert_almost_eq(float(cr.call("spin_time")), 0.0, 0.001, "Ω no spin-up")
	assert_eq(int(cr.call("cap")), 20)


# ------------------------------------------------------------------ the guns in action

func test_lawn_dart_sticks_then_detonates_and_bullseyes_rooted() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	_equip(&"lawn_dart")
	_aim_at(d.get_center())
	await _hold("fire", 2)
	await _frames(35)
	assert_eq(d.total_damage(), 0.0, "stuck: beep beep beep...")
	await _frames(70)
	assert_eq(d.total_damage(), 55.0, "...BOOM after the 1.0 s fuse")
	_st(d).apply(&"rooted", 5.0)
	d.hits.clear()
	await _frames(70)
	await _hold("fire", 2)
	await _frames(40)
	assert_eq(d.total_damage(), 74.0, "Weed Whacker: rooted = BULLSEYE, no fuse, x1.35")


func test_lawn_dart_paint_volley() -> void:
	_no_gun_model()
	var a: TestDummy = _dummy(Vector3(-2, 0, -8))
	var b: TestDummy = _dummy(Vector3(2, 0, -8))
	await _frames(2)
	var w: BSWeapon = _equip(&"lawn_dart")
	_aim_at(a.get_center())
	_wm.scripted = {"alt": true}
	await _frames(26)
	_aim_at(b.get_center())
	await _frames(26)
	assert_eq(int(w.hud_state()["painted"]), 2, "two targets painted")
	_wm.scripted = {"alt": true, "fire": true}
	await _frames(2)
	_wm.scripted = {}
	assert_eq(w.ammo(), 3, "1 ammo per painted dart")
	await _frames(150)
	assert_eq(a.total_damage(), 41.0, "75% of 55")
	assert_eq(b.total_damage(), 41.0)


func test_patent_forks_serve_bystanders_then_detonates() -> void:
	_no_gun_model()
	var core: TestDummy = _dummy(Vector3(0, 0, -14))
	var side: TestDummy = _dummy(Vector3(3, 0, -3))
	await _frames(2)
	_equip(&"patent_pending")
	_aim_at(core.get_center())
	await _hold("fire", 2)
	await _frames(140)
	assert_true(side.hits.size() > 0, "lawsuits fork at bystanders")
	assert_eq((side.hits[0] as Combat.Hit).amount, 10.0)
	assert_true((side.hits[0] as Combat.Hit).status.has("served"), "every lawsuit stamps SERVED")
	var big: bool = false
	for h: Variant in core.hits:
		if (h as Combat.Hit).amount >= 60.0:
			big = true
	assert_true(big, "the sphere detonates for 70 (explodeAt falloff from the contact point)")
	assert_gt(get_tree().get_nodes_in_group(&"pickups").size() + 1, 0)


func test_cease_ricochets_and_serves_every_defendant() -> void:
	_no_gun_model()
	var ds: Array[TestDummy] = [_dummy(Vector3(0, 0, -6)), _dummy(Vector3(4, 0, -7)), _dummy(Vector3(-4, 0, -7)), _dummy(Vector3(0, 0, -30))]
	await _frames(2)
	_equip(&"cease_desist")
	_aim_at(ds[0].get_center())
	await _hold("fire", 2)
	await _frames(60)
	for i: int in 3:
		assert_eq(ds[i].total_damage(), 24.0, "defendant %d takes 24" % i)
		assert_true(_st(ds[i]).has(&"served"), "and is SERVED")
	assert_eq(ds[3].total_damage(), 0.0, "2 ricochets = 3 defendants (the 4th is out of range)")
	assert_almost_eq(float(ds[0].get_meta(&"bs_served_mult")), 1.4, 0.001)


func test_cease_class_action_serves_the_area() -> void:
	_no_gun_model()
	var t: TestDummy = _dummy(Vector3(0, 0, -8))
	var n: TestDummy = _dummy(Vector3(3, 0, -9))
	await _frames(2)
	var w: BSWeapon = _equip(&"cease_desist")
	_aim_at(t.get_center())
	await _hold("alt", 2)
	await _frames(30)
	assert_eq(w.ammo(), 4, "2 ammo")
	assert_eq(t.total_damage(), 60.0, "60 to the target")
	assert_true(_st(n).has(&"served"), "everyone within 6 m SERVED")
	assert_gt(_st(n).time_left(&"served"), 7.0, "for 8 s")


func test_buzzkill_bounces_back_through_the_crowd() -> void:
	_no_gun_model()
	_box(Vector3(10, 4, 1), Vector3(0, 2, -9))
	var d: TestDummy = _dummy(Vector3(0, 0, -4))
	await _frames(2)
	_equip(&"buzzkill")
	_wm.aim_override = Vector3(0, -0.02, -1).normalized()
	await _hold("fire", 2)
	await _frames(40)
	assert_gte(d.hits.size(), 2, "passes through, bounces off the wall, shreds it again")
	assert_eq((d.hits[0] as Combat.Hit).amount, 14.0)
	assert_true((d.hits[0] as Combat.Hit).has_meta(&"plate_pierce"), "blades cut through plating")


func test_buzzkill_pops_plates() -> void:
	_no_gun_model()
	var p: PlatedDummy = PlatedDummy.new()
	p.hp = 9999.0
	p.position = Vector3(0, 0, -5)
	_world.add_child(p)
	await _frames(2)
	var w: BSWeapon = _equip(&"buzzkill")
	for i: int in 4:
		w.call("_shred", p, p.get_center())
	assert_eq(p.popped, 1, "every 4 blade hits pop a plate")
	_set_level(&"buzzkill", 5)
	w.call("_shred", p, p.get_center())
	w.call("_shred", p, p.get_center())
	assert_eq(p.popped, 2, "V5: every 2 hits")


func test_grav_clumps_pulls_and_launches() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(3, 0, -9))
	await _frames(2)
	_equip(&"grav_grenade")
	_set_level(&"grav_grenade", 5)
	_aim_at(Vector3(0, 0, -9))
	await _hold("fire", 2)
	var clumped: bool = false
	for i: int in 90:
		await get_tree().physics_frame
		if _st(d).has(&"gravity_clumped"):
			clumped = true
			break
	assert_true(clumped, "GRAVITY-CLUMPED")
	var x0: float = d.global_position.x
	await _frames(30)
	assert_lt(d.global_position.x, x0, "dragged toward the centre")
	var sg: GravSingularity = get_tree().get_nodes_in_group(&"singularities")[0] as GravSingularity
	sg.life = 0.05
	await _frames(4)
	assert_eq(d.launched, 11.0, "the collapse launches at 11 m/s")
	assert_gt(d.total_damage(), 20.0, "V3+ crush, and V5's 20 on collapse")


func test_grav_hold_keeps_it_open_for_ammo() -> void:
	_no_gun_model()
	var w: BSWeapon = _equip(&"grav_grenade")
	_aim_at(Vector3(0, 0, -8))
	await _hold("fire", 2)
	await _frames(60)
	var s: GravSingularity = w.get("last_sing") as GravSingularity
	assert_not_null(s, "a singularity opened")
	var before: int = w.ammo()
	_wm.scripted = {"alt": true}
	await _frames(2)
	var life0: float = s.life
	await _frames(40)
	assert_true(is_instance_valid(s) and not s.collapsed and s.held, "held open")
	assert_almost_eq(s.life, life0, 0.001, "its clock stops while held")
	assert_lt(w.ammo(), before, "holding costs ammo")
	_wm.scripted = {"alt": false}
	await _frames(3)
	assert_true(not is_instance_valid(s) or s.collapsed, "collapses on release")


func test_middleman_deploys_one_drone_that_fires_and_draws_aggro() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -10))
	await _frames(2)
	var w: BSWeapon = _equip(&"middleman")
	await _hold("fire", 2)
	await _frames(40)
	var drones: Array[Node] = get_tree().get_nodes_in_group(&"middleman_drones")
	assert_eq(drones.size(), 1, "one drone")
	assert_true(drones[0].is_in_group(&"enemy_decoys"), "it draws aggro")
	assert_gt(d.total_damage(), 0.0, "it fires")
	assert_eq((d.hits[0] as Combat.Hit).amount, 8.0)
	w.cooldown = 0.0
	await _hold("fire", 2)
	assert_eq(get_tree().get_nodes_in_group(&"middleman_drones").size(), 1, "Union rules: one at a time")
	assert_eq(w.ammo(), 2)
	var dr: MiddlemanDrone = drones[0] as MiddlemanDrone
	dr.take_damage(Combat.Hit.make(500.0))
	assert_false(dr.is_alive(), "it can be destroyed")


func test_middleman_v3_outsourced_explosion() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -4))
	await _frames(2)
	var w: BSWeapon = _equip(&"middleman")
	_set_level(&"middleman", 3)
	await _hold("fire", 2)
	await _frames(2)
	var dr: MiddlemanDrone = get_tree().get_nodes_in_group(&"middleman_drones")[0] as MiddlemanDrone
	dr.life = 0.02
	dr.shot_interval = 999.0
	d.hits.clear()
	await _frames(4)
	assert_gt(d.total_damage(), 20.0, "OUTSOURCED! (45, r5)")
	assert_false(is_instance_valid(dr))
	assert_not_null(w)


func test_frostbyte_freezes_and_shatter_pays_bolts() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	_equip(&"frostbyte")
	_aim_at(d.get_center())
	_wm.scripted = {"fire": true}
	var frozen: bool = false
	for i: int in 70:
		await get_tree().physics_frame
		if _st(d).has(&"frozen"):
			frozen = true
			break
	_wm.scripted = {}
	assert_true(frozen, "frost 1.0 (about 0.7 s) freezes")
	assert_gt(_st(d).time_left(&"frozen"), 5.5, "for 6 s")
	assert_gt(d.total_damage(), 0.0, "6 per second on the way")
	var before: int = get_tree().get_nodes_in_group(&"pickups").size()
	var shatter: Combat.Hit = Combat.Hit.make(25.0)
	shatter.status = {"shatter": 0.01}
	EventBus.enemy_hit.emit(d, shatter, false)
	await _frames(1)
	assert_eq(get_tree().get_nodes_in_group(&"pickups").size() - before, 5, "SHATTER: 5 bolts")


func test_frostbyte_ice_wall_blocks_and_chills() -> void:
	_no_gun_model()
	var w: BSWeapon = _equip(&"frostbyte")
	_wm.aim_override = Vector3(0, -0.05, -1).normalized()
	await _hold("alt", 2)
	await _frames(2)
	var walls: Array[Node] = get_tree().get_nodes_in_group(&"ice_walls")
	assert_eq(walls.size(), 1, "ICE WALL")
	assert_eq(w.ammo(), 40 - 8, "8 ammo")
	var wall: IceWall = walls[0] as IceWall
	var d: TestDummy = _dummy(wall.global_position + Vector3(0, 0, 0.6))
	await _frames(30)
	assert_gt(float(d.get_meta(&"bs_frost", 0.0)), 0.1, "touching it builds frost")


func test_root_canal_plants_root_and_bite() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -5))
	await _frames(2)
	_equip(&"root_canal")
	_aim_at(d.global_position + Vector3(0, 0.1, 0.8))
	await _hold("fire", 2)
	await _frames(70)
	assert_eq(get_tree().get_nodes_in_group(&"root_plants").size(), 1, "a garden sprouts")
	assert_true(_st(d).has(&"rooted"), "ROOTED")
	assert_gt(d.total_damage(), 7.0, "chews 8 every 0.5 s")
	assert_eq((d.hits[0] as Combat.Hit).amount, 8.0)


func test_root_canal_caps_gardens_and_replants() -> void:
	_no_gun_model()
	var w: BSWeapon = _equip(&"root_canal")
	for i: int in 4:
		w.call("plant_at", Vector3(i * 2.0, 0, -6), null)
	await _frames(2)
	assert_eq(get_tree().get_nodes_in_group(&"root_plants").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 3, "max 3: the oldest dies")
	var oldest: RootPlant = (w.get("plants") as Array)[0]
	var life0: float = oldest.life
	_wm.aim_override = Vector3(0, -0.3, -1).normalized()
	await _hold("alt", 2)
	assert_true(oldest.moving, "UPROOT & REPLANT: it burrows")
	assert_gt(oldest.life, life0 + 1.5, "keeps its life +2 s")


func test_late_fee_interest_and_falloff() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -3))
	await _frames(2)
	var w: BSWeapon = _equip(&"late_fee")
	w.set("idle", 0.0)
	_aim_at(d.get_center())
	await _hold("fire", 2)
	var base: float = d.total_damage()
	assert_gt(base, 0.0)
	for h: Variant in d.hits:
		assert_eq((h as Combat.Hit).amount, 7.0, "7 per pellet at point blank")
	d.hits.clear()
	w.set("idle", 8.0)
	w.cooldown = 0.0
	await _hold("fire", 2)
	for h2: Variant in d.hits:
		assert_eq((h2 as Combat.Hit).amount, 14.0, "x2.0 interest after 8 s")
		assert_true((h2 as Combat.Hit).status.has("slowed"), "x1.75+ garnishes: SLOWED")
	assert_almost_eq(float(w.get("idle")), 0.0, 0.05, "firing resets interest")
	assert_almost_eq(float(w.call("falloff", 4.0)), 1.0, 0.001)
	assert_almost_eq(float(w.call("falloff", 12.0)), 0.5, 0.001)
	assert_almost_eq(float(w.call("falloff", 16.0)), 0.0, 0.001)


func test_late_fee_collections_pulls_and_stuns() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -7.5))
	await _frames(2)
	var w: BSWeapon = _equip(&"late_fee")
	w.set("idle", 4.0)
	_aim_at(d.get_center())
	await _hold("alt", 2)
	await _frames(30)
	assert_lt(d.global_position.distance_to(_bolt.global_position), 3.5, "yanked to 2 m in front")
	assert_true(_st(d).has(&"stun"), "arrives stunned")
	assert_eq(d.total_damage(), 10.0)
	assert_gt(float(w.get("idle")), 4.0, "Collections doesn't reset interest")


func test_fine_print_marks_and_ricochets_rules() -> void:
	_no_gun_model()
	var d: WeakDummy = WeakDummy.new()
	d.hp = 9999.0
	d.position = Vector3(0, 0, -10)
	_world.add_child(d)
	await _frames(2)
	_equip(&"fine_print")
	_aim_at(d.get_center())
	await _hold("fire", 2)
	assert_eq(d.total_damage(), 42.0, "42 per shot")
	assert_true(_st(d).has(&"marked"), "MARKED")
	# marked: the weak-point radius doubles (0.3 -> 0.6) and crits deal 3.0x (relative to the enemy's 2.5x)
	var zap: BSWeapon = _wm.weapon(&"sprocket_zap")
	d.hits.clear()
	zap.deal(d, 10.0, d._weak_point_pos() + Vector3(0.45, 0, 0))
	var h: Combat.Hit = d.hits[0]
	assert_true(h.weak_point, "a marked weak point is twice as big")
	assert_almost_eq(h.amount, 12.0, 0.01, "3.0x instead of 2.5x")
	_omega(&"fine_print")
	d.hits.clear()
	zap.deal(d, 10.0, d.get_center() - Vector3(0, 0.8, 0))
	assert_almost_eq((d.hits[0] as Combat.Hit).amount, 12.5, 0.01, "Ω TERMS APPLY: +25% from everyone")


func test_fine_print_v3_pierces() -> void:
	_no_gun_model()
	var a: TestDummy = _dummy(Vector3(0, 0, -6))
	var b: TestDummy = _dummy(Vector3(0, 0, -10))
	await _frames(2)
	_equip(&"fine_print")
	_set_level(&"fine_print", 3)
	_aim_at(a.get_center())
	await _hold("fire", 2)
	assert_gt(a.total_damage(), 0.0)
	assert_gt(b.total_damage(), 0.0, "V3 pierces one")
	assert_true(_st(b).has(&"marked"), "both get marked")


func test_hostile_takeover_acquires_and_restructures() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -6), 30.0)
	await _frames(2)
	var w: BSWeapon = _equip(&"hostile_takeover")
	_aim_at(d.get_center())
	await _hold("fire", 70)
	assert_true(d.has_meta(&"bs_subsidiary"), "acquired after 0.9 s")
	assert_true(d.is_in_group(&"subsidiaries") and not d.is_in_group(&"enemies"), "a subsidiary, not an enemy")
	assert_true(_st(d).has(&"acquired"))
	assert_eq(w.ammo(), 5, "1 contract")
	var hp_before: float = d.hp
	_wm.weapon(&"omni_blaster").deal(d, 10.0, d.get_center())
	assert_eq(d.hp, hp_before, "our guns don't shoot our subsidiaries")
	var subs: Array = w.get("subs")
	(subs[0] as Dictionary)["t"] = 0.01
	await _frames(3)
	assert_false(d.has_meta(&"bs_subsidiary"), "the contract ends")
	assert_true(d.is_in_group(&"enemies"))
	assert_true(_st(d).has(&"stun"), "restructuring: stunned 1 s")


func test_hostile_takeover_refuses_bosses() -> void:
	_no_gun_model()
	var boss: TestDummy = _dummy(Vector3(0, 0, -6), 300.0)
	boss.add_to_group(&"bosses")
	await _frames(2)
	_equip(&"hostile_takeover")
	_aim_at(boss.get_center())
	watch_signals(EventBus)
	await _hold("fire", 60)
	assert_false(boss.has_meta(&"bs_subsidiary"), "ACQUISITION BLOCKED — ANTITRUST")
	assert_signal_emitted(EventBus, "subtitle")


func test_clearance_rack_spins_up_and_marks_down() -> void:
	_no_gun_model()
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	var w: BSWeapon = _equip(&"clearance_rack")
	_aim_at(d.get_center())
	_wm.scripted = {"fire": true}
	await _frames(30)
	assert_eq(d.total_damage(), 0.0, "0.6 s spin-up")
	await _frames(40)
	_wm.scripted = {}
	assert_gt(d.hits.size(), 3, "then a stream of tags")
	assert_eq((d.hits[0] as Combat.Hit).amount, 5.0)
	assert_eq(WeaponRules.markdown_stacks(d), mini(10, d.hits.size()), "1 MARKED DOWN stack per hit, max 10")
	assert_lt(w.ammo(), 150)


func test_clearance_markdown_lowers_boss_armour() -> void:
	var boss: TestDummy = _dummy(Vector3(0, 0, -6))
	boss.add_to_group(&"bosses")
	await _frames(2)
	var w: BSWeapon = _wm.give(&"clearance_rack")
	assert_almost_eq(WeaponRules.boss_armor_mul(boss), 1.0, 0.001)
	w.call("add_stacks", boss, 10)
	assert_almost_eq(WeaponRules.boss_armor_mul(boss), 0.65 / 0.45, 0.001, "10 stacks: armour 0.45 -> 0.65")
	_omega(&"clearance_rack")
	w.call("add_stacks", boss, 10)
	w.call("add_stacks", boss, 10)
	assert_almost_eq(WeaponRules.boss_armor_mul(boss), 1.0 / 0.45, 0.001, "Ω 20 stacks: no armour for 4 s")


# ------------------------------------------------------------------ cross-weapon rules

func test_super_sprocket_doubles_gun_damage() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	var s: Sprocket = Sprocket.new()
	_world.add_child(s)
	await _frames(1)
	var zap: BSWeapon = _wm.weapon(&"sprocket_zap")
	zap.deal(d, 10.0, d.get_center())
	assert_eq((d.hits[0] as Combat.Hit).amount, 10.0, "no protocol: x1")
	s.super_protocol.active = true
	zap.deal(d, 10.0, d.get_center())
	assert_eq((d.hits[1] as Combat.Hit).amount, 20.0, "Super Sprocket: x2 through the gun damage path")
	s.super_protocol.active = false
	s.queue_free()


func test_served_variants_correct_enemybase_multiplier() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	assert_almost_eq(WeaponRules.served_mult(d), 1.0, 0.001)
	_st(d).apply(&"served", 6.0)
	d.set_meta(&"bs_served_mult", 1.7)
	assert_almost_eq(WeaponRules.served_mult(d), 1.7, 0.001)


func test_braces_and_level_ups_from_damage() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	var w: BSWeapon = _wm.give(&"root_canal")
	_st(d).apply(&"rooted", 5.0)
	d.set_meta(&"bs_braces", true)
	w.deal(d, 10.0, d.get_center())
	assert_almost_eq((d.hits[0] as Combat.Hit).amount, 12.0, 0.01, "Braces: rooted +20%")
	watch_signals(EventBus)
	var big: TestDummy = _dummy(Vector3(5, 0, -6), 5000.0)
	await _frames(1)
	w.deal(big, 700.0, big.get_center())
	assert_eq(w.level(), 2, "600+ XP of damage: V2")
	assert_signal_emitted_with_parameters(EventBus, "weapon_leveled", [&"root_canal", 2])
