class_name WeaponInstance
extends RefCounted
## One weapon a player is holding: its data row plus live state (ammo, fire mode, underbarrel, heat).
## Upgraded variants (Crucible) come from the "upgraded" table and carry a "properties" dictionary.

var id: StringName
var data: Dictionary
var mag: int = 0
var reserve: int = 0
var upgraded: bool = false
var fire_mode: String = "semi"
var underbarrel_active: bool = false
var underbarrel_ammo: int = 0
var heat: float = 0.0              # seconds of continuous fire (overheating weapons)
var overheat_lockout: float = 0.0  # seconds left before it can fire again


static func create(weapon_id: StringName) -> WeaponInstance:
	var w: WeaponInstance = WeaponInstance.new()
	w.id = weapon_id
	var t: Dictionary = GLData.table("weapons")
	if t["weapons"].has(String(weapon_id)):
		w.data = t["weapons"][String(weapon_id)]
	else:
		w.data = t["upgraded"][String(weapon_id)]
		w.upgraded = true
	w.fire_mode = str(w.fire_modes()[0])
	w.refill()
	return w


## The base weapon id (for upgraded variants, the weapon they came from).
func base_id() -> StringName:
	return StringName(str(data.get("base", id)))


func property(key: String, fallback: Variant = null) -> Variant:
	return (data.get("properties", {}) as Dictionary).get(key, fallback)


func has_property(key: String) -> bool:
	return (data.get("properties", {}) as Dictionary).has(key)


## The upgraded weapon id this weapon becomes in the Crucible, or &"" if it can't be upgraded.
func upgrade_id() -> StringName:
	if upgraded:
		return &""
	var up: String = str(data.get("upgraded", ""))
	if up == "" or not (GLData.table("weapons").get("upgraded", {}) as Dictionary).has(up):
		return &""
	return StringName(up)


func display_name() -> String:
	var n: String = str(data.get("name", id))
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
	return int(data["mag"])


func reserve_max() -> int:
	return int(data["reserve"])


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


func f(key: String, fallback: float = 0.0) -> float:
	return float(data.get(key, fallback))


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
