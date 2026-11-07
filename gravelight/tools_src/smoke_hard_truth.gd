extends Node
## UPDATE 11 (T-192) headless smoke: Hard Truth, solo with a bot (the local co-op session). Silent, a god-mode human.
##   1. Map 0 with one bot; the rule on (auto, story rules).
##   2. The bot goes down and bleeds out: its body lies where it fell as a dormant zombie in its own risen body
##      (no hitboxes, no damage), and gets up on the fourth second of round time.
##   3. It is put down: the death crate (FallenCrate) drops where it fell, named for the bot's survivor.
##   4. The next round: the bot respawns exactly as before.
##   5. The rule off (Settings): another bleed-out leaves no body.
##   6. Map 0 / Kaltenbrunn: a few rounds' spawns include the Soviet risen (the share in data), none in the depths.
## Prints "[hard-truth] ..." and "[hard-truth] RESULT: PASS/FAIL"; exit code 0/1.

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 420.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _rt: float = 0.0   # round time (the rule's clock only runs while a round does)


func _ready() -> void:
	ProfileSave.path = "user://_qa_hard_truth_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_hard_truth_settings.cfg"
	GLSettings.values["classic_rules"] = false
	GLSettings.values["hard_truth"] = "auto"
	GLSettings.values["bot_local_ai"] = false
	GameState.bot_count = 1
	Campaign.reset()
	_run.call_deferred()


func _physics_process(delta: float) -> void:
	_t += delta
	if RoundManager.state == RoundManager.State.ROUND and not GameState.in_event():
		_rt += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(m: String) -> void:
	print("[hard-truth] " + m)


func _fail(m: String) -> void:
	_fails.append(m)
	print("[hard-truth] FAIL " + m)


func _check(c: bool, what: String) -> void:
	if c:
		_note("ok   " + what)
	else:
		_fail(what)


func _finish() -> void:
	print("[hard-truth] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), "; ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _secs(s: float) -> void:
	var end: float = _t + s
	while _t < end:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float) -> bool:
	var end: float = _t + seconds
	while _t < end:
		if pred.call():
			return true
		await get_tree().physics_frame
	return bool(pred.call())


func _root() -> MapRoot:
	return _map as MapRoot


func _bot() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		var p: Player = n as Player
		if p != null and not p.is_companion:
			return p
	return null


## Downs the bot and runs its bleed-out clock out (nobody revives: the human is idle and god-moded).
func _bleed_bot(b: Player) -> bool:
	var s: NetMatch = _root().session
	GameState.god_mode = false
	b.take_hit(99999.0, null)
	GameState.god_mode = true
	if not await _until(func() -> bool: return s.coop.is_downed(b.player_id), 5.0):
		return false
	(s.coop.players[b.player_id] as Dictionary)["bleed"] = 0.05
	(s.coop.players[b.player_id] as Dictionary)["reviver"] = 0
	return await _until(func() -> bool: return s.coop.is_dead(b.player_id), 5.0)


func _clear_round() -> void:
	for z: Zombie in _root().director.active_zombies():
		if not z.is_dormant():
			z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().session != null and _bot() != null, 40.0)
	var s: NetMatch = _root().session
	var b: Player = _bot()
	_check(s != null and s.hard_truth != null, "the local session carries the rule")
	_check(b != null, "one bot")
	if s == null or b == null or s.hard_truth == null:
		_finish()
		return
	_root().player.set_process_unhandled_input(false)
	_check(HardTruth.enabled(), "on by default in the story rules")
	await _until(func() -> bool: return RoundManager.state == RoundManager.State.ROUND, 90.0)
	await _secs(2.0)
	var ht: HardTruth = s.hard_truth
	var person: String = String(Net.character_of(b.player_id))
	# 2. the bleed-out and the body
	_check(await _bleed_bot(b), "the bot went down and bled out")
	var at: Vector3 = b.global_position
	var z: Zombie = ht.body_of(b.player_id)
	_check(z != null, "a body lies where %s fell" % person)
	if z == null:
		_finish()
		return
	_check(z.is_dormant() and z.global_position.distance_to(at) < 2.0, "dormant, at the spot (%.1f m)" % z.global_position.distance_to(at))
	_check(str(z.get_meta("person", "")) == person or not PeopleBodies.available(person), "in %s's own risen body" % person)
	_check(z.marke_site == &"", "unmarked")
	var hp0: float = z.hp
	z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
	_check(z.hp == hp0 and z.is_active(), "it takes nothing while it lies")
	var rt0: float = _rt
	await _until(func() -> bool: return not z.is_dormant(), 30.0)
	var took: float = _rt - rt0
	_check(not z.is_dormant() and took > 3.6 and took < 4.6, "it rises on the fourth second (%.2f s of round time)" % took)
	_check(z.state == Zombie.State.GETUP, "getting up off the floor")
	await _secs(2.6)
	# 3. put down -> the death crate
	z.take_damage(99999.0, &"head", &"m1911", 1, &"bullet")
	await _until(func() -> bool: return ht.last_crate != null, 3.0)
	var c: FallenCrate = ht.last_crate
	_check(c != null and is_instance_valid(c), "putting it down drops the death crate")
	if c != null:
		_check(c.global_position.distance_to(z.global_position) < 3.0, "where it fell")
		_check(c.get_prompt(_root().player).contains(HardTruth.survivor_name(person)) or c.get_prompt(_root().player) == "Ammo full", "the crate is %s's: \"%s\"" % [person, c.get_prompt(_root().player)])
	_check(int(ht.stats["crates"]) == 1 and int(ht.stats["rises"]) == 1, "one body, one rise, one crate (%s)" % str(ht.stats))
	# 4. the next round: the respawn as before
	var r0: int = RoundManager.current_round
	var ok_round: bool = await _until(func() -> bool:
		_clear_round()
		return RoundManager.current_round > r0, 150.0)
	_check(ok_round, "the round ended and the next began")
	await _secs(1.0)
	_check(s.coop.is_alive(b.player_id) and not b.spectating, "the bot respawned at the round start, as before")
	# 5. the rule off: no body
	GLSettings.values["hard_truth"] = "off"
	var bodies0: int = int(ht.stats["bodies"])
	await _secs(2.0)
	_check(await _bleed_bot(b), "a second bleed-out")
	await _secs(1.0)
	_check(int(ht.stats["bodies"]) == bodies0 and ht.body_of(b.player_id) == null, "with Hard Truth off no body rises")
	GLSettings.values["hard_truth"] = "auto"
	# 6. the Returned in the spawn mix (Map 0 from round 2)
	var seen: Dictionary = {}
	var t_end: float = _t + 60.0
	while _t < t_end and seen.size() < 1:
		for zz: Zombie in _root().director.active_zombies():
			if ZombieBody.SOVIET_KITS.has(zz.variant_name()):
				seen[zz.get_instance_id()] = true
				_check(zz.is_wound() and zz.marke_site != &"", "a Returned carries its wound, no Marke (%s)" % zz.marke_site)
		await get_tree().physics_frame
	_check(seen.size() > 0 or RoundManager.current_round < 2, "the Soviet risen join Map 0's spawns (round %d)" % RoundManager.current_round)
	_finish()
