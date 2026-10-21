extends Node
## Headless smoke run of Rustvane Canyon, landing to the Return Relay. Loads the real level scene
## (RustvaneLevel on BSLevel) and drives Bolt: colliders + navmesh, every zone probe, hub services, NPC
## quests q2a-q2d, every encounter, the Tether-Hook (earned at the Co-op winch, then real swing / pull physics
## on the practice course, the zip towers, the Strip Mine gantry and the Cliff Roost), zip lines, updrafts,
## bounce umbrellas, billboards and the staff lift, gold bolts, memos, secrets, story beats (l2_camp, l2_holo1,
## l2_staff, l2_mid, firmwareScene, ccIntro, l2_glambot), both boss arenas (the Rustvane Sentinel on the
## Quarry Floor, The Content Creator on the Sunset Stage, with its stage phases), the GLAMBOT pop-up, the
## exit with the shield reveal, and the out-of-bounds quips. Bosses come from EnemySpawner; if it returns null
## a TestDummy stands in (director.boss_fallback). Prints "[rustvane] RESULT PASS" or "... FAIL" with reasons.
##
## Run (no window, no audio):
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/smoke_rustvane.tscn
## Screenshot tour instead (rendered, silent, off-screen; every audio bus muted; never captures the mouse):
##   Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://tools_src/smoke_rustvane.tscn -- --shots --out=C:/dir
## Uses its own save profile (deleted afterwards).

const PROFILE: String = "user://smoke_rustvane_profile.json"
const LEVEL_SCENE: String = "res://bs/planets/rustvane/rustvane.tscn"

var level: RustvaneLevel
var D: RustvaneDirector
var bolt: Bolt
var hook: TetherHook
var fails: PackedStringArray = []
var notes: PackedStringArray = []
var barks: PackedStringArray = []
var prompts: PackedStringArray = []
var kills: Dictionary = {}
var shots: bool = false
var out_dir: String = "user://shots"
var _t0: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	for a: String in OS.get_cmdline_user_args():
		if a == "--shots":
			shots = true
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
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
	if shots:
		_shots.call_deferred()
	else:
		_run.call_deferred()


func check(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
		print("[rustvane]   FAIL: ", msg)
	return ok


func step(title: String) -> void:
	print("[rustvane] -- %s (%.1fs)" % [title, (Time.get_ticks_msec() - _t0) / 1000.0])


## Waits n physics frames, skipping any cutscene that starts (the smoke never watches them).
func frames(n: int) -> void:
	for i: int in n:
		_skip_cutscenes()
		await get_tree().physics_frame


func _skip_cutscenes() -> void:
	if level == null or not is_instance_valid(level):
		return
	if level.cutscenes != null and level.cutscenes.playing:
		level.cutscenes.skip()
	if get_tree().paused:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func tp(p: Vector3, wait: int = 6) -> void:
	if hook != null and hook.busy():
		hook.cancel()
	if D.zip_rider != null:
		D.zip_rider.cancel()
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


func feet() -> float:
	return bolt.global_position.y - bolt.motor.hy


# ====================================================================== the run

func _load() -> bool:
	if not ResourceLoader.exists(LEVEL_SCENE):
		check(false, "level scene missing")
		return false
	BSLevel.pending_cutscene = ""
	level = (load(LEVEL_SCENE) as PackedScene).instantiate() as RustvaneLevel
	get_tree().root.add_child(level)
	await frames(4)
	D = level.director
	bolt = level.bolt
	if D == null or bolt == null:
		check(false, "director / Bolt missing")
		return false
	D.boss_fallback = func(id: StringName, _pos: Vector3, _arena: RustvaneArena) -> Node3D:
		var td: TestDummy = TestDummy.new()
		td.max_hp = float(D.boss_cfg(String(id)).get("stand_in_hp", 300.0))
		td.hp = td.max_hp
		td.add_to_group(&"bosses")
		return td
	return true


func _run() -> void:
	step("load level")
	if not await _load():
		_finish()
		return
	notes.append("EnemySpawner present: %s" % EnemyBridge.has_spawner())
	check("flyover1" in D.cutscenes_played or BS.flag("cs.flyover1") or level.cutscenes.scene_id == "flyover1",
		"first landing plays flyover1 (then arrive1)")
	await frames(30)
	check(BS.flag("cs.arrive1"), "arrive1 plays after flyover1")
	await _check_world()
	await _zones()
	await _hub_services()
	await _earn_hook()
	await _tether_course()
	await _quests_and_encounters()
	await _traversal()
	await _critical_path()
	await _sentinel()
	await _towers_and_topdeck()
	await _content_creator()
	await _popup()
	await _collectibles_and_secrets()
	await _beats()
	await _exit()
	await _out_of_bounds()
	notes.append("stub enemies used: %s; boss stand-ins: %s" % [EnemyBridge.used_stub, D.stand_ins_used])
	notes.append("kills by type: %s" % str(kills))
	_finish()


func _check_world() -> void:
	step("colliders + navmesh")
	var solids: int = D.geometry.find_children("*", "StaticBody3D", true, false).size()
	check(solids > 200, "expected >200 static colliders, got %d" % solids)
	check(D.nav_polygons > 100, "navmesh has %d polygons" % D.nav_polygons)
	var map: RID = D.nav_region.get_navigation_map()
	await wait_until(func() -> bool: return NavigationServer3D.map_get_path(map, Vector3(0, 0, 30), Vector3(4, 0, 12), true).size() >= 2, 120)
	await frames(2)
	notes.append("navmesh: %d polygons, %d static colliders" % [D.nav_polygons, solids])
	var pairs: Array = [[Vector3(0, 0, 30), Vector3(18, 0.4, 30)], [Vector3(0, 0, 30), Vector3(0, 0, -74)],
		[Vector3(0, 0, -74), Vector3(40, 0, -57)], [Vector3(0, 6.5, -24), Vector3(13, 7.7, -41)],
		[Vector3(-4, 8.4, -106), Vector3(10, 8.4, -122)], [Vector3(88, 0.5, -58), Vector3(104, 0.5, -52)]]
	for pr: Array in pairs:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, pr[0], pr[1], true)
		var ok: bool = path.size() >= 2 and path[path.size() - 1].distance_to(pr[1]) < 3.0
		check(ok, "nav path %s -> %s (%d pts, end %s)" % [pr[0], pr[1], path.size(), path[path.size() - 1] if path.size() > 0 else "-"])
	check(is_equal_approx(bolt.kill_y, -8.0), "Bolt.kill_y = %s" % bolt.kill_y)
	check(bolt.water_zones.size() == 4, "water zones %d" % bolt.water_zones.size())
	check(level.splash_quips.size() == 4, "per-planet splash quip pool (%d)" % level.splash_quips.size())
	check(D.arenas.has("quarry") and D.arenas.has("sunset"), "both boss arenas built")
	for n: String in ["Center", "BossSpawn", "Gate", "Pillar_1", "Pillar_4", "Mound_1", "AddSpawn_1", "CableRing_1", "Searchlight", "PlungePool"]:
		check(D.arenas["quarry"].anchor(n) != null, "quarry arena anchor %s" % n)
	for n: String in ["Center", "Pool", "Deck", "HoverStage", "Mast_NW", "Ring", "DroneSpawn_NE", "Cabana_W", "Parasol_E", "Tile_0_0", "Ammo_W", "BoxDrop", "InfinityEdge", "AddSpawn_4"]:
		check(D.arenas["sunset"].anchor(n) != null, "sunset arena anchor %s" % n)
	check(D.arenas["sunset"].markers("Masts").size() == 4, "four camera masts")
	check(D.tethers.size() == 8, "8 Tether-Hook rings (%d)" % D.tethers.size())
	check(GadgetManager.attach_to(bolt) == level.gadgets and level.gadgets != null, "GadgetManager on Bolt (idempotent attach_to)")


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
	step("hub: beacon, ship, kiosk")
	prompts.clear()
	await tp(D.beacon.global_position + Vector3(0.8, 1.0, 0.8), 6)
	check(prompts.size() > 0 and prompts[prompts.size() - 1] != "", "beacon interact prompt")
	D.beacon.interact(bolt)
	check(D.beacon.saves == 1 and FileAccess.file_exists(PROFILE), "beacon saves")
	(D.nodes.get("interact.ship") as InteractPoint).interact(bolt)
	await frames(2)
	check(not BS.flag("cs.shieldReveal"), "boarding before the planet is cleared skips the shield reveal")
	check("board_ship" in D.host_calls, "ship asks the level to board")
	check(D.kiosk != null, "Blartz kiosk placed (ShopKiosk)")


func _aim_at(p: Vector3) -> void:
	var cam: BoltCamera = bolt.camera
	for i: int in 4:
		var d: Vector3 = (p - cam.cam.global_position).normalized()
		cam.yaw = atan2(-d.x, -d.z)
		cam.pitch = clampf(asin(-d.y), -0.55, 1.25)
		await frames(3)


func _earn_hook() -> void:
	step("the Tether-Hook (Co-op winch)")
	check(level.gadgets.get_gadget(&"tether_hook") == null and not level.gadgets.press(), "no hook before the winch")
	await tp(Vector3(18, 1.6, 30), 8)
	check(BS.flag("beat.l2_camp"), "l2_camp at the Co-op sign")
	var w: InteractPoint = D.nodes.get("interact.winch")
	await tp(w.global_position + Vector3(0, 1.0, 0), 4)
	w.interact(bolt)
	await frames(10)
	check("rv_tether_hook" in level.level_cutscenes_played and BS.flag("cs.rv_tether_hook"), "winch plays the hook cutscene (level data)")
	check(GadgetManager.owns(&"tether_hook") and SaveProfile.is_unlocked("bs.gadget.tether_hook"), "gadget.tether_hook owned + unlocked")
	hook = level.gadgets.get_gadget(&"tether_hook") as TetherHook
	check(hook != null, "TetherHook added to Bolt's belt")
	if hook == null:
		return
	check(D.encounters["camp_bomber"].started, "first Review Bomber over the camp once the hook is earned")
	await _clear(D.encounters["camp_bomber"])


## A pull through the real input path: aim the camera at the ring, press the gadget, land on the ledge.
func _pull_test(label: String, start: Vector3, ring_id: String, top_y: float, rect: Rect2) -> void:
	var ring: TetherPoint = D.tethers[ring_id]
	await tp(start, 20)
	await _aim_at(ring.global_position)
	var got: Node3D = hook.acquire()
	check(got == ring, "%s: camera-cone acquire picks %s (got %s)" % [label, ring_id, got.name if got != null else "none"])
	bolt.scripted = {"dir": Vector3.ZERO, "gadget_pressed": true}
	await frames(2)
	if not hook.busy():
		hook.attach(ring)
	check(await wait_until(func() -> bool: return hook.state == TetherHook.State.PULL, 20), "%s: reels in (PULL)" % label)
	check(await wait_until(func() -> bool: return hook.state == TetherHook.State.IDLE, 120), "%s: pull ends" % label)
	var landed: bool = await wait_until(func() -> bool: return bolt.motor.on_ground, 90)
	var p: Vector3 = bolt.global_position
	check(landed and absf(feet() - top_y) < 0.3 and rect.has_point(Vector2(p.x, p.z)),
		"%s: lands on the ledge (feet %.2f vs %.2f at %.1f, %.1f)" % [label, feet(), top_y, p.x, p.z])


## A swing through the gadget, played the way a player does it: jump off `start` toward `dir`, fire at the
## ring, pump toward `dir`; let go on the forward arc once past the ring (the release keeps the swing's
## velocity and adds 4 m/s up), double-jump, hold JUMP to hover and steer onto the far platform `rect`.
func _swing_test(label: String, start: Vector3, dir: Vector3, ring_id: String, top_y: float, rect: Rect2) -> bool:
	var ring: TetherPoint = D.tethers[ring_id]
	var ring_along: float = ring.global_position.dot(dir)
	await tp(start, 20)
	bolt.scripted = {"dir": dir, "jump_pressed": true, "jump_held": true}
	await frames(9)
	hook.attach(ring)
	check(await wait_until(func() -> bool: return hook.state == TetherHook.State.SWING, 20), "%s: swinging" % label)
	var released: bool = false
	for i: int in 240:
		await frames(1)
		if OS.get_environment("RV_DEBUG") != "" and i % 4 == 0:
			print("[dbg] %s f%d st %d pos %s vel %s rope %.2f" % [label, i, hook.state, bolt.global_position, hook.vel, hook.rope])
		if hook.state != TetherHook.State.SWING:
			break       # the swing ended by touching down (a landing lets go by itself)
		if bolt.global_position.dot(dir) >= ring_along + 0.8 and hook.vel.dot(dir) > 0.5:
			bolt.scripted["jump_pressed"] = true
			released = true
			await frames(1)
			break
	check(released or hook.state == TetherHook.State.IDLE, "%s: let go on the forward arc" % label)
	if released:
		check(hook.last_release_vel.y >= hook.vel.y + 3.9 - 0.01 and bolt.motor.jumps == 1 and is_equal_approx(bolt.motor.hover, 1.0),
			"%s: release keeps velocity + 4 up, double jump and hover ready (vy %.1f, jumps %d, hover %.2f)" % [label, hook.last_release_vel.y, bolt.motor.jumps, bolt.motor.hover])
		check(not level.gadgets.press(), "%s: 0.25 s re-fire cooldown" % label)
	if hook.busy():
		hook.cancel()
	var goal: Vector2 = rect.get_center()
	var doubled: bool = false
	var landed: bool = false
	for i: int in 240:
		var p2: Vector2 = Vector2(bolt.global_position.x, bolt.global_position.z)
		var to: Vector2 = goal - p2
		var steer: Vector3 = Vector3(to.x, 0, to.y).normalized() * clampf(to.length() / 1.5, 0.0, 1.0)
		bolt.scripted["dir"] = steer
		bolt.scripted["jump_held"] = true
		if released and not doubled and i == 8:
			bolt.scripted["jump_pressed"] = true
			doubled = true
		await frames(1)
		if bolt.motor.on_ground and i > 2:
			landed = true
			break
	bolt.scripted = {"dir": Vector3.ZERO}
	await frames(4)
	var p: Vector3 = bolt.global_position
	var ok: bool = landed and absf(feet() - top_y) < 0.6 and rect.grow(0.5).has_point(Vector2(p.x, p.z))
	check(ok, "%s: lands on the far side (feet %.2f vs %.2f at %.1f, %.1f)" % [label, feet(), top_y, p.x, p.z])
	return ok


func _tether_course() -> void:
	step("Tether-Hook: Co-op practice course")
	if hook == null:
		return
	# first pull: the winch's anchor ring, camp floor -> ledge B (12 m up)
	await _pull_test("winch pull", Vector3(24.0, 1.4, 35.5), "winch_anchor", 12.0, Rect2(29, 33, 5, 6))
	check(hook.pulls >= 1, "pull counted")
	# first swing: across the ore trench
	await _swing_test("trench swing", Vector3(21, 1.4, 39.6), Vector3(0, 0, 1), "camp_swing", 0.0, Rect2(13, 48, 14, 6))
	check("bs.gadget.tether.weight.01" in barks, "Sprocket's weight-limit bark on the first swing")
	# two-ring chain: ledge B -> ledge A (camp_chain_1), ledge A -> ledge C (camp_chain_2)
	await _swing_test("chain 1", Vector3(31.5, 12.95, 38.6), Vector3(0, 0, 1), "camp_chain_1", 9.5, Rect2(28.5, 47.5, 5, 7))
	await _swing_test("chain 2", Vector3(28.6, 10.45, 51), Vector3(-1, 0, 0), "camp_chain_2", 9.5, Rect2(9.5, 47.5, 5, 7))
	var jar: Variant = D.items.get("course_jar")     # may already be gone: the chain swing lands on it
	if is_instance_valid(jar):
		await tp((jar as LevelItem).global_position + Vector3(0, 0.3, 0), 6)
	check(D.flag("course_done"), "practice course reward on ledge C")


func _clear(e: Encounter) -> void:
	var guard: int = 0
	while not e.done and guard < 60:
		guard += 1
		for en: Node3D in e.living():
			if en.has_method("take_damage"):
				en.call("take_damage", hit(99999.0))
		await frames(8)
	check(e.done, "encounter %s cleared (%d spawned)" % [e.encounter_id, e.spawned_total])


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
	check(await wait_until(func() -> bool: return e.started, 30), "encounter %s started by its trigger" % id)
	await _clear(e)
	check(e.spawned_total > 0, "encounter %s spawned enemies" % id)


func _talk(npc_id: String) -> String:
	var n: NPCTalkPoint = D.npcs[npc_id]
	await tp(n.global_position + Vector3(1.0, 1.0, 1.0), 4)
	return n.talk()


func _turn_in(npc_id: String, qid: String) -> void:
	var before: int = BS.bolts
	var got: String = await _talk(npc_id)
	var reward: int = int((D.quest_book.defs[qid] as Dictionary)["reward"])
	check(got == qid and D.quest_book.state(qid) == QuestBook.DONE, "%s turned in (state %s)" % [qid, D.quest_book.state(qid)])
	check(BS.bolts - before >= reward and BS.bolts - before < reward + 30, "%s pays %d (got %d; loose bolts may land too)" % [qid, reward, BS.bolts - before])


func _collect_quest_items(qid: String) -> void:
	for qv: Variant in D.quest_items:
		if is_instance_valid(qv) and (qv as QuestItem).quest_id == qid:
			var qi: QuestItem = qv
			await frames(2)
			check(qi.visible, "%s item visible while active" % qid)
			await tp(qi.global_position + Vector3(0, 0.4, 0), 6)
	check(await wait_until(func() -> bool: return D.quest_book.state(qid) == QuestBook.READY, 30),
		"%s items collected (%d/%d)" % [qid, D.quest_book.count(qid), D.quest_book.need(qid)])


func _quests_and_encounters() -> void:
	step("quests + encounters")
	check(await _talk("concierge") == "q2a" and D.quest_book.state("q2a") == QuestBook.ACTIVE, "Concierge-Tron gives q2a")
	check(await _talk("bellhop") == "q2c" and D.quest_book.state("q2c") == QuestBook.ACTIVE, "Bellhop-9 gives q2c")
	check("q.q2a.intro.01" in D.npcs["concierge"].talked, "Concierge-Tron plays q2a intro lines")
	for id: String in ["hub_crates", "boh_crates"]:
		check(D.encounters[id].started, "%s autostarted" % id)
	for id: String in ["hub", "river", "ledges", "deck_a", "deck_b", "deck_c", "boh", "strip_climb", "towers", "billboards"]:
		step("encounter " + id)
		await _encounter(id)
	check(BS.flag("beat.l2_staff"), "l2_staff on the way into Back of House")
	check(D.quest_book.state("q2a") == QuestBook.READY, "q2a ready (selfie sentries %d)" % D.quest_book.count("q2a"))
	await _turn_in("concierge", "q2a")
	check(await _talk("concierge") == "q2b", "Concierge-Tron gives q2b")
	await _collect_quest_items("q2b")
	await _turn_in("concierge", "q2b")
	await _collect_quest_items("q2c")
	await _turn_in("bellhop", "q2c")
	check(await _talk("bellhop") == "q2d", "Bellhop-9 gives q2d")
	# q2d counts Lifeguard Bots killed while it is active
	for p: Vector3 in [Vector3(-5, 0.5, -85), Vector3(5, 0.5, -85)]:
		var lb: Node3D = EnemyBridge.spawn(&"lifeguard_bot", p, D.dynamic)
		await frames(4)
		if is_instance_valid(lb) and lb.has_method("take_damage"):
			lb.call("take_damage", hit(99999.0))
		await frames(4)
	check(D.quest_book.state("q2d") == QuestBook.READY, "q2d ready (lifeguards %d)" % D.quest_book.count("q2d"))
	await _turn_in("bellhop", "q2d")
	check(await _talk("concierge") == "" and "bs.rustvane.concierge_idle" in D.npcs["concierge"].talked, "Concierge-Tron idles after both quests")


func _traversal() -> void:
	step("updrafts, umbrellas, billboards, lift, zip lines")
	var u: CanyonUpdraft = D.updrafts["updraft_rim_1"]
	check(await wait_until(func() -> bool: return u.is_blowing() and fmod(u._t, u.on_time + u.off_time) < 0.3, 400), "updraft pulse starts")
	await tp(u.global_position + Vector3(0, 1.0, 0), 1)
	bolt.scripted = {"dir": Vector3.ZERO, "jump_pressed": true, "jump_held": true}
	var y0: float = bolt.global_position.y
	await frames(90)
	check(bolt.global_position.y - y0 > 5.5, "holding JUMP in the updraft lifts Bolt (+%.1f m in 1.5 s)" % (bolt.global_position.y - y0))
	check(await wait_until(func() -> bool: return not u.is_blowing(), 400), "updraft pulses off (3 s on / 1.5 s off)")
	bolt.scripted = {"dir": Vector3.ZERO}
	var um: BounceUmbrella = D.umbrellas["river_launch"]
	await tp(um.global_position + Vector3(0, 5.0, 0), 1)
	var b0: int = um.bounces
	check(await wait_until(func() -> bool: return um.bounces > b0, 90), "landing on an umbrella bounces")
	check(bolt.motor.vel.y > 12.0, "umbrella launches at power 19 (vy %.1f)" % bolt.motor.vel.y)
	var bb: MagnetCrane = D.billboards["billboard_1"]
	var by0: float = bb.global_position.y
	await frames(40)
	check(absf(bb.global_position.y - by0) > 0.05, "billboard platforms bob")
	var lift: ServiceLift = D.lifts["service_lift"]
	check(not lift.enabled, "staff lift parked without a badge")
	check(not D.gates["mine_door"].is_open, "Strip Mine door shut without a badge")
	var clock: InteractPoint = D.nodes.get("interact.time_clock")
	clock.interact(bolt)
	await frames(2)
	check(D.flag("staff_badge") and lift.enabled and D.gates["mine_door"].is_open, "time clock prints the badge: lift + Strip Mine door")
	await wait_until(func() -> bool: return lift.global_position.distance_to(lift.bottom) < 0.05, 900)
	await tp(lift.global_position + Vector3(0, 1.2, 0), 2)
	check(await wait_until(func() -> bool: return lift.at_top(), 900), "lift rises to the rim")
	await frames(10)
	check(bolt.global_position.y > 18.5, "Bolt rides the lift up (y %.1f)" % bolt.global_position.y)
	# zip line: the rim tower down to T2
	await tp(Vector3(22.4, 19.0, -50), 2)
	check(await wait_until(func() -> bool: return D.zip_rider.riding != null, 20), "walking onto the zip line attaches")
	var f0: int = Engine.get_physics_frames()
	var zp0: Vector3 = bolt.global_position
	await frames(10)
	var zspeed: float = bolt.global_position.distance_to(zp0) / (10.0 / 60.0)
	check(zspeed > 11.5 and zspeed < 15.5, "zip line speed ~13.5 m/s (%.1f)" % zspeed)
	check(await wait_until(func() -> bool: return D.zip_rider.riding == null, 120), "zip line ride ends")
	check(D.zip_rider.last_exit == &"soft", "rim zip ends soft on T2")
	check(await wait_until(func() -> bool: return bolt.motor.on_ground, 60) and absf(feet() - 10.0) < 0.3,
		"zip drops Bolt on tower T2 (feet %.2f)" % feet())
	notes.append("rim zip ride %.2f s" % ((Engine.get_physics_frames() - f0) / 60.0))
	if hook == null:
		return
	# T2 -> T3 is the hook gate (10 m up); T3 -> billboard 1 is the swing gap
	await _pull_test("tower pull", Vector3(8.6, 10.95, -50), "tower_pull", 20.0, Rect2(-5, -52, 4, 4))
	await _swing_test("tower gap", Vector3(-3, 20.95, -51.6), Vector3(0, 0, -1), "tower_gap", 20.0, Rect2(-4.5, -64.5, 3.0, 3.0))
	# the Cliff Roost (S4): plateau -> roost
	await _pull_test("roost pull", Vector3(28.5, 10.0, -23.5), "roost_pull", 16.0, Rect2(30, -32, 4, 4))


func _critical_path() -> void:
	step("Strip Mine: gantry pull, grind, quarry gate")
	if hook != null:
		await _pull_test("gantry pull", Vector3(66.8, 15.6, -58), "gantry_pull", 27.5, Rect2(71.5, -61, 6, 6))
	await tp(Vector3(76.4, 28.5, -58), 2)
	check(await wait_until(func() -> bool: return D.zip_rider.riding != null, 30), "the gantry line attaches")
	check(await wait_until(func() -> bool: return D.zip_rider.riding == null, 200), "grind over the quarry fence ends")
	check(await wait_until(func() -> bool: return bolt.motor.on_ground, 120) and bolt.global_position.x > 84.0,
		"the grind launches Bolt onto the Quarry Floor (x %.1f, y %.1f)" % [bolt.global_position.x, bolt.global_position.y])
	check(not D.gates["vip_gate"].is_open, "VIP gate shut (no wristband, security up)")


func _kill_boss(label: String) -> void:
	var boss: Node3D = D.rv_boss
	if not check(boss != null and is_instance_valid(boss), "%s spawned" % label):
		return
	notes.append("%s node: %s" % [label, boss.get_class() + (" (%s)" % boss.get_script().resource_path if boss.get_script() else "")])
	var id: String = D.rv_boss_id
	var mx: float = float(boss.get("max_hp")) if boss.get("max_hp") != null else 400.0
	if boss.has_method("start_fight"):
		boss.call("start_fight")
	var guard: int = 0
	while D.rv_boss_id == id and guard < 900:
		guard += 1
		if is_instance_valid(boss) and boss.has_method("take_damage"):
			# the Creator's camera drones shield it: break them too
			for dr: Node in get_tree().get_nodes_in_group(&"enemies"):
				if dr != boss and is_instance_valid(dr) and dr is Node3D and dr.has_method("take_damage") \
						and (dr as Node3D).global_position.distance_to(boss.global_position) < 40.0:
					dr.call("take_damage", hit(99999.0))
			var h: Combat.Hit = hit(mx * 0.12)
			h.weak_point = true
			if is_instance_valid(boss):
				boss.call("take_damage", h)
		await frames(10)
	check(D.rv_boss_id != id, "%s defeated by damage (%d volleys)" % [label, guard])


func _sentinel() -> void:
	step("RUSTVANE SENTINEL (Quarry Floor)")
	await tp(Vector3(91, 1.7, -57), 6)
	check(await wait_until(func() -> bool: return D.rv_boss_id == "rustvane_sentinel", 30), "entering the Quarry Floor starts the Sentinel")
	check(not D.gates["quarry_gate"].is_open, "quarry gate shut during the fight")
	check(D.rv_boss != null and D.rv_boss.get_meta(&"arena", null) == D.arenas["quarry"], "Sentinel gets the Quarry arena")
	await _kill_boss("Sentinel")
	await frames(30)
	check(D.flag("sentinel_down") and D.lamps["lamp_security"].lit, "SECURITY lamp lit")
	check(D.gates["quarry_gate"].is_open and not D.gates["mine_bridge"].is_open, "gate opens and the bridge extends back over the pit")
	await frames(120)
	await tp(Vector3(73, 1.5, -62.5), 20)
	check(bolt.motor.on_ground and bolt.global_position.y > 0.5, "the security bridge holds Bolt (y %.2f)" % bolt.global_position.y)
	var up: Variant = D.items.get("quarry_upgrade")
	if is_instance_valid(up):
		await tp((up as LevelItem).global_position + Vector3(0, 0.3, 0), 6)
	check(D.flag("secret_S8") and BS.max_hp >= 120, "updraft vault nanotech +20 HP (S8, max %d)" % BS.max_hp)


func _towers_and_topdeck() -> void:
	step("Top Billboard Deck: l2_mid, wristband, firmware, long zip")
	await tp(Vector3(0, 23.2, -76), 10)
	check(BS.flag("beat.l2_mid"), "l2_mid on the Top Billboard Deck")
	var con: InteractPoint = D.nodes.get("interact.ad_console")
	await tp(con.global_position + Vector3(0, 1.0, 0.4), 2)
	con.interact(bolt)
	await frames(6)
	check(BS.flag("beat.firmwareScene") and SaveProfile.is_unlocked("bs.cosmetic.sprocket_voice_filter"), "firmwareScene + the voice-filter unlock")
	await tp(Vector3(0, 23.0, -80.3), 2)
	check(D.flag("vip_transfer") and D.lamps["lamp_wristband"].lit, "VIP transfer prints the wristband")
	check(D.gates["vip_gate"].is_open and D.flag("vip_open"), "WRISTBAND + SECURITY open the VIP gate")
	check(await wait_until(func() -> bool: return D.zip_rider.riding != null, 30), "the long zip line attaches")
	check(await wait_until(func() -> bool: return D.zip_rider.riding == null, 300), "long zip ride ends")
	check(await wait_until(func() -> bool: return bolt.motor.on_ground, 60) and absf(feet() - 8.4) < 0.3 and absf(bolt.global_position.z + 101.5) < 2.2,
		"long zip lands on the VIP landing (feet %.2f, z %.1f)" % [feet(), bolt.global_position.z])


func _content_creator() -> void:
	step("THE CONTENT CREATOR (Sunset Stage)")
	await tp(Vector3(0, 9.6, -106.6), 8)
	check(BS.flag("beat.ccIntro") and "ccIntro" in level.level_cutscenes_played, "ccIntro plays at the VIP gate (level script)")
	check(await wait_until(func() -> bool: return D.rv_boss_id == "content_creator", 30), "the Creator spawns after ccIntro")
	check(not D.gates["vip_gate"].is_open, "VIP gate closes behind Bolt")
	var stage: HoverStage = D.arenas["sunset"].hover_stage
	check(stage.mode == &"low", "Unboxing: the stage hangs low")
	var modes: Array[StringName] = []
	var watcher: Callable = func() -> void:
		if modes.is_empty() or modes[modes.size() - 1] != stage.mode:
			modes.append(stage.mode)
	get_tree().physics_frame.connect(watcher)
	await _kill_boss("Content Creator")
	get_tree().physics_frame.disconnect(watcher)
	check(&"drift" in modes and &"high" in modes, "stage phases: drift (Collab) and high (Going live) %s" % str(modes))
	check(D.rv_phase_count() == 2, "both stage phases ran (%d)" % D.rv_phase_count())
	await frames(30)
	check(D.flag("cc_down") and BS.flag("story.glambot_prime"), "Creator demonetized; GLAMBOT defects (story.glambot_prime)")
	check(BS.flag("beat.l2_glambot") and "l2_glambot" in level.level_cutscenes_played, "l2_glambot plays (level cutscene)")
	check(stage.mode == &"parked", "the stage parks with the demonetized Creator")
	check(D.exit.active and D.gates["vip_gate"].is_open, "Return Relay lit, VIP gate open")
	check((D.nodes["glambot_drone"] as Node3D).visible and (D.nodes["popup_kiosk"] as Node3D).visible, "GLAMBOT's drone and pop-up kiosk appear")


func _popup() -> void:
	step("GLAMBOT pop-up: Poolside Pile-Up")
	var k: InteractPoint = D.nodes.get("interact.popup_kiosk")
	await tp(k.global_position + Vector3(0, 1.0, 0), 2)
	k.interact(bolt)
	await frames(4)
	var e: Encounter = D.encounters["poolside_pileup"]
	check(D.popup_running and e.started, "kiosk starts the pop-up")
	var before: int = BS.bolts
	await _clear(e)
	await frames(4)
	check(not D.popup_running and BS.bolts - before >= 250, "dry run pays 200 + 25%% (got %d)" % (BS.bolts - before))
	var rec: Dictionary = SaveProfile.doc["bs"].get("arena_records", {})
	check(rec.has("poolside_pileup"), "best time recorded (%s)" % str(rec))
	check(e.waves.size() == 5, "five waves")


func _collectibles_and_secrets() -> void:
	step("gold bolts, memos, items, secrets")
	BS.mallet_tier = 0
	D.switches["timbers_seal"].on_mallet(bolt)
	check(not D.gates["mine_timbers"].is_open, "timbers ignore a plain throw")
	BS.mallet_tier = 2
	D.switches["timbers_seal"].on_mallet(bolt)
	D.switches["vending_box"].on_mallet(bolt)
	check(D.gates["mine_timbers"].is_open and D.flag("secret_S6"), "Magma / Thunder throws open S3 / S6")
	BS.mallet_tier = 0
	await frames(40)
	var rig: InteractPoint = D.nodes.get("interact.ad_sun_rig")
	rig.interact(bolt)
	check(D.flag("secret_S7") and not D.ad_sun_on, "the projector rig switches the ad sun off (S7)")
	for id: String in D.gold.keys():
		var gv: Variant = D.gold[id]
		if is_instance_valid(gv) and not (gv as GoldBolt).taken:
			await tp((gv as GoldBolt).global_position + Vector3(0, 0.3, 0), 6)
	var found: Array = GoldBolt.found_list("rustvane")
	check(found.size() == 4, "4 gold bolts recorded (got %d: %s)" % [found.size(), found])
	for id: String in D.memos.keys():
		var mv: Variant = D.memos[id]
		if is_instance_valid(mv) and not (mv as MemoPickup).taken:
			await tp((mv as MemoPickup).global_position + Vector3(0, 0.3, 0), 6)
	var memos: Array = SaveProfile.doc["bs"]["memos"]
	for mid: String in ["memo.06", "memo.07", "memo.08", "memo.09", "memo.10"]:
		check(mid in memos, "%s recorded" % mid)
	for id: String in D.items.keys():
		var iv: Variant = D.items[id]
		if is_instance_valid(iv) and not (iv as LevelItem).taken:
			await tp((iv as LevelItem).global_position + Vector3(0, 0.3, 0), 6)
			if is_instance_valid(iv) and not (iv as LevelItem).taken:
				(iv as LevelItem).collect(bolt)
				notes.append("item %s needed a direct collect" % id)
	for s: Variant in D.D["secrets"]:
		var f: String = str((s as Dictionary)["flag"])
		check(D.flag(f) or BS.flag(f), "secret %s (%s)" % [(s as Dictionary)["id"], f])


func _beats() -> void:
	step("story beats")
	await tp(Vector3(0, 7.6, -27), 10)
	check(BS.flag("beat.l2_holo1"), "l2_holo1 over deck A's pool")
	for beat: String in ["l2_camp", "l2_holo1", "l2_staff", "l2_mid", "firmwareScene", "ccIntro", "l2_glambot"]:
		check(BS.flag("beat." + beat), "story beat %s played" % beat)


func _exit() -> void:
	step("exit + shield reveal")
	await tp(D.exit.global_position + Vector3(0, 1.2, 0), 10)
	check(await wait_until(func() -> bool: return D.exit.completed, 30), "stepping on the Return Relay completes the planet")
	await frames(10)
	check(BS.flag("cs.shieldReveal"), "the shield reveal plays the first time Bolt leaves Rustvane")
	check(BS.flag("planet_complete.rustvane") and BS.flag("cleared.rustvane"), "planet_complete / cleared flags")
	check(1 in (SaveProfile.doc["bs"]["planets_cleared"] as Array), "planets_cleared has 1")
	check(int(SaveProfile.doc["bs"].get("campaign_step", 0)) >= 2, "campaign step raised to 2")
	check("complete_level" in D.host_calls and level.completed, "host complete_level() ran after the reveal")


func _out_of_bounds() -> void:
	step("out of bounds")
	barks.clear()
	await tp(Vector3(0, 9.6, -122), 20)
	var safe: Vector3 = bolt.global_position
	await tp(Vector3(0, -4.0, -140), 0)
	bolt.last_safe = safe
	check(await wait_until(func() -> bool: return "splash.05" in barks, 30), "lava quip (splash.05)")
	check(await wait_until(func() -> bool: return bolt.global_position.y > -8.0 and bolt.global_position.distance_to(safe) < 3.0, 60),
		"falling into the lava resets Bolt to safe ground")
	await tp(Vector3(-27.4, 1.5, -46), 4)
	check(await wait_until(func() -> bool: return "splash.01" in barks, 30), "canyon wall quip (splash.01)")
	barks.clear()
	await tp(Vector3(-10.5, -2.0, 20), 2)
	check(await wait_until(func() -> bool: return "splash.03" in barks, 40), "river quip (splash.03)")


func _finish() -> void:
	for n: String in notes:
		print("[rustvane] note: ", n)
	if fails.is_empty():
		print("[rustvane] RESULT PASS (%.1fs)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	else:
		print("[rustvane] RESULT FAIL (%d)" % fails.size())
		for f: String in fails:
			print("[rustvane]   - ", f)
	BS.god_mode = false
	if level != null and is_instance_valid(level):
		level.queue_free()
		await frames(3)
	EnemySpawner.clear_pool()
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit(0 if fails.is_empty() else 1)


# ====================================================================== rendered screenshot tour

const CW: int = 400
const CH: int = 225
const COLS: int = 4
var _sheet: Image
var _n: int = 0


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir if not out_dir.begins_with("user://") else ProjectSettings.globalize_path(out_dir))
	if not await _load():
		get_tree().quit(1)
		return
	BS.flags["cs.flyover1"] = true
	BS.flags["cs.arrive1"] = true
	await frames(30)
	GadgetManager.grant(&"tether_hook")
	hook = level.gadgets.get_gadget(&"tether_hook") as TetherHook
	var views: Array = (D.D.get("shots", []) as Array).duplicate()
	if views.is_empty():
		for z: Variant in D.D["zones"]:
			var p: Array = (z as Dictionary)["probe"]
			views.append({"label": str((z as Dictionary)["id"]), "p": p, "yaw": 0.6, "pitch": 0.3})
	var rows: int = ceili(float(views.size()) / COLS)
	_sheet = Image.create(CW * COLS, CH * rows, false, Image.FORMAT_RGBA8)
	for v: Variant in views:
		var vd: Dictionary = v
		if vd.has("swing"):
			await _shot_swing(vd)
		else:
			await _shot(LevelKit.v3(vd["p"]) + Vector3(0, 0.3, 0), float(vd.get("yaw", 0.6)), float(vd.get("pitch", 0.3)), str(vd["label"]))
	var path: String = out_dir.path_join("rustvane_tour.png")
	_sheet.save_png(path)
	print("[shots] wrote ", path)
	level.queue_free()
	await frames(2)
	if FileAccess.file_exists(PROFILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit()


func _shot(at: Vector3, yaw: float, pitch: float, label: String, settle: int = 40) -> void:
	await tp(at, 2)
	var cam: BoltCamera = bolt.camera
	cam.yaw = yaw
	cam.pitch = pitch
	cam.snap_to(bolt)
	await frames(settle)
	await _grab(label)


func _shot_swing(vd: Dictionary) -> void:
	var ring: TetherPoint = D.tethers[str(vd["swing"])]
	await tp(LevelKit.v3(vd["p"]), 10)
	var cam: BoltCamera = bolt.camera
	cam.yaw = float(vd.get("yaw", 0.6))
	cam.pitch = float(vd.get("pitch", 0.3))
	cam.snap_to(bolt)
	bolt.scripted = {"dir": LevelKit.v3(vd.get("dir"), Vector3(0, 0, 1)), "jump_pressed": true, "jump_held": true}
	await frames(9)
	hook.attach(ring)
	await frames(int(vd.get("frames", 30)))
	await _grab(str(vd["label"]))
	hook.cancel()


func _grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(out_dir.path_join("rustvane_%02d_%s.png" % [_n, label]))
	img.resize(CW, CH)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	print("[shots] %02d %s" % [_n, label])
	_n += 1
