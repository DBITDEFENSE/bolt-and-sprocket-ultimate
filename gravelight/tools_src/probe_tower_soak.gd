extends Node
## T-268 probe: a scripted player stands on the watchtower's top platform; zombies are spawned; prints what they do.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/probe_tower_soak.tscn [-- --secs=90 --n=8 --at=x,y,z]

var _map: Node3D
var _p: Player


func _ready() -> void:
	ProfileSave.path = "user://_qa_tower_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_run.call_deferred()


func _run() -> void:
	var secs: float = 90.0
	var n: int = 8
	var at: Vector3 = Vector3.INF
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--secs="):
			secs = float(a.substr(7))
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--at="):
			var q: PackedStringArray = a.substr(5).split(",")
			at = Vector3(float(q[0]), float(q[1]), float(q[2]))
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	for i: int in 12:
		await get_tree().physics_frame
	_p = _map.get_node("Player1") as Player
	RoundManager.stop()
	GameState.god_mode = true
	GameState.open_zone(&"YARD")
	if at == Vector3.INF:
		for l: Node in get_tree().get_nodes_in_group(&"ladders"):
			if l.name == "TowerLadder_Foot" or l.name == "TowerLadder_Upper":
				at = (l as LadderClimb).to_pos
	_p.global_position = at + Vector3(0, 0.05, 0.6)
	for i: int in 30:
		await get_tree().physics_frame
	print("[tower] player at %s on_floor %s" % [str(_p.global_position), str(_p.is_on_floor())])
	var dir: ZombieDirector = _map.get("director")
	if OS.get_cmdline_user_args().has("--soak"):
		await _soak(dir, secs)
		return
	if OS.get_cmdline_user_args().has("--crawl"):
		dir.spawn_burst([Vector3(6.0, 0, 40.5)], 1)
		await get_tree().create_timer(3.0).timeout
		for z: Zombie in dir.active_zombies():
			z.become_crawler()
		for i: int in 40:
			await get_tree().create_timer(1.0).timeout
			for z: Zombie in dir.active_zombies():
				print("[crawl] %d %s %s wait %s t %.1f navfin %s next %s" % [i, Zombie.State.keys()[z.state], str(z.global_position.snapped(Vector3(0.01, 0.01, 0.01))), str(z.get("_ladder_wait")), float(z.get("_ladder_wait_t")), str(z._agent.is_navigation_finished()), str(z._agent.get_next_path_position().snapped(Vector3(0.01, 0.01, 0.01)))])
		get_tree().quit(0)
		return
	dir.debug_spawn(n)
	if OS.get_cmdline_user_args().has("--trace"):
		for f: int in 240:
			await get_tree().physics_frame
			if f % 12 == 0 or f < 6:
				var ln: String = "[trace] f %d" % f
				for z: Zombie in dir.active_zombies():
					if z.global_position.y > 2.0 or f < 6:
						ln += " | %s %s %s v %s floor %s" % [String(z.name).right(3), Zombie.State.keys()[z.state], str(z.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(z.velocity.snapped(Vector3(0.1, 0.1, 0.1))), str(z.is_on_floor())]
				print(ln)
	if OS.get_cmdline_user_args().has("--soak") or OS.get_cmdline_user_args().has("--crawl"):
		return
	var t: float = 0.0
	var hits0: float = _p.health if "health" in _p else 0.0
	while t < secs:
		await get_tree().create_timer(3.0).timeout
		t += 3.0
		var line: String = "[tower] t %3.0f" % t
		for z: Zombie in dir.active_zombies():
			line += " | %s %s (%.1f %.1f %.1f)" % [String(z.name).right(3), Zombie.State.keys()[z.state], z.global_position.x, z.global_position.y, z.global_position.z]
		print(line)
	print("[tower] done; health %s -> %s" % [str(hits0), str(_p.get("health"))])
	get_tree().quit(0)


## The soak (T-268): the rounds run (from --round, default 5) with the scripted player standing on the tower's top
## platform. The player "fights" only what reaches them: a zombie that has stood within 2.5 m of them for 1.5 s is
## killed (--force sets every body on the player with forced_target). Every sixth riser has its legs shot off on the way (a crawler: it must not hold the round up). Prints, per
## round: its length, how many arrived (and the gaps between arrivals), how many were put back in the queue, the
## longest any body lived, the most on the two ladders at once; and at the end whether every round ended.
func _soak(dir: ZombieDirector, secs: float) -> void:
	var start_round: int = 5
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--round="):
			start_round = int(a.substr(8))
	GameState.god_mode = true
	# the way a squad really gets to the tower: the stable's door from the taproom, then the yard's door (the gate and
	# the grounds stay shut)
	for dn: String in ["Door_Stable", "Door_Yard"]:
		var door: Node = _map.find_child(dn, true, false)
		if door != null and door.has_method("open"):
			door.call("open", 0)
	await get_tree().create_timer(2.0).timeout
	print("[soak] zones open: %s" % str(GameState.open_zones.keys()))
	RoundManager.resume_at(start_round - 1, 99, 99, 2.0)
	var links: Node = _map.get_node("ClimbLinks")
	var lower: NavigationLink3D = links.get_node("Climb_Tower")
	var upper: NavigationLink3D = links.get_node("Climb_TowerUpper")
	var near: Dictionary = {}      # zombie -> seconds within reach
	var born: Dictionary = {}      # zombie -> seconds alive
	var seen: int = 0
	var round_no: int = RoundManager.current_round
	var round_t: float = 0.0
	var arrivals: Array[float] = []
	var requeues: int = 0
	var oldest: float = 0.0
	var most_ladder: int = 0
	var attacks: int = 0
	var rounds_done: int = 0
	var t: float = 0.0
	while t < secs:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		round_t += 0.25
		if RoundManager.current_round != round_no:
			var gaps: String = ""
			for k: int in range(1, arrivals.size()):
				gaps += "%.0f " % (arrivals[k] - arrivals[k - 1])
			print("[soak] round %d ended after %.0f s: %d arrived on the top (first after %.0f s; gaps %s), %d put back in the queue, longest life %.0f s, most on the ladders at once %d, attacks seen %d" % [round_no, round_t, arrivals.size(), arrivals[0] if not arrivals.is_empty() else -1.0, gaps, requeues, oldest, most_ladder, attacks])
			rounds_done += 1
			round_no = RoundManager.current_round
			round_t = 0.0
			arrivals.clear()
			requeues = 0
			oldest = 0.0
			most_ladder = 0
			attacks = 0
		most_ladder = maxi(most_ladder, ClimbLink.on_ladder(lower) + ClimbLink.on_ladder(upper))
		var live: Array[Zombie] = dir.active_zombies()
		for z: Zombie in born.keys():
			if not is_instance_valid(z) or not live.has(z):
				if is_instance_valid(z) and z.state == Zombie.State.INACTIVE and not near.has(z):
					requeues += 1
				born.erase(z)
				near.erase(z)
		for z: Zombie in live:
			if z.state == Zombie.State.DEAD:
				continue
			if not born.has(z):
				born[z] = 0.0
				seen += 1
				if OS.get_cmdline_user_args().has("--force"):
					z.forced_target = _p   # (Jakub breaks out of his cage at round 5 and is nearer to most of them; but a forced target also switches off the dead's own way round a shut door, so the plain soak runs rounds 2..4 without it)
				if seen % 6 == 0:
					get_tree().create_timer(6.0).timeout.connect(func() -> void:
						if is_instance_valid(z) and z.is_active() and z.state == Zombie.State.CHASE:
							z.become_crawler())
			born[z] = float(born[z]) + 0.25
			oldest = maxf(oldest, float(born[z]))
			if z.state == Zombie.State.ATTACK:
				attacks += 1
			if z.global_position.distance_to(_p.global_position) < 2.5:
				if not near.has(z):
					near[z] = 0.0
					arrivals.append(round_t)
				near[z] = float(near[z]) + 0.25
				if float(near[z]) >= 1.5:
					z.take_damage(z.hp + 1.0, &"torso", &"none", 1, &"bullet")
	print("[soak] done: %d rounds ended in %.0f s; now round %d, %d alive, %d queued" % [rounds_done, t, RoundManager.current_round, dir.active_zombies().size(), RoundManager.to_spawn])
	for z: Zombie in dir.active_zombies():
		print("[soak]   left: %s %s at %s, alive %.0f s" % [z.name, Zombie.State.keys()[z.state], str(z.global_position.snapped(Vector3(0.1, 0.1, 0.1))), float(born.get(z, 0.0))])
	get_tree().quit(0)
