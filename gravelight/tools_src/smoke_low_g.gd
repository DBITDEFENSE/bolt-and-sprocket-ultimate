extends "res://gravelight/tools_src/smoke_m4d_u10_base.gd"
## UPDATE 10 §3 Act IV (T-158): low gravity done right, headless. The pads (five JumpPads, the yard's crater ring
## with its gap, the hall's leap points); a pad glide (the player steps on YardPad_S, is thrown over the crater's rim
## in a long arc and lands by the target); the fling into space (a Lodestone fling at a Gänger in the open yard sends
## it to orbit: a credited kill, the corpse taken, SENT TO ORBIT 1, the Operator; the same fling inside a dome does
## not); a leaper rises at a leap point and comes down at the player from above.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_low_g.tscn


func _init() -> void:
	TAG = "low_g"


func _body() -> void:
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/map04d.json").get("low_g", {})
	var pads: Array[Node] = get_tree().get_nodes_in_group(&"jump_pads")
	_check(pads.size() == (cfg.get("pads", []) as Array).size(), "the launch plates are placed (%d)" % pads.size())
	var crater: int = 0
	var cpos: Vector3 = Vector3(-31, 0, 79)
	for n: Node in _map.find_children("Rim_Crater*", "", true, false):
		crater += 1
	_check(crater >= 1, "the crater's rim is in the scene (%d blocks)" % crater)
	var rid: RID = _map.get_world_3d().navigation_map
	var walk: PackedVector3Array = NavigationServer3D.map_get_path(rid, cpos + Vector3(0, 0, -9.5), cpos + Vector3(0, 0, 10.0), true, 1 << 2)
	var walk_len: float = 0.0
	for i: int in walk.size() - 1:
		walk_len += walk[i].distance_to(walk[i + 1])
	_check(walk.size() > 1 and walk_len > 21.0, "on foot the crater is a detour (%.1f m for a 19.5 m crossing)" % walk_len)
	var inside: PackedVector3Array = NavigationServer3D.map_get_path(rid, cpos + Vector3(14, 0, 0), cpos, true, 1 << 2)
	_check(not inside.is_empty() and inside[inside.size() - 1].distance_to(cpos) < 1.5, "the bowl is reachable through the gap")
	var catwalks: int = 0
	for n2: Node in get_tree().get_nodes_in_group(&"zombie_spawns"):
		if String(n2.name).begins_with("Catwalk_E_HALL"):
			catwalks += 1
	_check(catwalks == 2, "the hall's two leap points (Catwalk_E_HALL_n)")
	# --- a pad glide over the crater
	var pad: JumpPad = _map.find_child("YardPad_S", true, false) as JumpPad
	_check(pad != null, "YardPad_S is in the yard")
	if pad != null:
		var v: Vector3 = JumpPad.launch_velocity(pad.global_position, pad.target, pad.flight_s, GameState.g_player())
		_check(JumpPad.apex_height(v, GameState.g_player()) > float((cfg.get("crater", {}) as Dictionary).get("rim_h", 2.4)) + 1.0, "the arc clears the rim (apex %.1f m)" % JumpPad.apex_height(v, GameState.g_player()))
		await _tp(pad.global_position + Vector3(0, 0.05, 0))
		var launched: bool = await _until(func() -> bool: return pad.launches > 0, 2.0)
		_check(launched, "standing on the plate launches the player")
		var peak: float = 0.0
		var t: float = 0.0
		while t < pad.flight_s + 1.5:
			peak = maxf(peak, _p.global_position.y)
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
			if t > 0.5 and _p.is_on_floor():
				break
		var land: Vector3 = _p.global_position
		_check(peak > 2.5, "a long glide: the player rose %.1f m" % peak)
		_check(Vector2(land.x - pad.target.x, land.z - pad.target.z).length() < 3.0, "landed by the target across the crater (%.1f m off)" % Vector2(land.x - pad.target.x, land.z - pad.target.z).length())
		var pad_line: bool = await _until(func() -> bool: return _said("OPR_M4D_PAD_01"), 25.0)
		_check(pad_line, "the Operator on the first launch")
	# --- the fling into space
	var lg: MoonLowG = _first(&"moon_lowg") as MoonLowG
	_check(lg != null, "MoonLowG runs the act's low gravity")
	await _tp(Vector3(10, 0, 82), 0.0)
	_p.rotation.y = 0.0
	await _frames(3)
	var fwd: Vector3 = -_p.global_transform.basis.z
	var z: Zombie = await _zombie_at(_p.global_position + fwd * 3.0)
	_check(z != null, "a Gänger out in the yard")
	var w: WeaponInstance = _p.weapons.find_weapon(&"lodestone")
	_check(w != null, "the Lodestone is in the kit")
	if w != null and lg != null and z != null:
		var gs: float = Lodestone.gravity_scale()
		var vel: Vector3 = Lodestone.fling_velocity(fwd, Lodestone.fling_distance(Lodestone.cfg(w), gs), gs)
		_check(MoonLowG.orbits(vel.length(), true, float(cfg.get("fling_speed", 15.0))), "a Moon fling is fast enough for orbit (%.1f m/s)" % vel.length())
		var res: Dictionary = Lodestone.resolve_fling(_p, _p.global_position + Vector3.UP * 1.5, fwd, w, 1)
		await _frames(5)
		_check(int(res.get("flung", 0)) >= 1 and int(res.get("orbited", 0)) >= 1, "the fling sends it to orbit (%s)" % str(res))
		_check(lg.orbit_count == 1 and (z.state == Zombie.State.DEAD or not z.is_active()), "a kill: SENT TO ORBIT 1")
		_check(get_tree().current_scene.find_children("*", "Node3D", false, false).filter(func(n: Node) -> bool: return n is MoonLowG.OrbitStreak).size() >= 1, "the streak and the scream rise from the yard")
		var orbit_line: bool = await _until(func() -> bool: return _said("OPR_M4D_ORBIT_01"), 25.0)
		_check(orbit_line, "the Operator: relocated off-site")
		await _secs(1.0)
		_check(not z.is_active() or z.state == Zombie.State.DEAD, "no corpse left on the regolith")
		# indoors: a fling only throws
		await _tp(Vector3(0, 0, 40))
		var z2: Zombie = await _zombie_at(_p.global_position + fwd * 3.0)
		var res2: Dictionary = Lodestone.resolve_fling(_p, _p.global_position + Vector3.UP * 1.5, fwd, w, 1)
		await _frames(3)
		_check(z2 != null and int(res2.get("orbited", 0)) == 0 and lg.orbit_count == 1, "under a roof the fling only throws")
		if z2 != null:
			z2.kill_silently()
	# --- a leaper from a leap point
	await _tp(Vector3(28, 0, 8))
	var lp: Node3D = _map.find_child("Catwalk_E_HALL_0", true, false) as Node3D
	if lp != null and lg != null:
		var zl: Zombie = await _zombie_at(lp.global_position)
		_check(zl != null, "a Gänger at the hall's leap point")
		if zl == null:
			return
		lg.make_leaper(zl)
		zl.target = _p
		lg.leap(zl, _p.global_position)
		var up: float = 0.0
		var tt: float = 0.0
		while tt < 3.0:
			up = maxf(up, zl.global_position.y)
			await get_tree().physics_frame
			tt += get_physics_process_delta_time()
		_check(lg.leaps >= 1 and up > 2.0, "a leaper comes down from above (apex %.1f m)" % up)
