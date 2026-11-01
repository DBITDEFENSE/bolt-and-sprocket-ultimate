extends Node
## Headless smoke test for Map 4 Act IV "Mondlicht" (UPDATE 07). The act is entered the way the launcher's "skip to
## Act IV" does (Campaign.begin_at at match round 30 with the arrival kit). In order:
##   1. the begin_at start: round 30 next, "ACT IV · 1", the kit (the Lodestone, a Thompson III, five perks), 0.38 g,
##      the vacuum rules, power on, no exfil (the act ends the campaign)
##   2. per-zone navigation with layer gating: reception → concourse → yard / store → hall → the Account
##   3. every ground / catwalk spawn stands on the navmesh; the per-zone counts match map04d.json
##   4. the placed systems: 8 perk machines, 2 crate spots, the Crucible, 3 columns, the sign, the console, 2 air
##      posts, the Earth, the Account's door shut by its flag
##   5. low gravity: a jump goes higher and hangs longer than at 1 g; the vacuum: the gauge runs down in the yard,
##      refills at a post, the suit mix is on the buses; the Suited die in vacuum from a cracked visor; a pressurized
##      Gänger hops at its target
##   6. the columns: three reads drop the sign's letters and open the Account; the door takes the flag
##   7. the Solar Flare: the posts fail, waves rise on the rim (the Suited), the posts come back at the round's end
##   8. the Account Manager: summoned when the Account opens; the arms, the renewal clock at 70 %, the trial, the
##      shield-cells at 35 % (one flung into the shaft), never dies: escalates at 0 and unlocks the console
##   9. the console: the cover, the vote, the key; the cancel ending at cutscene speed (relay cut, dioramas, cards,
##      credits) ends the run; then a second run: `renewal now` → the Retained state (perks kept, dust storms)
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04d.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04d.tscn"
const BITS: Dictionary = {"A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6}
const SHORT_ROUND: int = 8
const TIMEOUT: float = 1100.0

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _rounds_seen: Array[int] = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4d.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m4d_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	Campaign.begin_at(&"map04d_mondlicht", 30, Campaign.arrival_kit(&"map04d_mondlicht"))
	Campaign.cutscene_speed = 12.0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.round_started.connect(_on_round)
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
	print("[m4d] %-74s %s" % [what, "ok" if cond else "FAIL"])
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
	print("[m4d] %-74s %s (pts %d, end %s)" % [label, "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
	if not ok:
		_fails.append(label)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


func _zombie_at(pos: Vector3, kind: StringName = &"ganger") -> Zombie:
	var before: int = _dir.active_zombies().size()
	if kind == &"ganger":
		_dir.debug_spawn(1)
	else:
		_dir.debug_spawn_kind(kind, 1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	var z: Zombie = zs[zs.size() - 1]
	for c: Zombie in zs:
		if c.enemy_id == kind and (c.state == Zombie.State.TO_WINDOW or c.state == Zombie.State.EMERGE or c.state == Zombie.State.CHASE):
			z = c
	z.global_position = pos
	await _frames(2)
	return z


func _on_round(r: int, _special: bool) -> void:
	_rounds_seen.append(r)
	RoundManager.to_spawn = mini(RoundManager.to_spawn, SHORT_ROUND)
	RoundManager.round_total = mini(RoundManager.round_total, SHORT_ROUND)
	print("[m4d] round %d started (%s) t=%.0f" % [r, RoundManager.act_label(r), _t])


func _ctl() -> Node:
	return get_tree().get_first_node_in_group(&"mondlicht_controller")


func _bus_lowpass_on(bus_name: String) -> bool:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return false
	for i: int in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLowPassFilter and AudioServer.is_bus_effect_enabled(bus, i):
			return true
	return false


func _run() -> void:
	await _frames(40)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04d.json")

	# --- 1. the begin_at start
	_check(Campaign.active and RoundManager.current_round == 29 and RoundManager.state == RoundManager.State.BREAK, "begin_at: round 30 is next after the arrival grace (round %d, state %d)" % [RoundManager.current_round, RoundManager.state])
	_check(RoundManager.act_start == 30 and RoundManager.act_label(30) == "ACT IV · 1", "act numbering: match 30 is 'ACT IV · 1' (" + RoundManager.act_label(30) + ")")
	_check(_p.weapons.find_weapon(&"lodestone") != null and _p.weapons.find_weapon(&"thompson_up") != null, "the arrival kit is on the human (the Lodestone, Thompson III)")
	_check(PerkManager.owned(1).size() == 5 and PerkManager.owned(1).has(&"skyhook_sekt"), "the kit's five perks (%s)" % str(PerkManager.owned(1)))
	_check(is_equal_approx(GameState.gravity_scale, 0.38), "0.38 g on arrival (GameState.gravity_scale %.2f)" % GameState.gravity_scale)
	_check(is_equal_approx(GameState.slide_distance_mult, 1.4) and not GameState.vacuum_cfg.is_empty(), "slides 1.4x, the vacuum rules loaded")
	_check(GameState.power_on, "the relay runs: power on from the start")
	_check(get_tree().get_first_node_in_group(&"exfil_points") == null, "no exfil beacon: this act ends the campaign")
	_check(_ctl() != null and _ctl().get("director") != null, "the MondlichtController found the director")
	RoundManager.stop()
	Economy.grant(1, 100000)

	# --- 2. navigation
	_path_check("reception -> concourse (B open)", Vector3(0, 0, 8), Vector3(0, 0, 46), "A,B", true)
	_path_check("reception -> concourse with B shut", Vector3(0, 0, 8), Vector3(0, 0, 46), "A", false)
	_path_check("concourse -> yard (C open)", Vector3(0, 0, 40), Vector3(0, 0, 90), "B,C", true)
	_path_check("concourse -> yard with C shut", Vector3(0, 0, 40), Vector3(0, 0, 90), "B", false)
	_path_check("yard: the long oval, rim to rim", Vector3(-30, 0, 100), Vector3(30, 0, 100), "C", true)
	_path_check("concourse -> store (D open, by the concourse door)", Vector3(0, 0, 46), Vector3(28, 0, 38), "B,D", true)
	_path_check("yard -> store by the store's airlock", Vector3(28, 0, 90), Vector3(28, 0, 38), "C,D", true)
	_path_check("store -> hall (E open)", Vector3(28, 0, 38), Vector3(28, 0, 8), "D,E", true)
	_path_check("store -> hall with E shut", Vector3(28, 0, 38), Vector3(28, 0, 8), "D", false)
	_path_check("hall: round the columns", Vector3(14, 0, 8), Vector3(42, 0, 8), "E", true)
	_path_check("hall -> the Account (F open)", Vector3(28, 0, 8), Vector3(28, 0, -26), "E,F", true)
	_path_check("hall -> the Account with F shut", Vector3(28, 0, 8), Vector3(28, 0, -26), "E", false)
	_path_check("reception -> the Account (everything open)", Vector3(0, 0, 8), Vector3(28, 0, -36), "A,B,C,D,E,F", true)

	# --- 3. spawn points
	var rid: RID = _map.get_world_3d().navigation_map
	var counts: Dictionary = {}
	var off: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		var sp: ZombieSpawn = n as ZombieSpawn
		var z: String = String(sp.zone_id)
		var row: Dictionary = counts.get_or_add(z, {"windows": 0, "ground": 0, "catwalk": 0})
		if sp.kind == &"window":
			row["windows"] = int(row["windows"]) + 1
		elif String(sp.name).begins_with("Catwalk"):
			row["catwalk"] = int(row["catwalk"]) + 1
		else:
			row["ground"] = int(row["ground"]) + 1
		if sp.kind == &"ground":
			var snapped: Vector3 = NavigationServer3D.map_get_closest_point(rid, sp.global_position)
			if snapped.distance_to(sp.global_position) > 1.0:
				off += 1
				print("[m4d]   spawn %s is %.1f m off the navmesh" % [sp.name, snapped.distance_to(sp.global_position)])
	_check(off == 0, "every ground / catwalk spawn stands on the navmesh")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		var have: Dictionary = counts.get(zone, {"windows": 0, "ground": 0, "catwalk": 0})
		_check(int(have["windows"]) == int(want.get("windows", 0)) and int(have["ground"]) == int(want.get("ground", 0)) and int(have["catwalk"]) == int(want.get("catwalk", 0)),
			"%s spawns match the table (w%d g%d c%d)" % [zone, int(have["windows"]), int(have["ground"]), int(have["catwalk"])])

	# --- 4. the placed systems
	var perks: int = 0
	for n2: Node in _map.get_node("Gameplay").get_children():
		if n2 is PerkMachine:
			perks += 1
	_check(perks == 9, "9 perk machines (%d; Ledger Lager T-141)" % perks)
	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 2, "2 crate spots")
	_check(_g("Crucible") != null, "the first Crucible stands in the concourse")
	_check(get_tree().get_nodes_in_group(&"retention_columns").size() == 3, "3 retention columns")
	_check(get_tree().get_first_node_in_group(&"cancel_sign") != null and int(get_tree().get_first_node_in_group(&"cancel_sign").call("lit_letters")) == 13, "NOBODY CANCELS: 13 letters lit")
	var console: AccountConsole = get_tree().get_first_node_in_group(&"account_console") as AccountConsole
	_check(console != null and console.state == AccountConsole.C.DARK, "the console is dark before the Manager")
	_check(get_tree().get_nodes_in_group(&"air_posts").size() == 2 and AirPost.count_active(get_tree()) == 2, "2 air posts, both working")
	var sky: EarthSky = get_tree().get_first_node_in_group(&"earth_sky") as EarthSky
	_check(sky != null and sky.points.size() == 7, "the Earth hangs over the yard")
	var da: Node = _g("Door_Account")
	_check(da != null and da.get("requires_flag") == &"account_open", "the Account's door waits for account_open")
	var yard_vac: bool = ZoneVolume.vacuum_at(get_tree(), Vector3(0, 0.5, 85))
	_check(yard_vac and not ZoneVolume.vacuum_at(get_tree(), Vector3(0, 0.5, 40)), "the yard is vacuum, the concourse is not")
	for z in ["B_CONCOURSE", "C_YARD", "D_FULFILLMENT", "E_HALL"]:
		GameState.open_zone(StringName(z))
	_dir.recompute_nav_mask()

	# --- 5. low gravity and the vacuum
	await _tp(Vector3(0, 0, 40), 0.0)
	_p.velocity.y = float(_p._cfg["jump_velocity"]) * GameState.jump_mult()
	var top: float = 0.0
	var hang: float = 0.0
	var t0: float = _t
	await _frames(1)
	while not _p.is_on_floor() and _t - t0 < 4.0:
		top = maxf(top, _p.global_position.y)
		await get_tree().physics_frame
	hang = _t - t0
	_check(top > 1.4 and hang > 1.2, "a Moon jump: %.2f m up, %.2f s in the air (1 g: ~0.63 m, ~0.6 s; x2.6)" % [top, hang])
	await _tp(Vector3(0, 0, 85), 0.0)
	await _secs(2.5)
	_check(_p.in_vacuum and _p.air < _p.air_max - 1.5, "in the yard the gauge runs down (%.1f / %.0f s)" % [_p.air, _p.air_max])
	_check(_p.has_status(&"vacuum"), "the vacuum status is on")
	_check(_bus_lowpass_on("SFX"), "the suit's mix: a low-pass on the SFX bus")
	await _tp(Vector3(-24, 0, 84), 0.0)
	await _secs(3.5)
	_check(not _p.in_vacuum and _p.air > _p.air_max - 0.5, "at an air post the gauge refills (%.1f)" % _p.air)
	await _tp(Vector3(0, 0, 85), 0.0)
	_p.air = 0.0
	GameState.god_mode = false
	var hp0: float = _p.hp
	await _secs(1.6)
	_check(_p.hp < hp0, "at zero air the suit's wearer takes damage (%.0f -> %.0f)" % [hp0, _p.hp])
	GameState.god_mode = true
	_p.hp = _p.max_hp
	await _tp(Vector3(0, 0, 40), 0.0)
	await _secs(0.5)
	_check(not _p.in_vacuum and not _bus_lowpass_on("SFX"), "back in pressure: the mix is off")
	await _part_enemies()
	await _part_columns()
	await _part_flare()
	await _part_manager()
	await _part_endings()
	_finish()


func _part_enemies() -> void:
	# the Suited: vacuum-only, a cracked visor kills in vacuum after 2 s
	if not (GLData.table("enemies")["enemies"] as Dictionary).has("suited"):
		print("[m4d] (the Suited are not in enemies.json yet: skipped)")
		return
	var s: Zombie = await _zombie_at(Vector3(5, 0, 85), &"suited")
	_check(s.enemy_id == &"suited" and s.hp > 150.0 * 1.3, "a Suited rises in the yard with x1.4 health (%d)" % int(s.hp))
	s.take_damage(10.0, &"head", &"kar98k", 1, &"bullet")
	_check(bool(s.get("visor_cracked")), "a visor hit cracks the visor")
	var died: bool = await _until(func() -> bool: return not s.is_active(), 4.0)
	_check(died, "the Suited died in vacuum 2 s after the crack")
	var s2: Zombie = await _zombie_at(Vector3(0, 0, 40), &"suited")
	s2.take_damage(10.0, &"head", &"kar98k", 1, &"bullet")
	await _secs(2.6)
	_check(s2.is_active(), "in pressure a cracked visor is just a headshot")
	s2.kill_silently()
	# the low-g hop: a pressurized Gänger with a line to its target leaps
	await _tp(Vector3(0, 0, 50), 180.0)
	var g: Zombie = await _zombie_at(Vector3(0, 0, 43))
	if g.window != null:
		g.window.release(g)
		g.window = null
	g.forced_target = _p
	g._hop_cd = 0.0
	g._enter(Zombie.State.CHASE)
	g.set_physics_process(true)
	var hopped: bool = await _until(func() -> bool: return bool(g.get("hopping")) or int(g.get("hops_done")) > 0, 8.0)
	_check(hopped, "a pressurized Gänger hops at its target in low g")
	_dir.kill_all(true)
	await _frames(2)


func _part_columns() -> void:
	var cols: Array[Node] = get_tree().get_nodes_in_group(&"retention_columns")
	cols.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("index")) < int(b.get("index")))
	var sign: Node = get_tree().get_first_node_in_group(&"cancel_sign")
	var c1: RetentionColumn = cols[0] as RetentionColumn
	await _tp(c1.global_position + Vector3(0, 0, 2.0), 180.0)
	_check(c1.get_prompt(_p).contains("read the terms") and is_equal_approx(c1.hold_time(_p), 4.0), "column I: 'read the terms', a 4 s hold")
	c1.lift_cap()
	_check(is_equal_approx(c1.hold_time(_p), 1.0) and GameState.has_flag(&"cap_lifted_1"), "the cap lifted: a 1 s read")
	_p.use_interactable(c1)
	await _frames(3)
	_check(c1.dark and GameState.has_flag(&"column_1_dark"), "column I read: dark, flag column_1_dark")
	await _secs(1.5)
	_check(int(sign.call("lit_letters")) == 12, "one letter fell off the sign (%d lit)" % int(sign.call("lit_letters")))
	_check(not GameState.has_flag(&"account_open"), "the Account stays shut after one")
	(cols[1] as RetentionColumn).read_terms(1)
	(cols[2] as RetentionColumn).read_terms(0)
	await _secs(1.5)
	_check(GameState.has_flag(&"account_open"), "three dark: account_open")
	_check(int(sign.call("lit_letters")) == 7, "N B D  C N  LS: 7 letters left (%d)" % int(sign.call("lit_letters")))
	var da: Node = _g("Door_Account")
	await _tp(Vector3(28, 0, -14), 0.0)
	_check(da != null and da.call("can_interact", _p), "the Account's door takes the flag")
	_dir.kill_all(true)


func _part_flare() -> void:
	var flare: SolarFlare = _map.get_node_or_null("Gameplay/SolarFlare") as SolarFlare
	_check(flare != null and _dir.special_handler == flare, "the Solar Flare is the act's special handler")
	if flare == null:
		return
	RoundManager.is_special_round = true
	RoundManager.state = RoundManager.State.ROUND
	RoundManager.to_spawn = 9
	RoundManager.round_total = 9
	RoundManager.alive = 0
	flare._on_round_started(31, true)
	_check(AirPost.count_active(get_tree()) == 0, "the flare: both air posts fail")
	flare.tick_special(10.0)
	await _frames(3)
	var suited: int = 0
	for z: Zombie in _dir.active_zombies():
		if z.enemy_id == &"suited":
			suited += 1
	_check(flare.waves_fired == 1 and _dir.active_zombies().size() >= 3, "a wave rose on the rim (%d dead, %d suited)" % [_dir.active_zombies().size(), suited])
	flare._on_round_ended(31)
	RoundManager.is_special_round = false
	RoundManager.state = RoundManager.State.IDLE
	RoundManager.to_spawn = 0
	_check(AirPost.count_active(get_tree()) == 2, "the round over: the posts come back")
	_dir.kill_all(true)
	await _frames(2)


func _part_manager() -> void:
	var ctl: Node = _ctl()
	GameState.open_zone(&"F_CORE")
	_dir.recompute_nav_mask()
	await _frames(4)
	var am: Node = ctl.get("boss")
	if am == null:
		print("[m4d] (the Account Manager is not built yet: the finale parts are skipped)")
		return
	_check(GameState.has_flag(&"manager_present") and am.is_active(), "the Account Manager attends when the Account opens")
	var console: AccountConsole = get_tree().get_first_node_in_group(&"account_console") as AccountConsole
	_check(console.state == AccountConsole.C.SHIELDED and not console.can_interact(_p), "the console is shielded while she attends")
	await _tp(Vector3(28, 0, -26), 180.0)
	var armed: bool = await _until(func() -> bool: return int(am.get("arms_done")) > 0, 20.0)
	_check(armed, "ONBOARDING: the welcome arms swept (%d)" % int(am.get("arms_done")))
	am._present(1)
	var hp_a: float = am.hp
	am.take_damage(1000.0, &"torso", &"kar98k", 1, &"bullet")
	_check(am.hp < hp_a - 1000.0, "the contract presented: the torso takes x2.5 (%.0f)" % (hp_a - am.hp))
	am.hp = am.max_hp * 0.65
	await _frames(3)
	_check(int(am.get("phase")) == 2, "at 65 %%: RENEWAL (phase %d)" % int(am.get("phase")))
	_check(float(ctl.get("renewal_left")) > 0.0, "the renewal clock runs (%.0f s)" % float(ctl.get("renewal_left")))
	var trial: Node = get_tree().get_first_node_in_group(&"trial_offer")
	_check(trial != null, "the trial is offered")
	if trial != null:
		var owned0: int = PerkManager.owned(1).size()
		_p.use_interactable(trial)
		await _frames(2)
		_check(PerkManager.owned(1).size() > owned0, "taking the trial: every perk (%d)" % PerkManager.owned(1).size())
		am.call("end_trial")
		await _frames(2)
		_check(PerkManager.owned(1).size() < owned0 + 1, "the trial ended: the perks are stripped (%d left)" % PerkManager.owned(1).size())
	am.hp = am.max_hp * 0.32
	await _frames(3)
	_check(int(am.get("phase")) == 3, "at 32 %%: COLLECTIONS (phase %d)" % int(am.get("phase")))
	var cells: Array = am.call("live_cells")
	_check(cells.size() == 3, "three shield-cells orbit her (%d)" % cells.size())
	if cells.size() > 0:
		var c0: Zombie = cells[0] as Zombie
		am.presenting = 0.0
		var hp1: float = am.hp
		am.take_damage(1000.0, &"torso", &"kar98k", 1, &"bullet")
		_check(am.hp > hp1 - 400.0, "with cells up she takes a fifth of the damage (%.0f)" % (hp1 - am.hp))
		c0.global_position = Vector3(28, 8.5, -30)
		await _frames(3)
		_check((not is_instance_valid(c0) or not c0.is_active()) and int(am.get("cells_lost")) >= 1, "a cell carried into the shaft is gone for good")
		_check((am.call("live_cells") as Array).size() == 2, "two cells left (%d)" % (am.call("live_cells") as Array).size())
	var priced: bool = await _until(func() -> bool: return int(am.get("prices_done")) > 0, 20.0)
	_check(priced, "COLLECTIONS: she priced a player (%d)" % int(am.get("prices_done")))
	am.take_damage(am.max_hp * 2.0, &"torso", &"console", 1, &"world")
	await _frames(3)
	_check(bool(am.get("escalated")) and GameState.has_flag(&"manager_escalated"), "at 0 %: she escalates, never dies")
	_check(am.hp > 0.0 and not bool(am.get("gone")), "and stays on the floor, folded")
	_check(console.state == AccountConsole.C.COVER, "the console's cover is unlocked")
	_check(float(ctl.get("renewal_left")) > 0.0, "the clock keeps running until the key turns")


func _part_endings() -> void:
	var console: AccountConsole = get_tree().get_first_node_in_group(&"account_console") as AccountConsole
	var ctl: Node = _ctl()
	if console.state != AccountConsole.C.COVER:
		GameState.set_flag(&"manager_escalated")
		await _frames(2)
	await _tp(Vector3(28, 0, -28), 180.0)
	_check(console.can_interact(_p) and console.get_prompt(_p).contains("cover"), "the cover: '" + console.get_prompt(_p) + "'")
	_p.use_interactable(console)
	await _frames(2)
	_check(console.state == AccountConsole.C.VOTE and console.get_prompt(_p).contains("CANCEL"), "the vote: '" + console.get_prompt(_p) + "'")
	_p.use_interactable(console)
	await _frames(3)
	_check(console.state == AccountConsole.C.DONE and GameState.has_flag(&"cancelled"), "solo: one hold turns the key")
	var ending: Node = ctl.get("ending")
	_check(ending != null, "the cancel ending runs")
	if ending == null:
		return
	_check(float(ctl.get("renewal_left")) < 0.0, "the clock stopped")
	var sky: EarthSky = get_tree().get_first_node_in_group(&"earth_sky") as EarthSky
	var cut: bool = await _until(func() -> bool: return sky.frozen, 30.0)
	_check(cut, "the relay cut: the Earth's violet freezes")
	var cards: bool = await _until(func() -> bool: return int(ending.get("cards_shown")) > 0, 60.0)
	_check(cards, "the epilogue cards showed (%d)" % int(ending.get("cards_shown")))
	var over: bool = await _until(func() -> bool: return GameState.phase == GameState.Phase.GAME_OVER, 90.0)
	_check(over, "the credits ran and the run ended (phase GAME_OVER)")
	_check((ProfileSave.profile.get("endings_seen", []) as Array).has("kuendigung"), "profile: endings_seen has kuendigung")
	_check(not GameState.retained, "not retained: the canon ending")


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[m4d] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
