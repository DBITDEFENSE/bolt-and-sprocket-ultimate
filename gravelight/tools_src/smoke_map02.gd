extends Node
## Headless smoke test for Map 2 "Totenhafen" (T-036). In order:
##   1. per-zone navigation with layer gating: every door and zone is reachable when open and not when shut,
##      the catwalks, the tower ramp, the boat's deck and interior, the pump stair
##   2. every spawn point stands on (or, for windows, beside) the navmesh; the per-zone counts match map02.json
##   3. the placed systems: 6 perk machines, 5 crate spots (start at the hut or the warheads), the Signal Tower
##      door needs power, the Pumpenschalter's sweep lights every power light and bursts zombies, the Crucible
##      in the boat forges the pistol, the two traps kill, the tide rules and the tide controller (rise, flood,
##      spawn switch, wading slow, fall)
##   4. rounds 31-34 with 3 bots (each round shortened to a handful of zombies): the rounds advance, zombies
##      reach the squad, the tide comes in at 33 and goes out at 34
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map02.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const BITS: Dictionary = {"A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7}
const ZONES: Dictionary = {"A": "A_QUAY", "B": "B_CANNERY", "C": "C_WORKSHOP", "D": "D_PENHALL", "E": "E_UBOAT", "F": "F_LOWERPENS", "G": "G_SIGNAL"}
const LY: float = -3.0
const SY: float = -2.0
const CATY: float = 4.0
const TY: float = 7.0
const SHORT_ROUND: int = 10

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _hits: int = 0
var _rounds_seen: Array[int] = []
var _tide_at_33: Dictionary = {}
var _tide_at_34: Dictionary = {}


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m2.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"wren"
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
	print("[m2] %-64s %s" % [what, "ok" if cond else "FAIL"])
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
	print("[m2] %-64s %s (pts %d, end %s)" % [label, "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
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
	if r >= 31:
		RoundManager.to_spawn = mini(RoundManager.to_spawn, SHORT_ROUND)
		RoundManager.round_total = mini(RoundManager.round_total, SHORT_ROUND)


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	Economy.grant(1, 100000)

	# --- 1. navigation
	var all: String = "A,B,C,D,E,F,G"
	_path_check("quay -> cannery infirmary (all open)", Vector3(24, 0, 21), Vector3(-25, 0, 5), all, true)
	_path_check("quay -> cannery with B shut", Vector3(24, 0, 21), Vector3(-25, 0, 5), "A,C,D", false)
	_path_check("quay -> workshop warhead store", Vector3(24, 0, 21), Vector3(58, 0, 18), all, true)
	_path_check("quay -> workshop with C shut", Vector3(24, 0, 21), Vector3(58, 0, 18), "A,B,D", false)
	_path_check("cannery -> pen hall apron (west passage)", Vector3(-10, 0, 20), Vector3(-10, 0, 36), "B,D", true)
	_path_check("workshop -> pen hall apron (east passage)", Vector3(44, 0, 20), Vector3(44, 0, 36), "C,D", true)
	_path_check("cannery -> pen hall with D shut", Vector3(-10, 0, 20), Vector3(-10, 0, 36), "A,B,C", false)
	_path_check("apron -> pier 1 end", Vector3(-10, 0, 36), Vector3(-3, 0, 82), "D", true)
	_path_check("apron -> pier 2 end", Vector3(-10, 0, 36), Vector3(17, 0, 82), "D", true)
	_path_check("apron -> west catwalk via the NW stair", Vector3(-10, 0, 36), Vector3(-19, CATY, 70), "D", true)
	_path_check("apron -> east catwalk via the east stair", Vector3(30, 0, 36), Vector3(51, CATY, 80), "D", true)
	_path_check("west catwalk -> east catwalk along the north", Vector3(-19, CATY, 70), Vector3(51, CATY, 80), "D", true)
	_path_check("north catwalk -> tower (G open)", Vector3(20, CATY, 34), Vector3(47, TY, 36), "D,G", true)
	_path_check("north catwalk -> tower with G shut", Vector3(20, CATY, 34), Vector3(47, TY, 36), "D", false)
	_path_check("pier 2 -> boat deck (E open)", Vector3(17, 0, 50), Vector3(7, 1.0, 50), "D,E", true)
	_path_check("pier 2 -> boat torpedo room", Vector3(17, 0, 50), Vector3(7, SY, 44), "D,E", true)
	_path_check("pier 2 -> boat engine room", Vector3(17, 0, 50), Vector3(7, SY, 84), "D,E", true)
	_path_check("pier 2 -> boat with E shut", Vector3(17, 0, 50), Vector3(7, SY, 44), "D", false)
	_path_check("apron -> pump room (F open)", Vector3(44, 0, 40), Vector3(42, LY, 80), "D,F", true)
	_path_check("apron -> pump room with F shut", Vector3(44, 0, 40), Vector3(42, LY, 80), "D", false)
	_path_check("boat -> tower (everything open)", Vector3(7, SY, 44), Vector3(47, TY, 36), all, true)

	# --- 2. spawn points
	var rid: RID = _map.get_world_3d().navigation_map
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map02.json")
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
			print("[m2]   spawn off the navmesh: %s at %s (nearest %s)" % [sp.name, sp.global_position, near])
	_check(bad == 0, "every ground / catwalk spawn stands on the navmesh")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		var have: Dictionary = counts.get(zone, {})
		var ok: bool = int(have.get("windows", 0)) == int(want.get("windows", 0)) and int(have.get("ground", 0)) == int(want.get("ground", 0)) \
			and int(have.get("catwalk", 0)) == int(want.get("catwalk", 0))
		_check(ok, "%s spawn counts match map02.json (%s)" % [zone, str(have)])

	# --- 3. systems
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)
	var perks: int = 0
	for n2: Node in _g("").get_children():
		if n2 is PerkMachine:
			perks += 1
	_check(perks == 6, "6 perk machines placed")
	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 5, "5 crate spots")
	var start_spot: Node = null
	for s: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if int(s.get("spot_index")) == CrateManager.location_index:
			start_spot = s
	_check(start_spot != null and bool(start_spot.get("can_start")), "crate started at the hut or the warhead store")
	var want_props: int = 0
	for row: Dictionary in (GLData.table("story_props").get("props", []) as Array):
		if str(row.get("map", "")) == "2":
			want_props += 1
	_check(get_tree().get_nodes_in_group(&"story_props").size() == want_props, "%d Map 2 story items spawned (data says %d)" % [get_tree().get_nodes_in_group(&"story_props").size(), want_props])
	var sig: BuyDoor = _g("Door_Signal") as BuyDoor
	_check(sig.get_prompt(_p) == "Power must be activated", "Signal Tower door: 'Power must be activated'")
	var cru: Node = _g("Crucible")
	_check((cru as Interactable).get_prompt(_p).contains("Power"), "Crucible refuses before the pumps")
	# ballast: the switch refuses, a coffin is lifted (slow), hooked on the crane, then the switch takes the throw
	var sw: Interactable = _g("Pumpenschalter") as Interactable
	_check(sw.get_prompt(_p).contains("ballast") and not sw.can_interact(_p), "Pumpenschalter refuses without ballast (" + sw.get_prompt(_p) + ")")
	var coffin: Interactable = _g("Coffin_0") as Interactable
	var hook: Interactable = _g("BallastHook") as Interactable
	await _tp(Vector3(36.5, 0.2, 41.5), 0.0)
	_check(coffin.can_interact(_p) and coffin.get_prompt(_p).contains("lift"), "coffin prompt: " + coffin.get_prompt(_p))
	coffin.interact(_p)
	await _secs(0.6)
	_check(int(coffin.get("carrier")) == 1 and _p.has_status(&"ballast") and _p.status_move_mult() <= 0.5, "carrying the coffin slows the carrier (x%.2f)" % _p.status_move_mult())
	_check(not (_g("Coffin_1") as Interactable).can_interact(_p), "a carrier can't lift a second coffin")
	await _tp(Vector3(40.0, 0.2, 61.0), 0.0)
	_check(hook.can_interact(_p) and hook.get_prompt(_p).contains("hook"), "hook prompt: " + hook.get_prompt(_p))
	hook.interact(_p)
	await _frames(3)
	_check(GameState.has_flag(&"ballast_loaded") and bool(coffin.get("delivered")) and int(coffin.get("carrier")) == 0, "the crane took the coffin and set ballast_loaded")
	_check(sw.can_interact(_p) and sw.get_prompt(_p).contains("throw"), "Pumpenschalter takes the throw after ballast (" + sw.get_prompt(_p) + ")")
	# the pumps
	var alive0: int = RoundManager.alive
	(_g("Pumpenschalter")).call("run_sequence", 1)
	await _secs(9.5)
	var lit: int = 0
	var total: int = 0
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		total += 1
		if (l as OmniLight3D).light_energy > 0.05:
			lit += 1
	_check(GameState.power_on and lit == total and total > 10, "power on: %d/%d zone lights lit" % [lit, total])
	_check(RoundManager.alive > alive0, "power-on burst spawned zombies (%d)" % (RoundManager.alive - alive0))
	_dir.kill_all(true)
	_check(sig.get_prompt(_p).contains("2500"), "Signal Tower door buyable after power (" + sig.get_prompt(_p) + ")")
	sig.open(0)
	# the Crucible in the torpedo room
	await _tp(Vector3(7.0, SY + 0.2, 42.0), 0.0)
	_p.weapons.current_index = 0
	_check((cru as Interactable).get_prompt(_p).contains("5000"), "Crucible prompt: " + (cru as Interactable).get_prompt(_p))
	(cru as Interactable).interact(_p)
	await _secs(5.5)
	(cru as Interactable).interact(_p)
	await _frames(3)
	_check(_p.weapons.find_weapon(&"m1911_up") != null, "Crucible upgraded the M1911 to Last Rites")
	# traps
	await _tp(Vector3(48.0, 0.2, 24.0), 180.0)
	var z: Zombie = await _zombie_at(Vector3(46.0, 0, 27.0))
	(_g("Lever_Trolley") as Interactable).interact(_p)
	await _secs(6.0)
	_check(not z.is_active(), "Torpedo Trolley killed a zombie on the track")
	await _tp(Vector3(44.0, LY + 0.2, 54.0), 0.0)
	z = await _zombie_at(Vector3(49.0, LY, 50.9))
	(_g("Lever_Grille") as Interactable).interact(_p)
	await _secs(3.0)
	z.set_physics_process(true)
	await _secs(2.0)
	_check(not z.is_active(), "the Grille killed a zombie at the stair foot")
	_dir.kill_all(true)
	# the tide rules and the controller, driven directly
	var tcfg: Dictionary = cfg["tide"]
	_check(TideController.is_high_round(33, tcfg) and TideController.is_high_round(36, tcfg) and not TideController.is_high_round(34, tcfg)
		and not TideController.is_high_round(2, tcfg), "tide rules: 33 and 36 are high rounds, 34 and 2 are not")
	_check(TideController.warns_next(32, tcfg) and not TideController.warns_next(33, tcfg), "tide rules: the forecast comes at 32")
	var tide: TideController = _g("Tide") as TideController
	var water: Node3D = _map.get_node("TideWater") as Node3D
	_check(tide != null and water != null and absf(water.position.y - float(tcfg["low_y"])) < 0.01, "tide starts at low water")
	var lower: ZombieSpawn = _g("Ground_F_LOWERPENS_0") as ZombieSpawn
	var cat: ZombieSpawn = _g("Catwalk_D_PENHALL_0") as ZombieSpawn
	_check(lower.enabled and not cat.enabled, "low water: drain spawns on, catwalk spawns off")
	tide.on_round(33)
	await _secs(float(tcfg["rise_seconds"]) + 1.5)
	_check(absf(tide.level - float(tcfg["high_y"])) < 0.01 and absf(water.position.y - float(tcfg["high_y"])) < 0.01, "round 33: the water rose to high_y (%.2f)" % tide.level)
	_check(tide.flooded and not lower.enabled and cat.enabled, "high water: drain spawns off, catwalk spawns on")
	await _tp(Vector3(40.0, LY + 0.2, 62.0), 0.0)
	await _secs(1.0)
	_check(_p.has_status(&"wading") and _p.status_move_mult() < 0.9, "a player on the flooded deck wades (move x%.2f)" % _p.status_move_mult())
	z = await _zombie_at(Vector3(44.0, LY, 62.0))
	await _secs(1.0)
	_check(z.frost_speed_mult() < 0.9, "a zombie on the flooded deck is slowed (x%.2f)" % z.frost_speed_mult())
	_dir.kill_all(true)
	await _tp(Vector3(24.0, 0.2, 21.0), 180.0)
	tide.on_round(34)
	await _secs(float(tcfg["fall_seconds"]) + 1.5)
	_check(absf(tide.level - float(tcfg["low_y"])) < 0.01 and not tide.flooded and lower.enabled and not cat.enabled, "round 34: the water fell and the spawns switched back")

	# --- 4. rounds 31-34 with the bots
	_check(get_tree().get_nodes_in_group(&"players").size() == 4, "the human and 3 bots are in the match")
	_hits = 0
	_rounds_seen.clear()
	RoundManager.debug_set_round(31)
	var t: float = 0.0
	while t < 420.0 and not _rounds_seen.has(34):
		await _secs(1.0)
		t += 1.0
		# the squad "fights": anything that reaches a player dies (the human is in god mode and never shoots)
		for z2: Zombie in _dir.active_zombies():
			var reach: float = 4.0 if z2.enemy_id == &"ganger" or z2.enemy_id == &"glasshide" else 18.0   # a Screamer keeps its distance
			for pn: Node in get_tree().get_nodes_in_group(&"players"):
				if (pn as Player).is_alive() and z2.global_position.distance_to((pn as Player).global_position) < reach:
					z2.take_damage(z2.hp + 1.0, &"torso", &"kar98k", 1, &"bullet")
					break
		if RoundManager.current_round == 33 and tide.target > float(tcfg["low_y"]) and _tide_at_33.is_empty():
			_tide_at_33 = {"target": tide.target}
		if RoundManager.current_round == 34 and _tide_at_34.is_empty() and tide.target < float(tcfg["high_y"]) - 0.5:
			_tide_at_34 = {"target": tide.target}
	print("[m2] after the rounds phase: round=%d to_spawn=%d alive=%d" % [RoundManager.current_round, RoundManager.to_spawn, RoundManager.alive])
	for zd: Zombie in _dir.active_zombies():
		print("[m2]   zombie %s state=%s at %s zone=%s" % [zd.enemy_id, str(Zombie.State.keys()[zd.state]), str(zd.global_position), ZoneVolume.zone_at(get_tree(), zd.global_position)])
	_check(_rounds_seen.has(31) and _rounds_seen.has(32) and _rounds_seen.has(33), "rounds 31, 32 and 33 ran with the bots (%s, %.0f s)" % [str(_rounds_seen), t])
	_check(_rounds_seen.has(34), "round 34 started")
	_check(not _tide_at_33.is_empty(), "the tide came in at round 33 during play")
	_check(not _tide_at_34.is_empty(), "the tide went out at round 34 during play")
	var kills: int = int(GameState.stats.get(&"kills", 0))
	_check(kills > 0, "the squad killed zombies (%d)" % kills)
	var alive_bots: int = 0
	for n3: Node in get_tree().get_nodes_in_group(&"players"):
		if (n3 as Player).is_bot and (n3 as Player).is_alive():
			alive_bots += 1
	print("[m2] bots standing at the end: %d, human hit %d times" % [alive_bots, _hits])

	print("[m2] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
