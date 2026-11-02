class_name UndertowParts
extends RefCounted
## THE UNDERTOW's parts and bench on Totenhafen (contract C4, DECISIONS T-153). Totenhafen.attach calls attach():
## every candidate spot in map02.json "undertow".spots gets a BuildablePart (Part_<part>_<spot>); the quest
## map02_letzte_fahrt's random "ut_parts" picks the live one per part, and without that quest (or before it loads)
## this seeds its own pick with the match seed. The workbench stands at "undertow".bench. The coffin shard is not
## placed here: spawn_shard() puts it on the sea stairs once the third coffin has gone over (the dump calls it).

const QUEST: StringName = &"map02_letzte_fahrt"
const RANDOM_KEY: String = "ut_parts"
## The crane office is a solid block in the generator (CraneOffice, x 44..50, z 52..57): a bench spot inside it is
## moved to the office's west face (T-153) so it can be reached.
const OFFICE_LO: Vector2 = Vector2(44.0, 52.0)
const OFFICE_HI: Vector2 = Vector2(50.0, 57.0)
const OFFICE_BENCH: Array = [43.1, 0.0, 53.6, 90.0]


static func cfg() -> Dictionary:
	return GLData.load_json("res://data/gravelight/map02.json").get("undertow", {})


static func attach(t: Totenhafen) -> void:
	var c: Dictionary = cfg()
	var spots: Dictionary = c.get("spots", {})
	for part: String in spots.keys():
		var by_spot: Dictionary = spots[part]
		for spot: String in by_spot.keys():
			var bp: BuildablePart = BuildablePart.new()
			bp.part_id = StringName(part)
			bp.spot_id = StringName(spot)
			bp.buildable_id = &"undertow"
			t.place(bp, "Part_%s_%s" % [part, spot], by_spot[spot])
	var bench: Array = bench_spot(c)
	var wb: Workbench = Workbench.new()
	wb.buildable_id = &"undertow"
	t.place(wb, "Workbench_Undertow", bench)
	_bench_body(wb)
	# without the quest, seed the spots ourselves once the map's quests had their chance to load
	t.get_tree().process_frame.connect(func() -> void: seed_if_no_quest(t), CONNECT_ONE_SHOT | CONNECT_DEFERRED)


## The bench's spot [x, y, z, yaw] (moved out of the solid crane office when the data puts it inside).
static func bench_spot(c: Dictionary) -> Array:
	var b: Array = c.get("bench", OFFICE_BENCH)
	var out: Array = [float(b[0]), float(b[1]), float(b[2]), float(c.get("bench_yaw", b[3] if b.size() > 3 else 0.0))]
	if out[0] > OFFICE_LO.x and out[0] < OFFICE_HI.x and out[2] > OFFICE_LO.y and out[2] < OFFICE_HI.y:
		return OFFICE_BENCH.duplicate()
	return out


## A plank bench under the workbench's tools (the map has none here): a small collider so nobody walks through it.
static func _bench_body(wb: Node3D) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "BenchBody"
	body.collision_layer = 1
	var cs: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = Vector3(1.8, Workbench.BENCH_TOP, 0.8)
	cs.shape = bx
	cs.position = Vector3(0, Workbench.BENCH_TOP * 0.5, 0.4)
	body.add_child(cs)
	wb.add_child(body)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = bx.size
	mi.mesh = bm
	mi.material_override = Mats.get_mat("planks")
	mi.position = cs.position
	wb.add_child(mi)


## The pick per part from the match seed (pure: the same seed gives the same spots).
static func seeded_pick(spots: Dictionary, seed_v: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_v ^ 0x5AB0
	var out: Dictionary = {}
	var parts: Array = spots.keys()
	parts.sort()
	for part: Variant in parts:
		var names: Array = (spots[part] as Dictionary).keys()
		names.sort()
		if not names.is_empty():
			out[String(part)] = String(names[rng.randi_range(0, names.size() - 1)])
	return out


static func seed_if_no_quest(t: Totenhafen) -> void:
	if t == null or not t.is_inside_tree():
		return
	var picks: Variant = QuestManager.random_value(QUEST, RANDOM_KEY)
	if picks is Dictionary and not (picks as Dictionary).is_empty():
		return   # the quest seeded them
	var seed_v: int = QuestManager.match_seed
	var pick: Dictionary = seeded_pick(cfg().get("spots", {}), seed_v)
	for n: Node in t.get_tree().get_nodes_in_group(&"buildable_parts"):
		var bp: BuildablePart = n as BuildablePart
		if bp == null or bp.buildable_id != &"undertow" or bp.part_id == &"undertow_shard":
			continue
		bp.force_live(str(pick.get(String(bp.part_id), "")) == String(bp.spot_id))


## After the third dump: the coffin shard on the sea stairs (map02.json "ballast".shard_spot). Every peer runs it
## (the dump mirrors the call); returns the part (or the one already there).
static func spawn_shard(t: Totenhafen) -> Node3D:
	if t == null or t.gameplay == null:
		return null
	var existing: Node3D = t.gameplay.get_node_or_null("Part_undertow_shard_sea_stairs") as Node3D
	if existing != null:
		return existing
	var spot: Array = (GLData.load_json("res://data/gravelight/map02.json").get("ballast", {}) as Dictionary).get("shard_spot", [10.9, 0.0, -2.7])
	var bp: BuildablePart = BuildablePart.new()
	bp.part_id = &"undertow_shard"
	bp.spot_id = &"sea_stairs"
	bp.buildable_id = &"undertow"
	t.place(bp, "Part_undertow_shard_sea_stairs", spot)
	bp.force_live(true)
	return bp
