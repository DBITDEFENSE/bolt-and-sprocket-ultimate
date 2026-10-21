extends Node
## Headless smoke test for the campaign chain (DECISIONS T-033): a solo run with 3 bots on Map 0.
##   1. the exfil beacon exists, dormant, due at round 10; the squad is handed loot (guns with odd ammo, an
##      upgraded weapon, Scrip, perks)
##   2. round 10 starts (debug_set_round): the beacon lights, the stable's doors open for free
##   3. the human votes at the beacon: the round stops, the cutscene plays (fast-forwarded), Map 1 loads
##   4. on Map 1: round 11 is next with round-11 zombie counts, every player's weapons / ammo / upgraded state /
##      Scrip / perks are back, the bots are alive, have brains and follow; the Map 1 beacon is due at round 30
##   5. round 30: the beacon lights; the window is let run out -> missed, next at round 33; round 33: vote
##   6. the third map's scene is missing from this build: the cutscene plays, then the "campaign continues"
##      screen shows, the profile has Kaltenbrunn and Totenhafen unlocked
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_campaign.tscn
## Prints "[campaign] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 420.0

var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _expect: Dictionary = {}     # pid -> {"weapons": [[id, mag, reserve]], "scrip": int, "perks": [ids]}
var _rounds: Array[int] = []
var _ended: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_campaign_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	Campaign.begin()
	Campaign.cutscene_speed = 12.0
	GameState.god_mode = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		_rounds.append(r)
		print("[campaign] round %d started on %s (zombies %d, scaling players %d) t=%.0f" % [r, GameState.map_id, RoundManager.round_total, RoundManager.players, _t]))
	var map: Node3D = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	get_tree().set_deferred("current_scene", map)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[campaign] FAIL: ", msg)


func _check(cond: bool, what: String) -> void:
	print("[campaign] %-70s %s" % [what, "PASS" if cond else "FAIL"])
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


func _run() -> void:
	await _secs(2.0)
	var map: MapRoot = _map()
	var x: ExfilPoint = _exfil()
	_check(map != null and map.map_id == &"map00_crossroads", "Map 0 loaded in campaign mode")
	_check(x != null and x.state == ExfilPoint.State.DORMANT and x.next_round() == 10, "exfil beacon spawned, dormant, due at round 10")
	_check(x != null and x.global_position.distance_to(Vector3(18, 0, 32)) < 0.5, "beacon stands at the stable's great doors")
	_check(map.players.size() == 4 and get_tree().get_nodes_in_group(&"bots").size() == 3, "1 human + 3 bots")

	# ---- loot
	var human: Player = map.player
	human.weapons.give_weapon(&"kar98k")
	human.weapons.give_weapon(&"m1911_up")
	await _frames(2)
	for w: WeaponInstance in human.weapons.slots:
		w.mag = 2 if w.id == &"kar98k" else 3
		w.reserve = 17 if w.id == &"kar98k" else 29
	human.weapons.grenades = 1
	var bot_guns: Array = [&"mp40", &"trench_gun", &"m1_garand"]
	var i: int = 0
	for pid: int in GameState.bot_ids:
		var b: Player = map.players[pid] as Player
		b.weapons.give_weapon(bot_guns[i % bot_guns.size()])
		for w2: WeaponInstance in b.weapons.slots:
			w2.mag = 4 + i
			w2.reserve = 40 + i
		i += 1
	for pid2: int in GameState.player_ids:
		Economy.grant(pid2, 1000 + pid2 * 111)
		PerkManager.grant(pid2, &"ironhide_stout")
		if pid2 == 1:
			PerkManager.grant(pid2, &"trigger_tonic")
	await _frames(2)

	# ---- round 10: the beacon lights
	map.director.kill_all(true)
	RoundManager.debug_set_round(10)
	var lit: bool = await _until(func() -> bool: return _exfil() != null and _exfil().is_active(), 20.0)
	_check(lit, "round 10: the beacon is lit (window %d s)" % int(x.window_left))
	_check(GameState.is_zone_open(&"STABLE"), "the stable opened for free so the beacon is reachable")
	_check(_rounds.has(10), "round 10 started")

	# ---- the squad gathers, the human votes
	var front: Vector3 = x.global_position + x.global_basis * Vector3(0, 0, -1.6)
	human.global_position = front
	human.velocity = Vector3.ZERO
	var j: int = 0
	for pid3: int in GameState.bot_ids:
		var b2: Player = map.players[pid3] as Player
		b2.global_position = front + Vector3(1.2 * (j - 1), 0, -1.0)
		j += 1
	await _frames(3)
	_check(x.can_interact(human) and x.get_prompt(human).begins_with("Hold ["), "beacon prompt: %s" % x.get_prompt(human))
	_record_expectations(map)   # what everyone carries at the moment of the vote (round 10 topped up grenades / bot pistols)
	_check(_expect[1]["weapons"].size() == 2 and bool(_expect[1]["upgraded"].has(true)), "human carries two guns, one upgraded (odd ammo)")
	human.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING, "the vote passed (solo human + bots): departing")
	_check(x.cutscene != null and is_instance_valid(x.cutscene), "the transition cutscene is playing")
	_check(RoundManager.state == RoundManager.State.IDLE, "the round loop stopped for the cutscene")
	_check(not human.camera.current, "the cutscene camera took over")
	_check(GameState.input_blocked and GameState.god_mode, "players are frozen and safe")
	var swapped: bool = await _until(func() -> bool:
		var m: MapRoot = _map()
		return m != null and m.map_id == &"map01_kaltenbrunn" and m.is_node_ready(), 60.0)
	_check(swapped, "Map 1 loaded after the cutscene")
	if not swapped:
		_finish()
		return

	# ---- Map 1 arrival
	await _secs(2.0)
	map = _map()
	human = map.player
	_check(Campaign.active and Campaign.carry.is_empty(), "carry consumed on arrival")
	_check(not GameState.input_blocked, "input unblocked on the new map")
	_check(RoundManager.current_round == 10 and RoundManager.state == RoundManager.State.BREAK, "Map 1 starts at the end of round 10 (grace), round 11 next")
	_check(RoundManager.break_left > 5.0 and RoundManager.break_left <= float(Campaign.cfg()["arrival_grace_seconds"]) + 0.1, "arrival grace in effect (%.1f s)" % RoundManager.break_left)
	_check(RoundManager.next_special > 10 and RoundManager.next_boss > 10, "special/boss schedule carried past the arrival (special %d, boss %d)" % [RoundManager.next_special, RoundManager.next_boss])
	_check(map.players.size() == 4 and get_tree().get_nodes_in_group(&"bots").size() == 3, "the same squad arrived (1 human + 3 bots)")
	_check(map.squad != null and map.squad.brains.size() == 3, "bots have brains on Map 1")
	_verify_restored(map)
	var x1: ExfilPoint = _exfil()
	_check(x1 != null and x1.state == ExfilPoint.State.DORMANT and x1.next_round() == 30, "Map 1 beacon dormant, due at round 30")
	_check(ProfileSave.is_map_unlocked(&"map01_kaltenbrunn"), "profile: Kaltenbrunn unlocked by the exfil")
	RoundManager.break_left = 1.0
	var r11: bool = await _until(func() -> bool: return RoundManager.current_round == 11 and RoundManager.state == RoundManager.State.ROUND, 10.0)
	_check(r11, "round 11 began on Map 1")
	_check(RoundManager.round_total == RoundManager.zombie_count(11, RoundManager.players, GLData.table("rounds")), "round 11 has round-11 zombie count (%d for %d players)" % [RoundManager.round_total, RoundManager.players])
	await _secs(6.0)
	var near: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		var bp: Player = n as Player
		if bp.is_alive() and bp.global_position.distance_to(human.global_position) < 25.0:
			near += 1
	_check(near == 3, "bots alive and following on Map 1 (%d/3 near the human)" % near)

	# ---- round 30: miss the window once, then take the retry at 33
	map.director.kill_all(true)
	RoundManager.debug_set_round(30)
	var lit30: bool = await _until(func() -> bool: return _exfil() != null and _exfil().is_active(), 20.0)
	_check(lit30, "round 30: the Map 1 beacon is lit")
	x1 = _exfil()
	x1.window_left = 0.3
	var missed: bool = await _until(func() -> bool: return _exfil().state == ExfilPoint.State.DORMANT, 5.0)
	_check(missed and x1.attempt == 1 and x1.next_round() == 33, "window closed: campaign continues here, next chance at round 33")
	map.director.kill_all(true)
	RoundManager.debug_set_round(33)
	var lit33: bool = await _until(func() -> bool: return _exfil() != null and _exfil().is_active(), 20.0)
	_check(lit33, "round 33: the beacon is lit again")
	human.global_position = x1.global_position + x1.global_basis * Vector3(0, 0, -1.6)
	human.velocity = Vector3.ZERO
	await _frames(3)
	_record_expectations(map)   # the kit at this vote (rounds 11-33 on Map 1 topped up grenades, bots reloaded / shopped)
	human.use_interactable(x1)
	await _frames(2)
	_check(x1.state == ExfilPoint.State.DEPARTING, "voted at round 33: departing for Totenhafen")
	print("[campaign] third map scene present: %s" % str(Campaign.scene_exists(&"map02_totenhafen")))
	if Campaign.scene_exists(&"map02_totenhafen"):
		var to2: bool = await _until(func() -> bool:
			var m: MapRoot = _map()
			return m != null and m.map_id == &"map02_totenhafen" and m.is_node_ready(), 60.0)
		_check(to2, "Map 2 loaded after the cutscene")
		await _secs(2.0)
		_check(RoundManager.current_round == 33 and RoundManager.state == RoundManager.State.BREAK, "Map 2 starts after round 33")
		_verify_restored(_map())
	else:
		var ended: bool = await _until(func() -> bool: return _map() != null and _map().get_node_or_null("CampaignEndScreen") != null or _end_screen() != null, 60.0)
		_check(ended, "no third map in this build: the 'campaign continues' screen showed")
		_check(GameState.phase == GameState.Phase.GAME_OVER, "the run ended cleanly (phase GAME_OVER)")
		_check(ProfileSave.is_map_unlocked(&"map02_totenhafen"), "profile: Totenhafen unlocked by the exfil")
		_check(_map() != null and _map().map_id == &"map01_kaltenbrunn", "still on Map 1 under the end screen")
	_finish()


func _end_screen() -> Node:
	var m: MapRoot = _map()
	if m == null:
		return null
	for c: Node in m.get_children():
		if c is CampaignEndScreen:
			return c
	return null


func _record_expectations(map: MapRoot) -> void:
	var weapons: Dictionary = GLData.table("weapons")
	for pid: Variant in map.players.keys():
		var p: Player = map.players[pid] as Player
		var ws: Array = []
		var ups: Array = []
		for w: WeaponInstance in p.weapons.slots:
			ws.append([String(w.id), w.mag, w.reserve])
			ups.append(w.upgraded)
		_expect[int(pid)] = {"weapons": ws, "upgraded": ups, "scrip": Economy.get_scrip(int(pid)), "perks": PerkManager.owned(int(pid)).duplicate(),
			"grenades": p.weapons.grenades, "character": String(p.character_id)}
		print("[campaign] P%d (%s) leaves with %s, %d Scrip, perks %s" % [int(pid), p.character_id, str(ws), Economy.get_scrip(int(pid)), str(PerkManager.owned(int(pid)))])


func _verify_restored(map: MapRoot) -> void:
	var weapons: Dictionary = GLData.table("weapons")
	for pid: Variant in _expect.keys():
		var e: Dictionary = _expect[pid]
		var p: Player = map.players.get(int(pid)) as Player
		if p == null:
			_fail("player %d missing on the new map" % int(pid))
			continue
		var ws: Array = []
		var ups: Array = []
		for w: WeaponInstance in p.weapons.slots:
			ws.append([String(w.id), w.mag, w.reserve])
			ups.append(w.upgraded)
		if p.is_bot:
			# A bot may reload during the arrival grace (mag topped up from the reserve): the guns and the
			# total rounds per gun must match exactly, the mag/reserve split may not.
			_check(_totals(ws) == _totals(e["weapons"]), "P%d (bot) weapons + total rounds restored: %s" % [int(pid), str(ws)])
		else:
			_check(ws == e["weapons"], "P%d weapons + ammo restored: %s" % [int(pid), str(ws)])
		_check(ups == e["upgraded"], "P%d upgraded state restored" % int(pid))
		_check(Economy.get_scrip(int(pid)) == int(e["scrip"]), "P%d Scrip restored (%d)" % [int(pid), Economy.get_scrip(int(pid))])
		_check(PerkManager.owned(int(pid)) == e["perks"], "P%d perks restored (%s)" % [int(pid), str(PerkManager.owned(int(pid)))])
		_check(p.weapons.grenades == int(e["grenades"]), "P%d grenades restored" % int(pid))
		_check(String(p.character_id) == str(e["character"]), "P%d is still %s" % [int(pid), str(e["character"])])
		_check(p.is_alive() and not p.spectating, "P%d is alive on arrival" % int(pid))
		if p.is_bot:
			_check(p.get_node_or_null("Brain") != null, "bot P%d has its brain" % int(pid))
		if p.hp < p.max_hp - 0.5:
			_fail("P%d arrived hurt (%.0f/%.0f)" % [int(pid), p.hp, p.max_hp])
		if PerkManager.has_perk(int(pid), &"ironhide_stout") and p.max_hp < 200.0:
			_fail("P%d has Ironhide but max hp is %.0f" % [int(pid), p.max_hp])


static func _totals(ws: Array) -> Array:
	var out: Array = []
	for w: Variant in ws:
		out.append([str((w as Array)[0]), int((w as Array)[1]) + int((w as Array)[2])])
	return out


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[campaign] rounds seen: %s" % str(_rounds))
	if _fails.is_empty():
		print("[campaign] RESULT PASS")
	else:
		for f: String in _fails:
			print("[campaign] FAIL: ", f)
		print("[campaign] RESULT FAIL (%d)" % _fails.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
