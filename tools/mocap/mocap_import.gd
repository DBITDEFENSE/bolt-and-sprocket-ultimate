extends SceneTree
## T-210: the Godot step of tools/mocap.sh build. Reads the clip JSONs tools/mocap/mocap.py wrote
## (<work>/<scene>/<shot>_<role>.clip.json) and saves one AnimationLibrary per scene,
## <out>/<scene>/mocap_<scene>.res, with an animation per clip ("<shot>_<role>", MocapLibrary.animation_from_clip).
##   godot --headless --path . --script res://tools/mocap/mocap_import.gd -- --work=<abs dir> --out=res://assets/ours/mocap [--scenes=a,b]


func _init() -> void:
	var args: Dictionary = {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var work: String = str(args.get("work", ProjectSettings.globalize_path("res://.mocap_work")))
	var out: String = str(args.get("out", MocapLibrary.DIR))
	var only: PackedStringArray = str(args.get("scenes", "")).split(",", false)
	var code: int = 0
	var d: DirAccess = DirAccess.open(work)
	if d == null:
		push_error("[mocap] no work folder %s" % work)
		quit(1)
		return
	for scene: String in d.get_directories():
		if not only.is_empty() and not only.has(scene):
			continue
		var lib: AnimationLibrary = AnimationLibrary.new()
		var n: int = 0
		for f: String in DirAccess.get_files_at(work.path_join(scene)):
			if not f.ends_with(".clip.json"):
				continue
			var txt: String = FileAccess.get_file_as_string(work.path_join(scene).path_join(f))
			var j: Variant = JSON.parse_string(txt)
			if not (j is Dictionary):
				push_error("[mocap] bad clip %s" % f)
				code = 1
				continue
			var name: String = str((j as Dictionary).get("name", f.trim_suffix(".clip.json")))
			lib.add_animation(StringName(name), MocapLibrary.animation_from_clip(j as Dictionary))
			n += 1
		if n == 0:
			continue
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.path_join(scene)))
		var path: String = out.path_join(scene).path_join("mocap_%s.res" % scene)
		var err: int = ResourceSaver.save(lib, path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("[mocap] could not save %s (%d)" % [path, err])
			code = 1
		else:
			print("[mocap] %s: %d clips -> %s" % [scene, n, path])
	quit(code)
