extends GutTest
## Map marks and the bots' orders (Update 04 section 3, DECISIONS T-069): the order system's rules (assignment and
## the best bot, affordability and the short amount, the 60 s queue, the revive interruption and the resume, one
## order per bot, three personal marks with the oldest replaced), buy-for-teammate, the door confirmation, the ping
## key's target classification and its decisions, a mark on an easter-egg object going to the egg API, the
## Armorer's Bench order, the pause map's radial and who-picker. The live versions run in smoke_marks.

const TUNE: Dictionary = {"short_penalty_m": 4.0, "busy_penalty_m": 6.0}


class FakeHandler extends Node:
	var placed: Array = []
	var cancelled: Array = []
	var removed: Array = []
	var next_pid: int = 2

	func _init() -> void:
		add_to_group(MapMarks.HANDLER_GROUP)

	func place_order(spec: Dictionary, mark_id: int) -> Dictionary:
		if str(spec.get("kind", "")) == "buy" and not bool(spec.get("confirmed", false)) and spec.get("door", false):
			return {"ok": false, "reason": "Confirm the door first.", "pid": -1}
		var pid: int = int(spec["target"]) if spec.get("target") is int else next_pid
		placed.append([mark_id, pid])
		return {"ok": true, "pid": pid, "reason": ""}

	func cancel_order(mark_id: int) -> void:
		cancelled.append(mark_id)

	func mark_removed(m: Dictionary, why: String) -> void:
		removed.append([int(m["id"]), why])

	func bots() -> Array:
		return [{"pid": 2, "name": "Peg"}, {"pid": 3, "name": "Deacon"}]


var _root: Node3D
var _ms: MapState
var _mm: MapMarks
var _h: FakeHandler


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)
	_ms = MapState.new()
	_ms.setup(MapData.for_map(&"map00_crossroads"), _root, "gravelight")
	_mm = MapMarks.new()
	_mm.state = _ms
	add_child(_mm)
	_h = null


func after_each() -> void:
	if _h != null:
		_h.free()
	_mm.free()
	_ms.free()


func _with_bots() -> void:
	_h = FakeHandler.new()
	add_child(_h)


# ------------------------------------------------------------------ MapMarks: limits, who, replace-oldest

func test_default_targets() -> void:
	assert_eq(MapMarks.default_target("go", true), "me", "Go here: Me")
	assert_eq(MapMarks.default_target("note", true), "me")
	assert_eq(MapMarks.default_target("buy", true), "any", "BUY THIS: Any bot")
	assert_eq(MapMarks.default_target("collect", true), "any", "COLLECT: Any bot")
	assert_eq(MapMarks.default_target("defend", true), "any", "DEFEND: Any bot")
	assert_eq(MapMarks.default_target("danger", true), "squad")
	assert_eq(MapMarks.default_target("regroup", true), "squad")
	assert_eq(MapMarks.default_target("buy", false), "me", "no bots: everything is yours")


func test_drop_for_limit_takes_the_oldest() -> void:
	var g: Array = [{"id": 4}, {"id": 7}, {"id": 9}]
	assert_eq(MapMarks.drop_for_limit(g, 3), [4] as Array[int], "a 4th mark: the oldest goes")
	assert_eq(MapMarks.drop_for_limit([{"id": 1}], 3), [] as Array[int])
	assert_eq(MapMarks.drop_for_limit([{"id": 1}, {"id": 2}, {"id": 3}, {"id": 5}], 3), [1, 2] as Array[int])


func test_three_personal_marks_the_oldest_replaced() -> void:
	var ids: Array = []
	for i: int in 4:
		var r: Dictionary = _mm.place({"kind": "go", "pos": Vector3(i * 3.0, 0, 5), "owner": 1, "target": "me"})
		assert_true(bool(r["ok"]))
		ids.append(int(r["id"]))
	assert_eq(_mm.personal(1).size(), 3, "3 personal marks")
	assert_true(_mm.mark(int(ids[0])).is_empty(), "the oldest went")
	assert_false(_mm.mark(int(ids[3])).is_empty(), "the newest stayed")
	var r2: Dictionary = _mm.place({"kind": "note", "pos": Vector3(1, 0, 1), "owner": 2, "target": "me", "label": "Loop here"})
	assert_eq(_mm.personal(1).size(), 3, "another player's marks have their own limit")
	assert_eq(str(_mm.mark(int(r2["id"]))["label"]), "Loop here")


func test_an_order_without_bots_is_refused() -> void:
	var r: Dictionary = _mm.place({"kind": "buy", "pos": Vector3.ZERO, "owner": 1, "target": "any"})
	assert_false(bool(r["ok"]))
	assert_string_contains(str(r["reason"]), "No bots")


func test_orders_go_to_the_handler_and_its_bot() -> void:
	_with_bots()
	var r: Dictionary = _mm.place({"kind": "defend", "pos": Vector3(4, 0, 4), "owner": 1, "target": 3})
	assert_true(bool(r["ok"]))
	assert_eq(int(r["pid"]), 3, "the bot picked by portrait")
	var m: Dictionary = _mm.mark(int(r["id"]))
	assert_true(bool(m["order"]))
	assert_eq(int(m["pid"]), 3)
	assert_eq(_mm.order_mark_of(3)["id"], m["id"])
	_mm.remove(int(r["id"]))
	assert_eq(_h.cancelled, [int(r["id"])], "removing an order's mark cancels the bot's order")


func test_order_finished_removes_the_mark_without_cancelling() -> void:
	_with_bots()
	var r: Dictionary = _mm.place({"kind": "go", "pos": Vector3(4, 0, 4), "owner": 1, "target": 2})
	_mm.order_finished(int(r["id"]))
	assert_true(_mm.mark(int(r["id"])).is_empty())
	assert_eq(_h.cancelled, [], "a finished order isn't cancelled")


func test_danger_and_regroup_limits() -> void:
	_with_bots()
	for i: int in 4:
		_mm.place({"kind": "danger", "pos": Vector3(i, 0, 0), "owner": 1})
	var dangers: int = 0
	for m: Dictionary in _mm.marks():
		if str(m["kind"]) == "danger":
			dangers += 1
			assert_true(int(m.get("until", 0)) > 0, "a danger mark lasts 60 s")
	assert_eq(dangers, 3, "3 danger marks per player")
	_mm.place({"kind": "regroup", "pos": Vector3(1, 0, 0), "owner": 1})
	_mm.place({"kind": "regroup", "pos": Vector3(9, 0, 0), "owner": 1})
	var regroups: int = 0
	for m2: Dictionary in _mm.marks():
		if str(m2["kind"]) == "regroup":
			regroups += 1
	assert_eq(regroups, 1, "one regroup at a time")


# ------------------------------------------------------------------ the best bot, affordability, the queue

func test_best_bot_closest_that_can_afford() -> void:
	var c: Array = [{"pid": 2, "dist": 5.0, "scrip": 500}, {"pid": 3, "dist": 20.0, "scrip": 4000}, {"pid": 4, "dist": 12.0, "scrip": 3000}]
	assert_eq(BotMarkOrders.best_bot(c, 2500, TUNE), 4, "the closest who can afford it")
	assert_eq(BotMarkOrders.best_bot(c, 0, TUNE), 2, "not a purchase: the closest")


func test_best_bot_skips_the_downed_and_reviving() -> void:
	var c: Array = [{"pid": 2, "dist": 2.0, "scrip": 9000, "reviving": true}, {"pid": 3, "dist": 4.0, "scrip": 9000, "down": true},
		{"pid": 4, "dist": 30.0, "scrip": 9000}]
	assert_eq(BotMarkOrders.best_bot(c, 1000, TUNE), 4, "never a bot that is down or reviving")
	assert_eq(BotMarkOrders.best_bot([c[0], c[1]], 1000, TUNE), -1, "nobody free")


func test_best_bot_when_nobody_can_afford_it() -> void:
	var c: Array = [{"pid": 2, "dist": 5.0, "scrip": 100}, {"pid": 3, "dist": 8.0, "scrip": 2400}]
	assert_eq(BotMarkOrders.best_bot(c, 2500, TUNE), 3, "the least short (it saves the shortest time)")
	assert_eq(BotMarkOrders.best_bot([{"pid": 2, "dist": 5.0, "scrip": 0, "busy": true}, {"pid": 3, "dist": 9.0, "scrip": 0}], 0, TUNE), 3,
		"a bot already on an order counts a little farther")


func test_best_bot_never_picks_jakub_for_a_purchase() -> void:
	var c: Array = [{"pid": 9, "dist": 1.0, "scrip": 0, "companion": true}, {"pid": 2, "dist": 30.0, "scrip": 0}]
	assert_eq(BotMarkOrders.best_bot(c, 500, TUNE, false), 2)
	assert_eq(BotMarkOrders.best_bot(c, 0, TUNE, true), 9, "he can go and defend")


func test_short_amounts_and_their_lines() -> void:
	assert_eq(BotMarkTask.short_by(1300, 2500), 1200)
	assert_eq(BotMarkTask.short_by(3000, 2500), 0, "it can pay")
	var b: Array = BotAIData.table("marks")["lines"]["short_buckets"]
	assert_eq(BotMarkTask.short_category(600, b), "MARK_SHORT_600", "\"Need 600 more for that, boss.\"")
	assert_eq(BotMarkTask.short_category(1130, b), "MARK_SHORT_1250", "rounded up to the next amount it says")
	assert_eq(BotMarkTask.short_category(9000, b), "MARK_SHORT_LOTS")
	for bucket: Variant in b:
		for spk: String in ["DUT", "PEG", "DEA", "WRN"]:
			assert_true(GLVO.lines.has("%s_SQ5_MARK_SHORT_%d_01" % [spk, int(bucket)]), "%s has the %d line" % [spk, int(bucket)])


func test_queue_expiry_after_sixty_seconds() -> void:
	var q: float = float(BotAIData.table("marks")["queue_s"])
	assert_eq(q, 60.0, "an unaffordable order waits 60 s")
	assert_false(BotMarkTask.queue_expired(10.0, 69.0, q))
	assert_true(BotMarkTask.queue_expired(10.0, 70.0, q))
	assert_false(BotMarkTask.queue_expired(-1.0, 999.0, q), "not waiting: never expires this way")


func test_value_is_zero_while_waiting_for_scrip() -> void:
	var v: Dictionary = BotAIData.table("marks")["value"]
	assert_eq(BotMarkTask.value_for("buy", "wait_scrip", false, v), 0.0, "it earns instead of standing at the machine")
	assert_gt(BotMarkTask.value_for("buy", "go", false, v), 0.5)
	assert_eq(BotMarkTask.value_for("collect", "go", true, v), 0.0, "an egg mark is BotEE's action")
	assert_gt(BotMarkTask.value_for("defend", "go", false, v), BotMarkTask.value_for("go", "go", false, v), "defending holds harder")


func test_the_utility_ranks_a_revive_over_an_order() -> void:
	var acts: Dictionary = BotAIData.table("actions")["actions"]
	assert_true(acts.has("mark_order"), "the mark_order action exists")
	assert_gt(float(acts["revive"]["weight"]), float(acts["mark_order"]["weight"]), "a revive emergency outweighs an order")


func test_revive_interrupts_and_the_order_resumes() -> void:
	assert_eq(BotMarkTask.away_kind("revive", false, false), "revive")
	assert_eq(BotMarkTask.away_kind("cover", false, false), "revive")
	assert_eq(BotMarkTask.away_kind("fight", true, false), "down")
	assert_eq(BotMarkTask.away_kind("mark_order", false, false), "")
	assert_true(BotMarkTask.resume_due(true, true), "back from a revive: \"Back to it.\"")
	assert_false(BotMarkTask.resume_due(true, false), "back from a down: no line")
	for spk: String in ["DUT", "PEG", "DEA", "WRN", "JAK"]:
		assert_true(GLVO.lines.has("%s_SQ5_MARK_RESUME_01" % spk), "%s says Back to it" % spk)


# ------------------------------------------------------------------ refusals, the door, Jakub, buy for teammate

func test_refusals() -> void:
	assert_eq(BotMarkOrders.refusal("door", {"confirmed": false}), "confirm", "a door needs the confirmation")
	assert_eq(BotMarkOrders.refusal("door", {"confirmed": true}), "")
	assert_eq(BotMarkOrders.refusal("door", {"confirmed": true, "owned": true}), "owned")
	assert_eq(BotMarkOrders.refusal("perk", {"perk_state": "owned"}), "owned")
	assert_eq(BotMarkOrders.refusal("perk", {"perk_state": "cap"}), "cap")
	assert_eq(BotMarkOrders.refusal("perk", {"perk_state": "no_power"}), "power")
	assert_eq(BotMarkOrders.refusal("perk", {"perk_state": "ok"}), "")
	assert_eq(BotMarkOrders.refusal("gun", {"slots_free": false}), "full")
	assert_eq(BotMarkOrders.refusal("trap", {"ready": false}), "not_ready")
	assert_eq(BotMarkOrders.refusal("crucible", {"powered": false}), "power")


func test_jakub_refuses_perks_the_crucible_and_buying() -> void:
	assert_eq(BotMarkOrders.refusal("perk", {"companion": true}), "refuse_perk")
	assert_eq(BotMarkOrders.refusal("crucible", {"companion": true}), "refuse_crucible")
	assert_eq(BotMarkOrders.refusal("gun", {"companion": true}), "refuse_buy")
	assert_eq(BotMarkOrders.refusal("power", {"companion": true}), "", "he may throw the switch")
	assert_eq(BotMarkOrders.refusal_lines("refuse_perk")[0], "EE_REFUSE_PERK", "his section 5 refusal, in character")
	assert_true(GLVO.lines.has("JAK_SQ5_MARK_REFUSE_BUY_01"))


func test_door_question() -> void:
	assert_eq(MarkTargets.door_question(1250), "Open this door for 1,250?")
	assert_eq(MarkTargets.money(60000), "60,000")


func test_buy_for_teammate_parcel() -> void:
	var p: WeaponParcel = WeaponParcel.make(&"m1_garand", 1, 3)
	assert_eq(p.weapon_id, &"m1_garand")
	assert_eq(p.for_pid, 1, "only for the player it was bought for")
	assert_eq(p.from_pid, 3)
	assert_true(p.is_in_group(&"weapon_parcels"))
	var who: Player = Player.new()
	who.player_id = 2
	assert_false(p.can_interact(who), "a teammate it wasn't bought for can't take it")
	assert_eq(p.get_prompt(who), "")
	who.player_id = 1
	assert_string_contains(p.get_prompt(who), "M1 Garand", "the prompt names the gun")
	assert_string_contains(p.get_prompt(who), "bought it for you")
	who.free()
	p.free()


func test_status_lines() -> void:
	assert_true(GLVO.lines.has("DUT_SQ5_MARK_FOR_YOU_DROP_01"), "the bought-for-you line")
	assert_true(GLVO.lines.has("DUT_SQ5_MARK_BOUGHT_IRONHIDE_01"), "\"Got the Ironhide. Feel like a barrel.\"")
	assert_eq(str(GLVO.lines["DUT_SQ5_MARK_SHORT_600_01"]["text"]), "Need 600 more for that, boss.")


# ------------------------------------------------------------------ routing: EE marks, the bench, the power

func test_routes() -> void:
	assert_eq(BotMarkOrders.route("collect", {"kind": "collect", "sub": "quest"}), "ee", "an egg object goes to the squad's egg API")
	assert_eq(BotMarkOrders.route("collect", {"kind": "collect", "sub": "powerup"}), "powerup")
	assert_eq(BotMarkOrders.route("collect", {"kind": "activate", "sub": "power"}), "power")
	assert_eq(BotMarkOrders.route("buy", {"kind": "buy", "sub": "bench"}), "buy", "the Armorer's Bench is a purchase")
	assert_eq(BotMarkOrders.route("buy", {"kind": "go"}), "refuse", "nothing to buy there")
	assert_eq(BotMarkOrders.route("defend", {"kind": "go"}), "defend")
	assert_eq(BotMarkOrders.route("collect", {"kind": "go"}), "refuse")


func test_bench_pick() -> void:
	var rows: Array = [
		{"slot": "mag", "option": "extended", "price": 750, "installed": false, "reason": ""},
		{"slot": "grip", "option": "checkered", "price": 500, "installed": true, "reason": ""},
		{"slot": "sights", "option": "radium", "price": 600, "installed": false, "reason": "no_scrip"},
		{"slot": "ammo", "option": "nachtglas", "price": 2000, "installed": false, "reason": "needs_power"},
	]
	var prefs: Array = BotAIData.table("marks")["bench_prefs"]
	assert_eq(str(BotMarkOrders.pick_bench_option(rows, prefs, 800)["option"]), "extended", "the first preference it hasn't fitted and can afford")
	assert_eq(str(BotMarkOrders.pick_bench_option(rows, prefs, 650)["option"]), "radium", "the next one it can afford")
	assert_eq(str(BotMarkOrders.pick_bench_option(rows, prefs, 100)["option"]), "radium", "can't afford any: it saves for the cheapest")
	assert_true(BotMarkOrders.pick_bench_option([rows[1], rows[3]], prefs, 9000).is_empty(), "nothing left it may fit")


# ------------------------------------------------------------------ the ping key

func test_ping_target_classification() -> void:
	var pm: PerkMachine = PerkMachine.new()
	pm.perk_id = &"trigger_tonic"
	var area: Area3D = Area3D.new()
	pm.add_child(area)
	var c: Dictionary = MarkTargets.classify(area)
	assert_eq(str(c["kind"]), "buy", "the use box of a perk machine: Buy this")
	assert_eq(str(c["sub"]), "perk")
	assert_eq(c["node"], pm)
	assert_eq(int(c["price"]), PerkManager.price(&"trigger_tonic"))
	var wb: WallBuy = WallBuy.new()
	wb.weapon_id = &"kar98k"
	assert_eq(str(MarkTargets.classify(wb)["sub"]), "gun")
	var d: BuyDoor = BuyDoor.new()
	d.cost = 1250
	assert_eq(str(MarkTargets.classify(d)["sub"]), "door")
	d.is_open = true
	assert_eq(str(MarkTargets.classify(d)["kind"]), "go", "an open door is just a place")
	var wall: StaticBody3D = StaticBody3D.new()
	assert_eq(str(MarkTargets.classify(wall)["kind"]), "go", "a wall: Go here")
	assert_eq(str(MarkTargets.classify(null)["kind"]), "go")
	var note: QuestNote = QuestNote.new()
	assert_eq(str(MarkTargets.classify(note)["kind"]), "collect", "an easter-egg object: Collect / activate")
	for n: Node in [pm, wb, d, wall, note]:
		n.free()


func test_ping_decisions() -> void:
	var pc: Dictionary = MapMarks.cfg()["ping"]
	var perk: Dictionary = {"kind": "buy", "sub": "perk"}
	var door: Dictionary = {"kind": "buy", "sub": "door"}
	var flr: Dictionary = {"kind": "go", "sub": ""}
	var egg: Dictionary = {"kind": "collect", "sub": "quest"}
	assert_eq(MarkPing.decide(perk, true, 5000, false, false, pc), "buy", "a perk machine: Buy this for any bot")
	assert_eq(MarkPing.decide(flr, true, 5000, false, false, pc), "go", "a wall or the floor: Go here")
	assert_eq(MarkPing.decide(flr, true, 200, false, false, pc), "danger", "a double-tap: Danger")
	assert_eq(MarkPing.decide(egg, true, 5000, false, false, pc), "collect", "an egg object: Collect")
	assert_eq(MarkPing.decide(door, true, 5000, false, false, pc), "ask_door", "a door asks first")
	assert_eq(MarkPing.decide(door, true, 200, true, false, pc), "confirm_door", "the second press confirms (not a danger)")
	assert_eq(MarkPing.decide(door, false, 5000, false, false, pc), "buy", "no bots: a waypoint at the door")
	assert_eq(MarkPing.decide(flr, true, 5000, false, true, pc), "remove", "on one of your marks: it goes")


func test_ping_bindings() -> void:
	var t: Dictionary = GLData.table("input_defaults")
	assert_eq(str(t["ping"]["mouse"]), "MIDDLE", "middle mouse pings")
	assert_eq(str(t["ping"]["pad"]), "DPAD_UP", "D-pad up pings")
	assert_false((t["alt_fire"] as Dictionary).has("mouse"), "alt-fire left middle mouse to the ping (it keeps B / D-pad right)")
	for a: Variant in t.keys():
		if str(a) == "ping" or str(a).begins_with("_"):
			continue
		var b: Dictionary = t[a]
		assert_false(str(b.get("pad", "")) == "DPAD_UP", "nothing else is on D-pad up (%s)" % a)
		assert_false(str(b.get("mouse", "")) == "MIDDLE", "nothing else is on middle mouse (%s)" % a)


# ------------------------------------------------------------------ the pause map's menus

func test_radial_entries() -> void:
	var empty: Array = PauseMapView.radial_for({"kind": "go"}, true)
	var ids: Array = empty.map(func(e: Dictionary) -> String: return str(e["id"]))
	assert_eq(ids, ["go", "defend", "danger", "regroup", "note"], "an empty spot: Go Here · Defend Here · Danger · Regroup · Custom note")
	var buy: Array = PauseMapView.radial_for({"kind": "buy", "sub": "perk"}, true)
	assert_eq(str(buy[0]["id"]), "buy", "a buyable: BUY THIS")
	var door: Array = PauseMapView.radial_for({"kind": "buy", "sub": "door"}, true)
	assert_eq(str(door[0]["label"]), "OPEN THIS DOOR")
	var bench: Array = PauseMapView.radial_for({"kind": "buy", "sub": "bench"}, true)
	assert_eq(str(bench[0]["id"]), "bench_pick", "the bench: the bot's pick")
	assert_eq(bench.size(), 1 + M1911Kit.slot_order().size() + 1, "or one of its five slots (then Go here)")
	var egg: Array = PauseMapView.radial_for({"kind": "collect", "sub": "quest"}, true)
	assert_eq(str(egg[0]["id"]), "collect", "an egg object: Collect / activate this")
	var bs: Array = PauseMapView.radial_for({"kind": "buy", "sub": "perk"}, false, true)
	assert_eq(str(bs[0]["id"]), "go", "B&S has nothing for bots to buy")
	var alone: Array = PauseMapView.radial_for({"kind": "go"}, false)
	assert_false(alone.map(func(e: Dictionary) -> String: return str(e["id"])).has("defend"), "no bots: no Defend / Regroup")


func test_who_picker_defaults() -> void:
	var bots: Array = [{"pid": 2, "name": "Peg"}, {"pid": 3, "name": "Deacon"}, {"pid": 9, "name": "Jakub", "jakub": true}]
	var w: Dictionary = PauseMapView.who_options("go", "", bots)
	assert_eq(str(w["options"][int(w["default"])]["target"]), "me", "Go here defaults to Me")
	var b: Dictionary = PauseMapView.who_options("buy", "perk", bots)
	assert_eq(str(b["options"][int(b["default"])]["target"]), "any", "BUY THIS defaults to Any bot")
	var targets: Array = (b["options"] as Array).map(func(o: Dictionary) -> String: return str(o["target"]))
	assert_false(targets.has("jakub"), "Jakub isn't offered for a purchase")
	var d: Dictionary = PauseMapView.who_options("defend", "", bots)
	assert_eq(str(d["options"][int(d["default"])]["target"]), "any", "DEFEND defaults to Any bot")
	assert_true((d["options"] as Array).map(func(o: Dictionary) -> String: return str(o["target"])).has("jakub"), "Jakub can defend")
	var g: Dictionary = PauseMapView.who_options("buy", "gun", bots)
	assert_eq(str(g["options"][0]["target"]), "me_for", "a wall weapon for me: a bot buys it for you")


func test_tooltips() -> void:
	var poi: Dictionary = {"id": "x", "type": "door", "label": "Stable", "price": 1000, "data": {}}
	var lines: PackedStringArray = PauseMapView.tooltip_lines({"kind": "door", "poi": poi, "state": {"open": false, "locked": false, "price": 1000, "label": "Stable"}}, null, null, 1)
	assert_eq(lines[0], "Stable")
	assert_string_contains(lines[1], "1,000 Scrip")
	assert_string_contains(lines[2], "Closed")
	var l2: PackedStringArray = PauseMapView.tooltip_lines({"kind": "door", "poi": poi, "state": {"open": true, "price": 1000}}, null, null, 1)
	assert_eq(l2[2], "Open")
	var l3: PackedStringArray = PauseMapView.tooltip_lines({"kind": "door", "poi": poi, "state": {"open": false, "locked": true}}, null, null, 1)
	assert_string_contains(l3[2], "needs the power")
