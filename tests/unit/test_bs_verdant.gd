extends GutTest
## Verdant Sink (BS_LEVELS §6): the level data is consistent (zones, counts, memos, secrets, the roster, every
## line id resolves), the director builds the planet with a plain test host (murk pools, bounce mushrooms,
## drums, pennants, rings, the lagoon arena contract), the world objects behave (a murk pool slows and ticks
## Bolt, a mushroom bounces him, a valve seals on three mallet hits and drains a murk third), the Sprocket Glide
## (engages on a held jump with an empty hover, caps the fall, flies forward, an updraft lifts it, landing ends
## it), the boss flow with a stand-in (phases from data, the leaks burst), and the Compost King itself (leak
## healing, the seal feeder, the negotiation at 30%, the mercy ending versus the enraged failure). The four
## Verdant enemies spawn, telegraph and die with drops; the Gloomstalker cloaks, the Spore Lobber lands a cloud,
## the Pollinator dusts an ally, the Picket Corn stays neutral until a player hit.

const PROFILE: String = "user://test_bs_verdant_profile.json"
const ROSTER: Array = ["gloomstalker", "sporelobber", "pollinator", "picket_corn", "bolt_crate"]

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
	EnemySpawner.clear_pool()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func before_each() -> void:
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.god_mode = false
	BS.bolts = 0
	EnemyBridge.force_stub = false
	EnemySpawner.clear_pool()
	AttackTokens.reset()
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0
	Game.hitstop_t = 0.0
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	EnemyBridge.force_stub = false
	EnemySpawner.clear_pool()
	BS.god_mode = false
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _wait(cond: Callable, n: int) -> bool:
	for i: int in n:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _floor(size: Vector3 = Vector3(80, 1, 80), pos: Vector3 = Vector3(0, -0.5, 0)) -> void:
	LevelKit.box(_world, pos, size, "#555555", true)


func _bolt_at(p: Vector3) -> Bolt:
	var b: Bolt = Bolt.new()
	b.position = p
	_world.add_child(b)
	var cam: BoltCamera = BoltCamera.new()
	cam.target = b
	_world.add_child(cam)
	b.camera = cam
	b.scripted = {"dir": Vector3.ZERO}
	b.invuln = 0.0
	return b


func _data() -> Dictionary:
	return Data.table("bs/levels/verdant")


func _director() -> VerdantDirector:
	var d: VerdantDirector = VerdantDirector.new()
	d.name = "Director"
	_world.add_child(d)
	d.setup(_world, "verdant")
	return d


func _hit(amount: float, src: Node = null, melee: bool = false, crit: bool = false) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, Combat.Type.KINETIC, src)
	h.weapon_id = &"test"
	h.is_melee = melee
	h.weak_point = crit
	return h


func _collect_ids(v: Variant, out: PackedStringArray) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			if not (str(k) in ["_", "_doc", "how", "where", "name", "requires", "forbids", "all", "if", "flag", "unless", "unflag"]):
				_collect_ids((v as Dictionary)[k], out)
	elif v is Array:
		for x: Variant in v:
			_collect_ids(x, out)
	elif v is String:
		var s: String = v
		for pre: String in ["bs.", "code.", "cs.", "st.", "q.", "misc.", "splash."]:
			if s.begins_with(pre) and not s.contains(" "):
				out.append(s)


# ------------------------------------------------------------------ data

func test_level_data_counts() -> void:
	var D: Dictionary = _data()
	assert_eq(int(D["planet_index"]), 7, "LEVELS[7]")
	assert_eq((D["gold_bolts"] as Array).size(), 4, "4 gold bolts (BS_LEVELS §0.6)")
	assert_eq(int(D["gold_total"]), 4)
	assert_eq((D["zones"] as Array).size(), 7, "seven zones")
	var memos: PackedStringArray = []
	for m: Variant in D["memos"]:
		memos.append(str((m as Dictionary)["id"]))
	for id: String in ["memo.26", "memo.27", "memo.28", "memo.29", "memo.30", "memo.39"]:
		assert_true(id in memos, "%s placed" % id)
	assert_eq((D["secrets"] as Array).size(), 7, "S1-S7")
	var V: Dictionary = D["verdant"]
	assert_eq((V["murk_pools"] as Array).size(), 8, "8 murk pools outside the lagoon")
	assert_eq(((V["arena"] as Dictionary)["murk"] as Array).size(), 3, "3 murk thirds in the lagoon")
	assert_eq(((V["arena"] as Dictionary)["valves"] as Array).size(), 3, "3 coolant leaks")
	assert_eq((V["bouncers"] as Array).size(), 7, "7 bounce mushrooms / puffballs")
	assert_eq((V["quest_items"] as Array).size(), 3, "q7b: 3 sealant cores")
	assert_eq((D["gadget_points"] as Array).size(), 3, "3 glide pennants")
	assert_eq(str((D["boss"] as Dictionary)["id"]), "compost_king")
	assert_eq(str((D["rails"] as Array)[0]["id"]), "grain_boom")


func test_every_line_id_resolves() -> void:
	var lf: Dictionary = Data.table("bs/levels/verdant_lines")
	LevelKit.register_lines(lf.get("lines", {}))
	EnemyBase.register_lines(true)
	GadgetManager.register_lines()
	var ids: PackedStringArray = []
	_collect_ids(_data(), ids)
	assert_gt(ids.size(), 60, "level data references lines")
	for id: String in ids:
		assert_true(LevelKit.has_text(id), "line %s exists" % id)
	for id: String in ["bs.boss.compost.leak.01", "bs.boss.compost.mercy.03", "bs.gadget.glide.how", "code.updateMurk.01", "code.updateCompostKing.04"]:
		assert_true(LevelKit.has_text(id), "line %s exists" % id)


func test_enemy_ids_are_the_verdant_roster() -> void:
	var seen: Dictionary = {}
	for e: Variant in _data()["encounters"]:
		for w: Variant in (e as Dictionary)["waves"]:
			for row: Variant in w:
				var t: String = str((row as Dictionary)["type"])
				seen[t] = true
				assert_true(t in ROSTER, "encounter enemy id %s is a BS_ENEMIES §3.5 id" % t)
	for t: String in ["gloomstalker", "sporelobber", "pollinator"]:
		assert_true(seen.has(t), "%s appears" % t)
	for id: String in ["gloomstalker", "sporelobber", "pollinator", "picket_corn", "compost_king"]:
		assert_true(EnemySpawner.known_ids().has(id), "%s registered with the spawner" % id)
		var has: bool = not EnemySpawner.def_for(StringName(id)).is_empty() if id != "compost_king" else not (Data.table("bs/bosses").get(id, {}) as Dictionary).is_empty()
		assert_true(has, "%s has data" % id)


func test_quests_for_planet_7() -> void:
	var qb: QuestBook = QuestBook.new()
	qb.setup(7, _data()["enemy_aliases"])
	assert_true(qb.defs.has("q7a") and qb.defs.has("q7b"), "Cornelius' quests")
	assert_eq(qb.kill_type("q7a"), "pollinator", "q7a counts pollinator kills")
	qb.free()


func test_planet_registered_on_the_star_map() -> void:
	var p: Dictionary = Data.table("bs/planets")
	for row: Variant in p["campaign"]:
		if str((row as Dictionary)["level_id"]) == "verdant":
			assert_true(ResourceLoader.exists(str((row as Dictionary)["scene"])), "verdant scene exists")
			assert_eq(int((row as Dictionary)["index"]), 7)
			return
	fail_test("verdant row missing")


# ------------------------------------------------------------------ the director builds the planet

func test_director_builds_the_planet() -> void:
	EnemyBridge.force_stub = true
	var d: VerdantDirector = _director()
	assert_true(d.nav_polygons > 100, "navmesh baked (%d)" % d.nav_polygons)
	assert_true(d.geometry.find_children("*", "StaticBody3D", true, false).size() > 120, "colliders")
	assert_eq(d.murk_pools.size(), 11, "8 pools + 3 lagoon thirds")
	assert_eq(d.bouncers.size(), 8, "7 bouncers + the lagoon's")
	assert_eq(d.drums.size(), 2)
	assert_eq(d.tethers.size(), 3, "S7 rings")
	assert_eq(d.updrafts.size(), 1, "S6 vault vent")
	assert_eq(d.glide_pennants, 3)
	assert_not_null(d.zip_rider)
	assert_not_null(d.arena, "the lagoon arena")
	assert_not_null(d.core, "the Keystone Core (hidden)")
	assert_false(d.core.visible)
	assert_eq(d.quest_items.size(), 3)
	assert_true(d.gates["lagoon_gate"].is_open, "the lagoon gate starts open")
	assert_false(d.gates["annex_gate"].is_open)
	assert_eq(d.water_zones.size(), 1, "the murk lake")
	assert_eq(d.corn_spawned, 0, "no corn under force_stub (neutral units are never stubbed)")
	assert_false((d.nodes["king_npc"] as Node3D).visible, "the King at the hall waits for the mercy flag")


func test_arena_contract_anchors() -> void:
	EnemyBridge.force_stub = true
	var d: VerdantDirector = _director()
	var a: VerdantArena = d.arena
	for nm: String in ["Center", "BossSpawn", "Valves", "Valve_W", "Valve_E", "Valve_N", "Murk", "Murk_0", "Murk_2", "Cover", "RootArch_0", "Cluster_1", "AddSpawn0", "AddSpawn1", "Handshake", "Spectators", "Bouncer_E"]:
		assert_not_null(a.find_child(nm, true, false), "anchor %s" % nm)
	assert_eq(a.valves().size(), 3)
	assert_eq(a.open_leaks(), 3, "every leak sprays before the fight is staged")
	assert_true(a.get_meta(&"size") == Vector2(40, 32))
	a.set_initial_leaks(["W"])
	assert_eq(a.open_leaks(), 1)
	assert_false(a.all_sealed())


func test_valve_seals_on_three_mallet_hits_and_drains_its_third() -> void:
	EnemyBridge.force_stub = true
	var d: VerdantDirector = _director()
	var a: VerdantArena = d.arena
	a.set_initial_leaks(["W"])
	var v: CoolantValve = a.valve("W")
	var pool: MurkPool = a.murk_by_valve["W"]
	assert_false(pool.drained)
	var sealed: Array = []
	a.valve_sealed.connect(func(id: String) -> void: sealed.append(id))
	v.on_mallet(null)
	v.on_mallet(null)
	assert_true(v.open, "two hits are not enough")
	v.take_damage(_hit(10.0, null, true))
	assert_false(v.open, "the third (a mallet strike) seals it")
	assert_eq(sealed, ["W"])
	assert_true(pool.drained, "the sealed leak dries its murk third")
	assert_true(a.all_sealed())
	v.set_open(true)
	assert_false(pool.drained, "a re-cracked leak floods it again")
	assert_false(v.take_damage(_hit(10.0)), "guns do nothing to the wheel")
	assert_true(v.open)


# ------------------------------------------------------------------ world objects

func test_murk_pool_slows_and_ticks_bolt() -> void:
	_floor()
	var p: MurkPool = MurkPool.new()
	p.r = 4.0
	p.tick_every = 0.2
	p.tick_dmg = 5.0
	p.bark_chance = 1.0
	_world.add_child(p)
	var barks: Array = []
	EventBus.bark.connect(func(id: String) -> void: barks.append(id))
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	b.hp = 100.0
	await _frames(6)
	assert_true(p.inside, "Bolt wades")
	assert_true(await _wait(func() -> bool: return b.hp < 95.0, 40), "the murk ticks (hp %.0f)" % b.hp)
	assert_true(PlayerDebuffs.of(b).is_slowed(), "SLOWED while wading")
	assert_true("code.updateMurk.01" in barks, "the swamp bark")
	p.set_drained(true)
	await _frames(3)
	assert_false(p.inside, "a drained pool is dry ground")
	p.set_drained(false)
	p.flush(1.0)
	await _frames(3)
	assert_false(p.inside, "a flushed pool is clear for a while")


func test_bounce_mushroom_launches_bolt() -> void:
	_floor()
	var m: BounceMushroom = BounceMushroom.new()
	m.power = 22.0
	_world.add_child(m)
	var b: Bolt = _bolt_at(Vector3(0, 4.5, 0))
	var n0: int = m.bounces
	assert_true(await _wait(func() -> bool: return m.bounces > n0, 90), "landing on the cap bounces")
	assert_gt(b.motor.vel.y, 15.0, "launched at power 22 (vy %.1f)" % b.motor.vel.y)
	assert_eq(b.motor.jumps, 1, "double jump given back")


func test_threshing_drum_turns() -> void:
	var dr: ThreshingDrum = ThreshingDrum.new()
	dr.rate = 0.5
	_world.add_child(dr)
	await _frames(30)
	assert_gt(dr.rotation.y, 0.2, "0.5 rad/s")


# ------------------------------------------------------------------ the Sprocket Glide

func _glide(b: Bolt) -> SprocketGlide:
	GadgetManager.grant(&"sprocket_glide")
	var m: GadgetManager = GadgetManager.attach_to(b)
	await _frames(1)
	return m.get_gadget(&"sprocket_glide") as SprocketGlide


func test_glide_tuning_matches_bs_levels() -> void:
	var d: Dictionary = GadgetManager.table()["gadgets"]["sprocket_glide"]
	assert_almost_eq(float(d["fall_cap"]), 3.0, 0.01)
	assert_almost_eq(float(d["forward_speed"]), 9.0, 0.01)
	assert_almost_eq(float(d["turn_rate"]), 120.0, 0.01)
	assert_true(GadgetManager.table()["order"].has("sprocket_glide"))


func test_glide_engages_on_held_jump_with_empty_hover_and_caps_the_fall() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	var b: Bolt = _bolt_at(Vector3(0, 30.0, 0))
	var g: SprocketGlide = await _glide(b)
	assert_not_null(g, "the glide is on the belt")
	b.scripted = {"dir": Vector3(0, 0, -1), "jump_held": true}
	b.motor.hover = 0.0
	b.motor.vel = Vector3(0, -6.0, -3.0)
	b.motor.air_t = 0.5
	b.motor.on_ground = false
	assert_true(await _wait(func() -> bool: return g.gliding, 20), "the sail opens")
	await _frames(30)
	assert_true(g.gliding, "still gliding")
	assert_almost_eq(g.vel.y, -3.0, 0.3, "fall capped at 3 m/s (%.2f)" % g.vel.y)
	var fwd: float = Vector2(g.vel.x, g.vel.z).length()
	assert_gt(fwd, 6.0, "flying forward (%.1f m/s)" % fwd)
	assert_lt(b.global_position.z, -3.0, "moved north")
	var y0: float = b.global_position.y
	await _frames(60)
	assert_almost_eq(y0 - b.global_position.y, 3.0, 0.6, "about 3 m down per second")
	b.scripted = {"dir": Vector3(0, 0, -1), "jump_held": false}
	await _frames(2)
	assert_false(g.gliding, "letting go of JUMP ends the glide")
	assert_true(Gadget.body_free(b), "the body is handed back")
	assert_eq(b.motor.jumps, 1, "release rule: the double jump is ready")


func test_glide_needs_an_empty_hover_and_lands() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	var b: Bolt = _bolt_at(Vector3(0, 6.0, 0))
	var g: SprocketGlide = await _glide(b)
	b.scripted = {"dir": Vector3.ZERO, "jump_held": true}
	b.motor.hover = 1.0
	b.motor.vel = Vector3(0, -4.0, 0)
	b.motor.on_ground = false
	await _frames(10)
	assert_false(g.gliding, "with hover left the hover thrusts instead")
	b.motor.hover = 0.0
	assert_true(await _wait(func() -> bool: return g.gliding, 30), "once the hover is empty the sail opens")
	assert_true(await _wait(func() -> bool: return not g.gliding, 240), "landing ends it")
	assert_true(b.motor.on_ground or await _wait(func() -> bool: return b.motor.on_ground, 20), "on the floor")
	assert_gt(g.last_glide_time, 0.3)


func test_updraft_lifts_a_glide() -> void:
	_floor(Vector3(160, 1, 160), Vector3(0, -0.5, 0))
	var u: CanyonUpdraft = CanyonUpdraft.new()
	u.radius = 7.0
	u.height = 40.0
	u.force = 30.0
	u.on_time = 100.0
	u.off_time = 0.0
	u.position = Vector3(16, 0, 0)
	_world.add_child(u)
	var b: Bolt = _bolt_at(Vector3(0, 14.0, 0))
	var g: SprocketGlide = await _glide(b)
	# glide east into the column (a glide that starts inside would be lifted by the vent before the sail opens)
	b.scripted = {"dir": Vector3(1, 0, 0), "jump_held": true}
	b.motor.hover = 0.0
	b.motor.vel = Vector3(4.0, -4.0, 0)
	b.motor.air_t = 0.5
	b.motor.on_ground = false
	assert_true(await _wait(func() -> bool: return g.gliding, 20), "gliding toward the column")
	assert_true(await _wait(func() -> bool: return g.lifted_t > 0.0, 240), "entered the column while gliding")
	var y0: float = b.global_position.y
	await _frames(45)
	assert_true(g.gliding, "still gliding in the column")
	assert_gt(g.lifted_t, 0.5, "the column lifted the glide (%.2f s)" % g.lifted_t)
	assert_gt(b.global_position.y, y0 - 0.2, "no longer falling (%.1f -> %.1f)" % [y0, b.global_position.y])


# ------------------------------------------------------------------ boss flow (stand-in) and the King

func test_boss_stand_in_runs_the_data_phases() -> void:
	EnemyBridge.force_stub = true
	var d: VerdantDirector = _director()
	_bolt_at(Vector3(0, 1.2, -110))
	await _frames(2)
	d.start_compost()
	assert_true(d.boss_is_stand_in, "forced stub -> a TestDummy stand-in")
	assert_true(d.boss_active)
	assert_false(d.gates["lagoon_gate"].is_open, "the gate closes behind Bolt")
	assert_eq(d.arena.open_leaks(), 1, "phase 1: one leak")
	assert_true(d.arena.fighting)
	var mx: float = float(d.boss.get("max_hp"))
	d.boss.call("take_damage", _hit(mx * 0.45))
	await _frames(3)
	assert_eq(d.king_phase_count(), 1, "below 60%: the leaks burst (data phase)")
	assert_eq(d.arena.open_leaks(), 3)
	assert_true("phase:2" in d.boss_log)
	d.boss.call("take_damage", _hit(mx))
	await _frames(4)
	assert_true(d.boss_done, "defeated")
	assert_true(d.flag("compost_down"))
	assert_true(d.core.visible, "the core rises")
	assert_true(d.gates["lagoon_gate"].is_open)
	assert_false(d.arena.fighting)
	for p: MurkPool in d.arena.murk_pools:
		assert_true(p.drained, "the outfall drains")


func _king(opts: Dictionary = {}) -> CompostKing:
	var k: CompostKing = EnemySpawner.spawn(&"compost_king", Vector3(0, 0, 0), _world, opts) as CompostKing
	assert_not_null(k, "the King spawns")
	return k


## Damages the King down to `frac` of max HP in 5% steps (the phase clamp stops each burst just under a
## threshold, so small steps land in the right phase without skipping one).
func _push_to(k: CompostKing, frac: float, until_phase: int = 0) -> void:
	for i: int in 80:
		if k.hp <= k.max_hp * frac + 1.0 or (until_phase > 0 and k.phase >= until_phase):
			break
		k.phase_invuln = 0.0
		k.take_damage(_hit(k.max_hp * 0.05, null, false, true))
		await _frames(1)


func test_king_builds_its_own_arena_and_heals_from_open_leaks() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_bolt_at(Vector3(0, 0.95, 5))
	var k: CompostKing = _king()
	await _frames(3)
	assert_true(k.arena_owned, "no planet arena -> its own")
	assert_eq(k.valves().size(), 3, "three valves")
	k.start_fight()
	await _frames(2)
	assert_eq(k.open_leaks(), 1, "phase 1: only W sprays")
	k.phase_invuln = 0.0
	k.take_damage(_hit(100.0))
	var hp0: float = k.hp
	await _frames(60)
	assert_gt(k.hp, hp0 + 3.0, "an open leak heals ~1%%/s (%.0f -> %.0f)" % [hp0, k.hp])
	assert_gt(k.healed, 3.0)


func test_king_seal_feeds_break_and_flinches() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_bolt_at(Vector3(0, 0.95, 5))
	var k: CompostKing = _king()
	await _frames(3)
	k.start_fight()
	await _frames(2)
	var w: CoolantValve = null
	for v: CoolantValve in k.valves():
		if v.valve_id == "W":
			w = v
	assert_not_null(w)
	var acc0: float = k.break_acc
	w.seal()
	await _frames(2)
	assert_eq(k.seals_fed, 1, "the seal reached the King")
	assert_true(k.state == EnemyBase.State.STAGGER or k.breaks > 0, "he flinches (state %s)" % k.state_name())
	assert_true(k.break_acc > acc0 or k.breaks > 0, "BREAK fed +35%")
	assert_eq(k.open_leaks(), 0)


func test_king_attacks_telegraph_and_phase_two_bursts_the_leaks() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 5))
	b.hp = 100.0
	var k: CompostKing = _king()
	await _frames(3)
	k.start_fight()
	for kind: StringName in [&"slam", &"volley"]:
		var before: int = int(k.attacks_done.get(kind, 0))
		for i: int in 400:
			if int(k.attacks_done.get(kind, 0)) > before:
				break
			if k.state == EnemyBase.State.CHASE and k.force_next == &"":
				k.force_next = kind
				k.idle_t = 0.0
			await _frames(1)
		assert_gt(int(k.attacks_done.get(kind, 0)), before, "%s fired" % kind)
		assert_gte(float(k.tele_log.get(kind, 0.0)), 0.4, "%s telegraph >= 0.4 s" % kind)
	await _push_to(k, 0.58)
	assert_eq(k.phase, 2, "phase 2")
	assert_eq(k.open_leaks(), 3, "the leaks burst")
	assert_true(k._allowed(&"thrash") and k._allowed(&"wave"))


func test_king_negotiation_fails_with_leaks_open_then_enrages() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_bolt_at(Vector3(0, 0.95, 5))
	var k: CompostKing = _king()
	await _frames(3)
	k.start_fight()
	await _push_to(k, 0.58)
	await _push_to(k, 0.28, 3)
	assert_eq(k.phase, 3)
	assert_true(k.negotiating, "he pleads at 30%")
	assert_eq(k.pleas, 1)
	var hp0: float = k.hp
	k.take_damage(_hit(50.0))
	assert_almost_eq(k.hp, hp0, 0.01, "invulnerable while pleading")
	assert_false(k.accept_mercy(), "no mercy with the pipes still open")
	k.plea_t = 0.01
	await _frames(3)
	assert_false(k.negotiating)
	assert_true(k.enraged, "NEGOTIATION FAILED: enraged")
	assert_false(k.mercy)
	assert_gt(k.move_speed(), 4.9, "5 m/s enraged")


func test_king_mercy_ending_when_every_leak_is_sealed() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	_bolt_at(Vector3(0, 0.95, 5))
	var defeated: Array = []
	EventBus.boss_defeated.connect(func(id: StringName) -> void: defeated.append(id))
	var k: CompostKing = _king()
	await _frames(3)
	k.start_fight()
	await _push_to(k, 0.58)
	for v: CoolantValve in k.valves():
		v.seal()
	await _frames(2)
	assert_true(k.all_sealed())
	await _push_to(k, 0.28, 3)
	assert_true(k.negotiating, "the plea")
	var b0: int = BS.bolts
	assert_true(k.accept_mercy(), "the handshake is accepted")
	await _frames(2)
	assert_true(k.mercy and k.defeated, "he stands down")
	assert_true(&"compost_king" in defeated, "boss_defeated without a death")
	assert_true(BS.flag("trophy_collective_bargaining"), "the mercy trophy")
	assert_gte(BS.bolts - b0, 60, "the strike-fund bonus (%d)" % (BS.bolts - b0))
	assert_true(k.is_alive(), "not killed")
	assert_false(k.take_damage(_hit(10.0)), "no more hits")


# ------------------------------------------------------------------ the enemies

func _spawn(id: StringName, pos: Vector3, opts: Dictionary = {}) -> EnemyBase:
	var e: EnemyBase = EnemySpawner.spawn(id, pos, _world, opts) as EnemyBase
	assert_not_null(e, "%s spawns" % id)
	return e


func _await_attack(e: EnemyBase, max_frames: int, kind: StringName = &"") -> bool:
	var got: Array = []
	e.attacked.connect(func(k: StringName) -> void: got.append(k))
	for i: int in max_frames:
		await get_tree().physics_frame
		for k: Variant in got:
			if kind == &"" or k == kind:
				return true
	return false


func test_gloomstalker_cloaks_decloaks_to_pounce_and_dies() -> void:
	_floor()
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	b.hp = 100.0
	var e: EnemyBase = _spawn(&"gloomstalker", Vector3(0, 0, 12), {"aggro": true})
	await _frames(3)
	assert_true((e as Gloomstalker).is_cloaked(), "cloaked at 12 m")
	assert_true(await _await_attack(e, 400, &"pounce"), "it pounces")
	assert_false((e as Gloomstalker).is_cloaked(), "decloaked for the pounce")
	assert_gte(float(e.last_telegraph.get("dur", 0.0)), 0.5, "0.5 s telegraph")
	assert_true(await _wait(func() -> bool: return b.hp < 100.0, 60), "12 damage landed")
	var killed: bool = e.take_damage(_hit(999.0, b, false, true))
	assert_true(killed and not e.is_alive())


func test_gloomstalker_damage_reveals_it() -> void:
	_floor()
	_bolt_at(Vector3(0, 0.95, 0))
	var e: Gloomstalker = _spawn(&"gloomstalker", Vector3(0, 0, 14), {"aggro": false}) as Gloomstalker
	await _frames(3)
	assert_true(e.is_cloaked())
	e.take_damage(_hit(5.0))
	await _frames(2)
	assert_false(e.is_cloaked(), "a hit decloaks it for 3 s")
	assert_gt(e.reveal_t, 2.0)


func test_sporelobber_lobs_a_glob_that_leaves_a_cloud() -> void:
	_floor()
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	b.hp = 100.0
	var e: SporeLobber = _spawn(&"sporelobber", Vector3(0, 0, 9), {"aggro": true}) as SporeLobber
	assert_true(await _await_attack(e, 300, &"lob"), "it lobs")
	assert_gte(float(e.last_telegraph.get("dur", 0.0)), 0.55, "0.55 s telegraph")
	assert_eq(e.globs_fired, 1)
	assert_true(await _wait(func() -> bool: return e.clouds > 0, 150), "the glob lands a spore cloud")
	assert_true(e.weak_point_exposed() and e._weak_point_pos().y > 1.0, "the bulb is the weak point")
	e.take_damage(_hit(999.0, b, false, true))
	assert_false(e.is_alive())


func test_pollinator_dusts_an_ally_and_flees() -> void:
	_floor(Vector3(120, 1, 120), Vector3(0, -0.5, 0))
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	var ally: EnemyBase = _spawn(&"gloomstalker", Vector3(0, 0, 30), {"aggro": false})
	var p: Pollinator = _spawn(&"pollinator", Vector3(2, 2.5, 30), {"aggro": true}) as Pollinator
	assert_true(await _await_attack(p, 300, &"dust"), "it dusts")
	assert_gt(ally.aura_t, 0.0, "+30%% damage aura on the ally")
	assert_almost_eq(ally.aura_bonus, 0.3, 0.01)
	assert_true(ally.has_meta(&"pollen"), "+20% speed")
	assert_gt(ally.speed, 6.5)
	p.global_position = Vector3(0, 2.5, 4)
	await _frames(40)
	assert_gt(p.global_position.distance_to(b.global_position), 5.0, "it keeps away from Bolt")
	p.take_damage(_hit(999.0, b))
	assert_false(p.is_alive())


func test_picket_corn_marches_neutral_and_turns_hostile_when_hit() -> void:
	_floor()
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	b.hp = 100.0
	var c: PicketCorn = _spawn(&"picket_corn", Vector3(5, 0, 5), {"loop_center": Vector3(5, 0, 5), "loop_r": 3.0, "loop_phase": 0.0, "group": "t"}) as PicketCorn
	await _frames(60)
	assert_false(c.is_hostile() or c.aggro, "neutral: it never hunts Bolt")
	assert_true(c.is_in_group(&"enemy_decoys"), "enemies may target it")
	assert_gt(c.global_position.distance_to(Vector3(8, 0, 5)), 0.0)
	var hits: Array = []
	c.hit_by_player.connect(func(corn: Node3D, _h: Combat.Hit) -> void: hits.append(corn))
	# an enemy hit is not a grievance
	var g: EnemyBase = _spawn(&"gloomstalker", Vector3(20, 0, 20), {"aggro": false})
	c.take_damage(_hit(5.0, g))
	assert_false(c.is_hostile(), "enemy hits never anger it")
	assert_eq(hits.size(), 0)
	c.take_damage(_hit(5.0, b))
	assert_true(c.is_hostile(), "a player hit: hostile for 20 s")
	assert_eq(hits.size(), 1)
	assert_true(await _await_attack(c, 400, &"bash"), "it sign-bashes")
	assert_gte(float(c.last_telegraph.get("dur", 0.0)), 0.5)
	c.hostile_t = 0.01
	await _frames(3)
	assert_false(c.is_hostile(), "the grievance expires")
