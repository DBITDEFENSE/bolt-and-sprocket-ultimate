extends Node
## The Sherman on the Inn, rounds 30..40 (T-249; ShermanEvent, ShermanTank, FireZombie, FirePatch, StukaPlane, AirRaid),
## headless, solo with one bot, silent:
##   round 30  the round is reserved; der Fuhrmann's round begins too; the Sherman is heard, comes in from beyond the
##             edge, rolls over the barrier, parks outside the yard's gate facing it; the horse comes in behind it;
##             the assault (the count by the squad, fire zombies among them), the tank's boss bar and the counter; the
##             dead reach the hull and beat on it; a fire zombie against the hull hisses, bursts, hurts the tank and
##             leaves a burning patch; the team kills the rest: the tank HOLDS (a Resupply in the yard), and helps;
##   driving   (T-261) once it is parked a player climbs in at the hull (the prompt, the Use ray), backs it down the
##             road, drives it at the gate (it stops short of the gate's mouth), pivots; lays the turret and fires the
##             75 mm on the dead in the meadow (the blast, the reload), holds the machine gun; runs the dead down;
##             the dead that come for the driver beat on the hull; out again beside the hull; driven to its last
##             health outside the assault the driver is put out and the crew repairs; a bot against the moved hull;
##             then the assault runs round the tank where it now stands (the ring is laid there);
##   assist    the machine gun and the 75 mm on the dead in its sight (damage done, kills), nothing on the players;
##   round 40  the dive bomber dives, the bomb lands on the tank: it brews up and stays a wreck; the air raid: the
##             warning and the countdown; a bot outside is sent inside; a bomb by the human outside hurts them, a bomb
##             by the inn's wall spares the bot inside; bombs land through the raid; the all clear.
##             (T-261) a player in the tank when the dive bomber comes is put out; a Sherman that brews up with a
##             player in it puts them out unhurt.
## Prints "[sherman] ..." lines and "[sherman] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_sherman.tscn

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 1100.0

var _map: Node3D
var _fails: PackedStringArray = []
var _checks: int = 0
var _t: float = 0.0
var _drops: Array[String] = []
var _hurt: Dictionary = {}
var _keep: Array[Zombie] = []          # T-261: the drive's own zombies (not culled)
var _moved: float = 0.0
var _bot_note: String = ""


func _ready() -> void:
	ProfileSave.path = "user://_qa_sherman_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_sherman_settings.cfg"
	GLSettings.values["homage_bosses"] = true
	GameState.character_id = &"dutch"
	Campaign.reset()
	GLBus.powerup_spawned.connect(func(id: StringName, _p: Vector3) -> void: _drops.append(String(id)))
	GLBus.player_damaged.connect(func(pid: int, amount: float) -> void:
		_hurt[pid] = float(_hurt.get(pid, 0.0)) + amount)
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_check(false, "timeout")
		_finish()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[sherman] %-92s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	print("[sherman] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(pred: Callable, seconds: float, each: Callable = Callable()) -> bool:
	var t: float = 0.0
	while t < seconds:
		if each.is_valid():
			each.call()
		if pred.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return pred.call()


func _root() -> MapRoot:
	return _map as MapRoot


func _dir() -> ZombieDirector:
	return _root().director


func _p() -> Player:
	return _root().player


func _bot() -> Player:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		if (n as Player).is_bot:
			return n as Player
	return null


func _ev() -> ShermanEvent:
	return _map.get_node_or_null("ShermanEvent") as ShermanEvent


func _place(p: Player, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


## Kills the round's horde that is not the tank's (the rest of the round, not under test), keeps the horse alive.
func _cull_horde() -> void:
	var ev: ShermanEvent = _ev()
	for z: Zombie in _dir().active_zombies():
		if z is HomageBoss or (ev != null and ev.attackers.has(z)) or _keep.has(z):
			continue
		z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")


## Nothing but the bombs may touch the players while a bomb case runs: the queue held empty, every zombie down.
func _quiet() -> void:
	RoundManager.to_spawn = 0
	for z: Zombie in _dir().active_zombies():
		if not (z is HomageBoss):
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")


func _load() -> void:
	GameState.bot_count = 1
	GameState.god_mode = true
	_map = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 10.0)
	await _secs(1.0)
	GameState.god_mode = true
	_p().set_process_unhandled_input(false)
	_dir().kill_all(true)
	GLConsole.run("open_doors")
	for z: String in ["YARD", "GROUNDS", "STABLE", "UPSTAIRS", "CELLAR"]:
		GameState.open_zone(StringName(z))


func _run() -> void:
	await _load()
	var ev: ShermanEvent = _ev()
	_check(ev != null and ev.arrive_round == 30 and ev.stuka_round == 40, "map00: the event is on (rounds 30 and 40)")
	if ev == null:
		_finish()
		return
	_check(RoundManager.is_reserved(30) and RoundManager.is_reserved(40), "rounds 30 and 40 are reserved (no Bellringer round, no Foreman)")
	await _round30(ev)
	await _assist(ev)
	await _round40(ev)
	_finish()


# ================================================================== round 30

func _round30(ev: ShermanEvent) -> void:
	_place(_p(), Vector3(14.0, 0.05, 41.0))
	if _bot() != null:
		_place(_bot(), Vector3(12.0, 0.05, 40.0))
	# (T-261: the assault waits for the drive below; it is begun by hand once the tank has been moved)
	ev.cfg = ev.cfg.duplicate(true)
	ev.cfg["arrival"]["assault_after_park"] = 600.0
	RoundManager.debug_set_round(30)
	await _until(func() -> bool: return RoundManager.current_round == 30 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	var hr: HorseRound = _map.get_node_or_null("HorseRound_30") as HorseRound
	_check(ev.phase == ShermanEvent.Phase.ARRIVING, "round 30: the Sherman is coming")
	_check(hr != null and hr.phase == HomageEncounter.Phase.ACTIVE, "round 30: der Fuhrmann's round begins too (the Fuhrmann resolution)")
	await _until(func() -> bool: return ev.tank != null, 3.0)
	var tk: ShermanTank = ev.tank
	_check(tk != null and tk.global_position.z > 64.0, "it is heard first, beyond the map's edge (z %.1f)" % (tk.global_position.z if tk != null else 0.0))
	if tk == null:
		return
	var parked: bool = await _until(func() -> bool: return tk.parked() and tk.route.is_empty() and ev.t > 3.0, 40.0, _cull_horde)
	_check(parked and tk.global_position.distance_to(ev.park_point()) < 0.6, "it drives up the carters' road and parks outside the gate (%.1f m off, t %.1f s)" % [tk.global_position.distance_to(ev.park_point()), ev.t])
	_check(ev.barrier_crushed, "it rolled over the sawhorse barrier at the road's end")
	var fwd: Vector3 = -tk.global_transform.basis.z
	_check(fwd.dot((Vector3(18, 0, 48) - tk.global_position).normalized()) > 0.9, "facing the yard's gate")
	var horse_in: bool = await _until(func() -> bool: return hr != null and not hr.horses().is_empty(), 12.0, _cull_horde)
	_check(horse_in and hr.horses()[0].global_position.z > 48.0, "der Fuhrmann comes up the road behind it (t %.1f s)" % hr.t)
	_check(ev.phase == ShermanEvent.Phase.ARRIVING and not tk.attackable, "parked, the assault not yet on")
	await _drive(ev, tk)
	ev._sched.clear()
	ev.begin_assault()
	var on: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.ASSAULT, 12.0, _cull_horde)
	_check(on and not ev._ring.is_empty() and ev._ring_at.distance_to(tk.global_position) < 0.1 and tk.global_position.distance_to(ev.park_point()) > 2.0 and tk.defending,
		"the assault on the moved tank: the dead rise round where it stands now (%d ring points, %.1f m from its parking place)" % [ev._ring.size(), tk.global_position.distance_to(ev.park_point())])
	var ring_ok: bool = true
	for q: Vector3 in ev._ring:
		var dq: float = ShermanRules.flat(q, tk.global_position)
		if dq < float(ev.cfg["assault"]["ring_min"]) - 1.6 or dq > float(ev.cfg["assault"]["ring_max"]) + 1.6:
			ring_ok = false
	_check(ring_ok, "every ring point is 10..16 m from the hull as it stands")
	var want: int = ShermanEvent.assault_count(RoundManager.players, ev.cfg["assault"])
	_check(on and ev.assault_total == want and ev.assault_fire_total == ShermanEvent.fire_count(want, ev.cfg["assault"]), "the assault: %d of the dead for %d players, %d burning" % [ev.assault_total, RoundManager.players, ev.assault_fire_total])
	_check(ev._boss_hud != null and ev._boss_hud.has_bar("sherman") and absf(tk.hp_fraction() - 1.0) < 0.01, "the tank's health is a boss bar (%d)" % int(tk.max_hp))
	await _until(func() -> bool: return ev.hud.counter.visible, 3.0)
	_check(ev.hud.counter.visible and ev.hud.counter.text.begins_with("THE DEAD ON THE SHERMAN"), "the counter: '%s'" % ev.hud.counter.text)
	# the dead reach the hull and beat on it
	var sw_a: int = tk.swipes_taken
	var hit: bool = await _until(func() -> bool: return tk.swipes_taken >= sw_a + 3, 45.0, _cull_horde)
	_check(hit and tk.hp < tk.max_hp, "the dead reach the hull and beat on it (%d swipes, %d of %d health)" % [tk.swipes_taken - sw_a, int(tk.hp), int(tk.max_hp)])
	var with_prey: int = 0
	for z: Zombie in ev.attackers:
		if z.prey is ShermanAttackPoint:
			with_prey += 1
	_check(with_prey == ev.attackers.size() and with_prey > 0, "every one of them is after the tank (%d)" % with_prey)
	# a fire zombie against the hull: the hiss, the burst, the tank hurt, the patch
	var found: Array = []   # (a lambda gets copies of the locals: the find goes into an array)
	await _until(func() -> bool:
		for n: Node in get_tree().get_nodes_in_group(FireZombie.GROUP):
			if not (n as FireZombie).burst_done and (n as FireZombie).zombie.state != Zombie.State.EMERGE:
				found.append(n)
				return true
		return false, 30.0, _cull_horde)
	var fz: FireZombie = found[0] as FireZombie if not found.is_empty() else null
	_check(fz != null and float(fz.zombie.get("_char")) > 0.5 and fz.zombie.max_hp < float(RoundManager.current_health()) * 0.5, "a fire zombie: charred, alight, under half a zombie's health")
	if fz != null:
		var hp0: float = tk.hp
		var b0: int = FireZombie.bursts
		var z: Zombie = fz.zombie
		z.global_position = tk.global_transform * Vector3(1.9, 0.05, 0.0)
		var burst: bool = await _until(func() -> bool: return FireZombie.bursts > b0, 4.0)
		_check(burst and FireZombie.fuses > 0, "against the hull it hisses and bursts (%d bursts, %d fuses)" % [FireZombie.bursts, FireZombie.fuses])
		_check(tk.hp <= hp0 - float(ev.cfg["fire_zombie"]["tank_damage"]) + 1.0, "the burst hurts the tank (%d -> %d)" % [int(hp0), int(tk.hp)])
		_check(FirePatch.live > 0, "and leaves a burning patch")
	# the team kills them: shot as they come
	var held: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.ASSIST, 120.0, func() -> void:
		_cull_horde()
		for z2: Zombie in ev.attackers.duplicate():
			if is_instance_valid(z2) and z2.is_active() and z2.state != Zombie.State.EMERGE:
				z2.take_damage(z2.hp + 1.0, &"head", &"m1911", 1, &"bullet"))
	_check(held and ev.outcome == "held" and not tk.is_wreck(), "the team beats them off: THE SHERMAN HOLDS (%d of %d health left)" % [int(tk.hp), int(tk.max_hp)])
	_check(tk.assisting and not tk.attackable and not tk.defending and not ev._boss_hud.is_struck("sherman"), "it starts to help; its bar is laid down (greyed, not struck through)")
	print("[sherman] note: in the assault the gunner fired %d shells and %d machine-gun rounds (the smoke kills the wave as it comes up: sherman_bench has the real count)" % [tk.shots_main - tk.driver_shells, tk.shots_mg])
	_check(_drops.has("resupply"), "a Resupply is thrown into the yard (%s)" % str(_drops))
	_check(not ev.hud.counter.visible, "the counter is gone")


# ================================================================== the assist

func _assist(ev: ShermanEvent) -> void:
	var tk: ShermanTank = ev.tank
	if tk == null:
		return
	# (the checks below are T-249's, laid out for the tank at its parking place: it is put back there)
	tk.park_at(ev.park_point(), ev.park_yaw())
	_place(_p(), Vector3(4.0, 0.05, 37.0))   # (in the yard's far corner: the dead cross its sight to get to them)
	if _bot() != null:
		_place(_bot(), Vector3(5.0, 0.05, 39.0))
	_hurt.clear()
	var hr: HorseRound = _map.get_node_or_null("HorseRound_30") as HorseRound
	if hr != null:
		for b: HorseBoss in hr.horses():
			b.take_damage(b.hp + 1.0, &"torso", &"m1911", 1, &"bullet")
	_cull_horde()
	# the dead in its sight on the road. (T-261: one alone and close is the machine gun's, no shell; a pack is the 75 mm's)
	var mg0: int = tk.shots_mg
	var sh0: int = tk.shots_main
	var made1: int = _dir().spawn_burst([Vector3(10.0, 0.0, 56.0)], 1)   # (on the road west of the gate, 13 m off)
	var shot: bool = await _until(func() -> bool: return tk.shots_mg > mg0 + 6 and (tk.mg_hits > 0 or tk.kills > 0), 25.0)
	_check(made1 > 0 and shot, "the machine gun on one of the dead in its sight (%d rounds, %d hits, %d kills)" % [tk.shots_mg - mg0, tk.mg_hits, tk.kills])
	var pts: Array = []
	for i: int in 4:
		pts.append(tk.global_transform * Vector3(-4.0 + 2.6 * float(i), 0, -16.0))
	var sh1: int = tk.shots_main
	var made: int = _dir().spawn_burst(pts, 4)
	var main: bool = await _until(func() -> bool: return tk.shots_main > sh1, 25.0)
	_check(made > 0 and main, "the 75 mm fires on a pack of them (%d shells, %d kills; %d shells on the one alone)" % [tk.shots_main - sh1, tk.kills, sh1 - sh0])
	_check(float(_hurt.get(1, 0.0)) == 0.0 and (_bot() == null or float(_hurt.get(_bot().player_id, 0.0)) == 0.0), "nothing on the players")
	# the round ends; it helps on round 31 too
	var t: float = 0.0
	while t < 40.0 and RoundManager.state != RoundManager.State.BREAK:
		RoundManager.to_spawn = 0
		for z: Zombie in _dir().active_zombies():
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")
		if RoundManager.alive <= 0 and RoundManager.state == RoundManager.State.ROUND:
			RoundManager.on_zombie_died()
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	_check(RoundManager.state == RoundManager.State.BREAK, "round 30 ends")
	await _until(func() -> bool: return RoundManager.current_round == 31 and RoundManager.state == RoundManager.State.ROUND, 40.0)
	_check(ev.phase == ShermanEvent.Phase.ASSIST and tk.assisting and is_instance_valid(tk), "round 31: still there, still covering the yard")


# ================================================================== round 40

func _round40(ev: ShermanEvent) -> void:
	var tk: ShermanTank = ev.tank
	_dir().kill_all(true)
	await _stuka_puts_out(ev, tk)
	var off0: int = tk.forced_off
	RoundManager.debug_set_round(40)
	await _until(func() -> bool: return RoundManager.current_round == 40 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	_check(ev.phase == ShermanEvent.Phase.STUKA, "round 40: the dive bomber")
	_check(tk.driver == null and _p().carry == null and tk.forced_off == off0 + 1 and not tk.near_hull(_p().global_position, 0.2), "the driver is put out beside the tank as the dive bomber comes")
	_check(not tk.drivable and not tk.can_use(_p()) and tk.prompt_for(_p()) == "", "and nobody climbs in after")
	_place(_p(), Vector3(10.0, 0.05, 9.0))   # in the taproom for the dive
	var flying: bool = await _until(func() -> bool: return ev.plane != null and is_instance_valid(ev.plane), 4.0)
	_check(flying, "it is in the air")
	var hit: bool = await _until(func() -> bool: return ev.stuka_hit_at != Vector3.INF, 30.0, _cull_horde)
	_check(hit and ev.stuka_hit_at.distance_to(tk.global_position) < 3.0, "the bomb lands on the Sherman")
	_check(tk != null and is_instance_valid(tk) and tk.is_wreck(), "it brews up and stays, a burning wreck")
	var warned: bool = await _until(func() -> bool: return ev.raid.phase == AirRaid.Phase.WARN, 6.0, _cull_horde)
	_check(warned and ev.hud.title.text != "" and ev.hud.count.text.begins_with("BOMBS IN"), "the air raid: the warning and the countdown ('%s', '%s')" % [ev.hud.title.text, ev.hud.count.text])
	_check(ev.raid.is_sheltered(_p().global_position), "the taproom counts as inside")
	# a bot outside goes in
	var bot: Player = _bot()
	var squad: BotSquad = _root().squad
	if bot != null and squad != null:
		_place(bot, Vector3(16.0, 0.05, 41.0))
		var brain: BotBrain = null
		for b: BotBrain in squad.brains:
			if b.player == bot:
				brain = b
		var told: bool = await _until(func() -> bool: return brain != null and str(brain.setpieces.move.get("kind", "")) == "shelter", 5.0, _cull_horde)
		_check(told, "a bot outside is sent to shelter")
		var inside: bool = await _until(func() -> bool: return ev.raid.is_sheltered(bot.global_position), 60.0, _cull_horde)
		_check(inside, "and gets inside the inn (%s)" % str(bot.global_position.snapped(Vector3.ONE * 0.1)))
	# the bombs: one by the human outside, one by the wall next to the bot inside
	ev.raid.phase = AirRaid.Phase.BOMBING
	ev.raid.t = 0.0
	ev.raid.cfg = (ev.raid.cfg as Dictionary).duplicate()
	ev.raid.cfg["duration"] = 10.0
	GameState.god_mode = false
	_p().max_hp = 1000.0
	_p().hp = 1000.0
	_place(_p(), Vector3(14.0, 0.05, 42.0))
	if bot != null:
		bot.max_hp = 1000.0
		bot.hp = 1000.0
		_place(bot, Vector3(21.0, 0.05, 14.5))
	for i: int in 20:
		_quiet()
		await get_tree().physics_frame
	var h0: float = _p().hp
	var b0: float = bot.hp if bot != null else 0.0
	var out_at: Vector3 = Vector3(15.5, 0.0, 42.0)
	ev.raid.drop(out_at)
	await _until(func() -> bool: return ev.raid.last_impacts.has(out_at), 6.0, _quiet)
	_check(_p().hp < h0 - 50.0, "a bomb by the human outside hurts them (%d -> %d)" % [int(h0), int(_p().hp)])
	# the same player inside, against the taproom's south wall, a bomb 4 m off on the other side of it
	_place(_p(), Vector3(21.0, 0.05, 14.5))
	await _secs(0.2)
	var h1: float = _p().hp
	var spared0: int = ev.raid.spared_inside
	var wall_at: Vector3 = Vector3(21.0, 0.0, 18.5)
	ev.raid.drop(wall_at)
	await _until(func() -> bool: return ev.raid.last_impacts.has(wall_at), 6.0, _quiet)
	_check(absf(_p().hp - h1) < 0.5 and ev.raid.spared_inside > spared0, "a bomb by the wall spares the same player inside (%d -> %d, spared %d)" % [int(h1), int(_p().hp), ev.raid.spared_inside - spared0])
	_check(bot == null or absf(bot.hp - b0) < 0.5 or not ev.raid.is_sheltered(bot.global_position), "the bot inside is untouched (%d -> %d)" % [int(b0), int(bot.hp) if bot != null else 0])
	GameState.god_mode = true
	_place(_p(), Vector3(10.0, 0.05, 9.0))
	var clear: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.DONE, 30.0, _cull_horde)
	_check(ev.raid.bombs_landed >= 4, "bombs land through the raid (%d)" % ev.raid.bombs_landed)
	_check(clear, "the all clear")
	_check(tk != null and is_instance_valid(tk) and tk.is_wreck(), "the wreck is still there")
	await _wreck_puts_out(ev)
	if _bot_note != "":
		print("[sherman] note: %s" % _bot_note)
	print("[sherman] %s" % ev.status())


# ================================================================== T-261: a player drives it

## Kept zombies (the drive's own: spared by _cull_horde) risen at `pts`.
func _spawn_kept(pts: Array) -> Array[Zombie]:
	var before: Array[Zombie] = _dir().active_zombies().duplicate()
	_dir().spawn_burst(pts, pts.size())
	var out: Array[Zombie] = []
	for z: Zombie in _dir().active_zombies():
		if not before.has(z):
			out.append(z)
			_keep.append(z)
	return out


func _alive(z: Zombie) -> bool:
	return z != null and is_instance_valid(z) and z.is_active() and z.state != Zombie.State.DEAD


## One of the kept dead that is up (out of the ground), risen in the meadow if none is left.
func _one_up() -> Zombie:
	var found: Array = []
	var pick: Callable = func() -> bool:
		for z: Zombie in _keep:
			if _alive(z) and z.state != Zombie.State.EMERGE:
				found.append(z)
				return true
		return false
	if pick.call():
		return found[0]
	_spawn_kept([Vector3(36.0, 0.0, 58.0), Vector3(38.0, 0.0, 59.0)])
	await _until(pick, 10.0, _cull_horde)
	return found[0] if not found.is_empty() else null


func _drive(ev: ShermanEvent, tk: ShermanTank) -> void:
	var p: Player = _p()
	var bot: Player = _bot()
	var park: Vector3 = tk.global_position
	if bot != null:
		_place(bot, Vector3(12.0, 0.05, 40.0))
	# the prompt at the hull, the Use ray on the hull's area
	_place(p, tk.global_transform * Vector3(2.6, 0.05, 0.5))
	var to_hull: Vector3 = tk.global_transform.basis * Vector3(-1, 0, 0)
	p.rotation.y = atan2(-to_hull.x, -to_hull.z)
	for i: int in 6:
		_cull_horde()
		await get_tree().physics_frame
	_check(tk.drivable and tk.can_use(p) and tk.prompt_for(p).contains("climb into"), "parked: the prompt at the hull ('%s')" % tk.prompt_for(p))
	_check(p.call("_probe_interactable") == tk.use, "the player's Use ray finds the hull")
	_check(bot == null or not tk.can_use(bot), "a bot does not climb in")
	tk.use.interact(p)
	var seated: bool = await _until(func() -> bool: return tk.seat == ShermanTank.Seat.SEATED, 3.0, _cull_horde)
	await get_tree().physics_frame
	_check(seated and tk.driver == p and p.carry == tk and p.global_position.distance_to(tk.seat_feet()) < 0.3, "the player climbs in: in the hatch, carried by the tank")
	_check(tk.prompt_for(p) == "" and (bot == null or not tk.can_use(bot)) and tk.simulates(), "one driver at a time; this machine moves the hull")
	# backwards down the road
	var p0: Vector3 = tk.global_position
	tk.input_override = Vector3(0, -1, 0)
	await _until(func() -> bool: return false, 4.0, _cull_horde)
	var back: float = (tk.global_position - p0).dot(tk.global_transform.basis.z)
	_check(back > 3.0 and tk.speed < -1.0 and p.global_position.distance_to(tk.seat_feet()) < 0.3, "the move keys drive it: %.1f m backwards in 4 s (%.1f m/s), the driver with it" % [back, tk.speed])
	# forwards at the gate: it stops short of the gate's mouth, and never enters the yard
	tk.input_override = Vector3(0, 1, 0)
	var r0: int = tk.refusals
	await _until(func() -> bool: return tk.refusals > r0, 12.0, _cull_horde)
	var bow: Vector3 = tk.global_transform * Vector3(0, 0, ShermanRules.HULL_BOW)
	var gate: Array = (ev.map_cfg["drive_no_go"] as Array)[0]
	var gate_d: float = Vector2(bow.x - float(gate[0]), bow.z - float(gate[1])).length()
	_check(tk.refusals > r0 and tk.speed == 0.0 and gate_d >= float(gate[2]) - 0.05 and ShermanRules.may_stand(tk.global_transform, [], ev.map_cfg) and bow.z > 48.0,
		"driven at the gate it stops short of the gate's mouth (the bow %.1f m from it, z %.1f): the way into the yard stays open" % [gate_d, bow.z])
	# back off, then a pivot turn
	tk.input_override = Vector3(0, -1, 0)
	await _until(func() -> bool: return false, 3.0, _cull_horde)
	var yaw0: float = tk.rotation.y
	tk.input_override = Vector3(1, 0, 0)
	await _until(func() -> bool: return false, 2.0, _cull_horde)
	var turned: float = absf(wrapf(tk.rotation.y - yaw0, -PI, PI))
	_check(turned > 0.7 and absf(tk.speed) < 0.1, "tank steering: a pivot turn on the spot (%.0f degrees in 2 s)" % rad_to_deg(turned))
	tk.input_override = Vector3(0, 0, 0)
	# the 75 mm from the driver's seat, on the dead in the meadow; the reload
	# (a place in the meadow the gun has a clear line to, 12 m or more off, wherever the hull now points)
	var spot: Vector3 = Vector3(36.0, 0.0, 58.0)
	for c0v: Vector3 in [Vector3(36.0, 0.0, 58.0), Vector3(44.0, 0.0, 57.0), Vector3(8.0, 0.0, 57.0), Vector3(30.0, 0.0, 60.0), Vector3(46.0, 0.0, 44.0)]:
		var eye: Vector3 = tk.global_transform * Vector3(0, 2.3, 0)
		var lq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, c0v + Vector3.UP * 1.0, 1)
		if ShermanRules.flat(c0v, tk.global_position) >= 12.0 and _map.get_world_3d().direct_space_state.intersect_ray(lq).is_empty():
			spot = c0v
			break
	var pack: Array[Zombie] = _spawn_kept([spot, spot + Vector3(1.5, 0, 0.6), spot + Vector3(0.6, 0, 1.6)])
	var aim: Callable = func() -> void:
		_cull_horde()
		# the nearest of the pack, at its chest (the shell bursts on the first of the dead on the barrel's line)
		var best: Zombie = null
		for z: Zombie in pack:
			if _alive(z) and (best == null or z.global_position.distance_to(tk.global_position) < best.global_position.distance_to(tk.global_position)):
				best = z
		if best != null:
			tk.aim_override = best.global_position + Vector3.UP * 1.0
	var laid: bool = await _until(func() -> bool:
		var up: bool = false
		for z: Zombie in pack:
			if _alive(z) and z.state != Zombie.State.EMERGE:
				up = true
		return up and tk.aim_override is Vector3 and tk.gun_laid(tk.aim_override, 3.0) and tk._gun_t <= 0.0, 16.0, aim)
	var sh0: int = tk.shots_main
	var hp_p: float = p.hp
	var hp_b: float = bot.hp if bot != null else 0.0
	_hurt.clear()
	tk.fire_wanted = true
	var fired: bool = await _until(func() -> bool: return tk.driver_shells >= 1, 2.0, aim)
	var hurt_n: int = 0
	var near_burst: float = INF
	for z: Zombie in pack:
		if not _alive(z) or z.hp < z.max_hp:
			hurt_n += 1
		if is_instance_valid(z):
			near_burst = minf(near_burst, z.global_position.distance_to(tk.last_burst))
	var guns_hurt: float = float(_hurt.get(1, 0.0)) + absf(p.hp - hp_p) + (absf(bot.hp - hp_b) if bot != null and tk.last_burst.distance_to(bot.global_position) < 12.0 else 0.0)
	_check(not pack.is_empty() and laid and fired and tk.shots_main == sh0 + 1, "the view lays the turret and fire fires the 75 mm (%d of the dead risen, laid %s)" % [pack.size(), str(laid)])
	print("[sherman] note: the driver's first shell burst %.1f m from the nearest of the pack, %.1f m from the muzzle (%d of %d hurt)" % [near_burst, tk.last_burst.distance_to(tk.muzzle()), hurt_n, pack.size()])
	_check(guns_hurt == 0.0, "nothing on the players from the driver's shell")
	_check(tk._gun_t > 4.0 and ev.hud.drive.visible and ev.hud.drive.text.begins_with("75 MM LOADING"), "it reloads: '%s'" % ev.hud.drive.text)
	tk.fire_wanted = true
	await _until(func() -> bool: return false, 2.0, aim)
	_check(tk.driver_shells == 1, "no second shell before it is loaded")
	var again: bool = await _until(func() -> bool: return tk.driver_shells >= 2, 8.0, aim)
	_check(again, "the next shell when the reload is over (%.1f s)" % float(ev.cfg["assist"]["gun_reload_s"]))
	hurt_n = 0
	for z: Zombie in pack:
		if not _alive(z) or z.hp < z.max_hp:
			hurt_n += 1
	_check(hurt_n > 0, "the driver's shells hurt the dead in their blast (%d of %d after two)" % [hurt_n, pack.size()])
	tk.fire_wanted = false
	# the machine gun
	var mg0: int = tk.shots_mg
	tk.mg_wanted = true
	await _until(func() -> bool: return false, 1.2, aim)
	tk.mg_wanted = false
	var mg1: int = tk.shots_mg
	await _until(func() -> bool: return false, 0.6, aim)
	_check(mg1 - mg0 >= 6 and tk.shots_mg - mg1 <= 1, "aim holds the machine gun (%d rounds in 1.2 s), and it stops when let go" % (mg1 - mg0))
	tk.aim_override = null
	# the dead under the tracks (whichever way it has room to go)
	var c0: int = tk.crushed
	for way: float in [1.0, -1.0]:
		if tk.crushed > c0:
			break
		var victim: Zombie = await _one_up()
		if victim == null:
			break
		tk.input_override = Vector3(0, way, 0)
		await _until(func() -> bool: return tk.crushed > c0, 5.0, func() -> void:
			_cull_horde()
			if _alive(victim) and absf(tk.speed) > 0.9:
				victim.global_position = tk.global_transform * Vector3(0.3, 0.05, -2.6 * way))
	_check(tk.crushed > c0, "the dead under the tracks are run down (%d), and it costs the hull speed" % (tk.crushed - c0))
	tk.input_override = Vector3(0, 0, 0)
	# the dead that come for the driver go for the hull, and the hull pays
	var mobber: Zombie = await _one_up()
	var sw0: int = tk.swipes_taken
	var hp0: float = tk.hp
	if mobber != null:
		mobber.global_position = tk.global_transform * Vector3(3.2, 0.05, 0.4)
	var mobbed: bool = await _until(func() -> bool: return mobber != null and _alive(mobber) and mobber.prey is ShermanAttackPoint, 6.0, _cull_horde)
	var struck: bool = await _until(func() -> bool: return tk.swipes_taken > sw0, 10.0, _cull_horde)
	_check(mobbed and struck and tk.hp < hp0 and not tk.is_wreck(), "the dead that come for the driver beat on the hull instead (%d swipes, %d -> %d)" % [tk.swipes_taken - sw0, int(hp0), int(tk.hp)])
	# out again: Use (or jump): set down beside the hull, free to move
	tk.dismount_wanted = true
	var out: bool = await _until(func() -> bool: return tk.driver == null, 3.0, _cull_horde)
	await get_tree().physics_frame
	var nav: Vector3 = NavigationServer3D.map_get_closest_point(_map.get_world_3d().navigation_map, p.global_position)
	_check(out and p.carry == null and not tk.near_hull(p.global_position, 0.2) and ShermanRules.hull_dist(tk.global_transform, p.global_position) < 4.5 and absf(p.global_position.y - tk.global_position.y) < 0.6 and nav.distance_to(p.global_position) < 1.2,
		"the driver climbs out: beside the hull (%.1f m from it), on walkable ground" % ShermanRules.hull_dist(tk.global_transform, p.global_position))
	_check(GameState.is_zone_open(ZoneVolume.zone_at(get_tree(), p.global_position + Vector3.UP * 0.6)), "in a zone that is open")
	var back_on: bool = await _until(func() -> bool: return mobber == null or not _alive(mobber) or mobber.prey == null, 3.0, _cull_horde)
	_check(back_on, "the dead on the hull turn back on the players")
	# driven again: the dead cannot wreck it outside the assault; at its last health the driver is put out, the hatch shut
	tk.use.interact(p)
	await _until(func() -> bool: return tk.seat == ShermanTank.Seat.SEATED, 3.0, _cull_horde)
	tk.hp = 40.0
	tk.take_swipe(null, tk.global_position)
	tk.take_swipe(null, tk.global_position)
	await get_tree().physics_frame
	_check(tk.bails == 1 and tk.driver == null and p.carry == null and not tk.is_wreck() and tk.lock_t > 5.0 and not tk.can_use(p) and tk.prompt_for(p).contains("repairs"),
		"at its last health the driver is put out and the hatch stays shut ('%s'); it is not wrecked" % tk.prompt_for(p))
	_check(not tk.near_hull(p.global_position, 0.2) and absf(p.global_position.y - tk.global_position.y) < 0.6, "the driver is set down beside it")
	var hp1: float = tk.hp
	await _until(func() -> bool: return false, 1.0, _cull_horde)
	_check(tk.hp > hp1 + 50.0, "the crew repairs it (%d -> %d in a second)" % [int(hp1), int(tk.hp)])
	tk.lock_t = 0.0
	for z: Zombie in _keep:
		if _alive(z):
			z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world")
	_keep.clear()
	_moved = tk.global_position.distance_to(park)
	_check(_moved > 2.0, "the tank stands %.1f m from where it parked" % _moved)
	# a bot against the moved hull, the human on the other side: it is not held by it
	if bot != null:
		var b0: Vector3 = tk.global_transform * Vector3(-2.0, 0.05, 0.0)
		_place(bot, b0)
		_place(p, tk.global_transform * Vector3(9.0, 0.05, 0.0))
		await _until(func() -> bool: return false, 10.0, _cull_horde)
		_bot_note = "a bot set against the moved hull with the human on the other side moved %.1f m in 10 s (ends %.1f m from the hull, %.1f m from the human)" % [
			bot.global_position.distance_to(b0), ShermanRules.hull_dist(tk.global_transform, bot.global_position), bot.global_position.distance_to(p.global_position)]
		print("[sherman] note: %s" % _bot_note)
		_check(not tk.near_hull(bot.global_position, -0.3) and bot.global_position.distance_to(b0) > 1.0, "the bot is not held by the moved hull (it walked %.1f m)" % bot.global_position.distance_to(b0))
	_place(p, Vector3(14.0, 0.05, 41.0))
	if bot != null:
		_place(bot, Vector3(12.0, 0.05, 40.0))


## The driver is put out before the dive bomber (round 40), and nobody climbs in after.
func _stuka_puts_out(ev: ShermanEvent, tk: ShermanTank) -> void:
	var p: Player = _p()
	_place(p, tk.global_transform * Vector3(2.6, 0.05, 0.5))
	await get_tree().physics_frame
	tk.use.interact(p)
	var seated: bool = await _until(func() -> bool: return tk.seat == ShermanTank.Seat.SEATED, 3.0)
	_check(seated and tk.driver == p, "round 39: a player is in the Sherman")


## A spare tank in the meadow, in its assault, with a driver: it brews up, and the driver is out and unhurt.
func _wreck_puts_out(ev: ShermanEvent) -> void:
	var p: Player = _p()
	GameState.god_mode = false
	p.max_hp = 100.0
	p.hp = 100.0
	_dir().kill_all(true)
	RoundManager.to_spawn = 0
	var t2: ShermanTank = ShermanTank.new()
	t2.setup(ev.cfg["tank"], ev.cfg["assist"], 8000.0, ev.cfg["drive"], ev.map_cfg)
	t2.hud = ev.hud
	_map.add_child(t2)
	t2.park_at(Vector3(40.0, 0.0, 58.0), 0.0)
	t2.drivable = true
	t2.attackable = true
	_place(p, t2.global_transform * Vector3(2.6, 0.05, 0.5))
	await get_tree().physics_frame
	t2.use.interact(p)
	await _until(func() -> bool: return t2.seat == ShermanTank.Seat.SEATED, 3.0, _quiet)
	var in_it: bool = t2.driver == p
	t2.take_damage(1.0e6)
	await get_tree().physics_frame
	_check(in_it and t2.is_wreck() and t2.driver == null and p.carry == null and p.is_alive() and p.hp >= 99.0 and not t2.near_hull(p.global_position, 0.2),
		"a Sherman that brews up with a player in it: the driver is out beside it, alive and unhurt (%d health)" % int(p.hp))
	_check(not t2.can_use(p) and t2.prompt_for(p) == "" and not ev.hud.drive.visible, "nobody climbs into a wreck; the driver's line is gone")
	GameState.god_mode = true
	t2.queue_free()
