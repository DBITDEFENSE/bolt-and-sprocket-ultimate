extends RefCounted
## Loads the locally licensed, pre-retargeted GLBs once. No per-actor imports or pose generation.

const CONFIG: String = "res://data/gravelight/zombie_mocap.json"
const MANIFEST: String = "res://assets/zombies/anims/mocap_manifest.json"
var config: Dictionary = {}
var metadata: Dictionary = {}
var animations: Dictionary = {}
var errors: Array[String] = []

func load_bank() -> void:
	config = GLData.load_json(CONFIG)
	if not FileAccess.file_exists(MANIFEST): return
	var report: Dictionary = GLData.load_json(MANIFEST)
	for name: String in report.get("clips", {}):
		var row: Dictionary = report["clips"][name]
		var path: String = "res://assets/zombies/anims/" + str(row["file"])
		if not ResourceLoader.exists(path):
			errors.append("Missing local mocap import: " + name)
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			errors.append("Cannot load mocap GLB: " + name)
			continue
		var instance: Node = scene.instantiate()
		var players: Array[Node] = instance.find_children("*", "AnimationPlayer", true, false)
		var converted: Animation
		if not players.is_empty():
			var ap: AnimationPlayer = players[0] as AnimationPlayer
			for clip: String in ap.get_animation_list():
				if clip == "RESET": continue
				if converted != null:
					errors.append("Ambiguous clip in " + name)
					converted = null
					break
				converted = ap.get_animation(clip).duplicate() as Animation
		instance.free()
		if converted == null:
			errors.append("No unique animation in " + name)
			continue
		var valid: bool = true
		for track: int in converted.get_track_count():
			var old_path: NodePath = converted.track_get_path(track)
			var bone: String = str(old_path.get_subname(0)) if old_path.get_subname_count() == 1 else ""
			if not ZombieRig.bone_names().has(bone):
				errors.append("Unexpected mocap target " + str(old_path))
				valid = false
				break
			converted.track_set_path(track, NodePath("Skel:" + bone))
		if not valid: continue
		converted.loop_mode = Animation.LOOP_LINEAR if bool(row["loop"]) else Animation.LOOP_NONE
		converted.set_meta("source", row["source_fbx"])
		converted.set_meta("source_sha256", row["sha256"])
		animations[name] = converted
		metadata[name] = row
	for error: String in errors: push_error(error)
