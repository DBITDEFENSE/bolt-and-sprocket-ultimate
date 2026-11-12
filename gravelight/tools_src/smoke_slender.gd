extends Node
## Headless smoke for HB3, THE SLENDER at Totenhafen, the Hafenwaechter (docs/HOMAGE_BOSSES.md section 6;
## docs/U10_TOTENHAFEN_DESIGN.md section 9; DECISIONS T-160). Solo, god mode, silent.
##   Case ON: the power on, the Pen Hall doors and the pump stair door bought; round 25 forced: the reserved round,
##     the 50% horde, the arrival (keys from everywhere, "Evening.", the lantern at the end of the west catwalk, the
##     title card and the lantern pip); he walks; he locks two doors as he passes (the Pen Hall door and the pump
##     stair); the beam hurts (a Lantern Sweep logs the player through the tiers); the lit rule (smoke in the
##     dark, damage in a lamp pool); break-free from the Watch Room twice (the page torn out; a teammate's lantern
##     hits); Shift Change's decoys (a decoy shot logs +15); T-233 (the boss rework): the kit's dread block (cloth,
##     a quiet step, radius 24), the model's moving parts (hem and scarf strips, the swinging lantern, the pool of
##     light, the eyes, the lantern hum), the Mirroring step (he stands where you stood a second ago after the keys go
##     still), the Watch tiers on the dread layer, the whisper by tier and for a hurt player, End of Shift through the
##     kit (the lights die, the fuse boxes spark, the lights return) and the phase overrides (cooldowns, the Lash's
##     reach, his walk at 1.9); the fail-safe walk-off into the storm re-opens every door he locked and his return
##     round is 5 later; the return and the kill: he sits down, the rewards (Scrip, the card and charm, the Archive
##     card, the Watch-Book, OVERWATCH).
##   Case BOTS: round 25 with a bots-only squad (the human spectating): bots alone scales him, a kill pays out.
##   Case OFF: Homage Bosses Off: round 25 is a normal round.
## Prints "[slender] ..." lines and "[slender] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_slender.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const TIMEOUT: float = 900.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_slender_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_slender_settings.cfg"
	GLSettings.values["homage_names"] = "real"
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	Campaign.reset()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(msg: String) -> void:
	print("[slender] ", msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[slender] FAIL: ", msg)


func _check(cond: bool, what: String) -> void:
	print("[slender] %-78s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[slender] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (%d: %s)" % [_fails.size(), "; ".join(_fails)]])
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


func _enc() -> SlenderEncounter:
	return _dir().homage as SlenderEncounter


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
	GameState.power_on = true
	GameState.set_flag(&"power_on", true)


func _place(p: Vector3, look_at_pos: Vector3 = Vector3.INF) -> void:
	var pl: Player = _player()
	pl.global_position = p
	pl.velocity = Vector3.ZERO
	if look_at_pos != Vector3.INF:
		var d: Vector3 = look_at_pos - p
		pl.rotation.y = atan2(-d.x, -d.z)


func _door(n: String) -> BuyDoor:
	return _map.find_child(n, true, false) as BuyDoor


func _run() -> void:
	await _case_on()
	await _case_bots()
	await _case_off()
	_finish()


# ================================================================== case ON

func _case_on() -> void:
	_note("---- case ON: Homage Bosses On, Totenhafen round 25")
	await _load_map(true, 0)
	var enc: SlenderEncounter = _enc()
	_check(enc != null, "Totenhafen's director made THE SLENDER's encounter (the Hafenwaechter)")
	if enc == null:
		return
	_check(RoundManager.is_reserved(25), "round 25 is reserved (standalone)")
	var pen_w: BuyDoor = _door("Door_PenHall_W")
	var pumps: BuyDoor = _door("Door_Pumps")
	_check(pen_w != null and pumps != null, "the Pen Hall door and the pump stair door exist")
	if pen_w == null or pumps == null:
		return
	pen_w.open(0)
	pumps.open(0)
	_place(Vector3(24, 0, 21))
	RoundManager.debug_set_round(25)
	var began: bool = await _until(func() -> bool: return enc.phase == HomageEncounter.Phase.ACTIVE, 10.0)
	_check(began, "round 25 starts his round")
	if not began:
		return
	var full: int = RoundManager.zombie_count(25, RoundManager.players, GLData.table("rounds"))
	_check(RoundManager.round_total == HomageEncounter.horde_count(full, enc.cfg), "the horde is 50%% of round 25 (%d of %d)" % [RoundManager.round_total, full])
	_check(enc.jingles >= 5, "keys jingle across the whole harbour (%d points)" % enc.jingles)
	var in_: bool = await _until(func() -> bool: return enc.arrival_done, 8.0)
	_check(in_ and enc.lines_said.has("SLN_ARRIVE_01"), "\"Evening. Don't mind me. I'm only on my rounds.\" and the lantern lights")
	var s: Slender = enc.slender()
	if s == null:
		_fail("no Slender")
		return
	_check(s.global_position.distance_to(Vector3(-19, 4, 80)) < 3.0, "at the far end of the west catwalk (%s)" % str(s.global_position.snapped(Vector3.ONE * 0.1)))
	_check(enc.hud.cards_shown.has("DEVIN") and enc.hud.has_bar("the_slender"), "the title card (Real names: DEVIN over THE SLENDER) and his bar")
	_check(enc.hud.gauge_value("the_slender") >= 0.0, "the lantern pip on his bar")
	_check(is_equal_approx(s.max_hp, 35000.0 * (1.0 + 0.75 * float(RoundManager.players - 1))), "%d HP (35000 x the player scaling)" % int(s.max_hp))
	# ---- he walks
	var p0: Vector3 = s.global_position
	await _until(func() -> bool: return s.global_position.distance_to(p0) > 1.5, 8.0)
	_check(s.global_position.distance_to(p0) > 1.5, "he walks his rounds (moved %.1f m)" % s.global_position.distance_to(p0))
	# ---- he locks two doors as he passes
	s.debug_walk_to(Vector3(-10.0, 0.0, 34.0))
	var l1: bool = await _until(func() -> bool: return pen_w.boss_locked, 3.0)
	s.debug_walk_to(Vector3(49.0, 0.0, 43.5))
	var l2: bool = await _until(func() -> bool: return pumps.boss_locked, 3.0)
	_check(l1 and l2 and s.locked.size() >= 2, "he locks the Pen Hall door and the pump stair as he walks (%s)" % str(s.locks_done))
	_check(pen_w.boss_locked and pen_w.blocks() and not pen_w.can_interact(_player()), "a locked door shuts and can't be used")
	# ---- the beam hurts: a Lantern Sweep logs the player
	# along the north apron (z 33..38 is floor all the way; the docks south of it are water)
	s.debug_walk_to(Vector3(12.0, 0.0, 35.5))
	_place(Vector3(24.0, 0.0, 35.5), Vector3(12, 2, 35.5))
	await get_tree().physics_frame
	var m0: float = s.meter(_player().player_id).value if s.meter(_player().player_id) != null else 0.0
	s.debug_sweep()
	await _until(func() -> bool: return s.meter(_player().player_id) != null and s.meter(_player().player_id).value >= 45.0, 4.0)
	var m: WatchMeter = s.meter(_player().player_id)
	_check(m != null and m.value > m0 + 30.0, "the Lantern Sweep's beam logs the player (%.0f -> %.0f)" % [m0, m.value if m != null else -1.0])
	_check(m != null and m.tier_events.has(WatchMeter.Tier.LOW) and m.tier_events.has(WatchMeter.Tier.MEDIUM), "through the tiers (Noted., Observed.)")
	_check(s.sweeps >= 1 and enc.lines_said.has("SLN_SWEEP_01"), "\"Let's have a look at you.\"")
	# ---- the lit rule: smoke in the dark, damage in a lamp pool
	s.debug_walk_to(Vector3(-12.0, 0.0, 35.0))
	_place(Vector3(-12.0, 0.0, 50.0))
	var dark: bool = await _until(func() -> bool:
		s.debug_walk_to(Vector3(-12.0, 0.0, 35.0))
		return not s.is_lit(), 3.0)
	var hp0: float = s.hp
	s.take_damage(500.0, &"torso", &"kar98k", _player().player_id, &"bullet")
	_check(dark and is_equal_approx(s.hp, hp0) and s.smoke_hits >= 1, "in the dark the bullets pass through him like smoke")
	s.debug_walk_to(Vector3(16.0, 0.0, 60.0))
	_place(Vector3(16.0, 0.0, 74.0))
	var lit: bool = await _until(func() -> bool: return s.is_lit(), 3.0)
	hp0 = s.hp
	s.take_damage(500.0, &"torso", &"kar98k", _player().player_id, &"bullet")
	_check(lit and s.hp < hp0, "in the pen hall's lamp pool he bleeds (%.0f -> %.0f)" % [hp0, s.hp])
	# ---- break-free: the Watch Room, the page torn out
	_place(Vector3(16.0, 0.0, 70.0))
	var origin: Vector3 = _player().global_position
	m.value = 100.0
	_check(m.due(), "the meter at 100 is due (the tick hands the player to the Watch Room)")
	enc.quarantine(_player())
	var taken: bool = await _until(func() -> bool: return enc.room_busy(), 2.0)
	_check(taken and _player().global_position.y < -40.0, "at 100 LOGGED he quarantines you: the Watch Room below the harbour")
	_check(enc.lines_said.has("SLN_ROOM_01") and enc.lines_said.has("OPR_BOSS_SLENDER_QUAR_01"), "\"Everyone has a page. Find yours.\"")
	if taken:
		_check(not enc.room.tear((enc.room.right_book + 1) % 3), "the wrong book is not your page")
		var taken_at: Vector3 = enc.room.origin
		var torn: bool = enc.room.tear(enc.room.right_book)
		await get_tree().physics_frame
		_check(torn and not enc.room_busy() and _player().global_position.distance_to(taken_at) < 1.0 and taken_at.distance_to(origin) < 2.0,
			"you tear out your page and you're let go where you stood (%.2f m off)" % _player().global_position.distance_to(taken_at))
		_check(m.value == 0.0 and m.immune > 5.0, "the meter is 0 with 10 s of immunity")
	# ---- break-free in co-op: a teammate's lantern hits release you
	enc.quarantine(_player())
	_check(enc.room_busy(), "taken in again (for the co-op release)")
	for i: int in 5:
		s.take_damage(10.0, &"lantern", &"m1911", 2, &"bullet")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not enc.room_busy() and enc.room.escapes >= 2, "five lantern hits from a teammate release you")
	# ---- Shift Change: the decoys
	s.take_damage(s.hp - s.max_hp * 0.45, &"torso", &"debug", 1, &"world")
	var split: bool = await _until(func() -> bool: return s.decoys.size() == 2, 2.0)
	_check(split and enc.lines_said.has("SLN_DECOY_01"), "below 50%: Change of shift (two decoys, flickering lanterns)")
	m.immune = 0.0
	var mv: float = m.value
	var hp_d: float = s.hp
	s.take_damage(30.0, &"decoy", &"m1911", _player().player_id, &"bullet")
	_check(s.decoy_hits == 1 and m.value >= mv + 14.0 and is_equal_approx(s.hp, hp_d), "shooting a decoy: no damage, the shooter logged +15 (%.0f -> %.0f)" % [mv, m.value])
	await _t233(s, enc, m)
	# ---- the fail-safe: the walk-off into the storm
	s.debug_walk_to(Vector3(30.0, 0.0, 36.0))
	enc.spawn_t = enc.t - 481.0
	var left: bool = await _until(func() -> bool: return enc.phase == HomageEncounter.Phase.LEFT, 3.0)
	_check(left and enc.lines_said.has("SLN_LEAVE_01"), "past 8:00 he walks off: \"Rounds aren't finished.\"")
	_check(not pen_w.boss_locked and pen_w.is_open and not pumps.boss_locked and pumps.is_open, "every door he locked opens again, free")
	var sw: WeakRef = weakref(s)
	var gone: bool = await _until(func() -> bool: return sw.get_ref() == null or (sw.get_ref() as Slender).gone, 45.0)
	_check(gone, "he walks off the quay into the storm")
	_check(enc.event_round == 30 and RoundManager.is_reserved(30), "back 5 rounds later (round %d)" % enc.event_round)
	_check(not enc.rewards_given, "no rewards for a walk-off")
	RoundManager.round_total -= RoundManager.to_spawn
	RoundManager.to_spawn = 0
	await _until(func() -> bool: return RoundManager.state == RoundManager.State.BREAK, 30.0)
	# ---- the return and the kill
	RoundManager.debug_set_round(30)
	var again: bool = await _until(func() -> bool: return enc.phase == HomageEncounter.Phase.ACTIVE and enc.arrival_done, 10.0)
	_check(again, "he comes back on round 30")
	s = enc.slender()
	if s == null:
		_fail("no Slender on the return")
		return
	var scrip0: int = Economy.get_scrip(_player().player_id)
	s.debug_kill(1)
	_check(enc.phase == HomageEncounter.Phase.CLEARED, "THE SLENDER is beaten")
	var sat: bool = await _until(func() -> bool: return s.sat, 10.0)
	_check(sat and enc.lines_said.has("SLN_DEATH_01"), "\"Shift's over. Someone else has the watch now.\" He sits down and stays")
	_check(s.state == Zombie.State.DEAD and is_instance_valid(s) and not s.is_active(), "harmless for the rest of the match (nothing targets him)")
	var paid: bool = await _until(func() -> bool: return enc.rewards_given, 4.0)
	_check(paid and Economy.get_scrip(_player().player_id) >= scrip0 + 2500, "2500 Scrip each")
	_check(ProfileSave.is_unlocked("card_night_shift") and ProfileSave.is_unlocked("charm_violet_lantern") and ProfileSave.is_unlocked("ARC_HB_SLENDER"), "the Night Shift card, the Violet Lantern charm, the Archive card")
	_check(ProfileSave.has_intel(&"INT_HB_04") and (ProfileSave.profile.get("watch_book", []) as Array).size() >= 2, "the Watch-Book (%d pages)" % (ProfileSave.profile.get("watch_book", []) as Array).size())
	_check(enc.overwatch != null and is_instance_valid(enc.overwatch) and GameState.has_flag(&"overwatch"), "OVERWATCH for the squad")
	_check(GameState.has_flag(&"slender_relieved"), "slender_relieved is set")


# ================================================================== T-233: the boss rework

func _t233(s: Slender, enc: SlenderEncounter, m: WatchMeter) -> void:
	_note("---- T-233: the kit, the model, the Mirroring step, the whisper, End of Shift")
	# the kit's dread block and the model's moving parts
	_check(s.fx != null and is_equal_approx(s.fx.c("radius"), 24.0) and str(s.fx.cfg.get("surface", "")) == "cloth" and not s.fx.has_footfalls(),
		"the dread block: felt from 24 m, cloth, a quiet step (no stomp, no shake)")
	var strips_n: int = s.find_children("Strips", "", true, false).size()
	_check(strips_n >= 5 and s._eyes != null and s._lantern_swing != null and s._pool != null,
		"the coat and scarf sway (%d strip groups), the eyes glow, the lantern swings on its pole over its pool of light" % strips_n)
	_check(s._hum != null or not AudioDirector.has_sound("slender_lantern_hum"), "the lantern hums (slender_lantern_hum as a 3D loop)")
	# the Mirroring step: the keys go still, then he stands where you stood a second ago
	var a: Vector3 = Vector3(16.0, 0.0, 66.0)
	s._cds.erase("mirror_step")
	s.debug_walk_to(Vector3(16.0, 0.0, 56.0))
	_place(a, Vector3(16.0, 1.5, 56.0))
	await _secs(1.3)
	_place(Vector3(16.0, 0.0, 72.0), Vector3(16.0, 1.5, 56.0))
	var steps0: int = s.mirror_steps
	s.debug_mirror_step()
	_check(s.sstate == Slender.S.MIRROR_SILENCE and s._silent, "the keys go still first (the step's telegraph)")
	var stepped: bool = await _until(func() -> bool: return s.mirror_steps > steps0, 3.0)
	var off: float = Vector2(s.global_position.x - a.x, s.global_position.z - a.z).length()
	_check(stepped and off < 2.0, "the Mirroring step: he stands where you stood a second ago (%.1f m off)" % off)
	_check(enc.lines_said.has("SLN_MIRROR_STEP_01"), "\"You walked that way. I know. I was just behind you.\"")
	await _until(func() -> bool: return s.sstate == Slender.S.WALK, 2.0)
	_check(s.sstate == Slender.S.WALK and not s._silent, "he holds still for the clean shot, then the keys jingle again")
	# the squad rule: alone in the dark the Watch fills x1.5 (the pure rule; the smoke is solo, so the player is alone)
	var alone_r: float = m.rate({"pool": true, "seen": true, "dark": true, "alone": true}, 0.0, 0.0)
	var mate_r: float = m.rate({"pool": true, "seen": true, "dark": true, "teammate": true}, 0.0, 0.0)
	_check(is_equal_approx(alone_r, 18.0) and is_equal_approx(mate_r, 8.0), "alone in the dark his pool logs +18/s; beside a teammate +8/s")
	# the whisper: by tier (MEDIUM), and from LOW for a hurt player; the tiers push the dread layer
	var pid: int = _player().player_id
	var w0: int = s.whispers
	m.immune = 0.0
	m.value = 45.0
	s._whisper_t[pid] = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(s.whispers > w0 and m.tier == WatchMeter.Tier.MEDIUM, "at Observed. a whisper comes close behind you")
	var w1: int = s.whispers
	m.value = 15.0
	var hp_was: float = _player().hp
	_player().hp = _player().max_hp * 0.3
	s._whisper_t[pid] = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(s.whispers > w1 and m.tier == WatchMeter.Tier.LOW, "a hurt player hears it from Noted.")
	_player().hp = hp_was
	_place(Vector3(24.0, 0.0, 21.0))   # 45 m from him on the quay: the distance adds nothing, the tier does
	m.value = 45.0
	await _secs(0.35)
	var dfx: DreadFx = DreadFx.of(_player())
	var lvl: float = float(dfx.target_level()[0]) if dfx != null else -1.0
	_check(dfx != null and lvl >= 0.3, "the Watch tier is felt on the screen (dread %.2f at Observed., out of his radius)" % lvl)
	# End of Shift through the kit: the lights die (and gutter), the fuse boxes spark, the lights come back
	var hp_pct: float = s.hp / s.max_hp
	s.take_damage(s.hp - s.max_hp * 0.15, &"torso", &"debug", 1, &"world")
	var dark: bool = await _until(func() -> bool: return s.end_of_shift_done and s.dark_t > 0.0, 2.0)
	_check(dark and s.wphase == 3 and enc.lines_said.has("SLN_DARK_01"), "below 20%% (from %.0f%%): End of Shift, \"Lights out.\"" % (hp_pct * 100.0))
	_check(s.fx.dimmed_count() > 0, "the arena's lights die through the kit (%d captured; his lantern is the only light)" % s.fx.dimmed_count())
	await _until(func() -> bool: return enc.fuse_boxes.size() >= 3 and s.fuse_sparks >= 3, 4.0)
	_check(enc.fuse_boxes.size() == 3 and s.fuse_sparks >= 3, "the three fuse boxes spark in the dark (%d bursts)" % s.fuse_sparks)
	_check(is_equal_approx(Slender.phase_value(s.bcfg, 3, "sweep", "cooldown", 12.0), 7.0) and is_equal_approx(Slender.phase_value(s.bcfg, 1, "sweep", "cooldown", 12.0), 12.0)
		and is_equal_approx(s._mvf("lash", "range", 4.0), 5.0) and is_equal_approx(s.move_speed(), 1.9),
		"the last round escalates: the sweep 12 -> 7 s, the Lash reaches 5 m, he walks at 1.9 (never runs)")
	s.dark_t = 0.05
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(s.dark_t <= 0.0 and s.fx.dimmed_count() == 0, "when the 30 s are up the lights come back (the pools wait for the fuses)")
	s.relight_pools([0, 1, 2])
	_check(s.pools_on[2], "a fuse thrown relights its pools")


# ================================================================== case BOTS

func _case_bots() -> void:
	_note("---- case BOTS: round 25 with a bots-only squad")
	await _load_map(true, 2)
	var enc: SlenderEncounter = _enc()
	if enc == null:
		_fail("no encounter (bots)")
		return
	_player().spectating = true
	RoundManager.debug_set_round(25)
	var in_: bool = await _until(func() -> bool: return enc.arrival_done, 12.0)
	_check(in_, "bots alone: he arrives")
	var s: Slender = enc.slender()
	if s == null:
		return
	await _until(func() -> bool: return enc.bots_alone, 6.0)
	_check(enc.bots_alone and is_equal_approx(s.squad_hp_mult, 0.5), "bots alone scales him down (hp x%.2f)" % s.squad_hp_mult)
	await _secs(4.0)
	var bot_max: float = 0.0
	for v: Variant in s.meters.values():
		var wm: WatchMeter = v as WatchMeter
		if wm.is_bot:
			bot_max = maxf(bot_max, wm.value)
	_check(bot_max <= 94.0, "bots never pass HIGH (max %.0f)" % bot_max)
	s.debug_kill(1)
	var paid: bool = await _until(func() -> bool: return enc.rewards_given, 14.0)
	_check(paid, "a bots-only kill still pays out")
	_player().spectating = false


# ================================================================== case OFF

func _case_off() -> void:
	_note("---- case OFF: Homage Bosses Off")
	await _load_map(false, 0)
	var enc: SlenderEncounter = _enc()
	_check(not RoundManager.is_reserved(25), "Off: round 25 is not reserved")
	RoundManager.debug_set_round(25)
	await _until(func() -> bool: return RoundManager.state == RoundManager.State.ROUND, 6.0)
	await _secs(5.0)
	_check(enc == null or (enc.phase == HomageEncounter.Phase.IDLE and enc.slender() == null), "Off: no Slender on round 25")
	var full: int = RoundManager.zombie_count(25, RoundManager.players, GLData.table("rounds"))
	_check(RoundManager.round_total == full, "Off: the full horde (%d)" % RoundManager.round_total)
