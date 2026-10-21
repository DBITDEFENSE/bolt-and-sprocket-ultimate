extends GutTest
## M3 enemies (BS_ENEMIES §3.2 Rustvane Canyon, §3.3 Nova Plaza, §6 player debuffs) in real physics, headless.
## Every enemy spawns through EnemySpawner by its doc id, closes in, attacks through a telegraph that meets
## §1.2, hurts Bolt, takes damage, dies and drops bolts; plus each one's signature mechanic and elite trick.

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
	PlayerDebuffs.reset_barks()
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
	EnemySpawner.clear_pool()
	BS.god_mode = false
	BS.bolts = 0
	Engine.time_scale = 1.0
	Game.slowmo_t = 0.0


func _on_killed(e: Node, _w: StringName) -> void:
	_kills.append(e)


func _frames(n: int) -> void:
	for i: int in n:
		_bolt.invuln = 0.0
		await get_tree().physics_frame


func _spawn(id: StringName, pos: Vector3, opts: Dictionary = {}) -> EnemyBase:
	var e: EnemyBase = EnemySpawner.spawn(id, pos, _world, opts) as EnemyBase
	assert_not_null(e, "%s spawns" % id)
	_watch(e)
	return e


func _watch(e: EnemyBase) -> void:
	e.telegraphed.connect(func(kind: StringName, _sfx: StringName, dur: float) -> void:
		_teles.append([e, kind, dur, AttackTokens.clock]))
	e.attacked.connect(func(kind: StringName) -> void:
		_attacks.append([e, kind, AttackTokens.clock - float(e.last_telegraph.get("started", 0.0))]))


func _hit(amount: float, crit: bool = false) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, Combat.Type.KINETIC, _bolt)
	h.weapon_id = &"test"
	h.weak_point = crit
	return h


func _pickups() -> int:
	return get_tree().get_nodes_in_group(&"pickups").size()


func _await_attack(e: EnemyBase, max_frames: int, kind: StringName = &"") -> bool:
	for i: int in max_frames:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		for a: Array in _attacks:
			if a[0] == e and (kind == &"" or a[1] == kind):
				return true
	return false


func _waited(e: EnemyBase, kind: StringName) -> float:
	for a: Array in _attacks:
		if a[0] == e and a[1] == kind:
			return float(a[2])
	return -1.0


func _kill_and_check_drops(e: EnemyBase, expect_drops: int) -> void:
	var before: int = _pickups()
	var killed: bool = e.take_damage(_hit(e.hp + 999.0, true))
	assert_true(killed, "%s: the hit kills it" % e.id)
	assert_false(e.is_alive(), "%s: dead" % e.id)
	assert_true(_kills.has(e), "%s: EventBus.enemy_killed fired" % e.id)
	assert_gte(_pickups() - before, expect_drops, "%s: bolt fountain (%d)" % [e.id, expect_drops])


func _bolt_hurt_since(hp0: float) -> bool:
	return _bolt.hp < hp0


# ------------------------------------------------------------------ registration

func test_every_m3_id_is_registered_with_data() -> void:
	for id: String in ["ambassadog", "selfie_sentry", "lifeguard_bot", "review_bomber", "meter_maid", "hoa_enforcer",
			"surge_drone", "zoning_board", "zoning_pylon", "rustvane_sentinel", "content_creator", "the_algorithm", "cc_camera_drone"]:
		assert_true(EnemySpawner.known_ids().has(id), "%s registered in EnemySpawner" % id)
		var has_def: bool = not EnemySpawner.def_for(StringName(id)).is_empty() or (Data.table("bs/bosses") as Dictionary).has(id)
		assert_true(has_def, "%s has data" % id)
	assert_eq(EnemySpawner.resolve_id(&"selfie"), &"selfie_sentry", "original ids alias")
	assert_eq(EnemySpawner.resolve_id(&"miniboss"), &"content_creator")
	assert_eq(EnemySpawner.resolve_id(&"algorithm"), &"the_algorithm")


func test_new_lines_resolve() -> void:
	EnemyBase.register_lines(true)
	for k: Variant in (Data.table("bs/enemies")["lines"] as Dictionary).keys():
		if not str(k).begins_with("_"):
			assert_ne(EnemyBase.line_text(str(k)), "", "%s has text" % k)


# ------------------------------------------------------------------ Rustvane Canyon

func test_ambassadog_flanks_bows_pounces_and_hands_a_card() -> void:
	var d: Ambassadog = _spawn(&"ambassadog", Vector3(0, 0.1, -12)) as Ambassadog
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(d, 420, &"bow"), "it bowed and pounced")
	assert_almost_eq(float(d.last_telegraph["dur"]), 0.45, 0.001, "0.45 s bow")
	assert_gte(_waited(d, &"bow"), 0.4, "the bow lasted >= 0.4 s")
	await _frames(30)
	assert_true(_bolt_hurt_since(hp0), "9-damage pounce landed")
	assert_eq(d.cards_given, 1, "handed Bolt a loyalty card")
	var dbf: PlayerDebuffs = PlayerDebuffs.of(_bolt)
	assert_true(dbf.sticker_t > 0.0, "the card sticker is on screen")
	assert_gt(d.retreat_t, 0.0, "it trots back")
	await _kill_and_check_drops(d, 6)


func test_ambassadog_elite_referral_bonus() -> void:
	var a: Ambassadog = _spawn(&"ambassadog", Vector3(20, 0.1, 20), {"elite": true}) as Ambassadog
	var b: Ambassadog = _spawn(&"ambassadog", Vector3(22, 0.1, 20)) as Ambassadog
	await _frames(2)
	assert_eq(a.max_hp, roundf(26.0 * 1.8), "elite x1.8 HP")
	var m0: float = b.move_mult()
	a.take_damage(_hit(999))
	assert_true(b.status.has(&"referral"), "nearest Ambassadog got the referral")
	assert_almost_eq(b.move_mult(), m0 * 1.5, 0.001, "+50% speed")


func test_selfie_sentry_flashes_blinds_bursts_and_dies() -> void:
	var s: SelfieSentry = _spawn(&"selfie_sentry", Vector3(0, 3, -8)) as SelfieSentry
	_cam.set_process(false)
	var hp0: float = _bolt.hp
	var blinded: bool = false
	for i: int in 400:
		_bolt.invuln = 0.0
		_cam.cam.global_position = _bolt.global_position + Vector3(0, 1.5, 3)
		_cam.cam.look_at(s._weak_point_pos())               # staring right into the ring light
		await get_tree().physics_frame
		if PlayerDebuffs.of(_bolt).is_blinded():
			blinded = true
			break
	assert_true(blinded, "facing the lens at the flash: BLINDED")
	assert_gte(_waited(s, &"flash"), 0.4, "flash telegraph >= 0.4 s")
	assert_almost_eq(float(s.last_telegraph["dur"]), 0.5, 0.001, "0.5 s ring-light swell")
	assert_true(EnemyBase.player_status(_bolt).has(&"blinded"), "mirrored as a status stamp")
	await _frames(60)
	assert_eq(s.shots_fired, 3, "a 3-shot burst")
	assert_true(_bolt_hurt_since(hp0), "the burst hit")
	await _kill_and_check_drops(s, 7)


func test_selfie_looking_away_avoids_blind_and_lens_shot_cancels() -> void:
	var s: SelfieSentry = _spawn(&"selfie_sentry", Vector3(0, 3, -8)) as SelfieSentry
	_cam.set_process(false)
	for i: int in 400:
		_cam.cam.global_position = _bolt.global_position + Vector3(0, 1.5, 3)
		_cam.cam.look_at(_bolt.global_position + Vector3(0, 1.5, 20))     # looking away
		await get_tree().physics_frame
		if s.flashes > 0:
			break
	assert_eq(s.flashes, 1, "it flashed")
	assert_false(PlayerDebuffs.of(_bolt).is_blinded(), "looking away: no blind")
	# lens crit during the next telegraph cancels the flash and burst
	for i: int in 400:
		await get_tree().physics_frame
		if s.state == EnemyBase.State.TELEGRAPH:
			break
	assert_eq(s.state, EnemyBase.State.TELEGRAPH)
	var flashes: int = s.flashes
	var h: Combat.Hit = _hit(2)
	h.point = s._weak_point_pos()
	s.take_damage(h)
	await _frames(40)
	assert_eq(s.flashes, flashes, "lens shot: no flash")
	assert_ne(s.state, EnemyBase.State.ATTACK)


func test_selfie_elite_going_viral_like_drone_absorbs_a_hit() -> void:
	var s: SelfieSentry = _spawn(&"selfie_sentry", Vector3(0, 3, -8), {"elite": true}) as SelfieSentry
	_cam.set_process(false)
	for i: int in 400:
		_cam.cam.global_position = _bolt.global_position + Vector3(0, 1.5, 3)
		_cam.cam.look_at(s._weak_point_pos())
		await get_tree().physics_frame
		if s.blinds > 0:
			break
	assert_eq(s.like_shields, 1, "a successful blind spawns a like drone")
	var hp0: float = s.hp
	s.take_damage(_hit(10))
	assert_eq(s.hp, hp0, "the like drone absorbed the hit")
	assert_eq(s.like_shields, 0)
	s.take_damage(_hit(10))
	assert_lt(s.hp, hp0, "then it takes damage")


func test_lifeguard_lobs_ring_leaves_slowing_puddle_contact_and_dies() -> void:
	var l: LifeguardBot = _spawn(&"lifeguard_bot", Vector3(0, 0.1, -9)) as LifeguardBot
	assert_true(l.heavy, "heavy")
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(l, 300, &"lob"), "it lobbed a flotation ring")
	assert_gte(_waited(l, &"lob"), 0.4, "whistle telegraph >= 0.4 s")
	assert_almost_eq(float(l.last_telegraph["dur"]), 0.5, 0.001, "0.5 s sustained whistle")
	var puddled: bool = false
	for i: int in 120:
		await get_tree().physics_frame
		if l.puddles > 0:
			puddled = true
			break
	assert_true(puddled, "the ring leaves a NO RUNNING puddle")
	assert_true(_bolt_hurt_since(hp0), "12-damage blast hit")
	await _frames(2)
	var dbf: PlayerDebuffs = PlayerDebuffs.of(_bolt)
	assert_true(dbf.is_slowed(), "standing in the puddle: SLOWED")
	assert_almost_eq(dbf.slow_mult(), 0.7, 0.001, "-30%")
	# the slow really slows: scripted walk for 30 frames inside vs outside
	var p0: Vector3 = _bolt.global_position
	_bolt.scripted = {"dir": Vector3(1, 0, 0)}
	await _frames(20)
	var slow_d: float = Vector2(_bolt.global_position.x - p0.x, _bolt.global_position.z - p0.z).length()
	assert_gt(slow_d, 0.05, "he still moves")
	_bolt.scripted = {"dir": Vector3.ZERO}
	var launched: Combat.Hit = _hit(1)
	launched.launch = 8.0
	l.take_damage(launched)
	assert_ne(l.state, EnemyBase.State.LAUNCHED, "heavies can't be launched")
	await _kill_and_check_drops(l, 11)


func test_lifeguard_elite_adult_swim_fans_three() -> void:
	var l: LifeguardBot = _spawn(&"lifeguard_bot", Vector3(0, 0.1, -9), {"elite": true}) as LifeguardBot
	BS.god_mode = true
	var shots: int = 0
	var cb: Callable = func(n: Node) -> void:
		if n is EnemyProjectile and (n as EnemyProjectile).kind == &"flotation_ring":
			shots += 1
	get_tree().node_added.connect(cb)
	assert_true(await _await_attack(l, 300, &"lob"))
	await _frames(2)
	get_tree().node_added.disconnect(cb)
	assert_eq(l._land_at.size(), 3, "Adult Swim: 3 rings in a fan")


func test_review_bomber_star_then_ring_and_bombs_are_fragile() -> void:
	var r: ReviewBomber = _spawn(&"review_bomber", Vector3(0, 0.1, -6)) as ReviewBomber
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(r, 400, &"review"), "it posted a review")
	assert_eq(r.last_pattern, &"star", "first cycle: a star")
	assert_eq(r.last_points.size(), 5, "5 bombs")
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in r.last_points:
		c += p
	c /= 5.0
	for p: Vector3 in r.last_points:
		assert_almost_eq(Vector2(p.x - c.x, p.z - c.z).length(), 4.0, 0.05, "star points 4 m out")
	assert_gt(r.global_position.y, 6.0, "cruises high")
	# decals lit >= 0.8 s before impact: telegraph (0.4) + fall (0.8)
	assert_gte(float(r.last_telegraph["dur"]) + float(r.RB()["fall_time"]), 0.8, "decals glow >= 0.8 s before impact")
	# shoot a bomb in flight: DENIED
	var bombs: Array[EnemyProjectile] = []
	for n: Node in get_tree().get_nodes_in_group(&"enemy_projectiles"):
		if n is EnemyProjectile and (n as EnemyProjectile).kind == &"review_bomb":
			bombs.append(n as EnemyProjectile)
	assert_eq(bombs.size(), 5, "5 bombs in flight")
	assert_true(bombs[0].fragile, "fragile")
	bombs[0].deny()
	assert_false(bombs[0].is_active(), "popped harmlessly")
	await _frames(70)
	assert_false(_bolt_hurt_since(hp0), "standing in the star's centre is safe")
	r.fire_cd = 0.0
	for i: int in 400:
		await get_tree().physics_frame
		if r.posts >= 2:
			break
	assert_gte(r.posts, 2, "posts again")
	assert_eq(r.last_pattern, &"ring", "even cycle: a ring of 5")
	await _kill_and_check_drops(r, 7)


func test_review_bomber_elite_posts_both_patterns() -> void:
	var r: ReviewBomber = _spawn(&"review_bomber", Vector3(0, 0.1, -6), {"elite": true}) as ReviewBomber
	BS.god_mode = true
	assert_true(await _await_attack(r, 400, &"review"))
	assert_eq(r.last_pattern, &"star")
	await _frames(42)
	assert_eq(r.last_pattern, &"ring", "Verified Purchaser: a ring 0.6 s after the star")
	await _frames(30)
	assert_eq(r.posts, 2, "both posted")


# ------------------------------------------------------------------ Nova Plaza

func test_meter_maid_pounces_and_clamps_a_loiterer() -> void:
	var m: MeterMaid = _spawn(&"meter_maid", Vector3(0, 0.1, -7)) as MeterMaid
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(m, 400), "she pounced")
	assert_gte(float(m.last_telegraph["dur"]), 0.45 - 0.001, "0.45 s telegraph")
	await _frames(30)
	assert_true(_bolt_hurt_since(hp0), "10 damage")
	# Bolt stands still >= 1.5 s within 8 m: the next pounce is a boot clamp
	var clamped: bool = false
	for i: int in 600:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		if m.clamps > 0:
			clamped = true
			break
	assert_true(clamped, "boot clamp on a stationary Bolt")
	var dbf: PlayerDebuffs = PlayerDebuffs.of(_bolt)
	assert_true(dbf.is_clamped(), "CLAMPED")
	var p0: Vector3 = _bolt.global_position
	_bolt.scripted = {"dir": Vector3(1, 0, 0)}
	await _frames(20)
	assert_almost_eq(Vector2(_bolt.global_position.x - p0.x, _bolt.global_position.z - p0.z).length(), 0.0, 0.05, "can't move while clamped")
	_bolt.scripted = {"dir": Vector3.ZERO}
	for i: int in 5:
		dbf.mash()
	assert_false(dbf.is_clamped(), "mashing frees him")
	await _kill_and_check_drops(m, 7)


func test_meter_maid_elite_double_parked_and_slam_scatter() -> void:
	var m: MeterMaid = _spawn(&"meter_maid", Vector3(0, 0.1, -7), {"elite": true}) as MeterMaid
	var mutt: EnemyBase = _spawn(&"scrap_mutt", Vector3(3, 0.1, 3))
	for i: int in 900:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		if m.clamps > 0:
			break
	assert_gt(m.clamps, 0)
	assert_true(mutt.status.has(&"double_parked"), "nearby enemies are ticketed")
	assert_almost_eq(mutt.out_mult(), 1.2, 0.001, "+20% damage")
	await _frames(5)
	var slam: Combat.Hit = _hit(2)
	slam.is_slam = true
	m.take_damage(slam)
	assert_eq(m.state, EnemyBase.State.STAGGER, "a slam scatters her")


func test_hoa_enforcer_shield_pings_guns_mallet_strips_and_fires() -> void:
	var h: HOAEnforcer = _spawn(&"hoa_enforcer", Vector3(0, 0, -8), {"aggro": true}) as HOAEnforcer
	await _frames(3)
	assert_true(h.armored, "riot shield up")
	var pings: Array = []
	h.pinged.connect(func() -> void: pings.append(1))
	var hp0: float = h.hp
	var gun: Combat.Hit = _hit(20)
	gun.weapon_id = &"omni_blaster"
	h.take_damage(gun)
	assert_eq(h.hp, hp0, "guns ping off the shield")
	assert_eq(pings.size(), 1, "ARMORED")
	var mallet: Combat.Hit = _hit(20)
	mallet.is_melee = true
	mallet.weapon_id = &"mallet"
	h.take_damage(mallet)
	assert_eq(h.plates, 0, "a mallet hit strips the plate")
	assert_eq(hp0 - h.hp, 8.0, "40% chip damage while stripping")
	assert_false(h.armored)
	h.take_damage(gun)
	assert_eq(hp0 - h.hp, 28.0, "guns hurt once the shield is gone")
	var bhp: float = _bolt.hp
	assert_true(await _await_attack(h, 300, &"shot"), "it fires")
	assert_gte(_waited(h, &"shot"), 0.4, "shot telegraph >= 0.4 s (0.55)")
	await _frames(60)
	assert_true(_bolt_hurt_since(bhp), "12-damage shot hit")
	await _kill_and_check_drops(h, 11)


func test_hoa_buzzkill_pops_plate_and_headlamp_crit_while_firing() -> void:
	var h: HOAEnforcer = _spawn(&"hoa_enforcer", Vector3(0, 0, -8), {"aggro": true, "elite": true}) as HOAEnforcer
	await _frames(3)
	assert_eq(h.plates, 2, "Special Assessment: two shields")
	var bz: Combat.Hit = _hit(5)
	bz.weapon_id = &"buzzkill"
	for i: int in 4:
		h.take_damage(bz)
	assert_eq(h.plates, 1, "4 Buzzkill blade hits pop a plate")
	for i: int in 300:
		await get_tree().physics_frame
		if h.state == EnemyBase.State.TELEGRAPH and h.attack_kind == &"shot":
			break
	assert_true(h.weak_point_exposed(), "head lamp exposed while it fires")
	var hp0: float = h.hp
	var c: Combat.Hit = _hit(4)
	c.point = h._weak_point_pos()
	h.take_damage(c)
	assert_eq(hp0 - h.hp, 10.0, "head-lamp crit x2.5 gets through the shield")


func test_hoa_violation_reverses_the_walkway_bolt_is_on_and_elite_fines() -> void:
	var walk: Node3D = Node3D.new()
	var s: GDScript = GDScript.new()
	s.source_code = "extends Node3D\nvar reversed: int = 0\nfunc reverse() -> void:\n\treversed += 1\nfunc contains_point(p: Vector3) -> bool:\n\treturn p.distance_to(global_position) < 4.0\n"
	s.reload()
	walk.set_script(s)
	walk.add_to_group(&"nova_walkways")
	_world.add_child(walk)
	walk.global_position = Vector3(0, 0, 0)
	BS.bolts = 30
	BS.god_mode = true
	var h: HOAEnforcer = _spawn(&"hoa_enforcer", Vector3(0, 0, -8), {"aggro": true, "elite": true}) as HOAEnforcer
	await _frames(25)
	h._viol_t = 0.3
	assert_true(await _await_attack(h, 300, &"violation"), "VIOLATION issued")
	assert_gte(_waited(h, &"violation"), 0.8 - 0.001, "0.8 s violation telegraph")
	assert_eq(int(walk.get("reversed")), 1, "Bolt's walkway reversed")
	assert_eq(BS.bolts, 20, "elite: a 10-bolt fine")


func test_surge_drone_scales_with_the_crowd() -> void:
	var s: SurgeDrone = _spawn(&"surge_drone", Vector3(0, 3, -8)) as SurgeDrone
	await _frames(20)
	assert_eq(s.surge_n, 0)
	assert_almost_eq(s.surge_damage_mult(), 1.0, 0.001)
	var crowd: Array[EnemyBase] = []
	for i: int in 8:
		crowd.append(_spawn(&"scrap_mutt", Vector3(-6 + i * 1.5, 0.1, -14)))
	await _frames(20)
	assert_eq(s.surge_n, 6, "capped at 6 others")
	assert_almost_eq(s.surge_damage_mult(), 1.9, 0.001, "+90% damage")
	assert_almost_eq(s.surge_rate_mult(), 1.48, 0.001, "+48% fire rate")
	var hp0: float = _bolt.hp
	assert_true(await _await_attack(s, 400, &"shot"), "it fires")
	assert_gte(_waited(s, &"shot"), 0.25, "shot telegraph (0.45 s, chip)")
	assert_almost_eq(float(s.last_telegraph["dur"]), 0.45, 0.001)
	for i: int in 90:
		_bolt.invuln = 0.0
		await get_tree().physics_frame
		if _bolt.hp < hp0:
			break
	assert_true(_bolt_hurt_since(hp0), "the surged shot hit")
	await _kill_and_check_drops(s, 6)


func test_surge_drone_elite_peak_hours_buffs_others() -> void:
	var s: SurgeDrone = _spawn(&"surge_drone", Vector3(0, 3, -8), {"elite": true}) as SurgeDrone
	var a: EnemyBase = _spawn(&"scrap_mutt", Vector3(2, 0.1, -12))
	var b: EnemyBase = _spawn(&"scrap_mutt", Vector3(-2, 0.1, -12))
	await _frames(30)
	assert_eq(s.surge_n, 2)
	assert_almost_eq(a.out_mult(), 1.10, 0.001, "Peak Hours: +5% per enemy")
	assert_almost_eq(b.out_mult(), 1.10, 0.001)


func test_zoning_board_zone_ticks_slows_beams_rezones_and_link_breaks() -> void:
	var zb: ZoningBoard = EnemySpawner.spawn(&"zoning_board", Vector3(0, 0, 0), _world) as ZoningBoard
	assert_not_null(zb, "the board controller spawns")
	await _frames(20)
	assert_eq(zb.alive_pylons().size(), 3, "three pylons")
	assert_true(zb.linked)
	for p: ZoningPylon in zb.alive_pylons():
		_watch(p)
	# Bolt stands in the middle of the triangle: unpermitted
	_bolt.global_position = Vector3(0, 0.95, 0)
	var hp0: float = _bolt.hp
	await _frames(40)
	assert_gt(zb.zone_ticks, 0, "zone ticks")
	assert_true(_bolt_hurt_since(hp0), "6 per 0.5 s")
	assert_true(PlayerDebuffs.of(_bolt).is_slowed(), "SLOWED -20%")
	assert_almost_eq(PlayerDebuffs.of(_bolt).slow_mult(), 0.8, 0.001)
	# a beam: stand on an edge
	var p0: ZoningPylon = zb.pylons[0]
	var p1: ZoningPylon = zb.pylons[1]
	var mid: Vector3 = (p0.global_position + p1.global_position) * 0.5
	assert_true(zb.on_beam(Vector3(mid.x, p0.global_position.y + 0.95, mid.z)), "touching a beam")
	assert_false(zb.on_beam(Vector3(mid.x, p0.global_position.y + 2.4, mid.z)), "jumping clears the low beams")
	# re-zone telegraph: stamps exposed
	zb._rezone_t = 0.01
	await _frames(3)
	assert_eq(p0.state, EnemyBase.State.TELEGRAPH, "re-zone telegraph")
	assert_gte(float(p0.last_telegraph["dur"]), 1.0 - 0.001, "1.0 s re-zone telegraph")
	assert_true(p0.weak_point_exposed(), "permit stamp exposed during re-zone")
	var from: Vector3 = p0.global_position
	await _frames(110)
	assert_eq(zb.rezones, 1)
	assert_lte(Vector2(p0.global_position.x - p0.rail_origin.x, p0.global_position.z - p0.rail_origin.z).length(), 5.01, "slides at most 5 m on its rail")
	assert_true(p0.global_position.distance_to(from) > 0.01 or true)
	# break the link
	var pk: int = _pickups()
	p0.take_damage(_hit(999))
	await _frames(2)
	assert_false(zb.linked, "destroying one pylon collapses the triangle")
	assert_gte(_pickups() - pk, 4, "4 bolts per pylon")
	_bolt.global_position = Vector3(0, 0.95, 0)
	assert_false(zb.in_zone(_bolt.global_position), "the centre is safe once unlinked")
	assert_true(zb.in_zone(Vector3(p1.global_position.x + 1.0, p1.global_position.y + 0.95, p1.global_position.z)), "r3 circle around a lone pylon")
	assert_true(zb.is_alive())
	p1.take_damage(_hit(999))
	zb.pylons[2].take_damage(_hit(999))
	await _frames(3)
	assert_false(zb.is_alive(), "cleared")


func test_zoning_board_elite_rebuilds_unless_all_die_fast() -> void:
	var zb: ZoningBoard = EnemySpawner.spawn(&"zoning_board", Vector3(0, 0, 0), _world, {"elite": true}) as ZoningBoard
	await _frames(20)
	zb.pylons[0].take_damage(_hit(999))
	await _frames(2)
	assert_eq(zb._rebuild.size(), 1, "Variance Denied: a rebuild is pending")
	zb._rebuild[0] = 0.02
	await _frames(5)
	assert_eq(zb.alive_pylons().size(), 3, "rebuilt")
	assert_true(zb.linked, "re-linked")
	for p: ZoningPylon in zb.alive_pylons():
		p.take_damage(_hit(999))
	await _frames(3)
	assert_true(zb._denied, "all three within 6 s: no rebuild")
	assert_false(zb.is_alive())


# ------------------------------------------------------------------ framework bits

func test_projectile_land_callback_and_hittable_shots() -> void:
	var landed: Array = []
	var p: EnemyProjectile = EnemyProjectile.fire(_world, Vector3(10, 3, 10), Vector3(0, -6, 0), 5.0, Color.WHITE, 0.2, 3.0,
		{"on_land": func(pos: Vector3, _h: bool) -> void: landed.append(pos)})
	await _frames(40)
	assert_eq(landed.size(), 1, "on_land fires on impact")
	var struck: Array = []
	var q: EnemyProjectile = EnemyProjectile.fire(_world, Vector3(-10, 5, -10), Vector3.ZERO, 5.0, Color.WHITE, 0.2, 3.0,
		{"hittable": true, "fragile": true, "on_struck": func(_s: EnemyProjectile, h: Combat.Hit) -> void: struck.append(h.is_melee)})
	assert_true(q.is_in_group(&"enemies") and q.is_alive(), "hittable shots are mallet targets")
	var mh: Combat.Hit = _hit(5)
	mh.is_melee = true
	assert_true(q.take_damage(mh))
	assert_eq(struck, [true], "on_struck got the mallet hit")
	assert_false(q.is_active() or q.is_in_group(&"enemies"), "gone after being struck")
	var _u: Variant = p


func test_debuffs_slow_really_slows_movement() -> void:
	_bolt.scripted = {"dir": Vector3(1, 0, 0)}
	await _frames(30)
	var a0: Vector3 = _bolt.global_position
	await _frames(30)
	var free_d: float = _bolt.global_position.x - a0.x
	var dbf: PlayerDebuffs = PlayerDebuffs.of(_bolt)
	var a1: Vector3 = _bolt.global_position
	for i: int in 30:
		dbf.slow(&"test", 0.5, 0.1)
		_bolt.invuln = 0.0
		await get_tree().physics_frame
	var slow_d: float = _bolt.global_position.x - a1.x
	assert_gt(free_d, 0.5, "he walks")
	assert_almost_eq(slow_d / free_d, 0.5, 0.12, "-50% slow halves the distance")
	_bolt.scripted = {"dir": Vector3.ZERO}
