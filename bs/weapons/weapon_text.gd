class_name WeaponText
extends RefCounted
## Every player-facing weapon string by line id. VOManager's index wins; otherwise the weapons-owned lines in
## data/bs/weapons.json ("lines") are used, shown through the same EventBus.subtitle path (never audio here).


static func entry(id: String) -> Dictionary:
	if VOManager.has_line(id):
		return VOManager.line(id)
	var lines: Dictionary = WeaponData.doc().get("lines", {})
	return lines.get(id, {}) if lines.get(id, null) is Dictionary else {}


static func text(id: String) -> String:
	var e: Dictionary = entry(id)
	return str(e.get("text", id)) if not e.is_empty() else id


## Speaks a line (subtitle + voice when VOManager has it; subtitle only for weapons-owned lines).
static func say(id: String) -> void:
	if VOManager.has_line(id):
		VOManager.play(id)
		return
	var e: Dictionary = entry(id)
	if e.is_empty():
		return
	var who: String = str(e.get("who", ""))
	var spk: Dictionary = {}
	var sp: Variant = Data.table("bs/story/speakers")
	if sp is Dictionary:
		spk = ((sp as Dictionary).get("speakers", {}) as Dictionary).get(who, {})
	var t: String = str(e.get("text", ""))
	EventBus.vo_line_started.emit(id, who, t)
	EventBus.subtitle.emit(str(spk.get("name", who.to_upper())), t, Color.from_string(str(spk.get("color", "#ffffff")), Color.WHITE),
		1.2 + t.length() * 0.055)


## On-screen hint (ammo empty etc.): EventBus.hint(text, key).
static func hint(id: String, key: String = "") -> void:
	if id == "":
		return
	EventBus.hint.emit(text(id), key)
