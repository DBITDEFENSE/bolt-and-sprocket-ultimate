extends GutTest
## M1 UI/systems: BSLevel boot, cutscene subtitles, shop math, dev console, Sprocket barks, Super Sprocket.
## Headless, silent (VOManager never speaks headless). The save profile is redirected to a test file.


class MiniLevel extends BSLevel:
	func build() -> void:
		var b: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = Vector3(60, 1, 60)
		cs.shape = sh
		b.add_child(cs)
		b.position = Vector3(0, -0.5, 0)
		add_child(b)


var _saved_path: String
var _saved_doc: Dictionary
var _subs: Array = []


func before_all() -> void:
	_saved_path = SaveProfile.path
	_saved_doc = SaveProfile.doc.duplicate(true)
	SaveProfile.path = "user://test_bs_ui_profile.json"


func after_all() -> void:
	SaveProfile.path = _saved_path
	SaveProfile.doc = _saved_doc
	BS.load_from_profile()
	BS.ui_block = 0
	BS.god_mode = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_bs_ui_profile.json"))


func before_each() -> void:
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.ui_block = 0
	BS.super_meter = 0.0
	BS.super_owned = false
	BS.god_mode = false
	_subs.clear()
	get_tree().paused = false


func after_each() -> void:
	if EventBus.subtitle.is_connected(_on_sub):
		EventBus.subtitle.disconnect(_on_sub)
	get_tree().paused = false
	BS.ui_block = 0


func _on_sub(_speaker: String, text: String, _c: Color, _s: float) -> void:
	_subs.append(text)


func _level() -> MiniLevel:
	var l: MiniLevel = MiniLevel.new()
	l.spawn_point = Vector3(2, 1.0, 3)
	l.kill_y = -25.0
	l.level_id = "mini"
	l.play_arrival = false
	add_child_autofree(l)
	return l


# ------------------------------------------------------------------ BSLevel

func test_level_boots_with_bolt_camera_sprocket_hud() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	assert_not_null(l.bolt, "Bolt spawned")
	assert_not_null(l.camera, "camera spawned")
	assert_not_null(l.sprocket, "Sprocket spawned")
	assert_not_null(l.hud, "HUD spawned")
	assert_not_null(l.console, "console spawned")
	assert_not_null(l.pause_menu, "pause menu spawned")
	assert_eq(l.bolt.camera, l.camera, "bolt.camera set")
	assert_eq(l.camera.target, l.bolt, "camera.target set")
	assert_eq(l.sprocket.bolt, l.bolt, "Sprocket follows Bolt")
	assert_eq(l.bolt.kill_y, -25.0, "kill_y passed to Bolt")
	assert_eq(AimAssist.player, l.bolt, "aim assist player")
	assert_true(AimAssist.enabled_mode, "aim assist on in a level")
	assert_almost_eq(l.bolt.global_position.x, 2.0, 0.05, "Bolt at the spawn point")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "no mouse capture headless")
	if ResourceLoader.exists("res://bs/weapons/weapon_manager.gd"):
		assert_not_null(l.bolt.get_node_or_null("Weapons"), "WeaponManager attached to Bolt")
		assert_eq(l.weapons, l.bolt.get_node_or_null("Weapons"))


func test_sprocket_hovers_at_bolts_shoulder() -> void:
	var l: MiniLevel = _level()
	for i: int in 90:
		await get_tree().process_frame
	var want: Vector3 = l.sprocket.shoulder_point()
	assert_lt(l.sprocket.global_position.distance_to(want), 0.6, "spring settles at the shoulder point")
	assert_gt(l.sprocket.global_position.y, l.bolt.global_position.y, "floats above Bolt's centre")


func test_hint_once_per_key_and_banner() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	assert_true(l.show_hint("Mash F!", "mutts"))
	assert_false(l.show_hint("Mash F!", "mutts"), "same key shows once")
	assert_eq(l.hud.last_hint, "Mash F!")
	l.banner("SCRAPHEAP JUNCTION", "sub", 2.0)
	assert_eq(l.hud.last_banner, "SCRAPHEAP JUNCTION")


func test_death_respawns_at_checkpoint() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	l.set_checkpoint(Vector3(5, 1, 5), "COMPACTION LOT")
	l.bolt.invuln = 0.0
	l.bolt.take_damage(Combat.Hit.make(9999.0))
	assert_true(l.bolt.dead)
	assert_eq(l.hud.last_banner, BSText.text("code.damagePlayer.01"), "BOLT DOWN! banner")
	l.dead_timer = 0.01
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(l.bolt.dead, "respawned")
	assert_almost_eq(l.bolt.global_position.x, 5.0, 0.05, "at the checkpoint")
	assert_eq(l.hud.last_banner, BSText.text("code.respawn.01"), "RELAY RESPAWN banner")


func test_story_beat_plays_once() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	EventBus.subtitle.connect(_on_sub)
	assert_true(l.story_beat("l1_row"), "first time plays")
	assert_true(l.cutscenes.playing)
	assert_gt(BS.ui_block, 0, "dialogue blocks input")
	l.cutscenes.skip()
	assert_false(l.story_beat("l1_row"), "second time is skipped")
	assert_eq(_subs.size(), 1, "one line shown before the skip")


# ------------------------------------------------------------------ cutscenes

func test_cutscene_lines_emit_subtitles_in_order() -> void:
	var cp: CutscenePlayer = CutscenePlayer.new()
	cp.pause_world = false
	add_child_autofree(cp)
	EventBus.subtitle.connect(_on_sub)
	var expected: Array = []
	for s: Variant in (CutscenePlayer.scenes()["intro"] as Dictionary)["steps"]:
		if str((s as Dictionary)["type"]) == "line":
			expected.append(BSText.text(str(s["id"])))
	assert_eq(expected.size(), 8, "The Repossession has 8 lines")
	assert_true(cp.play("intro"))
	assert_gt(BS.ui_block, 0, "cutscene blocks input")
	var guard: int = 0
	while cp.playing and guard < 2000:
		cp.step(0.25)
		guard += 1
	assert_false(cp.playing, "finished on its own timers")
	assert_eq(_subs, expected, "subtitles in step order")
	assert_eq(BS.ui_block, 0, "input released")
	assert_true(BS.flag("cs.intro"), "marked seen")


func test_cutscene_advance_and_skip() -> void:
	var cp: CutscenePlayer = CutscenePlayer.new()
	cp.pause_world = false
	add_child_autofree(cp)
	EventBus.subtitle.connect(_on_sub)
	var done: Array = [false]
	cp.play("intro", func() -> void: done[0] = true)
	assert_eq(_subs.size(), 0, "opens on a camera move")
	cp.advance()
	cp.advance()
	assert_eq(_subs.size(), 2, "each advance moves to the next step")
	cp.skip()
	assert_false(cp.playing)
	assert_true(done[0], "on_done runs after a skip")
	assert_false(cp.play("no_such_scene"), "unknown ids fail gracefully")


func test_cutscene_vec_parsing() -> void:
	var cp: CutscenePlayer = CutscenePlayer.new()
	add_child_autofree(cp)
	assert_eq(cp.vec([1, 2, 3]), Vector3(1, 2, 3))
	assert_eq(cp.vec("garagePos([6, 3, 8])"), Vector3(6, 3, 8), "anchor + offset (no host: origin)")
	assert_eq(cp.vec("() => weird"), Vector3.INF, "unparseable -> skipped")


# ------------------------------------------------------------------ shop

func _shop() -> ShopLogic:
	var s: ShopLogic = ShopLogic.new(get_tree())
	for id: String in ["boom_box", "buzzkill", "lawn_dart"]:
		s.implemented_override[id] = true
	return s


func test_shop_buy_and_deny() -> void:
	var s: ShopLogic = _shop()
	BS.bolts = 200
	var r: Dictionary = s.buy("w.boom_box")
	assert_true(r["ok"], "bought the B.O.O.M. Box")
	assert_eq(BS.bolts, 50, "150 spent")
	assert_true(BS.owns(&"boom_box"))
	assert_true(str(r["line"]).begins_with("blartz.buy."), "Blartz's buy line")
	var d: Dictionary = s.buy("w.lawn_dart")
	assert_false(d["ok"])
	assert_eq(d["reason"], "broke")
	assert_true(str(d["line"]).begins_with("blartz.deny."), "deny line")
	assert_eq(BS.bolts, 50, "nothing spent on a deny")
	assert_true(s.find("w.boom_box").is_empty(), "owned guns leave the counter")


func test_shop_unimplemented_is_coming_soon() -> void:
	var s: ShopLogic = _shop()
	s.implemented_override["buzzkill"] = false
	BS.bolts = 999
	var it: Dictionary = s.find("w.buzzkill")
	assert_false(it["available"])
	assert_eq(it["locked_reason"], "coming_soon")
	assert_eq(s.buy("w.buzzkill")["reason"], "unavailable")
	assert_eq(BS.bolts, 999)


func test_shop_trade_in_sixty_percent() -> void:
	var s: ShopLogic = _shop()
	BS.give_weapon(&"omni_blaster")
	BS.give_weapon(&"boom_box")
	BS.give_weapon(&"lawn_dart")
	assert_eq(s.trade_value("boom_box"), 90, "60% of 150")
	assert_eq(s.trade_value("lawn_dart"), 150, "60% of 250")
	assert_eq(s.trade_value("omni_blaster"), 0, "starters can't be sold")
	assert_eq(s.trade_in_list().size(), 2)
	BS.bolts = 10
	(BS.weapons["boom_box"] as Dictionary)["mods"]["dmg"] = 2
	var r: Dictionary = s.sell("boom_box")
	assert_true(r["ok"])
	assert_eq(BS.bolts, 100)
	assert_false(BS.owns(&"boom_box"), "gone, with its mods")
	assert_false(s.sell("omni_blaster")["ok"])


func test_shop_mods_mallet_nano_deal_wish_tip() -> void:
	var s: ShopLogic = _shop()
	BS.give_weapon(&"boom_box")
	BS.bolts = 2000
	assert_true(s.buy("u.boom_box.dmg")["ok"])
	assert_eq(int((BS.weapons["boom_box"] as Dictionary)["mods"]["dmg"]), 1, "damage mod tier 1")
	assert_eq(BS.bolts, 2000 - 60)
	assert_eq(int(s.find("u.boom_box.dmg")["price"]), 110, "next tier price")
	assert_eq(int(s.find("mallet")["price"]), 220, "Magma Mallet")
	assert_true(s.buy("mallet")["ok"])
	assert_eq(BS.mallet_tier, 1)
	assert_true(s.buy("mallet")["ok"], "Thunder Mallet")
	assert_eq(s.buy("mallet")["reason"], "maxed", "mallet track maxed")
	assert_eq(int(s.find("nano")["price"]), 100)
	s.buy("nano")
	assert_eq(BS.max_hp, 120)
	assert_eq(int(s.find("nano")["price"]), 160, "100 + 60 per boost bought")
	s.open_visit()
	assert_ne(s.deal_id, "", "a deal of the day")
	var deal: Dictionary = s.find(s.deal_id)
	assert_true(deal["deal"])
	assert_eq(int(deal["price"]), roundi(float(deal["was"]) * 0.75), "25% off")
	BS.bolts = 100
	s.toggle_wish("super")
	s.toggle_wish("ammo")
	assert_eq(s.wish_pin()["id"], "super", "cheapest unaffordable wish")
	assert_true(s.buy("super")["ok"] == false)
	BS.bolts = 3
	assert_eq(s.tip()["line"], "blartz.tips.01")
	assert_eq(s.tip()["line"], "blartz.tips.02")
	assert_eq(BS.bolts, 1)
	assert_eq(s.tip_count(), 2)


func test_shop_super_purchase_comes_charged() -> void:
	var s: ShopLogic = _shop()
	BS.bolts = 900
	assert_true(s.buy("super")["ok"] or s.deal_id == "super")
	assert_true(BS.super_owned)
	assert_eq(BS.super_meter, 1.0)


func test_shop_ui_opens_and_blocks_input() -> void:
	BS.bolts = 500
	var ui: ShopUI = ShopUI.open(get_tree(), _shop())
	await get_tree().process_frame
	assert_eq(BS.ui_block, 1)
	assert_true(get_tree().paused, "the world freezes while shopping")
	ui.set_tab("tradein")
	ui.set_tab("all")
	ui.buy("w.boom_box")
	assert_true(BS.owns(&"boom_box"))
	ui.close()
	assert_eq(BS.ui_block, 0)
	assert_false(get_tree().paused, "and resumes")


func test_kiosk_tip_jar_and_arrested() -> void:
	var k: ShopKiosk = ShopKiosk.new()
	add_child_autofree(k)
	await get_tree().process_frame
	assert_eq(k.target_for(k.jar_position()), "tip")
	assert_eq(k.target_for(k.global_position + Vector3(0, 0, 2.5)), "shop")
	assert_eq(k.target_for(k.global_position + Vector3(0, 0, 9)), "")
	k.arrested = true
	k.target = "shop"
	assert_eq(k.interact(), "arrested", "BACK IN 5 MIN")
	assert_eq(BS.ui_block, 0, "no shop while he's arrested")


# ------------------------------------------------------------------ console

func test_console_commands() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	var c: DevConsole = l.console
	c.execute("bolts 75")
	assert_eq(BS.bolts, 75)
	c.execute("give boom_box")
	assert_true(BS.owns(&"boom_box"))
	c.execute("level boom_box 3")
	assert_eq(int((BS.weapons["boom_box"] as Dictionary)["level"]), 3)
	c.execute("omega boom_box")
	assert_true(bool((BS.weapons["boom_box"] as Dictionary)["omega"]))
	c.execute("god on")
	assert_true(BS.god_mode)
	c.execute("god")
	assert_false(BS.god_mode)
	c.execute("tp 4 2 -6")
	assert_almost_eq(l.bolt.global_position.z, -6.0, 0.01)
	assert_string_contains(c.execute("quest q1a 4"), "DONE")
	c.execute("super")
	assert_true(BS.super_owned)
	assert_eq(BS.super_meter, 1.0)
	c.execute("fps")
	assert_true(l.hud.show_fps)
	c.execute("enemies")
	assert_true(l.hud.show_enemies)
	assert_eq(c.execute("points 500"), "not in this mode", "Gravelight verb in B&S")
	assert_string_contains(c.execute("warp nowhere"), "no such level")
	assert_string_contains(c.execute("nonsense"), "unknown command")
	assert_ne(c.execute("spawn scrapmutt"), "", "spawn answers (spawner or not)")
	c.execute("cutscene intro")
	assert_true(l.cutscenes.playing)
	l.cutscenes.skip()
	c.execute("complete")
	assert_true(l.completed)
	assert_true(BS.flag("cleared.mini"))


# ------------------------------------------------------------------ Sprocket barks

func test_barks_respect_cooldowns() -> void:
	var b: SprocketBarks = SprocketBarks.new()
	assert_eq(b.try_bark("lowhp", 0.2), "", "8 s start cooldown")
	b.cd = 0.0
	assert_eq(b.try_bark("lowhp", 0.9), "", "lowhp needs <= 30% HP")
	var id: String = b.try_bark("lowhp", 0.2)
	assert_true(id.begins_with("bark.lowhp."), "low HP bark")
	assert_eq(b.cd, 32.0, "32 s after a non-combat bark")
	assert_eq(b.try_bark("lowhp", 0.1), "", "cooling down")
	b.tick(31.9, true, false)
	assert_eq(b.try_bark("lowhp", 0.1), "", "still cooling")
	b.tick(0.2, true, false)
	b.rng.seed = 7
	var got: String = ""
	for i: int in 200:
		got = b.try_bark("combat", 1.0)
		if got != "":
			break
	assert_true(got.begins_with("bark.combat."), "combat bark rolls eventually (12%)")
	assert_eq(b.cd, 24.0, "24 s after a combat bark")
	b.cd = 0.0
	assert_eq(b.try_bark("bolts", 1.0, true), "", "never while blocked")


func test_idle_bark_after_25s() -> void:
	var b: SprocketBarks = SprocketBarks.new()
	b.cd = 0.0
	assert_eq(b.tick(20.0, false, false), "")
	assert_eq(b.tick(5.0, true, false), "", "moving resets the idle timer")
	assert_eq(b.tick(24.0, false, false), "")
	assert_true(b.tick(1.5, false, false).begins_with("bark.idle."), "idle bark")
	assert_eq(b.cd, 32.0)


func test_sprocket_moods() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	var s: Sprocket = l.sprocket
	assert_eq(s.mood, &"normal")
	EventBus.player_damaged.emit(5.0, 95.0)
	assert_eq(s.mood, &"alarmed", "hurt -> alarmed")
	s.set_mood(&"happy", 0.05)
	assert_eq(s.mood, &"happy")
	for i: int in 10:
		await get_tree().process_frame
	assert_eq(s.mood, &"normal", "mood decays back to normal")
	s.set_mood(&"smug", 1.0)
	assert_lt(s.eye_scale().y, 0.7, "smug is half-lidded")
	s.set_voice_filter(&"firmware_classic")
	assert_eq(s.voice_filter, &"firmware_classic", "voice-filter hook stores the choice")


# ------------------------------------------------------------------ Super Sprocket

func test_super_meter_fills_from_damage_and_combo() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	var sp: SuperProtocol = l.sprocket.super_protocol
	EventBus.enemy_hit.emit(null, Combat.Hit.make(100.0), false)
	assert_eq(BS.super_meter, 0.0, "nothing until the protocol is owned")
	BS.super_owned = true
	EventBus.enemy_hit.emit(null, Combat.Hit.make(100.0), false)
	assert_almost_eq(BS.super_meter, 0.06, 0.0001, "+dmg x 0.0006")
	EventBus.combo_changed.emit(10)
	EventBus.enemy_hit.emit(null, Combat.Hit.make(100.0), false)
	assert_almost_eq(BS.super_meter, 0.06 + 0.09, 0.0001, "combo tier 10 -> x1.5")
	assert_almost_eq(sp.combo_mult(20), 2.0, 0.001)
	assert_false(sp.activate(), "not full yet")
	assert_eq(l.hud.last_hint, BSText.text("code.superActivate.01"), "still-charging hint")


func test_super_activation_overclock_turret() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	var sp: SuperProtocol = l.sprocket.super_protocol
	BS.super_owned = true
	BS.super_meter = 1.0
	BS.set_flag("super_seen")      # skip the first-time slow-mo in tests
	var dummy: TestDummy = TestDummy.new()
	l.add_child(dummy)
	dummy.global_position = l.bolt.global_position + Vector3(0, -0.95, -6)
	assert_true(sp.activate())
	assert_true(sp.active)
	assert_eq(BS.super_meter, 0.0, "meter spent")
	assert_eq(sp.mode, &"overclock")
	assert_eq(l.sprocket.damage_mult(), 2.0, "everything hits twice as hard")
	assert_eq(Sprocket.damage_mult_for(get_tree()), 2.0)
	EventBus.enemy_hit.emit(dummy, Combat.Hit.make(500.0), false)
	assert_eq(BS.super_meter, 0.0, "no charging while it runs")
	for i: int in 120:
		await get_tree().physics_frame
	assert_gt(sp.shots_fired, 0, "the turret fires")
	assert_gt(dummy.total_damage(), 0.0, "and hits through the Combat contract")
	assert_eq((dummy.hits[0] as Combat.Hit).weapon_id, &"super_sprocket")
	assert_eq((dummy.hits[0] as Combat.Hit).amount, 12.0, "6 x 2")
	sp.update(31.0)
	assert_false(sp.active, "ends after 30 s")
	assert_eq(l.sprocket.damage_mult(), 1.0)


func test_super_bulwark_shields_and_heals() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	var sp: SuperProtocol = l.sprocket.super_protocol
	BS.super_owned = true
	BS.super_meter = 1.0
	BS.set_flag("super_seen")
	l.bolt.hp = 10.0
	assert_eq(sp.pick_mode(), &"bulwark", "hurting -> Bulwark")
	assert_true(sp.activate())
	assert_eq(sp.mode, &"bulwark", "Bulwark runs as itself (T-029)")
	var before: float = l.bolt.hp
	l.bolt.invuln = 0.0
	l.bolt.take_damage(Combat.Hit.make(10.0))
	assert_almost_eq(before - l.bolt.hp, 3.5, 0.01, "Bolt takes 35% of a hit")
	var hp_now: float = l.bolt.hp
	sp.update(1.0)
	assert_almost_eq(l.bolt.hp, hp_now + 3.0, 0.01, "regenerates 3/s")
	sp.end()
	assert_eq(l.bolt.damage_taken_mult, 1.0, "the shield drops with the protocol")


func test_super_zip_hops_between_enemies() -> void:
	var l: MiniLevel = _level()
	await get_tree().process_frame
	var sp: SuperProtocol = l.sprocket.super_protocol
	BS.super_owned = true
	BS.super_meter = 1.0
	BS.set_flag("super_seen")
	var dummies: Array[TestDummy] = []
	for i: int in 5:
		var d: TestDummy = TestDummy.new()
		l.add_child(d)
		d.global_position = l.bolt.global_position + Vector3(-4.0 + i * 2.5, -0.95, -6)
		dummies.append(d)
	assert_eq(sp.pick_mode(), &"zip", "a crowd -> Zip")
	assert_true(sp.activate())
	assert_eq(sp.mode, &"zip")
	for i: int in 6:
		sp.update(0.5)
	assert_gte(sp.hops, 5, "hops every 0.45 s")
	var hit_count: int = 0
	for d: TestDummy in dummies:
		if d.total_damage() > 0.0:
			hit_count += 1
	assert_gte(hit_count, 3, "and spreads its bursts across the crowd")
	sp.end()
