extends Node
## Scripted QA for Map 1's placed systems: power-on event, the powered Lab door, pylons -> Core Vault,
## the lift ride, the three traps, the Crucible, crates and perk machines.
## T-232 (the boss rework): the Foreman in the Minehead Yard: the rock-burst arrival (the kit on him: iron hits,
## boss_stomp footfalls; the dust burst and the light drop that comes back), the model's new pieces (the coat strips,
## the chain, the headlamp), the core x3, ENRAGED puts the yard's lamps out while his core burns brighter, Core Vent
## (the new ENRAGED move) slows the player 3 m away, the squad read (a lone / hurt player), the lamps back on his death.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_map01_systems.tscn

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[m1s] %-60s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


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


func _run() -> void:
	await _frames(12)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	GameState.god_mode = true
	Economy.grant(1, 100000)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)

	_check(get_tree().get_nodes_in_group(&"crate_spots").size() == 5, "5 crate spots")
	var start_spot: Node = null
	for s: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if int(s.get("spot_index")) == CrateManager.location_index:
			start_spot = s
	_check(start_spot != null and bool(start_spot.get("can_start")), "crate started at Boxcar or Mess")
	var perks: int = 0
	for n: Node in _g("").get_children():
		if n is PerkMachine:
			perks += 1
	var want_perks: int = 0   # one cabinet per perk plate in machine_lore.json (T-141 added Ledger Lager: 10)
	for k: String in (GLData.load_json("res://data/gravelight/machine_lore.json")["maps"]["map01_kaltenbrunn"]["entries"] as Dictionary).keys():   # not a GLData table
		if k.begins_with("perk."):
			want_perks += 1
	_check(perks == want_perks, "%d perk machines placed (machine_lore says %d)" % [perks, want_perks])

	# --- Lab door needs power
	var lab: BuyDoor = _g("Door_Lab") as BuyDoor
	_check(lab.get_prompt(_p) == "Power must be activated", "Lab door: 'Power must be activated'")

	# --- power on
	var sw: Node = _g("Hauptschalter")
	var alive0: int = RoundManager.alive
	sw.call("run_sequence", 1)
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
	_check(lab.get_prompt(_p).contains("2000"), "Lab door buyable after power (" + lab.get_prompt(_p) + ")")
	lab.open(0)

	# --- pylons -> core vault
	for n: Node in get_tree().get_nodes_in_group(&"pylons"):
		n.call("debug_attune")
	await _secs(3.5)
	_check(GameState.has_flag(&"core_vault_open") and GameState.is_zone_open(&"I_CORE"), "3 pylons -> Core Vault open")
	var rid: RID = _map.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(rid, Vector3(12, -12, 70), Vector3(34, -18, 106), true, _dir.nav_mask)
	_check(not path.is_empty() and path[path.size() - 1].distance_to(Vector3(34, -18, 106)) < 1.5, "zombie nav reaches the Core after the vault opens")

	# --- Crucible
	await _tp(Vector3(44.6, -17.8, 124), -90.0)
	var cru: Node = _g("Crucible")
	_p.weapons.current_index = 0
	var price_ok: bool = (cru as Interactable).get_prompt(_p).contains("5000")
	_check(price_ok, "Crucible prompt: " + (cru as Interactable).get_prompt(_p))
	(cru as Interactable).interact(_p)
	await _secs(5.5)
	(cru as Interactable).interact(_p)
	await _frames(3)
	_check(_p.weapons.find_weapon(&"m1911_up") != null, "Crucible upgraded the M1911 to Last Rites")

	# --- Overclock Cordial (T-034): the Generator Hall machine sells the perk, and a reload at e >= 0.25
	# releases a static burst that damages a nearby zombie
	var oc: PerkMachine = _g("Perk_overclock_cordial") as PerkMachine
	_check(oc != null, "Overclock Cordial machine placed in the Generator Hall")
	if oc != null:
		await _tp(oc.global_position + Vector3(0, 0.2, 1.3), 180.0)
		_check(oc.get_prompt(_p).contains("2500"), "Overclock prompt: " + oc.get_prompt(_p))
		oc.interact(_p)
		await _secs(1.6)
		_check(PerkManager.has_perk(1, &"overclock_cordial"), "drank Overclock Cordial")
		var oz: Zombie = await _zombie_at(_p.global_position + Vector3(0, 0, 2.0))
		var hp0: float = oz.hp
		var w: WeaponInstance = _p.weapons.current()
		w.mag = int(w.mag_size() * 0.5)   # e = 0.5: radius 4.25 m, damage 0.3 x round health
		w.reserve = maxi(w.reserve, w.mag_size())
		_p.weapons.set("_sprinting", false)
		_p.weapons.start_reload()
		await _secs(0.4)
		_check(oz.hp < hp0 or not oz.is_active(), "Overclock burst damaged a zombie 2 m away (hp %.0f -> %.0f)" % [hp0, oz.hp])
		_check(_p.hp > 0.0, "the burst did not hurt the player")
		_dir.kill_all(true)

	# --- lift ride (top -> bottom)
	var lift: Node = _g("Lift")
	await _tp(Vector3(25, 0.3, 51))
	lift.call("request", &"cage")
	await _secs(27.0)
	_check(_p.global_position.y < -10.0, "rode the lift down (y=%.1f)" % _p.global_position.y)

	# --- traps
	await _tp(Vector3(46, 0.2, 44), 0.0)
	var z: Zombie = await _zombie_at(Vector3(44, 0, 30))
	(_g("Lever_OreCart") as Interactable).interact(_p)
	await _secs(6.0)
	_check(not z.is_active(), "Runaway Ore Cart killed a zombie on the track")
	await _secs(1.0)
	await _tp(Vector3(16, -11.8, 61.8), 180.0)
	z = await _zombie_at(Vector3(12, DYc(), 71))
	(_g("Lever_Chandelier") as Interactable).interact(_p)
	await _secs(3.0)
	_check(not z.is_active(), "Chandelier Drop killed a zombie in the aisle")
	await _tp(Vector3(73.5, -11.8, 77.5), 0.0)
	z = await _zombie_at(Vector3(69, DYc(), 70))
	(_g("Lever_LiveWire") as Interactable).interact(_p)
	await _secs(3.0)
	z.set_physics_process(true)
	await _secs(2.0)
	_check(not z.is_active(), "Live Wire Fence killed a zombie in the gap")

	# --- T-232: the Foreman in the yard (the boss rework: the kit, the rock burst, ENRAGED's dark, Core Vent, the squad)
	await _tp(Vector3(16, 0.2, 31), 20.0)
	var fm: Foreman = _dir.summon_boss(&"foreman", Vector3(20, 0, 25)) as Foreman
	_check(fm != null, "the Foreman is summoned in the Minehead Yard")
	if fm != null:
		_check(fm.fx != null and fm.fx.has_footfalls() and str(fm.fx.cfg.get("surface", "")) == "iron" and str(fm.fx.cfg.get("step_sound", "")) == "boss_stomp", "the kit is on him (iron hits, boss_stomp footfalls)")
		_check(fm._strips != null and fm._chain.size() >= 10 and fm._headlamp != null and fm._spin_loop != null, "the model: the coat's strips, the ten-link chain, the headlamp, the drill-spin loop")
		var t: float = 0.0
		while t < 9.0 and fm.fstate == Foreman.F.EMERGE:
			await _secs(0.25)
			t += 0.25
		_check(fm.fstate != Foreman.F.EMERGE and fm.arrival_bursts >= 1, "the rock burst brings him up (%.1f s)" % t)
		_check(fm.fx.dimmed_count() > 0, "the burst drops the yard's light round the spawn (%d lights)" % fm.fx.dimmed_count())
		await _secs(5.5)
		_check(fm.fx.dimmed_count() == 0, "and it comes back")
		_check(fm.squad_state.get("alone", false), "the squad read: a lone player (the whip comes from any side)")
		fm.max_hp = 30000.0   # his round-12 solo health (the rounds are stopped here: he came in with round 1's 2500)
		fm.hp = 30000.0
		var hp0: float = fm.hp
		fm.take_damage(1000.0, &"weakpoint", &"m1911", 1, &"bullet")
		_check(absf((hp0 - fm.hp) - 3000.0) < 0.5, "the core takes x3 (%.0f)" % (hp0 - fm.hp))
		# ENRAGED under 30%: the lamps go out round him and stay out; he is the light
		fm.take_damage(fm.hp - fm.max_hp * 0.25, &"torso", &"debug", 1, &"world")
		await _secs(0.6)
		_check(fm.enraged and fm.fx.dimmed_count() > 0, "ENRAGED: the yard's lamps go out round him (%d)" % fm.fx.dimmed_count())
		_check(fm._core_light.light_energy > 3.0 and fm._headlamp.light_energy > 2.0, "his core and headlamp burn brighter (%.1f / %.1f)" % [fm._core_light.light_energy, fm._headlamp.light_energy])
		# Core Vent: the new ENRAGED move, 3 m away: slowed
		await _tp(fm.global_position + Vector3(0, 0.2, 3.0), 180.0)
		_p.hp = _p.max_hp * 0.2
		_p.set("_since_hit", 0.0)   # (else the regen heals him before the read)
		await _secs(0.4)
		_check(fm.squad_state.get("hurt") == _p, "the squad read: a hurt player in his sight is his target (hp %.0f)" % _p.hp)
		_p.hp = _p.max_hp
		fm.debug_vent()
		_check(fm.fstate == Foreman.F.VENT, "Core Vent starts (the drill planted, the core flaring)")
		var hp1: float = fm.hp
		fm.take_damage(100.0, &"weakpoint", &"m1911", 1, &"bullet")
		_check(absf((hp1 - fm.hp) - 400.0) < 0.5, "the core takes x4 while it flares (%.0f)" % (hp1 - fm.hp))
		t = 0.0
		while t < 3.0 and fm.vents_done < 1:
			await _secs(0.1)
			t += 0.1
		_check(fm.vents_done >= 1 and _p.has_status(&"whip_slow"), "the Nachtglas bursts out: the player 3 m away is slowed")
		fm.take_damage(fm.hp + 1.0, &"torso", &"debug", 1, &"world")
		_check(fm.state == Zombie.State.DEAD, "the Foreman is killed")
		await _secs(3.5)
		_check(fm.fx.dimmed_count() == 0, "the lamps come back when he dies")
		await _secs(1.5)

	print("[m1s] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)


func DYc() -> float:
	return -12.0
