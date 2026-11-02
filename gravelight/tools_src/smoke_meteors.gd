extends "res://gravelight/tools_src/smoke_m4d_u10_base.gd"
## UPDATE 10 §3 Act IV (T-158): the meteor-shower round and the Account's vent, headless. The schedule (match rounds
## 33, 39, 45; never a special round); a shower forced now: the relay's warning (the Operator's "scheduled
## maintenance", the klaxon) ten seconds ahead, then impacts across the yard only (rings first, strikes in the box),
## the dead in the open killed, a player standing out there hit; shelter in a module takes nothing; the end line.
## Then the vent: the lever is paid, the grate opens, the dead on it are drawn down the shaft, it shuts and cycles.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_meteors.tscn


func _init() -> void:
	TAG = "meteors"


func _body() -> void:
	var ms: MeteorShower = _first(&"meteor_shower") as MeteorShower
	_check(ms != null and not ms.cfg.is_empty(), "the MeteorShower runs on the Moon")
	if ms == null:
		return
	var due: Array[int] = []
	for r: int in range(30, 46):
		if MeteorShower.is_shower_round(r, int(ms.cfg["first_round"]), int(ms.cfg["every"]), false):
			due.append(r)
	_check(due == [33, 39, 45], "the schedule: match rounds %s" % str(due))
	_check(not MeteorShower.is_shower_round(39, 33, 6, true), "never on a special round")
	# shelter first: the human in the concourse, the dead out in the yard
	await _tp(Vector3(0, 0, 40))
	var victims: Array[Zombie] = []
	for i: int in 6:
		var zz: Zombie = await _zombie_at(Vector3(-30.0 + 12.0 * float(i), 0, 88))
		if zz != null:
			victims.append(zz)
	_check(victims.size() == 6, "six of the dead out in the yard")
	ms.begin()
	await _frames(5)
	_check(not ms.active, "nothing falls during the warning")
	var started: bool = await _until(func() -> bool: return ms.active, float(ms.cfg["warn_seconds"]) + 2.0)
	_check(started and GameState.has_flag(&"meteor_shower"), "the shower starts after the warning (flag meteor_shower)")
	_check(_said("OPR_M4D_METEOR_WARN_01"), "the relay warned: scheduled maintenance (%s)" % str(_vo.slice(-3)))
	var hp0: float = _p.hp
	# force a few strikes onto the dead so the smoke does not wait on chance
	# strikes where the dead stand now (the telegraph is checked by the impact count below)
	for z: Zombie in victims:
		if z.is_active():
			z.global_position = Vector3(z.global_position.x, 0, 88)
			ms.call("_strike", z.global_position)
	await _frames(5)
	var dead: int = 0
	for z2: Zombie in victims:
		if z2.state == Zombie.State.DEAD or not z2.is_active():
			dead += 1
	_check(dead >= 5 and ms.kills >= dead, "the dead in the open are killed (%d of 6, kills %d)" % [dead, ms.kills])
	var box: Array = ms.cfg["yard_box"]
	var inside: bool = true
	var shown: int = 0
	await _secs(6.0)
	_check(ms.impacts >= 10, "impacts keep coming (%d)" % ms.impacts)
	for c: Node in ms.get_children():
		var m: MeshInstance3D = c as MeshInstance3D
		if m == null or not (m.mesh is CylinderMesh) or (m.mesh as CylinderMesh).height > 0.05:
			continue
		shown += 1
		var p: Vector3 = m.global_position
		if p.x < float(box[0]) - 0.1 or p.x > float(box[2]) + 0.1 or p.z < float(box[1]) - 0.1 or p.z > float(box[3]) + 0.1:
			inside = false
	_check(shown >= 5 and inside, "every crater mark lies in the open yard (%d marks)" % shown)
	_check(is_equal_approx(_p.hp, hp0), "shelter in a module: the player in the concourse is untouched")
	# a player out in the open is hit (god mode off for one strike)
	await _tp(Vector3(0, 0, 90))
	GameState.god_mode = false
	_p.hp = 100.0
	ms.call("_strike", _p.global_position + Vector3(0.5, 0, 0))
	await _frames(3)
	_check(_p.hp < 100.0, "a strike next to the player hurts (health %.0f)" % _p.hp)
	GameState.god_mode = true
	_p.hp = 100.0
	await _tp(Vector3(0, 0, 40))
	var ended: bool = await _until(func() -> bool: return not ms.active, float(ms.cfg["seconds"]) + 5.0)
	_check(ended and not GameState.has_flag(&"meteor_shower"), "the shower ends (%d impacts)" % ms.impacts)
	_check(_said("OPR_M4D_METEOR_END_01"), "the Operator: maintenance complete")
	# --- the Account's vent
	GameState.set_flag(&"account_open")
	GameState.open_zone(&"F_CORE")
	await _frames(5)
	var lever: ShaftGrateLever = _first(&"shaft_grate_lever") as ShaftGrateLever
	var grate: ShaftGrate = _first(&"shaft_grate") as ShaftGrate
	_check(lever != null and grate != null and lever.grate() == grate, "the vent and its lever are in the Account")
	if lever == null or grate == null:
		return
	await _tp(lever.global_position + Vector3(1.2, 0, 0))
	var on: Array[Zombie] = []
	for i2: int in 3:
		var zg: Zombie = await _zombie_at(grate.global_position + Vector3(-0.8 + 0.8 * float(i2), 0, 0))
		if zg != null:
			on.append(zg)
	_check(on.size() == 3, "three of the dead come through the Account's door")
	for zg2: Zombie in on:
		zg2.global_position = grate.global_position + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
	var scrip0: int = Economy.get_scrip(1)
	lever.interact(_p)
	_check(grate.is_open() and Economy.get_scrip(1) == scrip0 - int(grate.cfg["cost"]), "paid: the vent opens (%d Scrip)" % (scrip0 - Economy.get_scrip(1)))
	await _secs(1.2)
	var gone: int = 0
	for z3: Zombie in on:
		if z3.state == Zombie.State.DEAD or not z3.is_active():
			gone += 1
	_check(gone == 3 and grate.taken >= 3, "the dead on the grate go down the shaft (%d)" % gone)
	var shaft_line: bool = await _until(func() -> bool: return _said("OPR_M4D_SHAFT_01"), 25.0)
	_check(shaft_line, "the Operator: returned to sender")
	await _until(func() -> bool: return not grate.is_open(), float(grate.cfg["open_seconds"]) + 2.0)
	_check(not grate.is_open() and not lever.can_interact(_p), "it shuts and cycles (cooldown %.0f s)" % lever.cool_left)
