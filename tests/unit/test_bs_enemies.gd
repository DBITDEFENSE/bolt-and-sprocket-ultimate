extends GutTest
## B&S enemies + REPO-TRON in real physics, headless: every Scrapheap enemy spawns, chases Bolt, attacks
## through a telegraph, takes damage, dies and drops bolts; SERVED multiplies damage; DANCING blocks
## attacks; attack tokens cap attackers and shot starts; the Vulture steals and gives back bolts; LIEN;
## Repo-Tron's phases, BREAK, compactor walls, adds and the crane steal/return.

var _world: Node3D
var _bolt: Bolt
var _cam: BoltCamera
var _attacks: Array = []        # [enemy, kind, telegraph seconds actually waited]
var _teles: Array = []          # [enemy, kind, dur, clock]
var _kills: Array = []


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
	EnemySpawner.clear_pool()
	AttackTokens.reset()
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0
	Game.hitstop_t = 0.0
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
	_bolt.scripted = {"dir": Vector3.ZERO}
	_bolt.invuln = 0.0
	BS.god_mode = false
	BS.bolts = 0
	_attacks.clear()
	_teles.clear()
	_kills.clear()
	EventBus.enemy_killed.connect(_on_killed)


func after_each() -> void:
	if EventBus.enemy_killed.is_connected(_on_killed):
		EventBus.enemy_killed.disconnect(_on_killed)
	LienCrawler.clear_lien(_bolt)
	EnemySpawner.clear_pool()
	BS.god_mode = false
	BS.bolts = 0
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0


func _on_killed(e: Node, _w: StringName) -> void:
	_kills.append(e)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _spawn(id: StringName, pos: Vector3, opts: Dictionary = {}) -> EnemyBase:
	var e: EnemyBase = EnemySpawner.spawn(id, pos, _world, opts) as EnemyBase
	e.telegraphed.connect(func(kind: StringName, _sfx: StringName, dur: float) -> void:
		_teles.append([e, kind, dur, AttackTokens.clock]))
	e.attacked.connect(func(kind: StringName) -> void:
		_attacks.append([e, kind, AttackTokens.clock - float(e.last_telegraph.get("started", 0.0))]))
	return e


func _hit(amount: float, crit: bool = false) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, Combat.Type.KINETIC, _bolt)
	h.weapon_id = &"test"
	h.weak_point = crit
	return h


func _pickups() -> int:
	return get_tree().get_nodes_in_group(&"pickups").size()


## Waits until `e` has attacked (or the frame budget runs out). Keeps Bolt hittable.
func _await_attack(e: EnemyBase, max_frames: int) -> bool:
	for i: int in max_frames:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		for a: Array in _attacks:
			if a[0] == e:
				return true
	return false


func _kill_and_check_drops(e: EnemyBase, expect_drops: int) -> void:
	var before: int = _pickups()
	var killed: bool = e.take_damage(_hit(e.hp + 999.0))
	assert_true(killed, "%s: the hit kills it" % e.id)
	assert_false(e.is_alive(), "%s: dead" % e.id)
	assert_true(_kills.has(e), "%s: EventBus.enemy_killed fired" % e.id)
	assert_gte(_pickups() - before, expect_drops, "%s: bolt fountain (%d)" % [e.id, expect_drops])


# ------------------------------------------------------------------ each enemy, end to end

func test_scrap_mutt_chases_pounces_dies() -> void:
	var m: EnemyBase = _spawn(&"scrap_mutt", Vector3(0, 0.1, -9))
	await _frames(2)
	var d0: float = m.flat_dist_to_target()
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(m, 300), "the mutt pounced")
	assert_lt(m.flat_dist_to_target(), d0, "it chased Bolt")
	assert_gte(float(_attacks[0][2]), 0.4, "pounce telegraph lasted >= 0.4 s")
	assert_almost_eq(float(m.last_telegraph["dur"]), 0.45, 0.001, "0.45 s pounce telegraph (raised from 0.32)")
	await _frames(30)
	assert_lt(_bolt.hp, hp0, "the pounce hurt Bolt")
	var hp_e: float = m.hp
	m.take_damage(_hit(5))
	assert_eq(m.hp, hp_e - 5.0, "takes damage")
	await _kill_and_check_drops(m, 6)


func test_tinker_turret_ambush_fires_reloads_dies() -> void:
	var tt: TinkerTurret = _spawn(&"tinker_turret", Vector3(0, 0, -14)) as TinkerTurret
	await _frames(40)
	assert_eq(tt.state, EnemyBase.State.HIDDEN, "hidden under the junk lid")
	tt.global_position = Vector3(0, 0, -7)          # Bolt is now within the 11 m wake radius
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(tt, 400), "the turret rose and fired")
	assert_ne(tt.state, EnemyBase.State.HIDDEN)
	assert_gte(float(_attacks[0][2]), 0.4, "shot telegraph >= 0.4 s (0.55)")
	await _frames(60)
	assert_lt(_bolt.hp, hp0, "a 12-damage shot hit Bolt")
	# it reloads after 3 shots and its coil is a weak point
	for i: int in 600:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		if tt.reloading:
			break
	assert_true(tt.reloading, "reloads after 3 shots")
	assert_true(tt.weak_point_exposed(), "coil exposed while reloading")
	var hp_e: float = tt.hp
	tt.take_damage(_hit(4, true))
	assert_eq(tt.hp, hp_e - 10.0, "coil crit x2.5")
	await _kill_and_check_drops(tt, 8)


func test_vulture_dives_steals_flees_and_returns_bolts() -> void:
	BS.bolts = 20
	var v: VultureDrone = _spawn(&"vulture_drone", Vector3(0, 5, -8)) as VultureDrone
	assert_true(await _await_attack(v, 360), "the vulture dived")
	assert_gte(float(_attacks[0][2]), 0.4, "dive telegraph >= 0.4 s")
	for i: int in 120:
		await get_tree().physics_frame
		if v.stole_total > 0:
			break
	assert_eq(v.stole_total, 5, "stole 5 bolts")
	assert_eq(BS.bolts, 15, "Bolt lost 5 bolts")
	for i: int in 120:
		await get_tree().physics_frame
		if v.fleeing:
			break
	assert_true(v.fleeing, "flees with the loot")
	# shoot it down: loot + own drops come back as pickups
	var before: int = _pickups()
	v.take_damage(_hit(999))
	await _frames(2)
	var pk: Array[Node] = get_tree().get_nodes_in_group(&"pickups")
	assert_gte(pk.size() - before, 6 + 5, "drops its 6 plus the 5 it stole")
	for p: Node in pk:
		(p as Pickup).collect(_bolt)
	assert_eq(BS.bolts, 15 + 11, "the stolen bolts came back")


func test_vulture_escapes_with_loot() -> void:
	BS.bolts = 10
	var v: VultureDrone = _spawn(&"vulture_drone", Vector3(0, 5, -6)) as VultureDrone
	var escaped: Array = []
	v.escaped.connect(func(e: EnemyBase) -> void: escaped.append(e))
	for i: int in 400:
		await get_tree().physics_frame
		if v.fleeing:
			break
	assert_true(v.fleeing)
	v.flee_t = 0.05
	await _frames(10)
	assert_eq(escaped.size(), 1, "despawned after fleeing")
	assert_false(_kills.has(v), "escaping is not a kill")
	assert_eq(BS.bolts, 5, "the bolts are gone")


func test_lien_crawler_burrows_stamps_lien_and_clears_on_death() -> void:
	var c: LienCrawler = _spawn(&"lien_crawler", Vector3(0, 0.1, -9)) as LienCrawler
	await _frames(3)
	assert_true(c.burrowed, "starts underground")
	var mallet: Combat.Hit = _hit(20)
	mallet.is_melee = true
	assert_false(c.take_damage(mallet) or c.hp < c.max_hp, "non-slam hits can't reach it underground")
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(c, 400), "surfaced and stamped")
	assert_gte(float(_attacks[0][2]), 0.4, "stamp telegraph >= 0.4 s")
	assert_lt(_bolt.hp, hp0, "6 damage")
	var st: StatusEffects = EnemyBase.player_status(_bolt)
	assert_true(st.has(&"lien"), "LIEN on Bolt")
	assert_eq(LienCrawler.lien_owner_of(_bolt), c, "the crawler owns the lien")
	# LIEN makes Bolt take +15%
	_bolt.invuln = 0.0
	var h0: float = _bolt.hp
	EnemyBase.hurt_player(_bolt, Combat.Hit.make(20.0))
	assert_almost_eq(h0 - _bolt.hp, 23.0, 0.01, "+15% damage under LIEN")
	# garnish: every 5th bolt flies to the crawler
	BS.bolts = 0
	for i: int in 5:
		var p: Pickup = Pickup.spawn(_world, &"bolt", Vector3(30, 1, 30))
		p.collect(_bolt)
	assert_eq(BS.bolts, 4, "1 in 5 bolts garnished")
	assert_false(c.burrowed, "still surfaced in its recover window")
	await _kill_and_check_drops(c, 7)
	assert_false(st.has(&"lien"), "killing the crawler clears LIEN")


func test_lien_cleared_by_slam_and_slam_forces_it_up() -> void:
	var c: LienCrawler = _spawn(&"lien_crawler", Vector3(0, 0.1, -9)) as LienCrawler
	assert_true(await _await_attack(c, 400))
	var st: StatusEffects = EnemyBase.player_status(_bolt)
	assert_true(st.has(&"lien"))
	for i: int in 200:
		await get_tree().physics_frame
		if c.burrowed:
			break
	assert_true(c.burrowed, "re-burrowed after 1.2 s")
	var slam: Combat.Hit = _hit(5)
	slam.is_slam = true
	c.take_damage(slam)
	assert_false(st.has(&"lien"), "a slam clears LIEN")
	assert_false(c.burrowed, "the slam forced it up")
	assert_eq(c.state, EnemyBase.State.STAGGER, "stunned")


func test_bolt_crate_breaks_into_bolts() -> void:
	var cr: EnemyBase = _spawn(&"bolt_crate", Vector3(3, 0, 0))
	await _frames(2)
	assert_true(cr.is_in_group(&"props") and cr.is_in_group(&"damageable"))
	assert_eq(cr.collision_layer, 1 << 5, "solid prop layer")
	await _kill_and_check_drops(cr, 5)


# ------------------------------------------------------------------ statuses

func test_served_multiplies_damage() -> void:
	var a: EnemyBase = _spawn(&"scrap_mutt", Vector3(20, 0.1, 20))
	var b: EnemyBase = _spawn(&"scrap_mutt", Vector3(-20, 0.1, 20))
	await _frames(2)
	a.take_damage(_hit(10))
	var h: Combat.Hit = _hit(10)
	h.status = {"served": 6.0}
	b.take_damage(h)
	assert_eq(a.max_hp - a.hp, 10.0, "plain hit")
	assert_eq(b.max_hp - b.hp, 14.0, "SERVED: +40%")


func test_dancing_blocks_attacks_and_bobs() -> void:
	var m: EnemyBase = _spawn(&"scrap_mutt", Vector3(0, 0.1, -3))
	await _frames(25)
	var bobbed: float = 0.0
	for i: int in 150:
		m.status.apply(&"dancing", 0.5)
		await get_tree().physics_frame
		bobbed = maxf(bobbed, m.visual.position.y)
	assert_eq(_attacks.size(), 0, "no attacks while dancing")
	assert_eq(m.state, EnemyBase.State.STATUS)
	assert_gt(bobbed, 0.05, "it bobs")
	assert_true(await _await_attack(m, 300), "attacks again once the dance ends")


func test_dancing_cancels_a_telegraph() -> void:
	var m: EnemyBase = _spawn(&"scrap_mutt", Vector3(0, 0.1, -4))
	for i: int in 300:
		await get_tree().physics_frame
		if m.state == EnemyBase.State.TELEGRAPH:
			break
	assert_eq(m.state, EnemyBase.State.TELEGRAPH)
	m.status.apply(&"dancing", 1.0)
	await _frames(2)
	assert_ne(m.state, EnemyBase.State.ATTACK, "cancelled, not delayed")
	assert_eq(_attacks.size(), 0)


func test_frozen_rooted_slowed_launch_and_stun() -> void:
	var m: EnemyBase = _spawn(&"scrap_mutt", Vector3(10, 0.1, 10))
	await _frames(25)
	m.status.apply(&"frozen", 1.0)
	assert_false(m.can_move() or m.can_attack(), "frozen: helpless")
	m.status.clear(&"frozen")
	m.status.apply(&"rooted", 1.0)
	assert_false(m.can_move(), "rooted: can't move")
	assert_true(m.can_attack(), "rooted: can still attack")
	m.status.apply(&"slowed", 1.0)
	assert_almost_eq(m.move_mult(), 0.6, 0.001, "slowed -40%")
	var h: Combat.Hit = _hit(1)
	h.launch = 8.0
	m.take_damage(h)
	assert_eq(m.state, EnemyBase.State.LAUNCHED, "launched")
	assert_false(m.status.has(&"rooted"), "launch cancels root")
	await _frames(70)
	assert_ne(m.state, EnemyBase.State.LAUNCHED, "landed")
	var s: Combat.Hit = _hit(1)
	s.status = {"stun": 0.8}
	m.take_damage(s)
	assert_eq(m.state, EnemyBase.State.STAGGER, "finisher stun -> stagger")
	var tt: EnemyBase = _spawn(&"tinker_turret", Vector3(-10, 0, 10))
	await _frames(25)
	var lh: Combat.Hit = _hit(1)
	lh.launch = 8.0
	tt.take_damage(lh)
	assert_ne(tt.state, EnemyBase.State.LAUNCHED, "turrets can't be launched")


func test_burning_ticks_damage() -> void:
	var m: EnemyBase = _spawn(&"scrap_mutt", Vector3(10, 0.1, 10))
	await _frames(2)
	m.status.apply(&"burning", 3.0)
	await _frames(70)
	assert_lt(m.hp, m.max_hp - 4.0, "5 dps")


func test_elite_variant() -> void:
	var e: EnemyBase = _spawn(&"scrap_mutt", Vector3(10, 0.1, 10), {"elite": true})
	await _frames(2)
	assert_eq(e.max_hp, 54.0, "x1.8 HP")
	assert_eq(e.drops, 9, "x1.5 drops, rounded up")
	assert_true(e.elite)


# ------------------------------------------------------------------ tokens

func test_melee_tokens_cap_attackers() -> void:
	var ms: Array[EnemyBase] = []
	for i: int in 5:
		var a: float = TAU * i / 5.0
		ms.append(_spawn(&"scrap_mutt", Vector3(cos(a) * 6.0, 0.1, sin(a) * 6.0)))
	var peak: int = 0
	for f: int in 420:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		var n: int = 0
		for m: EnemyBase in ms:
			if m.is_attacking():
				n += 1
		peak = maxi(peak, n)
	assert_lte(peak, 2, "at most 2 mutts telegraphing/attacking at once")
	assert_gt(_attacks.size(), 0, "the pack still attacks")
	var feints: int = 0
	for m: EnemyBase in ms:
		feints += (m as ScrapMutt).feints
	assert_gt(feints, 0, "the others feint")


func test_ranged_tokens_cap_shot_starts() -> void:
	var ts: Array[EnemyBase] = []
	for i: int in 6:
		ts.append(_spawn(&"tinker_turret", Vector3(-7.5 + i * 3.0, 0, -8), {"revealed": true, "aggro": true}))
	BS.god_mode = true
	await _frames(400)
	var starts: Array[float] = []
	for t_: Array in _teles:
		if t_[1] == &"shot":
			starts.append(float(t_[3]))
	assert_gt(starts.size(), 3, "turrets fired")
	for i: int in starts.size():
		var n: int = 0
		for j: int in starts.size():
			if starts[j] >= starts[i] and starts[j] < starts[i] + 0.999:
				n += 1
		assert_lte(n, 3, "no more than 3 shot starts in any 1 s window")


# ------------------------------------------------------------------ pooling / spawner

func test_spawner_pools_and_aliases() -> void:
	var m: EnemyBase = EnemySpawner.spawn(&"scrapmutt", Vector3(20, 0.1, 20), _world) as EnemyBase
	assert_eq(m.id, &"scrap_mutt", "original ids alias")
	m.take_damage(_hit(999))
	await _frames(40)
	assert_eq(EnemySpawner.pooled_count(&"scrap_mutt"), 1, "returned to the pool")
	var m2: EnemyBase = EnemySpawner.spawn(&"scrap_mutt", Vector3(-20, 0.1, 20), _world) as EnemyBase
	assert_eq(m2, m, "reused")
	assert_true(m2.is_alive())
	assert_eq(m2.hp, 30.0)


func test_pickup_magnet_and_collect() -> void:
	BS.bolts = 0
	Pickup.spawn(_world, &"bolt", Vector3(3.0, 1.0, 0))
	await _frames(60)
	assert_eq(BS.bolts, 1, "pulled in and collected")


# ------------------------------------------------------------------ REPO-TRON

func _repo(pos: Vector3 = Vector3(0, 0.1, -10)) -> RepoTron:
	var r: RepoTron = EnemySpawner.spawn(&"repo_tron", pos, _world) as RepoTron
	r.telegraphed.connect(func(kind: StringName, _sfx: StringName, dur: float) -> void:
		_teles.append([r, kind, dur, AttackTokens.clock]))
	r.setup_arena(Vector3(0, 0, 0), 15.0, 15.0)
	return r


func test_repotron_starts_runs_phases_and_breaks() -> void:
	BS.god_mode = true
	var started: Array = []
	var health: Array = []
	var cb: Callable = func(id: StringName, _n: String) -> void: started.append(id)
	var hb: Callable = func(_id: StringName, f: float, _b: float) -> void: health.append(f)
	EventBus.boss_started.connect(cb)
	EventBus.boss_health.connect(hb)
	var r: RepoTron = _repo()
	await _frames(30)
	assert_true(r.started, "aggro within 24 m starts the fight")
	assert_eq(started, [&"repo_tron"], "boss_started")
	assert_gt(health.size(), 0, "boss_health streams")
	assert_eq(r.walls.size(), 2, "built the compactor walls")
	assert_almost_eq(r.wall_gap(), 30.0, 0.01)
	# armour: non-crit hits deal 45%
	r.take_damage(_hit(20))
	assert_almost_eq(r.max_hp - r.hp, 9.0, 0.5, "45% armour off the core")
	# a huge crit can't skip phase 2
	r.take_damage(_hit(200, true))
	assert_eq(r.phase, 2, "phase 2 REPOSSESSION MODE")
	assert_gt(r.hp, r.max_hp * 0.33, "phase 3 not skipped")
	assert_gt(r.breaks, 0, "the burst filled the BREAK meter")
	assert_eq(r.state, EnemyBase.State.STAGGER, "BREAK: staggered")
	var hp2: float = r.hp
	r.take_damage(_hit(50, true))
	assert_eq(r.hp, hp2, "1.2 s phase invulnerability")
	await _frames(80)
	r.phase_invuln = 0.0
	# phase 2 adds
	r._add_t = 0.0
	await _frames(3)
	assert_eq(r.adds.size(), 2, "2 Scrap Mutt adds")
	r.phase_invuln = 0.0
	r.take_damage(_hit(60, true))
	assert_eq(r.phase, 3, "phase 3 COMPACTION")
	await _frames(80)
	r._wall_t = 0.02
	await _frames(90)
	assert_almost_eq(r.wall_gap(), 28.0, 0.05, "walls advanced 1 m each")
	# hitting the stamp right after a compact pushes them back
	r.force_next = &"press"
	r.idle_t = 0.0
	r.state = EnemyBase.State.CHASE
	for i: int in 120:
		await get_tree().physics_frame
		if r.core_exposed() and r.state != EnemyBase.State.STAGGER:
			break
	assert_true(r.core_exposed(), "compact opened the recovery window")
	assert_gte(float(r.last_telegraph["dur"]), 0.95 - 0.001, "compact telegraph 0.95 s")
	r.take_damage(_hit(1, true))
	await _frames(90)
	assert_gt(r.wall_gap(), 28.5, "walls pushed back")
	# finish it
	r.phase_invuln = 0.0
	var defeated: Array = []
	var db: Callable = func(id: StringName) -> void: defeated.append(id)
	EventBus.boss_defeated.connect(db)
	r.take_damage(_hit(9999, true))
	assert_eq(defeated, [&"repo_tron"], "boss_defeated")
	assert_almost_eq(r.wall_gap(), 30.0, 0.01, "walls reopen")
	EventBus.boss_started.disconnect(cb)
	EventBus.boss_health.disconnect(hb)
	EventBus.boss_defeated.disconnect(db)


func test_repotron_crane_steals_and_returns_weapon() -> void:
	BS.god_mode = true
	var fake: Node = Node.new()
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node\nvar stolen: int = 0\nvar returned: int = 0\nfunc steal_current() -> StringName:\n\tstolen += 1\n\treturn &\"omni_blaster\"\nfunc return_stolen() -> void:\n\treturned += 1\n"
	s.reload()
	fake.set_script(s)
	fake.name = "Weapons"
	_bolt.add_child(fake)
	var r: RepoTron = _repo(Vector3(0, 0.1, -3.6))
	await _frames(10)
	r.phase = 2
	r.phase_invuln = 0.0
	r.force_next = &"magnet"
	r.idle_t = 0.0
	var stole: Array = []
	r.weapon_stolen.connect(func(w: StringName) -> void: stole.append(w))
	for i: int in 120:
		await get_tree().physics_frame
		if not stole.is_empty():
			break
	assert_eq(stole, [&"omni_blaster"], "the magnet repossessed the gun")
	assert_eq(int(fake.get("stolen")), 1, "Weapons.steal_current() called")
	assert_true(r.hook.is_alive(), "the hook holds it and can be hit")
	assert_gte(float(r.last_telegraph["dur"]), 0.75 - 0.001, "magnet telegraph 0.75 s")
	var acc0: float = r.break_acc
	r.hook.take_damage(_hit(30))
	assert_true(r.hook.is_alive())
	r.hook.take_damage(_hit(30))
	assert_false(r.hook.is_alive(), "60 HP hook smashed")
	assert_eq(int(fake.get("returned")), 1, "Weapons.return_stolen() called")
	assert_eq(r.stolen_weapon, &"")
	assert_true(r.break_acc > acc0 or r.breaks > 0, "+30% BREAK threshold")


func test_repotron_steal_without_weapons_blocks_firing() -> void:
	BS.god_mode = true
	var r: RepoTron = _repo(Vector3(0, 0.1, -3.6))
	await _frames(10)
	r.phase = 2
	r.steal_weapon()
	assert_true(_bolt.has_meta(&"fire_blocked"), "fallback flag blocks firing")
	r.hook.take_damage(_hit(60))
	assert_false(_bolt.has_meta(&"fire_blocked"), "returned")


func test_repotron_telegraphs_every_attack() -> void:
	BS.god_mode = true
	var r: RepoTron = _repo(Vector3(0, 0.1, -6))
	await _frames(10)
	r.phase = 2
	for k: StringName in [&"swipe", &"magnet", &"charge", &"press"]:
		r.force_next = k
		r.idle_t = 0.0
		r.state = EnemyBase.State.CHASE
		for i: int in 200:
			await get_tree().physics_frame
			if int(r.attacks_done.get(k, 0)) > 0:
				break
		assert_gt(int(r.attacks_done.get(k, 0)), 0, "%s happened" % k)
		assert_gte(float(r.last_telegraph["dur"]) if r.last_telegraph["kind"] == k else 0.4, 0.4, "%s telegraph >= 0.4 s" % k)
		await _frames(100)
	var kinds: Array = []
	for t_: Array in _teles:
		kinds.append(t_[1])
		if t_[1] in [&"swipe", &"magnet", &"charge", &"press"]:
			assert_gte(float(t_[2]), 0.4, "boss telegraph %s >= 0.4 s" % t_[1])
	assert_true(kinds.has(&"charge"), "tread charge in phase 2")
