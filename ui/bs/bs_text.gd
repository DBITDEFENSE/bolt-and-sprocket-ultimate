class_name BSText
extends RefCounted
## Player-facing text by line id for the B&S UI. Looks in VOManager's indexes (lines_index) first, then in
## data/bs/ui_lines.json (the UI builder's new bs.* lines). say() voices a line when VOManager knows it,
## otherwise it emits the subtitle itself so new lines still show.

const EXTRA: String = "bs/ui_lines"


static func _extra() -> Dictionary:
	var t: Variant = Data.table(EXTRA) if Data.has_table(EXTRA) else null
	return t as Dictionary if t is Dictionary else {}


static func has(id: String) -> bool:
	return VOManager.has_line(id) or _extra().has(id)


static func entry(id: String) -> Dictionary:
	if VOManager.has_line(id):
		return VOManager.line(id)
	var e: Variant = _extra().get(id, {})
	return e as Dictionary if e is Dictionary else {}


## Text for a line id; `fallback` (or the id itself) when unknown.
static func text(id: String, fallback: String = "") -> String:
	var e: Dictionary = entry(id)
	if e.has("text"):
		return str(e["text"])
	return fallback if fallback != "" else id


## Speaks a character line (subtitle + voice). Returns false when the id is unknown everywhere.
static func say(id: String) -> bool:
	if VOManager.has_line(id):
		return VOManager.play(id)
	var e: Dictionary = entry(id)
	if e.is_empty():
		push_warning("Unknown line: %s" % id)
		return false
	var who: String = str(e.get("who", ""))
	var spk: Dictionary = speaker(who)
	var t: String = str(e.get("text", ""))
	EventBus.subtitle.emit(str(spk.get("name", who.to_upper())), t, Color.from_string(str(spk.get("color", "#ffffff")), Color.WHITE),
		1.2 + t.length() * 0.055)
	return true


static func speaker(who: String) -> Dictionary:
	var sp: Variant = Data.table("bs/story/speakers")
	if sp is Dictionary:
		return ((sp as Dictionary).get("speakers", {}) as Dictionary).get(who, {})
	return {}


## Ids of a pool like "blartz.deny" -> ["blartz.deny.01", ...] (two-digit suffixes, stops at the first gap).
static func pool(prefix: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var i: int = 1
	while has("%s.%02d" % [prefix, i]):
		out.append("%s.%02d" % [prefix, i])
		i += 1
	return out
