extends Node
## Headless smoke for the four Fernflug act bosses (UPDATE 10 §9, THE_BAR row 13; DECISIONS T-171). Solo, god mode,
## no bots, one case per act. Each act is entered the way the launcher's "skip to Act N" does (Campaign.begin_at at
## the act's first match round with the arrival kit), every door is bought and the boss's arena zone opened, then the
## boss's reserved round is forced the way smoke_paul does (RoundManager.debug_set_round to the ActController's
## boss_round_match: Act I match round 13, Act II 18, Act III 26; the act controller summons him on that round's
## start). Act IV's Account Manager has no round: she attends when F_CORE opens (MondlichtController), so that case
## opens the zone. Every case checks the arrival (summoned on the round the data names, standing, scaled HP), the
## title card (a BossHud in the map with the data's title in cards_shown), one attack or move inside the window, and
## a scripted kill's payout (HomageBoss.debug_kill: the data's flag and kill_scrip_per_player each; the Account
## Manager escalates instead: manager_escalated, escalate_scrip_per_player and her Resupply). The horde is culled
## while waiting so the boss has the stage. One "[actboss] RESULT: PASS|FAIL" line (tools/run_smokes.sh reads it).
##
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_act_bosses.tscn

const TIMEOUT: float = 900.0
const CASES: Array[Dictionary] = [
	{"label": "Act I: DER KRANFÜHRER on act round 13", "map": &"map04a_thalbach", "scene": "res://gravelight/maps/map04_fernflug/map04a.tscn",
		"start": 1, "id": "kranfuehrer", "round": 13, "arena": &"H_HALLE", "flags": [&"halle_unlocked"],
		"stand": Vector3(-20.0, 0.2, 175.0), "counters": ["drops_done", "sweeps_done", "rings_done"], "act_window": 30.0},
	{"label": "Act II: DER BORDWART on act round 4", "map": &"map04b_kranich", "scene": "res://gravelight/maps/map04_fernflug/map04b.tscn",
		"start": 15, "id": "bordwart", "round": 18, "arena": &"D_TRIEBWERK", "flags": [],
		"stand": Vector3(-66.0, 0.2, 38.0), "counters": ["vents_done", "lashes_done", "pulls_done"], "act_window": 30.0},
	{"label": "Act III: THE TEST PILOT on act round 6", "map": &"map04c_groomlake", "scene": "res://gravelight/maps/map04_fernflug/map04c.tscn",
		"start": 21, "id": "testpilot", "round": 26, "arena": &"F_LAB", "flags": [],
		"stand": Vector3(-32.0, -5.8, 128.0), "counters": ["leaps_done", "landings", "drags_done"], "act_window": 30.0},
	{"label": "Act IV: THE ACCOUNT MANAGER when F_CORE opens", "map": &"map04d_mondlicht", "scene": "res://gravelight/maps/map04_fernflug/map04d.tscn",
		"start": 30, "id": "account_manager", "round": -1, "arena": &"F_CORE", "flags": [],
		"stand": Vector3(28.0, 0.2, -24.0), "counters": ["arms_done", "prices_done", "crews_done", "presents_done"], "act_window": 45.0},
]

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _done: bool = false
var _drops: Array[String] = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_actboss.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_actboss_settings.cfg"
	GLSettings.values["bot_ee_help"] = "off"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"dutch"
	GameState.bot_count = 0
	GLBus.powerup_spawned.connect(func(id: StringName, _p: Vector3) -> void: _drops.append(String(id)))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout after %.0f s" % _t)
		_finish()


func _run() -> void:
	for c: Dictionary in CASES:
		await _case(c)
	_finish()


# ================================================================== one act

func _case(c: Dictionary) -> void:
	_note("---- %s" % str(c["label"]))
	await _load(c)
	var p: Player = _player()
	if p == null:
		_check(false, "%s: the act loaded (no player)" % str(c["id"]))
		return
	var table: Dictionary = GLData.table("bosses/map04")
	var bcfg: Dictionary = (table.get("bosses", {}) as Dictionary).get(str(c["id"]), {})
	var title: String = str(bcfg.get("title", ""))
	_check(not bcfg.is_empty() and title != "", "%s has a bosses/map04.json row" % str(c["id"]))
	# the act opened as a squad would have it by the boss's round: every door bought, the arena's zone open
	for f: Variant in c["flags"]:
		GameState.set_flag(f as StringName)
	var arena: StringName = c["arena"] as StringName
	if str(c["id"]) != "account_manager":
		await _open_doors(true)
		if not GameState.is_zone_open(arena):
			GameState.open_zone(arena)
	await _frames(3)
	_place(c["stand"] as Vector3)
	_cull()
	var ctl: Node = _controller(c)
	_check(ctl != null, "the act's controller is in the scene")
	if ctl == null:
		return
	var expect_round: int = int(c["round"])
	if str(c["id"]) == "account_manager":
		GameState.open_zone(arena)
		var attends: bool = await _until(func() -> bool: return bool(ctl.get("boss_spawned")), 10.0)
		_check(attends, "the Account Manager attends when F_CORE opens")
	else:
		var ac: ActController = ctl as ActController
		ac._reserve_boss()
		var r: int = ac.boss_round_match
		_check(r == expect_round and RoundManager.is_reserved(r), "%s's round is reserved: match round %d, act round %d (wanted %d)" % [title, r, r - RoundManager.act_start + 1, expect_round])
		RoundManager.debug_set_round(r)
		var began: bool = await _until(func() -> bool: return RoundManager.current_round == r and ac.boss_spawned, 25.0)
		_check(began, "round %d starts and the act controller summons him (round %d, spawned %s)" % [r, RoundManager.current_round, str(ac.boss_spawned)])
	var boss: HomageBoss = ctl.get("boss") as HomageBoss
	_check(boss != null and is_instance_valid(boss) and boss.is_active(), "%s arrived and stands (hp %d)" % [title, int(boss.max_hp) if boss != null else 0])
	if boss == null or not is_instance_valid(boss):
		return
	var want_hp: float = HomageBoss.scaled_hp(float(bcfg.get("hp_base", 0)), RoundManager.players, float(table.get("hp_player_step", 0.75)))
	_check(is_equal_approx(boss.max_hp, want_hp), "his health is the data's, scaled (%d)" % int(boss.max_hp))
	# the title card
	await _frames(2)
	var hud: BossHud = _hud()
	_check(hud != null and hud.cards_shown.has(title), "the title card says %s (%s)" % [title, str(hud.cards_shown) if hud != null else "no BossHud"])
	# one attack or one move
	var p0: Vector3 = boss.global_position
	var counters: Array = c["counters"]
	var acted: bool = await _until(func() -> bool: return _acted(boss, p0, counters), float(c["act_window"]))
	_check(acted, "he moves or attacks within %.0f s (moved %.1f m; %s)" % [float(c["act_window"]), boss.global_position.distance_to(p0) if is_instance_valid(boss) else 0.0, _counts(boss, counters)])
	# the scripted kill and its payout
	var scrip0: int = Economy.get_scrip(p.player_id)
	_drops.clear()
	if is_instance_valid(boss):
		boss.debug_kill(p.player_id)
	await _secs(1.5)
	var flag: StringName = StringName(str(bcfg.get("flag", "")))
	if str(c["id"]) == "account_manager":
		var pay: int = int(bcfg.get("escalate_scrip_per_player", 0))
		_check(is_instance_valid(boss) and bool(boss.get("escalated")) and not boss.is_active(), "she escalates instead of dying (the console unlocks)")
		_check(GameState.has_flag(flag), "the flag %s is set" % flag)
		_check(Economy.get_scrip(p.player_id) >= scrip0 + pay, "the escalation pays %d Scrip (%d -> %d)" % [pay, scrip0, Economy.get_scrip(p.player_id)])
	else:
		var pay2: int = int(bcfg.get("kill_scrip_per_player", 0))
		_check(not is_instance_valid(boss) or not boss.is_active(), "the kill takes him down")
		_check(GameState.has_flag(flag), "he drops his flag %s" % flag)
		_check(Economy.get_scrip(p.player_id) >= scrip0 + pay2, "the kill pays %d Scrip each (%d -> %d)" % [pay2, scrip0, Economy.get_scrip(p.player_id)])
	for d: Variant in bcfg.get("drops", []):
		_check(_drops.has(str(d)), "his %s drop" % str(d))


# ================================================================== helpers

func _load(c: Dictionary) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.bot_count = 0
	GameState.god_mode = true
	Campaign.begin_at(c["map"] as StringName, int(c["start"]), Campaign.arrival_kit(c["map"] as StringName))
	Campaign.cutscene_speed = 12.0
	_map = (load(str(c["scene"])) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _player() != null and _player().is_inside_tree(), 20.0)
	await _frames(40)
	GameState.god_mode = true
	if _player() != null:
		_player().set_process_unhandled_input(false)


func _controller(c: Dictionary) -> Node:
	if str(c["id"]) == "account_manager":
		return get_tree().get_first_node_in_group(&"mondlicht_controller")
	return get_tree().get_first_node_in_group(&"act_controllers")


func _hud() -> BossHud:
	if _map == null:
		return null
	for n: Node in _map.get_children():
		if n is BossHud:
			return n as BossHud
	return null


func _acted(boss: HomageBoss, p0: Vector3, counters: Array) -> bool:
	if boss == null or not is_instance_valid(boss):
		return false
	if boss.global_position.distance_to(p0) > 1.0:
		return true
	for k: Variant in counters:
		if int(boss.get(str(k))) > 0:
			return true
	return false


func _counts(boss: HomageBoss, counters: Array) -> String:
	var parts: PackedStringArray = []
	for k: Variant in counters:
		parts.append("%s %d" % [str(k), int(boss.get(str(k))) if is_instance_valid(boss) else 0])
	return ", ".join(parts)


func _root() -> MapRoot:
	return _map as MapRoot


func _player() -> Player:
	return _root().player if _map != null and is_instance_valid(_map) else null


func _place(p: Vector3) -> void:
	var pl: Player = _player()
	if pl == null:
		return
	pl.global_position = p
	pl.velocity = Vector3.ZERO


## Every active zombie but a boss away (the boss has the stage; the round stays open on his reserve).
func _cull() -> void:
	if _map == null or not is_instance_valid(_map) or _root().director == null:
		return
	for z: Zombie in _root().director.active_zombies():
		if not (z is HomageBoss) and is_instance_valid(z):
			z.kill_silently()


func _open_doors(include_power: bool = false) -> void:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var bd: BuyDoor = n as BuyDoor
		if bd != null and not bd.is_open and (include_power or not bd.requires_power):
			bd.open(0)
	await _frames(3)


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		_cull()
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _note(msg: String) -> void:
	print("[actboss] ", msg)


func _check(cond: bool, what: String) -> void:
	print("[actboss] %-78s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[actboss] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), "; ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
