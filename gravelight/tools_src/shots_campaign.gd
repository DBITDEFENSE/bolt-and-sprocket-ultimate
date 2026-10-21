extends Node
## Dev tool (T-033): silent off-screen screenshots of the campaign exfil: the lit beacon with the squad at it
## on Map 0, then three frames of the Map 0 -> Map 1 transition cutscene (the great doors, the crossroads at
## dawn, the KALTENBRUNN title card). A real window off-screen, never the mouse (D-058):
##   godot --audio-driver Dummy --position -4000,-4000 --resolution 1280x720 --path . res://gravelight/tools_src/shots_campaign.tscn [-- --out=<dir>]
## -> <dir>/campaign_<name>.png (default user://shots). Quits before Map 1 loads.

const MAP0: String = "res://gravelight/maps/map00_crossroads/map00.tscn"

var _out: String = "user://shots"
var _cam: Camera3D
var _taken: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out if _out.is_absolute_path() else ProjectSettings.globalize_path(_out))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	ProfileSave.path = "user://_qa_campaign_shots_profile.json"
	ProfileSave.profile = ProfileSave.new_profile()
	GameState.character_id = &"peg"
	GameState.bot_count = 3
	GameState.bot_skill = "regular"
	Campaign.begin()
	Campaign.cutscene_speed = 1.0
	GameState.god_mode = true
	var map: Node3D = (load(MAP0) as PackedScene).instantiate() as Node3D
	get_tree().root.add_child.call_deferred(map)
	get_tree().set_deferred("current_scene", map)
	_cam = Camera3D.new()
	_cam.far = 400.0
	add_child(_cam)
	_run.call_deferred()


func _process(_delta: float) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _snap(shot_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join("campaign_%s.png" % shot_name)
	img.save_png(path)
	_taken[shot_name] = true
	print("shot %s" % ProjectSettings.globalize_path(path) if path.begins_with("user://") else "shot %s" % path)


func _run() -> void:
	await _secs(3.0)
	var map: MapRoot = get_tree().current_scene as MapRoot
	var x: ExfilPoint = get_tree().get_first_node_in_group(&"exfil_points") as ExfilPoint
	if map == null or x == null:
		print("no map / beacon")
		get_tree().quit(1)
		return
	map.director.kill_all(true)
	RoundManager.debug_set_round(10)
	var t: float = 0.0
	while not x.is_active() and t < 20.0:
		await _secs(0.25)
		t += 0.25
	RoundManager.stop()   # a quiet stable for the photo
	map.director.kill_all(true)
	var human: Player = map.player
	var front: Vector3 = x.global_position + x.global_basis * Vector3(0, 0, -1.8)
	human.global_position = front + Vector3(0.6, 0, 0)
	human.velocity = Vector3.ZERO
	human.rotation.y = atan2(-(x.global_position.x - human.global_position.x), -(x.global_position.z - human.global_position.z))
	var j: int = 0
	for pid: int in GameState.bot_ids:
		var b: Player = map.players[pid] as Player
		b.global_position = front + Vector3(1.3 * (j - 1) - 0.6, 0, -1.2 - 0.4 * j)
		b.rotation.y = human.rotation.y
		j += 1
	await _secs(1.5)
	# the beacon from the stalls, the squad around it
	_cam.global_position = x.global_position + Vector3(3.6, 2.2, -5.8)
	_cam.look_at(x.global_position + Vector3(0.3, 1.3, -0.5), Vector3.UP)
	_cam.current = true
	await _secs(0.6)
	await _snap("01_beacon")
	# the human's own view of the prompt
	human.camera.current = true
	human.set("_pitch", 0.05)
	await _secs(0.6)
	await _snap("02_beacon_prompt")
	# vote -> the cutscene; frames at the doors, the dawn crossroads and the title card
	human.use_interactable(x)
	var cs: ExfilCutscene = null
	t = 0.0
	while cs == null and t < 5.0:
		await _secs(0.1)
		t += 0.1
		cs = x.cutscene
	if cs == null:
		print("no cutscene")
		get_tree().quit(1)
		return
	var marks: Array = [["03_cut_doors", 3.0], ["04_cut_dawn", 15.0], ["05_cut_title", 24.0]]
	for m: Array in marks:
		while is_instance_valid(cs) and float(cs.get("_t")) < float(m[1]):
			await _secs(0.1)
		if is_instance_valid(cs):
			await _snap(str(m[0]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ProfileSave.path))
	get_tree().quit(0 if _taken.size() == 5 else 1)
