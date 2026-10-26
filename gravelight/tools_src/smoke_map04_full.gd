extends Node
## Headless smoke test for the whole of Map 4 "Fernflug" in one run (UPDATE 07, T-116; docs/MAP4_FERNFLUG.md §10,
## §14): the chain of acts with the dev skips a player has, the carry at every transition, the canon ending, then
## the bad ending from a skip. Under ten minutes (the cutscenes at 12x).
##   1. Campaign.begin_at(map04a_thalbach, 14, kit): Werk Thalbach, round 14 next ("ACT I · 14"), the kit on the human
##   2. `exfil now` lights the ramp beacon early; the human votes; the boarding cutscene; der Kranich loads
##   3. Act II: the carry (every player's guns, Scrip, perks, grenades), "ACT II · 1"; the autopilot key set as the
##      Bordwart's death would; `exfil now`; the cradle's stage (hold once), then the vote (hold again); the round
##      moved to 20 first so the crash lands on round 21 ("ACT III · 1")
##   4. Act III: the carry; the rocket flags set as the console sequence would (burn_known, rocket_key_turned,
##      ignition_key, rocket_ready: rocket_ready lights the gantry lift); the vote; the launch; Mondlicht at
##      round 30 ("ACT IV · 1")
##   5. Act IV: the carried flags (autopilot_ripped, ignition_key...), the Mondlicht controller, no beacon; `cancel
##      now`: the key turns, the KÜNDIGUNG ending runs (12x) and ends on kuendigung_done + GAME_OVER
##   6. a second start: Campaign.begin_at(map04d_mondlicht, 30, the arrival kit) from the launcher's skip, `renewal
##      now`: the AUTO-RENEWAL ending, GameState.retained (the match goes on)
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04_full.tscn

const MAP_A: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const TIMEOUT: float = 560.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _expect: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4full.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m4full_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	Campaign.begin_at(&"map04a_thalbach", 14, {"weapons": [["kar98k", 1], ["thompson_up", 1]], "perks": ["ironhide_stout", "second_wind"], "scrip": 2500, "grenades": 2})
	Campaign.cutscene_speed = 12.0
	GameState.god_mode = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		print("[m4full] round %d started on %s (%s) t=%.0f" % [r, GameState.map_id, RoundManager.act_label(r), _t]))
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
	print("[m4full] %-74s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _map() -> MapRoot:
	return get_tree().current_scene as MapRoot


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


func _loadout(p: Player) -> Array:
	var ws: Array = []
	for w: WeaponInstance in p.weapons.slots:
		ws.append([String(w.id), w.mag, w.reserve, w.upgraded])
	return ws


func _snapshot(map: MapRoot) -> void:
	_expect = {}
	for pid: Variant in map.players.keys():
		var p: Player = map.players[pid] as Player
		_expect[int(pid)] = {"weapons": _loadout(p), "scrip": Economy.get_scrip(int(pid)), "perks": PerkManager.owned(int(pid)).duplicate(), "grenades": p.weapons.grenades}


func _check_carry(map: MapRoot, where: String) -> void:
	_check(Campaign.active and Campaign.carry.is_empty(), "%s: carry consumed on arrival" % where)
	_check(not GameState.input_blocked, "%s: input unblocked" % where)
	_check(map.players.size() == 4 and get_tree().get_nodes_in_group(&"bots").size() == 3 and map.squad != null and map.squad.brains.size() == 3, "%s: the same squad (1 human + 3 bots with brains)" % where)
	for pid2: Variant in _expect.keys():
		var e: Dictionary = _expect[pid2]
		var p2: Player = map.players.get(int(pid2)) as Player
		if p2 == null:
			_fails.append("%s: player %d missing" % [where, int(pid2)])
			continue
		if p2.is_bot:
			_check(_loadout(p2).size() == (e["weapons"] as Array).size(), "%s: P%d (bot) carries the same guns" % [where, int(pid2)])
		else:
			_check(_loadout(p2) == e["weapons"], "%s: P%d weapons + ammo carried: %s" % [where, int(pid2), str(_loadout(p2))])
		_check(Economy.get_scrip(int(pid2)) == int(e["scrip"]), "%s: P%d Scrip carried (%d)" % [where, int(pid2), Economy.get_scrip(int(pid2))])
		_check(PerkManager.owned(int(pid2)) == e["perks"], "%s: P%d perks carried (%s)" % [where, int(pid2), str(PerkManager.owned(int(pid2)))])
		_check(p2.weapons.grenades == int(e["grenades"]), "%s: P%d grenades carried" % [where, int(pid2)])


## Lights the beacon by console, holds it as the human (the stage first when it has one), waits for the next map.
func _vote_and_travel(map: MapRoot, target: StringName, label: String) -> bool:
	var human: Player = map.player
	var x: ExfilPoint = _exfil()
	_check(x != null and x.target_id() == target, "%s: the beacon leads to %s" % [label, target])
	if x == null:
		return false
	if not x.is_active():
		print("[m4full] console: " + GLConsole.run("exfil now", 1))
		await _frames(2)
	_check(x.is_active(), "%s: the beacon is lit (window %d s)" % [label, int(x.window_left)])
	human.global_position = x.global_position + x.global_basis * Vector3(0, 0, -1.6)
	human.velocity = Vector3.ZERO
	await _frames(3)
	_check(x.can_interact(human), "%s: the human can hold it (%s)" % [label, x.get_prompt(human)])
	if str(x.cfg.get("stage_flag", "")) != "":
		_check(x.get_prompt(human).begins_with(str(x.cfg.get("stage_prompt", "Hold")).left(4)), "%s: the stage prompt first (%s)" % [label, x.get_prompt(human)])
		human.use_interactable(x)
		await _frames(2)
		_check(GameState.has_flag(StringName(str(x.cfg["stage_flag"]))) and x.state == ExfilPoint.State.ACTIVE and x.votes.is_empty(), "%s: the first hold did the stage (%s), no vote yet" % [label, str(x.cfg["stage_flag"])])
	_snapshot(map)
	print("[m4full] the human leaves %s with %s, %d Scrip" % [map.map_id, str(_expect[1]["weapons"]), int(_expect[1]["scrip"])])
	human.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING and x.cutscene != null and is_instance_valid(x.cutscene), "%s: the vote passed, the cutscene plays (%s)" % [label, str(x.cfg.get("cutscene", ""))])
	_check(RoundManager.state == RoundManager.State.IDLE and GameState.input_blocked, "%s: the round loop stopped, players frozen" % label)
	var swapped: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == target and m.is_node_ready(), 90.0)
	_check(swapped, "%s: %s loaded after the cutscene" % [label, target])
	return swapped


func _run() -> void:
	await _secs(2.0)
	var map: MapRoot = _map()
	var human: Player = map.player
	_check(map != null and map.map_id == &"map04a_thalbach" and Campaign.active, "Act I: Werk Thalbach loaded in campaign mode")
	_check(RoundManager.current_round == 13 and RoundManager.state == RoundManager.State.BREAK, "Act I: begin_at 14: round 14 is next (round %d)" % RoundManager.current_round)
	_check(RoundManager.act_label(14) == "ACT I · 14", "Act I: a mid-act start keeps Act I's numbering (" + RoundManager.act_label(14) + ")")
	_check(human.weapons.find_weapon(&"kar98k") != null and human.weapons.find_weapon(&"thompson_up") != null and Economy.get_scrip(1) == 2500, "Act I: the kit's guns and Scrip are on the human")
	_check(PerkManager.owned(1).has(&"ironhide_stout") and PerkManager.owned(1).has(&"second_wind") and human.weapons.grenades == 2, "Act I: the kit's perks and grenades")
	_check(QuestManager.has_quest(&"map04_kuendigung"), "Act I: the main egg is loaded")
	RoundManager.break_left = 0.5
	var r14: bool = await _until(func() -> bool: return RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.ROUND, 10.0)
	_check(r14, "Act I: round 14 began")
	RoundManager.stop()
	map.director.kill_all(true)
	for d: Node in get_tree().get_nodes_in_group(&"doors"):   # by round 14 the squad has bought its way to the hangar
		(d as BuyDoor).open(0)
	await _frames(2)
	_check(GameState.is_zone_open(&"H_HALLE"), "Act I: the hangar is open")
	if not await _vote_and_travel(map, &"map04b_kranich", "Act I"):
		_finish()
		return

	# ---- Act II: der Kranich
	await _secs(2.0)
	map = _map()
	_check(RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.BREAK and RoundManager.act_start == 15, "Act II: starts at the end of round 14, round 15 next")
	_check(RoundManager.act_label(15) == "ACT II · 1", "Act II: round 15 reads 'ACT II · 1' (" + RoundManager.act_label(15) + ")")
	_check_carry(map, "Act II")
	var fc: FlightController = map.get_node_or_null("Gameplay/FlightController") as FlightController
	_check(fc != null and not fc.cfg.is_empty(), "Act II: the FlightController is armed")
	_check(QuestManager.has_quest(&"map04_kuendigung"), "Act II: the main egg carried")
	var x2: ExfilPoint = _exfil()
	_check(x2 != null and x2.state == ExfilPoint.State.DORMANT and x2.next_round() == 20, "Act II: the autopilot cradle is dormant, due at round 20")
	_check(x2 != null and not x2.can_interact(map.player), "Act II: the cradle takes the autopilot key first")
	RoundManager.debug_set_round(21)   # the crash lands on round 21: the squad leaves on round 20
	GameState.set_flag(&"autopilot_key")   # as the Bordwart's death (or the act's fallback round) sets it
	await _frames(2)
	if not await _vote_and_travel(map, &"map04c_groomlake", "Act II"):
		_finish()
		return

	# ---- Act III: Groom Lake
	await _secs(2.0)
	map = _map()
	_check(RoundManager.current_round == 20 and RoundManager.act_start == 21 and RoundManager.act_label(21) == "ACT III · 1", "Act III: round 21 reads 'ACT III · 1' (" + RoundManager.act_label(21) + ")")
	_check_carry(map, "Act III")
	_check(GameState.has_flag(&"autopilot_key") and GameState.has_flag(&"autopilot_ripped"), "Act III: the autopilot flags carried (key, ripped)")
	_check(map.get_node_or_null("Gameplay/GroomController") != null or get_tree().get_first_node_in_group(&"groom_controller") != null, "Act III: the GroomController is on the map")
	var x3: ExfilPoint = _exfil()
	_check(x3 != null and x3.state == ExfilPoint.State.DORMANT and x3.next_round() == 29, "Act III: the gantry lift is dormant, due at round 29")
	RoundManager.debug_set_round(30)   # the launch lands on round 30
	for f: StringName in [&"peg_resigned", &"burn_known", &"rocket_key_turned", &"ignition_key"]:
		GameState.set_flag(f)
	GameState.set_flag(&"rocket_ready")   # the console sequence's last flag lights the lift itself (trigger_flag)
	await _frames(2)
	_check(x3 != null and x3.is_active(), "Act III: rocket_ready lit the gantry lift before its round")
	if not await _vote_and_travel(map, &"map04d_mondlicht", "Act III"):
		_finish()
		return

	# ---- Act IV: Mondlicht
	await _secs(2.0)
	map = _map()
	_check(RoundManager.current_round == 29 and RoundManager.act_start == 30 and RoundManager.act_label(30) == "ACT IV · 1", "Act IV: round 30 reads 'ACT IV · 1' (" + RoundManager.act_label(30) + ")")
	_check_carry(map, "Act IV")
	_check(GameState.has_flag(&"ignition_key") and GameState.has_flag(&"burn_known") and GameState.has_flag(&"autopilot_ripped"), "Act IV: the carried flags (ignition_key, burn_known, autopilot_ripped)")
	_check(_exfil() == null, "Act IV: no beacon (the act ends in an ending)")
	var ctl: Node = get_tree().get_first_node_in_group(&"mondlicht_controller")
	_check(ctl != null, "Act IV: the Mondlicht controller is on the map")
	_check(is_equal_approx(GameState.gravity_scale, 0.38), "Act IV: low gravity (%.2f)" % GameState.gravity_scale)
	_check(not GameState.has_flag(&"cancelled") and not GameState.has_flag(&"renewed"), "Act IV: no ending yet")
	print("[m4full] console: " + GLConsole.run("cancel now", 1))
	await _frames(2)
	_check(GameState.has_flag(&"cancelled") and ctl != null and ctl.get("ending") != null, "Act IV: `cancel now` turned the key, the KUENDIGUNG ending runs")
	var cancelled: bool = await _until(func() -> bool: return GameState.has_flag(&"kuendigung_done"), 60.0)
	_check(cancelled, "Act IV: the canon ending finished (kuendigung_done)")
	_check(GameState.phase == GameState.Phase.GAME_OVER and RoundManager.state == RoundManager.State.IDLE, "Act IV: the run is over (GAME_OVER, the rounds stopped)")
	_check(bool(ProfileSave.profile.get("seen_kuendigung", false)), "Act IV: the profile saw the ending")

	# ---- a second start: the launcher's skip to Act IV, then the bad ending
	GameState.phase = GameState.Phase.MENU
	RoundManager.stop()
	var kit: Dictionary = Campaign.arrival_kit(&"map04d_mondlicht")
	kit["scrip"] = DevLauncher.scrip_for_round(30)
	Campaign.begin_at(&"map04d_mondlicht", 30, kit)
	get_tree().change_scene_to_file(Campaign.scene_for(&"map04d_mondlicht"))
	var fresh: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == &"map04d_mondlicht" and m.is_node_ready() and m != map, 60.0)
	_check(fresh, "skip: Mondlicht loaded again from Campaign.begin_at(30)")
	if not fresh:
		_finish()
		return
	await _secs(2.0)
	map = _map()
	_check(RoundManager.current_round == 29 and RoundManager.act_start == 30 and RoundManager.act_label(30) == "ACT IV · 1", "skip: round 30 next, 'ACT IV · 1'")
	_check(map.player.weapons.find_weapon(&"lodestone") != null and PerkManager.owned(1).has(&"skyhook_sekt"), "skip: the arrival kit (the Lodestone, Skyhook Sekt)")
	_check(Economy.get_scrip(1) == DevLauncher.scrip_for_round(30), "skip: the launcher's Scrip for round 30 (%d)" % Economy.get_scrip(1))
	_check(not GameState.has_flag(&"cancelled") and not GameState.has_flag(&"renewed") and not GameState.retained, "skip: a clean slate (no ending flags)")
	print("[m4full] console: " + GLConsole.run("renewal now", 1))
	await _frames(2)
	_check(GameState.has_flag(&"renewed"), "skip: `renewal now` runs the AUTO-RENEWAL ending")
	var retained: bool = await _until(func() -> bool: return GameState.retained, 30.0)
	_check(retained, "skip: the squad is RETAINED (the match goes on)")
	_check(GameState.phase == GameState.Phase.PLAYING, "skip: the match continues after the bad ending")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[m4full] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
