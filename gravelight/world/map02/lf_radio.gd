class_name LfRadio
extends Interactable
## Letzte Fahrt's code radios (UPDATE 10 contract C3, design section 2 s2, DECISIONS T-153): three sets (the cannery
## office, the workshop bench, U-1047's radio room) crackling German U-boat traffic. Hold [interact] to listen: the
## set gives its 4-letter code group and its place in the keying order ("Spruch 2 von 3") from the quest's seeded
## `cipher` roll, and counts for the quest's `lf_radio` collect. The groups' first letters, in that order, set the
## rotor machine's wheels. Co-op: the host decides; the message banner shows on every peer.

const QUEST: StringName = &"map02_letzte_fahrt"

@export var radio_id: StringName = &"radio_cannery"

var heard: bool = false
var _hum: AudioStreamPlayer3D
var _lamp: MeshInstance3D


func _ready() -> void:
	interact_size = Vector3(0.9, 0.8, 0.8)
	interact_offset = Vector3(0, 0.9, 0)
	super._ready()
	add_to_group(&"lf_radios")
	_hum = AudioDirector.make_loop_3d("radio_static", self)
	if _hum != null:
		_hum.position = Vector3.UP


func build_greybox() -> void:
	var case: StandardMaterial3D = greybox_mat(Color(0.18, 0.2, 0.17))
	add_box(self, Vector3(0.6, 0.8, 0.5), Vector3(0, 0.4, 0), greybox_mat(Color(0.3, 0.24, 0.17)))   # the stand
	add_box(self, Vector3(0.55, 0.32, 0.36), Vector3(0, 0.96, 0), case)
	_lamp = add_box(self, Vector3(0.05, 0.05, 0.02), Vector3(0.18, 1.02, -0.19), greybox_mat(Color(1.0, 0.6, 0.2), 2.0))
	add_box(self, Vector3(0.36, 0.14, 0.02), Vector3(-0.05, 0.94, -0.19), greybox_mat(Color(0.7, 0.65, 0.5), 0.4))   # the dial
	var l: Label3D = add_label(self, "FUNK", Vector3(0, 1.16, -0.19), 14, Color(0.9, 0.85, 0.7))
	l.rotation.y = 0.0


## Pure (tested): the radio's message from a cipher roll: [place in order (1-based), group].
static func message_for(rid: StringName, roll: Dictionary) -> Array:
	var order: Array = roll.get("order", [])
	var groups: Dictionary = roll.get("groups", {})
	return [order.find(String(rid)) + 1, str(groups.get(String(rid), "????"))]


func get_prompt(_player: Player) -> String:
	return "Hold [%s] to listen to the radio" % prompt_key(&"interact")


func hold_time(_player: Player) -> float:
	return 1.2


func repeats() -> bool:
	return true


func interact(player: Player) -> void:
	if not Net.is_authority():
		return
	var roll: Dictionary = QuestManager.random_value(QUEST, "cipher") if QuestManager.random_value(QUEST, "cipher") is Dictionary else {}
	if roll.is_empty():
		_show(0, "")
		Net.mirror(self, &"_show", [0, ""])
		return
	var m: Array = message_for(radio_id, roll)
	_show(int(m[0]), str(m[1]))
	Net.mirror(self, &"_show", [int(m[0]), str(m[1])])
	if not heard:
		heard = true
		QuestManager.collect(&"lf_radio", radio_id, player.player_id)


## Every peer: the message on the banner, the set's voice.
func _show(place: int, group: String) -> void:
	heard = heard or place > 0
	var t: Totenhafen = Totenhafen.of(get_tree())
	if place <= 0:
		if t != null:
			t.banner("Static. Somewhere under it, an engine-room clock ticking.", 3.0)
		return
	if t != null:
		t.banner("FUNKSPRUCH %d VON 3\nGRUPPE  %s" % [place, " ".join(group.split(""))], 6.0)
	GLVO.play_local(StringName("RAD_M2_CODE_%02d" % clampi(place, 1, 3)))
	if _lamp != null:
		var tw: Tween = create_tween()
		tw.tween_property(_lamp, "scale", Vector3.ONE * 1.6, 0.2)
		tw.tween_property(_lamp, "scale", Vector3.ONE, 0.6)
