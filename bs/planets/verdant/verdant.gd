class_name VerdantLevel
extends BSLevel
## Verdant Sink (Planet 6, LEVELS[7]; BS_LEVELS §6): a failed TerraFarm terraforming project. The mega-harvester
## HR-9 has leaked coolant into the swamp for six years; everything mutated around it, glows, talks, and the corn
## unionized (Local 404). Everything is data (data/bs/levels/verdant.json); a VerdantDirector builds and runs it.
## This script wires the director into BSLevel's lifecycle, puts the gadget belt on Bolt (GadgetManager: the
## Sprocket Glide is earned here), plays the level-owned cutscene scripts and answers the runner's anchors.
##
## Critical path (BS_LEVELS §6.2): the picket line guards the harvester -> the Union Hall (west): Local 404
## issues the solidarity sail (Glide, verdantLate) -> the Spore Groves (east): bounce mushrooms up the caps to
## the canopy and the fallen grain boom -> ride the boom and glide 30 m into the harvester's cab (verdantMid)
## -> down through the guts to the reactor bay (verdantIntro) -> the Coolant Lagoon: the Compost King and the
## three coolant leaks (introCompost; seal them all and shake hands for the mercy ending) -> the Keystone Core
## (coreVerdant) -> the Return Relay on the landing pad.

const LEVEL_ID: String = "verdant"

var director: VerdantDirector
var gadgets: GadgetManager
var level_cutscenes_played: PackedStringArray = []


func build() -> void:
	level_id = LEVEL_ID
	planet_index = 7
	director = VerdantDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup(self, LEVEL_ID)
	level_name = str(director.D.get("name", "VERDANT SINK"))
	spawn_point = director.start_point()
	kill_y = director.kill_y
	water_zones = director.water_zones
	for q: Variant in director.D.get("splash_quips", []):
		splash_quips.append(str(q))


func on_level_ready() -> void:
	gadgets = GadgetManager.attach_to(bolt)
	director.level_ready()
	if director.flag("compost_down"):
		director.boss_done = true
		director.reveal_core()
	var o: String = str((director.D.get("story", {}) as Dictionary).get("objective", ""))
	if o != "" and not director.flag("compost_down"):
		director.objective("bs.verdant.obj_boom" if director.flag("glide_earned") else o)


## flyover7 on the first landing (BS_LEVELS §6.9), once per save.
func arrival_beat() -> void:
	var q: PackedStringArray = []
	for cs: Variant in (director.D.get("story", {}) as Dictionary).get("arrival_cutscenes", ["flyover7"]):
		if not BS.flag("cs." + str(cs)) and (CutscenePlayer.has_scene(str(cs)) or director.has_level_cutscene(str(cs))):
			q.append(str(cs))
	_play_queue(q)


# ------------------------------------------------------------------ cutscenes

## Level-owned scripts first (verdant.json "cutscenes"), then the story file's.
func play_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	if director != null and director.has_level_cutscene(id):
		return play_level_cutscene(id, on_done)
	return super.play_cutscene(id, on_done)


## Plays a level cutscene through the shared CutscenePlayer (its internal _start, like Rustvane and Nova).
func play_level_cutscene(id: String, on_done: Callable = Callable()) -> bool:
	if cutscenes == null or BS.flag("cs." + id):
		return false
	level_cutscenes_played.append(id)
	BS.set_flag("cs." + id)
	cutscenes.call("_start", id, director.level_cutscene_steps(id), false, on_done)
	return true


func cutscene_anchor(anchor: String) -> Vector3:
	var anchors: Dictionary = (director.D.get("story", {}) as Dictionary).get("anchors", {}) if director != null else {}
	if anchors.has(anchor):
		return LevelKit.v3(anchors[anchor])
	return super.cutscene_anchor(anchor)


func cutscene_actor(actor: String) -> Node3D:
	var a: Node3D = director.get_actor(actor) if director != null else null
	if a == null and actor == "king" and director != null and director.boss != null and is_instance_valid(director.boss):
		a = director.boss
	return a if a != null else super.cutscene_actor(actor)


# ------------------------------------------------------------------ host calls the director doesn't own

func open_star_map() -> void:
	BS.save_to_profile()
	if DisplayServer.get_name() == "headless":
		return
	StarMap.open(get_tree())
