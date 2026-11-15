extends Node
## Headless smoke for Jakub Ostrowski, the prisoner companion (Update 02 section 6.2, DECISIONS T-051). Silent,
## solo, a god-mode human. Three cases:
##   GIVE (as Wren, Door 5 bought at the start): rounds 1-4 with Jakub in his cage (no player, no scaling, no
##     zombie goes for him); round 5's breakout (the zombie through the coal window bursts the hinge, his Polish
##     shout, the coal-shovel kill, he steps out and waits); "Talk to Jakub" -> GIVE HIM A GUN (the human's
##     Kar98k goes to him, the profile flag is saved, Wren's scene); he fights beside the human (kills, shots);
##     he is downed (his own 60 s clock) and the human revives him; rounds 6-10 with him, the Cousins Round on
##     round 10 (Homage Bosses On) with Jakub still on his feet, his line about the song, then rounds 11 and 12.
##     The round size never counts him; he shops with his own Scrip between rounds (T-177).
##   NOT YET (as Dutch, Door 5 shut): the breakout comes anyway, he waits in the shut cellar and calls out;
##     Door 5 opens, NOT YET: he follows with the coal shovel; a wall-buy with him beside it sells him the
##     Gewehr 43; an ammo box refills him from the human's Scrip at half price; the power on, "Talk to Jakub" sends
##     him for a tonic (T-127): he walks to a cellar machine and drinks it on the human's Scrip; then he is downed
##     (the tonic is lost) and nobody
##     comes: he bleeds out after 60 s, is out cold for the rest of the match and never respawns.
##   CARRY: the campaign payload from that map carries him to Kaltenbrunn: he arrives with the squad, wounded
##     ("Not yet. Not tonight."), and the Maintenance Stairs cost 500 less while he is with you.
## Prints "[jakub-smoke] ..." lines and "[jakub-smoke] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_jakub.tscn [-- --case=give|notyet|carry]

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 2400.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _rounds: Array[int] = []
var _jkills: int = 0
var _jmelee: int = 0
var _jboards: int = 0
var _revives_of_jakub: int = 0
var _first_seen: Dictionary = {}   # zombie instance id -> seconds
var _clock: float = 0.0
var _only: String = ""
var _snapshot: Dictionary = {}
var _max_players_seen: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--case="):
			_only = a.substr(7)
	ProfileSave.path = "user://_qa_jakub_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_jakub_settings.cfg"   # never the player's own settings file
	GLSettings.values["homage_bosses"] = true
	GameState.bot_count = 0
	Campaign.reset()
	GLVO.always_pass_chance = true
	GLBus.round_started.connect(func(r: int, _s: bool) -> void:
		_rounds.append(r)
		_max_players_seen = maxi(_max_players_seen, RoundManager.players)
		print("[jakub-smoke] round %d at t=%.0fs (round size counts %d player(s), %d zombies)" % [r, _t, RoundManager.players, RoundManager.round_total]))
	GLBus.enemy_killed.connect(func(_e: StringName, _l: StringName, w: StringName, by: int) -> void:
		if by == JakubCompanion.pid():
			_jkills += 1
			if w == &"coal_shovel":
				_jmelee += 1)
	GLBus.board_repaired.connect(func(_w: StringName, by: int) -> void:
		if by == JakubCompanion.pid():
			_jboards += 1)
	GLBus.player_revived.connect(func(p: int, by: int) -> void:
		if p == JakubCompanion.pid():
			_revives_of_jakub += 1
			print("[jakub-smoke] Jakub revived by P%d at t=%.0fs" % [by, _t]))
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _physics_process(delta: float) -> void:
	_clock += delta


func _note(msg: String) -> void:
	print("[jakub-smoke] ", msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[jakub-smoke] FAIL: ", msg)


func _check(cond: bool, what: String) -> void:
	print("[jakub-smoke] %-86s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)


func _finish() -> void:
	Engine.time_scale = 1.0
	print("[jakub-smoke] RESULT: %s%s" % ["PASS" if _fails.is_empty() else "FAIL", "" if _fails.is_empty() else " (%d: %s)" % [_fails.size(), "; ".join(_fails)]])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
	set_process(false)


func _secs(s: float) -> void:
	var t0: float = _clock
	while _clock - t0 < s:
		await get_tree().physics_frame


func _until(pred: Callable, seconds: float, each: Callable = Callable()) -> bool:
	var t0: float = _clock
	while _clock - t0 < seconds:
		if each.is_valid():
			each.call()
		if pred.call():
			return true
		await get_tree().physics_frame
	return pred.call()


func _root() -> MapRoot:
	return _map as MapRoot


func _jc() -> JakubCompanion:
	return JakubCompanion.instance(get_tree())


func _jakub() -> Player:
	var jc: JakubCompanion = _jc()
	return jc.player if jc != null else null


func _human() -> Player:
	return _root().player


func _load(scene: String, character: StringName) -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	GameState.character_id = character
	GameState.god_mode = true
	if scene == MAP0:
		# T-251: the inn's machines are dealt onto perk spots all over the map. This smoke's tonic errand has every
		# machine shut away until the Helvetia cellar's door opens: it pins a deal with none in the taproom or the Old
		# Cellar (the two zones open by then) and one in the Helvetia cellar
		PerkLayout.forced_seed = PerkLayout.seed_where(MAP0, func(zones: Dictionary, _deal: Dictionary) -> bool:
			var z: Array = zones.values()
			return z.has("CELLAR") and not z.has("TAPROOM") and not z.has("OLD_CELLAR"))
	_map = (load(scene) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await _until(func() -> bool: return _root().player != null and _root().player.is_inside_tree(), 20.0)
	await _secs(1.0)
	GameState.god_mode = true
	_human().set_process_unhandled_input(false)
	_first_seen.clear()


func _place(p: Vector3) -> void:
	var h: Player = _human()
	h.global_position = p
	h.velocity = Vector3.ZERO


func _door(id: StringName) -> BuyDoor:
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d != null and d.door_id == id:
			return d
	return null


## Kills the horde: everything except Jakub's breakout zombie, Homage bosses and (fight mode) zombies younger
## than `grace` seconds within `near` m of Jakub, so he gets to fight.
func _cull(grace: float = 0.0, near: float = 0.0) -> void:
	# no relief squad in this check: a patrol on the map shoots Jakub's breakout zombie and the round's horde before
	# he reaches them (the shovel kill and the song line then never come; the failures of 2026-11-15 each had one)
	var rs: ReliefSquad = ReliefSquad.instance(get_tree())
	if rs != null:
		rs.last_round = RoundManager.current_round
	var jc: JakubCompanion = _jc()
	var jp: Player = _jakub()
	for z: Zombie in _root().director.active_zombies():
		if z is HomageBoss or (jc != null and z == jc.breakout_zombie):
			continue
		var id: int = z.get_instance_id()
		if not _first_seen.has(id):
			_first_seen[id] = _clock
		var age: float = _clock - float(_first_seen[id])
		var close: bool = jp != null and z.global_position.distance_to(jp.global_position) < near
		if grace > 0.0 and close and age < grace:
			continue
		if grace > 0.0 and age < 1.5:
			continue
		if z.take_damage(z.hp + 1.0, &"head", &"m1911", 0, &"world"):
			_first_seen.erase(id)


## A teammate's hold on a downed Jakub: the human steps over and revives him.
func _revive_jakub() -> bool:
	var jp: Player = _jakub()
	if jp == null or not jp.downed or Net.session == null or not Net.session.coop.is_downed(jp.player_id):
		return false
	var h: Player = _human()
	_place(jp.global_position + Vector3(0.8, 0.0, 0.0))
	var rp: RevivePoint = jp.get_node_or_null("Revive") as RevivePoint
	if rp == null:
		return false
	rp.hold_changed(h, true)
	rp.interact(h)
	rp.hold_changed(h, false)
	return not jp.downed


func _run() -> void:
	if _only == "" or _only == "give":
		await _case_give()
	if _only == "" or _only == "notyet" or _only == "carry":
		await _case_not_yet()
	if _only == "" or _only == "carry":
		await _case_carry()
	_finish()


# ================================================================== GIVE

func _case_give() -> void:
	_note("---- case GIVE: as Wren, Door 5 bought, rounds 1 to 12")
	_rounds.clear()
	await _load(MAP0, &"wren")
	var jc: JakubCompanion = _jc()
	_check(jc != null and jc.state == JakubCompanion.State.CAGED, "Map 0: Jakub is in his cage")
	if jc == null:
		return
	var jp: Player = jc.player
	_check(not jp.is_in_group(&"players") and jp.is_companion and jp.remote_body != null and jp.remote_body.character == &"jakub",
		"he is a companion body (\"jakub\" outfit), no zombie target while caged")
	_check(GameState.player_ids.size() == 1 and GameState.player_ids[0] == 1 and GameState.bot_ids.is_empty(), "no player slot: player_ids [1], bot_ids []")
	var d5: BuyDoor = _door(&"door_old_cellar")
	_check(d5 != null, "Door 5 (the Old Cellar) exists")
	if d5 != null:
		d5.open(1)
	_place(Vector3(14, 0, 8))
	Engine.time_scale = 2.0
	var at5: bool = await _until(func() -> bool: return RoundManager.current_round >= 5, 700.0, _cull)
	_check(at5 and _rounds.has(1) and _rounds.has(4), "rounds 1-4 played (%s)" % str(_rounds))
	_check(jc.state == JakubCompanion.State.CAGED or jc.state == JakubCompanion.State.BREAKOUT, "still caged as round 5 starts")
	_check(RoundManager.players == 1, "round 5's size counts 1 player (Jakub is not one)")
	var out: bool = await _until(func() -> bool: return jc.state == JakubCompanion.State.WAITING, 120.0, _cull)
	_check(out and jc.events.has("breakout") and jc.events.has("burst"), "round 5: the breakout (events %s)" % str(jc.events))
	_check(jc.cage != null and jc.cage.is_open, "the cage hinge is burst")
	_check(jc.events.has("kill"), "he kills the zombie with the coal shovel")
	_check(int(GLVO.fired.get("JAK:BREAKOUT", 0)) + int(GLVO.fired.get("JAK:BREAKOUT_SELF", 0)) > 0, "his Polish shout (subtitled)")
	await _secs(2.0)
	var h: Player = _human()
	h.weapons.give_weapon(&"kar98k")
	_check(h.weapons.current() != null and h.weapons.current().id == &"kar98k", "the human holds a Kar98k (and the M1911)")
	_place(jp.global_position + Vector3(-0.6, 0.0, 1.2))
	_check(jc.talk_prompt(h).contains("talk to Jakub"), "prompt: \"%s\"" % jc.talk_prompt(h))
	jc.on_talk(h)   # headless: the choice goes to GIVE HIM A GUN when he'd take it
	await _secs(0.5)
	_check(jc.state == JakubCompanion.State.JOINED, "GIVE HIM A GUN: he joins")
	_check(jp.weapons.current() != null and jp.weapons.current().id == &"kar98k", "he has the Kar98k")
	_check(h.weapons.find_weapon_base(&"kar98k") == null and h.weapons.slots.size() == 1, "and the human lost it")
	_check(jc.brain != null and bool(jc.brain.options.get("armed", false)) and jc.brain.options.get("escort_pid") == 1, "armed brain, escorting P1")
	_check(str(ProfileSave.profile.get("companion_jakub", "")) == "joined" and ProfileSave.has_intel("INT_JAK_01"), "profile flag companion_jakub = joined, his letter in the Archive")
	var saved: String = FileAccess.get_file_as_string(ProfileSave.path)
	_check(saved.contains("\"companion_jakub\": \"joined\""), "and saved to the profile file")
	_check(jc.events.has("wren_scene"), "Wren is in the match: their quiet scene")
	_check(jp.is_in_group(&"players") and not GameState.player_ids.has(jp.player_id) and not GameState.bot_ids.has(jp.player_id),
		"a zombie target now, still no player slot")
	_check(bool(jc.brain.options.get("perks", false)) and bool(jc.brain.options.get("shopping", false)) and not bool(jc.brain.options.get("kit", true)) 		and not bool(jc.brain.options.get("bonus_perk", true)), "T-177: he shops with his own Scrip (no spawn kit, no bonus perk)")
	# he fights beside the human
	var shots0: int = jc.brain.shots
	var fought: bool = await _until(func() -> bool: return _jkills >= 2 and jc.brain != null and jc.brain.shots > shots0, 200.0,
		func() -> void:
			_cull(14.0, 20.0)
			if jp.downed and Net.session.coop.bleed_left(jp.player_id) < 50.0:
				_revive_jakub())
	_check(fought, "he fights: %d kills, %d shots" % [_jkills, jc.brain.shots if jc.brain != null else 0])
	# downed and revived (a down from the fight above started his clock already: up first, then the down we time)
	if jp.downed:
		_revive_jakub()
		await _secs(0.5)
	if not jp.downed:
		jp.take_hit(jp.hp + 1.0, null)
	await _secs(0.3)
	_check(jp.downed and Net.session.coop.is_downed(jp.player_id), "Jakub is downed")
	_check(absf(Net.session.coop.bleed_left(jp.player_id) - 60.0) < 1.5, "his own clock: %.1f s to bleed out" % Net.session.coop.bleed_left(jp.player_id))
	_check(GameState.phase == GameState.Phase.PLAYING, "the match goes on")
	await _secs(2.0)
	var rv: bool = _revive_jakub()
	await _secs(0.5)
	_check(rv and not jp.downed and Net.session.coop.is_alive(jp.player_id), "the human revives him")
	_place(Vector3(14, 0, 8))
	# on to round 10 with him
	var at10: bool = await _until(func() -> bool: return RoundManager.current_round >= 10 and _root().director.cousins != null \
			and _root().director.cousins.phase == CousinsRound.Phase.ACTIVE, 1200.0,
		func() -> void:
			_cull(10.0, 16.0)
			if jp.downed and Net.session.coop.bleed_left(jp.player_id) < 40.0:
				_revive_jakub())
	_check(at10, "round 10: the Cousins Round, Jakub alongside")
	var cr: CousinsRound = _root().director.cousins
	await _until(func() -> bool: return cr == null or cr.boss("hammer") != null, 20.0, _cull)
	await _until(func() -> bool: return false, 30.0, func() -> void:
		_cull()
		if jp.downed and Net.session.coop.bleed_left(jp.player_id) < 40.0:
			_revive_jakub())
	_check(jc.state == JakubCompanion.State.JOINED, "Jakub survives into the Cousins Round (%s)" % jc.state_name())
	# a down at the Cousins' arrival holds the line until he's back up (JakubCompanion._later_say patience)
	await _until(func() -> bool: return int(GLVO.fired.get("JAK:COUSINS", 0)) > 0, 15.0, _cull)
	_check(int(GLVO.fired.get("JAK:COUSINS", 0)) > 0, "\"I know that song. Everyone in this valley knows that song.\"")
	if cr != null:
		cr.retreat()
	var at12: bool = await _until(func() -> bool: return RoundManager.current_round >= 12, 600.0, func() -> void:
		_cull()
		if jp.downed and Net.session.coop.bleed_left(jp.player_id) < 40.0:
			_revive_jakub())
	_check(at12 and _rounds.has(11) and _rounds.has(12), "rounds 11 and 12")
	_check(jc.state == JakubCompanion.State.JOINED, "Jakub is still with the squad at round 12")
	_check(_max_players_seen == 1, "every round's size counted 1 player")
	_check(_revives_of_jakub >= 1, "revived %d time(s)" % _revives_of_jakub)
	Engine.time_scale = 1.0


# ================================================================== NOT YET

func _case_not_yet() -> void:
	_note("---- case NOT YET: as Dutch, Door 5 shut at the breakout")
	_rounds.clear()
	_jkills = 0
	_jmelee = 0
	await _load(MAP0, &"dutch")
	var jc: JakubCompanion = _jc()
	if jc == null:
		_fail("no companion on Map 0")
		return
	var jp: Player = jc.player
	_place(Vector3(14, 0, 8))
	RoundManager.debug_set_round(5)
	Engine.time_scale = 2.0
	var out: bool = await _until(func() -> bool: return jc.state == JakubCompanion.State.WAITING, 150.0, _cull)
	var d5: BuyDoor = _door(&"door_old_cellar")
	_check(out and d5 != null and not d5.is_open, "round 5 with Door 5 shut: he breaks out anyway and waits in the cellar")
	var called: bool = await _until(func() -> bool: return int(GLVO.fired.get("JAK:CALL", 0)) > 0, 40.0, _cull)
	_check(called, "he calls out from the shut cellar (positional, subtitled)")
	d5.open(1)
	var h: Player = _human()
	_place(jp.global_position + Vector3(-0.6, 0.0, 1.2))
	jc.choose(h, false)
	await _secs(0.5)
	_check(jc.state == JakubCompanion.State.JOINED and jp.weapons.slots.is_empty() and jp.weapons.melee_id == &"coal_shovel",
		"NOT YET: he follows with the coal shovel")
	_check(jc.brain != null and not jc.brain.armed(), "an unarmed brain")
	# the shovel: zombies come; he swings at what reaches him (or the human)
	var swung: bool = await _until(func() -> bool: return _jmelee >= 1 or (jc.brain != null and jc.brain.aim.melee_cd > 0.0), 160.0,
		func() -> void:
			_cull(25.0, 12.0)
			if jp.downed:
				_revive_jakub())
	_check(swung, "he fights with the shovel (%d shovel kills)" % _jmelee)
	# a wall-buy with him beside it sells to him
	var wb: WallBuy = _map.find_child("WallBuy_gewehr43", true, false) as WallBuy
	_check(wb != null, "the Old Cellar's Gewehr 43 wall-buy")
	if wb != null:
		var front: Vector3 = wb.global_position - wb.global_basis.z * 1.0
		front.y = -3.2
		_place(front)
		if jp.downed:
			_revive_jakub()
			_place(front)
		jp.global_position = front - wb.global_basis.z * 1.6
		Economy.grant(1, 3000)
		await _secs(0.2)
		jp.global_position = front - wb.global_basis.z * 1.6
		var prompt: String = wb.get_prompt(h)
		_check(prompt.contains("for Jakub"), "wall-buy prompt: \"%s\"" % prompt)
		var s0: int = Economy.get_scrip(1)
		wb.interact(h)
		await _secs(0.3)
		_check(jp.weapons.current() != null and jp.weapons.current().id == &"gewehr43", "he has the Gewehr 43 now")
		_check(s0 - Economy.get_scrip(1) == wb.price(), "at the normal price (%d)" % wb.price())
		_check(h.weapons.find_weapon_base(&"gewehr43") == null, "the human didn't get one")
	# an ammo box at half price from the human's Scrip
	var box: AmmoBox = null
	for n: Node in get_tree().get_nodes_in_group(&"ammo_boxes"):
		box = n as AmmoBox
	var w: WeaponInstance = jp.weapons.current()
	if box != null and w != null:
		w.reserve = 0
		var full: int = AmmoBox.price_for(w.data, w.upgraded, AmmoBox.cfg())
		var s1: int = Economy.get_scrip(1)
		var res: StringName = box.use_holder(jp.weapons, jp.player_id, 1, float(JakubCompanion.cfg()["brain"]["ammo_price_mult"]))
		_check(res == &"ok" and s1 - Economy.get_scrip(1) == int(ceil(full * 0.5)) and w.reserve > 0,
			"ammo box: %d Scrip from the human, half of %d" % [s1 - Economy.get_scrip(1), full])
	# T-127: "Talk to Jakub" -> GET YOURSELF A TONIC: he walks to the nearest cellar machine and drinks one, paid from
	# the human's Scrip at the normal price (the card's choice: choose_tonic)
	if jp.downed:
		_revive_jakub()
	if not GameState.power_on:
		GameState.power_on = true
		GameState.set_flag(&"power_on", true)
		GLBus.power_activated.emit()
	Economy.grant(1, 8000)
	var dc: BuyDoor = _door(&"door_cellar")   # the Helvetia cellar, where Map 0's machines stand
	_check(jc.tonic_offer(h).get("code", "") == "unreachable" or dc == null or dc.is_open, "no tonic on offer while the machines are shut away")
	if dc != null and not dc.is_open:
		dc.open(1)
	_place(jp.global_position + Vector3(-0.6, 0.0, 1.2))
	await _secs(0.5)
	var ton: Dictionary = jc.tonic_offer(h)
	_check(bool(ton.get("ok", false)), "a tonic is on offer for him (%s)" % str(ton.get("name", ton.get("code", "?"))))
	_check(jc.talk_prompt(h).contains("tonic"), "the talk prompt offers it: \"%s\"" % jc.talk_prompt(h))
	if bool(ton.get("ok", false)):
		var want: StringName = ton["perk"] as StringName
		var paid: Array[int] = [0]   # what the purchase itself cost (kill rewards land in the same window: no Scrip delta)
		var on_buy: Callable = func(pl: int, _item: StringName, cost: int) -> void:
			if pl == 1:
				paid[0] += cost
		GLBus.purchase_made.connect(on_buy)
		_check(jc.choose_tonic(h), "he is sent for the %s" % str(ton["name"]))
		var drank: bool = await _until(func() -> bool: return PerkManager.has_perk(jp.player_id, want), 60.0,
			func() -> void:
				_cull(25.0, 12.0)
				if jp.downed:
					_revive_jakub())
		_check(drank, "he walks to the machine and drinks it (events %s)" % str(jc.events.slice(-4)))
		GLBus.purchase_made.disconnect(on_buy)
		_check(paid[0] == PerkManager.price(want), "paid from the human's Scrip at the normal price (%d)" % paid[0])
		_check(jc.events.has("tonic:%s" % want), "his tonic event")
		_check(not jc.tonic_offer(h).has("machine") or jc.tonic_offer(h).get("perk") != want, "never the same tonic twice")
	# downed and left: he bleeds out after 60 s and stays out cold
	_place(Vector3(14, 0, 8))
	if not jp.downed:
		jp.take_hit(jp.hp + 1.0, null)
	await _secs(0.2)
	_check(PerkManager.owned(jp.player_id).is_empty(), "downed: his tonic is lost, like anyone's (T-127)")
	var t0: float = _clock
	Engine.time_scale = 4.0
	var bled: bool = await _until(func() -> bool: return jc.state == JakubCompanion.State.FALLEN, 80.0, _cull)
	var took: float = _clock - t0
	Engine.time_scale = 2.0
	_check(bled and took > 58.0 and took < 63.0, "nobody comes: he bleeds out after %.1f s" % took)
	_check(not jp.is_in_group(&"players") and jc.brain == null, "out cold: out of the fight, his brain gone")
	_check(GameState.phase == GameState.Phase.PLAYING, "the match goes on without him")
	var r0: int = RoundManager.current_round
	await _until(func() -> bool: return RoundManager.current_round > r0, 200.0, _cull)
	await _secs(1.0)
	_check(jc.state == JakubCompanion.State.FALLEN and jp.spectating, "a new round: he does not respawn")
	_snapshot = JakubCompanion.snapshot_of(_map)
	var plan: Dictionary = JakubCompanion.restore_plan(_snapshot)
	_check(str(_snapshot.get("state", "")) == "fallen" and bool(plan.get("wounded", false)) and not bool(plan.get("armed", true)),
		"the campaign payload: fallen -> next map wounded, unarmed")
	Engine.time_scale = 1.0


# ================================================================== CARRY

func _case_carry() -> void:
	_note("---- case CARRY: on to Kaltenbrunn")
	if _snapshot.is_empty():
		_snapshot = {"state": "fallen", "armed": false, "inv": {}, "escort": 1, "wounded": true}
	var payload: Dictionary = Campaign.snapshot(_root(), &"map01_kaltenbrunn", "exfil_m0")
	payload["companion"] = _snapshot
	Campaign.active = true
	Campaign.carry = payload
	Campaign.prepare_state(payload)
	await _load(MAP1, &"dutch")
	var jc: JakubCompanion = _jc()
	_check(jc != null and jc.state == JakubCompanion.State.JOINED, "Kaltenbrunn: Jakub arrives with the squad")
	if jc == null:
		Campaign.reset()
		return
	_check(jc.wounded and jc.player.max_hp < 100.0, "wounded (max health %.0f)" % jc.player.max_hp)
	var said: bool = await _until(func() -> bool: return int(GLVO.fired.get("JAK:RETURN_WOUNDED", 0)) > 0, 12.0)
	_check(said, "\"Not yet. Not tonight.\"")
	var st: BuyDoor = _door(&"door_stairs")
	_check(st != null and st.cost == 1000, "the Maintenance Stairs open for 500 less with him (%d)" % (st.cost if st != null else -1))
	_check(not GameState.player_ids.has(jc.player.player_id) and RoundManager.players == 1, "still no player slot on the next map")
	Campaign.reset()
