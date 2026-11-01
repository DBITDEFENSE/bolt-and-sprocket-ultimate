extends Node
## Headless smoke test for Map 4 Act III "Groom Lake, Nevada" (UPDATE 07). The act is entered the way the
## launcher's "skip to Act III" does (Campaign.begin_at at match round 21 with the arrival kit). In order:
##   1. the begin_at start: round 21 next, "ACT III · 1", the arrival kit, the gantry lift dormant at match 29,
##      the Test Pilot reserved at match 26
##   2. per-zone navigation with layer gating: the wreck → the salt → the hangar / the motor pool, Dee's side
##      door, the radar rise, the hatch ramp down to the lab, the cable trench, the lab → the silo; shut doors block
##   3. every ground / burrow spawn stands on the navmesh; the per-zone counts match map04c.json
##   4. the systems: 9 perk machines, 3 crate spots, the lab hatch needs the generator, the generator lights every
##      zone, Dee's radio opens her side door for free, the Lodestone's three seeded parts and the workbench build it
##   5. the act's dead, driven directly: the burrow points walk to a player on the salt; a Canary's head kill
##      leaves a gas cloud that hurts; a Jumpjockey leaps and lands, and dies when shot in the air; a Backorder is
##      phased (immune, no collision), walks through the salt berm and solidifies at its target
##   6. the Test Pilot by console: he leaps at the human in the lab, lands with a shockwave, is vulnerable on the
##      ground; at 60 % he takes the fight up to the lake bed; a stagger mid-leap catches him (slammed_once); dead
##      by console he drops the ignition key and a Resupply; a retreat releases both alive counts
##   7. Peg's choice: the core carried to the hatch opens the choice; "keep" makes it hers for the rocket; the
##      rocket cradle takes it; Dee's three cage items complete the yard rule
##   8. the rocket: the console's stages (key, burn), Fasbender's numbers from the radar radio, rocket_ready lights
##      the gantry lift, the vote, the MONDLICHT cutscene at speed, and (no Act IV scene in this build) the
##      "campaign continues" screen; the profile unlocks Mondlicht
##   9. a dust storm round with 3 bots (shortened): burrowers rise in packs, the clear drops a Resupply
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map04c.tscn

const MAP: String = "res://gravelight/maps/map04_fernflug/map04c.tscn"
const BITS: Dictionary = {"A": 1, "B": 2, "C": 3, "D": 4, "E": 5, "F": 6, "G": 7}
const SHORT_ROUND: int = 8
const TIMEOUT: float = 900.0
const LAB_Y: float = -6.0

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _gc: GroomController
var _fails: PackedStringArray = []
var _hits: int = 0
var _rounds_seen: Array[int] = []
var _powerups: Array[StringName] = []
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_m4c.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m4c_settings.cfg"
	GLSettings.values["bot_ee_help"] = "off"   # u09: a Full Partner bot would do the radar-radio step (burn_known) before the human-ordered console checks
	GLSettings.values["homage_bosses"] = false
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	Campaign.begin_at(&"map04c_groomlake", 21, Campaign.arrival_kit(&"map04c_groomlake"))
	Campaign.cutscene_speed = 12.0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	GLBus.player_damaged.connect(func(_p: int, _a: float) -> void: _hits += 1)
	GLBus.round_started.connect(_on_round)
	GLBus.powerup_spawned.connect(func(id: StringName, _pos: Vector3) -> void: _powerups.append(id))
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
	print("[m4c] %-74s %s" % [what, "ok" if cond else "FAIL"])
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
	print("[m4c] %-74s %s (pts %d, end %s)" % [label, "ok" if ok else "WRONG", path.size(), str(path[path.size() - 1]) if not path.is_empty() else "-"])
	if not ok:
		_fails.append(label)


func _tp(pos: Vector3, yaw: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	await _frames(3)


## A zombie by console, put at `pos` (physics kept on unless `freeze`).
func _zombie_at(pos: Vector3, freeze: bool = true) -> Zombie:
	_dir.debug_spawn(1)
	await _frames(2)
	var zs: Array[Zombie] = _dir.active_zombies()
	var z: Zombie = zs[zs.size() - 1]
	for c: Zombie in zs:
		if c.state == Zombie.State.TO_WINDOW or c.state == Zombie.State.EMERGE:
			z = c
	z.global_position = pos
	if freeze:
		z.set_physics_process(false)
	await _frames(2)
	return z


func _on_round(r: int, _special: bool) -> void:
	_rounds_seen.append(r)
	RoundManager.to_spawn = mini(RoundManager.to_spawn, SHORT_ROUND)
	RoundManager.round_total = mini(RoundManager.round_total, SHORT_ROUND)
	print("[m4c] round %d started (%s) t=%.0f" % [r, RoundManager.act_label(r), _t])


func _exfil() -> ExfilPoint:
	return get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint


func _end_screen() -> Node:
	if not is_instance_valid(_map):
		return null
	for c: Node in _map.get_children():
		if c is CampaignEndScreen:
			return c
	return null


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
	_gc = _g("GroomController") as GroomController

	# --- 1. the begin_at start
	_check(Campaign.active and RoundManager.current_round == 20 and RoundManager.state == RoundManager.State.BREAK, "begin_at: round 21 is next after the arrival grace (round %d, state %d)" % [RoundManager.current_round, RoundManager.state])
	_check(RoundManager.act_start == 21 and RoundManager.act_label(21) == "ACT III · 1", "act numbering: match 21 is 'ACT III · 1' (" + RoundManager.act_label(21) + ")")
	_check(_p.weapons.find_weapon(&"thompson_up") != null and _p.weapons.find_weapon(&"stg44_up") != null, "the arrival kit is on the human (Thompson, STG-44, upgraded)")
	_check(PerkManager.owned(1).size() == 4 and PerkManager.owned(1).has(&"trigger_tonic"), "the kit's four perks (%s)" % str(PerkManager.owned(1)))
	_check(_p.weapons.grenades == 4, "four grenades in the kit (%d)" % _p.weapons.grenades)
	var x: ExfilPoint = _exfil()
	_check(x != null and x.state == ExfilPoint.State.DORMANT and x.next_round() == 29, "the gantry lift is dormant, due at match round 29 (%s)" % (str(x.next_round()) if x != null else "none"))
	var ac: ActController = _g("ActController") as ActController
	_check(ac != null and ac.boss_round_match == 26, "the Test Pilot's round is reserved at match 26 (%d)" % (ac.boss_round_match if ac != null else -1))
	_check(_gc != null and not _gc.cfg.is_empty() and _gc.director == _dir and _dir.special_handler == _gc, "the GroomController owns the act's systems and the dust storm")
	_check(Zombie.kill_plane_y == -25.0, "the kill plane is at -25 (the shaft, the trench)")
	RoundManager.stop()
	Economy.grant(1, 100000)

	# --- 2. navigation
	var all: String = "A,B,C,D,E,F,G"
	_path_check("wreck aft -> wreck bay", Vector3(0, 0, -30), Vector3(0, 0, -8), "A", true)
	_path_check("wreck -> the salt (B open)", Vector3(0, 0, -20), Vector3(0, 0, 30), "A,B", true)
	_path_check("wreck -> the salt with B shut", Vector3(0, 0, -20), Vector3(0, 0, 30), "A", false)
	_path_check("the salt -> the hangar (C open)", Vector3(0, 0, 30), Vector3(30, 0, 80), "B,C", true)
	_path_check("the salt -> the hangar with C shut", Vector3(0, 0, 30), Vector3(30, 0, 80), "B", false)
	_path_check("the salt -> the motor pool (D open)", Vector3(0, 0, 30), Vector3(-45, 0, 80), "B,D", true)
	_path_check("the hangar -> the motor pool by Dee's side door and the lane", Vector3(30, 0, 80), Vector3(-45, 0, 80), "C,D", true)
	_path_check("the hangar -> the lane with D shut", Vector3(30, 0, 80), Vector3(0, 0, 93), "C", false)
	_path_check("the hangar -> the radar rise (E open)", Vector3(30, 0, 80), Vector3(45, 0, 130), "C,E", true)
	_path_check("the hangar -> the radar rise with E shut", Vector3(30, 0, 80), Vector3(45, 0, 130), "C", false)
	_path_check("the motor pool -> down the hatch ramp into the lab (F open)", Vector3(-45, 0, 80), Vector3(-40, LAB_Y, 125), "D,F", true)
	_path_check("the motor pool -> the lab with F shut", Vector3(-45, 0, 80), Vector3(-40, LAB_Y, 125), "D", false)
	_path_check("the radar rise -> down the cable trench into the lab", Vector3(45, 0, 130), Vector3(-40, LAB_Y, 125), "E,F", true)
	_path_check("the lab hall -> specimen room 2 (the pit)", Vector3(-40, LAB_Y, 125), Vector3(-64, LAB_Y, 126), "F", true)
	_path_check("the lab -> the silo control room (G open)", Vector3(-40, LAB_Y, 125), Vector3(-58, LAB_Y, 170), "F,G", true)
	_path_check("the lab -> the silo with G shut", Vector3(-40, LAB_Y, 125), Vector3(-58, LAB_Y, 170), "F", false)
	_path_check("the silo control room -> the shaft, the lift's foot", Vector3(-58, LAB_Y, 170), Vector3(-38, LAB_Y, 172), "G", true)
	_path_check("the wreck -> the lift (everything open)", Vector3(0, 0, -20), Vector3(-38, LAB_Y, 172), all, true)

	# --- 3. spawn points
	var rid: RID = _map.get_world_3d().navigation_map
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04c.json")
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
			print("[m4c]   spawn off the navmesh: %s at %s (nearest %s)" % [sp.name, sp.global_position, near])
	_check(bad == 0, "every ground / burrow spawn stands on the navmesh")
	for zone: String in (cfg["spawn_table"] as Dictionary).keys():
		if zone.begins_with("_"):
			continue
		var want: Dictionary = cfg["spawn_table"][zone]
		var have: Dictionary = counts.get(zone, {})
		var ok: bool = int(have.get("windows", 0)) == int(want.get("windows", 0)) and int(have.get("ground", 0)) == int(want.get("ground", 0)) \
			and int(have.get("catwalk", 0)) == int(want.get("catwalk", 0))
		_check(ok, "%s spawn counts match map04c.json (%s)" % [zone, str(have)])

	# --- 4. systems
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var bd: BuyDoor = n as BuyDoor
		if not bd.requires_power and bd.door_id != &"door_side":
			bd.open(0)
	var perks: int = 0
	for n2: Node in _g("").get_children():
		if n2 is PerkMachine:
			perks += 1
	_check(perks == 10, "10 perk machines placed (%d; Ledger Lager T-141)" % perks)
	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 3, "three crate spots (the wreck, the hangar, the lab)")
	_check(RoundManager.has_act() and RoundManager.act_index() == 3, "the act block is loaded (index 3)")
	var lab: BuyDoor = _g("Door_Lab") as BuyDoor
	var trench: BuyDoor = _g("Door_Trench") as BuyDoor
	_check(lab != null and trench != null and lab.get_prompt(_p) == "Power must be activated", "the lab hatch: 'Power must be activated' (" + (lab.get_prompt(_p) if lab != null else "none") + ")")
	var cru: Node = _g("Crucible")
	_check(cru != null and (cru as Interactable).get_prompt(_p).contains("Power"), "the Crucible refuses before the generator")
	# Dee's side door: shut until her radio is answered, then free
	var side: BuyDoor = _g("Door_Side") as BuyDoor
	_check(side != null and not side.is_open, "Dee's side door starts shut")
	var dee: StoryRadio = _g("DeeRadio") as StoryRadio
	await _tp(Vector3(60.0, 0.2, 96.0), 90.0)
	_check(dee != null and dee.get_prompt(_p).contains("answer"), "Dee's radio prompt: " + (dee.get_prompt(_p) if dee != null else "none"))
	_p.use_interactable(dee)
	await _frames(3)
	_check(dee.done and GameState.has_flag(&"dee_radio_done") and side.is_open, "her radio answered: dee_radio_done, the side door opened for free")
	var alive0: int = RoundManager.alive
	(_g("Generator")).call("run_sequence", 1)
	await _secs(10.5)
	var lit: int = 0
	var total: int = 0
	for l: Node in get_tree().get_nodes_in_group(&"power_lights"):
		total += 1
		if (l as OmniLight3D).light_energy > 0.05:
			lit += 1
	_check(GameState.power_on and lit == total and total >= 7, "generator on: %d/%d zone lights lit" % [lit, total])
	_check(RoundManager.alive > alive0, "power-on burst spawned zombies (%d)" % (RoundManager.alive - alive0))
	_dir.kill_all(true)
	_check(lab.get_prompt(_p).contains("1500"), "with the power the lab hatch sells for 1,500 (" + lab.get_prompt(_p) + ")")
	lab.open(0)
	await _frames(3)
	_check(trench.is_open and GameState.is_zone_open(&"F_LAB"), "the hatch and the cable trench open together (one link group)")
	(_g("Door_Silo") as BuyDoor).open(0)
	await _frames(2)
	# the Lodestone: three live parts (one per part), the workbench builds it
	var live: Dictionary = {}
	for n3: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
		var bp: BuildablePart = n3 as BuildablePart
		if bp.buildable_id == &"lodestone" and bp._live:
			live[bp.part_id] = bp
	_check(live.size() == 3 and not _gc.parts_seeded.is_empty(), "three Lodestone parts live, one per part (%s)" % str(_gc.parts_seeded))
	for pid: Variant in live.keys():
		var bp2: BuildablePart = live[pid]
		await _tp(bp2.global_position + Vector3(0.8, 0.2, 0), 0.0)
		_p.use_interactable(bp2)
		await _frames(2)
	_check(BuildablePart.parts_held(&"lodestone") == 3, "the three parts picked up (%d)" % BuildablePart.parts_held(&"lodestone"))
	var wb: Workbench = _g("Workbench") as Workbench
	await _tp(Vector3(-60.0, LAB_Y + 0.2, 116.0), 180.0)
	_check(wb != null and wb.buildable_id == &"lodestone" and wb.get_prompt(_p).contains("build the Lodestone"), "the workbench offers the build (" + (wb.get_prompt(_p) if wb != null else "none") + ")")
	_p.use_interactable(wb)
	await _frames(2)
	_check(wb.built, "the Lodestone is built")
	_p.use_interactable(wb)
	await _frames(2)
	_check(_p.weapons.find_weapon_base(&"lodestone") != null, "the human took the Lodestone")

	# --- 5. the act's dead, driven directly
	RoundManager.debug_set_round(24)   # act round 4: every kind is in season
	RoundManager.stop()
	# the burrow points walk toward a player on the salt
	await _tp(Vector3(10.0, 0.2, 30.0), 0.0)
	await _secs(3.6)
	var near_me: int = 0
	for n4: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		if n4.name.begins_with("Catwalk_B_LAKEBED"):
			var d: float = Vector2((n4 as Node3D).global_position.x - 10.0, (n4 as Node3D).global_position.z - 30.0).length()
			if d >= 5.0 and d <= 13.0:
				near_me += 1
	_check(near_me >= 5, "the burrow points moved to 6-12 m of the player on the salt (%d of 6)" % near_me)
	# a Canary: the hood, the head kill's gas
	await _tp(Vector3(-40.0, LAB_Y + 0.2, 120.0), 0.0)
	var zc: Zombie = await _zombie_at(Vector3(-40.0, LAB_Y, 123.0))
	_gc.make("canary", zc)
	await _frames(2)
	_check(zc.get_meta("groom", "") == "canary" and zc.has_meta("groom_hood") and absf(zc.armor_torso_mult - 1.5) < 0.01, "a Canary: tagged, hooded, torso x1.5")
	var hb: int = _hits
	zc.take_damage(zc.hp + 1.0, &"head", &"kar98k", 1, &"bullet")
	await _secs(0.6)
	var gas: GasCloud = get_tree().get_first_node_in_group(&"gas_clouds") as GasCloud
	_check(gas != null, "a head kill left a gas cloud")
	await _secs(1.0)
	_check(_hits > hb, "the cloud hurts the player standing in it (%d hits, god mode)" % (_hits - hb))
	await _secs(6.0)
	_check(get_tree().get_first_node_in_group(&"gas_clouds") == null, "the cloud blew away after its seconds")
	# a Jumpjockey: the leap, the landing, the fall when shot in the air
	await _tp(Vector3(42.0, 0.2, 108.0), 180.0)
	var zj: Zombie = await _zombie_at(Vector3(42.5, 1.0, 117.5), false)   # the tower step's south-west corner (Launch_Tower_1)
	_gc.make("jumpjockey", zj)
	await _frames(2)
	_check(zj.has_meta("groom_rig") and _gc.jj.has(zj), "a Jumpjockey: tagged, rigged")
	zj._enter(Zombie.State.CHASE)
	_gc.leap(zj, _p.global_position)
	await _frames(2)
	_check(zj.is_pushed() and bool(_gc.jj[zj]["airborne"]), "it leaped (airborne, pushed)")
	var landed: bool = await _until(func() -> bool: return not bool(_gc.jj[zj]["airborne"]), 4.0)
	_check(landed and zj.is_active() and zj.global_position.distance_to(_p.global_position) < 9.0, "it landed near the player (%.1f m)" % zj.global_position.distance_to(_p.global_position))
	zj.global_position = Vector3(42.5, 1.0, 117.5)
	_gc.jj[zj]["cd"] = 0.0
	_gc.leap(zj, _p.global_position)
	await _frames(3)
	zj.take_damage(10.0, &"torso", &"kar98k", 1, &"bullet")
	await _frames(3)
	_check(not zj.is_active() or zj.state == Zombie.State.DEAD, "shot in the air: the rig fails, it falls and dies")
	# a Backorder: phased through the berm, solid at its target
	await _tp(Vector3(0.0, 0.2, 10.0), 0.0)
	var zb: Zombie = await _zombie_at(Vector3(0.0, 0.0, -1.5), false)   # on the salt, the berm between it and nothing: it walks straight
	zb._enter(Zombie.State.CHASE)
	_gc.make("backorder", zb)
	await _frames(2)
	_check(zb.get_meta("groom", "") == "backorder" and zb.collision_layer == 0 and not zb.is_physics_processing(), "a Backorder: phased (no collision, no physics)")
	var hb0: int = 0
	for hbx: Hitbox in zb._hitboxes:
		if hbx.collision_layer != 0:
			hb0 += 1
	_check(hb0 == 0, "phased: every hitbox off (immune)")
	zb.target = _p
	var z0: float = zb.global_position.z
	await _secs(2.0)
	_check(zb.global_position.z > z0 + 1.5, "it walks at the player while phased (%.1f -> %.1f)" % [z0, zb.global_position.z])
	var solid: bool = await _until(func() -> bool: return not bool(_gc.bo[zb]["phased"]), 12.0)
	_check(solid and zb.collision_layer == Zombie.LAYER_ZBODY and zb.is_physics_processing(), "it solidified at its target (collision and physics back)")
	_dir.kill_all(true)
	await _frames(2)

	# --- 6. the Test Pilot by console
	await _tp(Vector3(-32.0, LAB_Y + 0.2, 128.0), 90.0)
	var tp: TestPilot = _dir.summon_boss(&"testpilot", Vector3.ZERO) as TestPilot
	ac.boss = tp
	await _frames(2)
	_check(tp != null and tp.is_active() and tp.global_position.distance_to(Vector3(-40, LAB_Y, 130)) < 3.0, "the Test Pilot is summoned at the hall anchor (%s)" % (str(tp.global_position) if tp != null else "none"))
	_check(tp.max_hp >= 32000.0, "his health is 32,000 scaled (%d)" % int(tp.max_hp))
	_check(RoundManager.alive - _dir.active_zombies().size() == 1, "while he stands the round counts him twice (alive %d, bodies %d)" % [RoundManager.alive, _dir.active_zombies().size()])
	var leaped: bool = await _until(func() -> bool: return tp.landings >= 1, 15.0)
	_check(leaped and tp.pstate in [TestPilot.P.LAND, TestPilot.P.VULN, TestPilot.P.IDLE, TestPilot.P.CROUCH, TestPilot.P.AIR], "he leaped and landed (leaps %d, landings %d)" % [tp.leaps_done, tp.landings])
	_check(tp.global_position.distance_to(_p.global_position) < 8.0, "he landed on the player (%.1f m)" % tp.global_position.distance_to(_p.global_position))
	var vuln: bool = await _until(func() -> bool: return tp.pstate == TestPilot.P.VULN, 6.0)
	_check(vuln and absf(TestPilot.damage_mult(tp.pstate, false, tp.tcfg["leap"], tp.tcfg["stall"]) - 1.0) < 0.01, "vulnerable on the ground after the landing (x1.0)")
	tp.take_damage(tp.max_hp * 0.45, &"torso", &"kar98k", 1, &"bullet")
	await _frames(2)
	_check(tp.phase >= 2, "under 60 %%: the lakebed phase (%d)" % tp.phase)
	var air: bool = await _until(func() -> bool: return tp.pstate == TestPilot.P.AIR, 15.0)
	_check(air, "he leaps again (toward the lake bed)")
	if air:
		tp.force_stagger()   # the Lodestone's lift in the air
		await _frames(2)
		_check(tp.catches == 1 and GameState.has_flag(&"slammed_once") and tp.pstate == TestPilot.P.VULN, "caught mid-leap by a stagger: slammed_once, dropped, vulnerable")
	var lake: bool = await _until(func() -> bool: return tp.on_lake or GameState.has_flag(&"pilot_on_lake"), 20.0)
	_check(lake, "he took the fight up to the lake bed (pilot_on_lake)")
	tp.retreat()
	var gone: bool = await _until(func() -> bool: return not is_instance_valid(tp) or tp.gone, 6.0)
	await _secs(0.5)
	_check(gone and RoundManager.alive == _dir.active_zombies().size(), "a retreat releases both counts (alive %d, bodies %d)" % [RoundManager.alive, _dir.active_zombies().size()])
	tp = _dir.summon_boss(&"testpilot", Vector3.ZERO) as TestPilot
	ac.boss = tp
	await _frames(2)
	_powerups.clear()
	tp.debug_kill(1)
	await _secs(1.0)
	_check(not tp.is_active() and GameState.has_flag(&"ignition_key") and _powerups.has(&"resupply"), "dead by console: the ignition key and a Resupply")
	await _secs(0.5)
	_check(RoundManager.alive == _dir.active_zombies().size(), "his death releases both counts (alive %d, bodies %d)" % [RoundManager.alive, _dir.active_zombies().size()])

	# --- 7. Peg's choice, the core, Dee's cage
	var core: CarryObject = _g("ImpellerCore") as CarryObject
	await _tp(Vector3(20.0, 0.2, 14.5), 0.0)
	_check(core != null and core.get_prompt(_p).contains("lift"), "the core's prompt: " + (core.get_prompt(_p) if core != null else "none"))
	_p.use_interactable(core)
	await _frames(3)
	_check(core.carrier == 1 and _p.has_status(&"ballast"), "the human carries the core (ballast status)")
	var hatch: CarryCradle = _g("HangarCradle") as CarryCradle
	await _tp(Vector3(38.0, 0.2, 96.0), -90.0)
	_check(hatch != null and hatch.get_prompt(_p).contains("set"), "the hatch takes a carried core: " + (hatch.get_prompt(_p) if hatch != null else "none"))
	_p.use_interactable(hatch)
	await _frames(3)
	var pc: PegsChoice = get_tree().root.get_node_or_null("PegsChoice") as PegsChoice
	_check(pc != null and hatch.deciding and core.carrier == 0, "the choice is open (P%d decides), the core set down at the hatch" % (pc.decider if pc != null else -1))
	if pc != null:
		pc.choose("keep")
		await _frames(3)
	_check(GameState.has_flag(&"peg_resigned") and not GameState.has_flag(&"peg_delivered") and core.deliver_to == &"rocket_cradle", "keep: peg_resigned, the core is bound for the rocket")
	await _tp(core.global_position + Vector3(0.6, 0.2, 0), 0.0)
	_p.use_interactable(core)
	await _frames(3)
	_check(core.carrier == 1 and core.trips == 1, "carried again (heavier the second time)")
	var rc: CarryCradle = _g("RocketCradle") as CarryCradle
	await _tp(Vector3(-38.0, LAB_Y + 0.2, 173.0), 90.0)
	_p.use_interactable(rc)
	await _frames(3)
	_check(core.delivered and GameState.has_flag(&"core_in_rocket"), "the rocket's engine bay took the core (core_in_rocket)")
	for ci: String in ["casing", "bomber_coil", "honey"]:
		var it: CageItem = _g("CageItem_" + ci) as CageItem
		await _tp(it.global_position + Vector3(0.6, 0.2, 0), 0.0)
		_p.use_interactable(it)
		await _frames(2)
	_check(GameState.has_flag(&"dee_cage_done"), "Dee's three cage items complete the yard rule")

	# --- 8. the rocket
	var con: SiloConsole = _g("SiloConsole") as SiloConsole
	await _tp(Vector3(-58.0, LAB_Y + 0.2, 175.5), 0.0)
	_check(con != null and SiloConsole.stage_of(GameState.flags) == "key" and con.get_prompt(_p).contains("turn the ignition key"), "the console: the key stage (" + (con.get_prompt(_p) if con != null else "none") + ")")
	_p.use_interactable(con)
	await _frames(3)
	_check(GameState.has_flag(&"rocket_key_turned") and con.get_prompt(_p).contains("not known"), "the key turned; the burn is not known yet (" + con.get_prompt(_p) + ")")
	_check(not con.can_interact(_p), "the console refuses the burn until Fasbender's numbers")
	var rr: StoryRadio = _g("RadarRadio") as StoryRadio
	await _tp(Vector3(62.0, 0.2, 125.5), 0.0)
	_p.use_interactable(rr)
	await _frames(3)
	var burn: Variant = GameState.flags.get(&"burn", [])
	_check(rr.done and GameState.has_flag(&"burn_known") and burn is Array and (burn as Array).size() == 3, "Fasbender's radio: burn_known, three numbers (%s)" % str(burn))
	x = _exfil()
	_check(x != null and x.state == ExfilPoint.State.DORMANT, "the lift is still dormant before the burn")
	await _tp(Vector3(-58.0, LAB_Y + 0.2, 175.5), 0.0)
	_check(con.can_interact(_p) and con.get_prompt(_p).contains("enter the burn"), "with the numbers: the burn stage (" + con.get_prompt(_p) + ")")
	_p.use_interactable(con)
	await _frames(3)
	_check(GameState.has_flag(&"rocket_ready") and x.is_active(), "rocket_ready: the gantry lift lit (trigger_flag)")
	await _tp(x.global_position + x.global_basis * Vector3(0, 0, -1.6), 0.0)
	_check(x.can_interact(_p) and x.get_prompt(_p).contains("exfil") and x.hold_time(_p) == 3.0, "the lift's vote prompt, 3 s (" + x.get_prompt(_p) + ")")
	_p.use_interactable(x)
	await _frames(2)
	_check(x.state == ExfilPoint.State.DEPARTING and x.cutscene != null and is_instance_valid(x.cutscene), "the vote passed: the MONDLICHT cutscene plays")
	var rk: Node3D = _map.find_child("Rocket", true, false) as Node3D
	var y0: float = rk.position.y if rk != null else 0.0
	print("[m4c] Act IV scene present: %s" % str(Campaign.scene_exists(&"map04d_mondlicht")))
	var ended: bool = await _until(func() -> bool:
		if not is_instance_valid(_map) or _map.get_parent() == null:   # the map was swapped out for Act IV
			var cur: Node = get_tree().current_scene
			return cur is MapRoot and (cur as MapRoot).map_id == &"map04d_mondlicht"
		return _end_screen() != null, 90.0)
	if rk != null and is_instance_valid(rk) and is_instance_valid(_map):
		_check(rk.position.y > y0 + 1.0, "the launch fx lifted the rocket (%.0f -> %.0f)" % [y0, rk.position.y])
	if Campaign.scene_exists(&"map04d_mondlicht"):
		_check(ended, "Act IV loaded after the cutscene")
	else:
		_check(ended and GameState.phase == GameState.Phase.GAME_OVER, "no Act IV in this build: the 'campaign continues' screen showed after the launch")
	_check(ProfileSave.is_map_unlocked(&"map04d_mondlicht"), "profile: Mondlicht unlocked by the exfil")
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[m4c] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
