extends Node
## Headless smoke test for Map 4 Act I "Werk Thalbach" (UPDATE 07). In order:
##   1. per-zone navigation with layer gating: every zone is reachable when its door is open and not when shut,
##      the service gate between the wind tunnel and the test stands, the hangar's catwalk ramps
##   2. every ground / catwalk spawn stands on the navmesh; the per-zone counts match map04a.json
##   3. the placed systems: 8 perk machines, 4 crate spots, the hangar door needs the power and the act's
##      unlock, the Hauptschalter's sweep lights every power light and bursts zombies, the Crucible forges
##      the pistol, the two traps kill, the act line reads "ACT I · n"
##   4. rounds 1-3 with 3 bots (shortened), then act round 13: the Kranführer is summoned on the rail, hurts a
##      player under a casing, dies by console and drops the hangar key; a Fliegeralarm circle fires
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04a.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04a.tscn"
const BITS: Dictionary = {"A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7, "H": 8}
const SHORT_ROUND: int = 8

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _hits: int = 0
var _rounds_seen: Array[int] = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4a.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.player_damaged.connect(func(_p: int, _a: float) -> void: _hits += 1)
	GLBus.round_started.connect(_on_round)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[m4a] %-64s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _mask(zones: String) -> int:
	var m: int = 0
	for z: String in zones.split(","):
		m |= 1 << (int(BITS[z]) - 1)
	return m


func _path_check(label: String, from: Vector3, to: Vector3, zones: String, expect: bool) -> void:
	var rid: RID = _map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, from, to, true, _mask(zones))
	var end_ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.2
	var ok: bool = end_ok == expect
	print("[m4a] %-64s %s (pts %d, end %s)" % [label, "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
	if not ok:
		_fails.append(label)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


func _zombie_at(pos: Vector3) -> Zombie:
	_dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	var z: Zombie = zs[zs.size() - 1]
	for c: Zombie in zs:
		if c.state == Zombie.State.TO_WINDOW or c.state == Zombie.State.EMERGE:
			z = c
	z.global_position = pos
	z.set_physics_process(false)
	await _frames(2)
	return z


func _on_round(r: int, _special: bool) -> void:
	_rounds_seen.append(r)
	RoundManager.to_spawn = mini(RoundManager.to_spawn, SHORT_ROUND)
	RoundManager.round_total = mini(RoundManager.round_total, SHORT_ROUND)


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	Economy.grant(1, 100000)

	# --- 1. navigation
	var all: String = "A,B,C,D,E,F,G,H"
	_path_check("siedlung -> cellar", Vector3(20, 0, 15), Vector3(7, 0, 5), "A", true)
	_path_check("siedlung -> rail yard (B open)", Vector3(20, 0, 15), Vector3(20, 0, 40), "A,B", true)
	_path_check("siedlung -> rail yard with B shut", Vector3(20, 0, 15), Vector3(20, 0, 40), "A", false)
	_path_check("rail yard -> goods shed", Vector3(20, 0, 40), Vector3(34, 0, 56), "B", true)
	_path_check("rail yard -> canteen stage (C open)", Vector3(20, 0, 40), Vector3(-30, 0, 52), "A,B,C", true)
	_path_check("rail yard -> canteen with C shut", Vector3(20, 0, 40), Vector3(-30, 0, 52), "A,B", false)
	_path_check("rail yard -> church square well", Vector3(20, 0, 40), Vector3(8, 0, 76), "B,D", true)
	_path_check("canteen -> assembly hall 2 (E open)", Vector3(-20, 0, 45), Vector3(-26, 0, 90), "C,E", true)
	_path_check("canteen -> Kraftzentrale", Vector3(-20, 0, 45), Vector3(-56, 0, 66), "C,E", true)
	_path_check("canteen -> assembly hall with E shut", Vector3(-20, 0, 45), Vector3(-26, 0, 90), "C", false)
	_path_check("church square -> wind tunnel test section (F open)", Vector3(8, 0, 76), Vector3(32, 0, 121), "D,F", true)
	_path_check("wind tunnel -> through the tunnel", Vector3(5, 0, 115), Vector3(40, 0, 115), "F", true)
	_path_check("assembly hall -> test stands ring (G open)", Vector3(-26, 0, 90), Vector3(-30, 0, 136), "E,G", true)
	_path_check("wind tunnel -> test stands by the service gate", Vector3(4, 0, 122), Vector3(-4, 0, 122), "F,G", true)
	_path_check("wind tunnel -> test stands with G shut", Vector3(4, 0, 122), Vector3(-4, 0, 122), "F", false)
	_path_check("test stands -> bunker crucible", Vector3(-30, 0, 136), Vector3(-56, 0, 146), "G", true)
	_path_check("test stands -> hangar floor (H open)", Vector3(-30, 0, 136), Vector3(-20, 0, 158), "G,H", true)
	_path_check("test stands -> hangar with H shut", Vector3(-30, 0, 136), Vector3(-20, 0, 158), "G", false)
	_path_check("hangar floor -> west catwalk via the ramp", Vector3(-30, 0, 158), Vector3(-68.2, 12, 200), "H", true)
	_path_check("hangar floor -> east catwalk via the ramp", Vector3(-30, 0, 158), Vector3(28.2, 12, 200), "H", true)
	_path_check("hangar floor -> round the wing's nose", Vector3(-30, 0, 158), Vector3(-20, 0, 210), "H", true)
	_path_check("siedlung -> hangar (everything open)", Vector3(20, 0, 15), Vector3(-20, 0, 158), all, true)

	# --- 2. spawn points
	var rid: RID = _map.get_world_3d().navigation_map
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04a.json")
	var counts: Dictionary = {}
	var bad: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		var zc: Dictionary = counts.get(String(sp.zone_id), {"windows": 0, "ground": 0, "catwalk": 0})
		var kind: String = "windows" if sp.kind == &"window" else ("catwalk" if sp.name.begins_with("Catwalk") else "ground")
		zc[kind] = int(zc[kind]) + 1
		counts[String(sp.zone_id)] = zc
		if sp.kind == &"window":
			continue
		var near: Vector3 = NavigationServer3D.map_get_closest_point(rid, sp.global_position)
		if Vector2(near.x - sp.global_position.x, near.z - sp.global_position.z).length() > 0.6 or absf(near.y - sp.global_position.y) > 1.0:
			bad += 1
			print("[m4a]   spawn off the navmesh: %s at %s (nearest %s)" % [sp.name, sp.global_position, near])
	_check(bad == 0, "every ground / catwalk spawn stands on the navmesh")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		var have: Dictionary = counts.get(zone, {})
		var ok: bool = int(have.get("windows", 0)) == int(want.get("windows", 0)) and int(have.get("ground", 0)) == int(want.get("ground", 0)) \
			and int(have.get("catwalk", 0)) == int(want.get("catwalk", 0))
		_check(ok, "%s spawn counts match map04a.json (%s)" % [zone, str(have)])

	# --- 3. systems
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)
	var perks: int = 0
	for n2: Node in _g("").get_children():
		if n2 is PerkMachine:
			perks += 1
	_check(perks == 9, "9 perk machines placed (Ledger Lager T-141)")
	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 4, "4 crate spots")
	var start_spot: Node = null
	for s: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if int(s.get("spot_index")) == CrateManager.location_index:
			start_spot = s
	_check(start_spot != null and bool(start_spot.get("can_start")), "crate started in the cellar or the goods shed")
	_check(RoundManager.has_act() and RoundManager.act_index() == 1, "the act block is loaded (index 1)")
	_check(RoundManager.act_label(7) == "ACT I · 7", "the HUD's act line reads 'ACT I · 7' (" + RoundManager.act_label(7) + ")")
	var halle: BuyDoor = _g("Door_Halle") as BuyDoor
	_check(halle.get_prompt(_p) == "Power must be activated", "hangar door: 'Power must be activated' (" + halle.get_prompt(_p) + ")")
	var cru: Node = _g("Crucible")
	_check((cru as Interactable).get_prompt(_p).contains("Power"), "Crucible refuses before the breaker")
	var alive0: int = RoundManager.alive
	(_g("Hauptschalter")).call("run_sequence", 1)
	await _secs(10.5)
	var lit: int = 0
	var total: int = 0
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		total += 1
		if (l as OmniLight3D).light_energy > 0.05:
			lit += 1
	_check(GameState.power_on and lit == total and total > 10, "power on: %d/%d zone lights lit" % [lit, total])
	_check(RoundManager.alive > alive0, "power-on burst spawned zombies (%d)" % (RoundManager.alive - alive0))
	_dir.kill_all(true)
	_check(not halle.can_interact(_p) and halle.get_prompt(_p).contains("sealed"), "hangar door still sealed before the act's unlock (" + halle.get_prompt(_p) + ")")
	GameState.set_flag(&"file_1")
	GameState.set_flag(&"file_2")
	GameState.set_flag(&"file_3")
	await _frames(3)
	_check(GameState.has_flag(&"halle_unlocked") and halle.get_prompt(_p).contains("2000"), "the three files unlock the hangar (" + halle.get_prompt(_p) + ")")
	halle.open(0)
	# the Crucible in the bunker
	await _tp(Vector3(-56.0, 0.2, 146.0), 90.0)
	_p.weapons.current_index = 0
	_check((cru as Interactable).get_prompt(_p).contains("5000"), "Crucible prompt: " + (cru as Interactable).get_prompt(_p))
	(cru as Interactable).interact(_p)
	await _secs(5.5)
	(cru as Interactable).interact(_p)
	await _frames(3)
	_check(_p.weapons.find_weapon(&"m1911_up") != null, "Crucible upgraded the M1911 to Last Rites")
	# traps
	await _tp(Vector3(38.0, 0.2, 47.0), 180.0)
	var z: Zombie = await _zombie_at(Vector3(20.0, 0, 45.5))
	(_g("Lever_CoalHopper") as Interactable).interact(_p)
	await _secs(6.0)
	_check(not z.is_active(), "the Coal Hopper killed a zombie on the platform")
	await _tp(Vector3(-2.0, 0.2, 90.0), 90.0)
	z = await _zombie_at(Vector3(-26.0, 0, 84.0))
	(_g("Lever_JigCrane") as Interactable).interact(_p)
	await _secs(6.0)
	_check(not z.is_active(), "the Jig Crane killed a zombie under the jig")
	_dir.kill_all(true)

	# --- 4. rounds 1-3 with the bots, then the boss round and a Fliegeralarm circle
	_check(get_tree().get_nodes_in_group(&"players").size() == 4, "the human and 3 bots are in the match")
	_hits = 0
	_rounds_seen.clear()
	await _tp(Vector3(20.0, 0.2, 15.0), 0.0)
	RoundManager.debug_set_round(1)
	var t: float = 0.0
	while t < 300.0 and not _rounds_seen.has(4):
		await _secs(1.0)
		t += 1.0
		for z2: Zombie in _dir.active_zombies():
			for pn: Node in get_tree().get_nodes_in_group(&"players"):
				if (pn as Player).is_alive() and z2.global_position.distance_to((pn as Player).global_position) < 4.0:
					z2.take_damage(z2.hp + 1.0, &"torso", &"kar98k", 1, &"bullet")
					break
	_check(_rounds_seen.has(1) and _rounds_seen.has(2) and _rounds_seen.has(3), "rounds 1, 2 and 3 ran with the bots (%s, %.0f s)" % [str(_rounds_seen), t])
	var kills: int = int(GameState.stats.get(&"kills", 0))
	_check(kills > 0, "the squad killed zombies (%d)" % kills)
	# the boss: summoned on the rail, drops a casing on the player under it, dies by console, leaves the key
	RoundManager.stop()
	_dir.kill_all(true)
	await _tp(Vector3(-20.0, 0.2, 175.0), 0.0)
	var kf: Node3D = _dir.summon_boss(&"kranfuehrer", Vector3.ZERO)
	_check(kf != null and kf is Kranfuehrer, "the Kranführer is summoned")
	if kf != null:
		var boss: Kranfuehrer = kf as Kranfuehrer
		_check(absf(boss.global_position.y - 12.0) < 0.5 and absf(boss.global_position.x - 28.0) < 0.5, "he rides the east rail 12 m up (%s)" % str(boss.global_position))
		_check(boss.max_hp >= 24000.0, "his health is 24,000 scaled (%d)" % int(boss.max_hp))
		var hits0: int = _hits   # god mode stays on: a hit still emits player_damaged (amount 0), so the count works
		var t2: float = 0.0
		while t2 < 25.0 and boss.drops_done == 0:
			await _secs(0.5)
			t2 += 0.5
		_check(boss.drops_done > 0, "he dropped a casing (%d in %.0f s)" % [boss.drops_done, t2])
		_check(absf(boss.trolley_z - 175.0) < 6.0, "the trolley ran to the player's z (%.1f)" % boss.trolley_z)
		print("[m4a] player hit %d times under the crane" % (_hits - hits0))
		boss.take_damage(boss.max_hp * 0.5, &"torso", &"kar98k", 1, &"bullet")
		await _frames(2)
		_check(boss.phase >= 2, "half his health: the sweep phase (%d)" % boss.phase)
		boss.debug_kill(1)
		await _secs(1.0)
		_check(not boss.is_active(), "the Kranführer is dead")
		_check(GameState.has_flag(&"kranfuehrer_down") and not GameState.has_flag(&"hangar_key"), "he dropped his flag; the hangar key is the egg's (only a kill over the ramp, T-114)")
	# a Fliegeralarm circle, driven directly
	var fa: Fliegeralarm = _g("Fliegeralarm") as Fliegeralarm
	_check(fa != null and fa.director == _dir and _dir.special_handler == fa, "the Fliegeralarm owns the act's special rounds")
	if fa != null:
		# a live round so the landers can draw from the queue (the circle itself is driven directly)
		_rounds_seen.clear()
		RoundManager.debug_set_round(2)
		var t3: float = 0.0
		while t3 < 30.0 and not _rounds_seen.has(2):
			await _secs(0.5)
			t3 += 0.5
		_dir.kill_all(true)
		RoundManager.to_spawn = maxi(RoundManager.to_spawn, 3)
		await _tp(Vector3(28.0, 0.2, 20.0), 0.0)
		fa._started = true
		fa._telegraph(Vector3(28, 0, 20))
		var hb: int = _hits
		await _secs(0.3)
		fa.tick_special(float(fa.cfg.get("telegraph_seconds", 4.0)) + 1.0)   # the telegraph's whole time in one tick: the bomb lands
		await _frames(3)
		print("[m4a]   circle: fired %d, hits %d, phase %s, hp %.0f, pos %s, local %s" % [fa.circles_fired, _hits - hb, str(GameState.phase), _p.hp, str(_p.global_position), str(_p.is_local)])
		_check(fa.circles_fired == 1 and _hits > hb, "a circle fired and hurt the player standing in it")
		_check(RoundManager.alive >= 1 or _dir.active_zombies().size() >= 1, "landers rose on the circle's edge (%d alive)" % RoundManager.alive)
		fa._started = false
		RoundManager.stop()
	_dir.kill_all(true)

	print("[m4a] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
