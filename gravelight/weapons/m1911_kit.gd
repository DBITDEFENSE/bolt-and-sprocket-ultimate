class_name M1911Kit
extends RefCounted
## The starting pistol's view of the attachments (UPDATE_04 section 6, DECISIONS T-068; generalised to every gun
## by WeaponKit, T-074). The M1911 / Last Rites table is unchanged: five slots (magazine, barrel, sights,
## grip / stock, ammo), eleven options, each with its upgraded Last Rites version, now stored as
## data/gravelight/weapons/attachments.json "weapons.m1911" (own_table) with the cosmetic finishes and the
## Loadout Pick, which stay M1911-only (they unlock with M1911 kills).
##
## The (slot, option) calls here are the M1911's table: they forward to WeaponKit with the M1911 as the gun.
## Anything that works on whatever gun is in hand calls WeaponKit directly. Public API for other sections:
## M1911Kit.loadout_rows (the pause menu's LOADOUT tab), the finishes and the Loadout Pick (Settings > Gameplay).

const GUN: StringName = &"m1911"
const REASONS: Dictionary = WeaponKit.REASONS

static var _cfg: Dictionary = {}


## The shared attachment data (sounds, vo, flash_scale, companion_refuses) with the M1911's own table on top
## (slot_order, slots, options, stat_bars, finishes, loadout_pick).
static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var c: Dictionary = WeaponKit.cfg().duplicate()
		c.merge((c.get("weapons", {}) as Dictionary).get(String(GUN), {}) as Dictionary, true)
		c["weapons"] = [String(GUN)]
		_cfg = c
	return _cfg


## Drops the cached tables (tests, data edits).
static func reload() -> void:
	_cfg = {}
	WeaponKit.reload()


# ================================================================== the M1911's catalogue

static func slot_order() -> Array:
	return WeaponKit.slot_order(GUN)


static func slot_name(slot: String) -> String:
	return WeaponKit.slot_name(GUN, slot)


static func slot_sound(slot: String) -> String:
	return WeaponKit.slot_sound(GUN, slot)


static func options(slot: String) -> Array:
	return WeaponKit.options(GUN, slot)


static func option_def(slot: String, option: String) -> Dictionary:
	return WeaponKit.option_def(GUN, slot, option)


static func is_known(slot: String, option: String) -> bool:
	return WeaponKit.is_known(GUN, slot, option)


static func variant(slot: String, option: String, upgraded: bool) -> Dictionary:
	return WeaponKit.variant(GUN, slot, option, upgraded)


static func price(slot: String, option: String) -> int:
	return WeaponKit.price(GUN, slot, option)


static func option_name(slot: String, option: String, upgraded: bool = false) -> String:
	return WeaponKit.option_name(GUN, slot, option, upgraded)


## True for the M1911 and anything taught from it (Last Rites, II, III).
static func applies_to(w: WeaponInstance) -> bool:
	return w != null and w.base_id() == GUN


static func compile(kit: Dictionary, upgraded: bool) -> Dictionary:
	return WeaponKit.compile(GUN, kit, upgraded)


static func apply_recoil(rc: Dictionary, w: WeaponInstance) -> Dictionary:
	return WeaponKit.apply_recoil(rc, w)


## WeaponKit.check, limited to the M1911 ("wrong_weapon" for any other gun).
static func check(w: WeaponInstance, slot: String, option: String, power_on: bool, companion: bool = false) -> String:
	if w == null:
		return "no_pistol"
	if not applies_to(w):
		return "wrong_weapon"
	return WeaponKit.check(w, slot, option, power_on, companion)


static func reason_text(code: String) -> String:
	return WeaponKit.reason_text(code)


static func install(w: WeaponInstance, slot: String, option: String) -> void:
	WeaponKit.install(w, slot, option)


## The M1911 in `p`'s hands, else the first one in their slots.
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
	return WeaponKit.has_option(w, slot, option)


static func companion_accepts(w: WeaponInstance) -> bool:
	return WeaponKit.companion_accepts(w)


static func encode(kit: Dictionary) -> Array:
	return WeaponKit.encode(kit)


static func decode(list: Variant) -> Dictionary:
	return WeaponKit.decode(list, GUN)


static func copy(from: WeaponInstance, to: WeaponInstance) -> void:
	WeaponKit.copy(from, to)


static func from_build(build: String) -> WeaponInstance:
	return WeaponKit.from_build(build)


static func build_file_name(build: String) -> String:
	return WeaponKit.build_file_name(build)


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


static func signature(kit: Dictionary, finish: StringName = &"") -> String:
	return WeaponKit.signature(kit, finish)


static func describe(w: WeaponInstance) -> Array:
	return WeaponKit.describe(w) if applies_to(w) else []


## For the LOADOUT tab: the attachments on `p`'s pistol (describe()), [] when they carry none.
static func loadout_rows(p: Player) -> Array:
	return describe(pistol_of(p))


static func stats(w: WeaponInstance, slot: String = "", option: String = "") -> Dictionary:
	return WeaponKit.stats(w, slot, option)


static func on_hit(w: WeaponInstance, z: Zombie, killed: bool, dist: float, pid: int) -> void:
	WeaponKit.on_hit(w, z, killed, dist, pid)


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
