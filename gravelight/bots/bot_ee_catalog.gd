class_name BotEECatalog
extends RefCounted
## Bots on the easter egg (Update 04 section 5, T-067): the rules, as pure functions the hub, the executors and the
## unit tests share. Every quest step can carry a `bot_task` (data/gravelight/quests/*.json, docs/gravelight/
## EASTER_EGGS.md section 9), the data that tells a bot how to do it:
##   type        collect | shoot_target | hold_zone | carry | interact_sequence | kill_with_weapon | escort | turn_key
##   player_only "cutscene" / "final" / "choice" / "handoff": the player's alone; a bot asked for it covers them
##   needs       discovered-info keys (the quest's "bot_knowledge" block) the squad must know first
##   find        "seen" / "heard": each target must have been found by a squad member first
##   final       a last step: Full Partner waits for the player close by (ee.json full_final_wait_s, then goes on)
##   commit      "last_input": the input that finishes the step is the player's; in Full Partner the bot waits
##               ee.json full_commit_after_s for them, then makes it itself (T-086); the bot-mode agent is the
##               player and commits at once
##   risky       true / "shoot" / "trigger": that part can fail or set off the egg (the Chapel bell brings the
##               Foreman, a crate pull lets the drummer escape): only when the player ordered it
##   touches     ["crucible"] / ["perk"]: Jakub refuses those
##   node specs  {"group": g} or {"class": ScriptClass}, with "where": {property: value} ("visible": true = shown)
## The setting "Bot Easter-Egg Help" (GLSettings bot_ee_help): off (never), ask (When Asked: only steps the player
## assigns through the Objectives tab, a map mark or the ping key), full (Full Partner, the default since T-086: bots
## pick open steps themselves, one task at a time, and call out what they do).

const TYPES: PackedStringArray = ["collect", "shoot_target", "hold_zone", "carry", "interact_sequence", "kill_with_weapon", "escort", "turn_key"]
const MODES: PackedStringArray = ["off", "ask", "full"]
const MODE_LABELS: PackedStringArray = ["Off", "When Asked", "Full Partner"]
const SETTING: String = "bot_ee_help"


static func cfg() -> Dictionary:
	return BotAIData.table("ee")


## The mode from the settings values (ee.json default_mode, "full", when the key is missing or unknown).
static func mode_of(values: Dictionary) -> String:
	var dflt: String = str(cfg().get("default_mode", "full"))
	var m: String = str(values.get(SETTING, dflt))
	match m:
		"asked", "when_asked":
			return "ask"
		"partner", "full_partner":
			return "full"
	return m if MODES.has(m) else (dflt if MODES.has(dflt) else "full")


## A quest step's bot_task ({} none).
static func task_def(step: Dictionary) -> Dictionary:
	var t: Variant = step.get("bot_task", {})
	return t if t is Dictionary else {}


static func is_player_only(t: Dictionary) -> bool:
	return t.has("player_only") and str(t["player_only"]) != "" and str(t["player_only"]) != "false"


## Problems with one bot_task (the quest-data test runs this over every step).
static func validate(t: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	if t.is_empty():
		return ["no bot_task"]
	if is_player_only(t):
		return out
	var ty: String = str(t.get("type", ""))
	if not TYPES.has(ty):
		out.append("unknown type '%s'" % ty)
		return out
	match ty:
		"collect":
			if not t.get("targets") is Dictionary:
				out.append("collect needs targets")
		"interact_sequence", "turn_key":
			if not t.get("target") is Dictionary and not t.get("key") is Dictionary:
				out.append("%s needs a target" % ty)
		"shoot_target":
			if not t.get("target") is Dictionary and not t.get("sequence") is Dictionary:
				out.append("shoot_target needs a target or a sequence")
		"carry":
			if not t.get("deliver") is Dictionary:
				out.append("carry needs deliver")
			if not t.has("item") and not t.get("pickups") is Dictionary:
				out.append("carry needs an item or pickups")
		"kill_with_weapon":
			if not t.has("weapon"):
				out.append("kill_with_weapon needs a weapon")
		"hold_zone":
			if not t.get("anchors") is Dictionary and str(t.get("while", "")) == "":
				out.append("hold_zone needs anchors or a while")
	for k: String in ["targets", "target", "sequence", "pickups", "pickup", "deliver", "anchors", "get_weapon", "key", "partner_key", "then_pickup"]:
		if t.has(k) and t[k] is Dictionary:
			var spec: Dictionary = t[k]
			if not spec.has("group") and not spec.has("class"):
				out.append("%s: a node spec needs a group or a class" % k)
	if t.has("full_partner"):
		if not t["full_partner"] is Array:
			out.append("full_partner must be a list of stages")
		else:
			for st: Variant in t["full_partner"]:
				if str(t.get("risky", "")) != str(st):
					out.append("full_partner '%s' is not the task's risky stage" % str(st))
	return out


# ------------------------------------------------------------------ the gate (pure)

## Can a bot take this step's task? `ctx`:
##   mode "off"/"ask"/"full", ordered (the player assigned it), active / done (the step's state), companion (Jakub),
##   known (Dictionary of discovered keys), labels (key -> "heard the music box's melody"), player_near (the player
##   is at the step's spot, for final steps in Full Partner), jakub (ee.json jakub block)
## Returns {"ok", "code", "reason", "as"}: as = "task" (do it) or "escort" (a player-only step: cover the player).
## Codes: off, done, locked, no_task, player_only, not_asked, jakub_type, jakub_crucible, jakub_perk, info, risky,
## needs_player, ok.
static func gate(t: Dictionary, ctx: Dictionary) -> Dictionary:
	var mode: String = str(ctx.get("mode", "ask"))
	var ordered: bool = bool(ctx.get("ordered", false))
	if mode == "off":
		return _no("off", "Bot Easter-Egg Help is off.")
	if bool(ctx.get("done", false)):
		return _no("done", "That one's already done.")
	if not bool(ctx.get("active", false)):
		return _no("locked", "That step isn't open yet.")
	if t.is_empty():
		return _no("no_task", "The squad doesn't know how to help with that one.")
	if is_player_only(t):
		# U08 (T-131): the bot-mode agent IS the player: it does the player's steps itself (a cutscene, the last
		# input, a hand-off; a choice takes its default pick). In Full Partner a squad bot may take a choice's
		# default pick when the player is away or down, so the egg can finish; every other player step stays theirs.
		if bool(ctx.get("agent", false)):
			return {"ok": true, "code": "ok", "reason": "", "as": "task"}
		if str(t.get("player_only", "")) == "choice" and mode == "full" and bool(ctx.get("player_absent", false)):
			return {"ok": true, "code": "ok", "reason": "The player isn't here: taking the default.", "as": "task"}
		if ordered or (mode == "full" and bool(ctx.get("player_near", false))):
			return {"ok": true, "code": "player_only", "reason": "That one's yours (%s): covering you instead." % player_only_why(t), "as": "escort"}
		return _no("player_only", "That one's yours (%s)." % player_only_why(t))
	if not ordered and mode != "full":
		return _no("not_asked", "Waiting for your word (When Asked).")
	if bool(ctx.get("companion", false)):
		var jk: Dictionary = ctx.get("jakub", cfg().get("jakub", {}))
		var touches: Array = t.get("touches", [])
		var refuses: Array = jk.get("refuses", ["crucible", "perk"])
		for r: Variant in refuses:
			if touches.has(r):
				return _no("jakub_" + str(r), "Jakub won't go near the %s." % ("Crucible" if str(r) == "crucible" else "perk machines"))
		if not (jk.get("types", ["collect", "hold_zone", "carry", "escort"]) as Array).has(str(t.get("type", ""))):
			return _no("jakub_type", "Jakub only carries, collects and holds ground.")
	var miss: Array = missing_info(t, ctx.get("known", {}))
	if not miss.is_empty():
		var labels: Dictionary = ctx.get("labels", {})
		return _no("info", "Can't do that yet: we haven't %s." % str(labels.get(str(miss[0]), "found out how (" + str(miss[0]) + ")")))
	if is_risky(t, "") and not ordered:
		return _no("risky", "That could set the egg back: only on your word.")
	if bool(t.get("final", false)) and mode == "full" and not ordered and not bool(ctx.get("player_near", false)):
		return _no("needs_player", "That's a last step: it waits for you to be there.")
	return {"ok": true, "code": "ok", "reason": "", "as": "task"}


static func _no(code: String, reason: String) -> Dictionary:
	return {"ok": false, "code": code, "reason": reason, "as": ""}


static func player_only_why(t: Dictionary) -> String:
	match str(t.get("player_only", "")):
		"cutscene":
			return "it starts a cutscene"
		"final":
			return "the last step is yours to finish"
		"choice":
			return "a choice only you can make"
		"handoff":
			return "a hand-off only you can make"
	return "it's yours"


## The needs keys the squad doesn't know yet (`known`: Dictionary key -> anything).
static func missing_info(t: Dictionary, known: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in t.get("needs", []):
		if not known.has(str(k)):
			out.append(str(k))
	return out


## Is this task (stage "": the whole task; "shoot" / "trigger": that stage) one that needs an order?
static func is_risky(t: Dictionary, stage: String) -> bool:
	var r: Variant = t.get("risky", false)
	if r is bool:
		return r as bool
	if stage == "":
		return false   # a stage-only risk: the rest of the task is safe
	return str(r) == stage


## U10 (T-163): may this risky stage run now? Ordered (the player, or the agent who is the player) always; in Full
## Partner also a stage the task lists under "full_partner" (the Requiem's crate pull for Herr Tamtam, whose miss
## only resets the chase; the Chapel bell with a Crucible gun): the bot-mode agent works the egg in the 10-15 s
## breaks alone (its trainer owns the rounds), so those stages waited for it for whole matches.
static func stage_allowed(t: Dictionary, stage: String, ordered: bool, mode: String) -> bool:
	if not is_risky(t, stage) or ordered:
		return true
	return mode == "full" and (t.get("full_partner", []) as Array).has(stage)


# ------------------------------------------------------------------ the never-sequence-break guard (pure)

## May a bot make this ordered input? Only the input the sequence expects next (`expected[progress]`), unless the
## player ordered exactly this one (they marked that bell themselves). A wrong input resets the step, so a bot
## never guesses.
static func safe_input(expected: Array, progress: int, value: String, ordered: bool) -> bool:
	if ordered:
		return true
	return progress >= 0 and progress < expected.size() and str(expected[progress]) == value


## The commit rule: with commit "last_input" the input that would finish the step is the player's.
static func commit_blocked(t: Dictionary, progress: int, total: int) -> bool:
	return str(t.get("commit", "")) == "last_input" and total > 0 and progress >= total - 1


## T-086: may this bot make the commit anyway? The bot-mode agent is the player (always); a Full Partner bot once
## it has waited `waited_s` (since it said the last one was the player's) past ee.json full_commit_after_s; an
## assigned (When Asked) bot never.
static func commit_open(source: String, waited_s: float, is_agent: bool, c: Dictionary) -> bool:
	if is_agent:
		return true
	return source == "full" and waited_s >= 0.0 and waited_s >= float(c.get("full_commit_after_s", 45.0))


## T-086: a final step in Full Partner stops waiting for the player once `waited_s` (since a bot first could have
## started it) passed ee.json full_final_wait_s.
static func final_wait_over(waited_s: float, c: Dictionary) -> bool:
	return waited_s >= float(c.get("full_final_wait_s", 60.0))


## The utility value of a running task (ee.json value).
static func task_value(ty: String, c: Dictionary) -> float:
	var v: Dictionary = c.get("value", {})
	return float(v.get(ty, v.get("default", 0.8)))


## Should this task pause? `s`: {type, pressure, teammate_down, round_left (zombies up with nothing to spawn, -1 = the
## round isn't ending), player_away, was (the current pause reason, for the threat hysteresis)}. Returns the reason ("" = keep going): threat, teammate_down, round_end,
## player_away.
static func pause_reason(s: Dictionary, c: Dictionary) -> String:
	var pc: Dictionary = c.get("pause", {})
	var ty: String = str(s.get("type", ""))
	if bool(s.get("player_away", false)):
		return "player_away"
	# hysteresis: once paused for threat it waits for the pressure to drop to resume_pressure
	var limit: float = float(pc.get("resume_pressure", 0.45)) if str(s.get("was", "")) == "threat" else float(pc.get("pressure", 0.65))
	if float(s.get("pause_pressure", -1.0)) > 0.0:
		# U10 (T-163): a task's own threshold (the drummer's crate pulls go on under more pressure); resume the same
		# margin below it
		var own: float = float(s["pause_pressure"])
		limit = own - (float(pc.get("pressure", 0.65)) - float(pc.get("resume_pressure", 0.45))) if str(s.get("was", "")) == "threat" else own
	if not (pc.get("no_threat_pause_types", []) as Array).has(ty) and float(s.get("pressure", 0.0)) >= limit:
		return "threat"
	if bool(s.get("teammate_down", false)) and not (pc.get("no_down_pause_types", []) as Array).has(ty):
		return "teammate_down"
	var left: int = int(s.get("round_left", -1))
	if left > 0 and left <= int(pc.get("round_end_left", 2)) and not (pc.get("no_threat_pause_types", []) as Array).has(ty):
		return "round_end"
	if bool(s.get("shop", false)):
		return "shopping"   # T-153: ee.json shop_break: a rich bot steps off the egg to buy its kit
	return ""


## T-153 (ee.json shop_break): may a bot on an egg task take a shopping break now? It has `scrip` or more, its plan is
## not a hold, a door, an input or a hand-off (never mid-job), and its last break ended `every_s` ago. A Full Partner
## bot otherwise never stopped working the egg to shop: on Totenhafen the squad reached the round-10 diesel holds
## with 7,000-11,000 Scrip unspent and starting guns, and was wiped.
static func shop_break_due(scrip: int, plan_do: String, now: float, next_ok: float, sb: Dictionary) -> bool:
	if sb.is_empty() or now < next_ok or scrip < int(sb.get("scrip", 3000)):
		return false
	return not ["hold", "door", "input", "handoff", "turn"].has(plan_do)


## The voice category for a refusal / can't code (VO_SCRIPT section 18).
static func cant_category(code: String) -> String:
	match code:
		"info":
			return "EE_CANT_INFO"
		"not_found", "unreachable":
			return "EE_CANT_FIND"
		"needs_player", "player_away":
			return "EE_WAIT_PLAYER"
		"commit_self":
			return "EE_COMMIT_SELF"
		"risky":
			return "EE_CANT_RISKY"
		"player_only":
			return "EE_PLAYER_ONLY"
		"jakub_crucible":
			return "EE_REFUSE_CRUCIBLE"
		"jakub_perk":
			return "EE_REFUSE_PERK"
		"jakub_type":
			return "EE_REFUSE_TYPE"
	return "EE_CANT"


## What the bot is doing, for the status lines ("Collecting the radio notes").
static func verb(t: Dictionary, stage: String = "") -> String:
	var what: String = str(t.get("what", "the egg step"))
	if stage == "escort" or is_player_only(t):
		return "Covering you at %s" % what
	if stage == "handoff":
		return "Covering you at %s: the last one's yours" % what
	if stage == "door":
		return "Opening the way to %s" % what
	if stage == "wait":
		return "Waiting on %s" % what
	match str(t.get("type", "")):
		"collect":
			return "Collecting %s" % what
		"shoot_target":
			return "Shooting %s" % what
		"hold_zone":
			return "Holding %s" % what
		"carry":
			return "Carrying %s" % what
		"interact_sequence":
			return "Working %s" % what
		"kill_with_weapon":
			return "Charging %s" % what
		"escort":
			return "Covering you at %s" % what
		"turn_key":
			return "Standing at %s" % what
		"scout":
			return "Looking for %s" % what
	return "On %s" % what


# ------------------------------------------------------------------ node specs

## The nodes a spec names: {"group": g} or {"class": ScriptClass} (from `pool`, the map's Interactables, plus the
## group when both are given), filtered by "where" ({property: value}; "visible" = shown in the tree).
static func resolve(spec: Dictionary, tree: SceneTree, pool: Array) -> Array[Node]:
	var out: Array[Node] = []
	if spec.is_empty() or tree == null:
		return out
	var src: Array = []
	if spec.has("group"):
		src = tree.get_nodes_in_group(StringName(str(spec["group"])))
	elif spec.has("class"):
		src = pool
	var cls: String = str(spec.get("class", ""))
	var where: Dictionary = spec.get("where", {})
	for n: Variant in src:
		if not is_instance_valid(n) or not n is Node:   # (validity first: the pool can hold freed nodes)
			continue
		var node: Node = n as Node
		if cls != "" and not script_is(node, cls):
			continue
		if not matches(node, where):
			continue
		out.append(node)
	return out


static func matches(node: Node, where: Dictionary) -> bool:
	for k: Variant in where.keys():
		var want: Variant = where[k]
		if str(k) == "visible":
			var vis: bool = node is Node3D and (node as Node3D).is_visible_in_tree()
			if vis != bool(want):
				return false
			continue
		var have: Variant = node.get(StringName(str(k)))
		if have == null:
			return false
		if want is bool:
			if bool(have) != bool(want):
				return false
		elif str(have) != str(want):
			return false
	return true


## Is `n` an instance of the script class `cls` (or a subclass), or of the engine class?
static func script_is(n: Node, cls: String) -> bool:
	var s: Script = n.get_script() as Script
	while s != null:
		if String(s.get_global_name()) == cls:
			return true
		s = s.get_base_script()
	return n.is_class(cls)


## The node specs of a task that point at its objects (for ee_assign_node and the discovery sweep).
static func spec_keys() -> PackedStringArray:
	return ["targets", "target", "sequence", "pickups", "pickup", "deliver", "anchors", "key", "then_pickup", "get_weapon"]


## The id a collect target is counted under (its id_prop, default the node name).
static func target_id(n: Node, t: Dictionary) -> String:
	var p: String = str(t.get("id_prop", "name"))
	if p == "name":
		return String(n.name)
	return str(n.get(StringName(p)))
