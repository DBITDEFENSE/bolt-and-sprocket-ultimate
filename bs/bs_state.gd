extends Node
## Bolt & Sprocket run state: bolts, gold bolts, owned weapons with their levels and mods, mallet tier,
## memos, quests, story flags, Super Sprocket meter. Lives in SaveProfile.doc["bs"] so one profile holds all.
## Autoload name: BS.

const START_HP: int = 100

var bolts: int = 0
var max_hp: int = START_HP
var weapons: Dictionary = {}      # weapon_id -> {"xp": int, "level": int, "mods": {"dmg": int, "rate": int, "ammo": int}, "sig": int, "omega": bool, "ammo_now": int}
var weapon_order: Array = []      # owned weapon ids in wheel order
var current_weapon: StringName = &""
var mallet_tier: int = 0          # 0 Scrap, 1 Magma, 2 Thunder (3 Riot)
var flags: Dictionary = {}        # story flags (beat ids seen, gates opened)
var super_meter: float = 0.0
var super_owned: bool = false
var god_mode: bool = false        # dev console
var ui_block: int = 0             # >0 while a menu, shop, dialogue or cutscene owns the input


func _ready() -> void:
	load_from_profile()


func load_from_profile() -> void:
	var b: Dictionary = SaveProfile.doc.get("bs", {})
	bolts = int(b.get("bolts", 0))
	max_hp = int(b.get("max_hp", START_HP))
	weapons = (b.get("weapons", {}) as Dictionary).duplicate(true)
	weapon_order = (b.get("weapon_order", []) as Array).duplicate()
	current_weapon = StringName(str(b.get("current_weapon", "")))
	mallet_tier = int(b.get("mallet_tier", 0))
	flags = (b.get("flags", {}) as Dictionary).duplicate(true)
	super_owned = bool(b.get("super_owned", false))


func save_to_profile() -> void:
	var b: Dictionary = SaveProfile.doc["bs"]
	b["bolts"] = bolts
	b["max_hp"] = max_hp
	b["weapons"] = weapons.duplicate(true)
	b["weapon_order"] = weapon_order.duplicate()
	b["current_weapon"] = String(current_weapon)
	b["mallet_tier"] = mallet_tier
	b["flags"] = flags.duplicate(true)
	b["super_owned"] = super_owned
	SaveProfile.save_profile()


func blocked() -> bool:
	return ui_block > 0


func add_bolts(n: int) -> void:
	if n == 0:
		return
	bolts = maxi(0, bolts + n)
	EventBus.bolts_changed.emit(bolts, n)


func spend(n: int) -> bool:
	if bolts < n:
		return false
	add_bolts(-n)
	return true


func owns(weapon_id: StringName) -> bool:
	return weapons.has(String(weapon_id))


func give_weapon(weapon_id: StringName) -> void:
	var id: String = String(weapon_id)
	if not weapons.has(id):
		weapons[id] = {"xp": 0, "level": 1, "mods": {"dmg": 0, "rate": 0, "ammo": 0}, "sig": -1, "omega": false, "ammo_now": -1}
		weapon_order.append(id)
	if current_weapon == &"":
		current_weapon = weapon_id
		EventBus.weapon_changed.emit(weapon_id)


func flag(id: String) -> bool:
	return bool(flags.get(id, false))


func set_flag(id: String, v: bool = true) -> void:
	flags[id] = v


func add_super(amount: float) -> void:
	if not super_owned:
		return
	super_meter = clampf(super_meter + amount, 0.0, 1.0)
	EventBus.super_meter_changed.emit(super_meter)
