class_name Phonograph
extends Interactable
## Hidden song (side egg): with all 3 cylinders found, play them here: "Lanterns Down Below".
## There's no recording yet, so the lyrics run as subtitles (credited "placeholder audio").

const QUEST: StringName = &"map01_song"

var _playing: bool = false


func _ready() -> void:
	interact_size = Vector3(0.8, 0.7, 0.3)
	interact_offset = Vector3(0, 0.9, -0.3)
	super._ready()


func build_greybox() -> void:
	InteractableArt.place(self, "phonograph", func(r: Node3D) -> void: InteractableArt.phonograph(r))


func get_prompt(_player: Player) -> String:
	if _playing:
		return ""
	if QuestManager.interact_ready(&"phonograph"):
		return "Hold [%s] to play the cylinders" % prompt_key(&"interact")
	if QuestManager.is_active(QUEST, &"s1_cylinders"):
		var got: Variant = QuestManager.progress(QUEST, &"s1_cylinders")
		return "A phonograph. Cylinders: %d/3" % ((got as Array).size() if got is Array else 0)
	return ""


func can_interact(_player: Player) -> bool:
	return not _playing and QuestManager.interact_ready(&"phonograph")


func interact(player: Player) -> void:
	if not QuestManager.interact(&"phonograph", player.player_id):
		return
	_play_song()
	Net.mirror(self, &"_play_song")


## The lyrics as subtitles (every peer: the host from interact(), clients from the host).
func _play_song() -> void:
	_playing = true
	var lyrics: Array = GLData.load_json("res://data/gravelight/quests/map01_song.json").get("lyrics", [])
	var t: float = 1.0
	for l: Variant in lyrics:
		var text: String = str(l)
		get_tree().create_timer(t).timeout.connect(func() -> void:
			GLBus.vo_line_started.emit(&"SONG_LANTERNS", &"SONG", "♪ " + text, 3.4))
		t += 3.6
	get_tree().create_timer(t).timeout.connect(func() -> void: _playing = false)
