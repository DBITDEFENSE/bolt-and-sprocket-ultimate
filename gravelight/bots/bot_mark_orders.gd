class_name BotMarkOrders
extends Node
## The squad's side of the map marks (Update 04 section 3, DECISIONS T-069): the order handler MapMarks talks to
## (group "map_mark_orders"), a child of the BotSquad. A mark for a bot becomes that bot's order (BotMarkTask,
## `brain.mark`), a high-weight action on the utility AI:
##   - who: the bot the player picked, or for "Any bot" the best one: not down, not reviving, closest by path; for a
##     purchase one who can afford it beats one who can't (best_bot, pure);
##   - one order per bot: a new one replaces the old (its mark goes); an easter-egg mark goes through the squad's
##     egg API (BotSquad.ee_assign_node: the When Asked / Full Partner rules, Jakub's limits) and counts as that
##     bot's order;
##   - BUY THIS: perk, wall weapon (for the bot, or "for me": the bot buys it and brings it over), ammo box, door
##     (only marked doors the player confirmed: "Open this door for 1,250?"), the Requisition Crate, the Crucible,
##     a trap, the Armorer's Bench (the slot / option picked in the radial, or the bot's own sensible pick it can
##     afford: pick_bench_option); short of Scrip the bot says by how much and waits 60 s while it earns;
##   - DEFEND HERE (one bot holds ~4 m round the spot, rebuilds the windows close by), REGROUP (every bot comes),
##     DANGER (every bot's paths avoid it for 60 s, and the nearest calls it out);
##   - Jakub: no purchases ("I have no Scrip"), never a perk machine or the Crucible (his U02 / section 5 refusals);
##     he goes, defends, regroups and does the egg steps section 5 lets him.
## Revives come first (the brain's revive action outweighs the order); the order resumes after ("Back to it.").

const GROUP: StringName = &"map_mark_orders"
const JAKUB_PID: int = 9

var squad: BotSquad
var orders_given: int = 0
var orders_done: int = 0
var orders_failed: int = 0
var log_lines: PackedStringArray = []
var _cfg: Dictionary = {}
var _regroup_id: int = -1


func setup(s: BotSquad) -> void:
	squad = s
	_cfg = BotAIData.table("marks")
	add_to_group(GROUP)
	for b: BotBrain in squad.brains:
		attach(b)


func attach(b: BotBrain) -> void:
	if b.mark == null:
		b.mark = BotMarkTask.new()
		b.mark.setup(b)


func marks() -> MapMarks:
	return MapMarks.current()


func _log(s: String) -> void:
	log_lines.append("%.0f %s" % [squad.time(), s])
	if log_lines.size() > 60:
		log_lines.remove_at(0)


# ================================================================== the pure rules (unit-tested)

## The best bot for a job: candidates [{pid, dist (path m, INF unreachable), scrip, down, reviving, busy, companion}],
## `price` (0: not a purchase). Down or reviving bots never; companions only when `allow_companion`. Among the rest:
## the one who can afford it first, then by distance + short_penalty_m per 100 Scrip short + busy_penalty_m when it
## already has an order. -1 when nobody can.
static func best_bot(cands: Array, price: int, tune: Dictionary, allow_companion: bool = false) -> int:
	var best: int = -1
	var best_s: float = INF
	var best_afford: bool = false
	for c: Variant in cands:
		var d: Dictionary = c
		if bool(d.get("down", false)) or bool(d.get("reviving", false)):
			continue
		if bool(d.get("companion", false)) and not allow_companion:
			continue
		var dist: float = float(d.get("dist", INF))
		if dist == INF:
			dist = 500.0   # no path now (a door): still a candidate, last
		var short: int = maxi(0, price - int(d.get("scrip", 0)))
		var afford: bool = short == 0
		var s: float = dist + float(tune.get("short_penalty_m", 4.0)) * float(short) / 100.0
		if bool(d.get("busy", false)):
			s += float(tune.get("busy_penalty_m", 6.0))
		if (afford and not best_afford) or (afford == best_afford and s < best_s):
			best = int(d["pid"])
			best_s = s
			best_afford = afford
	return best


## Why a bot can't take a purchase ("" = it can), from plain facts: sub, companion, perk_state (PerkManager.can_buy
## result), powered, owned (already has this gun / door open), confirmed (a door), slots_free (a gun: false when
## every slot holds an upgraded gun).
static func refusal(sub: String, facts: Dictionary) -> String:
	if bool(facts.get("companion", false)):
		match sub:
			"perk":
				return "refuse_perk"
			"crucible", "crucible_ammo":
				return "refuse_crucible"
			"power":
				return ""
		return "refuse_buy"
	match sub:
		"perk":
			var ps: String = str(facts.get("perk_state", "ok"))
			if ps == "owned":
				return "owned"
			if ps == "no_power" or ps == "gone":
				return "power"
			if ps == "cap":
				return "cap"
		"door":
			if bool(facts.get("owned", false)):
				return "owned"
			if not bool(facts.get("confirmed", false)):
				return "confirm"
			if bool(facts.get("locked", false)):
				return "power"
		"crucible":
			if not bool(facts.get("powered", true)):
				return "power"
			if not bool(facts.get("upgradeable", true)):
				return "nothing_to_forge"
		"trap":
			if not bool(facts.get("ready", true)):
				return "not_ready"
		"gun":
			if not bool(facts.get("slots_free", true)):
				return "full"
		"bench":
			if not bool(facts.get("has_pistol", true)):
				return "no_pistol"
			if bool(facts.get("owned", false)):
				return "owned"
	return ""


static func refusal_text(code: String, who: String) -> String:
	match code:
		"refuse_buy":
			return "Jakub has no Scrip of his own."
		"refuse_perk":
			return "Jakub won't touch the perk machines."
		"refuse_crucible":
			return "Jakub won't go near the Crucible."
		"owned":
			return "%s has that already." % who
		"power":
			return "That needs the power on."
		"cap":
			return "%s can't hold another tonic." % who
		"confirm":
			return "Confirm the door first."
		"nothing_to_forge":
			return "%s has nothing worth forging." % who
		"not_ready":
			return "That trap isn't ready."
		"full":
			return "%s's hands are full of upgraded guns." % who
		"no_pistol":
			return "%s has no M1911 for the bench." % who
		"no_bot":
			return "No bot can take that right now."
	return "Can't do that."


static func refusal_lines(code: String) -> Array:
	match code:
		"refuse_buy":
			return ["MARK_REFUSE_BUY", "EE_CANT"]
		"refuse_perk":
			return ["EE_REFUSE_PERK"]
		"refuse_crucible":
			return ["EE_REFUSE_CRUCIBLE"]
		"owned":
			return ["MARK_CANT_OWNED", "MARK_CANT"]
		"power":
			return ["MARK_CANT_POWER", "MARK_CANT"]
		"cap":
			return ["MARK_CANT_CAP", "MARK_CANT"]
		"full":
			return ["MARK_CANT_FULL", "MARK_CANT"]
	return ["MARK_CANT"]


## The bot's own pick at the Armorer's Bench: the first option in `prefs` (slot / option pairs) not fitted and not
## refused that it can afford; else the cheapest it can't afford yet (it saves for it); {} when there is nothing.
## `rows` = ArmorersBench.options_for(bot).
static func pick_bench_option(rows: Array, prefs: Array, scrip: int) -> Dictionary:
	var open: Array = []
	for r: Variant in rows:
		var d: Dictionary = r
		var code: String = str(d.get("reason", ""))
		if bool(d.get("installed", false)) or (code != "" and code != "no_scrip"):
			continue
		open.append(d)
	if open.is_empty():
		return {}
	var order_of: Callable = func(d: Dictionary) -> int:
		for i: int in prefs.size():
			var pr: Array = prefs[i]
			if str(pr[0]) == str(d["slot"]) and str(pr[1]) == str(d["option"]):
				return i
		return prefs.size() + int(d.get("price", 0)) / 100
	open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return order_of.call(a) < order_of.call(b))
	for d2: Dictionary in open:
		if int(d2.get("price", 0)) <= scrip:
			return d2
	var cheapest: Dictionary = open[0]
	for d3: Dictionary in open:
		if int(d3.get("price", 0)) < int(cheapest.get("price", 0)):
			cheapest = d3
	return cheapest


# ================================================================== the MapMarks handler

func bots() -> Array:
	var out: Array = []
	for b: BotBrain in squad.brains:
		var pid: int = b.player.player_id
		out.append({"pid": pid, "name": "Jakub" if b.player.is_companion else Net.display_name(pid), "color": Net.player_color(pid) if not b.player.is_companion else Color("#8a6a3a"),
			"jakub": b.player.is_companion, "down": b.player.downed or b.player.spectating, "scrip": Economy.get_scrip(pid)})
	return out


func brain_of(pid: int) -> BotBrain:
	for b: BotBrain in squad.brains:
		if b.player.player_id == pid:
			return b
	return null


func has_order(pid: int) -> bool:
	var b: BotBrain = brain_of(pid)
	return b != null and b.mark != null and b.mark.active()


func order_of(pid: int) -> Dictionary:
	var b: BotBrain = brain_of(pid)
	return b.mark.order if b != null and b.mark != null else {}


## A mark for a bot (MapMarks.place): {ok, pid, reason, label}.
func place_order(spec: Dictionary, mark_id: int) -> Dictionary:
	var kind: String = str(spec.get("kind", "go"))
	var node: Node = spec.get("node") as Node
	var target: Variant = spec.get("target", "any")
	var c: Dictionary = MarkTargets.classify(node) if node != null else {"kind": "go", "sub": "", "label": "", "price": 0}
	var want_pid: int = -1
	if target is int:
		want_pid = int(target)
	elif str(target) == "jakub":
		want_pid = JAKUB_PID
		if brain_of(JAKUB_PID) == null:
			return {"ok": false, "reason": "Jakub isn't with you.", "pid": -1}
	elif str(target) != "any" and str(target).is_valid_int():
		want_pid = int(str(target))
	var pos: Vector3 = spec.get("pos", Vector3.ZERO)
	var where: String = _where(pos)
	# ---- easter-egg objects: the squad's egg API decides (and speaks)
	if kind == "collect" and str(c.get("sub", "")) == "quest":
		var r: Dictionary = squad.ee_assign_node(node, want_pid)
		if not bool(r.get("ok", false)):
			return {"ok": false, "reason": str(r.get("reason", "")), "pid": int(r.get("pid", -1))}
		var pid_e: int = int(r.get("pid", -1))
		var be: BotBrain = brain_of(pid_e)
		if be == null:
			return {"ok": false, "reason": "No bot took it.", "pid": -1}
		_replace(be, mark_id, false)
		be.mark.start({"kind": "collect", "ee": true, "mark_id": mark_id, "node": node, "pos": pos, "label": str(c.get("label", "")), "where": where})
		orders_given += 1
		_log("%s: EE mark %s (%s)" % [Net.display_name(pid_e), c.get("label", ""), r.get("reason", "")])
		return {"ok": true, "pid": pid_e, "reason": str(r.get("reason", "")), "label": str(c.get("label", "Collect"))}
	var o: Dictionary = {"mark_id": mark_id, "pos": pos, "where": where, "node": node, "label": str(spec.get("label", ""))}
	var price: int = 0
	match kind:
		"buy":
			if str(c.get("kind", "")) != "buy" and str(c.get("kind", "")) != "activate":
				return {"ok": false, "reason": "There's nothing to buy there.", "pid": -1}
			o["kind"] = "buy"
			o["sub"] = str(c.get("sub", ""))
			o["label"] = str(c.get("label", ""))
			o["price"] = int(c.get("price", 0))
			if int(spec.get("for_pid", 0)) > 0 and o["sub"] == "gun":
				o["for_pid"] = int(spec["for_pid"])
			if o["sub"] == "bench":
				o["slot"] = str(spec.get("slot", ""))
				o["option"] = str(spec.get("option", ""))
			price = int(o["price"])
		"collect":
			if str(c.get("sub", "")) == "powerup":
				o["kind"] = "powerup"
				o["label"] = str(c.get("label", "power-up"))
			elif str(c.get("kind", "")) == "activate":
				o["kind"] = "buy"
				o["sub"] = "power"
				o["label"] = "the power"
			else:
				return {"ok": false, "reason": "Nothing to collect there.", "pid": -1}
		"go", "defend":
			o["kind"] = kind
			o["label"] = where
		_:
			return {"ok": false, "reason": "Not an order.", "pid": -1}
	# ---- who
	var pid: int = want_pid
	if pid < 0:
		var why: Array = []
		pid = _best_for(o, price, spec, why)
		if pid < 0:
			return {"ok": false, "reason": refusal_text(str(why[0]) if not why.is_empty() else "no_bot", "Every bot"), "pid": -1}
	var b: BotBrain = brain_of(pid)
	if b == null:
		return {"ok": false, "reason": "No such bot.", "pid": -1}
	if b.player.downed or b.player.spectating:
		return {"ok": false, "reason": "%s is down." % _name(b), "pid": pid}
	# ---- may it (and the details: the bench's pick, an owned wall gun means its ammo)
	if str(o.get("kind", "")) == "buy":
		var code: String = _prepare_buy(b, o, spec)
		if code != "":
			if b.mark == null:
				attach(b)
			b.mark._say(refusal_lines(code), Vector3.INF, "")
			return {"ok": false, "reason": refusal_text(code, _name(b)), "pid": pid}
	_replace(b, mark_id, true)
	b.mark.start(o)
	orders_given += 1
	var short: int = BotMarkTask.short_by(Economy.get_scrip(pid), b.mark.price()) if str(o.get("kind", "")) == "buy" else 0
	_log("%s: %s %s %s%s" % [_name(b), o.get("kind", ""), o.get("sub", ""), o.get("label", ""), (" (%d short)" % short) if short > 0 else ""])
	var lbl: String = str(o.get("label", ""))
	if str(o.get("sub", "")) == "bench":
		lbl = "%s (%s)" % [M1911Kit.option_name(str(o["slot"]), str(o["option"]), false), "Armorer's Bench"]
	return {"ok": true, "pid": pid, "reason": ("%s short: %s will save up." % [MarkTargets.money(short), _name(b)]) if short > 0 else "", "label": lbl}


## Fills in the purchase details on `o` for bot `b` and says whether it may ("" = yes, else a refusal code).
func _prepare_buy(b: BotBrain, o: Dictionary, spec: Dictionary) -> String:
	var sub: String = str(o["sub"])
	var n: Node = o.get("node") as Node
	var p: Player = b.player
	var facts: Dictionary = {"companion": p.is_companion}
	match sub:
		"perk":
			facts["perk_state"] = String(PerkManager.can_buy(p.player_id, (n as PerkMachine).perk_id))
		"gun":
			var wb: WallBuy = n as WallBuy
			if int(o.get("for_pid", 0)) <= 0:
				if p.weapons.find_weapon_base(wb.weapon_id) != null:
					o["sub"] = "ammo"   # it has that gun: the wall sells it ammo
					o["label"] = "%s ammo" % str(o["label"])
					o["slot"] = p.weapons.slots.find(p.weapons.find_weapon_base(wb.weapon_id))
					o["price"] = wb.ammo_price(p)
					sub = "ammo"
				else:
					facts["slots_free"] = p.weapons.slots.size() < p.weapons.max_slots() or b._slot_to_give_up() >= 0
		"door":
			var d: BuyDoor = n as BuyDoor
			facts["owned"] = d.is_open
			facts["confirmed"] = bool(spec.get("confirmed", false))
			facts["locked"] = d.requires_power and not GameState.power_on
		"crucible":
			var cr: Crucible = n as Crucible
			facts["powered"] = cr.is_powered()
			var up: int = b._upgradeable_slot()
			if up < 0:
				for i: int in p.weapons.slots.size():
					if p.weapons.slots[i].upgraded:
						o["sub"] = "crucible_ammo"
						o["slot"] = i
						o["label"] = "upgraded ammo"
						sub = "crucible_ammo"
						break
			facts["upgradeable"] = up >= 0 or sub == "crucible_ammo"
		"trap":
			var t: Node = (n as TrapLever).trap() if n is TrapLever else null
			facts["ready"] = t != null and (not t.has_method("can_activate") or bool(t.call("can_activate")))
		"ammo_box":
			var mg: WeaponInstance = b.economy._main_gun()
			o["slot"] = p.weapons.slots.find(mg) if mg != null else -1
		"bench":
			var w: WeaponInstance = M1911Kit.pistol_of(p)
			facts["has_pistol"] = w != null
			if w != null and not p.is_companion:
				if str(o.get("slot", "")) == "" or str(o.get("option", "")) == "":
					var pick: Dictionary = pick_bench_option(ArmorersBench.options_for(p), _cfg.get("bench_prefs", []), Economy.get_scrip(p.player_id))
					if pick.is_empty():
						facts["owned"] = true
					else:
						o["slot"] = str(pick["slot"])
						o["option"] = str(pick["option"])
				else:
					facts["owned"] = M1911Kit.has_option(w, str(o["slot"]), str(o["option"]))
				if str(o.get("slot", "")) != "":
					o["price"] = M1911Kit.price(str(o["slot"]), str(o["option"]))
					o["label"] = M1911Kit.option_name(str(o["slot"]), str(o["option"]), w.upgraded)
	return refusal(sub, facts)


## The best bot for a job (BotMarkOrders.best_bot over the squad's live state).
func _best_for(o: Dictionary, price: int, spec: Dictionary = {}, why: Array = []) -> int:
	var cands: Array = []
	var at: Vector3 = o.get("pos", Vector3.ZERO)
	var n: Variant = o.get("node")
	if n is Node3D and is_instance_valid(n):
		at = (n as Node3D).global_position
	var buying: bool = str(o.get("kind", "")) == "buy"
	for b: BotBrain in squad.brains:
		var pid: int = b.player.player_id
		if buying and not b.player.is_companion:
			var code: String = _prepare_buy(b, o.duplicate(), spec)
			if code != "":
				why.append(code)   # it has that perk already, no room for another tonic...
				continue
		var d: float = b.loco.path_length_to(b.snap(at)) if b.loco != null else INF
		if d == INF:
			d = b.player.global_position.distance_to(at) * 2.0 + 30.0
		cands.append({"pid": pid, "dist": d, "scrip": Economy.get_scrip(pid), "down": b.player.downed or b.player.spectating,
			"reviving": b.action == "revive" or b.revive_pid != 0, "busy": b.mark != null and b.mark.active(), "companion": b.player.is_companion})
	return best_bot(cands, price if buying else 0, _cfg.get("best_bot", {}), not buying)


## One order per bot: the bot's last order (its mark) goes, and so does an egg task it was on.
func _replace(b: BotBrain, new_mark: int, cancel_ee: bool) -> void:
	if b.mark == null:
		attach(b)
	var pid: int = b.player.player_id
	if b.mark.active():
		var old: int = int(b.mark.order.get("mark_id", -1))
		b.mark.cancel("replaced", false)
		var mm: MapMarks = marks()
		if mm != null and old > 0 and old != new_mark and bool(mm.mark(old).get("order", false)):
			mm.order_finished(old)
	if cancel_ee and not squad.ee_task_of(pid).is_empty():
		squad.ee_cancel(pid)


## The player removed an order's mark (or it was replaced): the bot drops the order.
func cancel_order(mark_id: int) -> void:
	for b: BotBrain in squad.brains:
		if b.mark != null and b.mark.active() and int(b.mark.order.get("mark_id", -1)) == mark_id:
			if bool(b.mark.order.get("ee", false)):
				squad.ee_cancel(b.player.player_id)
			b.mark.cancel("mark removed", false)


## A bot's order ended (BotMarkTask): its mark goes (a regroup's when every bot is done).
func order_ended(b: BotBrain, o: Dictionary, ok: bool, why: String) -> void:
	if ok:
		orders_done += 1
	else:
		orders_failed += 1
	_log("%s: %s %s %s (%s)" % [_name(b), o.get("kind", ""), o.get("label", ""), "done" if ok else "ended", why])
	var id: int = int(o.get("mark_id", -1))
	var mm: MapMarks = marks()
	if mm == null or id <= 0:
		return
	if str(o.get("kind", "")) == "regroup":
		for b2: BotBrain in squad.brains:
			if b2 != b and b2.mark != null and b2.mark.active() and int(b2.mark.order.get("mark_id", -1)) == id:
				return   # others are still on their way
	mm.order_finished(id)


## DANGER: every bot's paths avoid the spot for the mark's life, and the nearest bot calls it out.
func on_danger(m: Dictionary) -> void:
	var pos: Vector3 = m["pos"]
	var life: float = float((MapMarks.cfg().get("lifetime_s", {}) as Dictionary).get("danger", 60.0))
	squad.blackboard.add_danger(pos, float(_cfg.get("danger_radius_m", 4.5)), float(_cfg.get("danger_cost", 3.0)), squad.time() + life, "mark:%d" % int(m["id"]))
	var b: BotBrain = squad._nearest_standing_brain(pos)
	if b != null and b.player.global_position.distance_to(pos) < float(_cfg.get("danger_callout_m", 40.0)):
		if b.mark == null:
			attach(b)
		b.mark._say(["MARK_DANGER"], pos + Vector3.UP * 1.2, "DANGER")
	_log("danger at %s (%s)" % [pos.snapped(Vector3.ONE), _where(pos)])


## REGROUP: every standing bot drops what it was ordered to do and comes to the spot.
func on_regroup(m: Dictionary) -> Dictionary:
	var pos: Vector3 = m["pos"]
	var id: int = int(m["id"])
	_regroup_id = id
	var n: int = 0
	for b: BotBrain in squad.brains:
		if b.player.downed or b.player.spectating:
			continue
		_replace(b, id, true)
		b.mark.start({"kind": "regroup", "mark_id": id, "pos": pos, "where": _where(pos), "label": "Regroup"})
		n += 1
	_log("regroup at %s: %d bots" % [_where(pos), n])
	return {"reason": "%d bots regrouping." % n if n > 0 else "No bot can come."}


## A danger or regroup mark went (the player, its time ran out).
func mark_removed(m: Dictionary, _why: String) -> void:
	var id: int = int(m.get("id", -1))
	match str(m.get("kind", "")):
		"danger":
			for z: Variant in squad.blackboard.danger_zones:
				if str((z as Dictionary).get("key", "")) == "mark:%d" % id:
					(z as Dictionary)["until"] = 0.0
		"regroup":
			for b: BotBrain in squad.brains:
				if b.mark != null and b.mark.active() and int(b.mark.order.get("mark_id", -1)) == id:
					b.mark.cancel("regroup removed", false)


## The order line for the pause map: the mark order, else the egg task, else what it is doing ("Idle").
func status_of(pid: int) -> String:
	var b: BotBrain = brain_of(pid)
	if b == null:
		return ""
	if b.player.spectating:
		return "Out"
	if b.player.downed:
		return "Down"
	if b.action == "revive" and b.revive_pid != 0:
		return "Reviving %s" % _name_of(b.revive_pid)
	if b.mark != null and b.mark.active():
		return b.mark.status()
	var t: Dictionary = squad.ee_task_of(pid)
	if not t.is_empty():
		return "Doing: %s" % str(t.get("label", ""))
	return "Idle"


func _name(b: BotBrain) -> String:
	return "Jakub" if b.player.is_companion else Net.display_name(b.player.player_id)


func _name_of(pid: int) -> String:
	if pid == JAKUB_PID:
		return "Jakub"
	if GameState.human_ids().has(pid):
		return "you" if pid == Net.local_player_id() else Net.display_name(pid)
	return Net.display_name(pid)


## The zone name at a spot ("Rail Yard"), else "the mark".
func _where(pos: Vector3) -> String:
	var ms: MapState = MapState.current()
	if ms == null:
		return ""
	var z: String = ms.data.zone_label_at(pos)
	return z


func report() -> PackedStringArray:
	var out: PackedStringArray = ["marks: orders %d (done %d, ended %d)" % [orders_given, orders_done, orders_failed]]
	for b: BotBrain in squad.brains:
		if b.mark != null and (b.mark.active() or b.mark.bought > 0):
			out.append("  %s: %s (bought %d, gave up %d, resumed %d)" % [_name(b), status_of(b.player.player_id), b.mark.bought, b.mark.gave_up, b.mark.resumed])
	for l: String in log_lines.slice(maxi(0, log_lines.size() - 12)):
		out.append("  MARK " + l)
	return out
