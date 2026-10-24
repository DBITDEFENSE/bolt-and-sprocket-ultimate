class_name WeaponKit
extends RefCounted
## Attachments for any gun (UPDATE_04 section 6 generalised, DECISIONS T-074; T-068 made them for the M1911 only).
## Up to five slots (mag, barrel, sights, grip, ammo), one option per slot, bought at an Armorer's Bench for the
## gun in your hands. Everything is data: data/gravelight/weapons/attachments.json. A gun's table is its
## weapons.json class's table ("classes", which may be "like" another class) with the per-weapon entry merged on
## top (keyed by base id, so Last Rites / the _up rows use their base gun's table); the M1911 keeps its own
## T-068 table unchanged ("own_table"). Wonder weapons, melee and tacticals are refused in character ("refuse").
##
## The kit lives on the WeaponInstance (`kit`: slot -> option id), so it goes wherever that gun goes: through the
## Crucible (the upgraded gun keeps it, each part becomes its "upgraded" version), to Jakub, into the campaign
## carry and the co-op inventory (WeaponHolder.net_entry). A wall-buy or a Mystery Crate result that takes the
## gun's slot takes the kit with it (the new gun comes plain). WeaponInstance.f() / mag_size() / limb_mult()
## apply the compiled kit (refresh_kit -> compile), WeaponHolder reads the recoil, feel, draw time, flash and
## sounds, WeaponKitModels dresses the gun model.
##
## Functions that need a gun's table take `of`: a WeaponInstance, or a weapon id (String / StringName; an
## upgraded id resolves to its base). Public API: ArmorersBench.buy / options_for (bots, map marks),
## WeaponKit.held / gun_of / accepts / refusal / options / price / stats, WeaponInstance.is_suppressed() and
## GLBus.shot_is_suppressed(pid) (the minimap's firing reveal). M1911Kit is the M1911's view of this (finishes,
## the Loadout Pick, and the old (slot, option) calls).

const PATH: String = "res://data/gravelight/weapons/attachments.json"
## Keys an option's upgraded block takes from the base block when it doesn't set them itself (looks, not numbers).
const LOOK_KEYS: PackedStringArray = ["flash", "glow", "tip"]
## Number groups an upgraded block on a class table may leave out (then derived from the base with upgrade_boost).
const NUM_GROUPS: PackedStringArray = ["stats", "recoil", "limb", "scale"]
## Copied from the base block when the upgraded one leaves them out (on every table).
const COPY_KEYS: PackedStringArray = ["model", "r", "w", "len", "ext", "band", "hide_mag", "replace_legs", "scope"]
## f() keys where a smaller multiplier is the better one (for the upgrade boost).
const LOWER_BETTER: PackedStringArray = ["reload_partial", "reload_empty", "ads_time", "sway", "spread_hip", "spread_ads",
	"v", "h", "h_swing", "punch", "draw"]
const REASONS: Dictionary = {
	"no_gun": "Bring a gun to the bench.", "no_pistol": "Bring a gun to the bench.",
	"wrong_weapon": "The armorer can't work on that.", "unknown": "The armorer doesn't stock that for this gun.",
	"installed": "Already fitted.", "needs_power": "Under the counter. Come back when the lights are on.",
	"refused": "Jakub won't load Nachtglas.", "no_scrip": "Not enough Scrip.", "busy": "Not now.",
}

static var _cfg: Dictionary = {}
static var _tables: Dictionary = {}   # base id -> resolved table


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = GLData.load_json(PATH)
	return _cfg


## Drops the cached data (tests, data edits).
static func reload() -> void:
	_cfg = {}
	_tables = {}


## The base weapon id behind `of` (a WeaponInstance, or a weapon id; "_up" rows map to their base).
static func base_of(of: Variant) -> StringName:
	if of is WeaponInstance:
		return (of as WeaponInstance).base_id()
	var id: String = str(of)
	var up: Dictionary = GLData.table("weapons").get("upgraded", {})
	if up.has(id):
		return StringName(str((up[id] as Dictionary).get("base", id)))
	return StringName(id)


static func _class_of(base: StringName) -> String:
	var row: Dictionary = (GLData.table("weapons").get("weapons", {}) as Dictionary).get(String(base), {})
	return str(row.get("class", ""))


# ================================================================== resolving a gun's table

## The resolved table for `of`: {slot_order, slots ({slot: {name, sound}}), options ({slot: {opt: def}}),
## stat_bars, boost (upgrade boost, 0 = none), refuse ("" = the bench works on it), class}. Cached.
static func table(of: Variant) -> Dictionary:
	var base: StringName = base_of(of)
	if _tables.has(base):
		return _tables[base]
	var t: Dictionary = _resolve(base)
	_tables[base] = t
	return t


static func _resolve(base: StringName) -> Dictionary:
	var c: Dictionary = cfg()
	var went: Dictionary = (c.get("weapons", {}) as Dictionary).get(String(base), {})
	var cls: String = str(went.get("class", _class_of(base)))
	var out: Dictionary = {"slot_order": [], "slots": {}, "options": {}, "stat_bars": (c.get("stat_bars", {}) as Dictionary).duplicate(),
		"boost": 0.0, "refuse": "", "class": cls, "own": false}
	if went.has("refuse"):
		out["refuse"] = str(went["refuse"])
		return out
	var src: Dictionary = {}
	if bool(went.get("own_table", false)):
		src = went
		out["own"] = true
	else:
		src = _class_table(cls, 0)
		if src.is_empty():
			var rc: Dictionary = c.get("refuse_classes", {})
			out["refuse"] = str(rc.get(cls, c.get("refuse_default", "The armorer can't work on that.")))
			if cls == "" and went.is_empty():
				out["refuse"] = str(c.get("refuse_default", "The armorer can't work on that."))
			return out
		src = src.duplicate(true)
		src["boost"] = float(c.get("upgrade_boost", 0.0))
		_merge_into(src, went)
	out["slot_order"] = (src.get("slot_order", []) as Array).duplicate()
	out["options"] = src.get("options", {})
	out["boost"] = float(src.get("boost", 0.0))
	(out["stat_bars"] as Dictionary).merge(src.get("stat_bars", {}) as Dictionary, true)
	var gslots: Dictionary = c.get("slots", {})
	var own_slots: Dictionary = src.get("slots", {})
	var names: Dictionary = src.get("slot_names", {})
	var slots: Dictionary = {}
	for s: Variant in out["slot_order"]:
		var sd: Dictionary = ((own_slots.get(s, gslots.get(s, {})) as Dictionary)).duplicate()
		if names.has(s):
			sd["name"] = names[s]
		slots[str(s)] = sd
	out["slots"] = slots
	# a slot left without options drops out of the order
	var order: Array = []
	for s2: Variant in out["slot_order"]:
		if not ((out["options"] as Dictionary).get(s2, {}) as Dictionary).is_empty():
			order.append(str(s2))
	out["slot_order"] = order
	if order.is_empty():
		out["refuse"] = str(c.get("refuse_default", "The armorer can't work on that."))
	return out


## A class table with its "like" chain folded in (deep copy).
static func _class_table(cls: String, depth: int) -> Dictionary:
	var classes: Dictionary = cfg().get("classes", {})
	if cls == "" or not classes.has(cls) or depth > 4:
		return {}
	var own: Dictionary = classes[cls]
	if not own.has("like"):
		return own.duplicate(true)
	var base: Dictionary = _class_table(str(own["like"]), depth + 1)
	_merge_into(base, own)
	return base


## Folds an override entry onto a table: options option by option (null removes, a dict's keys replace),
## slot_order / slot_names / stat_bars replace or merge.
static func _merge_into(dst: Dictionary, over: Dictionary) -> void:
	if over.has("slot_order"):
		dst["slot_order"] = (over["slot_order"] as Array).duplicate()
	if over.has("slot_names"):
		var n: Dictionary = dst.get("slot_names", {})
		n.merge(over["slot_names"] as Dictionary, true)
		dst["slot_names"] = n
	if over.has("stat_bars"):
		var sb: Dictionary = dst.get("stat_bars", {})
		sb.merge(over["stat_bars"] as Dictionary, true)
		dst["stat_bars"] = sb
	var opts: Dictionary = dst.get("options", {})
	for slot: Variant in (over.get("options", {}) as Dictionary).keys():
		var so: Dictionary = (opts.get(slot, {}) as Dictionary)
		var ov: Dictionary = (over["options"] as Dictionary)[slot]
		for o: Variant in ov.keys():
			if ov[o] == null:
				so.erase(o)
			elif so.has(o):
				var merged: Dictionary = (so[o] as Dictionary).duplicate(true)
				merged.merge((ov[o] as Dictionary).duplicate(true), true)
				so[o] = merged
			else:
				so[o] = (ov[o] as Dictionary).duplicate(true)
		opts[slot] = so
	dst["options"] = opts


# ================================================================== the catalogue

## True when the bench works on `of` (it has at least one slot).
static func accepts(of: Variant) -> bool:
	if of == null:
		return false
	return str(table(of).get("refuse", "")) == "" and not (table(of)["slot_order"] as Array).is_empty()


## The bench's in-character refusal for `of` ("" when it takes attachments).
static func refusal(of: Variant) -> String:
	if of == null:
		return REASONS["no_gun"]
	return str(table(of).get("refuse", ""))


static func slot_order(of: Variant) -> Array:
	return table(of)["slot_order"] if of != null else []


## Every slot id any gun can have, in display order (encode, the map marks' radial).
static func slot_ids() -> Array:
	return cfg().get("slot_ids", ["mag", "barrel", "sights", "grip", "ammo"])


static func slot_name(of: Variant, slot: String) -> String:
	var sd: Dictionary = (table(of)["slots"] as Dictionary).get(slot, {}) if of != null else {}
	if sd.is_empty():
		sd = (cfg().get("slots", {}) as Dictionary).get(slot, {})
	return str(sd.get("name", slot.capitalize()))


static func slot_sound(of: Variant, slot: String) -> String:
	var sd: Dictionary = (table(of)["slots"] as Dictionary).get(slot, {}) if of != null else {}
	if sd.is_empty():
		sd = (cfg().get("slots", {}) as Dictionary).get(slot, {})
	return str(sd.get("sound", "reload_end"))


## Option ids of a slot on `of`, in data order.
static func options(of: Variant, slot: String) -> Array:
	if of == null:
		return []
	return ((table(of)["options"] as Dictionary).get(slot, {}) as Dictionary).keys()


static func option_def(of: Variant, slot: String, option: String) -> Dictionary:
	if of == null:
		return {}
	return (((table(of)["options"] as Dictionary).get(slot, {}) as Dictionary).get(option, {}) as Dictionary)


static func is_known(of: Variant, slot: String, option: String) -> bool:
	return not option_def(of, slot, option).is_empty()


## The option as fitted to the base gun or (upgraded) to its Crucible version: the upgraded block's own name,
## text and numbers; price, power gate, looks and model it doesn't set come from the base block. On a class
## table, a number group the upgraded block leaves out is the base's, boosted (benefits x boost, drawbacks x0.6).
static func variant(of: Variant, slot: String, option: String, upgraded: bool) -> Dictionary:
	var d: Dictionary = option_def(of, slot, option)
	if not upgraded or not d.has("upgraded"):
		return d
	var out: Dictionary = (d["upgraded"] as Dictionary).duplicate(true)
	for k: String in ["price", "requires_power", "locked_text"]:
		if d.has(k):
			out[k] = d[k]
	for k2: String in LOOK_KEYS:
		if not out.has(k2) and d.has(k2):
			out[k2] = d[k2]
	for k3: String in COPY_KEYS:
		if not out.has(k3) and d.has(k3):
			out[k3] = d[k3]
	var boost: float = float(table(of).get("boost", 0.0))
	if boost > 0.0:
		for g: String in NUM_GROUPS:
			if not out.has(g) and d.has(g):
				var src: Dictionary = d[g]
				var dst: Dictionary = {}
				for key: Variant in src.keys():
					dst[key] = boosted(float(src[key]), LOWER_BETTER.has(str(key)), boost)
				out[g] = dst
		for g2: String in ["set", "props", "feel"]:
			if not out.has(g2) and d.has(g2):
				out[g2] = (d[g2] as Dictionary).duplicate(true)
		if not out.has("draw") and d.has("draw"):
			out["draw"] = boosted(float(d["draw"]), true, boost)
	return out


## One multiplier grown for an upgraded part: a benefit by `boost`, a drawback shrunk to 60%.
static func boosted(m: float, lower_better: bool, boost: float) -> float:
	var good: bool = (m < 1.0) if lower_better else (m > 1.0)
	var k: float = boost if good else 0.6
	return snappedf(maxf(0.05, 1.0 + (m - 1.0) * k), 0.0001)


static func price(of: Variant, slot: String, option: String) -> int:
	return int(option_def(of, slot, option).get("price", 0))


static func option_name(of: Variant, slot: String, option: String, upgraded: bool = false) -> String:
	if option == "":
		return "Standard"
	return str(variant(of, slot, option, upgraded).get("name", option.capitalize()))


## A name for `option` in `slot` without a gun to hand (the map marks' radial): the first table that has it.
static func any_option_name(slot: String, option: String) -> String:
	for wid: Variant in (cfg().get("weapons", {}) as Dictionary).keys():
		var d: Dictionary = option_def(str(wid), slot, option)
		if not d.is_empty():
			return str(d.get("name", option.capitalize()))
	for cls: Variant in (cfg().get("classes", {}) as Dictionary).keys():
		var t: Dictionary = _class_table(str(cls), 0)
		var d2: Dictionary = ((t.get("options", {}) as Dictionary).get(slot, {}) as Dictionary).get(option, {})
		if not d2.is_empty():
			return str(d2.get("name", option.capitalize()))
	return option.capitalize()


# ================================================================== compiling a kit into numbers

## Folds a kit (slot -> option) for gun `of` into the modifiers WeaponInstance and WeaponHolder read: stats
## (multipliers on f() keys), set (mag / reserve), scale (mag / reserve multipliers), limb (hitbox multipliers),
## recoil (pattern multipliers), feel (overrides), props (flags), draw (raise-time multiplier), the looks (flash,
## glow, tip).
static func compile(of: Variant, kit: Dictionary, upgraded: bool) -> Dictionary:
	var m: Dictionary = {"stats": {}, "set": {}, "scale": {}, "limb": {}, "recoil": {}, "feel": {}, "props": {}, "draw": 1.0,
		"flash": "", "glow": [], "tip": ""}
	for slot: String in slot_order(of):
		var opt: String = str(kit.get(slot, ""))
		if opt == "" or not is_known(of, slot, opt):
			continue
		var v: Dictionary = variant(of, slot, opt, upgraded)
		for group: String in ["stats", "limb", "recoil", "scale"]:
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

## Why `option` can't go into `slot` on `w` ("" = it can): no gun, a gun the bench refuses, unknown for this gun,
## already fitted, under the counter before the power, Jakub and the Nachtglas rounds. Slots are exclusive: a
## different option replaces the fitted one.
static func check(w: WeaponInstance, slot: String, option: String, power_on: bool, companion: bool = false) -> String:
	if w == null:
		return "no_gun"
	if not accepts(w):
		return "wrong_weapon"
	if not is_known(w, slot, option):
		return "unknown"
	if str(w.kit.get(slot, "")) == option:
		return "installed"
	if bool(option_def(w, slot, option).get("requires_power", false)) and not power_on:
		return "needs_power"
	if companion and (cfg().get("companion_refuses", []) as Array).has(option):
		return "refused"
	return ""


## A reason code as text; "wrong_weapon" with a gun gives that gun's in-character refusal.
static func reason_text(code: String, w: WeaponInstance = null) -> String:
	if code == "wrong_weapon" and w != null and refusal(w) != "":
		return refusal(w)
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


## The gun in `p`'s hands (whatever it is: the bench shows its refusal when it takes nothing).
static func held(p: Player) -> WeaponInstance:
	if p == null or p.weapons == null:
		return null
	return p.weapons.current()


## The gun a purchase goes on: the one in `p`'s hands when the bench works on it (and, when `slot` / `option` are
## given, offers that option), else the first such gun in their slots (a bot sent for a part); null if none.
static func gun_of(p: Player, slot: String = "", option: String = "") -> WeaponInstance:
	if p == null or p.weapons == null:
		return null
	var ok: Callable = func(w: WeaponInstance) -> bool:
		return w != null and accepts(w) and (slot == "" or option == "" or is_known(w, slot, option)) \
			and (slot == "" or option != "" or not options(w, slot).is_empty())
	var cw: WeaponInstance = p.weapons.current()
	if ok.call(cw):
		return cw
	for w2: WeaponInstance in p.weapons.slots:
		if ok.call(w2):
			return w2
	return null


static func has_option(w: WeaponInstance, slot: String, option: String) -> bool:
	return w != null and str(w.kit.get(slot, "")) == option


## False for a gun Jakub won't take: one loaded with Nachtglas rounds (data companion_refuses).
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
	for slot: Variant in slot_ids():
		var opt: String = str(kit.get(slot, ""))
		if opt != "":
			out.append("%s:%s" % [slot, opt])
	return out


## The list back into a kit for gun `of` (parts that gun doesn't take are dropped).
static func decode(list: Variant, of: Variant) -> Dictionary:
	var kit: Dictionary = {}
	if not (list is Array) or of == null:
		return kit
	for e: Variant in list:
		var parts: PackedStringArray = str(e).split(":")
		if parts.size() == 2 and is_known(of, parts[0], parts[1]):
			kit[parts[0]] = parts[1]
	return kit


## Copies the attachments and finish of `from` onto `to` (a weapon rebuilt from the same gun: the Crucible's
## result, the gun Jakub hands back). Parts `to` doesn't take are dropped.
static func copy(from: WeaponInstance, to: WeaponInstance) -> void:
	if from == null or to == null or not accepts(to):
		return
	to.kit = decode(encode(from.kit), to)
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


## Every build that changes a gun's sights or stock, for tools/ads_check.sh: the M1911 / Last Rites sights x grip
## grid (as in T-068), then for every other gun (base and upgraded) each sights option alone and with each grip
## option that puts a part on the model.
static func sight_stock_builds() -> PackedStringArray:
	var out: PackedStringArray = M1911Kit.sight_stock_builds()
	var t: Dictionary = GLData.table("weapons")
	var ids: Array = (t.get("weapons", {}) as Dictionary).keys() + (t.get("upgraded", {}) as Dictionary).keys()
	for id: Variant in ids:
		var wid: String = str(id)
		if base_of(wid) == &"m1911" or not accepts(wid):
			continue
		var grips: Array = [""]
		for g: Variant in options(wid, "grip"):
			if str(option_def(wid, "grip", str(g)).get("model", "")) != "":
				grips.append(str(g))
		for s: Variant in options(wid, "sights"):
			for g2: String in grips:
				out.append("%s:sights=%s%s" % [wid, s, (",grip=" + g2) if g2 != "" else ""])
	return out


## A short signature of the kit and finish (cache keys: models, recoil, ADS zoom).
static func signature(kit: Dictionary, finish: StringName = &"") -> String:
	if kit.is_empty() and finish == &"":
		return ""
	return ",".join(PackedStringArray(encode(kit))) + "|" + String(finish)


# ================================================================== the bench's read-outs

## The gun's attachments, one row per slot (the bench and the pause menu's LOADOUT tab):
## [{slot, slot_name, option ("" = standard), name, desc}].
static func describe(w: WeaponInstance) -> Array:
	var out: Array = []
	if not accepts(w):
		return out
	for slot: String in slot_order(w):
		var opt: String = str(w.kit.get(slot, ""))
		out.append({"slot": slot, "slot_name": slot_name(w, slot), "option": opt, "name": option_name(w, slot, opt, w.upgraded),
			"desc": str(variant(w, slot, opt, w.upgraded).get("desc", "")) if opt != "" else ""})
	return out


## The six stat bars (0..1 each, plus a readable value) for `w`, or for `w` with `slot` set to `option` when a
## preview is given: {damage, range, recoil, ads, mobility, capacity} -> {value, text}. Recoil is relative to the
## plain base gun; the bar ranges are per class (stat_bars).
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
	var plain: WeaponInstance = WeaponInstance.create(w.base_id())
	var sb: Dictionary = table(w)["stat_bars"]
	var rc: Dictionary = WeaponHolder.recoil_for(t)
	var rc0: Dictionary = WeaponHolder.recoil_for(plain)
	var kick: float = float(rc.get("v", 0.6)) * (0.5 + 0.5 * float(rc.get("punch", 0.45)) / maxf(0.01, float(rc0.get("punch", 0.45))))
	var kick0: float = maxf(0.01, float(rc0.get("v", 0.6)))
	var dmg: float = t.f("damage", 40.0) * maxf(1.0, float(t.data.get("pellets", 1)))
	var rng: float = t.f("falloff_end", 30.0)
	if t.data.has("stream"):
		rng = float(t.property("reach", (t.data["stream"] as Dictionary).get("reach", 7.0)))
	var ads_time: float = maxf(0.01, t.f("ads_time", 0.15))
	var mob: float = t.f("move_mult", 1.0) / sqrt(maxf(0.1, t.draw_mult()))
	var rng_max: float = float(sb.get("range_max", 60.0)) if not t.data.has("stream") else 14.0
	return {
		"damage": {"value": clampf(dmg / float(sb.get("damage_max", 200.0)), 0.0, 1.0), "text": "%d" % roundi(dmg)},
		"range": {"value": clampf(rng / rng_max, 0.0, 1.0), "text": "%d m" % roundi(rng)},
		"recoil": {"value": clampf(0.6 * kick / kick0 * float(sb.get("recoil_ref", 1.0)), 0.0, 1.0), "text": "%d%%" % roundi(100.0 * kick / kick0)},
		"ads": {"value": clampf(float(sb.get("ads_speed_ref", 0.075)) / ads_time, 0.0, 1.0), "text": "%.2f s" % ads_time},
		"mobility": {"value": clampf(mob / float(sb.get("mobility_max", 1.2)), 0.0, 1.0), "text": "%d%%" % roundi(100.0 * mob)},
		"capacity": {"value": clampf(float(t.mag_size()) / float(sb.get("capacity_max", 40.0)), 0.0, 1.0), "text": "%d" % t.mag_size()},
	}


# ================================================================== hits and sounds

## A hit landed by a kitted gun: Nachtglas rounds may slow the target, the Censer Compensator's flare sets close
## targets alight, incendiary rounds now and then set it burning. `dist` is from the shooter's eye.
static func on_hit(w: WeaponInstance, z: Zombie, killed: bool, dist: float, pid: int) -> void:
	if killed or z == null:
		return
	var slow: Variant = w.property("kit_slow")
	if slow is Dictionary and randf() < float((slow as Dictionary).get("chance", 0.0)):
		z.apply_frost(float((slow as Dictionary).get("slow", 0.3)), float((slow as Dictionary).get("dur", 1.5)))
	var flare: Variant = w.property("kit_flare")
	if flare is Dictionary and dist <= float((flare as Dictionary).get("range", 6.0)):
		z.ignite(float((flare as Dictionary).get("dps", 80.0)), float((flare as Dictionary).get("dur", 3.0)), pid)
	var ign: Variant = w.property("kit_ignite")
	if ign is Dictionary and randf() < float((ign as Dictionary).get("chance", 0.0)):
		z.ignite(float((ign as Dictionary).get("dps", 60.0)), float((ign as Dictionary).get("dur", 3.0)), pid)


## The fire sound key for a suppressed gun: "fire_<base>_suppressed" when the bank has it, else the M1911's
## suppressed shot (data sounds.suppressed_fire); "" = none (play the normal shot, quieter: feel fire_db).
static func suppressed_sound(w: WeaponInstance) -> String:
	var own: String = "fire_%s_suppressed" % String(w.base_id())
	if AudioDirector.has_sound(own):
		return own
	var sk: String = str((cfg().get("sounds", {}) as Dictionary).get("suppressed_fire", ""))
	return sk if sk != "" and AudioDirector.has_sound(sk) else ""


static func sound(key: String, fallback: String = "") -> String:
	return str((cfg().get("sounds", {}) as Dictionary).get(key, fallback))
