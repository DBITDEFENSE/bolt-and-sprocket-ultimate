class_name LfPage
extends StoryProp
## A page of U-1047's log (Letzte Fahrt s3, UPDATE 10 contract C3, design sections 2 and 8, DECISIONS T-153): placed
## at one of its two seeded spots (the quest's `log_spots` roll), read in the full-screen reader like any story item,
## and counted for the quest's `lf_log` collect (four pages). The authority runs the read so the count is the host's;
## the reader opens on the reading player's own machine (mirrored by player id).

const QUEST: StringName = &"map02_letzte_fahrt"

var page_id: StringName = &""
var read_by_anyone: bool = false


func _ready() -> void:
	page_id = intel_id
	style = "logbook"
	super._ready()
	add_to_group(&"lf_log_pages")


func net_local() -> bool:
	return false


func interact(player: Player) -> void:
	if not Net.is_authority():
		return
	if not read_by_anyone:
		read_by_anyone = true
		QuestManager.collect(&"lf_log", page_id, player.player_id)
		ProfileSave.add_intel(intel_id)
	_open(player.player_id)
	Net.mirror(self, &"_open", [player.player_id])


## The reader opens for that player only where they are local (bots read in silence).
func _open(pid: int) -> void:
	read_by_anyone = true
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Player = n as Player
		if p != null and p.player_id == pid and p.is_local and not p.is_bot:
			StoryReader.open_for(p, intel_id, row)
