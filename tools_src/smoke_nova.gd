extends Node
## Headless smoke run of Nova Plaza, landing to the Return Relay. Loads the real level scene (NovaPlazaLevel on
## BSLevel) and drives a scripted Bolt through it: colliders + navmesh, every zone probe, the hub services,
## the walkways and the HOA violation system (a real Eye sees a sprint; flash -> reverse -> cooldown; a
## blinded Eye), the ventilation updraft, the HOA Variance (the three clubhouse rules in front of the three
## Eyes) and the Permit to Approach (take a number, then the counter), the Squatter's quests q4a / q4b,
## every encounter, gold bolts, memos, secrets, story beats, the Transit Loop ride (Bolt carried by the car
## to the FineTree deck, novaLate on the way), novaIntro, The Algorithm (spawned with opts["arena"]; a TestDummy
## stand-in if the id is missing; damage to death), a complaint canister fed into an intake slot, the
## Keystone Core, the exit and the out-of-bounds quips.
## Prints "[nova] RESULT PASS" or "[nova] RESULT FAIL" with the reasons.
##
## Run (no window, no audio):
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/smoke_nova.tscn
## Screenshot tour instead (rendered, silent, off-screen; every audio bus muted; never captures the mouse):
##   Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://tools_src/smoke_nova.tscn -- --shots --out=C:/dir
## Uses its own save profile (user://smoke_nova_profile.json, deleted afterwards).

const PROFILE: String = "user://smoke_nova_profile.json"
const LEVEL_SCENE: String = "res://bs/planets/nova_plaza/nova_plaza.tscn"
const CW: int = 400
const CH: int = 225
const COLS: int = 4

var level: NovaPlazaLevel
var D: LevelDirector
var NB: NovaBuilder
var bolt: Bolt
var fails: PackedStringArray = []
var notes: PackedStringArray = []
var barks: PackedStringArray = []
var prompts: PackedStringArray = []
var kills: Dictionary = {}
var _t0: int = 0
var _shots: bool = false
var _out: String = "user://shots"
var _sheet: Image
var _n: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a == "--shots":
			_shots = true
		elif a.begins_with("--out="):
			_out = a.substr(6)
	for i: int in AudioServer.bus_count:
		AudioServer.set_bus_mute(i, true)
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
	if _shots:
		_tour.call_deferred()
	else:
		_run.call_deferred()


func check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("[nova]   FAIL: ", msg)
	return ok


func step(title: String) -> void:
	print("[nova] -- %s (%.1fs)" % [title, (Time.get_ticks_msec() - _t0) / 1000.0])


## Waits n physics frames, skipping any cutscene that starts (the smoke never watches them).
func frames(n: int) -> void:
	for i: int in n:
		_skip_cutscenes()
		await get_tree().physics_frame


func _skip_cutscenes() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if level == null or not is_instance_valid(level):
		return
	var cs: CutscenePlayer = level.cutscenes
	if cs != null and cs.playing and not cs.is_dialogue:
		cs.skip()
	elif cs != null and cs.playing and cs.is_dialogue:
		cs.advance()
	if get_tree().paused:
		get_tree().paused = false


func tp(p: Vector3, wait: int = 6) -> void:
	bolt.global_position = p
	bolt.motor.vel = Vector3.ZERO
	bolt.last_safe = p
	bolt.scripted = {"dir": Vector3.ZERO}
	await frames(wait)


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
	h.is_slam = true
	return h


func _load_level() -> bool:
	if not ResourceLoader.exists(LEVEL_SCENE):
		check(false, "level scene missing")
		return false
	BSLevel.pending_cutscene = ""
	var ps: PackedScene = load(LEVEL_SCENE) as PackedScene
	level = ps.instantiate() as NovaPlazaLevel if ps != null else null
	if not check(level != null, "level scene failed to load / instantiate (script error?)"):
		return false
	add_child(level)
	await frames(4)
	D = level.director
	NB = level.nova
	bolt = level.bolt
	return check(D != null and bolt != null and NB != null, "director / Bolt / NovaBuilder missing")


# ====================================================================== the run

func _run() -> void:
	step("load level")
	if not await _load_level():
		_finish()
		return
	notes.append("EnemySpawner present: %s" % EnemyBridge.has_spawner())
	check("flyover5" in D.cutscenes_played or BS.flag("cs.flyover5"), "first landing plays flyover5")
	await _check_world()
	await _zones()
	await _hub_services()
	await _walkways_and_hoa()
	await _updraft()
	await _variance()
	await _permit()
	await _quests_and_encounters()
	await _collectibles_and_secrets()
	await _beats()
	await _train()
	await _boss()
	await _core_and_exit()
	await _out_of_bounds()
	notes.append("stub enemies used: %s %s" % [EnemyBridge.used_stub, str(NovaSpawn.stubbed)])
	notes.append("kills by type: %s" % str(kills))
	_finish()


func _check_world() -> void:
	step("colliders + navmesh")
	var solids: int = D.geometry.find_children("*", "StaticBody3D", true, false).size()
	check(solids > 300, "expected >300 static colliders, got %d" % solids)
	notes.append("static colliders: %d" % solids)
	check(D.nav_polygons > 200, "navmesh has %d polygons" % D.nav_polygons)
	var map: RID = D.nav_region.get_navigation_map()
	await wait_until(func() -> bool: return NavigationServer3D.map_get_path(map, Vector3(0, 0, 14), Vector3(0, 0, 0), true).size() >= 2, 180)
	await frames(2)
	notes.append("navmesh: %d polygons" % D.nav_polygons)
	var pairs: Array = [[Vector3(0, 0, 14), Vector3(4, 4.5, -26)], [Vector3(4, 4.5, -26), Vector3(-30, 6, -52)],
		[Vector3(0, 0, 14), Vector3(30, 3, -36)], [Vector3(-30, 6, -52), Vector3(-30, 9, -62)], [Vector3(0, 0, 14), Vector3(-94, 0.5, -12)],
		[Vector3(-3, 6, -94), Vector3(0, 6, -108)]]
	for pr: Array in pairs:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, pr[0], pr[1], true)
		var ok: bool = path.size() >= 2 and path[path.size() - 1].distance_to(pr[1]) < 3.0
		check(ok, "nav path %s -> %s (%d pts, end %s)" % [pr[0], pr[1], path.size(), path[path.size() - 1] if path.size() > 0 else "-"])
	check(is_equal_approx(bolt.kill_y, -10.0), "Bolt.kill_y = %s" % bolt.kill_y)
	check(bolt.water_zones.size() == 1, "water zones %d" % bolt.water_zones.size())
	check(bolt.global_position.distance_to(LevelKit.v3(D.D["spawn"])) < 1.5, "Bolt starts at the hub spawn")
	check(get_tree().get_nodes_in_group(&"tether_points").size() >= 20, "tether points placed (%d)" % get_tree().get_nodes_in_group(&"tether_points").size())
	check(get_tree().get_nodes_in_group(&"nova_walkways").size() == 9, "9 walkways (%d)" % get_tree().get_nodes_in_group(&"nova_walkways").size())
	check(NB.eyes.size() >= 10 and NB.train != null and NB.arena != null and NB.core != null, "Eyes / train / arena / core built")


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
	step("hub: beacon, ship, kiosk, vending")
	prompts.clear()
	await tp(D.beacon.global_position + Vector3(0.8, 1.0, 0.8), 6)
	check(prompts.size() > 0 and prompts[prompts.size() - 1] != "", "beacon interact prompt")
	D.beacon.interact(bolt)
	check(D.beacon.saves == 1 and FileAccess.file_exists(PROFILE), "beacon saves")
	(D.nodes["interact.ship"] as InteractPoint).interact(bolt)
	check("open_star_map" in D.host_calls, "ship opens the star map (host call)")
	(D.nodes["interact.vending"] as InteractPoint).interact(bolt)
	await frames(2)
	check("code.populateLife.16" in D.lines.history or D.lines.playing, "vending machine plays the Squatter's line")
	check(D.kiosk != null, "Blartz kiosk placed (ShopKiosk)")
	check(D.exit != null and not D.exit.active, "Return Relay dark until the core")


func _ride(w: NovaWalkway, secs: int = 60) -> float:
	var mid: Vector3 = w.global_transform.origin + Vector3(0, 1.2, 0)
	await tp(mid, 12)
	var p0: Vector3 = bolt.global_position
	await frames(secs)
	var d: Vector3 = bolt.global_position - p0
	var along: Vector3 = (w.to - w.from).normalized()
	return d.dot(along)


func _walkways_and_hoa() -> void:
	step("walkways + the HOA violation system")
	var w: NovaWalkway = NB.walkways["civic_w"]
	var moved: float = await _ride(w)
	check(moved > 1.2, "civic ramp walkway carries Bolt up (%.2f m in 1 s)" % moved)
	var C: HOACompliance = NB.compliance
	# a real Eye sees a sprint up the ramp: Bolt sprints toward the eye's look point
	var eye: ComplianceEye = NB.eyes["civic_eye_w"]
	await tp(Vector3(-8, 1.4, -8), 4)
	bolt.scripted = {"dir": Vector3(0, 0, -1), "sprint": true}
	check(await wait_until(func() -> bool: return "civic:sprint" in C.history, 90), "civic Eye logs Bolt sprinting in its cone (%s)" % str(C.history))
	bolt.scripted = {"dir": Vector3.ZERO}
	check(C.state("civic") == HOACompliance.FLASH, "district flashes first (state %d)" % C.state("civic"))
	check((NB.lamp_posts["civic_l1"] as NovaLampPost).flashing(), "civic lamp posts flash red")
	check(not w.is_reversed(), "walkways not reversed during the 1.0 s flash")
	await frames(66)
	check(w.is_reversed() and (NB.walkways["civic_e"] as NovaWalkway).is_reversed(), "both civic walkways reverse after the flash")
	check(not (NB.walkways["hall_1"] as NovaWalkway).is_reversed(), "other districts' walkways unaffected")
	moved = await _ride(w)
	check(moved < -0.8, "reversed walkway carries Bolt down (%.2f m)" % moved)
	await frames(330)
	check(C.state("civic") == HOACompliance.COOLDOWN and not w.is_reversed(), "6 s reversal ends in the 8 s cooldown (state %d)" % C.state("civic"))
	check(not C.log_violation("civic", "fight"), "no new reversal during the cooldown")
	await frames(490)
	check(C.state("civic") == HOACompliance.IDLE, "district idle after the cooldown")
	eye.on_mallet(bolt)
	check(eye.is_blind() and not eye.sees(bolt.global_position), "a mallet throw blinds the Eye (%.0f s)" % eye.blind_t)
	check("bs.nova.pa_violation_sprint" in barks, "PA violation bark")


func _updraft() -> void:
	step("ventilation updraft")
	var u: NovaUpdraft = NB.updrafts["permit_vent"]
	await tp(u.global_position + Vector3(0, 1.2, 0), 2)
	var y0: float = bolt.global_position.y
	await frames(50)
	check(bolt.global_position.y - y0 > 3.0, "updraft lifts Bolt (%.2f m)" % (bolt.global_position.y - y0))


func _variance() -> void:
	step("HOA Variance: three rules in front of three Eyes")
	var stamp: LevelItem = D.items.get("variance_stamp")
	check(stamp != null and not stamp.visible, "variance stamp hidden before the rules")
	var lawn: Vector3 = Vector3(-30, 10.2, -62.5)
	await tp(lawn, 6)
	bolt.scripted = {"dir": Vector3(0, 0, -1), "sprint": true}
	check(await wait_until(func() -> bool: return D.flag("rule_run"), 40), "RULE 1: sprinting in front of eye_run")
	await tp(lawn, 4)
	bolt.melee.swung.emit("smoke")
	check(await wait_until(func() -> bool: return D.flag("rule_horseplay"), 20), "RULE 2: a mallet swing in front of eye_horseplay")
	await tp(lawn, 8)
	bolt.scripted = {"dir": Vector3.ZERO, "jump_pressed": true, "jump_held": true}
	check(await wait_until(func() -> bool: return D.flag("rule_lawn"), 30), "RULE 3: a jump in front of eye_lawn")
	bolt.scripted = {"dir": Vector3.ZERO}
	check(D.flag("rules_done") and stamp != null and is_instance_valid(stamp) and stamp.visible, "found in contravention: the stamp appears")
	if stamp != null and is_instance_valid(stamp):
		await tp(stamp.global_position + Vector3(0, 0.3, 0), 8)
	check(D.flag("variance") and D.lamps["lamp_variance"].lit, "HOA Variance taken, the gate lamp lights")
	check(not D.gates["finetree_gate"].is_open, "one stamp is not enough")


func _permit() -> void:
	step("Permit to Approach: take a number, reach the counter")
	var counter: InteractPoint = D.nodes["interact.permit_counter"]
	counter.interact(bolt)
	check(not D.flag("permit"), "no permit without a number")
	(D.nodes["interact.take_number"] as InteractPoint).interact(bolt)
	check(D.flag("took_number") and D.encounters["permit_hall"].started, "number taken; the hall's enforcement wakes up")
	counter.interact(bolt)
	check(D.flag("permit") and D.lamps["lamp_permit"].lit, "permit issued at the counter")
	check(D.flag("variance") and D.gates["finetree_gate"].is_open and D.lamps["lamp_train"].lit, "both stamps: FineTree gate + train lamp")
	check("nova_stamps" in D.cutscenes_played, "stamps cutscene (level data) requested")
	check("bs.nova.obj_train" in level.objectives, "objective moves to the Nova Loop")
	await frames(10)


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


func _damage_all(e: Node3D) -> void:
	if e.has_method("take_damage"):
		e.call("take_damage", hit(99999.0))
		return
	for p: Variant in (e.get("pylons") if e.get("pylons") != null else []):
		if is_instance_valid(p) and (p as Node).has_method("take_damage"):
			(p as Node).call("take_damage", hit(99999.0))
	for c: Node in e.find_children("*", "", true, false):
		if c.is_in_group(&"damageable") and c.has_method("take_damage") and c.has_method("is_alive") and bool(c.call("is_alive")):
			c.call("take_damage", hit(99999.0))


func _encounter(id: String) -> void:
	var e: Encounter = D.encounters.get(id)
	if not check(e != null, "encounter %s exists" % id):
		return
	if not e.started:
		var trig: TriggerVolume = null
		for t: TriggerVolume in D.triggers.values():
			for a: Variant in t.actions:
				if a is Dictionary and str((a as Dictionary).get("encounter", "")) == id and t.armed():
					trig = t
		if trig != null:
			await tp(trig.global_position, 4)
		if not e.started:
			e.start()
	check(await wait_until(func() -> bool: return e.started, 30), "encounter %s started" % id)
	var guard: int = 0
	while not e.done and guard < 60:
		guard += 1
		for en: Node3D in e.living():
			_damage_all(en)
		await frames(10)
	check(e.done, "encounter %s cleared (%d spawned)" % [id, e.spawned_total])
	check(e.spawned_total > 0, "encounter %s spawned enemies" % id)


func _quests_and_encounters() -> void:
	step("quests + encounters")
	check(await _talk("squatter") == "q4a" and D.quest_book.state("q4a") == QuestBook.ACTIVE, "The Squatter gives q4a")
	check("q.q4a.intro.01" in D.npcs["squatter"].talked, "q4a intro lines")
	for id: String in ["hub_crates", "civic_crates"]:
		check(D.encounters[id].started, "%s autostarted" % id)
	for id: String in ["hub", "civic", "hoa_streets", "hoa_lawn", "underpass", "permit_hall", "permit_records"]:
		step("encounter " + id)
		await _encounter(id)
	check(D.flag("underpass_cleared") and D.gates["vault_cage"].is_open, "the Underpass plaza clear opens the vault cage")
	check(D.quest_book.state("q4a") == QuestBook.READY, "q4a ready (meter maids %d)" % D.quest_book.count("q4a"))
	await _turn_in("squatter", "q4a")
	check(await _talk("squatter") == "q4b", "The Squatter gives q4b")
	await _collect_quest_items("q4b")
	await _turn_in("squatter", "q4b")
	check(await _talk("squatter") == "" and "code.populateLife.15" in D.npcs["squatter"].talked, "The Squatter idles (GRANDFATHERED) after both quests")
	# the Tow Zone pop-up waits for GLAMBOT's defection (Rustvane)
	BS.set_flag("beat.l2_glambot")
	await _encounter("tow_zone")
	check(D.flag("tow_zone_done"), "Tow Zone pays out")


func _collectibles_and_secrets() -> void:
	step("gold bolts, memos, items, secrets")
	for id: String in D.gold.keys():
		var gv: Variant = D.gold[id]
		if is_instance_valid(gv) and not (gv as GoldBolt).taken:
			await tp((gv as GoldBolt).global_position + Vector3(0, 0.3, 0), 6)
	var found: Array = GoldBolt.found_list("nova_plaza")
	check(found.size() == 4, "4 gold bolts recorded (got %d: %s)" % [found.size(), found])
	for id: String in D.memos.keys():
		var mv: Variant = D.memos[id]
		if is_instance_valid(mv) and not (mv as MemoPickup).taken:
			await tp((mv as MemoPickup).global_position + Vector3(0, 0.3, 0), 6)
	var memos: Array = SaveProfile.doc["bs"]["memos"]
	for mid: String in ["memo.16", "memo.17", "memo.18", "memo.19", "memo.20", "memo.38"]:
		check(mid in memos, "%s recorded" % mid)
	var tier: int = BS.mallet_tier
	BS.mallet_tier = 0
	D.switches["fuse_box"].on_mallet(bolt)
	D.switches["pump_seal"].on_mallet(bolt)
	check(not D.flag("secret_S6") and not D.gates["pump_hatch"].is_open, "Thunder / Magma targets ignore a plain throw")
	BS.mallet_tier = 2
	var b0: int = BS.bolts
	D.switches["fuse_box"].on_mallet(bolt)
	D.switches["pump_seal"].on_mallet(bolt)
	check(D.flag("secret_S6") and BS.bolts - b0 == 120, "Thunder throw reboots resident rewards (120 bolts)")
	check(D.gates["pump_hatch"].is_open, "Magma throw opens the pump-room hatch")
	BS.mallet_tier = tier
	await frames(30)
	for id: String in D.items.keys():
		var iv: Variant = D.items[id]
		if is_instance_valid(iv) and not (iv as LevelItem).taken:
			await tp((iv as LevelItem).global_position + Vector3(0, 0.3, 0), 6)
			if is_instance_valid(iv) and not (iv as LevelItem).taken:
				(iv as LevelItem).collect(bolt)
				notes.append("item %s needed a direct collect (touch missed)" % id)
	for s: Variant in D.D["secrets"]:
		var f: String = str((s as Dictionary)["flag"])
		check(D.flag(f) or BS.flag(f), "secret %s (%s)" % [(s as Dictionary)["id"], f])
	await frames(4)
	var cushion: Node3D = D.nodes.get("bench_cushion") as Node3D
	check(cushion != null and cushion.visible, "S7 puts the spare cushion on the Squatter's bench")
	check(BS.max_hp >= 120, "Underpass vault nanotech +20 HP (max %d)" % BS.max_hp)


func _beats() -> void:
	step("story beats")
	for beat: String in ["novaMid", "novaHolo"]:
		if BS.flag("beat." + beat):
			continue
		for t: TriggerVolume in D.triggers.values():
			for a: Variant in t.actions:
				if a is Dictionary and str((a as Dictionary).get("beat", "")) == beat:
					await tp(t.global_position, 8)
	for beat: String in ["novaMid", "novaHolo"]:
		check(BS.flag("beat." + beat), "story beat %s played" % beat)


func _train() -> void:
	step("Transit Loop: Civic Center -> FineTree deck")
	var t: NovaTrain = NB.train
	check(t.station == "civic" and not t.moving, "the car waits at the Civic Center station")
	await tp(Vector3(-10.5, 13.2, -20.2), 10)
	(D.nodes["interact.board_civic"] as InteractPoint).interact(bolt)
	check(t.moving, "boarding starts the ride")
	check(await wait_until(func() -> bool: return not t.moving, 1500), "the car arrives (%.1f s)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	await frames(10)
	check(t.station == "finetree", "parked at the FineTree station (%s)" % t.station)
	var loc: Vector3 = t.global_transform.affine_inverse() * bolt.global_position
	notes.append("Bolt in the car at local %s" % loc)
	check(absf(loc.x) < t.car_width * 0.5 + 0.2 and absf(loc.z) < t.car_length * 0.5 and loc.y > 0.0 and loc.y < 2.5,
		"Bolt rode the car to the deck (car-local %s)" % loc)
	check(BS.flag("beat.novaLate"), "novaLate plays riding past the FineTree screen")
	check(D.encounters["loop"].started, "Surge Drones swarm the loop")
	await _encounter("loop")
	await _encounter("loop_station")
	await tp(Vector3(-1, 13.2, -86), 10)
	check(await wait_until(func() -> bool: return BS.flag("cs.novaIntro"), 60), "novaIntro (deck camera, level data) on the FineTree deck")
	check(level.level_cutscene("novaIntro").size() > 0, "novaIntro comes from the level's cutscene table")


func _boss() -> void:
	step("The Algorithm")
	var arena: FineTreeArena = NB.arena
	for nm: String in ["ServerWall", "SlotLow", "SlotMid", "SlotHigh", "BossSpawn", "Core", "FineTree", "Center", "Kiosks", "ComplaintKiosks",
			"Walkways", "Doomscroll", "EscapePlatforms", "AddPads", "FineLanes", "LampPosts", "Deck"]:
		check(arena.get_node_or_null(nm) != null, "arena anchor %s" % nm)
	check(arena.find_child("SpawnPad_0", true, false) != null and arena.find_child("Platform_W", true, false) != null, "D's SpawnPad*/Platform* anchors")
	await _encounter("plaza_pre")
	await tp(Vector3(0, 7.4, -104), 10)
	check(await wait_until(func() -> bool: return level.boss != null, 120), "plaza trigger starts the Algorithm")
	check(BS.flag("cs.introAlgorithm") or "introAlgorithm" in D.cutscenes_played, "introAlgorithm title card on first aggro")
	check(not D.gates["finetree_gate"].is_open, "the gate closes behind Bolt")
	var boss: Node3D = level.boss
	if not check(boss != null and is_instance_valid(boss), "the Algorithm spawned"):
		return
	notes.append("boss: %s%s" % [boss.get_class(), (" (%s)" % boss.get_script().resource_path) if boss.get_script() != null else ""])
	notes.append("boss is stand-in: %s" % level.boss_is_stand_in)
	if not level.boss_is_stand_in:
		var o: Variant = boss.get("opts")
		check(o is Dictionary and (o as Dictionary).get("arena") == arena, "boss got opts[\"arena\"] = the FineTree arena")
	check(arena.fighting, "arena fight running (complaint kiosks printing)")
	# feed a complaint canister into the low slot
	var k: ComplaintKiosk = arena.get_node("ComplaintKiosks/ComplaintKiosk_0") as ComplaintKiosk
	var c: ComplaintCanister = k.print_canister()
	await frames(2)
	c.global_position = arena.slot_position("SlotLow")
	c.linear_velocity = Vector3.ZERO
	check(await wait_until(func() -> bool: return "SlotLow" in arena.notices, 30), "a complaint canister fed into SlotLow is a notice")
	var mx: float = float(boss.get("max_hp")) if boss.get("max_hp") != null else 520.0
	var guard: int = 0
	while not level.boss_done and guard < 500:
		guard += 1
		if is_instance_valid(boss) and boss.has_method("take_damage"):
			var h: Combat.Hit = hit(mx * 0.08)
			h.weak_point = true
			boss.call("take_damage", h)
		await frames(10)
	check(level.boss_done, "the Algorithm defeated by damage (%d volleys)" % guard)
	check(D.flag("algorithm_down"), "algorithm_down flag")
	check(level.phase_count() == 2, "both arena phases ran (%d)" % level.phase_count())
	check(not arena.fighting, "arena fight ended")
	await frames(90)
	check(D.gates["plaza_exit"].is_open and D.gates["finetree_gate"].is_open, "exit stairs + gate open after the kill")
	check(NB.core != null and is_instance_valid(NB.core) and NB.core.visible, "Keystone Core revealed behind the wall")


func _core_and_exit() -> void:
	step("core + exit")
	var core: NovaCore = NB.core
	if core != null and is_instance_valid(core):
		await tp(core.global_position + Vector3(0, 0.2, 0), 10)
	check(BS.flag("core.nova_plaza"), "core.nova_plaza flag (star map counts cores)")
	check("coreNova" in D.cutscenes_played, "coreNova plays on the pickup")
	check(D.exit.active, "Return Relay lit")
	await tp(D.exit.global_position + Vector3(0, 1.2, 0), 10)
	check(await wait_until(func() -> bool: return D.exit.completed, 30), "the Return Relay completes the planet")
	check(BS.flag("planet_complete.nova_plaza") and BS.flag("cleared.nova_plaza"), "planet_complete / cleared flags")
	check(5 in (SaveProfile.doc["bs"]["planets_cleared"] as Array), "planets_cleared has 5")


func _out_of_bounds() -> void:
	step("out of bounds")
	barks.clear()
	await tp(Vector3(16, 1.2, -82), 20)
	var safe: Vector3 = bolt.global_position
	await tp(Vector3(31, -5.5, -82), 0)
	bolt.last_safe = safe
	check(await wait_until(func() -> bool: return "splash.05" in barks, 40), "service-level drop quip (splash.05)")
	check(await wait_until(func() -> bool: return bolt.global_position.y > -10.0 and bolt.global_position.distance_to(safe) < 3.0, 90),
		"falling past kill_y resets Bolt to safe ground")
	await tp(Vector3(0, 1.5, 26.5), 4)
	check(await wait_until(func() -> bool: return "splash.01" in barks, 30), "HOA perimeter wall quip (splash.01)")
	await tp(Vector3(-6, 1.2, 7), 10)
	var safe2: Vector3 = bolt.global_position
	await tp(Vector3(0, 0.96, 6.5), 0)
	bolt.last_safe = safe2
	check(await wait_until(func() -> bool: return bolt.global_position.distance_to(safe2) < 1.5, 40), "the fountain is water: Bolt is reset")


func _finish() -> void:
	for n: String in notes:
		print("[nova] note: ", n)
	if fails.is_empty():
		print("[nova] RESULT PASS (%.1fs)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	else:
		print("[nova] RESULT FAIL (%d)" % fails.size())
		for f: String in fails:
			print("[nova]   - ", f)
	BS.god_mode = false
	if level != null and is_instance_valid(level):
		level.queue_free()
		await frames(3)
	EnemySpawner.clear_pool()
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit(0 if fails.is_empty() else 1)


# ====================================================================== screenshot tour

const TOUR: Array = [
	# [label, bolt position, camera yaw, pitch]
	["hub_arrival", [0, 1.2, 17], 0.0, 0.25],
	["hub_fountain", [-6, 1.2, 14], -0.4, 0.2],
	["civic_walkways", [-8, 1.2, -1], 0.15, 0.3],
	["civic_center", [4, 5.7, -20], 0.3, 0.3],
	["civic_station", [-10.5, 13.2, -20.2], 0.6, 0.35],
	["hoa_street", [-24, 7.2, -46], 1.2, 0.3],
	["hoa_clubhouse", [-30, 10.2, -60], 0.0, 0.3],
	["hoa_eyes", [-46, 7.2, -51.5], -1.4, 0.3],
	["underpass_camp", [-30, 1.2, 6], 1.3, 0.25],
	["underpass_plaza", [-84, 1.7, -12], 1.57, 0.3],
	["permit_facade", [38, 4.2, -31], 0.0, 0.25],
	["permit_hall", [40, 4.2, -45], 0.4, 0.3],
	["records_hallway", [48, 10.2, -76], 0.0, 0.2],
	["transit_ride", [], 0.0, 0.3],
	["finetree_deck", [-3, 13.2, -85], 0.0, 0.35],
	["finetree_plaza", [0, 7.2, -88], 0.0, 0.2],
	["algorithm_fight", [0, 7.2, -94], 0.0, 0.25],
	["dead_train", [15, 13.2, -73], -0.92, 0.35],
]


func _tour() -> void:
	DirAccess.make_dir_recursive_absolute(_out if not _out.begins_with("user://") else ProjectSettings.globalize_path(_out))
	if not await _load_level():
		get_tree().quit(1)
		return
	BS.set_flag("nova_plaza.variance")
	BS.set_flag("nova_plaza.permit")
	await frames(30)
	var rows: int = ceili(float(TOUR.size()) / COLS)
	_sheet = Image.create(CW * COLS, CH * rows, false, Image.FORMAT_RGBA8)
	for e: Variant in TOUR:
		var row: Array = e
		var label: String = str(row[0])
		if label == "transit_ride":
			await tp(Vector3(-10.5, 13.2, -20.2), 10)
			level.board_train("finetree", -1)
			await frames(300)
			await _shot(Vector3.INF, float(row[2]), float(row[3]), label, 2)
			await wait_until(func() -> bool: return not NB.train.moving, 900)
			continue
		if label == "algorithm_fight":
			level.start_algorithm()
			await frames(60)
		await _shot(LevelKit.v3(row[1]), float(row[2]), float(row[3]), label, 50)
	var path: String = _out.path_join("nova_tour.png")
	_sheet.save_png(path)
	print("[shots] wrote ", path)
	if level != null and is_instance_valid(level):
		level.queue_free()
		await frames(3)
	EnemySpawner.clear_pool()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit()


func _shot(at: Vector3, yaw: float, pitch: float, label: String, settle: int) -> void:
	if at != Vector3.INF:
		bolt.global_position = at
		bolt.motor.vel = Vector3.ZERO
		bolt.last_safe = at
		bolt.scripted = {"dir": Vector3.ZERO}
	var cam: BoltCamera = bolt.camera
	cam.yaw = yaw
	cam.pitch = pitch
	cam.snap_to(bolt)
	await frames(settle)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(_out.path_join("nova_%02d_%s.png" % [_n, label]))
	img.resize(CW, CH)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	print("[shots] %02d %s" % [_n, label])
	_n += 1
