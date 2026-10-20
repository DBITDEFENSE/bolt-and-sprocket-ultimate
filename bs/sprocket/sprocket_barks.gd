class_name SprocketBarks
extends RefCounted
## Sprocket's ambient barks, ported from barkTry / updateBarks (index.html:11280-11298):
##   - one shared cooldown (8 s at start; 24 s after a combat bark, 32 s after any other)
##   - lowhp: only at or below 30% HP; bolts: 20% chance; combat: 12% chance (both rolled on a kill)
##   - idle: 25 s without movement input, when the cooldown is clear
##   - never while a menu, dialogue or cutscene owns the input
## Lines: data/bs/story/barks.json "sprocket" categories. Tuning: data/bs/sprocket.json "barks".

var B: Dictionary
var cd: float = 8.0
var idle_t: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lines: Dictionary = {}     # kind -> PackedStringArray of line ids


func _init() -> void:
	B = (Data.table("bs/sprocket") as Dictionary)["barks"]
	cd = float(B["start_cd"])
	rng.randomize()
	var doc: Variant = Data.table("bs/story/barks")
	if doc is Dictionary:
		var sp: Dictionary = (doc as Dictionary).get("sprocket", {})
		for kind: String in sp.keys():
			var ids: PackedStringArray = []
			for e: Variant in sp[kind]:
				ids.append(str((e as Dictionary)["id"]))
			_lines[kind] = ids


func lines(kind: String) -> PackedStringArray:
	return _lines.get(kind, PackedStringArray())


## Rolls a bark of `kind`. Returns the line id to play, or "" (cooldown, chance, HP or blocked).
func try_bark(kind: String, hp_frac: float = 1.0, blocked: bool = false) -> String:
	if blocked or cd > 0.0:
		return ""
	if kind == "lowhp" and hp_frac > float(B["lowhp_frac"]):
		return ""
	if kind == "bolts" and rng.randf() > float(B["p_bolts"]):
		return ""
	if kind == "combat" and rng.randf() > float(B["p_combat"]):
		return ""
	var ids: PackedStringArray = lines(kind)
	if ids.is_empty():
		return ""
	cd = float(B["cd_combat"]) if kind == "combat" else float(B["cd_other"])
	return ids[rng.randi_range(0, ids.size() - 1)]


## Per frame. Returns an idle bark id when one fires, else "".
func tick(dt: float, moving: bool, blocked: bool) -> String:
	cd -= dt
	if blocked:
		return ""
	idle_t = 0.0 if moving else idle_t + dt
	if idle_t > float(B["idle_after"]) and cd <= 0.0:
		idle_t = 0.0
		cd = float(B["cd_other"])
		var ids: PackedStringArray = lines("idle")
		return ids[rng.randi_range(0, ids.size() - 1)] if not ids.is_empty() else ""
	return ""
