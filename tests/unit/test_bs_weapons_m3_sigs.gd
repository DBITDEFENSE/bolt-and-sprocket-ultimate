extends GutTest
## M3 arsenal, part 2: Signature Mods and Ω evolutions in action (the pure rule checks live in test_bs_weapons_m3).

var _world: Node3D
var _bolt: Bolt
var _cam: BoltCamera
var _wm: WeaponManager
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {"weapons": BS.weapons.duplicate(true), "order": BS.weapon_order.duplicate(), "cur": BS.current_weapon,
		"bolts": BS.bolts, "flags": BS.flags.duplicate(true), "block": BS.ui_block}
	BS.weapons = {}
	BS.weapon_order = []
	BS.current_weapon = &""
	BS.bolts = 0
	BS.ui_block = 0
	_world = Node3D.new()
	add_child_autofree(_world)
	var floor_b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(120, 1, 120)
	cs.shape = sh
	floor_b.add_child(cs)
	floor_b.position = Vector3(0, -0.5, 0)
	_world.add_child(floor_b)
	_bolt = Bolt.new()
	_bolt.position = Vector3(0, 0.95, 0)
	_world.add_child(_bolt)
	_cam = BoltCamera.new()
	_cam.target = _bolt
	_world.add_child(_cam)
	_bolt.camera = _cam
	_bolt.scripted = {"dir": Vector3.ZERO}
	_wm = WeaponManager.attach_to(_bolt, false)
	_wm.aim_override = Vector3(0, 0, -1)
	_wm.ammo_drops_enabled = false
	_wm.callouts_enabled = false
	_wm.rng.seed = 5
	if _wm.gun_visual != null:
		_wm.gun_visual.queue_free()
		_wm.gun_visual = null


func after_each() -> void:
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


func _gun(id: StringName, lv: int = 1, sig: int = -1, om: bool = false) -> BSWeapon:
	_wm.give(id)
	_wm.select(id)
	var st: Dictionary = BS.weapons[String(id)]
	st["xp"] = float(WeaponData.thresholds()[lv - 1])
	st["level"] = lv
	st["sig"] = sig
	st["omega"] = om
	return _wm.weapon(id)


func _aim_at(p: Vector3) -> void:
	_wm.aim_override = (p - _bolt.aim_origin()).normalized()


func _hold(input: String, frames: int) -> void:
	_wm.scripted = {input: true}
	await _frames(frames)
	_wm.scripted = {input: false}
	await _frames(1)


func _st(d: Node) -> StatusEffects:
	return d.get_node("Status") as StatusEffects


func test_lawn_dart_express_never_sticks() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	_gun(&"lawn_dart", 3, 1)
	_aim_at(d.get_center())
	await _hold("fire", 2)
	await _frames(25)
	assert_gt(d.total_damage(), 40.0, "Express Delivery detonates on impact, no fuse")


func test_lawn_dart_omega_double_fault() -> void:
	var a: TestDummy = _dummy(Vector3(-1.5, 0, -7))
	var b: TestDummy = _dummy(Vector3(2.5, 0, -7))
	await _frames(2)
	_gun(&"lawn_dart", 5, 0, true)
	_aim_at((a.get_center() + b.get_center()) * 0.5)
	await _hold("fire", 2)
	var darts: int = 0
	for n: Node in _world.get_children():
		if n is BSProjectile and bool((n as BSProjectile).data.get("dart", false)):
			darts += 1
	assert_eq(darts, 2, "Ω DOUBLE FAULT: two darts per trigger")
	await _frames(150)
	assert_gt(a.total_damage(), 0.0)
	assert_gt(b.total_damage(), 0.0, "each locking a different target")


func test_patent_prior_art_webs() -> void:
	var a: TestDummy = _dummy(Vector3(2, 0, -3))
	var b: TestDummy = _dummy(Vector3(4, 0, -3))
	await _frames(2)
	var w: BSWeapon = _gun(&"patent_pending", 3, 1)
	w.call("fork", Vector3(0, 1, -3), [], 0)
	await _frames(30)
	assert_gt(a.total_damage(), 0.0, "the fork hits the nearest")
	assert_gt(b.total_damage(), 0.0, "Prior Art: the victim forks a lawsuit at its neighbour")
	assert_eq((b.hits[0] as Combat.Hit).amount, roundf(w.dmg(6.0)), "6 per Prior Art lawsuit")


func test_cease_omega_injunction_silences() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	await _frames(2)
	_gun(&"cease_desist", 5, 0, true)
	_aim_at(d.get_center())
	await _hold("fire", 2)
	await _frames(20)
	assert_true(_st(d).has(&"silenced"), "Ω INJUNCTION blocks abilities")
	assert_gt(_st(d).time_left(&"served"), 9.0, "Cease: SERVED 10 s")
	assert_almost_eq(float(d.get_meta(&"bs_served_mult")), 1.7, 0.001)


func test_buzzkill_bank_shot_and_omega_splits() -> void:
	var w: BSWeapon = _gun(&"buzzkill", 5, 1, true)
	var pr: BSProjectile = w.call("blade", Vector3(0, 1, -2), Vector3(0, 0, -34), 14.0, 5, true, true, 2.2)
	pr.data["bounced"] = 3
	assert_almost_eq(float(w.call("blade_damage", pr)), 14.0 * 1.75, 0.01, "Bank Shot: +75% by the third bounce")
	pr.queue_free()
	var wall: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(30, 6, 1)
	cs.shape = sh
	wall.add_child(cs)
	wall.position = Vector3(0, 2, -8)
	_world.add_child(wall)
	var back: StaticBody3D = wall.duplicate() as StaticBody3D
	back.position = Vector3(0, 2, 7)
	_world.add_child(back)
	await _frames(2)
	await _hold("fire", 2)
	await _frames(56)
	var blades: int = 0
	for n: Node in _world.get_children():
		if n is BSProjectile and bool((n as BSProjectile).data.get("saw", false)):
			blades += 1
	assert_gte(blades, 3, "Ω MOOD KILLER: blades keep splitting (4 per shot)")


func test_buzzkill_hedge_trimmer_orbits_first() -> void:
	var d: TestDummy = _dummy(Vector3(1.5, 0, 0))
	await _frames(2)
	_gun(&"buzzkill", 3, 0)
	await _hold("fire", 2)
	await _frames(40)
	assert_gt(d.total_damage(), 0.0, "the blade orbits Bolt at 1.5 m and shreds what's beside him")


func test_grav_tidy_up_has_no_crush() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -8))
	await _frames(2)
	_gun(&"grav_grenade", 3, 0)
	_aim_at(Vector3(0, 0, -8))
	await _hold("fire", 2)
	await _frames(200)
	assert_true(d.launched > 0.0 or _st(d).has(&"gravity_clumped"), "it still groups")
	assert_eq(d.total_damage(), 0.0, "Tidy Up: no crush")


func test_middleman_consultant_and_omega_two_drones() -> void:
	_gun(&"middleman", 5, 0, true)
	await _hold("fire", 2)
	await _frames(40)
	_wm.weapon(&"middleman").cooldown = 0.0
	await _hold("fire", 2)
	var drones: Array[Node] = get_tree().get_nodes_in_group(&"middleman_drones")
	assert_eq(drones.size(), 2, "Ω MIDDLE MANAGEMENT: two drones")
	for dr: Node in drones:
		assert_false(dr.is_in_group(&"enemy_decoys"), "Consultant: no aggro")
		assert_gt((dr as MiddlemanDrone).life, 18.0, "20 s contract")
		assert_eq((dr as MiddlemanDrone).shield, 60.0, "V5 shield")


func test_frostbyte_cold_storage_and_v3_spread() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	var n: TestDummy = _dummy(Vector3(2, 0, -6))
	await _frames(2)
	var w: BSWeapon = _gun(&"frostbyte", 3, 0)
	var before: int = get_tree().get_nodes_in_group(&"pickups").size()
	w.call("on_shatter", d)
	await _frames(1)
	assert_eq(get_tree().get_nodes_in_group(&"pickups").size() - before, 8, "Cold Storage: 8 bolts")
	assert_true(_st(n).has(&"frozen"), "V3: the shatter spreads the freeze within 5 m")


func test_root_wisdom_teeth_roots_two() -> void:
	var a: TestDummy = _dummy(Vector3(0.8, 0, -6))
	var b: TestDummy = _dummy(Vector3(-0.8, 0, -6))
	await _frames(2)
	var w: BSWeapon = _gun(&"root_canal", 3, 1)
	w.call("plant_at", Vector3(0, 0, -6), null)
	await _frames(40)
	assert_true(_st(a).has(&"rooted") and _st(b).has(&"rooted"), "Wisdom Teeth: two targets")
	assert_eq((a.hits[0] as Combat.Hit).amount, 4.0, "at half bite damage")


func test_late_fee_grace_slug_and_omega_refund() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -20), 9999.0)
	await _frames(2)
	var w: BSWeapon = _gun(&"late_fee", 3, 1)
	w.set("idle", 4.0)
	_aim_at(d.get_center())
	await _hold("fire", 2)
	assert_eq(d.hits.size(), 1, "Grace Period: a single slug, accurate to 30 m")
	assert_almost_eq((d.hits[0] as Combat.Hit).amount, roundf(w.dmg(80.0) * 1.5), 1.0, "80 x 1.5 interest")
	var kill: TestDummy = _dummy(Vector3(0, 0, -2.5), 20.0)
	await _frames(2)
	var w2: BSWeapon = _gun(&"late_fee", 5, -1, true)
	w2.set("idle", 8.0)
	w2.cooldown = 0.0
	_aim_at(kill.get_center())
	await _hold("fire", 2)
	assert_false(kill.is_alive())
	assert_almost_eq(float(w2.call("interest")), 1.5, 0.05, "Ω COMPOUND INTEREST: a killing x2.0 blast leaves x1.5")


func test_fine_print_footnote_spreads_mark() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -10))
	var n: TestDummy = _dummy(Vector3(3, 0, -10))
	await _frames(2)
	_gun(&"fine_print", 3, 0)
	_aim_at(d.get_center())
	await _hold("fire", 2)
	assert_true(_st(n).has(&"marked"), "Footnote: the mark spreads within 6 m")
	assert_eq(n.total_damage(), 0.0)


func test_fine_print_asterisk_refunds() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -10), 30.0)
	await _frames(2)
	var w: BSWeapon = _gun(&"fine_print", 3, 1)
	var start: int = w.ammo()
	_aim_at(d.get_center())
	await _hold("fire", 2)
	assert_false(d.is_alive())
	assert_eq(w.ammo(), start, "Asterisk: a marked kill refunds the round")


func test_hostile_omega_golden_parachute() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6), 30.0)
	var near: TestDummy = _dummy(Vector3(2, 0, -6))
	await _frames(2)
	var w: BSWeapon = _gun(&"hostile_takeover", 5, 0, true)
	assert_true(bool(w.call("acquire", d)), "acquired")
	assert_true(d.is_in_group(&"subsidiaries"))
	var subs: Array = w.get("subs")
	(subs[0] as Dictionary)["t"] = 0.01
	await _frames(3)
	assert_false(d.is_alive(), "Ω GOLDEN PARACHUTE: the unit explodes at contract end")
	assert_gt(near.total_damage(), 20.0, "50 at r4 to enemies")


func test_hostile_merger() -> void:
	var a: TestDummy = _dummy(Vector3(0, 0, -6), 30.0)
	var b: TestDummy = _dummy(Vector3(3, 0, -6), 30.0)
	await _frames(2)
	var w: BSWeapon = _gun(&"hostile_takeover", 3)
	w.call("acquire", a)
	w.cooldown = 0.0
	w.call("acquire", b)
	assert_eq((w.get("subs") as Array).size(), 2)
	_aim_at(a.get_center())
	await _hold("alt", 2)
	assert_eq((w.get("subs") as Array).size(), 1, "MERGER: two become one")
	assert_almost_eq(a.max_hp, (36.0 + 36.0) * 1.25, 0.01, "combined HP x1.25 (V3 subsidiaries +20%)")


func test_clearance_final_sale_and_bogo() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -6))
	var n: TestDummy = _dummy(Vector3(3, 0, -6))
	await _frames(2)
	var w: BSWeapon = _gun(&"clearance_rack", 1, 0)
	w.call("add_stacks", d, 2)
	assert_eq(WeaponRules.markdown_stacks(d), 2)
	_gun(&"clearance_rack", 1, 1)
	_aim_at(d.get_center())
	await _hold("fire", 70)
	assert_gt(n.total_damage(), 0.0, "Buy One Get One: free ricochet tags")


func test_clearance_doorbuster() -> void:
	var d: TestDummy = _dummy(Vector3(0, 0, -3))
	await _frames(2)
	var w: BSWeapon = _gun(&"clearance_rack", 1)
	_aim_at(d.get_center())
	_wm.scripted = {"alt": true}
	await _frames(70)
	_wm.scripted = {}
	await _frames(2)
	assert_eq(d.total_damage(), 25.0, "DOORBUSTER: 25 in a 6 m cone")
	assert_eq(WeaponRules.markdown_stacks(d), 3, "3 stacks")
	assert_eq(w.ammo(), 135, "15 ammo")
