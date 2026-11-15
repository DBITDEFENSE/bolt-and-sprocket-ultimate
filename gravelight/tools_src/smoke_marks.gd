extends Node
## Smoke test for the pause map's marks and what bots do with them (Update 04 section 3, DECISIONS T-069): Map 0,
## 3 bots, a god-mode human in the taproom, the cellar open and the power on.
##   1. BUY THIS on a perk for "Any bot": the best bot says it is short, waits, and buys it once it has the Scrip
##   2. a queued order it can't afford expires (queue_s shortened for the test) and the mark goes
##   3. a wall weapon marked "for me": a bot pays, carries it over, drops it at the player's feet; the player takes it
##   4. a door: refused unconfirmed, opened once confirmed
##   5. the Armorer's Bench for one bot (Checkered Grips): it walks there and fits it
##   6. an easter-egg note marked for any bot: the squad's egg API takes it; the status line says "Doing: ..."
##   7. Danger (a blackboard danger zone), Regroup (every bot comes), Defend (one bot holds ~4 m)
##   8. a revive interrupts an order and the order resumes ("Back to it.")
##   9. the ping key: a perk machine -> buy for any bot, the floor -> go here, double-tap -> danger, a mark -> removed
##  10. limits: 3 personal marks (the oldest goes), 1 order per bot (the newest replaces it)
##  11. the pause map: the MAP tab's PauseMapView, a click on a perk -> the radial -> the who-picker -> the mark; a
##      door -> "Open this door for 1,500?"; a right-click removes a mark
##   godot --headless --audio-driver Dummy --path . res://gravelight/tools_src/smoke_marks.tscn
##   (--clip: a chase camera on the working bot, for the clip of a bot buying a marked perk)
##   --map=map04b (T-162, UPDATE 10 s6 item 4): the same squad phases on any act's map (7 Danger / Regroup / Defend and 8
##   revive-and-resume; the inn's perk, wall-gun, door and pause-map phases need Map 0's props and are skipped there).
## Prints "[marks] ..." lines and RESULT PASS/FAIL (exit code 0/1).

const MAP: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _map: MapRoot
var _t: float = 0.0
var _fails: PackedStringArray = []
var _lines: PackedStringArray = []
var _clip: bool = false
var _only: String = ""
var _map_name: String = "map00"
var _cam: Camera3D = null
var _focus_pid: int = -1
var _done: bool = false
var _perk1: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a == "--clip":
			_clip = true
		elif a.begins_with("--only="):
			_only = a.substr(7)
		elif a.begins_with("--map="):
			_map_name = a.substr(6)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_marks_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GLSettings.path = "user://_qa_marks_settings.cfg"
	GLSettings.values["bot_ee_help"] = "ask"
	GLSettings.values["homage_bosses"] = false
	Campaign.reset()
	GameState.character_id = &"dutch"
	GameState.bot_count = 3
	GameState.bot_ai_mode = "off"
	GameState.god_mode = true
	var scene_path: String = MAP if _map_name == "map00" else NpcWallProbe.scene_for(_map_name)
	if _map_name == "map00":
		# T-251: the inn's machines are dealt onto perk spots all over the map; this smoke opens the cellar and the stable,
		# so it pins a deal with Marathon Malt, a 3000-Scrip tonic and a third machine behind those two doors
		PerkLayout.forced_seed = PerkLayout.seed_where(MAP, func(zones: Dictionary, _deal: Dictionary) -> bool:
			var near: Array = []
			for pid: String in zones.keys():
				if str(zones[pid]) in ["CELLAR", "STABLE"]:
					near.append(pid)
			return near.size() >= 3 and near.has("marathon_malt") and (near.has("trigger_tonic") or near.has("magpie_mead") or near.has("ledger_lager")))
	_map = (load(scene_path) as PackedScene).instantiate() as MapRoot
	get_tree().root.add_child.call_deferred(_map)
	get_tree().set_deferred("current_scene", _map)
	GLBus.vo_line_started.connect(func(id: StringName, _spk: StringName, text: String, _d: float) -> void:
		if String(id).contains("_SQ5_MARK_") or String(id).contains("_SQ4_EE_"):
			_lines.append(String(id))
			print("[marks] t=%.1f line %s: \"%s\"" % [_t, id, text]))
	_run.call_deferred()


func _check(cond: bool, what: String) -> bool:
	print("[marks] %-86s %s" % [what, "PASS" if cond else "FAIL"])
	if not cond:
		_fails.append(what)
	return cond


func _process(delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_t += delta
	_drive_camera(delta)


## Waits (physics frames) until cond() holds or `timeout` s pass; true when it held.
func _until(cond: Callable, timeout: float) -> bool:
	var t0: float = _t
	while _t - t0 < timeout:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
	return bool(cond.call())


func _wait(s: float) -> void:
	var t0: float = _t
	while _t - t0 < s:
		await get_tree().physics_frame


func _sq() -> BotSquad:
	return _map.squad


func _mm() -> MapMarks:
	return MapMarks.current()


func _set_scrip(pid: int, n: int) -> void:
	var have: int = Economy.get_scrip(pid)
	if have > n:
		Economy.spend(pid, &"qa", have - n)
	elif have < n:
		Economy.grant(pid, n - have)


func _node(path: String) -> Node:
	return _map.get_node_or_null(NodePath(path))


## T-251: does the machine stand in a zone that is open (the bots can walk to it)?
func _in_open_zone(pm: PerkMachine) -> bool:
	return GameState.is_zone_open(ZoneVolume.zone_at(get_tree(), pm.global_position + Vector3.UP * 0.3))


## A perk machine behind the doors this smoke opened that none of `pids` has (and none takes as a bonus), priced at
## least `min_price`.
func _free_perk(pids: Array, min_price: int) -> PerkMachine:
	var best: PerkMachine = null
	for n: Node in get_tree().get_nodes_in_group(&"perk_machines"):
		var pm: PerkMachine = n as PerkMachine
		if pm == null or pm.perk_id == _perk1 or PerkManager.price(pm.perk_id) < min_price or not _in_open_zone(pm):
			continue
		var free: bool = true
		for pid: Variant in pids:
			if PerkManager.has_perk(int(pid), pm.perk_id):
				free = false
		if free and (best == null or PerkManager.price(pm.perk_id) < PerkManager.price(best.perk_id)):
			best = pm
	if best == null:   # the bots' random kit perks took every pricey one: free the cheapest (setup, not under test)
		for n2: Node in get_tree().get_nodes_in_group(&"perk_machines"):
			var pm2: PerkMachine = n2 as PerkMachine
			if pm2 != null and pm2.perk_id != _perk1 and _in_open_zone(pm2) and PerkManager.price(pm2.perk_id) >= min_price and (best == null or PerkManager.price(pm2.perk_id) < PerkManager.price(best.perk_id)):
				best = pm2
		if best != null:
			for pid2: Variant in pids:
				if PerkManager.has_perk(int(pid2), best.perk_id):
					PerkManager.remove(int(pid2), best.perk_id)
	return best


func _brain(pid: int) -> BotBrain:
	return _sq().mark_orders.brain_of(pid)


func _phase(name: String) -> bool:
	print("[marks] ---- %s (t=%.0f)" % [name, _t])
	if _map_name != "map00" and not (name.begins_with("7") or name.begins_with("8")):
		return false   # (the other phases use the inn's own machines, guns, doors and pause map)
	return _only == "" or name.begins_with(_only)


func _run() -> void:
	var live: bool = await _until(func() -> bool:
		return _map.player != null and _map.player.is_inside_tree() and _map.squad != null and _map.squad.mark_orders != null and MapMarks.current() != null \
			and NavigationServer3D.map_get_iteration_id(_map.player.get_world_3d().navigation_map) > 0, 30.0)
	if not _check(live, "the match started with a squad, its mark orders and the map marks"):
		_finish()
		return
	await _wait(1.5)
	var sq: BotSquad = _sq()
	var mm: MapMarks = _mm()
	var human: Player = _map.player
	_check(mm.has_bots() and mm.bots().size() == 3, "MapMarks sees the 3 bots (%d)" % mm.bots().size())
	# the cellar open, the power on (the perks live down there)
	if _map_name == "map00":
		(_node("Gameplay/Door_Cellar") as BuyDoor).open(1)
		(_node("Gameplay/Door_Stable") as BuyDoor).open(1)
	GameState.power_on = true
	GLBus.power_activated.emit()
	RoundManager.break_left = 3.0
	if _clip:
		_start_clip()
	var bots: Array = GameState.bot_ids.duplicate()
	for pid: int in bots:
		_set_scrip(pid, 1000)
	var mcfg: Dictionary = BotAIData.table("marks")

	# ---- 1. a perk for any bot, short of Scrip first
	if _phase("1 perk"):
		var pm: PerkMachine = _free_perk(bots, 3000)
		_perk1 = pm.perk_id
		var r: Dictionary = mm.place({"kind": "buy", "pos": pm.global_position, "node": pm, "target": "any"})
		_check(bool(r["ok"]) and int(r["pid"]) > 0, "BUY THIS (%s) for any bot: taken by P%d (%s)" % [PerkManager.display_name(pm.perk_id), int(r["pid"]), r["reason"]])
		var pid: int = int(r["pid"])
		_focus_pid = pid
		var b: BotBrain = _brain(pid)
		var price1: int = PerkManager.price(pm.perk_id)
		_check(b != null and b.mark.active() and str(b.mark.order.get("state", "")) == "wait_scrip", "1,000 Scrip for a %s perk: it waits for the Scrip" % MarkTargets.money(price1))
		_check(mm.status_of(pid).contains("%s short" % MarkTargets.money(price1 - 1000)), "the status line: \"%s\"" % mm.status_of(pid))
		await _wait(2.0 if not _clip else 5.0)
		_check(not PerkManager.has_perk(pid, _perk1), "it didn't buy what it couldn't afford")
		_set_scrip(pid, price1 + 400)
		var got: bool = await _until(func() -> bool: return PerkManager.has_perk(pid, _perk1), 70.0)
		_check(got, "given the Scrip it walked down and bought it (%s)" % mm.status_of(pid))
		await _wait(0.5 if not _clip else 4.0)
		_check(not b.mark.active() and mm.mark(int(r["id"])).is_empty(), "the order and its mark are done")
		_check(b.mark.bought >= 1, "the bot's bought counter (%d)" % b.mark.bought)

	# ---- 2. the 60 s queue runs out (shortened)
	if _phase("2 queue"):
		var keep_q: float = float(mcfg.get("queue_s", 60.0))
		mcfg["queue_s"] = 6.0
		var pid2: int = int(bots[1])
		var pm2: PerkMachine = _free_perk([pid2], 0)
		_set_scrip(pid2, 100)
		var r2: Dictionary = mm.place({"kind": "buy", "pos": pm2.global_position, "node": pm2, "target": pid2})
		_check(bool(r2["ok"]) and int(r2["pid"]) == pid2, "BUY THIS (Packmule) for P%d by portrait" % pid2)
		var gone: bool = await _until(func() -> bool: return mm.mark(int(r2["id"])).is_empty(), 15.0)
		_check(gone and not _brain(pid2).mark.active(), "unaffordable for the whole queue time: the order expired and its mark went")
		_check(_brain(pid2).mark.gave_up == 1, "it gave up once (%d)" % _brain(pid2).mark.gave_up)
		mcfg["queue_s"] = keep_q

	# ---- 3. buy for teammate
	if _phase("3 for me"):
		var wb: WallBuy = _node("Gameplay/WallBuy_m1_garand") as WallBuy
		for pid: int in bots:
			_set_scrip(pid, 1500)
		var r3: Dictionary = mm.place({"kind": "buy", "pos": wb.global_position, "node": wb, "target": "any", "for_pid": human.player_id})
		var pid3: int = int(r3["pid"])
		_focus_pid = pid3
		_check(bool(r3["ok"]) and pid3 > 0, "M1 Garand marked for me: P%d buys it" % pid3)
		# the payment is a single drop of the gun's price; kills on the way add Scrip, so the balance alone can't tell
		var watch: Dictionary = {"prev": Economy.get_scrip(pid3), "paid": false}
		var paid: bool = await _until(func() -> bool:
			var now_s: int = Economy.get_scrip(pid3)
			if int(watch["prev"]) - now_s >= 600:
				watch["paid"] = true
			watch["prev"] = now_s
			return bool(watch["paid"]), 60.0)
		_check(paid, "the bot paid 600 of its own Scrip (%d left)" % Economy.get_scrip(pid3))
		_check(_sq().player_by_id(pid3).weapons.find_weapon_base(&"m1_garand") == null, "and the gun isn't in the bot's hands")
		var dropped: bool = await _until(func() -> bool:
			for n: Node in get_tree().get_nodes_in_group(&"weapon_parcels"):
				var wp: WeaponParcel = n as WeaponParcel
				if wp != null and not wp.carried and wp.global_position.distance_to(human.global_position) < 3.0:
					return true
			return false, 60.0)
		_check(dropped, "it brought it over and dropped it at the player's feet")
		var parcel: WeaponParcel = get_tree().get_first_node_in_group(&"weapon_parcels") as WeaponParcel
		if parcel != null:
			_check(parcel.can_interact(human) and parcel.get_prompt(human).contains("M1 Garand"), "the prompt: \"%s\"" % parcel.get_prompt(human))
			parcel.interact(human)
		_check(human.weapons.find_weapon_base(&"m1_garand") != null, "the player took the M1 Garand")

	# ---- 4. a door: confirm first
	if _phase("4 door"):
		var door: BuyDoor = _node("Gameplay/Door_Upstairs") as BuyDoor
		for pid: int in bots:
			_set_scrip(pid, 1200)
		var r4: Dictionary = mm.place({"kind": "buy", "pos": door.global_position, "node": door, "target": "any"})
		_check(not bool(r4["ok"]) and str(r4["reason"]).contains("Confirm"), "a door marked without the confirmation is refused (\"%s\")" % r4["reason"])
		_check(MarkTargets.door_question(door.cost) == "Open this door for 750?", "the question: \"%s\"" % MarkTargets.door_question(door.cost))
		var r4b: Dictionary = mm.place({"kind": "buy", "pos": door.global_position, "node": door, "target": "any", "confirmed": true})
		_check(bool(r4b["ok"]), "confirmed: P%d takes it" % int(r4b["pid"]))
		_focus_pid = int(r4b["pid"])
		var opened: bool = await _until(func() -> bool: return door.is_open, 60.0)
		_check(opened, "the bot opened the Upstairs door")

	# ---- 5. the Armorer's Bench
	if _phase("5 bench"):
		var bench: ArmorersBench = _node("Gameplay/ArmorersBench") as ArmorersBench
		var pid5: int = int(bots[2])
		_focus_pid = pid5
		_set_scrip(pid5, 1500)
		var r5: Dictionary = mm.place({"kind": "buy", "pos": bench.global_position, "node": bench, "target": pid5, "slot": "grip", "option": "checkered"})
		_check(bool(r5["ok"]), "the Armorer's Bench (Checkered Grips) for P%d: %s" % [pid5, r5.get("label", "")])
		var p5: Player = _sq().player_by_id(pid5)
		var fitted: bool = await _until(func() -> bool: return M1911Kit.has_option(M1911Kit.pistol_of(p5), "grip", "checkered"), 70.0)
		_check(fitted, "it walked to the bench and fitted Checkered Grips to its M1911 (%s)" % mm.status_of(pid5))
		# the bot's own pick
		_set_scrip(pid5, 800)
		var r5b: Dictionary = mm.place({"kind": "buy", "pos": bench.global_position, "node": bench, "target": pid5})
		_check(bool(r5b["ok"]) and str(_brain(pid5).mark.order.get("slot", "")) != "", "the bot's own pick at the bench: %s" % r5b.get("label", ""))
		mm.remove(int(r5b["id"]))

	# ---- 6. an easter-egg note
	if _phase("6 egg"):
		var note: Node = _map.find_child("NoteA", true, false)
		var r6: Dictionary = mm.place({"kind": "collect", "pos": (note as Node3D).global_position, "node": note, "target": "any"})
		_check(bool(r6["ok"]) and int(r6["pid"]) > 0, "Collect this (radio note I) for any bot: P%d" % int(r6["pid"]))
		var pid6: int = int(r6["pid"])
		_focus_pid = pid6
		_check(mm.status_of(pid6).begins_with("Doing: "), "the status line: \"%s\"" % mm.status_of(pid6))
		var took: bool = await _until(func() -> bool:
			var got: Variant = QuestManager.progress(&"map00_radio", &"s1_notes")
			return got is Array and (got as Array).has(&"note_a"), 90.0)
		_check(took, "the bot picked up the marked note")
		if _clip:
			await _wait(3.0)
		var off: bool = await _until(func() -> bool: return mm.mark(int(r6["id"])).is_empty(), 10.0)
		_check(off, "the egg mark went when the task ended")
		sq.ee_cancel()

	# ---- 7. danger, regroup, defend
	if _phase("7 squad"):
		var dpos: Vector3 = human.global_position + Vector3(4, 0, 0)
		var r7: Dictionary = mm.place({"kind": "danger", "pos": dpos})
		var zone: bool = false
		for z: Variant in sq.blackboard.danger_zones:
			if str((z as Dictionary).get("key", "")) == "mark:%d" % int(r7["id"]):
				zone = true
		_check(bool(r7["ok"]) and zone, "Danger: a 60 s danger zone on the squad blackboard")
		mm.remove(int(r7["id"]))
		var zone_after: bool = false
		for z2: Variant in sq.blackboard.danger_zones:
			if str((z2 as Dictionary).get("key", "")) == "mark:%d" % int(r7["id"]) and float((z2 as Dictionary)["until"]) > sq.time():
				zone_after = true
		_check(not zone_after, "removing the Danger mark lifts the zone")
		var rp: Vector3 = sq.brains[0].snap(human.global_position + Vector3(2, 0, -2))
		var r8: Dictionary = mm.place({"kind": "regroup", "pos": rp})
		_check(bool(r8["ok"]), "Regroup: %s" % r8["reason"])
		var came: bool = await _until(func() -> bool:
			for pid: int in bots:
				var p: Player = sq.player_by_id(pid)
				if p.global_position.distance_to(rp) > 4.0:
					return false
			return true, 45.0)
		_check(came, "every bot came to the regroup mark")
		var dp: Vector3 = sq.brains[0].snap(human.global_position + Vector3(-3, 0, -3))   # (into the room: the spawn is at the taproom's south end, T-076)
		var r9: Dictionary = mm.place({"kind": "defend", "pos": dp, "target": int(bots[0])})
		_check(bool(r9["ok"]) and mm.status_of(int(bots[0])).begins_with("Defending"), "Defend here: \"%s\"" % mm.status_of(int(bots[0])))
		var held: bool = await _until(func() -> bool: return sq.player_by_id(int(bots[0])).global_position.distance_to(dp) < 4.0, 30.0)
		_check(held, "the defender holds within 4 m")
		await _wait(3.0)
		_check(sq.player_by_id(int(bots[0])).global_position.distance_to(dp) < 4.5, "and stays there")
		mm.remove(int(r9["id"]))

	# ---- 8. a revive interrupts an order, which resumes
	if _phase("8 revive"):
		var down_pid: int = int(bots[1])
		var downed: Player = sq.player_by_id(down_pid)
		downed.take_hit(9999.0, null)
		var claimed: bool = await _until(func() -> bool: return sq.blackboard.claimer("revive:%d" % down_pid, sq.time()) != 0, 10.0)
		var rev: int = sq.blackboard.claimer("revive:%d" % down_pid, sq.time())
		_check(claimed and rev > 0, "a bot claimed the revive (P%d)" % rev)
		var gp: Vector3 = sq.brains[0].snap(human.global_position + Vector3(0, 0, -3))
		var r10: Dictionary = mm.place({"kind": "go", "pos": gp, "target": rev})
		_check(bool(r10["ok"]), "an order for the reviver while it revives")
		var up: bool = await _until(func() -> bool: return not downed.downed, 30.0)
		_check(up, "the revive came first and finished")
		var rb: BotBrain = _brain(rev)
		var res: bool = await _until(func() -> bool: return rb.mark.resumed >= 1, 15.0)
		_check(res, "then the order resumed (\"Back to it.\")")
		mm.remove(int(r10["id"]))

	# ---- 9. the ping key
	if _phase("9 ping"):
		var ping: MarkPing = mm.ping
		var kar: WallBuy = _node("Gameplay/WallBuy_kar98k") as WallBuy
		_look_at(human, kar.global_position + kar.global_basis * Vector3(0, 0, -2.5), kar.global_position)
		await _wait(0.3)
		var c: Dictionary = MarkTargets.classify(ping.look_hit().get("node"))
		_check(str(c.get("sub", "")) == "gun", "looking at the Kar98k chalk: classified as a wall weapon (%s)" % str(c.get("sub", "")))
		for pid: int in bots:
			_set_scrip(pid, 1500)
		var rp1: Dictionary = ping.ping()
		_check(bool(rp1.get("ok", false)) and int(rp1.get("pid", -1)) > 0, "ping on it: Buy this for any bot (P%d)" % int(rp1.get("pid", -1)))
		if bool(rp1.get("ok", false)):
			mm.remove(int(rp1["id"]))
		await _wait(0.6)
		_look_at(human, human.global_position + Vector3(0, 1.6, 0), human.global_position + Vector3(3, 0, 1))
		await _wait(0.3)
		ping._last_t = -100000   # the key's timing is real time; a fixed-fps run is faster than that
		var rp2: Dictionary = ping.ping()
		_check(bool(rp2.get("ok", false)) and str(mm.mark(int(rp2.get("id", -1))).get("kind", "")) == "go", "ping at the floor: Go here (yours)")
		await _wait(0.1)
		var rp3: Dictionary = ping.ping()
		_check(bool(rp3.get("ok", false)) and str(mm.mark(int(rp3.get("id", -1))).get("kind", "")) == "danger" and mm.mark(int(rp2.get("id", -1))).is_empty(),
			"double-tap: the mark became Danger")
		await _wait(0.8)
		ping._last_t = -100000
		var rp4: Dictionary = ping.ping()
		_check(bool(rp4.get("removed", false)) and mm.mark(int(rp3.get("id", -1))).is_empty(), "pinging the mark removes it")

	# ---- 10. limits
	if _phase("10 limits"):
		mm.clear()
		var ids: Array = []
		for i: int in 4:
			ids.append(int(mm.place({"kind": "go", "pos": human.global_position + Vector3(i * 2.0, 0, 0), "target": "me"})["id"]))
		_check(mm.personal(human.player_id).size() == 3 and mm.mark(int(ids[0])).is_empty(), "4 personal marks: 3 stay, the oldest went")
		var pid10: int = int(bots[2])
		var o1: Dictionary = mm.place({"kind": "go", "pos": human.global_position + Vector3(2, 0, 0), "target": pid10})
		var o2: Dictionary = mm.place({"kind": "defend", "pos": human.global_position + Vector3(-2, 0, 0), "target": pid10})
		_check(bool(o1["ok"]) and bool(o2["ok"]) and mm.mark(int(o1["id"])).is_empty() and str(_brain(pid10).mark.order.get("kind", "")) == "defend",
			"1 order per bot: the second replaced the first (and its mark)")
		mm.clear()

	# ---- 11. the pause map
	if _phase("11 pause map"):
		await _pause_map()

	_check(_only != "" or _lines.size() >= 4, "the bots spoke their mark lines (%d: %s)" % [_lines.size(), ", ".join(_lines.slice(0, 8))])
	_finish()


func _pause_map() -> void:
	var pmenu: PauseMenu = _map.pause_menu
	pmenu.toggle()
	await get_tree().process_frame
	await get_tree().process_frame
	var view: PauseMapView = pmenu.map_view() as PauseMapView
	_check(view != null and pmenu.tab_name() == "MAP", "the pause page opened on MAP with a PauseMapView")
	if view == null:
		pmenu.toggle()
		return
	_check(get_tree().paused, "solo: the game is frozen under the map")
	await get_tree().process_frame
	view.refresh()
	for i: int in 6:
		await get_tree().process_frame
	var pm: PerkMachine = _node("Gameplay/Perk_marathon_malt") as PerkMachine
	MapState.current().discover_all()
	view.set_floor(MapState.current().data.floor_at(pm.global_position + Vector3.UP * 0.2))
	view.canvas.center = Vector2(pm.global_position.x, pm.global_position.z)
	view.canvas.zoom = 12.0
	for i2: int in 6:
		await get_tree().process_frame
	var at: Vector2 = view.canvas.world_to_canvas(pm.global_position)
	var hit: Dictionary = view.canvas.icon_at(at, 16.0)
	_check(str(hit.get("kind", "")) == "perk", "the perk machine's icon is under its spot on the map (%s)" % str(hit.get("kind", "")))
	var tip: PackedStringArray = PauseMapView.tooltip_lines(hit, MapState.current(), MapMarks.current(), _map.player.player_id)
	_check(tip.size() >= 3 and tip[1].contains("2,000"), "hover: %s" % " | ".join(tip))
	view.click(at)
	_check(view.radial.visible and view.radial.ids().has("buy"), "click: the radial (%s)" % ", ".join(view.radial.ids()))
	view.radial.choose_id("buy")
	_check(view.picker_open(), "BUY THIS -> who is it for")
	view.pick_target("any")
	var placed: bool = false
	for m: Dictionary in MapMarks.current().marks():
		if str(m.get("kind", "")) == "buy" and bool(m.get("order", false)):
			placed = true
	_check(placed, "the mark: %s" % view.toast_text())
	var door: BuyDoor = _node("Gameplay/Door_Yard") as BuyDoor
	view.set_floor(MapState.current().data.floor_at(door.global_position + Vector3.UP * 0.2))
	view.canvas.center = Vector2(door.global_position.x, door.global_position.z)
	for i3: int in 6:
		await get_tree().process_frame
	var dat: Vector2 = view.canvas.world_to_canvas(door.global_position)
	view.click(dat)
	if view.radial.visible and view.radial.choose_id("buy"):
		view.pick_target("any")
		_check(view.dialog_text() == "Open this door for 1,250?", "a door asks: \"%s\"" % view.dialog_text())
		view.confirm_dialog(false)
	else:
		_check(false, "the door's radial (%s)" % ", ".join(view.radial.ids()))
	var empty_at: Vector2 = view.canvas.world_to_canvas(_map.player.global_position + Vector3(1.5, 0, 1.5))
	view.set_floor(MapState.current().local_floor())
	view.canvas.center = Vector2(_map.player.global_position.x, _map.player.global_position.z)
	for i4: int in 4:
		await get_tree().process_frame
	empty_at = view.canvas.world_to_canvas(_map.player.global_position + Vector3(1.5, 0, 1.5))
	view.click(empty_at)
	var ids: PackedStringArray = view.radial.ids()
	_check(ids.has("go") and ids.has("defend") and ids.has("danger") and ids.has("regroup") and ids.has("note"), "an empty spot: %s" % ", ".join(ids))
	view.radial.choose_id("go")
	view.pick_target("me")
	var mine: Array[Dictionary] = MapMarks.current().personal(_map.player.player_id)
	_check(mine.size() == 1, "Go here for me: a personal mark")
	for i5: int in 4:
		await get_tree().process_frame
	if not mine.is_empty():
		var mat: Vector2 = view.canvas.world_to_canvas(mine[0]["pos"] as Vector3)
		_check(view.remove_at(mat) and MapMarks.current().personal(_map.player.player_id).is_empty(), "right-click on it: removed")
	_check(not MapMarks.current().status_of(int(GameState.bot_ids[0])).is_empty(), "the order line: \"%s\"" % MapMarks.current().status_of(int(GameState.bot_ids[0])))
	pmenu.toggle()
	MapMarks.current().clear()


## Turns the human (body yaw, head pitch) to look from `eye_from`'s spot at `target`.
func _look_at(p: Player, stand: Vector3, target: Vector3) -> void:
	var s: Vector3 = _sq().brains[0].snap(stand)
	p.global_position = s
	p.velocity = Vector3.ZERO
	var eye: Vector3 = p.camera.global_position if p.camera != null else s + Vector3.UP * 1.6
	eye = Vector3(s.x, eye.y, s.z)
	var d: Vector3 = (target - eye).normalized()
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = asin(clampf(d.y, -1.0, 1.0))
	p.set("_pitch", p.head.rotation.x)   # the camera reads the player's own pitch every frame


func _start_clip() -> void:
	_cam = Camera3D.new()
	_cam.fov = 72.0
	_map.add_child(_cam)
	_cam.global_position = _map.player.global_position + Vector3(0, 3, 4)
	_cam.make_current()


func _drive_camera(delta: float) -> void:
	if _cam == null or _map == null or _focus_pid <= 0 or _map.squad == null:
		return
	if not _cam.current:
		_cam.make_current()   # the player's own camera takes over on spawn
	var tgt: Player = _map.squad.player_by_id(_focus_pid)
	if tgt == null:
		return
	var back: Vector3 = tgt.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var want: Vector3 = tgt.global_position + back * 3.4 + Vector3.UP * 2.2
	var from: Vector3 = tgt.global_position + Vector3.UP * 1.6
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, want, 1, [tgt.get_rid()])
	var r: Dictionary = tgt.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		want = from.lerp(r["position"], 0.85)
	_cam.global_position = _cam.global_position.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	var look: Vector3 = tgt.global_position + Vector3.UP * 1.1 - back * 1.5
	if _cam.global_position.distance_to(look) > 0.5:
		_cam.look_at(look, Vector3.UP)


func _finish() -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	if _map != null and _map.squad != null:
		for line: String in _map.squad.report():
			print("[marks] ", line)
	print("[marks] RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL (%d): %s" % [_fails.size(), ", ".join(_fails)]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _fails.is_empty() else 1)
