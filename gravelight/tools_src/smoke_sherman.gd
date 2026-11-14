extends Node
## The Sherman on the Inn, rounds 30..40 (T-249; ShermanEvent, ShermanTank, FireZombie, FirePatch, StukaPlane, AirRaid),
## headless, solo with one bot, silent:
##   round 30  the round is reserved; der Fuhrmann's round begins too; the Sherman is heard, comes in from beyond the
##             edge, rolls over the barrier, parks outside the yard's gate facing it; the horse comes in behind it;
##             the assault (the count by the squad, fire zombies among them), the tank's boss bar and the counter; the
##             dead reach the hull and beat on it; a fire zombie against the hull hisses, bursts, hurts the tank and
##             leaves a burning patch; the team kills the rest: the tank HOLDS (a Resupply in the yard), and helps;
##   assist    the machine gun and the 75 mm on the dead in its sight (damage done, kills), nothing on the players;
##   round 40  the dive bomber dives, the bomb lands on the tank: it brews up and stays a wreck; the air raid: the
##             warning and the countdown; a bot outside is sent inside; a bomb by the human outside hurts them, a bomb
##             by the inn's wall spares the bot inside; bombs land through the raid; the all clear.
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
		if z is HomageBoss or (ev != null and ev.attackers.has(z)):
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
	var on: bool = await _until(func() -> bool: return ev.phase == ShermanEvent.Phase.ASSAULT, 12.0, _cull_horde)
	var want: int = ShermanEvent.assault_count(RoundManager.players, ev.cfg["assault"])
	_check(on and ev.assault_total == want and ev.assault_fire_total == ShermanEvent.fire_count(want, ev.cfg["assault"]), "the assault: %d of the dead for %d players, %d burning" % [ev.assault_total, RoundManager.players, ev.assault_fire_total])
	_check(ev._boss_hud != null and ev._boss_hud.has_bar("sherman") and absf(tk.hp_fraction() - 1.0) < 0.01, "the tank's health is a boss bar (%d)" % int(tk.max_hp))
	await _until(func() -> bool: return ev.hud.counter.visible, 3.0)
	_check(ev.hud.counter.visible and ev.hud.counter.text.begins_with("THE DEAD ON THE SHERMAN"), "the counter: '%s'" % ev.hud.counter.text)
	# the dead reach the hull and beat on it
	var hit: bool = await _until(func() -> bool: return tk.swipes_taken >= 3, 45.0, _cull_horde)
	_check(hit and tk.hp < tk.max_hp, "the dead reach the hull and beat on it (%d swipes, %d of %d health)" % [tk.swipes_taken, int(tk.hp), int(tk.max_hp)])
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
	_check(tk.assisting and not tk.attackable and not ev._boss_hud.is_struck("sherman"), "it starts to help; its bar is laid down (greyed, not struck through)")
	_check(_drops.has("resupply"), "a Resupply is thrown into the yard (%s)" % str(_drops))
	_check(not ev.hud.counter.visible, "the counter is gone")


# ================================================================== the assist

func _assist(ev: ShermanEvent) -> void:
	var tk: ShermanTank = ev.tank
	if tk == null:
		return
	_place(_p(), Vector3(12.0, 0.05, 40.0))
	_hurt.clear()
	var hr: HorseRound = _map.get_node_or_null("HorseRound_30") as HorseRound
	if hr != null:
		for b: HorseBoss in hr.horses():
			b.take_damage(b.hp + 1.0, &"torso", &"m1911", 1, &"bullet")
	_cull_horde()
	# the dead in its sight on the road
	var pts: Array = []
	for i: int in 4:
		pts.append(tk.global_transform * Vector3(-4.0 + 2.6 * float(i), 0, -16.0))
	var mg0: int = tk.shots_mg
	var made: int = _dir().spawn_burst(pts, 4)
	var shot: bool = await _until(func() -> bool: return tk.shots_mg > mg0 + 6 and (tk.mg_hits > 0 or tk.kills > 0), 25.0)
	_check(made > 0 and shot, "the machine gun on the dead in its sight (%d rounds, %d hits, %d kills)" % [tk.shots_mg - mg0, tk.mg_hits, tk.kills])
	var main: bool = await _until(func() -> bool: return tk.shots_main > 0, 25.0)
	_check(main, "the 75 mm fires on them (%d shells, %d kills)" % [tk.shots_main, tk.kills])
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
	RoundManager.debug_set_round(40)
	await _until(func() -> bool: return RoundManager.current_round == 40 and RoundManager.state == RoundManager.State.ROUND, 8.0)
	_check(ev.phase == ShermanEvent.Phase.STUKA, "round 40: the dive bomber")
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
	print("[sherman] %s" % ev.status())
