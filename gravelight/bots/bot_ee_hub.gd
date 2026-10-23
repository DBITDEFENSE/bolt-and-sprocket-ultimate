class_name BotEEHub
extends Node
## The squad's easter-egg help (Update 04 section 5, T-067), a child of the BotSquad (`squad.ee`):
##   - the setting "Bot Easter-Egg Help" (GLSettings bot_ee_help: off / ask / full), mode()
##   - what the squad has discovered (BotEEKnowledge, on the blackboard as `ee_known`), fed from the quest data's
##     "bot_knowledge" blocks (collected items, lines heard, steps done, flags, things seen) and a sight sweep: a
##     findable egg object (a task's find: seen / heard) is found once the player or a bot sees or hears it
##   - assignments (BotSquad.ee_assign / ee_can_assign / ee_task_of / ee_cancel / ee_assign_node call these): the
##     Objectives tab, a map mark, the ping key and the dev console all come here; pid -1 = the best available bot
##     (closest to the step, able, not busy reviving)
##   - Full Partner: every pick_every_s a free bot (at most full_max_bots at once) takes the best open step it can do
##   - the failed-egg counter (quest_step_failed while a bot works that step), the dev console's `ee_bot_assign` /
##     `ee_bot_mode` / `ee_bot_status`, and the report lines
## Each bot's task itself runs in its BotEE (bot_ee.gd).

var squad: BotSquad
var knowledge: BotEEKnowledge = BotEEKnowledge.new()
## Session override of the setting (dev console `ee_bot_mode`, tests, the soak); "" = the setting.
var mode_override: String = ""
## Telemetry (the soak): steps finished by bots, quest_step_failed events (and those on a step a bot was working).
var steps_by_bots: int = 0
var tasks_started: int = 0
var tasks_failed: int = 0
var egg_failures: int = 0
var egg_failures_bot: int = 0
var failure_log: PackedStringArray = []
var inputs_by_bots: int = 0

var _pool: Array = []
var _pool_t: float = -INF
var _sweep_t: float = 0.0
var _pick_t: float = 0.0
var _ray_rr: int = 0


func setup(s: BotSquad) -> void:
	squad = s
	name = "BotEE"
	squad.blackboard.ee_known = knowledge
	for b: BotBrain in squad.brains:
		attach(b)
	GLBus.quest_step_failed.connect(_on_step_failed)
	GLBus.quest_step_completed.connect(_on_step_completed)
	GLBus.vo_line_started.connect(_on_vo)
	GLBus.flag_changed.connect(_on_flag)
	_load_labels()
	QuestManager.quest_loaded.connect(_on_quest_loaded)
	var con: Node = get_node_or_null("/root/GLConsole")
	if con != null and con.has_method("register"):
		con.call("register", "ee_bot_assign", _cmd_assign, "ee_bot_assign <step> [quest] [bot pid]: give an easter-egg step to a bot (default: the best one); ee_bot_assign cancel")
		con.call("register", "ee_bot_mode", _cmd_mode, "ee_bot_mode off|ask|full: Bot Easter-Egg Help for this session (Off / When Asked / Full Partner)")
		con.call("register", "ee_bot_status", _cmd_status, "ee_bot_status: each bot's easter-egg task and what the squad has discovered")


## Gives a brain its BotEE (a companion joining later, too).
func attach(b: BotBrain) -> void:
	if b.ee == null:
		b.ee = BotEE.new()
		b.ee.setup(b)
	b.ee.hub = self


func mode() -> String:
	if mode_override != "":
		return mode_override
	return BotEECatalog.mode_of(GLSettings.values)


func set_mode(m: String) -> void:
	mode_override = BotEECatalog.mode_of({BotEECatalog.SETTING: m})
	if mode_override == "off":
		cancel(-1, "Bot Easter-Egg Help is off")
	elif mode_override == "ask":
		for b: BotBrain in squad.brains:
			if b.ee != null and b.ee.active() and str(b.ee.task.get("source", "")) == "full":
				b.ee.cancel("When Asked now")


# ================================================================== the public API (BotSquad wraps these)

## Gives the step to a bot: {"ok", "reason", "pid"}. pid -1 = the best available bot. `focus` = the object the
## player marked (that note, that bell); `source` = "ask" (Objectives tab / console), "mark", "ping".
func assign(qid: StringName, sid: StringName, pid: int = -1, focus: Node = null, source: String = "ask") -> Dictionary:
	if mode() == "off":
		return {"ok": false, "reason": "Bot Easter-Egg Help is off (Settings > Gameplay).", "pid": -1}
	if not QuestManager.has_quest(qid) or QuestManager.step_def(qid, sid).is_empty():
		return {"ok": false, "reason": "No such easter-egg step.", "pid": -1}
	var t: Dictionary = BotEECatalog.task_def(QuestManager.step_def(qid, sid))
	var cands: Array[BotBrain] = []
	for b: BotBrain in squad.brains:
		if pid < 0 or b.player.player_id == pid:
			cands.append(b)
	if cands.is_empty():
		return {"ok": false, "reason": "No such bot." if pid >= 0 else "No bots in the squad.", "pid": -1}
	var anchor: Vector3 = step_anchor(qid, sid, t, focus)
	var best: BotBrain = null
	var best_r: Dictionary = {}
	var best_d: float = INF
	var fail_b: BotBrain = null
	var fail_r: Dictionary = {}
	var fail_d: float = INF
	for b2: BotBrain in cands:
		var r: Dictionary = try_brain(b2, qid, sid, t, true, focus)
		var d: float = _dist(b2, anchor)
		if bool(r["ok"]) and (pid >= 0 or not _reviving(b2)):
			if d < best_d:
				best_d = d
				best = b2
				best_r = r
		elif d < fail_d or fail_b == null:
			fail_d = d
			fail_b = b2
			fail_r = r
	if best == null:
		if fail_b != null and fail_b.ee != null:
			fail_b.ee.say_cant(str(fail_r.get("code", "")))
		return {"ok": false, "reason": str(fail_r.get("reason", "Nobody can do that right now.")), "pid": fail_b.player.player_id if fail_b != null and pid >= 0 else -1}
	start_on(best, qid, sid, t, true, source, focus, str(best_r.get("as", "task")))
	return {"ok": true, "reason": str(best_r.get("reason", "")), "pid": best.player.player_id}


## Could any bot be given this step now (for the Objectives tab's "Assign to bot" button)?
func can_assign(qid: StringName, sid: StringName) -> bool:
	if mode() == "off" or not QuestManager.has_quest(qid):
		return false
	var step: Dictionary = QuestManager.step_def(qid, sid)
	if step.is_empty():
		return false
	var t: Dictionary = BotEECatalog.task_def(step)
	for b: BotBrain in squad.brains:
		if bool(try_brain(b, qid, sid, t, true, null)["ok"]):
			return true
	return false


## The bot's current task for status lines ({} none): {quest_id, step_id, type, label, state, paused, source, ordered, pid}.
func task_of(pid: int) -> Dictionary:
	for b: BotBrain in squad.brains:
		if b.player.player_id == pid and b.ee != null:
			return b.ee.describe()
	return {}


## Cancels the bot's task (pid -1: every bot's).
func cancel(pid: int = -1, why: String = "cancelled") -> void:
	for b: BotBrain in squad.brains:
		if b.ee != null and b.ee.active() and (pid < 0 or b.player.player_id == pid):
			b.ee.cancel(why)


## A map mark / the ping key on an egg object, part or power-up: finds the open step it belongs to and assigns it
## (the object becomes the task's focus: that note, that bell).
func assign_node(node: Node, pid: int = -1, source: String = "mark") -> Dictionary:
	if node == null or not is_instance_valid(node):
		return {"ok": false, "reason": "Nothing there.", "pid": -1}
	var probe: Node = node
	for _i: int in 5:
		if probe == null:
			break
		var hit: Array = step_of_node(probe)
		if not hit.is_empty():
			return assign(hit[0], hit[1], pid, probe, source)
		probe = probe.get_parent()
	return {"ok": false, "reason": "That isn't part of an open easter-egg step.", "pid": -1}


## [quest_id, step_id] of the open step whose bot_task names `node`, [] none.
func step_of_node(node: Node) -> Array:
	for qid: StringName in QuestManager.quest_ids():
		for step: Variant in QuestManager.steps_of(qid):
			var sd: Dictionary = step as Dictionary
			var sid: StringName = StringName(str(sd["id"]))
			if not QuestManager.is_active(qid, sid):
				continue
			var t: Dictionary = BotEECatalog.task_def(sd)
			for k: String in BotEECatalog.spec_keys():
				if t.get(k) is Dictionary and resolve(t[k]).has(node):
					return [qid, sid]
	return []


# ================================================================== the gate with the live state

## Can this brain do the step now? {"ok", "code", "reason", "as"}.
func try_brain(b: BotBrain, qid: StringName, sid: StringName, t: Dictionary, ordered: bool, focus: Node) -> Dictionary:
	if b.player.spectating or b.player.downed or not b.player.is_alive():
		return {"ok": false, "code": "down", "reason": "%s is down." % Net.display_name(b.player.player_id), "as": ""}
	var ctx: Dictionary = {"mode": mode(), "ordered": ordered, "active": QuestManager.is_active(qid, sid), "done": QuestManager.is_step_done(qid, sid),
		"companion": b.player.is_companion, "known": knowledge.known, "labels": knowledge.labels,
		"player_near": _human_within(step_anchor(qid, sid, t, focus), float(BotEECatalog.cfg().get("presence_m", 20.0))),
		"jakub": BotEECatalog.cfg().get("jakub", {})}
	var g: Dictionary = BotEECatalog.gate(t, ctx)
	if not bool(g["ok"]):
		return g
	if str(g.get("as", "")) == "escort":
		return g
	if b.ee == null:
		attach(b)
	var pv: Dictionary = b.ee.preview(qid, sid, t, ordered, focus)
	if not bool(pv["ok"]):
		var code: String = str(pv.get("code", "failed"))
		return {"ok": false, "code": code, "reason": reason_text(code, t), "as": ""}
	if not ordered and str(pv.get("do", "")) == "wait":
		return {"ok": false, "code": "wait", "reason": "Nothing to do on that one yet.", "as": ""}
	g["do"] = pv.get("do", "")
	return g


static func reason_text(code: String, t: Dictionary) -> String:
	var what: String = str(t.get("what", "it"))
	match code:
		"not_found":
			return "Can't do that yet: we haven't found %s." % what
		"unreachable":
			return "Can't reach %s from here (a door's in the way)." % what
		"no_upgraded":
			return "Needs an upgraded gun first (the Crucible)."
		"no_weapon":
			return "Needs the weapon first, and there's none to take."
		"risky":
			return "That could set the egg back: only on your word."
		"info":
			return "Can't do that yet: we don't know the answer."
		"done":
			return "That one's already done."
		"locked":
			return "That step isn't open yet."
	return "Can't do that right now."


func start_on(b: BotBrain, qid: StringName, sid: StringName, t: Dictionary, ordered: bool, source: String, focus: Node, as_kind: String) -> void:
	if b.ee == null:
		attach(b)
	tasks_started += 1
	b.ee.start(qid, sid, t, ordered, source, focus, as_kind)


func on_task_finished(_b: BotBrain, _t: Dictionary, ok: bool, _code: String) -> void:
	if not ok:
		tasks_failed += 1


## Is a teammate's egg task already going for this object (its plan's target or its claim)?
func targeted_by_other(n: Node, me: BotBrain) -> bool:
	for b: BotBrain in squad.brains:
		if b == me or b.ee == null or not b.ee.active():
			continue
		if b.ee._plan.get("node") == n or b.ee._claim_key == "ee:%d" % n.get_instance_id():
			return true
	return false


## Where a step happens (its first named object; the holdout / kill spot), INF unknown.
func step_anchor(qid: StringName, sid: StringName, t: Dictionary, focus: Node = null) -> Vector3:
	if focus is Node3D and is_instance_valid(focus):
		return (focus as Node3D).global_position
	for k: String in BotEECatalog.spec_keys():
		if t.get(k) is Dictionary:
			for n: Node in resolve(t[k]):
				if n is Node3D:
					return (n as Node3D).global_position
	var p: Dictionary = QuestManager.step_def(qid, sid).get("params", {})
	if p.has("center"):
		var c: Array = p["center"]
		return Vector3(float(c[0]), float(c[1]), float(c[2]))
	if p.has("points") and not (p["points"] as Array).is_empty():
		var a: Array = (p["points"] as Array)[0]
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.INF


# ================================================================== node specs and discoveries

## The nodes a node spec names (BotEECatalog.resolve over the map's Interactables, refreshed every 6 s).
func resolve(spec: Variant) -> Array[Node]:
	if not spec is Dictionary or squad == null or squad.map == null:
		return []
	if (spec as Dictionary).has("class") and squad.time() - _pool_t > 6.0:
		_pool_t = squad.time()
		_pool = squad.map.find_children("*", "Interactable", true, false)
	return BotEECatalog.resolve(spec, get_tree(), _pool)


func path_of(n: Node) -> String:
	if squad != null and squad.map != null and squad.map.is_ancestor_of(n):
		return str(squad.map.get_path_to(n))
	return str(n.get_path())


## Has the squad found this object (seen or heard it)?
func found(n: Node) -> bool:
	return knowledge.knows(BotEEKnowledge.seen_key(path_of(n)))


func _on_quest_loaded(_q: StringName) -> void:
	_load_labels()


func _load_labels() -> void:
	for qid: StringName in QuestManager.quest_ids():
		var bk: Dictionary = QuestManager.definition(qid).get("bot_knowledge", {})
		for k: Variant in bk.keys():
			knowledge.labels[str(k)] = str((bk[k] as Dictionary).get("label", k))


func _process(delta: float) -> void:
	if squad == null or GameState.phase != GameState.Phase.PLAYING:
		return
	var c: Dictionary = BotEECatalog.cfg()
	_sweep_t -= delta
	if _sweep_t <= 0.0:
		_sweep_t = float((c.get("sight", {}) as Dictionary).get("every_s", 0.5))
		_poll_knowledge()
		_sweep_sight()
	_pick_t -= delta
	if _pick_t <= 0.0:
		_pick_t = float(c.get("pick_every_s", 1.0))
		if mode() == "full":
			_full_partner()


## The quest data's bot_knowledge entries that are polled: on_collect, on_step, on_flag, on_seen.
func _poll_knowledge() -> void:
	var now: float = squad.time()
	for qid: StringName in QuestManager.quest_ids():
		var bk: Dictionary = QuestManager.definition(qid).get("bot_knowledge", {})
		for k: Variant in bk.keys():
			var key: String = str(k)
			if knowledge.knows(key):
				continue
			var e: Dictionary = bk[k]
			var how: String = BotEEHub.entry_due(qid, e)
			if how != "":
				knowledge.learn(key, 0, now, how)
				continue
			if e.get("on_seen") is Dictionary:
				var os: Dictionary = e["on_seen"]
				var n_seen: int = 0
				for n: Node in resolve(os):
					if found(n):
						n_seen += 1
				if n_seen >= int(os.get("count", 1)):
					knowledge.learn(key, 0, now, "seen")


## Is a bot_knowledge entry learned by the quest state now (on_collect / on_step / on_flag)? Its "how" ("" = not yet).
## Pure over the QuestManager and the flags (unit-tested).
static func entry_due(qid: StringName, e: Dictionary) -> String:
	if e.get("on_collect") is Dictionary:
		var oc: Dictionary = e["on_collect"]
		for step: Variant in QuestManager.steps_of(qid):
			var sd: Dictionary = step as Dictionary
			if str(sd.get("type", "")) != "collect" or str((sd.get("params", {}) as Dictionary).get("tag", "")) != str(oc.get("tag", "")):
				continue
			var got: Variant = QuestManager.progress(qid, StringName(str(sd["id"])))
			if got is Array and (got as Array).size() >= int(oc.get("count", 1)):
				return "collect"
	for st: Variant in e.get("on_step", []):
		if QuestManager.is_step_done(qid, StringName(str(st))):
			return "step"
	for f: Variant in e.get("on_flag", []):
		if GameState.has_flag(StringName(str(f))):
			return "flag"
	return ""


func _on_vo(line_id: StringName, _speaker: StringName, _text: String, _dur: float) -> void:
	for qid: StringName in QuestManager.quest_ids():
		var bk: Dictionary = QuestManager.definition(qid).get("bot_knowledge", {})
		for k: Variant in bk.keys():
			if ((bk[k] as Dictionary).get("on_vo", []) as Array).has(String(line_id)):
				knowledge.learn(str(k), 0, squad.time() if squad != null else 0.0, "heard")


func _on_flag(_f: StringName, _v: Variant) -> void:
	_sweep_t = minf(_sweep_t, 0.05)


func _on_step_completed(q: StringName, s: StringName) -> void:
	_sweep_t = minf(_sweep_t, 0.05)
	if squad == null:
		return
	_poll_knowledge()   # what the step taught (all three notes read) is known at once
	for b: BotBrain in squad.brains:
		if b.ee != null and b.ee.active() and b.ee.task["qid"] == q and b.ee.task["sid"] == s and str(b.ee.task.get("type", "")) != "escort":
			steps_by_bots += 1   # a step finished while a bot worked it (the player may have made the commit)
			return


## The objects to be found: every active step's findable targets and the on_seen specs.
func _findables() -> Array:
	var out: Array = []   # [node, hear_m (0 = sight)]
	var hear_d: float = float((BotEECatalog.cfg().get("sight", {}) as Dictionary).get("hear_m", 12.0))
	for qid: StringName in QuestManager.quest_ids():
		for step: Variant in QuestManager.steps_of(qid):
			var sd: Dictionary = step as Dictionary
			if not QuestManager.is_active(qid, StringName(str(sd["id"]))):
				continue
			var t: Dictionary = BotEECatalog.task_def(sd)
			var how: String = str(t.get("find", ""))
			if how == "":
				continue
			for k: String in ["targets", "pickups", "sequence"]:
				if t.get(k) is Dictionary:
					for n: Node in resolve(t[k]):
						out.append([n, float(t.get("hear_m", hear_d)) if how == "heard" else 0.0])
		var bk: Dictionary = QuestManager.definition(qid).get("bot_knowledge", {})
		for k2: Variant in bk.keys():
			if not knowledge.knows(str(k2)) and (bk[k2] as Dictionary).get("on_seen") is Dictionary:
				for n2: Node in resolve(bk[k2]["on_seen"]):
					out.append([n2, 0.0])
	return out


## Discovery sweep: a squad member within sight_m with a clear line of sight (or within hear_m of an audible one)
## finds the object. A few rays per sweep, round-robin.
func _sweep_sight() -> void:
	var sc: Dictionary = BotEECatalog.cfg().get("sight", {})
	var sight_m: float = float(sc.get("sight_m", 26.0))
	var budget: int = int(sc.get("rays_per_sweep", 10))
	var items: Array = _findables()
	if items.is_empty():
		return
	var obs: Array[Player] = squad.standing()
	var h: Player = squad.human()
	if h != null and is_instance_valid(h) and not h.spectating and not obs.has(h):
		obs.append(h)
	var now: float = squad.time()
	var n_items: int = items.size()
	for i: int in n_items:
		if budget <= 0:
			break
		var it: Array = items[(i + _ray_rr) % n_items]
		var n: Node3D = it[0] as Node3D
		if n == null or not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		var key: String = BotEEKnowledge.seen_key(path_of(n))
		if knowledge.knows(key):
			continue
		var hear: float = float(it[1])
		for p: Player in obs:
			var eye: Vector3 = p.head.global_position if p.head != null else p.global_position + Vector3.UP * 1.5
			var d: float = eye.distance_to(n.global_position)
			if hear > 0.0:
				var audible: bool = not (n is Interactable) or (n as Interactable).can_interact(p)
				if d <= hear and audible:
					knowledge.learn(key, p.player_id, now, "heard")
					break
				continue
			if d > sight_m:
				continue
			budget -= 1
			if _los(p, eye, n):
				knowledge.learn(key, p.player_id, now, "seen")
				break
			if budget <= 0:
				break
	_ray_rr += 1


func _los(p: Player, eye: Vector3, n: Node3D) -> bool:
	var to: Vector3 = n.global_position + Vector3.UP * 0.1
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, to, BotPerception.MASK_LOS, [p.get_rid()])
	var res: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	if res.is_empty():
		return true
	var col: Object = res["collider"]
	if col is Node and (col == n or n.is_ancestor_of(col as Node) or (col as Node).is_ancestor_of(n)):
		return true
	return (res["position"] as Vector3).distance_to(to) < 0.8


# ================================================================== Full Partner

## A free bot takes the best open step it can do (one task each, at most full_max_bots at once, never one a teammate
## works unless it has several targets).
func _full_partner() -> void:
	var c: Dictionary = BotEECatalog.cfg()
	var cap: int = int(c.get("full_max_bots", 2))
	var busy: int = 0
	var taken: Dictionary = {}   # "qid/sid" -> true for single-worker steps
	for b: BotBrain in squad.brains:
		if b.ee != null and b.ee.active():
			busy += 1
			var ty: String = str(b.ee.task.get("type", ""))
			if ty != "collect" and not (ty == "carry" and (b.ee.task["def"] as Dictionary).has("pickups")):
				taken["%s/%s" % [b.ee.task["qid"], b.ee.task["sid"]]] = true
	if busy >= cap:
		return
	var sc: Dictionary = c.get("scores", {})
	var qids: Array[StringName] = QuestManager.quest_ids()
	for b2: BotBrain in squad.brains:
		if busy >= cap:
			return
		if b2.ee == null or b2.ee.active() or b2.player.downed or b2.player.spectating or _reviving(b2):
			continue
		var best: Dictionary = {}
		for qi: int in qids.size():
			var qid: StringName = qids[qi]
			if QuestManager.is_complete(qid):
				continue
			var base: float = float(sc.get("main_quest", 70.0)) if qi == 0 else float(sc.get("side_quest", 52.0))
			for step: Variant in QuestManager.steps_of(qid):
				var sd: Dictionary = step as Dictionary
				var sid: StringName = StringName(str(sd["id"]))
				if not QuestManager.is_active(qid, sid) or taken.has("%s/%s" % [qid, sid]):
					continue
				var t: Dictionary = BotEECatalog.task_def(sd)
				if t.is_empty():
					continue
				var r: Dictionary = try_brain(b2, qid, sid, t, false, null)
				if not bool(r["ok"]):
					continue
				var a: Vector3 = step_anchor(qid, sid, t)
				var s: float = base + float(sc.get(str(t.get("type", "")), 0.0)) - float(sc.get("per_m", 0.25)) * minf(_dist(b2, a), 120.0)
				if str(r.get("as", "")) == "escort":
					s -= 10.0
				if best.is_empty() or s > float(best["s"]):
					best = {"s": s, "qid": qid, "sid": sid, "t": t, "as": str(r.get("as", "task"))}
		if not best.is_empty():
			start_on(b2, best["qid"], best["sid"], best["t"], false, "full", null, best["as"])
			busy += 1
			if str(best["as"]) == "escort" or (str((best["t"] as Dictionary).get("type", "")) != "collect" and not (best["t"] as Dictionary).has("pickups")):
				taken["%s/%s" % [best["qid"], best["sid"]]] = true


# ================================================================== events and telemetry

func _on_step_failed(qid: StringName, sid: StringName, reason: StringName) -> void:
	egg_failures += 1
	var bot: String = ""
	for b: BotBrain in squad.brains:
		if b.ee != null and b.ee.active() and b.ee.task["qid"] == qid and b.ee.task["sid"] == sid:
			bot = Net.display_name(b.player.player_id)
	if bot != "":
		egg_failures_bot += 1
	var line: String = "%.0fs %s/%s failed (%s)%s" % [squad.time(), qid, sid, reason, (" while %s worked it" % bot) if bot != "" else ""]
	failure_log.append(line)
	print("[ee] " + line)


func report() -> PackedStringArray:
	var out: PackedStringArray = ["ee: mode %s, tasks started %d, failed %d, steps finished by bots %d, inputs %d, egg failures %d (%d on a bot's step)" % [mode(),
		tasks_started, tasks_failed, steps_by_bots, inputs_by_bots, egg_failures, egg_failures_bot]]
	out.append("  " + knowledge.describe()[0])
	for b: BotBrain in squad.brains:
		if b.ee != null:
			var d: Dictionary = b.ee.describe()
			out.append("  %s: %s (done %d, stopped %d)" % [Net.display_name(b.player.player_id), str(d.get("label", "no egg task")), b.ee.done_count, b.ee.failed_count])
	for f: String in failure_log.slice(maxi(0, failure_log.size() - 8)):
		out.append("  EGG FAIL " + f)
	return out


func _reviving(b: BotBrain) -> bool:
	return b.revive_pid != 0 or b.action == "revive"


func _dist(b: BotBrain, a: Vector3) -> float:
	if a == Vector3.INF:
		return 0.0
	return Vector2(a.x - b.player.global_position.x, a.z - b.player.global_position.z).length()


func _human_within(a: Vector3, r: float) -> bool:
	var h: Player = squad.human()
	if a == Vector3.INF or h == null or not is_instance_valid(h) or h.spectating:
		return false
	return Vector2(a.x - h.global_position.x, a.z - h.global_position.z).length() <= r


# ================================================================== dev console

func _cmd_mode(a: PackedStringArray) -> String:
	if a.is_empty():
		return "Bot Easter-Egg Help: %s (ee_bot_mode off|ask|full)" % mode()
	set_mode(a[0])
	return "Bot Easter-Egg Help: %s (this session)" % BotEECatalog.MODE_LABELS[BotEECatalog.MODES.find(mode())]


func _cmd_assign(a: PackedStringArray) -> String:
	if a.is_empty():
		return "ee_bot_assign <step> [quest] [bot pid] | ee_bot_assign cancel [pid]"
	if a[0] == "cancel":
		cancel(int(a[1]) if a.size() > 1 else -1, "cancelled (console)")
		return "egg tasks cancelled"
	var sid: StringName = StringName(a[0])
	var qid: StringName = StringName(a[1]) if a.size() > 1 and not a[1].is_valid_int() else &""
	var pid: int = -1
	for x: String in a.slice(1):
		if x.is_valid_int():
			pid = int(x)
	if qid == &"":
		for q: StringName in QuestManager.quest_ids():
			if not QuestManager.step_def(q, sid).is_empty():
				qid = q
				break
	if qid == &"":
		return "no step '%s' in the loaded quests" % sid
	var r: Dictionary = assign(qid, sid, pid, null, "console")
	return "%s/%s -> %s: %s" % [qid, sid, ("P%d" % int(r["pid"])) if bool(r["ok"]) else "refused", str(r["reason"]) if str(r["reason"]) != "" else "ok"]


func _cmd_status(_a: PackedStringArray) -> String:
	return "\n".join(report())
