class_name NovaBuilder
extends RefCounted
## Builds everything Nova Plaza needs beyond the shared level kit, from data/bs/levels/nova_plaza.json "nova":
## lit-window towers, identical HOA smart homes and smart cars, lamp posts (Tether points), Compliance Eyes,
## moving walkways and the HOA violation system, ventilation updrafts, the elevated highway, the Transit Loop
## (ring, stations, the monorail car, the broken spur), fountains, holo-billboards and neon, the FineTree
## Plaza arena, the Keystone Core, the level's own quest items and encounters, and ambient life.
## The LevelDirector has already built the generic rows (boxes, signs, gates, triggers, NPCs...); static
## pieces go under director.geometry (so the navmesh re-bake sees them), moving ones under director.dynamic.

var director: LevelDirector
var N: Dictionary = {}
var compliance: HOACompliance
var walkways: Dictionary = {}           # id -> NovaWalkway
var eyes: Dictionary = {}               # id -> ComplianceEye
var lamp_posts: Dictionary = {}         # id -> NovaLampPost
var updrafts: Dictionary = {}           # id -> NovaUpdraft
var train: NovaTrain = null
var arena: FineTreeArena = null
var core: NovaCore = null
var ambient: NovaAmbient = null
var tether_points: int = 0
var _keep_out: Array[Rect2] = []


func build(dir: LevelDirector) -> void:
	director = dir
	N = director.D.get("nova", {})
	for r: Variant in N.get("keep_out", []):
		var a: Array = r
		_keep_out.append(Rect2(Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))))
	compliance = HOACompliance.new()
	compliance.name = "HOACompliance"
	compliance.tuning = N.get("hoa", {})
	compliance.director = director
	director.add_child(compliance)
	_build_towers()
	_build_homes_cars()
	_build_fountains()
	_build_billboards_neon()
	_build_highway()
	_build_walkways()
	_build_lamp_posts()
	_build_eyes()
	_build_updrafts()
	_build_loop()
	_build_arena()
	_build_core()
	_build_quest_items()
	_build_encounters()
	_build_ambient()
	for g: Variant in N.get("hidden_groups", []):
		var gd: Dictionary = g
		if not director.flag(str(gd.get("unless", ""))):
			var n: Node3D = director.nodes.get(str(gd["group"])) as Node3D
			if n != null:
				n.visible = false
				for c: Node in n.find_children("*", "CollisionShape3D", true, false):
					(c as CollisionShape3D).disabled = true


## Re-bakes the director's navmesh so it includes the Nova geometry.
func rebake() -> void:
	director.nav_region.bake_navigation_mesh(false)
	director.nav_polygons = director.nav_region.navigation_mesh.get_polygon_count()


func _blocked(x: float, z: float, half: float) -> bool:
	var r: Rect2 = Rect2(Vector2(x - half, z - half), Vector2(half * 2.0, half * 2.0))
	for k: Rect2 in _keep_out:
		if k.intersects(r):
			return true
	return false


# ------------------------------------------------------------------ city dressing

func _build_towers() -> void:
	var g: Node3D = director.geometry
	var i: int = 0
	for td: Variant in N.get("towers", []):
		var r: Dictionary = td
		var p: Array = r["p"]
		NovaArt.tower(g, Vector3(float(p[0]), float(r.get("base", 0.0)), float(p[1])), float(r.get("w", 5.0)), float(r.get("d", r.get("w", 5.0))),
			float(r.get("h", 16.0)), r.get("hue", "#3ee6ff"), i)
		i += 1
	var hues: Array = N.get("tower_hues", ["#ffd23e", "#3ee6ff", "#ff4d9d", "#9dff5a"])
	for fd: Variant in N.get("tower_fields", []):
		var f: Dictionary = fd
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(f.get("seed", 7))
		var placed: Array[Rect2] = []
		var tries: int = 0
		var n: int = 0
		while n < int(f.get("count", 6)) and tries < 400:
			tries += 1
			var w: float = rng.randf_range(float(f["w"][0]), float(f["w"][1]))
			var x: float = rng.randf_range(float(f["x"][0]), float(f["x"][1]))
			var z: float = rng.randf_range(float(f["z"][0]), float(f["z"][1]))
			var rect: Rect2 = Rect2(Vector2(x - w * 0.5 - 1.0, z - w * 0.5 - 1.0), Vector2(w + 2.0, w + 2.0))
			var clash: bool = _blocked(x, z, w * 0.5 + 0.5)
			for o: Rect2 in placed:
				if o.intersects(rect):
					clash = true
					break
			if clash:
				continue
			placed.append(rect)
			var h: float = rng.randf_range(float(f["h"][0]), float(f["h"][1]))
			NovaArt.tower(g, Vector3(x, float(f.get("base", 0.0)), z), w, w * rng.randf_range(0.8, 1.2), h, hues[(n + i) % hues.size()], n + i)
			n += 1
		i += n


func _build_homes_cars() -> void:
	var g: Node3D = director.geometry
	var cols: Array = N.get("home_colors", ["#c9cfd8"])
	var i: int = 0
	for hd: Variant in N.get("homes", []):
		var r: Dictionary = hd
		NovaArt.home(g, LevelKit.v3(r["p"]), float(r.get("ry", 0.0)), r.get("c", cols[i % cols.size()]),
			str(r.get("notice", "bs.nova.home_notice")), str(r.get("placard", "bs.nova.home_placard")))
		i += 1
	for cd: Variant in N.get("cars", []):
		var r: Dictionary = cd
		NovaArt.car(g, LevelKit.v3(r["p"]), float(r.get("ry", 0.0)), r.get("c", "#3ee6ff"))


func _build_fountains() -> void:
	var g: Node3D = director.geometry
	for fd: Variant in N.get("fountains", []):
		var f: Dictionary = fd
		var c: Vector3 = LevelKit.v3(f["p"])
		var r: float = float(f.get("r", 4.4))
		var h: float = float(f.get("h", 0.6))
		var segs: int = 14
		for i: int in segs:
			var a0: float = TAU * float(i) / segs
			var a1: float = TAU * float(i + 1) / segs
			NovaArt.beam(g, c + Vector3(cos(a0) * r, h * 0.5, sin(a0) * r), c + Vector3(cos(a1) * r, h * 0.5, sin(a1) * r),
				Vector2(0.5, h), f.get("rim", "#d8dee9"), true)
		LevelKit.cylinder(g, c + Vector3(0, h * 0.7, 0), r - 0.2, 0.04, "#7fdcff", false, "y", -1.0, 0.9)
		var col: float = float(f.get("column", 0.0))
		if col > 0.0:
			LevelKit.cylinder(g, c + Vector3(0, col * 0.5, 0), 0.5, col, f.get("rim", "#d8dee9"), true)
			LevelKit.cylinder(g, c + Vector3(0, col, 0), 1.6, 0.25, f.get("rim", "#d8dee9"), false)
			var spray: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.2
			cm.bottom_radius = 1.4
			cm.height = col * 0.6
			spray.mesh = cm
			spray.material_override = NovaArt.glow("#bff4ff", 0.25)
			spray.position = c + Vector3(0, col + col * 0.3, 0)
			g.add_child(spray)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = c + Vector3(0, 1.0, 0)
		light.light_color = LevelKit.color("#7fdcff")
		light.light_energy = 1.6
		light.omni_range = r * 2.2
		g.add_child(light)


func _build_billboards_neon() -> void:
	var g: Node3D = director.geometry
	for bd: Variant in N.get("billboards", []):
		var b: Dictionary = bd
		NovaArt.billboard(g, LevelKit.v3(b["p"]), LevelKit.v2(b.get("size", [8, 4])), float(b.get("ry", 0.0)), str(b.get("text", "")), b.get("color", "#3ee6ff"))
	for nd: Variant in N.get("neon", []):
		var n: Dictionary = nd
		NovaArt.neon_text(g, str(n["text"]), LevelKit.v3(n["p"]), float(n.get("px", 0.02)), n.get("color", "#3ee6ff"), float(n.get("ry", 0.0)))
	for sd: Variant in N.get("light_shafts", []):
		var s: Dictionary = sd
		var mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = float(s.get("r", 4.0))
		cm.bottom_radius = float(s.get("r", 4.0))
		cm.height = float(s.get("h", 14.0))
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		mi.material_override = NovaArt.glow(s.get("color", "#3ee6ff"), float(s.get("alpha", 0.06)))
		mi.position = LevelKit.v3(s["p"])
		g.add_child(mi)


func _build_highway() -> void:
	var H: Dictionary = N.get("highway", {})
	if H.is_empty():
		return
	var g: Node3D = director.geometry
	var pts: Array = H.get("points", [])
	var w: float = float(H.get("w", 5.0))
	for i: int in pts.size() - 1:
		var a: Vector3 = LevelKit.v3(pts[i])
		var b: Vector3 = LevelKit.v3(pts[i + 1])
		NovaArt.beam(g, a, b, Vector2(w, 0.8), "#141a30", false)
		for s: float in [-1.0, 1.0]:
			var d: Vector3 = (b - a).normalized()
			var side: Vector3 = Vector3(-d.z, 0, d.x) * (w * 0.5 - 0.1) * s
			NovaArt.beam(g, a + side + Vector3(0, 0.6, 0), b + side + Vector3(0, 0.6, 0), Vector2(0.15, 0.4), "#ff4d9d", false, 1.2)
	for pd: Variant in H.get("pillars", []):
		var p: Array = pd
		var top: float = float(H.get("y", 14.0)) - 0.4
		LevelKit.box(g, Vector3(float(p[0]), top * 0.5, float(p[1])), Vector3(1.4, top, 1.4), "#1a2240", true)


# ------------------------------------------------------------------ traversal + HOA

func _build_walkways() -> void:
	for wd: Variant in N.get("walkways", []):
		var r: Dictionary = wd
		var w: NovaWalkway = NovaWalkway.new()
		w.name = "Walkway_" + str(r["id"])
		w.walkway_id = str(r["id"])
		w.district = str(r.get("district", ""))
		w.from = LevelKit.v3(r["from"])
		w.to = LevelKit.v3(r["to"])
		w.width = float(r.get("w", 4.0))
		w.carry = float(r.get("carry", float(N.get("walkway_carry", 2.5))))
		w.force = float(r.get("force", float(N.get("walkway_force", 10.0))))
		w.reverse_default = float((N.get("hoa", {}) as Dictionary).get("reverse", 6.0))
		director.geometry.add_child(w)
		walkways[w.walkway_id] = w
		director.nodes["walkway." + w.walkway_id] = w
		compliance.add_walkway(w)


func _build_lamp_posts() -> void:
	for ld: Variant in N.get("lamp_posts", []):
		var r: Dictionary = ld
		var lp: NovaLampPost = NovaLampPost.new()
		lp.name = "Lamp_" + str(r["id"])
		lp.post_id = str(r["id"])
		lp.district = str(r.get("district", ""))
		lp.tether = bool(r.get("tether", true))
		lp.ring_h = float(r.get("ring_h", 7.0))
		lp.height = float(r.get("h", 6.5))
		lp.with_light = bool(r.get("light", true))
		lp.position = LevelKit.v3(r["p"])
		lp.rotation_degrees.y = float(r.get("ry", 0.0))
		director.geometry.add_child(lp)
		lamp_posts[lp.post_id] = lp
		director.nodes["lamp_post." + lp.post_id] = lp
		if lp.district != "":
			compliance.add_lamp(lp)
		if lp.tether:
			tether_points += 1
	# arena lamp posts belong to the FineTree district too (added in _build_arena)


func _build_eyes() -> void:
	for ed: Variant in N.get("eyes", []):
		var r: Dictionary = ed
		var e: ComplianceEye = ComplianceEye.new()
		e.name = "Eye_" + str(r["id"])
		e.eye_id = str(r["id"])
		e.district = str(r.get("district", ""))
		e.position = LevelKit.v3(r["p"])
		e.look = LevelKit.v3(r.get("look", r["p"]))
		var H: Dictionary = N.get("hoa", {})
		e.view_range = float(H.get("eye_range", 14.0))
		e.cone_deg = float(H.get("eye_cone", 40.0))
		e.blind_time = float(H.get("blind", 20.0))
		if r.has("watches"):
			e.watches = PackedStringArray(r["watches"])
		e.on_violation = r.get("on_violation", [])
		e.once = bool(r.get("once", false))
		director.geometry.add_child(e)
		eyes[e.eye_id] = e
		director.nodes["eye." + e.eye_id] = e
		compliance.add_eye(e)


func _build_updrafts() -> void:
	for ud: Variant in N.get("updrafts", []):
		var r: Dictionary = ud
		var u: NovaUpdraft = NovaUpdraft.new()
		u.name = "Updraft_" + str(r["id"])
		u.updraft_id = str(r["id"])
		u.radius = float(r.get("r", 3.0))
		u.height = float(r.get("h", 12.0))
		u.force = float(r.get("force", 30.0))
		u.cap = float(r.get("cap", 11.0))
		u.gravity_comp = float(r.get("gravity_comp", 58.0))
		u.liftoff = float(r.get("liftoff", 3.0))
		u.position = LevelKit.v3(r["p"])
		director.geometry.add_child(u)
		updrafts[u.updraft_id] = u
		director.nodes["updraft." + u.updraft_id] = u


# ------------------------------------------------------------------ Transit Loop

func _build_loop() -> void:
	var L: Dictionary = N.get("loop", {})
	if L.is_empty():
		return
	var g: Node3D = director.geometry
	var c: Vector2 = LevelKit.v2(L.get("center", [0, -46]))
	var rx: float = float(L.get("rx", 22.0))
	var rz: float = float(L.get("rz", 36.0))
	var y: float = float(L.get("y", 12.0))
	var segs: int = int(L.get("segments", 32))
	var broken: Array = L.get("broken_spans", [])
	var skip: Array[Rect2] = []
	for r: Variant in L.get("no_pillars", []):
		var a: Array = r
		skip.append(Rect2(Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))))
	# the monorail beam (deco) and the golden maintenance ride-rail under it (markers in group "rails")
	var rail_pts: Array = []
	for i: int in segs + 1:
		var t0: float = TAU * float(i) / segs - PI
		rail_pts.append(NovaTrain.point_at(c, rx, rz, y - 1.4, t0))
	for i: int in segs:
		var t0: float = TAU * float(i) / segs - PI
		var t1: float = TAU * float(i + 1) / segs - PI
		var a: Vector3 = NovaTrain.point_at(c, rx, rz, y - 0.75, t0)
		var b: Vector3 = NovaTrain.point_at(c, rx, rz, y - 0.75, t1)
		NovaArt.beam(g, a, b, Vector2(1.4, 0.9), "#d8dee9", false)
		NovaArt.beam(g, a + Vector3(0, -0.5, 0), b + Vector3(0, -0.5, 0), Vector2(1.5, 0.1), "#3ee6ff", false, 1.0)
		var is_broken: bool = false
		for bk: Variant in broken:
			if i == int(bk):
				is_broken = true
		if not is_broken:
			NovaArt.beam(g, a + Vector3(0, -0.75, 0), b + Vector3(0, -0.75, 0), Vector2(0.14, 0.14), "#ffd23e", false, 1.2)
		if i % 2 == 0:
			var foot: Vector2 = Vector2(a.x, a.z)
			var ok: bool = true
			for r2: Rect2 in skip:
				if r2.has_point(foot):
					ok = false
			if ok:
				LevelKit.box(g, Vector3(a.x, (y - 1.2) * 0.5, a.z), Vector3(0.9, y - 1.2, 0.9), "#5a6377", true)
	var rail: Node3D = Node3D.new()
	rail.name = "Rail_loop_maintenance"
	rail.add_to_group(&"rails")
	var pts: PackedVector3Array = []
	for p: Variant in rail_pts:
		pts.append(p as Vector3)
	rail.set_meta(&"points", pts)
	rail.set_meta(&"rail_id", "loop_maintenance")
	rail.set_meta(&"two_way", true)
	rail.set_meta(&"loop", true)
	rail.set_meta(&"broken_spans", broken)
	director.dynamic.add_child(rail)
	director.nodes["loop_maintenance"] = rail
	# the car
	var TD: Dictionary = L.get("train", {})
	train = NovaTrain.new()
	train.name = "TransitLoopCar"
	train.center = c
	train.rx = rx
	train.rz = rz
	train.floor_y = y
	train.speed = float(TD.get("speed", 9.0))
	var st: Dictionary = L.get("stations", {})
	for k: String in st.keys():
		train.stations[k] = float(st[k])
	train.station = str(TD.get("station", "civic"))
	director.dynamic.add_child(train)
	director.nodes["train"] = train


# ------------------------------------------------------------------ the arena, the core

func _build_arena() -> void:
	var AD: Dictionary = N.get("arena", {})
	if AD.is_empty():
		return
	arena = FineTreeArena.new()
	arena.name = "FineTreeArena"
	arena.setup(AD)
	arena.position = LevelKit.v3(AD.get("p", [0, 6, -100]))
	director.geometry.add_child(arena)
	director.nodes["arena"] = arena
	for w: NovaWalkway in arena.walkways:
		walkways[w.walkway_id] = w
		compliance.add_walkway(w)
	for lp: Node in arena.get_node("LampPosts").get_children():
		compliance.add_lamp(lp as NovaLampPost)
		tether_points += 1


func _build_core() -> void:
	var CD: Dictionary = N.get("core", {})
	if CD.is_empty():
		return
	var flag_id: String = str(CD.get("flag", "core." + director.level_id))
	if BS.flag(flag_id):
		return
	core = NovaCore.new()
	core.name = "KeystoneCore"
	core.core_flag = flag_id
	core.actions = CD.get("actions", [])
	core.director = director
	core.position = LevelKit.v3(CD["p"]) if CD.has("p") else (arena.core_position() if arena != null else Vector3.ZERO)
	director.dynamic.add_child(core)
	director.nodes["core"] = core
	core.reveal(false)


## Quest items placed by this level (BS_LEVELS §4.8 placements) instead of quests.json's source spots.
func _build_quest_items() -> void:
	var i: int = 0
	for qd: Variant in N.get("quest_items", []):
		var r: Dictionary = qd
		var qi: QuestItem = QuestItem.new()
		qi.name = "QuestItem_%s_%d" % [r["quest"], i]
		qi.quest_id = str(r["quest"])
		qi.item = str(r.get("item", ""))
		qi.position = LevelKit.v3(r["p"])
		director.dynamic.add_child(qi)
		director.quest_items.append(qi)
		director.nodes["%s.%d" % [qi.quest_id, i]] = qi
		i += 1


func _build_encounters() -> void:
	for ed: Variant in N.get("encounters", []):
		var r: Dictionary = ed
		var e: NovaEncounter = NovaEncounter.new()
		e.name = "Encounter_" + str(r["id"])
		e.encounter_id = str(r["id"])
		e.waves = r.get("waves", [])
		e.on_clear = r.get("on_clear", [])
		e.set_meta(&"autostart", bool(r.get("autostart", false)))
		e.set_meta(&"zone", str(r.get("zone", "")))
		e.cleared.connect(func(en: Encounter) -> void: director.run_actions(en.on_clear, en, director.bolt()))
		director.dynamic.add_child(e)
		director.encounters[e.encounter_id] = e


func _build_ambient() -> void:
	ambient = NovaAmbient.new()
	ambient.name = "Ambient"
	ambient.data = N.get("ambient", {})
	director.dynamic.add_child(ambient)
