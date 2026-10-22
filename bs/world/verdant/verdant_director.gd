class_name VerdantDirector
extends LevelDirector
## Verdant Sink's director: the shared LevelDirector (data/bs/levels/verdant.json) plus what this planet adds,
## all from the data's "verdant" table:
##   "murk_pools"   MurkPool zones (slow + tick damage + the swamp bark)     "bouncers"  BounceMushroom pads
##   "drums"        ThreshingDrum rotating platforms in the harvester guts   "corn_groups"  Picket Corn loops
##   "quest_items"  q7b sealant cores at the BS_LEVELS §6.8 spots            "arena"     the VerdantArena (lagoon)
##   "core"         the Keystone Core (NovaCore) revealed when the King falls or stands down
##   "glide"        the sail: GadgetManager.grant(sprocket_glide) + the vd_glide scene   "popup"  the Picket Line
## Plus the generic extras Rustvane introduced: "rails" rows take "end"/"posts" (the grain boom's ZipRider),
## "updrafts" (CanyonUpdraft, the S6 vault), "tether_points" (S7 rings), gates with "start_open", "hidden_groups".
## The boss flow (the Compost King, BS_ENEMIES §4.6) lives here so a plain test host can run it: start_compost()
## spawns through EnemySpawner with {"arena": VerdantArena} (a TestDummy stand-in when the id is missing),
## relays sealed valves to the boss's BREAK feeder, the arena's handshake to the mercy ending, and runs the data's
## boss.phases / on_defeat. Host calls the data uses ({"host": ...}) resolve on the director first.

signal boss_started_vd(boss: Node3D)
signal popup_finished(won: bool)

var murk_pools: Dictionary = {}       # id -> MurkPool
var bouncers: Dictionary = {}         # id -> BounceMushroom
var drums: Dictionary = {}            # id -> ThreshingDrum
var corn_groups: Dictionary = {}      # id -> Array[Node3D]
var updrafts: Dictionary = {}         # id -> CanyonUpdraft
var tethers: Dictionary = {}          # id -> TetherPoint
var zip_rider: ZipRider = null
var arena: VerdantArena = null
var core: NovaCore = null
var level_cutscenes: Dictionary = {}
var glide_pennants: int = 0
var objectives: PackedStringArray = []
var corn_spawned: int = 0
var corn_stubbed: int = 0
# the boss
var boss_is_stand_in: bool = false
var boss_log: PackedStringArray = []
var boss_mercy: bool = false
var _boss_phases: Dictionary = {}
var _boss_max: float = 1.0
# the pop-up
var popup_running: bool = false
var popup_failed: bool = false
var popup_won: bool = false


func V() -> Dictionary:
	return D.get("verdant", {})


# ------------------------------------------------------------------ build

## Dressing and the arena go in before the bake so the navmesh sees the solid pieces.
func _bake_navmesh() -> void:
	var dress: Node3D = Node3D.new()
	dress.name = "Dressing"
	geometry.add_child(dress)
	_dress(dress)
	var AD: Dictionary = V().get("arena", {})
	if not AD.is_empty():
		arena = VerdantArena.new()
		arena.name = "LagoonArena"
		arena.setup(AD, self)
		geometry.add_child(arena)
		arena.global_position = LevelKit.v3(AD.get("center", [0, -0.3, -118]))
		nodes["arena"] = arena
		arena.valve_sealed.connect(_on_valve_sealed)
		arena.handshake.connect(_on_handshake)
	super._bake_navmesh()


## LevelDirector calls this after triggers and encounters; Verdant builds its moving and interactive pieces.
func _build_boss_arena() -> void:
	level_cutscenes = D.get("cutscenes", {})
	_build_rail_extras()
	zip_rider = ZipRider.new()
	zip_rider.name = "ZipRider"
	zip_rider.T = D.get("zip", {})
	dynamic.add_child(zip_rider)
	_build_murk()
	_build_bouncers()
	_build_drums()
	_build_updrafts()
	_build_tethers()
	_build_corn()
	_build_quest_items()
	_build_core()
	for m: Node in get_tree().get_nodes_in_group(&"gadget_points"):
		if is_ancestor_of(m) and str(m.get_meta(&"kind", "")) == "glide":
			glide_pennants += 1
	for gd: Variant in D.get("gates", []):
		if bool((gd as Dictionary).get("start_open", false)):
			var g: LevelGate = gates.get(str((gd as Dictionary)["id"]))
			if g != null:
				g.open(true)
	for hg: Variant in V().get("hidden_groups", []):
		var h: Dictionary = hg
		if not flag(str(h.get("unless", ""))):
			var n: Node3D = nodes.get(str(h["group"])) as Node3D
			if n != null:
				n.visible = false
				_set_group_collision(n, false)
				if n is InteractPoint:
					(n as InteractPoint).enabled = false


func _dress(root: Node3D) -> void:
	# glow-mushroom groves (deco) around the hub, the flats, the ridges and the annex; solid ones are the stalks (data)
	VerdantDressing.grove(root, Vector3(-18, -0.3, 10), 7.0, 9, 11)
	VerdantDressing.grove(root, Vector3(20, -0.3, 18), 6.0, 7, 12)
	VerdantDressing.grove(root, Vector3(-30, -0.3, -22), 9.0, 9, 13)
	VerdantDressing.grove(root, Vector3(30, -0.3, -10), 8.0, 9, 14)
	VerdantDressing.grove(root, Vector3(-50, -0.3, -30), 7.0, 7, 15)
	VerdantDressing.grove(root, Vector3(-96, -0.3, -18), 8.0, 9, 16)
	VerdantDressing.grove(root, Vector3(-60, -0.3, -84), 9.0, 9, 17)
	VerdantDressing.grove(root, Vector3(44, -0.3, -84), 8.0, 9, 18)
	VerdantDressing.grove(root, Vector3(-24, -0.3, -112), 6.0, 6, 19)
	VerdantDressing.grove(root, Vector3(40, -0.3, -120), 7.0, 7, 20)
	# root arches over the paths (deco; the lagoon's solid ones are in the arena)
	VerdantDressing.root_arch(root, Vector3(0, -0.3, -8), 3.2, 4.5)
	VerdantDressing.root_arch(root, Vector3(-20, -0.3, -34), 3.0, 4.0)
	VerdantDressing.root_arch(root, Vector3(16, -0.3, -30), 3.0, 4.0)
	VerdantDressing.root_arch(root, Vector3(-60, -0.3, -12), 3.4, 5.0)
	VerdantDressing.root_arch(root, Vector3(0, -0.3, -56), 3.4, 6.0)
	# the picket line's planted signs
	VerdantDressing.picket_sign(root, Vector3(-5, -0.3, -54), "bs.verdant.chant_01", 180.0)
	VerdantDressing.picket_sign(root, Vector3(5, -0.3, -54), "bs.verdant.chant_02", 180.0)
	VerdantDressing.picket_sign(root, Vector3(0, -0.3, -47.5), "bs.verdant.chant_03", 180.0)
	# the TerraFarm fence on the south rim and the lake shores
	VerdantDressing.fence(root, Vector3(-60, -0.3, 33), Vector3(60, -0.3, 33), 4.0)
	VerdantDressing.fence(root, Vector3(-32, -0.3, -58), Vector3(-12, -0.3, -58), 4.0)
	VerdantDressing.fence(root, Vector3(12, -0.3, -58), Vector3(32, -0.3, -58), 4.0)
	# glow-vines: the hub boardwalk, the silo rafters, the groves canopy
	VerdantDressing.glow_vine(root, Vector3(-8, 3.2, 27), Vector3(8, 3.2, 27), 1.0, "#5affc8")
	VerdantDressing.glow_vine(root, Vector3(-44, 15.5, -46), Vector3(-20, 15.5, -46), 2.5, "#ffd23e")
	VerdantDressing.glow_vine(root, Vector3(-44, 15.5, -64), Vector3(-20, 15.5, -64), 2.5, "#ff6ad5")
	VerdantDressing.glow_vine(root, Vector3(20, 9.0, -44), Vector3(34, 15.0, -54), 2.0, "#4fc3ff")
	VerdantDressing.glow_vine(root, Vector3(34, 15.0, -54), Vector3(46, 20.5, -62), 2.0, "#5affc8")
	# the harvester's south face: the dead intake, draped vines, its name
	VerdantDressing.harvester_face(root, Vector3(1, -0.3, -84))
	# ambient life (dynamic, deco): frog-bots on lily pads, firefly fields
	VerdantDressing.frog_bot(dynamic, Vector3(-14, -0.3, 8), 30.0)
	VerdantDressing.frog_bot(dynamic, Vector3(18, -0.3, -2), -60.0)
	VerdantDressing.frog_bot(dynamic, Vector3(-10, -0.3, -26), 120.0)
	VerdantDressing.frog_bot(dynamic, Vector3(26, -0.3, -24), 10.0)
	VerdantDressing.frog_bot(dynamic, Vector3(-28, -0.3, -108), 80.0)
	VerdantDressing.fireflies(dynamic, Vector3(0, 0.5, 0), 14.0, 16, 21)
	VerdantDressing.fireflies(dynamic, Vector3(0, 0.5, -30), 20.0, 18, 22)
	VerdantDressing.fireflies(dynamic, Vector3(32, 6.0, -55), 14.0, 16, 23)
	VerdantDressing.fireflies(dynamic, Vector3(-90, 0.5, -12), 14.0, 12, 24)
	VerdantDressing.fireflies(dynamic, Vector3(0, 0.5, -118), 16.0, 14, 25)


func _build_rail_extras() -> void:
	for rl: Variant in D.get("rails", []):
		var r: Dictionary = rl
		var n: Node3D = nodes.get(str(r.get("id", ""))) as Node3D
		if n == null:
			continue
		for k: String in ["end", "speed_mul"]:
			if r.has(k):
				n.set_meta(StringName(k), r[k])
		if bool(r.get("posts", false)):
			var pts: Array = r["points"]
			for p: Variant in [pts[0], pts[pts.size() - 1]]:
				var v: Vector3 = LevelKit.v3(p)
				LevelKit.box(n, Vector3(v.x, v.y - 0.6, v.z), Vector3(0.3, 1.0, 0.3), "#7a4a2a", false)


static func make_murk(r: Dictionary, M: Dictionary) -> MurkPool:
	var p: MurkPool = MurkPool.new()
	p.pool_id = str(r.get("id", ""))
	p.name = "Murk_" + p.pool_id
	p.r = float(r.get("r", 4.0))
	p.height = float(M.get("height", 1.4))
	p.drag = float(M.get("drag", 9.0))
	p.slow_mult = float(M.get("slow_mult", 0.45))
	p.tick_dmg = float(r.get("tick_dmg", M.get("tick_dmg", 5.0)))
	p.tick_every = float(M.get("tick_every", 0.7))
	p.bark_id = str(M.get("bark", "code.updateMurk.01"))
	p.bark_chance = float(M.get("bark_chance", 0.5))
	p.bark_cd = float(M.get("bark_cd", 12.0))
	return p


func _build_murk() -> void:
	var M: Dictionary = V().get("murk", {})
	for md: Variant in V().get("murk_pools", []):
		var r: Dictionary = md
		var p: MurkPool = make_murk(r, M)
		p.position = LevelKit.v3(r["p"])
		dynamic.add_child(p)
		murk_pools[p.pool_id] = p
		nodes["murk." + p.pool_id] = p
	if arena != null:
		for p: MurkPool in arena.murk_pools:
			murk_pools[p.pool_id] = p


func _build_bouncers() -> void:
	for bd: Variant in V().get("bouncers", []):
		var r: Dictionary = bd
		var b: BounceMushroom = BounceMushroom.new()
		b.bouncer_id = str(r["id"])
		b.name = "Bouncer_" + b.bouncer_id
		b.power = float(r.get("power", 22.0))
		b.radius = float(r.get("r", 1.7))
		b.color = r.get("color", "#4fc3ff")
		b.position = LevelKit.v3(r["p"])
		dynamic.add_child(b)
		bouncers[b.bouncer_id] = b
		nodes[b.bouncer_id] = b
	if arena != null and arena.bouncer != null:
		bouncers["lagoon_e"] = arena.bouncer


func _build_drums() -> void:
	for dd: Variant in V().get("drums", []):
		var r: Dictionary = dd
		var d: ThreshingDrum = ThreshingDrum.new()
		d.drum_id = str(r["id"])
		d.name = "Drum_" + d.drum_id
		d.r = float(r.get("r", 2.4))
		d.h = float(r.get("h", 0.6))
		d.rate = float(r.get("rate", 0.5))
		d.position = LevelKit.v3(r["p"])
		dynamic.add_child(d)
		drums[d.drum_id] = d
		nodes[d.drum_id] = d


func _build_updrafts() -> void:
	for ud: Variant in D.get("updrafts", []):
		var r: Dictionary = ud
		var u: CanyonUpdraft = CanyonUpdraft.new()
		u.name = "Updraft_" + str(r["id"])
		u.radius = float(r.get("r", 2.4))
		u.height = float(r.get("h", 10.0))
		u.force = float(r.get("force", 30.0))
		u.on_time = float(r.get("on", 100.0))
		u.off_time = float(r.get("off", 0.0))
		u.phase = float(r.get("phase", 0.0))
		u.position = LevelKit.v3(r["p"])
		dynamic.add_child(u)
		updrafts[str(r["id"])] = u
		nodes[str(r["id"])] = u


func _build_tethers() -> void:
	for td: Variant in D.get("tether_points", []):
		var r: Dictionary = td
		var t: TetherPoint = TetherPoint.new()
		t.name = "Tether_" + str(r["id"])
		t.point_id = str(r["id"])
		t.kind = StringName(str(r.get("kind", "swing")))
		t.enabled = bool(r.get("enabled", true))
		t.face_deg = float(r.get("face", 0.0))
		if r.has("land"):
			t.land_offset = LevelKit.v3(r["land"])
		t.position = LevelKit.v3(r["p"])
		dynamic.add_child(t)
		tethers[str(r["id"])] = t
		nodes["tether." + str(r["id"])] = t


## Picket corn through EnemySpawner (id picket_corn); null when the spawner doesn't know the id (tests with
## EnemyBridge.force_stub keep the corn count at zero rather than stubbing neutral units).
static func spawn_corn(pos: Vector3, parent: Node, opts: Dictionary = {}) -> Node3D:
	if EnemyBridge.force_stub or not NovaSpawn.known(&"picket_corn"):
		return null
	var n: Node3D = NovaSpawn.spawn(&"picket_corn", pos, parent, opts, false)
	return n


func _build_corn() -> void:
	for gd: Variant in V().get("corn_groups", []):
		var g: Dictionary = gd
		var id: String = str(g["id"])
		var c: Vector3 = LevelKit.v3(g["center"])
		var r: float = float(g.get("r", 5.0))
		var n: int = int(g.get("count", 4))
		var group: Node3D = Node3D.new()
		group.name = "Corn_" + id
		dynamic.add_child(group)
		var members: Array[Node3D] = []
		for i: int in n:
			var a: float = TAU * float(i) / float(n)
			var at: Vector3 = c + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var opts: Dictionary = {"loop_center": c, "loop_r": r, "loop_phase": a, "group": id, "steward": bool(g.get("steward", false)) and i == 0}
			var corn: Node3D = spawn_corn(at, group, opts)
			if corn == null:
				corn_stubbed += 1
				continue
			corn_spawned += 1
			members.append(corn)
			if corn.has_signal("hit_by_player"):
				corn.connect("hit_by_player", _on_corn_hit)
		corn_groups[id] = members
		nodes["corn." + id] = group


func _build_quest_items() -> void:
	var i: int = 0
	for qd: Variant in V().get("quest_items", []):
		var r: Dictionary = qd
		var qi: QuestItem = QuestItem.new()
		qi.name = "QuestItem_%s_%d" % [r["quest"], i]
		qi.quest_id = str(r["quest"])
		qi.item = str(r.get("item", ""))
		qi.position = LevelKit.v3(r["p"])
		dynamic.add_child(qi)
		quest_items.append(qi)
		nodes["%s.%d" % [qi.quest_id, i]] = qi
		i += 1


func _build_core() -> void:
	var CD: Dictionary = V().get("core", {})
	if CD.is_empty():
		return
	var flag_id: String = str(CD.get("flag", "core." + level_id))
	if BS.flag(flag_id):
		return
	core = NovaCore.new()
	core.name = "KeystoneCore"
	core.core_flag = flag_id
	core.actions = CD.get("actions", [])
	core.director = self
	core.position = LevelKit.v3(CD["p"]) if CD.has("p") else (arena.center() + Vector3(0, 0.8, 0) if arena != null else Vector3.ZERO)
	dynamic.add_child(core)
	nodes["core"] = core
	core.reveal(false)


# ------------------------------------------------------------------ host calls (resolved here first)

const OWN_HOST_CALLS: PackedStringArray = ["objective", "open_star_map", "flush_pool", "grant_glide", "start_popup", "popup_cleared",
	"start_compost", "open_all_leaks", "reveal_core"]


## Verdant's own host actions resolve here (a plain test host runs the planet); everything else (story_beat,
## show_hint, complete_level...) goes to the host as usual.
func _host_call(method: String, args: Variant) -> bool:
	if method in OWN_HOST_CALLS and has_method(method):
		var a: Array = args if args is Array else []
		callv(method, a)
		host_calls.append(method)
		return true
	return super._host_call(method, args)


## {"host": "objective", "args": ["bs.verdant.obj_..."]}
func objective(line_id: String) -> void:
	objectives.append(line_id)
	if host != null and host.has_method("set_objective"):
		host.call("set_objective", LevelKit.text(line_id))


func open_star_map() -> void:
	BS.save_to_profile()
	if host != null and host.has_method("open_star_map"):
		host.call("open_star_map")


## {"host": "flush_pool", "args": [id, seconds]}: the S5 sprinkler pump flushes a pool clear.
func flush_pool(id: String, seconds: float = 10.0) -> void:
	var p: MurkPool = murk_pools.get(id) as MurkPool
	if p != null:
		p.flush(seconds)


## {"host": "grant_glide"}: the sail interact at the loft. Once per save.
func grant_glide() -> void:
	var G: Dictionary = V().get("glide", {})
	var f: String = str(G.get("grant_flag", "glide_earned"))
	if flag(f):
		return
	set_flag(f)
	GadgetManager.grant(&"sprocket_glide")
	var l: LevelLamp = lamps.get("lamp_glide")
	if l != null:
		l.set_lit(true)
	var cs: String = str(G.get("cutscene", "vd_glide"))
	if cs != "":
		play_cutscene(cs)
	objective("bs.verdant.obj_boom")


# ------------------------------------------------------------------ level cutscenes

func has_level_cutscene(id: String) -> bool:
	return level_cutscenes.has(id) and id != "_doc"


func level_cutscene_steps(id: String) -> Array:
	return (level_cutscenes.get(id, {}) as Dictionary).get("steps", []) if has_level_cutscene(id) else []


## Level-owned scripts first (the host plays them through the shared CutscenePlayer when it can), then the
## story file's. Without a cutscene host the lines play through LinePlayer and the flag is set.
func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	if has_level_cutscene(id):
		cutscenes_played.append(id)
		host_calls.append("play_cutscene")
		if host != null and host.has_method("play_level_cutscene") and bool(host.call("play_level_cutscene", id, on_done)):
			return true
		var ids: PackedStringArray = []
		for st: Variant in level_cutscene_steps(id):
			if str((st as Dictionary).get("type", "")) == "line":
				ids.append(str((st as Dictionary)["id"]))
		lines.play_lines(ids)
		BS.set_flag("cs." + id)
		if on_done.is_valid():
			on_done.call()
		return false
	return super.play_cutscene(id, on_done)


# ------------------------------------------------------------------ the Compost King

func boss_cfg() -> Dictionary:
	return D.get("boss", {})


## {"host": "start_compost"}: the lagoon trigger. The title card plays once per save, then the boss spawns.
func start_compost() -> void:
	if boss_active or boss_done or flag("compost_down"):
		return
	boss_active = true
	_boss_phases.clear()
	var B: Dictionary = boss_cfg()
	run_actions(B.get("on_start", []), self, bolt())
	var card: String = str(B.get("title_card", "introCompost"))
	if card != "" and not BS.flag("cs." + card):
		if play_cutscene(card, _spawn_king):
			return
	_spawn_king()


func _spawn_king() -> void:
	if boss != null:
		return
	var B: Dictionary = boss_cfg()
	var id: StringName = StringName(str(B.get("id", "compost_king")))
	var at: Vector3 = arena.boss_spawn() if arena != null else LevelKit.v3(B.get("spawn"))
	boss = NovaSpawn.spawn(id, at, dynamic, {"arena": arena}, false)
	if boss == null:
		boss = _stand_in(B, at)
		boss_is_stand_in = true
		boss_log.append("stand_in")
	else:
		boss_log.append("spawned:" + String(id))
		boss.set_meta(&"level_director", self)
		if boss.has_method("start_fight"):
			boss.call("start_fight")
	_boss_max = maxf(1.0, float(boss.get("max_hp")) if boss.get("max_hp") != null else 1.0)
	if arena != null:
		arena.begin_fight(boss)
		if boss_is_stand_in:
			arena.set_initial_leaks(["W"])
	boss_started_vd.emit(boss)
	boss_engaged.emit(boss)


func _stand_in(B: Dictionary, at: Vector3) -> Node3D:
	var d: TestDummy = TestDummy.new()
	d.name = "CompostKingStandIn"
	d.max_hp = float(B.get("stand_in_hp", 560.0))
	d.hp = d.max_hp
	d.radius = 2.0
	d.add_to_group(&"bosses")
	d.set_meta(&"enemy_id", str(B.get("id", "compost_king")))
	dynamic.add_child(d)
	d.global_position = at
	LevelKit.cylinder(d, Vector3(0, 1.2, 0), 2.0, 2.4, "#4a6a2a", false, "y", 1.2)
	LevelKit.cylinder(d, Vector3(0, 2.6, 0), 0.8, 0.5, "#8a95a8", false, "y", 1.0)
	EventBus.boss_started.emit(StringName(str(B.get("id", "compost_king"))), LevelKit.text(str(B.get("name_line", "code.updateCompostKing.01"))))
	EventBus.banner.emit(LevelKit.text(str(B.get("name_line", "code.updateCompostKing.01"))), LevelKit.text("code.bossStart.01"), 2.4)
	return d


func boss_hp_frac() -> float:
	if boss == null or not is_instance_valid(boss) or boss.get("hp") == null:
		return 0.0
	return clampf(float(boss.get("hp")) / _boss_max, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not boss_active or boss_done or boss == null:
		return
	if not is_instance_valid(boss) or (boss.has_method("is_alive") and not bool(boss.call("is_alive")) and not boss_mercy):
		_king_defeated()
		return
	var f: float = boss_hp_frac()
	if boss_is_stand_in:
		EventBus.boss_health.emit(StringName(str(boss_cfg().get("id", "compost_king"))), f, 0.0)
	_king_phases(f)


func _on_boss_health(id: StringName, frac: float, _break_frac: float) -> void:
	if boss_active and not boss_done and String(id) == str(boss_cfg().get("id", "compost_king")):
		_king_phases(frac)


## Arena-side phase actions (data "boss.phases"): the leaks burst at 60% for the stand-in; the real King opens
## them itself (its _on_phase), so the data action is idempotent.
func _king_phases(frac: float) -> void:
	var phases: Array = boss_cfg().get("phases", [])
	for i: int in phases.size():
		var ph: Dictionary = phases[i]
		if not _boss_phases.has(i) and frac <= float(ph.get("below", 0.0)):
			_boss_phases[i] = true
			boss_log.append("phase:%d" % (i + 2))
			run_actions(ph.get("actions", []), self, bolt())


func king_phase_count() -> int:
	return _boss_phases.size()


## {"host": "open_all_leaks"}
func open_all_leaks() -> void:
	if arena == null:
		return
	for v: CoolantValve in arena.valves():
		v.set_open(true)


func _on_valve_sealed(id: String) -> void:
	boss_log.append("sealed:" + id)
	if boss != null and is_instance_valid(boss) and boss.has_method("on_leak_sealed"):
		boss.call("on_leak_sealed", id)
	if arena != null and arena.all_sealed():
		boss_log.append("all_sealed")


func _on_handshake(by: Node) -> void:
	if boss != null and is_instance_valid(boss) and boss.has_method("accept_mercy"):
		if bool(boss.call("accept_mercy", by)):
			boss_mercy = true
			boss_log.append("mercy")
			set_flag("compost_mercy")
			BS.set_flag("verdant.compost_mercy")
			play_cutscene("vd_mercy", _king_defeated)


## The base director's own boss flow (its physics poll, phase check and defeat) is routed to the King's.
func _boss_defeated() -> void:
	_king_defeated()


func _check_phases(frac: float) -> void:
	_king_phases(frac)


## The King's defeat (or stand-down) runs through _king_defeated, not the base director's boss flow.
func _on_boss_defeated(id: StringName) -> void:
	if boss_active and String(id) == str(boss_cfg().get("id", "compost_king")):
		_king_defeated()
		return
	super._on_boss_defeated(id)


func _on_enemy_killed(enemy: Node, w: StringName) -> void:
	if boss_active and enemy == boss:
		_king_defeated()
		return
	super._on_enemy_killed(enemy, w)


func _king_defeated() -> void:
	if boss_done:
		return
	boss_done = true
	boss_active = false
	if not boss_mercy and boss != null and is_instance_valid(boss) and boss.get("mercy") != null and bool(boss.get("mercy")):
		boss_mercy = true                      # accept_mercy emits boss_defeated before _on_handshake returns
		boss_log.append("mercy")
		set_flag("compost_mercy")
		BS.set_flag("verdant.compost_mercy")
	boss_log.append("mercy_end" if boss_mercy else "defeated")
	if arena != null:
		arena.end_fight()
		arena.drain_all()
	if boss_is_stand_in and is_instance_valid(boss):
		boss.queue_free()
	run_actions(boss_cfg().get("on_defeat", []), self, bolt())
	boss_down.emit()
	if boss_mercy:
		var n: Node3D = nodes.get("king_npc") as Node3D
		if n != null:
			n.visible = true
			_set_group_collision(n, true)
			if n is InteractPoint:
				(n as InteractPoint).enabled = true


## {"host": "reveal_core"}
func reveal_core() -> void:
	if core != null and is_instance_valid(core):
		core.reveal(true)


# ------------------------------------------------------------------ the Picket Line pop-up

## {"host": "start_popup"}: the GLAMBOT pop-up in THE COMPOST RING, once he has defected (beat.l2_glambot).
func start_popup() -> void:
	var P: Dictionary = V().get("popup", {})
	if popup_running or flag("picket_line_done"):
		return
	var need: String = str(P.get("needs_beat", "l2_glambot"))
	if need != "" and not BS.flag("beat." + need):
		lines.play_line("bs.verdant.popup_locked")
		return
	var e: Encounter = encounters.get(str(P.get("encounter", "picket_line")))
	if e == null or e.started:
		return
	popup_running = true
	popup_failed = false
	popup_won = false
	# the six corn the waves come for
	var c: Vector3 = LevelKit.v3(P.get("center", [-90, -0.3, -12]))
	var members: Array[Node3D] = []
	var group: Node3D = Node3D.new()
	group.name = "Corn_popup"
	dynamic.add_child(group)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var corn: Node3D = spawn_corn(c + Vector3(cos(a) * 4.5, 0.0, sin(a) * 4.5), group, {"loop_center": c, "loop_r": 4.5, "loop_phase": a, "group": "popup"})
		if corn != null:
			members.append(corn)
			if corn.has_signal("hit_by_player"):
				corn.connect("hit_by_player", _on_corn_hit)
	corn_groups["popup"] = members
	lines.play_line("bs.verdant.popup_start")
	e.start()


func _on_corn_hit(corn: Node3D, _hit: Variant) -> void:
	var grp: String = str(corn.get_meta(&"corn_group", ""))
	if popup_running and grp == "popup" and not popup_failed:
		popup_failed = true
		EventBus.bark.emit(str((V().get("popup", {}) as Dictionary).get("fail_bark", "bs.verdant.picket_fail")))
		EventBus.banner.emit(LevelKit.text("bs.verdant.picket_fail_banner"), LevelKit.text("bs.verdant.picket_fail_sub"), 2.4)


## {"host": "popup_cleared"}: the encounter's on_clear.
func popup_cleared() -> void:
	if not popup_running:
		return
	popup_running = false
	var P: Dictionary = V().get("popup", {})
	if popup_failed:
		popup_finished.emit(false)
		return
	popup_won = true
	set_flag("picket_line_done")
	BS.add_bolts(int(P.get("reward", 240)))
	EventBus.banner.emit(LevelKit.text("bs.verdant.popup_banner"), LevelKit.text("bs.verdant.popup_sub"), 2.4)
	lines.play_line("bs.verdant.popup_done")
	popup_finished.emit(true)
