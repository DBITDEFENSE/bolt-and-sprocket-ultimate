extends GutTest
## M3 bosses (BS_ENEMIES §4.0, 4.2-4.4): the Rustvane Sentinel, The Content Creator and The Algorithm.
## Spawn with and without a planet arena, phase gating (no skips, 1.2 s invulnerability), telegraphs >= 0.4 s,
## the BREAK feeders, the CC's spotlight shield, defeat (events, drops, trophy, music cues).

var _world: Node3D
var _bolt: Bolt
var _cam: BoltCamera
var _beats: Array = []


func _box(size: Vector3, pos: Vector3, parent: Node3D = null) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	(parent if parent != null else _world).add_child(b)
	return b


func before_each() -> void:
	EnemySpawner.clear_pool()
	AttackTokens.reset()
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0
	Game.hitstop_t = 0.0
	BS.flags.clear()
	_world = Node3D.new()
	add_child_autofree(_world)
	_box(Vector3(140, 1, 140), Vector3(0, -0.5, 0))
	_bolt = Bolt.new()
	_bolt.position = Vector3(0, 0.95, 6)
	_world.add_child(_bolt)
	_cam = BoltCamera.new()
	_cam.target = _bolt
	_world.add_child(_cam)
	_bolt.camera = _cam
	_bolt.scripted = {"dir": Vector3.ZERO}
	_bolt.invuln = 0.0
	BS.god_mode = true
	BS.bolts = 0
	_beats.clear()
	EventBus.story_beat.connect(_on_beat)


func after_each() -> void:
	if EventBus.story_beat.is_connected(_on_beat):
		EventBus.story_beat.disconnect(_on_beat)
	EnemySpawner.clear_pool()
	BS.god_mode = false
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0


func _on_beat(b: String) -> void:
	_beats.append(b)


func _frames(n: int) -> void:
	for i: int in n:
		Game.slowmo_t = 0.0
		Engine.time_scale = 1.0
		await get_tree().physics_frame


func _hit(amount: float, crit: bool = false) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, Combat.Type.KINETIC, _bolt)
	h.weapon_id = &"test"
	h.weak_point = crit
	return h


func _boss(id: StringName, pos: Vector3, opts: Dictionary = {}) -> PatternBoss:
	var b: PatternBoss = EnemySpawner.spawn(id, pos, _world, opts) as PatternBoss
	assert_not_null(b, "%s spawns" % id)
	return b


func _force(b: PatternBoss, kind: StringName, max_frames: int = 500) -> bool:
	var before: int = int(b.attacks_done.get(kind, 0))
	for i: int in max_frames:
		if int(b.attacks_done.get(kind, 0)) > before:
			return true
		if b.state == EnemyBase.State.CHASE and b.force_next == &"":
			b.force_next = kind
			b.idle_t = 0.0
		await _frames(1)
	return int(b.attacks_done.get(kind, 0)) > before


func _push_phase(b: PatternBoss, to_phase: int) -> void:
	for i: int in 20:
		if b.phase >= to_phase:
			break
		b.phase_invuln = 0.0
		b.take_damage(_hit(2000.0, true))
		await _frames(1)


# ------------------------------------------------------------------ shared rules

func test_phases_gate_and_invulnerability() -> void:
	var b: PatternBoss = _boss(&"rustvane_sentinel", Vector3(0, 0.1, -8))
	await _frames(20)
	assert_true(b.started, "aggro starts the fight")
	assert_true(_beats.has("music:push:bs_boss_rustvane_sentinel"), "boss music pushed")
	b.take_damage(_hit(5000.0, true))
	assert_eq(b.phase, 2, "a huge burst only reaches phase 2")
	assert_gt(b.hp, b.max_hp * 0.33, "phase 3 not skipped")
	var hp: float = b.hp
	b.take_damage(_hit(100.0, true))
	assert_eq(b.hp, hp, "1.2 s phase invulnerability")
	await _push_phase(b, 3)
	assert_eq(b.phase_log, [1, 2, 3], "phases in order")


func test_boss_armour_is_45_percent_off_the_weak_point() -> void:
	var b: PatternBoss = _boss(&"the_algorithm", Vector3(0, 0.1, -10))
	await _frames(20)
	var hp0: float = b.hp
	b.take_damage(_hit(20.0))
	assert_almost_eq(hp0 - b.hp, 9.0, 0.5, "45% off the core")
	var hp1: float = b.hp
	var c: Combat.Hit = _hit(4.0)
	c.point = (b as TheAlgorithm).core_pos()
	b.take_damage(c)
	assert_almost_eq(hp1 - b.hp, 10.0, 0.5, "core crit x2.5, full damage")


func test_defeat_events_drops_trophy_and_music_pop() -> void:
	var defeated: Array = []
	var cb: Callable = func(id: StringName) -> void: defeated.append(id)
	EventBus.boss_defeated.connect(cb)
	var b: PatternBoss = _boss(&"rustvane_sentinel", Vector3(0, 0.1, -8))
	await _frames(20)
	await _push_phase(b, 3)
	b.phase_invuln = 0.0
	var pk: int = get_tree().get_nodes_in_group(&"pickups").size()
	b.take_damage(_hit(99999.0, true))
	assert_eq(defeated, [&"rustvane_sentinel"], "boss_defeated")
	assert_gte(get_tree().get_nodes_in_group(&"pickups").size() - pk, 30, "30 bolts")
	assert_true(BS.flag("trophy_wristband_optional"), "no damage taken: Wristband Optional")
	assert_true(_beats.has("music:pop:bs_boss_rustvane_sentinel"), "boss music popped")
	EventBus.boss_defeated.disconnect(cb)


# ------------------------------------------------------------------ Rustvane Sentinel

func test_sentinel_beam_guide_and_muzzle_shot_feeds_break() -> void:
	var b: RustvaneSentinel = _boss(&"rustvane_sentinel", Vector3(0, 0.1, -8)) as RustvaneSentinel
	await _frames(20)
	assert_true(await _force(b, &"beam"), "charge beam")
	assert_gte(float(b.tele_log[&"beam"]), 1.25 - 0.001, "1.25 s guide-line telegraph")
	var beams: int = get_tree().get_nodes_in_group(&"enemy_beams").size()
	assert_gt(beams, 0, "the beam fired")
	await _frames(80)
	b.force_next = &"beam"
	b.idle_t = 0.0
	for i: int in 300:
		await _frames(1)
		if b.state == EnemyBase.State.TELEGRAPH and b.attack_kind == &"beam":
			break
	var h: Combat.Hit = _hit(3.0)
	h.point = b.muzzle_pos()
	var acc: float = b.break_acc
	b.take_damage(h)
	assert_eq(b.muzzle_shots, 1, "a shot down the barrel")
	assert_ne(b.state, EnemyBase.State.TELEGRAPH, "cancels that beam")
	assert_true(b.break_acc >= acc + b.break_threshold() * 0.25 - 0.01 or b.breaks > 0, "+25% of the BREAK threshold")


func test_sentinel_uses_a_given_arena_pillars_and_add_spawns() -> void:
	var arena: Node3D = Node3D.new()
	arena.name = "StripMineArena"
	arena.set_meta(&"size", Vector2(40, 40))
	_world.add_child(arena)
	var c: Marker3D = Marker3D.new()
	c.name = "Center"
	arena.add_child(c)
	c.position = Vector3(0, 0, -8)
	var pil: StaticBody3D = _box(Vector3(2.4, 7, 2.4), Vector3(0, 3.5, 6), arena)
	pil.name = "PillarA"
	var sp: Marker3D = Marker3D.new()
	sp.name = "AddSpawnA"
	arena.add_child(sp)
	sp.position = Vector3(-10, 0.3, -10)
	var b: RustvaneSentinel = _boss(&"rustvane_sentinel", Vector3(0, 0.1, -8), {"arena": arena}) as RustvaneSentinel
	await _frames(20)
	assert_false(b.arena_owned, "uses the planet's arena")
	assert_eq(b.anchors("Pillar").size(), 1, "finds Pillar* anchors")
	assert_almost_eq(b.arena_mid.z, -8.0, 0.01, "Center anchor")
	assert_eq(b.arena_size, Vector2(40, 40), "size meta")
	await _push_phase(b, 3)
	await _frames(5)
	assert_eq(b.adds.size(), 2, "2 Ambassadogs")
	for a: Node3D in b.adds:
		assert_almost_eq(a.global_position.x, -10.0, 1.0, "at the AddSpawn anchor")
	# a ram into the pillar: Bolt stands behind it
	_bolt.global_position = Vector3(0, 0.95, 12)
	await _frames(80)
	assert_true(await _force(b, &"ram"), "ram")
	assert_gte(float(b.tele_log[&"ram"]), 0.7 - 0.001, "0.7 s lane telegraph")
	for i: int in 200:
		await _frames(1)
		if b.ram_stuns > 0:
			break
	assert_eq(b.ram_stuns, 1, "rammed the quarry pillar: self-stun")
	assert_eq(b.state, EnemyBase.State.STAGGER)


# ------------------------------------------------------------------ The Content Creator

func test_cc_spotlight_shield_and_drones_break() -> void:
	var b: ContentCreator = _boss(&"content_creator", Vector3(0, 0.1, 0)) as ContentCreator
	_bolt.global_position = Vector3(0, 0.95, 12)
	for i: int in 900:
		await _frames(1)
		if b.drones_alive() == 3:
			break
	assert_eq(b.drones_alive(), 3, "3 camera drones")
	assert_true(b.shielded())
	b.phase_invuln = 0.0
	var hp0: float = b.hp
	b.take_damage(_hit(40.0))
	assert_almost_eq(hp0 - b.hp, 10.0, 0.5, "SPOTLIGHT SHIELD: 25% everywhere")
	b.break_acc = 0.0
	var d0: CameraDrone = b.drones[0]
	d0.take_damage(_hit(999.0))
	assert_almost_eq(b.break_acc, b.break_threshold() * 0.2, 0.5, "a drone kill adds 20% of the threshold")
	b.break_cd = 5.0                                 # even during the cooldown the 3rd drone forces a BREAK
	for d: CameraDrone in b.drones.duplicate():
		if is_instance_valid(d) and d.is_alive():
			d.take_damage(_hit(999.0))
	assert_gt(b.breaks, 0, "all three down: guaranteed BREAK")
	assert_false(b.shielded(), "shield down")
	assert_eq(b.state, EnemyBase.State.STAGGER)


func test_cc_unbox_contents_and_sponsored_backfire() -> void:
	var b: ContentCreator = _boss(&"content_creator", Vector3(0, 0.1, 0)) as ContentCreator
	_bolt.global_position = Vector3(0, 0.95, 12)
	await _frames(30)
	b.force_box = &"lifeguard"
	assert_true(await _force(b, &"unbox"), "unboxing")
	assert_gte(float(b.tele_log[&"unbox"]), 0.8 - 0.001, "0.8 s shadow decal")
	await _frames(110)
	var lg: int = 0
	for a: Node3D in b.adds:
		if a is LifeguardBot:
			lg += 1
	assert_eq(lg, 1, "the box held a Lifeguard Bot")
	b.force_box = &"bomb"
	b.force_next = &"unbox"
	b.idle_t = 0.0
	var box: MysteryBox = null
	for i: int in 400:
		await _frames(1)
		for n: Node in _world.get_children():
			if n is MysteryBox and (n as MysteryBox).contents == &"bomb":
				box = n
		if box != null:
			break
	assert_not_null(box, "a SPONSORED box drops")
	assert_true(box.is_alive() and box.is_in_group(&"enemies"), "shootable while it falls")
	box.take_damage(_hit(1.0))
	assert_eq(b.sponsored_shots, 1, "detonates on the CC")


func test_cc_pool_water_doubles_the_sweep() -> void:
	var arena: Node3D = Node3D.new()
	_world.add_child(arena)
	var pool: Marker3D = Marker3D.new()
	pool.name = "Pool"
	pool.set_meta(&"radius", 5.0)
	arena.add_child(pool)
	pool.position = Vector3(20, 0, 0)
	var b: ContentCreator = _boss(&"content_creator", Vector3(20, 0.1, 10), {"arena": arena}) as ContentCreator
	await _frames(5)
	assert_almost_eq(b.pool_radius(), 5.0, 0.001, "Pool meta radius")
	assert_true(b.in_water(Vector3(21, 0.95, 1)), "in the pool")
	assert_false(b.in_water(Vector3(20, 0.95, 7)), "on the deck")


# ------------------------------------------------------------------ The Algorithm

func test_algorithm_zones_summons_trending_and_overload_feeders() -> void:
	var b: TheAlgorithm = _boss(&"the_algorithm", Vector3(0, 0.1, -10)) as TheAlgorithm
	_bolt.global_position = Vector3(0, 0.95, 4)
	for i: int in 400:
		await _frames(1)
		if int(b.attacks_done.get(&"violation_zone", 0)) > 0 and b.adds.size() >= 2:
			break
	assert_gt(int(b.attacks_done.get(&"violation_zone", 0)), 0, "VIOLATION zone stamped")
	assert_gte(float(b.tele_log[&"violation_zone"]), 1.2 - 0.001, "1.2 s shrinking ring")
	assert_gte(b.adds.size(), 2, "Recommended For You summoned a pair")
	assert_gte(float(b.tele_log[&"recommend"]), 1.0 - 0.001, "1.0 s holo-card")
	b.break_acc = 0.0
	b.break_cd = 0.0
	var cd: Combat.Hit = _hit(1.0)
	cd.weapon_id = &"cease_desist"
	b.phase_invuln = 0.0
	b.take_damage(cd)
	assert_gte(b.break_acc, b.max_hp * 0.04, "C&D: +4% max HP BREAK")
	await _push_phase(b, 2)
	assert_almost_eq(b.spd(), 0.62, 0.001, "TRENDING x0.62")
	b.do_break()
	assert_gt(b.overloads, 0, "BREAK plays as OVERLOAD")
	assert_eq(b.overloads, b.breaks, "every BREAK is an OVERLOAD")
	await _push_phase(b, 3)
	assert_true(b.doomscroll_on, "VIRAL: doomscroll")
	assert_true(await _force(b, &"mega_fine"), "mega-fine")
	assert_gte(float(b.tele_log[&"mega_fine"]), 1.6 - 0.001, "1.6 s telegraph")
	assert_true(await _force(b, &"like_orbs"), "engagement bait")


func test_algorithm_served_add_complaint() -> void:
	var b: TheAlgorithm = _boss(&"the_algorithm", Vector3(0, 0.1, -10)) as TheAlgorithm
	_bolt.global_position = Vector3(0, 0.95, 4)
	for i: int in 400:
		await _frames(1)
		if b.adds.size() >= 1:
			break
	var a: EnemyBase = b.adds[0] as EnemyBase
	a.global_position = b.global_position + b.forward() * 3.0
	a.status.apply(&"served", 6.0)
	b.break_acc = 0.0
	b.break_cd = 0.0
	b.break_t = 0.0
	a.take_damage(_hit(9999.0))
	assert_eq(b.complaints, 1, "a SERVED add died near the wall")
	assert_almost_eq(b.break_acc, b.max_hp * 0.02, 0.5, "+2% max HP")


# ------------------------------------------------------------------ planet arena contracts (B's RustvaneArena, C's FineTreeArena)

func _marker(parent: Node3D, nm: String, pos: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = nm
	parent.add_child(m)
	m.position = pos
	return m


func test_sentinel_searchlight_rides_the_arena_mount() -> void:
	var arena: Node3D = Node3D.new()
	_world.add_child(arena)
	_marker(arena, "Center", Vector3(0, 0, -8))
	var mount: Marker3D = _marker(arena, "Searchlight", Vector3(15, 7, -8))
	var b: RustvaneSentinel = _boss(&"rustvane_sentinel", Vector3(0, 0.1, -8), {"arena": arena}) as RustvaneSentinel
	await _frames(5)
	assert_true(mount.is_ancestor_of(b._search_pivot), "the lamp moved to the terrace mount")
	await _push_phase(b, 2)
	await _frames(30)
	var d: Vector3 = b.searchlight_dir()
	assert_gt(d.dot((Vector3(0, 0, -8) - mount.global_position).normalized()), 0.4, "it sweeps across the quarry centre")


func test_cc_follows_the_hover_stage_docks_drones_and_uses_arena_tiles() -> void:
	var arena: Node3D = Node3D.new()
	_world.add_child(arena)
	var pool: Marker3D = _marker(arena, "Pool", Vector3(0, 0, 0))
	pool.set_meta(&"radius", 3.2)
	pool.set_meta(&"surface_y", 0.0)
	pool.set_meta(&"aabb", AABB(Vector3(-6, -1, -3), Vector3(12, 2, 6)))
	var stage: Marker3D = _marker(arena, "HoverStage", Vector3(0, 4, -10))
	_marker(stage, "Mount", Vector3(0, 0.5, 0))
	var masts: Node3D = _marker(arena, "Masts", Vector3.ZERO)
	for i: int in 3:
		_marker(masts, "DroneSpawn_%d" % i, Vector3(-10 + i * 10, 12, 8))
	var tiles: Node3D = _marker(arena, "PoolTiles", Vector3.ZERO)
	for r: int in 4:
		for c: int in 4:
			var t: Marker3D = _marker(tiles, "Tile_%d_%d" % [r, c], Vector3(-3 + c * 2, 0, 6 + r * 2))
			t.set_meta(&"row", r)
			t.set_meta(&"col", c)
	var b: ContentCreator = _boss(&"content_creator", Vector3(0, 4.5, -10), {"arena": arena}) as ContentCreator
	_bolt.global_position = Vector3(0, 0.95, 9)
	for i: int in 900:
		await _frames(1)
		if b.drones_alive() == 3:
			break
	assert_almost_eq(b.global_position.distance_to(Vector3(0, 4.5, -10)), 0.0, 1.0, "floats at the stage mount")
	assert_true(b.in_water(Vector3(5, 0.5, 2)), "Pool aabb: the rectangular water")
	assert_false(b.in_water(Vector3(5, 0.5, 4)))
	for d: CameraDrone in b.drones:
		assert_ne(d.dock, Vector3.INF, "drones dock at the mast spawns")
		assert_lt(Vector2(d.global_position.x - d.dock.x, d.global_position.z - d.dock.z).length(), 3.0)
	await _push_phase(b, 3)
	await _frames(80)
	assert_true(await _force(b, &"like_floor"), "LIKE floor")
	assert_eq(b.like_tiles, 8, "half the arena's tiles in reach light up (checkerboard)")


func test_algorithm_uses_the_finetree_wall_lanes_notices_and_walkways() -> void:
	var arena: Node3D = Node3D.new()
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node3D\nsignal notice_delivered(slot: StringName, by: Node)\nvar reversed: int = 0\nvar doom: Array = []\nvar smashed: int = 0\nfunc reverse_walkways(_s: float = 6.0) -> void:\n\treversed += 1\nfunc set_doomscroll(on: bool) -> void:\n\tdoom.append(on)\nfunc smash_cover_near(_p: Vector3, _r: float) -> int:\n\tsmashed += 1\n\treturn 0\n"
	s.reload()
	arena.set_script(s)
	_world.add_child(arena)
	var c: Marker3D = _marker(arena, "Center", Vector3(0, 0, 0))
	c.set_meta(&"size", Vector2(36, 36))
	var wall: Marker3D = _marker(arena, "ServerWall", Vector3(0, 4, -16.5))
	var eyes: Marker3D = _marker(wall, "FaceEyes", Vector3.ZERO)
	var em: MeshInstance3D = EnemyFx.box(eyes, Vector3.ONE, Vector3.ZERO, EnemyFx.mat(Color.YELLOW))
	var lanes: Node3D = _marker(arena, "FineLanes", Vector3.ZERO)
	for i: int in 3:
		_marker(lanes, "Lane_%d" % i, Vector3(-6 + i * 6, 0, 0)).set_meta(&"half_length", 12.0)
	_bolt.global_position = Vector3(0, 0.95, 4)
	var b: TheAlgorithm = _boss(&"the_algorithm", Vector3(0, 0.1, -14), {"arena": arena}) as TheAlgorithm
	await _frames(20)
	assert_eq(b.arena_size, Vector2(36, 36), "size meta on Center")
	assert_almost_eq(b.core_pos().z, -16.5 + 1.3, 0.05, "the core sits on the arena wall's face")
	b.break_acc = 0.0
	b.break_cd = 0.0
	arena.emit_signal(&"notice_delivered", &"SlotMid", null)
	assert_eq(b.notices, 1, "a delivered complaint notice")
	assert_almost_eq(b.break_acc, b.max_hp * 0.04, 0.5, "= a Cease & Desist: +4% max HP")
	await _push_phase(b, 2)
	assert_eq((em.material_override as StandardMaterial3D).albedo_color, Color("#ff4d3a"), "TRENDING turns the arena face red")
	b._rain_t = 0.01
	for i: int in 120:
		await _frames(1)
		if int(b.attacks_done.get(&"fine_rain", 0)) > 0:
			break
	assert_gt(int(b.attacks_done.get(&"fine_rain", 0)), 0, "Fine Rain on the arena lanes")
	b._walk_t = 0.01
	await _frames(70)
	assert_gt(int(arena.get("reversed")), 0, "arena.reverse_walkways()")
	await _push_phase(b, 3)
	assert_eq(arena.get("doom"), [true], "arena.set_doomscroll(true)")
	b._zone_t = 0.01
	await _frames(85)
	assert_gt(int(arena.get("smashed")), 0, "violation zones smash cover")
	b.phase_invuln = 0.0
	b.take_damage(_hit(99999.0, true))
	assert_eq(arena.get("doom"), [true, false], "doomscroll off on defeat")
