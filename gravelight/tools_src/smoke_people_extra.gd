extends Node
## T-143 headless smoke: the extra people. On Kaltenbrunn: the three people are there with a Talk card, the miners'
## lamp favour (accept, the lamp appears, take it, give it: Scrip and a map mark), the medic's bandages (two rounds as
## a revive point: a downed player beside him is got up), the switchboard operator's valve (the intel ping), the
## quartermaster's trade at Ammer (Scrip for an ammo refill or a grenade pack, once per round, broke). On Map 0: the
## deserter takes a gun and covers, the widow's lamp unbolts the kitchen back door for two rounds, the courier's Crate
## tip is bought once a round. Prints "[people-smoke] ..." and "[people-smoke] RESULT: PASS/FAIL"; exit code 0/1.
## godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_people_extra.tscn [-- --only=map01]

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"
const MAP1: String = "res://gravelight/maps/map01_kaltenbrunn/map01.tscn"
const TIMEOUT: float = 600.0

var _map: Node3D
var _fails: PackedStringArray = []
var _t: float = 0.0
var _only: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
	ProfileSave.path = "user://_qa_people_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_people_settings.cfg"
	GameState.bot_count = 1
	Campaign.reset()
	GLVO.always_pass_chance = true
	_run.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _t > TIMEOUT:
		_fail("timeout")
		_finish()


func _note(msg: String) -> void:
	print("[people-smoke] " + msg)


func _fail(msg: String) -> void:
	_fails.append(msg)
	print("[people-smoke] FAIL " + msg)


func _check(cond: bool, what: String) -> void:
	if cond:
		_note("ok   " + what)
	else:
		_fail(what)


func _finish() -> void:
	print("[people-smoke] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	get_tree().quit(0 if _fails.is_empty() else 1)


func _secs(s: float) -> void:
	var end: float = _t + s
	while _t < end:
		await get_tree().physics_frame


func _root() -> MapRoot:
	return _map as MapRoot


func _human() -> Player:
	return _root().player


func _person(pid: String) -> ExtraPerson:
	for n: Node in get_tree().get_nodes_in_group(&"extra_people"):
		if (n as ExtraPerson).id == pid:
			return n as ExtraPerson
	return null


func _ids() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group(&"extra_people"):
		out.append((n as ExtraPerson).id)
	out.sort()
	return out


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
	while _root().player == null or not _root().player.is_inside_tree():
		await get_tree().process_frame
	await _secs(1.0)
	GameState.god_mode = true
	_human().set_process_unhandled_input(false)


## Talk, then the card's option on `action`.
func _talk_choose(p: ExtraPerson, action: StringName) -> bool:
	p.on_talk(_human())
	await get_tree().process_frame
	var card: PersonCard = null
	for c: Node in _map.get_children():
		if c is PersonCard:
			card = c as PersonCard
	if card == null:
		return false
	var ok: bool = card.choose(action)
	await get_tree().process_frame
	return ok


func _fetch_and_give(p: ExtraPerson) -> void:
	_check(p != null, "the person is there")
	if p == null:
		return
	_check(p.talk != null and p.talk.can_interact(_human()), "%s: a Talk prompt (%s)" % [p.id, p.talk.get_prompt(_human())])
	_check(p.bodies.size() == (p.cfg["bodies"] as Array).size(), "%s: %d bodies" % [p.id, p.bodies.size()])
	_check(await _talk_choose(p, &"interact"), "%s: the card's first option (I will do it)" % p.id)
	_check(p.favour == ExtraPerson.Favour.ASKED and p.item != null and p.item.shown, "%s: asked, the %s is out" % [p.id, p.cfg["favour"]["item_name"]])
	_check(p.item.get_prompt(_human()) != "", "%s: the item has a prompt (%s)" % [p.id, p.item.get_prompt(_human())])
	_human().global_position = p.item.global_position
	p.item.interact(_human())
	_check(p.favour == ExtraPerson.Favour.HAVE and not p.item.shown, "%s: the item is taken" % p.id)
	_check(await _talk_choose(p, &"interact"), "%s: give it" % p.id)
	_check(p.favour == ExtraPerson.Favour.DONE, "%s: done" % p.id)
	_check(p.events.has("done"), "%s: events %s" % [p.id, str(p.events)])


func _markers() -> int:
	var ms: MapState = MapState.current()
	return ms.markers().size() if ms != null else -1


func _run() -> void:
	if _only == "" or _only == "map01":
		await _kaltenbrunn()
	if _only == "" or _only == "map00":
		await _inn()
	_finish()


func _kaltenbrunn() -> void:
	await _load(MAP1)
	_note("-- Kaltenbrunn")
	var ids: Array = _ids()
	_check(ids == ["medic", "miners", "radio"], "the people on Kaltenbrunn: %s" % str(ids))
	_check(_markers() >= 3, "a minimap marker for each (%d markers)" % _markers())
	# the miners
	var mi: ExtraPerson = _person("miners")
	var m0: int = _markers()
	var s0: int = Economy.get_scrip(1)
	await _fetch_and_give(mi)
	_check(Economy.get_scrip(1) == s0 + 500, "the miners pay 500 Scrip (%d -> %d)" % [s0, Economy.get_scrip(1)])
	_check(_markers() == m0 + 1, "and chalk a short way on the map")
	# the medic: two rounds as a revive point
	var md: ExtraPerson = _person("medic")
	await _fetch_and_give(md)
	_check(md.rounds_left >= 2, "the medic serves for rounds (%d left)" % md.rounds_left)
	GameState.god_mode = false
	_human().global_position = md.spot() + Vector3(1.5, 0.3, 0)
	await _secs(0.5)
	_human().take_hit(9999.0, null)
	await _secs(0.5)
	_check(_human().downed, "the human is down beside the medic")
	var got_up: bool = false
	var end: float = _t + 12.0
	while _t < end and not got_up:
		await get_tree().physics_frame
		got_up = not _human().downed
	_check(got_up, "the medic got them up (events %s)" % str(md.events))
	GameState.god_mode = true
	for i: int in 3:
		GLBus.round_started.emit(RoundManager.current_round + 1 + i, false)
	_check(md.rounds_left == 0 and md.events.has("reward_ended"), "and it ends after the rounds")
	# the switchboard operator
	var rd: ExtraPerson = _person("radio")
	await _fetch_and_give(rd)
	var pinged: bool = false
	for e: String in rd.events:
		pinged = pinged or e.begins_with("reward:intel_ping")
	_check(pinged, "the operator sweeps the line (a free intel ping)")
	# Ammer's trade
	var am: MapCompanion = null
	for c: MapCompanion in MapCompanion.instances(get_tree()):
		if c.id == "ammer":
			am = c
	_check(am != null and am.cfg.has("trade") and am.talk_prompt(_human()) != "", "Ammer has a Talk prompt with a trade")
	Economy.grant(1, 5000)
	var sc: int = Economy.get_scrip(1)
	var out: String = am.trade(_human())
	_check(out == "ammo" or out == "grenades", "the trade pays out %s" % out)
	_check(Economy.get_scrip(1) == sc - 1500, "for 1500 Scrip")
	_check(am.trade(_human()) == "" and am.events.has("trade_once"), "once per round")
	RoundManager.current_round += 1
	Economy.spend(1, &"smoke", Economy.get_scrip(1))
	_check(am.trade(_human()) == "" and am.events.has("trade_broke"), "short of Scrip, the book does not balance")
	RoundManager.current_round -= 1


func _inn() -> void:
	await _load(MAP0)
	_note("-- Crossroads Inn")
	var ids: Array = _ids()
	_check(ids == ["courier", "deserter", "widow"], "the people at the inn: %s" % str(ids))
	# the deserter takes a gun and covers
	var de: ExtraPerson = _person("deserter")
	_human().weapons.give_weapon(&"kar98k")
	_check(bool(de.gun_offer(_human()).get("ok", false)), "the deserter may be handed the gun (%s)" % str(de.gun_offer(_human()).get("reason", "")))
	_check(await _talk_choose(de, &"interact"), "give him the gun")
	_check(de.favour == ExtraPerson.Favour.DONE and de.rounds_left >= 1 and de.events.has("reward:cover"), "he covers the stable door (%s)" % str(de.events))
	# the widow: the kitchen back door is free for two rounds
	var wi: ExtraPerson = _person("widow")
	var door: BuyDoor = null
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		if (n as BuyDoor).door_id == &"door_stable":
			door = n as BuyDoor
	var cost0: int = door.cost
	await _fetch_and_give(wi)
	_check(door.cost == 0 and wi.rounds_left >= 2, "the side door is unbolted (cost %d -> %d, %d rounds)" % [cost0, door.cost, wi.rounds_left])
	for i: int in 4:
		GLBus.round_started.emit(RoundManager.current_round + 1 + i, false)
	_check(door.cost == cost0, "and bolted again after two rounds (cost %d)" % door.cost)
	# the courier's tip
	var co: ExtraPerson = _person("courier")
	Economy.grant(1, 1000)
	var m0: int = _markers()
	var sc: int = Economy.get_scrip(1)
	co.buy_tip(_human())
	_check(co.events.has("tip") and Economy.get_scrip(1) == sc - 200 and _markers() == m0 + 1, "the tip: 200 Scrip, the Crate marked on the map")
	co.buy_tip(_human())
	_check(Economy.get_scrip(1) == sc - 200, "one tip a round")
