class_name IntelPickup
extends Interactable
## A lore document, photo or recording found in the world. Picking it up files it in the Intel Archive.

@export var intel_id: StringName = &""
@export var title: String = ""
@export var kind: String = "DOC"

var _taken: bool = false


func _ready() -> void:
	interact_size = Vector3(0.7, 0.6, 0.7)
	super._ready()


func build_greybox() -> void:
	match kind:
		"AUDIO":
			InteractableArt.place(self, "intel_audio", func(r: Node3D) -> void: InteractableArt.intel_audio(r))
		"PHOTO":
			InteractableArt.place(self, "intel_photo", func(r: Node3D) -> void: InteractableArt.intel_photo(r))
		_:
			InteractableArt.place(self, "intel_doc", func(r: Node3D) -> void: InteractableArt.intel_doc(r))
	var glint: OmniLight3D = OmniLight3D.new()
	glint.light_color = Color(0.8, 0.7, 1.0)
	glint.light_energy = 0.5
	glint.omni_range = 1.6
	glint.position = Vector3(0, 0.3, 0)
	add_child(glint)


func get_prompt(_player: Player) -> String:
	return "" if _taken else "Hold [%s] to take: %s" % [prompt_key(&"interact"), title]


func can_interact(_player: Player) -> bool:
	return not _taken


## Intel is personal (each peer places and finds its own): never sent to the host.
func net_local() -> bool:
	return true


func interact(_player: Player) -> void:
	if _taken:
		return
	_taken = true
	GLBus.intel_found.emit(intel_id)
	AudioDirector.play_2d("intel_pickup", 0.0, 0.0)
	var hud: Node = get_tree().get_first_node_in_group(&"hud")
	if hud != null:
		hud.call("show_banner", "INTEL FILED\n" + title, 2.5)
	queue_free()
