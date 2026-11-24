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
var _final_first_t: Dictionary = {}   # "qid/sid" -> squad time a bot first could have started a final step (T-086)
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
		"player_near": _human_within(step_anchor(qid, sid, t, focus), float(BotEECatalog.cfg().get("presence_m", 20.0))) or final_wait_over(qid, sid),
		"jakub": BotEECatalog.cfg().get("jakub", {}), "agent": b.is_player_bot, "player_absent": _player_absent()}
	var g: Dictionary = BotEECatalog.gate(t, ctx)
	if not bool(g["ok"]):
		if str(g.get("code", "")) == "needs_player" and not _final_first_t.has("%s/%s" % [qid, sid]):
			_final_first_t["%s/%s" % [qid, sid]] = squad.time()   # T-086: the wait for the player starts now
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


## U08 (T-131): the human player is away from the egg: benched (a bots-alone soak), bled out, or down.
func _player_absent() -> bool:
	var h: Player = squad.human()
	return h == null or not is_instance_valid(h) or h.spectating or h.downed


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
		# U10 T-172: Full Partner leaves a step this bot just failed to reach alone for a while (the Four Bells
		# started and stopped "unreachable" 340 times in one soak, every pick)
		if str(_t.get("source", "")) == "full" and _code in ["unreachable", "missed", "not_found"] and squad != null:
			_backoff["%d/%s/%s" % [_b.player.player_id, _t["qid"], _t["sid"]]] = squad.time() + float(BotEECatalog.cfg().get("retry_after_s", 45.0))
			if str(_t.get("type", "")) == "scout" and _code == "not_found":
				_scout_off_until = squad.time() + float(BotEECatalog.cfg().get("retry_after_s", 45.0))   # the map was walked: a rest for every scout

var _backoff: Dictionary = {}
var _scout_off_until: float = -INF


## Did this bot just fail this step (Full Partner's retry_after_s back-off)?
func backed_off(b: BotBrain, qid: StringName, sid: StringName) -> bool:
	return squad != null and float(_backoff.get("%d/%s/%s" % [b.player.player_id, qid, sid], -INF)) > squad.time()


## Is a teammate's egg task already going for this object (its plan's target or its claim)?
func targeted_by_other(n: Node, me: BotBrain) -> bool:
	for b: BotBrain in squad.brains:
		if b == me or b.ee == null or not b.ee.active():
			continue
		if b.ee._plan.get("node") == n or b.ee._claim_key == "ee:%d" % n.get_instance_id():
			return true
	return false


## T-086: has a final step waited long enough for the player (ee.json full_final_wait_s) that the bots go on alone?
func final_wait_over(qid: StringName, sid: StringName) -> bool:
	var key: String = "%s/%s" % [qid, sid]
	if not _final_first_t.has(key) or squad == null:
		return false
	return BotEECatalog.final_wait_over(squad.time() - float(_final_first_t[key]), BotEECatalog.cfg())


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
		_pool = interactables_of(squad.map)
	return BotEECatalog.resolve(spec, get_tree(), _pool)


## Every Interactable under `map`, in tree order: what map.find_children("*", "Interactable", true, false) gave,
## from the group each Interactable joins when it is made, so no walk over the map's every node (T-265).
static func interactables_of(map: Node) -> Array[Node]:
	var out: Array[Node] = []
	if map == null or not map.is_inside_tree():
		return out
	for n: Node in map.get_tree().get_nodes_in_group(&"interactables"):
		if map.is_ancestor_of(n):
			out.append(n)
	return out


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


var _sweep_due: bool = false   # the sight sweep owed since last frame's knowledge poll (T-265)


func _process(delta: float) -> void:
	if squad == null or GameState.phase != GameState.Phase.PLAYING:
		return
	var c: Dictionary = BotEECatalog.cfg()
	# T-265: the knowledge poll one frame, the sight sweep the next (both still every sight.every_s): together
	# they were the squad's dearest frame twice a second (each walks every quest's steps and resolves its nodes)
	if _sweep_due:
		_sweep_due = false
		_sweep_sight()
	_sweep_t -= delta
	if _sweep_t <= 0.0:
		_sweep_t = float((c.get("sight", {}) as Dictionary).get("every_s", 0.5))
		_poll_knowledge()
		_sweep_due = true
	_pick_t -= delta
	if _pick_t <= 0.0:
		_pick_t = float(c.get("pick_every_s", 1.0))
		if mode() == "full":
			_full_partner()
		_escorts()


## The quest data's bot_knowledge entries that are polled: on_collect, on_step, on_flag, on_power (U08), on_seen.
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
	if bool(e.get("on_power", false)) and GameState.power_on:
		return "power"   # U08 (T-131): the map's power is on (Groom Lake's radar shack radio needs it)
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
			if rally_now(b.ee.task["def"]):
				cap = squad.brains.size()   # U10 (T-163): the Chapel bell is lit: everyone free joins the hold
				continue
			if ty != "collect" and not (ty == "carry" and (b.ee.task["def"] as Dictionary).has("pickups")):
				taken["%s/%s" % [b.ee.task["qid"], b.ee.task["sid"]]] = true
	_main_first(taken)
	if _hold_rally():
		return   # U10 T-172: everyone free goes to the hold
	_scout_first(busy >= cap)
	if busy >= cap:
		return
	var now: float = squad.time()
	for b2: BotBrain in squad.brains:
		if busy >= cap:
			return
		if b2.ee == null or b2.ee.active() or b2.player.downed or b2.player.spectating or _reviving(b2):
			continue
		if b2.player.is_companion:
			continue   # Jakub stays at the side of the one he covers: egg work only when asked
		if b2.mark != null and b2.mark.active():
			continue   # on the player's map-mark order (T-069)
		if _escort_of.has(b2.player.player_id):
			continue   # U10 T-172: escorting a teammate on a far errand
		if b2.ee.between_steps_shop(now):
			continue   # U10 T-172: a rich bot stocks up before its next step
		var best: Dictionary = pick_for(b2, taken, false)
		var sj: Dictionary = scout_job()
		if not sj.is_empty() and backed_off(b2, sj["qid"], sj["sid"]):
			sj = {}   # this bot just walked the map for it and found nothing
		if not sj.is_empty() and (best.is_empty() or str((best["t"] as Dictionary).get("type", "")) == "collect" or best["qid"] != sj["qid"]):
			best = sj   # U10 (T-163; T-172: before a collect step or a side quest too): a "seen" need: go and look
		if not best.is_empty():
			start_on(b2, best["qid"], best["sid"], best["t"], false, "full", null, best["as"])
			busy += 1
			if str(best["as"]) == "escort" or (str((best["t"] as Dictionary).get("type", "")) != "collect" and not (best["t"] as Dictionary).has("pickups")):
				taken["%s/%s" % [best["qid"], best["sid"]]] = true


## U10 T-172: the scout before a collect step. When a "seen" need waits (the Four Bells) and nobody scouts: with every
## egg slot taken (`full`), a Full Partner bot on a collect step drops it for the scout (two bots on the radios kept
## the scout from ever starting, and the squad never saw all four little bells).
func _scout_first(full: bool) -> void:
	if not full:
		return
	var sj: Dictionary = scout_job()
	if sj.is_empty():
		return
	var pick: BotBrain = null
	for b: BotBrain in squad.brains:
		if b.ee == null or not b.ee.active() or str(b.ee.task.get("source", "")) != "full" or b.player.is_companion:
			continue
		if backed_off(b, sj["qid"], sj["sid"]):
			continue
		var side: bool = b.ee.task["qid"] != sj["qid"]
		if str(b.ee.task.get("type", "")) != "collect" and not side:
			continue
		if pick == null or side or str(b.ee._plan.get("do", "")) == "wait":
			pick = b
	if pick != null:
		pick.ee.cancel("the scout first")
		start_on(pick, sj["qid"], sj["sid"], sj["t"], false, "full", null, "task")


## U10 T-172 (ee.json hold_rally): a bot holds a running main-egg hold, or waits at one it is about to start (from
## gather_from_round): every other squad bot that is free or on a Full Partner errand it can leave (not a hold of its
## own, a carry, an input or a door) joins that step on the same anchor, all at once (no egg-bot cap). One diesel
## hold runs at a time: the bots walked off to the next diesel and the holder died alone. True = a rally is on.
var _rally_seen_t: float = -INF

func _hold_rally() -> bool:
	var hr: Dictionary = BotEECatalog.cfg().get("hold_rally", {})
	if hr.is_empty() or RoundManager.current_round < int(hr.get("from_round", 1)):
		return false
	var qids: Array[StringName] = QuestManager.quest_ids()
	if qids.is_empty():
		return false
	var lead: BotBrain = null
	var at: Node3D = null
	for b: BotBrain in _rally_lead_order():
		if b.ee == null or not b.ee.active() or b.ee.task["qid"] != qids[0] or str(b.ee.task.get("type", "")) != "hold_zone":
			continue
		if b.player.downed or b.player.spectating:
			continue
		if bool(b.ee.task.get("rally", false)) and not b.ee.holding_now():
			continue   # a joiner leads only while it holds the running anchor itself (the lead went down: it stays)
		var n: Node3D = b.ee.gathering_at()
		if n == null and str(b.ee._plan.get("do", "")) == "use" and str(b.ee.task.get("source", "")) == "full" and not b.is_player_bot \
				and RoundManager.current_round >= int(hr.get("gather_from_round", 6)) and is_instance_valid(b.ee._plan.get("node")):
			n = b.ee._plan.get("node") as Node3D   # on its way to start one: the others come along (no cancel churn)
		var holding: bool = n == null and b.ee.holding_now()
		if holding:
			n = b.ee._plan.get("node") as Node3D if is_instance_valid(b.ee._plan.get("node")) else null   # (null: a holdout's zone)
		if n != null or holding:
			lead = b
			at = n
			break
	var now: float = squad.time()
	if lead == null:
		# the hold is over (or never started): the joiners go back to the squad a few seconds later
		if now - _rally_seen_t > 6.0:
			for b3: BotBrain in squad.brains:
				if b3.ee != null and b3.ee.active() and bool(b3.ee.task.get("rally", false)):
					b3.ee.cancel("the hold is over")
		return false
	_rally_seen_t = now
	for b2: BotBrain in squad.brains:
		if b2 == lead or b2.ee == null or b2.is_player_bot or b2.player.is_companion or b2.player.downed or b2.player.spectating or _reviving(b2):
			continue
		if b2.mark != null and b2.mark.active():
			continue
		if b2.ee.active():
			var tk: Dictionary = b2.ee.task
			if tk["qid"] == lead.ee.task["qid"] and tk["sid"] == lead.ee.task["sid"]:
				# already on it: a joiner follows the lead to its next anchor (pylon 1 done, the lead walks to 2)
				if bool(tk.get("rally", false)) and at != null and tk.get("focus") != at and str(b2.ee._plan.get("do", "")) != "hold":
					tk["focus"] = at
					b2.ee._replan = true
				continue
			if str(tk.get("source", "")) != "full" or bool(tk.get("ordered", false)):
				continue   # the player's own order
			var d: String = str(b2.ee._plan.get("do", ""))
			if str(tk.get("type", "")) == "carry" or d in ["hold", "input", "door", "handoff", "turn"]:
				continue
			b2.ee.cancel("to the hold")
		start_on(b2, lead.ee.task["qid"], lead.ee.task["sid"], lead.ee.task["def"], false, "full", at, "task")
		b2.ee.task["rally"] = true
	return true


## The rally's lead candidates: the bots on their own hold first, then the joiners (one holding the anchor leads
## once the lead is down or out, so the others aren't sent home from a charging hold).
func _rally_lead_order() -> Array[BotBrain]:
	var own: Array[BotBrain] = []
	var joined: Array[BotBrain] = []
	for b: BotBrain in squad.brains:
		if b.ee != null and b.ee.active() and bool(b.ee.task.get("rally", false)):
			joined.append(b)
		else:
			own.append(b)
	own.append_array(joined)
	return own


## U10 T-172 (ee.json together.escort): in a hot round a Full Partner bot whose errand takes it away from everyone
## (the Four Bells' far vantages: it paused "apart" 140 times in a soak and never fired a shot) gets a free bot as
## its escort (the brain's escort_pid, Jakub's follow-and-cover), so it is never alone; the escort goes back to the
## squad when the errand ends, the bot is down or the round cools. Only escorts this hub set are ever cleared.
var _escort_of: Dictionary = {}   # escort pid -> escorted pid

func _escorts() -> void:
	var tg: Dictionary = BotEECatalog.cfg().get("together", {})
	var on: bool = bool(tg.get("escort", false)) and mode() == "full" and RoundManager.current_round >= int(tg.get("from_round", 9)) \
		and RoundManager.state == RoundManager.State.ROUND
	# end the escorts that are no longer needed
	for epid: Variant in _escort_of.keys():
		var eb: BotBrain = _brain_of(int(epid))
		var tb: BotBrain = _brain_of(int(_escort_of[epid]))
		var keep: bool = on and eb != null and tb != null and tb.ee != null and tb.ee.active() and not tb.player.downed and not tb.player.spectating \
			and not eb.player.downed and not (eb.ee != null and eb.ee.active())
		if not keep:
			if eb != null and int(eb.options.get("escort_pid", 0)) == int(_escort_of[epid]):
				eb.options["escort_pid"] = 0
			_escort_of.erase(epid)
	if not on:
		return
	var max_m: float = float(tg.get("max_m", 24.0))
	for b: BotBrain in squad.brains:
		if b.ee == null or not b.ee.active() or str(b.ee.task.get("source", "")) != "full" or bool(b.ee.task.get("rally", false)) or b.is_player_bot:
			continue
		if b.player.downed or b.player.spectating or _escort_of.values().has(b.player.player_id):
			continue
		var a: Vector3 = b.ee.anchor()
		if a == Vector3.INF:
			continue
		var na: Array = nearest_teammate(squad, b.player, a)
		if float(na[0]) <= max_m:
			continue   # its spot is by the squad anyway
		var pick: BotBrain = null
		var pick_d: float = INF
		for c: BotBrain in squad.brains:
			if c == b or c.is_player_bot or c.player.is_companion or c.player.downed or c.player.spectating or _reviving(c):
				continue
			if (c.ee != null and c.ee.active()) or (c.mark != null and c.mark.active()) or _escort_of.has(c.player.player_id) or int(c.options.get("escort_pid", 0)) != 0:
				continue
			var d: float = _dist(c, b.player.global_position)
			if d < pick_d:
				pick_d = d
				pick = c
		if pick != null:
			pick.options["escort_pid"] = b.player.player_id
			_escort_of[pick.player.player_id] = b.player.player_id
			print("[ee] %s: escorting %s (%s)" % [Net.display_name(pick.player.player_id), Net.display_name(b.player.player_id), str((b.ee.task["def"] as Dictionary).get("what", "the egg"))])


func _brain_of(pid: int) -> BotBrain:
	for b: BotBrain in squad.brains:
		if b.player.player_id == pid:
			return b
	return null


## U10 T-172: the nearest standing teammate (bot, companion or human; not `me`) to `p`: [flat metres, |dy|] (INF, INF none).
static func nearest_teammate(sq: BotSquad, me: Player, p: Vector3) -> Array:
	var best: float = INF
	var best_dy: float = INF
	for q: Player in sq.all_players():
		if q == me or not is_instance_valid(q) or q.downed or q.spectating or not q.is_alive():
			continue
		var d: float = Vector2(q.global_position.x - p.x, q.global_position.z - p.z).length()
		if d < best:
			best = d
			best_dy = absf(q.global_position.y - p.y)
	return [best, best_dy]


## U10 T-172 (ee.json start_wait_s): a hold whose start waits for the player near it (the pylons) is started by the
## bots after start_wait_s in Full Partner, in a round break or before together.from_round.
var _start_wait_t: Dictionary = {}

func note_start_wait(qid: StringName, sid: StringName) -> void:
	var key: String = "%s/%s" % [qid, sid]
	if not _start_wait_t.has(key) and squad != null:
		_start_wait_t[key] = squad.time()


func start_wait_over(qid: StringName, sid: StringName) -> bool:
	var key: String = "%s/%s" % [qid, sid]
	if mode() != "full" or not _start_wait_t.has(key) or squad == null:
		return false
	var c: Dictionary = BotEECatalog.cfg()
	if squad.time() - float(_start_wait_t[key]) < float(c.get("start_wait_s", 30.0)):
		return false
	var tg: Dictionary = c.get("together", {})
	return RoundManager.state != RoundManager.State.ROUND or RoundManager.current_round < int(tg.get("from_round", 9))


## U10 T-172 (ee.json egg_gun): the squad bot that should feed a gun to the Crucible for the egg now (0 none): a
## main-egg step that needs an upgraded gun is still to come, no squad bot carries a taught gun, and this is the
## richest bot with a long gun the Crucible can teach. Cached 2 s.
var _egg_gun_t: float = -INF
var _egg_gun_pid: int = 0

func egg_gun_pid() -> int:
	if squad == null:
		return 0
	var now: float = squad.time()
	if now - _egg_gun_t < 2.0:
		return _egg_gun_pid
	_egg_gun_t = now
	_egg_gun_pid = 0
	var eg: Dictionary = BotEECatalog.cfg().get("egg_gun", {})
	if not bool(eg.get("enabled", false)) or mode() == "off":
		return 0
	var qids: Array[StringName] = QuestManager.quest_ids()
	if qids.is_empty() or QuestManager.is_complete(qids[0]):
		return 0
	var needed: bool = false
	for st: Variant in QuestManager.steps_of(qids[0]):
		var sd: Dictionary = st as Dictionary
		if bool(BotEECatalog.task_def(sd).get("need_upgraded", false)) and not QuestManager.is_step_done(qids[0], StringName(str(sd["id"]))):
			needed = true
	if not needed:
		return 0
	for b0: BotBrain in squad.brains:
		if b0.is_player_bot or b0.player.is_companion or not is_instance_valid(b0.player):
			continue
		for w: WeaponInstance in b0.player.weapons.slots:
			if w.upgraded and w.weapon_class() != &"wonder":
				_egg_gun_was = 0
				return 0   # one of us has one (checked before any pick, so the cache never keeps a stale bot)
	var best_s: int = -1
	var keep: int = _egg_gun_was
	var keep_ok: bool = false
	for b: BotBrain in squad.brains:
		if b.is_player_bot or b.player.is_companion or not is_instance_valid(b.player):
			continue
		if b.player.downed or b.player.spectating:
			continue
		var slot: int = b._upgradeable_slot()
		if slot < 0:
			continue
		var cls: StringName = b.player.weapons.slots[slot].weapon_class()
		if cls == &"pistol" or cls == &"wonder":
			continue
		if b.player.player_id == keep:
			keep_ok = true
		var sc: int = Economy.get_scrip(b.player.player_id)
		if sc > best_s:
			best_s = sc
			_egg_gun_pid = b.player.player_id
	if keep_ok:
		_egg_gun_pid = keep   # the one already saving stays the one
	_egg_gun_was = _egg_gun_pid
	return _egg_gun_pid

var _egg_gun_was: int = 0


## U10 (T-163): a Full Partner bot on a side quest drops it for an open main-egg step it can do now (it took the
## Song's cylinders at round 1 because the power switch was still behind doors, and kept them for eight rounds).
func _main_first(taken: Dictionary) -> void:
	var qids: Array[StringName] = QuestManager.quest_ids()
	if qids.is_empty() or QuestManager.is_complete(qids[0]):
		return
	for b: BotBrain in squad.brains:
		if b.ee == null or not b.ee.active() or str(b.ee.task.get("source", "")) != "full" or b.ee.task["qid"] == qids[0]:
			continue
		var best: Dictionary = pick_for(b, taken, false)
		if best.is_empty() or best["qid"] != qids[0]:
			continue
		b.ee.cancel("the main egg first")
		start_on(b, best["qid"], best["sid"], best["t"], false, "full", null, best["as"])
		if str(best["as"]) == "escort" or (str((best["t"] as Dictionary).get("type", "")) != "collect" and not (best["t"] as Dictionary).has("pickups")):
			taken["%s/%s" % [best["qid"], best["sid"]]] = true


## U10 (T-163): the main egg's open step blocked only by a "seen" need nobody has found (the Four Bells: "found
## where the four little bells hang", learned by seeing them): one free Full Partner bot scouts the open zones.
## {} when there is none, or someone already scouts.
func scout_job() -> Dictionary:
	if squad != null and squad.time() < _scout_off_until:
		return {}   # U10: a scout just walked every open zone and found nothing: not again at once
	for b: BotBrain in squad.brains:
		if b.ee != null and b.ee.active() and str(b.ee.task.get("type", "")) == "scout":
			return {}
	var qids: Array[StringName] = QuestManager.quest_ids()
	if qids.is_empty() or QuestManager.is_complete(qids[0]):
		return {}
	var qid: StringName = qids[0]
	for st: Variant in QuestManager.steps_of(qid):
		var sd: Dictionary = st as Dictionary
		var sid: StringName = StringName(str(sd["id"]))
		if not QuestManager.is_active(qid, sid):
			continue
		var t: Dictionary = BotEECatalog.task_def(sd)
		for need: Variant in BotEECatalog.missing_info(t, knowledge.known):
			if _seen_need(str(need)):
				return {"qid": qid, "sid": sid, "t": {"type": "scout", "need": str(need), "what": str(knowledge.labels.get(str(need), "what we haven't found"))}, "as": "task"}
		# T-181: a collect step whose things are found by ear or eye (find: heard / seen: Requiem's calling radios)
		# with none known left to take and some still unfound: scout for them too (T-172: "the scout walks for seen
		# needs only", so a radio never heard kept s2b and s8a locked for the rest of the match)
		if collect_scout_due(qid, sid, t):
			return {"qid": qid, "sid": sid, "t": {"type": "scout", "need": "", "find_step": true, "of": t, "what": str(t.get("what", "what we haven't found"))}, "as": "task"}
	return {}


## T-181: a find: heard / seen collect step with nothing known left to take and something still to find.
func collect_scout_due(qid: StringName, sid: StringName, t: Dictionary) -> bool:
	if str(t.get("type", "")) != "collect" or str(t.get("find", "")) == "" or not (t.get("targets") is Dictionary):
		return false
	var taken: Array = []
	var prog: Variant = QuestManager.progress(qid, sid)
	if prog is Array:
		for g: Variant in prog:
			taken.append(str(g))
	var stand: Array[Player] = squad.standing() if squad != null else []
	var who: Player = stand[0] if not stand.is_empty() else null
	var unknown: int = 0
	for n: Node in resolve(t["targets"]):
		var n3: Node3D = n as Node3D
		if n3 == null or not n3.is_visible_in_tree() or taken.has(BotEECatalog.target_id(n3, t)):
			continue
		if n3 is Interactable and who != null and not (n3 as Interactable).can_interact(who):
			continue   # (a radio that is not calling: not one of this match's three)
		if knowledge.knows(BotEEKnowledge.seen_key(path_of(n3))):
			return false   # a known one is still to take: the collectors do that
		unknown += 1
	return unknown > 0


## Is a bot_knowledge key one learned by seeing things (on_seen)?
func _seen_need(key: String) -> bool:
	for q: StringName in QuestManager.quest_ids():
		var bk: Dictionary = QuestManager.definition(q).get("bot_knowledge", {})
		if bk.has(key) and (bk[key] as Dictionary).get("on_seen") is Dictionary:
			return true
	return false


## U10 (T-163): a lit shoot_target with a then_hold (the Chapel bell: the Foreman comes 20 s later and must die in
## the Chapel within the light) is a rally: every free bot joins the hold, not one.
static func rally_now(t: Dictionary) -> bool:
	return t.has("then_hold") and str(t.get("lit_flag", "")) != "" and GameState.has_flag(StringName(str(t["lit_flag"])))


## U10 (T-163): the zone an armed kill condition wants `enemy_id` killed in ({} none): an active kill_condition
## step with a zone and a world flag that is on now (the Requiem's s4: the Foreman, in F_CHAPEL, the bell lit).
## Shot on its way in, it dies outside the zone and the step fails, so the bots hold fire until it is inside.
var _kz_t: float = -INF
var _kz: Dictionary = {}

func kill_zone_for(enemy_id: StringName) -> StringName:
	var now: float = squad.time()
	if now - _kz_t >= 0.5:
		_kz_t = now
		_kz = {}
		for qid: StringName in QuestManager.quest_ids():
			for st: Variant in QuestManager.steps_of(qid):
				var sd: Dictionary = st as Dictionary
				if str(sd.get("type", "")) != "kill_condition" or not QuestManager.is_active(qid, StringName(str(sd["id"]))):
					continue
				var p: Dictionary = sd.get("params", {})
				if p.has("zone") and p.has("world_flag") and GameState.has_flag(StringName(str(p["world_flag"]))):
					_kz[StringName(str(p.get("enemy", "")))] = StringName(str(p["zone"]))
	return _kz.get(enemy_id, &"")


## The best open step this brain can do now ({} none): {s, qid, sid, t, as}. Full Partner's pick, and the
## bot-mode agent's (AgentPlan, T-086: `ordered` true, the agent is the player). `taken`: "qid/sid" keys other
## bots already work.
func pick_for(b: BotBrain, taken: Dictionary, ordered: bool) -> Dictionary:
	var sc: Dictionary = BotEECatalog.cfg().get("scores", {})
	var tg: Dictionary = BotEECatalog.cfg().get("together", {})
	var hot: bool = not b.is_player_bot and BotEE.hot_round(tg, _round_left()) and not b.in_break() \
		and (b.perception.pressure >= float(tg.get("pressure", 0.25)) or b.perception.count_near(b.player.global_position, float(tg.get("threat_m", 12.0))) >= int(tg.get("threat_n", 2)))
	var qids: Array[StringName] = QuestManager.quest_ids()
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
			if not ordered and backed_off(b, qid, sid):
				continue   # U10 T-172: just failed it: later
			var t: Dictionary = BotEECatalog.task_def(sd)
			if t.is_empty():
				continue
			var a: Vector3 = step_anchor(qid, sid, t)
			if not ordered and hot and a != Vector3.INF:
				var na: Array = nearest_teammate(squad, b.player, a)
				if BotEE.apart_rule(tg, true, false, (tg.get("exempt_types", []) as Array).has(str(t.get("type", ""))), float(na[0]), float(na[1])):
					continue   # U10 T-172 (ee.json together): not off alone mid-round in a hot round
			var r: Dictionary = try_brain(b, qid, sid, t, ordered, null)
			if not bool(r["ok"]):
				continue
			# (U10 T-172: a bot_task `priority` adds to the score: the pylons once the power is on)
			var s: float = base + float(sc.get(str(t.get("type", "")), 0.0)) + float(t.get("priority", 0.0)) - float(sc.get("per_m", 0.25)) * minf(_dist(b, a), 120.0)
			if str(r.get("as", "")) == "escort":
				s -= 10.0
			if best.is_empty() or s > float(best["s"]):
				best = {"s": s, "qid": qid, "sid": sid, "t": t, "as": str(r.get("as", "task"))}
	return best


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


## The zombies left once the round spawns no more (-1 while it still spawns), for BotEE.hot_round.
func _round_left() -> int:
	if RoundManager.state != RoundManager.State.ROUND or RoundManager.to_spawn > 0 or squad == null or squad.director() == null:
		return -1
	return squad.director().active_zombies().size()


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
