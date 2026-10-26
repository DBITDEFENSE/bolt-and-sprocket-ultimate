class_name Switchboard
extends Interactable
## The Administration switchboard (step 2b): plug the six code digits in order. Opens ui/switchboard_ui.gd.

const QUEST: StringName = &"map01_requiem"

@export var target: StringName = &"switchboard"
## UPDATE 07 (T-114): the same board serves the Thalbach canteen's PA line (quest map04_kuendigung, step s3).
@export var quest: StringName = &"map01_requiem"
@export var step: StringName = &"s2b_switchboard"
@export var sign: String = "AMT KALTENBRUNN  ·  VERMITTLUNG"
@export var prompt_text: String = "work the switchboard"

var _ui: CanvasLayer


func _ready() -> void:
	interact_size = Vector3(2.2, 1.6, 0.3)
	interact_offset = Vector3(0, 1.1, -0.2)
	super._ready()


func build_greybox() -> void:
	# the jack field, cords and plugs, lamps and the shelf on the front of the board (cached)
	InteractableArt.place(self, "switchboard", func(r: Node3D) -> void: InteractableArt.switchboard(r))
	add_label(self, sign, Vector3(0, 2.0, -0.065), 18, Color(0.9, 0.8, 0.55))


func get_prompt(_player: Player) -> String:
	if QuestManager.is_active(quest, step):
		return "Hold [%s] to %s" % [prompt_key(&"interact"), prompt_text]
	return ""


func can_interact(_player: Player) -> bool:
	return QuestManager.is_active(quest, step)


## Co-op: the board's UI opens on the user's machine; each plug goes to the host (plug()).
func net_local() -> bool:
	return true


func net_callable() -> Array:
	return ["plug"]


func interact(player: Player) -> void:
	if _ui != null and is_instance_valid(_ui):
		return
	_ui = (load("res://gravelight/ui/switchboard_ui.gd") as GDScript).new() as CanvasLayer
	_ui.set("board", self)
	_ui.set("player", player)
	get_tree().current_scene.add_child(_ui)


## Called by the UI (and tests) for each plugged digit. Returns "ok", "wrong", "done" or "inactive".
func plug(digit: int) -> String:
	var res: Dictionary = QuestManager.submit(target, str(digit))   # a client gets a prediction
	if Net.is_client() and Net.session != null:
		Net.session.request_call(self, &"plug", [digit])
	match str(res["result"]):
		"ok", "done":
			AudioDirector.play_3d("bolt_cycle", global_position + Vector3.UP, -4.0)
		"wrong":
			AudioDirector.play_3d("deny", global_position + Vector3.UP, 2.0)
			Effects.explosion(global_position + Vector3(0, 1.4, -0.2), 0.6)
	return str(res["result"])
