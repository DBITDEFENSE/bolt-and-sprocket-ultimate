class_name NovaPlazaLevel
extends BSLevel
## Nova Plaza (Planet 4, LEVELS[5]; BS_LEVELS §4): a fully automated smart city with zero residents.
## Data-driven like Scrapheap: a LevelDirector builds the generic rows of data/bs/levels/nova_plaza.json and
## a NovaBuilder the Nova pieces ("nova": towers, walkways + the HOA violation system, lamp-post Tether points,
## Compliance Eyes, updrafts, the Transit Loop and its car, the FineTree Plaza arena, the Keystone Core).
##
## Critical path: an HOA Variance (the clubhouse rules board, west) and a Permit to Approach (the take-a-number
## hall, east), in either order -> the Transit Loop car carries Bolt from the Civic Center station to the
## FineTree deck -> The Algorithm -> the Keystone Core -> the Return Relay on the landing pad.
##
## Story: flyover5 on the first landing; novaMid (Civic Center), novaHolo (HOA Clubhouse), novaLate (riding
## the Loop past a FineTree screen) as story beats; novaIntro on the FineTree deck and introAlgorithm on the
## Algorithm's first aggro as cutscenes; coreNova on the core pickup. Nova-only cutscene scripts live in the
## level data's "cutscenes" table and play through the shared cutscene player (play_cutscene override).
##
## The boss: EnemySpawner.spawn(&"the_algorithm", pos, parent, {"arena": FineTreeArena}) (builder D). While
## that id doesn't exist yet, a TestDummy stand-in with the data's HP takes its place so the planet can be
## finished (the smoke test reports which one fought).

const LEVEL_ID: String = "nova_plaza"

var director: LevelDirector
var nova: NovaBuilder
var boss: Node3D = null
var boss_is_stand_in: bool = false
var boss_active: bool = false
var boss_done: bool = false
var boss_log: PackedStringArray = []          # what happened in the fight (tests / smoke)
var objectives: PackedStringArray = []
var _phases_done: Dictionary = {}
var _boss_max: float = 1.0


func build() -> void:
	level_id = LEVEL_ID
	planet_index = 5
	director = LevelDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup(self, LEVEL_ID)
	nova = NovaBuilder.new()
	nova.build(director)
	nova.rebake()
	level_name = str(director.D.get("name", "NOVA PLAZA"))
	spawn_point = director.start_point()
	kill_y = director.kill_y
	water_zones = director.water_zones
	_hide_until_flags()
	if nova.train != null:
		nova.train.arrived.connect(_on_train_arrived)
	if nova.arena != null:
		nova.arena.notice_delivered.connect(func(slot: StringName, _by: Node) -> void: boss_log.append("notice:" + String(slot)))
	EventBus.boss_defeated.connect(_on_boss_defeated_event)
	EventBus.enemy_killed.connect(_on_enemy_killed_event)
	EventBus.boss_health.connect(_on_boss_health)


## Items and groups that only appear once a flag is set (the variance stamp after the three rules).
func _hide_until_flags() -> void:
	for hd: Variant in (director.D.get("nova", {}) as Dictionary).get("hidden_items", []):
		var h: Dictionary = hd
		var n: Node = director.nodes.get(str(h["node"]))
		if n is Collectible and not director.flag(str(h["unless"])):
			(n as Collectible).reveal(false)


func on_level_ready() -> void:
	director.level_ready()
	if director.flag("algorithm_down"):
		boss_done = true
		reveal_core()
	var o: String = str((director.D.get("story", {}) as Dictionary).get("objective", ""))
	if o != "" and not director.flag("algorithm_down"):
		objective(o)


## flyover5 on the first landing (BS_LEVELS §4.9). There is no arrive5 scene in the story data.
func arrival_beat() -> void:
	var q: PackedStringArray = []
	for cs: Variant in (director.D.get("story", {}) as Dictionary).get("arrival_cutscenes", []):
		if not BS.flag("cs." + str(cs)):
			q.append(str(cs))
	_play_queue(q)


# ------------------------------------------------------------------ cutscenes as level data

func level_cutscene(id: String) -> Dictionary:
	return (director.D.get("cutscenes", {}) as Dictionary).get(id, {}) if director != null else {}


## Level-data cutscenes ("cutscenes" in nova_plaza.json) play through the shared player; anything else falls
## through to cutscenes.json.
func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	var def: Dictionary = level_cutscene(id)
	if def.is_empty():
		return super.play_cutscene(id, on_done)
	# CutscenePlayer has no public "play these steps" yet (gap reported); _start is its internal entry point.
	cutscenes.call("_start", id, def.get("steps", []), false, on_done)
	return true


func cutscene_anchor(anchor: String) -> Vector3:
	var anchors: Dictionary = (director.D.get("story", {}) as Dictionary).get("anchors", {}) if director != null else {}
	if anchors.has(anchor):
		return LevelKit.v3(anchors[anchor])
	return super.cutscene_anchor(anchor)


func cutscene_actor(actor: String) -> Node3D:
	var a: Node3D = director.get_actor(actor) if director != null else null
	return a if a != null else super.cutscene_actor(actor)


# ------------------------------------------------------------------ host calls from data actions

## {"host": "objective", "args": ["bs.nova.obj_..."]}
func objective(line_id: String) -> void:
	objectives.append(line_id)
	if hud != null:
		set_objective(LevelKit.text(line_id))


func open_star_map() -> void:
	BS.save_to_profile()
	if DisplayServer.get_name() == "headless":
		return
	StarMap.open(get_tree())


func stamps_ok() -> bool:
	return director.flag("variance") and director.flag("permit")


## {"host": "board_train", "args": ["finetree", -1]}: the station interact.
func board_train(goal: String, via: float = 0.0) -> bool:
	var t: NovaTrain = nova.train
	if t == null or t.moving:
		return false
	if not stamps_ok():
		director.lines.play_line("bs.nova.train_locked")
		return false
	if t.station == goal:
		return false
	var ok: bool = t.ride(goal, bolt, via)
	if ok:
		director.run_actions((director.D.get("nova", {}) as Dictionary).get("on_depart", {}).get(goal, []), t, bolt)
	return ok


func _on_train_arrived(station: String) -> void:
	director.run_actions((director.D.get("nova", {}) as Dictionary).get("on_arrive", {}).get(station, []), nova.train, bolt)


# ------------------------------------------------------------------ the Algorithm

## {"host": "start_algorithm"}: the plaza trigger. The title card plays once per save, then the boss spawns.
func start_algorithm() -> void:
	if boss_active or boss_done or director.flag("algorithm_down"):
		return
	boss_active = true
	_phases_done.clear()
	var B: Dictionary = director.D.get("boss", {})
	director.run_actions(B.get("on_start", []), self, bolt)
	var card: String = str(B.get("title_card", "introAlgorithm"))
	if card != "" and not BS.flag("cs." + card):
		if play_cutscene(card, _spawn_algorithm):
			return
	_spawn_algorithm()


func _spawn_algorithm() -> void:
	if boss != null:
		return
	var B: Dictionary = director.D.get("boss", {})
	var id: StringName = StringName(str(B.get("id", "the_algorithm")))
	var arena: FineTreeArena = nova.arena
	var at: Vector3 = arena.boss_spawn() if arena != null else LevelKit.v3(B.get("spawn"))
	boss = NovaSpawn.spawn(id, at, director.dynamic, {"arena": arena}, false)
	if boss == null:
		boss = _stand_in(B, at)
		boss_is_stand_in = true
		boss_log.append("stand_in")
	else:
		boss_log.append("spawned:" + String(id))
		boss.set_meta(&"level_director", director)
		if boss.has_method("start_fight"):
			boss.call("start_fight")
	_boss_max = maxf(1.0, float(boss.get("max_hp")) if boss.get("max_hp") != null else 1.0)
	if arena != null:
		arena.begin_fight()
	director.boss = boss
	director.boss_engaged.emit(boss)


## The Algorithm isn't built yet: a TestDummy with the boss's HP behind a server-wall placeholder.
func _stand_in(B: Dictionary, at: Vector3) -> Node3D:
	var d: TestDummy = TestDummy.new()
	d.name = "AlgorithmStandIn"
	d.max_hp = float(B.get("stand_in_hp", 520.0))
	d.hp = d.max_hp
	d.radius = 2.0
	d.add_to_group(&"bosses")
	d.set_meta(&"enemy_id", str(B.get("id", "the_algorithm")))
	director.dynamic.add_child(d)
	d.global_position = at
	LevelKit.box(d, Vector3(0, 1.6, 0), Vector3(3.2, 3.2, 1.2), "#1a2240", false)
	LevelKit.box(d, Vector3(0, 2.2, 0.62), Vector3(2.0, 0.5, 0.04), "#ffd23e", false, Vector3.ZERO, 1, 2.0)
	EventBus.boss_started.emit(StringName(str(B.get("id", "the_algorithm"))), LevelKit.text(str(B.get("name_line", "code.updateAlgorithm.01"))))
	banner(LevelKit.text(str(B.get("name_line", "code.updateAlgorithm.01"))), LevelKit.text("code.bossStart.01"), 2.4)
	return d


func boss_hp_frac() -> float:
	if boss == null or not is_instance_valid(boss) or boss.get("hp") == null:
		return 0.0
	return clampf(float(boss.get("hp")) / _boss_max, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	if not boss_active or boss_done:
		return
	if boss == null:
		return
	if not is_instance_valid(boss) or (boss.has_method("is_alive") and not bool(boss.call("is_alive"))):
		_algorithm_defeated()
		return
	var f: float = boss_hp_frac()
	if boss_is_stand_in:
		EventBus.boss_health.emit(StringName(str((director.D.get("boss", {}) as Dictionary).get("id", "the_algorithm"))), f, 0.0)
	_check_phases(f)


func _on_boss_health(_id: StringName, frac: float, _b: float) -> void:
	if boss_active and not boss_done:
		_check_phases(frac)


## Arena-side phase changes (data "boss.phases"): the Doomscroll floor at 33% if the boss hasn't started it.
func _check_phases(frac: float) -> void:
	var phases: Array = (director.D.get("boss", {}) as Dictionary).get("phases", [])
	for i: int in phases.size():
		var ph: Dictionary = phases[i]
		if not _phases_done.has(i) and frac <= float(ph.get("below", 0.0)):
			_phases_done[i] = true
			boss_log.append("phase:%d" % (i + 2))
			director.run_actions(ph.get("actions", []), self, bolt)


func phase_count() -> int:
	return _phases_done.size()


## {"host": "arena_doomscroll", "args": [true]}
func arena_doomscroll(on: bool) -> void:
	if nova.arena != null and nova.arena.doomscroll_on() != on:
		nova.arena.set_doomscroll(on)


## {"host": "arena_reverse"}: the walkway ring reverses (phase 2 rhythm when the boss doesn't drive it).
func arena_reverse(seconds: float = 6.0) -> void:
	if nova.arena != null:
		nova.arena.reverse_walkways(seconds)


func _on_boss_defeated_event(_id: StringName) -> void:
	if boss_active and not boss_done:
		_algorithm_defeated()


func _on_enemy_killed_event(e: Node, _w: StringName) -> void:
	if boss_active and not boss_done and e == boss:
		_algorithm_defeated()


func _algorithm_defeated() -> void:
	if boss_done:
		return
	boss_done = true
	boss_active = false
	boss_log.append("defeated")
	if nova.arena != null:
		nova.arena.end_fight()
	if boss_is_stand_in and is_instance_valid(boss):
		boss.queue_free()
	director.run_actions((director.D.get("boss", {}) as Dictionary).get("on_defeat", []), self, bolt)
	director.boss_down.emit()


## {"host": "reveal_core"}
func reveal_core() -> void:
	if nova.core != null and is_instance_valid(nova.core):
		nova.core.reveal(true)
