extends Node
## Scripted QA: plays "Requiem for Kaltenbrunn" end to end on Map 1, plus both side eggs, driving each step's
## real trigger (radios, switchboard, parts + workbench, a real shot at the Chapel bell, the Foreman killed in
## the lit Chapel, the altar, the Four Bells, the crate drummer chase incl. an escape, the Crucible, Totenglocke
## rings near the heart, the Heartstorm, the ending). Debug helpers only for travel/time: teleports,
## pylon attunement, Engine.time_scale, and forcing the crate's next result.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_requiem.tscn

const Q: StringName = &"map01_requiem"
const DY: float = -12.0
const CY: float = -18.0

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile_requiem.json"
	ProfileSave.profile = ProfileSave.new_profile()
	QuestManager.pending_seed = 4471
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
	print("[req] %-64s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _g(path: String) -> Node:
	return _map.get_node_or_null("Gameplay/" + path)


func _tp(pos: Vector3) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	await _frames(3)


func _aim_at(target: Vector3) -> void:
	var cam_pos: Vector3 = _p.global_position + Vector3.UP * 1.62
	var d: Vector3 = target - cam_pos
	_p.rotation.y = atan2(-d.x, -d.z)
	_p.set("_pitch", atan2(d.y, Vector2(d.x, d.z).length()))
	_p.set("_recoil", 0.0)
	await _frames(3)


func _fire_once() -> void:
	Input.action_press(&"fire")
	await _frames(2)
	Input.action_release(&"fire")
	await _frames(2)


func _ring_totenglocke() -> void:
	Input.action_press(&"fire")
	await _secs(0.9)
	Input.action_release(&"fire")
	await _frames(4)


func _run() -> void:
	await _frames(15)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	GameState.god_mode = true
	Economy.grant(1, 200000)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if not (n as BuyDoor).requires_power:
			(n as BuyDoor).open(0)
	_check(QuestManager.has_quest(Q) and QuestManager.has_quest(&"map01_song") and QuestManager.has_quest(&"map01_wren_tag"), "quests loaded on Map 1 (seed %d)" % QuestManager.match_seed)

	# ---- 0/1: power and the Core Vault
	_g("Hauptschalter").call("run_sequence", 1)
	await _secs(9.5)
	_check(QuestManager.is_step_done(Q, &"s0_power"), "step 0: power on")
	(_g("Door_Lab") as BuyDoor).open(0)
	for n: Node in get_tree().get_nodes_in_group(&"pylons"):
		n.call("debug_attune")
	await _secs(1.0)
	_check(QuestManager.is_step_done(Q, &"s1_vault"), "step 1: Core Vault open")
	_dir.kill_all(true)

	# ---- 2a: radios
	var live: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"quest_radios"):
		var r: QuestRadio = n as QuestRadio
		if r.live:
			live += 1
			r.interact(_p)
	_check(live == 3 and QuestManager.is_step_done(Q, &"s2a_radios"), "step 2a: 3 live radios heard (%d live)" % live)
	var code: String = str(QuestManager.random_value(Q, "code"))
	_check(str(GLVO.lines["FAS_M1_CODE3_01"]["text"]).contains("%s %s" % [code[4], code[5]]), "step 2a: fragment 3 speaks the last pair")

	# ---- 2b: switchboard (one wrong digit first)
	var board: Switchboard = _g("Switchboard") as Switchboard
	board.plug(int(code[0]))
	var wrong: int = (int(code[1]) + 1) % 10
	_check(board.plug(wrong) == "wrong" and int(QuestManager.progress(Q, &"s2b_switchboard")) == 0, "step 2b: a wrong jack resets the line")
	var last: String = ""
	for c: String in code:
		last = board.plug(int(c))
	_check(last == "done" and QuestManager.is_step_done(Q, &"s2b_switchboard"), "step 2b: switchboard code %s" % code)

	# ---- 3: Totenglocke parts + workbench
	var parts: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
		var bp: BuildablePart = n as BuildablePart
		if bp.visible:
			parts += 1
			bp.interact(_p)
	_check(parts == 3 and BuildablePart.parts_held() == 3, "step 3: three seeded parts picked up (%d visible)" % parts)
	var bench: Workbench = _g("Workbench") as Workbench
	bench.interact(_p)
	_check(QuestManager.is_step_done(Q, &"s3_build"), "step 3: Totenglocke built at the workbench")

	# ---- 4: light the bell with a real upgraded shot, kill the Foreman in the Chapel
	_p.weapons.give_weapon(&"m1911_up")
	await _secs(0.6)
	await _tp(Vector3(12, DY + 0.1, 77))
	await _aim_at(Vector3(12, DY + 10.7, 85))
	await _fire_once()
	_check(GameState.has_flag(&"chapel_bell_lit"), "step 4: Chapel bell lit by an upgraded shot")
	Engine.time_scale = 4.0
	await _secs(22.0)
	Engine.time_scale = 1.0
	var foreman: Zombie = null
	for z: Zombie in _dir.active_zombies():
		if z.enemy_id == &"foreman":
			foreman = z
	_check(foreman != null, "step 4: lighting the bell summoned the Foreman")
	if foreman != null:
		foreman.global_position = Vector3(12, DY, 70)
		await _frames(3)
		foreman.take_damage(foreman.hp + 99999.0, &"head", &"m1911_up", 1, &"bullet")
		await _frames(5)
	_check(QuestManager.has_item(&"overseers_key"), "step 4: the Foreman dropped the Overseer's Key")

	# ---- 5: altar
	(_g("Altar") as AltarReliquary).interact(_p)
	_check(QuestManager.has_item(&"music_box") and QuestManager.is_step_done(Q, &"s5_reliquary"), "step 5: reliquary opened, music box")

	# ---- 6: Four Bells (wrong order first)
	var melody: Array = QuestManager.random_value(Q, "melody")
	var bells: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(&"quest_bells"):
		var qb: QuestBell = n as QuestBell
		if qb.kind == &"small" and qb.visible:
			bells[String(qb.note)] = qb
	_check(bells.size() == 4, "step 6: one seeded bell per note (%d)" % bells.size())
	(bells[str(melody[0])] as QuestBell).on_shot(&"m1911", false, 1)
	(bells[str(melody[3])] as QuestBell).on_shot(&"m1911", false, 1)
	_check(int(QuestManager.progress(Q, &"s6_bells")) == 0, "step 6: a wrong bell resets the melody")
	for note: Variant in melody:
		(bells[str(note)] as QuestBell).on_shot(&"m1911", false, 1)
	_check(QuestManager.is_step_done(Q, &"s6_bells"), "step 6: bells rung in melody order %s" % str(melody))

	# ---- 7: the drummer chase (let the first one escape)
	var crate: MysteryCrate = _current_crate()
	CrateManager.debug_next = CrateManager.DRUMMER
	crate.interact(_p)
	await _frames(5)
	_check(get_tree().get_nodes_in_group(&"quest_drummers").size() == 1, "step 7: Herr Tamtam marches off instead of vanishing")
	Engine.time_scale = 6.0
	await _secs(26.0)
	Engine.time_scale = 1.0
	_check(get_tree().get_nodes_in_group(&"quest_drummers").is_empty() and QuestManager.is_active(Q, &"s7_drummer")
		and CrateManager.uses_until_move <= 3, "step 7: he escaped; step resets, drummer due after %d uses" % CrateManager.uses_until_move)
	await _secs(1.0)
	crate = _current_crate()
	CrateManager.debug_next = CrateManager.DRUMMER
	crate.interact(_p)
	await _frames(5)
	var drummers: Array[Node] = get_tree().get_nodes_in_group(&"quest_drummers")
	if not drummers.is_empty():
		var dr: Node3D = drummers[0] as Node3D
		await _secs(1.0)
		await _tp(dr.global_position + Vector3(0, 0, 5))
		await _aim_at(dr.global_position + Vector3.UP * 0.35)
		await _fire_once()
		await _frames(5)
		if is_instance_valid(dr) and dr.is_inside_tree():
			print("[req] (note) the aimed shot missed the moving drummer; hitting him directly")
			dr.call("on_shot", &"m1911_up", true, 1)
			await _frames(3)
	var shard: QuestPickup = null
	for n: Node in _map.find_children("*", "Node3D", true, false):
		if n is QuestPickup and (n as QuestPickup).item_id == &"nachtglas_shard":
			shard = n as QuestPickup
	_check(shard != null, "step 7: shooting him drops the Nachtglas shard")
	if shard != null:
		shard.interact(_p)
	_check(QuestManager.is_step_done(Q, &"s7_drummer"), "step 7: shard picked up")

	# ---- 8: place the shard, 30 Totenglocke kills near the heart
	await _tp(Vector3(42, CY + 0.1, 124))
	var cru: Crucible = _g("Crucible") as Crucible
	cru.interact(_p)
	_check(QuestManager.is_step_done(Q, &"s8a_place"), "step 8a: shard placed in the Crucible")
	bench.interact(_p)
	_check(_p.weapons.find_weapon(&"totenglocke") != null, "step 3: took the Totenglocke from the workbench")
	await _secs(0.6)
	await _tp(Vector3(34, CY + 0.1, 106))
	_p.rotation.y = 0.0
	_p.set("_pitch", 0.0)
	_p.weapons.current_index = _slot_of(&"totenglocke")
	_p.weapons.call("_rebuild_gun")
	var tries: int = 0
	while not QuestManager.is_step_done(Q, &"s8b_charge") and tries < 12:
		tries += 1
		_p.weapons.current().refill()
		var pts: Array = [Vector3(33.4, CY, 102.5), Vector3(34.6, CY, 102.5), Vector3(33.4, CY, 103.8),
			Vector3(34.6, CY, 103.8), Vector3(34.0, CY, 101.5), Vector3(34.0, CY, 104.4)]
		_dir.spawn_burst(pts, 6)
		await _frames(4)
		for z: Zombie in _dir.active_zombies():
			z.set_physics_process(false)
		await _aim_at(Vector3(34, CY + 1.0, 103))
		var before: int = _dir.active_zombies().size()
		var mag0: int = _p.weapons.current().mag
		await _ring_totenglocke()
		await _secs(0.3)
		if _p.weapons.current().mag == mag0:
			print("[req] (note) ring did not fire: weapon %s, %d zombies" % [_p.weapons.current().id, before])
	_check(QuestManager.is_step_done(Q, &"s8b_charge"), "step 8b: 30 Totenglocke kills near the heart (%s)" % str(QuestManager.progress(Q, &"s8b_charge")))
	_dir.kill_all(true)

	# ---- 9: Heartstorm (sped up), 10: ending
	await _tp(Vector3(42, CY + 0.1, 124))
	cru.interact(_p)
	_check(not QuestManager.holdout_state(Q, &"s9_heartstorm").is_empty(), "step 9: Heartstorm started at the Crucible")
	Engine.time_scale = 8.0
	await _secs(128.0)
	_check(QuestManager.is_step_done(Q, &"s9_heartstorm"), "step 9: held the Core for two minutes")
	await _secs(45.0)
	Engine.time_scale = 1.0
	await _frames(5)
	_check(QuestManager.is_complete(Q), "step 10: ending played, Requiem complete")
	_check(PerkManager.owned(1).size() == 8 and GameState.has_flag(&"requiem_complete"), "rewards: all 8 perks above the cap")
	_check(bool((ProfileSave.profile.get("egg_rewards", {}) as Dictionary).get("map01_perk_slot_5", false)) and PerkManager.cap_for(1) == 5,
		"rewards: permanent 5th perk slot on Map 1")
	_check(ProfileSave.is_map_unlocked(&"map02_totenhafen"), "rewards: Map 2 Totenhafen unlocked")

	# ---- side eggs
	for c: String in ["Cylinder1", "Cylinder2", "Cylinder3"]:
		(_g(c) as QuestPickup).interact(_p)
	(_g("Phonograph") as Phonograph).interact(_p)
	_check(GameState.has_flag(&"song_unlocked") and QuestManager.is_complete(&"map01_song"), "side egg: Lanterns Down Below unlocked")
	(_g("Tag_KB4471") as QuestPickup).interact(_p)
	_check(QuestManager.is_complete(&"map01_wren_tag"), "side egg: tag KB-4471 found")

	print("[req] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _current_crate() -> MysteryCrate:
	for s: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		if int(s.get("spot_index")) == CrateManager.location_index:
			return s as MysteryCrate
	return null


func _slot_of(id: StringName) -> int:
	for i: int in _p.weapons.slots.size():
		if _p.weapons.slots[i].id == id:
			return i
	return 0
