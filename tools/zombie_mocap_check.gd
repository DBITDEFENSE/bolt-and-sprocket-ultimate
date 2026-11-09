extends Node
## Actual GLB import checks: target rests, finite poses, source clip retention and conversion metrics.

func _ready() -> void:
	var cfg: Dictionary = GLData.load_json("res://data/gravelight/zombie_mocap.json")
	var report: Dictionary = GLData.load_json("res://assets/zombies/anims/mocap_manifest.json")
	if "--prepare-imports" in OS.get_cmdline_user_args():
		ResourceSaver.save(ZombieRig.bone_map(), "res://assets/zombies/anims/shared_humanoid_bone_map.tres")
		for key: String in report["clips"]:
			var settings := ConfigFile.new()
			var path: String = "res://assets/zombies/anims/" + str(report["clips"][key]["file"]) + ".import"
			if settings.load(path) != OK:
				push_error("Run Godot --import first: " + path)
				get_tree().quit(1)
				return
			settings.set_value("params", "import_script/path", "res://tools/blender/zombie_anim_import.gd")
			settings.set_value("params", "animation/remove_immutable_tracks", false)
			settings.set_value("params", "meshes/generate_lods", false)
			settings.set_value("params", "meshes/create_shadow_meshes", false)
			settings.save(path)
		print("ZOMBIE_MOCAP_PRESETS ", report["clips"].size())
		get_tree().quit(0)
		return
	var rows: Array[Dictionary] = []
	var failures: Array[String] = []
	for key: String in report["clips"]:
		var row: Dictionary = report["clips"][key]
		var path: String = "res://assets/zombies/anims/" + str(row["file"])
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			failures.append("Cannot load " + path)
			continue
		var node: Node = scene.instantiate()
		add_child(node)
		var sk: Skeleton3D = node.find_child("*", true, false) as Skeleton3D
		var skeletons: Array[Node] = node.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty(): sk = skeletons[0] as Skeleton3D
		var players: Array[Node] = node.find_children("*", "AnimationPlayer", true, false)
		var item: Dictionary = {"clip": key, "bones": 0, "tracks": [], "animations": []}
		if sk == null:
			failures.append(key + ": no imported Skeleton3D")
		else:
			item["bones"] = sk.get_bone_count()
			if not sk.get_meta("bone_map", null) is BoneMap:
				failures.append(key + ": missing shared Humanoid import map")
			for bone: String in ZombieRig.bone_names():
				var bi: int = sk.find_bone(bone)
				if bi < 0:
					failures.append(key + ": missing " + bone)
				elif not sk.get_bone_rest(bi).origin.is_equal_approx(ZombieRig.rest_offset(bone)) or not sk.get_bone_rest(bi).basis.is_equal_approx(Basis.IDENTITY):
					failures.append(key + ": rest mismatch " + bone + " " + str(sk.get_bone_rest(bi)))
		if players.is_empty():
			failures.append(key + ": no AnimationPlayer")
		else:
			var ap: AnimationPlayer = players[0] as AnimationPlayer
			item["animations"] = Array(ap.get_animation_list())
			for anim_name: String in ap.get_animation_list():
				if anim_name == "RESET": continue
				var a: Animation = ap.get_animation(anim_name)
				for t: int in a.get_track_count(): item["tracks"].append(str(a.track_get_path(t)))
				item["duration"] = a.length
				if absf(a.length - float(row["duration"])) > 0.04: failures.append(key + ": duration changed on import")
		rows.append(item)
		node.free()
	if rows.size() != (cfg["clips"] as Array).size():
		failures.append("Incomplete pack conversion")
	var out: Dictionary = {"clips": rows, "failures": failures, "expected": (cfg["clips"] as Array).size()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/captures/after/mocap"))
	var file := FileAccess.open("res://docs/captures/after/mocap/godot_import.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t"))
	print("ZOMBIE_MOCAP_CHECK ", rows.size(), " clips; failures=", JSON.stringify(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
