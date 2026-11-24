extends Node
## T-272: Kaltenbrunn's round 1 opening, the night shift runs (data/gravelight/map01_opening.json; InnOpening,
## YardGate), headless, solo, silent, the map loaded the way a smoke drops it in (round 1 comes by itself):
## the opening reads this map's file; the four miners are in the Waschkaue with the squad before round 1, under its roof,
## each in a modelled person's body (the row's `person`; the risen wear it too);
## round 1 waits for the settled view and the cue (the intro lines and Gorny's "What was that?" first); round 1 starts:
## the opening runs; the miners run out of the doorways and through the squad's view (within 56 degrees of the
## spawn's forward: an 80 degree FOV at 16:9); the north gate swings open for
## them and shuts again; Gorny and Kania go out through the gateway and are gone; Pietsch and Mrozek are caught in the
## south lane by the two that rise out of the snow, fall, and rise as zombies of round 1 on the yard's navmesh; round 1's
## size is unchanged (the four slots came off its queue); nothing is left over when the opening ends.
## Prints "[m1open] ..." and "[m1open] RESULT: PASS/FAIL"; exit code 0/1.
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_map01_opening.tscn

var _map: Node3D
var _p: Player
var _fails: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_m1open_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_m1open_settings.cfg"
	GameState.bot_count = 0
	Campaign.reset()
	_map = (load("res://gravelight/maps/map01_kaltenbrunn/map01.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	_checks += 1
	print("[m1open] %-100s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


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


func _nav_gap(p: Vector3) -> float:
	var q: Vector3 = NavigationServer3D.map_get_closest_point(_map.get_world_3d().navigation_map, p + Vector3.UP * 0.3)
	return Vector2(q.x - p.x, q.z - p.z).length() if absf(q.y - p.y) < 1.0 else INF


func _run() -> void:
	for i: int in 6:
		await get_tree().physics_frame
	_p = (_map as MapRoot).player
	GameState.god_mode = true
	_p.set_process_unhandled_input(false)
	var t0: int = Time.get_ticks_msec()
	var op: InnOpening = _map.find_child("InnOpening", true, false) as InnOpening
	var gate: Node3D = get_tree().get_first_node_in_group(&"yard_gate") as Node3D
	_check(op != null and str(op.cfg.get("map", "")) == "map01_kaltenbrunn" and op.phase == InnOpening.Phase.IDLE, "the opening reads this map's file and waits for round 1")
	if op == null or op.phase != InnOpening.Phase.IDLE:
		_finish()
		return
	var in_kaue: int = 0
	for pb: PatronBody in op.patrons.values():
		var p: Vector3 = pb.global_position
		var roof: bool = not _map.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.2, p + Vector3.UP * 20.0, 1)).is_empty()
		if pb.visible and p.x > 4.0 and p.x < 16.0 and p.z > 26.0 and p.z < 31.85 and roof:
			in_kaue += 1
	_check(op.patrons.size() == 4 and in_kaue == 4, "the four miners are in the Waschkaue with the squad, under its roof (%d of %d)" % [in_kaue, op.patrons.size()])
	var modelled: int = 0
	for pb3: PatronBody in op.patrons.values():
		if pb3.person != null:
			modelled += 1
	_check(modelled == 4, "every miner wears a modelled person's body, not the blockout (%d of 4)" % modelled)
	_check(RoundManager.current_round == 0, "round 1 has not started yet")
	var started: bool = await _until(func() -> bool: return RoundManager.current_round == 1, 40.0)
	var waited: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_check(started and op.cued and op.settle_t >= float(op.cfg["look"]["min_seconds"]) - 0.01, "round 1 waits for the settled view and the cue (it came after %.1f s, %.1f s of settled view)" % [waited, op.settle_t])
	_check(op._done_lines.size() >= 2, "the miners talked before it (%d intro lines)" % op._done_lines.size())
	var running: bool = await _until(func() -> bool: return op.phase == InnOpening.Phase.RUNNING, 3.0)
	_check(running, "round 1 starts: the opening runs")
	var slots: int = op.riser_specs.size() + op.attacker_specs.size()
	_check(slots == 4, "the two risers' and the two attackers' slots came off round 1's queue (%d)" % slots)
	# the run
	var seen: Dictionary = {}
	var through: Dictionary = {}
	var gate_opened: Array = [false]
	var cam_ok: Callable = func() -> void:
		for id: String in op.patrons.keys():
			var pb2: PatronBody = op.patrons[id]
			if not pb2.visible:
				continue
			var to: Vector3 = pb2.global_position - _p.global_position
			var fwd: Vector3 = -_p.global_transform.basis.z
			if Vector2(to.x, to.z).length() > 1.0 and rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)))) < 56.0 and pb2.global_position.z < 26.0:
				seen[id] = true
			if pb2.global_position.z < -0.6 and absf(pb2.global_position.x - 20.0) < 2.3:
				through[id] = true
		if gate != null and bool(gate.get("opened")):
			gate_opened[0] = true
	var done: bool = await _until(func() -> bool: return op.phase == InnOpening.Phase.DONE, 48.0, func() -> void:
		cam_ok.call()
		_p.hp = _p.max_hp
		# (nothing kills the risen in this check: the round's other zombies are culled where they come in)
		for z: Zombie in (_map as MapRoot).director.active_zombies():
			if not op.risen.values().has(z) and not op.attackers.values().has(z) and z.global_position.distance_to(_p.global_position) < 3.0:
				z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world"))
	_check(done, "the opening ends (t %.1f s)" % op.t)
	_check(seen.size() == 4, "every miner runs out through the squad's view (%s)" % str(seen.keys()))
	_check(gate_opened[0] and int(gate.get("opens")) >= 1, "the north gate swings open for them")
	await _until(func() -> bool: return not bool(gate.get("opened")), 3.0)
	_check(not bool(gate.get("opened")), "and shuts again")
	_check(through.has("gorny") and through.has("kania") and str(op.fates.get("gorny", "")) == "escaped" and str(op.fates.get("kania", "")) == "escaped",
		"Gorny and Kania go out through the gateway and are gone (%s)" % str(op.fates))
	var risen_ok: int = 0
	for id2: String in ["pietsch", "mrozek"]:
		var z2: Zombie = op.risen.get(id2) as Zombie
		if z2 != null and is_instance_valid(z2) and z2.is_active() and _nav_gap(z2.global_position) < 0.8 and String(ZoneVolume.zone_at(get_tree(), z2.global_position + Vector3.UP * 0.6)) == "A_MINEHEAD":
			risen_ok += 1
	_check(str(op.fates.get("pietsch", "")) == "risen" and str(op.fates.get("mrozek", "")) == "risen" and risen_ok == 2,
		"Pietsch and Mrozek are caught in the south lane and rise as zombies on the yard's navmesh (%d of 2)" % risen_ok)
	var dressed: int = 0
	for id3: String in ["pietsch", "mrozek"]:
		var z3: Zombie = op.risen.get(id3) as Zombie
		if z3 != null and is_instance_valid(z3) and str(z3.get_meta("person", "")) != "":
			dressed += 1
	_check(dressed == 2, "the risen wear the same people's bodies (%d of 2)" % dressed)
	_check(op.attackers.size() == 2, "two of the dead rose out of the snow for them (%d)" % op.attackers.size())
	_check(op.slots_returned == 0 and op.riser_specs.is_empty() and op.attacker_specs.is_empty(), "every slot was used, none returned (%d returned)" % op.slots_returned)
	_finish()


func _finish() -> void:
	print("[m1open] RESULT: %s (%d checks%s)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, "" if _fails.is_empty() else "; %d failed: %s" % [_fails.size(), "; ".join(_fails)]])
	get_tree().quit(0 if _fails.is_empty() else 1)
