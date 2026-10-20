extends GutTest
## Level kit (bs/world) and Scrapheap data: conveyors carry bodies, mallet switches fire, gold bolts / memos
## record into BS + SaveProfile, quests complete and pay, triggers / gates / the Return Relay work, the level
## data is consistent (counts, line ids), and the director builds the level with a plain test host.

const PROFILE: String = "user://test_bs_level_profile.json"

var _saved_path: String
var _saved_doc: Dictionary
var _world: Node3D


func before_all() -> void:
	_saved_path = SaveProfile.path
	_saved_doc = SaveProfile.doc.duplicate(true)
	SaveProfile.path = PROFILE


func after_all() -> void:
	SaveProfile.path = _saved_path
	SaveProfile.doc = _saved_doc
	BS.load_from_profile()
	BS.god_mode = false
	BS.ui_block = 0
	EnemySpawner.clear_pool()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE))


func before_each() -> void:
	SaveProfile.doc = SaveProfile.blank()
	BS.load_from_profile()
	BS.flags.clear()
	BS.bolts = 0
	BS.mallet_tier = 0
	BS.god_mode = true
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	BS.god_mode = false


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _floor(size: Vector3 = Vector3(60, 1, 60), pos: Vector3 = Vector3(0, -0.5, 0)) -> void:
	LevelKit.box(_world, pos, size, "#555555", true)


func _bolt_at(p: Vector3) -> Bolt:
	var b: Bolt = Bolt.new()
	b.position = p
	_world.add_child(b)
	b.scripted = {"dir": Vector3.ZERO}
	return b


func _belt(speed: float = 3.2) -> ConveyorBelt:
	var c: ConveyorBelt = ConveyorBelt.new()
	c.size = Vector3(12, 0.5, 3)
	c.dir = Vector3(-1, 0, 0)
	c.speed = speed
	c.position = Vector3(0, 0.25, 0)       # top at y 0.5
	_world.add_child(c)
	return c


# ------------------------------------------------------------------ conveyors

func test_conveyor_carries_bolt() -> void:
	_floor(Vector3(60, 1, 60), Vector3(0, -0.5, 20))
	var c: ConveyorBelt = _belt()
	var b: Bolt = _bolt_at(Vector3(3, 0.5 + 0.96, 0))
	await _frames(15)
	var x0: float = b.global_position.x
	await _frames(60)
	assert_almost_eq(b.global_position.x - x0, -3.2, 0.7, "Bolt rides the belt west at ~3.2 m/s")
	assert_eq(c.get_platform_delta().length() > 0.0, true, "belt reports a platform delta")


func test_conveyor_carries_character_body() -> void:
	_belt(2.6)
	var body: CharacterBody3D = CharacterBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(0.6, 0.6, 0.6)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(2, 0.82, 0)
	_world.add_child(body)
	var mover: Callable = func() -> void:
		body.velocity.y -= 30.0 / 60.0
		body.move_and_slide()
	get_tree().physics_frame.connect(mover)
	await _frames(20)
	var x0: float = body.global_position.x
	await _frames(60)
	get_tree().physics_frame.disconnect(mover)
	assert_lt(body.global_position.x - x0, -1.5, "a CharacterBody3D on the belt is carried (floor velocity)")


func test_conveyor_reverser() -> void:
	var c: ConveyorBelt = _belt()
	await _frames(2)
	assert_almost_eq(c.current_velocity().x, -3.2, 0.001)
	c.reverse_for(0.5)
	assert_true(c.reversed())
	assert_almost_eq(c.current_velocity().x, 3.2, 0.001, "reversed belt runs the other way")
	await _frames(40)
	assert_false(c.reversed(), "flips back after the timer")


# ------------------------------------------------------------------ switches, triggers, gates

func test_mallet_switch_fires_from_the_throw_path() -> void:
	var s: MalletSwitch = MalletSwitch.new()
	s.position = Vector3(0, 1, -3)
	_world.add_child(s)
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	_floor()
	watch_signals(s)
	b.melee.call("_hit_switches", Vector3(0, 1, -2.2))     # BoltMelee's boomerang check (within 1.4 m)
	assert_signal_emitted(s, "switched")
	assert_true(s.is_down)
	s.on_mallet(b)
	assert_eq(s.hits, 1, "one-shot switch ignores further hits")
	assert_true(s.is_in_group(&"mallet_switches"))


func test_gadget_switch_needs_mallet_tier() -> void:
	var s: MalletSwitch = MalletSwitch.new()
	s.gadget = "thunder"
	_world.add_child(s)
	s.on_mallet(null)
	assert_eq(s.hits, 0, "Thunder target ignores the Scrap Mallet")
	BS.mallet_tier = 2
	s.on_mallet(null)
	assert_eq(s.hits, 1, "Thunder Mallet throw powers it")


func test_trigger_volume_fires_once_and_respects_flags() -> void:
	_floor()
	var t: TriggerVolume = TriggerVolume.new()
	t.size = Vector3(4, 4, 4)
	t.position = Vector3(0, 1, -6)
	t.requires = PackedStringArray(["door_key"])
	t.gate_check = func(req: PackedStringArray, _f: PackedStringArray) -> bool: return BS.flag(req[0])
	_world.add_child(t)
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	await _frames(5)
	b.global_position = Vector3(0, 0.95, -6)
	await _frames(5)
	assert_eq(t.fired_count, 0, "blocked while its flag is clear")
	BS.set_flag("door_key")
	await _frames(3)
	assert_eq(t.fired_count, 1, "fires for a player standing inside once the flag is set")
	await _frames(5)
	assert_eq(t.fired_count, 1, "once")


func test_level_gate_opens_and_closes() -> void:
	var g: LevelGate = LevelGate.new()
	g.size = Vector3(4, 3, 0.5)
	g.open_offset = Vector3(0, 3, 0)
	g.speed = 30.0
	g.position = Vector3(0, 1.5, 0)
	_world.add_child(g)
	g.open()
	await _frames(10)
	assert_true(g.is_open and g.settled())
	assert_almost_eq(g.position.y, 4.5, 0.01)
	g.close(true)
	assert_almost_eq(g.position.y, 1.5, 0.01)


# ------------------------------------------------------------------ collectibles

func test_gold_bolt_records_into_bs_and_profile() -> void:
	var g: GoldBolt = GoldBolt.new()
	g.gold_id = "scrapheap.2"
	g.planet = "scrapheap"
	_world.add_child(g)
	watch_signals(EventBus)
	assert_true(g.collect(null))
	assert_true(BS.flag("gold.scrapheap.2"))
	assert_true(GoldBolt.is_found("scrapheap.2"))
	assert_eq(GoldBolt.found_list("scrapheap"), ["scrapheap.2"])
	assert_eq(int(SaveProfile.doc["bs"]["gold_bolts"]), 1)
	assert_signal_emitted_with_parameters(EventBus, "gold_bolt_found", ["scrapheap.2"])
	assert_true(FileAccess.file_exists(PROFILE), "autosaved")
	assert_false(g.collect(null), "only once")


func test_gold_bolt_collected_by_touch() -> void:
	_floor()
	var g: GoldBolt = GoldBolt.new()
	g.gold_id = "scrapheap.3"
	g.planet = "scrapheap"
	g.position = Vector3(0, 1, -4)
	_world.add_child(g)
	var b: Bolt = _bolt_at(Vector3(0, 0.95, 0))
	await _frames(4)
	b.global_position = Vector3(0, 0.95, -4)
	await _frames(6)
	assert_true(BS.flag("gold.scrapheap.3"), "walking into it collects it")


func test_memo_records() -> void:
	var m: MemoPickup = MemoPickup.new()
	m.memo_id = "memo.03"
	m.title = "Scrap Mutt Feeding Policy"
	_world.add_child(m)
	watch_signals(EventBus)
	m.collect(null)
	assert_true("memo.03" in (SaveProfile.doc["bs"]["memos"] as Array))
	assert_true(MemoPickup.is_found("memo.03"))
	assert_signal_emitted_with_parameters(EventBus, "memo_found", ["memo.03"])


func test_hidden_memo_cannot_be_taken_until_revealed() -> void:
	var m: MemoPickup = MemoPickup.new()
	m.memo_id = "memo.02"
	_world.add_child(m)
	m.reveal(false)
	assert_false(m.collect(null))
	m.reveal(true)
	assert_true(m.collect(null))


# ------------------------------------------------------------------ quests

func _book() -> QuestBook:
	var q: QuestBook = QuestBook.new()
	q.setup(0, {"scrapmutt": "scrap_mutt", "vulture": "vulture_drone"})
	_world.add_child(q)
	return q


func _fake_enemy(id: String) -> Node:
	var n: Node = Node.new()
	n.set_meta(&"enemy_id", id)
	_world.add_child(n)
	return n


func test_kill_quest_completes_and_pays() -> void:
	var q: QuestBook = _book()
	assert_eq(q.state("q1a"), QuestBook.NONE)
	q.start("q1a")
	assert_eq(q.state("q1a"), QuestBook.ACTIVE)
	EventBus.enemy_killed.emit(_fake_enemy("vulture_drone"), &"mallet")
	assert_eq(q.count("q1a"), 0, "wrong type does not count")
	for i: int in 4:
		EventBus.enemy_killed.emit(_fake_enemy("scrap_mutt"), &"mallet")
	assert_eq(q.state("q1a"), QuestBook.READY)
	watch_signals(EventBus)
	assert_true(q.turn_in("q1a"))
	assert_eq(BS.bolts, 80, "q1a pays 80 bolts")
	assert_eq(q.state("q1a"), QuestBook.DONE)
	assert_signal_emitted_with_parameters(EventBus, "quest_done", ["q1a"])
	assert_eq(str((SaveProfile.doc["bs"]["quests"] as Dictionary)["q1a"]["state"]), "done", "persisted")


func test_collect_quest_items_show_only_while_active() -> void:
	var q: QuestBook = _book()
	var item: QuestItem = QuestItem.new()
	item.quest_id = "q1b"
	item.item = "sandwich"
	_world.add_child(item)
	await _frames(2)
	assert_false(item.visible, "hidden before the quest")
	assert_false(item.collect(null))
	q.start("q1b")
	await _frames(2)
	assert_true(item.visible)
	assert_true(item.collect(null))
	assert_eq(q.count("q1b"), 1)


func test_npc_talk_runs_quests_in_order() -> void:
	var q: QuestBook = _book()
	var n: NPCTalkPoint = NPCTalkPoint.new()
	n.display_name = "Rusty"
	n.quests = PackedStringArray(["q1a", "q1b"])
	n.idle_line = "bs.scrapheap.rusty_idle"
	_world.add_child(n)
	assert_eq(n.talk(), "q1a")
	assert_eq(q.state("q1a"), QuestBook.ACTIVE)
	assert_true("q.q1a.intro.01" in n.talked, "intro lines")
	n.talk()
	assert_true("q.q1a.prog.01" in n.talked, "progress line while under way")
	for i: int in 4:
		EventBus.enemy_killed.emit(_fake_enemy("scrap_mutt"), &"mallet")
	n.talk()
	assert_eq(q.state("q1a"), QuestBook.DONE)
	assert_eq(BS.bolts, 80)
	assert_eq(n.talk(), "q1b", "next quest after the first is done")
	assert_eq(q.state("q1b"), QuestBook.ACTIVE)


# ------------------------------------------------------------------ exit

func test_teleporter_marks_planet_complete() -> void:
	var t: TeleporterExit = TeleporterExit.new()
	t.planet_id = "scrapheap"
	t.planet_index = 0
	_world.add_child(t)
	assert_false(t.try_complete(), "dark until the boss falls")
	t.activate(true)
	watch_signals(t)
	assert_true(t.try_complete())
	assert_true(BS.flag("planet_complete.scrapheap"))
	assert_true(0 in (SaveProfile.doc["bs"]["planets_cleared"] as Array))
	assert_eq(int(SaveProfile.doc["bs"]["campaign_step"]), 1)
	assert_signal_emitted(t, "planet_completed")


# ------------------------------------------------------------------ data

func _walk_line_refs(v: Variant, out: PackedStringArray) -> void:
	if v is Dictionary:
		var d: Dictionary = v
		for k: String in ["hint", "line", "bark", "label", "text", "prompt", "idle", "from", "to"]:
			if d.has(k) and d[k] is String and (str(d[k]).begins_with("bs.") or str(d[k]).begins_with("code.") or str(d[k]).begins_with("splash.")):
				out.append(str(d[k]))
		for k2: String in ["banner", "barks"]:
			if d.has(k2) and d[k2] is Array:
				for s: Variant in d[k2]:
					out.append(str(s))
		for val: Variant in d.values():
			_walk_line_refs(val, out)
	elif v is Array:
		for e: Variant in v:
			_walk_line_refs(e, out)


func test_scrapheap_data_is_consistent() -> void:
	var D: Dictionary = Data.table("bs/levels/scrapheap")
	var L: Dictionary = Data.table("bs/levels/scrapheap_lines")
	LevelKit.register_lines(L["lines"])
	assert_eq((D["gold_bolts"] as Array).size(), int(D["gold_total"]), "gold bolt rows match the total")
	assert_eq(int(D["gold_total"]), 5, "Scrapheap has 5 gold bolts (BS_LEVELS §0.6)")
	var memo_ids: Array = []
	for m: Variant in D["memos"]:
		memo_ids.append(str((m as Dictionary)["id"]))
	assert_eq(memo_ids, ["memo.01", "memo.02", "memo.03", "memo.04", "memo.05"], "planet-0 memos")
	var quests: Array = []
	for n: Variant in D["npcs"]:
		quests.append_array((n as Dictionary).get("quests", []))
	assert_eq(quests, ["q1a", "q1b", "q1c", "q1d"], "Rusty + Mama Gasket give q1a-q1d")
	var allowed: Array = ["scrap_mutt", "tinker_turret", "vulture_drone", "lien_crawler", "bolt_crate"]
	for e: Variant in D["encounters"]:
		for wave: Variant in (e as Dictionary)["waves"]:
			for row: Variant in wave:
				assert_true(str((row as Dictionary)["type"]) in allowed, "encounter %s uses a Scrapheap type" % (e as Dictionary)["id"])
	var refs: PackedStringArray = []
	_walk_line_refs(D, refs)
	assert_gt(refs.size(), 40)
	for id: String in refs:
		assert_true(LevelKit.has_text(id), "line id %s exists" % id)
	for beat: String in ["l1_glitch", "l1_row", "l1_mast", "l1_mid", "l1_vista", "l1_repo"]:
		assert_true(JSON.stringify(D["triggers"]).contains("\"%s\"" % beat), "a trigger plays %s" % beat)


func test_director_builds_and_runs_rules_with_a_plain_host() -> void:
	var host: Node3D = Node3D.new()
	_world.add_child(host)
	var d: LevelDirector = LevelDirector.new()
	host.add_child(d)
	d.setup(host, "scrapheap")
	assert_gt(d.nav_polygons, 100, "navmesh baked")
	assert_gt(d.geometry.find_children("*", "StaticBody3D", true, false).size(), 150, "colliders built")
	assert_eq(d.gold.size(), 5)
	assert_eq(d.start_point(), LevelKit.v3(d.D["prologue_spawn"]), "new save starts in the garage")
	assert_false(d.gates["lot_gate"].is_open)
	d.set_flag("power", true)
	assert_true(d.lamps["lamp_power"].lit, "POWER lamp")
	for c: String in ["clamp_1", "clamp_2", "clamp_3"]:
		d.set_flag(c)
	assert_true(d.flag("uplink") and d.lamps["lamp_uplink"].lit, "UPLINK from the three clamps")
	assert_true(d.gates["lot_gate"].is_open, "both lamps open the Compaction Lot")
	assert_true(BS.flag("scrapheap.uplink"), "level flags are stored as scrapheap.<name>")
	d.set_respawn(Vector3(1, 2, 3))
	assert_eq(d.respawn_point, Vector3(1, 2, 3))
