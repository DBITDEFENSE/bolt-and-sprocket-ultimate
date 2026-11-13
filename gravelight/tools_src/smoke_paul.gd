extends Node
## Headless smoke for HB2, PAUL on Kaltenbrunn (docs/HOMAGE_BOSSES.md section 5; DECISIONS T-159). Solo, god mode,
## silent.
##   Case ON: round 15 forced (debug_set_round, as the dev launcher does): the reserved round, the 60% horde, the
##     arrival (the headframe shakes, the PA roar, the leap, the crater knockdown, the title card and the rage
##     bottle on the bar), two stages reached by scripted damage (Angry, BERSERK, the growth), Grab & Squeeze with
##     the lift and a bottle shot that frees the player and cools him 20, a door charged open, then the fail-safe:
##     the clock run past 6:00, he leaves (headframe, north) and his return round is 8-10 later; the return: +35%
##     HP and six bottles, then the kill: the twist (the last line to the nearest player, the tin cup, the fall)
##     and the rewards (Scrip, Double Scrip, the unlocks and documents, PAUL'S LAST ROUND drunk: free Ironhide).
##     T-232 (the boss rework): the kit is on him (flesh hits, boss_stomp footfalls that shake harder per stage), the
##     model's new pieces (lit bottles, the eyes, the drips), BERSERK kills the yard's floods and swings the headframe's
##     lamps (and shrinking out of it brings the light back), the squad read (a lone player; a hurt player becomes his
##     target), a bottle's glow dims as it breaks.
##   Case BOTS: round 15 with a bots-only squad (the human spectating): bots alone switches on (half HP); T-232: at
##     BERSERK he guards a downed bot's body ("protect my guys": he walks to it, stands over it, slams the bot that
##     comes near, and lets go when the body is revived); and the kill still pays out.
##   Case OFF: Homage Bosses Off: round 15 is a normal round (no PAUL, not reserved).
## Prints "[paul] ..." lines and "[paul] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_paul.tscn

const MAP: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 900.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _drops: Array[String] = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_paul_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_paul_settings.cfg"
	GLSettings.values["homage_names"] = "real"
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	Campaign.reset()
	GLBus.powerup_spawned.connect(func(id: StringName, _p: Vector3) -> void: _drops.append(String(id)))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(msg: String) -> void:
	print("[paul] ", msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[paul] FAIL: ", msg)


func _check(cond: bool, what: String) -> void:
	print("[paul] %-78s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[paul] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (%d: %s)" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
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


func _enc() -> PaulEncounter:
	return _dir().homage as PaulEncounter


func _player() -> Player:
	return _root().player


func _cull_horde() -> void:
	if _map == null or not is_instance_valid(_map) or _root().director == null:
		return
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss):
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")


func _load_map(homage: bool, bots: int) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GLSettings.values["homage_bosses"] = homage
	GameState.bot_count = bots
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0)
	await _secs(1.0)
	GameState.god_mode = true
	_player().set_process_unhandled_input(false)
	_dir().kill_all(true)


func _place(p: Vector3) -> void:
	_player().global_position = p
	_player().velocity = Vector3.ZERO


func _run() -> void:
	await _case_on()
	await _case_bots()
	await _case_off()
	_finish()


# ================================================================== case ON

func _case_on() -> void:
	_note("---- case ON: Homage Bosses On, Kaltenbrunn round 15")
	await _load_map(true, 0)
	var enc: PaulEncounter = _enc()
	_check(enc != null, "Kaltenbrunn's director made PAUL's encounter")
	if enc == null:
		return
	_check(RoundManager.is_reserved(15), "round 15 is reserved (no Foreman, no Bellringer round on it)")
	_place(Vector3(16, 0, 27))
	RoundManager.debug_set_round(15)
	var began: bool = await _until(func() -> bool: return enc.phase == HomageEncounter.Phase.ACTIVE, 10.0)
	_check(began, "round 15 starts PAUL's round")
	if not began:
		return
	var full: int = RoundManager.zombie_count(15, RoundManager.players, GLData.table("rounds"))
	_check(RoundManager.round_total == HomageEncounter.horde_count(full, enc.cfg), "the horde is 60%% of round 15 (%d of %d)" % [RoundManager.round_total, full])
	_check(enc._shake_left > 0.0 and not enc._shaking.is_empty(), "the headframe shakes (%d pieces)" % enc._shaking.size())
	var landed: bool = await _until(func() -> bool: return enc.arrival_done, 9.0)
	_check(landed, "he leaps down from the headframe and lands")
	var p: Paul = enc.paul()
	if p == null:
		_fail("no PAUL")
		return
	_check(enc.lines_said.has("PAU_PA_01"), "WHERE'S MY SQUAD?! over the PA")
	_check(enc.craters.size() >= 1, "the crater decal stays")
	_check(enc.knocked.has(_player().player_id), "the crater knocks the player down (within 10 m)")
	_check(enc.hud != null and enc.hud.cards_shown.has("PAUL"), "the title card says PAUL (never a placeholder)")
	_check(enc.hud.has_bar("paul") and enc.hud.gauge_value("paul") >= 0.0, "his bar has the rage bottle")
	var want_hp: float = 30000.0 * (1.0 + 0.75 * float(RoundManager.players - 1))
	_check(is_equal_approx(p.max_hp, want_hp), "PAUL has %d HP (30000 x the player scaling)" % int(p.max_hp))
	_check(p.bottles_left() == 6, "six IV bottles on the rack")
	# ---- T-232: the kit and the model
	_check(p.fx != null and p.fx.has_footfalls() and str(p.fx.cfg.get("surface", "")) == "flesh" and str(p.fx.cfg.get("step_sound", "")) == "boss_stomp", "the kit is on him (flesh hits, boss_stomp footfalls)")
	var shake_calm: float = float(p.fx.cfg.get("step_shake", 0.0)) if p.fx != null else 0.0
	_check(is_equal_approx(shake_calm, 0.45), "Calm footfalls shake 0.45 (%.2f)" % shake_calm)
	_check(p._eyes != null and p._bottle_mat != null and p._bottle_mat.emission_enabled and p._drips != null and p._drips.emitting and p._steam != null, "the model: amber eyes, bottles lit from inside, stout drips at the neck, the steam emitter")
	var glow_full: float = p._bottle_mat.emission_energy_multiplier if p._bottle_mat != null else 0.0
	_check(p.squad_read().get("alone", false), "the squad read: a lone player")
	# ---- stages by scripted damage
	p.take_damage(p.max_hp * 0.36, &"torso", &"debug", 1, &"world")
	await _secs(1.5)
	_check(p.stage() == PaulRage.ANGRY and p.stage_scale > 1.1, "36%% damage: Angry (rage %.0f, scale %.2f)" % [p.rage.value, p.stage_scale])
	_check(not p._floods_out and (p.fx == null or p.fx.dimmed_count() == 0), "Angry: the yard's light stays")
	p.take_damage(p.max_hp * 0.33, &"torso", &"debug", 1, &"world")
	await _secs(1.5)
	_check(p.stage() == PaulRage.BERSERK and p.stage_scale > 1.25, "69%% damage: BERSERK (rage %.0f, scale %.2f)" % [p.rage.value, p.stage_scale])
	_check(is_equal_approx(p.move_speed(), 6.2), "BERSERK runs at 6.2 m/s")
	_check(enc.lines_said.has("PAU_BERSERK_01"), "his BERSERK roar line")
	_check(p._floods_out and p.fx != null and p.fx.dimmed_count() > 0, "BERSERK: the yard's floods die under his roar (%d lights dimmed)" % (p.fx.dimmed_count() if p.fx != null else 0))
	_check(enc.lamp_swings >= 1 and enc._swinging.size() > 0, "the headframe's floods swing on their brackets (%d pieces)" % enc._swinging.size())
	_check(p.fx != null and float(p.fx.cfg.get("step_shake", 0.0)) > 0.8 and float(p.fx.cfg.get("step_radius", 0.0)) > 20.0, "his footfalls shake harder and wider at BERSERK (%.2f, %.0f m)" % [float(p.fx.cfg.get("step_shake", 0.0)), float(p.fx.cfg.get("step_radius", 0.0))])
	_check(p._steam != null and p._steam.emitting, "steam pours off him at BERSERK")
	# ---- T-232: the squad read: a hurt player is his target
	_place(p.global_position + p.basis_fwd() * 4.0)
	var hp_save: float = _player().hp
	_player().hp = _player().max_hp * 0.2
	_player().set("_since_hit", 0.0)   # (else the regen heals him before the read)
	await _secs(0.35)
	_check(p.squad_read().get("hurt") == _player(), "the squad read: a hurt player (20%%) in his sight becomes his target (hp %.0f, los %s)" % [_player().hp, str(p.has_los(_player(), 2.2, 1.2))])
	_player().hp = hp_save
	await _secs(0.4)
	_check(p.squad_read().get("hurt") == null, "healed: no longer the hurt one")
	# ---- Grab & Squeeze, then a bottle shot frees the player and cools him
	p.set_rage(20.0)   # Calm again: the hysteresis lets him shrink
	await _secs(0.3)
	_check(not p._floods_out, "shrinking out of BERSERK brings the yard's light back")
	_place(p.global_position + p.basis_fwd() * 1.8)
	await get_tree().physics_frame
	p.debug_move("grab")
	var held: bool = await _until(func() -> bool: return not p.grabs().is_empty(), 3.0)
	_check(held, "Grab & Squeeze holds the player")
	if held:
		await _secs(0.4)
		_check(_player().global_position.y > p.global_position.y + 1.0, "the player is lifted off the ground (y %.1f over his %.1f)" % [_player().global_position.y, p.global_position.y])
	var rage_before: float = p.rage.value
	var hpb: float = p.bottles_hp[0]
	p.take_damage(hpb + 1.0, &"bottle1", &"m1911", 1, &"bullet")
	_check(p.bottles_left() == 5, "a shot bottle breaks (5 left)")
	_check(p._bottle_mat != null and p._bottle_mat.emission_energy_multiplier < glow_full - 0.05, "the rack's glow dims with the broken bottle (%.2f -> %.2f)" % [glow_full, p._bottle_mat.emission_energy_multiplier if p._bottle_mat != null else 0.0])
	_check(p.rage.value <= rage_before - 19.0 or p.rage.value <= 0.01, "the bottle cools him 20 (%.0f -> %.0f)" % [rage_before, p.rage.value])
	_check(p.grabs().is_empty(), "breaking a bottle frees the held player")
	_check(enc.lines_said.has("PAU_BOTTLE_01"), "his bottle line")
	# ---- a door charged open (Door_Admin, the yard's west door, still shut)
	var door: BuyDoor = _map.find_child("Door_Admin", true, false) as BuyDoor
	_check(door != null and not door.is_open, "the Administration door is shut")
	if door != null:
		_place(Vector3(14, 0, 20))
		p.global_position = Vector3(9.0, 0.0, 25.0)
		p.velocity = Vector3.ZERO
		await get_tree().physics_frame
		p.debug_charge_at(Vector3(-8.0, 0.0, 25.0))
		var opened: bool = await _until(func() -> bool: return door.is_open, 4.0)
		_check(opened and p.doors_smashed.has(&"door_a_c"), "the Charge smashes the unbought door open for free")
		_check(GameState.is_zone_open(&"C_ADMIN"), "and the zone behind it is open")
	await _secs(1.0)
	# ---- the fail-safe: the clock past 6:00
	enc.spawn_t = enc.t - 361.0
	var left: bool = await _until(func() -> bool: return enc.phase == HomageEncounter.Phase.LEFT, 3.0)
	_check(left, "past 6:00 he leaves (the fail-safe)")
	_check(enc.lines_said.has("PAU_LEAVE_01"), "I'm coming, fellas! HOLD ON!")
	var pw: WeakRef = weakref(p)   # he is freed when he has gone (a plain capture would be a freed lambda capture)
	var gone: bool = await _until(func() -> bool: return pw.get_ref() == null or (pw.get_ref() as Paul).gone, 10.0)
	_check(gone, "he climbs the headframe and leaps away north")
	_check(enc.event_round >= 23 and enc.event_round <= 25 and RoundManager.is_reserved(enc.event_round), "he is due back 8-10 rounds later (round %d)" % enc.event_round)
	_check(not enc.rewards_given, "no rewards for a retreat")
	var ended: bool = await _until(func() -> bool: return RoundManager.state == RoundManager.State.BREAK, 20.0)
	_check(ended, "round 15 ends once the horde is gone")
	# ---- the return and the kill
	var back: int = enc.event_round
	RoundManager.debug_set_round(back)
	var again: bool = await _until(func() -> bool: return enc.phase == HomageEncounter.Phase.ACTIVE and enc.arrival_done, 12.0)
	_check(again, "he comes back on round %d" % back)
	p = enc.paul()
	if p == null:
		_fail("no PAUL on the return")
		return
	_check(is_equal_approx(p.max_hp, want_hp * 1.35), "the return has +35%% HP (%d)" % int(p.max_hp))
	_check(p.bottles_left() == 6, "all six bottles regrown")
	_place(p.global_position + Vector3(3, 0, 3))
	var scrip0: int = Economy.get_scrip(_player().player_id)
	p.debug_kill(1)
	_check(enc.phase == HomageEncounter.Phase.CLEARED, "PAUL is beaten")
	await _secs(1.0)
	var fell: bool = await _until(func() -> bool: return p.fallen, 14.0)
	_check(p.death_line == "PAU_LAST_DUT_01" and enc.lines_said.has("PAU_LAST_DUT_01"), "the twist: his last line to Dutch (%s)" % p.death_line)
	_check(p.cup_given_to == _player().player_id and enc.cup_holder == _player().player_id, "he presses the tin cup into the player's hand")
	_check(fell, "he falls forward like a tree")
	_check(enc.rewards_given, "the rewards are granted")
	_check(_drops.has("double_scrip"), "a Double Scrip drop")
	if true:
		_check(Economy.get_scrip(_player().player_id) >= scrip0 + 2000, "2000 Scrip each")
	_check(ProfileSave.is_unlocked("card_carried_my_share") and ProfileSave.is_unlocked("ARC_HB_PAUL"), "the Carried My Share card and the Archive card")
	_check(ProfileSave.has_intel(&"INT_HB_02") and ProfileSave.has_intel(&"INT_HB_03"), "his POW card and his letter in the profile")
	_check(enc.bottles_spawned.size() == GameState.player_ids.size(), "one PAUL'S LAST ROUND per player")
	if not enc.bottles_spawned.is_empty() and is_instance_valid(enc.bottles_spawned[0]):
		var eff: String = (enc.bottles_spawned[0] as PaulsLastRound).drink(_player().player_id)
		_check(eff == "ironhide" and PerkManager.has_perk(_player().player_id, &"ironhide_stout") and PerkManager.slotless_perk(_player().player_id) == &"ironhide_stout", "drinking it: free Ironhide, no perk slot")
	_check(GameState.has_flag(&"paul_down"), "paul_down is set")
	await _secs(4.0)
	_check(enc.lines_said.has("OPR_BOSS_PAUL_DEAD_01"), "the Operator's quiet line after the fall")
	# the round's queued horde is skipped so the round can end now (the culling only removes what has spawned)
	RoundManager.round_total -= RoundManager.to_spawn
	RoundManager.to_spawn = 0
	var ended2: bool = await _until(func() -> bool: return RoundManager.state == RoundManager.State.BREAK, 30.0)
	_check(ended2 and enc.event_round == -1 and enc.phase == HomageEncounter.Phase.CLEARED, "the round ends and he is gone for the match (never undone)")
	RoundManager.debug_set_round(back + 10)
	await _until(func() -> bool: return RoundManager.state == RoundManager.State.ROUND, 6.0)
	await _secs(1.0)
	_check(enc.paul() == null or not enc.paul().is_active(), "no PAUL on a later round (his death is never undone)")


# ================================================================== case BOTS

func _case_bots() -> void:
	_note("---- case BOTS: round 15 with a bots-only squad")
	await _load_map(true, 2)
	var enc: PaulEncounter = _enc()
	if enc == null:
		_fail("no encounter (bots)")
		return
	_player().spectating = true
	RoundManager.debug_set_round(15)
	var landed: bool = await _until(func() -> bool: return enc.arrival_done, 12.0)
	_check(landed, "bots alone: PAUL arrives")
	var p: Paul = enc.paul()
	if p == null:
		return
	await _until(func() -> bool: return enc.bots_alone, 6.0)
	_check(enc.bots_alone and is_equal_approx(p.squad_hp_mult, 0.5), "bots alone scales him down (hp x%.2f)" % p.squad_hp_mult)
	await _secs(3.0)
	# ---- T-232: "protect my guys": at BERSERK he stands over a downed bot's body and slams the one who comes near
	var bots: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var b: Player = n as Player
		if b != null and b.is_bot:
			bots.append(b)
	_check(bots.size() >= 2, "two bots in the yard")
	if bots.size() >= 2 and is_instance_valid(p) and p.is_active():
		var body: Player = bots[0]
		var comer: Player = bots[1]
		if _root().squad != null:
			_root().squad.process_mode = Node.PROCESS_MODE_DISABLED   # brains off: the bots hold still
		body.set_physics_process(false)
		comer.set_physics_process(false)
		body.global_position = p.global_position + Vector3(3.0, 0.0, 2.0)
		comer.global_position = p.global_position + Vector3(14.0, 0.0, 14.0)
		p.set_rage(80.0)
		await _secs(0.3)
		body.down()
		# (he may be mid-move: the Headframe Climb & Dive he picks the moment he turns BERSERK runs ~5 s; the guard
		# is checked whenever he is back to choosing)
		# He walks on between moves, so the body laid 3 m from him can be 15 m off and behind a wall by the time he
		# is choosing again: it is kept in his sight (3 m in front of him) until he takes the guard.
		var tries: Array = [0]
		var guarding: bool = await _until(func() -> bool:
			if p.guard_pid == body.player_id:
				return true
			if p.bstate != HomageBoss.B.SPECIAL and p.bstate != HomageBoss.B.TELEGRAPH and (p.dist_to(body) > 6.0 or not p.has_los(body, 2.2, 0.4)):
				# a spot 3 m from him on the navmesh, a new bearing each try (the one in front may be a wall)
				tries[0] = int(tries[0]) + 1
				var f: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, float(tries[0]) * PI * 0.25)
				body.global_position = NavigationServer3D.map_get_closest_point(p.get_world_3d().navigation_map, p.global_position + f * 3.0)
			return false, 30.0)
		_check(guarding and p.bstate == HomageBoss.B.SPECIAL, "BERSERK + a downed bot in sight: he goes to guard the body (downed %s, los %s, state %d/%s, %.1f m)" % [str(body.downed), str(p.has_los(body, 2.2, 0.4)), p.bstate, p._special_id, p.dist_to(body)])
		_check(enc.lines_said.has("PAU_CALM_03"), "'Nobody gets left. Nobody.'")
		var over: bool = await _until(func() -> bool: return p.guard_pid == body.player_id and p.dist_to(body) <= 1.3 * p.stage_scale + 0.3, 10.0)
		_check(over, "he stands over the body (%.2f m, scale %.2f, guard_pid %d, bstate %d, guard_t %.1f, posed %s, speed %.2f, vel %s, y %.1f body y %.1f, climbing %s, state %d, tele %.2f)" % [p.dist_to(body), p.stage_scale, p.guard_pid, p.bstate, p.guard_t, str(p._guard_posed), p.move_speed(), str(p.velocity), p.global_position.y, body.global_position.y, str(p.climbing), p.state, p._guard_tele])
		if over:
			comer.global_position = p.global_position + p.basis_fwd() * 2.2
			var slammed: bool = await _until(func() -> bool: return p.guard_slams >= 1, 5.0)
			_check(slammed and int(p.moves_used.get("guard", 0)) >= 1, "a bot coming near takes the slam after the telegraph (%d)" % p.guard_slams)
			_check(p.grabs().is_empty(), "the guard is never a grab")
		body.revive(1)
		var let_go: bool = await _until(func() -> bool: return p.guard_pid < 0, 3.0)
		_check(let_go, "the body revived: he lets go of the guard")
		_check(not p.cd_ready("guard"), "and does not guard again at once (again_after)")
		comer.set_physics_process(true)
		body.set_physics_process(true)
		p.set_rage(10.0)
		await _secs(0.5)
	p.debug_kill(1)
	var paid: bool = await _until(func() -> bool: return enc.rewards_given, 16.0)
	_check(paid, "a bots-only kill still pays out")
	_player().spectating = false


# ================================================================== case OFF

func _case_off() -> void:
	_note("---- case OFF: Homage Bosses Off")
	await _load_map(false, 0)
	var enc: PaulEncounter = _enc()
	_check(not RoundManager.is_reserved(15), "Off: round 15 is not reserved")
	RoundManager.debug_set_round(15)
	await _until(func() -> bool: return RoundManager.state == RoundManager.State.ROUND, 6.0)
	await _secs(5.0)
	_check(enc == null or (enc.phase == HomageEncounter.Phase.IDLE and enc.paul() == null), "Off: no PAUL on round 15")
	var full: int = RoundManager.zombie_count(15, RoundManager.players, GLData.table("rounds"))
	_check(RoundManager.round_total == full, "Off: the full horde (%d)" % RoundManager.round_total)
