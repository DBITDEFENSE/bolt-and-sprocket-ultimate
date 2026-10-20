class_name QuestBook
extends Node
## Side-quest state for one planet (quests.json, planet index). Kill quests count EventBus.enemy_killed by
## enemy type; collect quests count QuestItem pickups. Turning in pays the reward through BS.add_bolts.
## State persists in SaveProfile.doc["bs"]["quests"][id] = {"state": "active"|"done", "k": count}.
## Emits EventBus.quest_progress / quest_done and a progress hint ("<name>: k/n — return to <npc>!").

const NONE: String = "none"
const ACTIVE: String = "active"
const READY: String = "ready"      # active and the count is met: talk to the giver
const DONE: String = "done"

static var current: QuestBook = null

var defs: Dictionary = {}          # quest id -> quests.json entry
var aliases: Dictionary = {}       # source enemy type ("scrapmutt") -> remake id ("scrap_mutt")


func setup(planet_index: int, type_aliases: Dictionary) -> void:
	aliases = type_aliases
	defs.clear()
	var all: Variant = Data.table("bs/story/quests")
	if all is Array:
		for q: Variant in all:
			if q is Dictionary and int((q as Dictionary).get("planet", -1)) == planet_index:
				defs[str(q["id"])] = q


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _store() -> Dictionary:
	var bs: Dictionary = SaveProfile.doc["bs"]
	if not bs.has("quests") or not (bs["quests"] is Dictionary):
		bs["quests"] = {}
	return bs["quests"]


func state(qid: String) -> String:
	var s: Dictionary = _store().get(qid, {})
	var st: String = str(s.get("state", NONE))
	if st == ACTIVE and count(qid) >= need(qid):
		return READY
	return st


func count(qid: String) -> int:
	return int((_store().get(qid, {}) as Dictionary).get("k", 0))


func need(qid: String) -> int:
	return int((defs.get(qid, {}) as Dictionary).get("n", 1))


func start(qid: String) -> void:
	if not defs.has(qid) or state(qid) != NONE:
		return
	_store()[qid] = {"state": ACTIVE, "k": 0}
	EventBus.quest_progress.emit(qid, 0, need(qid))
	BS.save_to_profile()


func add_progress(qid: String, n: int = 1) -> void:
	if state(qid) != ACTIVE:
		return
	var s: Dictionary = _store()[qid]
	s["k"] = mini(need(qid), int(s.get("k", 0)) + n)
	var d: Dictionary = defs[qid]
	EventBus.quest_progress.emit(qid, int(s["k"]), need(qid))
	var txt: String = LevelKit.text("code.collectPickup.08").replace("{q.name}", str(d.get("name", qid))) \
		.replace("{Math.min(qs.k, q.n)}", str(s["k"])).replace("{q.n}", str(need(qid)))
	if int(s["k"]) >= need(qid):
		txt += LevelKit.text("code.collectPickup.09").replace("{q.npcName}", str(d.get("npcName", "")))
	EventBus.hint.emit(txt, "quest_" + qid)
	BS.save_to_profile()


## Pays out a READY quest. Returns true when it completed.
func turn_in(qid: String) -> bool:
	if state(qid) != READY:
		return false
	var s: Dictionary = _store()[qid]
	s["state"] = DONE
	BS.add_bolts(int((defs[qid] as Dictionary).get("reward", 0)))
	EventBus.quest_done.emit(qid)
	BS.save_to_profile()
	return true


func lines(qid: String, part: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for l: Variant in (defs.get(qid, {}) as Dictionary).get(part, []):
		out.append(str((l as Dictionary).get("id", "")))
	return out


func kill_type(qid: String) -> String:
	var d: Dictionary = defs.get(qid, {})
	if str(d.get("kind", "")) != "kill":
		return ""
	var t: String = str(d.get("type", ""))
	return str(aliases.get(t, t))


func _on_enemy_killed(enemy: Node, _by: StringName) -> void:
	var eid: String = EnemyBridge.enemy_id(enemy)
	if eid == "":
		return
	for qid: String in defs.keys():
		if state(qid) == ACTIVE and kill_type(qid) == eid:
			add_progress(qid, 1)
