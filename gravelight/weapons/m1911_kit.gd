class_name M1911Kit
extends RefCounted
## The starting pistol's attachments (UPDATE_04 section 6, DECISIONS T-068): five slots (magazine, barrel, sights,
## grip / stock, ammo), one option per slot, bought at an Armorer's Bench. Everything is data:
## data/gravelight/weapons/m1911_attachments.json (prices, stat multipliers, the eleven upgraded versions used on
## Last Rites, the cosmetic finishes and the Loadout Pick).
##
## The kit lives on the WeaponInstance (`WeaponInstance.kit`: slot -> option id), so it goes wherever that pistol
## goes: through the Crucible (Last Rites keeps it, each part becomes its upgraded version), to Jakub, into the
## campaign carry and the co-op inventory (WeaponHolder.to_net entry 7). A wall-buy that takes the pistol's slot
## takes the kit with it. WeaponInstance.f() / mag_size() / limb_mult() apply the compiled kit
## (WeaponInstance.refresh_kit -> compile()), WeaponHolder reads the recoil, feel, draw time, flash and sounds, and
## M1911KitModels dresses the gun model.
##
## Public API for other sections: ArmorersBench.buy / options_for (bots, map marks), M1911Kit.loadout_rows (the
## pause menu's LOADOUT tab), WeaponInstance.is_suppressed() and GLBus.shot_is_suppressed(pid) (the minimap's
## firing reveal).

const PATH: String = "res://data/gravelight/weapons/m1911_attachments.json"
## Keys an option's upgraded block takes from the base block when it doesn't set them itself (looks, not numbers).
const LOOK_KEYS: PackedStringArray = ["flash", "glow", "tip"]
const REASONS: Dictionary = {
	"no_pistol": "Bring your M1911 to the bench.", "wrong_weapon": "The bench only works on the M1911.",
	"unknown": "The armorer doesn't stock that.", "installed": "Already fitted.",
	"needs_power": "Under the counter. Come back when the lights are on.",
	"refused": "Jakub won't load Nachtglas.", "no_scrip": "Not enough Scrip.", "busy": "Not now.",
}

static var _cfg: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PATH)
	return _cfg


## Drops the cached table (tests, data edits).
static func reload() -> void:
	_cfg = {}


# ================================================================== the catalogue

static func slot_order() -> Array:
	return cfg().get("slot_order", [])


static func slot_name(slot: String) -> String:
	return str(((cfg().get("slots", {}) as Dictionary).get(slot, {}) as Dictionary).get("name", slot.capitalize()))


static func slot_sound(slot: String) -> String:
	return str(((cfg().get("slots", {}) as Dictionary).get(slot, {}) as Dictionary).get("sound", "reload_end"))


## Option ids of a slot, in data order.
static func options(slot: String) -> Array:
	return ((cfg().get("options", {}) as Dictionary).get(slot, {}) as Dictionary).keys()


static func option_def(slot: String, option: String) -> Dictionary:
	return (((cfg().get("options", {}) as Dictionary).get(slot, {}) as Dictionary).get(option, {}) as Dictionary)


static func is_known(slot: String, option: String) -> bool:
	return not option_def(slot, option).is_empty()


## The option as fitted to the base pistol or (upgraded) to Last Rites: the upgraded block's own name, text and
## numbers; price, power gate and looks it doesn't set come from the base block.
static func variant(slot: String, option: String, upgraded: bool) -> Dictionary:
	var d: Dictionary = option_def(slot, option)
	if not upgraded or not d.has("upgraded"):
		return d
	var out: Dictionary = (d["upgraded"] as Dictionary).duplicate(true)
	for k: String in ["price", "requires_power", "locked_text"]:
		if d.has(k):
			out[k] = d[k]
	for k2: String in LOOK_KEYS:
		if not out.has(k2) and d.has(k2):
			out[k2] = d[k2]
	return out


static func price(slot: String, option: String) -> int:
	return int(option_def(slot, option).get("price", 0))


static func option_name(slot: String, option: String, upgraded: bool = false) -> String:
	if option == "":
		return "Standard"
	return str(variant(slot, option, upgraded).get("name", option.capitalize()))


## True for the weapons the bench works on: the M1911 and anything taught from it (Last Rites, II, III).
static func applies_to(w: WeaponInstance) -> bool:
	return w != null and (cfg().get("weapons", ["m1911"]) as Array).has(String(w.base_id()))


# ================================================================== compiling a kit into numbers

## Folds a kit (slot -> option) into the modifiers WeaponInstance and WeaponHolder read: stats (multipliers on
## f() keys), set (mag / reserve), limb (hitbox multipliers), recoil (pattern multipliers), feel (overrides),
## props (flags), draw (raise-time multiplier), and the looks (flash, glow, tip).
static func compile(kit: Dictionary, upgraded: bool) -> Dictionary:
	var m: Dictionary = {"stats": {}, "set": {}, "limb": {}, "recoil": {}, "feel": {}, "props": {}, "draw": 1.0,
		"flash": "", "glow": [], "tip": ""}
	for slot: String in slot_order():
		var opt: String = str(kit.get(slot, ""))
		if opt == "" or not is_known(slot, opt):
			continue
		var v: Dictionary = variant(slot, opt, upgraded)
		for group: String in ["stats", "limb", "recoil"]:
			var src: Dictionary = v.get(group, {})
			var dst: Dictionary = m[group]
			for k: Variant in src.keys():
				dst[k] = float(dst.get(k, 1.0)) * float(src[k])
		(m["set"] as Dictionary).merge(v.get("set", {}) as Dictionary, true)
		(m["feel"] as Dictionary).merge(v.get("feel", {}) as Dictionary, true)
		(m["props"] as Dictionary).merge(v.get("props", {}) as Dictionary, true)
		m["draw"] = float(m["draw"]) * float(v.get("draw", 1.0))
		for k2: String in LOOK_KEYS:
			if v.has(k2):
				m[k2] = v[k2]
	return m


## A recoil pattern (WeaponHolder.recoil_for) with the kit's multipliers applied ("recover" speeds the drift back).
static func apply_recoil(rc: Dictionary, w: WeaponInstance) -> Dictionary:
	var mult: Dictionary = w.kit_mods().get("recoil", {})
	if mult.is_empty():
		return rc
	var out: Dictionary = rc.duplicate()
	for k: Variant in mult.keys():
		out[k] = float(out.get(k, 1.0 if k == "recover" else 0.0)) * float(mult[k])
	return out


# ================================================================== the rules

## Why `option` can't go into `slot` on `w` ("" = it can): not an M1911, unknown, already fitted, Nachtglas before
## the power, Jakub and the Nachtglas rounds. Slots are exclusive: a different option replaces the fitted one.
static func check(w: WeaponInstance, slot: String, option: String, power_on: bool, companion: bool = false) -> String:
	if w == null:
		return "no_pistol"
	if not applies_to(w):
		return "wrong_weapon"
	if not is_known(slot, option):
		return "unknown"
	if str(w.kit.get(slot, "")) == option:
		return "installed"
	if bool(option_def(slot, option).get("requires_power", false)) and not power_on:
		return "needs_power"
	if companion and (cfg().get("companion_refuses", []) as Array).has(option):
		return "refused"
	return ""


static func reason_text(code: String) -> String:
	return str(REASONS.get(code, code))


## Fits `option` into `slot` ("" clears the slot). A bigger magazine is topped up from the reserve; a smaller one
## hands its spare rounds back to the reserve.
static func install(w: WeaponInstance, slot: String, option: String) -> void:
	if w == null:
		return
	if option == "":
		w.kit.erase(slot)
	else:
		w.kit[slot] = option
	w.refresh_kit()
	var size: int = w.mag_size()
	if w.mag > size:
		w.reserve += w.mag - size
		w.mag = size
	elif w.mag < size and w.reserve > 0:
		var moved: int = mini(size - w.mag, w.reserve)
		w.mag += moved
		w.reserve -= moved
	w.reserve = mini(w.reserve, w.reserve_max())


## The pistol a player would take to the bench: the one in their hands, else the first M1911 in their slots.
static func pistol_of(p: Player) -> WeaponInstance:
	if p == null or p.weapons == null:
		return null
	var cw: WeaponInstance = p.weapons.current()
	if applies_to(cw):
		return cw
	for w: WeaponInstance in p.weapons.slots:
		if applies_to(w):
			return w
	return null


static func has_option(w: WeaponInstance, slot: String, option: String) -> bool:
	return w != null and str(w.kit.get(slot, "")) == option


## False for a pistol Jakub won't take: one loaded with Nachtglas rounds (data companion_refuses).
static func companion_accepts(w: WeaponInstance) -> bool:
	if w == null or w.kit.is_empty():
		return true
	var refused: Array = cfg().get("companion_refuses", [])
	for slot: Variant in w.kit.keys():
		if refused.has(str(w.kit[slot])):
			return false
	return true


# ================================================================== carrying the kit

## The kit as a flat list for the network / campaign payload: ["mag:drum", "sights:radium", ...] in slot order.
static func encode(kit: Dictionary) -> Array:
	var out: Array = []
	for slot: String in slot_order():
		var opt: String = str(kit.get(slot, ""))
		if opt != "":
			out.append("%s:%s" % [slot, opt])
	return out


static func decode(list: Variant) -> Dictionary:
	var kit: Dictionary = {}
	if not (list is Array):
		return kit
	for e: Variant in list:
		var parts: PackedStringArray = str(e).split(":")
		if parts.size() == 2 and is_known(parts[0], parts[1]):
			kit[parts[0]] = parts[1]
	return kit


## Copies the attachments and finish of `from` onto `to` (a weapon rebuilt from the same pistol: the Crucible's
## result, the gun Jakub hands back). Nothing happens unless `to` is an M1911 too.
static func copy(from: WeaponInstance, to: WeaponInstance) -> void:
	if from == null or to == null or not applies_to(to):
		return
	to.kit = from.kit.duplicate()
	to.finish = from.finish
	to.refresh_kit()


## A weapon from a build string "<weapon id>[:slot=option,...,finish=<id>]" (tools: ads_check, kit_shots, tests).
static func from_build(build: String) -> WeaponInstance:
	var parts: PackedStringArray = build.split(":", true, 1)
	var w: WeaponInstance = WeaponInstance.create(StringName(parts[0]))
	if parts.size() > 1:
		for kv: String in parts[1].split(",", false):
			var p: PackedStringArray = kv.split("=")
			if p.size() != 2:
				continue
			if p[0] == "finish":
				w.finish = StringName(p[1])
			else:
				w.kit[p[0]] = p[1]
	w.refresh_kit()
	w.refill()
	return w


## A build string as a file name ("m1911_up__sights-radium_grip-stock").
static func build_file_name(build: String) -> String:
	return build.replace(":", "__").replace(",", "_").replace("=", "-")


## Every M1911 / Last Rites combination that changes the sights or the stock (tools/ads_check.sh checks them all):
## sights (standard, radium, raised target) x grip (standard, stock, checkered), minus the two plain guns.
static func sight_stock_builds() -> PackedStringArray:
	var out: PackedStringArray = []
	for wid: String in ["m1911", "m1911_up"]:
		for s: String in [""] + options("sights"):
			for g: String in [""] + options("grip"):
				if s == "" and g == "":
					continue
				var kv: PackedStringArray = []
				if s != "":
					kv.append("sights=" + s)
				if g != "":
					kv.append("grip=" + g)
				out.append(wid + ":" + ",".join(kv))
	return out


## A short signature of the kit and finish (cache keys: models, recoil, ADS zoom).
static func signature(kit: Dictionary, finish: StringName = &"") -> String:
	if kit.is_empty() and finish == &"":
		return ""
	return ",".join(PackedStringArray(encode(kit))) + "|" + String(finish)


# ================================================================== the bench's read-outs

## The pistol's attachments, one row per slot (the bench and the pause menu's LOADOUT tab):
## [{slot, slot_name, option ("" = standard), name, desc}].
static func describe(w: WeaponInstance) -> Array:
	var out: Array = []
	if not applies_to(w):
		return out
	for slot: String in slot_order():
		var opt: String = str(w.kit.get(slot, ""))
		out.append({"slot": slot, "slot_name": slot_name(slot), "option": opt, "name": option_name(slot, opt, w.upgraded),
			"desc": str(variant(slot, opt, w.upgraded).get("desc", "")) if opt != "" else ""})
	return out


## For the LOADOUT tab: the attachments on `p`'s pistol (describe()), [] when they carry none.
static func loadout_rows(p: Player) -> Array:
	return describe(pistol_of(p))


## The six stat bars (0..1 each, plus a readable value) for `w`, or for `w` with `slot` set to `option` when a
## preview is given: {damage, range, recoil, ads, mobility, capacity} -> {value, text}.
static func stats(w: WeaponInstance, slot: String = "", option: String = "") -> Dictionary:
	if w == null:
		return {}
	var t: WeaponInstance = WeaponInstance.create(w.id)
	t.tier = w.tier
	t.kit = w.kit.duplicate()
	if slot != "":
		if option == "":
			t.kit.erase(slot)
		else:
			t.kit[slot] = option
	t.refresh_kit()
	var plain: WeaponInstance = WeaponInstance.create(&"m1911")
	var sb: Dictionary = cfg().get("stat_bars", {})
	var rc: Dictionary = WeaponHolder.recoil_for(t)
	var rc0: Dictionary = WeaponHolder.recoil_for(plain)
	var kick: float = float(rc.get("v", 0.6)) * (0.5 + 0.5 * float(rc.get("punch", 0.45)) / maxf(0.01, float(rc0.get("punch", 0.45))))
	var kick0: float = maxf(0.01, float(rc0.get("v", 0.6)))
	var dmg: float = t.f("damage", 40.0)
	var rng: float = t.f("falloff_end", 30.0)
	var ads_time: float = maxf(0.01, t.f("ads_time", 0.15))
	var mob: float = t.f("move_mult", 1.0) / sqrt(maxf(0.1, t.draw_mult()))
	return {
		"damage": {"value": clampf(dmg / float(sb.get("damage_max", 200.0)), 0.0, 1.0), "text": "%d" % roundi(dmg)},
		"range": {"value": clampf(rng / float(sb.get("range_max", 60.0)), 0.0, 1.0), "text": "%d m" % roundi(rng)},
		"recoil": {"value": clampf(0.6 * kick / kick0 * float(sb.get("recoil_ref", 1.0)), 0.0, 1.0), "text": "%d%%" % roundi(100.0 * kick / kick0)},
		"ads": {"value": clampf(float(sb.get("ads_speed_ref", 0.075)) / ads_time, 0.0, 1.0), "text": "%.2f s" % ads_time},
		"mobility": {"value": clampf(mob / float(sb.get("mobility_max", 1.2)), 0.0, 1.0), "text": "%d%%" % roundi(100.0 * mob)},
		"capacity": {"value": clampf(float(t.mag_size()) / float(sb.get("capacity_max", 40.0)), 0.0, 1.0), "text": "%d" % t.mag_size()},
	}


# ================================================================== hits

## A hit landed by a kitted pistol: Nachtglas rounds may slow the target, the Censer Compensator's flare sets
## close targets alight. `dist` is from the shooter's eye.
static func on_hit(w: WeaponInstance, z: Zombie, killed: bool, dist: float, pid: int) -> void:
	if killed or z == null:
		return
	var slow: Variant = w.property("kit_slow")
	if slow is Dictionary and randf() < float((slow as Dictionary).get("chance", 0.0)):
		z.apply_frost(float((slow as Dictionary).get("slow", 0.3)), float((slow as Dictionary).get("dur", 1.5)))
	var flare: Variant = w.property("kit_flare")
	if flare is Dictionary and dist <= float((flare as Dictionary).get("range", 6.0)):
		z.ignite(float((flare as Dictionary).get("dps", 80.0)), float((flare as Dictionary).get("dur", 3.0)), pid)


# ================================================================== meta: finishes and the Loadout Pick

static func _kills() -> int:
	return ProfileSave.weapon_kills(&"m1911")


## [{id, name, kills (needed), unlocked}] in display order, for `kills` lifetime M1911 kills.
static func finish_rows(kills: int) -> Array:
	var f: Dictionary = cfg().get("finishes", {})
	var rows: Dictionary = f.get("rows", {})
	var out: Array = []
	for id: Variant in f.get("order", []):
		var r: Dictionary = rows.get(str(id), {})
		out.append({"id": str(id), "name": str(r.get("name", str(id).capitalize())), "kills": int(r.get("kills", 0)),
			"unlocked": kills >= int(r.get("kills", 0))})
	return out


static func finish_def(id: StringName) -> Dictionary:
	return ((cfg().get("finishes", {}) as Dictionary).get("rows", {}) as Dictionary).get(String(id), {})


static func finish_unlocked(id: StringName, kills: int) -> bool:
	var d: Dictionary = finish_def(id)
	return not d.is_empty() and kills >= int(d.get("kills", 0))


## The finish the profile has chosen, if it is (still) unlocked.
static func equipped_finish() -> StringName:
	var id: StringName = StringName(str((ProfileSave.profile.get("equipped", {}) as Dictionary).get("m1911_finish", "")))
	return id if finish_unlocked(id, _kills()) else &""


static func set_finish(id: StringName) -> bool:
	if not finish_unlocked(id, _kills()):
		return false
	_equip("m1911_finish", String(id))
	return true


static func pick_kills() -> int:
	return int((cfg().get("loadout_pick", {}) as Dictionary).get("kills", 75))


static func pick_choices() -> Array:
	return (cfg().get("loadout_pick", {}) as Dictionary).get("choices", [])


static func pick_unlocked(kills: int) -> bool:
	return kills >= pick_kills()


## "slot:option" chosen as the Loadout Pick ("" = none, or not unlocked yet).
static func equipped_pick() -> String:
	var c: String = str((ProfileSave.profile.get("equipped", {}) as Dictionary).get("m1911_pick", ""))
	return c if pick_choices().has(c) and pick_unlocked(_kills()) else ""


static func set_loadout_pick(choice: String) -> bool:
	if choice != "" and (not pick_choices().has(choice) or not pick_unlocked(_kills())):
		return false
	_equip("m1911_pick", choice)
	return true


static func _equip(key: String, value: String) -> void:
	var eq: Dictionary = ProfileSave.profile.get("equipped", {})
	eq[key] = value
	ProfileSave.profile["equipped"] = eq
	ProfileSave.save_profile()


## Match start (the starting pistol of a local, human player): the chosen finish and the Loadout Pick.
static func apply_start(w: WeaponInstance, pick: String, finish: StringName) -> void:
	if not applies_to(w):
		return
	w.finish = finish
	var parts: PackedStringArray = pick.split(":")
	if parts.size() == 2 and pick_choices().has(pick):
		install(w, parts[0], parts[1])
		w.refill()
	else:
		w.refresh_kit()
