class_name WeaponInstance
extends RefCounted
## One weapon a player is holding: its data row plus live state (ammo, fire mode, underbarrel, heat).
## Upgraded variants (Crucible) come from the "upgraded" table and carry a "properties" dictionary.
## `tier` (T-037): 0 = base, 1 = Crucible-taught (the "_up" row), 2 and 3 = re-taught twice / thrice: the same row
## scaled by weapons.json "crucible_tiers" (damage, mag, reserve, reload) with a name suffix.

var id: StringName
var data: Dictionary
var mag: int = 0
var reserve: int = 0
var upgraded: bool = false
var tier: int = 0
var fire_mode: String = "semi"
var underbarrel_active: bool = false
var underbarrel_ammo: int = 0
var heat: float = 0.0              # seconds of continuous fire (overheating weapons)
var overheat_lockout: float = 0.0  # seconds left before it can fire again
## Attachments (UPDATE_04 section 6, WeaponKit; any gun since T-074): slot -> option id, and the cosmetic finish
## (M1911 only). They belong to this gun, so they go wherever it goes. Call refresh_kit() after changing `kit`.
var kit: Dictionary = {}
var finish: StringName = &""
var _kit_mods: Dictionary = {}     # WeaponKit.compile(self, kit, upgraded), rebuilt by refresh_kit()
var _kit_stats: Dictionary = {}    # its "stats" block (f() multipliers), kept apart for speed


static func create(weapon_id: StringName) -> WeaponInstance:
	var w: WeaponInstance = WeaponInstance.new()
	w.id = weapon_id
	var t: Dictionary = GLData.table("weapons")
	if t["weapons"].has(String(weapon_id)):
		w.data = t["weapons"][String(weapon_id)]
	else:
		w.data = t["upgraded"][String(weapon_id)]
		w.upgraded = true
		w.tier = 1
	w.fire_mode = str(w.fire_modes()[0])
	w.refill()
	return w


## The base weapon id (for upgraded variants, the weapon they came from).
func base_id() -> StringName:
	return StringName(str(data.get("base", id)))


func property(key: String, fallback: Variant = null) -> Variant:
	if not _kit_mods.is_empty() and (_kit_mods["props"] as Dictionary).has(key):
		return (_kit_mods["props"] as Dictionary)[key]
	return (data.get("properties", {}) as Dictionary).get(key, fallback)


func has_property(key: String) -> bool:
	if not _kit_mods.is_empty() and (_kit_mods["props"] as Dictionary).has(key):
		return true
	return (data.get("properties", {}) as Dictionary).has(key)


# ---------------------------------------------------------------- attachments (WeaponKit)

## Recompiles the attachment modifiers after `kit` changed (WeaponKit.install does this for you).
func refresh_kit() -> void:
	if kit.is_empty():
		_kit_mods = {}
		_kit_stats = {}
		return
	_kit_mods = WeaponKit.compile(self, kit, upgraded)
	_kit_stats = _kit_mods["stats"]


## The compiled attachment modifiers ({} without attachments): see WeaponKit.compile.
func kit_mods() -> Dictionary:
	return _kit_mods


## True with a suppressor fitted: its shots don't reveal on the minimap (UPDATE_04 section 2's firing reveal).
func is_suppressed() -> bool:
	return bool(property("suppressed", false))


## Raise-time multiplier after a swap (a stock or bipod is slower to draw, checkered grips or a sling faster).
func draw_mult() -> float:
	return float(_kit_mods.get("draw", 1.0)) if not _kit_mods.is_empty() else 1.0


## The fitted attachments by name (the Crucible names on an upgraded gun), then the finish: what the pause menu's
## LOADOUT tab lists under the gun (PauseMenu.attachment_text calls this).
func attachment_labels() -> PackedStringArray:
	var out: PackedStringArray = []
	for d: Dictionary in WeaponKit.describe(self):
		if str(d["option"]) != "":
			out.append(str(d["name"]))
	if finish != &"":
		out.append("%s finish" % str(M1911Kit.finish_def(finish).get("name", String(finish))))
	return out


## Cache key part for anything the attachments or finish change (models, recoil, ADS zoom).
func kit_sig() -> String:
	return WeaponKit.signature(kit, finish) if not kit.is_empty() or finish != &"" else ""


## The Crucible's tier table (weapons.json "crucible_tiers"): [{tier, suffix, damage_mult, mag_mult, reserve_mult, reload_mult}].
static func tiers() -> Array:
	return GLData.table("weapons").get("crucible_tiers", [])


## The highest tier the Crucible teaches (1 when the table is empty).
static func max_tier() -> int:
	var m: int = 1
	for t: Dictionary in tiers():
		m = maxi(m, int(t.get("tier", 1)))
	return m


## This weapon's tier row ({} for base and first-tier weapons).
func tier_cfg() -> Dictionary:
	if tier < 2:
		return {}
	for t: Dictionary in tiers():
		if int(t.get("tier", 1)) == tier:
			return t
	return {}


## The upgraded weapon id this weapon becomes in the Crucible, or &"" if it can't be upgraded. A taught weapon
## below the top tier returns its own id: the Crucible re-teaches it (tier + 1).
func upgrade_id() -> StringName:
	if upgraded:
		return id if tier < max_tier() else &""
	var up: String = str(data.get("upgraded", ""))
	if up == "" or not (GLData.table("weapons").get("upgraded", {}) as Dictionary).has(up):
		return &""
	return StringName(up)


func display_name() -> String:
	var n: String = str(data.get("name", id)) + str(tier_cfg().get("suffix", ""))
	if overheat_lockout > 0.0:
		return n + "  [OVERHEATED]"
	if can_overheat() and heat > 0.5:
		return n + "  [HEAT %d%%]" % int(100.0 * heat / f("overheat_seconds", 8.0))
	if underbarrel_active:
		return n + "  [GRENADE %d]" % underbarrel_ammo
	if fire_modes().size() > 1:
		return n + "  [%s]" % fire_mode.to_upper()
	return n


func mag_size() -> int:
	var base: int = int(data["mag"])
	if not _kit_mods.is_empty():
		base = int((_kit_mods["set"] as Dictionary).get("mag", base))
		base = maxi(1, roundi(base * float((_kit_mods["scale"] as Dictionary).get("mag", 1.0))))
	return ceili(base * float(tier_cfg().get("mag_mult", 1.0)))


func reserve_max() -> int:
	var base: int = int(data["reserve"])
	if not _kit_mods.is_empty():
		base = int((_kit_mods["set"] as Dictionary).get("reserve", base))
		base = roundi(base * float((_kit_mods["scale"] as Dictionary).get("reserve", 1.0)))
	return ceili(base * float(tier_cfg().get("reserve_mult", 1.0)))


func refill() -> void:
	mag = mag_size()
	reserve = reserve_max()
	if property("underbarrel", "") == "rifle_grenade":
		underbarrel_ammo = int(GLData.table("weapons").get("rifle_grenade", {}).get("count", 6))


func is_full() -> bool:
	var ub_full: bool = property("underbarrel", "") != "rifle_grenade" \
		or underbarrel_ammo >= int(GLData.table("weapons").get("rifle_grenade", {}).get("count", 6))
	return mag >= mag_size() and reserve >= reserve_max() and ub_full


func weapon_class() -> StringName:
	return StringName(str(data.get("class", "rifle")))


## A numeric stat; damage and the reload times scale with the Crucible tier (T-037).
func f(key: String, fallback: float = 0.0) -> float:
	var v: float = float(data.get(key, fallback))
	if tier >= 2:
		var tc: Dictionary = tier_cfg()
		match key:
			"damage":
				v *= float(tc.get("damage_mult", 1.0))
			"reload_partial", "reload_empty":
				v *= float(tc.get("reload_mult", 1.0))
	if not _kit_stats.is_empty():
		v *= float(_kit_stats.get(key, 1.0))
	return v


## Damage multiplier at a distance (full to falloff_start, linear to falloff_min at falloff_end).
func falloff(dist: float) -> float:
	var s: float = f("falloff_start", 20.0)
	var e: float = f("falloff_end", 50.0)
	if dist <= s:
		return 1.0
	if dist >= e:
		return f("falloff_min", 0.5)
	return lerpf(1.0, f("falloff_min", 0.5), (dist - s) / maxf(0.01, e - s))


func limb_mult(limb: StringName) -> float:
	var m: float
	var overrides: Dictionary = data.get("limb_mults", {})
	if limb == &"head" and has_property("head_mult"):
		m = float(property("head_mult"))
	elif overrides.has(String(limb)):
		m = float(overrides[String(limb)])
	else:
		m = float(GLData.table("weapons")["default_limb_mults"].get(String(limb), 1.0))
	if has_property("hollow_point") and (limb == &"arms" or limb == &"legs"):
		m *= 1.5
	if not _kit_mods.is_empty():
		m *= float((_kit_mods["limb"] as Dictionary).get(String(limb), 1.0))
	return m


# ---------------------------------------------------------------- fire modes / alt-fire

## Available fire modes. Upgrades may add a selector ("fire_modes" property).
func fire_modes() -> Array:
	var p: Variant = property("fire_modes")
	if p is Array and not (p as Array).is_empty():
		return p
	return [str(data.get("mode", "semi"))]


static func next_mode(modes: Array, cur: String) -> String:
	var i: int = modes.find(cur)
	return str(modes[(i + 1) % modes.size()])


## Alt-fire: cycles the fire mode, or toggles the underbarrel launcher. Returns what changed.
func toggle_alt() -> StringName:
	if property("underbarrel", "") == "rifle_grenade":
		underbarrel_active = not underbarrel_active
		return &"underbarrel"
	var modes: Array = fire_modes()
	if modes.size() > 1:
		fire_mode = next_mode(modes, fire_mode)
		return &"mode"
	return &""


# ---------------------------------------------------------------- overheat (Browning M1919)

func can_overheat() -> bool:
	return data.has("overheat_seconds") and not bool(property("no_overheat", false))


func can_fire_heat() -> bool:
	return overheat_lockout <= 0.0


## Advances heat. `firing` = the trigger is held and a shot went out this frame.
func tick_heat(delta: float, firing: bool) -> void:
	if not can_overheat():
		heat = 0.0
		return
	if overheat_lockout > 0.0:
		overheat_lockout = maxf(0.0, overheat_lockout - delta)
		heat = 0.0
		return
	var limit: float = f("overheat_seconds", 8.0)
	var cool: float = f("overheat_cooldown", 3.0)
	if firing:
		heat += delta
		if heat >= limit:
			heat = 0.0
			overheat_lockout = cool
	else:
		heat = maxf(0.0, heat - delta * limit / cool)
