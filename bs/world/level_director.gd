class_name LevelDirector
extends Node3D
## Builds a B&S planet from its data file (data/bs/levels/<id>.json) and runs it: greybox geometry under a
## runtime-baked NavigationRegion3D, traversal objects, collectibles, NPCs and quests, triggers, encounters,
## rules (flag combinations), the boss arena and the exit. A planet scene (extends BSLevel) owns one director
## and forwards build() / on_level_ready() to it; the director calls back into the host level for the
## systems the UI builder owns (story_beat, play_cutscene, show_hint, open_shop, open_star_map,
## complete_planet), each guarded with has_method and given a local fallback.
##
## Data actions (triggers, switches, items, rules, encounter clears, boss events) are dictionaries; see
## _run() for the vocabulary. Flags without a dot are level-local: BS flag "<level>.<name>".

signal flag_changed(flag_name: String, on: bool)
signal boss_engaged(boss: Node3D)
signal boss_down
signal intro_started
signal planet_completed(level_id: String)

var host: Node = null
var level_id: String = ""
var D: Dictionary = {}
var common: Dictionary = {}
var kill_y: float = -40.0
var water_zones: Array[AABB] = []
var water_quips: PackedStringArray = []

var nav_region: NavigationRegion3D
var geometry: Node3D        # static, navmesh-baked
var dynamic: Node3D         # moving / interactive (not baked)
var nodes: Dictionary = {}  # id -> Node (groups, gates, conveyors, movers, lamps, items, npcs, ...)
var gates: Dictionary = {}
var conveyors: Dictionary = {}
var movers: Dictionary = {}
var lamps: Dictionary = {}
var switches: Dictionary = {}
var triggers: Dictionary = {}
var relays: Dictionary = {}
var npcs: Dictionary = {}
var encounters: Dictionary = {}
var gold: Dictionary = {}
var memos: Dictionary = {}
var items: Dictionary = {}
var quest_items: Array[QuestItem] = []
var zones: Dictionary = {}
var quest_book: QuestBook
var lines: LinePlayer
var exit: TeleporterExit
var beacon: SaveBeacon
var walls: CompactorWalls
var boss: Node3D = null
var boss_active: bool = false
var boss_done: bool = false
var nav_polygons: int = 0
var respawn_point: Vector3 = Vector3.INF
var kiosk: Node3D = null
var pickups_spawned: int = 0
var boss_owns_walls: bool = false
var loading: bool = false

# logs the smoke test and GUT read
var action_log: Array[String] = []
var beats_played: PackedStringArray = []
var cutscenes_played: PackedStringArray = []
var hints_shown: Dictionary = {}
var host_calls: PackedStringArray = []

var _rules_fired: Dictionary = {}
var _phases_done: Dictionary = {}
var _qhint_cd: Dictionary = {}
var _qhint_t: float = 0.0


# ================================================================== setup

## Builds everything. `host_node` is the level (BSLevel) or any Node3D test host.
func setup(host_node: Node, id: String) -> void:
	host = host_node
	level_id = id
	D = Data.table("bs/levels/" + id)
	var c: Variant = Data.table("bs/levels/level_common")
	common = c if c is Dictionary else {}
	var lf: Variant = Data.table(str(D.get("lines_file", "bs/levels/%s_lines" % id)))
	if lf is Dictionary:
		LevelKit.register_lines((lf as Dictionary).get("lines", {}))
	LevelKit.set_palette(D.get("materials", {}), D.get("rim", {}))
	kill_y = float(D.get("kill_y", -40.0))
	for q: Variant in D.get("water_quips", []):
		water_quips.append(str(q))
	for z: Variant in D.get("zones", []):
		zones[str(z["id"])] = z

	lines = LinePlayer.new()
	lines.name = "Lines"
	add_child(lines)
	quest_book = QuestBook.new()
	quest_book.name = "QuestBook"
	quest_book.setup(int(D.get("planet_index", 0)), D.get("enemy_aliases", {}))
	add_child(quest_book)

	_build_environment()
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	add_child(nav_region)
	geometry = Node3D.new()
	geometry.name = "Geometry"
	nav_region.add_child(geometry)
	dynamic = Node3D.new()
	dynamic.name = "Dynamic"
	add_child(dynamic)

	_build_boxes()
	_build_shacks()
	_build_mounds_cylinders()
	_build_signs_lights()
	_build_conveyors()
	_build_rails_markers()
	_build_water()
	_bake_navmesh()

	_build_movers()
	_build_gates_lamps()
	_build_switches()
	_build_collectibles()
	_build_npcs()
	_build_relays_and_interacts()
	_build_triggers()
	_build_encounters()
	_build_boss_arena()

	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.boss_health.connect(_on_boss_health)
	_apply_saved_state()


## Where Bolt starts: inside the garage until the prologue is done, then the hub.
func start_point() -> Vector3:
	if not flag("prologue_done") and D.has("prologue_spawn"):
		return LevelKit.v3(D["prologue_spawn"])
	return LevelKit.v3(D.get("spawn", [0, 1.2, 0]))


## Called from the host's on_level_ready(), once Bolt exists.
func level_ready() -> void:
	for id: String in encounters.keys():
		var e: Encounter = encounters[id]
		if bool(e.get_meta(&"autostart", false)):
			e.start()
	for id: String in relays.keys():
		var r: CheckpointRelay = relays[id]
		if bool(r.get_meta(&"start", false)):
			r.activate(bolt(), true)
	_spawn_pickups()


## flyover0 -> arrive0 back to back on the first return by ship (fixes the web build's order bug):
## the scenes still unseen, once the planet has been cleared. The planet's arrival_beat() plays them.
func return_cutscenes() -> PackedStringArray:
	var out: PackedStringArray = []
	if not (flag("planet_complete." + level_id) or BS.flag("cleared." + level_id)):
		return out
	for cs: Variant in (D.get("story", {}) as Dictionary).get("return_cutscenes", []):
		if not BS.flag("cs." + str(cs)):
			out.append(str(cs))
	return out


func bolt() -> Node3D:
	return LevelKit.player(get_tree())


func zone(id: String) -> Dictionary:
	return zones.get(id, {})


# ================================================================== flags and rules

func flag_key(n: String) -> String:
	return n if n.contains(".") else "%s.%s" % [level_id, n]


func flag(n: String) -> bool:
	return BS.flag(flag_key(n))


func set_flag(n: String, on: bool = true) -> void:
	var was: bool = flag(n)
	BS.set_flag(flag_key(n), on)
	if was != on:
		flag_changed.emit(n, on)
		_eval_rules()


func _gate_check(requires: PackedStringArray, forbids: PackedStringArray) -> bool:
	for r: String in requires:
		if not flag(r):
			return false
	for f: String in forbids:
		if flag(f):
			return false
	return true


func _eval_rules(load_pass: bool = false) -> void:
	for r: Variant in D.get("rules", []):
		var rule: Dictionary = r
		var id: String = str(rule.get("id", ""))
		if _rules_fired.has(id):
			continue
		if bool(rule.get("on_load_only", false)) and not load_pass:
			continue
		var ok: bool = true
		for f: Variant in rule.get("all", []):
			if not flag(str(f)):
				ok = false
				break
		if ok:
			_rules_fired[id] = true
			run_actions(rule.get("do", []), self, bolt())


func _apply_saved_state() -> void:
	loading = true
	if flag("prologue_done"):
		_finish_prologue(true)
	else:
		_set_group_visible("lot_after", false)
	_eval_rules(true)
	loading = false


# ================================================================== actions

func run_actions(list: Variant, source: Node = null, who: Node = null) -> void:
	if not (list is Array):
		return
	for a: Variant in list:
		if a is Dictionary:
			_run(a as Dictionary, source, who)


func _run(a: Dictionary, _source: Node, who: Node) -> void:
	action_log.append(JSON.stringify(a))
	if who == null:
		who = bolt()
	if a.has("if"):
		run_actions(a.get("then", []) if flag(str(a["if"])) else a.get("else", []), _source, who)
		return
	var quiet: bool = loading
	if a.has("beat") and not quiet:
		story_beat(str(a["beat"]))
	if a.has("cutscene") and not quiet:
		play_cutscene(str(a["cutscene"]))
	if a.has("hint") and not quiet:
		show_hint(LevelKit.text(str(a["hint"])), str(a.get("key", a["hint"])))
	if a.has("banner") and not quiet:
		var b: Array = a["banner"]
		EventBus.banner.emit(LevelKit.text(str(b[0])), LevelKit.text(str(b[1])) if b.size() > 1 else "", float(a.get("sec", 2.2)))
	if a.has("line") and not quiet:
		lines.play_line(str(a["line"]))
	if a.has("bark") and not quiet:
		EventBus.bark.emit(str(a["bark"]))
	if a.has("flag"):
		set_flag(str(a["flag"]), true)
	if a.has("unflag"):
		set_flag(str(a["unflag"]), false)
	if a.has("open"):
		var g: LevelGate = gates.get(str(a["open"]))
		if g != null:
			g.open(quiet or bool(a.get("instant", false)))
			if a.has("for"):
				_close_later(g, float(a["for"]))
	if a.has("close"):
		var g2: LevelGate = gates.get(str(a["close"]))
		if g2 != null:
			g2.close(quiet or bool(a.get("instant", false)))
	if a.has("encounter") and not quiet:
		var e: Encounter = encounters.get(str(a["encounter"]))
		if e != null:
			e.start()
	if a.has("reverse"):
		var cv: ConveyorBelt = conveyors.get(str(a["reverse"]))
		if cv != null:
			cv.reverse_for(float(a.get("seconds", 8.0)))
	if a.has("reveal"):
		var col: Node = nodes.get(str(a["reveal"]))
		if col is Collectible:
			(col as Collectible).reveal(true)
	if a.has("lamp"):
		var l: LevelLamp = lamps.get(str(a["lamp"]))
		if l != null:
			l.set_lit(bool(a.get("on", true)))
	if a.has("bolts"):
		BS.add_bolts(int(a["bolts"]))
	if a.has("heal") and who != null and who.has_method("heal"):
		who.call("heal", float(who.get("max_hp")) * float(a["heal"]))
	if a.has("max_hp"):
		var n: int = int(a["max_hp"])
		BS.max_hp += n
		if who != null and who.get("max_hp") != null:
			who.set("max_hp", float(who.get("max_hp")) + n)
			who.call("heal", float(n))
		BS.save_to_profile()
	if a.has("boss") and not quiet:
		start_boss(str(a["boss"]))
	if a.has("exit") and exit != null:
		exit.activate(quiet or bool(a.get("silent", false)))
	if a.has("host") and not quiet:
		_host_call(str(a["host"]), a.get("args", []))
	if a.has("remove"):
		_remove_node(str(a["remove"]))
	if a.has("show"):
		_set_group_visible(str(a["show"]), true)
	if a.has("rotate"):
		var rn: Node3D = nodes.get(str(a["rotate"])) as Node3D
		if rn != null:
			rn.rotation_degrees += LevelKit.v3(a.get("deg", [0, 0, 0]))
	if a.has("pause"):
		var mv: MagnetCrane = movers.get(str(a["pause"]))
		if mv != null:
			mv.pause_for(float(a.get("for", 10.0)))
	if a.has("walls") and walls != null and not boss_owns_walls:
		walls.set_width(float(a["walls"]))
	if a.has("crush"):
		_crush(str(a["crush"]))
	if a.has("bark_swap"):
		var npc: NPCTalkPoint = npcs.get(str(a["bark_swap"]))
		if npc != null:
			var idx: int = npc.barks.find(str(a.get("from", "")))
			if idx >= 0:
				npc.barks[idx] = str(a.get("to", ""))
	if a.has("intro") and not quiet:
		begin_intro()


func _close_later(g: LevelGate, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(g):
		g.close()


func _host_call(method: String, args: Variant) -> bool:
	host_calls.append(method)
	if host != null and host.has_method(method):
		host.callv(method, args if args is Array else [])
		return true
	return false


# ================================================================== host-owned systems (with fallbacks)

## Plays a story_beats.json beat once (the host's story_beat when present; else the lines via LinePlayer).
func story_beat(id: String) -> void:
	if BS.flag("beat." + id) or id in beats_played:
		return
	beats_played.append(id)
	if _host_call("story_beat", [id]):
		return
	BS.set_flag("beat." + id)
	var beats: Variant = Data.table("bs/story/story_beats")
	if beats is Dictionary and (beats as Dictionary).has(id):
		var ids: PackedStringArray = []
		for l: Variant in ((beats as Dictionary)[id] as Dictionary).get("lines", []):
			ids.append(str((l as Dictionary)["id"]))
		lines.play_lines(ids)
	EventBus.story_beat.emit(id)


## Returns true when the host's cutscene player took it (on_done then runs when it ends).
func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	cutscenes_played.append(id)
	host_calls.append("play_cutscene")
	if host != null and host.has_method("play_cutscene") and bool(host.call("play_cutscene", id, on_done)):
		return true
	var cs: Variant = Data.table("bs/story/cutscenes")
	if cs is Dictionary and (cs as Dictionary).has(id):
		var ids: PackedStringArray = []
		for st: Variant in ((cs as Dictionary)[id] as Dictionary).get("steps", []):
			if str((st as Dictionary).get("type", "")) == "line":
				ids.append(str((st as Dictionary)["id"]))
		lines.play_lines(ids)
	BS.set_flag("cs." + id)
	if on_done.is_valid():
		on_done.call()
	return false


## Each hint key shows once per visit (showHint keys in the source).
func show_hint(text: String, key: String) -> void:
	if hints_shown.has(key):
		return
	hints_shown[key] = true
	if _host_call("show_hint", [text, key]):
		return
	EventBus.hint.emit(text, key)


## Cutscene actors ("garage", "ship") for the cutscene runner's `act` steps.
func get_actor(actor_name: String) -> Node3D:
	return nodes.get(actor_name) as Node3D


# ================================================================== prologue

## The garage gate: plays `intro`, lifts the garage away and leaves the empty lot with memo 02.
func begin_intro() -> void:
	if flag("prologue_done"):
		return
	set_flag("prologue_done")
	intro_started.emit()
	var story: Dictionary = D.get("story", {})
	# the host's cutscene player lifts the garage itself (act "rise" through cutscene_actor("garage"))
	if play_cutscene(str(story.get("intro_cutscene", "intro")), _finish_prologue.bind(false)):
		return
	if flag("prologue_finished"):
		return
	var rise: Dictionary = story.get("garage_rise", {})
	var g: Node3D = nodes.get("garage") as Node3D
	if g != null and is_inside_tree():
		_set_group_collision(g, false)
		var tw: Tween = create_tween()
		tw.tween_interval(float(rise.get("delay", 0.0)))
		tw.tween_property(g, "position:y", g.position.y + float(rise.get("h", 40.0)), float(rise.get("dur", 2.2))) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(g, "rotation:y", g.rotation.y + float(rise.get("spin", 2.5)), float(rise.get("dur", 2.2)))
		tw.tween_callback(_finish_prologue.bind(false))
	else:
		_finish_prologue(false)


func _finish_prologue(_instant: bool) -> void:
	set_flag("prologue_finished")
	for gname: String in ["garage", "garage_door"]:
		_remove_node(gname)
	_set_group_visible("lot_after", true)
	for d: Node in get_tree().get_nodes_in_group(&"prologue_only"):
		d.queue_free()
	for m: Node3D in memos.values():
		if is_instance_valid(m) and str(m.get_meta(&"after_flag", "")) == "prologue_done":
			(m as Collectible).reveal(true)


# ================================================================== boss

func start_boss(id: String) -> void:
	if boss_active or boss_done or flag("repo_down"):
		return
	var B: Dictionary = D.get("boss", {})
	boss_active = true
	_phases_done.clear()
	run_actions(B.get("on_start", []), self, bolt())
	boss = EnemyBridge.spawn(StringName(id), LevelKit.v3(B.get("spawn")), dynamic)
	if boss != null:
		boss.set_meta(&"level_director", self)
		if boss.has_method("setup_arena"):
			# RepoTron builds and drives its own wall colliders at center.x +/- half_size; the level's car-stack
			# walls follow them (walls_moved) so the riding cubes and the look stay in step.
			var h: Vector2 = LevelKit.v2(B.get("arena_half"), Vector2(18, 12))
			boss.call("setup_arena", LevelKit.v3(B.get("arena_center")), h.x, h.y)
			boss_owns_walls = true
			if boss.has_signal("walls_moved"):
				boss.connect("walls_moved", _on_boss_walls_moved)
	boss_engaged.emit(boss)


func _on_boss_walls_moved(gap: float) -> void:
	if walls != null:
		walls.set_width(gap)


func _on_boss_health(_id: StringName, frac: float, _break_frac: float) -> void:
	if boss_active and not boss_done:
		_check_phases(frac)


func _check_phases(frac: float) -> void:
	var phases: Array = (D.get("boss", {}) as Dictionary).get("phases", [])
	for i: int in phases.size():
		var ph: Dictionary = phases[i]
		if not _phases_done.has(i) and frac <= float(ph.get("below", 0.0)):
			_phases_done[i] = true
			run_actions(ph.get("actions", []), self, bolt())


func _on_enemy_killed(enemy: Node, _w: StringName) -> void:
	if boss_active and enemy == boss:
		_boss_defeated()


func _on_boss_defeated(_id: StringName) -> void:
	if boss_active:
		_boss_defeated()


func _boss_defeated() -> void:
	if boss_done:
		return
	boss_done = true
	boss_active = false
	run_actions((D.get("boss", {}) as Dictionary).get("on_defeat", []), self, bolt())
	boss_down.emit()


## REPO-TRON's phase 2 magnet drops stolen guns in the Impound Cage; smashing the hook opens it.
func impound_cage_position() -> Vector3:
	var g: LevelGate = gates.get("impound_cage")
	return g.global_position + Vector3(1.5, -1.0, -0.9) if g != null else Vector3.ZERO


func open_impound_cage() -> void:
	var g: LevelGate = gates.get("impound_cage")
	if g != null:
		g.open()


func close_impound_cage() -> void:
	var g: LevelGate = gates.get("impound_cage")
	if g != null:
		g.close()


func get_arena_walls() -> CompactorWalls:
	return walls


## How many of the data's arena phases have run this fight.
func phase_count() -> int:
	return _phases_done.size()


# ================================================================== per-frame

func _physics_process(delta: float) -> void:
	if boss_active and not boss_done:
		if boss == null or not is_instance_valid(boss) or (boss.has_method("is_alive") and not bool(boss.call("is_alive"))):
			_boss_defeated()
		elif boss.get("hp") != null and boss.get("max_hp") != null and float(boss.get("max_hp")) > 0.0:
			_check_phases(float(boss.get("hp")) / float(boss.get("max_hp")))
	_qhint_t -= delta
	if _qhint_t <= 0.0:
		_qhint_t = 1.0
		_quest_hints(1.0)


## Sprocket barks when an active quest's item/target is near (BS_LEVELS §0.6).
func _quest_hints(step: float) -> void:
	var qh: Dictionary = D.get("quest_hints", {})
	var p: Node3D = bolt()
	if qh.is_empty() or p == null:
		return
	var r: float = float(qh.get("radius", 25.0))
	var hint_lines: Dictionary = qh.get("lines", {})
	for qid: String in hint_lines.keys():
		_qhint_cd[qid] = float(_qhint_cd.get(qid, 0.0)) - step
		if float(_qhint_cd[qid]) > 0.0 or quest_book.state(qid) != QuestBook.ACTIVE:
			continue
		var near: bool = false
		var kt: String = quest_book.kill_type(qid)
		if kt != "":
			for e: Node in get_tree().get_nodes_in_group(&"enemies"):
				if EnemyBridge.enemy_id(e) == kt and (e as Node3D).global_position.distance_to(p.global_position) < r:
					near = true
					break
		else:
			for qi: QuestItem in quest_items:
				if is_instance_valid(qi) and qi.quest_id == qid and qi.global_position.distance_to(p.global_position) < r:
					near = true
					break
		if near:
			_qhint_cd[qid] = float(qh.get("cooldown", 60.0))
			EventBus.bark.emit(str(hint_lines[qid]))


# ================================================================== builders

func _group_node(gname: String) -> Node3D:
	if nodes.has(gname):
		return nodes[gname]
	var g: Node3D = Node3D.new()
	g.name = gname.to_pascal_case()
	geometry.add_child(g)
	nodes[gname] = g
	return g


func _build_environment() -> void:
	var P: Dictionary = D.get("palette", {})
	if P.is_empty():
		return
	var env: Environment = Environment.new()
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color.html(str(P.get("sky", "#45203a")))
	sm.sky_horizon_color = Color.html(str(P.get("fog", "#9a4f33")))
	sm.ground_horizon_color = Color.html(str(P.get("fog", "#9a4f33")))
	sm.ground_bottom_color = Color.html(str(P.get("hemi_bot", "#5e3c1c")))
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html(str(P.get("hemi_top", "#ffd9b0"))).lerp(Color.html(str(P.get("hemi_bot", "#5e3c1c"))), 0.35)
	env.ambient_light_energy = float(P.get("hemi_i", 0.85)) * 0.6 + float(P.get("amb_i", 0.2))
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color.html(str(P.get("fog", "#9a4f33")))
	env.fog_depth_begin = float(P.get("fog_near", 45))
	env.fog_depth_end = float(P.get("fog_far", 165))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color.html(str(P.get("sun", "#ffb27a")))
	sun.light_energy = float(P.get("sun_i", 1.5))
	sun.shadow_enabled = true
	add_child(sun)
	var off: Vector3 = LevelKit.v3(P.get("sun_off", [26, 18, 10]))
	sun.look_at_from_position(off, Vector3.ZERO, Vector3.UP)


func _build_boxes() -> void:
	for b: Variant in D.get("boxes", []):
		var r: Dictionary = b
		var parent: Node3D = _group_node(str(r["group"])) if r.has("group") else geometry
		var m: Variant = r.get("m", "slab")
		var n: Node3D
		if bool(r.get("ramp", false)):
			n = LevelKit.ramp(parent, LevelKit.v3(r["from"]), LevelKit.v3(r["to"]), float(r.get("w", 2.0)), m, float(r.get("t", 0.4)))
		elif r.has("p") and r.has("s"):
			n = LevelKit.box(parent, LevelKit.v3(r["p"]), LevelKit.v3(r["s"]), m, not bool(r.get("deco", false)),
				LevelKit.v3(r.get("rot", [0, 0, 0])), LevelKit.WORLD_LAYER, float(r.get("glow", 0.0)))
		else:
			continue
		if r.has("id"):
			nodes[str(r["id"])] = n


func _build_shacks() -> void:
	var S: Dictionary = D.get("shacks", {})
	for s: Variant in S.get("list", []):
		var r: Dictionary = s
		var top: float = _shack(geometry, float(r["x"]), float(r["z"]), float(r["w"]), float(r["d"]), r.get("c", "shack1"), r.get("r", "rust"), float(r.get("floor", 0.0)))
		if bool(r.get("stack", false)):
			_shack(geometry, float(r["x"]) - 0.3, float(r["z"]) + 0.2, float(r["w"]) * 0.7, float(r["d"]) * 0.7, r.get("r", "rust"), r.get("c", "shack1"), top)
	var bd: Dictionary = S.get("backdrop", {})
	if not bd.is_empty():
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(bd.get("seed", 41))
		var cols: Array[String] = ["shack1", "shack2", "shack3", "rust", "slab", "hull"]
		for i: int in int(bd.get("count", 0)):
			var x: float = rng.randf_range(float(bd["x0"]), float(bd["x1"]))
			var z: float = rng.randf_range(float(bd["z1"]), float(bd["z0"]))
			var h: float = rng.randf_range(2.4, 3.2)
			var base: float = rng.randf_range(0.0, 4.0)
			var w: float = rng.randf_range(2.6, 4.2)
			LevelKit.box(geometry, Vector3(x, base + h * 0.5, z), Vector3(w, h, rng.randf_range(2.6, 3.8)), cols[i % cols.size()], false)
			LevelKit.box(geometry, Vector3(x, base + h + 0.15, z), Vector3(w + 0.6, 0.3, 3.6), "rust", false)


## shack() from expandScrapheap: solid body, walkable roof, door, lit window, stove pipe. Returns roof top.
func _shack(parent: Node3D, x: float, z: float, w: float, d: float, col: Variant, roof: Variant, gy: float) -> float:
	var h: float = 2.6
	LevelKit.box(parent, Vector3(x, gy + h * 0.5 - 0.2, z), Vector3(w, h + 0.4, d), col, true)
	LevelKit.box(parent, Vector3(x, gy + h + 0.12, z), Vector3(w + 0.8, 0.3, d + 0.8), roof, true)
	LevelKit.box(parent, Vector3(x, gy + 1.0, z + d * 0.5 + 0.03), Vector3(1.0, 2.0, 0.08), "navy", false)
	LevelKit.box(parent, Vector3(x + w * 0.28, gy + 1.5, z + d * 0.5 + 0.04), Vector3(0.7, 0.6, 0.06), "#ffd27a", false, Vector3.ZERO, 1, 1.4)
	LevelKit.box(parent, Vector3(x - w * 0.3, gy + h + 0.9, z - d * 0.2), Vector3(0.25, 1.4, 0.25), "steel", false)
	return gy + h + 0.27


func _build_mounds_cylinders() -> void:
	for mm: Variant in D.get("mounds", []):
		var r: Dictionary = mm
		if float(r.get("r", 0.0)) <= 0.0:
			continue
		LevelKit.mound(geometry, float(r["x"]), float(r["z"]), float(r.get("floor", 0.0)), float(r["r"]), float(r["h"]), r.get("m", "dune"))
	for cc: Variant in D.get("cylinders", []):
		var r: Dictionary = cc
		LevelKit.cylinder(geometry, LevelKit.v3(r["p"]), float(r["r"]), float(r["h"]), r.get("m", "steel"), bool(r.get("solid", false)), str(r.get("axis", "y")))


func _build_signs_lights() -> void:
	for s: Variant in D.get("signs", []):
		var r: Dictionary = s
		var parent: Node3D = _group_node(str(r["group"])) if r.has("group") else geometry
		LevelKit.text_sign(parent, str(r["text"]), LevelKit.v3(r["p"]), LevelKit.v2(r.get("size", [3, 1])), float(r.get("ry", 0.0)),
			r.get("bg", "#2a1a10"), r.get("fg", "#ffd23e"))
	for l: Variant in D.get("lights", []):
		var r: Dictionary = l
		var o: OmniLight3D = OmniLight3D.new()
		o.position = LevelKit.v3(r["p"])
		o.light_color = Color.html(str(r.get("color", "#ffffff")))
		o.light_energy = float(r.get("energy", 1.0))
		o.omni_range = float(r.get("range", 10.0))
		geometry.add_child(o)


func _build_conveyors() -> void:
	for c: Variant in D.get("conveyors", []):
		var r: Dictionary = c
		var cv: ConveyorBelt = ConveyorBelt.new()
		cv.name = str(r["id"]).to_pascal_case()
		cv.size = LevelKit.v3(r["s"])
		var d2: Vector2 = LevelKit.v2(r.get("dir", [1, 0]))
		cv.dir = Vector3(d2.x, 0, d2.y)
		cv.speed = float(r.get("speed", 3.2))
		cv.warn_time = float(r.get("warn", 1.0))
		cv.position = LevelKit.v3(r["p"])
		geometry.add_child(cv)
		conveyors[str(r["id"])] = cv
		nodes[str(r["id"])] = cv


func _build_rails_markers() -> void:
	for rl: Variant in D.get("rails", []):
		var r: Dictionary = rl
		if not r.has("points"):
			continue
		var m: Node3D = Node3D.new()
		m.name = "Rail_" + str(r["id"])
		m.add_to_group(&"rails")
		var pts: PackedVector3Array = []
		for p: Variant in r["points"]:
			pts.append(LevelKit.v3(p))
		m.set_meta(&"points", pts)
		m.set_meta(&"rail_id", str(r["id"]))
		m.set_meta(&"two_way", bool(r.get("two_way", false)))
		m.set_meta(&"gadget", str(r.get("gadget", "")))
		dynamic.add_child(m)
		nodes[str(r["id"])] = m
		for i: int in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var seg: Node3D = LevelKit.box(m, (a + b) * 0.5, Vector3(0.12, 0.12, a.distance_to(b)), r.get("color", "#ffd23e"), false, Vector3.ZERO, 1, 1.2)
			seg.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.FORWARD)
	for gp: Variant in D.get("gadget_points", []):
		var r: Dictionary = gp
		var mk: Marker3D = Marker3D.new()
		mk.position = LevelKit.v3(r["p"])
		mk.add_to_group(&"gadget_points")
		for k: String in r.keys():
			if k != "p" and k != "_":
				mk.set_meta(StringName(k), r[k])
		var col: String = "#ff9d2e" if str(r.get("kind", "")) == "tether" else ("#7ad04a" if str(r.get("kind", "")) == "glide" else "#c9e8f0")
		LevelKit.cylinder(mk, Vector3.ZERO, 0.45, 0.12, col, false, "x", -1.0, 0.8)
		dynamic.add_child(mk)
		nodes[str(r["id"])] = mk
	for ps: Variant in D.get("pickup_spots", []):
		var r: Dictionary = ps
		var kind: String = str(r.get("kind", ""))
		var pts2: Array[Vector3] = []
		if kind == "bolt_row":
			var n: int = int(r.get("n", 3))
			for i: int in n:
				pts2.append(LevelKit.v3(r["p"]).lerp(LevelKit.v3(r["to"]), float(i) / maxf(1.0, float(n - 1))))
			kind = "bolt"
		elif kind == "bolt_trail":
			var path: Array = r.get("points", [])
			for i: int in path.size() - 1:
				for k: int in int(r.get("n", 3)):
					var t: float = float(k) / float(int(r.get("n", 3)))
					var a2: Vector2 = LevelKit.v2(path[i])
					var b2: Vector2 = LevelKit.v2(path[i + 1])
					var q: Vector2 = a2.lerp(b2, t)
					pts2.append(Vector3(q.x, 0.6, q.y))
			kind = "bolt"
		elif r.has("p"):
			pts2.append(LevelKit.v3(r["p"]))
		for p3: Vector3 in pts2:
			var mk2: Marker3D = Marker3D.new()
			mk2.position = p3
			mk2.add_to_group(&"pickup_spots")
			mk2.set_meta(&"kind", kind)
			dynamic.add_child(mk2)


func _build_water() -> void:
	for w: Variant in D.get("water", []):
		var r: Dictionary = w
		var s: Vector3 = LevelKit.v3(r["s"])
		water_zones.append(AABB(LevelKit.v3(r["p"]) - s * 0.5, s))


func _bake_navmesh() -> void:
	var N: Dictionary = common.get("navmesh", {})
	var nm: NavigationMesh = NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.cell_size = float(N.get("cell_size", 0.25))
	nm.cell_height = float(N.get("cell_height", 0.25))
	nm.agent_radius = float(N.get("agent_radius", 0.5))
	nm.agent_height = float(N.get("agent_height", 1.8))
	nm.agent_max_climb = float(N.get("agent_max_climb", 0.5))
	nm.agent_max_slope = float(N.get("agent_max_slope", 45.0))
	nm.region_min_size = float(N.get("region_min_size", 4.0))
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh(false)
	nav_polygons = nav_region.navigation_mesh.get_polygon_count()


func _build_movers() -> void:
	for mv: Variant in D.get("movers", []):
		var r: Dictionary = mv
		var c: MagnetCrane = MagnetCrane.new()
		c.name = str(r["id"]).to_pascal_case()
		c.base = LevelKit.v3(r["base"])
		c.end = LevelKit.v3(r["end"])
		c.speed = float(r.get("speed", 0.55))
		c.size = LevelKit.v3(r.get("size", [3.4, 0.4, 3.4]))
		c.tower = str(r.get("kind", "crane")) == "crane"
		if r.has("tower"):
			c.tower_offset = LevelKit.v3(r["tower"])
		if str(r.get("kind", "")) == "crusher":
			c.plate_color = "#5a6377"
		elif str(r.get("kind", "")) == "lift":
			c.plate_color = "#ffd23e"
		dynamic.add_child(c)
		movers[str(r["id"])] = c
		nodes[str(r["id"])] = c


func _build_gates_lamps() -> void:
	for gd: Variant in D.get("gates", []):
		var r: Dictionary = gd
		var g: LevelGate = LevelGate.new()
		g.name = str(r["id"]).to_pascal_case()
		g.gate_id = str(r["id"])
		g.size = LevelKit.v3(r["s"])
		g.open_offset = LevelKit.v3(r.get("open", [0, -4, 0]))
		g.speed = float(r.get("speed", 3.0))
		g.gate_color = r.get("color", "#5a6377")
		g.position = LevelKit.v3(r["p"])
		dynamic.add_child(g)
		gates[g.gate_id] = g
		nodes[g.gate_id] = g
	for ld: Variant in D.get("lamps", []):
		var r: Dictionary = ld
		var l: LevelLamp = LevelLamp.new()
		l.lamp_id = str(r["id"])
		l.lamp_radius = float(r.get("r", 0.35))
		l.off_color = r.get("off", "#5a2a1a")
		l.on_color = r.get("on", "#3ee6ff")
		l.blink = bool(r.get("blink", false))
		l.position = LevelKit.v3(r["p"])
		dynamic.add_child(l)
		lamps[l.lamp_id] = l
		nodes[l.lamp_id] = l


func _build_switches() -> void:
	for sd: Variant in D.get("switches", []):
		var r: Dictionary = sd
		var s: MalletSwitch = MalletSwitch.new()
		s.name = str(r["id"]).to_pascal_case()
		s.switch_id = str(r["id"])
		s.actions = r.get("actions", [])
		s.one_shot = bool(r.get("one_shot", true))
		s.cooldown = float(r.get("cooldown", 1.0))
		s.gadget = str(r.get("gadget", ""))
		s.size = LevelKit.v2(r.get("size", [1.0, 1.0]))
		s.position = LevelKit.v3(r["p"])
		s.rotation_degrees.y = float(r.get("ry", 0.0))
		s.switched.connect(func(sw: MalletSwitch, b: Node) -> void: run_actions(sw.actions, sw, b))
		dynamic.add_child(s)
		switches[s.switch_id] = s
		nodes[s.switch_id] = s
		if bool(r.get("one_shot", true)) and r.has("actions"):
			# one-shot switches whose flag is already set load "down"
			for a: Variant in r["actions"]:
				if a is Dictionary and (a as Dictionary).has("flag") and flag(str(a["flag"])):
					s.is_down = true


func _build_collectibles() -> void:
	var planet: String = level_id
	var total: int = int(D.get("gold_total", 5))
	for gd: Variant in D.get("gold_bolts", []):
		var r: Dictionary = gd
		var id: String = str(r["id"])
		if GoldBolt.is_found(id):
			continue
		var g: GoldBolt = GoldBolt.new()
		g.name = "Gold_" + id.replace(".", "_")
		g.gold_id = id
		g.planet = planet
		g.total_on_planet = total
		g.position = LevelKit.v3(r["p"])
		dynamic.add_child(g)
		gold[id] = g
		nodes[id] = g
	var titles: Dictionary = {}
	var mt: Variant = Data.table("bs/story/memos")
	if mt is Dictionary:
		for m: Variant in (mt as Dictionary).get("memos", []):
			titles[str((m as Dictionary)["id"])] = str((m as Dictionary).get("title", ""))
	for md: Variant in D.get("memos", []):
		var r: Dictionary = md
		var id: String = str(r["id"])
		if MemoPickup.is_found(id):
			continue
		var m2: MemoPickup = MemoPickup.new()
		m2.name = "Memo_" + id.replace(".", "_")
		m2.memo_id = id
		m2.title = str(titles.get(id, id))
		m2.position = LevelKit.v3(r["p"])
		dynamic.add_child(m2)
		if r.has("after_flag"):
			m2.set_meta(&"after_flag", str(r["after_flag"]))
			if not flag(str(r["after_flag"])):
				m2.reveal(false)
		memos[id] = m2
		nodes[id] = m2
	if bool(D.get("quest_items_from_quests", false)):
		for qid: String in quest_book.defs.keys():
			var q: Dictionary = quest_book.defs[qid]
			if str(q.get("kind", "")) != "collect":
				continue
			var i: int = 0
			for sp: Variant in q.get("spots", []):
				var qi: QuestItem = QuestItem.new()
				qi.name = "QuestItem_%s_%d" % [qid, i]
				qi.quest_id = qid
				qi.item = str(q.get("item", ""))
				qi.position = LevelKit.v3(sp)
				dynamic.add_child(qi)
				quest_items.append(qi)
				nodes["%s.%d" % [qid, i]] = qi
				i += 1
	for it: Variant in D.get("items", []):
		var r: Dictionary = it
		var id: String = str(r["id"])
		if BS.flag("%s.item.%s" % [level_id, id]):
			continue
		if id == "mallet" and flag("prologue_done"):
			continue
		var li: LevelItem = LevelItem.new()
		li.name = "Item_" + id
		li.item_id = id
		li.level_id = level_id
		li.kind = str(r.get("kind", "cell"))
		li.actions = r.get("actions", [])
		li.director = self
		if r.has("radius"):
			li.radius = float(r["radius"])
		li.position = LevelKit.v3(r["p"])
		dynamic.add_child(li)
		items[id] = li
		nodes["item." + id] = li


func _build_npcs() -> void:
	for nd: Variant in D.get("npcs", []):
		var r: Dictionary = nd
		var n: NPCTalkPoint = NPCTalkPoint.new()
		n.name = "NPC_" + str(r["id"])
		n.npc_id = str(r["id"])
		n.display_name = str(r.get("name", r.get("kind", "")))
		for q: Variant in r.get("quests", []):
			n.quests.append(str(q))
		for b: Variant in r.get("barks", []):
			n.barks.append(str(b))
		n.idle_line = str(r.get("idle", ""))
		n.body_color = r.get("color", "#9a8a6a")
		n.bark_radius = float(common.get("denizen_bark_radius", 3.4))
		n.bark_cd = float(common.get("denizen_bark_cd", 12.0))
		n.radius = float(common.get("interact_radius", 2.2))
		n.lines = lines
		n.position = LevelKit.v3(r["p"])
		dynamic.add_child(n)
		npcs[n.npc_id] = n
		nodes[n.npc_id] = n
	if not flag("prologue_done"):
		for dd: Variant in D.get("dummies", []):
			var td: TestDummy = TestDummy.new()
			td.name = "RepoDroneDummy"
			td.position = LevelKit.v3((dd as Dictionary)["p"])
			td.add_to_group(&"prologue_only")
			dynamic.add_child(td)
			LevelKit.box(td, Vector3(0, 0.9, 0), Vector3(0.9, 1.4, 0.9), "#5a6377", false)


func _build_relays_and_interacts() -> void:
	for rd: Variant in D.get("relays", []):
		var r: Dictionary = rd
		var c: CheckpointRelay = CheckpointRelay.new()
		c.name = "Relay_" + str(r["id"])
		c.relay_id = str(r["id"])
		c.label = str(r.get("label", ""))
		c.heal_frac = float(common.get("checkpoint_heal", 0.25))
		c.position = LevelKit.v3(r["p"])
		c.set_meta(&"start", bool(r.get("start", false)))
		c.activated.connect(_on_relay)
		dynamic.add_child(c)
		relays[c.relay_id] = c
		nodes["relay." + c.relay_id] = c
	if D.has("beacon"):
		beacon = SaveBeacon.new()
		beacon.name = "SaveBeacon"
		beacon.radius = float(common.get("interact_radius", 2.2))
		beacon.host = host
		beacon.position = LevelKit.v3((D["beacon"] as Dictionary)["p"])
		dynamic.add_child(beacon)
		nodes["beacon"] = beacon
	for idd: Variant in D.get("interacts", []):
		var r: Dictionary = idd
		var ip: InteractPoint = InteractPoint.new()
		ip.name = "Interact_" + str(r["id"])
		ip.prompt = str(r.get("prompt", ""))
		ip.actions = r.get("actions", [])
		ip.radius = float(common.get("interact_radius", 2.2))
		ip.position = LevelKit.v3(r["p"])
		ip.interacted.connect(func(pt: InteractPoint, b: Node) -> void: run_actions(pt.actions, pt, b))
		dynamic.add_child(ip)
		nodes["interact." + str(r["id"])] = ip
	if D.has("kiosk"):
		# Blartz kiosk: the UI/systems builder's ShopKiosk (tip jar, shop screen, prompt)
		var kd: Dictionary = D["kiosk"]
		var ks: Script = _global_script("ShopKiosk")
		if ks != null:
			kiosk = ks.new() as Node3D
			kiosk.name = "Kiosk"
			kiosk.position = LevelKit.v3(kd["p"])
			kiosk.rotation_degrees.y = float(kd.get("ry", 0.0))
			dynamic.add_child(kiosk)
			nodes["kiosk"] = kiosk
	if D.has("teleporter"):
		exit = TeleporterExit.new()
		exit.name = "ReturnRelay"
		exit.planet_id = level_id
		exit.planet_index = int(D.get("planet_index", 0))
		exit.campaign_step_after = int(D.get("campaign_step_after", 1))
		exit.position = LevelKit.v3((D["teleporter"] as Dictionary)["p"])
		exit.planet_completed.connect(_on_exit_completed)
		dynamic.add_child(exit)
		nodes["teleporter"] = exit


func _on_relay(r: CheckpointRelay, _b: Node) -> void:
	for o: CheckpointRelay in relays.values():
		if o != r:
			o.deactivate()
	set_respawn(r.respawn_pos(), LevelKit.text(r.label))


## Moves the respawn point: BSLevel.set_checkpoint(pos, label) when present, else the host's spawn_point.
func set_respawn(p: Vector3, label: String = "") -> void:
	respawn_point = p
	if host == null:
		return
	if host.has_method("set_checkpoint"):
		host.call("set_checkpoint", p, label)
	elif "spawn_point" in host:
		host.set("spawn_point", p)


func _on_exit_completed(id: String) -> void:
	_host_call("complete_level", [])
	planet_completed.emit(id)


func _build_triggers() -> void:
	for td: Variant in D.get("triggers", []):
		var r: Dictionary = td
		if not r.has("p"):
			continue
		var t: TriggerVolume = TriggerVolume.new()
		t.name = "Trigger_" + str(r["id"])
		t.trigger_id = str(r["id"])
		t.size = LevelKit.v3(r["s"])
		t.once = bool(r.get("once", true))
		t.cooldown = float(r.get("cooldown", 0.0))
		for f: Variant in r.get("requires", []):
			t.requires.append(str(f))
		for f: Variant in r.get("forbids", []):
			t.forbids.append(str(f))
		t.actions = r.get("actions", [])
		t.gate_check = _gate_check
		t.position = LevelKit.v3(r["p"])
		t.fired.connect(func(tv: TriggerVolume, b: Node) -> void: run_actions(tv.actions, tv, b))
		dynamic.add_child(t)
		triggers[t.trigger_id] = t


func _build_encounters() -> void:
	for ed: Variant in D.get("encounters", []):
		var r: Dictionary = ed
		var e: Encounter = Encounter.new()
		e.name = "Encounter_" + str(r["id"])
		e.encounter_id = str(r["id"])
		e.waves = r.get("waves", [])
		e.on_clear = r.get("on_clear", [])
		e.set_meta(&"autostart", bool(r.get("autostart", false)))
		e.set_meta(&"zone", str(r.get("zone", "")))
		e.cleared.connect(func(en: Encounter) -> void: run_actions(en.on_clear, en, bolt()))
		dynamic.add_child(e)
		encounters[e.encounter_id] = e


func _build_boss_arena() -> void:
	var B: Dictionary = D.get("boss", {})
	if not B.has("walls"):
		return
	var W: Dictionary = B["walls"]
	walls = CompactorWalls.new()
	walls.name = "CompactorWalls"
	walls.center = LevelKit.v3(W.get("center"))
	walls.start_width = float(W.get("start_width", 36.0))
	walls.min_width = float(W.get("min_width", 14.0))
	walls.wall_size = LevelKit.v3(W.get("wall_size", [2, 4, 24]))
	walls.speed = float(W.get("speed", 2.0))
	dynamic.add_child(walls)
	nodes["compactor_walls"] = walls
	var riders: Dictionary = W.get("riders", {})
	for rid: String in riders.keys():
		var n: Node3D = nodes.get(rid) as Node3D
		if n != null:
			walls.add_rider(n, float(riders[rid]))


# ================================================================== pickups

const PICKUP_KINDS: Dictionary = {"bolt": &"bolt", "ammoR": &"ammo_r", "ammoZ": &"ammo_z"}


## Loose bolts and ammo orbs at the data's pickup spots, through the enemy builder's Pickup.spawn().
func _spawn_pickups() -> void:
	var ps: Script = _global_script("Pickup")
	if ps == null:
		return
	for m: Node in get_tree().get_nodes_in_group(&"pickup_spots"):
		if not is_ancestor_of(m):
			continue
		var kind: String = str(m.get_meta(&"kind", ""))
		if PICKUP_KINDS.has(kind):
			ps.call("spawn", dynamic, PICKUP_KINDS[kind], (m as Node3D).global_position)
			pickups_spawned += 1


static func _global_script(cls: String) -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == cls and ResourceLoader.exists(str(c["path"])):
			return load(str(c["path"])) as Script
	return null


# ================================================================== node helpers

func _remove_node(id: String) -> void:
	var n: Node = nodes.get(id)
	if n == null or not is_instance_valid(n):
		return
	nodes.erase(id)
	n.queue_free()


func _set_group_visible(gname: String, on: bool) -> void:
	var g: Node3D = nodes.get(gname) as Node3D
	if g == null:
		return
	g.visible = on
	_set_group_collision(g, on)


func _set_group_collision(n: Node, on: bool) -> void:
	for c: Node in n.find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).set_deferred(&"disabled", not on)


## Phase 3: the container stack is crushed flat (the high ground goes away).
func _crush(id: String) -> void:
	var g: Node3D = nodes.get(id) as Node3D
	if g == null:
		return
	var aabb_min: Vector3 = Vector3.INF
	var aabb_max: Vector3 = -Vector3.INF
	for c: Node in g.get_children():
		if c is Node3D:
			aabb_min = aabb_min.min((c as Node3D).global_position)
			aabb_max = aabb_max.max((c as Node3D).global_position)
	_remove_node(id)
	if aabb_min.x < INF:
		var mid: Vector3 = (aabb_min + aabb_max) * 0.5
		var flat: Node3D = LevelKit.box(dynamic, Vector3(mid.x, aabb_min.y - 0.45, mid.z), Vector3(6.4, 0.6, 2.9), "car2", true)
		nodes[id] = flat
