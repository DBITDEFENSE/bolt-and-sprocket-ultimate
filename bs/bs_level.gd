class_name BSLevel
extends Node3D
## Base of every Bolt & Sprocket planet scene. A planet script extends this, sets the properties, builds its
## geometry in build() and wires its content in on_level_ready().
##
## _ready sequence:
##   1. build()                        (subclass: geometry, props, kiosk, triggers)
##   2. Bolt at spawn_point (+ kill_y, water_zones), BoltCamera (bolt.camera / camera.target), Sprocket,
##      the HUD, the cutscene player, the dev console and the pause menu
##   3. AimAssist.player / enabled_mode; WeaponManager.attach_to(bolt) when the weapons code exists
##   4. Game mode, mouse capture (never headless; only with a focused window)
##   5. on_level_ready()               (subclass: enemies, quests, hints)
##   6. arrival_beat()                 (first-visit cutscenes; overridable)
##
## API (planets, world objects, enemies and the console call these):
##   play_cutscene(id, on_done) -> bool   story_beat(id) -> bool (once per save, BS.flags "beat.<id>")
##   show_hint(text, key)  (once per key)   banner(title, sub, secs)   set_objective(text, pos)
##   set_checkpoint(pos, label)   save_game()   complete_level()   respawn()
##   cutscene_anchor(name) -> Vector3 and cutscene_actor(name) -> Node3D and cutscene_fx(scene, i, step):
##   virtual hooks for cutscene steps ("garagePos(...)", act "garage").
## Signals: level_completed, player_respawned.

signal level_completed(level_id: String)
signal player_respawned

const MENU_SCENE: String = "res://ui/main_menu.tscn"

## Set by the main menu (or anything that loads a level) to play a cutscene right after the level boots.
static var pending_cutscene: String = ""

@export var spawn_point: Vector3 = Vector3(0, 1.0, 0)
@export var kill_y: float = -40.0
@export var water_zones: Array[AABB] = []
@export var planet_index: int = 0
@export var level_id: String = ""
@export var level_name: String = ""
## Play the first-visit arrival cutscenes (tests turn it off).
@export var play_arrival: bool = true

var bolt: Bolt
var camera: BoltCamera
var sprocket: Sprocket
var hud: BSHud
var cutscenes: CutscenePlayer
var console: DevConsole
var pause_menu: BSPauseMenu
var weapons: Node = null
var checkpoint: Dictionary = {}           # {pos, label}
var level_time: float = 0.0
var level_bolts: int = 0
var completed: bool = false
var dead_timer: float = -1.0
var _hints: Dictionary = {}


## Subclass: build the level geometry.
func build() -> void:
	pass


## Subclass: everything that needs Bolt / the HUD to exist.
func on_level_ready() -> void:
	pass


## This planet's out-of-bounds splash quips (line ids, from the level data's "splash_quips"; empty = all six).
var splash_quips: PackedStringArray = []


func _ready() -> void:
	if level_id != "" and Data.has_table("bs/levels/" + level_id):
		var ld: Variant = Data.table("bs/levels/" + level_id)
		if ld is Dictionary:
			splash_quips = PackedStringArray((ld as Dictionary).get("splash_quips", []))
	# The shared game hosts several modes: B&S bindings back on, Gravelight's overlays off (T-024).
	Game.set_mode(Game.Mode.BOLT_AND_SPROCKET)
	if Engine.has_singleton(&"GLSettings") or get_node_or_null(^"/root/GLSettings") != null:
		get_node(^"/root/GLSettings").call("deactivate")
	InputSetup.apply(SaveProfile.doc.get("input_overrides", {}))
	build()
	_spawn_player()
	_spawn_ui()
	AimAssist.player = bolt
	AimAssist.enabled_mode = true
	weapons = attach_weapons(bolt)
	Game.set_mode(Game.Mode.BOLT_AND_SPROCKET)
	BSStyle.capture_mouse(get_tree())
	EventBus.bolts_changed.connect(_on_bolts)
	on_level_ready()
	var pend: String = pending_cutscene
	pending_cutscene = ""
	if pend != "":
		play_cutscene(pend, arrival_beat if play_arrival else Callable())
	elif play_arrival:
		arrival_beat()


func _exit_tree() -> void:
	if AimAssist.player == bolt:
		AimAssist.player = null
		AimAssist.enabled_mode = false


func _spawn_player() -> void:
	bolt = Bolt.new()
	bolt.name = "Bolt"
	add_child(bolt)
	bolt.global_position = spawn_point
	bolt.last_safe = spawn_point
	bolt.kill_y = kill_y
	bolt.water_zones = water_zones
	bolt.died.connect(_on_died)
	camera = BoltCamera.new()
	camera.name = "BoltCamera"
	camera.target = bolt
	add_child(camera)
	bolt.camera = camera
	sprocket = Sprocket.new()
	sprocket.name = "Sprocket"
	sprocket.bolt = bolt
	add_child(sprocket)


func _spawn_ui() -> void:
	MapState.attach(self, StringName(level_id), "bs")   # the planet's holo minimap (Update 04, T-065)
	hud = BSHud.new()
	hud.name = "HUD"
	hud.bolt = bolt
	add_child(hud)
	cutscenes = CutscenePlayer.new()
	cutscenes.name = "Cutscenes"
	cutscenes.host = self
	add_child(cutscenes)
	console = DevConsole.new()
	console.name = "DevConsole"
	console.host = self
	console.mode = &"bs"
	add_child(console)
	pause_menu = BSPauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.restart_requested.connect(restart_level)
	pause_menu.quit_requested.connect(quit_to_menu)
	add_child(pause_menu)


## WeaponManager (weapons builder): a global class with a static attach_to(bolt), or an autoload with
## attach_to(bolt). Returns what attach_to returned (the manager node), or null when it isn't there yet.
static func attach_weapons(b: Bolt) -> Node:
	var tree: SceneTree = b.get_tree()
	var auto: Node = tree.root.get_node_or_null("WeaponManager") if tree != null else null
	if auto != null and auto.has_method("attach_to"):
		return auto.call("attach_to", b) as Node
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c["class"]) == "WeaponManager" and ResourceLoader.exists(str(c["path"])):
			var s: Script = load(str(c["path"])) as Script
			if s != null and s.can_instantiate():
				for m: Dictionary in s.get_script_method_list():
					if str(m["name"]) == "attach_to":
						return s.call("attach_to", b) as Node
	return b.get_node_or_null("Weapons")


## First-visit beats: Scrapheap opens with the intro (The Repossession) unless it has played, then each
## planet's "arrive<planet_index>" landing scene once.
func arrival_beat() -> void:
	var queue: PackedStringArray = []
	if planet_index == 0 and not BS.flag("cs.intro"):
		queue.append("intro")
	var arr: String = "arrive%d" % planet_index
	if CutscenePlayer.has_scene(arr) and not BS.flag("cs." + arr):
		queue.append(arr)
	_play_queue(queue)


func _play_queue(q: PackedStringArray) -> void:
	if q.is_empty():
		return
	var first: String = q[0]
	var rest: PackedStringArray = q.slice(1)
	play_cutscene(first, func() -> void: _play_queue(rest))


func _process(delta: float) -> void:
	if not BS.blocked() and not completed:
		level_time += delta
	if dead_timer >= 0.0:
		dead_timer -= delta
		if dead_timer < 0.0:
			respawn()


# ------------------------------------------------------------------ story

func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	return cutscenes.play(id, on_done)


## Plays a story beat once per save (storyBeat 11832): a cutscenes.json scene if one exists with that id,
## else the story_beats.json lines as dialogue. Returns false if already seen or unknown.
func story_beat(id: String, on_done: Callable = Callable()) -> bool:
	if BS.flag("beat." + id):
		return false
	var beats: Variant = Data.table("bs/story/story_beats")
	var lines: Array = ((beats as Dictionary).get(id, {}) as Dictionary).get("lines", []) if beats is Dictionary else []
	if not CutscenePlayer.has_scene(id) and lines.is_empty():
		return false
	BS.set_flag("beat." + id)
	EventBus.story_beat.emit(id)
	BS.save_to_profile()
	if CutscenePlayer.has_scene(id):
		return cutscenes.play(id, on_done)
	return cutscenes.play_lines(id, lines, on_done)


## showHint 17105: shown once per key (empty key = always).
func show_hint(text: String, key: String = "") -> bool:
	if key != "":
		if _hints.has(key) or BS.flag("hint." + key):
			return false
		_hints[key] = true
	EventBus.hint.emit(text, key)
	return true


func banner(title: String, sub: String = "", secs: float = 2.2) -> void:
	EventBus.banner.emit(title, sub, secs)


func set_objective(text: String, world_pos: Vector3 = Vector3.INF) -> void:
	hud.set_objective(text, world_pos)


## Cutscene anchor positions for "<name>Pos([..])" steps; planets override (e.g. the garage).
func cutscene_anchor(_anchor: String) -> Vector3:
	return spawn_point


## Cutscene actors for act steps; planets override. Looks for a child node named like the actor.
func cutscene_actor(actor: String) -> Node3D:
	return find_child(actor, true, false) as Node3D


func cutscene_fx(_scene: String, _index: int, _step: Dictionary) -> void:
	pass


# ------------------------------------------------------------------ checkpoints, death, completion

## Relay checkpoints (activateCheckpoint): respawn() returns here.
func set_checkpoint(pos: Vector3, label: String = "") -> void:
	checkpoint = {"pos": pos, "label": label}


## The save beacon calls this (saveGame).
func save_game() -> void:
	BS.save_to_profile()


func _on_bolts(_total: int, delta: int) -> void:
	if delta > 0:
		level_bolts += delta


## damagePlayer death (index.html:4383): "BOLT DOWN!" then respawn after 1.5 s.
func _on_died() -> void:
	banner(BSText.text("code.damagePlayer.01"), BSText.text("code.damagePlayer.02"), 2.2)
	dead_timer = 1.5


## respawn 17621: back to the last relay checkpoint (or the spawn), full HP.
func respawn() -> void:
	dead_timer = -1.0
	var at: Vector3 = checkpoint.get("pos", spawn_point)
	bolt.respawn_at(at)
	if not checkpoint.is_empty():
		banner(BSText.text("code.respawn.01"), str(checkpoint.get("label", "")), 1.4)
	player_respawned.emit()


## completeLevel 17599: marks the planet cleared, saves, shows the summary.
## Gold bolts on this planet (the level data's gold_total; the summary shows "found / total").
func _gold_total_from_data() -> int:
	var d: Variant = Data.table("bs/levels/" + level_id) if Data.has_table("bs/levels/" + level_id) else null
	return int((d as Dictionary).get("gold_total", 3)) if d is Dictionary else 3


func complete_level() -> void:
	if completed:
		return
	completed = true
	if level_id != "":
		BS.set_flag("cleared." + level_id)
	var cleared: Array = (SaveProfile.doc["bs"] as Dictionary).get("planets_cleared", [])
	if not (planet_index in cleared):
		cleared.append(planet_index)
	BS.save_to_profile()
	BS.ui_block += 1
	BSStyle.free_mouse()
	var gold_total: int = _gold_total_from_data()
	var gold: int = 0
	for k: Variant in BS.flags.keys():
		if str(k).begins_with("gold.%s." % level_id) and BS.flag(str(k)):
			gold += 1
	hud.show_summary(level_name if level_name != "" else level_id.to_upper(), level_bolts, "%d / %d" % [gold, gold_total], level_time, to_star_map)
	level_completed.emit(level_id)


func restart_level() -> void:
	get_tree().paused = false
	BS.ui_block = 0
	get_tree().reload_current_scene.call_deferred()


## The summary's STAR MAP button (html.btnMap): pick the next planet (M3 minimal star map; full port in M4).
func to_star_map() -> void:
	BS.save_to_profile()
	StarMap.open(get_tree())


func quit_to_menu() -> void:
	get_tree().paused = false
	BS.ui_block = 0
	BS.save_to_profile()
	BSStyle.free_mouse()
	Game.set_mode(Game.Mode.MENU)
	get_tree().change_scene_to_file.call_deferred(MENU_SCENE)
