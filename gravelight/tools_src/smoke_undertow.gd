extends Node
## Headless smoke for THE UNDERTOW on Totenhafen (UPDATE 10 contract C4, DECISIONS T-153). In order:
##   1. the parts: two spots per part, one live per part; the shard appears on the sea stairs (spawn_shard); the
##      three parts taken, the workbench builds it and gives it
##   2. the line: six zombies in a row on the quay; one harpoon skewers five (not the sixth), reels them to ~2 m,
##      and they arrive stunned
##   3. water: the lower pens flooded; a harpoon into the water opens a whirlpool that drags the zombies in it under
##   4. dry ground: the base gun opens nothing; MAELSTROM opens a land vortex (it drowns a zombie) and chains
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_undertow.tscn

const MAP: String = "res://gravelight/maps/map02_totenhafen/map02.tscn"
const TIMEOUT_S: float = 600.0

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _t0: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_undertow.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"deacon"
	GameState.bot_count = 0
	_map = (load(MAP) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GameState.god_mode = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> void:
	if Time.get_ticks_msec() - _t0 > int(TIMEOUT_S * 1000.0):
		_fails.append("timeout")
		_finish()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[undertow] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _tp(pos: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p.rotation.y = deg_to_rad(yaw)
	_p._pitch = deg_to_rad(pitch)
	if _p.head != null:
		_p.head.rotation.x = deg_to_rad(pitch)
	await _frames(3)


## A zombie of its own at `pos` (rise_at from the free pool: never one already placed), frozen until released.
func _zombie_at(pos: Vector3) -> Zombie:
	var z: Zombie = _dir.rise_at(pos, "sailor", 0.05)
	if z == null:
		return null
	await _frames(2)
	z.global_position = pos
	z.set_physics_process(false)
	await _frames(1)
	return z


func _clear() -> void:
	for z: Zombie in _dir.active_zombies():
		z.set_physics_process(true)
	_dir.kill_all(true)
	await _secs(1.5)


func _give(id: StringName) -> WeaponInstance:
	var wh: WeaponHolder = _p.weapons
	var w: WeaponInstance = wh.find_weapon_base(&"undertow")
	if w != null:
		wh.slots.erase(w)
	wh.give_weapon(id)
	w = wh.find_weapon_base(&"undertow")
	if w == null:
		w = wh.find_weapon(id)
	wh._select(wh.slots.find(w))
	await _frames(30)
	return w


func _shoot(w: WeaponInstance) -> Dictionary:
	w.mag = 1
	_p.weapons.harpoon_logic()._cd = 0.0
	_p.weapons.harpoon_logic().fire(w)
	return Undertow.last_result


func _run() -> void:
	await _frames(40)
	_p = _map.get_node_or_null("Player1") as Player
	_dir = get_tree().get_first_node_in_group(&"director") as ZombieDirector
	_check(_p != null and _dir != null, "the map, the player and the director")
	if _p == null or _dir == null:
		_finish()
		return
	RoundManager.stop()
	_dir.kill_all(true)
	var th: Totenhafen = Totenhafen.of(get_tree())
	_check(th != null, "Totenhafen's systems are attached")
	if th != null and th.gameplay.get_node_or_null("Workbench_Undertow") == null:
		print("[undertow] (Totenhafen did not attach the Undertow's parts: attaching them here)")
		UndertowParts.attach(th)
		await _frames(3)

	# --- 1. the parts and the bench
	var by_part: Dictionary = {}
	var live: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
		var bp: BuildablePart = n as BuildablePart
		if bp == null or bp.buildable_id != &"undertow":
			continue
		by_part[bp.part_id] = int(by_part.get(bp.part_id, 0)) + 1
		if bp.is_live():
			live[bp.part_id] = bp
	_check(int(by_part.get(&"undertow_pump", 0)) == 2 and int(by_part.get(&"undertow_head", 0)) == 2, "two spots each for the pump and the head (%s)" % str(by_part))
	_check(live.has(&"undertow_pump") and live.has(&"undertow_head") and live.size() == 2, "one live spot per part, no shard yet (%s)" % str(live.keys()))
	var shard: BuildablePart = UndertowParts.spawn_shard(th) as BuildablePart
	await _frames(2)
	_check(shard != null and shard.is_live() and shard.global_position.z < 3.0, "the shard lies by the sea stairs (the quay parapet, z < 3) after the dumps")
	for bp2: Variant in live.values():
		(bp2 as BuildablePart).interact(_p)
	if shard != null:
		shard.interact(_p)
	await _frames(3)
	_check(BuildablePart.parts_held(&"undertow") == 3, "the squad holds the three parts (%d)" % BuildablePart.parts_held(&"undertow"))
	var wb: Workbench = th.gameplay.get_node_or_null("Workbench_Undertow") as Workbench
	_check(wb != null and wb.get_prompt(_p).contains("build the Undertow"), "the bench offers the build (%s)" % (wb.get_prompt(_p) if wb != null else "none"))
	if wb != null:
		var bxz: Vector2 = Vector2(wb.global_position.x, wb.global_position.z)
		_check(not (bxz.x > 44.0 and bxz.x < 50.0 and bxz.y > 52.0 and bxz.y < 57.0), "the bench stands outside the solid crane office (%s)" % str(bxz))
		wb.interact(_p)
		await _frames(2)
		wb.interact(_p)
		await _frames(2)
	_check(wb != null and wb.built and _p.weapons.find_weapon_base(&"undertow") != null, "built, and the Undertow is in the player's hands")

	# --- 2. the line on the quay
	var w: WeaponInstance = await _give(&"undertow")
	_check(w != null and w.data.has("harpoon"), "holding the Undertow")
	await _tp(Vector3(26.0, 0.1, 28.0), 0.0, 0.0)
	var line: Array[Zombie] = []
	for zz: float in [24.0, 21.0, 18.0, 15.0, 12.0, 9.5]:
		line.append(await _zombie_at(Vector3(26.0, 0.0, zz)))
	for z: Zombie in line:
		z._enter(Zombie.State.CHASE)
		z.set_physics_process(true)
	var res: Dictionary = _shoot(w)
	var sk: Array = res.get("skewered", [])
	_check(sk.size() + int(res.get("killed", 0)) == 5, "one harpoon skewers five (%d skewered, %d killed)" % [sk.size(), int(res.get("killed", 0))])
	_check(not sk.has(line[5]), "the sixth in the line is past the pierce cap")
	_check(get_tree().get_first_node_in_group(&"undertow_whirls") == null, "no whirlpool on the dry quay (the base gun)")
	await _secs(float((w.data["harpoon"] as Dictionary)["reel_s"]) + 0.15)
	var near: int = 0
	var stunned: int = 0
	for z2: Variant in sk:
		var zz2: Zombie = z2 as Zombie
		if not is_instance_valid(zz2) or not zz2.is_active():
			continue
		var d: float = Vector2(zz2.global_position.x - _p.global_position.x, zz2.global_position.z - _p.global_position.z).length()
		if d < 4.5:
			near += 1
		if zz2.frost_speed_mult() < 0.05:
			stunned += 1
	_check(near >= mini(4, sk.size()) and sk.size() > 0, "reeled in to the shooter (%d of %d within 4.5 m)" % [near, sk.size()])
	_check(stunned >= mini(4, sk.size()) and sk.size() > 0, "they arrive stunned (%d of %d)" % [stunned, sk.size()])
	await _clear()

	# --- 3. the whirlpool in the flooded pens
	var tide: TideController = get_tree().get_first_node_in_group(&"tide") as TideController
	_check(tide != null, "the tide controller")
	if tide != null:
		tide.level = -1.5
		tide.target = -1.5
		tide._apply_level()
		await _frames(5)
		_check(tide.flooded, "the lower pens are flooded")
		await _tp(Vector3(40.0, -2.9, 58.0), 180.0, -16.0)
		var wz: Array[Zombie] = []
		for off: Vector3 in [Vector3(1.8, 0, 0.4), Vector3(-1.8, 0, 0.2), Vector3(1.4, 0, 1.6)]:
			wz.append(await _zombie_at(Vector3(40.0, -3.0, 64.0) + off))
		res = _shoot(w)
		var whirl: UndertowWhirl = res.get("whirl") as UndertowWhirl
		_check(whirl != null and not whirl.land, "a harpoon into the flood opens a whirlpool (impact %s)" % str(res.get("impact")))
		await _secs(1.8)
		var dead: int = 0
		for z3: Zombie in wz:
			if not z3.is_active() or z3.state == Zombie.State.DEAD:
				dead += 1
		_check(dead == wz.size(), "the whirlpool dragged the zombies in it under (%d of %d)" % [dead, wz.size()])
		tide.level = -4.0
		tide.target = -4.0
		tide._apply_level()
		await _clear()

	# --- 4. MAELSTROM on dry ground: a land vortex and the chain
	var wu: WeaponInstance = await _give(&"undertow_maelstrom")
	_check(wu != null and wu.upgraded, "holding Maelstrom")
	await _tp(Vector3(26.0, 0.1, 28.0), 0.0, -20.0)
	var lz: Zombie = await _zombie_at(Vector3(27.6, 0.0, 23.6))
	res = _shoot(wu)
	var lw: UndertowWhirl = res.get("whirl") as UndertowWhirl
	_check(lw != null and lw.land, "Maelstrom opens a violet vortex on the quay (impact %s)" % str(res.get("impact")))
	await _secs(1.6)
	_check(not lz.is_active() or lz.state == Zombie.State.DEAD, "the land vortex drowned the zombie beside it")
	await _clear()
	await _tp(Vector3(26.0, 0.1, 28.0), 0.0, 0.0)
	var cz: Array[Zombie] = []
	for pos: Vector3 in [Vector3(26.0, 0.0, 20.0), Vector3(29.5, 0.0, 18.0), Vector3(31.0, 0.0, 14.0)]:
		cz.append(await _zombie_at(pos))
	for z4: Zombie in cz:
		z4._enter(Zombie.State.CHASE)
		z4.set_physics_process(true)
	res = _shoot(wu)
	_check(int(res.get("chained", 0)) >= 2, "the harpoon chains on to the next targets within 6 m (%d)" % int(res.get("chained", 0)))
	_finish()


func _finish() -> void:
	set_process(false)
	print("[undertow] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	get_tree().quit(0 if _fails.is_empty() else 1)
