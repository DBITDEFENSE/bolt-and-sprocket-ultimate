extends Node
## T-276: Rocket Man at Map 0's V2 site, headless, solo, silent:
##   the machine   Perk_rocket_man stands in the firing-control dugout (the pinned spot launch_bunker, whatever the
##                 seed), lit without the power; bought with Scrip from in front of it, the tonic is held after the
##                 drink beat and shows on the HUD's perk row
##   the blast     a frag of the holder's at their feet: no damage to them, they are thrown clear (up and away); a
##                 zombie 6.8 m off (past a frag's 6 m, inside Rocket Man's 7.5 m) is hit; another player's frag would
##                 not be boosted (the multipliers are the owner's)
##   tier IV       the launch's own blast leaves the holder untouched
## Prints "[rocket_man] ..." lines and "[rocket_man] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_rocket_man.tscn

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 240.0

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0


func _ready() -> void:
	ProfileSave.path = "user://_qa_rocket_man_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_rocket_man_settings.cfg"
	GameState.character_id = &"dutch"
	Campaign.reset()
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[rocket_man] %-92s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[rocket_man] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _root() -> MapRoot:
	return _map as MapRoot


func _p() -> Player:
	return _root().player


func _zombie_at(pos: Vector3) -> Zombie:
	var dir: ZombieDirector = _root().director
	var before: Dictionary = {}
	for c: Zombie in dir.active_zombies():
		before[c.get_instance_id()] = true
	dir.debug_spawn(1)
	await _frames(2)
	var z: Zombie = null
	for c2: Zombie in dir.active_zombies():
		if not before.has(c2.get_instance_id()):
			z = c2
	if z != null:
		z.global_position = pos
		z.set_physics_process(false)
	await _frames(1)
	return z


func _run() -> void:
	GameState.bot_count = 0
	GameState.god_mode = false
	_map = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	var t0: float = 0.0
	while (_root().player == null or not _root().player.is_inside_tree()) and t0 < 10.0:
		await get_tree().physics_frame
		t0 += get_physics_process_delta_time()
	await _secs(1.0)
	_p().set_process_unhandled_input(false)
	var op: InnOpening = _map.find_child("InnOpening", true, false) as InnOpening
	if op != null:
		op.cancel()
	_root().director.kill_all(true)
	RoundManager.to_spawn = 0
	GLConsole.run("open_doors")
	for z: String in ["YARD", "GROUNDS", "STABLE", "FORSTWEG", "STELLUNG"]:
		GameState.open_zone(StringName(z))
	await _machine()
	await _blast()
	_finish()


func _machine() -> void:
	var m: PerkMachine = _map.find_child("Perk_rocket_man", true, false) as PerkMachine
	var spot: Node3D = _map.find_child("PerkSpot_launch_bunker", true, false) as Node3D
	_check(m != null and spot != null, "Perk_rocket_man and its spot are on the map")
	if m == null or spot == null:
		return
	_check(Vector2(m.global_position.x - spot.global_position.x, m.global_position.z - spot.global_position.z).length() < 0.4, "it stands on launch_bunker (the dugout, seed %d)" % QuestManager.match_seed)
	_check(MapRocketGen.BUNKER_IN.has_point(Vector2(m.global_position.x, m.global_position.z)), "inside the firing-control dugout")
	_check(not GameState.power_on and m.can_interact(_p()), "it pours without the power")
	var front: Vector3 = m.global_position - m.global_transform.basis.z * 1.1
	_p().global_position = Vector3(front.x, 0.05, front.z)
	_p().velocity = Vector3.ZERO
	await _frames(3)
	Economy.grant_raw(_p().player_id, 5000)
	var before: int = Economy.get_scrip(_p().player_id)
	m.interact(_p())
	await _secs(float(GLData.table("perks").get("drink_seconds", 1.2)) + 0.6)
	_check(PerkManager.has_perk(_p().player_id, &"rocket_man"), "bought: the holder has Rocket Man")
	_check(before - Economy.get_scrip(_p().player_id) == PerkManager.price(&"rocket_man"), "it cost %d" % (before - Economy.get_scrip(_p().player_id)))
	var shown: bool = false
	await _frames(10)
	for c: Node in get_tree().root.find_children("*", "", true, false):   # (the perk row is PerkManager's own CanvasLayer)
		if c is Control and c.get("perk_id") != null and StringName(c.get("perk_id")) == &"rocket_man" and (c as Control).is_visible_in_tree():
			shown = true
	_check(shown, "the HUD shows its cap")


func _blast() -> void:
	var p: Player = _p()
	# out in the clearing, on open snow
	p.global_position = Vector3(104.0, 0.05, 50.0)
	p.velocity = Vector3.ZERO
	await _frames(8)
	var z: Zombie = await _zombie_at(Vector3(104.6, 0.0, 56.9))
	var z_hp: float = z.hp if z != null else 0.0
	var hp0: float = p.hp
	var start: Vector3 = p.global_position
	# a frag's reach (6 m) with a light charge for the test: it hurts, it never kills the zombie
	var cfg: Dictionary = {"damage": 60.0, "radius": 6.0, "edge_mult": 0.2, "self_damage_near": 100.0, "self_near_m": 3.0, "self_damage_far": 50.0}
	Explosion.detonate(p, p.global_position + Vector3(0.6, 0.1, 0.0), cfg, p.player_id, &"frag")
	var peak: float = start.y
	var far: float = 0.0
	for i: int in 40:
		await get_tree().physics_frame
		peak = maxf(peak, p.global_position.y)
		far = maxf(far, Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length())
	_check(p.hp >= hp0, "own frag at the feet: no damage (hp %.0f -> %.0f)" % [hp0, p.hp])
	_check(peak > start.y + 0.4, "thrown up (%.2f m)" % (peak - start.y))
	_check(far > 1.0, "and away (%.2f m)" % far)
	_check(peak < start.y + 2.3, "never over a 2.3 m fence (%.2f m)" % (peak - start.y))
	print("[rocket_man] (zombie: %s, hp %.0f -> %.0f, active %s, at %s)" % [str(z != null), z_hp, z.hp if z != null else -1.0, str(z.is_active()) if z != null else "-", str(z.global_position) if z != null else "-"])
	_check(z != null and z.hp < z_hp, "a zombie 6.9 m off is hit (past a frag's 6 m; Rocket Man reaches 7.5 m)")
	# tier IV: the launch's own blast leaves the holder alone
	PerkManager.set_tier(p.player_id, &"rocket_man", 4)
	var rl: RocketLaunch = _map.find_child("RocketLaunch", true, false) as RocketLaunch
	p.global_position = rl.global_position + Vector3(-3.0, 0.05, -3.5)
	p.velocity = Vector3.ZERO
	await _frames(4)
	var hp1: float = p.hp
	rl._blast(rl.global_position)
	await _frames(2)
	_check(p.hp >= hp1 and int(rl.last_blast.get("players", -1)) == 0, "tier IV: the V2's blast does not touch the holder")
