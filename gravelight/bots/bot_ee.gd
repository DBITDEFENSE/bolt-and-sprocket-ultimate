class_name BotEE
extends RefCounted
## One bot's easter-egg work (Update 04 section 5, T-067): at most one task at a time, a quest step's `bot_task`
## (BotEECatalog), started by the player (BotSquad.ee_assign: the Objectives tab, a map mark, the ping key, the dev
## console) or, in Full Partner mode, picked by BotEEHub. The brain's utility action "ee_task" (actions.json) runs it;
## its input is value(): 0 while paused (threat, a teammate down, the round ending, the player away from a final
## step) or waiting, so the bot fights / revives / follows meanwhile and comes back ("Back to it.").
##
## Each task type has a pure planner (plan_<type>: a world snapshot in, one move out, unit-tested with fakes in
## test_bot_ee.gd) and this class carries the move out with the brain's layers (BotTasks errands for walking and
## using, BotAim for shots, the locomotion layer for holding and escorting):
##   collect           take each eligible target (not counted yet, found, not claimed by a teammate), nearest first
##   interact_sequence one use (the power switch), or the step's ordered inputs (radio frequencies, switchboard
##                     jacks) from the quest itself, never a guess; commit "last_input" leaves the last one to the player
##   shoot_target      one target (the Chapel bell with an upgraded gun, then hold the Chapel while it is lit), a
##                     sequence (the Four Bells in the melody's order: only ever the bell the sequence expects next,
##                     unless the player marked that bell themselves), or a moving target (Herr Tamtam, then his shard)
##   hold_zone         stand in the zone: a charging pylon's ring (attuning one only with the player close), the
##                     Heartstorm while it runs (the start is the player's)
##   carry             fetch the item or the parts, then deliver them (the key to the altar, the shard to the
##                     Crucible, the parts to the workbench); the Crucible only when the quest is ready for it, so a
##                     bot never hands its gun to the forge by mistake
##   kill_with_weapon  take the weapon (the Totenglocke from the bench) and kill near the spot with it
##   escort            cover the player while they do a player-only step
##   turn_key          stand at its key and turn it only once the player is at (or has turned) the other one
## The never-sequence-break rule lives in the planners (BotEECatalog.safe_input / commit_blocked / is_risky) and in
## shot_allowed(): a quest shootable reacts to this bot's bullet only when it is the one the plan aims at this frame.

var brain: BotBrain
var player: Player
var hub: BotEEHub = null
## {qid, sid, def, type, ordered, source, focus, stage, t0, paused, paused_t, picked, inputs, cur, said}
var task: Dictionary = {}
var done_count: int = 0
var failed_count: int = 0
var history: PackedStringArray = []

var _plan: Dictionary = {}
var _errand: Dictionary = {}
var _claim_key: String = ""
var _shoot_target: Node = null
var _shoot_frame: int = -1
var _forced: Dictionary = {}          # {"weapon": [ids]} or {"upgraded": true}
var _last_tick: float = -INF
var _line_t: Dictionary = {}          # category -> squad time it was said
var _failed_nodes: Dictionary = {}    # instance id -> squad time it may be tried again
var _fail_count: Dictionary = {}      # instance id -> failures this task (3: given up)
var _hold_t: float = 0.0
var _vantage: Dictionary = {}         # instance id -> Vector3
var _replan: bool = true
var _round_end_skip: int = -1         # the round whose dragging end no longer pauses the task


func setup(b: BotBrain) -> void:
	brain = b
	player = b.player


## U08 (T-131): holding a zone that keeps the round open (a charging pylon, a running holdout): nothing may pull the
## bot off it (the agent's trainer would leave the pylon empty and the round could never end).
func holding_now() -> bool:
	if not active() or str(_plan.get("do", "")) != "hold":
		return false
	var n: Node = _plan.get("node") as Node
	if n is Pylon:
		return (n as Pylon).state == Pylon.State.CHARGING
	return true


func active() -> bool:
	return not task.is_empty()


func _now() -> float:
	return brain.squad.time()


func _cfg() -> Dictionary:
	return BotEECatalog.cfg()


# ================================================================== start / stop

## Takes on a step. `as_kind` "escort" = a player-only step: cover the player while they do it.
func start(qid: StringName, sid: StringName, t: Dictionary, ordered: bool, source: String, focus: Node = null, as_kind: String = "task") -> void:
	if active():
		_release()
	var escort: bool = as_kind == "escort"
	task = {"qid": qid, "sid": sid, "def": t, "type": "escort" if escort else str(t.get("type", "")), "ordered": ordered, "source": source,
		"focus": focus, "stage": "escort" if escort else "run", "t0": _now(), "paused": "", "paused_t": 0.0, "picked": 0, "inputs": 0, "said": {}}
	_plan = {}
	_errand = {}
	_replan = true
	_failed_nodes.clear()
	_fail_count.clear()
	_log("start %s/%s (%s, %s%s)" % [qid, sid, task["type"], source, ", ordered" if ordered else ""])
	_announce_start()


## Drops the task (`why` for the log; `say` the interrupted line).
func cancel(why: String = "cancelled", say: bool = false) -> void:
	if not active():
		return
	_log("cancel %s/%s: %s" % [task["qid"], task["sid"], why])
	if say:
		_say("EE_INTERRUPTED", true)
	_release()
	task = {}
	_plan = {}


func _finish(ok: bool, code: String = "") -> void:
	if not active():
		return
	var t: Dictionary = task
	if ok:
		done_count += 1
		_log("done %s/%s" % [t["qid"], t["sid"]])
		if QuestManager.is_step_done(t["qid"], t["sid"]) or int(t.get("picked", 0)) > 0 or int(t.get("inputs", 0)) > 0:
			_say("EE_DONE", true)
	else:
		failed_count += 1
		_log("stopped %s/%s: %s" % [t["qid"], t["sid"], code])
		if bool(t.get("ordered", false)) and code != "" and code != "locked":
			_say(BotEECatalog.cant_category(code), true)
	if hub != null:
		hub.on_task_finished(brain, t, ok, code)
	_release()
	task = {}
	_plan = {}


func _release() -> void:
	if _claim_key != "":
		brain.squad.blackboard.release(_claim_key, player.player_id)
		_claim_key = ""
	_errand = {}
	_shoot_target = null
	_forced = {}


func _log(s: String) -> void:
	history.append("%.0fs %s" % [_now(), s])
	if history.size() > 16:
		history.remove_at(0)
	print("[ee] %s: %s" % [Net.display_name(player.player_id), s])


# ================================================================== the brain's hooks

## The utility input (actions.json ee_task): 0 = nothing to do now.
func value() -> float:
	if brain != null and brain.is_player_bot and active() and not AgentPlan.egg_may_work_now(brain):
		return 0.0   # T-086: the agent's egg work keeps to the breaks until its plan says it can afford a round
	if not active() or str(task.get("paused", "")) != "":
		return 0.0
	var d: String = str(_plan.get("do", ""))
	if d == "wait" or d == "":
		return 0.0
	var ty: String = "hold_zone" if d == "hold" else str(task["type"])
	return BotEECatalog.task_value(ty, _cfg())


## Every think (~5 Hz): the step's state, the pause rule and a fresh plan.
func tick_think(now: float) -> void:
	if not active():
		return
	var resumed_from_down: bool = now - _last_tick > 2.0 and _last_tick > -INF
	_last_tick = now
	var qid: StringName = task["qid"]
	var sid: StringName = task["sid"]
	if QuestManager.is_step_done(qid, sid):
		_finish(true)
		return
	if not QuestManager.is_active(qid, sid):
		_finish(false, "locked")
		return
	var was: String = str(task.get("paused", ""))
	var ps: Dictionary = _pause_state()
	ps["was"] = was
	var why: String = BotEECatalog.pause_reason(ps, _cfg())
	if why == "" and was != "" and now - float(task.get("paused_t", now)) < float((_cfg().get("pause", {}) as Dictionary).get("min_pause_s", 3.0)):
		why = was   # a pause lasts a moment at least (no flicker between fighting and the task)
	if why != was:
		task["paused"] = why
		if why != "":
			task["paused_t"] = now
			_log("paused (%s)" % why)
			if why == "player_away":
				_say("EE_WAIT_PLAYER", false)
			else:
				_say("EE_INTERRUPTED", false)
		else:
			_log("resumed")
			_say("EE_RESUME", false)
	elif resumed_from_down and why == "":
		_say("EE_RESUME", false)
	if why != "" and str(task.get("source", "")) == "full" and now - float(task.get("paused_t", now)) > float((_cfg().get("pause", {}) as Dictionary).get("full_drop_after_s", 60.0)):
		cancel("paused too long")
		return
	if now - float(task.get("t0", now)) > float(_cfg().get("wait_timeout_s", 150.0)) and str(_plan.get("do", "")) == "wait" and str(task.get("source", "")) == "full":
		cancel("nothing to do")
		return
	if str(task["type"]) == "escort" and str(task.get("source", "")) == "full" and hub != null:
		# Full Partner covers the player at a player-only step while they are at it; they walked off: done
		var a: Vector3 = hub.step_anchor(qid, sid, task["def"])
		var h: Player = brain.squad.human()
		if a != Vector3.INF and (h == null or not is_instance_valid(h) or _flat(h.global_position, a) > float(_cfg().get("presence_m", 20.0))):
			cancel("the player left")
			return
	_refresh_plan()


func _pause_state() -> Dictionary:
	var down: bool = false
	if Net.session != null:
		for p: Player in brain.squad.all_players():
			if p != player and is_instance_valid(p) and not p.spectating and Net.session.coop.is_downed(p.player_id):
				down = true
	var left: int = -1
	if RoundManager.state == RoundManager.State.ROUND and RoundManager.to_spawn <= 0 and brain.squad.director() != null and _round_end_skip != RoundManager.current_round:
		left = brain.squad.director().active_zombies().size()
		# a round that drags on (the last zombie stuck somewhere): back to the task after round_end_max_s
		if str(task.get("paused", "")) == "round_end" and _now() - float(task.get("paused_t", _now())) > float((_cfg().get("pause", {}) as Dictionary).get("round_end_max_s", 20.0)):
			_round_end_skip = RoundManager.current_round
			left = -1
	var away: bool = false
	var t: Dictionary = task["def"]
	var wait_over: bool = hub != null and hub.final_wait_over(task["qid"], task["sid"])   # T-086
	if bool(t.get("final", false)) and not bool(task.get("ordered", false)) and str(task["type"]) != "escort" and not wait_over:
		var a: Vector3 = anchor()
		var h: Player = brain.squad.human()
		if a != Vector3.INF and h != null and is_instance_valid(h):
			away = h.spectating or _flat(h.global_position, a) > float(_cfg().get("presence_m", 20.0)) * 1.5
	return {"type": str(task["type"]) if str(_plan.get("do", "")) != "hold" else "hold_zone", "pressure": brain.perception.pressure,
		"teammate_down": down, "round_left": left, "player_away": away}


## The action "ee_task" was picked: carry the plan out this frame.
func run(delta: float) -> void:
	if not active():
		brain.loco.stop()
		if not brain.aim.update(delta, true):
			brain.idle_look(delta)
		return
	if _replan:
		_refresh_plan()
	_execute(delta)


func on_exit() -> void:
	_shoot_target = null
	# T-086: the errand starts over when the action comes back (a fight, a round the trainer owns): its timeout
	# counted the whole time away and the agent's note runs ended in "couldn't use"
	_errand = {}


## The weapon slot the plan needs in hand (-1 none): the task's weapon, or any upgraded gun.
func forced_slot() -> int:
	if _forced.is_empty() or not active():
		return -1
	var ws: Array = _forced.get("weapon", [])
	for i: int in player.weapons.slots.size():
		var w: WeaponInstance = player.weapons.slots[i]
		if not ws.is_empty() and (ws.has(String(w.id)) or ws.has(String(w.base_id()))):
			return i
		if bool(_forced.get("upgraded", false)) and w.upgraded:
			return i
	return -1


## The never-sequence-break gate for bullets: a quest shootable (a bell, the drummer) reacts to this bot's shot only
## when it is exactly what the plan aimed at this physics frame.
func shot_allowed(n: Node) -> bool:
	return active() and n != null and n == _shoot_target and _shoot_frame == Engine.get_physics_frames()


## Where the task is (for distances and the player-presence rule).
func anchor() -> Vector3:
	var n: Variant = _plan.get("node")
	if n is Node3D and is_instance_valid(n):
		return (n as Node3D).global_position
	if _plan.has("pos"):
		return _plan["pos"]
	return Vector3.INF


## The status for UI lines (BotSquad.ee_task_of).
func describe() -> Dictionary:
	if not active():
		return {}
	var t: Dictionary = task["def"]
	var d: String = str(_plan.get("do", ""))
	var stage: String = "escort" if str(task["type"]) == "escort" else ("handoff" if d == "handoff" else ("door" if d == "door" else ("wait" if d == "wait" else "")))
	var line: String = BotEECatalog.verb(t, stage)
	if str(task["type"]) == "collect":
		var got: Variant = QuestManager.progress(task["qid"], task["sid"])
		var p: Dictionary = QuestManager.step_def(task["qid"], task["sid"]).get("params", {})
		line += " (%d/%d)" % [(got as Array).size() if got is Array else 0, int(p.get("count", 1))]
	var paused: String = str(task.get("paused", ""))
	if paused != "":
		line += " - paused: %s" % {"threat": "too hot", "teammate_down": "someone's down", "round_end": "finishing the round", "player_away": "waiting for you"}.get(paused, paused)
	return {"quest_id": task["qid"], "step_id": task["sid"], "type": task["type"], "label": line, "state": "paused" if paused != "" else (d if d != "" else "running"),
		"paused": paused, "source": task["source"], "ordered": task["ordered"], "pid": player.player_id}


# ================================================================== planning

func _refresh_plan() -> void:
	_replan = false
	if not active():
		return
	if str(_plan.get("do", "")) == "door":
		var dn: BuyDoor = _plan.get("node") as BuyDoor
		if dn != null and is_instance_valid(dn) and not dn.is_open and float(_failed_nodes.get(dn.get_instance_id(), -INF)) <= _now():
			return   # on the way to open a door: no second-guessing every think
	var w: Dictionary = snapshot(task["qid"], task["sid"], task["def"], task.get("focus"), bool(task["ordered"]), str(task["type"]))
	var was: String = "%s %s" % [str(_plan.get("do", "")), str((_plan.get("node") as Node).name) if _plan.get("node") is Node and is_instance_valid(_plan.get("node")) else ""]
	_plan = plan(str(task["type"]), task["def"], w)
	var d: String = str(_plan.get("do", ""))
	if OS.has_environment("EGG_DEBUG"):
		var now_s: String = "%s %s" % [d, str((_plan.get("node") as Node).name) if _plan.get("node") is Node and is_instance_valid(_plan.get("node")) else ""]
		if now_s != was:
			var anchors: String = ""
			for r: Variant in w.get("anchors", []):
				anchors += " %s:%s" % [str(((r as Dictionary)["node"] as Node).name), str((r as Dictionary)["state"])]
			_log("plan %s -> %s%s" % [was, now_s, (" |" + anchors) if anchors != "" else ""])
	if d == "done":
		_finish(true)
	elif d == "fail":
		_finish(false, str(_plan.get("code", "failed")))


## What this bot would do for a step right now, without starting it (the hub's Full Partner pick and ee_assign):
## {"ok", "code", "do", "node", "pos"}.
func preview(qid: StringName, sid: StringName, t: Dictionary, ordered: bool, focus: Node = null, as_kind: String = "task") -> Dictionary:
	var ty: String = "escort" if as_kind == "escort" else str(t.get("type", ""))
	var w: Dictionary = snapshot(qid, sid, t, focus, ordered, ty)
	var p: Dictionary = plan(ty, t, w)
	var d: String = str(p.get("do", ""))
	if d == "fail":
		return {"ok": false, "code": str(p.get("code", "failed")), "do": d}
	if d == "done":
		return {"ok": false, "code": "done", "do": d}
	if d == "use":
		var n: Node3D = p.get("node") as Node3D
		if n != null and brain.stand_point(n) == Vector3.INF and _blocking_door(n.global_position) == null:
			return {"ok": false, "code": "unreachable", "do": d}
	var out: Dictionary = p.duplicate()
	out["ok"] = true
	out["code"] = "ok"
	return out


## A world snapshot for the planners (the live game state, read once).
## T-153: per quest step, when a thinking solver may make its first input (think_s in the bot_task).
var _think_until: Dictionary = {}

func snapshot(qid: StringName, sid: StringName, t: Dictionary, focus: Variant, ordered: bool, ty: String) -> Dictionary:
	var now: float = _now()
	var step: Dictionary = QuestManager.step_def(qid, sid)
	var params: Dictionary = step.get("params", {})
	var prog: Variant = QuestManager.progress(qid, sid)
	var w: Dictionary = {"step_done": QuestManager.is_step_done(qid, sid), "step_active": QuestManager.is_active(qid, sid), "ordered": ordered,
		"focus": focus if focus is Node and is_instance_valid(focus) else null, "picked": int(task.get("picked", 0)) if active() else 0, "me": player.global_position,
		"current": task.get("cur") if active() and is_instance_valid(task.get("cur")) else null}
	var hub_ok: bool = hub != null
	match ty:
		"collect":
			var got: Array = []
			if prog is Array:
				for g: Variant in prog:
					got.append(str(g))
			w["got"] = got
			var rows: Array = []
			if hub_ok:
				for n: Node in hub.resolve(t.get("targets", {})):
					var n3: Node3D = n as Node3D
					if n3 == null:
						continue
					rows.append({"node": n3, "id": BotEECatalog.target_id(n3, t), "ok": _eligible(n3, t) and not hub.targeted_by_other(n3, brain),
						"retry": _retry_later(n3), "d": _flat(n3.global_position, player.global_position)})
			w["nodes"] = rows
		"interact_sequence":
			w["node"] = _first(t.get("target", {}), focus)
			w["has_input"] = not (t.get("input", {}) as Dictionary).is_empty()
			w["expected"] = QuestManager.sequence_inputs(qid, sid) if w["has_input"] else []
			w["progress"] = int(prog) if prog != null and not prog is Array else 0
			w["commit_ok"] = _commit_ok()
			w["ready"] = str(t.get("ready", "")) == "" or QuestManager.interact_ready(StringName(str(t["ready"])))
			var nd: Interactable = w["node"] as Interactable
			w["usable"] = nd != null and nd.can_interact(player)
			if t.has("think_s"):   # T-153: a puzzle solver "thinks" a while before the first input (the cipher: 20-40 s)
				var tk: String = "%s:%s" % [qid, sid]
				var now_s: float = Time.get_ticks_msec() / 1000.0
				if not _think_until.has(tk):
					var ts: Variant = t["think_s"]
					var secs: float = randf_range(float(ts[0]), float(ts[1])) if ts is Array else float(ts)
					_think_until[tk] = now_s + secs
				w["think_left"] = float(_think_until[tk]) - now_s
		"shoot_target":
			w["expected"] = QuestManager.sequence_inputs(qid, sid) if t.has("sequence") else []
			w["progress"] = int(prog) if prog != null and not prog is Array else 0
			var seq: Dictionary = {}
			if t.has("sequence") and hub_ok:
				var vp: String = str((t["sequence"] as Dictionary).get("value_prop", "note"))
				for n2: Node in hub.resolve(t["sequence"]):
					seq[str(n2.get(StringName(vp)))] = n2
			w["sequence"] = seq
			w["single"] = _first(t.get("target", {}), null) if not bool(t.get("moving", false)) else null
			w["moving"] = _first(t.get("target", {}), null) if bool(t.get("moving", false)) else null
			w["lit"] = str(t.get("lit_flag", "")) != "" and GameState.has_flag(StringName(str(t["lit_flag"])))
			w["has_upgraded"] = _has_upgraded()
			w["pickup"] = _first(t.get("then_pickup", {}), null)
			var crate: MysteryCrate = _current_crate()
			w["crate"] = crate
			w["can_trigger"] = crate != null and Economy.get_scrip(player.player_id) >= CrateManager.cost()
		"hold_zone":
			var running: bool = not QuestManager.holdout_state(qid, sid).is_empty()
			w["holdout_running"] = running
			w["is_agent"] = brain.is_player_bot   # U08 (T-131): the agent starts a holdout that is the player's to start
			var sn: Interactable = _first(t.get("target", {}), null) as Interactable
			w["start_node"] = sn if sn != null and sn.can_interact(player) else null
			var pts: Array = params.get("points", [])
			var sum: Vector3 = Vector3.ZERO
			for pt: Variant in pts:
				sum += Vector3(float(pt[0]), float(pt[1]), float(pt[2]))
			w["center"] = sum / float(pts.size()) if not pts.is_empty() else (Vector3(float(params["center"][0]), float(params["center"][1]), float(params["center"][2])) if params.has("center") else player.global_position)
			var arows: Array = []
			if t.has("anchors") and hub_ok:
				var near_m: float = float(t.get("start_needs_player_m", 0.0))
				for a: Node in hub.resolve(t["anchors"]):
					var a3: Node3D = a as Node3D
					var st: String = _anchor_state(a3, t, near_m)
					arows.append({"node": a3, "state": st, "d": _flat(a3.global_position, player.global_position)})
			w["anchors"] = arows
		"carry":
			var item: String = str(t.get("item", ""))
			w["has_item"] = item == "" or QuestManager.has_item(StringName(item))
			w["pickup"] = _first(t.get("pickup", {}), null)
			var prow: Array = []
			w["carrying"] = false
			if t.has("pickups") and hub_ok:
				for pn: Node in hub.resolve(t["pickups"]):
					var p3: Node3D = pn as Node3D
					if p3 != null and "carrier" in p3 and int(p3.get("carrier")) == player.player_id:
						w["carrying"] = true   # T-153: already holding one (a ballast coffin): deliver it
					if p3 != null and _eligible(p3, t) and not hub.targeted_by_other(p3, brain):
						prow.append({"node": p3, "d": _flat(p3.global_position, player.global_position)})
			w["pickups"] = prow
			var dn: Node = _first(t.get("deliver", {}), null)
			w["deliver"] = dn
			var dr: String = str(t.get("deliver_ready", ""))
			w["deliver_ready"] = dn != null and (dn as Interactable).can_interact(player) if dr == "" else (dn != null and QuestManager.interact_ready(StringName(dr)))
		"kill_with_weapon":
			var ws: Array = t.get("weapon", []) if t.get("weapon") is Array else [t.get("weapon", "")]
			var holding: bool = false
			for wi: WeaponInstance in player.weapons.slots:
				if ws.has(String(wi.id)) or ws.has(String(wi.base_id())):
					holding = true
			w["holding"] = holding
			var gn: Node = null
			if hub_ok:
				for g2: Node in hub.resolve(t.get("get_weapon", {})):
					if (g2 as Interactable).can_interact(player):
						gn = g2
						break
			w["get_node"] = gn
			var c: Array = params.get("center", [player.global_position.x, player.global_position.y, player.global_position.z])
			w["center"] = Vector3(float(c[0]), float(c[1]), float(c[2]))
			w["radius"] = float(params.get("radius", 15.0))
		"escort":
			w["human"] = brain.squad.human()
		"turn_key":
			var key: Node = _first(t.get("key", t.get("target", {})), null)
			var partner: Node = _first(t.get("partner_key", {}), null)
			w["key"] = key
			w["key_turned"] = key != null and key.has_method("is_turned") and bool(key.call("is_turned"))
			var h: Player = brain.squad.human()
			var pready: bool = partner != null and partner.has_method("is_turned") and bool(partner.call("is_turned"))
			if not pready and partner is Node3D and h != null and is_instance_valid(h) and not h.spectating:
				pready = (h.global_position - (partner as Node3D).global_position).length() <= float(t.get("partner_m", 1.8))
			w["partner_ready"] = pready
			w["at_key"] = key is Node3D and _flat((key as Node3D).global_position, player.global_position) <= float(t.get("reach_m", 1.6))
	return w


## The planners, by type (pure: w in, a move out).
static func plan(ty: String, t: Dictionary, w: Dictionary) -> Dictionary:
	if bool(w.get("step_done", false)):
		return {"do": "done"}
	match ty:
		"collect":
			return plan_collect(t, w)
		"interact_sequence":
			return plan_inputs(t, w)
		"shoot_target":
			return plan_shoot(t, w)
		"hold_zone":
			return plan_hold(t, w)
		"carry":
			return plan_carry(t, w)
		"kill_with_weapon":
			return plan_kill(t, w)
		"escort":
			return plan_escort(t, w)
		"turn_key":
			return plan_turn_key(t, w)
	return {"do": "fail", "code": "no_task"}


## Collect: the focus (a marked note) if it still counts, else the nearest eligible target not counted yet.
static func plan_collect(_t: Dictionary, w: Dictionary) -> Dictionary:
	var got: Array = w.get("got", [])
	var focus: Variant = w.get("focus")
	var best: Dictionary = {}
	var cur: Dictionary = {}
	for r: Variant in w.get("nodes", []):
		var row: Dictionary = r
		if not bool(row.get("ok", false)) or got.has(str(row.get("id", ""))):
			continue
		if focus != null and row.get("node") == focus:
			return {"do": "use", "node": row["node"]}
		if w.get("current") != null and row.get("node") == w["current"]:
			cur = row
		if best.is_empty() or float(row.get("d", 0.0)) < float(best.get("d", 0.0)):
			best = row
	if not cur.is_empty():
		return {"do": "use", "node": cur["node"]}   # stays with the one it set out for (no dithering between two)
	if not best.is_empty():
		return {"do": "use", "node": best["node"]}
	for r2: Variant in w.get("nodes", []):
		if bool((r2 as Dictionary).get("retry", false)) and not got.has(str((r2 as Dictionary).get("id", ""))):
			return {"do": "wait"}   # one it couldn't reach just now: tries again after a moment
	if int(w.get("picked", 0)) > 0:
		return {"do": "done"}
	return {"do": "fail", "code": "not_found"}


## Interact sequence: one use, or the next expected input; the last one is the player's (commit), never a guess.
static func plan_inputs(t: Dictionary, w: Dictionary) -> Dictionary:
	var n: Variant = w.get("node")
	if n == null:
		return {"do": "fail", "code": "not_found"}
	if not bool(w.get("has_input", false)):
		if not bool(w.get("ready", true)):
			return {"do": "wait", "node": n}
		if not bool(w.get("usable", true)):
			return {"do": "fail", "code": "locked"}
		return {"do": "use", "node": n, "guard_ready": str(t.get("ready", ""))}
	var expected: Array = w.get("expected", [])
	var idx: int = int(w.get("progress", 0))
	if expected.is_empty():
		return {"do": "fail", "code": "info"}
	if float(w.get("think_left", 0.0)) > 0.0 and idx == 0:
		return {"do": "wait", "node": n}   # T-153: still working the puzzle out
	if idx >= expected.size():
		return {"do": "done"}
	if BotEECatalog.commit_blocked(t, idx, expected.size()) and not bool(w.get("commit_ok", false)):
		return {"do": "handoff", "node": n}
	var value: String = str(expected[idx])
	if not BotEECatalog.safe_input(expected, idx, value, false):
		return {"do": "fail", "code": "info"}
	return {"do": "input", "node": n, "value": value, "index": idx}


## Shoot target: a sequence (only the expected bell), a moving target (then its drop), or one target (and the hold
## while it is lit).
static func plan_shoot(t: Dictionary, w: Dictionary) -> Dictionary:
	var ordered: bool = bool(w.get("ordered", false))
	if t.has("sequence"):
		var expected: Array = w.get("expected", [])
		var idx: int = int(w.get("progress", 0))
		if expected.is_empty():
			return {"do": "fail", "code": "info"}
		if idx >= expected.size():
			return {"do": "done"}
		var seq: Dictionary = w.get("sequence", {})
		var focus: Variant = w.get("focus")
		if focus != null and ordered:
			# the player marked this exact bell: their call, even out of order
			var fv: String = ""
			for k: Variant in seq.keys():
				if seq[k] == focus:
					fv = str(k)
			if fv != "" and BotEECatalog.safe_input(expected, idx, fv, true):
				return {"do": "shoot", "node": focus, "value": fv, "ordered_input": fv != str(expected[idx])}
		var want: String = str(expected[idx])
		var bell: Variant = seq.get(want)
		if bell == null:
			return {"do": "fail", "code": "not_found"}
		if not BotEECatalog.safe_input(expected, idx, want, false):
			return {"do": "fail", "code": "info"}
		return {"do": "shoot", "node": bell, "value": want}
	if bool(t.get("moving", false)):
		if w.get("moving") != null:
			return {"do": "shoot_moving", "node": w["moving"]}
		if w.get("pickup") != null:
			return {"do": "use", "node": w["pickup"]}
		if str(t.get("trigger", "")) == "crate":
			if BotEECatalog.is_risky(t, "trigger") and not ordered:
				return {"do": "wait"}
			if bool(w.get("can_trigger", false)):
				return {"do": "crate", "node": w.get("crate")}
		return {"do": "wait"}
	var target: Variant = w.get("single")
	if target == null:
		return {"do": "fail", "code": "not_found"}
	if bool(w.get("lit", false)):
		return {"do": "hold", "node": target, "vantage": true, "radius": float((t.get("then_hold", {}) as Dictionary).get("radius", 4.0))}
	if BotEECatalog.is_risky(t, "shoot") and not ordered:
		return {"do": "fail", "code": "risky"}
	if bool(t.get("need_upgraded", false)) and not bool(w.get("has_upgraded", false)):
		return {"do": "fail", "code": "no_upgraded"}
	return {"do": "shoot", "node": target, "need_upgraded": bool(t.get("need_upgraded", false))}


## Hold zone: a running holdout's centre (its start is the player's: cover them till then), or a charging anchor's
## ring (starting an idle one only when the snapshot says it may).
static func plan_hold(t: Dictionary, w: Dictionary) -> Dictionary:
	if str(t.get("while", "")) == "holdout":
		if bool(w.get("holdout_running", false)):
			return {"do": "hold", "pos": w.get("center", Vector3.ZERO), "radius": float(t.get("radius", 5.0))}
		if str(t.get("start", "")) == "player":
			if bool(w.get("is_agent", false)) and w.get("start_node") != null:
				return {"do": "use", "node": w["start_node"]}
			return {"do": "escort"}
		return {"do": "wait"}
	var charging: Dictionary = {}
	var startable: Dictionary = {}
	var pending: bool = false
	for r: Variant in w.get("anchors", []):
		var row: Dictionary = r
		match str(row.get("state", "")):
			"charging":
				if charging.is_empty() or float(row["d"]) < float(charging["d"]):
					charging = row
			"start_ok":
				if startable.is_empty() or float(row["d"]) < float(startable["d"]):
					startable = row
			"idle":
				pending = true
	if not charging.is_empty():
		return {"do": "hold", "node": charging["node"], "radius_mult": float(t.get("radius_mult", 0.45))}
	if not startable.is_empty():
		return {"do": "use", "node": startable["node"]}
	if pending:
		return {"do": "wait"}
	return {"do": "fail", "code": "not_found"}


## Carry: fetch (the item's pickup, or each part), then deliver once the target is ready for it.
static func plan_carry(t: Dictionary, w: Dictionary) -> Dictionary:
	if t.has("pickups") and not bool(w.get("carrying", false)):
		var best: Dictionary = {}
		for r: Variant in w.get("pickups", []):
			var row: Dictionary = r
			if w.get("current") != null and row["node"] == w["current"]:
				best = row
				break
			if best.is_empty() or float(row["d"]) < float(best["d"]):
				best = row
		if not best.is_empty():
			return {"do": "use", "node": best["node"]}
	elif not bool(w.get("has_item", true)):
		if w.get("pickup") != null:
			return {"do": "use", "node": w["pickup"]}
		return {"do": "fail", "code": "not_found"}
	var dn: Variant = w.get("deliver")
	if dn == null:
		return {"do": "fail", "code": "not_found"}
	if not bool(w.get("deliver_ready", false)):
		return {"do": "wait", "node": dn}
	return {"do": "use", "node": dn, "guard_ready": str(t.get("deliver_ready", ""))}


## Kill with weapon X near Y: the weapon first (the bench), then hold the spot with it in hand.
static func plan_kill(t: Dictionary, w: Dictionary) -> Dictionary:
	if bool(w.get("holding", false)):
		return {"do": "hold", "pos": w.get("center", Vector3.ZERO), "radius": minf(float(w.get("radius", 15.0)) * 0.4, 5.0),
			"weapon": t.get("weapon", []) if t.get("weapon") is Array else [t.get("weapon", "")]}
	if w.get("get_node") != null:
		return {"do": "use", "node": w["get_node"]}
	return {"do": "fail", "code": "no_weapon"}


static func plan_escort(_t: Dictionary, w: Dictionary) -> Dictionary:
	if not bool(w.get("step_active", true)):
		return {"do": "done"}
	return {"do": "escort"}


## Turn key: go to the key, wait there (covering) until the player is at the other key or has turned it, then turn.
static func plan_turn_key(_t: Dictionary, w: Dictionary) -> Dictionary:
	var key: Variant = w.get("key")
	if key == null:
		return {"do": "fail", "code": "not_found"}
	if bool(w.get("key_turned", false)):
		return {"do": "done"}
	if not bool(w.get("at_key", false)):
		return {"do": "goto", "node": key}
	if bool(w.get("partner_ready", false)):
		return {"do": "turn", "node": key}
	return {"do": "guard", "node": key}


# ================================================================== carrying the plan out

func _execute(delta: float) -> void:
	_forced = {}
	var d: String = str(_plan.get("do", ""))
	var n: Node3D = _plan.get("node") as Node3D
	if _plan.has("node") and (n == null or not is_instance_valid(n)) and d != "escort" and d != "wait" and d != "hold":
		_replan = true
		_idle(delta)
		return
	match d:
		"use":
			_do_use(n, delta)
		"input":
			_do_input(n, delta)
		"shoot":
			_do_shoot(n, delta)
		"shoot_moving":
			_shoot_target = n
			_shoot_frame = Engine.get_physics_frames()
			_run_errand({"kind": "shoot_moving", "node": n}, delta)
		"crate":
			var r: String = _run_errand({"kind": "crate", "id": "ee", "node": n, "stand": brain.stand_point(n)}, delta)
			if r != "running":
				_replan = true
		"hold":
			_do_hold(delta)
		"escort", "handoff", "wait":
			if d == "handoff" and not bool((task["said"] as Dictionary).get("handoff", false)):
				(task["said"] as Dictionary)["handoff"] = true
				task["handoff_t"] = _now()   # T-086: Full Partner waits full_commit_after_s from here, then commits
				_say("EE_HANDOFF", true, n.global_position + Vector3.UP if n != null else Vector3.INF)
			if d == "handoff" and _commit_ok():
				_replan = true   # the wait is over: the next plan makes the commit
			_escort(delta)
		"goto", "guard":
			if d == "goto":
				_walk(n.global_position, 1.2, delta)
			else:
				brain.loco.stop()
				if not brain.aim.update(delta, true):
					brain.idle_look(delta)
		"turn":
			if n.has_method("turn"):
				n.call("turn", player)
			elif n is Interactable:
				(n as Interactable).interact(player)
			task["inputs"] = int(task["inputs"]) + 1
			_replan = true
		"door":
			_do_door(delta)
		_:
			_idle(delta)


func _idle(delta: float) -> void:
	brain.loco.stop()
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


## A BotTasks errand (walk, hold use, interact), kept across frames while it is the same node and kind.
func _run_errand(e: Dictionary, delta: float) -> String:
	if _errand.is_empty() or _errand.get("node") != e.get("node") or str(_errand.get("kind", "")) != str(e.get("kind", "")):
		_errand = e.duplicate()
		_errand["until"] = _now() + float(_cfg().get("errand_timeout_s", 45.0))
		_errand["hold"] = 0.0
		_errand["state"] = "running"
		_errand["qid"] = String(task["qid"])
		_errand["sid"] = String(task["sid"])
	var r: String = brain.tasks.run(_errand, delta)
	if r != "running":
		_errand = {}
	return r


func _do_use(n: Node3D, delta: float) -> void:
	var guard: String = str(_plan.get("guard_ready", ""))
	if guard != "" and not QuestManager.interact_ready(StringName(guard)):
		_replan = true   # the quest isn't ready for it (never feed the Crucible a gun by mistake)
		_idle(delta)
		return
	var sp: Vector3 = brain.stand_point(n)
	if sp == Vector3.INF:
		if _try_door(n.global_position):
			return
		_log("can't reach %s" % n.name)
		_mark_failed(n, 20.0)
		_replan = true
		_idle(delta)
		return
	if not _claim(n):
		_failed_nodes[n.get_instance_id()] = _now() + 8.0
		_replan = true
		return
	task["cur"] = n
	var r: String = _run_errand({"kind": "use", "node": n, "stand": sp}, delta)
	if r == "done":
		task["picked"] = int(task["picked"]) + 1
		task["cur"] = null
		_progress_line(n)
		_unclaim()
		_replan = true
	elif r == "failed":
		_log("couldn't use %s" % n.name)
		_mark_failed(n, 15.0)
		task["cur"] = null
		_unclaim()
		_replan = true


## The next ordered input: walk up, a short hold (like a player at the dial), then exactly the expected value.
func _do_input(n: Node3D, delta: float) -> void:
	var sp: Vector3 = brain.stand_point(n)
	if sp == Vector3.INF:
		if not _try_door(n.global_position):
			_finish(false, "unreachable")
		return
	if not _walk(sp, 0.6, delta):
		_hold_t = 0.0
		return
	brain.loco.look_at_dir(n.global_position + Vector3.UP * 0.3 - brain.aim.eye())
	brain.committed = true
	if GLVO.current_speaker(GLVO.GROUP_STORY) == &"FAS":
		_hold_t = 0.0   # T-086: the radio is answering the last input: a person listens before the next one
		return
	if player.remote_body != null:
		player.remote_body.hold_action(&"buy")
	_hold_t += delta
	if _hold_t < 0.9:
		return
	_hold_t = 0.0
	# re-read the sequence now (another player may have moved it on): still the expected one, never a guess
	var expected: Array = QuestManager.sequence_inputs(task["qid"], task["sid"])
	var prog: Variant = QuestManager.progress(task["qid"], task["sid"])
	var idx: int = int(prog) if prog != null and not prog is Array else 0
	var value: String = str(_plan.get("value", ""))
	if idx != int(_plan.get("index", -1)) or not BotEECatalog.safe_input(expected, idx, value, false) or (BotEECatalog.commit_blocked(task["def"], idx, expected.size()) and not _commit_ok()):
		_replan = true
		return
	if BotEECatalog.commit_blocked(task["def"], idx, expected.size()) and not bool((task["said"] as Dictionary).get("commit_self", false)):
		(task["said"] as Dictionary)["commit_self"] = true
		_say("EE_COMMIT_SELF", true)   # T-086: the player didn't come: the bot makes the last input itself
	var inp: Dictionary = (task["def"] as Dictionary).get("input", {})
	var method: String = str(inp.get("method", "submit"))
	var res: String = ""
	if n.has_method(method):
		var arg: Variant = int(value) if str(inp.get("arg", "string")) == "int" else value
		res = str(n.call(method, arg))
	else:
		res = str(QuestManager.submit(StringName(str(inp.get("target", ""))), value).get("result", ""))
	task["inputs"] = int(task["inputs"]) + 1
	if hub != null:
		hub.inputs_by_bots += 1
	_replan = true
	if res == "done":
		_finish(true)
	elif res == "ok":
		_progress_line(n)
	else:
		_finish(false, "wrong")


func _do_shoot(n: Node3D, delta: float) -> void:
	if bool(_plan.get("need_upgraded", false)):
		_forced = {"upgraded": true}
	var id: int = n.get_instance_id()
	if not _vantage.has(id):
		_vantage[id] = brain.vantage_for(n.global_position)
	var vp: Vector3 = _vantage[id]
	if vp == Vector3.INF:
		if not _try_door(n.global_position):
			_finish(false, "unreachable")
		return
	if not _walk(vp, 0.8, delta):
		return
	if bool(_plan.get("need_upgraded", false)) and forced_slot() >= 0 and player.weapons.current_index != forced_slot():
		brain.aim.select(forced_slot())
		return
	_shoot_target = n
	_shoot_frame = Engine.get_physics_frames()
	var before: int = int(task.get("shots", 0))
	if brain.aim.shoot_at(n.global_position, 1.0):
		task["shots"] = before + 1
		brain.aim.fire_cd = maxf(brain.aim.fire_cd, 0.6)
		_replan = true
		if int(task["shots"]) > 24:
			_finish(false, "missed")


func _do_hold(delta: float) -> void:
	var n: Node3D = _plan.get("node") as Node3D
	var pos: Vector3 = _plan.get("pos", Vector3.INF)
	var r: float = float(_plan.get("radius", 2.0))
	if n != null and is_instance_valid(n):
		if bool(_plan.get("vantage", false)):
			var id: int = n.get_instance_id()
			if not _vantage.has(id):
				_vantage[id] = brain.vantage_for(n.global_position)
			pos = _vantage[id]
		elif n is Pylon:
			pos = brain.snap(n.global_position)
			r = (n as Pylon).radius * float(_plan.get("radius_mult", 0.45))
		else:
			pos = brain.snap(n.global_position)
	if pos == Vector3.INF:
		_finish(false, "unreachable")
		return
	if _plan.has("weapon"):
		_forced = {"weapon": _plan["weapon"]}
		var fs: int = forced_slot()
		if fs >= 0 and player.weapons.current_index != fs:
			brain.aim.select(fs)
	brain.committed = true
	if brain.perception.nearest_d < float(_cfg().get("hold_fight_m", 2.2)):
		brain.actions.run("fight", delta)   # something at arm's length: fight it properly (back off, knife), then back to the spot
		return
	if _flat(pos, player.global_position) > r or absf(pos.y - player.global_position.y) > 1.8:
		brain.loco.move_to(pos, 0.45, r * 0.6)
		brain.aim.update(delta, true)
		return
	brain.loco.stop()
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)


## Covers the player: a step behind and to the side of them, shooting what comes.
func _escort(delta: float) -> void:
	var h: Player = brain.squad.human()
	if h == null or not is_instance_valid(h) or h.spectating:
		_idle(delta)
		return
	var hv: Vector3 = Vector3(h.velocity.x, 0.0, h.velocity.z)
	var back: Vector3 = -hv.normalized() if hv.length() > 0.6 else h.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var side: Vector3 = Vector3(-back.z, 0.0, back.x) * (1.2 if brain.index % 2 == 0 else -1.2)
	var spot: Vector3 = brain.snap(h.global_position + back * 2.6 + side)
	if _flat(spot, player.global_position) > 1.2:
		brain.loco.move_to(spot, 0.7 if _flat(h.global_position, player.global_position) > 9.0 else 0.35, 1.0)
	else:
		brain.loco.stop()
	if not brain.armed():
		brain.aim.melee_unarmed()
		brain.idle_look(delta, h)
	elif not brain.aim.update(delta, true):
		brain.idle_look(delta, h)


func _walk(p: Vector3, tol: float, delta: float) -> bool:
	if _flat(p, player.global_position) <= tol and absf(p.y - player.global_position.y) < 1.8:
		brain.loco.stop()
		return true
	brain.loco.move_to(p, 0.75 if _flat(p, player.global_position) > 9.0 and brain.aim.target == null else 0.4, tol * 0.8)
	if not brain.aim.update(delta, true):
		brain.idle_look(delta)
	return false


# ---------------------------------------------------------------- doors in the way

func _try_door(goal: Vector3) -> bool:
	var mode: String = hub.mode() if hub != null else "ask"
	if not bool((_cfg().get("open_blocking_doors", {}) as Dictionary).get(mode, false)):
		return false
	var d: BuyDoor = _blocking_door(goal)
	if d == null:
		return false
	_plan = {"do": "door", "node": d, "resume": _plan.duplicate()}
	return true


func _do_door(delta: float) -> void:
	var d: BuyDoor = _plan.get("node") as BuyDoor
	if d == null or d.is_open:
		_replan = true
		return
	if not brain.squad.can_claim(d, player.player_id):
		_failed_nodes[d.get_instance_id()] = _now() + 10.0   # a teammate is on it
		_replan = true
		return
	brain.squad.claim(d, player.player_id)
	if not bool((task["said"] as Dictionary).get("door:%d" % d.get_instance_id(), false)):
		(task["said"] as Dictionary)["door:%d" % d.get_instance_id()] = true
		brain.squad.ping(d.global_position + Vector3.UP * 1.6, "DOOR", brain)
	var r: String = _run_errand({"kind": "door", "node": d}, delta)
	if r != "running":
		brain.squad.release(d, player.player_id)
		if r == "failed" or not d.is_open:
			_failed_nodes[d.get_instance_id()] = _now() + 30.0
			_log("couldn't open %s" % BotBrain.door_label(d))
		else:
			_log("opened %s for %s" % [BotBrain.door_label(d), str((task["def"] as Dictionary).get("what", "the egg"))])
		brain.invalidate_stand_cache()
		_replan = true


## The closed door between the bot and `goal`: the first closed door the navmesh path to it crosses (the path
## ignoring doors; doors aren't baked into the navmesh), if this bot can open it (usable, affordable, not failed just
## now). null when the way is open or the door isn't ours to open.
func _blocking_door(goal: Vector3) -> BuyDoor:
	var nav: RID = player.get_world_3d().navigation_map
	var dest: Vector3 = Vector3.INF
	for dy: float in [0.0, -1.5, -3.0]:
		var sn: Vector3 = brain.snap(goal + Vector3(0.0, dy, 0.0))
		if _flat(sn, goal) < 2.0 and absf(sn.y - goal.y) < 3.5:
			dest = sn
			break
	if dest == Vector3.INF:
		return null
	# T-153: over every layer: a zone behind a closed door is not in the squad's mask, so a masked path never reaches it
	# and the door in the way was never found (Totenhafen gives every zone its own layer)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav, player.global_position, dest, true, 0x7FFFFFFF)
	if path.is_empty() or path[path.size() - 1].distance_to(dest) > 1.5:
		return null
	var best: BuyDoor = null
	var best_d: float = INF
	for d: BuyDoor in brain.loco_doors():
		if d == null or not is_instance_valid(d) or d.is_open or not ZombieDirector.door_crossed(d, path):
			continue
		var dd: float = _flat(d.global_position, player.global_position)
		if dd < best_d:
			best_d = dd
			best = d
	if best == null or not best.can_interact(player) or Economy.get_scrip(player.player_id) < best.cost:
		return null
	if float(_failed_nodes.get(best.get_instance_id(), -INF)) > _now():
		return null
	return best


# ---------------------------------------------------------------- snapshot helpers

func _first(spec: Variant, focus: Variant) -> Node:
	if not spec is Dictionary or (spec as Dictionary).is_empty() or hub == null:
		return null
	var ns: Array[Node] = hub.resolve(spec)
	if focus is Node and is_instance_valid(focus) and ns.has(focus):
		return focus
	var best: Node = null
	var bd: float = INF
	for n: Node in ns:
		var d: float = _flat((n as Node3D).global_position, player.global_position) if n is Node3D else 0.0
		if d < bd:
			bd = d
			best = n
	return best


## A target this bot may go for: shown, usable, found (find), not claimed by a teammate, not failed just now.
func _eligible(n: Node3D, t: Dictionary) -> bool:
	if not n.is_visible_in_tree():
		return false
	if n is Interactable and not (n as Interactable).can_interact(player):
		return false
	if float(_failed_nodes.get(n.get_instance_id(), -INF)) > _now():
		return false
	if str(t.get("find", "")) != "" and hub != null and not hub.found(n):
		return false
	var key: String = "ee:%d" % n.get_instance_id()
	return brain.squad.blackboard.can_claim(key, player.player_id, _now())


## A target this bot failed on a moment ago but may try again (at most 3 failures each).
func _retry_later(n: Node3D) -> bool:
	var id: int = n.get_instance_id()
	return float(_failed_nodes.get(id, -INF)) > _now() and int(_fail_count.get(id, 0)) < 3 and n.is_visible_in_tree() 		and (not (n is Interactable) or (n as Interactable).can_interact(player))


func _mark_failed(n: Node, seconds: float) -> void:
	var id: int = n.get_instance_id()
	_fail_count[id] = int(_fail_count.get(id, 0)) + 1
	_failed_nodes[id] = _now() + (seconds if int(_fail_count[id]) < 3 else 1.0e9)


func _claim(n: Node) -> bool:
	var key: String = "ee:%d" % n.get_instance_id()
	if _claim_key != key:
		_unclaim()
	if not brain.squad.blackboard.claim(key, player.player_id, "ee", _now(), _now() + 30.0, n):
		return false
	_claim_key = key
	return true


func _unclaim() -> void:
	if _claim_key != "":
		brain.squad.blackboard.release(_claim_key, player.player_id)
		_claim_key = ""


## A hold anchor's state: charging (hold it), start_ok (may be started now: idle, usable, affordable, the player
## within start_needs_player_m), idle (later), done.
func _anchor_state(a: Node3D, t: Dictionary, near_m: float) -> String:
	if a is Pylon:
		var py: Pylon = a as Pylon
		if py.state == Pylon.State.CHARGING:
			return "charging"
		if py.state == Pylon.State.ATTUNED:
			return "done"
		# U08 (T-131): the bot-mode agent is the player: it brings itself (a squad bot waits for the human)
		if py.can_interact(player) and Economy.get_scrip(player.player_id) >= int(Pylon.cfg().get("cost", 1500)) 				and (near_m <= 0.0 or brain.is_player_bot or _human_near(a.global_position, near_m)):
			return "start_ok"
		return "idle"
	if a.has_method("is_holding") and bool(a.call("is_holding")):
		return "charging"
	if str(t.get("start", "")) == "interact" and a is Interactable and (a as Interactable).can_interact(player) 			and (near_m <= 0.0 or brain.is_player_bot or _human_near(a.global_position, near_m)):
		return "start_ok"
	return "idle"


func _human_near(p: Vector3, r: float) -> bool:
	var h: Player = brain.squad.human()
	if h == null or not is_instance_valid(h) or h.spectating or h.downed:
		return false
	return _flat(h.global_position, p) <= r


func _has_upgraded() -> bool:
	for w: WeaponInstance in player.weapons.slots:
		if w.upgraded:
			return true
	return false


func _current_crate() -> MysteryCrate:
	for s: Node in brain.get_tree().get_nodes_in_group(&"crate_spots"):
		var c: MysteryCrate = s as MysteryCrate
		if c != null and c.spot_index == CrateManager.location_index and c.phase == MysteryCrate.Phase.CLOSED:
			return c
	return null


# ---------------------------------------------------------------- the voice

## A line from this bot (VO_SCRIPT section 18), with a world ping at `at`. `force` skips the per-category gap.
func _say(category: String, force: bool, at: Vector3 = Vector3.INF, text: String = "") -> bool:
	var lc: Dictionary = _cfg().get("lines", {})
	var gap: float = float(lc.get("progress_gap_s", 15.0))
	if category == "EE_INTERRUPTED" or category == "EE_RESUME":
		gap = float(lc.get("interrupt_gap_s", 30.0))
	elif category.begins_with("EE_CANT") or category.begins_with("EE_REFUSE") or category == "EE_WAIT_PLAYER":
		gap = float(lc.get("cant_gap_s", 6.0))
	var now: float = _now()
	if not force and now - float(_line_t.get(category, -INF)) < gap:
		return false
	_line_t[category] = now
	var ok: bool = brain.squad.callout(brain, category, true, at, text)
	if not ok and category.begins_with("EE_ACK_"):
		ok = brain.squad.callout(brain, "EE_ACK", true, at, text)
	elif not ok and (category.begins_with("EE_CANT_") or category == "EE_PLAYER_ONLY"):
		ok = brain.squad.callout(brain, "EE_CANT", true, at, text)
	if not ok and at != Vector3.INF:
		brain.squad.ping(at, text if text != "" else category.replace("EE_", "").replace("_", " "), brain)
	return ok


func say_cant(code: String) -> void:
	_say(BotEECatalog.cant_category(code), true)


func _announce_start() -> void:
	var t: Dictionary = task["def"]
	var cat: String = "EE_PLAYER_ONLY" if str(task["type"]) == "escort" else "EE_ACK_" + str(task["type"]).to_upper()
	var at: Vector3 = Vector3.INF
	var label: String = str(t.get("ping", "EGG"))
	var w: Dictionary = snapshot(task["qid"], task["sid"], t, task.get("focus"), bool(task["ordered"]), str(task["type"]))
	var p: Dictionary = plan(str(task["type"]), t, w)
	var n: Node3D = p.get("node") as Node3D
	if n != null and is_instance_valid(n):
		at = n.global_position + Vector3.UP * 1.2
	elif p.has("pos"):
		at = (p["pos"] as Vector3) + Vector3.UP * 1.2
	_say(cat, true, at, label)


func _progress_line(n: Node3D) -> void:
	var t: Dictionary = task["def"]
	# T-086: a step whose data gives the one who did it a story line (on_item "vo_actor") speaks for itself
	for a: Variant in QuestManager.step_def(task["qid"], task["sid"]).get("on_item", []):
		if (a as Dictionary).has("vo_actor"):
			return
	_say("EE_PROGRESS", false, n.global_position + Vector3.UP * 1.0 if n != null and is_instance_valid(n) else Vector3.INF, str(t.get("ping", "")))


## T-086: may this bot make a commit-rule input now? The agent always; Full Partner after the hand-off wait.
func _commit_ok() -> bool:
	if not active():
		return false
	var waited: float = (_now() - float(task["handoff_t"])) if task.has("handoff_t") else -1.0
	return BotEECatalog.commit_open(str(task.get("source", "")), waited, brain != null and brain.is_player_bot, _cfg())


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
