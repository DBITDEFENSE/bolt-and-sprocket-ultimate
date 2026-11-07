extends Node
## Smoke (T-181): Easter Egg Mode on Map 0, Kaltenbrunn and Totenhafen. Each map plays a few rounds headless with
## the survivor standing in god mode: the rounds still advance (on the crawlers' deaths or the round clock), only
## crawlers spawn, never more than a handful at once, no Bellringer round, the bank is shut and the match is practice
## (no profile progress). Then the eggs' own enemies must still come: Kaltenbrunn's Chapel bell lit calls the
## Foreman, Requiem's s8b (30 Totenglocke kills) is fed crawlers, Totenhafen's s6 brings der Kielholer, and a pylon
## hold gets its few crawlers. Prints RESULT PASS / FAIL.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_egg_mode.tscn

const MAPS: Array = [
	["map00", "res://gravelight/maps/map00_crossroads/map00.tscn", "sparse", 3],
	["map01", "res://gravelight/maps/map01_kaltenbrunn/map01.tscn", "sparse", 3],
	["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn", "none", 2],
]

var _map: MapRoot
var _fails: PackedStringArray = []
var _spawned: int = 0
var _not_crawler: int = 0
var _max_up: int = 0
var _specials: int = 0
var _ended: int = 0
var _tag: String = ""


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_egg_mode.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_settings.cfg"
	GLSettings.values["homage_bosses"] = true   # Easter Egg Mode turns the homage rounds off by itself
	GLSettings.values["classic_rules"] = false
	GLSettings.values["bot_local_ai"] = false
	GameState.bot_count = 0
	GLBus.enemy_spawned.connect(_on_spawned)
	GLBus.round_started.connect(func(_r: int, special: bool) -> void: if special: _specials += 1)
	GLBus.round_ended.connect(func(_r: int) -> void: _ended += 1)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[egg_mode] %-6s %-66s %s" % [_tag, what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append("%s: %s" % [_tag, what])


func _on_spawned(enemy_id: StringName, iid: int) -> void:
	var z: Zombie = instance_from_id(iid) as Zombie
	if z == null or BotPerception.is_boss(z):
		return
	_spawned += 1
	if not z.is_crawler:
		_not_crawler += 1
		print("[egg_mode] %s not a crawler: %s" % [_tag, enemy_id])


func _ordinary_up(dir: ZombieDirector) -> int:
	var n: int = 0
	for z: Zombie in dir.active_zombies():
		if not BotPerception.is_boss(z):
			n += 1
	return n


func _load(path: String) -> void:
	if _map != null:
		RoundManager.stop()
		_map.queue_free()
		GameState.phase = GameState.Phase.MENU
		await _frames(10)
	_map = (load(path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	var t0: int = Time.get_ticks_msec()
	while (_map.player == null or not _map.player.is_inside_tree()) and Time.get_ticks_msec() - t0 < 30000:
		await _frames(5)
	await _frames(20)
	GameState.god_mode = true


## Plays until `rounds` rounds have started and ended (at most `cap_s` game seconds), tracking what is up.
func _play_rounds(rounds: int, cap_s: float) -> void:
	var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
	var r0: int = RoundManager.current_round
	var t: float = 0.0
	while RoundManager.current_round < r0 + rounds and t < cap_s:
		await _secs(0.5)
		t += 0.5
		_max_up = maxi(_max_up, _ordinary_up(dir))
	while RoundManager.state == RoundManager.State.ROUND and t < cap_s:
		await _secs(0.5)
		t += 0.5
		_max_up = maxi(_max_up, _ordinary_up(dir))
	print("[egg_mode] %s round %d after %.0f game s (%d spawned, %d up at most)" % [_tag, RoundManager.current_round, t, _spawned, _max_up])


func _run() -> void:
	Engine.time_scale = 6.0
	var c: Dictionary = EggMode.cfg()
	var cap_count: int = int((c["count"] as Dictionary)["max"])
	for m: Array in MAPS:
		_tag = str(m[0])
		GLSettings.values[EggMode.SETTING] = str(m[2])
		_spawned = 0
		_not_crawler = 0
		_max_up = 0
		_specials = 0
		await _load(str(m[1]))
		_ended = 0
		_check(EggMode.current() == str(m[2]), "the match is in Easter Egg Mode (%s)" % str(m[2]))
		_check(ProfileSave.practice and not bool(ProfileSave.cur_match.get("active", true)), "practice: the profile tracks nothing")
		_check(BankAccount.closed_reason() == "practice", "the bank is shut")
		var rounds: int = int(m[3])
		var scrip0: int = Economy.get_scrip(1)
		await _play_rounds(rounds, 140.0 * rounds)
		var pay: int = int(c.get("round_scrip", 0))
		_check(Economy.get_scrip(1) - scrip0 >= pay * (rounds - 1), "each round pays the stipend (%d -> %d Scrip)" % [scrip0, Economy.get_scrip(1)])
		_check(RoundManager.current_round >= rounds and _ended >= rounds, "the rounds advance and end (round %d, %d ended)" % [RoundManager.current_round, _ended])
		_check(_not_crawler == 0, "every ordinary zombie is a crawler (%d of %d not)" % [_not_crawler, _spawned])
		_check(_specials == 0, "no Bellringer round")
		if str(m[2]) == "none":
			_check(_spawned == 0, "No Zombies: nothing spawned (%d)" % _spawned)
		else:
			_check(_spawned > 0 and _max_up <= cap_count, "Few Crawlers: some came, at most %d up (%d spawned, %d up)" % [cap_count, _spawned, _max_up])
		match _tag:
			"map01":
				await _kaltenbrunn()
			"map02":
				await _totenhafen()
	Engine.time_scale = 1.0
	GLSettings.values[EggMode.SETTING] = "off"
	RoundManager.stop()
	var xp: int = int(ProfileSave.profile.get("xp", 0))
	_check(xp == 0 and (ProfileSave.profile.get("best_round", {}) as Dictionary).is_empty(), "the profile earned nothing (xp %d)" % xp)
	print("RESULT %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else ": " + "; ".join(_fails)])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _kaltenbrunn() -> void:
	const Q: StringName = &"map01_requiem"
	var dir: ZombieDirector = _map.get_node("ZombieDirector") as ZombieDirector
	# the Chapel bell, lit with an upgraded gun at s4, still calls the Foreman
	QuestManager.debug_skipto(Q, &"s4_key")
	var bell: QuestBell = null
	for n: Node in get_tree().get_nodes_in_group(&"quest_bells"):
		if (n as QuestBell).kind == &"chapel":
			bell = n as QuestBell
	_check(bell != null and QuestManager.is_active(Q, &"s4_key"), "s4 is open and the Chapel bell is there")
	if bell != null:
		bell.on_shot(&"m1_carbine", true, 1)
		var t: float = 0.0
		while not QuestManager.boss_alive(&"foreman") and t < 40.0:
			await _secs(0.5)
			t += 0.5
		_check(QuestManager.boss_alive(&"foreman"), "the lit Chapel bell calls the Foreman (%.0f game s)" % t)
	dir.kill_all(true)
	# a pylon hold gets its few crawlers ("sparse"), and the round stays open while it charges
	var pylon: Node = get_tree().get_first_node_in_group(&"pylons")
	if pylon != null and pylon.has_method("start_charge"):
		while RoundManager.state != RoundManager.State.ROUND:
			await _secs(0.5)
		var r: int = RoundManager.current_round
		pylon.call("start_charge")
		await _secs(70.0)
		_check(RoundManager.current_round == r and RoundManager.state == RoundManager.State.ROUND, "a charging pylon holds the round open")
		var up: int = _ordinary_up(dir)
		_check(up >= 1 and up <= int((EggMode.cfg()["hold_active"] as Dictionary)["sparse"]), "a pylon hold has a few crawlers (%d up)" % up)
		pylon.call("debug_attune")
		await _frames(10)
	dir.kill_all(true)
	# s8b: 30 Totenglocke kills by the heart need zombies: the feed brings them in every mode
	QuestManager.debug_skipto(Q, &"s8b_charge")
	_check(QuestManager.is_active(Q, &"s8b_charge"), "s8b is open")
	var t2: float = 0.0
	var most: int = 0
	while t2 < 120.0 and most < 4:
		await _secs(0.5)
		if RoundManager.state == RoundManager.State.ROUND:
			t2 += 0.5
		most = maxi(most, _ordinary_up(dir))
	_check(most >= 4 and most <= int(EggMode.cfg()["feed_active"]) + int((EggMode.cfg()["count"] as Dictionary)["max"]), "a kill-count step is fed crawlers by the heart (%d up)" % most)
	dir.kill_all(true)


func _totenhafen() -> void:
	const Q: StringName = &"map02_letzte_fahrt"
	if not QuestManager.has_quest(Q):
		_check(false, "Letzte Fahrt is loaded")
		return
	QuestManager.debug_skipto(Q, &"s6_boss")
	var t: float = 0.0
	while not QuestManager.boss_alive(&"der_kielholer") and t < 30.0:
		await _secs(0.5)
		t += 0.5
	_check(QuestManager.boss_alive(&"der_kielholer"), "s6 still brings der Kielholer up in No Zombies")
