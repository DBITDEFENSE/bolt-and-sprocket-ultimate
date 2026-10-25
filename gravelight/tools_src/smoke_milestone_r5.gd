extends Node
## Smoke (T-078): Map 0 solo plays round 4 to its end headless; the round-5 milestone must drop a tonic bottle and a
## Resupply next to the survivor; picking them up gives a free tonic (no power, no Scrip) and full ammo; round pay
## and the untouched bonus are paid with their toasts; dog tags pay on pickup; round 5 starts. Then the player-bot
## agent (PlayerBot) must walk to and take a tonic bottle dropped near it, and an uncollected milestone drop that
## runs out is applied anyway. Prints RESULT PASS / FAIL.
## Usage: godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_milestone_r5.tscn

var _map: MapRoot
var _p: Player
var _dir: ZombieDirector
var _fails: PackedStringArray = []
var _spawned: Array = []        # [id, pos]
var _collected: Array = []      # [id, by]
var _bonuses: Array = []        # [pid, kind, amount, label]


func _ready() -> void:
	ProfileSave.path = "user://_qa_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_settings.cfg"
	GLSettings.values["homage_bosses"] = false
	GameState.bot_count = 0
	_map = (load("res://gravelight/maps/map00_crossroads/map00.tscn") as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.powerup_spawned.connect(func(id: StringName, pos: Vector3) -> void: _spawned.append([id, pos]))
	GLBus.powerup_collected.connect(func(id: StringName, by: int) -> void: _collected.append([id, by]))
	GLBus.bonus_awarded.connect(func(pid: int, kind: StringName, amount: int, label: String) -> void:
		_bonuses.append([pid, kind, amount, label])
		print("[milestone] bonus P%d %s %d \"%s\"" % [pid, kind, amount, label]))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _check(cond: bool, what: String) -> void:
	print("[milestone] %-66s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _pickups(id: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in _map.find_children("*", "PowerupPickup", true, false):
		if StringName(str(n.get("powerup_id"))) == id and n.is_inside_tree():
			out.append(n as Node3D)
	return out


func _bonus_of(kind: StringName) -> Array:
	return _bonuses.filter(func(b: Array) -> bool: return b[1] == kind)


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	while (_map.player == null or not _map.player.is_inside_tree()) and Time.get_ticks_msec() - t0 < 20000:
		await _frames(5)
	await _frames(30)
	_p = _map.player
	_dir = _map.get_node("ZombieDirector") as ZombieDirector
	GameState.god_mode = true
	_check(not GameState.power_on, "the power is off (the tonic needs none)")

	# ---- round 4 to its end
	RoundManager.debug_set_round(4)
	var t: float = 0.0
	while RoundManager.current_round < 4 and t < 10.0:
		await _secs(0.25)
		t += 0.25
	_check(RoundManager.current_round == 4 and RoundManager.state == RoundManager.State.ROUND, "round 4 started")
	var scrip_r4: int = Economy.get_scrip(1)
	t = 0.0
	while RoundManager.state == RoundManager.State.ROUND and t < 240.0:
		_dir.kill_all(false)   # credited to P1, as body kills
		_p.global_position = Vector3(14, 0, 8) if _p.global_position.distance_to(Vector3(14, 0, 8)) > 8.0 else _p.global_position
		await _secs(0.5)
		t += 0.5
	_check(RoundManager.state == RoundManager.State.BREAK and RoundManager.current_round == 4, "round 4 ended (%.0f s)" % t)
	await _frames(5)

	# ---- the milestone drops
	var tonic: Array[Node3D] = _pickups(&"tonic_bottle")
	var supply: Array[Node3D] = _pickups(&"resupply")
	_check(tonic.size() == 1, "a tonic bottle dropped")
	_check(supply.size() >= 1, "a Resupply dropped")
	_check(PowerupManager.milestones_done().has(5), "round 5's milestone is marked done")
	if tonic.size() == 1:
		_check(tonic[0].global_position.distance_to(_p.global_position) < 4.0, "the bottle is next to the survivor (%.1f m)" % tonic[0].global_position.distance_to(_p.global_position))
	_check(_bonus_of(&"round_pay").size() == 1 and int(_bonus_of(&"round_pay")[0][2]) == ScripBonuses.round_pay(4, ScripBonuses.cfg()), "round 4 pay with its toast")
	_check(_bonus_of(&"untouched").size() == 1, "untouched bonus (god mode: no hit landed)")
	_check(Economy.get_scrip(1) > scrip_r4, "Scrip went up over round 4")

	# ---- pick them up
	var perks_before: int = PerkManager.owned(1).size()
	var scrip_before: int = Economy.get_scrip(1)
	var w: WeaponInstance = _p.weapons.current()
	if w != null:
		w.reserve = 0
	if tonic.size() == 1:
		_p.global_position = tonic[0].global_position - Vector3.UP * 0.9
		await _frames(6)
	if not supply.is_empty() and is_instance_valid(supply[0]):
		_p.global_position = supply[0].global_position - Vector3.UP * 0.9
		await _frames(6)
	_check(_collected.any(func(c: Array) -> bool: return c[0] == &"tonic_bottle" and c[1] == 1), "P1 took the tonic bottle")
	_check(_collected.any(func(c: Array) -> bool: return c[0] == &"resupply"), "the Resupply was taken")
	_check(PerkManager.owned(1).size() == perks_before + 1, "a free tonic: %s" % ", ".join(PackedStringArray(PerkManager.owned(1).map(func(x: Variant) -> String: return str(x)))))
	_check(Economy.get_scrip(1) == scrip_before, "it cost nothing")
	_check(_bonus_of(&"tonic_bottle").size() == 1 and str(_bonus_of(&"tonic_bottle")[0][3]).begins_with("FREE TONIC"), "the HUD toast names it")
	if w != null:
		_check(w.reserve > 0, "the Resupply refilled the reserve (%d)" % w.reserve)

	# ---- dog tags
	scrip_before = Economy.get_scrip(1)
	var tag: Node3D = Economy.bonuses.spawn_tag(_p.global_position + Vector3(2.5, 0, 0), 150)
	_check(tag != null, "dog tags spawn")
	await _secs(1.5)
	_check(Economy.get_scrip(1) == scrip_before + 150 and not is_instance_valid(tag), "dog tags drift in and pay 150 (%d)" % (Economy.get_scrip(1) - scrip_before))
	_check(_bonus_of(&"salvage").size() == 1, "dog tags toast")

	# ---- round 5
	t = 0.0
	while RoundManager.current_round < 5 and t < 20.0:
		await _secs(0.25)
		t += 0.25
	_check(RoundManager.current_round == 5, "round 5 started")
	_dir.kill_all(true)

	# ---- the player-bot agent takes a bottle by itself
	var pb: PlayerBot = PlayerBot.of(get_tree())
	var on: bool = pb != null and pb.set_on(true, "smoke")
	_check(on, "player bot mode on")
	if on:
		RoundManager.stop()   # a quiet map: only the bottle to go for
		_dir.kill_all(true)
		await _secs(1.0)
		var fwd: Vector3 = -_p.global_basis.z
		fwd.y = 0.0
		var at: Vector3 = NavigationServer3D.map_get_closest_point(_p.get_world_3d().navigation_map, _p.global_position + fwd.normalized() * 5.0)
		var n_before: int = _collected.size()
		PowerupManager.spawn(&"tonic_bottle", at, 60.0, 50.0)
		t = 0.0
		while _collected.size() == n_before and t < 30.0:
			await _secs(0.25)
			t += 0.25
		_check(_collected.size() > n_before and _collected.back()[0] == &"tonic_bottle" and _collected.back()[1] == 1, "the agent walked over and took it (%.1f s)" % t)
		pb.set_on(false, "smoke end")

	# ---- an untouched milestone drop is applied when it runs out
	var n2: int = _collected.size()
	var far: Node3D = PowerupManager.spawn(&"tonic_bottle", _p.global_position + Vector3(0, 30, 0), 1.0, 0.5)
	_check(far != null, "a bottle nobody can reach")
	await _secs(2.0)
	_check(_collected.size() > n2 and _collected.back()[0] == &"tonic_bottle" and _collected.back()[1] == 0, "it expired and was applied anyway")

	print("[milestone] RESULT %s" % ("PASS" if _fails.is_empty() else "FAIL: " + "; ".join(_fails)))
	get_tree().quit(0 if _fails.is_empty() else 1)
