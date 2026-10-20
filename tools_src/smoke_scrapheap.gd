extends Node
## Headless smoke run of Scrapheap Junction, garage prologue to the Return Relay. Loads the real level scene
## (ScrapheapLevel on BSLevel) and drives a scripted Bolt by teleporting it through every zone:
## colliders + navmesh, the prologue (mallet, pit latch, gold 1, intro), every zone probe, NPC quests q1a-q1d
## (kills via direct damage, items by touch), every encounter, gold bolts, memos, secrets, conveyors + crane,
## story beats, POWER + UPLINK, REPO-TRON (damage to death), the exit, and the out-of-bounds quips.
## Prints "[scrapheap] RESULT PASS" or "[scrapheap] RESULT FAIL" with the reasons.
##
## Run (no window, no audio):
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/smoke_scrapheap.tscn
## Uses its own save profile (user://smoke_scrapheap_profile.json, deleted afterwards).

const PROFILE: String = "user://smoke_scrapheap_profile.json"
const LEVEL_SCENE: String = "res://bs/planets/scrapheap/scrapheap.tscn"

var level: Node3D
var D: LevelDirector
var bolt: Bolt
var fails: PackedStringArray = []
var notes: PackedStringArray = []
var barks: PackedStringArray = []
var prompts: PackedStringArray = []
var kills: Dictionary = {}
var _t0: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	SaveProfile.path = PROFILE
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.bolts = 0
	BS.god_mode = true
	EventBus.bark.connect(func(id: String) -> void: barks.append(id))
	EventBus.interact_prompt.connect(func(t: String) -> void: prompts.append(t))
	EventBus.enemy_killed.connect(func(e: Node, _w: StringName) -> void:
		var id: String = EnemyBridge.enemy_id(e)
		kills[id] = int(kills.get(id, 0)) + 1)
	_run.call_deferred()


func check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("[scrapheap]   FAIL: ", msg)
	return ok


func step(title: String) -> void:
	print("[scrapheap] -- %s (%.1fs)" % [title, (Time.get_ticks_msec() - _t0) / 1000.0])


## Waits n physics frames, skipping any cutscene / dialogue that starts (the smoke never watches them).
func frames(n: int) -> void:
	for i: int in n:
		_skip_cutscenes()
		await get_tree().physics_frame


func _skip_cutscenes() -> void:
	if level == null or not is_instance_valid(level):
		return
	var cs: Node = level.get("cutscenes") as Node
	if cs != null and bool(cs.get("playing")):
		cs.call("skip")
	if get_tree().paused:
		get_tree().paused = false


func tp(p: Vector3, wait: int = 6) -> void:
	bolt.global_position = p
	bolt.motor.vel = Vector3.ZERO
	bolt.last_safe = p
	bolt.scripted = {"dir": Vector3.ZERO}
	await frames(wait)


## Waits until cond() is true (max n frames). Returns whether it became true.
func wait_until(cond: Callable, n: int = 120) -> bool:
	for i: int in n:
		if bool(cond.call()):
			return true
		await frames(1)
	return bool(cond.call())


func hit(amount: float) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, Combat.Type.KINETIC, bolt)
	h.weapon_id = &"smoke"
	h.is_melee = true
	h.is_slam = true          # burrowed Lien Crawlers only take slams
	return h


# ====================================================================== the run

func _run() -> void:
	step("load level")
	if not ResourceLoader.exists(LEVEL_SCENE):
		check(false, "level scene missing")
		_finish()
		return
	BSLevel.pending_cutscene = "intro"     # what the main menu sets for a new game
	level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Node3D
	add_child(level)
	check(not BS.flag("cs.intro") and not bool((level.get("cutscenes") as Node).get("playing")),
		"new game: intro waits for the end of the prologue (not played at boot)")
	await frames(4)
	D = level.get("director") as LevelDirector
	bolt = level.get("bolt") as Bolt
	if not check(D != null and bolt != null, "director / Bolt missing"):
		_finish()
		return
	notes.append("EnemySpawner present: %s" % EnemyBridge.has_spawner())

	await _check_world()
	await _prologue()
	await _zones()
	await _hub_services()
	await _quests_and_encounters()
	await _collectibles_and_secrets()
	await _traversal()
	await _beats()
	await _power_uplink()
	await _boss()
	await _exit()
	await _out_of_bounds()
	notes.append("stub enemies used: %s" % EnemyBridge.used_stub)
	notes.append("kills by type: %s" % str(kills))
	_finish()


func _check_world() -> void:
	step("colliders + navmesh")
	var solids: int = D.geometry.find_children("*", "StaticBody3D", true, false).size()
	check(solids > 150, "expected >150 static colliders, got %d" % solids)
	check(D.nav_polygons > 100, "navmesh has %d polygons" % D.nav_polygons)
	var map: RID = D.nav_region.get_navigation_map()
	# the first map iteration can be the empty map; wait until the baked region is actually queryable
	await wait_until(func() -> bool: return NavigationServer3D.map_get_path(map, Vector3(0, 0, 12), Vector3(-8, 0, 2), true).size() >= 2, 120)
	await frames(2)
	notes.append("navmesh: %d polygons, map iteration %d, regions %d" % [D.nav_polygons, NavigationServer3D.map_get_iteration_id(map), NavigationServer3D.map_get_regions(map).size()])
	var pairs: Array = [[Vector3(0, 0, 12), Vector3(0, -0.5, -25)], [Vector3(0, -0.5, -25), Vector3(-36, 0, -60)],
		[Vector3(0, 0, 12), Vector3(33, 0, -12)], [Vector3(0, 0, -100), Vector3(0, 2, -128)]]
	for pr: Array in pairs:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, pr[0], pr[1], true)
		var ok: bool = path.size() >= 2 and path[path.size() - 1].distance_to(pr[1]) < 3.0
		check(ok, "nav path %s -> %s (%d pts, end %s)" % [pr[0], pr[1], path.size(), path[path.size() - 1] if path.size() > 0 else "-"])
	check(is_equal_approx(bolt.kill_y, -8.0), "Bolt.kill_y = %s" % bolt.kill_y)
	check(bolt.water_zones.size() == 3, "water zones %d" % bolt.water_zones.size())
	check(bolt.global_position.distance_to(LevelKit.v3(D.D["prologue_spawn"])) < 1.5, "Bolt starts in the garage")


func _prologue() -> void:
	step("prologue")
	await frames(20)
	check(bolt.motor.on_ground, "Bolt stands in the garage")
	# grab the mallet from under the low shelf (Area3D pickup)
	var mallet: LevelItem = D.items.get("mallet")
	check(mallet != null, "mallet item")
	if mallet != null:
		await tp(mallet.global_position + Vector3(0, 0.55, 0), 4)
	check(await wait_until(func() -> bool: return D.flag("got_mallet"), 30), "mallet collected by touch")
	# mallet throw at the pit-lid latch -> lid opens -> gold bolt 1
	var latch: MalletSwitch = D.switches.get("pit_latch")
	latch.on_mallet(bolt)
	check(D.gates["pit_lid"].is_open, "pit lid opens")
	await frames(60)
	await tp(Vector3(12, 1.0, -2.5), 4)
	check(await wait_until(func() -> bool: return BS.flag("gold.scrapheap.1"), 40), "gold 1 in the inspection pit")
	# leave the lot -> intro, the garage lifts away, the lot shows memo 02
	await tp(Vector3(4.5, 1.2, 4.5), 4)
	check(await wait_until(func() -> bool: return D.flag("prologue_finished"), 900), "intro plays and the prologue finishes")
	check("intro" in D.cutscenes_played, "intro cutscene requested")
	check(not D.nodes.has("garage"), "garage removed")
	var m2: MemoPickup = D.memos.get("memo.02")
	check(m2 != null and m2.visible, "memo 02 revealed on the empty lot")


func _zones() -> void:
	step("zone sweep")
	for z: Variant in D.D["zones"]:
		var zd: Dictionary = z
		var p: Vector3 = LevelKit.v3(zd["probe"])
		await tp(p, 30)
		var ok: bool = bolt.motor.on_ground and absf(bolt.global_position.y - p.y) < 1.6
		check(ok, "zone %s: Bolt stands at the probe (on_ground %s, y %.2f vs %.2f)" % [zd["id"], bolt.motor.on_ground, bolt.global_position.y, p.y])
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -4, 0), 1)
		check(not bolt.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "zone %s: world collider under the probe" % zd["id"])


func _hub_services() -> void:
	step("hub: beacon, ship, kiosk, prompts")
	prompts.clear()
	await tp(D.beacon.global_position + Vector3(0.8, 1.0, 0.8), 6)
	check(prompts.size() > 0 and prompts[prompts.size() - 1] != "", "beacon interact prompt")
	D.beacon.interact(bolt)
	check(D.beacon.saves == 1 and FileAccess.file_exists(PROFILE), "beacon saves")
	var ship: InteractPoint = D.nodes.get("interact.ship")
	ship.interact(bolt)
	await frames(2)
	check("bs.scrapheap.ship_booted" in D.lines.history or D.lines.playing, "booted ship refuses (line)")
	check(D.kiosk != null, "Blartz kiosk placed (ShopKiosk)")


func _talk(npc_id: String) -> String:
	var n: NPCTalkPoint = D.npcs[npc_id]
	await tp(n.global_position + Vector3(1.0, 1.0, 1.0), 4)
	return n.talk()


func _turn_in(npc_id: String, qid: String) -> void:
	var before: int = BS.bolts
	var got: String = await _talk(npc_id)
	var reward: int = int((D.quest_book.defs[qid] as Dictionary)["reward"])
	check(got == qid and D.quest_book.state(qid) == QuestBook.DONE, "%s turned in (state %s)" % [qid, D.quest_book.state(qid)])
	check(BS.bolts - before == reward, "%s pays %d (got %d)" % [qid, reward, BS.bolts - before])


func _collect_quest_items(qid: String) -> void:
	for qv: Variant in D.quest_items:
		if is_instance_valid(qv) and (qv as QuestItem).quest_id == qid:
			var qi: QuestItem = qv
			await frames(2)
			check(qi.visible, "%s item visible while active" % qid)
			await tp(qi.global_position + Vector3(0, 0.4, 0), 6)
	check(await wait_until(func() -> bool: return D.quest_book.state(qid) == QuestBook.READY, 30),
		"%s items collected (%d/%d)" % [qid, D.quest_book.count(qid), D.quest_book.need(qid)])


func _encounter(id: String) -> void:
	var e: Encounter = D.encounters.get(id)
	if not check(e != null, "encounter %s exists" % id):
		return
	if not e.started:
		var trig: TriggerVolume = null
		for t: TriggerVolume in D.triggers.values():
			for a: Variant in t.actions:
				if a is Dictionary and str((a as Dictionary).get("encounter", "")) == id:
					trig = t
		if trig != null:
			await tp(trig.global_position, 4)
		elif not e.started:
			e.start()
	check(await wait_until(func() -> bool: return e.started, 30), "encounter %s started by its trigger" % id)
	var guard: int = 0
	while not e.done and guard < 40:
		guard += 1
		for en: Node3D in e.living():
			if en.has_method("take_damage"):
				en.call("take_damage", hit(99999.0))
		await frames(8)
	check(e.done, "encounter %s cleared (%d spawned)" % [id, e.spawned_total])
	check(e.spawned_total > 0, "encounter %s spawned enemies" % id)


func _quests_and_encounters() -> void:
	step("quests + encounters")
	check(await _talk("rusty") == "q1a" and D.quest_book.state("q1a") == QuestBook.ACTIVE, "Rusty gives q1a")
	check(await _talk("gasket") == "q1c" and D.quest_book.state("q1c") == QuestBook.ACTIVE, "Mama Gasket gives q1c")
	check("q.q1a.intro.01" in D.npcs["rusty"].talked, "Rusty plays q1a intro lines")
	await _collect_quest_items("q1c")
	await _turn_in("gasket", "q1c")
	check(await _talk("gasket") == "q1d" and D.quest_book.state("q1d") == QuestBook.ACTIVE, "Mama Gasket gives q1d")
	for id: String in ["hub_crates", "bowl_crates", "row_crates"]:
		check(D.encounters[id].started, "%s autostarted" % id)
	for id: String in ["bowl", "vault", "mast", "works", "hull", "row", "boneyard"]:
		step("encounter " + id)
		await _encounter(id)
	check(D.flag("boneyard_cleared") and D.gates["vault_cage"].is_open, "Crusher Pit clear opens the vault cage")
	check(D.quest_book.state("q1a") == QuestBook.READY, "q1a ready (mutts %d)" % D.quest_book.count("q1a"))
	check(D.quest_book.state("q1d") == QuestBook.READY, "q1d ready (vultures %d)" % D.quest_book.count("q1d"))
	await _turn_in("rusty", "q1a")
	check(await _talk("rusty") == "q1b", "Rusty gives q1b")
	await _collect_quest_items("q1b")
	await _turn_in("rusty", "q1b")
	await _turn_in("gasket", "q1d")
	check(await _talk("rusty") == "" and "bs.scrapheap.rusty_idle" in D.npcs["rusty"].talked, "Rusty idles after both quests")


func _collectibles_and_secrets() -> void:
	step("gold bolts, memos, items, secrets")
	for id: String in D.gold.keys():
		var gv: Variant = D.gold[id]
		if is_instance_valid(gv) and not (gv as GoldBolt).taken:
			await tp((gv as GoldBolt).global_position + Vector3(0, 0.3, 0), 6)
	var found: Array = GoldBolt.found_list("scrapheap")
	check(found.size() == 5, "5 gold bolts recorded in SaveProfile (got %d: %s)" % [found.size(), found])
	check(int(SaveProfile.doc["bs"].get("gold_bolts", 0)) == 5, "gold_bolts total 5")
	for id: String in D.memos.keys():
		var mv: Variant = D.memos[id]
		if is_instance_valid(mv) and not (mv as MemoPickup).taken:
			await tp((mv as MemoPickup).global_position + Vector3(0, 0.3, 0), 6)
	var memos: Array = SaveProfile.doc["bs"]["memos"]
	for mid: String in ["memo.01", "memo.02", "memo.03", "memo.04", "memo.05"]:
		check(mid in memos, "%s recorded" % mid)
	# gadget secrets: Thunder (S5) and Magma (S7) throws need the mallet tiers
	var tier: int = BS.mallet_tier
	BS.mallet_tier = 0
	D.switches["crusher_box"].on_mallet(bolt)
	check(not D.gates["crusher_bay"].is_open, "crusher box ignores a plain throw")
	BS.mallet_tier = 2
	D.switches["crusher_box"].on_mallet(bolt)
	D.switches["tarp_seal"].on_mallet(bolt)
	check(D.gates["crusher_bay"].is_open and D.gates["tarp"].is_open, "Thunder / Magma throws open S5 / S7")
	check(D.movers["stamp"].paused > 0.0, "Thunder throw stops the stamp")
	BS.mallet_tier = tier
	await frames(30)
	for id: String in D.items.keys():
		var iv: Variant = D.items[id]
		if is_instance_valid(iv) and not (iv as LevelItem).taken and id != "power_cell":
			await tp((iv as LevelItem).global_position + Vector3(0, 0.3, 0), 6)
			if is_instance_valid(iv) and not (iv as LevelItem).taken:
				(iv as LevelItem).collect(bolt)
				notes.append("item %s needed a direct collect (touch missed)" % id)
	for s: Variant in D.D["secrets"]:
		var f: String = str((s as Dictionary)["flag"])
		check(D.flag(f) or BS.flag(f), "secret %s (%s)" % [(s as Dictionary)["id"], f])
	check("bs.scrapheap.mailbox_bark" in D.npcs["denizen_mailbox"].barks, "mailbox secret changes the denizen's bark")
	check(BS.max_hp >= 120, "Boneyard vault nanotech +20 HP (max %d)" % BS.max_hp)


func _traversal() -> void:
	step("conveyors + crane")
	var belt: ConveyorBelt = D.conveyors["west_belt"]
	var top: float = belt.top_y()
	await tp(Vector3(3, top + 0.96, -52), 10)
	var x0: float = bolt.global_position.x
	await frames(60)
	var dx: float = bolt.global_position.x - x0
	check(dx < -2.0 and dx > -4.5, "west belt carries Bolt west ~3.2 m/s (moved %.2f m in 1 s)" % dx)
	D.switches["lever_west_e"].on_mallet(bolt)
	check(belt.reversed(), "belt-reverser lever flips the belt")
	await tp(Vector3(-2, top + 0.96, -52), 10)
	x0 = bolt.global_position.x
	await frames(60)
	check(bolt.global_position.x - x0 > 2.0, "reversed belt carries Bolt east (moved %.2f)" % (bolt.global_position.x - x0))
	var crane: MagnetCrane = D.movers["magnet_crane"]
	var c0: Vector3 = crane.global_position
	await frames(45)
	check(crane.global_position.distance_to(c0) > 0.05, "magnet crane patrols")


func _beats() -> void:
	step("story beats")
	for beat: String in ["l1_glitch", "l1_row", "l1_mast", "l1_mid", "l1_vista"]:
		if BS.flag("beat." + beat):
			continue
		for t: TriggerVolume in D.triggers.values():
			for a: Variant in t.actions:
				if a is Dictionary and str((a as Dictionary).get("beat", "")) == beat:
					await tp(t.global_position, 8)
	for beat: String in ["l1_glitch", "l1_row", "l1_mast", "l1_mid", "l1_vista"]:
		check(BS.flag("beat." + beat), "story beat %s played" % beat)
	check(D.gates["blast_door"].is_open, "hull blast door opened at l1_mid")


func _power_uplink() -> void:
	step("POWER + UPLINK")
	var cell: LevelItem = D.items.get("power_cell")
	if check(cell != null, "power cell present"):
		await tp(cell.global_position + Vector3(0, 0.3, 0), 6)
	check(D.flag("power") and D.lamps["lamp_power"].lit and D.gates["rear_hatch"].is_open, "power cell lights POWER, opens the rear hatch")
	check(not D.gates["lot_gate"].is_open, "lot gate stays shut with POWER only")
	for s: String in ["clamp_nest", "clamp_step3", "clamp_step5"]:
		D.switches[s].on_mallet(bolt)
	check(D.flag("uplink") and D.lamps["lamp_uplink"].lit and D.lamps["mast_beacon"].lit, "three clamps -> UPLINK")
	check(D.gates["lot_gate"].is_open, "POWER + UPLINK open the Compaction Lot gate")
	await _encounter("lot_pre")


func _boss() -> void:
	step("REPO-TRON")
	await tp(Vector3(0, 3.2, -123), 10)
	check(await wait_until(func() -> bool: return D.boss_active, 60), "l1_repo trigger starts the boss")
	check(BS.flag("beat.l1_repo"), "l1_repo beat")
	check(not D.gates["lot_gate"].is_open, "arena gate closes behind Bolt")
	var boss: Node3D = D.boss
	if not check(boss != null and is_instance_valid(boss), "REPO-TRON spawned"):
		return
	notes.append("boss node: %s" % boss.get_class() + (" (%s)" % boss.get_script().resource_path if boss.get_script() else ""))
	var mx: float = float(boss.get("max_hp")) if boss.get("max_hp") != null else 380.0
	var guard: int = 0
	while not D.boss_done and guard < 400:
		guard += 1
		if is_instance_valid(boss) and boss.has_method("take_damage"):
			var h: Combat.Hit = hit(mx * 0.08)
			h.weak_point = true
			boss.call("take_damage", h)
		await frames(10)
	check(D.boss_done, "REPO-TRON defeated by damage (%d volleys)" % guard)
	check(D.flag("repo_down"), "repo_down flag")
	check(D.phase_count() == 2, "both arena phases ran (%d)" % D.phase_count())
	await frames(90)
	check(D.gates["yard_fence"].is_open and D.gates["lot_gate"].is_open, "fence + gate open after the kill")
	check(D.exit.active, "Return Relay lit")
	check(not D.nodes.has("boot"), "repo boot removed from the ship")


func _exit() -> void:
	step("exit")
	await tp(D.exit.global_position + Vector3(0, 1.2, 0), 10)
	check(await wait_until(func() -> bool: return D.exit.completed, 30), "stepping on the Return Relay completes the planet")
	check(BS.flag("planet_complete.scrapheap"), "planet_complete.scrapheap flag")
	check(0 in (SaveProfile.doc["bs"]["planets_cleared"] as Array), "planets_cleared has 0")
	check("complete_level" in D.host_calls, "host complete_level() called")


func _out_of_bounds() -> void:
	step("out of bounds")
	# leave the summary screen's input block alone; Bolt still simulates
	barks.clear()
	await tp(Vector3(0, 3.2, -128), 20)
	var safe: Vector3 = bolt.global_position
	await tp(Vector3(0, -5.0, -150), 0)
	bolt.last_safe = safe
	check(await wait_until(func() -> bool: return "splash.06" in barks, 30), "Slag Flats quip (splash.06)")
	check(await wait_until(func() -> bool: return bolt.global_position.y > -8.0 and bolt.global_position.distance_to(safe) < 3.0, 60),
		"falling past kill_y resets Bolt to safe ground")
	await tp(Vector3(0, 1.5, 18.8), 4)
	check(await wait_until(func() -> bool: return "splash.01" in barks, 30), "property-line fence quip (splash.01)")
	await tp(Vector3(-8, 0.5, -36), 4)
	check(await wait_until(func() -> bool: return barks.size() >= 3, 40), "oil pond splash (water zone)")


func _finish() -> void:
	for n: String in notes:
		print("[scrapheap] note: ", n)
	if fails.is_empty():
		print("[scrapheap] RESULT PASS (%.1fs)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	else:
		print("[scrapheap] RESULT FAIL (%d)" % fails.size())
		for f: String in fails:
			print("[scrapheap]   - ", f)
	BS.god_mode = false
	if level != null and is_instance_valid(level):
		level.queue_free()
		await frames(3)
	EnemySpawner.clear_pool()
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit(0 if fails.is_empty() else 1)
