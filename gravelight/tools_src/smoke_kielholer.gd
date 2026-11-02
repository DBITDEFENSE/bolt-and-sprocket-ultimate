extends Node
## Headless smoke for the drowned of Totenhafen (UPDATE 10 C2 "Kielholer" + C5, DECISIONS T-153). In order:
##   1. the controller and its 8 Surface_* points are there, off while the docks are dry
##   2. a spring tide (round 9) floods the docks: the flag `flooded` comes on and the surface points go live
##   3. a Ganger rising at a surface point is tagged a Kielholer (the drowned kit); a diver gets its helmet hitbox
##   4. a Kielholer grabs a player on pier 2 and pulls him toward the edge; 60 damage to arm_grab frees him
##   5. the diver's helmet soaks hits, then breaks: the glow takes x2.0
##   6. DER KIELHOLER: the summon, the title card and bar; a quarter of his HP gone -> he sinks (no damage lands under
##      water) and resurfaces at another dock; the helmet glass broke on the way
##   7. his death drops the ignition key; taking it sets `boat_key` (and `kielholer_down`)
##   8. the fail-safe: a second summon with the clock at 420 s dives for good and the key floats up at the dock edge
##   9. dry docks: the surface points go off again
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_kielholer.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const TIMEOUT_S: float = 420.0

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_kielholer.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"deacon"
	GameState.bot_count = 0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	get_tree().create_timer(TIMEOUT_S).timeout.connect(func() -> void:
		if not _done:
			_fails.append("TIMEOUT")
			_finish())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, s: float) -> bool:
	var t: float = 0.0
	while t < s:
		if pred.call():
			return true
		await _secs(0.1)
		t += 0.1
	return bool(pred.call())


func _check(cond: bool, what: String) -> void:
	print("[kielholer] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _tp(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	await _frames(3)


func _zombie_at(pos: Vector3) -> Zombie:
	_dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	var z: Zombie = null
	for c: Zombie in zs:
		if not (c is HomageBoss) and (c.state == Zombie.State.TO_WINDOW or c.state == Zombie.State.EMERGE):
			z = c
	if z == null:
		z = zs[zs.size() - 1]
	z.global_position = pos
	await _frames(2)
	return z


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[kielholer] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	for z: String in ["A_QUAY", "B_CANNERY", "C_WORKSHOP", "D_PENHALL", "E_UBOAT", "F_LOWERPENS", "G_SIGNAL"]:
		GameState.open_zone(StringName(z))

	# --- 1. the controller and the surface points
	var kc: KielholerController = KielholerController.of(get_tree())
	_check(kc != null, "the KielholerController is attached (Totenhafen)")
	if kc == null:
		_finish()
		return
	var n_pts: int = (GLData.load_json("res://data/gravelight/map02.json")["kielholer"]["surface_points"] as Array).size()
	_check(kc.spawns.size() == n_pts and _map.get_node_or_null("Gameplay/Surface_0") != null, "%d Surface_* spawns under Gameplay" % n_pts)
	_check(kc.spawns.all(func(s: ZombieSpawn) -> bool: return not s.enabled), "dry docks: the surface points are off")

	# --- 2. a spring tide floods the docks
	var tide: TideController = get_tree().get_first_node_in_group(&"tide") as TideController
	tide.on_round(9)
	var flooded: bool = await _until(func() -> bool: return GameState.has_flag(&"flooded"), 40.0)
	_check(flooded and tide.stage == &"spring", "round 9: a spring tide, the flag flooded is on")
	_check(kc.spawns.all(func(s: ZombieSpawn) -> bool: return s.enabled and s.is_active(9)), "flooded: the surface points are live")

	# --- 3. tagging
	var sp0: Vector3 = kc.spawns[3].global_position
	var z1: Zombie = await _zombie_at(sp0)
	kc._on_enemy_spawned(&"ganger", z1.get_instance_id())
	_check(kc.tagged.has(z1) and str(z1.get_meta("kielholer", "")) in ["kielholer", "kielholer_diver"], "a Ganger rising at a surface point is a Kielholer (%s)" % str(z1.get_meta("kielholer", "-")))
	_check(z1.kit_name() in ["drowned", "drowned_diver"], "it wears the drowned kit (%s)" % z1.kit_name())
	_check(z1.find_child("ArmGrab", true, false) != null, "its arm_grab hitbox")
	_dir.kill_all(true)
	await _frames(5)

	# --- 4. the grab on pier 2 (the west edge at x 14)
	await _tp(Vector3(16.0, 0.2, 60.0))
	var z2: Zombie = await _zombie_at(Vector3(17.2, 0.0, 60.0))
	kc.make("kielholer", z2)
	z2.call("_enter", Zombie.State.CHASE)
	var started: int = kc.grabs_started
	var grabbed: bool = await _until(func() -> bool: return kc.grabs_started > started, 4.0)
	_check(grabbed and kc.held_by(1) == z2, "the Kielholer grabs the player within 2 m")
	var x0: float = _p.global_position.x
	await _secs(1.2)
	_check(_p.global_position.x < x0 - 0.3 and _p.has_status(&"kielholer_grab"), "he is pulled toward the water (x %.2f -> %.2f), held" % [x0, _p.global_position.x])
	z2.take_damage(61.0, &"arm_grab", &"smoke", 0, &"bullet")
	await _frames(3)
	_check(kc.held_by(1) == null and int(kc.grabs_broken.get("arm", 0)) >= 1, "61 damage to arm_grab frees him")
	_dir.kill_all(true)
	await _frames(5)

	# --- 5. the diver's helmet
	var z3: Zombie = await _zombie_at(Vector3(24.0, 0.0, 36.0))
	z3.set_physics_process(false)
	kc.make("kielholer_diver", z3)
	_check(z3.find_child("HelmetGlass", true, false) != null and z3.marke_site == &"", "the diver: a helmet_glass hitbox, no hand mark (the glow is his Marke)")
	var raw: float = KielholerController.helmet_threshold(z3.max_hp, KielholerController.ecfg("kielholer_diver")) + 2.0
	var hp0: float = z3.hp
	z3.take_damage(raw, &"helmet_glass", &"smoke", 1, &"bullet")
	_check(absf((hp0 - z3.hp) - raw * 0.5) < 1.0, "the helmet soaks half (%.0f of %.0f)" % [hp0 - z3.hp, raw])
	_check(kc.helmets_broken == 1, "the glass breaks after its share of the diver's HP")
	var hp1: float = z3.hp
	z3.take_damage(10.0, &"helmet_glass", &"smoke", 1, &"bullet")
	_check(absf((hp1 - z3.hp) - 20.0) < 0.5, "the glow takes x2.0 (%.1f)" % (hp1 - z3.hp))
	_dir.kill_all(true)
	await _frames(5)

	# --- 6. DER KIELHOLER
	await _tp(Vector3(17.0, 0.2, 52.0))
	var docks: Dictionary = GLData.load_json("res://data/gravelight/map02.json")["letzte_fahrt"]["boss_docks"]
	var d2: Array = docks["dock2"]
	var boss: Kielholer = _dir.summon_boss(&"der_kielholer", Vector3(float(d2[0]), float(d2[1]), float(d2[2]))) as Kielholer
	_check(boss != null and boss.enemy_id == &"der_kielholer", "the summon brings DER KIELHOLER")
	if boss == null:
		_finish()
		return
	_check(boss.dock == "dock2", "he surfaces at dock 2")
	var hud: BossHud = null
	for c: Node in _map.get_children():
		if c is BossHud:
			hud = c
	_check(hud != null and (hud.get("_rows") as Dictionary).has("der_kielholer"), "the title card and the boss bar")
	_check(kc.boss == boss, "the controller tracks him (bots-alone scaling)")
	await _until(func() -> bool: return boss.kstate != Kielholer.K.RISE, 3.0)
	boss.take_damage(boss.max_hp * 0.27, &"torso", &"smoke", 1, &"world")
	_check(boss.helmet_broken, "a quarter gone: the helmet glass broke on the way (15%)")
	var sank: bool = await _until(func() -> bool: return boss.kstate == Kielholer.K.UNDER, 4.0)
	_check(sank and boss.submerges == 1, "he sinks at 75%")
	var hp_under: float = boss.hp
	boss.take_damage(5000.0, &"torso", &"smoke", 1, &"bullet")
	_check(absf(boss.hp - hp_under) < 0.01, "nothing lands while he is under")
	var up: bool = await _until(func() -> bool: return boss.kstate == Kielholer.K.WALK, 16.0)
	_check(up and boss.dock != "dock2", "he resurfaces at another dock (%s)" % boss.dock)

	# --- 7. the kill drops the key
	boss.debug_kill(1)
	await _frames(5)
	var key: BoatKey = _map.get_node_or_null("Gameplay/BoatKey") as BoatKey
	_check(key != null and not key.floating, "his death drops the ignition key at the body")
	_check(GameState.has_flag(&"kielholer_down"), "the flag kielholer_down")
	if key != null:
		key.take(1)
	await _frames(3)
	_check(GameState.has_flag(&"boat_key") and QuestManager.has_item(&"boat_key"), "taking it: the flag boat_key and the quest item")
	_check(_map.get_node_or_null("Gameplay/BoatKey") == null or (_map.get_node_or_null("Gameplay/BoatKey") as BoatKey).is_queued_for_deletion(), "the key is gone from the pier")

	# --- 8. the fail-safe
	GameState.set_flag(&"boat_key", false)
	await _frames(3)
	var boss2: Kielholer = _dir.summon_boss(&"der_kielholer", Vector3(float(d2[0]), float(d2[1]), float(d2[2]))) as Kielholer
	_check(boss2 != null and boss2 != boss, "a second summon (the standalone round after the egg's)")
	if boss2 != null:
		boss2.spawn_t = float(Kielholer.table()["failsafe_seconds"]) - 0.05
		var dove: bool = await _until(func() -> bool: return boss2.failsafe_dived, 2.0)
		_check(dove, "at 420 s he dives for good")
		var key2: BoatKey = _map.get_node_or_null("Gameplay/BoatKey") as BoatKey
		_check(key2 != null and key2.floating, "the key floats up at the dock edge")
		if key2 != null:
			_check(KielholerController.edge_distance(key2.global_position) < 0.2, "on the edge (%s)" % str(key2.global_position))
		var gone: bool = await _until(func() -> bool: return not is_instance_valid(boss2) or boss2.gone, 5.0)
		_check(gone and GameState.has_flag(&"kielholer_dived"), "he is gone; the flag kielholer_dived")
		if key2 != null:
			await _tp(key2.global_position + Vector3(0.8, 0.2, 0.0))
			var auto: bool = await _until(func() -> bool: return GameState.has_flag(&"boat_key"), 2.0)
			_check(auto, "walking onto the floating key takes it (bots finish the egg alone)")

	# --- 9. dry docks
	GameState.set_flag(&"flooded", false)
	await _frames(2)
	_check(kc.spawns.all(func(s: ZombieSpawn) -> bool: return not s.enabled), "dry again: the surface points are off")
	_finish()
