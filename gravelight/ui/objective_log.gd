class_name ObjectiveLog
extends RefCounted
## The OBJECTIVES tab's model (Update 04 section 4, DECISIONS T-066; docs/gravelight/OBJECTIVES.md). Pure: it
## never touches the game. ObjectiveSnapshot reads the match into a plain Dictionary, this turns that snapshot,
## the text data (data/gravelight/objectives.json) and the spoiler level into the list the tab draws, and the
## tests feed it hand-made snapshots.
##
## Snapshot (Gravelight): {map_id, round, power, flags {name: value}, zones [open zone ids], jakub (state name or
## ""), exfil_active, settings {key: value}, intel_match [{id, title, type, text}], challenges [{id, name, desc,
## progress, target, scope, xp}], quests {quest_id: {title, complete, random {key: value}, steps [{id, type,
## status "complete"|"active"|"locked", n, target}]}}}.
## Snapshot (B&S): {game "bs", planet, mission, quests [{id, name, state, k, n, npc, npc_pos, reward}],
## gold [{id, found, how, p}], memos [{id, found, title, where, p}], challenges [...]}.
##
## Output: {spoiler, current: entry, sections: [{id, title, entries: [entry]}]}. An entry: {id, kind
## ("objective" | "header" | "step" | "challenge" | "intel" | "collectible" | "note"), status ("done" | "current" |
## "future" | "info"), title (the line), text (the detail pane), where, progress (0..1, or -1), progress_text,
## nodes [scene node names], pos ([x, y, z] or null), locatable, quest_id, step_id, bot_candidate, intel_id}.
##
## Spoiler levels (applied to the easter egg and the side quests):
##   hidden  completed steps only, no hints, no locations (an unstarted secret side quest is not listed at all);
##   hints   (default) completed steps, each current step as its in-character hint, future steps as "???";
##   full    completed steps, each current step as a clear instruction with where it is (and the MAP tab can
##           show it), future steps still "???".
## A future step's own text never appears at any level.

const HIDDEN: String = "hidden"
const HINTS: String = "hints"
const FULL: String = "full"
const LEVELS: PackedStringArray = ["hidden", "hints", "full"]
const LEVEL_NAMES: PackedStringArray = ["Hidden", "Hints", "Full Guide"]
const UNKNOWN: String = "???"
const DATA_PATH: String = "res://data/gravelight/objectives.json"


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return v if v is Dictionary else {}


## A valid level for any input ("" or junk -> the default, Hints).
static func level(s: Variant) -> String:
	var l: String = str(s).to_lower()
	return l if LEVELS.has(l) else HINTS


# ================================================================== the whole tab

static func build(snap: Dictionary, data: Dictionary, spoiler: String) -> Dictionary:
	if str(snap.get("game", "gravelight")) == "bs":
		return build_bs(snap, data, spoiler)
	var lv: String = level(spoiler)
	var m: Dictionary = (data.get("maps", {}) as Dictionary).get(str(snap.get("map_id", "")), {})
	var qtext: Dictionary = data.get("quests", {})
	var sections: Array = []
	# EASTER EGG
	var ee: Array = []
	for qid: Variant in m.get("easter_egg", []):
		ee.append_array(quest_entries(str(qid), snap, qtext.get(str(qid), {}), lv, "ee", true))
	if ee.is_empty():
		ee.append(_note("ee/none", "No easter egg on this map." if (m.get("easter_egg", []) as Array).is_empty() else "Nothing found yet."))
	sections.append({"id": "ee", "title": "EASTER EGG", "entries": ee})
	# SIDE QUESTS
	var side: Array = []
	for sq: Variant in m.get("side", []):
		var d: Dictionary = sq
		if d.has("quest"):
			side.append_array(quest_entries(str(d["quest"]), snap, qtext.get(str(d["quest"]), {}), lv, "side", false))
		else:
			side.append_array(tracked_entries(d, snap, lv))
	if side.is_empty():
		side.append(_note("side/none", "Nothing to note yet."))
	sections.append({"id": "side", "title": "SIDE QUESTS", "entries": side})
	sections.append({"id": "challenges", "title": "CHALLENGES", "entries": challenge_entries(snap.get("challenges", []))})
	sections.append({"id": "intel", "title": "INTEL", "entries": intel_entries(snap.get("intel_match", []))})
	return {"spoiler": lv, "current": current_objective(snap, m.get("current", [])), "sections": sections}


# ================================================================== CURRENT OBJECTIVE

## The first rule whose `when` holds (or has none) and whose `done` does not.
static func current_objective(snap: Dictionary, rules: Array) -> Dictionary:
	for r: Variant in rules:
		var rule: Dictionary = r
		if rule.has("when") and not eval(rule["when"], snap):
			continue
		if rule.has("done") and eval(rule["done"], snap):
			continue
		var e: Dictionary = _entry("current", "objective", "current", str(rule.get("text", "Survive.")))
		var p: Dictionary = rule.get("progress", {})
		if p.has("flag"):
			var n: int = _flag_int(snap, str(p["flag"]))
			var mx: int = maxi(1, int(p.get("max", 1)))
			e["progress"] = clampf(float(n) / float(mx), 0.0, 1.0)
			e["progress_text"] = "%d/%d" % [mini(n, mx), mx]
		elif p.has("round"):
			var target: int = maxi(1, int(p["round"]))
			var rn: int = int(snap.get("round", 0))
			e["title"] = "%s (round %d of %d)" % [e["title"], rn, target]
			e["progress"] = clampf(float(rn) / float(target), 0.0, 1.0)
			e["progress_text"] = "round %d / %d" % [rn, target]
		if e["progress_text"] != "" and not str(e["title"]).contains("round"):
			e["title"] = "%s (%s)" % [e["title"], e["progress_text"]]
		e["text"] = str(rule.get("detail", e["title"]))
		e["nodes"] = PackedStringArray(rule.get("nodes", []))
		e["locatable"] = not (e["nodes"] as PackedStringArray).is_empty()
		return e
	return _entry("current", "objective", "current", "Survive.")


# ================================================================== quests (QuestManager step graphs)

## A loaded quest's lines: a header and one line per step, through the spoiler filter. `listed_even_unstarted`:
## the easter egg is always listed; a side quest the squad hasn't touched is hidden at Hidden.
static func quest_entries(qid: String, snap: Dictionary, qtext: Dictionary, lv: String, section: String, listed_even_unstarted: bool) -> Array:
	var qs: Dictionary = (snap.get("quests", {}) as Dictionary).get(qid, {})
	if qs.is_empty():
		return []
	var steps: Array = qs.get("steps", [])
	var texts: Dictionary = qtext.get("steps", {})
	var done_n: int = 0
	for s: Variant in steps:
		if str((s as Dictionary).get("status", "")) == "complete":
			done_n += 1
	var complete: bool = bool(qs.get("complete", false)) or (done_n == steps.size() and not steps.is_empty())
	if lv == HIDDEN and done_n == 0 and not listed_even_unstarted:
		return []
	var out: Array = []
	var title: String = str(qtext.get("title", qs.get("title", qid)))
	var head: Dictionary = _entry("%s/%s" % [section, qid], "header", "done" if complete else "info",
		("%s  ✔" % title) if complete else title)
	head["quest_id"] = qid
	head["progress"] = float(done_n) / float(maxi(1, steps.size())) if lv != HIDDEN else -1.0
	head["progress_text"] = ("%d/%d steps" % [done_n, steps.size()]) if lv != HIDDEN else ("%d found" % done_n)
	head["text"] = "%s: %s" % [title, "complete." if complete else head["progress_text"] + "."]
	out.append(head)
	var shown: int = 0
	for s: Variant in steps:
		var st: Dictionary = s
		var sid: String = str(st.get("id", ""))
		var status: String = {"complete": "done", "active": "current"}.get(str(st.get("status", "locked")), "future")
		var t: Dictionary = texts.get(sid, {})
		var vars: Dictionary = step_vars(st, t, snap, qs.get("random", {}))
		var v: Dictionary = step_view(t, status, lv, vars)
		if v.is_empty():
			continue
		var e: Dictionary = _entry("%s/%s/%s" % [section, qid, sid], "step", status, str(v["title"]))
		e["text"] = str(v["text"])
		e["where"] = str(v["where"])
		e["quest_id"] = qid
		e["step_id"] = sid
		if status == "current" and lv != HIDDEN:
			# T-086: the step's story (what is going on, shown above the instruction) and the line that set it up
			e["story"] = str(t.get("story", ""))
			e["said"] = str(t.get("said", ""))
		if status == "current" and int(vars.get("target", -1)) > 0 and lv != HIDDEN:
			e["progress"] = clampf(float(vars["n"]) / float(vars["target"]), 0.0, 1.0)
			e["progress_text"] = "%d/%d" % [mini(int(vars["n"]), int(vars["target"])), int(vars["target"])]
		if bool(v["locate"]):
			e["nodes"] = step_nodes(t, qs.get("random", {}))
			e["pos"] = t.get("pos", null)
			e["locatable"] = not (e["nodes"] as PackedStringArray).is_empty() or e["pos"] != null
		e["bot_candidate"] = status == "current"
		out.append(e)
		shown += 1
	if shown == 0 and not complete:
		out.append(_note("%s/%s/none" % [section, qid], "Nothing found yet."))
	return out


## The spoiler filter for one step: {title, text, where, locate} or {} when the step is not shown at this level.
## Never returns a future step's own words.
static func step_view(t: Dictionary, status: String, lv: String, vars: Dictionary = {}) -> Dictionary:
	match status:
		"done":
			var d: String = fill(str(t.get("done", "Done.")), vars, false)
			return {"title": "✔ " + d, "text": d, "where": "", "locate": false}
		"current":
			if lv == HIDDEN:
				return {}
			if lv == FULL:
				var raw: String = str(t.get("guide", ""))
				if raw.strip_edges() == "":
					raw = str(t.get("hint", ""))
				var g: String = fill(raw, vars, true) if raw.strip_edges() != "" else UNKNOWN
				return {"title": "▸ " + g, "text": g, "where": str(t.get("where", "")), "locate": true}
			var h: String = fill(str(t.get("hint", "")), vars, false)
			if h.strip_edges() == "":
				h = UNKNOWN
			return {"title": "▸ " + h, "text": h, "where": "", "locate": false}
		_:
			if lv == HIDDEN:
				return {}
			return {"title": UNKNOWN, "text": UNKNOWN, "where": "", "locate": false}


## {n, target, rand} for a step's tokens: QuestManager progress counts, or a flag for flag steps.
static func step_vars(st: Dictionary, t: Dictionary, snap: Dictionary, random: Dictionary) -> Dictionary:
	var n: int = int(st.get("n", 0)) if st.get("n", null) != null else 0
	var target: int = int(st.get("target", -1)) if st.get("target", null) != null else -1
	var p: Dictionary = t.get("progress", {})
	if p.has("flag"):
		n = _flag_int(snap, str(p["flag"]))
		target = int(p.get("max", 1))
	return {"n": maxi(0, n), "target": target, "rand": random}


## Replaces {n}, {target} and (allow_random only) {rand:<key>}. A random token that isn't allowed becomes "???".
static func fill(text: String, vars: Dictionary, allow_random: bool) -> String:
	var out: String = text.replace("{n}", str(vars.get("n", 0)))
	var target: int = int(vars.get("target", -1))
	out = out.replace("{target}", str(target) if target >= 0 else "?")
	var rx: RegEx = RegEx.create_from_string("\\{rand:([a-z0-9_]+)\\}")
	for m: RegExMatch in rx.search_all(out):
		var key: String = m.get_string(1)
		var val: String = UNKNOWN
		if allow_random:
			val = random_text((vars.get("rand", {}) as Dictionary).get(key, null))
		out = out.replace(m.get_string(0), val)
	return out


## A seeded value as words: digits in pairs ("12 34 56"), a list joined, a dict's values.
static func random_text(v: Variant) -> String:
	if v == null:
		return UNKNOWN
	if v is String:
		var s: String = v
		if s.is_valid_int() and s.length() % 2 == 0 and s.length() > 2:
			var parts: PackedStringArray = []
			for i: int in range(0, s.length(), 2):
				parts.append(s.substr(i, 2))
			return " ".join(parts)
		return s
	if v is Array:
		return ", ".join(PackedStringArray((v as Array).map(func(x: Variant) -> String: return str(x))))
	if v is Dictionary:
		return ", ".join(PackedStringArray((v as Dictionary).values().map(func(x: Variant) -> String: return str(x))))
	return str(v)


## The scene nodes for a step's location: its `nodes`, plus `nodes_random` names built from the seeded picks.
static func step_nodes(t: Dictionary, random: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var nr: Dictionary = t.get("nodes_random", {})
	if not nr.is_empty():
		var v: Variant = random.get(str(nr.get("key", "")), null)
		var fmt: String = str(nr.get("format", "{v}"))
		if v is Dictionary:
			var keys: Array = (v as Dictionary).keys()
			keys.sort()
			for g: Variant in keys:
				out.append(fmt.replace("{g}", str(g)).replace("{v}", str(v[g])))
		elif v is Array:
			for x: Variant in v:
				out.append(fmt.replace("{g}", "").replace("{v}", str(x)))
	for n: Variant in t.get("nodes", []):
		out.append(str(n))
	return out


# ================================================================== tracked side quests (match flags)

## A side quest that is not a QuestManager graph (Jakub's escape, the Cousins' room): ordered steps, each
## complete when its `when` condition holds; the first incomplete one is current.
static func tracked_entries(def: Dictionary, snap: Dictionary, lv: String) -> Array:
	if def.has("show_when") and not eval(def["show_when"], snap):
		return []
	var qid: String = str(def.get("id", "side"))
	var title: String = str(def.get("title", qid))
	var out: Array = []
	if def.has("requires_setting") and not bool((snap.get("settings", {}) as Dictionary).get(str(def["requires_setting"]), true)):
		if lv == HIDDEN:
			return []
		var off: Dictionary = _entry("side/%s" % qid, "header", "info", title)
		off["text"] = "%s: switched off in Settings." % title
		out.append(off)
		out.append(_note("side/%s/off" % qid, "Off in Settings (%s)." % str(def["requires_setting"]).replace("_", " ").capitalize()))
		return out
	var steps: Array = def.get("steps", [])
	var statuses: Array = []
	var found_current: bool = false
	var done_n: int = 0
	for s: Variant in steps:
		if eval((s as Dictionary).get("when", {"never": true}), snap):
			statuses.append("done")
			done_n += 1
		elif not found_current:
			statuses.append("current")
			found_current = true
		else:
			statuses.append("future")
	if lv == HIDDEN and done_n == 0 and not bool(def.get("public", false)):
		return []
	var complete: bool = done_n == steps.size() and not steps.is_empty()
	var head: Dictionary = _entry("side/%s" % qid, "header", "done" if complete else "info", ("%s  ✔" % title) if complete else title)
	head["progress"] = float(done_n) / float(maxi(1, steps.size())) if lv != HIDDEN else -1.0
	head["progress_text"] = "%d/%d" % [done_n, steps.size()]
	head["text"] = "%s: %s" % [title, "complete." if complete else "%d/%d." % [done_n, steps.size()]]
	out.append(head)
	var shown: int = 0
	for i: int in steps.size():
		var t: Dictionary = steps[i]
		var v: Dictionary = step_view(t, statuses[i], lv, {})
		if v.is_empty():
			continue
		var e: Dictionary = _entry("side/%s/%s" % [qid, str(t.get("id", i))], "step", statuses[i], str(v["title"]))
		e["text"] = str(v["text"])
		e["where"] = str(v["where"])
		e["step_id"] = str(t.get("id", ""))
		if bool(v["locate"]):
			e["nodes"] = PackedStringArray(t.get("nodes", []))
			e["pos"] = t.get("pos", null)
			e["locatable"] = not (e["nodes"] as PackedStringArray).is_empty() or e["pos"] != null
		out.append(e)
		shown += 1
	if shown == 0 and not complete:
		out.append(_note("side/%s/none" % qid, "Nothing found yet."))
	return out


## Conditions (data/gravelight/objectives.json "_doc"). Unknown keys are false, so a typo never completes a step.
static func eval(cond: Variant, snap: Dictionary) -> bool:
	if not (cond is Dictionary):
		return bool(cond)
	var c: Dictionary = cond
	if c.is_empty():
		return true
	for k: Variant in c.keys():
		if not _eval_one(str(k), c[k], snap):
			return false
	return true


static func _eval_one(key: String, v: Variant, snap: Dictionary) -> bool:
	match key:
		"all":
			for x: Variant in v:
				if not eval(x, snap):
					return false
			return true
		"any":
			for x2: Variant in v:
				if eval(x2, snap):
					return true
			return false
		"not":
			return not eval(v, snap)
		"power":
			return bool(snap.get("power", false)) == bool(v)
		"flag":
			return _flag_true(snap, str(v))
		"flag_at_least":
			return _flag_int(snap, str(v[0])) >= int(v[1])
		"zone_open":
			return (snap.get("zones", []) as Array).has(str(v))
		"round_at_least":
			return int(snap.get("round", 0)) >= int(v)
		"step":
			var qs: Dictionary = (snap.get("quests", {}) as Dictionary).get(str(v[0]), {})
			for s: Variant in qs.get("steps", []):
				if str((s as Dictionary).get("id", "")) == str(v[1]):
					return str((s as Dictionary).get("status", "")) == "complete"
			return false
		"quest_done":
			return bool(((snap.get("quests", {}) as Dictionary).get(str(v), {}) as Dictionary).get("complete", false))
		"intel_match":
			for r: Variant in snap.get("intel_match", []):
				if str((r as Dictionary).get("id", "")) == str(v):
					return true
			return false
		"jakub_in":
			return (v as Array).has(str(snap.get("jakub", "")))
		"exfil_active":
			return bool(snap.get("exfil_active", false)) == bool(v)
		"setting":
			return bool((snap.get("settings", {}) as Dictionary).get(str(v), false))
	return false


static func _flag_true(snap: Dictionary, f: String) -> bool:
	var v: Variant = (snap.get("flags", {}) as Dictionary).get(f, null)
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	return true


static func _flag_int(snap: Dictionary, f: String) -> int:
	var v: Variant = (snap.get("flags", {}) as Dictionary).get(f, 0)
	if v is bool:
		return 1 if v else 0
	if v is int or v is float:
		return int(v)
	return 0


# ================================================================== challenges + intel

static func challenge_entries(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		var c: Dictionary = r
		var target: int = maxi(1, int(c.get("target", 1)))
		var p: int = int(c.get("progress", 0))
		var e: Dictionary = _entry("challenges/%s" % c.get("id", ""), "challenge", "done" if p >= target else "current",
			"%s: %s" % [c.get("name", c.get("id", "")), c.get("desc", "")])
		e["progress"] = clampf(float(p) / float(target), 0.0, 1.0)
		e["progress_text"] = "%d/%d" % [mini(p, target), target]
		e["text"] = "%s\n%s  ·  %s  ·  %d XP" % [c.get("desc", ""), e["progress_text"], "this match" if str(c.get("scope", "")) == "match" else "career", int(c.get("xp", 0))]
		out.append(e)
	if out.is_empty():
		out.append(_note("challenges/none", "No challenges running on this map."))
	return out


static func intel_entries(rows: Array) -> Array:
	var out: Array = []
	for r: Variant in rows:
		var d: Dictionary = r
		var e: Dictionary = _entry("intel/%s" % d.get("id", ""), "intel", "done", "✔ " + str(d.get("title", d.get("id", ""))))
		e["text"] = str(d.get("text", ""))
		e["intel_id"] = str(d.get("id", ""))
		out.append(e)
	if out.is_empty():
		out.append(_note("intel/none", "No intel found this match."))
	return out


# ================================================================== Bolt & Sprocket

static func build_bs(snap: Dictionary, data: Dictionary, spoiler: String) -> Dictionary:
	var lv: String = level(spoiler)
	var planet: String = str(snap.get("planet", "the planet"))
	var cur: Dictionary = _entry("current", "objective", "current", str(snap.get("mission", "")) if str(snap.get("mission", "")) != "" else "Explore " + planet)
	cur["text"] = cur["title"]
	var quests: Array = []
	for r: Variant in snap.get("quests", []):
		var q: Dictionary = r
		var st: String = str(q.get("state", "none"))
		var nm: String = str(q.get("name", q.get("id", "")))
		var npc: String = str(q.get("npc", "someone"))
		var e: Dictionary = {}
		match st:
			"done":
				e = _entry("side/%s" % q["id"], "step", "done", "✔ %s" % nm)
				e["text"] = "%s: done for %s. +%d bolts." % [nm, npc, int(q.get("reward", 0))]
			"ready":
				e = _entry("side/%s" % q["id"], "step", "current", "▸ %s: go back to %s" % [nm, npc])
				e["text"] = "%s: all done. Return to %s for %d bolts." % [nm, npc, int(q.get("reward", 0))]
				e["pos"] = q.get("npc_pos", null)
			"active":
				e = _entry("side/%s" % q["id"], "step", "current", "▸ %s (%d/%d)" % [nm, int(q.get("k", 0)), int(q.get("n", 1))])
				e["text"] = "%s for %s: %d/%d." % [nm, npc, int(q.get("k", 0)), int(q.get("n", 1))]
				e["progress"] = clampf(float(q.get("k", 0)) / float(maxi(1, int(q.get("n", 1)))), 0.0, 1.0)
				e["progress_text"] = "%d/%d" % [int(q.get("k", 0)), int(q.get("n", 1))]
			_:
				if lv == HIDDEN:
					continue
				if lv == FULL:
					e = _entry("side/%s" % q["id"], "step", "future", "%s: talk to %s" % [nm, npc])
					e["text"] = "%s asks a favour: %s. Find them on %s." % [npc, nm, planet]
					e["pos"] = q.get("npc_pos", null)
				else:
					e = _entry("side/%s" % q["id"], "step", "future", UNKNOWN)
					e["text"] = "Someone on %s needs a hand." % planet
		if e.get("pos", null) != null and (lv == FULL or st == "ready"):
			e["locatable"] = true
		quests.append(e)
	if quests.is_empty():
		quests.append(_note("side/none", "No side quests on this planet."))
	var sections: Array = [{"id": "side", "title": "SIDE QUESTS", "entries": quests},
		{"id": "gold", "title": "GOLD BOLTS", "entries": _bs_collectibles(snap.get("gold", []), "gold", "Gold bolt", lv)},
		{"id": "memos", "title": "MEMOS", "entries": _bs_collectibles(snap.get("memos", []), "memos", "Memo", lv)}]
	var ch: Array = challenge_entries(snap.get("challenges", []))
	if (snap.get("challenges", []) as Array).is_empty():
		ch = [_note("challenges/none", "No planet challenges yet.")]
	sections.append({"id": "challenges", "title": "CHALLENGES", "entries": ch})
	return {"spoiler": lv, "current": cur, "sections": sections}


static func _bs_collectibles(rows: Array, sec: String, noun: String, lv: String) -> Array:
	var out: Array = []
	var found: int = 0
	for r: Variant in rows:
		if bool((r as Dictionary).get("found", false)):
			found += 1
	var head: Dictionary = _entry("%s/head" % sec, "header", "done" if found == rows.size() and not rows.is_empty() else "info",
		"%ss found: %d / %d" % [noun, found, rows.size()])
	head["progress"] = float(found) / float(maxi(1, rows.size()))
	head["progress_text"] = "%d/%d" % [found, rows.size()]
	head["text"] = head["title"]
	out.append(head)
	var i: int = 0
	for r2: Variant in rows:
		i += 1
		var d: Dictionary = r2
		var label: String = str(d.get("title", "")) if str(d.get("title", "")) != "" else "%s %d" % [noun, i]
		if bool(d.get("found", false)):
			var e: Dictionary = _entry("%s/%s" % [sec, d.get("id", i)], "collectible", "done", "✔ " + label)
			e["text"] = label
			out.append(e)
		elif lv == FULL:
			var where: String = clean_bs_where(str(d.get("how", d.get("where", ""))))
			var e2: Dictionary = _entry("%s/%s" % [sec, d.get("id", i)], "collectible", "future", "%s %d: %s" % [noun, i, where])
			e2["text"] = where
			e2["where"] = where
			e2["pos"] = d.get("p", null)
			e2["locatable"] = e2["pos"] != null
			out.append(e2)
		elif lv == HINTS:
			out.append(_entry("%s/%s" % [sec, d.get("id", i)], "collectible", "future", UNKNOWN))
	return out


## The level files' gold "how" notes carry the source port's coordinates; the player sees only the words.
static func clean_bs_where(s: String) -> String:
	var rx: RegEx = RegEx.create_from_string("\\s*\\(source(?:[^()]|\\([^()]*\\))*\\)")
	var out: String = rx.sub(s, "", true)
	out = RegEx.create_from_string("^source #\\d+:\\s*").sub(out, "")
	out = RegEx.create_from_string("^S\\d+:\\s*").sub(out, "")
	return out.strip_edges()


# ================================================================== helpers

static func _entry(id: String, kind: String, status: String, title: String) -> Dictionary:
	return {"id": id, "kind": kind, "status": status, "title": title, "text": title, "where": "", "progress": -1.0,
		"progress_text": "", "nodes": PackedStringArray(), "pos": null, "locatable": false, "quest_id": "", "step_id": "",
		"bot_candidate": false, "intel_id": ""}


static func _note(id: String, text: String) -> Dictionary:
	return _entry(id, "note", "info", text)


## Every visible string of a built log, one per line (tests check what may and may not leak).
static func all_text(log: Dictionary) -> String:
	var parts: PackedStringArray = []
	var cur: Dictionary = log.get("current", {})
	parts.append(str(cur.get("title", "")))
	parts.append(str(cur.get("text", "")))
	for s: Variant in log.get("sections", []):
		parts.append(str((s as Dictionary).get("title", "")))
		for e: Variant in (s as Dictionary).get("entries", []):
			var d: Dictionary = e
			parts.append(str(d.get("title", "")))
			parts.append(str(d.get("text", "")))
			parts.append(str(d.get("where", "")))
	return "\n".join(parts)
