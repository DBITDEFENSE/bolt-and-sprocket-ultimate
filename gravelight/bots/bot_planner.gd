class_name BotPlanner
extends Node
## The objective planner of one AI teammate (bots.json "local_ai"), a child of its BotBrain. Every
## `decide_every_s` it lists what the bot could set out to do right now (BotPlanner.gather):
##   the map's easter egg (every active step of every loaded quest, read from the QuestManager: pick up notes /
##   radios / parts / items, tune the radio, plug the switchboard, attune pylons, light the Chapel bell and hold
##   the Chapel for the Foreman, the altar, ring the Four Bells in order, pull the crate for the drummer and shoot
##   him, kill with the Totenglocke at the heart, start and hold the Heartstorm), the power, a door that blocks one
##   of those, the usual shopping (perks, wall guns, ammo, doors, the Crucible, boards), and sticking with the team.
## Each option has a score. In mode "local" a local LLM (LocalAI, Ollama) reads a short summary of the match and
## the option list and picks one id (structured output, the ids as an enum); otherwise, and whenever the model is
## offline, busy past its timeout or answers nonsense, the highest score wins. The pick becomes `directive`, which
## the brain turns into an errand (BotBrain._planner_errand) and executes; it reports back through
## on_errand_finished. Fights, revives and fleeing still come first in the brain.

var brain: BotBrain
var squad: BotSquad
var use_llm: bool = false
var ai: LocalAI = null
var directive: Dictionary = {}
var options: Array[Dictionary] = []
var decisions: int = 0
var llm_picks: int = 0
var scripted_picks: int = 0
var history: PackedStringArray = []   # the last picks, "t source id"

var _cfg: Dictionary = {}
var _t: float = 1.0
var _failed: Dictionary = {}          # option id -> squad time until it may be picked again
var _speak_t: float = 0.0
var _announced: bool = false
var _nodes: Array[Node] = []          # quest objects without a group (notes, pickups, altar, radio...)
var _nodes_t: float = -INF


func setup(b: BotBrain, s: BotSquad, llm: bool) -> void:
	brain = b
	squad = s
	use_llm = llm
	_cfg = BotConfig.cfg().get("local_ai", {})
	if use_llm:
		ai = LocalAI.new()
		ai.name = "LocalAI"
		add_child(ai)
		ai.setup(_cfg)
		ai.start()
	print("[planner] %s plans its own objectives (%s)" % [Net.display_name(brain.player.player_id), "local AI" if use_llm else "scripted"])


func _physics_process(delta: float) -> void:
	if brain == null or GameState.phase != GameState.Phase.PLAYING:
		return
	if brain.player.downed or brain.player.spectating:
		directive = {}   # nothing to plan from the floor; a fresh pick once it is up again
		_t = 0.5
		return
	_speak_t -= delta
	_t -= delta
	if ai != null and not _announced and (ai.is_ready() or ai.state == LocalAI.State.OFFLINE):
		_announced = true
		_announce()
	var gone: bool = not directive.is_empty() and not is_instance_valid(directive.get("node"))
	if _t <= 0.0 or gone:
		_t = float(_cfg.get("decide_every_s", 4.0))
		_decide(gone)


## The brain's errand for `id` is over; a failure keeps that option out for fail_cooldown_s.
func on_errand_finished(id: String, ok: bool) -> void:
	if not ok:
		_failed[id] = squad.time() + float(_cfg.get("fail_cooldown_s", 25.0))
	if str(directive.get("id", "")) == id:
		directive = {}
	_t = minf(_t, 0.05)


func status_line() -> String:
	var src: String = ai.status_text() if ai != null else "scripted"
	return "planner [%s] picks: %d LLM / %d scripted, objectives done %d: %s" % [src, llm_picks, scripted_picks,
		brain.objectives_done, str(directive.get("label", "-"))]


# ------------------------------------------------------------------ deciding

func _decide(force: bool) -> void:
	options = gather()
	decisions += 1
	if options.is_empty():
		directive = {}
		return
	var cur: String = str(directive.get("id", ""))
	var fb: int = fallback_index(_scores(options), _ids(options), cur)
	if ai != null and ai.is_ready():
		var ids: Array = _ids(options)
		var sent: bool = ai.ask(_messages(cur), reply_schema(ids), func(reply: Variant, ms: int) -> void: _on_reply(reply, ms, ids))
		if not sent and (force or directive.is_empty()):
			_set_directive(options[fb], "scripted (model busy)", "")
		elif sent and (force or directive.is_empty()):
			_set_directive(options[fb], "scripted (while the model thinks)", "")
		return
	_set_directive(options[fb], "scripted", "")


func _on_reply(reply: Variant, ms: int, ids: Array) -> void:
	if brain == null or not is_instance_valid(brain):
		return
	var i: int = choice_index(reply, ids)
	if i < 0:
		return   # nonsense: the scripted pick stands until the next decision
	var id: String = str(ids[i])
	for o: Dictionary in options:
		if str(o["id"]) == id and is_instance_valid(o.get("node")):
			var say: String = str((reply as Dictionary).get("say", "")).strip_edges() if reply is Dictionary else ""
			_set_directive(o, "local AI %d ms" % ms, say)
			return


func _set_directive(o: Dictionary, source: String, say: String) -> void:
	if source.begins_with("local AI"):
		llm_picks += 1
	else:
		scripted_picks += 1
	var changed: bool = str(o.get("id", "")) != str(directive.get("id", ""))
	directive = o
	if not changed:
		return
	var line: String = "%.0fs %s -> %s (%s)" % [squad.time(), source, str(o["id"]), str(o.get("label", ""))]
	history.append(line)
	if history.size() > 24:
		history.remove_at(0)
	print("[planner] %s: %s" % [Net.display_name(brain.player.player_id), line])
	if say != "" and bool(_cfg.get("speak", true)) and _speak_t <= 0.0:
		_speak_t = float(_cfg.get("speak_cooldown_s", 22.0))
		_say(say.left(90))


func _say(text: String) -> void:
	var spk: StringName = GLVO.CHARACTER_SPEAKERS.get(brain.player.character_id, &"DUT")
	GLBus.vo_line_started.emit(&"BOT_AI", spk, text, maxf(2.2, float(text.length()) * 0.07))


func _announce() -> void:
	var who: String = Net.display_name(brain.player.player_id)
	if ai.is_ready():
		_say("[%s is on local AI: %s]" % [who, ai.model])
	else:
		_say("[Local AI offline (%s): %s plans on its own]" % [ai.last_error.left(40), who])


static func _scores(opts: Array[Dictionary]) -> Array:
	var out: Array = []
	for o: Dictionary in opts:
		out.append(float(o.get("score", 0.0)))
	return out


static func _ids(opts: Array[Dictionary]) -> Array:
	var out: Array = []
	for o: Dictionary in opts:
		out.append(str(o["id"]))
	return out


## The scripted pick: the best score, the current objective with a small bonus so it isn't dropped for a near
## tie (pure, unit-tested). -1 when empty.
static func fallback_index(scores: Array, ids: Array, current: String, stickiness: float = 8.0) -> int:
	var best: int = -1
	var best_s: float = -INF
	for i: int in scores.size():
		var s: float = float(scores[i]) + (stickiness if i < ids.size() and str(ids[i]) == current else 0.0)
		if s > best_s:
			best_s = s
			best = i
	return best


## The option a model reply names: {"choice": "<id>"} exactly, case-insensitively, or by its 1-based number
## (pure, unit-tested). -1 when it names nothing on the list.
static func choice_index(reply: Variant, ids: Array) -> int:
	if not reply is Dictionary:
		return -1
	var c: String = str((reply as Dictionary).get("choice", "")).strip_edges()
	if c == "":
		return -1
	var i: int = ids.find(c)
	if i >= 0:
		return i
	for k: int in ids.size():
		if str(ids[k]).to_lower() == c.to_lower():
			return k
	if c.is_valid_int() and int(c) >= 1 and int(c) <= ids.size():
		return int(c) - 1
	return -1


## The JSON schema for a reply: the option ids as an enum, and a short remark.
static func reply_schema(ids: Array) -> Dictionary:
	return {"type": "object", "properties": {"choice": {"type": "string", "enum": ids}, "say": {"type": "string"}},
		"required": ["choice", "say"]}


const SYSTEM_PROMPT: String = """You are %s, a survivor in GRAVELIGHT, a round-based co-op zombie game like Call of Duty Zombies, fighting next to a human teammate. You decide what you set out to do next; your body handles walking, aiming and shooting, and always fights back, revives and flees on its own.
Your goals, in order: stay alive and keep the team alive; finish the map's easter egg quest, one step at a time; turn the power on; open doors that block the quest; buy perks and better guns with your own Scrip; rebuild boards.
Keep your current objective unless it is finished, impossible, or a clearly better one appeared. Regroup with the team when the human is hurt or swarmed. Do not spend Scrip the next quest step needs.
Each option shows a suggested priority score; higher is usually better.
Reply only with JSON: {"choice": "<one option id>", "say": "<a short in-character remark, at most 12 words>"}."""


func _messages(current: String) -> Array:
	var who: String = Net.display_name(brain.player.player_id)
	return [
		{"role": "system", "content": SYSTEM_PROMPT % who},
		{"role": "user", "content": build_prompt(_state_lines(), options, current)},
	]


## The user turn: the match state, then the options (pure, unit-tested).
static func build_prompt(state_lines: PackedStringArray, opts: Array[Dictionary], current: String) -> String:
	var lines: PackedStringArray = state_lines.duplicate()
	lines.append("Current objective: %s" % (current if current != "" else "none"))
	lines.append("Options:")
	for o: Dictionary in opts:
		lines.append("- %s: %s [score %d]" % [str(o["id"]), str(o.get("label", "")), int(round(float(o.get("score", 0.0))))])
	lines.append("Pick one option id.")
	return "\n".join(lines)


func _state_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	var p: Player = brain.player
	var dir: ZombieDirector = squad.director()
	var alive: int = dir.active_zombies().size() if dir != null else 0
	var phase: String = "fighting" if RoundManager.state == RoundManager.State.ROUND else "break between rounds"
	out.append("Map: %s. Round %d (%s, %d zombies up, %d still to come). Power: %s." % [squad.map.display_name,
		RoundManager.current_round, phase, alive, RoundManager.to_spawn, "on" if GameState.power_on else "off"])
	var guns: PackedStringArray = []
	for w: WeaponInstance in p.weapons.slots:
		guns.append("%s (%d/%d)" % [w.display_name(), w.mag, w.reserve])
	var perks: PackedStringArray = []
	for pk: Variant in PerkManager.owned(p.player_id):
		perks.append(PerkManager.display_name(StringName(pk)))
	out.append("You: health %d/%d, Scrip %d, guns %s, perks %s." % [int(p.hp), int(p.max_hp), Economy.get_scrip(p.player_id),
		", ".join(guns), ", ".join(perks) if not perks.is_empty() else "none"])
	for q: Player in squad.all_players():
		if q == p:
			continue
		var st: String = "spectating" if q.spectating else ("DOWN" if q.downed else "standing")
		out.append("%s (%s): %s, health %d, %d m away." % [Net.display_name(q.player_id), "bot" if q.is_bot else "human",
			st, int(q.hp), int(brain.flat_distance(q.global_position))])
	for qid: StringName in QuestManager.quest_ids():
		var done: int = 0
		var total: int = 0
		var active: PackedStringArray = []
		for step: Variant in QuestManager.steps_of(qid):
			var sid: StringName = StringName(str((step as Dictionary)["id"]))
			total += 1
			if QuestManager.is_step_done(qid, sid):
				done += 1
			elif QuestManager.is_active(qid, sid):
				active.append(String(sid))
		var state: String = "complete" if QuestManager.is_complete(qid) else "%d/%d steps done, active: %s" % [done, total, ", ".join(active) if not active.is_empty() else "none"]
		out.append("Quest \"%s\": %s." % [QuestManager.display_name_of(qid), state])
	return out


# ------------------------------------------------------------------ the options

## Everything the bot could set out to do now, best score first, at most max_options (the current one kept).
func gather() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if squad.time() - _nodes_t > 8.0:
		_nodes_t = squad.time()
		_nodes = squad.map.find_children("*", "Interactable", true, false)
	_egg_options(out)
	_power_option(out)
	var me: Vector3 = brain.player.global_position
	for c: Dictionary in brain.errand_candidates(me, 6.0):
		var o: Dictionary = c.duplicate()
		o["id"] = "%s:%s" % [str(c["kind"]), String((c["node"] as Node).name)]
		out.append(o)
	out.append(_follow_option())
	# drop the ones that just failed, keep the best of any duplicate id, best first
	var by_id: Dictionary = {}
	for o2: Dictionary in out:
		var id: String = str(o2["id"])
		if float(_failed.get(id, -INF)) > squad.time():
			continue
		if not by_id.has(id) or float(o2["score"]) > float((by_id[id] as Dictionary)["score"]):
			by_id[id] = o2
	var sorted: Array[Dictionary] = []
	for v: Variant in by_id.values():
		sorted.append(v as Dictionary)
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var cap: int = int(_cfg.get("max_options", 9))
	if sorted.size() > cap:
		var cur: String = str(directive.get("id", ""))
		var keep: Array[Dictionary] = sorted.slice(0, cap)
		for o3: Dictionary in sorted.slice(cap):
			if str(o3["id"]) == cur:
				keep[cap - 1] = o3
		sorted = keep
	for o4: Dictionary in sorted:
		var n: Node3D = o4.get("node") as Node3D
		if n != null and str(o4["kind"]) != "follow":
			o4["label"] = "%s (%d m)" % [str(o4.get("label", "")), int(brain.flat_distance(n.global_position))]
	return sorted


func _egg_score() -> float:
	return float(_cfg.get("egg_score", 70.0))


func _dist_cost(n: Node3D) -> float:
	return brain.flat_distance(n.global_position) * 0.25


func _egg_options(out: Array[Dictionary]) -> void:
	var qids: Array[StringName] = QuestManager.quest_ids()
	for qi: int in qids.size():
		var qid: StringName = qids[qi]
		if QuestManager.is_complete(qid):
			continue
		var base: float = _egg_score() - (0.0 if qi == 0 else 18.0)   # the first quest file is the main egg
		var qname: String = QuestManager.display_name_of(qid)
		for step: Variant in QuestManager.steps_of(qid):
			var sd: Dictionary = step as Dictionary
			var sid: StringName = StringName(str(sd["id"]))
			if QuestManager.is_active(qid, sid):
				_step_options(out, qid, sid, sd, base, "Easter egg \"%s\"" % qname)
	# quest items lying about (the Nachtglas shard after the drummer is shot)
	for n: Node in _nodes:
		var qp: QuestPickup = n as QuestPickup
		if qp != null and is_instance_valid(qp) and qp.item_id != &"" and qp.is_visible_in_tree() and qp.can_interact(brain.player):
			_use_option(out, "egg:item:%s" % qp.name, qp, _egg_score() + 20.0, "Easter egg: pick up %s" % qp.label, {})


## The options for one active quest step, by step type.
func _step_options(out: Array[Dictionary], qid: StringName, sid: StringName, step: Dictionary, base: float, tag: String) -> void:
	var p: Dictionary = step.get("params", {})
	var ctx: Dictionary = {"qid": String(qid), "sid": String(sid)}
	var me: Player = brain.player
	match str(step.get("type", "")):
		"collect":
			var t: StringName = StringName(str(p.get("tag", "")))
			var got: Variant = QuestManager.progress(qid, sid)
			var have: int = (got as Array).size() if got is Array else 0
			for n: Node3D in _collectables(t, got if got is Array else []):
				_use_option(out, "egg:%s:%s" % [sid, n.name], n, base, "%s: pick up %s (%d/%d found)" % [tag, _thing_name(n), have, int(p.get("count", 1))], ctx)
		"sequence":
			var target: StringName = StringName(str(p.get("target", "")))
			if target == &"four_bells":
				var bells: Dictionary = {}
				for b: Node in get_tree().get_nodes_in_group(&"quest_bells"):
					var qb: QuestBell = b as QuestBell
					if qb.kind == &"small" and qb.visible:
						bells[String(qb.note)] = qb
				if not bells.is_empty():
					var first: Node3D = bells.values()[0]
					var o: Dictionary = {"id": "egg:%s" % sid, "kind": "shoot_seq", "node": first, "bells": bells, "vantages": {},
						"score": base + 5.0, "label": "%s: ring the Four Bells in the music box's order" % tag, "extra_s": 120.0}
					o.merge(ctx)
					out.append(o)
				return
			for n2: Node in _nodes:
				var hit: bool = (n2 is FieldRadio and (n2 as FieldRadio).quest_target == target) or (n2 is Switchboard and (n2 as Switchboard).target == target)
				if not hit or not is_instance_valid(n2):
					continue
				var what: String = "tune the radio to the notes' frequencies" if n2 is FieldRadio else "plug the radio code into the switchboard"
				_use_option(out, "egg:%s" % sid, n2 as Node3D, base + 5.0, "%s: %s" % [tag, what], ctx, "radio" if n2 is FieldRadio else "switchboard")
		"interact":
			var target2: StringName = StringName(str(p.get("target", "")))
			if not QuestManager.interact_ready(target2):
				return
			var node: Node3D = _interact_node(target2)
			if node != null:
				_use_option(out, "egg:%s" % sid, node, base + 5.0, "%s: use the %s" % [tag, _thing_name(node)], ctx)
		"build":
			if BuildablePart.parts_held() < 3:
				for n3: Node in get_tree().get_nodes_in_group(&"buildable_parts"):
					var bp: BuildablePart = n3 as BuildablePart
					if bp.visible and bp.can_interact(me):
						_use_option(out, "egg:%s:%s" % [sid, bp.name], bp, base, "%s: pick up %s (%d/3)" % [tag, BuildablePart.NAMES.get(bp.part_id, "a part"), BuildablePart.parts_held()], ctx)
			else:
				for n4: Node in get_tree().get_nodes_in_group(&"workbenches"):
					var wb: Workbench = n4 as Workbench
					if not wb.built and wb.can_interact(me):
						_use_option(out, "egg:%s" % sid, wb, base + 5.0, "%s: build the %s at the workbench" % [tag, String(wb.buildable_id).capitalize()], ctx)
		"flag":
			var flag: String = str(p.get("flag", ""))
			if flag == "power_on":
				return   # the power option carries the egg bonus (_power_option)
			if flag == "core_vault_open":
				for n5: Node in get_tree().get_nodes_in_group(&"pylons"):
					var py: Pylon = n5 as Pylon
					if py.state == Pylon.State.CHARGING:
						var oh: Dictionary = {"id": "egg:%s:%s" % [sid, py.name], "kind": "hold", "node": py, "cond": "pylon",
							"pos": brain._snap(py.global_position), "radius": py.radius * 0.45, "extra_s": 90.0,
							"score": base + 12.0 - _dist_cost(py), "label": "%s: stand in the charging pylon's ring" % tag}
						oh.merge(ctx)
						out.append(oh)
					elif py.can_interact(me) and Economy.get_scrip(me.player_id) >= int(Pylon.cfg().get("cost", 1500)) and _human_near(py.global_position, 22.0):
						# a pylon is a 45 s holdout with doubled spawns that holds the round open: only with the
						# human close by, never alone across the map
						_use_option(out, "egg:%s:%s" % [sid, py.name], py, base, "%s: attune a Resonance Pylon with %s (%d Scrip, then hold its ring)" % [tag, Net.display_name(squad.human().player_id), int(Pylon.cfg().get("cost", 1500))], ctx)
		"kill_condition":
			_chapel_options(out, qid, sid, p, base, tag, ctx)
		"chase":
			var drummers: Array[Node] = get_tree().get_nodes_in_group(&"quest_drummers")
			if not drummers.is_empty():
				var od: Dictionary = {"id": "egg:%s:shoot" % sid, "kind": "shoot_moving", "node": drummers[0], "score": base + 30.0,
					"label": "%s: shoot Herr Tamtam before he marches off" % tag, "extra_s": 0.0}
				od.merge(ctx)
				out.append(od)
				return
			var crate: MysteryCrate = _current_crate()
			if crate != null and Economy.get_scrip(me.player_id) >= CrateManager.cost() + int(_cfg.get("crate_reserve_scrip", 250)):
				_use_option(out, "egg:%s:crate" % sid, crate, base - 6.0, "%s: pull the Requisition Crate until Herr Tamtam hops out (%d Scrip)" % [tag, CrateManager.cost()], ctx, "crate")
		"kill_count":
			var weps: Array = p.get("weapon", []) if p.get("weapon") is Array else [p.get("weapon", "")]
			var held: String = ""
			for w: WeaponInstance in me.weapons.slots:
				if weps.has(String(w.id)) or weps.has(String(w.base_id())):
					held = String(w.base_id())
			if held == "":
				for n6: Node in get_tree().get_nodes_in_group(&"workbenches"):
					var wb2: Workbench = n6 as Workbench
					if wb2.built and wb2.can_interact(me):
						_use_option(out, "egg:%s:take" % sid, wb2, base + 5.0, "%s: take the %s from the workbench" % [tag, String(weps[0]).capitalize()], ctx)
				return
			var c: Array = p.get("center", [0, 0, 0])
			var center: Vector3 = Vector3(float(c[0]), float(c[1]), float(c[2]))
			var ok: Dictionary = {"id": "egg:%s" % sid, "kind": "hold", "node": squad.map, "cond": "step", "weapon": held,
				"pos": brain._snap(center), "radius": minf(float(p.get("radius", 15.0)) * 0.4, 5.0), "extra_s": 240.0,
				"score": base + 5.0, "label": "%s: kill zombies with the %s near the heart (%s)" % [tag, held.capitalize(), str(QuestManager.progress(qid, sid))]}
			ok.merge(ctx)
			out.append(ok)
		"holdout":
			if not QuestManager.holdout_state(qid, sid).is_empty():
				var pts: Array = p.get("points", [])
				var sum: Vector3 = Vector3.ZERO
				for pt: Variant in pts:
					sum += Vector3(float(pt[0]), float(pt[1]), float(pt[2]))
				var mid: Vector3 = sum / maxf(1.0, float(pts.size())) if not pts.is_empty() else brain.player.global_position
				var oh2: Dictionary = {"id": "egg:%s:hold" % sid, "kind": "hold", "node": squad.map, "cond": "holdout",
					"pos": brain._snap(mid), "radius": 5.0, "extra_s": float(p.get("duration", 120.0)) + 30.0,
					"score": base + 30.0, "label": "%s: hold the zone through the holdout" % tag}
				oh2.merge(ctx)
				out.append(oh2)
				return
			var st: StringName = StringName(str(p.get("start_target", "")))
			if QuestManager.interact_ready(st):
				var node2: Node3D = _interact_node(st)
				if node2 != null:
					_use_option(out, "egg:%s:start" % sid, node2, base - 5.0, "%s: begin the holdout at the %s (%d s, a hard fight)" % [tag, _thing_name(node2), int(p.get("duration", 120.0))], ctx)


## Step 4 of the Requiem shape: light the Chapel bell with an upgraded gun, then hold the Chapel for the Foreman.
func _chapel_options(out: Array[Dictionary], _qid: StringName, sid: StringName, p: Dictionary, base: float, tag: String, ctx: Dictionary) -> void:
	var flag: StringName = StringName(str(p.get("world_flag", "")))
	var bell: QuestBell = null
	for b: Node in get_tree().get_nodes_in_group(&"quest_bells"):
		if (b as QuestBell).kind == &"chapel":
			bell = b as QuestBell
	if bell == null:
		return
	var vp: Vector3 = brain.vantage_for(bell.global_position)
	if vp == Vector3.INF:
		_blocked(out, bell, base - 4.0, tag)
		return
	if flag != &"" and GameState.has_flag(flag):
		var o: Dictionary = {"id": "egg:%s:hold" % sid, "kind": "hold", "node": bell, "cond": "chapel", "pos": vp, "radius": 4.0,
			"extra_s": 100.0, "score": base + 20.0, "label": "%s: hold the lit Chapel and kill the %s there" % [tag, str(p.get("enemy", "boss")).capitalize()]}
		o.merge(ctx)
		out.append(o)
		return
	var has_up: bool = false
	for w: WeaponInstance in brain.player.weapons.slots:
		has_up = has_up or w.upgraded
	if has_up:
		var o2: Dictionary = {"id": "egg:%s:bell" % sid, "kind": "shoot", "node": bell, "vantage": vp, "need_upgraded": true,
			"cond": "bell_lit", "score": base + 5.0 - _dist_cost(bell), "label": "%s: light the Chapel bell with an upgraded gun" % tag}
		o2.merge(ctx)
		out.append(o2)
		return
	# no upgraded gun yet: the Crucible first, early if need be
	var econ: Dictionary = GLData.table("economy")
	var cost: int = Crucible.price_for(&"upgrade", econ)
	if Economy.get_scrip(brain.player.player_id) >= cost and brain._upgradeable_slot() >= 0:
		var cr: Crucible = brain.crucible_for_me(INF, brain.player.global_position)
		if cr != null:
			out.append({"id": "crucible:%s" % cr.name, "kind": "crucible", "node": cr, "score": base,
				"label": "%s: upgrade a gun at the Crucible (%d Scrip) to light the Chapel bell" % [tag, cost]})


## A use/radio/switchboard/crate option at `node` (reachable stand point required), or the door in the way.
func _use_option(out: Array[Dictionary], id: String, node: Node3D, score: float, label: String, ctx: Dictionary, kind: String = "use") -> void:
	var sp: Vector3 = brain.stand_point(node)
	if sp == Vector3.INF:
		_blocked(out, node, score - 4.0, label)
		return
	var o: Dictionary = {"id": id, "kind": kind, "node": node, "stand": sp, "score": score - _dist_cost(node), "label": label}
	o.merge(ctx)
	out.append(o)


## The closed door that most likely stands between the bot and `goal`: affordable, usable now, its near side
## reachable, and nearest the goal. Offered just under the objective it unblocks.
func _blocked(out: Array[Dictionary], goal: Node3D, score: float, why: String) -> void:
	var me: Player = brain.player
	var scrip: int = Economy.get_scrip(me.player_id)
	var best: BuyDoor = null
	var best_d: float = INF
	for n: Node in get_tree().get_nodes_in_group(&"doors"):
		var d: BuyDoor = n as BuyDoor
		if d == null or d.is_open or not d.can_interact(me) or scrip < d.cost:
			continue
		if not brain.reachable(BotBrain._door_side(d, me.global_position)):
			continue
		var dd: float = Vector2(d.global_position.x - goal.global_position.x, d.global_position.z - goal.global_position.z).length()
		if dd < best_d:
			best_d = dd
			best = d
	if best != null:
		out.append({"id": "door:%s" % best.name, "kind": "door", "node": best, "score": score - _dist_cost(best),
			"label": "open the %s (%d Scrip): it is in the way to: %s" % [BotBrain.door_label(best), best.cost, why]})


func _power_option(out: Array[Dictionary]) -> void:
	if GameState.power_on:
		return
	var egg_needs: bool = false
	for qid: StringName in QuestManager.quest_ids():
		for step: Variant in QuestManager.steps_of(qid):
			var sd: Dictionary = step as Dictionary
			if str(sd.get("type", "")) == "flag" and str((sd.get("params", {}) as Dictionary).get("flag", "")) == "power_on" \
					and QuestManager.is_active(qid, StringName(str(sd["id"]))):
				egg_needs = true
	var score: float = _egg_score() + 10.0 if egg_needs else (52.0 if RoundManager.current_round >= 2 else 34.0)
	for n: Node in get_tree().get_nodes_in_group(&"power_switch"):
		var ps: PowerSwitch = n as PowerSwitch
		if ps != null and ps.can_interact(brain.player):
			_use_option(out, "power:%s" % ps.name, ps, score, "throw the power switch (perks, the Crucible and powered doors need it)", {})


## The human is standing within `r` metres (flat) of `p`.
func _human_near(p: Vector3, r: float) -> bool:
	var h: Player = squad.human()
	if h == null or h.spectating or h.downed:
		return false
	return Vector2(h.global_position.x - p.x, h.global_position.z - p.z).length() <= r


func _follow_option() -> Dictionary:
	var h: Player = squad.human()
	var score: float = float(_cfg.get("follow_score", 12.0))
	var label: String = "stick with the team and fight"
	if h != null and not h.spectating:
		var near: int = 0
		var dir: ZombieDirector = squad.director()
		if dir != null:
			for z: Zombie in dir.active_zombies():
				if z.global_position.distance_to(h.global_position) < 7.0:
					near += 1
		score += minf(float(near) * 7.0, 55.0)
		if h.hp < h.max_hp * 0.5:
			score += 20.0
		label = "regroup with %s and fight (%d zombies near them, health %d)" % [Net.display_name(h.player_id), near, int(h.hp)]
	return {"id": "follow", "kind": "follow", "node": h if h != null else brain.player, "score": score, "label": label}


func _collectables(tag: StringName, got: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var me: Player = brain.player
	for n: Node in _nodes:
		if not is_instance_valid(n):
			continue
		if n is QuestNote and (n as QuestNote).tag == tag and (n as QuestNote).can_interact(me):
			out.append(n as Node3D)
		elif n is QuestPickup and (n as QuestPickup).collect_tag == tag and (n as QuestPickup).can_interact(me) and (n as QuestPickup).is_visible_in_tree():
			out.append(n as Node3D)
		elif n is QuestRadio and tag == &"quest_radio" and (n as QuestRadio).can_interact(me) and not got.has((n as QuestRadio).radio_id):
			out.append(n as Node3D)
	return out


func _interact_node(target: StringName) -> Node3D:
	for n: Node in _nodes:
		if not is_instance_valid(n):
			continue
		match target:
			&"altar":
				if n is AltarReliquary:
					return n as Node3D
			&"phonograph":
				if n is Phonograph:
					return n as Node3D
			&"crucible_shard", &"crucible_heartstorm":
				if n is Crucible:
					return n as Node3D
		if n is QuestPickup and (n as QuestPickup).interact_target == target and (n as QuestPickup).can_interact(brain.player):
			return n as Node3D
	return null


func _current_crate() -> MysteryCrate:
	for s: Node in get_tree().get_nodes_in_group(&"crate_spots"):
		var c: MysteryCrate = s as MysteryCrate
		if c != null and c.spot_index == CrateManager.location_index and c.phase == MysteryCrate.Phase.CLOSED:
			return c
	return null


static func _thing_name(n: Node) -> String:
	if n is QuestNote:
		return "radio note %s" % (n as QuestNote).numeral
	if n is QuestPickup:
		return (n as QuestPickup).label
	if n is QuestRadio:
		return "the calling radio"
	if n is AltarReliquary:
		return "altar reliquary"
	if n is Crucible:
		return "Crucible"
	return String(n.name).to_snake_case().replace("_", " ")
