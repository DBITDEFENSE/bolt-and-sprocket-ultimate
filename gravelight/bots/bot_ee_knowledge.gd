class_name BotEEKnowledge
extends RefCounted
## What the squad has discovered about the easter egg (Update 04 section 5, T-067), on the blackboard as
## `blackboard.ee_known`. Bots know only this: a step whose `needs` aren't known can't be done by a bot ("can't do
## that yet", with the reason). Keys come from each quest's "bot_knowledge" block (data/gravelight/quests/*.json):
##   on_collect {tag, count}   that many of a collect step's items were taken (notes read, radios heard)
##   on_vo [line ids]          a line was heard (the music box's melody: MUSIC_BOX)
##   on_step [step ids]        a step of that quest completed
##   on_flag [flags]           a world flag was set
##   on_seen {spec, count}     that many matching objects were seen by a squad member (the four little bells)
## and "seen:<path>" for each findable object a squad member saw or heard (a task's find: seen / heard). Pure data
## with the clock passed in, unit-tested (test_bot_ee.gd); BotEEHub feeds it.

## key -> {"by": pid (0 = the squad / everyone heard it), "t": squad time, "how": "collect" / "vo" / "seen" / ...}
var known: Dictionary = {}
## key -> label ("heard the music box's melody"), from the quest data (for the "can't do that yet" reasons).
var labels: Dictionary = {}


func learn(key: String, by: int, now: float, how: String) -> bool:
	if key == "" or known.has(key):
		return false
	known[key] = {"by": by, "t": now, "how": how}
	return true


func knows(key: String) -> bool:
	return known.has(key)


func forget(key: String) -> void:
	known.erase(key)


func missing(keys: Array) -> Array:
	var out: Array = []
	for k: Variant in keys:
		if not known.has(str(k)):
			out.append(str(k))
	return out


func clear() -> void:
	known.clear()


static func seen_key(path: String) -> String:
	return "seen:" + path


## One line per key (the AI debug panel).
func describe() -> PackedStringArray:
	var out: PackedStringArray = []
	var info: PackedStringArray = []
	var seen: int = 0
	for k: Variant in known.keys():
		if str(k).begins_with("seen:"):
			seen += 1
		else:
			info.append(str(k))
	out.append("EE known: %s; %d object(s) found" % [", ".join(info) if not info.is_empty() else "nothing yet", seen])
	return out
