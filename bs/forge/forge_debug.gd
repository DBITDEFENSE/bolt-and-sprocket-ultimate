class_name ForgeDebug
extends RefCounted
## Dev-console helpers for the arsenal and the Omega Forge (the lead wires the commands in core/dev_console.gd):
##   ForgeDebug.give_all() -> int                 every one of the 16 guns, full ammo (returns how many were new)
##   ForgeDebug.set_level(id, lvl) -> bool        V1..V5 by setting the XP to that level's threshold
##   ForgeDebug.open_forge() -> Node              opens the Forge screen (a temporary, unlocked Forge near Bolt if
##                                                the level has none); sets OmegaForge.debug_unlock
##   ForgeDebug.max_out(id, sig_choice) -> bool   V5 + all mods tier 3 + a Signature Mod: ready to evolve
##   ForgeDebug.evolve(id) -> bool                Ω for free (no cutscene)


static func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func manager() -> WeaponManager:
	var t: SceneTree = tree()
	var b: Node = t.get_first_node_in_group(&"player") if t != null else null
	return b.get_node_or_null("Weapons") as WeaponManager if b != null else null


static func give_all() -> int:
	var n: int = 0
	var m: WeaponManager = manager()
	for id: StringName in WeaponData.ids():
		if not BS.owns(id):
			n += 1
		if m != null:
			m.give(id)
		else:
			BS.give_weapon(id)
	if m != null:
		m.refill_all()
		m.wheel_changed.emit()
	return n


static func set_level(id: StringName, lvl: int) -> bool:
	if not WeaponData.has(id):
		return false
	BS.give_weapon(id)
	var lv: int = clampi(lvl, 1, WeaponData.thresholds().size())
	var st: Dictionary = BS.weapons[String(id)]
	st["xp"] = float(WeaponData.thresholds()[lv - 1])
	st["level"] = lv
	EventBus.weapon_leveled.emit(id, lv)
	var m: WeaponManager = manager()
	if m != null:
		m.give(id)
		m.wheel_changed.emit()
	return true


static func max_out(id: StringName, sig_choice: int = 0) -> bool:
	if not set_level(id, 5):
		return false
	var st: Dictionary = BS.weapons[String(id)]
	var mods: Dictionary = st["mods"]
	for s: String in WeaponData.MOD_SLOTS:
		mods[s] = int(WeaponData.mods()["max_tier"])
	st["sig"] = clampi(sig_choice, 0, 1)
	return true


static func evolve(id: StringName) -> bool:
	if not WeaponData.has(id):
		return false
	BS.give_weapon(id)
	(BS.weapons[String(id)] as Dictionary)["omega"] = true
	var m: WeaponManager = manager()
	if m != null:
		m.wheel_changed.emit()
	return true


static func open_forge() -> Node:
	OmegaForge.debug_unlock = true
	var t: SceneTree = tree()
	if t == null:
		return null
	var f: OmegaForge = t.get_first_node_in_group(&"omega_forge") as OmegaForge
	if f == null:
		f = OmegaForge.new()
		f.name = "DebugOmegaForge"
		var parent: Node = t.current_scene if t.current_scene != null else t.root
		parent.add_child(f)
		var b: Node3D = t.get_first_node_in_group(&"player") as Node3D
		if b != null:
			f.global_position = b.global_position + Vector3(0, -0.95, -3.0)
	return f.open_ui()
