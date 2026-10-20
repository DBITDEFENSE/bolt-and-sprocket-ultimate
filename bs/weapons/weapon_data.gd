class_name WeaponData
extends RefCounted
## Read-only view of data/bs/weapons.json plus the pure progression maths (docs/BS_WEAPONS.md §1-§2).
## Everything here is static and side-effect free, so the shop, the Forge, the HUD and tests can share it.
##
##   WeaponData.def(id) -> Dictionary            the weapon's table row
##   WeaponData.param(id, key, fallback)         a number from its "params"
##   WeaponData.ids() -> Array[StringName]       wheel order (slots 1..16)
##   WeaponData.level_for_xp(xp) -> int          V1..V5 from cumulative XP (0 / 600 / 1800 / 4000 / 8000)
##   WeaponData.dmg_mul(dmg_tier, level)         (1 + 0.25 tier) x (1 + 0.06 per V-level above 1)
##   WeaponData.rate_mul(rate_tier)              1 - 0.15 tier (interval / drain / redeploy multiplier)
##   WeaponData.max_ammo(id, ammo_tier, level)   (AMMO_BASE + AMMO_PER_TIER x tier) x (1 + V bonus), rounded up; -1 = infinite
##   WeaponData.heat_capacity(id, ammo_tier)     Blaster heat max (100 + 20 per Heat Sink tier)
##   WeaponData.mod_price(slot, next_tier)       Blartz Mod prices (60/110/170, 50/90/140, 40/70/110)

const PATH: String = "bs/weapons"
const MOD_SLOTS: Array[String] = ["dmg", "rate", "ammo"]


static func doc() -> Dictionary:
	return Data.table(PATH) as Dictionary


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: Variant in doc()["order"]:
		out.append(StringName(str(s)))
	return out


static func has(id: StringName) -> bool:
	return (doc()["weapons"] as Dictionary).has(String(id))


static func def(id: StringName) -> Dictionary:
	return (doc()["weapons"] as Dictionary).get(String(id), {})


static func params(id: StringName) -> Dictionary:
	return def(id).get("params", {})


static func param(id: StringName, key: String, fallback: Variant = 0.0) -> Variant:
	return params(id).get(key, fallback)


static func progression() -> Dictionary:
	return doc()["progression"]


static func mods() -> Dictionary:
	return doc()["mods"]


static func display_name(id: StringName, omega: bool = false) -> String:
	var d: Dictionary = def(id)
	if omega and d.has("omega_name"):
		return str(d["omega_name"])
	return str(d.get("name", String(id).to_upper()))


static func color(id: StringName) -> Color:
	return Color.from_string(str(def(id).get("color", "#ffffff")), Color.WHITE)


static func slot_of(id: StringName) -> int:
	return int(def(id).get("slot", 0))


# ------------------------------------------------------------------ progression maths

static func thresholds() -> Array:
	return progression()["xp_thresholds"]


static func level_for_xp(xp: float) -> int:
	var th: Array = thresholds()
	var lv: int = 1
	for i: int in th.size():
		if xp >= float(th[i]):
			lv = i + 1
	return clampi(lv, 1, th.size())


## XP still needed for the next level (0 at V5).
static func xp_to_next(xp: float) -> float:
	var lv: int = level_for_xp(xp)
	var th: Array = thresholds()
	if lv >= th.size():
		return 0.0
	return float(th[lv]) - xp


static func level_dmg_bonus(level: int) -> float:
	var a: Array = progression()["level_dmg_bonus"]
	return float(a[clampi(level - 1, 0, a.size() - 1)])


static func level_ammo_bonus(level: int) -> float:
	var a: Array = progression()["level_ammo_bonus"]
	return float(a[clampi(level - 1, 0, a.size() - 1)])


static func dmg_mul(dmg_tier: int, level: int = 1) -> float:
	return (1.0 + float(mods()["dmg"]["per_tier"]) * dmg_tier) * (1.0 + level_dmg_bonus(level))


static func rate_mul(rate_tier: int) -> float:
	return 1.0 - float(mods()["rate"]["per_tier"]) * rate_tier


## Shots get bigger and brighter with damage mods (tierMul 4507).
static func visual_mul(dmg_tier: int) -> float:
	return 1.0 + float(mods()["visual_tier_per_dmg"]) * dmg_tier


static func max_ammo(id: StringName, ammo_tier: int, level: int = 1) -> int:
	var d: Dictionary = def(id)
	var base: int = int(d.get("ammo_base", -1))
	if base < 0:
		return -1
	var raw: float = float(base + int(d.get("ammo_per_tier", 0)) * ammo_tier)
	return ceili(raw * (1.0 + level_ammo_bonus(level)) - 0.0001)


static func heat_capacity(id: StringName, ammo_tier: int, level: int = 1) -> float:
	var base: float = float(param(id, "heat_max", 100.0))
	return (base + float(mods()["ammo"]["heat_per_tier"]) * ammo_tier) * (1.0 + level_ammo_bonus(level))


static func mod_price(slot: String, next_tier: int) -> int:
	var prices: Array = (mods()[slot] as Dictionary)["prices"]
	if next_tier < 1 or next_tier > prices.size():
		return -1
	return int(prices[next_tier - 1])


static func signature(id: StringName, choice: int) -> Dictionary:
	var s: Dictionary = def(id).get("signature", {})
	return s.get("A" if choice == 0 else "B", {}) if choice >= 0 else {}


static func signature_id(id: StringName, choice: int) -> StringName:
	return StringName(str(signature(id, choice).get("id", "")))


static func omega_desc(id: StringName) -> String:
	var i: int = int(def(id).get("omega_desc_index", -1))
	var src: Variant = Data.table("bs_source/OMEGA_DESC")
	if i >= 0 and src is Array and i < (src as Array).size():
		return str((src as Array)[i])
	return ""


## Ammo granted by one orb of `family` to weapon `id` (0 if it isn't in that family).
static func family_grant(family: String, id: StringName) -> int:
	var fams: Dictionary = doc()["ammo_families"]
	if not fams.has(family) or not (fams[family] is Dictionary):
		return 0
	return int(((fams[family] as Dictionary)["grants"] as Dictionary).get(String(id), 0))


static func family_names() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in (doc()["ammo_families"] as Dictionary).keys():
		if (doc()["ammo_families"] as Dictionary)[k] is Dictionary:
			out.append(str(k))
	return out


static func damage_type(id: StringName) -> int:
	match str(def(id).get("damage_type", "kinetic")):
		"energy": return Combat.Type.ENERGY
		"fire": return Combat.Type.FIRE
		"frost": return Combat.Type.FROST
		"shock": return Combat.Type.SHOCK
		"legal": return Combat.Type.LEGAL
		"void": return Combat.Type.VOID
	return Combat.Type.KINETIC


static func unlock_hint_id(id: StringName) -> String:
	return "bs.weapon.unlock." + str(def(id).get("unlock", "shop"))


## Optional bool property on a duck-typed node (heavy, elite, armored, fragile); false when absent.
static func prop_bool(o: Object, prop: String) -> bool:
	return o != null and prop in o and bool(o.get(prop))
