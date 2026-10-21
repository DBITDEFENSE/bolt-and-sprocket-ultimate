class_name RustvaneLevel
extends BSLevel
## Rustvane Canyon (Planet 2, LEVELS[1]): OmniScrap's two-star influencer resort on top of a worker-owned mine.
## Everything is data (data/bs/levels/rustvane.json); a RustvaneDirector builds and runs it. This script wires
## the director into BSLevel's lifecycle, puts the gadget belt on Bolt (GadgetManager), plays the level-owned
## cutscene scripts (the JSON's "cutscenes"), answers the cutscene runner's anchors / actors / fx, and plays
## the shield reveal the first time Bolt leaves Rustvane.
##
## Critical path (BS_LEVELS §3.2, remade): Old Co-op Camp (Tether-Hook) + Back of House (staff badge) ->
## the Strip Mine (badge door, hook pull up the gantry) -> the Rustvane Sentinel on the Quarry Floor
## (SECURITY lamp) and the scenic towers (hook pull) -> the Top Billboard Deck (WRISTBAND lamp, l2_mid,
## firmwareScene) -> the long zip line -> the VIP gate (ccIntro) -> The Content Creator -> l2_glambot ->
## the Return Relay -> shieldReveal.

const LEVEL_ID: String = "rustvane"

var director: RustvaneDirector
var gadgets: GadgetManager
var level_cutscenes_played: PackedStringArray = []    # level-owned scripts started (tests read it)


func build() -> void:
	level_id = LEVEL_ID
	planet_index = 1
	director = RustvaneDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup(self, LEVEL_ID)
	level_name = str(director.D.get("name", "RUSTVANE CANYON"))
	spawn_point = director.start_point()
	kill_y = director.kill_y
	water_zones = director.water_zones


func on_level_ready() -> void:
	gadgets = GadgetManager.attach_to(bolt)
	director.level_ready()


## First landing: flyover1 then arrive1, back to back (BS_LEVELS §3.9), each once per save.
func arrival_beat() -> void:
	var q: PackedStringArray = []
	for cs: Variant in (director.D.get("story", {}) as Dictionary).get("arrival_cutscenes", ["flyover1", "arrive1"]):
		if not BS.flag("cs." + str(cs)) and (CutscenePlayer.has_scene(str(cs)) or director.has_level_cutscene(str(cs))):
			q.append(str(cs))
	_play_queue(q)


# ------------------------------------------------------------------ cutscenes

## Level-owned scripts first (data/bs/levels/rustvane.json "cutscenes"), then the story file's.
func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	if director != null and director.has_level_cutscene(id):
		return play_level_cutscene(id, on_done)
	return super.play_cutscene(id, on_done)


## Plays a level cutscene through the shared CutscenePlayer. Uses its public play_steps() when the lead adds
## one; until then the player's internal _start (same step runner the story scenes use).
func play_level_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	var steps: Array = director.level_cutscene_steps(id)
	level_cutscenes_played.append(id)
	if steps.is_empty() or cutscenes == null:
		if on_done.is_valid():
			on_done.call()
		return false
	if cutscenes.has_method(&"play_steps"):
		return bool(cutscenes.call(&"play_steps", id, steps, on_done))
	cutscenes.call(&"_start", id, steps, false, on_done)
	return true


## A level cutscene with a beat's id plays as that beat (l2_glambot gets cameras on the Sunset Stage).
func story_beat(id: String, on_done: Callable = Callable()) -> bool:
	if director != null and director.has_level_cutscene(id):
		if BS.flag("beat." + id):
			return false
		BS.set_flag("beat." + id)
		EventBus.story_beat.emit(id)
		BS.save_to_profile()
		return play_level_cutscene(id, on_done)
	return super.story_beat(id, on_done)


func cutscene_anchor(anchor: String) -> Vector3:
	var anchors: Dictionary = (director.D.get("story", {}) as Dictionary).get("anchors", {}) if director != null else {}
	if anchors.has(anchor):
		return LevelKit.v3(anchors[anchor])
	if anchor == "boss" and director != null and director._boss_present():
		return director.rv_boss.global_position
	return super.cutscene_anchor(anchor)


func cutscene_actor(actor: String) -> Node3D:
	if director == null:
		return super.cutscene_actor(actor)
	if actor == "cc" and director._boss_present():
		return director.rv_boss
	var a: Node3D = director.get_actor(actor)
	return a if a != null else super.cutscene_actor(actor)


## The web build's JS fx steps, re-done where they matter: arrive1 lifts the ship 14 m so the act "drop"
## lands it on the pad; firmwareScene sets Sprocket alarmed; the rest is flavour (sfx, flashes) and skipped.
func cutscene_fx(scene: String, index: int, _step: Dictionary) -> void:
	if scene == "arrive1" and index == 0:
		var ship: Node3D = director.get_actor("ship")
		if ship != null:
			ship.position.y += float((director.D.get("story", {}) as Dictionary).get("ship_drop", 14.0))
	elif scene == "firmwareScene" and sprocket != null:
		sprocket.set_mood(&"alarmed", 6.0)


# ------------------------------------------------------------------ leaving

## The ship (interact): leave at any time. The first departure after Rustvane is cleared plays shieldReveal
## (btnNext, index.html:17734), then the star map.
func board_ship() -> void:
	if (BS.flag("cleared." + level_id) or BS.flag("planet_complete." + level_id)) and not BS.flag("cs.shieldReveal"):
		play_cutscene("shieldReveal", _open_map)
	else:
		_open_map()


func _open_map() -> void:
	if has_method(&"open_star_map"):
		call(&"open_star_map")
	else:
		director.lines.play_line("bs.rustvane.ship_ready")


## Stepping on the Return Relay: the shield goes up first (once per save), then the summary.
func complete_level() -> void:
	if completed:
		return
	if not BS.flag("cs.shieldReveal") and cutscenes != null and CutscenePlayer.has_scene("shieldReveal"):
		play_cutscene("shieldReveal", _complete_now)
		return
	super.complete_level()


func _complete_now() -> void:
	super.complete_level()
