extends Node
## Scripted QA for M2 systems on Map 0: crate (+ drummer), power-ups, perks (+ Second Wind),
## special weapons, the gramophone lure, the radio quest, VO lines.
## Usage: godot --headless --path . res://gravelight/tools_src/smoke_m2.tscn

var _map: Node3D
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _explosions: int = 0
var _vo_lines: int = 0
var _drummer: int = 0


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.explosion.connect(func(_pos: Vector3, _r: float) -> void: _explosions += 1)
	GLBus.vo_line_started.connect(func(_i: StringName, _s: StringName, _t: String, _d: float) -> void: _vo_lines += 1)
	GLBus.crate_drummer.connect(func(_i: int) -> void: _drummer += 1)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[m2] %-58s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _face(target: Vector3) -> void:
	var d: Vector3 = target - _p.global_position
	_p.rotation.y = atan2(-d.x, -d.z)
	var cam_h: float = 1.62
	_p.set("_pitch", atan2(target.y - (_p.global_position.y + cam_h), Vector2(d.x, d.z).length()))
	await _frames(2)


func _spawn_zombie_at(pos: Vector3) -> Zombie:
	for old: Zombie in _dir.active_zombies():
		old.kill_silently()
	await _secs(2.6)
	_dir.debug_spawn(1)
	await _frames(2)
	var z: Zombie = _dir.active_zombies()[0]
	z.global_position = pos
	z.set_physics_process(false)
	await _frames(2)
	return z


func _walk_forward(seconds: float) -> void:
	Input.action_press(&"move_forward")
	await _secs(seconds)
	Input.action_release(&"move_forward")
	await _frames(3)


func _run() -> void:
	await _frames(10)
	_p = _map.get_node("Player1") as Player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	RoundManager.stop()
	GameState.god_mode = true
	Economy.grant(1, 50000)

	# ---- crate
	var spots: Array[Node] = get_tree().get_nodes_in_group(&"crate_spots")
	_check(spots.size() == 3, "3 crate spots on Map 0")
	var crate: MysteryCrate = null
	for s: Node in spots:
		if (s as MysteryCrate).spot_index == CrateManager.location_index:
			crate = s as MysteryCrate
	_check(crate != null and crate.can_start, "crate starts at a can_start spot (%s)" % (crate.spot_name if crate else "-"))
	GameState.open_zone(&"STABLE")
	_p.global_position = crate.global_position + crate.global_basis.z * -1.3
	await _face(crate.global_position + Vector3.UP * 0.5)
	var scrip0: int = Economy.get_scrip(1)
	crate.interact(_p)
	_check(Economy.get_scrip(1) == scrip0 - 950, "crate charged 950")
	await _secs(4.8)
	_check(crate.phase == MysteryCrate.Phase.OFFERED, "crate offers a weapon after cycling")
	var before_slots: int = _p.weapons.slots.size()
	crate.interact(_p)
	_check(_p.weapons.slots.size() > before_slots or _p.weapons.tactical_id != &"", "took the crate weapon")
	await _secs(0.5)
	# force the drummer
	CrateManager.debug_next = CrateManager.DRUMMER
	scrip0 = Economy.get_scrip(1)
	var old_loc: int = CrateManager.location_index
	crate.interact(_p)
	_check(Economy.get_scrip(1) == scrip0, "drummer refunded the 950")
	await _secs(4.0)
	_check(_drummer == 1 and CrateManager.location_index != old_loc, "drummer moved the crate (%d -> %d)" % [old_loc, CrateManager.location_index])
	_check(GameState.has_flag(&"crate_has_moved"), "crate_has_moved flag set")

	# ---- power-ups
	_p.global_position = Vector3(14, 0, 8)
	_p.rotation.y = 0.0
	await _frames(3)
	PowerupManager.force_drop(&"double_scrip")
	await _walk_forward(1.0)
	_check(Economy.multiplier == 2, "Double Scrip collected (multiplier %d)" % Economy.multiplier)
	var w: WeaponInstance = _p.weapons.current()
	w.mag = 0
	w.reserve = 0
	_p.global_position = Vector3(14, 0, 8)
	PowerupManager.force_drop(&"resupply")
	await _walk_forward(1.0)
	_check(w.mag == w.mag_size(), "Resupply refilled ammo")

	# ---- the Crucible (T-032): in the cellar, dark until the lever
	var cru: Crucible = get_tree().get_first_node_in_group(&"crucible") as Crucible
	_check(cru != null and cru.global_position.y < -2.0 and cru.global_position.z > 19.0, "Crucible on Map 0, in the cellar")
	if cru != null:
		_check(not cru.can_interact(_p) and cru.get_prompt(_p) == "Power must be activated", "Crucible waits for the cellar power")

	# ---- perks
	GameState.power_on = true
	GLBus.power_activated.emit()
	var r: StringName = PerkManager.buy_for(1, &"ironhide_stout")
	await _frames(2)
	_check(r == &"ok" and is_equal_approx(_p.max_hp, 250.0), "Ironhide Stout: max hp %.0f" % _p.max_hp)
	PerkManager.buy_for(1, &"packmule_porter")
	await _frames(2)
	_check(_p.weapons.max_slots() == 3, "Packmule Porter: 3 slots")

	# ---- the Crucible, powered: feed a Kar98k, wait out the forge, take the upgrade
	if cru != null:
		_p.weapons.give_weapon(&"kar98k")
		await _frames(2)
		var price: int = Crucible.price_for(&"upgrade", GLData.table("economy"))
		Economy.grant(1, price)
		_check(cru.can_interact(_p) and cru.get_prompt(_p).begins_with("Hold"), "Crucible usable once powered (%s)" % cru.get_prompt(_p))
		var scrip_c: int = Economy.get_scrip(1)
		cru.interact(_p)
		await _frames(2)
		_check(cru.phase == Crucible.Phase.FORGING and Economy.get_scrip(1) == scrip_c - price, "Crucible took the weapon and %d Scrip" % price)
		await _secs(cru.forge_seconds + 0.4)
		_check(cru.phase == Crucible.Phase.OFFERED, "Crucible offers the upgrade")
		cru.interact(_p)
		await _frames(2)
		var uw: WeaponInstance = _p.weapons.current()
		_check(uw != null and uw.upgraded, "took the upgraded weapon (%s)" % (uw.display_name() if uw != null else "-"))
	PerkManager.buy_for(1, &"second_wind")
	PerkManager.buy_for(1, &"trigger_tonic")
	_check(PerkManager.buy_for(1, &"hawkeye_brandy") == &"cap", "perk cap of 4 enforced")
	GameState.god_mode = false
	_p.take_hit(9999.0, null)
	await _secs(0.5)
	_check(_p.downed and GameState.phase == GameState.Phase.PLAYING, "Second Wind: downed but the game continues")
	await _secs(4.0)
	_check(not _p.downed and PerkManager.has_perk(1, &"ironhide_stout") and not PerkManager.has_perk(1, &"second_wind"),
		"self-revived, kept Ironhide, lost Second Wind")
	GameState.god_mode = true

	# ---- special weapons
	_p.global_position = Vector3(14, 0, 13)
	_p.rotation.y = 0.0
	_p.weapons.give_weapon(&"panzerschreck")
	await _secs(0.6)
	var z: Zombie = await _spawn_zombie_at(Vector3(14, 0, 4))
	await _face(z.global_position + Vector3.UP)
	var ex0: int = _explosions
	for _t: int in 6:
		_p.weapons.tick(0.016, {"fire_pressed": true, "fire_held": true})
		await _secs(0.4)
		if _explosions > ex0:
			break
	_check(_explosions > ex0, "Panzerschreck rocket exploded")
	_p.weapons.give_weapon(&"ashlight")
	await _secs(0.6)
	z = await _spawn_zombie_at(Vector3(14, 0, 5))
	await _face(z.global_position + Vector3.UP)
	var hp0: float = z.hp
	# Retry for up to ~2 s: under load the raise animation can still be running on the first click.
	for _t: int in 8:
		_p.weapons.tick(0.016, {"fire_pressed": true, "fire_held": true})
		await _secs(0.25)
		if not z.is_active() or z.hp < hp0:
			break
	_check(not z.is_active() or z.hp < hp0, "Ashlight bolt hit (%.0f -> %.0f)" % [hp0, z.hp])
	_p.weapons.give_weapon(&"flamethrower")
	await _secs(0.6)
	z = await _spawn_zombie_at(Vector3(14, 0, 9.5))
	z.hp = 99999.0
	await _face(z.global_position + Vector3.UP)
	for i: int in 40:
		_p.weapons.tick(0.05, {"fire_pressed": i == 0, "fire_held": true})
		await _frames(3)
		if z.is_burning():
			break
	_check(z.is_burning(), "flamethrower set the zombie burning")
	z.kill_silently()

	# ---- gramophone lure
	_p.weapons.give_tactical(&"gramophone")
	_p.global_position = Vector3(14, 0, 8)
	_p.rotation.y = 0.0
	_p.set("_pitch", deg_to_rad(-20))
	await _frames(3)
	z = await _spawn_zombie_at(Vector3(20, 0, 12))
	z.set_physics_process(true)
	z.state = Zombie.State.CHASE
	_p.weapons.tick(0.016, {"tactical": true})
	await _secs(3.5)
	var lure: Node = get_tree().get_first_node_in_group(&"lures")
	_check(lure != null, "gramophone landed and is luring")
	if lure != null:
		var lp: Vector3 = (lure as Node3D).global_position
		var d0: float = Vector3(20, 0, 12).distance_to(lp)
		var d1: float = z.global_position.distance_to(lp)
		_check(d1 < d0 - 1.0 or d1 < 2.5, "zombie moving toward the lure (%.1f m -> %.1f m)" % [d0, d1])
	await _secs(6.0)
	_check(get_tree().get_first_node_in_group(&"lures") == null, "gramophone detonated")

	# ---- radio quest
	for n: Node in [_map.get_node("Gameplay/NoteA"), _map.get_node("Gameplay/NoteB"), _map.get_node("Gameplay/NoteC")]:
		(n as QuestNote).interact(_p)
	_check(QuestManager.is_step_done(&"map00_radio", &"s1_notes"), "picked up all 3 notes")
	var radio: FieldRadio = _map.get_node("Gameplay/FieldRadio") as FieldRadio
	_check(radio.lock_frequency("3.120") == "ok", "radio: first frequency locks")
	_check(radio.lock_frequency("6.000") == "wrong", "radio: wrong frequency resets")
	radio.lock_frequency("3.120")
	radio.lock_frequency("5.785")
	_check(radio.lock_frequency("7.440") == "done", "radio: full sequence completes")
	_check(GameState.has_flag(&"map00_complete") and ProfileSave.is_map_unlocked(&"map01_kaltenbrunn"), "map00_complete + Kaltenbrunn unlocked")

	# ---- VO
	await _secs(1.0)
	_check(_vo_lines > 0, "VO lines played (%d)" % _vo_lines)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	print("[m2] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)
