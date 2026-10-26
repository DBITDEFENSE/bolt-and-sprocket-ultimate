class_name ActController
extends Node3D
## Map 4's per-act controller (UPDATE 07, docs/MAP4_FERNFLUG.md §10, §14): reads the act block of the act's json
## (RoundManager.act) and runs what the round clock owes the act: the Great Hangar unlock (flag `halle_unlocked`
## at act round `halle_open_round`, or once the three Fernflug files are read: flags file_1..file_3), the act's
## boss (reserved on its act round like the Cousins Round, summoned on that round's start, the horde cut to
## `horde_fraction`, bots-alone scaling while no human stands), and the arrival / act lines. The special round
## is the Fliegeralarm node's job. Pure rules are static for the tests.

var act: Dictionary = {}
var boss_cfg: Dictionary = {}
var director: ZombieDirector = null
var boss: HomageBoss = null
var boss_round_match: int = -1
var boss_spawned: bool = false
var _no_human_t: float = 0.0
var _human_t: float = 0.0
var bots_alone: bool = false


## The match round an act round falls on.
static func match_round_of(act_round: int, act_start: int) -> int:
	return act_start + act_round - 1


## True when the hangar unlock is due: the act round reached `halle_open_round`, or every file flag is set.
static func halle_due(act_round: int, open_round: int, files_read: int, files_needed: int = 3) -> bool:
	return act_round >= open_round or files_read >= files_needed


func _ready() -> void:
	name = "ActController"
	add_to_group(&"act_controllers")
	GLBus.match_started.connect(_on_match_started)
	GLBus.round_started.connect(_on_round_started)
	GLBus.round_ended.connect(_on_round_ended)
	GLBus.flag_changed.connect(_on_flag_changed)


func _on_match_started(_map: StringName) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"director"):
		director = n as ZombieDirector
	act = RoundManager.act_block_of(GameState.map_id)
	var b: Dictionary = act.get("boss", {})
	if not b.is_empty():
		boss_cfg = (Kranfuehrer.table().get("bosses", {}) as Dictionary).get(str(b.get("id", "")), {})
	(func() -> void:
		_reserve_boss()
		_check_halle()).call_deferred()


## UPDATE 07 (T-114): the main egg fires an act's clock event early through the quest action {"act_event": name}:
## "open_halle" (the hangar unlock), "london_window" and "bomb_run" (the FlightController's beats, Act II).
func fire_event(ev: StringName) -> void:
	match ev:
		&"open_halle":
			if not GameState.has_flag(&"halle_unlocked"):
				GameState.set_flag(&"halle_unlocked")
		&"london_window", &"bomb_run":
			var fc: Node = get_parent().get_node_or_null("FlightController") if get_parent() != null else null
			if fc == null:
				fc = get_tree().get_first_node_in_group(&"flight_controller")
			if fc == null:
				return
			if ev == &"london_window" and fc.has_method("start_london"):
				fc.call("start_london")
			elif ev == &"bomb_run" and fc.has_method("start_bomb_run"):
				fc.call("start_bomb_run")
		_:
			print("[act] unknown act_event %s" % ev)


## The boss's match round, once RoundManager knows the act's start round (start_game / resume_at run after match_started).
func _reserve_boss() -> void:
	var b: Dictionary = act.get("boss", {})
	if b.is_empty() or boss_round_match > 0 or not RoundManager.has_act():
		return
	boss_round_match = match_round_of(int(b.get("round", 13)), RoundManager.act_start)
	RoundManager.reserve_round(boss_round_match)


func _on_flag_changed(_flag: StringName, _value: Variant) -> void:
	_check_halle()


func _files_read() -> int:
	var n: int = 0
	for i: int in [1, 2, 3]:
		if GameState.has_flag(StringName("file_%d" % i)):
			n += 1
	return n


func _check_halle() -> void:
	if act.is_empty() or GameState.has_flag(&"halle_unlocked"):
		return
	if halle_due(RoundManager.act_round(), int(act.get("halle_open_round", 12)), _files_read()):
		GameState.set_flag(&"halle_unlocked")


func _on_round_started(r: int, special: bool) -> void:
	_reserve_boss()
	_check_halle()
	if act.is_empty() or special or director == null or not Net.is_authority():
		return
	if r == boss_round_match and not boss_spawned:
		var arena: StringName = StringName(str((act.get("boss", {}) as Dictionary).get("arena_zone", "")))
		if arena != &"" and not GameState.is_zone_open(arena):
			# the squad has not opened his arena yet: he waits a round (the act's fallback covers a squad that never does)
			boss_round_match = r + 1
			RoundManager.reserve_round(boss_round_match)
			print("[act] boss waits: %s is shut (next round %d)" % [arena, boss_round_match])
			return
		_spawn_boss()
	elif boss_spawned and boss != null and is_instance_valid(boss) and boss.gone and not boss.is_active():
		# a retreated boss returns a couple of rounds later, on the rail again
		var back: int = int((act.get("boss", {}) as Dictionary).get("returns_after_rounds", 2))
		if r >= boss_round_match + back and r != boss_round_match:
			boss_spawned = false
			boss_round_match = r
			_spawn_boss()


func _spawn_boss() -> void:
	var id: StringName = StringName(str((act.get("boss", {}) as Dictionary).get("id", "")))
	if id == &"":
		return
	RoundManager.round_total = maxi(2, int(round(float(RoundManager.round_total) * float(Kranfuehrer.table().get("horde_fraction", 0.5)))))
	RoundManager.to_spawn = mini(RoundManager.to_spawn, RoundManager.round_total)
	var n: Node3D = director.summon_boss(id, Vector3.ZERO)
	boss = n as HomageBoss
	boss_spawned = boss != null
	if boss != null:
		_no_human_t = 0.0
		_human_t = 0.0
		bots_alone = false
		print("[act] %s on round %d (act round %d), hp %d" % [id, RoundManager.current_round, RoundManager.act_round(), int(boss.max_hp)])


func _on_round_ended(_r: int) -> void:
	for c: Node in get_tree().get_nodes_in_group(&"map04_casings"):
		c.queue_free()


func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_active():
		return
	var ba: Dictionary = CousinsRound.bots_alone_cfg(Kranfuehrer.table())
	if not bool(ba.get("enabled", false)):
		return
	var humans_up: int = 0
	var humans: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p == null or p.is_bot:
			continue
		humans += 1
		if p.is_alive():
			humans_up += 1
	if CousinsRound.squad_is_bots_alone(humans_up, humans):
		_no_human_t += delta
		_human_t = 0.0
		if not bots_alone and _no_human_t >= float(ba.get("engage_after", 4.0)):
			bots_alone = true
			var m: Array[float] = CousinsRound.squad_mults(true, ba)
			boss.set_squad_scale(m[0], m[1], m[2], m[3])
	else:
		_human_t += delta
		_no_human_t = 0.0
		if bots_alone and _human_t >= float(ba.get("release_after", 2.0)):
			bots_alone = false
			var m2: Array[float] = CousinsRound.squad_mults(false, ba)
			boss.set_squad_scale(m2[0], m2[1], m2[2], m2[3])
