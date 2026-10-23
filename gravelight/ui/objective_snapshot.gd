class_name ObjectiveSnapshot
extends RefCounted
## Reads the running match into the plain snapshot ObjectiveLog builds the OBJECTIVES tab from (DECISIONS T-066),
## and turns a selected entry back into world positions for the MAP tab. Everything that touches autoloads and
## scenes lives here so ObjectiveLog stays pure and testable.


## Gravelight. `intel_ids`: the intel found this match (the pause menu tracks it).
static func gravelight(tree: SceneTree, intel_ids: Array) -> Dictionary:
	var flags: Dictionary = {}
	for k: Variant in GameState.flags.keys():
		flags[str(k)] = GameState.flags[k]
	var zones: Array = []
	for z: Variant in GameState.open_zones.keys():
		if bool(GameState.open_zones[z]):
			zones.append(str(z))
	var snap: Dictionary = {
		"game": "gravelight", "map_id": String(GameState.map_id), "round": RoundManager.current_round,
		"power": GameState.power_on, "flags": flags, "zones": zones, "jakub": _jakub_state(tree),
		"exfil_active": _exfil_active(tree), "settings": GLSettings.values.duplicate(),
		"intel_match": intel_rows(intel_ids), "challenges": challenges(GameState.map_id), "quests": quests(),
	}
	return snap


static func quests() -> Dictionary:
	var out: Dictionary = {}
	for qid: StringName in QuestManager.quest_ids():
		var steps: Array = []
		for s: Variant in QuestManager.steps_of(qid):
			var st: Dictionary = s
			var sid: StringName = StringName(str(st.get("id", "")))
			var row: Dictionary = {"id": String(sid), "type": str(st.get("type", "")), "status": QuestManager.status(qid, sid)}
			var nt: Vector2i = step_progress(qid, sid, st)
			row["n"] = nt.x
			row["target"] = nt.y
			row["bot_task"] = st.has("bot_task")
			steps.append(row)
		out[String(qid)] = {"title": QuestManager.display_name_of(qid), "complete": QuestManager.is_complete(qid),
			"random": QuestManager.random_values(qid) if QuestManager.has_method("random_values") else {}, "steps": steps}
	return out


## (done so far, needed) for a step's counter; (-1, -1) when the type has none.
static func step_progress(qid: StringName, sid: StringName, st: Dictionary) -> Vector2i:
	var p: Dictionary = st.get("params", {})
	var prog: Variant = QuestManager.progress(qid, sid)
	match str(st.get("type", "")):
		"collect":
			return Vector2i((prog as Array).size() if prog is Array else 0, int(p.get("count", 1)))
		"sequence":
			return Vector2i(int(prog) if prog != null else 0, QuestManager.sequence_inputs(qid, sid).size())
		"kill_count":
			return Vector2i(int(prog) if prog != null else 0, QuestManager.kill_target(st))
		"holdout":
			var h: Dictionary = QuestManager.holdout_state(qid, sid)
			return Vector2i(int(float(h.get("t", 0.0))), int(float(p.get("duration", 120.0))))
	return Vector2i(-1, -1)


static func challenges(map_id: StringName) -> Array:
	var out: Array = []
	if ProfileSave.cur_match.is_empty() or not bool(ProfileSave.cur_match.get("active", false)):
		return out
	for cid: Variant in ProfileSave.active_challenges(map_id):
		var c: Dictionary = ProfileSave.challenge_def(str(cid))
		if c.is_empty():
			continue
		out.append({"id": str(cid), "name": str(c.get("name", cid)), "desc": str(c.get("desc", "")),
			"progress": ProfileSave.challenge_progress(str(cid)), "target": int(c.get("target", 1)),
			"scope": str(c.get("scope", "career")), "xp": int(c.get("xp", 0))})
	return out


## Archive rows for intel ids (an id the Archive doesn't list still gets a readable title).
static func intel_rows(ids: Array) -> Array:
	var by_id: Dictionary = {}
	for r: Variant in ProfileSave.intel_rows():
		by_id[str((r as Dictionary).get("id", ""))] = r
	var out: Array = []
	for id: Variant in ids:
		var row: Dictionary = by_id.get(str(id), {})
		if row.is_empty():
			row = {"id": str(id), "title": str(id).replace("_", " ").capitalize(), "type": "", "text": ""}
		out.append(row)
	return out


static func _jakub_state(tree: SceneTree) -> String:
	var j: JakubCompanion = JakubCompanion.instance(tree)
	if j == null:
		return ""
	return JakubCompanion.STATE_NAMES[int(j.state)] if int(j.state) < JakubCompanion.STATE_NAMES.size() else ""


static func _exfil_active(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for n: Node in tree.get_nodes_in_group(&"exfil_points"):
		if n.has_method("is_active") and bool(n.call("is_active")):
			return true
	return false


# ================================================================== Bolt & Sprocket

## A B&S planet (the BSLevel the pause menu sits in).
static func bs(level: Node) -> Dictionary:
	var level_id: String = str(level.get("level_id")) if level != null and level.get("level_id") != null else ""
	var dir: LevelDirector = level.get("director") as LevelDirector if level != null and level.get("director") is LevelDirector else null
	var D: Dictionary = dir.D if dir != null else {}
	if D.is_empty() and level_id != "" and Data.has_table("bs/levels/" + level_id):
		var t: Variant = Data.table("bs/levels/" + level_id)
		D = t if t is Dictionary else {}
	var planet: String = str(D.get("name", level.get("level_name") if level != null else ""))
	var mission: String = ""
	var hud: Node = level.get("hud") as Node if level != null else null
	if hud != null and hud.get("objective_text") != null:
		mission = str(hud.get("objective_text"))
	var quests: Array = []
	var qb: QuestBook = QuestBook.current
	if qb != null:
		for qid: String in qb.defs.keys():
			var q: Dictionary = qb.defs[qid]
			quests.append({"id": qid, "name": str(q.get("name", qid)), "state": qb.state(qid), "k": qb.count(qid), "n": qb.need(qid),
				"npc": str(q.get("npcName", "")), "npc_pos": q.get("npcPos", null), "reward": int(q.get("reward", 0))})
	var gold: Array = []
	for g: Variant in D.get("gold_bolts", []):
		var gd: Dictionary = g
		gold.append({"id": str(gd.get("id", "")), "found": GoldBolt.is_found(str(gd.get("id", ""))), "how": str(gd.get("how", "")), "p": gd.get("p", null)})
	var titles: Dictionary = {}
	var mt: Variant = Data.table("bs/story/memos") if Data.has_table("bs/story/memos") else null
	if mt is Dictionary:
		for m: Variant in (mt as Dictionary).get("memos", []):
			titles[str((m as Dictionary).get("id", ""))] = str((m as Dictionary).get("title", ""))
	var memos: Array = []
	for md: Variant in D.get("memos", []):
		var r: Dictionary = md
		var id: String = str(r.get("id", ""))
		var found: bool = MemoPickup.is_found(id)
		memos.append({"id": id, "found": found, "title": str(titles.get(id, "")) if found else "", "where": str(r.get("where", "")), "p": r.get("p", null)})
	var ch: Array = ((ObjectiveLog.load_data().get("bs", {}) as Dictionary).get("challenges", {}) as Dictionary).get(level_id, [])
	return {"game": "bs", "planet": planet.capitalize() if planet == planet.to_upper() else planet, "mission": mission,
		"quests": quests, "gold": gold, "memos": memos, "challenges": ch}


# ================================================================== where is it

## World positions for an entry: each of its `nodes` found in the scene (a scripted, visible node wins over a
## same-named geometry box; a picked-up or hidden one is skipped), then its fixed `pos`.
static func locate(root: Node, entry: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if root != null:
		for name: String in entry.get("nodes", PackedStringArray()):
			var best: Node3D = null
			for n: Node in root.find_children(name, "Node3D", true, false):
				var n3: Node3D = n as Node3D
				if n3 == null or not n3.is_inside_tree() or not n3.is_visible_in_tree():
					continue
				if best == null or (n3.get_script() != null and best.get_script() == null):
					best = n3
			if best != null:
				out.append(best.global_position)
	var p: Variant = entry.get("pos", null)
	if p is Array and (p as Array).size() >= 3:
		out.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	return out
