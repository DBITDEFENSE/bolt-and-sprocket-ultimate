extends Node
## Headless smoke test for the boarding transition, Act I → Act II (UPDATE 07, docs/MAP4_FERNFLUG.md §10):
##   1. Campaign.begin_at(map04a_thalbach, 14, kit): Werk Thalbach loads with round 14 next, the act's own
##      numbering kept ("ACT I · 14"), the kit on the human (guns, perks, Scrip, grenades)
##   2. the console's `exfil now` (trigger_now): the Kranich ramp beacon lights before its round
##   3. the human votes: the round stops, the boarding cutscene plays (fast-forwarded), Act II loads
##   4. on the Kranich: round 15 is next after the grace and reads "ACT II · 1"; every weapon, Scrip and perk is
##      back; the bots have brains; the FlightController has its config; the autopilot cradle is due at round 20
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04_flow.tscn

const MAP_A: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const TIMEOUT: float = 300.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _expect: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4flow.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m4flow_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	Campaign.begin_at(&"map04a_thalbach", 14, {"weapons": [["kar98k", 1], ["thompson_up", 1]], "perks": ["ironhide_stout", "second_wind"], "scrip": 2500, "grenades": 2})
	Campaign.cutscene_speed = 12.0
	GameState.god_mode = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		print("[m4flow] round %d started on %s (%s) t=%.0f" % [r, GameState.map_id, RoundManager.act_label(r), _t]))
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
	print("[m4flow] %-70s %s" % [what, "PASS" if cond else "FAIL"])
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


func _run() -> void:
	await _secs(2.0)
	var map: MapRoot = _map()
	var human: Player = map.player
	_check(map != null and map.map_id == &"map04a_thalbach" and Campaign.active, "Werk Thalbach loaded in campaign mode")
	_check(RoundManager.current_round == 13 and RoundManager.state == RoundManager.State.BREAK, "begin_at 14: round 14 is next (round %d)" % RoundManager.current_round)
	_check(RoundManager.act_start == 1 and RoundManager.act_label(14) == "ACT I · 14", "a mid-act start keeps Act I's numbering (" + RoundManager.act_label(14) + ")")
	_check(human.weapons.find_weapon(&"kar98k") != null and human.weapons.find_weapon(&"thompson_up") != null, "the kit's guns are on the human")
	_check(Economy.get_scrip(1) == 2500, "the kit's Scrip (%d)" % Economy.get_scrip(1))
	_check(PerkManager.owned(1).has(&"ironhide_stout") and PerkManager.owned(1).has(&"second_wind"), "the kit's perks (%s)" % str(PerkManager.owned(1)))
	_check(human.weapons.grenades == 2, "the kit's grenades (%d)" % human.weapons.grenades)
	_check(Campaign.pending_start_for(&"map04a_thalbach").is_empty(), "the pending start is consumed")
	var x: ExfilPoint = _exfil()
	_check(x != null and x.state == ExfilPoint.State.DORMANT and x.next_round() == 15, "the ramp beacon is dormant, due at round 15")
	_check(map.players.size() == 4 and get_tree().get_nodes_in_group(&"bots").size() == 3, "1 human + 3 bots")

	# ---- `exfil now`, during round 14 (the squad leaves on 14, so the Kranich's act counts from 15)
	RoundManager.break_left = 0.5
	var r14: bool = await _until(func() -> bool: return RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.ROUND, 10.0)
	_check(r14, "round 14 began")
	RoundManager.stop()
	map.director.kill_all(true)
	for d: Node in get_tree().get_nodes_in_group(&"doors"):   # by round 14 the squad has bought its way to the hangar
		(d as BuyDoor).open(0)
	await _frames(2)
	_check(GameState.is_zone_open(&"H_HALLE"), "the hangar is open")
	for n: Node in get_tree().get_nodes_in_group(&"exfil_points"):
		n.call("trigger_now")
	await _frames(2)
	_check(x.is_active(), "trigger_now lit the beacon before its round (window %d s)" % int(x.window_left))

	# ---- the vote
	var front: Vector3 = x.global_position + x.global_basis * Vector3(0, 0, -1.6)
	human.global_position = front
	human.velocity = Vector3.ZERO
	await _frames(3)
	_check(x.can_interact(human) and x.get_prompt(human).begins_with("Hold ["), "beacon prompt: %s" % x.get_prompt(human))
	for pid: Variant in map.players.keys():
		var p: Player = map.players[pid] as Player
		_expect[int(pid)] = {"weapons": _loadout(p), "scrip": Economy.get_scrip(int(pid)), "perks": PerkManager.owned(int(pid)).duplicate(), "grenades": p.weapons.grenades}
	print("[m4flow] the human boards with %s, %d Scrip" % [str(_expect[1]["weapons"]), int(_expect[1]["scrip"])])
	human.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING and x.cutscene != null and is_instance_valid(x.cutscene), "the vote passed: the boarding cutscene plays")
	_check(RoundManager.state == RoundManager.State.IDLE and GameState.input_blocked, "the round loop stopped, players frozen")
	var swapped: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == &"map04b_kranich" and m.is_node_ready(), 90.0)
	_check(swapped, "der Kranich loaded after the cutscene")
	if not swapped:
		_finish()
		return

	# ---- Act II arrival
	await _secs(2.0)
	map = _map()
	human = map.player
	_check(Campaign.active and Campaign.carry.is_empty(), "carry consumed on arrival")
	_check(not GameState.input_blocked, "input unblocked on the Kranich")
	_check(RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.BREAK, "Act II starts at the end of round 14 (grace), round 15 next")
	_check(RoundManager.act_start == 15 and RoundManager.act_label(15) == "ACT II · 1", "round 15 reads 'ACT II · 1' (" + RoundManager.act_label(15) + ")")
	_check(map.players.size() == 4 and get_tree().get_nodes_in_group(&"bots").size() == 3, "the same squad boarded (1 human + 3 bots)")
	_check(map.squad != null and map.squad.brains.size() == 3, "bots have brains on the Kranich")
	for pid2: Variant in _expect.keys():
		var e: Dictionary = _expect[pid2]
		var p2: Player = map.players.get(int(pid2)) as Player
		if p2 == null:
			_fails.append("player %d missing on the Kranich" % int(pid2))
			continue
		if p2.is_bot:
			_check(_loadout(p2).size() == (e["weapons"] as Array).size(), "P%d (bot) carries the same guns" % int(pid2))
		else:
			_check(_loadout(p2) == e["weapons"], "P%d weapons + ammo carried: %s" % [int(pid2), str(_loadout(p2))])
		_check(Economy.get_scrip(int(pid2)) == int(e["scrip"]), "P%d Scrip carried (%d)" % [int(pid2), Economy.get_scrip(int(pid2))])
		_check(PerkManager.owned(int(pid2)) == e["perks"], "P%d perks carried (%s)" % [int(pid2), str(PerkManager.owned(int(pid2)))])
		_check(p2.weapons.grenades == int(e["grenades"]), "P%d grenades carried" % int(pid2))
	var fc: FlightController = map.get_node_or_null("Gameplay/FlightController") as FlightController
	_check(fc != null and not fc.cfg.is_empty() and fc.racks.size() == 6, "the FlightController is armed (config, six racks)")
	var x2: ExfilPoint = _exfil()
	_check(x2 != null and x2.state == ExfilPoint.State.DORMANT and x2.next_round() == 20, "the autopilot cradle is dormant, due at round 20 (%s)" % (str(x2.next_round()) if x2 != null else "none"))
	_check(ProfileSave.is_map_unlocked(&"map04b_kranich"), "profile: the Kranich unlocked by the boarding")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[m4flow] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
