class_name CinemaTheatre
extends Node
## T-194: the LAZARUS cutscenes outside a match, on a scene of their own (gravelight/ui/cinema/cinema_theatre.tscn):
## the prologue LAZARUS SATURDAY before the main menu on the first launch, and every cutscene the Archive's gallery
## replays. `CinemaTheatre.play_ids(tree, ids, back)` queues the reel and changes to the scene; at the end (or a skip)
## the scene goes `back` ("menu": the CLAUDE ZOMBIES menu, "archive": the menu with the Archive's gallery open again,
## "launcher": the dev launcher).
## The Archive also replays the campaign hops (exfil_*): their maps load as for a match with nobody else in it, the
## rounds stopped, and the hop plays on ExfilCutscene with no beacon (it ends instead of travelling); see
## `replay_exfil` and LazarusCinema.on_rounds_started.
## The first-launch rule: ProfileSave "prologue_seen" false -> the prologue plays once; it is set when the prologue
## ends or is skipped, and only the Archive plays it again. Headless runs (tests, smokes, the dedicated tools) never
## start it on their own (`force_prologue` turns it on for the smoke).

const SCENE: String = "res://gravelight/ui/cinema/cinema_theatre.tscn"
const MENU: String = "res://gravelight/ui/main_menu.tscn"
## "launcher": the dev launcher's U11 buttons come back to it (Play.bat).
const LAUNCHER: String = "res://ui/dev_launcher.tscn"

static var queue: Array = []
static var back: String = "menu"
static var force_prologue: bool = false
## The Archive's replay of a campaign hop (exfil_*): the id the next map load plays instead of a match.
static var replay_id: String = ""
## The menu reopens the Archive's gallery after a replay.
static var open_gallery: bool = false

var reel: CinemaReel = null


## Does the main menu play the prologue first? (first launch: the profile has not seen it; never headless unforced)
static func wants_prologue() -> bool:
	if DisplayServer.get_name() == "headless" and not force_prologue:
		return false
	return prologue_due(ProfileSave.profile)


## Pure: the profile's first-launch flag.
static func prologue_due(profile: Dictionary) -> bool:
	return not bool(profile.get("prologue_seen", false))


static func mark_prologue_seen() -> void:
	ProfileSave.profile["prologue_seen"] = true
	note_seen("lazarus_saturday")
	ProfileSave.save_profile()


static func note_seen(id: String) -> void:
	var seen: Array = ProfileSave.profile.get("cutscenes_seen", [])
	if not seen.has(id):
		seen.append(id)
	ProfileSave.profile["cutscenes_seen"] = seen


static func play_ids(tree: SceneTree, cut_ids: Array, back_to: String = "menu") -> void:
	queue = cut_ids.duplicate()
	back = back_to
	tree.change_scene_to_file.call_deferred(SCENE)


## The Archive: a campaign hop on its own map (no match: CinemaTheatre.replay_id, LazarusCinema.on_rounds_started).
static func replay_exfil(tree: SceneTree, cut_id: String, map_id: StringName) -> void:
	Campaign.reset()
	replay_id = cut_id
	back = "archive"
	GameState.bot_count = 0
	GameState.bot_ai_mode = "off"
	LoadingScreen.go(tree, Campaign.scene_for(map_id), String(map_id))


## The map that plays a campaign hop (the map whose beacon names it).
static func exfil_map(cut_id: String) -> StringName:
	for m: Variant in Campaign.chain():
		if str(Campaign.exfil_cfg(StringName(str(m))).get("cutscene", "")) == cut_id:
			return StringName(str(m))
	return &""


func _ready() -> void:
	GLSettings.activate()
	Game.set_mode(Game.Mode.GRAVELIGHT)
	get_tree().paused = false
	GameState.phase = GameState.Phase.MENU
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	AudioDirector.stop_all_music()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl: CanvasLayer = CanvasLayer.new()
	cl.layer = 0
	add_child(cl)
	cl.add_child(bg)
	var ids: Array = queue.duplicate()
	queue = []
	if ids.is_empty():
		ids = ["lazarus_saturday"]
	reel = CinemaReel.play(self, ids, {"speed": Campaign.cutscene_speed})
	reel.cut_ended.connect(_on_cut_ended)
	reel.finished.connect(_on_finished)


func _on_cut_ended(_i: int, id: String, _skipped: bool) -> void:
	if id == "lazarus_saturday":
		mark_prologue_seen()
	else:
		note_seen(id)
		ProfileSave.save_profile()


func _on_finished() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open_gallery = back == "archive"
	get_tree().change_scene_to_file.call_deferred(LAUNCHER if back == "launcher" else MENU)
