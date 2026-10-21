class_name WeaponText
extends RefCounted
## Every player-facing weapon / Forge string by line id. VOManager's index wins; otherwise the lines owned by the
## arsenal builder are used: data/bs/weapons.json "lines", then data/bs/forge.json "lines". Shown through the same
## EventBus.subtitle path (never audio here).

const SOURCES: Array[String] = ["bs/weapons", "bs/forge"]


static func entry(id: String) -> Dictionary:
	if VOManager.has_line(id):
		return VOManager.line(id)
	for src: String in SOURCES:
		if not Data.has_table(src):
			continue
		var t: Variant = Data.table(src)
		if not (t is Dictionary):
			continue
		var lines: Dictionary = (t as Dictionary).get("lines", {})
		if lines.get(id, null) is Dictionary:
			return lines[id]
	return {}


static func has(id: String) -> bool:
	return not entry(id).is_empty()


static func text(id: String) -> String:
	var e: Dictionary = entry(id)
	return str(e.get("text", id)) if not e.is_empty() else id


static func who(id: String) -> String:
	return str(entry(id).get("who", ""))


## Speaks a line (subtitle + voice when VOManager has it; subtitle only for arsenal-owned lines).
static func say(id: String) -> void:
	if VOManager.has_line(id):
		VOManager.play(id)
		return
	var e: Dictionary = entry(id)
	if e.is_empty():
		return
	var w: String = str(e.get("who", ""))
	var spk: Dictionary = {}
	var sp: Variant = Data.table("bs/story/speakers")
	if sp is Dictionary:
		spk = ((sp as Dictionary).get("speakers", {}) as Dictionary).get(w, {})
	var t: String = str(e.get("text", ""))
	EventBus.vo_line_started.emit(id, w, t)
	EventBus.subtitle.emit(str(spk.get("name", w.to_upper())), t, Color.from_string(str(spk.get("color", "#ffffff")), Color.WHITE),
		1.2 + t.length() * 0.055)


## On-screen hint (ammo empty etc.): EventBus.hint(text, key).
static func hint(id: String, key: String = "") -> void:
	if id == "":
		return
	EventBus.hint.emit(text(id), key)
