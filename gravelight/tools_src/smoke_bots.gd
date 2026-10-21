extends Node
## Headless smoke test for AI teammates (T-031): a solo match on Map 0 with 3 bots and a god-mode human standing
## at the spawn. Checks, in order:
##   1. three bot Players with distinct survivors, the offline session and revive points, scaled round size
##   2. the bots fight: rounds advance, every bot fires, the squad kills zombies, nobody drifts off or errors;
##      they shop: a bot buys a wall weapon and a bot opens a door (each bot is handed 1200 Scrip at round 2)
##   3. a bot goes down and a teammate revives it
##   4. the human goes down and a bot revives them
##   5. the human bleeds out, spectates, and respawns at the next round
##   6. everyone down = game over
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_bots.tscn [-- --rounds=3 --skill=veteran]
## Prints "[bots] ..." lines, the squad report, and RESULT PASS/FAIL (exit code 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 600.0

var _map: Node3D
var _t: float = 0.0
var _phase: int = 0
var _phase_t: float = 0.0
var _fails: PackedStringArray = []
var _notes: PackedStringArray = []
var _rounds_seen: Array[int] = []
var _bot_kills: int = 0
var _human_kills: int = 0
var _downs: Array[int] = []
var _revives: Array = []
var _far_samples: int = 0
var _samples: int = 0
var _sample_t: float = 0.0
var _phys_ms: Array[float] = []
var _last_us: int = 0
var _game_over: bool = false
var _fight_rounds: int = 3
var _done: bool = false
var _max_alive: int = 0
var _bleed_checked: bool = false
var _bot_buys: Array = []        # [pid, item]
var _door_ids: Dictionary = {}



func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--rounds="):
			_fight_rounds = int(a.substr(9))
		elif a.begins_with("--skill="):
			GameState.bot_skill = a.substr(8)
	ProfileSave.path = "user://_qa_bots_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, _w: StringName, by: int) -> void:
		if GameState.is_bot(by):
			_bot_kills += 1
		elif by == 1:
			_human_kills += 1)
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		_rounds_seen.append(r)
		print("[bots] round %d at t=%.0fs (zombies %d, players for scaling %d)" % [r, _t, RoundManager.round_total, RoundManager.players])
		if r == 2:
			for pid: int in GameState.bot_ids:
				Economy.grant(pid, 1200)   # enough for a wall gun and a door this early
			print("[bots] handed every bot 1200 Scrip"))
	GLBus.purchase_made.connect(func(p: int, item: StringName, cost: int) -> void:
		if GameState.is_bot(p):
			_bot_buys.append([p, item])
			print("[bots] P%d bought %s for %d at t=%.0fs" % [p, item, cost, _t]))
	GLBus.door_opened.connect(func(d: StringName, by: int) -> void:
		print("[bots] door %s opened by P%d at t=%.0fs" % [d, by, _t]))
	GLBus.player_downed.connect(func(p: int) -> void:
		_downs.append(p)
		print("[bots] P%d down at t=%.0fs" % [p, _t]))
	GLBus.player_revived.connect(func(p: int, by: int) -> void:
		_revives.append([p, by])
		print("[bots] P%d revived by P%d at t=%.0fs" % [p, by, _t]))
	GLBus.game_over.connect(func(_s: Dictionary) -> void:
		_game_over = true
		print("[bots] game over at t=%.0fs" % _t))


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[bots] FAIL: ", msg)


func _note(msg: String) -> void:
	_notes.append(msg)
	print("[bots] ", msg)


func _root() -> MapRoot:
	return _map as MapRoot


func _bots() -> Array[Player]:
	var out: Array[Player] = []
	for n: Node in get_tree().get_nodes_in_group(&"bots"):
		out.append(n as Player)
	return out


func _physics_process(delta: float) -> void:
	if _done or _map == null or not _map.is_inside_tree():
		return
	_t += delta
	_phase_t += delta
	var now: int = Time.get_ticks_usec()
	if _last_us > 0 and _t > 10.0 and _phase == 1:
		_phys_ms.append(float(now - _last_us) / 1000.0)
	_last_us = now
	if _t > TIMEOUT:
		_fail("timeout in phase %d" % _phase)
		_finish()
		return
	if _game_over and _phase < 5:
		_fail("game over in phase %d" % _phase)
		_finish()
		return
	var root: MapRoot = _root()
	var human: Player = root.player
	match _phase:
		0:
			if _phase_t < 2.0:
				return
			_check_setup(root)
			_phase = 1
			_phase_t = 0.0
		1:
			_watch_fight(delta, root, human)
			if RoundManager.current_round > _fight_rounds or _phase_t > 420.0:
				_check_fight(root)
				_phase = 2
				_phase_t = 0.0
				var b: Player = _bots()[0]
				b.take_hit(9999.0, null)
				_note("downed %s (P%d) on purpose" % [Net.display_name(b.player_id), b.player_id])
		2:
			var b: Player = _bots()[0]
			var revived: bool = false
			for r: Array in _revives:
				if int(r[0]) == b.player_id and GameState.is_bot(int(r[1])):
					revived = true
			if revived and not b.downed:
				_note("bot revived by a bot after %.0fs" % _phase_t)
				_phase = 3
				_phase_t = 0.0
				GameState.god_mode = false
				human.take_hit(9999.0, null)
				_note("downed the human on purpose")
			elif _phase_t > 60.0:
				_fail("no bot revived the downed bot within 60 s (downed %s, reviver %d)" % [str(b.downed), root.session.coop.reviver_of(b.player_id)])
				_phase = 3
				_phase_t = 0.0
				GameState.god_mode = false
				human.take_hit(9999.0, null)
		3:
			var revived: bool = false
			for r: Array in _revives:
				if int(r[0]) == 1 and GameState.is_bot(int(r[1])):
					revived = true
			if revived and not human.downed:
				_note("human revived by a bot after %.0fs (hp %.0f, last stand over: %s)" % [_phase_t, human.hp, str(not human.last_stand)])
				_phase = 4
				_phase_t = 0.0
				human.take_hit(9999.0, null)
				# bleed out at once (the clock would otherwise pause as soon as a bot starts the revive hold)
				root.session.coop.players[1]["bleed"] = 0.001
				root.session.coop.players[1]["reviver"] = 0
				root.session._tick_bleed(0.01)
				_note("downed the human again and ran the clock out")
			elif _phase_t > 60.0:
				_fail("no bot revived the downed human within 60 s (downed %s, reviver %d)" % [str(human.downed), root.session.coop.reviver_of(1)])
				_phase = 5
				_phase_t = 0.0
		4:
			if _phase_t < 2.0:
				return
			if not _bleed_checked:
				_bleed_checked = true
				if not human.spectating:
					_fail("the human didn't bleed out into spectating (downed %s, dead %s)" % [str(human.downed), str(root.session.coop.is_dead(1))])
				elif root.session._spectate_cam == null:
					_fail("no spectate camera while bled out")
				else:
					_note("human bled out and spectates %s" % root.session.spectate_name())
				root.director.kill_all(false)   # end the round quickly: the respawn comes with the next one
				RoundManager.break_left = minf(RoundManager.break_left, 3.0)
			if not human.spectating and _phase_t > 2.2:
				_note("human respawned after %.0fs (round %d, hp %.0f, weapon %s)" % [_phase_t, RoundManager.current_round, human.hp, str(human.weapons.current().id) if human.weapons.current() != null else "-"])
				if human.downed:
					_fail("respawned but still downed")
				_phase = 5
				_phase_t = 0.0
			elif RoundManager.state == RoundManager.State.ROUND and RoundManager.remaining() > 0 and fmod(_phase_t, 8.0) < delta:
				root.director.kill_all(false)
			elif _phase_t > 120.0:
				_fail("the human never respawned (round %d, spectating %s)" % [RoundManager.current_round, str(human.spectating)])
				_phase = 5
				_phase_t = 0.0
		5:
			if _phase_t < 1.0:
				return
			if _phase_t < 1.1:
				GameState.god_mode = false
				for b: Player in _bots():
					if b.is_alive():
						b.take_hit(9999.0, null)
				if human.is_alive() and not human.spectating:
					human.take_hit(9999.0, null)
				_note("downed everyone")
			if _game_over:
				_note("game over once everyone was down")
				_finish()
			elif _phase_t > 20.0:
				_fail("no game over with everyone down (alive %d)" % root.session.coop.alive_count())
				_finish()


func _check_setup(root: MapRoot) -> void:
	var bots: Array[Player] = _bots()
	if bots.size() != 3:
		_fail("expected 3 bots, found %d" % bots.size())
	var chars: Dictionary = {}
	for b: Player in bots:
		chars[b.character_id] = true
		if b.get_node_or_null("Brain") == null:
			_fail("bot P%d has no brain" % b.player_id)
		if b.get_node_or_null("Revive") == null:
			_fail("bot P%d has no revive point" % b.player_id)
		if b.remote_body == null:
			_fail("bot P%d has no body" % b.player_id)
		if b.character_id == GameState.character_id:
			_fail("bot P%d plays the human's survivor" % b.player_id)
	if chars.size() != bots.size():
		_fail("bots share a survivor: %s" % str(chars.keys()))
	if root.session == null or Net.session != root.session:
		_fail("no local session")
	if Net.is_online():
		_fail("the session went online")
	if root.player.get_node_or_null("Revive") == null:
		_fail("the human has no revive point")
	if root.squad == null or root.squad.brains.size() != bots.size():
		_fail("no squad / wrong brain count")
	if RoundManager.players != 3:
		_fail("round scaling sees %d players, expected 3 (1 human + 3 x 0.75)" % RoundManager.players)
	if GameState.is_solo():
		_fail("GameState thinks this is solo")
	_note("setup: %d bots (%s), scaling players %d, session %s" % [bots.size(), ", ".join(PackedStringArray(chars.keys().map(func(c: Variant) -> String: return str(c)))), RoundManager.players, "local" if not Net.is_online() else "online"])


func _watch_fight(delta: float, root: MapRoot, human: Player) -> void:
	_sample_t -= delta
	_max_alive = maxi(_max_alive, root.director.active_zombies().size())
	if _sample_t > 0.0:
		return
	_sample_t = 1.0
	for b: Player in _bots():
		_samples += 1
		if b.global_position.distance_to(human.global_position) > 22.0:
			_far_samples += 1
		if b.global_position.y < -20.0:
			_fail("bot P%d fell out of the world" % b.player_id)


func _check_fight(root: MapRoot) -> void:
	if _rounds_seen.size() < 2:
		_fail("rounds didn't advance (seen %s)" % str(_rounds_seen))
	if _bot_kills == 0:
		_fail("the bots killed nothing")
	for b: BotBrain in root.squad.brains:
		if b.shots == 0:
			_fail("%s never fired" % Net.display_name(b.player.player_id))
	if _samples > 0 and float(_far_samples) / float(_samples) > 0.15:
		_fail("bots were far from the human %d%% of the time" % int(100.0 * _far_samples / _samples))
	var guns: int = 0
	var doors: int = 0
	var weapons: Dictionary = GLData.table("weapons")["weapons"]
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor:
			_door_ids[(n as BuyDoor).door_id] = true
	for b: Variant in _bot_buys:
		var item: StringName = (b as Array)[1]
		if weapons.has(String(item)):
			guns += 1
		elif _door_ids.has(item):
			doors += 1
	if guns == 0:
		_fail("no bot bought a wall weapon")
	if doors == 0:
		_fail("no bot opened a door (bot purchases: %s)" % str(_bot_buys))
	_note("bot purchases: %d wall guns, %d doors, %d total" % [guns, doors, _bot_buys.size()])

	_phys_ms.sort()
	var p50: float = _phys_ms[_phys_ms.size() / 2] if not _phys_ms.is_empty() else 0.0
	var p99: float = _phys_ms[int(_phys_ms.size() * 0.99)] if not _phys_ms.is_empty() else 0.0
	_note("fight: rounds %s, bot kills %d, human kills %d, max alive %d, far-from-human %d%%, frame ms p50 %.2f p99 %.2f" % [
		str(_rounds_seen), _bot_kills, _human_kills, _max_alive, int(100.0 * _far_samples / maxi(1, _samples)), p50, p99])
	for line: String in root.squad.report():
		print("[bots]   ", line)


func _finish() -> void:
	if _done:
		return
	_done = true
	var root: MapRoot = _root()
	if root != null and root.squad != null:
		for line: String in root.squad.report():
			print("[bots]   ", line)
	print("[bots] downs: %s  revives: %s" % [str(_downs), str(_revives)])
	if _fails.is_empty():
		print("[bots] RESULT PASS")
	else:
		for f: String in _fails:
			print("[bots] FAIL: ", f)
		print("[bots] RESULT FAIL")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://_qa_bots_profile.json"))
	get_tree().quit(0 if _fails.is_empty() else 1)
