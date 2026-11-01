extends Node
## T-136 headless smoke: the savings bank. Silent, solo, a god-mode human, a scratch profile.
##   Map 0: the Darlehenskasse in the old woodshed: the branch, its teller and counter are there; the navmesh goes in
##     through the doorway to the counter (a path from the start, every door open); walking up, the teller greets
##     you (a TEL line); the counter's prompt; the card opens, DEPOSIT 1000 and DEPOSIT ALL move Scrip into the
##     profile's balance; a round start adds 1%; a zombie by the counter makes him cower.
##   Kaltenbrunn: the pay office; the balance is still there (from the saved profile); WITHDRAW ALL brings it back
##     into your pocket, and none of it counted as earned Scrip.
##   T-141 (UPDATE 09 contract C6), every other map: Totenhafen's Marinekasse, Werk Thalbach's Lohnkasse, the Kranich's
##     Bordkasse, Groom Lake's Range Finance Office, Darkmatter's Accounts: the branch, its teller (or the Operator's
##     speaking-tube window), the navmesh reaches the counter, the greeting in the right voice, a deposit and a
##     withdrawal, the same account; Ledger Lager's machine is on every map and the navmesh reaches it.
## Prints "[bank-smoke] ..." and "[bank-smoke] RESULT: PASS/FAIL"; exit code 0/1.

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 600.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _tel_lines: PackedStringArray = []


func _ready() -> void:
	ProfileSave.path = "user://_qa_bank_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	ProfileSave.save_profile()
	GLSettings.path = "user://_qa_bank_settings.cfg"
	GLSettings.values["classic_rules"] = false
	GameState.bot_count = 0
	Campaign.reset()
	GLBus.vo_line_started.connect(func(id: StringName, _who: StringName, _text: String, _d: float) -> void:
		if String(id).contains("_BANK_"):
			_tel_lines.append(String(id))
			print("[bank-smoke] teller: %s" % id))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(m: String) -> void:
	print("[bank-smoke] " + m)


func _fail(m: String) -> void:
	_fails.append(m)
	print("[bank-smoke] FAIL " + m)


func _check(c: bool, what: String) -> void:
	if c:
		_note("ok   " + what)
	else:
		_fail(what)


func _finish() -> void:
	print("[bank-smoke] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _secs(s: float) -> void:
	var end: float = _t + s
	while _t < end:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float) -> bool:
	var end: float = _t + seconds
	while _t < end:
		if pred.call():
			return true
		await get_tree().physics_frame
	return bool(pred.call())


func _root() -> MapRoot:
	return _map as MapRoot


func _load(scene: String) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(scene) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 30.0)
	await _secs(1.5)
	GameState.god_mode = true
	_root().player.set_process_unhandled_input(false)
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and not (n as BuyDoor).is_open:
			(n as BuyDoor).open(1)


func _branch() -> BankBranch:
	return get_tree().get_first_node_in_group(&"bank_branch") as BankBranch


func _run() -> void:
	await _load(MAP0)
	var b: BankBranch = _branch()
	_check(b != null and b.teller != null and b.counter != null, "map00: the bank, its teller and its counter")
	if b == null:
		_finish()
		return
	var h: Player = _root().player
	var front: Vector3 = b.counter.global_position + b.global_basis.z * 0.5
	var nav: RID = h.get_world_3d().navigation_map
	var start: Vector3 = _root().spawn_transform(1).origin
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, start, front, true, 0xFFFFFFFF)
	var end_ok: bool = not path.is_empty() and path[path.size() - 1].distance_to(front) < 0.8
	_check(end_ok, "map00: the navmesh reaches the counter through the doorway (%d points, ends %s, counter %s)" % [path.size(),
		str(path[path.size() - 1].snapped(Vector3.ONE * 0.1)) if not path.is_empty() else "-", str(front.snapped(Vector3.ONE * 0.1))])
	h.global_position = front + b.global_basis.z * 0.4
	h.velocity = Vector3.ZERO
	await _until(func() -> bool: return _tel_lines.size() > 0, 5.0)
	_check(_tel_lines.size() > 0 and _tel_lines[0].begins_with("TEL_BANK_GREET_"), "map00: he greets you (%s)" % (_tel_lines[0] if _tel_lines.size() > 0 else "-"))
	_check(b.counter.get_prompt(h).begins_with("Bank:"), "map00: the counter's prompt: \"%s\"" % b.counter.get_prompt(h))
	Economy.grant(1, 4500)
	var pocket0: int = Economy.get_scrip(1)
	var earned0: int = int(GameState.stats.get(&"scrip_earned", 0))
	b.counter.interact(h)
	await _secs(0.3)
	var card: BankCard = b.counter.card
	_check(card != null and GameState.input_blocked, "map00: the card opens (you stand still)")
	if card != null:
		_check(card.move("deposit") == 1000, "map00: DEPOSIT 1000")
		var rest: int = Economy.get_scrip(1)
		_check(card.move("deposit_all") == rest, "map00: DEPOSIT ALL (%d)" % rest)
		_check(Economy.get_scrip(1) == 0 and BankAccount.balance() == pocket0, "map00: all %d in the bank, nothing in the pocket" % pocket0)
		card.close()
		await _secs(0.2)
	_check(not GameState.input_blocked, "map00: input free again")
	var bal0: int = BankAccount.balance()
	RoundManager.advance_round()
	await _secs(0.2)
	_check(BankAccount.balance() == bal0 + int(floor(bal0 * 0.01)), "map00: a round start adds 1%% (%d -> %d)" % [bal0, BankAccount.balance()])
	# a shot fired in the bank: he flinches and cowers behind the counter, then gets back up
	_check(b.teller.pose == &"clutch", "map00: he clutches the counter (%s)" % b.teller.pose)
	GLBus.weapon_fired.emit(1, &"m1911", false, front + Vector3(0, 1.5, 0), b.global_basis.z)
	await _secs(0.6)
	_check(b.teller.pose == &"cower", "map00: a shot in the bank: he cowers (%s)" % b.teller.pose)
	await _secs(3.5)
	_check(b.teller.pose == &"clutch" or b._dead_near(12.0), "map00: and gets back up (%s)" % b.teller.pose)
	var saved: int = BankAccount.balance()
	# Kaltenbrunn: the pay office, the same account
	ProfileSave.profile = {}
	ProfileSave.load_profile()
	_check(BankAccount.balance() == saved, "the balance is in the saved profile (%d)" % saved)
	_tel_lines.clear()
	await _load(MAP1)
	b = _branch()
	_check(b != null and b.teller != null, "map01: the pay office, its teller")
	if b != null:
		h = _root().player
		front = b.counter.global_position + b.global_basis.z * 0.5
		path = NavigationServer3D.map_get_path(h.get_world_3d().navigation_map, _root().spawn_transform(1).origin, front, true, 0xFFFFFFFF)
		_check(not path.is_empty() and path[path.size() - 1].distance_to(front) < 0.8, "map01: the navmesh reaches the counter (%d points, ends %s, counter %s)" % [path.size(),
			str(path[path.size() - 1].snapped(Vector3.ONE * 0.1)) if not path.is_empty() else "-", str(front.snapped(Vector3.ONE * 0.1))])
		h.global_position = front + b.global_basis.z * 0.4
		h.velocity = Vector3.ZERO
		await _until(func() -> bool: return _tel_lines.size() > 0, 5.0)
		_check(_tel_lines.size() > 0 and _tel_lines[0].begins_with("TEL_BANK_GREET_M1_"), "map01: he remembers you (%s)" % (_tel_lines[0] if _tel_lines.size() > 0 else "-"))
		var p0: int = Economy.get_scrip(1)
		b.counter.interact(h)
		await _secs(0.3)
		if b.counter.card != null:
			var got: int = b.counter.card.move("withdraw_all")
			_check(got == saved and Economy.get_scrip(1) == p0 + saved, "map01: WITHDRAW ALL brings back %d" % got)
			b.counter.card.close()
		_check(int(GameState.stats.get(&"scrip_earned", 0)) - earned0 <= 4500 + 50000, "no bank move counted as earned (only the test's grant)")
	await _other_maps()
	_finish()


## The five branches of UPDATE 09 (T-141) and Ledger Lager's machine on each (and on Map 0 / Kaltenbrunn).
func _other_maps() -> void:
	var rows: Array = [
		["map02", "res://gravelight/maps/map02_totenhafen/map02.tscn", "JES_BANK_GREET_M2_"],
		["map04a", "res://gravelight/maps/map04_fernflug/map04a.tscn", "RUH_BANK_GREET_M4A_"],
		["map04b", "res://gravelight/maps/map04_fernflug/map04b.tscn", "RUH_BANK_GREET_M4B_"],
		["map04c", "res://gravelight/maps/map04_fernflug/map04c.tscn", "PRU_BANK_GREET_M4C_"],
		["map04d", "res://gravelight/maps/map04_fernflug/map04d.tscn", "OPR_BANK_GREET_M4D_"],
	]
	for row: Array in rows:
		var tag: String = str(row[0])
		_tel_lines.clear()
		await _load(str(row[1]))
		var b: BankBranch = _branch()
		_check(b != null and b.counter != null and (b.teller != null or b.construct), "%s: the branch, its teller or window, its counter" % tag)
		if b == null:
			continue
		var h: Player = _root().player
		var front: Vector3 = b.counter.global_position + b.global_basis.z * 0.5
		var nav: RID = h.get_world_3d().navigation_map
		var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, _root().spawn_transform(1).origin, front, true, 0xFFFFFFFF)
		_check(not path.is_empty() and path[path.size() - 1].distance_to(front) < 0.8, "%s: the navmesh reaches the counter (%d points, ends %s, counter %s)" % [tag, path.size(),
			str(path[path.size() - 1].snapped(Vector3.ONE * 0.1)) if not path.is_empty() else "-", str(front.snapped(Vector3.ONE * 0.1))])
		h.global_position = front + b.global_basis.z * 0.4
		h.velocity = Vector3.ZERO
		await _until(func() -> bool: return _tel_lines.size() > 0, 5.0)
		_check(_tel_lines.size() > 0 and _tel_lines[0].begins_with(str(row[2])), "%s: the greeting (%s)" % [tag, _tel_lines[0] if _tel_lines.size() > 0 else "-"])
		_check(b.counter.get_prompt(h).begins_with("Bank:"), "%s: the counter's prompt \"%s\"" % [tag, b.counter.get_prompt(h)])
		Economy.grant_raw(1, 3000)
		var p0: int = Economy.get_scrip(1)
		var bal: int = BankAccount.balance()
		b.counter.interact(h)
		await _secs(0.3)
		var card: BankCard = b.counter.card
		_check(card != null, "%s: the card opens" % tag)
		if card != null:
			_check(card.move("deposit") == 1000, "%s: DEPOSIT 1000" % tag)
			_check(card.move("withdraw_all") >= 1000 + bal and BankAccount.balance() == 0, "%s: WITHDRAW ALL" % tag)
			card.close()
			await _secs(0.2)
		_check(Economy.get_scrip(1) >= p0, "%s: the Scrip came back" % tag)
		# Ledger Lager's machine
		var lm: PerkMachine = null
		for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
			if n is PerkMachine and (n as PerkMachine).perk_id == &"ledger_lager":
				lm = n as PerkMachine
		_check(lm != null, "%s: Ledger Lager's machine is there" % tag)
		if lm != null:
			var mf: Vector3 = lm.global_position - lm.global_basis.z * 1.6
			var mp: PackedVector3Array = NavigationServer3D.map_get_path(nav, _root().spawn_transform(1).origin, mf, true, 0xFFFFFFFF)
			_check(not mp.is_empty() and mp[mp.size() - 1].distance_to(mf) < 0.8, "%s: the navmesh reaches the machine (ends %s, front %s)" % [tag, str(mp[mp.size() - 1].snapped(Vector3.ONE * 0.1)) if not mp.is_empty() else "-", str(mf.snapped(Vector3.ONE * 0.1))])
