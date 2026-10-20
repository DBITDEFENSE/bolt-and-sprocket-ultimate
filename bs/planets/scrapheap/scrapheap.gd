class_name ScrapheapLevel
extends BSLevel
## Scrapheap Junction (Planet 1, LEVELS[0]): the garage prologue through REPO-TRON. Everything is data
## (data/bs/levels/scrapheap.json); a LevelDirector builds and runs it. This script wires the director into
## BSLevel's lifecycle and answers the cutscene runner's anchors / actors ("garagePos(...)", act "garage").

const LEVEL_ID: String = "scrapheap"

var director: LevelDirector


func build() -> void:
	level_id = LEVEL_ID
	planet_index = 0
	director = LevelDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup(self, LEVEL_ID)
	level_name = str(director.D.get("name", "SCRAPHEAP JUNCTION"))
	spawn_point = director.start_point()
	kill_y = director.kill_y
	water_zones = director.water_zones
	# A new game arrives with pending_cutscene = "intro" (main menu). On Scrapheap the intro is the END of the
	# playable prologue (the garage gate trigger plays it), so it must not play at boot. BSLevel reads
	# pending_cutscene after build(), so clearing it here is enough.
	if pending_cutscene == "intro" and not director.flag("prologue_done"):
		pending_cutscene = ""


func on_level_ready() -> void:
	director.level_ready()


## The prologue ends in `intro` at the garage gate (BS_LEVELS §1.2), so it never plays at boot; on the first
## return after the planet is cleared, flyover0 then arrive0 play back to back.
func arrival_beat() -> void:
	_play_queue(director.return_cutscenes())


func cutscene_anchor(anchor: String) -> Vector3:
	var story: Dictionary = director.D.get("story", {}) if director != null else {}
	if anchor == "garage":
		return LevelKit.v3(story.get("garage_anchor", [14, 0, 4]))
	if anchor == "lvlShip" or anchor == "ship":
		return LevelKit.v3(story.get("ship_anchor", [-8, 0, 8]))
	return super.cutscene_anchor(anchor)


func cutscene_actor(actor: String) -> Node3D:
	var a: Node3D = director.get_actor(actor) if director != null else null
	return a if a != null else super.cutscene_actor(actor)
