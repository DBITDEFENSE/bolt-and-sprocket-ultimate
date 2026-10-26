extends Node
## Headless smoke test for Map 4 Act II "der Kranich, in flight" (UPDATE 07). The act is entered the way the
## launcher's "skip to Act II" does (Campaign.begin_at at match round 15 with the arrival kit). In order:
##   1. the begin_at start: round 15 next, act round 1 ("ACT II · 1"), the arrival kit on the human
##   2. per-zone navigation with layer gating: bay → centre body → wings → engine room / blisters → cockpit by
##      both walkways, shut doors block
##   3. every ground / catwalk spawn stands on the navmesh; the per-zone counts match map04b.json
##   4. the placed systems: 8 perk machines, the galley crate, the cockpit door needs the aux bus and the key,
##      the bus lights every zone, the Crucible forges a gun
##   5. the flight systems driven directly: a breach pulls the player and swallows a zombie, a seal shuts it; a
##      bank rolls the camera and pushes; a strafe rakes the bay and hurts a zombie on its line
##   6. rounds 15-19 with 3 bots (shortened): the London window plays at round 17 (act 3) at cutscene speed and
##      hands the camera back; the Bordwart is summoned on round 18 (act 4) at his station, pulls or vents,
##      reaches his cable phase at 60 %, dies by console and drops the autopilot key; the bomb run starts on
##      round 19 (act 5): rack 1 is away, two racks are jammed by console, the run finishes with flags per city
##   7. the autopilot: the egg's flag lights the cradle early, the key gate, the unlock stage, the 6 s rip-out
##      vote, the crash cutscene at speed, and Act III loading with the carry-over (round 21 = "ACT III · 1")
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04b.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04b.tscn"
const BITS: Dictionary = {"A": 1, "B": 2, "CL": 3, "CR": 4, "D": 5, "E": 6, "F": 7}
const SHORT_ROUND: int = 8
const TIMEOUT: float = 1000.0

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _hits: int = 0
var _rounds_seen: Array[int] = []
var _london_done: bool = false
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4b.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m4b_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	Campaign.begin_at(&"map04b_kranich", 15, Campaign.arrival_kit(&"map04b_kranich"))
	Campaign.cutscene_speed = 12.0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.player_damaged.connect(func(_p: int, _a: float) -> void: _hits += 1)
	GLBus.round_started.connect(_on_round)
	GLBus.flag_changed.connect(func(f: StringName, v: Variant) -> void:
		if f == &"london_window_done" and bool(v):
			_london_done = true)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if not _done and _t > TIMEOUT:
		_fails.append("timeout after %.0f s" % _t)
		_finish()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _check(cond: bool, what: String) -> void:
	print("[m4b] %-70s %s" % [what, "ok" if cond else "FAIL"])
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
	print("[m4b] %-70s %s (pts %d, end %s)" % [label, "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
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
	print("[m4b] round %d started (%s) t=%.0f" % [r, RoundManager.act_label(r), _t])


func _exfil() -> ExfilPoint:
	return get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint


func _end_screen() -> Node:
	if _map == null or not is_instance_valid(_map):
		return null
	for c: Node in _map.get_children():
		if c is CampaignEndScreen:
			return c
	return null


## Rounds run with the bots; zombies that reach a player are shot by the console so the rounds keep moving.
func _run_rounds_until(target: int, seconds: float) -> float:
	var t: float = 0.0
	while t < seconds and not _rounds_seen.has(target):
		await _secs(1.0)
		t += 1.0
		for z2: Zombie in _dir.active_zombies():
			if z2 is HomageBoss:
				continue
			for pn: Node in get_tree().get_nodes_in_group(&"players"):
				if (pn as Player).is_alive() and z2.global_position.distance_to((pn as Player).global_position) < 4.0:
					z2.take_damage(z2.hp + 1.0, &"torso", &"kar98k", 1, &"bullet")
					break
	return t


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector

	# --- 1. the begin_at start
	_check(Campaign.active and RoundManager.current_round == 14 and RoundManager.state == RoundManager.State.BREAK, "begin_at: round 15 is next after the arrival grace (round %d, state %d)" % [RoundManager.current_round, RoundManager.state])
	_check(RoundManager.act_start == 15 and RoundManager.act_label(15) == "ACT II · 1", "act numbering: match 15 is 'ACT II · 1' (" + RoundManager.act_label(15) + ")")
	_check(_p.weapons.find_weapon(&"thompson_up") != null and _p.weapons.find_weapon(&"mp40") != null, "the arrival kit is on the human (Thompson II, MP40)")
	_check(PerkManager.owned(1).has(&"ironhide_stout") and PerkManager.owned(1).has(&"second_wind") and PerkManager.owned(1).has(&"marathon_malt"), "the kit's three perks (%s)" % str(PerkManager.owned(1)))
	_check(_p.weapons.grenades == 3, "three grenades in the kit (%d)" % _p.weapons.grenades)
	var x: ExfilPoint = _exfil()
	_check(x != null and x.state == ExfilPoint.State.DORMANT and x.next_round() == 20, "the autopilot cradle is dormant, due at match round 20 (%s)" % (str(x.next_round()) if x != null else "none"))
	RoundManager.stop()
	Economy.grant(1, 100000)

	# --- 2. navigation
	var all: String = "A,B,CL,CR,D,E,F"
	_path_check("bay aft -> bay forward", Vector3(0, 0, 2), Vector3(0, 0, 22), "A", true)
	_path_check("bay -> centre body (B open)", Vector3(0, 0, 12), Vector3(0, 0, 40), "A,B", true)
	_path_check("bay -> centre body with B shut", Vector3(0, 0, 12), Vector3(0, 0, 40), "A", false)
	_path_check("centre body -> port wing (CL open)", Vector3(0, 0, 36), Vector3(-30, 0, 37), "B,CL", true)
	_path_check("centre body -> port wing with CL shut", Vector3(0, 0, 36), Vector3(-30, 0, 37), "B", false)
	_path_check("centre body -> starboard wing (CR open)", Vector3(0, 0, 36), Vector3(30, 0, 37), "B,CR", true)
	_path_check("port wing -> engine room (D open)", Vector3(-30, 0, 37), Vector3(-70, 0, 40), "CL,D", true)
	_path_check("port wing -> engine room with D shut", Vector3(-30, 0, 37), Vector3(-70, 0, 40), "CL", false)
	_path_check("engine room -> port walkway", Vector3(-70, 0, 40), Vector3(-30, 0, 54), "D", true)
	_path_check("engine room -> flight deck by the port walkway (F open)", Vector3(-70, 0, 40), Vector3(0, 0, 64), "D,F", true)
	_path_check("engine room -> flight deck with F shut", Vector3(-70, 0, 40), Vector3(0, 0, 64), "D", false)
	_path_check("starboard wing -> gun blisters (E open)", Vector3(30, 0, 37), Vector3(70, 0, 40), "CR,E", true)
	_path_check("blisters -> the blister rims", Vector3(70, 0, 40), Vector3(62, 0, 26), "E", true)
	_path_check("blisters -> flight deck by the starboard walkway", Vector3(70, 0, 40), Vector3(0, 0, 64), "E,F", true)
	_path_check("bay -> flight deck (everything open)", Vector3(0, 0, 8), Vector3(0, 0, 64), all, true)

	# --- 3. spawn points
	var rid: RID = _map.get_world_3d().navigation_map
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04b.json")
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
			print("[m4b]   spawn off the navmesh: %s at %s (nearest %s)" % [sp.name, sp.global_position, near])
	_check(bad == 0, "every ground / catwalk spawn stands on the navmesh")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		var have: Dictionary = counts.get(zone, {})
		var ok: bool = int(have.get("windows", 0)) == int(want.get("windows", 0)) and int(have.get("ground", 0)) == int(want.get("ground", 0)) \
			and int(have.get("catwalk", 0)) == int(want.get("catwalk", 0))
		_check(ok, "%s spawn counts match map04b.json (%s)" % [zone, str(have)])

	# --- 4. systems
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)
	var perks: int = 0
	for n2: Node in _g("").get_children():
		if n2 is PerkMachine:
			perks += 1
	_check(perks == 8, "8 perk machines placed")
	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 1, "the galley crate spot")
	_check(RoundManager.has_act() and RoundManager.act_index() == 2, "the act block is loaded (index 2)")
	var cl: BuyDoor = _g("Door_CockpitL") as BuyDoor
	var cr: BuyDoor = _g("Door_CockpitR") as BuyDoor
	_check(cl != null and cr != null and cl.get_prompt(_p) == "Power must be activated", "cockpit door: 'Power must be activated' (" + (cl.get_prompt(_p) if cl != null else "none") + ")")
	var cru: Node = _g("Crucible")
	_check(cru != null and (cru as Interactable).get_prompt(_p).contains("Power"), "Crucible refuses before the bus")
	var alive0: int = RoundManager.alive
	(_g("AuxBus")).call("run_sequence", 1)
	await _secs(10.5)
	var lit: int = 0
	var total: int = 0
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		total += 1
		if (l as OmniLight3D).light_energy > 0.05:
			lit += 1
	_check(GameState.power_on and lit == total and total >= 7, "aux bus on: %d/%d zone lights lit" % [lit, total])
	_check(RoundManager.alive > alive0, "power-on burst spawned zombies (%d)" % (RoundManager.alive - alive0))
	_dir.kill_all(true)
	_check(not cl.can_interact(_p) and cl.get_prompt(_p).contains("engineer"), "cockpit door still waits for the engineer's key (" + cl.get_prompt(_p) + ")")
	GameState.set_flag(&"autopilot_key")
	await _frames(3)
	_check(cl.get_prompt(_p).contains("1500"), "with the key the cockpit door sells for 1,500 (" + cl.get_prompt(_p) + ")")
	cl.open(0)
	await _frames(3)
	_check(cr.is_open and GameState.is_zone_open(&"F_COCKPIT"), "the cockpit pair opens together (one link group)")
	GameState.flags.erase(&"autopilot_key")   # the Bordwart drops the real one in part 6
	# the Crucible in the centre body
	await _tp(Vector3(-5.0, 0.2, 34.0), -90.0)
	var mp: WeaponInstance = _p.weapons.find_weapon(&"mp40")
	_p.weapons.current_index = _p.weapons.slots.find(mp)
	_check((cru as Interactable).get_prompt(_p).contains("5000"), "Crucible prompt: " + (cru as Interactable).get_prompt(_p))
	(cru as Interactable).interact(_p)
	await _secs(5.5)
	(cru as Interactable).interact(_p)
	await _frames(3)
	_check(_p.weapons.find_weapon(&"mp40_up") != null, "Crucible upgraded the MP40")

	# --- 5. the flight systems, driven directly
	var fc: FlightController = _g("FlightController") as FlightController
	_check(fc != null and not fc.cfg.is_empty() and fc.director == _dir and _dir.special_handler == fc, "the FlightController owns the act's set-pieces and the special round")
	_check(fc.racks.size() == 6, "six racks registered, in order")
	var marked: int = 0
	for r: Node in fc.racks:
		if bool(r.get("marked")):
			marked += 1
	_check(marked == 2 and not bool(fc.racks[0].get("marked")), "two chalked duds, never rack 1")
	# a breach: suction on the player, a zombie at the hole dies, a seal shuts it
	var bl1: BreachPanel = _g("BreachL1") as BreachPanel
	await _tp(Vector3(-20.0, 0.2, 42.0), 0.0)
	var z0: float = _p.global_position.z
	fc.blow_panel(bl1)
	await _frames(2)
	_check(bl1.is_open and bl1.times_blown == 1, "BreachL1 blew")
	await _secs(1.0)
	_check(_p.global_position.z > z0 + 0.3, "the breach pulls the player toward the hole (%.1f -> %.1f)" % [z0, _p.global_position.z])
	var zb: Zombie = await _zombie_at(Vector3(-20.5, 0.0, 46.3))
	await _secs(0.5)
	_check(not zb.is_active(), "a zombie at the hole went out of it")
	_check(bl1.get_prompt(_p).contains("seal") and bl1.hold_time(_p) == 2.0, "seal prompt and a 2 s hold (" + bl1.get_prompt(_p) + ")")
	bl1.interact(_p)
	await _frames(2)
	_check(not bl1.is_open, "the breach is sealed")
	await _tp(Vector3(0.0, 0.2, 12.0), 0.0)
	# a bank
	fc.bank_now()
	await _frames(2)
	_check(fc.banking and absf(_p.ext_roll_deg) > 1.0, "a bank: the camera rolls (%.1f°) and the deck pushes" % _p.ext_roll_deg)
	await _secs(7.0)
	_check(not fc.banking and _p.ext_roll_deg == 0.0, "the bank ended and the camera levelled")
	# a strafe over the bay
	var hb: int = _hits
	fc.strafe_now()
	_check(fc.strafes_done == 1 and fc._strafe_zone == "A_BOMBENSCHACHT", "fighters rake the zone the player stands in (%s)" % fc._strafe_zone)
	await _secs(2.6)
	_check(fc._strafe_lines.size() == 3, "three tracer lines are live (%d)" % fc._strafe_lines.size())
	if not fc._strafe_lines.is_empty():
		var ln: Dictionary = fc._strafe_lines[0]
		var zs: Zombie = await _zombie_at(Vector3(float(ln["x"]), 0.0, 12.0))
		var hp0: float = zs.hp
		await _secs(0.5)
		_check(not zs.is_active() or zs.hp < hp0, "a zombie on the line is shot (hp %.0f -> %.0f)" % [hp0, zs.hp])
	await _secs(2.5)
	_check(fc._strafe_lines.is_empty(), "the lines are gone after their seconds")
	print("[m4b] player hit %d times by the strafe (god mode)" % (_hits - hb))
	_dir.kill_all(true)

	# --- 6. rounds 15-19 with the bots: London at 17, the Bordwart at 18, the bomb run at 19
	_check(get_tree().get_nodes_in_group(&"players").size() == 4, "the human and 3 bots are in the match")
	_rounds_seen.clear()
	await _tp(Vector3(0.0, 0.2, 8.0), 0.0)
	RoundManager.reserve_round(18)   # RoundManager.stop() above dropped the ActController's reservation of the boss round
	RoundManager.debug_set_round(15)
	var t: float = await _run_rounds_until(17, 300.0)
	_check(_rounds_seen.has(15) and _rounds_seen.has(16) and _rounds_seen.has(17), "rounds 15, 16 and 17 ran with the bots (%s, %.0f s)" % [str(_rounds_seen), t])
	_check(RoundManager.act_label(17) == "ACT II · 3", "round 17 reads 'ACT II · 3' (" + RoundManager.act_label(17) + ")")
	await _frames(3)
	_check(fc.london_started and GameState.has_flag(&"london_seen"), "the London window opened on act round 3")
	var lw: Node = _map.get_node_or_null("LondonWindow")
	_check(lw != null and not _p.camera.current, "the window's camera took over")
	var back: bool = await _until(func() -> bool: return _london_done, 30.0)
	_check(back and _p.camera.current and GameState.god_mode, "the window finished at cutscene speed and handed the camera back (god mode kept)")
	# the Bordwart on round 18: stand in the engine room so he has someone to pull
	var ac: ActController = _g("ActController") as ActController
	_check(ac != null and ac.boss_round_match == 18, "the Bordwart's round is reserved at match 18 (%d)" % (ac.boss_round_match if ac != null else -1))
	t = await _run_rounds_until(18, 200.0)
	_check(_rounds_seen.has(18), "round 18 started (%.0f s)" % t)
	await _tp(Vector3(-66.0, 0.2, 38.0), 90.0)
	var got: bool = await _until(func() -> bool: return ac.boss != null and is_instance_valid(ac.boss) and ac.boss.is_active(), 10.0)
	_check(got and ac.boss is Bordwart, "the Bordwart is summoned on his round")
	if got and ac.boss is Bordwart:
		var bw: Bordwart = ac.boss as Bordwart
		_check(bw.global_position.distance_to(Vector3(-72, 0, 38)) < 3.0, "he stands at his station (%s)" % str(bw.global_position))
		_check(bw.max_hp >= 30000.0, "his health is 30,000 scaled (%d)" % int(bw.max_hp))
		var t2: float = 0.0
		while t2 < 25.0 and bw.pulls_done + bw.vents_done + bw.lashes_done == 0:
			await _secs(0.5)
			t2 += 0.5
		_check(bw.pulls_done + bw.vents_done + bw.lashes_done > 0, "he pulled, vented or lashed (%d/%d/%d in %.0f s)" % [bw.pulls_done, bw.vents_done, bw.lashes_done, t2])
		# the failsafe's path: a retreat pays both of his alive counts, so the round can end without him
		# (the round is live, so the count is compared against the director's: a boss is one body counted twice)
		_check(RoundManager.alive - _dir.active_zombies().size() == 1, "while he stands the round counts him twice (alive %d, bodies %d)" % [RoundManager.alive, _dir.active_zombies().size()])
		bw.retreat()
		var gone: bool = await _until(func() -> bool: return not is_instance_valid(bw) or bw.gone, 6.0)
		await _secs(0.5)
		_check(gone and RoundManager.alive == _dir.active_zombies().size(), "a retreat releases both counts (alive %d, bodies %d)" % [RoundManager.alive, _dir.active_zombies().size()])
		# summoned again (by console) for the fight proper
		bw = _dir.summon_boss(&"bordwart", Vector3.ZERO) as Bordwart
		ac.boss = bw
		await _frames(2)
		_check(bw != null and bw.is_active(), "summoned again by console")
		bw.take_damage(bw.max_hp * 0.5, &"torso", &"kar98k", 1, &"bullet")
		await _frames(2)
		_check(bw.phase >= 2, "half his health: the cable phase (%d)" % bw.phase)
		bw.debug_kill(1)
		await _secs(1.0)
		_check(not bw.is_active(), "the Bordwart is dead")
		await _secs(0.5)
		_check(RoundManager.alive == _dir.active_zombies().size(), "his death releases both counts (alive %d, bodies %d)" % [RoundManager.alive, _dir.active_zombies().size()])
		_check(GameState.has_flag(&"autopilot_key"), "he dropped the autopilot key")
	await _tp(Vector3(0.0, 0.2, 8.0), 0.0)
	# the bomb run on round 19
	t = await _run_rounds_until(19, 200.0)
	_check(_rounds_seen.has(19), "round 19 started (%.0f s)" % t)
	await _secs(3.5)
	_check(fc.run_on, "the bomb run is on (act round 5)")
	var st: Array = fc.rack_states()
	_check(st.size() == 6 and str(st[0]) == "dropped", "rack 1 (Boston) is away first (%s)" % str(st))
	var jammed: int = 0
	for r2: Node in fc.racks:
		if jammed < 2 and int(r2.get("state")) == BombRack.R.ARMED:
			r2.call("jam", 1)
			jammed += 1
	await _frames(2)
	var saved: int = 0
	for c: String in fc.rack_results.keys():
		if str(fc.rack_results[c]) == "saved":
			saved += 1
	_check(saved >= 2, "two racks jammed by console are saved (%s)" % str(fc.rack_results))
	var t3: float = 0.0
	while t3 < 40.0 and not fc.run_done:
		fc.run_t = 1000.0
		await _secs(0.5)
		t3 += 0.5
	_check(fc.run_done and fc.rack_results.size() == 6, "the run finished with a result per city (%s)" % str(fc.rack_results))
	_check(GameState.has_flag(&"bomb_boston_hit") and GameState.has_flag(&"bomb_run_done"), "flags: bomb_boston_hit, bomb_run_done")
	var duds: int = 0
	for c2: String in fc.rack_results.keys():
		if str(fc.rack_results[c2]) == "dud":
			duds += 1
	print("[m4b] cities: %d saved, %d duds, %d hit" % [saved, duds, 6 - saved - duds])
	RoundManager.stop()
	_dir.kill_all(true)

	# --- 7. the autopilot: lit by the flag, the key gate, the unlock stage, the rip-out vote, the crash
	x = _exfil()
	_check(x != null and x.state == ExfilPoint.State.DORMANT, "the cradle is still dormant before round 20")
	GameState.set_flag(&"autopilot_now")
	await _frames(2)
	_check(x.is_active(), "the egg's flag lights the cradle early (trigger_flag)")
	await _tp(x.global_position + x.global_basis * Vector3(0, 0, -1.6), 0.0)
	GameState.flags.erase(&"autopilot_key")
	_check(not x.can_interact(_p) and x.get_prompt(_p).contains("key"), "without the key: '" + x.get_prompt(_p) + "'")
	GameState.set_flag(&"autopilot_key")
	_check(x.can_interact(_p) and x.get_prompt(_p).contains("unlock") and x.hold_time(_p) == 2.0, "with the key: the unlock stage, 2 s (" + x.get_prompt(_p) + ")")
	_p.use_interactable(x)
	await _frames(2)
	_check(GameState.has_flag(&"autopilot_unlocked") and x.state == ExfilPoint.State.ACTIVE, "the stage set autopilot_unlocked; the cradle still waits for the vote")
	_check(x.get_prompt(_p).contains("exfil") and x.hold_time(_p) == 6.0, "then the 6 s rip-out hold (" + x.get_prompt(_p) + ")")
	_p.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING and x.cutscene != null and is_instance_valid(x.cutscene), "the vote passed: the crash cutscene plays")
	print("[m4b] Act III scene present: %s" % str(Campaign.scene_exists(&"map04c_groomlake")))
	if Campaign.scene_exists(&"map04c_groomlake"):
		# the crash lands the squad on the salt: Act III loads with the carry-over and its own numbering
		var swapped: bool = await _until(func() -> bool:
			var m: MapRoot = _map_root()
			return m != null and m.map_id == &"map04c_groomlake" and m.is_node_ready(), 120.0)
		_check(swapped, "Groom Lake loaded after the crash cutscene")
		if swapped:
			await _secs(2.0)
			var m3: MapRoot = _map_root()
			# the smoke left the Kranich during round 19 (by console), so the act continues from there: the arrival
			# round is the act's first round, whatever it is (the campaign's own run leaves on 20 and arrives on 21)
			var arrive: int = RoundManager.current_round + 1
			_check(RoundManager.state == RoundManager.State.BREAK and arrive >= 20, "Act III starts in the arrival grace, round %d next (state %d)" % [arrive, RoundManager.state])
			_check(RoundManager.act_start == arrive and RoundManager.act_label(arrive) == "ACT III · 1", "the arrival round reads 'ACT III · 1' (" + RoundManager.act_label(arrive) + ")")
			_check(m3.players.size() == 4, "the same squad came down (1 human + 3 bots)")
			var hp: Player = m3.player
			_check(hp != null and hp.weapons.find_weapon(&"thompson_up") != null and hp.weapons.find_weapon(&"mp40_up") != null, "the human's guns carried (Thompson II, the forged MP40)")
			_check(PerkManager.owned(1).has(&"ironhide_stout"), "the perks carried")
			var x3: ExfilPoint = _exfil()
			_check(x3 != null and x3.state == ExfilPoint.State.DORMANT and x3.next_round() == RoundManager.act_start + 8, "the gantry lift is dormant, due on act round 9 (match %s)" % (str(x3.next_round()) if x3 != null else "none"))
			_check(m3.get_node_or_null("Gameplay/GroomController") != null, "the GroomController is on the salt")
	else:
		var ended: bool = await _until(func() -> bool: return _end_screen() != null, 90.0)
		_check(ended, "no Act III in this build: the 'campaign continues' screen showed after the crash")
		_check(GameState.phase == GameState.Phase.GAME_OVER, "the run ended cleanly (phase GAME_OVER)")
	_check(ProfileSave.is_map_unlocked(&"map04c_groomlake"), "profile: Groom Lake unlocked by the exfil")
	_finish()


func _map_root() -> MapRoot:
	for c: Node in get_tree().root.get_children():
		if c is MapRoot:
			return c as MapRoot
	return null


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[m4b] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
