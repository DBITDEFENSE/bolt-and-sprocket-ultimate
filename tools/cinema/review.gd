extends Node
## Off-screen review of the real replacement camera, stage and post stack.
## godot --audio-driver Dummy --position -4000,-4000 --path . res://tools/cinema/review.tscn
const FRAMES: Array = [
	["lazarus_saturday", 6.0, "village"],
	["lazarus_saturday", 166.0, "relic"],
	["lazarus_saturday", 195.0, "ward"],
	["fourth_day", 6.0, "front"],
	["fourth_day", 64.0, "grave"],
	["staub", 5.0, "mill"],
	["staub", 62.0, "heart"],
	["gravelight_one", 6.0, "aircraft"],
	["epilogue_1953", 5.0, "vault"]
]


func _ready() -> void:
	ProfileSave.path = "user://_qa_cinema_horror_profile.json"
	GLSettings.path = "user://_qa_cinema_horror_settings.cfg"
	GLSettings.values["screen_shake"] = 1.0
	GLSettings.values["graphics_preset"] = "high"
	Game.set_mode(Game.Mode.GRAVELIGHT)
	AudioDirector.stop_all_music()
	var out: String = "res://docs/captures/cinema_horror/review"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for item: Array in FRAMES:
		var source: Dictionary = CinemaLibrary.resolved(str(item[0]))
		var shot: Dictionary = {}
		for candidate: Dictionary in source["shots"]:
			if is_equal_approx(float(candidate["t"]), float(item[1])):
				shot = candidate.duplicate(true)
		var stage: CinemaSet = (load(CinemaLibrary.stage_path(str(shot["_set"]))) as PackedScene).instantiate() as CinemaSet
		stage.set_meta("roster", CinemaLibrary.SQUAD)
		add_child(stage)
		LookGrade.apply_stage(stage, "cinema_horror")
		var post: LookPost = LookPost.add_to(self, "cinema_horror")
		# No fast-forward: old titles and queued dialogue must not cover the frame.
		for key: String in ["lines", "squad_lines", "vo", "vo2", "card", "caption", "sfx", "sfx_opt", "stinger", "black"]:
			shot.erase(key)
		shot["t"] = 0.0
		shot["cut"] = "cut"
		var d: Dictionary = {"seconds": 12.0, "shots": [shot], "fade_in_s": 0.0, "skip_after": 100.0, "grade": source.get("grade", "neutral")}
		var director: CinemaDirector = CinemaDirector.make(self, d, stage, {"cast": false, "hide_hud": false, "speed": 1.0})
		if str(item[2]) == "relic":
			stage.fx("enter", 0.1)
			stage.fx("vessel_open", 0.15)
			await get_tree().create_timer(0.3).timeout
		var fx: Variant = shot.get("fx", [])
		if fx is String:
			stage.fx(str(fx), 7.0)
		elif fx is Array:
			for effect: String in fx:
				stage.fx(effect, 7.0)
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		var path: String = out.path_join(str(item[2]) + ".png")
		var err: Error = get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("[cinema-review] %s %s" % [path, error_string(err)])
		director.queue_free()
		post.queue_free()
		stage.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	print("[cinema-review] COMPLETE")
	get_tree().quit()
