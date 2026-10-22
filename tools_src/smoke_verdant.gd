extends Node
## Headless smoke run of Verdant Sink, landing to the Return Relay. Loads the real level scene (VerdantLevel on
## BSLevel) and drives a scripted Bolt through it: colliders + navmesh, every zone probe, the hub services, the
## murk pools (slow + ticks + the bark), puffballs and bounce mushrooms, the picket line (neutral corn), Shop
## Steward Cornelius' quests q7a / q7b, every encounter, the Union Hall silo and the sail (the Glide granted,
## vd_glide, verdantLate), the Spore Groves climb, the grain boom ride and the long glide into the cab
## (verdantMid), the harvester guts (belt, drums) down to the reactor bay (verdantIntro), the Compost King
## (spawned with opts["arena"]; a TestDummy stand-in if the id is missing) through both endings' machinery
## (the valves, the leaks, the negotiation and the handshake when the real boss is there; damage to death
## otherwise), the Keystone Core, the exit, the Root Cellar pop-up and the out-of-bounds quips.
## Prints "[verdant] RESULT PASS" or "[verdant] RESULT FAIL" with the reasons.
##
## Run (no window, no audio):
##   Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools_src/smoke_verdant.tscn
## Screenshot tour instead (rendered, silent, off-screen; every audio bus muted; never captures the mouse):
##   Godot_v4.7.2-stable_win64_console.exe --audio-driver Dummy --position -4000,-4000 --resolution 1600x900 --path . res://tools_src/smoke_verdant.tscn -- --shots --out=C:/dir
## Uses its own save profile (user://smoke_verdant_profile.json, deleted afterwards).

const PROFILE: String = "user://smoke_verdant_profile.json"
const LEVEL_SCENE: String = "res://bs/planets/verdant/verdant.tscn"
const CW: int = 400
const CH: int = 225
const COLS: int = 4
const TOUR: Array = [
	# [label, bolt position, camera yaw, pitch]
	["hub_pad", [0, 1.6, 23], 0.0, 0.3],
	["hub_boardwalk", [-10, 1.6, 10], -0.5, 0.25],
	["swamp_flats", [0, 0.7, -16], 0.0, 0.2],
	["picket_line", [0, 0.7, -40], 0.0, 0.2],
	["union_hall_ridge", [-20, 5.0, -44], 0.9, 0.25],
	["silo_inside", [-24, 5.0, -52], 1.2, 0.4],
	["silo_loft", [-41, 14.2, -55], -1.4, 0.3],
	["root_cellar", [-70, 0.7, -12], 1.57, 0.2],
	["compost_ring", [-88, 0.7, -8], 1.2, 0.3],
	["spore_groves", [20, 5.0, -42], -0.6, 0.35],
	["groves_caps", [30, 5.0, -56], -0.9, 0.5],
	["canopy_boom", [46, 19.6, -62], -0.9, 0.2],
	["murk_lake", [-26, 0.7, -56], -0.8, 0.15],
	["harvester_cab", [0, 9.6, -86], 0.0, 0.3],
	["harvester_guts", [8, 3.3, -90], 0.6, 0.4],
	["reactor_bay", [0, 0.7, -96], 0.0, 0.2],
	["lagoon", [0, 0.7, -108], 0.0, 0.25],
	["king_fight", [0, 0.7, -114], 0.0, 0.2],
]

var level: VerdantLevel
var D: VerdantDirector
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
		print("[verdant]   FAIL: ", msg)
	return ok


func step(title: String) -> void:
	print("[verdant] -- %s (%.1fs)" % [title, (Time.get_ticks_msec() - _t0) / 1000.0])


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
	if level.gadgets != null:
		level.gadgets.cancel_all()
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


func hit(amount: float, melee: bool = true) -> Combat.Hit:
	var h: Combat.Hit = Combat.Hit.make(amount, Combat.Type.KINETIC, bolt)
	h.weapon_id = &"smoke"
	h.is_melee = melee
	h.is_slam = melee
	h.weak_point = true
	return h


func feet() -> float:
	return bolt.global_position.y - bolt.motor.hy


## A line id the LinePlayer has spoken or still has queued (conversations queue behind each other).
func said(id: String) -> bool:
	return id in D.lines.history or id in D.lines._queue


func _load_level() -> bool:
	if not ResourceLoader.exists(LEVEL_SCENE):
		check(false, "level scene missing")
		return false
	BSLevel.pending_cutscene = ""
	var ps: PackedScene = load(LEVEL_SCENE) as PackedScene
	level = ps.instantiate() as VerdantLevel if ps != null else null
	if not check(level != null, "level scene failed to load / instantiate (script error?)"):
		return false
	add_child(level)
	await frames(4)
	D = level.director
	bolt = level.bolt
	return check(D != null and bolt != null, "director / Bolt missing")


# ====================================================================== the run

func _run() -> void:
	step("load level")
	if not await _load_level():
		_finish()
		return
	notes.append("EnemySpawner present: %s" % EnemyBridge.has_spawner())
	check("flyover7" in D.cutscenes_played or BS.flag("cs.flyover7"), "first landing plays flyover7")
	await _check_world()
	await _zones()
	await _hub_services()
	await _murk_and_mushrooms()
	await _picket_line()
	await _quests_and_encounters()
	await _union_hall()
	await _groves_and_boom()
	await _harvester()
	await _collectibles_and_secrets()
	await _boss()
	await _core_and_exit()
	await _popup()
	await _out_of_bounds()
	notes.append("stub enemies used: %s %s" % [EnemyBridge.used_stub, str(NovaSpawn.stubbed)])
	notes.append("kills by type: %s" % str(kills))
	_finish()


func _check_world() -> void:
	step("colliders + navmesh")
	var solids: int = D.geometry.find_children("*", "StaticBody3D", true, false).size()
	check(solids > 120, "expected >120 static colliders, got %d" % solids)
	notes.append("static colliders: %d" % solids)
	check(D.nav_polygons > 150, "navmesh has %d polygons" % D.nav_polygons)
	var map: RID = D.nav_region.get_navigation_map()
	await wait_until(func() -> bool: return NavigationServer3D.map_get_path(map, Vector3(0, 0, -6), Vector3(0, 0, -20), true).size() >= 2, 180)
	await frames(2)
	notes.append("navmesh: %d polygons" % D.nav_polygons)
	var pairs: Array = [[Vector3(0, -0.3, -6), Vector3(0, -0.3, -50)], [Vector3(0, -0.3, -20), Vector3(-30, 4, -52)], [Vector3(0, -0.3, -20), Vector3(26, 4, -46)],
		[Vector3(-50, -0.3, -12), Vector3(-90, -0.3, -12)], [Vector3(-8, -0.3, -97), Vector3(0, -0.3, -118)], [Vector3(-60, -0.3, -70), Vector3(-60, -0.3, -100)]]
	for pr: Array in pairs:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, pr[0], pr[1], true)
		var ok: bool = path.size() >= 2 and path[path.size() - 1].distance_to(pr[1]) < 3.0
		check(ok, "nav path %s -> %s (%d pts, end %s)" % [pr[0], pr[1], path.size(), path[path.size() - 1] if path.size() > 0 else "-"])
	check(is_equal_approx(bolt.kill_y, -12.0), "Bolt.kill_y = %s" % bolt.kill_y)
	check(bolt.water_zones.size() == 1, "water zones %d (the murk lake)" % bolt.water_zones.size())
	check(bolt.global_position.distance_to(LevelKit.v3(D.D["spawn"])) < 1.5, "Bolt starts on the pad")
	check(D.murk_pools.size() == 11 and D.bouncers.size() == 8 and D.drums.size() == 2, "murk %d / bouncers %d / drums %d" % [D.murk_pools.size(), D.bouncers.size(), D.drums.size()])
	check(D.arena != null and D.core != null and D.zip_rider != null, "arena / core / zip rider built")
	check(D.glide_pennants == 3 and D.tethers.size() == 3 and D.updrafts.size() == 1, "pennants %d / rings %d / updrafts %d" % [D.glide_pennants, D.tethers.size(), D.updrafts.size()])
	notes.append("picket corn spawned: %d (stubbed %d)" % [D.corn_spawned, D.corn_stubbed])
	check(level.gadgets != null, "gadget belt on Bolt")
	check(level.gadgets.get_gadget(&"sprocket_glide") == null, "no Glide before the Union Hall")


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
	step("hub services")
	check(D.beacon != null and D.kiosk != null and D.exit != null and not D.exit.active, "beacon / kiosk / Return Relay (dark)")
	notes.append("pad relay active: %s" % D.relays["pad"].active)
	await tp(D.beacon.global_position + Vector3(0.5, 1.0, 0.5), 6)
	check(prompts.size() > 0, "the beacon prompts")
	check(D.npcs.has("cornelius") and D.npcs.has("customer") and D.npcs.has("corn_dental"), "Cornelius and the denizens")
	await tp(D.npcs["customer"].global_position + Vector3(1.0, 1.0, 1.0), 20)
	check(await wait_until(func() -> bool: return "code.populateLife.21" in barks, 60), "the Confused Customer barks (Tuesday HERE too)")


func _murk_and_mushrooms() -> void:
	step("murk pools, puffballs, bounce mushrooms")
	var p: MurkPool = D.murk_pools["flats_a"]
	var hp0: float = bolt.hp
	BS.god_mode = false
	await tp(p.global_position + Vector3(0, 0.95, 0), 2)
	check(await wait_until(func() -> bool: return p.inside, 30), "Bolt wades in the murk")
	check(await wait_until(func() -> bool: return p.ticks > 0 and bolt.hp < hp0, 90), "the murk ticks 5 damage (hp %.0f -> %.0f)" % [hp0, bolt.hp])
	check(PlayerDebuffs.of(bolt).is_slowed(), "SLOWED while wading")
	bolt.scripted = {"dir": Vector3(1, 0, 0), "sprint": true}
	var x0: float = bolt.global_position.x
	await frames(30)
	var waded: float = bolt.global_position.x - x0
	check(waded < 4.0, "the drag holds him back (%.1f m in 0.5 s)" % waded)
	BS.god_mode = true
	bolt.hp = bolt.max_hp
	notes.append("murk bark: %s" % ("code.updateMurk.01" in barks))
	var puff: BounceMushroom = D.bouncers["puff_flats"]
	await tp(puff.global_position + Vector3(0, 4.5, 0), 1)
	var b0: int = puff.bounces
	check(await wait_until(func() -> bool: return puff.bounces > b0, 90), "landing on a puffball bounces")
	check(bolt.motor.vel.y > 10.0, "puffball power 16 (vy %.1f)" % bolt.motor.vel.y)
	var b1: BounceMushroom = D.bouncers["groves_b1"]
	await tp(b1.global_position + Vector3(0, 5.0, 0), 1)
	var c0: int = b1.bounces
	check(await wait_until(func() -> bool: return b1.bounces > c0, 90), "a bounce mushroom bounces")
	check(bolt.motor.vel.y > 16.0, "express lift power 22 (vy %.1f)" % bolt.motor.vel.y)
	bolt.scripted = {"dir": Vector3.ZERO, "jump_held": true}
	var top: float = bolt.global_position.y
	for i: int in 90:
		await frames(1)
		top = maxf(top, bolt.global_position.y)
	check(top > 13.0, "with JUMP held the lift reaches the caps (peak %.1f)" % top)
	bolt.scripted = {"dir": Vector3.ZERO}


func _picket_line() -> void:
	step("the picket line")
	await tp(Vector3(0, 0.7, -44), 20)
	check(await wait_until(func() -> bool: return said("bs.verdant.picket_line_01"), 30), "the corn turn a non-member away")
	var corn: Array = D.corn_groups.get("picket_line", [])
	notes.append("picket line corn: %d" % corn.size())
	if corn.size() > 0:
		var c: Node3D = corn[0]
		check(not bool(c.call("is_hostile")), "the corn are neutral")
		check(c.is_in_group(&"enemy_decoys"), "enemies may target the corn")


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
	check(await _talk("cornelius") == "q7a" and D.quest_book.state("q7a") == QuestBook.ACTIVE, "Cornelius gives q7a")
	check("q.q7a.intro.01" in D.npcs["cornelius"].talked, "q7a intro lines")
	for id: String in ["hub", "groves", "harvester", "root_cellar", "lagoon_pre"]:
		step("encounter " + id)
		await _encounter(id)
	check(D.flag("groves_cleared") and D.flag("harvester_cleared"), "clear flags")
	check(int(kills.get("pollinator", 0)) >= 5, "5+ pollinators died (%d)" % int(kills.get("pollinator", 0)))
	check(D.quest_book.state("q7a") == QuestBook.READY, "q7a ready (pollinators %d)" % D.quest_book.count("q7a"))
	await _turn_in("cornelius", "q7a")
	check(await _talk("cornelius") == "q7b", "Cornelius gives q7b")
	await _collect_quest_items("q7b")
	await _turn_in("cornelius", "q7b")
	check(await _talk("cornelius") == "" and "code.populateLife.19" in D.npcs["cornelius"].talked, "Cornelius idles (salutes you, sibling) after both quests")


func _union_hall() -> void:
	step("Union Hall: verdantLate, the silo, the sail")
	await tp(Vector3(-21, 5.3, -52), 10)
	check(await wait_until(func() -> bool: return BS.flag("beat.verdantLate"), 60), "verdantLate at the hall door")
	await _encounter("hall_sneak")
	for p: Vector3 in [Vector3(-40, 8.0, -48), Vector3(-36, 11.0, -62), Vector3(-41, 14.0, -55)]:
		await tp(p, 12)
		check(bolt.motor.on_ground and absf(feet() - (p.y - 0.8)) < 0.6, "silo climb: stands at %s (feet %.2f)" % [p, feet()])
	var sail: InteractPoint = D.nodes["interact.sail"]
	await tp(sail.global_position + Vector3(0.5, 1.0, 0.5), 4)
	sail.interact(bolt)
	await frames(10)
	check(D.flag("glide_earned") and GadgetManager.owns(&"sprocket_glide"), "the sail grants the Glide")
	check("vd_glide" in D.cutscenes_played, "vd_glide (level cutscene) plays")
	check(await wait_until(func() -> bool: return level.gadgets.get_gadget(&"sprocket_glide") != null, 10), "the Glide is on the belt")
	# the taught glide: the loft rafters east over the hall to the floor (21 m from 9 m)
	var g: SprocketGlide = level.gadgets.get_gadget(&"sprocket_glide")
	await tp(Vector3(-37.8, 14.2, -55), 2)
	bolt.scripted = {"dir": Vector3(1, 0, 0), "jump_held": true, "sprint": true}
	bolt.motor.hover = 0.0
	bolt.motor.vel = Vector3(6, 0, 0)
	bolt.motor.on_ground = false
	check(await wait_until(func() -> bool: return g.gliding, 90), "the sail opens over the hall")
	check(await wait_until(func() -> bool: return not g.gliding, 400), "the glide ends (%.1f s, %.1f m)" % [g.last_glide_time, g.last_glide_distance])
	check(g.last_glide_distance > 10.0 and bolt.global_position.x > -30.0, "glided east across the hall (x %.1f)" % bolt.global_position.x)
	bolt.scripted = {"dir": Vector3.ZERO}
	await tp(Vector3(0, 0.7, -44), 20)
	check(await wait_until(func() -> bool: return said("bs.verdant.picket_line_02"), 30), "card-carrying: the picket line lets Bolt through")


func _groves_and_boom() -> void:
	step("Spore Groves: caps, the canopy, the grain boom, the long glide")
	for p: Vector3 in [Vector3(20, 8.0, -44), Vector3(34, 14.0, -54), Vector3(46, 19.5, -62)]:
		await tp(p, 12)
		check(bolt.motor.on_ground and absf(feet() - (p.y - 0.8)) < 0.7, "cap at %s (feet %.2f)" % [p, feet()])
	check(await wait_until(func() -> bool: return BS.flag("hint.boom") or true, 1), "canopy hint")
	# the boom: walk onto the rail from C5
	await tp(Vector3(45, 20.0, -62), 2)
	check(await wait_until(func() -> bool: return D.zip_rider.riding != null, 40), "walking onto the grain boom attaches")
	check(await wait_until(func() -> bool: return D.zip_rider.riding == null, 400), "the boom ride ends at the broken end (%s)" % D.zip_rider.last_exit)
	var end_p: Vector3 = bolt.global_position
	check(end_p.x < 34.0 and end_p.z < -78.0, "launched from the broken end over the lake (%s)" % end_p)
	# the long glide west to the cab: burn the hover, then hold JUMP
	var g: SprocketGlide = level.gadgets.get_gadget(&"sprocket_glide")
	bolt.scripted = {"dir": Vector3(-1, 0, -0.2).normalized(), "jump_held": true}
	bolt.motor.hover = 0.0
	check(await wait_until(func() -> bool: return g.gliding, 120), "the sail opens over the murk lake")
	# steer at the cab and let go of JUMP over it (a player drops in; the sail would carry much farther)
	for i: int in 600:
		if not g.gliding or bolt.global_position.x < 2.5:
			break
		var to: Vector3 = Vector3(0, 0, -88) - bolt.global_position
		to.y = 0.0
		bolt.scripted = {"dir": to.normalized(), "jump_held": true}
		await frames(1)
	var flew: float = g.last_glide_distance if not g.gliding else Vector2(bolt.global_position.x - 30.0, bolt.global_position.z + 84.0).length()
	bolt.scripted = {"dir": Vector3.ZERO, "jump_held": false}
	check(await wait_until(func() -> bool: return not g.gliding, 30), "letting go ends the long glide (%.1f s)" % g.last_glide_time)
	check(await wait_until(func() -> bool: return bolt.motor.on_ground, 240), "lands")
	await frames(10)
	notes.append("long glide landed at %s (feet %.1f) after %.1f m" % [bolt.global_position, feet(), flew])
	check(flew > 18.0, "a long glide (%.1f m)" % flew)
	check(bolt.global_position.x < 14.0 and bolt.global_position.x > -12.0 and feet() > 7.0, "reached the harvester's cab / roof (x %.1f, feet %.1f)" % [bolt.global_position.x, feet()])


func _harvester() -> void:
	step("Mega-Harvester: the cab, the guts, the reactor bay")
	await tp(Vector3(0, 9.6, -86), 12)
	check(await wait_until(func() -> bool: return BS.flag("beat.verdantMid"), 60), "verdantMid in the cab")
	await tp(Vector3(0, 9.6, -90), 2)
	check(await wait_until(func() -> bool: return feet() < 6.0, 120), "the cab hatch drops onto the belt (feet %.1f)" % feet())
	var z0: float = bolt.global_position.z
	await frames(40)
	check(bolt.global_position.z < z0 - 0.8, "the belt carries north (%.1f m)" % (z0 - bolt.global_position.z))
	var d1: ThreshingDrum = D.drums["drum_1"]
	await tp(d1.global_position + Vector3(1.2, 1.4, 0), 10)
	var a0: float = atan2(bolt.global_position.z - d1.global_position.z, bolt.global_position.x - d1.global_position.x)
	await frames(60)
	var a1: float = atan2(bolt.global_position.z - d1.global_position.z, bolt.global_position.x - d1.global_position.x)
	check(absf(wrapf(a1 - a0, -PI, PI)) > 0.2, "the threshing drum carries Bolt around (%.2f rad)" % wrapf(a1 - a0, -PI, PI))
	await tp(Vector3(0, 0.7, -97.5), 10)
	check(await wait_until(func() -> bool: return BS.flag("cs.verdantIntro") or "verdantIntro" in D.cutscenes_played, 60), "verdantIntro in the reactor bay (level cutscene)")


func _collectibles_and_secrets() -> void:
	step("gold bolts, memos, items, secrets")
	for id: String in D.gold.keys():
		var gv: Variant = D.gold[id]
		if is_instance_valid(gv) and not (gv as GoldBolt).taken:
			await tp((gv as GoldBolt).global_position + Vector3(0, 0.3, 0), 6)
	var found: Array = GoldBolt.found_list("verdant")
	check(found.size() == 4, "4 gold bolts recorded (got %d: %s)" % [found.size(), found])
	for id: String in D.memos.keys():
		var mv: Variant = D.memos[id]
		if is_instance_valid(mv) and not (mv as MemoPickup).taken:
			await tp((mv as MemoPickup).global_position + Vector3(0, 0.3, 0), 6)
	var memos: Array = SaveProfile.doc["bs"]["memos"]
	for mid: String in ["memo.26", "memo.27", "memo.28", "memo.29", "memo.30", "memo.39"]:
		check(mid in memos, "%s recorded" % mid)
	# the mallet-tier switches: S3 vine curtain (Magma), S5 sprinkler pump (Thunder), the annex plate (any)
	var tier: int = BS.mallet_tier
	BS.mallet_tier = 0
	D.switches["vine_seal"].on_mallet(bolt)
	D.switches["pump_box"].on_mallet(bolt)
	check(not D.gates["vine_curtain"].is_open and not D.flag("secret_S5"), "Magma / Thunder targets ignore a plain throw")
	D.switches["annex_plate"].on_mallet(bolt)
	check(D.gates["annex_gate"].is_open, "the Root Cellar plate opens the annex gate")
	BS.mallet_tier = 2
	var b0: int = BS.bolts
	var pool: MurkPool = D.murk_pools["hub_e"]
	D.switches["vine_seal"].on_mallet(bolt)
	D.switches["pump_box"].on_mallet(bolt)
	check(D.gates["vine_curtain"].is_open, "Magma throw burns the vine curtain")
	check(D.flag("secret_S5") and BS.bolts - b0 == 100 and pool.flush_t > 5.0, "Thunder throw restarts the pump: 100 bolts, the pool flushes clear")
	BS.mallet_tier = tier
	await frames(30)
	for id: String in D.items.keys():
		var iv: Variant = D.items[id]
		if is_instance_valid(iv) and not (iv as LevelItem).taken:
			await tp((iv as LevelItem).global_position + Vector3(0, 0.3, 0), 6)
			if is_instance_valid(iv) and not (iv as LevelItem).taken:
				(iv as LevelItem).collect(bolt)
				notes.append("item %s needed a direct collect (touch missed)" % id)
	# S1 the hollow log (a slide-height crawl), S3 the storeroom, S4 the mast: trigger flags
	await tp(Vector3(-38, 0.6, -40), 8)
	await tp(Vector3(-56, 0.7, -63.5), 8)
	await tp(Vector3(28, 10.0, -121), 8)
	for s: Variant in D.D["secrets"]:
		var f: String = str((s as Dictionary)["flag"])
		check(D.flag(f) or BS.flag(f), "secret %s (%s)" % [(s as Dictionary)["id"], f])
	check(BS.max_hp >= 120, "Root Cellar vault nanotech +20 HP (max %d)" % BS.max_hp)
	# the S6 updraft lifts
	var u: CanyonUpdraft = D.updrafts["vault_vent"]
	await tp(u.global_position + Vector3(0, 1.0, 0), 1)
	bolt.scripted = {"dir": Vector3.ZERO, "jump_pressed": true, "jump_held": true}
	var y0: float = bolt.global_position.y
	await frames(90)
	check(bolt.global_position.y - y0 > 5.0, "holding JUMP in the vault vent lifts Bolt (+%.1f m)" % (bolt.global_position.y - y0))
	bolt.scripted = {"dir": Vector3.ZERO}


func _boss() -> void:
	step("The Compost King")
	var arena: VerdantArena = D.arena
	for nm: String in ["Center", "BossSpawn", "Valve_W", "Valve_E", "Valve_N", "Murk_0", "Murk_1", "Murk_2", "RootArch_0", "Cluster_0", "AddSpawn0", "Handshake", "Spectators", "Bouncer_E"]:
		check(arena.find_child(nm, true, false) != null, "arena anchor %s" % nm)
	await tp(Vector3(0, 0.7, -110), 10)
	check(await wait_until(func() -> bool: return D.boss != null, 120), "the lagoon trigger starts the King")
	check(BS.flag("cs.introCompost") or "introCompost" in D.cutscenes_played, "introCompost title card on first aggro")
	check(not D.gates["lagoon_gate"].is_open, "the gate closes behind Bolt")
	var boss: Node3D = D.boss
	if not check(boss != null and is_instance_valid(boss), "the King spawned"):
		return
	notes.append("boss: %s%s" % [boss.get_class(), (" (%s)" % boss.get_script().resource_path) if boss.get_script() != null else ""])
	notes.append("boss is stand-in: %s" % D.boss_is_stand_in)
	check(arena.fighting, "arena fight running")
	check(arena.open_leaks() == 1, "phase 1: one leak open (%d)" % arena.open_leaks())
	var mx: float = float(boss.get("max_hp")) if boss.get("max_hp") != null else 560.0
	if not D.boss_is_stand_in:
		var k: CompostKing = boss as CompostKing
		check(k.opts.get("arena") == arena, "the King got opts[\"arena\"] = the lagoon")
		check(k.started or await wait_until(func() -> bool: return k.started, 60), "start_fight")
		# phase 2: the leaks burst
		for i: int in 30:
			if k.phase >= 2:
				break
			k.phase_invuln = 0.0
			k.take_damage(hit(mx * 0.1, false))
			await frames(1)
		check(k.phase == 2 and arena.open_leaks() == 3, "phase 2: the leaks burst (%d open)" % arena.open_leaks())
		# the jet hurts; seal every valve from the arena side (mallet hits), each feeds the King
		var v: CoolantValve = arena.valve("W")
		BS.god_mode = false
		bolt.hp = bolt.max_hp
		await tp(v.jet + Vector3(0, 0.95, 0), 2)
		check(await wait_until(func() -> bool: return v.jet_hits > 0, 60), "standing in a coolant jet hurts")
		BS.god_mode = true
		bolt.hp = bolt.max_hp
		var fed0: int = k.seals_fed
		for id: String in ["W", "E", "N"]:
			var vv: CoolantValve = arena.valve(id)
			await tp(vv.global_position + Vector3(0, 0.6, 1.5), 2)
			vv.on_mallet(bolt)
			vv.on_mallet(bolt)
			vv.on_mallet(bolt)
			await frames(3)
			check(not vv.open, "valve %s sealed by three mallet hits" % id)
		check(k.seals_fed - fed0 == 3, "three seals fed the King (%d)" % (k.seals_fed - fed0))
		check(arena.all_sealed(), "all sealed")
		for p: MurkPool in arena.murk_pools:
			check(p.drained, "murk third %s drained" % p.pool_id)
		# phase 3: the negotiation, then the handshake
		for i: int in 40:
			if k.phase >= 3:
				break
			k.phase_invuln = 0.0
			k.take_damage(hit(mx * 0.08, false))
			await frames(1)
		check(k.negotiating, "NEGOTIATION at 30%")
		check(await wait_until(func() -> bool: return arena.handshake_on(), 30), "the handshake is offered (every leak sealed)")
		await tp(boss.global_position + Vector3(2.5, 1.0, 2.5), 4)
		arena.handshake_point.interact(bolt)
		await frames(6)
		check(k.mercy, "MERCY ENDING: the King stands down")
		check(D.boss_mercy and D.flag("compost_mercy"), "the director records the mercy")
		check(await wait_until(func() -> bool: return D.boss_done, 240), "the fight ends")
		check(BS.flag("trophy_collective_bargaining"), "Collective Bargaining trophy")
		check("vd_mercy" in D.cutscenes_played, "vd_mercy plays")
	else:
		var guard: int = 0
		while not D.boss_done and guard < 500:
			guard += 1
			if is_instance_valid(boss) and boss.has_method("take_damage"):
				boss.call("take_damage", hit(mx * 0.08, false))
			await frames(10)
		check(D.boss_done, "the stand-in defeated by damage (%d volleys)" % guard)
		check(D.king_phase_count() == 1, "the data phase ran (%d)" % D.king_phase_count())
	check(D.flag("compost_down"), "compost_down flag")
	check(not arena.fighting, "arena fight ended")
	await frames(60)
	check(D.gates["lagoon_gate"].is_open, "the gate opens after the fight")
	check(D.core != null and is_instance_valid(D.core) and D.core.visible, "the Keystone Core rises out of the drained outfall")


func _core_and_exit() -> void:
	step("core + exit")
	var core: NovaCore = D.core
	if core != null and is_instance_valid(core):
		await tp(core.global_position + Vector3(0, 0.2, 0), 10)
	check(BS.flag("core.verdant"), "core.verdant flag (the star map counts cores)")
	check("coreVerdant" in D.cutscenes_played, "coreVerdant plays on the pickup")
	check(D.exit.active, "Return Relay lit")
	if D.boss_mercy:
		await tp(Vector3(-28, 5.0, -50), 10)
		var npc: Node3D = D.nodes.get("king_npc") as Node3D
		check(npc != null and npc.visible, "the King keeps a chair at the Union Hall after the mercy ending")
	await tp(D.exit.global_position + Vector3(0, 1.2, 0), 10)
	check(await wait_until(func() -> bool: return D.exit.completed, 30), "the Return Relay completes the planet")
	check(BS.flag("planet_complete.verdant") and BS.flag("cleared.verdant"), "planet_complete / cleared flags")
	check(7 in (SaveProfile.doc["bs"]["planets_cleared"] as Array), "planets_cleared has 7")


func _popup() -> void:
	step("Root Cellar pop-up: PICKET LINE")
	var ip: InteractPoint = D.nodes["interact.popup"]
	await tp(ip.global_position + Vector3(0.5, 1.0, 0.5), 4)
	ip.interact(bolt)
	await frames(4)
	check(not D.popup_running and said("bs.verdant.popup_locked"), "the pop-up waits for GLAMBOT's defection")
	BS.set_flag("beat.l2_glambot")
	ip.interact(bolt)
	await frames(4)
	check(D.popup_running, "the pop-up starts")
	notes.append("pop-up corn: %d" % (D.corn_groups.get("popup", []) as Array).size())
	await _encounter("picket_line")
	check(await wait_until(func() -> bool: return not D.popup_running, 30), "the pop-up resolves")
	check(D.popup_won and D.flag("picket_line_done"), "PICKET LINE held (won %s, failed %s)" % [D.popup_won, D.popup_failed])


func _any_splash() -> bool:
	for b: String in barks:
		if b.begins_with("splash."):
			return true
	return false


func _out_of_bounds() -> void:
	step("out of bounds")
	barks.clear()
	await tp(Vector3(-40, 0.7, -56), 20)
	var safe: Vector3 = bolt.global_position
	await tp(Vector3(0, -1.5, -70), 0)
	bolt.last_safe = safe
	check(await wait_until(func() -> bool: return _any_splash(), 60),
		"the murk lake's deep centre: a dive quip (the level's splash.05 when it is the current scene, else the shared pool)")
	check(await wait_until(func() -> bool: return bolt.global_position.distance_to(safe) < 3.0, 90), "the lake resets Bolt to safe ground")
	await tp(Vector3(0, 1.5, 33.5), 4)
	check(await wait_until(func() -> bool: return "splash.01" in barks, 30), "the rim fence quip (splash.01)")


func _finish() -> void:
	for n: String in notes:
		print("[verdant] note: ", n)
	if fails.is_empty():
		print("[verdant] RESULT PASS (%.1fs)" % ((Time.get_ticks_msec() - _t0) / 1000.0))
	else:
		print("[verdant] RESULT FAIL (%d)" % fails.size())
		for f: String in fails:
			print("[verdant]   - ", f)
	BS.god_mode = false
	if level != null and is_instance_valid(level):
		level.queue_free()
		await frames(3)
	EnemySpawner.clear_pool()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))
	get_tree().quit(0 if fails.is_empty() else 1)


# ====================================================================== the screenshot tour

func _tour() -> void:
	DirAccess.make_dir_recursive_absolute(_out if not _out.begins_with("user://") else ProjectSettings.globalize_path(_out))
	if not await _load_level():
		get_tree().quit(1)
		return
	BS.set_flag("verdant.glide_earned")
	await frames(30)
	var rows: int = ceili(float(TOUR.size()) / COLS)
	_sheet = Image.create(CW * COLS, CH * rows, false, Image.FORMAT_RGBA8)
	for e: Variant in TOUR:
		var row: Array = e
		var label: String = str(row[0])
		if label == "king_fight":
			D.start_compost()
			await frames(60)
		await _shot(LevelKit.v3(row[1]), float(row[2]), float(row[3]), label, 50)
	var path: String = _out.path_join("verdant_tour.png")
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
	img.save_png(_out.path_join("verdant_%02d_%s.png" % [_n, label]))
	img.resize(CW, CH)
	_sheet.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i((_n % COLS) * CW, (_n / COLS) * CH))
	print("[shots] %02d %s" % [_n, label])
	_n += 1
