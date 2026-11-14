extends Node
## T-245 headless smoke: a map companion gets tonics and wonder weapons (the owner: "MAKE TRUDI BE ABLE TO GET PERKS,
## ALLOW THEM TO ALSO HAVE WONDER WEAPONS, THAT GOES FOR ANY OTHER BOTS LIKE HER"). Silent, solo, a god-mode human,
## Map 0 with Trudi (joined unarmed). Round 4, the power on, every door open, the human beside the nearest machine.
##   A. mid-round and calm, she drinks a tonic from her OWN Scrip (BotEconomy.companion_tonic_now);
##   B. Talk sends her for a tonic on the human's Scrip (tonic_offer / choose_tonic, Jakub's T-127 errand);
##   C. her damage_taken follows her tonics (0.6, 1.0 with Ironhide Stout), and a down takes them all (co-op rule);
##   D. the human hands her the Ashlight (a wonder weapon: refuses_classes is empty), she keeps it beside a gun she
##      already had, fires real bolts (Projectile, by her pid) and kills with it;
##   E. the squad panel shows her own Scrip.
## Prints "[t245] ..." and "[t245] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_companion_perks.tscn

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const TIMEOUT: float = 900.0

var _map: MapRoot
var _fails: PackedStringArray = []
var _t: float = 0.0
var _hold_mid: bool = false     # phase A: a round on, nothing left alive near (calm), more still to come
var _hold_break: bool = false
var _bolts: int = 0
var _bolt_kills: int = 0
var _bought: Array = []         # [pid, perk]


func _ready() -> void:
	ProfileSave.path = "user://_qa_t245_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_t245_settings.cfg"
	GLSettings.values["classic_rules"] = false
	GameState.bot_count = 0
	Campaign.reset()
	GLBus.perk_bought.connect(func(pid: int, perk: StringName) -> void:
		_bought.append([pid, perk])
		_note("perk_bought: pid %d %s" % [pid, perk]))
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, w: StringName, by: int) -> void:
		if by == 10 and String(w).begins_with("ashlight"):
			_bolt_kills += 1)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Projectile and (n as Projectile).by_player == 10:
			_bolts += 1)
	_run.call_deferred()


func _note(msg: String) -> void:
	print("[t245] " + msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[t245] FAIL " + msg)


func _check(cond: bool, what: String) -> void:
	if cond:
		_note("ok   " + what)
	else:
		_fail(what)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[t245] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _physics_process(delta: float) -> void:
	_t += delta / maxf(0.01, Engine.time_scale)
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()
		set_physics_process(false)
		return
	if _map == null or not is_instance_valid(_map) or _map.director == null:
		return
	if _hold_mid:
		RoundManager.state = RoundManager.State.ROUND
		RoundManager.to_spawn = maxi(RoundManager.to_spawn, 40)
		_map.director.kill_all(true)
	elif _hold_break:
		RoundManager.state = RoundManager.State.BREAK
		RoundManager.break_left = 999.0
		_map.director.kill_all(true)


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


func _trudi() -> MapCompanion:
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		if c.id == "trudi":
			return c
	return null


func _bought_by(pid: int) -> Array:
	var out: Array = []
	for b: Array in _bought:
		if int(b[0]) == pid:
			out.append(b[1])
	return out


func _nearest_machine(from: Vector3, mc: MapCompanion) -> PerkMachine:
	var best: PerkMachine = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: PerkMachine = n as PerkMachine
		if pm == null or not pm.is_visible_in_tree() or not pm.is_powered():
			continue
		if mc.brain != null and not mc.brain.reachable(BotBrain._front_of(pm)):
			continue
		var d: float = pm.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = pm
	return best


func _run() -> void:
	GameState.character_id = &"dutch"
	GameState.god_mode = true
	_map = (load(MAP) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _map.player != null and _map.player.is_inside_tree(), 30.0)
	await _secs(2.0)
	GameState.god_mode = true
	var h: Player = _map.player
	h.set_process_unhandled_input(false)
	_map.director.kill_all(true)
	var mc: MapCompanion = _trudi()
	_check(mc != null, "Trudi is on Map 0")
	if mc == null:
		_finish()
		return
	while mc.player == null and RoundManager.current_round < 10:
		RoundManager.advance_round()
	await _secs(0.5)
	RoundManager.debug_set_round(4)
	_hold_break = true
	if not GameState.power_on:
		GameState.power_on = true
		GameState.set_flag(&"power_on", true)
		GLBus.power_activated.emit()
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if n is BuyDoor and not (n as BuyDoor).is_open:
			(n as BuyDoor).open(1)
	await _secs(1.0)
	_check(mc.player != null, "Trudi appeared")
	if mc.player == null:
		_finish()
		return
	# she joins unarmed (NOT YET): the wonder weapon comes later
	h.global_position = mc.player.global_position + Vector3(1.2, 0.2, 0.0)
	h.velocity = Vector3.ZERO
	await _secs(0.3)
	mc.choose(h, false)
	await _secs(0.5)
	_check(mc.state == MapCompanion.State.JOINED, "Trudi joined (unarmed)")
	var pid: int = mc.player.player_id
	_check(is_equal_approx(mc.player.bot_damage_mult, 0.6), "no tonics: damage_taken 0.6 (%.2f)" % mc.player.bot_damage_mult)
	# a gun of her own (as from a wall or the crate) arms her through _sync_armed
	mc.player.weapons.give_weapon(&"kar98k")
	await _secs(0.3)
	_check(bool(mc.brain.options.get("armed", false)), "a gun she got on her own arms her (brain armed)")
	# the human beside the nearest powered machine she can reach, Trudi with him
	var pm: PerkMachine = _nearest_machine(h.global_position, mc)
	_check(pm != null, "a powered perk machine she can reach")
	if pm == null:
		_finish()
		return
	var stand: Vector3 = BotBrain._front_of(pm)
	var nav: RID = _map.get_world_3d().navigation_map
	var at: Vector3 = NavigationServer3D.map_get_closest_point(nav, stand + (stand - pm.global_position).normalized() * 3.0)
	h.global_position = at + Vector3(0, 0.1, 0)
	h.velocity = Vector3.ZERO
	mc.player.global_position = NavigationServer3D.map_get_closest_point(nav, at + Vector3(1.5, 0, 0)) + Vector3(0, 0.1, 0)
	mc.player.velocity = Vector3.ZERO
	_note("machine %s at %s; the human at %s" % [pm.perk_id, str(pm.global_position.snapped(Vector3.ONE * 0.1)), str(at.snapped(Vector3.ONE * 0.1))])
	Engine.time_scale = 3.0
	# ---- A: mid-round, calm, her own Scrip
	Economy.grant_raw(pid, 9000)
	_hold_break = false
	_hold_mid = true
	await _secs(1.0)
	_check(not mc.brain.in_break(), "A: a round is on (not a break)")
	var s0: int = Economy.get_scrip(pid)
	var drank: bool = await _until(func() -> bool: return not PerkManager.owned(pid).is_empty(), 90.0)
	_note("A: Trudi owns %s, Scrip %d -> %d, action %s task '%s'" % [str(PerkManager.owned(pid)), s0, Economy.get_scrip(pid), mc.brain.action, str(mc.brain.task.get("label", ""))])
	_check(drank, "A: mid-round and calm she drinks a tonic")
	_check(Economy.get_scrip(pid) < s0, "A: paid from her own Scrip")
	_check(mc.events.has("tonic:%s" % (PerkManager.owned(pid)[0] if drank else "")), "A: the drink is noted (banner)")
	# ---- B: Talk sends her for one on the human's Scrip
	_hold_mid = false
	_hold_break = true
	Economy.grant_raw(pid, -Economy.get_scrip(pid))   # her pocket empty: only the human's Scrip can pay
	Economy.grant_raw(1, 20000)
	h.global_position = mc.player.global_position + Vector3(1.0, 0.1, 0.0)
	h.velocity = Vector3.ZERO
	await _secs(1.0)
	var t: Dictionary = mc.tonic_offer(h)
	_note("B: tonic_offer %s" % str(CompanionNet.wire(t)))
	_check(bool(t.get("ok", false)), "B: a tonic on offer on the human's Scrip")
	_check(mc.talk_prompt(h).contains("tonic"), "B: the prompt offers it (%s)" % mc.talk_prompt(h))
	if bool(t.get("ok", false)):
		var hs0: int = Economy.get_scrip(1)
		var n0: int = PerkManager.owned(pid).size()
		_check(mc.choose_tonic(h), "B: she sets off")
		var got: bool = await _until(func() -> bool: return PerkManager.owned(pid).size() > n0, 60.0)
		_check(got, "B: she drinks it")
		_check(Economy.get_scrip(1) == hs0 - int(t["price"]), "B: the human paid %d" % int(t["price"]))
	# ---- C: damage_taken by her tonics; a down takes them
	PerkManager.grant(pid, &"ironhide_stout")
	await _secs(0.2)
	_check(is_equal_approx(mc.player.bot_damage_mult, 1.0), "C: with Ironhide Stout she takes full damage (%.2f)" % mc.player.bot_damage_mult)
	_check(MapCompanion.damage_mult_for([&"second_wind"], MapCompanion.table()) == 0.6, "C: another tonic keeps 0.6")
	mc.player.take_hit(9999.0, null)
	await _secs(0.5)
	_check(mc.player.downed, "C: downed")
	_check(PerkManager.owned(pid).is_empty(), "C: a down takes her tonics (co-op rule)")
	_check(is_equal_approx(mc.player.bot_damage_mult, 0.6), "C: back to 0.6 without them")
	if Net.session != null:
		Net.session.coop_revive(pid, 1)
	await _until(func() -> bool: return not mc.player.downed, 5.0)
	_check(not mc.player.downed, "C: revived")
	# ---- D: the Ashlight from the human's hands
	h.weapons.give_weapon(&"ashlight")
	h.global_position = mc.player.global_position + Vector3(1.0, 0.1, 0.0)
	await _secs(0.5)
	var o: Dictionary = mc.gun_offer(h)
	_check(bool(o.get("ok", false)), "D: she takes a wonder weapon (%s)" % str(o.get("reason", "ok")))
	var before: int = mc.player.weapons.slots.size()
	mc._take_gun(h)
	await _secs(0.3)
	var ids: Array = []
	for w: WeaponInstance in mc.player.weapons.slots:
		ids.append(String(w.id))
	_note("D: her slots %s; the human's %s" % [str(ids), str(h.weapons.slots.map(func(w: WeaponInstance) -> String: return String(w.id)))])
	_check(ids.has("ashlight"), "D: she carries the Ashlight")
	_check(mc.player.weapons.current() != null and mc.player.weapons.current().id == &"ashlight", "D: in her hands")
	_check(h.weapons.find_weapon(&"kar98k") != null and mc.player.weapons.slots.size() == before, "D: her Kar98k went back to you in the swap")
	# let a round run at the start: she fights with it
	_hold_break = false
	h.global_position = _map.spawn_transform(1).origin
	h.velocity = Vector3.ZERO
	mc.player.global_position = h.global_position + Vector3(1.2, 0.1, 0.0)
	mc.player.velocity = Vector3.ZERO
	mc.player.weapons.current().refill()
	mc.player.hp = mc.player.max_hp
	RoundManager.debug_set_round(4)
	RoundManager.state = RoundManager.State.BREAK
	RoundManager.break_left = 1.0   # the next round starts on its own
	var fought: bool = await _until(func() -> bool:
		if mc.player.weapons.current() != null and mc.player.weapons.current().id == &"ashlight" and mc.player.weapons.current().mag + mc.player.weapons.current().reserve <= 2:
			mc.player.weapons.current().refill()
		mc.player.hp = mc.player.max_hp if not mc.player.downed else mc.player.hp
		return _bolts >= 3 and _bolt_kills >= 1, 300.0)
	_note("D: %d bolts fired by her, %d kills with the Ashlight, fire blocks %s" % [_bolts, _bolt_kills, str(mc.brain.aim.fire_blocks if mc.brain != null else {})])
	_check(fought, "D: she fires real Ashlight bolts and kills with them")
	# ---- E: the squad panel shows her own Scrip
	if Net.session != null:
		var rows: Array = CoopHud.squad_rows(Net.session, 1)
		var mine: Dictionary = {}
		for r: Dictionary in rows:
			if int(r["pid"]) == pid:
				mine = r
		_check(not mine.is_empty() and int(mine.get("scrip", -1)) == Economy.get_scrip(pid), "E: the squad panel shows her Scrip (%s)" % str(mine.get("scrip", "-")))
	_note("Trudi events: %s" % ",".join(mc.events))
	_finish()
