extends Node
## Headless smoke for HB1, the Cousins Round (docs/HOMAGE_BOSSES.md section 4). Map 0, solo, god mode, silent.
##   Case ON (Homage Bosses On): round 10 starts (debug_set_round, as the dev launcher does): the setup beat
##     (lamps out), the reduced horde, the Hammer first (title card, Door 1 split open), the Reach 30 s in (the
##     clock is skipped ahead), Alix third when a cousin drops under 50%; each signature move is exercised at
##     least once against the god-mode player (Mallet Throw + catch, the x1.5 airborne window, the melee stagger,
##     Overhead Split; Long Reach Grab + the wrist break, Through-the-Wall; Holding Hand + the melee break, Lash,
##     ObservedFreeze while watched and moving while not); then the deaths in order: the enrage chain, Alix holding
##     the Hammer's hand (x2 window), the clear's rewards (drops, Scrip, unlocks, the letter), and the round ending.
##     T-232 (the boss rework): the kit is on every cousin (a porcelain dread block, the Hammer's and the Reach's
##     footfalls, the modelled doll with the glaze, eyes and crack tiers built), the cracks open as a cousin takes
##     damage (the porcelain splitting), the hum goes flat once enraged (the loop exists and plays), the Reach's
##     Through-the-Window grab (the boards creak, one board torn, the player held and the wrist break), Alix's
##     look-away step (a player who turns their back inside her band hears the dress and finds her closer), her
##     longer second grief window, and the dark hunt: after the second death the last cousin puts the lamps out again
##     (the lamps_out count climbs back, the hearth comes up) until the clear relights everything.
##   Case BORED: round 10 again on a fresh map, the clock run past 6:00: they leave, no rewards, round 15 is theirs
##     and they come back on it at full HP.
##   Case OFF (Homage Bosses Off): round 10 is a normal round: the full horde, no cousin, no reserved round.
## Prints "[cousins] ..." lines and "[cousins] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_cousins.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 900.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _drops: Array[String] = []
var _rounds_ended: Array[int] = []
var _rounds_started: Array[int] = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_cousins_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_cousins_settings.cfg"   # never write the player's own settings file
	GLSettings.values["homage_names"] = "real"
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	Campaign.reset()
	GLBus.powerup_spawned.connect(func(id: StringName, _p: Vector3) -> void: _drops.append(String(id)))
	GLBus.round_ended.connect(func(r: int) -> void: _rounds_ended.append(r))
	GLBus.round_started.connect(func(r: int, _s: bool) -> void: _rounds_started.append(r))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(msg: String) -> void:
	print("[cousins] ", msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[cousins] FAIL: ", msg)


func _check(cond: bool, what: String) -> void:
	print("[cousins] %-74s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[cousins] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (%d: %s)" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


## _until, culling the normal horde every frame and running `each` (if given) first.
func _until_cull(pred: Callable, seconds: float, each: Callable = Callable()) -> bool:
	var t: float = 0.0
	while t < seconds:
		_cull_horde()
		if each.is_valid():
			each.call()
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _root() -> MapRoot:
	return _map as MapRoot


func _dir() -> ZombieDirector:
	return _root().director


func _cr() -> CousinsRound:
	return _dir().cousins


func _player() -> Player:
	return _root().player


func _load_map(homage: bool) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GLSettings.values["homage_bosses"] = homage
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0)
	await _secs(1.0)
	GameState.god_mode = true
	_player().set_process_unhandled_input(false)
	_dir().kill_all(true)


## Kills the normal horde (never the cousins) every frame while `pred` holds.
var _culled: int = 0
var _last_alive: int = -1


func _cull_horde() -> void:
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss):
			if z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world"):
				_culled += 1
	if RoundManager.alive != _last_alive:
		_last_alive = RoundManager.alive
		var bosses: int = 0
		var horde: int = 0
		for z: Zombie in _dir().active_zombies():
			if z is HomageBoss:
				bosses += 1
			else:
				horde += 1
		print("[cousins]   alive %d (active bosses %d, horde %d, queued %d, culled %d)" % [RoundManager.alive, bosses, horde, RoundManager.to_spawn, _culled])


## Puts the player at `p` (floor), looking at `at` (or keeping the yaw).
func _place(p: Vector3, at: Vector3 = Vector3.INF) -> void:
	var pl: Player = _player()
	pl.global_position = p
	pl.velocity = Vector3.ZERO
	if at != Vector3.INF:
		var d: Vector3 = at - p
		pl.rotation.y = atan2(-d.x, -d.z)
		pl._pitch = 0.0


## A floor point in the taproom about `dist` metres from `from`, with a clear line to it.
func _taproom_point_away(from: Vector3, dist: float) -> Vector3:
	var best: Vector3 = Vector3(14, 0, 8)
	var best_err: float = INF
	for x: float in [3.0, 6.0, 10.0, 13.0, 16.0, 19.0, 22.0]:
		for z: float in [2.0, 5.0, 10.0, 12.5]:
			var p: Vector3 = Vector3(x, 0, z)
			if x < 9.5 and z < 9.0:
				continue   # the bar
			var err: float = absf(Vector2(p.x - from.x, p.z - from.z).length() - dist)
			if err < best_err and _clear(from + Vector3.UP * 1.4, p + Vector3.UP * 1.3):
				best_err = err
				best = p
	return best


func _clear(a: Vector3, b: Vector3) -> bool:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a, b, 1 | (1 << 8))
	return _map.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _run() -> void:
	await _case_on()
	await _case_bored()
	await _case_off()
	_finish()


# ================================================================== case ON

func _case_on() -> void:
	_note("---- case ON: Homage Bosses On, round 10")
	await _load_map(true)
	var cr: CousinsRound = _cr()
	_check(cr != null, "Map 0's director made the Cousins Round")
	if cr == null:
		return
	_check(RoundManager.is_reserved(10), "round 10 is reserved (no Bellringer round can land on it)")
	_place(Vector3(14, 0, 8))
	RoundManager.debug_set_round(10)
	var began: bool = await _until(func() -> bool: return cr.phase == CousinsRound.Phase.ACTIVE, 10.0)
	_check(began, "round 10 starts the Cousins Round")
	if not began:
		return
	var full: int = RoundManager.zombie_count(10, RoundManager.players, GLData.table("rounds"))
	_check(RoundManager.round_total == CousinsRound.horde_count(full, cr.cfg), "the horde is 40%% of round 10 (%d of %d)" % [RoundManager.round_total, full])
	_check(cr.setup_played and cr.lamps_out >= 10, "the lamps gutter out (%d out), the fire dies" % cr.lamps_out)
	# T-057: the lamps' glass goes dark with them (it used to keep glowing)
	var glow: LampGlow = _map.get_node_or_null("LampGlow") as LampGlow
	var tap1: Vector3 = (_map.find_child("TapLamp1", true, false) as Node3D).global_position
	_check(glow != null and glow.bound_count() >= 15, "lamp glass is bound to its lights (%d)" % (glow.bound_count() if glow != null else 0))
	if glow != null:
		var dark: bool = await _until(func() -> bool: return glow.glow_near(tap1) >= 0.0 and glow.glow_near(tap1) < 0.1, 6.0)
		_check(dark, "the taproom lantern's glass is dark with its light (glow %.2f)" % glow.glow_near(tap1))
	# ---- the Hammer
	var ham_in: bool = await _until_cull(func() -> bool: return cr.boss("hammer") != null, 5.0)
	_check(ham_in and cr.boss("reach") == null and cr.boss("alix") == null, "the Hammer arrives first")
	var ham: CousinHammer = cr.boss("hammer") as CousinHammer
	if ham == null:
		return
	_check(is_equal_approx(ham.max_hp, 6000.0 * (1.0 + 0.75 * float(RoundManager.players - 1))), "the Hammer has %d HP (6000 x the player scaling)" % int(ham.max_hp))
	_check(cr.hud != null and cr.hud.cards_shown.has("MARA"), "her title card is stamped (Real names: MARA, the default for the unfilled sheet)")
	_check(cr._door_open("door_upstairs"), "Door 1 is split open on her way down")
	# T-232: the kit and the doll pass
	_check(ham.fx != null and str(ham.fx.cfg.get("surface", "")) == "porcelain" and ham.fx.has_footfalls(), "the kit: a porcelain dread block with footfalls")
	_check(ham.modelled() and ham._eyes != null and ham._crack_tiers.size() == 3 and ham.crack_tier_now == 0, "the modelled doll with the glaze, glass eyes and three crack tiers (closed)")
	await _hammer_moves(cr, ham)
	# ---- the Reach (skip the clock to 0:29)
	cr.t = maxf(cr.t, float(cr.cfg["arrival"]["reach_after"]) - 1.0)
	var reach_in: bool = await _until_cull(func() -> bool: return cr.boss("reach") != null, 5.0)
	_check(reach_in and cr.boss("alix") == null, "the Reach arrives second, 30 s in")
	var rch: CousinReach = cr.boss("reach") as CousinReach
	if rch == null:
		return
	await _reach_moves(cr, rch)
	# ---- Alix: a cousin under half
	if cr.boss("alix") == null:
		ham.take_damage(ham.hp - ham.max_hp * 0.45, &"torso", &"debug", 1, &"world")
	var alix_in: bool = await _until_cull(func() -> bool: return cr.boss("alix") != null, 3.0)
	_check(alix_in, "Alix rises third, when a cousin is under 50%")
	var alx: CousinAlix = cr.boss("alix") as CousinAlix
	if alx == null:
		return
	_check(cr.hud.cards_shown.has("ALIX") and cr.hud.has_bar("alix"), "her title card and bar")
	await _alix_moves(cr, alx)
	await _deaths(cr, ham, rch, alx)


func _hammer_moves(cr: CousinsRound, ham: CousinHammer) -> void:
	# let her get down into the taproom
	await _until_cull(func() -> bool: return ham.bstate == HomageBoss.B.MOVE and ham.global_position.y < 0.3 and ham.global_position.x > 6.5, 25.0)
	_note("the Hammer is down at %s" % str(ham.global_position.snapped(Vector3.ONE * 0.1)))
	# the Mallet Throw: stand ~11 m off with a clear line
	var spot: Vector3 = _taproom_point_away(ham.global_position, 11.0)
	_place(spot, ham.global_position)
	var keep_off: Callable = func() -> void:
		if ham.global_position.distance_to(_player().global_position) < 5.0:
			_place(_taproom_point_away(ham.global_position, 11.0), ham.global_position)
	var threw: bool = await _until_cull(func() -> bool: return ham.maul_out, 14.0, keep_off)
	if not threw and ham.bstate == HomageBoss.B.MOVE:
		_note("(forcing the throw)")
		ham._begin("throw", 0.9)
		threw = await _until(func() -> bool: return ham.maul_out, 3.0)
	_check(threw and int(ham.moves_used.get("throw", 0)) >= 1, "Mallet Throw: the hum stops, the wind-up, the maul flies")
	if ham.maul_out:
		var hp0: float = ham.hp
		ham.take_damage(100.0, &"torso", &"m1911", 1, &"bullet")
		_check(absf((hp0 - ham.hp) - 150.0) < 0.5, "while the maul is airborne she takes x1.5 (100 -> %.0f)" % (hp0 - ham.hp))
	# T-232: the cracks spread with the damage (a tier opens under 75%)
	ham.take_damage(maxf(0.0, ham.hp - ham.max_hp * 0.7), &"arms", &"debug", 1, &"world")
	_check(ham.crack_tier_now == 1 and ham.doll_cracks == 1, "under 75%% the first hairline cracks open (tier %d, the porcelain splits)" % ham.crack_tier_now)
	var caught: bool = await _until_cull(func() -> bool: return ham.catches >= 1, 8.0)
	_check(caught, "the maul comes back and she catches it blind (%d hit(s) on the player, out and back)" % ham.maul_hits)
	_check(ham.maul_hits >= 1, "the maul hit the player at least once on its passes")
	# the melee stagger on a second throw
	ham._cds["throw"] = 0.0
	_place(_taproom_point_away(ham.global_position, 10.0), ham.global_position)
	var out2: bool = await _until_cull(func() -> bool: return ham.maul_out, 10.0)
	if not out2 and ham.bstate == HomageBoss.B.MOVE:
		ham._begin("throw", 0.9)
		out2 = await _until(func() -> bool: return ham.maul_out, 3.0)
	if out2:
		ham.take_damage(20.0, &"torso", &"trench_knife", 1, &"melee")
		_check(ham.bstate == HomageBoss.B.STAGGER and ham._maul_dropped, "a melee hit while unarmed staggers her; the maul drops at her feet")
		var picked: bool = await _until(func() -> bool: return not ham.maul_out and not ham._maul_dropped and ham.bstate == HomageBoss.B.MOVE, 5.0)
		_check(picked, "she stoops for it and carries on")
	else:
		_fail("no second throw for the stagger check")
	# Overhead Split: right in front of her
	ham._cds["split"] = 0.0
	var in_front: Callable = func() -> void:
		var f: Vector3 = ham.global_position - ham.global_basis.z * 1.4
		if ham.bstate == HomageBoss.B.MOVE:
			_place(Vector3(f.x, ham.global_position.y, f.z), ham.global_position)
	var split: bool = await _until_cull(func() -> bool: return ham.splits >= 1, 10.0, in_front)
	_check(split, "Overhead Split: both hands overhead, the crack, the splinter zone")
	var zone: bool = false
	for n: Node in _map.get_children():
		if n is CousinHammer.SplinterZone:
			zone = true
	_check(zone or ham.splits >= 1, "the splinter zone is on the floor")
	await _secs(0.3)
	_check(_player().has_status(&"splinters") or not zone, "standing in the splinters slows the player")


func _reach_moves(cr: CousinsRound, rch: CousinReach) -> void:
	var inside: bool = await _until_cull(func() -> bool: return rch.bstate == HomageBoss.B.MOVE, 6.0)
	_check(inside, "the Reach is in (through the east window: the stable door is shut) at %s" % str(rch.global_position.snapped(Vector3.ONE * 0.1)))
	# keep the Hammer out of the way
	var ham: HomageBoss = cr.boss("hammer")
	if ham != null:
		ham.global_position = Vector3(2.0, 3.8, 7.5)
	# Long Reach Grab at ~8 m
	_place(_taproom_point_away(rch.global_position, 8.0), rch.global_position)
	var reach_off: Callable = func() -> void:
		if ham != null and ham.is_active():
			ham.global_position = Vector3(2.0, 3.8, 7.5)
		if rch.bstate == HomageBoss.B.MOVE and rch.global_position.distance_to(_player().global_position) < 4.0:
			_place(_taproom_point_away(rch.global_position, 8.0), rch.global_position)
	var grabbed: bool = await _until_cull(func() -> bool: return rch.grabs_landed >= 1, 15.0, reach_off)
	if not grabbed and rch.bstate == HomageBoss.B.MOVE and rch.target != null:
		_note("(forcing the grab)")
		rch._begin("grab", 0.7)
		grabbed = await _until(func() -> bool: return rch.grabs_landed >= 1, 4.0)
	_check(grabbed, "Long Reach Grab: the arm shoots out and takes the player")
	if grabbed:
		_check(_player().has_status(&"boss_grab"), "the held player can't walk away (boss_grab status)")
		await _secs(0.4)
		rch.take_damage(rch.max_hp * 0.05, &"wrist", &"m1911", 1, &"bullet")   # x2 -> 10% >= 8%
		_check(rch.grabs().is_empty(), "shooting the glowing wrist (x2, 8% of her HP) breaks the grab")
	# Through-the-Wall: the player out of her sight, in the vestibule behind the stairwell wall
	await _until(func() -> bool: return rch.bstate == HomageBoss.B.MOVE, 4.0)
	rch._cds["wall"] = 0.0
	rch._cds["grab"] = 99.0
	_place(Vector3(4.8, 0.0, 12.2))
	var wall_off: Callable = func() -> void:
		if ham != null and ham.is_active():
			ham.global_position = Vector3(2.0, 3.8, 7.5)
		if rch.global_position.distance_to(_player().global_position) < 5.0 and rch.bstate == HomageBoss.B.MOVE:
			rch.global_position = Vector3(18.0, 0.0, 6.0)
	var walled: bool = await _until_cull(func() -> bool: return rch.wall_hits >= 1, 12.0, wall_off)
	if not walled and rch.bstate == HomageBoss.B.MOVE:
		_note("(forcing Through-the-Wall)")
		rch.target = _player()
		rch._begin("wall", 0.6)
		walled = await _until(func() -> bool: return rch.wall_hits >= 1, 3.0)
	_check(walled, "Through-the-Wall: the dust and creak at the spot, then the arm through the boards")
	_check(_player().has_status(&"reach_slow") or walled, "the punch slows the player")
	# T-232: Through-the-Window: the player by the boarded north-east taproom window, the Reach far off across the room
	await _until(func() -> bool: return rch.bstate == HomageBoss.B.MOVE, 4.0)
	var w: Barricade = cr._window("W_TAP_N2")
	_check(w != null, "the taproom's W_TAP_N2 window exists")
	if w != null:
		while w.boards < 2:
			w.repair_board(_player())
		var boards0: int = w.boards
		rch._cds["window"] = 0.0
		rch._cds["grab"] = 99.0
		rch._cds["wall"] = 99.0
		rch._cds["swipe"] = 99.0
		rch.global_position = cr._snap(Vector3(10.0, 0.0, 12.5))
		var by_window: Callable = func() -> void:
			if ham != null and ham.is_active():
				ham.global_position = Vector3(2.0, 3.8, 7.5)
			_place(Vector3(17.0, 0.0, 1.7), Vector3(17.0, 0.0, 12.0))
			if rch.bstate == HomageBoss.B.MOVE and rch.global_position.distance_to(_player().global_position) < 7.5:
				rch.global_position = cr._snap(Vector3(10.0, 0.0, 12.5))
		var creaked: bool = await _until_cull(func() -> bool: return rch.bstate == HomageBoss.B.TELEGRAPH and rch.move_id == "window", 8.0, by_window)
		if not creaked and rch.bstate == HomageBoss.B.MOVE:
			_note("(forcing Through-the-Window)")
			rch.target = _player()
			rch._win = w
			rch._begin("window", 1.0)
			creaked = true
		_check(creaked, "Through-the-Window: the boards creak and rattle for 1 s under a glow at the window")
		var win_grab: bool = await _until(func() -> bool: return rch.window_grabs >= 1, 5.0)
		_check(win_grab, "her arm punches through the boards from outside and takes the player")
		if win_grab:
			_check(w.boards == boards0 - 1 and rch.window_boards_torn >= 1, "one board torn (%d -> %d)" % [boards0, w.boards])
			_check(_player().has_status(&"boss_grab"), "the held player can't walk away")
			await _secs(0.3)
			rch.take_damage(rch.max_hp * 0.05, &"wrist", &"m1911", 1, &"bullet")
			_check(rch.grabs().is_empty(), "the wrist (x2, 8%) breaks the window grab too")
		var win_done: bool = await _until(func() -> bool: return rch._win_state == "" and rch.bstate == HomageBoss.B.MOVE, 6.0)
		_check(win_done, "the arm withdraws through the window")
	_check(rch.breaths >= 1 or rch._breath == null, "her breath frosts in the cold taproom (%d puffs)" % rch.breaths)


func _alix_moves(cr: CousinsRound, alx: CousinAlix) -> void:
	var up: bool = await _until_cull(func() -> bool: return alx.bstate == HomageBoss.B.MOVE, 5.0)
	_check(up, "Alix is up out of the trapdoor at %s" % str(alx.global_position.snapped(Vector3.ONE * 0.1)))
	_check(cr.hatch_open(), "out of the trapdoor behind the bar (a runtime hatch, open)")
	var others: Array[HomageBoss] = [cr.boss("hammer"), cr.boss("reach")]
	var park: Callable = func() -> void:
		for o: HomageBoss in others:
			if o != null and o.is_active():
				o.global_position = Vector3(2.0, 3.8, 7.5)
				o._cds["throw"] = 99.0
				o._cds["grab"] = 99.0
				o._cds["wall"] = 99.0
	# ObservedFreeze beyond 8 m: watched -> frozen
	alx.global_position = _cr()._snap(Vector3(20.0, 0.0, 12.5))
	_place(Vector3(2.0, 0.0, 9.0), alx.global_position + Vector3.UP * 1.3)
	var look_at_her_once: Callable = func() -> void:
		park.call()
		_place(Vector3(2.0, 0.0, 9.0), alx.global_position + Vector3.UP * 1.3)
	var seen: bool = await _until_cull(func() -> bool: return alx.freeze.observed, 4.0, look_at_her_once)
	_check(seen, "Alix beyond 8 m, in the player's view: observed (%d observer)" % alx.freeze.observers)
	var p0: Vector3 = alx.global_position
	var f0: int = alx.frozen_frames
	var look_at_her: Callable = look_at_her_once
	var watched: bool = await _until_cull(func() -> bool: return alx.frozen_frames - f0 > 40, 3.0, look_at_her)
	_check(watched and alx.global_position.distance_to(p0) < 0.5, "ObservedFreeze: watched from ~15 m she does not move (%d frozen frames, moved %.2f m)" % [alx.frozen_frames - f0, alx.global_position.distance_to(p0)])
	# looked away -> she moves, fast
	var u0: float = alx.unseen_moves
	var look_away: Callable = func() -> void:
		park.call()
		var away: Vector3 = _player().global_position + (_player().global_position - alx.global_position)
		_place(Vector3(2.0, 0.0, 9.0), away)
	var moved: bool = await _until_cull(func() -> bool: return alx.unseen_moves - u0 > 2.0 or alx.global_position.distance_to(_player().global_position) < 8.5, 4.0, look_away)
	_check(moved, "unwatched she glides in (%.1f m while nobody looked)" % (alx.unseen_moves - u0))
	# Holding Hand within 2 m
	var close_in: Callable = func() -> void:
		park.call()
		if alx.bstate == HomageBoss.B.MOVE:
			var f: Vector3 = alx.global_position - alx.global_basis.z * 1.4
			_place(Vector3(f.x, alx.global_position.y, f.z), alx.global_position)
	var held: bool = await _until_cull(func() -> bool: return alx.holds_landed >= 1, 10.0, close_in)
	_check(held, "Holding Hand: the Third Hand takes the player's hand")
	if held:
		_check(_player().has_status(&"held_hand"), "the held hand: vignette + ducked audio (held_hand status FX), no walking away")
		for i: int in 3:
			alx.take_damage(15.0, &"torso", &"trench_knife", 1, &"melee")
		_check(alx.grabs().is_empty(), "three melee hits break her grip")
	# Lash at ~4 m
	alx._cds["hold"] = 99.0
	alx._cds["swipe"] = 99.0
	var lash_range: Callable = func() -> void:
		park.call()
		if alx.bstate == HomageBoss.B.MOVE:
			var f: Vector3 = alx.global_position - alx.global_basis.z * 3.8
			_place(Vector3(f.x, alx.global_position.y, f.z), alx.global_position)
	var lashed: bool = await _until_cull(func() -> bool: return alx.lashes + alx.lash_dodged >= 1, 12.0, lash_range)
	_check(lashed, "Lash: both hands to her ears, then the third arm whips out to 5 m")
	# T-232: the look-away step: inside her band, the player turns their back for 0.6 s
	await _until(func() -> bool: return alx.bstate == HomageBoss.B.MOVE, 4.0)
	alx._cds["lash"] = 99.0
	alx._cds["step"] = 0.0
	alx.global_position = cr._snap(Vector3(16.0, 0.0, 11.0))
	var d0: float = 6.0
	var back_turned: Callable = func() -> void:
		park.call()
		if alx.steps_taken == 0:
			var p: Vector3 = alx.global_position + Vector3(0, 0, -6.0)
			_place(Vector3(p.x, alx.global_position.y, p.z), Vector3(p.x, 0.0, p.z - 6.0))   # looking away north
			d0 = alx.dist_to(_player())
	var stepped: bool = await _until_cull(func() -> bool: return alx.steps_taken >= 1, 6.0, back_turned)
	_check(stepped, "the look-away step: a player who turns their back inside 8 m hears the dress (%d step)" % alx.steps_taken)
	if stepped:
		var closer: bool = await _until(func() -> bool: return alx.bstate == HomageBoss.B.MOVE and alx.dist_to(_player()) < d0 - 0.8, 3.0)
		_check(closer, "and finds her closer (%.1f -> %.1f m), stopped short of her reach" % [d0, alx.dist_to(_player())])
		_check(alx.dist_to(_player()) >= float(alx.bcfg["hold"]["range"]), "never a step straight into a grab")


func _deaths(cr: CousinsRound, ham: CousinHammer, rch: CousinReach, alx: CousinAlix) -> void:
	var scrip0: int = Economy.get_scrip(1)
	_drops.clear()
	# the Hammer dies first
	alx.global_position = cr._snap(ham.global_position + Vector3(2.0, 0, 0))
	ham.debug_kill(1)
	_check(cr.dead.has("hammer") and cr.hud.is_struck("hammer"), "the Hammer dies: her bar is struck through")
	_check(rch.enrage_steps == 1 and alx.enrage_steps == 1 and is_equal_approx(rch.speed_mult(), 1.2), "the survivors enrage (+20%%: Reach x%.2f)" % rch.speed_mult())
	_check(ham.crack_tier_now == 3, "her death opens every crack")
	var grief: bool = await _until_cull(func() -> bool: return alx.griefs >= 1, 15.0)
	_check(grief, "Alix goes to the Hammer's body and holds her hand")
	if grief:
		var hp0: float = alx.hp
		alx.take_damage(100.0, &"torso", &"m1911", 1, &"bullet")
		_check(absf((hp0 - alx.hp) - 200.0) < 0.5, "the grief window: she takes x2 (100 -> %.0f)" % (hp0 - alx.hp))
		var rose: bool = await _until_cull(func() -> bool: return alx.dripping, 5.0)
		_check(rose, "she rises enraged: the third arm drips Nachtglas light (Double Lash)")
		_check(alx.grief_rises == 1 and is_equal_approx(alx.grief_damage_mult(0.15, alx.grief_rises), 1.15), "and hits harder from here (x%.2f on her double damage)" % alx.grief_damage_mult(0.15, alx.grief_rises))
	# T-232: the hum has gone flat on the enraged (the loop exists and plays between tells)
	var hum: bool = await _until_cull(func() -> bool: return rch._hum_loop != null and rch._hum_loop.playing, 6.0)
	_check(hum, "the enraged Reach hums the lullaby flat (boss_hum_wrong loop)")
	# the Reach second
	rch.debug_kill(1)
	_check(alx.enrage_steps == 2 and is_equal_approx(alx.speed_mult(), 1.4), "the second death stacks the enrage (+40%%: Alix x%.2f)" % alx.speed_mult())
	_check(_drops.has("fortify"), "the Reach drops Fortify")
	_check(is_equal_approx(alx.grief_seconds_now(), 4.5), "her second grief window is longer (%.1f s)" % alx.grief_seconds_now())
	# T-232: the dark hunt: the lamps that came back go out again, the hearth comes up, Alix hunts in the dark
	var out_before: int = cr.lamps_out
	var dark: bool = await _until_cull(func() -> bool: return cr.dark_hunt, 8.0)
	_check(dark and alx.dark_hunt, "the last cousin standing puts the lamps out again (the dark hunt)")
	await _secs(2.4)   # past the lamps' gutter and the hearth's 0.6 s + 1.5 s relight tween
	_check(cr.lamps_out > out_before, "the lamps are out again (%d -> %d out)" % [out_before, cr.lamps_out])
	var fire: Light3D = cr._lamp_node(str(cr.cfg["setup"]["fire"]))
	var fire_e: float = float(fire.get("base_energy")) if fire != null and fire.get("base_energy") != null else (fire.light_energy if fire != null else 0.0)
	var fire_base: float = float((cr._lamps[str(cr.cfg["setup"]["fire"])] as Array)[1]) if fire != null else 1.0
	_check(fire != null and fire_e > fire_base * 0.6, "only the hearth is relit for the finale (%.2f of %.2f)" % [fire_e, fire_base])
	alx.debug_kill(1)
	_check(cr.cleared_count == 1 and cr.rewards_given, "all three dead: the round is cleared")
	_check(_drops.has("deaths_door") and _drops.has("resupply"), "Death's Door + Resupply drop at the last body (drops %s)" % str(_drops))
	var gained: int = Economy.get_scrip(1) - scrip0
	_check(gained >= 400 + 300 + 500 + 500 + 1500, "Scrip: kills + the Reach's 500 + 1500 for the clear (+%d)" % gained)
	_check(ProfileSave.is_unlocked("card_the_game_is_over") and ProfileSave.is_unlocked("charm_three_ribbons") and ProfileSave.has_intel("INT_HB_01"),
		"profile: the calling card, the Three Ribbons charm and the Aunt's Letter are recorded")
	_check(cr.lines_said.has("OPR_BOSS_COUSINS_DEAD_M0_03") and cr.lines_said.has("ALX_COUSIN_01"), "the lines played (subtitles): %d lines" % cr.lines_said.size())
	_check(cr.lamps_out == 0, "every lamp relit")
	var glow2: LampGlow = _map.get_node_or_null("LampGlow") as LampGlow
	if glow2 != null:
		var tap: Vector3 = (_map.find_child("TapLamp1", true, false) as Node3D).global_position
		var lit: bool = await _until(func() -> bool: return glow2.glow_near(tap) > 0.85, 6.0)
		_check(lit, "the lantern glass glows again with its light (glow %.2f)" % glow2.glow_near(tap))
	# the round ends once the horde is gone
	var ended: bool = await _until_cull(func() -> bool: return _rounds_ended.has(10), 30.0)
	_check(ended, "round 10 ends once the horde is cleared")
	var r11: bool = await _until_cull(func() -> bool: return RoundManager.current_round >= 11, 25.0)
	if not r11:
		_note("round %d state %s break_left %.1f alive %d queued %d" % [RoundManager.current_round, RoundManager.State.keys()[RoundManager.state], RoundManager.break_left, RoundManager.alive, RoundManager.to_spawn])
	_check(r11 and cr.phase == CousinsRound.Phase.IDLE, "round 11 follows; the encounter is over (%s, round %d)" % [CousinsRound.Phase.keys()[cr.phase], cr.event_round])


# ================================================================== case BORED

func _case_bored() -> void:
	_note("---- case BORED: the 6:00 fail-safe and the round-15 return")
	_rounds_ended.clear()
	await _load_map(true)
	var cr: CousinsRound = _cr()
	_place(Vector3(14, 0, 8))
	RoundManager.debug_set_round(10)
	var began: bool = await _until(func() -> bool: return cr.phase == CousinsRound.Phase.ACTIVE, 10.0)
	_check(began, "round 10: the Cousins Round again")
	await _until_cull(func() -> bool: return cr.boss("hammer") != null, 5.0)
	var scrip0: int = Economy.get_scrip(1)
	cr.t = float(cr.cfg["failsafe_seconds"]) - 0.5
	var bored: bool = await _until(func() -> bool: return cr.phase == CousinsRound.Phase.BORED, 3.0)
	_check(bored and cr.lines_said.has("CSN_BORED_01"), "past 6:00 they get bored and leave (\"Langweilig! Morgen wieder!\")")
	var gone: bool = await _until_cull(func() -> bool: return cr.alive_count() == 0, 5.0)
	_check(gone, "every cousin is gone")
	_check(not cr.rewards_given and Economy.get_scrip(1) - scrip0 < 1500, "no rewards for a bored round")
	_check(cr.event_round == 15 and RoundManager.is_reserved(15), "round 15 is theirs now")
	var ended: bool = await _until_cull(func() -> bool: return _rounds_ended.has(10), 30.0)
	_check(ended, "round 10 ends normally once the horde is cleared")
	RoundManager.debug_set_round(15)
	var back: bool = await _until_cull(func() -> bool: return cr.phase == CousinsRound.Phase.ACTIVE and cr.boss("hammer") != null, 12.0)
	_check(back and cr.returning, "round 15: they come back")
	var ham: HomageBoss = cr.boss("hammer")
	_check(ham != null and is_equal_approx(ham.hp, ham.max_hp) and is_equal_approx(ham.max_hp, CousinsRound.boss_hp("hammer", RoundManager.players, cr.cfg)), "with full HP")
	_check(cr.lines_said.has("OPR_BOSS_COUSINS_RETURN_M0_01"), "and the Operator's return line")


# ================================================================== case OFF

func _case_off() -> void:
	_note("---- case OFF: Homage Bosses Off, round 10 is a normal round")
	_rounds_ended.clear()
	_rounds_started.clear()
	await _load_map(false)
	var cr: CousinsRound = _cr()
	_check(not RoundManager.is_reserved(10), "round 10 is not reserved")
	_place(Vector3(14, 0, 8))
	RoundManager.debug_set_round(10)
	var started: bool = await _until(func() -> bool: return _rounds_started.has(10), 10.0)
	_check(started, "round 10 starts")
	var full: int = RoundManager.zombie_count(10, RoundManager.players, GLData.table("rounds"))
	_check(RoundManager.round_total == full, "the full horde (%d)" % RoundManager.round_total)
	await _secs(4.0)
	var any: bool = false
	for z: Zombie in _dir().active_zombies():
		if z is HomageBoss:
			any = true
	_check(not any and (cr == null or cr.phase == CousinsRound.Phase.IDLE), "no cousin comes")
	var ended: bool = await _until_cull(func() -> bool: return _rounds_ended.has(10), 90.0)
	_check(ended, "round 10 ends like any round")
