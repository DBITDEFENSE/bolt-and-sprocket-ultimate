class_name FineTreeArena
extends Node3D
## FineTree Plaza: the boss arena for THE ALGORITHM (BS_LEVELS §4.10, BS_ENEMIES §4.4). Built by Nova Plaza's
## NovaBuilder from data/bs/levels/nova_plaza.json "nova.arena" and passed to the boss as opts["arena"]:
##   EnemySpawner.spawn(&"the_algorithm", arena.boss_spawn(), parent, {"arena": arena})
##
## ==================================================================== ARENA CONTRACT (for builder D)
## Frame: this node's origin is the plaza centre ON the floor surface (world (0, 6, -100); floor_y = 6).
##   Local -z is NORTH (the server wall), +z is SOUTH (the Transit Loop deck and the gate). Use
##   arena.to_global(local) / arena.global_transform for world positions; the node is not rotated or scaled.
## Size: a round plaza, `radius` = 18 m (36 m across), fenced at the rim (1.6 m railing, one gap to the
##   south-west exit stairs, which open after the kill). The deck south of the plaza is 6 m above the floor.
## Named children (all Node3D unless noted; get them with get_node("Name") or the helpers below):
##   ServerWall      the Algorithm's server wall, 12 m wide x 8 m tall x 2 m deep, centred at (0, 4, -16.5);
##                   its face is the plane z = -15.5. Children: FaceEyes, FaceMouth (MeshInstance3D groups
##                   you may recolour: red for TRENDING), Leds.
##   SlotLow / SlotMid / SlotHigh   Area3D intake slots on the wall face at heights 1.5 / 4 / 6.5 m
##                   (x -4 / 0 / +4). A ComplaintCanister entering one is consumed and emits
##                   notice_delivered(slot_name, canister). Anything else may call deliver_notice(slot, by).
##   BossSpawn       Marker3D (0, 0, -14): where the boss is spawned (just in front of the wall face).
##   Core            Marker3D (0, 2.6, -20), behind the wall: the Keystone Core appears here on the kill.
##   Center          Marker3D (0, 0, 0): the plaza centre the wall faces. Meta "size" = Vector2(36, 36).
##   FineTree        the hologram at the centre (7 tiers to 17.5 m); Fine Rain lanes start under it.
##                   FineTreeTop Marker3D (0, 17.5, 0) is its star (where fines visibly fall from).
##   FineLanes       Lane_0 / Lane_1 / Lane_2 Marker3D at x -6 / 0 / +6 (z 0); each lane runs north-south
##                   from z -12 to z +12 (meta "half_length" = 12, "width" = 3).
##   Kiosks          Kiosk_0..Kiosk_4: the five fine-o-meter kiosks (ComplaintKiosk kind "meter"), r 9 ring,
##                   3 m tall cover. ComplaintKiosks: ComplaintKiosk_0..2, r 9, between them; they print a
##                   canister every 12 s while printing. Every cover piece is in group "finetree_cover" and
##                   has smash() (violation stamps destroy cover); smash_cover_near(p, r) helps.
##   Walkways        WalkwayWest (x -14, carries north) and WalkwayEast (x +14, carries south): the clockwise
##                   walkway ring, NovaWalkway (group "nova_walkways", reverse() / reverse_for(s) /
##                   set_stopped(on) / contains_point(p)). reverse_walkways(s) flips both.
##   Doomscroll      the phase-3 feed: a 16 m strip from z +8 to z -12 whose chevrons scroll NORTH (toward
##                   the wall) at 3 m/s. Visual only (not in "nova_walkways"; the boss pushes Bolt itself);
##                   set_doomscroll(on) shows it and stops / restarts the ring walkways.
##   EscapePlatforms Platform_W / Platform_E: 4 x 4 m fountain platforms 1.8 m high at (-11 / +11, -11), the
##                   phase-3 escape from the Mega-Fine (D's "Platform*" anchors).
##   AddPads         SpawnPad_0..SpawnPad_3 Marker3D on the floor (D's "SpawnPad*" anchors: the Recommended
##                   For You holo-cards / adds).
##   No other node in the arena starts with "SpawnPad" or "Platform" (prefix lookups stay clean).
## Note: the ring walkways are only two of the level's nine; a boss that wants just the arena's should filter
##   group "nova_walkways" with arena.is_ancestor_of(w) or use arena.walkways.
##   LampPosts       NovaLampPost nodes at the rim; each has a TetherPoint (group "tether_points") 7 m up
##                   (13 m above the floor at the north pair), for the 6.5 m slot.
##   Deck            Marker3D on the Transit Loop deck (0, 6, 12.5) (the arena mouth; the relay is there).
## Signals: notice_delivered(slot, by), cover_smashed(node), fight_started, fight_ended.
## Helpers: boss_spawn(), core_position(), slot_position(name), slot_names(), spawn_pads(), lane_points(),
##   reverse_walkways(s), set_doomscroll(on), set_printing(on), smash_cover_near(p, r), cover_left().
## The level calls begin_fight() when the boss spawns and end_fight() on the kill (printing on/off).
## ====================================================================

signal notice_delivered(slot: StringName, by: Node)
signal cover_smashed(node: Node)
signal fight_started
signal fight_ended

var A: Dictionary = {}                       # data/bs/levels/nova_plaza.json "nova.arena"
var radius: float = 18.0
var floor_y: float = 6.0
var walkways: Array[NovaWalkway] = []
var doomscroll: NovaWalkway = null
var notices: Array[String] = []              # slot names in delivery order (tests read it)
var fighting: bool = false
var _tree: Node3D
var _labels: Array[Label3D] = []
var _leds: Array[MeshInstance3D] = []
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(data: Dictionary) -> void:
	A = data
	radius = float(A.get("radius", 18.0))
	floor_y = float(A.get("floor_y", 6.0))


func _ready() -> void:
	_rng.seed = 5
	add_to_group(&"boss_arenas")
	_build_floor()
	_build_wall()
	_build_tree()
	_build_cover()
	_build_walkways()
	_build_platforms_pads_lanes()
	_build_lamps()
	_marker("Deck", LevelKit.v3(A.get("deck", [0, 6, 12.5])))
	_marker("Center", Vector3.ZERO)
	set_meta(&"size", Vector2(radius * 2.0, radius * 2.0))


func _marker(n: String, p: Vector3, parent: Node = null) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = n
	m.position = p
	(parent if parent != null else self).add_child(m)
	return m


func _group(n: String) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	add_child(g)
	return g


# ------------------------------------------------------------------ build

func _build_floor() -> void:
	LevelKit.cylinder(self, Vector3(0, -floor_y * 0.5, 0), radius, floor_y, "#141a30", true)
	LevelKit.cylinder(self, Vector3(0, 0.01, 0), radius - 0.4, 0.04, "#1e2a4a", false)
	# paving rings and a neon edge
	for r: float in [6.0, 12.0]:
		NovaArt.ring(self, Vector3(0, 0.04, 0), r, 0.06, "#ff4d9d", 0.9, Vector3.ZERO)
	NovaArt.ring(self, Vector3(0, 0.05, 0), radius - 0.3, 0.1, "#3ee6ff", 1.2, Vector3.ZERO)
	# rim railing with a gap toward the exit stairs
	var gap: float = float(A.get("exit_gap_deg", 135.0))
	var segs: int = 28
	for i: int in segs:
		var a0: float = TAU * float(i) / segs
		var a1: float = TAU * float(i + 1) / segs
		var mid: float = (a0 + a1) * 0.5
		if absf(wrapf(rad_to_deg(mid) - gap, -180.0, 180.0)) < 9.0:
			continue
		var pa: Vector3 = Vector3(cos(a0), 0, sin(a0)) * (radius - 0.15)
		var pb: Vector3 = Vector3(cos(a1), 0, sin(a1)) * (radius - 0.15)
		NovaArt.beam(self, pa + Vector3(0, 0.8, 0), pb + Vector3(0, 0.8, 0), Vector2(0.15, 1.6), "#3a4658", true)
		LevelKit.box(self, pa + Vector3(0, 1.65, 0), Vector3(0.2, 0.1, 0.2), "#3ee6ff", false, Vector3.ZERO, 1, 1.5)


func _build_wall() -> void:
	var w: Node3D = _group("ServerWall")
	w.position = Vector3(0, 4, -16.5)
	LevelKit.box(w, Vector3.ZERO, Vector3(12, 8, 2), "#1a2240", true)
	# rack columns
	for i: int in 6:
		LevelKit.box(w, Vector3(-5 + i * 2.0, 0, 1.02), Vector3(1.7, 7.6, 0.06), "#232c4a", false)
	var leds: Node3D = Node3D.new()
	leds.name = "Leds"
	w.add_child(leds)
	for i: int in 36:
		var m: MeshInstance3D = LevelKit.box(leds, Vector3(-5.4 + (i % 12) * 0.98, -3.2 + float(i / 12) * 0.35, 1.06),
			Vector3(0.18, 0.08, 0.02), "#9dff5a", false, Vector3.ZERO, 1, 2.0) as MeshInstance3D
		_leds.append(m)
	var eyes: Node3D = Node3D.new()
	eyes.name = "FaceEyes"
	w.add_child(eyes)
	for sx: float in [-1.0, 1.0]:
		LevelKit.box(eyes, Vector3(sx * 2.4, 1.9, 1.07), Vector3(1.4, 1.6, 0.04), "#ffd23e", false, Vector3.ZERO, 1, 2.2)
	var mouth: Node3D = Node3D.new()
	mouth.name = "FaceMouth"
	w.add_child(mouth)
	for i: int in 9:
		var a: float = lerpf(-0.9, 0.9, float(i) / 8.0)
		LevelKit.box(mouth, Vector3(sin(a) * 3.4, -1.4 + (1.0 - cos(a)) * 1.6, 1.07), Vector3(0.62, 0.32, 0.04), "#ffd23e", false,
			Vector3(0, 0, rad_to_deg(atan2(1.6 * sin(a), 3.4 * cos(a)))), 1, 2.2)
	NovaArt.neon_text(w, "bs.nova.algorithm_wall", Vector3(0, 4.4, 1.1), 0.012, "#ff4d9d")
	# intake slots on the face (z = -15.5 in arena space)
	var slots: Array = A.get("slots", [{"name": "SlotLow", "p": [-4, 1.5, -15.3]}, {"name": "SlotMid", "p": [0, 4, -15.3]},
		{"name": "SlotHigh", "p": [4, 6.5, -15.3]}])
	for sd: Variant in slots:
		var s: Dictionary = sd
		var ar: Area3D = Area3D.new()
		ar.name = str(s["name"])
		ar.position = LevelKit.v3(s["p"])
		ar.collision_layer = 0
		ar.collision_mask = 1 << 5
		ar.monitoring = true
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = Vector3(2.0, 0.9, 1.2)
		cs.shape = sh
		ar.add_child(cs)
		add_child(ar)
		ar.add_to_group(&"algorithm_slots")
		LevelKit.box(ar, Vector3(0, 0, -0.18), Vector3(1.8, 0.5, 0.04), "#0e0e14", false)
		LevelKit.box(ar, Vector3(0, 0.3, -0.16), Vector3(1.9, 0.08, 0.04), "#ff4d9d", false, Vector3.ZERO, 1, 2.0)
		ar.body_entered.connect(_on_slot_body.bind(ar.name))
	# the core pillar behind the wall, on the back platform
	LevelKit.box(self, Vector3(0, -floor_y * 0.5, -19.5), Vector3(14, floor_y, 5), "#141a30", true)
	LevelKit.box(self, Vector3(0, 1.0, -20), Vector3(1.6, 2.0, 1.6), "#39404f", true)
	_marker("Core", LevelKit.v3(A.get("core", [0, 2.6, -20])))
	_marker("BossSpawn", LevelKit.v3(A.get("boss_spawn", [0, 0, -14])))


func _build_tree() -> void:
	_tree = _group("FineTree")
	for t: int in 7:
		var r: float = 5.5 - t * 0.7
		var c: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = r
		cm.height = 2.0
		cm.radial_segments = 24
		c.mesh = cm
		c.material_override = NovaArt.glow("#ff4d9d", 0.32 - t * 0.02, 1.4 - t * 0.08)
		c.position = Vector3(0, 2.0 + t * 2.2, 0)
		_tree.add_child(c)
	var star: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	star.mesh = sm
	star.material_override = LevelKit.mat("#ffd23e", 3.0)
	star.position = Vector3(0, 17.5, 0)
	_tree.add_child(star)
	_marker("FineTreeTop", Vector3(0, 17.5, 0), _tree)
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 6.0
	cyl.bottom_radius = 6.0
	cyl.height = 16.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	shaft.mesh = cyl
	shaft.material_override = NovaArt.glow("#ff4d9d", 0.05)
	shaft.position = Vector3(0, 8, 0)
	_tree.add_child(shaft)
	# the tree's base: a low fountain ring (memo 17's kiosk ring is outside it)
	for i: int in 12:
		var a0: float = TAU * float(i) / 12.0
		var a1: float = TAU * float(i + 1) / 12.0
		NovaArt.beam(_tree, Vector3(cos(a0) * 3.4, 0.25, sin(a0) * 3.4), Vector3(cos(a1) * 3.4, 0.25, sin(a1) * 3.4),
			Vector2(0.35, 0.5), "#d8dee9", true)
	var water: MeshInstance3D = LevelKit.cylinder(_tree, Vector3(0, 0.3, 0), 3.2, 0.04, "#7fdcff", false, "y", -1.0, 0.8) as MeshInstance3D
	water.name = "FountainWater"
	# floating fines orbiting the tree
	var fines: Array = A.get("fine_lines", [])
	for i: int in fines.size():
		var l: Label3D = NovaArt.neon_text(_tree, str(fines[i]), Vector3.ZERO, 0.007, "#ffd23e", 0.0, true)
		_labels.append(l)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = LevelKit.color("#ff4d9d")
	light.light_energy = 2.5
	light.omni_range = 22.0
	light.position = Vector3(0, 6, 0)
	_tree.add_child(light)


func _ring_pos(deg: float, r: float) -> Vector3:
	return Vector3(cos(deg_to_rad(deg)) * r, 0, sin(deg_to_rad(deg)) * r)


func _face_center(n: Node3D) -> void:
	var p: Vector3 = n.position
	n.rotation.y = atan2(-p.x, -p.z)


func _build_cover() -> void:
	var kg: Node3D = _group("Kiosks")
	var ring_r: float = float(A.get("kiosk_ring", 9.0))
	var i: int = 0
	for a: Variant in A.get("meter_angles", [90, 162, 234, 306, 18]):
		var k: ComplaintKiosk = ComplaintKiosk.new()
		k.kind = "meter"
		k.name = "Kiosk_%d" % i
		k.position = _ring_pos(float(a), ring_r)
		kg.add_child(k)
		_face_center(k)
		k.smashed.connect(func(n: Node) -> void: cover_smashed.emit(n))
		i += 1
	var cg: Node3D = _group("ComplaintKiosks")
	i = 0
	for a: Variant in A.get("complaint_angles", [198, 342, 270]):
		var c: ComplaintKiosk = ComplaintKiosk.new()
		c.name = "ComplaintKiosk_%d" % i
		c.interval = float(A.get("print_interval", 12.0))
		c.position = _ring_pos(float(a), ring_r)
		cg.add_child(c)
		_face_center(c)
		c.smashed.connect(func(n: Node) -> void: cover_smashed.emit(n))
		i += 1


func _build_walkways() -> void:
	var g: Node3D = _group("Walkways")
	for wd: Variant in A.get("walkways", []):
		var r: Dictionary = wd
		var w: NovaWalkway = NovaWalkway.new()
		w.name = str(r["name"])
		w.walkway_id = str(r.get("id", r["name"]))
		w.district = str(r.get("district", "finetree"))
		w.from = LevelKit.v3(r["from"])
		w.to = LevelKit.v3(r["to"])
		w.width = float(r.get("w", 4.0))
		w.carry = float(r.get("carry", 2.5))
		w.force = float(r.get("force", 10.0))
		g.add_child(w)
		walkways.append(w)
	var dd: Dictionary = A.get("doomscroll", {})
	if not dd.is_empty():
		doomscroll = NovaWalkway.new()
		doomscroll.name = "Doomscroll"
		doomscroll.walkway_id = "doomscroll"
		doomscroll.district = "finetree_doom"
		doomscroll.from = LevelKit.v3(dd["from"])
		doomscroll.to = LevelKit.v3(dd["to"])
		doomscroll.width = float(dd.get("w", 16.0))
		doomscroll.carry = float(dd.get("carry", 3.0))
		doomscroll.force = 0.0
		doomscroll.thickness = 0.1
		doomscroll.visual_only = true
		doomscroll.stopped = true
		doomscroll.strip_color = "#141a30"
		doomscroll.chevron_color = "#ff4d9d"
		add_child(doomscroll)
		doomscroll.visible = false


func _build_platforms_pads_lanes() -> void:
	var pg: Node3D = _group("EscapePlatforms")
	for pd: Variant in A.get("platforms", [{"name": "Platform_W", "p": [-11, 0, -11]}, {"name": "Platform_E", "p": [11, 0, -11]}]):
		var r: Dictionary = pd
		var root: Node3D = Node3D.new()
		root.name = str(r["name"])
		root.position = LevelKit.v3(r["p"])
		pg.add_child(root)
		LevelKit.box(root, Vector3(0, 0.9, 0), Vector3(4, 1.8, 4), "#d8dee9", true)
		LevelKit.box(root, Vector3(0, 1.82, 0), Vector3(3.6, 0.04, 3.6), "#7fdcff", false, Vector3.ZERO, 1, 0.7)
		LevelKit.cylinder(root, Vector3(0, 0.05, 0), 3.2, 0.1, "#7fdcff", false, "y", -1.0, 0.5)
	var sp: Node3D = _group("AddPads")
	var i: int = 0
	for p: Variant in A.get("spawn_pads", [[-8, 0, -4], [8, 0, -4], [-12, 0, 4], [12, 0, 4]]):
		var m: Marker3D = _marker("SpawnPad_%d" % i, LevelKit.v3(p), sp)
		LevelKit.cylinder(m, Vector3(0, 0.03, 0), 1.2, 0.04, "#ff4d9d", false, "y", -1.0, 0.8)
		i += 1
	var lg: Node3D = _group("FineLanes")
	i = 0
	for x: Variant in A.get("lane_x", [-6, 0, 6]):
		var m2: Marker3D = _marker("Lane_%d" % i, Vector3(float(x), 0, 0), lg)
		m2.set_meta(&"half_length", float(A.get("lane_half_length", 12.0)))
		m2.set_meta(&"width", 3.0)
		i += 1


func _build_lamps() -> void:
	var lg: Node3D = _group("LampPosts")
	var i: int = 0
	for p: Variant in A.get("lamp_posts", [[-15.5, 0, -10], [15.5, 0, -10], [-15.5, 0, 6], [15.5, 0, 6]]):
		var lp: NovaLampPost = NovaLampPost.new()
		lp.name = "LampPost_%d" % i
		lp.post_id = "finetree_%d" % i
		lp.district = "finetree"
		lp.position = LevelKit.v3(p)
		lp.ring_h = 7.0
		lp.with_light = i < 2
		lg.add_child(lp)
		i += 1


# ------------------------------------------------------------------ contract helpers

func boss_spawn() -> Vector3:
	return (get_node("BossSpawn") as Node3D).global_position


func core_position() -> Vector3:
	return (get_node("Core") as Node3D).global_position


func slot_names() -> PackedStringArray:
	var out: PackedStringArray = []
	for n: Node in get_children():
		if n.is_in_group(&"algorithm_slots"):
			out.append(n.name)
	return out


func slot_position(slot: String) -> Vector3:
	var n: Node3D = get_node_or_null(slot) as Node3D
	return n.global_position if n != null else global_position


func spawn_pads() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m: Node in get_node("AddPads").get_children():
		out.append((m as Node3D).global_position)
	return out


func lane_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m: Node in get_node("FineLanes").get_children():
		out.append((m as Node3D).global_position)
	return out


func reverse_walkways(seconds: float = 6.0) -> void:
	for w: NovaWalkway in walkways:
		w.flash(0.8)
		w.reverse_for(seconds)


func set_doomscroll(on: bool) -> void:
	if doomscroll != null:
		doomscroll.visible = on
		doomscroll.set_stopped(not on)
	for w: NovaWalkway in walkways:
		w.set_stopped(on)


func doomscroll_on() -> bool:
	return doomscroll != null and not doomscroll.stopped


func set_printing(on: bool) -> void:
	for k: Node in get_tree().get_nodes_in_group(&"complaint_kiosks"):
		if is_ancestor_of(k):
			(k as ComplaintKiosk).printing = on


func cover_left() -> int:
	var n: int = 0
	for k: Node in get_tree().get_nodes_in_group(&"finetree_cover"):
		if is_ancestor_of(k) and not bool(k.get("is_smashed")):
			n += 1
	return n


## Smashes every cover piece within r of p (world). Returns how many fell.
func smash_cover_near(p: Vector3, r: float) -> int:
	var n: int = 0
	for k: Node in get_tree().get_nodes_in_group(&"finetree_cover"):
		if is_ancestor_of(k) and not bool(k.get("is_smashed")) and (k as Node3D).global_position.distance_to(Vector3(p.x, (k as Node3D).global_position.y, p.z)) < r:
			k.call("smash")
			n += 1
	return n


func deliver_notice(slot: StringName, by: Node) -> void:
	notices.append(String(slot))
	notice_delivered.emit(slot, by)


func _on_slot_body(b: Node, slot: StringName) -> void:
	if b is ComplaintCanister and (b as ComplaintCanister).is_alive():
		(b as ComplaintCanister).consume()
		deliver_notice(slot, b)


func begin_fight() -> void:
	fighting = true
	set_printing(true)
	fight_started.emit()


func end_fight() -> void:
	fighting = false
	set_printing(false)
	set_doomscroll(false)
	fight_ended.emit()


func _process(delta: float) -> void:
	_t += delta
	if _tree != null:
		for i: int in _labels.size():
			var a: float = _t * 0.35 + TAU * float(i) / float(maxi(1, _labels.size()))
			_labels[i].position = Vector3(cos(a) * 6.5, 4.0 + float(i % 4) * 2.6 + sin(_t + i) * 0.3, sin(a) * 6.5)
	if fmod(_t, 0.25) < delta and not _leds.is_empty():
		var m: MeshInstance3D = _leds[_rng.randi() % _leds.size()]
		m.visible = not m.visible
