extends GutTest
## Nova Plaza (builder C): level data consistency (counts, line ids, enemy ids), the walkway (carry, push,
## reversal), the HOA violation cycle (flash -> reverse -> cooldown), Compliance Eye vision and blinding,
## the ventilation updraft, the Transit Loop car carrying Bolt, the FineTree arena contract (named anchors,
## a canister fed into a slot), and NovaSpawn's stand-in for ids builder D hasn't listed.

const PROFILE: String = "user://test_bs_nova_profile.json"
const NOVA_ENEMIES: Array = ["meter_maid", "hoa_enforcer", "surge_drone", "zoning_board", "bolt_crate"]

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
	BS.god_mode = true
	_world = Node3D.new()
	add_child_autofree(_world)


func after_each() -> void:
	BS.god_mode = false


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func _floor(size: Vector3 = Vector3(80, 1, 80), pos: Vector3 = Vector3(0, -0.5, 0)) -> void:
	LevelKit.box(_world, pos, size, "#555555", true)


func _bolt_at(p: Vector3) -> Bolt:
	var b: Bolt = Bolt.new()
	b.position = p
	_world.add_child(b)
	b.scripted = {"dir": Vector3.ZERO}
	return b


func _data() -> Dictionary:
	return Data.table("bs/levels/nova_plaza")


func _collect_ids(v: Variant, out: PackedStringArray) -> void:
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			if not (str(k) in ["_", "_doc", "how", "where", "name", "requires", "forbids", "all", "if", "flag", "unless"]):
				_collect_ids((v as Dictionary)[k], out)
	elif v is Array:
		for x: Variant in v:
			_collect_ids(x, out)
	elif v is String:
		var s: String = v
		for pre: String in ["bs.", "code.", "cs.", "st.", "q.", "misc.", "splash."]:
			if s.begins_with(pre) and not s.contains(" "):
				out.append(s)


# ------------------------------------------------------------------ data

func test_level_data_counts() -> void:
	var D: Dictionary = _data()
	assert_eq(int(D["planet_index"]), 5, "LEVELS[5]")
	assert_eq((D["gold_bolts"] as Array).size(), 4, "4 gold bolts (BS_LEVELS §0.6)")
	assert_eq(int(D["gold_total"]), 4)
	var memos: PackedStringArray = []
	for m: Variant in D["memos"]:
		memos.append(str((m as Dictionary)["id"]))
	for id: String in ["memo.16", "memo.17", "memo.18", "memo.19", "memo.20", "memo.38"]:
		assert_true(id in memos, "%s placed" % id)
	assert_eq((D["secrets"] as Array).size(), 7, "S1-S7")
	var N: Dictionary = D["nova"]
	var walk: int = (N["walkways"] as Array).size() + ((N["arena"] as Dictionary)["walkways"] as Array).size()
	assert_eq(walk, 9, "9 walkways (BS_LEVELS §4.5)")
	assert_eq(str((D["boss"] as Dictionary)["id"]), "the_algorithm")


func test_every_line_id_resolves() -> void:
	var lf: Dictionary = Data.table("bs/levels/nova_plaza_lines")
	LevelKit.register_lines(lf.get("lines", {}))
	var ids: PackedStringArray = []
	_collect_ids(_data(), ids)
	assert_gt(ids.size(), 50, "level data references lines")
	for id: String in ids:
		if id.begins_with("bs.levels") or id.begins_with("bs/"):
			continue
		assert_true(LevelKit.has_text(id), "line %s exists" % id)


func test_enemy_ids_are_the_nova_roster() -> void:
	var N: Dictionary = _data()["nova"]
	var seen: Dictionary = {}
	for e: Variant in N["encounters"]:
		for w: Variant in (e as Dictionary)["waves"]:
			for row: Variant in w:
				var t: String = str((row as Dictionary)["type"])
				seen[t] = true
				assert_true(t in NOVA_ENEMIES, "encounter enemy id %s is a BS_ENEMIES §3.3 id" % t)
	for t: String in ["meter_maid", "hoa_enforcer", "surge_drone", "zoning_board"]:
		assert_true(seen.has(t), "%s appears" % t)


func test_quests_for_planet_5() -> void:
	var qb: QuestBook = QuestBook.new()
	qb.setup(5, _data()["enemy_aliases"])
	assert_true(qb.defs.has("q4a") and qb.defs.has("q4b"), "the Squatter's quests")
	assert_eq(qb.kill_type("q4a"), "meter_maid", "q4a counts meter_maid kills")
	qb.free()


# ------------------------------------------------------------------ walkways + HOA

func _walkway(from: Vector3, to: Vector3) -> NovaWalkway:
	var w: NovaWalkway = NovaWalkway.new()
	w.from = from
	w.to = to
	w.district = "t"
	w.walkway_id = "t1"
	_world.add_child(w)
	return w


func test_walkway_carries_and_reverses() -> void:
	_floor()
	var w: NovaWalkway = _walkway(Vector3(0, 0.05, 8), Vector3(0, 0.05, -8))
	assert_true(w.is_in_group(&"nova_walkways"))
	var b: Bolt = _bolt_at(Vector3(0, 1.2, 4))
	await _frames(15)
	var z0: float = b.global_position.z
	await _frames(60)
	assert_lt(b.global_position.z - z0, -1.5, "carried north along the arrows")
	assert_true(w.contains_point(b.global_position), "contains_point under Bolt")
	w.reverse_for(2.0)
	assert_true(w.is_reversed())
	z0 = b.global_position.z
	await _frames(60)
	assert_gt(b.global_position.z - z0, 1.5, "reversed: carried south")
	await _frames(70)
	assert_false(w.is_reversed(), "reversal times out")


func test_hoa_cycle_flash_reverse_cooldown() -> void:
	var C: HOACompliance = HOACompliance.new()
	C.tuning = {"flash": 0.2, "reverse": 0.3, "cooldown": 0.3}
	_world.add_child(C)
	var w: NovaWalkway = _walkway(Vector3(0, 0.05, 8), Vector3(0, 0.05, -8))
	w.district = "civic"
	C.add_walkway(w)
	var l: NovaLampPost = NovaLampPost.new()
	l.district = "civic"
	l.with_light = false
	_world.add_child(l)
	C.add_lamp(l)
	assert_true(C.log_violation("civic", "sprint"), "an idle district starts a reversal")
	assert_eq(C.state("civic"), HOACompliance.FLASH)
	assert_true(l.flashing(), "lamp posts flash red")
	assert_false(w.is_reversed(), "no reversal during the flash")
	await _frames(15)
	assert_eq(C.state("civic"), HOACompliance.REVERSED)
	assert_true(w.is_reversed(), "walkways reverse after the flash")
	assert_false(C.log_violation("civic", "fight"), "no stacking while reversed")
	await _frames(20)
	assert_eq(C.state("civic"), HOACompliance.COOLDOWN)
	await _frames(20)
	assert_eq(C.state("civic"), HOACompliance.IDLE)
	assert_eq(int(C.reversals["civic"]), 1)
	assert_eq(C.history.size(), 2, "both violations logged")


func test_eye_sees_cone_and_blinds() -> void:
	_floor()
	var e: ComplianceEye = ComplianceEye.new()
	e.position = Vector3(0, 0, 0)
	e.look = Vector3(0, 0, -10)
	_world.add_child(e)
	await _frames(2)
	assert_true(e.sees(Vector3(0, 1, -8)), "straight ahead, 8 m")
	assert_true(e.sees(Vector3(2, 1, -10)), "inside the 40° cone")
	assert_false(e.sees(Vector3(8, 1, -8)), "outside the cone (45°)")
	assert_false(e.sees(Vector3(0, 1, -16)), "beyond 14 m")
	assert_false(e.sees(Vector3(0, 1, 6)), "behind the eye")
	LevelKit.box(_world, Vector3(0, 2, -4), Vector3(4, 4, 0.5), "#333333", true)
	await _frames(2)
	assert_false(e.sees(Vector3(0, 1, -8)), "a wall blocks the line of sight")
	assert_true(e.is_in_group(&"mallet_switches"), "a mallet-throw target")
	e.on_mallet(null)
	assert_true(e.is_blind() and not e.sees(Vector3(0, 1, -2)), "blinded for %.0f s" % e.blind_t)


func test_eye_logs_a_sprint() -> void:
	_floor()
	var C: HOACompliance = HOACompliance.new()
	_world.add_child(C)
	var e: ComplianceEye = ComplianceEye.new()
	e.district = "hoa"
	e.position = Vector3(0, 0, 8)
	e.look = Vector3(0, 0, 0)
	_world.add_child(e)
	C.add_eye(e)
	var b: Bolt = _bolt_at(Vector3(0, 1.2, 2))
	await _frames(10)
	b.scripted = {"dir": Vector3(0, 0, -1), "sprint": true}
	for i: int in 40:
		await get_tree().physics_frame
		if "hoa:sprint" in C.history:
			break
	assert_true("hoa:sprint" in C.history, "the eye logs a sprint in its cone (%s)" % str(C.history))


# ------------------------------------------------------------------ updraft, train

func test_updraft_lifts_bolt() -> void:
	_floor()
	var u: NovaUpdraft = NovaUpdraft.new()
	u.radius = 2.5
	u.height = 12.0
	_world.add_child(u)
	var b: Bolt = _bolt_at(Vector3(0, 1.2, 0))
	await _frames(10)
	var y0: float = b.global_position.y
	await _frames(50)
	assert_gt(b.global_position.y - y0, 3.0, "lifted (%.2f m)" % (b.global_position.y - y0))
	assert_true(b.global_position.y < 14.5, "capped near the top")


func test_train_carries_bolt_between_stations() -> void:
	var t: NovaTrain = NovaTrain.new()
	t.center = Vector2(0, 0)
	t.rx = 10.0
	t.rz = 10.0
	t.floor_y = 3.0
	t.speed = 9.0
	t.stations = {"a": 0.0, "b": -PI * 0.5}
	t.station = "a"
	_world.add_child(t)
	var b: Bolt = _bolt_at(Vector3(0, 10, 10))
	await _frames(4)
	assert_true(t.ride("b", b, -1.0), "ride starts")
	for i: int in 300:
		await get_tree().physics_frame
		if not t.moving:
			break
	assert_false(t.moving, "arrived")
	assert_eq(t.station, "b")
	await _frames(5)
	var loc: Vector3 = t.global_transform.affine_inverse() * b.global_position
	assert_true(t.inside_car(loc), "Bolt still in the car at %s" % loc)
	assert_almost_eq(b.global_position.x, -10.0, 2.0, "carried a quarter turn west")


# ------------------------------------------------------------------ arena, spawning

func test_arena_contract_and_notice() -> void:
	var A: FineTreeArena = FineTreeArena.new()
	A.setup(_data()["nova"]["arena"])
	_world.add_child(A)
	await _frames(2)
	for n: String in ["ServerWall", "SlotLow", "SlotMid", "SlotHigh", "BossSpawn", "Core", "FineTree", "Center", "Kiosks", "ComplaintKiosks",
			"Walkways", "Doomscroll", "EscapePlatforms", "AddPads", "FineLanes", "LampPosts", "Deck"]:
		assert_not_null(A.get_node_or_null(n), "anchor %s" % n)
	assert_eq(A.spawn_pads().size(), 4)
	assert_eq(A.slot_names().size(), 3)
	assert_eq(A.walkways.size(), 2)
	assert_false(A.doomscroll.is_in_group(&"nova_walkways"), "the Doomscroll feed is visual only")
	assert_eq(A.get_meta(&"size"), Vector2(36, 36))
	assert_eq(A.cover_left(), 8, "5 fine-o-meters + 3 complaint kiosks")
	assert_eq(A.smash_cover_near(A.to_global(Vector3(0, 0, 9)), 1.5), 1, "a stamp smashes the south kiosk")
	A.begin_fight()
	var k: ComplaintKiosk = A.get_node("ComplaintKiosks/ComplaintKiosk_0") as ComplaintKiosk
	assert_true(k.printing)
	var c: ComplaintCanister = k.print_canister()
	await _frames(2)
	c.global_position = A.slot_position("SlotHigh")
	c.linear_velocity = Vector3.ZERO
	await _frames(6)
	assert_true("SlotHigh" in A.notices, "a canister in a slot is a notice")
	A.set_doomscroll(true)
	assert_true(A.doomscroll_on() and A.walkways[0].stopped, "Doomscroll on stops the ring")
	A.end_fight()
	assert_false(A.doomscroll_on() or k.printing)


func test_nova_spawn_stub_for_unknown_id() -> void:
	var n: Node3D = NovaSpawn.spawn(&"not_an_enemy_yet", Vector3(1, 0, 1), _world)
	assert_not_null(n, "a stand-in spawned")
	assert_true(n is StubEnemy)
	assert_eq(str(n.get_meta(&"enemy_id")), "not_an_enemy_yet")
	assert_null(NovaSpawn.spawn(&"not_an_enemy_yet", Vector3.ZERO, _world, {}, false), "no stub when not wanted")
