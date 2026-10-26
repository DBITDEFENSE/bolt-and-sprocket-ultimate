extends Node
## Headless smoke test for Map 4's main egg "Kündigung" across the four acts (UPDATE 07, docs/MAP4_FERNFLUG.md
## §9; T-114, T-115), played the way a squad would, by console where a human would hold a key:
##   1. Werk Thalbach in campaign mode: the egg and Jette's side egg load; s1 (power) is the only open step
##   2. the Hauptschalter: s1 done, s2 (files) and s4 (tunnel) open; the three files spell the seeded extension
##      in order and raise file_1..3; s3 opens
##   3. the canteen's PA board: a wrong digit resets the line, the six right ones open Wittkamp's line
##      (hangar_code_known)
##   4. the wind tunnel: kills in the test section count only while the fan runs; the count completes s4 and
##      grants Skyhook tier II for the match
##   5. the Kranführer: killed on the rails he keeps the key (the step stays open); parked over the ramp
##      (flag under_ramp) his death hands the hangar key
##   6. Jette's logbook: the three glider models and the office hatch (the side egg completes, the Archive entry)
##   7. the ramp switch: locked until key + code, then it lights the beacon before its round; the squad boards
##   8. der Kranich: the carry brings s1-s6 done, s7a/s7 open and the same code; the three crew tags; the London
##      window is fired by the egg (act_event) and completes s8; the bomb run follows (s9), the Bordwart over
##      his station (s7); the autopilot step lights the cradle, the rip-out completes s10; the crash
##   9. Groom Lake (T-115): the carry brings s1-s10 done, Dee's radio (s11a) and the Lodestone (s12) open; her radio;
##      the core to the hatch and Peg's choice (keep: peg_resigned completes s11b, an `any` step); the Lodestone's
##      parts and the workbench (s12); Fasbender's numbers (s12b); the Test Pilot caught once by a stagger in the air
##      (slammed_once) and killed (s13); the silo console's key and burn (s14, rocket_ready); the lift; the launch
##  10. Mondlicht: the yard's airlock (s15a, a `zone` step); the three columns read (s15, an `all` step) and the
##      Account (s16); the Manager escalates (s17); the smile at the rim (the side egg); `cancel now` (s18): the
##      quest completes with its profile rewards (card, mutator, title, dossier page, Archive) and the ending runs
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04_egg.tscn

const MAP_A: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const QID: StringName = &"map04_kuendigung"
const SIDE: StringName = &"map04a_jette"
const TIMEOUT: float = 1200.0
const LAB_Y: float = -6.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _london_done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4egg.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m4egg_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"wren"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	QuestManager.match_seed = 20260704
	Campaign.begin_at(&"map04a_thalbach", 10, {"weapons": [["kar98k", 1], ["thompson_up", 1]], "perks": ["ironhide_stout"], "scrip": 5000, "grenades": 2})
	Campaign.cutscene_speed = 12.0
	GameState.god_mode = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		print("[m4egg] round %d started on %s (%s) t=%.0f" % [r, GameState.map_id, RoundManager.act_label(r), _t]))
	GLBus.quest_step_completed.connect(func(q: StringName, s: StringName) -> void:
		print("[m4egg] step done: %s/%s t=%.0f" % [q, s, _t]))
	GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
		if f == &"london_window_done" and bool(v):
			_london_done = true)
	var map: Node3D = (load(MAP_A) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	get_tree().set_deferred("current_scene", map)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	print("[m4egg] %-78s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _map() -> MapRoot:
	return get_tree().current_scene as MapRoot


func _g(path: String) -> Node:
	return _map().get_node_or_null("Gameplay/" + path)


func _exfil() -> ExfilPoint:
	return get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _tp(p: Player, pos: Vector3, yaw: float = 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


func _status(sid: StringName) -> String:
	return QuestManager.status(QID, sid)


## A plain zombie stood at `pos` (physics off so it stays put), spawned by the director.
func _zombie_at(dir: ZombieDirector, pos: Vector3) -> Zombie:
	dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = dir.active_zombies()
	if zs.is_empty():
		return null
	var z: Zombie = zs[zs.size() - 1]
	z.global_position = pos
	z.set_physics_process(false)
	await _frames(2)
	return z


func _end_screen() -> Node:
	var m: MapRoot = _map()
	if m == null:
		return null
	for c: Node in m.get_children():
		if c is CampaignEndScreen:
			return c
	return null


func _run() -> void:
	await _secs(2.0)
	var map: MapRoot = _map()
	var human: Player = map.player
	var dir: ZombieDirector = map.director
	# ---- 1. the load
	_check(map != null and map.map_id == &"map04a_thalbach" and Campaign.active, "Werk Thalbach loaded in campaign mode")
	_check(QuestManager.has_quest(QID) and QuestManager.has_quest(SIDE), "the egg and Jette's side egg are loaded")
	_check(_status(&"s1_power") == "active" and _status(&"s2_files") == "locked" and _status(&"s4_tunnel") == "locked", "s1 (power) is the only open step")
	_check(QuestManager.status(SIDE, &"s1_models") == "active", "Jette's models are collectable from the start")
	var code: String = str(QuestManager.random_value(QID, "files"))
	_check(code.length() == 6 and code.is_valid_int(), "the hangar extension is six seeded digits (%s)" % code)
	RoundManager.stop()
	dir.kill_all(true)
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(0)
	await _frames(2)
	_check(GameState.is_zone_open(&"F_WINDKANAL") and GameState.is_zone_open(&"H_HALLE"), "every door opened by console (the egg's rooms)")

	# ---- 2. the power
	var tunnel: WindTunnel = _g("WindTunnel") as WindTunnel
	_check(tunnel != null and not tunnel.can_interact(human) and tunnel.get_prompt(human).contains("power"), "the fan waits for the works' power (" + (tunnel.get_prompt(human) if tunnel != null else "none") + ")")
	(_g("Hauptschalter")).call("run_sequence", 1)
	var powered: bool = await _until(func() -> bool: return GameState.power_on, 20.0)
	_check(powered, "the Hauptschalter ran")
	await _secs(0.5)
	_check(_status(&"s1_power") == "complete" and _status(&"s2_files") == "active" and _status(&"s4_tunnel") == "active", "s1 done: the files and the tunnel are open")
	# the files, in order
	var files: Array = [_g("File1") as QuestNote, _g("File2") as QuestNote, _g("File3") as QuestNote]
	var spelled: String = ""
	for i: int in 3:
		var f: QuestNote = files[i]
		if f == null:
			_fails.append("File%d missing" % (i + 1))
			continue
		spelled += f.text_now()
		_check(f.get_prompt(human).contains("read the file"), "File%d prompt: %s" % [i + 1, f.get_prompt(human)])
		f.interact(human)
		await _frames(2)
		var got: Array = QuestManager.progress(QID, &"s2_files") if QuestManager.progress(QID, &"s2_files") is Array else []
		_check(GameState.has_flag(StringName("file_%d" % (i + 1))) and (got.has(StringName("file_%d" % (i + 1))) or i == 2), "File%d raised its flag and counted (%s)" % [i + 1, str(got)])
	_check(spelled == code, "the three files spell the extension in order (%s = %s)" % [spelled, code])
	_check(_status(&"s2_files") == "complete" and _status(&"s3_pa_line") == "active", "s2 done: the PA line is open")

	# ---- 3. the PA board
	var board: Switchboard = _g("PASwitchboard") as Switchboard
	_check(board != null and board.can_interact(human) and board.get_prompt(human).begins_with("Hold ["), "the canteen's PA board is live (" + (board.get_prompt(human) if board != null else "none") + ")")
	var wrong: int = (int(code[0]) + 1) % 10
	_check(board.plug(wrong) == "wrong", "a wrong first digit is refused")
	_check(board.plug(int(code[0])) == "ok", "the first digit")
	_check(board.plug((int(code[1]) + 1) % 10) == "wrong" and int(QuestManager.progress(QID, &"s3_pa_line")) == 0, "a wrong second digit resets the line")
	var last: String = ""
	for c: String in code:
		last = board.plug(int(c))
	_check(last == "done" and _status(&"s3_pa_line") == "complete", "the six digits in order open Wittkamp's line")
	_check(GameState.has_flag(&"hangar_code_known"), "flag hangar_code_known")

	# ---- 4. the wind tunnel
	var need: int = QuestManager.kill_target(QuestManager.step_def(QID, &"s4_tunnel"))
	_check(need == 20 + 5 * 3, "the tunnel asks %d kills for 1 human + 3 bots" % need)
	var in_tunnel: Vector3 = Vector3(20, 0.2, 115)
	var z0: Zombie = await _zombie_at(dir, in_tunnel)
	_check(z0 != null and ZoneVolume.zone_at(get_tree(), in_tunnel) == &"F_WINDKANAL", "the test section is in F_WINDKANAL")
	if z0 != null:
		z0.take_damage(z0.hp + 1000.0, &"torso", &"kar98k", 1, &"bullet")
		z0.set_physics_process(true)   # let the body finish dying and go back to the pool
		await _frames(2)
		_check(QuestManager.progress(QID, &"s4_tunnel") == null, "a kill with the fan off does not count")
	_check(tunnel.can_interact(human), "with the power on the fan can run")
	tunnel.start_run()
	await _frames(2)
	_check(GameState.has_flag(&"tunnel_running") and GameState.has_flag(&"tunnel_ran") and tunnel.get_prompt(human).contains("running"), "the fan runs (flags tunnel_running, tunnel_ran)")
	await _tp(human, Vector3(10, 0.2, 115), -90.0)
	var x0: float = human.global_position.x
	await _secs(1.0)
	_check(human.global_position.x > x0 + 0.5, "the wind pushes the player down the tunnel (%.1f -> %.1f)" % [x0, human.global_position.x])
	await _tp(human, Vector3(20, 0.2, 124), 0.0)
	var tries: int = 0
	var used: Dictionary = {}
	while _status(&"s4_tunnel") == "active" and tries < need * 4:
		tries += 1
		if tunnel.running < 5.0:   # keep the fan on for the whole count
			tunnel.running = tunnel.run_seconds
		dir.debug_spawn(1)
		await _frames(2)
		var z: Zombie = null
		for c: Zombie in dir.active_zombies():
			if c != null and is_instance_valid(c) and c.is_active() and not used.has(c.get_instance_id()):
				z = c
		if z == null:   # the pool is out of bodies: the corpses dissolve under pool pressure in a second or two
			await _secs(1.0)
			continue
		used[z.get_instance_id()] = true
		z.set_physics_process(false)
		z.global_position = in_tunnel + Vector3(randf_range(-4, 4), 0, randf_range(-1, 1))
		await _frames(1)
		if ZoneVolume.zone_at(get_tree(), z.global_position) != &"F_WINDKANAL":
			continue
		z.take_damage(z.hp + 1000.0, &"torso", &"kar98k", 1, &"bullet")
		z.set_physics_process(true)   # the body finishes dying and returns to the pool (the pool is finite)
		await _frames(1)
		if tries % 10 == 0:
			await _secs(1.0)
	await _frames(2)
	_check(_status(&"s4_tunnel") == "complete", "%d kills while the fan ran complete s4 (progress %s, %d spawns)" % [need, str(QuestManager.progress(QID, &"s4_tunnel")), tries])
	_check(int(GameState.flags.get(&"perk_tier_free_skyhook_sekt", 0)) == 2, "Skyhook Sekt tier II is free for the match")
	dir.kill_all(true)
	tunnel.running = 0.0
	tunnel.cooldown = 0.0
	GameState.set_flag(&"tunnel_running", false)

	# ---- 5. the Kranführer
	_check(_status(&"s5_kranfuehrer") == "active", "s5 (the crane driver) is open after the files")
	var ramp_switch: QuestInteract = _g("RampSwitch") as QuestInteract
	_check(ramp_switch != null and not ramp_switch.can_interact(human) and ramp_switch.get_prompt(human) == "", "the ramp switch says nothing while its step is locked")
	var halle: Vector3 = Vector3(-20, 0.2, 180)
	_check(ZoneVolume.zone_at(get_tree(), halle) == &"H_HALLE", "the hangar floor is H_HALLE")
	var kf: HomageBoss = dir.summon_boss(&"kranfuehrer", halle) as HomageBoss
	await _frames(2)
	_check(kf != null and kf.is_active(), "the Kranführer is summoned by console")
	if kf != null:
		kf.set_physics_process(false)
		kf.global_position = halle
		GameState.set_flag(&"under_ramp", false)
		kf.debug_kill(1)
		await _secs(0.5)
		_check(_status(&"s5_kranfuehrer") == "active" and not GameState.has_flag(&"hangar_key"), "killed on the rails: no key, the step stays open")
		kf = dir.summon_boss(&"kranfuehrer", halle) as HomageBoss
		await _frames(2)
		kf.set_physics_process(false)
		kf.global_position = halle
		GameState.set_flag(&"under_ramp")   # what his park phase sets (kranfuehrer.gd PARK_TELEGRAPH)
		kf.debug_kill(1)
		await _secs(0.5)
		_check(_status(&"s5_kranfuehrer") == "complete" and GameState.has_flag(&"hangar_key"), "killed over the ramp: THE HANGAR KEY")
	dir.kill_all(true)
	# the switch's locked prompt names what is missing
	GameState.flags.erase(&"hangar_key")
	_check(_status(&"s6_board") == "active" and not ramp_switch.can_interact(human) and ramp_switch.get_prompt(human) == "The ramp is locked: it needs the hangar key", "without the key the switch says so (" + ramp_switch.get_prompt(human) + ")")
	GameState.set_flag(&"hangar_key")

	# ---- 6. Jette's logbook (the side egg)
	for n: String in ["Glider1", "Glider2", "Glider3"]:
		var g: QuestNote = _g(n) as QuestNote
		if g == null:
			_fails.append(n + " missing")
			continue
		g.interact(human)
		await _frames(1)
	_check(QuestManager.is_step_done(SIDE, &"s1_models"), "the three glider models are on the desk list")
	var hatch: QuestInteract = _g("JetteHatch") as QuestInteract
	_check(hatch != null and hatch.can_interact(human), "the office hatch opens with the models")
	hatch.interact(human)
	await _frames(2)
	_check(QuestManager.is_complete(SIDE), "Jette's side egg is complete")
	PerkManager.grant(1, &"skyhook_sekt")
	_check(PerkManager.has_perk(1, &"skyhook_sekt") and PerkManager.tier_of(1, &"skyhook_sekt") >= 2, "a Skyhook bought now pours at tier II (tier %d)" % PerkManager.tier_of(1, &"skyhook_sekt"))

	# ---- 7. the ramp switch and the boarding
	var x: ExfilPoint = _exfil()
	_check(x != null and x.state == ExfilPoint.State.DORMANT, "the ramp beacon is still dormant (round %d)" % RoundManager.current_round)
	_check(_status(&"s6_board") == "active" and ramp_switch.can_interact(human) and ramp_switch.get_prompt(human).begins_with("Hold ["), "with key and code the ramp switch is live (" + ramp_switch.get_prompt(human) + ")")
	ramp_switch.interact(human)
	await _frames(2)
	_check(_status(&"s6_board") == "complete", "s6 done: the ramp is down")
	_check(x.is_active(), "the egg lit the beacon before its round (window %d s)" % int(x.window_left))
	var snap: Dictionary = QuestManager.carry_snapshot(&"map04b_kranich")
	_check(snap.has(String(QID)) and (snap[String(QID)]["done"] as Array).size() == 6, "the carry holds the six Act I steps")
	await _tp(human, x.global_position + x.global_basis * Vector3(0, 0, -1.6), 0.0)
	_check(x.can_interact(human), "beacon prompt: %s" % x.get_prompt(human))
	human.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING, "the vote passed: the boarding cutscene plays")
	var swapped: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == &"map04b_kranich" and m.is_node_ready(), 90.0)
	_check(swapped, "der Kranich loaded after the cutscene")
	if not swapped:
		_finish()
		return

	# ---- 8. der Kranich
	await _secs(2.0)
	map = _map()
	human = map.player
	dir = map.director
	_check(QuestManager.has_quest(QID), "the egg is loaded on the Kranich")
	_check(_status(&"s6_board") == "complete" and _status(&"s7a_crew_tags") == "active" and _status(&"s7_bordwart") == "active" and _status(&"s8_london") == "locked", "the carry: s1-s6 done, the tags and the engineer open")
	_check(str(QuestManager.random_value(QID, "files")) == code, "the same extension on the Kranich")
	_check(GameState.has_flag(&"hangar_code_known") and GameState.has_flag(&"hangar_key"), "the carried flags are back (hangar_code_known, hangar_key)")
	_check(not GameState.has_flag(&"tunnel_running"), "the works' own flags stayed behind")
	RoundManager.stop()
	dir.kill_all(true)
	for d2: Node in get_tree().get_nodes_in_group(&"doors"):
		(d2 as BuyDoor).open(0)
	await _frames(2)
	for n2: String in ["Tag1", "Tag2", "Tag3"]:
		var tg: QuestNote = _g(n2) as QuestNote
		if tg == null:
			_fails.append(n2 + " missing")
			continue
		_check(tg.get_prompt(human).contains("take the tag"), "%s prompt: %s" % [n2, tg.get_prompt(human)])
		tg.interact(human)
		await _frames(1)
	_check(_status(&"s7a_crew_tags") == "complete" and _status(&"s8_london") == "active", "three tags: s7a done, the London window step is open")
	var fc: FlightController = _g("FlightController") as FlightController
	var started: bool = await _until(func() -> bool: return fc != null and fc.london_started, 6.0)
	_check(started, "the egg fired the London window (act_event, 2 s)")
	var back: bool = await _until(func() -> bool: return _london_done, 40.0)
	_check(back and GameState.has_flag(&"london_seen"), "the window finished at cutscene speed: london_seen")
	_check(_status(&"s8_london") == "complete" and _status(&"s9_bomb_run") == "active", "s8 done, the bomb run step is open")
	# the Bordwart over his station, meanwhile
	var station: Vector3 = Vector3(-72, 0.2, 38)
	_check(ZoneVolume.zone_at(get_tree(), station) == &"D_TRIEBWERK", "his station is D_TRIEBWERK")
	var bw: HomageBoss = dir.summon_boss(&"bordwart", station) as HomageBoss
	await _frames(2)
	_check(bw != null and bw.is_active(), "the Bordwart is summoned by console")
	if bw != null:
		bw.set_physics_process(false)
		bw.global_position = station
		bw.debug_kill(1)
		await _secs(0.6)
		_check(_status(&"s7_bordwart") == "complete" and GameState.has_flag(&"autopilot_key"), "killed at his station: s7 done, the autopilot key dropped")
	dir.kill_all(true)
	# the bomb run: the egg fires it 60 s after the window
	var run: bool = await _until(func() -> bool: return fc.run_on, 75.0)
	_check(run, "the egg fired the bomb run (act_event, 60 s) t=%.0f" % _t)
	var jammed: int = 0
	for r: Node in fc.racks:
		if jammed < 2 and int(r.get("state")) == BombRack.R.ARMED:
			r.call("jam", 1)
			jammed += 1
	var t3: float = 0.0
	while t3 < 40.0 and not fc.run_done:
		fc.run_t = 1000.0
		await _secs(0.5)
		t3 += 0.5
	_check(fc.run_done and GameState.has_flag(&"bomb_run_done"), "the run finished (%s)" % str(fc.rack_results))
	await _frames(2)
	_check(_status(&"s9_bomb_run") == "complete" and _status(&"s10_autopilot") == "active", "s9 done: the autopilot step is open")
	# ---- the autopilot
	x = _exfil()
	_check(x != null and x.is_active(), "s10's start lit the cradle early")
	await _tp(human, x.global_position + x.global_basis * Vector3(0, 0, -1.6), 0.0)
	_check(x.can_interact(human) and x.get_prompt(human).contains("unlock"), "with the key: the unlock stage (" + x.get_prompt(human) + ")")
	human.use_interactable(x)
	await _frames(2)
	_check(GameState.has_flag(&"autopilot_unlocked") and x.state == ExfilPoint.State.ACTIVE, "autopilot_unlocked; the rip-out vote waits")
	human.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING, "the vote passed: the crash cutscene plays")
	_check(GameState.has_flag(&"autopilot_ripped") and _status(&"s10_autopilot") == "complete", "the exfil's done_flag completed s10")
	for sid: String in ["s1_power", "s2_files", "s3_pa_line", "s4_tunnel", "s5_kranfuehrer", "s6_board", "s7a_crew_tags", "s7_bordwart", "s8_london", "s9_bomb_run", "s10_autopilot"]:
		if _status(StringName(sid)) != "complete":
			_fails.append(sid + " not complete after the rip-out")
	_check(_status(&"s11a_dee") == "active" and _status(&"s12_lodestone") == "active" and _status(&"s11b_choice") == "locked", "Acts I-II done: Dee's radio and the Lodestone are the open steps")
	var has_c: bool = Campaign.scene_exists(&"map04c_groomlake")
	print("[m4egg] Act III scene present: %s" % str(has_c))
	if not has_c:
		var ended: bool = await _until(func() -> bool: return _end_screen() != null, 90.0)
		_check(ended, "no Act III in this build: the 'campaign continues' screen showed after the crash")
		_finish()
		return
	var to_c: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == &"map04c_groomlake" and m.is_node_ready(), 90.0)
	_check(to_c, "Groom Lake loaded after the crash")
	if not to_c:
		_finish()
		return
	await _secs(2.5)

	# ---- 9. Groom Lake
	map = _map()
	human = map.player
	dir = map.director
	_check(QuestManager.has_quest(QID) and _status(&"s10_autopilot") == "complete" and _status(&"s11a_dee") == "active", "the egg's progress reached Act III")
	_check(QuestManager.has_quest(&"map04c_cage"), "Dee's yard rule is loaded with the act")
	RoundManager.stop()
	dir.kill_all(true)
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(0)
	await _frames(3)
	_check(GameState.is_zone_open(&"F_LAB") and GameState.is_zone_open(&"G_SILO"), "every door opened by console (the lab and the silo)")
	var dee: StoryRadio = _g("DeeRadio") as StoryRadio
	await _tp(human, Vector3(60.0, 0.2, 96.0), 90.0)
	_check(dee != null and dee.can_interact(human), "Dee's radio takes the call")
	human.use_interactable(dee)
	await _frames(3)
	_check(_status(&"s11a_dee") == "complete" and _status(&"s11b_choice") == "active" and _status(&"s12b_burn") == "active", "s11a done: the choice and Fasbender's burn open")
	# the core: the human carries it to the hatch, Peg's choice by console (keep)
	var core: CarryObject = _g("ImpellerCore") as CarryObject
	await _tp(human, Vector3(20.0, 0.2, 14.5), 0.0)
	human.use_interactable(core)
	await _frames(3)
	_check(core != null and core.carrier == 1, "the human carries the core")
	var cradle: CarryCradle = _g("HangarCradle") as CarryCradle
	await _tp(human, Vector3(38.0, 0.2, 96.0), -90.0)
	human.use_interactable(cradle)
	await _frames(3)
	var pc: PegsChoice = get_tree().root.get_node_or_null("PegsChoice") as PegsChoice
	_check(pc != null and cradle.deciding, "the choice is open at the hatch")
	if pc != null:
		pc.choose("keep")
		await _frames(3)
	_check(GameState.has_flag(&"peg_resigned") and _status(&"s11b_choice") == "complete", "keep: peg_resigned completes s11b (any of the two flags)")
	# the power (the radar radio needs it), then the Lodestone
	(_g("Generator")).call("run_sequence", 1)
	var powered_c: bool = await _until(func() -> bool: return GameState.power_on, 20.0)
	_check(powered_c, "the generator ran")
	dir.kill_all(true)
	var live: Dictionary = {}
	for n3: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
		var bp: BuildablePart = n3 as BuildablePart
		if bp.buildable_id == &"lodestone" and bp._live:
			live[bp.part_id] = bp
	_check(live.size() == 3, "three Lodestone parts live (%d)" % live.size())
	for pid: Variant in live.keys():
		var bp2: BuildablePart = live[pid]
		await _tp(human, bp2.global_position + Vector3(0.8, 0.2, 0), 0.0)
		human.use_interactable(bp2)
		await _frames(2)
	var wb: Workbench = _g("Workbench") as Workbench
	await _tp(human, Vector3(-60.0, LAB_Y + 0.2, 116.0), 180.0)
	human.use_interactable(wb)
	await _frames(3)
	_check(wb != null and wb.built and _status(&"s12_lodestone") == "complete", "the Lodestone built: s12 done")
	human.use_interactable(wb)
	await _frames(2)
	_check(_status(&"s13_testpilot") == "active", "the Test Pilot step opens with the weapon")
	# Fasbender's numbers
	var rr: StoryRadio = _g("RadarRadio") as StoryRadio
	await _tp(human, Vector3(62.0, 0.2, 125.5), 0.0)
	human.use_interactable(rr)
	await _frames(3)
	_check(GameState.has_flag(&"burn_known") and _status(&"s12b_burn") == "complete", "Fasbender's radio: burn_known completes s12b")
	# the Test Pilot: caught once by a lift (a stagger in the air), then killed
	var tp: TestPilot = dir.summon_boss(&"testpilot", Vector3.ZERO) as TestPilot
	_check(tp != null and tp.is_active(), "the Test Pilot is summoned by console")
	if tp != null:
		await _tp(human, Vector3(-40.0, LAB_Y + 0.2, 122.0), 0.0)
		var air: bool = await _until(func() -> bool: return tp.pstate == TestPilot.P.AIR, 25.0)
		if air:
			tp.force_stagger()
			await _frames(3)
		_check(air and GameState.has_flag(&"slammed_once"), "caught mid-leap: slammed_once (air %s)" % str(air))
		tp.set_physics_process(false)
		tp.debug_kill(1)
		await _secs(0.6)
		_check(_status(&"s13_testpilot") == "complete" and GameState.has_flag(&"ignition_key"), "killed after the catch: s13 done, the ignition key")
	dir.kill_all(true)
	# the console: the key, then the burn
	var con: SiloConsole = _g("SiloConsole") as SiloConsole
	await _tp(human, Vector3(-58.0, LAB_Y + 0.2, 175.5), 0.0)
	_check(con != null and _status(&"s14_rocket") == "active" and con.can_interact(human), "s14 open: the console takes the key")
	human.use_interactable(con)
	await _frames(3)
	_check(GameState.has_flag(&"rocket_key_turned") and con.can_interact(human), "the key turned; the burn is known: the burn stage")
	human.use_interactable(con)
	await _frames(3)
	x = _exfil()
	_check(GameState.has_flag(&"rocket_ready") and _status(&"s14_rocket") == "complete" and x != null and x.is_active(), "rocket_ready completes s14 and lights the lift")
	await _tp(human, x.global_position + x.global_basis * Vector3(0, 0, -1.6), 0.0)
	human.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING, "the vote passed: the launch cutscene plays")
	var has_d: bool = Campaign.scene_exists(&"map04d_mondlicht")
	print("[m4egg] Act IV scene present: %s" % str(has_d))
	if not has_d:
		_finish()
		return
	var to_d: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == &"map04d_mondlicht" and m.is_node_ready(), 90.0)
	_check(to_d, "Mondlicht loaded after the launch")
	if not to_d:
		_finish()
		return
	await _secs(2.5)

	# ---- 10. Mondlicht
	map = _map()
	human = map.player
	dir = map.director
	_check(_status(&"s14_rocket") == "complete" and _status(&"s15a_yard") == "active", "the egg's progress reached the Moon: the yard step is open")
	_check(GameState.has_flag(&"peg_resigned") and GameState.has_flag(&"burn_known"), "peg_* and burn_known were carried up")
	RoundManager.stop()
	dir.kill_all(true)
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		if (d as BuyDoor).door_id == &"door_concourse" or (d as BuyDoor).door_id == &"door_yard":
			(d as BuyDoor).open(0)
	await _frames(3)
	_check(GameState.is_zone_open(&"C_YARD") and _status(&"s15a_yard") == "complete", "the airlock opened: the zone step completes s15a")
	for d: Node in get_tree().get_nodes_in_group(&"doors"):
		(d as BuyDoor).open(0)
	await _frames(3)
	var cols: Array[Node] = get_tree().get_nodes_in_group(&"retention_columns")
	cols.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("index")) < int(b.get("index")))
	_check(cols.size() == 3 and _status(&"s15_columns") == "active", "three columns, the read step open")
	(cols[0] as RetentionColumn).read_terms(1)
	(cols[1] as RetentionColumn).read_terms(1)
	await _secs(1.0)
	_check(_status(&"s15_columns") == "active", "two dark: the `all` step waits for the third")
	(cols[2] as RetentionColumn).read_terms(1)
	await _secs(1.5)
	_check(_status(&"s15_columns") == "complete" and GameState.has_flag(&"account_open") and _status(&"s16_account") == "complete", "three dark: s15 and the Account (s16) done")
	# the Manager escalates
	var ctl: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
	GameState.open_zone(&"F_CORE")
	dir.recompute_nav_mask()
	var am_up: bool = await _until(func() -> bool: return ctl != null and ctl.get("boss") != null, 12.0)
	var am: Node = ctl.get("boss") if ctl != null else null
	_check(am_up and am != null, "the Account Manager attends the open Account")
	if am != null:
		await _tp(human, Vector3(28, 0.2, -26), 180.0)
		await _secs(1.0)
		am.set("presenting", 0.0)
		am.call("take_damage", float(am.get("max_hp")) * 2.0, &"torso", &"console", 1, &"world")
		await _frames(3)
	_check(GameState.has_flag(&"manager_escalated") and _status(&"s17_manager") == "complete", "she escalates: s17 done, the cancel step opens")
	# the smile at the rim (the side egg)
	var marker: QuestInteract = _g("SmileMarker") as QuestInteract
	await _tp(human, Vector3(0.0, 0.2, 102.5), 0.0)
	_check(marker != null and QuestManager.has_quest(&"map04d_smile") and marker.can_interact(human), "the rim marker is live in the vacuum")
	if marker != null:
		marker.interact(human)
		await _frames(3)
	_check(QuestManager.is_complete(&"map04d_smile") and (ProfileSave.profile.get("charms", []) as Array).has("mondstein"), "the smile seen: the Mondstein charm")
	# cancel now
	var out: String = GLConsole.run("cancel now")
	print("[m4egg] console: " + out)
	await _frames(4)
	_check(GameState.has_flag(&"cancelled") and _status(&"s18_cancel") == "complete" and QuestManager.is_complete(QID), "the key turned: s18 done, KÜNDIGUNG complete")
	var prof: Dictionary = ProfileSave.profile
	_check((prof.get("calling_cards", []) as Array).has("kuendigung") and (prof.get("mutators", []) as Array).has("low_gravity_all") and (prof.get("titles", []) as Array).has("Cancelled"), "profile: the card, the mutator, the title")
	_check(int((prof.get("dossiers", {}) as Dictionary).get("wren", 0)) >= 10 and (prof.get("intel", []) as Array).has("INT_M4_KUENDIGUNG") and (prof.get("egg_rewards", {}) as Dictionary).has("map04_kuendigung"), "profile: dossier page 10, the Archive entry, the egg reward")
	var over: bool = await _until(func() -> bool: return GameState.phase == GameState.Phase.GAME_OVER, 120.0)
	_check(over and (ProfileSave.profile.get("endings_seen", []) as Array).has("kuendigung"), "the cancel ending ran to the credits (endings_seen kuendigung)")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[m4egg] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
