extends Node
## Scripted QA for Map 1's placed systems: power-on event, the powered Lab door, pylons -> Core Vault,
## the lift ride, the three traps, the Crucible, crates and perk machines.
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
	_check(perks == 9, "9 perk machines placed")

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

	print("[m1s] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)


func DYc() -> float:
	return -12.0
