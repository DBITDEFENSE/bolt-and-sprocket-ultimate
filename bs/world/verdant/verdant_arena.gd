class_name VerdantArena
extends Node3D
## The Coolant Lagoon (BS_LEVELS §6.10, BS_ENEMIES §4.6): the Compost King's arena, built by the VerdantDirector
## from verdant.json "verdant.arena". The planet passes this node to the boss:
##   EnemySpawner.spawn(&"compost_king", arena.boss_spawn(), parent, {"arena": VerdantArena})
##
## ============================== ARENA CONTRACT (for the boss) ==============================
## Metas: "arena_id" ("lagoon"), "center" (Vector3), "size" (Vector2 x/z extent), "floor_y".
## Children (PatternBoss.anchor / anchors find them by name, recursively):
##   Center, BossSpawn       Marker3D
##   Valves/Valve_W|E|N      CoolantValve: the three coolant leaks (open = spraying, healing the King)
##   Murk/Murk_0..2          MurkPool thirds (drained one per sealed valve)
##   Cover/RootArch_0..3     StaticBody3D root arches (meta "radius") and Cluster_0..1 mushroom clusters
##   AddSpawn0..1            Marker3D where adds appear
##   Handshake               InteractPoint "SHAKE HANDS": enabled during the plea when every leak is sealed
##   Spectators              the picket corn on the west rim ledge (they cheer for seals)
## Methods: open_leaks() -> int, sealed_count(), all_sealed(), set_leak(id, open), valve(id), valves(),
##   set_handshake(on), handshake_on(), boss_spawn(), center(), begin_fight(), end_fight(), drain_all().
## Signals: valve_sealed(id), valve_reopened(id), handshake(by), fight_changed(on).

signal valve_sealed(id: String)
signal valve_reopened(id: String)
signal handshake(by: Node)
signal fight_changed(on: bool)

var A: Dictionary = {}
var director: LevelDirector = null
var valves_by_id: Dictionary = {}       # "W" -> CoolantValve
var murk_by_valve: Dictionary = {}      # "W" -> MurkPool
var murk_pools: Array[MurkPool] = []
var bouncer: BounceMushroom = null
var handshake_point: InteractPoint = null
var spectators: Array[Node3D] = []
var fighting: bool = false
var handshakes: int = 0
var _hand_on: bool = false
var _boss: Node3D = null


func setup(data: Dictionary, dir: LevelDirector) -> void:
	A = data
	director = dir
	set_meta(&"arena_id", "lagoon")
	set_meta(&"center", LevelKit.v3(A.get("center", [0, -0.3, -118])))
	set_meta(&"size", LevelKit.v2(A.get("size", [40, 32])))
	set_meta(&"floor_y", float(A.get("floor_y", -0.3)))


func _ready() -> void:
	_build()


func center() -> Vector3:
	return get_meta(&"center", Vector3.ZERO)


func boss_spawn() -> Vector3:
	return LevelKit.v3(A.get("boss_spawn"), center() + Vector3(0, 0, -6))


func _build() -> void:
	var c: Vector3 = center()
	PatternBoss.arena_marker(self, "Center", c - global_position)
	PatternBoss.arena_marker(self, "BossSpawn", boss_spawn() - global_position)
	var i: int = 0
	for ad: Variant in A.get("add_spawns", []):
		PatternBoss.arena_marker(self, "AddSpawn%d" % i, LevelKit.v3(ad) - global_position)
		i += 1
	# murk thirds
	var murk: Node3D = Node3D.new()
	murk.name = "Murk"
	add_child(murk)
	var M: Dictionary = (director.D.get("verdant", {}) as Dictionary).get("murk", {}) if director != null else {}
	i = 0
	for md: Variant in A.get("murk", []):
		var r: Dictionary = md
		var p: MurkPool = VerdantDirector.make_murk(r, M)
		p.name = "Murk_%d" % i
		murk.add_child(p)
		p.global_position = LevelKit.v3(r["p"])
		murk_pools.append(p)
		if director != null:
			director.nodes["murk." + p.pool_id] = p
		i += 1
	# cover: root arches and mushroom clusters
	var cover: Node3D = Node3D.new()
	cover.name = "Cover"
	add_child(cover)
	i = 0
	for ar: Variant in A.get("arches", []):
		var a: Array = ar
		var root: StaticBody3D = StaticBody3D.new()
		root.name = "RootArch_%d" % i
		root.collision_layer = 1
		root.set_meta(&"radius", 1.6)
		cover.add_child(root)
		root.global_position = Vector3(float(a[0]), float(A.get("floor_y", -0.3)), float(a[1]))
		root.rotation_degrees.y = float(a[2]) if a.size() > 2 else 0.0
		VerdantDressing.root_arch(root, Vector3.ZERO, 2.5, 3.2)
		i += 1
	i = 0
	for cl: Variant in A.get("clusters", []):
		var a: Array = cl
		var n: Node3D = Node3D.new()
		n.name = "Cluster_%d" % i
		cover.add_child(n)
		n.global_position = Vector3(float(a[0]), float(A.get("floor_y", -0.3)), float(a[1]))
		VerdantDressing.mushroom_cluster(n, Vector3.ZERO, 5 + i, true)
		i += 1
	# the valves and their leaks
	var vals: Node3D = Node3D.new()
	vals.name = "Valves"
	add_child(vals)
	var L: Dictionary = A.get("leak", {})
	for vd: Variant in A.get("valves", []):
		var r: Dictionary = vd
		var v: CoolantValve = CoolantValve.new()
		v.valve_id = str(r["id"])
		v.name = "Valve_" + v.valve_id
		v.jet = LevelKit.v3(r.get("jet", r["p"]))
		v.jet_r = float(L.get("r", 1.8))
		v.jet_dmg = float(L.get("dmg", 4.0))
		v.jet_every = float(L.get("every", 0.5))
		vals.add_child(v)
		v.global_position = LevelKit.v3(r["p"])
		v.look_at(Vector3(c.x, v.global_position.y, c.z), Vector3.UP)
		v.call(&"_layout_jet")
		valves_by_id[v.valve_id] = v
		var mid: String = str(r.get("murk", ""))
		for p: MurkPool in murk_pools:
			if p.pool_id == mid:
				murk_by_valve[v.valve_id] = p
		v.sealed.connect(_on_valve_sealed)
		v.reopened.connect(_on_valve_reopened)
		if director != null:
			director.nodes["valve." + v.valve_id] = v
	# the bounce mushroom up to the E valve
	if A.has("bouncer"):
		var bd: Dictionary = A["bouncer"]
		bouncer = BounceMushroom.new()
		bouncer.name = "Bouncer_E"
		bouncer.bouncer_id = "lagoon_e"
		bouncer.power = float(bd.get("power", 22.0))
		bouncer.color = "#5affc8"
		add_child(bouncer)
		bouncer.global_position = LevelKit.v3(bd["p"])
	# the spectators' rim ledge (picket corn cheer for seals)
	var SP: Dictionary = A.get("spectators", {})
	if not SP.is_empty():
		var sp: Node3D = Node3D.new()
		sp.name = "Spectators"
		add_child(sp)
		var lp: Vector3 = LevelKit.v3(SP.get("ledge", [-23.5, 3, -118]))
		var ls: Vector3 = LevelKit.v3(SP.get("size", [4, 0.4, 14]))
		var ledge: StaticBody3D = StaticBody3D.new()
		ledge.name = "SpectatorLedge"
		ledge.collision_layer = 1
		sp.add_child(ledge)
		ledge.global_position = lp
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = ls
		cs.shape = sh
		cs.position.y = -ls.y * 0.5
		ledge.add_child(cs)
		LevelKit.box(ledge, Vector3(0, -ls.y * 0.5, 0), ls, "#3b2a1e", false)
		var n: int = int(SP.get("count", 5))
		for k: int in n:
			var at: Vector3 = lp + Vector3(0, 0.2, -ls.z * 0.4 + ls.z * 0.8 * float(k) / maxf(1.0, float(n - 1)))
			var corn: Node3D = VerdantDirector.spawn_corn(at, sp, {"loop_r": 0.0, "spectator": true})
			if corn != null:
				spectators.append(corn)
	# the handshake (mercy) interact: enabled only during the plea with every leak sealed
	handshake_point = InteractPoint.new()
	handshake_point.name = "Handshake"
	handshake_point.prompt = "SHAKE HANDS"
	handshake_point.radius = float(A.get("handshake_radius", 4.5))
	handshake_point.interacted.connect(func(_p: InteractPoint, b: Node) -> void:
		if _hand_on:
			handshakes += 1
			handshake.emit(b))
	add_child(handshake_point)
	handshake_point.global_position = boss_spawn()
	handshake_point.enabled = false
	handshake_point.visible = false


# ------------------------------------------------------------------ leaks

func valve(id: String) -> CoolantValve:
	return valves_by_id.get(id) as CoolantValve


func valves() -> Array[CoolantValve]:
	var out: Array[CoolantValve] = []
	for v: Variant in valves_by_id.values():
		out.append(v as CoolantValve)
	return out


func open_leaks() -> int:
	var n: int = 0
	for v: CoolantValve in valves():
		if v.open:
			n += 1
	return n


func sealed_count() -> int:
	return valves_by_id.size() - open_leaks()


func all_sealed() -> bool:
	return open_leaks() == 0 and not valves_by_id.is_empty()


func set_leak(id: String, on: bool) -> void:
	var v: CoolantValve = valve(id)
	if v != null:
		v.set_open(on)


## Phase 1 starts with one leak open (the first valve); the others burst at phase 2.
func set_initial_leaks(open_ids: Array) -> void:
	for v: CoolantValve in valves():
		v.set_open(v.valve_id in open_ids)


func _on_valve_sealed(v: CoolantValve) -> void:
	var p: MurkPool = murk_by_valve.get(v.valve_id) as MurkPool
	if p != null:
		p.set_drained(true)
	for s: Node3D in spectators:
		if is_instance_valid(s) and s.has_method("cheer"):
			s.call("cheer", 2.5)
	valve_sealed.emit(v.valve_id)


func _on_valve_reopened(v: CoolantValve) -> void:
	var p: MurkPool = murk_by_valve.get(v.valve_id) as MurkPool
	if p != null:
		p.set_drained(false)
	valve_reopened.emit(v.valve_id)


func drain_all() -> void:
	for p: MurkPool in murk_pools:
		p.set_drained(true)


# ------------------------------------------------------------------ the fight

func begin_fight(boss: Node3D = null) -> void:
	fighting = true
	_boss = boss
	fight_changed.emit(true)


func end_fight() -> void:
	fighting = false
	set_handshake(false)
	fight_changed.emit(false)


func set_handshake(on: bool) -> void:
	_hand_on = on
	if handshake_point != null:
		handshake_point.enabled = on
		handshake_point.visible = on
		if not on:
			handshake_point.prompt = ""
		else:
			handshake_point.prompt = "SHAKE HANDS"
	for s: Node3D in spectators:
		if is_instance_valid(s) and s.has_method("chant_deal"):
			s.call("chant_deal", on)


func handshake_on() -> bool:
	return _hand_on


func _physics_process(_delta: float) -> void:
	if _hand_on and _boss != null and is_instance_valid(_boss) and handshake_point != null:
		handshake_point.global_position = _boss.global_position
