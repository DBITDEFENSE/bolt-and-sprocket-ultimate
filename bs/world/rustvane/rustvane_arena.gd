class_name RustvaneArena
extends Node3D
## Rustvane Canyon's boss arenas, built from rustvane.json "arenas" by RustvaneArena.build(). The arena node is
## what the planet passes to the bosses:
##   EnemySpawner.spawn(&"rustvane_sentinel", <BossSpawn>, parent, {"arena": <QuarryArena>})
##   EnemySpawner.spawn(&"content_creator",   <BossSpawn>, parent, {"arena": <SunsetStageArena>})
##
## ============================== ARENA CONTRACT (for the bosses builder) ==============================
## Both arena roots are RustvaneArena (Node3D) with these metas and helpers:
##   meta "arena_id" (String "quarry" / "sunset"), meta "center" (Vector3, floor height), meta "size"
##   (Vector2 x/z extent in metres), meta "floor_y" (float)
##   center() -> Vector3   size() -> Vector2   floor_y() -> float   half() -> Vector2
##   anchor(name) -> Node3D (a child by name, or null)   markers(group_name) -> Array[Node3D] (its children)
##   contains(p) -> bool (inside the floor rectangle, any height)
##   add_spawn_points() -> Array[Vector3]   set_gate(open: bool)
## Container nodes are named so that no container matches a prefix the bosses search for (PatternBoss
## anchors("Pillar") / ("AddSpawn") / ("Cabana") / ("DroneSpawn") collect every descendant whose name starts
## with the prefix): QuarryPillars, Adds, Shade, Umbrellas, Masts, Cover, ZipCables, PoolTiles.
##
## QuarryArena: THE QUARRY FLOOR in the Strip Mine (the Rustvane Sentinel; later the Poolside Pile-Up).
##   centre (100, 0.5, -58), 34 x 26 m, floor y 0.5; the long axis runs east-west (x).
##   Center, BossSpawn (south part of the floor), PlayerEntry (west edge, where the grind rail lands)
##   Gate               LevelGate on the west entry (closed while the fight runs; director data opens it)
##   QuarryPillars/Pillar_1..4  StaticBody3D sandstone pillars (1.8 x 7 x 1.8), group "arena_pillars",
##                          meta "radius" 1.3: ram targets for the Phase 3 tread charge (+40% BREAK self-stun)
##   Cover/Mound_1..5       Node3D gravel mounds (two solid stacked cylinders each), group "arena_cover":
##                          they block beams, not mortars
##   ZipCables/Cable_1..2   overhead zip cables at 10 m (golden rails, rideable); CableRing_1..2 TetherPoints
##                          (swing) under them: the Tether-Hook escape routes
##   Terrace                the raised east terrace (top y 5.5) the challenge's updraft lifts Bolt to
##   Searchlight            Marker3D mount for the Phase 2 searchlight (on the east terrace, 7 m up)
##   Adds/AddSpawn_1..3     Marker3D: where Phase 3 Ambassadogs come in (the west and south rims)
##   PlungePool             Marker3D at the centre plunge pool; meta "aabb" (AABB) of its water
##
## SunsetStageArena: the Sunset Stage / Infinity Lava Pool deck (The Content Creator).
##   centre (0, 8.4, -116), 32 x 24 m, deck y 8.4; north (-z) is the infinity edge over the lava falls.
##   Center             Marker3D at the SHOW POOL's centre (0, 8.4, -112), 4 m south of the deck centre (meta
##                      "center" stays the deck centre): what ContentCreator orbits
##   Pool               Marker3D at the show pool's centre; meta "radius" (the pool's inscribed radius, 3.2 m),
##                      meta "surface_y" (8.5), meta "aabb" (AABB of the rectangular 11.8 x 6.4 water)
##   Deck               Marker3D at the deck centre; meta "outer_radius" (11.5: the deck ring's usable edge)
##   PlayerEntry (the VIP gate, south edge), BossSpawn (= the HoverStage mount at fight start)
##   Gate               the VIP gate (LevelGate, south edge; opens on WRISTBAND + SECURITY, closes in the fight)
##   HoverStage         HoverStage (AnimatableBody3D) over the north edge; set_mode(&"low"/&"drift"/&"high"/
##                      &"parked"); its "Mount" child is where the Creator stands. The director switches the
##                      modes at the HP thresholds in "bosses.content_creator.phases"; the boss may call
##                      set_stage_mode() itself.
##   HoverPath/HoverPath_W, HoverPath_C, HoverPath_E   Marker3D along the north edge, 4 m above the deck
##   Masts/Mast_NW, Mast_NE, Mast_SW, Mast_SE   Node3D at the deck corners, 12 m tall; each has
##                      Ring (TetherPoint swing ring at 8 m) and DroneSpawn_<corner> (Marker3D at the top,
##                      12 m: the camera drones dock on the masts, so swinging from a mast reaches a drone)
##   Shade/Cabana_W, Cabana_E   Node3D cabanas (positioned at the cabana's centre) on the wings; roof
##                      walkable at +2.5 m (the shade in "Going live"); meta "destructible" true; ammo orbs
##                      spawn at them
##   Umbrellas/Parasol_W, Parasol_E   BounceUmbrella (power 16)
##   ShowPool           alias of Pool (same metas) for the planet's own use
##   PoolTiles/Tile_<i>_<j>   Marker3D on a 2 m grid over the deck ring around the pool (the LIKE-button
##                      floor); meta "row", "col"
##   AmmoSpots/Ammo_W, Ammo_E   Marker3D at the two cabanas (ammo orbs spawn here)
##   BoxDrop            Marker3D centre of the unboxing drop zone; meta "radius" (float)
##   InfinityEdge       Marker3D at the north edge centre (falling past it is the lava kill plane)
##   Adds/AddSpawn_1..4     Marker3D: the camera crew, the fans and the box drops' spill points
## ======================================================================================================

var arena_id: String = ""
var director: Node = null
var hover_stage: HoverStage = null
var gate: LevelGate = null


func center() -> Vector3:
	return get_meta(&"center", global_position)


func size() -> Vector2:
	return get_meta(&"size", Vector2(20, 20))


func half() -> Vector2:
	return size() * 0.5


func floor_y() -> float:
	return float(get_meta(&"floor_y", global_position.y))


func anchor(n: String) -> Node3D:
	return find_child(n, true, false) as Node3D


func markers(group_name: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var g: Node = get_node_or_null(NodePath(group_name))
	if g != null:
		for c: Node in g.get_children():
			if c is Node3D:
				out.append(c as Node3D)
	return out


func contains(p: Vector3) -> bool:
	var c: Vector3 = center()
	var h: Vector2 = half()
	return absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.y


func add_spawn_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m: Node3D in markers("Adds"):
		out.append(m.global_position)
	return out


func set_gate(open: bool) -> void:
	if gate == null:
		return
	if open:
		gate.open()
	else:
		gate.close()


func set_stage_mode(m: StringName) -> void:
	if hover_stage != null:
		hover_stage.set_mode(m)


# ------------------------------------------------------------------ builder

static func _marker(parent: Node3D, n: String, p: Vector3) -> Marker3D:
	var m: Marker3D = Marker3D.new()
	m.name = n
	parent.add_child(m)
	m.global_position = p
	return m


static func _group(parent: Node3D, n: String) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


## Builds one arena under `parent` (the director's navmesh-baked geometry, so cover is baked as obstacles).
## Gates are registered with the director (data actions {"open": id} / {"close": id} work on them).
static func build(parent: Node3D, id: String, cfg: Dictionary, dir: Node) -> RustvaneArena:
	var a: RustvaneArena = RustvaneArena.new()
	a.name = str(cfg.get("node", id.to_pascal_case() + "Arena"))
	a.arena_id = id
	a.director = dir
	parent.add_child(a)
	var c: Vector3 = LevelKit.v3(cfg.get("center"))
	a.set_meta(&"arena_id", id)
	a.set_meta(&"center", c)
	a.set_meta(&"size", LevelKit.v2(cfg.get("size"), Vector2(30, 24)))
	a.set_meta(&"floor_y", c.y)
	_marker(a, "Center", LevelKit.v3(cfg.get("center_marker"), c))
	_marker(a, "BossSpawn", LevelKit.v3(cfg.get("boss_spawn"), c))
	_marker(a, "PlayerEntry", LevelKit.v3(cfg.get("entry"), c))
	if cfg.has("gate"):
		var gd: Dictionary = cfg["gate"]
		var g: LevelGate = LevelGate.new()
		g.name = "Gate"
		g.gate_id = str(gd.get("id", id + "_gate"))
		g.size = LevelKit.v3(gd.get("s"), Vector3(6, 4, 0.6))
		g.open_offset = LevelKit.v3(gd.get("open"), Vector3(0, -4.2, 0))
		g.speed = float(gd.get("speed", 3.0))
		g.gate_color = gd.get("color", "#5a6377")
		g.start_open = bool(gd.get("start_open", false))
		g.position = LevelKit.v3(gd.get("p")) - a.global_position
		a.add_child(g)
		a.gate = g
		if dir != null and "gates" in dir:
			(dir.get("gates") as Dictionary)[g.gate_id] = g
			(dir.get("nodes") as Dictionary)[g.gate_id] = g
	var adds: Node3D = _group(a, "Adds")
	var i: int = 0
	for p: Variant in cfg.get("add_spawns", []):
		i += 1
		_marker(adds, "AddSpawn_%d" % i, LevelKit.v3(p))
	if id == "quarry" or str(cfg.get("kind", "")) == "quarry":
		_build_quarry(a, cfg)
	else:
		_build_sunset(a, cfg)
	return a


static func _build_quarry(a: RustvaneArena, cfg: Dictionary) -> void:
	var fy: float = a.floor_y()
	var pillars: Node3D = _group(a, "QuarryPillars")
	var i: int = 0
	for p: Variant in cfg.get("pillars", []):
		i += 1
		var v: Vector2 = LevelKit.v2(p)
		var h: float = float(cfg.get("pillar_h", 7.0))
		var body: Node3D = LevelKit.box(pillars, Vector3(v.x, fy + h * 0.5, v.y), Vector3(1.8, h, 1.8), "#9e4a32", true)
		body.name = "Pillar_%d" % i
		body.add_to_group(&"arena_pillars")
		body.set_meta(&"radius", 1.3)
		LevelKit.box(body, Vector3(0, h * 0.5 + 0.2, 0), Vector3(2.4, 0.4, 2.4), "#74301f", false)
		LevelKit.box(body, Vector3(0, -h * 0.5 + 0.5, 0), Vector3(2.2, 1.0, 2.2), "#74301f", false)
	var cover: Node3D = _group(a, "Cover")
	i = 0
	for m: Variant in cfg.get("mounds", []):
		i += 1
		var md: Array = m
		var mound: Node3D = Node3D.new()
		mound.name = "Mound_%d" % i
		mound.add_to_group(&"arena_cover")
		cover.add_child(mound)
		LevelKit.mound(mound, float(md[0]), float(md[1]), fy, float(md[2]), float(md[3]), "#c8955a")
	var cables: Node3D = _group(a, "ZipCables")
	i = 0
	for cb: Variant in cfg.get("cables", []):
		i += 1
		var cd: Dictionary = cb
		var from: Vector3 = LevelKit.v3(cd.get("from"))
		var to: Vector3 = LevelKit.v3(cd.get("to"))
		var rail: Node3D = Node3D.new()
		rail.name = "Cable_%d" % i
		rail.add_to_group(&"rails")
		rail.set_meta(&"points", PackedVector3Array([from, to]))
		rail.set_meta(&"two_way", true)
		rail.set_meta(&"rail_id", "quarry_cable_%d" % i)
		cables.add_child(rail)
		var mid: Vector3 = (from + to) * 0.5
		var seg: Node3D = LevelKit.box(rail, mid, Vector3(0.12, 0.12, from.distance_to(to)), "#3ee6ff", false, Vector3.ZERO, 1, 1.0)
		seg.look_at_from_position(mid, to, Vector3.UP)
		for end: Vector3 in [from, to]:
			LevelKit.box(rail, Vector3(end.x, (fy + end.y) * 0.5, end.z), Vector3(0.6, end.y - fy, 0.6), "#5a6377", false)
		if cd.has("ring"):
			var tp: TetherPoint = TetherPoint.new()
			tp.name = "CableRing_%d" % i
			cables.add_child(tp)
			tp.global_position = LevelKit.v3(cd["ring"])
	if cfg.has("terrace"):
		var t: Marker3D = _marker(a, "Terrace", LevelKit.v3(cfg["terrace"]))
		t.set_meta(&"top_y", float(LevelKit.v3(cfg["terrace"]).y))
	_marker(a, "Searchlight", LevelKit.v3(cfg.get("searchlight"), a.center() + Vector3(0, 7, 0)))
	var pool: Marker3D = _marker(a, "PlungePool", LevelKit.v3(cfg.get("plunge_pool"), a.center()))
	var ps: Vector3 = LevelKit.v3(cfg.get("plunge_size"), Vector3(6, 1, 6))
	pool.set_meta(&"aabb", AABB(pool.global_position - ps * 0.5, ps))


static func _build_sunset(a: RustvaneArena, cfg: Dictionary) -> void:
	var fy: float = a.floor_y()
	var c: Vector3 = a.center()
	var h: Vector2 = a.half()
	# the hover-stage over the north infinity edge
	var hs: HoverStage = HoverStage.new()
	hs.name = "HoverStage"
	hs.deck_y = fy
	hs.edge_center = LevelKit.v3(cfg.get("edge_center"), Vector3(c.x, fy, c.z - h.y - 2.5))
	var st: Dictionary = cfg.get("stage", {})
	hs.low_h = float(st.get("low_h", 4.0))
	hs.high_h = float(st.get("high_h", 8.0))
	hs.drift_half = float(st.get("drift_half", 9.0))
	hs.drift_speed = float(st.get("drift_speed", 0.35))
	hs.move_speed = float(st.get("move_speed", 3.0))
	a.add_child(hs)
	a.hover_stage = hs
	var boss_spawn: Node3D = a.get_node("BossSpawn") as Node3D
	boss_spawn.global_position = hs.edge_center + Vector3(0, hs.low_h + 0.25, 0)
	var path: Node3D = _group(a, "HoverPath")
	for side: Array in [["HoverPath_W", -1.0], ["HoverPath_C", 0.0], ["HoverPath_E", 1.0]]:
		_marker(path, str(side[0]), hs.edge_center + Vector3(float(side[1]) * hs.drift_half, hs.low_h, 0))
	_marker(a, "InfinityEdge", Vector3(c.x, fy, c.z - h.y)).set_meta(&"z", c.z - h.y)
	# camera masts at the corners, 12 m, ring at 8 m
	var masts: Node3D = _group(a, "Masts")
	var mh: float = float(cfg.get("mast_h", 12.0))
	var ring_h: float = float(cfg.get("mast_ring_h", 8.0))
	for m: Array in [["Mast_NW", -1.0, -1.0], ["Mast_NE", 1.0, -1.0], ["Mast_SW", -1.0, 1.0], ["Mast_SE", 1.0, 1.0]]:
		var mast: Node3D = Node3D.new()
		mast.name = str(m[0])
		masts.add_child(mast)
		mast.global_position = Vector3(c.x + float(m[1]) * (h.x - 0.8), fy, c.z + float(m[2]) * (h.y - 0.8))
		var pole: Node3D = LevelKit.box(mast, Vector3(0, mh * 0.5, 0), Vector3(0.45, mh, 0.45), "#8a95a8", true)
		pole.name = "Pole"
		LevelKit.box(mast, Vector3(0, mh, 0), Vector3(1.6, 0.3, 1.6), "#39404f", false)
		LevelKit.cylinder(mast, Vector3(0, mh + 0.5, 0), 0.4, 0.6, "#c06aff", false, "y", -1.0, 1.2)
		var ring: TetherPoint = TetherPoint.new()
		ring.name = "Ring"
		# the ring hangs off the canyon-facing side of the pole, toward the deck centre
		ring.position = Vector3(-float(m[1]) * 0.9, ring_h, -float(m[2]) * 0.9)
		mast.add_child(ring)
		var dock: Marker3D = Marker3D.new()
		dock.name = "DroneSpawn_" + str(m[0]).trim_prefix("Mast_")
		dock.position = Vector3(0, mh + 0.2, 0)
		mast.add_child(dock)
	# cabanas on the raised wings, parasols as bounce pads
	var cab: Node3D = _group(a, "Shade")
	for cb: Array in [["Cabana_W", cfg.get("cabana_w")], ["Cabana_E", cfg.get("cabana_e")]]:
		if cb[1] == null:
			continue
		var node: Node3D = Node3D.new()
		node.name = str(cb[0])
		node.set_meta(&"destructible", true)
		node.add_to_group(&"arena_cover")
		cab.add_child(node)
		node.global_position = LevelKit.v3(cb[1])
		RustvaneDressing.cabana(node, Vector3.ZERO, 0.0, true)
	var par: Node3D = _group(a, "Umbrellas")
	for pr: Array in [["Parasol_W", cfg.get("parasol_w")], ["Parasol_E", cfg.get("parasol_e")]]:
		if pr[1] == null:
			continue
		var u: BounceUmbrella = BounceUmbrella.new()
		u.name = str(pr[0])
		u.power = float(cfg.get("parasol_power", 16.0))
		u.color = "#ff6ac2" if str(pr[0]).ends_with("W") else "#6fd4ff"
		par.add_child(u)
		u.global_position = LevelKit.v3(pr[1])
	var psz: Vector3 = LevelKit.v3(cfg.get("pool_size"), Vector3(11.8, 1.2, 6.4))
	var pool: Marker3D = null
	for pn: String in ["Pool", "ShowPool"]:
		pool = _marker(a, pn, LevelKit.v3(cfg.get("pool_center"), c))
		pool.set_meta(&"aabb", AABB(pool.global_position - Vector3(psz.x, 0, psz.z) * 0.5 - Vector3(0, 0.5, 0), psz))
		pool.set_meta(&"scalding", true)
		pool.set_meta(&"radius", minf(psz.x, psz.z) * 0.5)
		pool.set_meta(&"surface_y", float(cfg.get("pool_surface_y", fy + 0.1)))
	_marker(a, "Deck", c).set_meta(&"outer_radius", float(cfg.get("deck_outer_radius", 11.5)))
	# the LIKE-button floor: a 2 m grid of tiles on the deck ring around the pool
	var tiles: Node3D = _group(a, "PoolTiles")
	var pa: AABB = pool.get_meta(&"aabb")
	var step: float = float(cfg.get("tile_step", 2.0))
	var nx: int = int(a.size().x / step)
	var nz: int = int(a.size().y / step)
	for ix: int in nx:
		for iz: int in nz:
			var tp: Vector3 = Vector3(c.x - h.x + step * (ix + 0.5), fy, c.z - h.y + step * (iz + 0.5))
			if pa.grow(0.8).has_point(Vector3(tp.x, pa.position.y + 0.1, tp.z)):
				continue
			var t: Marker3D = _marker(tiles, "Tile_%d_%d" % [ix, iz], tp)
			t.set_meta(&"row", iz)
			t.set_meta(&"col", ix)
	var ammo: Node3D = _group(a, "AmmoSpots")
	_marker(ammo, "Ammo_W", LevelKit.v3(cfg.get("ammo_w"), c + Vector3(-13, 0.8, 0)))
	_marker(ammo, "Ammo_E", LevelKit.v3(cfg.get("ammo_e"), c + Vector3(13, 0.8, 0)))
	_marker(a, "BoxDrop", LevelKit.v3(cfg.get("box_drop"), c)).set_meta(&"radius", float(cfg.get("box_drop_r", 10.0)))
