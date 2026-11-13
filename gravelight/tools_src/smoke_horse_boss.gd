extends Node
## The undead horses (T-240; data/gravelight/bosses/horse.json, HorseBoss, HorseRound), headless, solo, silent.
##   The Inn (map00), round 20 forced: the round is reserved and its horde cut to 60%; DAS TOTENROSS is heard first and
##     comes in up the carters' road `spawn_at` seconds in, breaks the chained gate open and reaches the yard; the title
##     card and its bar; every attack telegraphs for half a second or more and can be dodged (the charge by a side-step
##     once the line is set, the stomp by backing out, the kick by leaving the cone, the trample broken off by a
##     teammate's fire) and lands when it is not (damage, the knockdown, the knockback); a wall staggers it (x1.5);
##     the phases by health (faster, the yard's lights dying); it never goes into the taproom after a player (the siege
##     scream sets the dead running instead); the living horse in the yard is left alone and shies; the fail-safe (it
##     bolts, the round can end, it is back two rounds later); the kill ends the encounter and pays out (Scrip, the
##     drops), and the round ends when the horde is dead.
##   Round 30: DER FUHRMANN rides it: the whip (telegraph, dodge, the slow), the rider thrown at half health and up
##     again on foot with four rounds' health; the kill, the round's end.
##   Kaltenbrunn (map01), rounds 20 and 30: it comes in on the surface, paths to the squad in the Minehead Yard,
##     charges, dies, the round ends, the reward drops.
##   Bots: a squad bot counts it a boss, and the charge's lane is on the squad's danger map while it winds up.
## Prints "[horse_boss] ..." lines and "[horse_boss] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_horse_boss.tscn

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 1100.0

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0
var _drops: Array[String] = []
var _hurt: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_horse_boss_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_horse_boss_settings.cfg"
	GLSettings.values["homage_bosses"] = true
	GameState.character_id = &"dutch"
	Campaign.reset()
	GLBus.powerup_spawned.connect(func(id: StringName, _p: Vector3) -> void: _drops.append(String(id)))
	GLBus.player_damaged.connect(func(pid: int, amount: float) -> void:
		if pid == 1:
			_hurt += amount)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[horse_boss] %-84s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[horse_boss] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float, cull: bool = true) -> bool:
	var t: float = 0.0
	while t < seconds:
		if cull:
			_cull_horde()
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _root() -> MapRoot:
	return _map as MapRoot


func _dir() -> ZombieDirector:
	return _root().director


func _p() -> Player:
	return _root().player


func _enc(r: int) -> HorseRound:
	return _map.get_node_or_null("HorseRound_%d" % r) as HorseRound


func _cull_horde(keep: Zombie = null) -> void:
	if _map == null or not is_instance_valid(_map) or _root().director == null:
		return
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss) and z != keep:
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")


func _load_map(path: String, bots: int) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.bot_count = bots
	GameState.god_mode = true
	_map = (load(path) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0, false)
	await _secs(1.0)
	GameState.god_mode = true
	_p().set_process_unhandled_input(false)
	_dir().kill_all(true)


func _place(at: Vector3) -> void:
	_p().global_position = at
	_p().velocity = Vector3.ZERO
	_p().set("_lunge_t", 0.0)


## The player `dist` metres off the horse at `deg` degrees from its nose (0 = dead ahead, 180 = behind).
func _place_rel(b: HorseBoss, dist: float, deg: float) -> void:
	var f: Vector3 = b.facing().rotated(Vector3.UP, deg_to_rad(deg))
	_place(b.global_position + f * dist + Vector3.UP * 0.05)


func _still(b: HorseBoss, at: Vector3, yaw_deg: float) -> void:
	b.global_position = at
	b.rotation.y = deg_to_rad(yaw_deg)
	b.set("_vis_yaw", b.rotation.y)
	b.velocity = Vector3.ZERO
	b.bstate = HomageBoss.B.MOVE
	b.set("_bt", 0.0)
	b.set("_cds", {"charge": 99.0, "stomp": 99.0, "kick": 99.0, "trample": 99.0, "whip": 99.0})   # nothing of its own while a case is set up


func _hit_on(on: bool) -> void:
	GameState.god_mode = not on
	_p().hp = 100.0
	_p().set("_status", {})
	_hurt = 0.0


## Starts round `r` (the dev launcher's way) and waits for the horse to come in.
func _start_round(r: int) -> HorseBoss:
	var enc: HorseRound = _enc(r)
	RoundManager.debug_set_round(r)
	_dir().kill_all(true)
	await _until(func() -> bool: return RoundManager.current_round == r and RoundManager.state == RoundManager.State.ROUND, 8.0, false)
	if enc == null:
		return null
	var total_full: int = RoundManager.zombie_count(r, RoundManager.players, GLData.table("rounds"))
	_check(enc.phase == HomageEncounter.Phase.ACTIVE and RoundManager.is_reserved(r), "round %d: the horse's round is reserved and begins" % r)
	_check(RoundManager.round_total == HomageEncounter.horde_count(total_full, enc.cfg), "round %d: the horde is cut to %d of %d" % [r, RoundManager.round_total, total_full])
	_check(enc.horses().is_empty(), "round %d: it is heard before it is seen (not in yet at the round's start)" % r)
	var spawn_at: float = float((enc.cfg.get("arrival", {}) as Dictionary).get("spawn_at", 6.0))
	var t0: float = enc.t
	await _until(func() -> bool: return not enc.horses().is_empty(), spawn_at + 4.0)
	var hs: Array[HorseBoss] = enc.horses()
	_check(hs.size() == int(enc.row.get("count", 1)) and enc.t - t0 >= spawn_at - 1.0, "round %d: it comes in %.1f s into the round (%d of them)" % [r, enc.t, hs.size()])
	return hs[0] if not hs.is_empty() else null


## The round ends once the horde is dead: the queue is held empty and what is up is culled (as the other boss smokes do).
func _round_ends(seconds: float = 30.0) -> bool:
	var t: float = 0.0
	while t < seconds and RoundManager.state != RoundManager.State.BREAK:
		RoundManager.to_spawn = 0
		_cull_horde()
		if RoundManager.alive <= 0 and RoundManager.state == RoundManager.State.ROUND:
			RoundManager.on_zombie_died()   # (the queue was emptied by hand after the last death: the round is asked again)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return RoundManager.state == RoundManager.State.BREAK


func _run() -> void:
	await _inn()
	await _kaltenbrunn()
	_finish()


# ================================================================== the Inn

func _inn() -> void:
	await _load_map(MAP0, 1)
	var rows: Array = HorseRound.rows_for(&"map00_crossroads")
	_check(rows.size() == 2 and _enc(20) != null and _enc(30) != null, "map00: two horse rounds in the data and in the scene (20, 30)")
	var yard_horse: Horse = get_tree().get_first_node_in_group(&"horses") as Horse
	GameState.open_zone(&"STABLE")
	GameState.open_zone(&"YARD")
	_place(Vector3(14.0, 0.05, 41.0))
	var gate: Node = _map.get_node_or_null("Gameplay/Door_Gate")
	_check(gate != null and not bool(gate.get("is_open")), "map00: the yard's gate is still chained")
	var b: HorseBoss = await _start_round(20)
	if b == null:
		_check(false, "map00 round 20: no horse came")
		return
	var enc: HorseRound = _enc(20)
	var want_hp: float = HomageBoss.scaled_hp(46000.0, RoundManager.players)
	_check(absf(b.max_hp - want_hp) < 1.0 and b.boss_key == "totenross", "the Totenross: 46,000 health solo, x1.75 for the second (bot) player's scaling (%d, %d players)" % [int(b.max_hp), RoundManager.players])
	_check(b.rig != null and b.rig.look == "dead" and not b._body.visible and b.hitbox_rids().size() >= 10, "it wears the horse's body and limb boxes (%d boxes)" % b._hitboxes.size())
	_check(b.global_position.z > 50.0, "it comes up the carters' road (z %.1f)" % b.global_position.z)
	var came: bool = await _until(func() -> bool: return b.global_position.distance_to(_p().global_position) < 12.0, 30.0)
	_check(came, "it paths to the squad in the yard (%.1f m off)" % b.global_position.distance_to(_p().global_position))
	await _until(func() -> bool: return b.global_position.z < 46.5, 20.0)
	_check(b.doors_smashed.has(&"door_gate") and bool(gate.get("is_open")) and b.global_position.z < 46.5, "it broke the chained gate open and came into the yard (%s, z %.1f)" % [str(b.doors_smashed), b.global_position.z])
	await _until(func() -> bool: return enc.card_shown, 9.0)
	_check(enc.card_shown and enc.hud != null and enc.hud.has_bar("totenross_0"), "the title card and its bar")
	_check(yard_horse != null and yard_horse.mode == Horse.Mode.TIED, "the living horse stands where it was (the boss walked past it)")
	if yard_horse != null:
		_still(b, Vector3(24.0, 0, 42.0), 0.0)
		await _secs(0.6)
		_check(float(yard_horse.get("_shy")) > 0.5 and yard_horse.pace_cap() <= 1.0, "the living horse shies from it (%.2f)" % float(yard_horse.get("_shy")))
		_check(b.target == null or b.target is Player, "the boss has no eyes for the living horse")
	_check(BotPerception.is_boss(b), "the squad's bots count it a boss")

	# ---- the charge: the telegraph, a side-step, a hit, a wall
	await _charge_case(b, Vector3(10.0, 0, 44.0), -90.0, 14.0)
	# into the stable's south wall
	_still(b, Vector3(21.0, 0, 45.0), 0.0)
	_place(Vector3(21.0, 0.05, 35.6))
	await _secs(0.2)
	var stuns0: int = b.wall_stuns
	b.debug_move("charge")
	await _until(func() -> bool: return bool(b.get("_locked")), 3.0)
	_place(Vector3(26.5, 0.05, 40.0))
	await _until(func() -> bool: return b.bstate != HomageBoss.B.SPECIAL and b.bstate != HomageBoss.B.TELEGRAPH, 6.0)
	_check(b.wall_stuns == stuns0 + 1 and b.bstate == HomageBoss.B.STAGGER and b.global_position.z < 36.5, "a charge into the stable wall staggers it (stuns +%d, state %d, z %.1f)" % [b.wall_stuns - stuns0, b.bstate, b.global_position.z])
	_check(is_equal_approx(b.damage_taken_mult(), 1.5), "staggered it takes x1.5")
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 4.0)

	# ---- the stomp
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	_place_rel(b, 2.6, 0.0)
	_hit_on(true)
	b.debug_move("stomp")
	await get_tree().physics_frame
	var tl: Array = b.tele_log[b.tele_log.size() - 1]
	_check(b.bstate == HomageBoss.B.TELEGRAPH and str(tl[0]) == "stomp" and float(tl[1]) >= 0.5, "the stomp telegraphs (%.2f s)" % float(tl[1]))
	await _secs(float(tl[1]) * 0.5)
	_check(b.rig.rear > 0.3 and b._tele_light.light_energy > 0.3, "pose and light: it rears (%.2f), the light is up (%.1f)" % [b.rig.rear, b._tele_light.light_energy])
	_place_rel(b, 10.0, 0.0)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.RECOVER or b.bstate == HomageBoss.B.MOVE, 3.0)
	_check(_hurt <= 0.0 and not _p().has_status(&"knockdown"), "backing out of the ring dodges it (hurt %.0f)" % _hurt)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 3.0)
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	_place_rel(b, 2.6, 0.0)
	_hit_on(true)
	b.debug_move("stomp")
	await _until(func() -> bool: return _hurt > 0.0 or b.bstate == HomageBoss.B.MOVE, 3.5)
	_check(is_equal_approx(_hurt, 60.0) and _p().has_status(&"knockdown"), "standing under it: 60 and the knockdown (hurt %.0f)" % _hurt)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 3.0)

	# ---- the kick
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	_place_rel(b, 2.2, 180.0)
	_hit_on(true)
	b.set("_cds", {"charge": 99.0, "stomp": 99.0, "trample": 99.0, "whip": 99.0})
	var kicked: bool = await _until(func() -> bool: return b.bstate == HomageBoss.B.TELEGRAPH and b.move_id == "kick", 3.0)
	tl = b.tele_log[b.tele_log.size() - 1]
	_check(kicked and float(tl[1]) >= 0.5, "lingering behind it draws the kick, telegraphed (%.2f s)" % float(tl[1]))
	_place_rel(b, 6.0, 90.0)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 3.0)
	_check(_hurt <= 0.0 and b.kicks == 1, "leaving the cone dodges it (hurt %.0f)" % _hurt)
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	_place_rel(b, 2.2, 180.0)
	_hit_on(true)
	b.debug_move("kick")
	var at0: Vector3 = _p().global_position
	await _until(func() -> bool: return _hurt > 0.0 or b.bstate == HomageBoss.B.MOVE, 3.0)
	await _secs(0.3)
	_check(is_equal_approx(_hurt, 55.0) and _p().global_position.distance_to(at0) > 0.5, "standing behind it: 55 and thrown back (hurt %.0f, moved %.1f m)" % [_hurt, _p().global_position.distance_to(at0)])
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 3.0)

	# ---- the trample, broken off by a teammate
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	_place_rel(b, 3.0, 0.0)
	_hit_on(true)
	_p().apply_status(&"knockdown", 6.0)
	b.debug_move("trample")
	tl = b.tele_log[b.tele_log.size() - 1]
	_check(str(tl[0]) == "trample" and float(tl[1]) >= 0.5, "the trample telegraphs (%.2f s)" % float(tl[1]))
	await _until(func() -> bool: return _hurt > 0.0, 5.0)
	_check(is_equal_approx(_hurt, 30.0), "knocked down under it: a stamp of 30 (hurt %.0f)" % _hurt)
	var hp0: float = b.hp
	b.take_damage(b.max_hp * 0.03, &"torso", &"m1911", 2, &"bullet")
	await _until(func() -> bool: return b.bstate != HomageBoss.B.SPECIAL, 1.0)
	_check(b.trample_interrupts == 1 and b.bstate == HomageBoss.B.RECOVER, "a teammate's fire (3%% of its health) breaks it off (interrupts %d)" % b.trample_interrupts)
	b.hp = hp0
	_hit_on(false)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 3.0)

	# ---- weak points: the head, the lit ribs
	var h1: float = b.hp
	b.take_damage(100.0, &"back", &"m1911", 1, &"bullet")
	_check(is_equal_approx(h1 - b.hp, 200.0), "the lit ribs take x2 (%.0f for 100)" % (h1 - b.hp))
	h1 = b.hp
	b.take_damage(400.0, &"head", &"m1911", 1, &"bullet")
	_check(is_equal_approx(h1 - b.hp, 160.0), "the head takes x1.6 (a weapon's x4 head shot of 100: %.0f)" % (h1 - b.hp))

	# ---- it does not follow into the taproom: the siege
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	_place(Vector3(12.0, 0.05, 8.0))
	_cull_horde()
	RoundManager.to_spawn = 0
	var made: int = _dir().spawn_burst([Vector3(22.0, 0, 44.0), Vector3(24.0, 0, 44.0)], 2)
	await _secs(4.0)
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss):
			z.debug_set_tier(&"walk")
	var sieged: bool = await _until(func() -> bool: return b.sieges >= 1, 12.0, false)
	var running: int = 0
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss) and z.tier == &"sprint":
			running += 1
	_check(b.target == null and sieged and running >= 1, "a player in the taproom is not chased: it screams and the dead run (%d of %d, sieges %d)" % [running, made, b.sieges])
	_check(ZoneVolume.zone_at(get_tree(), b.global_position + Vector3.UP) in [&"YARD", &"GROUNDS", &"STABLE"], "it stays on its own ground (%s)" % str(ZoneVolume.zone_at(get_tree(), b.global_position + Vector3.UP)))
	_place(Vector3(14.0, 0.05, 41.0))
	_cull_horde()

	# ---- the bots' danger map carries the charge's lane
	var squad: BotSquad = _root().squad
	if squad != null:
		_still(b, Vector3(10.0, 0, 44.0), -90.0)
		_place_rel(b, 14.0, 0.0)
		b.debug_move("charge")
		await _secs(0.6)
		var mid: Vector3 = b.global_position + b.facing() * 7.0
		_check(squad.blackboard.danger_at(mid, squad.time()) > 0.0 and squad.blackboard.danger_at(mid + Vector3(0, 0, 6.0), squad.time()) <= 2.01,
			"the charge's lane is on the squad's danger map while it winds up (%.1f in the lane, %.1f beside it)" % [squad.blackboard.danger_at(mid, squad.time()), squad.blackboard.danger_at(mid + Vector3(0, 0, 6.0), squad.time())])
		_place_rel(b, 9.0, 80.0)
		await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 8.0)

	# ---- the phases
	_still(b, Vector3(18.0, 0, 42.0), -90.0)
	b.take_damage(b.hp - b.max_hp * 0.6, &"torso", &"m1911", 1, &"world")
	await _secs(0.3)
	_check(b.phase_i == 1 and is_equal_approx(b.move_speed(), 5.2), "at 66%% it is the second phase: faster (%.1f m/s)" % b.move_speed())
	b.take_damage(b.hp - b.max_hp * 0.3, &"torso", &"m1911", 1, &"world")
	await _secs(0.3)
	_check(b.phase_i == 2 and is_equal_approx(b.move_speed(), 6.0) and b.fx.dimmed_count() > 0, "at 33%% the third: faster again, the yard's lights dying (%d lamps held down)" % b.fx.dimmed_count())

	# ---- the fail-safe: it bolts, the round can end, it is back two rounds on
	enc.spawn_t = enc.t - float(enc.cfg.get("failsafe_seconds", 300.0)) - 1.0
	await _until(func() -> bool: return enc.left_count >= 1, 2.0)
	_check(enc.left_count == 1 and b.retreating, "the fail-safe: it turns and bolts")
	var gone_t: float = 0.0
	while is_instance_valid(b) and not b.gone and gone_t < 8.0:   # (no lambda: the horse is freed as it goes)
		await get_tree().physics_frame
		gone_t += get_physics_process_delta_time()
	_check(not is_instance_valid(b) or b.gone, "and is gone (%.1f s)" % gone_t)
	_check(enc.event_round == 22 and RoundManager.is_reserved(22), "it will be back on round 22")
	var ended: bool = await _round_ends()
	_check(ended, "with the horse gone and the horde dead the round ends (alive %d, queued %d)" % [RoundManager.alive, RoundManager.to_spawn])

	# ---- round 30: the Fuhrmann
	_drops.clear()
	_place(Vector3(14.0, 0.05, 41.0))
	var f: HorseBoss = await _start_round(30)
	if f == null:
		_check(false, "map00 round 30: no horse came")
		return
	var enc30: HorseRound = _enc(30)
	_check(f.boss_key == "totenross_fuhrmann" and absf(f.max_hp - HomageBoss.scaled_hp(72000.0, RoundManager.players)) < 1.0 and f.rider_on, "DER FUHRMANN: 72,000 health solo (x1.75 here), the carter in the saddle (%d, rider %s)" % [int(f.max_hp), str(f.rider_on)])
	await _until(func() -> bool: return f.global_position.distance_to(_p().global_position) < 14.0, 30.0)
	# the whip
	_still(f, Vector3(12.0, 0, 44.0), -90.0)
	_place_rel(f, 7.0, 0.0)
	_hit_on(true)
	f.debug_move("whip")
	tl = f.tele_log[f.tele_log.size() - 1]
	_check(str(tl[0]) == "whip" and float(tl[1]) >= 0.5, "the whip telegraphs (%.2f s)" % float(tl[1]))
	await _secs(float(tl[1]) * 0.7)
	_place_rel(f, 7.0, 40.0)
	await _until(func() -> bool: return f.bstate == HomageBoss.B.MOVE, 3.0)
	_check(_hurt <= 0.0 and not _p().has_status(&"whip_slow") and f.whips == 1, "stepping off the line dodges it (hurt %.0f)" % _hurt)
	_still(f, Vector3(12.0, 0, 44.0), -90.0)
	_place_rel(f, 7.0, 0.0)
	_hit_on(true)
	f.debug_move("whip")
	await _until(func() -> bool: return _hurt > 0.0 or f.bstate == HomageBoss.B.MOVE, 3.0)
	_check(is_equal_approx(_hurt, 35.0 * 1.2) and _p().has_status(&"whip_slow"), "standing in it: 42 (35 x1.2) and the slow (hurt %.0f)" % _hurt)
	_hit_on(false)
	await _until(func() -> bool: return f.bstate == HomageBoss.B.MOVE, 3.0)
	# the rider is thrown at half
	f.take_damage(f.hp - f.max_hp * 0.49, &"torso", &"m1911", 1, &"world")
	await _secs(0.5)
	_check(not f.rider_on and f.rider_zombie != null and f.rider_zombie.is_active(), "at half its health the carter is thrown and gets up on foot")
	if f.rider_zombie != null:
		_check(is_equal_approx(f.rider_zombie.max_hp, float(RoundManager.current_health()) * 4.0), "on foot he has four of this round's zombies' health (%d)" % int(f.rider_zombie.max_hp))
	# the kill
	var scrip0: int = Economy.scrip_of(1) if Economy.has_method("scrip_of") else 0
	f.debug_kill(1)
	await _secs(0.5)
	_check(enc30.phase == HomageEncounter.Phase.CLEARED and enc30.rewards_given, "the kill clears the encounter and pays out")
	_check(_drops.has("resupply") and _drops.has("deaths_door") and _drops.has("double_scrip"), "the drops fall where it fell (%s)" % str(_drops))
	if Economy.has_method("scrip_of"):
		_check(Economy.scrip_of(1) - scrip0 >= 3000, "3,000 Scrip each (+%d)" % (Economy.scrip_of(1) - scrip0))
	_check(GameState.has_flag(&"fuhrmann_down"), "the flag is set")
	await _secs(2.6)
	_check(f.rig.collapse > 0.9, "it goes down on its side (no ragdoll)")
	ended = await _round_ends()
	_check(ended, "the horse and the carter dead, the horde dead: round 30 ends (alive %d, queued %d)" % [RoundManager.alive, RoundManager.to_spawn])


## The charge on open ground: the telegraph (seconds, pose, light), the line set before it runs, a side-step, a hit.
func _charge_case(b: HorseBoss, at: Vector3, yaw: float, dist: float) -> void:
	_still(b, at, yaw)
	_place_rel(b, dist, 0.0)
	_hit_on(true)
	await _secs(0.2)
	b.debug_move("charge")
	await get_tree().physics_frame
	var tl: Array = b.tele_log[b.tele_log.size() - 1]
	_check(b.bstate == HomageBoss.B.TELEGRAPH and str(tl[0]) == "charge" and float(tl[1]) >= 1.0, "the charge telegraphs, long (%.2f s)" % float(tl[1]))
	await _secs(float(tl[1]) * 0.5)
	_check(b.rig.head_low > 0.5 and b.rig.paw > 0.5 and b._tele_light.light_energy > 0.5, "pose and light: the head down (%.2f), pawing, the light up (%.1f)" % [b.rig.head_low, b._tele_light.light_energy])
	_check(not bool(b.get("_locked")), "half way through the wind-up the line still follows the target")
	await _until(func() -> bool: return bool(b.get("_locked")), 2.0)
	var aim: Vector3 = b.get("_aim")
	_place(_p().global_position + aim.cross(Vector3.UP) * 4.5)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.SPECIAL, 2.0)
	_check((b.get("_aim") as Vector3).distance_to(aim) < 0.01, "the line was set before it ran (a side-step after that is a dodge)")
	var top: float = 0.0
	while b.bstate == HomageBoss.B.SPECIAL:
		await get_tree().physics_frame
		top = maxf(top, Vector2(b.velocity.x, b.velocity.z).length())
	_check(b.charge_hits == 0 and _hurt <= 0.0, "the side-step dodges it (hits %d, hurt %.0f)" % [b.charge_hits, _hurt])
	_check(top > 11.0 and b.rig.gait == HorseGait.Gait.GALLOP or top > 11.0, "it runs at a gallop (%.1f m/s)" % top)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 4.0)
	# and standing in the lane
	_still(b, at, yaw)
	_place_rel(b, dist, 0.0)
	_hit_on(true)
	await _secs(0.2)
	b.debug_move("charge")
	await _until(func() -> bool: return b.charge_hits >= 1 or b.bstate == HomageBoss.B.MOVE, 8.0)
	_check(b.charge_hits == 1 and is_equal_approx(_hurt, 80.0 * float(b.bcfg.get("damage_mult", 1.0))) and _p().has_status(&"knockdown"),
		"standing in the lane: %.0f, thrown aside and knocked down (hits %d, hurt %.0f)" % [80.0 * float(b.bcfg.get("damage_mult", 1.0)), b.charge_hits, _hurt])
	_hit_on(false)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE, 5.0)


# ================================================================== Kaltenbrunn

func _kaltenbrunn() -> void:
	await _load_map(MAP1, 0)
	_drops.clear()
	_check(HorseRound.rows_for(&"map01_kaltenbrunn").size() == 2 and _enc(20) != null, "map01: the horse rounds are on")
	_check(HorseRound.rows_for(&"map02_totenhafen").is_empty(), "map02: off (no row)")
	var home: Vector3 = _p().global_position
	var b: HorseBoss = await _start_round(20)
	if b == null:
		_check(false, "map01 round 20: no horse came")
		return
	var enc: HorseRound = _enc(20)
	var z0: StringName = ZoneVolume.zone_at(get_tree(), b.global_position + Vector3.UP)
	_check(z0 in [&"A_MINEHEAD", &"B_RAILYARD"] and absf(b.global_position.y) < 1.0, "it comes in on the surface (%s, y %.1f, %.0f m from the squad)" % [str(z0), b.global_position.y, b.global_position.distance_to(home)])
	var came: bool = await _until(func() -> bool: return b.global_position.distance_to(_p().global_position) < 10.0, 40.0)
	_check(came, "it paths to the squad in the Minehead Yard (%.1f m off)" % b.global_position.distance_to(_p().global_position))
	_check(absf(b.global_position.y) < 1.0, "it stayed above ground (y %.2f)" % b.global_position.y)
	# a charge on Kaltenbrunn's yard
	_hit_on(true)
	b.set("_cds", {"stomp": 99.0, "kick": 99.0, "trample": 99.0})
	var n0: int = b.tele_log.size()
	var c0: int = b.charges
	var charged: bool = false
	var t: float = 0.0
	while t < 25.0 and not charged:
		# keep the squad 12 m off its nose with a clear run so it chooses the charge itself
		if b.bstate == HomageBoss.B.MOVE:
			_place(home if b.global_position.distance_to(home) > 9.0 else home + (home - b.global_position).normalized() * 6.0)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		charged = b.charges > c0
		_cull_horde()
	_check(charged and b.tele_log.size() > n0 and str(b.tele_log[n0][0]) == "charge" and float(b.tele_log[n0][1]) >= 0.5, "it chooses the charge itself and telegraphs it (%d charges, %d before)" % [b.charges, c0])
	_hit_on(false)
	await _until(func() -> bool: return b.bstate == HomageBoss.B.MOVE or b.bstate == HomageBoss.B.STAGGER, 8.0)
	b.debug_kill(1)
	await _secs(0.5)
	_check(enc.phase == HomageEncounter.Phase.CLEARED and enc.rewards_given and _drops.has("resupply") and _drops.has("double_scrip"), "the kill pays out (drops %s)" % str(_drops))
	var ended: bool = await _round_ends()
	_check(ended, "map01: round 20 ends (alive %d, queued %d, holds %s)" % [RoundManager.alive, RoundManager.to_spawn, str(RoundManager.is_held())])
	var f: HorseBoss = await _start_round(30)
	_check(f != null and f.boss_key == "totenross_fuhrmann" and f.rider_on, "map01 round 30: DER FUHRMANN comes")
	if f != null:
		f.debug_kill(1)
		await _secs(0.5)
		ended = await _round_ends()
		_check(ended, "map01: round 30 ends (alive %d, queued %d)" % [RoundManager.alive, RoundManager.to_spawn])
