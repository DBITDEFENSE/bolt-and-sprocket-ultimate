extends GutTest
## Rustvane Canyon: the level data is consistent (zones, counts, quests, every line id it names resolves),
## the director builds the planet with a plain test host (arenas and their contract anchors, rings, rails,
## updrafts, umbrellas, billboards, the lift), its rules gate the critical path, the boss flow tolerates a
## missing boss (stand-in) and runs the arena phases, and the world objects behave (zip lines, updrafts,
## umbrellas, the staff lift, the hover-stage). Enemies are stubbed (EnemyBridge.force_stub) so nothing here
## depends on the enemy builder's in-progress files.

const PROFILE: String = "user://test_bs_rustvane_profile.json"

var _saved_path: String
var _saved_doc: Dictionary
var _world: Node3D


func before_all() -> void:
	_saved_path = SaveProfile.path
	_saved_doc = SaveProfile.doc.duplicate(true)
	SaveProfile.path = PROFILE


func after_all() -> void:
	SaveProfile.path = _saved_path
	SaveProfile.doc = _saved_doc
	BS.load_from_profile()
	BS.god_mode = false
	BS.ui_block = 0
	EnemyBridge.force_stub = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func before_each() -> void:
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.bolts = 0
	BS.god_mode = true
	EnemyBridge.force_stub = true
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	BS.god_mode = false
	EnemyBridge.force_stub = false


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _data() -> Dictionary:
	return Data.table("bs/levels/rustvane")


func _bolt_at(p: Vector3) -> Bolt:
	var b: Bolt = Bolt.new()
	b.position = p
	_world.add_child(b)
	b.scripted = {"dir": Vector3.ZERO}
	return b


func _director() -> RustvaneDirector:
	var d: RustvaneDirector = RustvaneDirector.new()
	d.name = "Director"
	_world.add_child(d)
	d.setup(_world, "rustvane")
	return d


# ------------------------------------------------------------------ data

func test_data_counts_and_zones() -> void:
	var D: Dictionary = _data()
	assert_eq(int(D["planet_index"]), 1)
	assert_eq(int(D["gold_total"]), 4, "Rustvane has 4 gold bolts (BS_LEVELS §0.6)")
	assert_eq((D["gold_bolts"] as Array).size(), 4)
	var memo_ids: Array = []
	for m: Variant in D["memos"]:
		memo_ids.append(str((m as Dictionary)["id"]))
	assert_eq(memo_ids, ["memo.06", "memo.07", "memo.08", "memo.09", "memo.10"], "Rustvane memos 06-10")
	assert_eq((D["secrets"] as Array).size(), 8, "S1-S8")
	assert_true((D["zones"] as Array).size() >= 12, "every §3.4 zone has a probe")
	for z: Variant in D["zones"]:
		assert_true((z as Dictionary).has("probe"), "zone %s probe" % (z as Dictionary)["id"])
	assert_eq(int(D["campaign_step_after"]), 2, "story stage 2 after Rustvane")


func test_quests_for_planet_one_resolve() -> void:
	var book: QuestBook = QuestBook.new()
	add_child_autofree(book)
	book.setup(1, _data()["enemy_aliases"])
	for q: String in ["q2a", "q2b", "q2c", "q2d"]:
		assert_true(book.defs.has(q), "%s on planet 1" % q)
	assert_eq(book.kill_type("q2a"), "selfie_sentry", "Delete My Reviews counts Selfie Sentries")
	assert_eq(book.kill_type("q2d"), "lifeguard_bot", "Break Enforcement counts Lifeguard Bots")
	var npcs: Dictionary = {}
	for n: Variant in _data()["npcs"]:
		npcs[str((n as Dictionary)["id"])] = n
	assert_eq((npcs["concierge"] as Dictionary)["quests"], ["q2a", "q2b"])
	assert_eq((npcs["bellhop"] as Dictionary)["quests"], ["q2c", "q2d"])


func test_enemy_and_boss_ids_are_the_contract_ones() -> void:
	var ids: Dictionary = {}
	for e: Variant in _data()["encounters"]:
		for w: Variant in (e as Dictionary)["waves"]:
			for row: Variant in w:
				ids[str((row as Dictionary)["type"])] = true
	for id: String in ids.keys():
		assert_true(id in ["ambassadog", "selfie_sentry", "lifeguard_bot", "review_bomber", "bolt_crate"], "encounter enemy id %s" % id)
	for id: String in ["ambassadog", "selfie_sentry", "lifeguard_bot", "review_bomber"]:
		assert_true(ids.has(id), "Rustvane spawns %s" % id)
	assert_eq((_data()["bosses"] as Dictionary).keys(), ["rustvane_sentinel", "content_creator"])


func _ids_in(v: Variant, out: Dictionary, key: String = "") -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			_ids_in((v as Dictionary)[k], out, str(k))
	elif v is Array:
		for x: Variant in v:
			_ids_in(x, out, key)
	elif v is String and key in ["text", "hint", "banner", "line", "label", "prompt", "idle", "barks", "bark", "name", "id", "to", "from"]:
		var s: String = v
		var prefixes: Array = ["bs.", "code.", "cs.", "st.", "splash."]
		for p: String in prefixes:
			if s.begins_with(p) and not s.contains(" ") and not s.begins_with("bs.cosmetic") and not s.begins_with("bs.gadget.tether_"):
				out[s] = key


func test_every_line_id_resolves() -> void:
	LevelKit.register_lines((Data.table("bs/levels/rustvane_lines") as Dictionary)["lines"])
	GadgetManager.register_lines()
	var ids: Dictionary = {}
	_ids_in(_data(), ids)
	_ids_in(Data.table("bs/levels/rustvane_lines"), ids)
	var missing: Array = []
	for id: String in ids.keys():
		if id.begins_with("bs.levels") or id.begins_with("bs.cosmetic"):
			continue
		if not (LevelKit.has_text(id) or VOManager.has_line(id)):
			missing.append(id)
	assert_eq(missing, [], "unresolved line ids in rustvane.json")
	for id: String in ["cs.ccIntro.01", "st.l2_glambot.04", "cs.shieldReveal.03", "cs.firmwareScene.07", "st.l2_camp.02"]:
		assert_true(VOManager.has_line(id), "original story line %s exists" % id)


func test_level_cutscenes_use_original_line_ids() -> void:
	var cs: Dictionary = _data()["cutscenes"]
	var ids: PackedStringArray = []
	for st: Variant in (cs["ccIntro"] as Dictionary)["steps"]:
		if str((st as Dictionary).get("type", "")) == "line":
			ids.append(str((st as Dictionary)["id"]))
	assert_eq(ids, PackedStringArray(["cs.ccIntro.01", "cs.ccIntro.02", "cs.ccIntro.03", "cs.ccIntro.04", "cs.ccIntro.05"]), "ccIntro keeps every original line in order")
	ids.clear()
	for st: Variant in (cs["l2_glambot"] as Dictionary)["steps"]:
		if str((st as Dictionary).get("type", "")) == "line":
			ids.append(str((st as Dictionary)["id"]))
	assert_eq(ids.size(), 5, "l2_glambot keeps its five lines")
	assert_eq(ids[3], "st.l2_glambot.04", "the defection line")


# ------------------------------------------------------------------ the director with a test host

func test_director_builds_the_planet() -> void:
	var d: RustvaneDirector = _director()
	assert_true(d.nav_polygons > 100, "navmesh baked (%d)" % d.nav_polygons)
	assert_true(d.geometry.find_children("*", "StaticBody3D", true, false).size() > 200, "colliders")
	assert_eq(d.arenas.keys().size(), 2)
	assert_eq(d.tethers.size(), 8, "8 Tether-Hook rings")
	assert_eq(d.updrafts.size(), 4)
	assert_eq(d.umbrellas.size(), 3)
	assert_eq(d.billboards.size(), 3)
	assert_true(d.lifts.has("service_lift"))
	assert_not_null(d.zip_rider, "zip rider")
	assert_eq(d.water_zones.size(), 4)
	assert_true(d.gates["mine_bridge"].is_open, "the security bridge starts retracted")
	for g: String in ["grindstone_holo", "cc_demonetized", "glambot_drone", "popup_kiosk"]:
		assert_false((d.nodes[g] as Node3D).visible, "%s hidden at start" % g)


func test_arena_contract_anchors() -> void:
	var d: RustvaneDirector = _director()
	var q: RustvaneArena = d.arenas["quarry"]
	assert_eq(q.size(), Vector2(34, 26))
	var pillars: int = 0
	var adds: int = 0
	for n: Node in q.find_children("*", "", true, false):
		if String(n.name).begins_with("Pillar"):
			pillars += 1
		if String(n.name).begins_with("AddSpawn"):
			adds += 1
	assert_eq(pillars, 4, "exactly 4 nodes named Pillar* (no container matches the prefix)")
	assert_eq(adds, 3, "exactly 3 AddSpawn* markers")
	assert_eq(q.add_spawn_points().size(), 3)
	assert_true(q.contains(Vector3(100, 0, -58)) and not q.contains(Vector3(60, 0, -58)))
	var s: RustvaneArena = d.arenas["sunset"]
	var cabanas: int = 0
	var drones: int = 0
	for n: Node in s.find_children("*", "", true, false):
		if String(n.name).begins_with("Cabana"):
			cabanas += 1
			assert_true((n as Node3D).global_position.distance_to(Vector3.ZERO) > 10.0, "Cabana* nodes sit at the cabana, not the origin")
		if String(n.name).begins_with("DroneSpawn"):
			drones += 1
	assert_eq(cabanas, 2)
	assert_eq(drones, 4, "a DroneSpawn on every camera mast")
	var pool: Node3D = s.anchor("Pool")
	assert_not_null(pool)
	assert_almost_eq(float(pool.get_meta(&"radius")), 3.2, 0.01)
	assert_true(s.anchor("Center").global_position.distance_to(pool.global_position) < 0.01, "Center = the pool centre (ContentCreator orbits it)")
	assert_true(s.anchor("Deck").has_meta(&"outer_radius"))
	for m: Node3D in s.markers("Masts"):
		var ring: TetherPoint = m.get_node("Ring") as TetherPoint
		assert_almost_eq(ring.global_position.y - s.floor_y(), 8.0, 0.01, "mast ring at 8 m")
	assert_true(s.gate == d.gates["vip_gate"], "the VIP gate is the arena gate and a director gate")


func test_critical_path_rules() -> void:
	var d: RustvaneDirector = _director()
	assert_false(d.gates["mine_door"].is_open)
	assert_false(d.lifts["service_lift"].enabled)
	d.set_flag("staff_badge")
	assert_true(d.gates["mine_door"].is_open and d.lifts["service_lift"].enabled, "the badge opens the Strip Mine and runs the lift")
	assert_false(d.gates["vip_gate"].is_open)
	d.set_flag("vip_transfer")
	assert_true(d.lamps["lamp_wristband"].lit)
	assert_false(d.gates["vip_gate"].is_open, "wristband alone does not open the VIP gate")
	d.set_flag("sentinel_down")
	assert_true(d.lamps["lamp_security"].lit and d.gates["vip_gate"].is_open and d.flag("vip_open"), "WRISTBAND + SECURITY open it")
	assert_false(d.gates["mine_bridge"].is_open, "security down extends the bridge back over the pit")
	d.set_flag("hook_earned")
	assert_true(GadgetManager.owns(&"tether_hook"), "the winch flag grants the Tether-Hook")
	d.set_flag("story.glambot_prime")
	assert_true((d.nodes["glambot_drone"] as Node3D).visible and (d.nodes["popup_kiosk"] as Node3D).visible)


func test_boss_stand_in_and_phases() -> void:
	var d: RustvaneDirector = _director()
	var b: Node3D = d.start_rv_boss("content_creator")
	assert_true(b is RustvaneBossStandIn, "no spawner (forced stub) -> a stand-in boss")
	assert_eq(d.stand_ins_used, PackedStringArray(["content_creator"]))
	assert_almost_eq(float(b.get("max_hp")), 420.0, 0.01, "stand-in HP from the data")
	assert_true(b.get_meta(&"arena") == d.arenas["sunset"])
	assert_null(d.start_rv_boss("rustvane_sentinel"), "one boss at a time")
	var stage: HoverStage = d.arenas["sunset"].hover_stage
	assert_eq(stage.mode, &"low")
	var h: Combat.Hit = Combat.Hit.make(150.0)
	b.call("take_damage", h)
	await _frames(2)
	assert_eq(stage.mode, &"drift", "below 66%: Collab drift")
	b.call("take_damage", h)
	await _frames(2)
	assert_eq(stage.mode, &"high", "below 33%: Going live")
	b.call("take_damage", h)
	await _frames(3)
	assert_true(d.flag("cc_down") and BS.flag("story.glambot_prime"), "defeat: cc_down, GLAMBOT defects")
	assert_eq(stage.mode, &"parked")
	assert_true(d.exit.active, "Return Relay lit")
	assert_true(BS.flag("beat.l2_glambot"), "l2_glambot beat (level cutscene through the test host)")
	assert_true("l2_glambot" in d.cutscenes_played)
	assert_true((d.nodes["cc_demonetized"] as Node3D).visible, "the demonetized Creator prop stays on the stage")


func test_boss_fallback_hook_takes_testdummy() -> void:
	var d: RustvaneDirector = _director()
	d.boss_fallback = func(_id: StringName, _p: Vector3, _a: RustvaneArena) -> Node3D:
		var t: TestDummy = TestDummy.new()
		t.max_hp = 50.0
		t.hp = 50.0
		return t
	var b: Node3D = d.start_rv_boss("rustvane_sentinel")
	assert_true(b is TestDummy)
	b.call("take_damage", Combat.Hit.make(60.0))
	await _frames(2)
	assert_true(d.flag("sentinel_down"), "a TestDummy boss counts as down when it dies (polled is_alive)")
	assert_eq(d.rv_boss_id, "")


func test_spawner_knows() -> void:
	var sp: Script = load("res://bs/enemies/enemy_spawner.gd") as Script
	assert_false(RustvaneDirector.spawner_knows(sp, &"no_such_boss"), "unknown ids never reach EnemySpawner's push_error")
	assert_true(RustvaneDirector.spawner_knows(sp, &"scrap_mutt"))


func test_popup_reward_and_record() -> void:
	var d: RustvaneDirector = _director()
	d._popup_start()
	assert_true(d.popup_running and d.flag("popup_running"))
	d.popup_t = 42.0
	d._popup_end()
	assert_eq(BS.bolts, 250, "dry run: 200 + 25%")
	assert_almost_eq(float((SaveProfile.doc["bs"]["arena_records"] as Dictionary)["poolside_pileup"]), 42.0, 0.01)
	d._popup_start()
	d.set_flag("popup_wet")
	d.popup_t = 50.0
	d._popup_end()
	assert_eq(BS.bolts, 450, "wet run: 200")
	assert_almost_eq(float((SaveProfile.doc["bs"]["arena_records"] as Dictionary)["poolside_pileup"]), 42.0, 0.01, "best time kept")


# ------------------------------------------------------------------ world objects

func _floor(size: Vector3 = Vector3(80, 1, 80), pos: Vector3 = Vector3(0, -0.5, 0)) -> void:
	LevelKit.box(_world, pos, size, "#555555", true)


func _rail(points: Array[Vector3], end: String = "") -> Node3D:
	var r: Node3D = Node3D.new()
	r.add_to_group(&"rails")
	r.set_meta(&"points", PackedVector3Array(points))
	r.set_meta(&"two_way", false)
	if end != "":
		r.set_meta(&"end", end)
	_world.add_child(r)
	return r


func _rider() -> ZipRider:
	var z: ZipRider = ZipRider.new()
	z.T = _data()["zip"]
	_world.add_child(z)
	return z


func test_zip_line_ride_and_soft_end() -> void:
	_floor()
	_rail([Vector3(0, 5, 0), Vector3(0, 5, -20)], "soft")
	var z: ZipRider = _rider()
	var b: Bolt = _bolt_at(Vector3(0, 6.0, 0.5))
	await _frames(4)
	assert_not_null(z.riding, "attaches within 1.9 m² and 0.4 below .. 1.9 above")
	assert_false(b.is_physics_processing(), "the rider owns the body")
	var p0: Vector3 = b.global_position
	await _frames(30)
	assert_almost_eq(p0.distance_to(b.global_position), 13.5 * 0.5, 0.8, "13.5 m/s")
	assert_almost_eq(b.global_position.y, 6.0, 0.05, "rides 1 m above the line")
	await _frames(60)
	assert_null(z.riding)
	assert_eq(z.last_exit, &"soft")
	assert_true(b.is_physics_processing(), "body handed back")
	assert_almost_eq(z.last_exit_vel.y, 2.0, 0.01, "soft end steps off (2 up)")
	assert_almost_eq(Vector2(z.last_exit_vel.x, z.last_exit_vel.z).length(), 4.0, 0.01, "at 4 m/s")


func test_zip_line_jump_off() -> void:
	_floor()
	_rail([Vector3(0, 5, 0), Vector3(0, 5, -40)])
	var z: ZipRider = _rider()
	var b: Bolt = _bolt_at(Vector3(0, 6.0, 0.5))
	await _frames(10)
	assert_not_null(z.riding)
	b.scripted["jump_pressed"] = true
	await _frames(1)
	assert_null(z.riding)
	assert_eq(z.last_exit, &"jump")
	assert_almost_eq(z.last_exit_vel.y, 10.5, 0.01, "jumps off at 10.5 m/s")
	assert_eq(b.motor.jumps, 1, "double jump ready")


func test_grind_soles_rail_needs_the_gadget() -> void:
	_floor()
	var r: Node3D = _rail([Vector3(0, 5, 0), Vector3(0, 5, -20)])
	r.set_meta(&"gadget", "grind_soles")
	var z: ZipRider = _rider()
	_bolt_at(Vector3(0, 6.0, 0.5))
	await _frames(4)
	assert_null(z.riding, "a (G) rail without Grind Soles")
	BS.set_flag("gadget.grind_soles")
	await _frames(2)
	assert_not_null(z.riding, "with Grind Soles")


func test_updraft_lifts_when_blowing_and_holding_jump() -> void:
	_floor()
	var u: CanyonUpdraft = CanyonUpdraft.new()
	u.off_time = 0.0
	_world.add_child(u)
	var b: Bolt = _bolt_at(Vector3(0, 1.0, 0))
	await _frames(10)
	b.scripted = {"dir": Vector3.ZERO, "jump_pressed": true, "jump_held": true}
	var y0: float = b.global_position.y
	await _frames(90)
	assert_gt(b.global_position.y - y0, 5.5, "rides the column up")
	assert_lte(b.motor.vel.y, 11.01, "capped at 11 m/s")
	assert_gt(u.lifted_t, 1.0)


func test_updraft_pulse_cycle() -> void:
	var u: CanyonUpdraft = CanyonUpdraft.new()
	_world.add_child(u)
	var on_frames: int = 0
	for i: int in 270:
		await get_tree().physics_frame
		if u.is_blowing():
			on_frames += 1
	assert_almost_eq(float(on_frames) / 60.0, 3.0, 0.2, "3 s on in a 4.5 s cycle")


func test_bounce_umbrella() -> void:
	_floor()
	var u: BounceUmbrella = BounceUmbrella.new()
	u.power = 19.0
	_world.add_child(u)
	var b: Bolt = _bolt_at(Vector3(0, 6.0, 0))
	assert_true(await _wait(func() -> bool: return u.bounces > 0, 90), "falling onto the canopy bounces")
	assert_eq(b.motor.jumps, 1, "double jump back")
	assert_gt(b.global_position.y, 3.0)


func test_service_lift_waits_for_the_badge_then_carries_bolt() -> void:
	_floor()
	var l: ServiceLift = ServiceLift.new()
	l.bottom = Vector3(0, 0.2, 0)
	l.top = Vector3(0, 6.2, 0)
	l.speed = 3.0
	_world.add_child(l)
	var b: Bolt = _bolt_at(Vector3(0, 1.4, 0))
	await _frames(30)
	assert_almost_eq(l.global_position.y, 0.2, 0.01, "parked")
	l.enable()
	assert_true(await _wait(func() -> bool: return l.at_top(), 200), "rises")
	await _frames(5)
	assert_almost_eq(b.global_position.y, 6.4 + b.motor.hy, 0.3, "Bolt rode it up")


func test_hover_stage_modes() -> void:
	var hs: HoverStage = HoverStage.new()
	hs.deck_y = 8.4
	hs.edge_center = Vector3(0, 8.4, -10)
	hs.move_speed = 100.0
	_world.add_child(hs)
	await _frames(3)
	assert_almost_eq(hs.height_above_deck(), 4.0, 0.05, "low = 4 m")
	hs.set_mode(&"high")
	await _frames(5)
	assert_almost_eq(hs.height_above_deck(), 8.0, 0.05, "Going live = 8 m")
	hs.set_mode(&"drift")
	await _frames(40)
	assert_ne(hs.global_position.x, 0.0, "Collab drifts along the edge")


func _wait(cond: Callable, n: int) -> bool:
	for i: int in n:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
	return bool(cond.call())
