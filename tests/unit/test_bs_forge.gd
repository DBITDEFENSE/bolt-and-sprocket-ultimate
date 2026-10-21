extends GutTest
## BLARTZ'S OMEGA FORGE (bs/forge/omega_forge.gd), its screen (ui/bs/forge_ui.gd) and ForgeDebug. Headless.

var _world: Node3D
var _bolt: Bolt
var _wm: WeaponManager
var _forge: OmegaForge
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {"weapons": BS.weapons.duplicate(true), "order": BS.weapon_order.duplicate(), "cur": BS.current_weapon,
		"bolts": BS.bolts, "flags": BS.flags.duplicate(true), "block": BS.ui_block, "paused": get_tree().paused}
	BS.weapons = {}
	BS.weapon_order = []
	BS.current_weapon = &""
	BS.bolts = 0
	BS.ui_block = 0
	BS.flags = {}
	OmegaForge.debug_unlock = false
	ForgeUI.pause_default = false
	_world = Node3D.new()
	add_child_autofree(_world)
	_bolt = Bolt.new()
	_bolt.position = Vector3(0, 0.95, 0)
	_world.add_child(_bolt)
	_bolt.scripted = {"dir": Vector3.ZERO}
	_wm = WeaponManager.attach_to(_bolt, false)
	_wm.callouts_enabled = false
	_forge = OmegaForge.new()
	_world.add_child(_forge)
	_forge.position = Vector3(0, 0, -2)
	var cut: Dictionary = (_forge.F.get("cutscene", {}) as Dictionary).duplicate()
	for k: String in ["door", "bellows", "flare", "stamp", "line"]:
		cut[k] = 0.05
	_forge.F = _forge.F.duplicate()
	_forge.F["cutscene"] = cut


func after_each() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"omega_forge"):
		n.queue_free()
	for c: Node in get_tree().root.get_children():
		if c is ForgeUI:
			(c as ForgeUI).close()
	OmegaForge.debug_unlock = false
	ForgeUI.pause_default = true
	BS.weapons = _saved["weapons"]
	BS.weapon_order = _saved["order"]
	BS.current_weapon = _saved["cur"]
	BS.bolts = _saved["bolts"]
	BS.flags = _saved["flags"]
	BS.ui_block = _saved["block"]
	get_tree().paused = _saved["paused"]


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func test_forge_look_and_plaque() -> void:
	var plaque: Label3D = _forge.get_node("Plaque") as Label3D
	assert_not_null(plaque)
	assert_eq(plaque.text, "BLARTZ'S OMEGA FORGE · MOD. Ω-1 · PAT. PEND. BLZ-40417", "the plaque rhymes with the Crucible's")
	assert_true(_forge.is_in_group(&"omega_forge") and _forge.is_in_group(&"interactables"))


func test_locked_until_blartz_rescue() -> void:
	watch_signals(EventBus)
	assert_false(_forge.is_unlocked())
	assert_eq(_forge.interact(), "locked")
	assert_signal_emitted(EventBus, "hint", "a cold forge")
	BS.set_flag("blartzRescue")
	assert_true(_forge.is_unlocked(), "unlocks with the rescue beat (M4)")


func test_first_visit_plays_the_schematics_dialogue_once() -> void:
	BS.set_flag("blartzRescue")
	watch_signals(EventBus)
	assert_eq(_forge.interact(), "intro")
	assert_true(_forge.intro_playing)
	await _frames(3)
	assert_signal_emitted_with_parameters(EventBus, "vo_line_started", ["bs.forge.blartz.01", "blartz", WeaponText.text("bs.forge.blartz.01")])
	_forge.skip_intro()
	assert_false(_forge.intro_playing)
	await _frames(2)
	assert_eq(BS.ui_block, 1, "then the Forge screen opens and owns the input")
	var ui: Node = _forge.open_ui()
	assert_true(ui is ForgeUI)
	(ui as ForgeUI).close()
	assert_eq(BS.ui_block, 0)
	assert_eq(_forge.interact(), "open", "the dialogue plays once")


func test_deny_lines_in_order_then_evolve() -> void:
	OmegaForge.debug_unlock = true
	var id: StringName = &"omni_blaster"
	assert_eq(_forge.evolve(id), "bs.forge.deny.01", "below V5: a CHILD")
	ForgeDebug.set_level(id, 5)
	assert_eq(_forge.evolve(id), "bs.forge.deny.02", "mods missing")
	for s: String in WeaponData.MOD_SLOTS:
		(BS.weapons["omni_blaster"]["mods"] as Dictionary)[s] = 3
	assert_eq(_forge.evolve(id), "bs.forge.deny.03", "no signature")
	BS.weapons["omni_blaster"]["sig"] = 0
	BS.bolts = 1999
	assert_eq(_forge.evolve(id), "bs.forge.deny.04", "TWO. THOUSAND.")
	assert_false(_wm.weapon(id).omega())
	BS.bolts = 2500
	watch_signals(EventBus)
	watch_signals(_forge)
	assert_eq(_forge.evolve(id), "", "ready: it evolves")
	assert_eq(BS.bolts, 500, "2,000 bolts")
	assert_true(_wm.weapon(id).omega(), "Ω")
	assert_eq(WeaponData.display_name(id, true), "Ω OVERTIME")
	assert_true(_forge.playing, "the evolution cutscene plays")
	assert_false(_forge.can_skip(), "the first one can't be skipped")
	await _frames(40)
	assert_false(_forge.playing)
	assert_signal_emitted(_forge, "cutscene_finished")
	assert_signal_emitted(EventBus, "banner", "the new name as a banner")
	assert_signal_emitted_with_parameters(EventBus, "vo_line_started",
		["bs.forge.evolve.blaster", "blartz", WeaponText.text("bs.forge.evolve.blaster")])
	assert_eq(int(_wm.weapon(id).call("hot_every")), 3, "and the Ω behaviour is live")


func test_cutscene_is_skippable_after_the_first() -> void:
	OmegaForge.debug_unlock = true
	BS.set_flag("forge.evolve_seen")
	ForgeDebug.max_out(&"void_ripper", 1)
	BS.bolts = 2000
	assert_eq(_forge.evolve(&"void_ripper"), "")
	assert_true(_forge.can_skip())
	assert_true(_forge.skip(), "SKIP")
	assert_false(_forge.playing)
	assert_true(_wm.weapon(&"void_ripper").omega())


func test_forge_ui_rows_signatures_and_evolve() -> void:
	OmegaForge.debug_unlock = true
	ForgeDebug.give_all()
	var ui: ForgeUI = _forge.open_ui() as ForgeUI
	await _frames(2)
	assert_eq(ui._list.get_child_count(), 16, "a row per owned gun")
	BS.bolts = 1000
	assert_false(ui.install(&"lawn_dart", 0), "Signature Mods unlock at V3")
	ForgeDebug.set_level(&"lawn_dart", 3)
	assert_true(ui.install(&"lawn_dart", 1), "install B")
	assert_eq(BS.bolts, 800, "200 bolts")
	assert_eq(_wm.weapon(&"lawn_dart").sig(), &"express_delivery")
	assert_true(ui.install(&"lawn_dart", 0), "swap is free")
	assert_eq(BS.bolts, 800)
	assert_eq(ui.evolve(&"lawn_dart"), "bs.forge.deny.01")
	ForgeDebug.max_out(&"lawn_dart", 0)
	BS.bolts = 2000
	assert_eq(ui.evolve(&"lawn_dart"), "")
	assert_true(_wm.weapon(&"lawn_dart").omega())
	await _frames(2)
	assert_false(ui._panel.visible, "the panel hides while the cutscene plays")
	await _frames(40)
	ui.close()
	assert_eq(BS.ui_block, 0)


func test_forge_debug_helpers() -> void:
	assert_eq(ForgeDebug.give_all(), 13, "13 new guns on top of the 3 starters")
	assert_eq(_wm.weapons.size(), 16)
	for id: StringName in WeaponData.ids():
		var w: BSWeapon = _wm.weapon(id)
		assert_true(w.ammo() < 0 or w.ammo() == w.max_ammo(), "%s full" % id)
	assert_true(ForgeDebug.set_level(&"fine_print", 4))
	assert_eq(_wm.weapon(&"fine_print").level(), 4)
	assert_eq(float(BS.weapons["fine_print"]["xp"]), 4000.0)
	assert_false(ForgeDebug.set_level(&"nope", 2))
	assert_true(ForgeDebug.max_out(&"root_canal", 1))
	BS.bolts = 2000
	assert_eq(_wm.can_evolve(&"root_canal"), "", "max_out = ready for the Forge")
	_forge.queue_free()
	await _frames(1)
	var ui: Node = ForgeDebug.open_forge()
	assert_true(ui is ForgeUI, "open_forge opens the screen")
	assert_true(OmegaForge.debug_unlock)
	assert_not_null(get_tree().get_first_node_in_group(&"omega_forge"), "on a temporary Forge when the level has none")
	(ui as ForgeUI).close()
	assert_true(ForgeDebug.evolve(&"clearance_rack"))
	assert_true(_wm.weapon(&"clearance_rack").omega())
